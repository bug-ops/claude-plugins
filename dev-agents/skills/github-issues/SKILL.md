---
name: github-issues
description: "GitHub issue mechanics for dev-agents: detects what the repository and the installed gh support (issue types, statuses, fields, relation flags), files an issue with its type, priority label, and real parent and blocked-by relations in one call, searches for duplicates, moves statuses, closes as duplicate or not planned, and attaches evidence as images or issue artifacts. Agents and orchestration skills load it before they create, edit, link, or close a GitHub issue; it is not meant to be invoked by users."
user-invocable: false
---

# GitHub Issues

Mechanics of GitHub issues through `gh`. What to file, its priority, and the body template come from the caller: `.claude/rules/commits-and-issues.md`, the audit or testing protocol, or the agent's own filing section. This skill decides only how the issue is expressed on GitHub.

## 1. Capabilities

Detect once per session, before the first issue command:

```bash
gh --version
gh api graphql -F owner='{owner}' -F repo='{repo}' -f query='
  query($owner: String!, $repo: String!) {
    repository(owner: $owner, name: $repo) {
      issueTypes(first: 25) { nodes { name description isEnabled } }
      planningStatuses(first: 25) { nodes { id name } }
      issueFields(first: 25) { nodes { ... on IssueFieldCommon { name dataType } } }
    }
  }' --jq '.data.repository | {
    types: [.issueTypes.nodes[]? | select(.isEnabled) | {name, description}],
    statuses: [.planningStatuses.nodes[]? | {name, id}],
    fields: [.issueFields.nodes[]? | .name]}'
```

`gh` fills `{owner}` and `{repo}` from the current repository. An empty list means the repository lacks the feature: skip it, and never emulate it with a label. If the query fails on an unknown field (an older GitHub Enterprise Server), remove that field and run it again.

| Feature | Needs `gh` | On an older `gh` |
|---------|-----------|------------------|
| `--type`, `--parent`, `--blocked-by`, `--blocking`, relation fields in `--json` | 2.94 | [REST fallback](${CLAUDE_PLUGIN_ROOT}/skills/github-issues/references/rest-fallback.md) |
| `gh issue close --duplicate-of` | 2.88 | `--reason "not planned"` with a `Duplicate of #N` comment |
| `gh search issues --search-type` | 2.98 | skip the hybrid pass |
| `--attach` | 2.99 | describe the evidence in text |
| `gh issue artifact` (preview) | 2.103 | a comment |

## 2. Duplicates

Search before filing, open and closed, with two or three wordings: the symptom, the component or symbol, the error text.

```bash
gh issue list --state all --search "<key terms> in:title,body" --limit 20 --json number,title,state,stateReason,url
gh search issues "<the problem in plain words>" --repo <owner>/<repo> --search-type hybrid --limit 10 --json number,title,state,url
```

The hybrid pass ranks by meaning and returns one page; many repositories are not indexed for it, so an empty result there proves nothing.

| Match | Action |
|-------|--------|
| open | comment with the new evidence; no new issue |
| closed as completed, the symptom is back | new issue, linked to the old one with a relates-to relation (section 4) |
| closed as not planned or duplicate | no new issue unless the evidence changes the decision; then comment on the closed one |

Two open issues describing one problem: move the unique evidence into the older one, then `gh issue close <newer> --duplicate-of <older>`. Close as duplicate only an issue you filed in this session or one the caller's protocol tells you to close; otherwise comment on both and report.

## 3. Filing

One `gh issue create` call carries the type, the labels, and the relations. Nothing is added in a second pass; drop the flags that do not apply:

```bash
gh issue create \
  --title "<title>" \
  --type "<type>" \
  --label "<P0-P4>,<category>" \
  --parent <tracking issue> \
  --blocked-by <n>[,<n>] \
  --blocking <n>[,<n>] \
  --body-file <file>
```

**Type.** Set it whenever the Capabilities query lists types:

| The issue is | Type |
|--------------|------|
| a defect: wrong behavior, crash, regression, vulnerability | `Bug` |
| a new capability or a user-visible improvement | `Feature` |
| anything else: refactoring, tech debt, research, documentation, CI, dependency update, hardening | `Task` |

A repository may define its own types. Pick the enabled type whose name and description fit best, and prefer a specific one (`Epic` for a tracking parent, `Security`, `Research`) over the three defaults. No fitting type: omit `--type`.

**Labels.** The type is added to the labels, not instead of them. The literal `P0`-`P4` label and the category label (`bug`, `enhancement`, `research`, ...) stay, set at creation: triage and searches read them, and they work in repositories without types.

**Fields.** Where the Capabilities query lists fields, see [Issue Fields](${CLAUDE_PLUGIN_ROOT}/skills/github-issues/references/fields.md). The priority label stays the priority of record.

## 4. Relations

A dependency or a hierarchy is a real GitHub relation, never only a text mention. Every flag takes issue numbers or URLs; a URL reaches another repository.

| Relation | At creation | On existing issues |
|----------|-------------|--------------------|
| this issue cannot start until N lands | `--blocked-by N` | `gh issue edit <n> --add-blocked-by N` |
| N cannot start until this issue lands | `--blocking N` | `gh issue edit <n> --add-blocking N` |
| part of tracking issue P | `--parent P` | `gh issue edit <n> --parent P`, or `gh issue edit P --add-sub-issue <n>` |
| same area, no order between them | — | relates-to, below |

Removal mirrors it: `--remove-blocked-by`, `--remove-blocking`, `--remove-parent`, `--remove-sub-issue`.

Read all relations in one call:

```bash
gh issue view <n> --json parent,subIssues,subIssuesSummary,blockedBy,blocking
```

`blockedBy`, `blocking`, and `subIssues` are `{nodes: [{number, state, title, url}], totalCount}`; `parent` is an issue or null. The same fields work in `gh issue list --json`.

Relates-to has no `gh` flag. One call links both issues, and repeating it is harmless:

```bash
a=$(gh issue view <n> --json id --jq .id)
b=$(gh issue view <m> --json id --jq .id)
gh api graphql -f a="$a" -f b="$b" -f query='
  mutation($a: ID!, $b: ID!) {
    addRelatesTo(input: {issueId: $a, relatedIssueId: $b}) {
      issue { number relatesTo(first: 20) { nodes { number } } }
    }
  }'
```

`removeRelatesTo` takes the same input; `relatesTo` on an issue reads the relation.

## 5. Status

Applies when the Capabilities query lists statuses (`Backlog`, `Todo`, `In progress`, `In review`, `Done`, `Not planned`, `Duplicate`; public preview). GitHub moves an issue on its own: a new issue starts in `Backlog`, assigning a person moves `Backlog` to `Todo`, linking a draft PR sets `In progress`, an open PR that closes the issue sets `In review`, and closing sets `Done`, `Not planned`, or `Duplicate` from the close reason. Nothing moves back: unassigning leaves the status where it was. An issue filed before the repository had statuses has none until something moves it. Set by hand only what that automation cannot see:

| Moment | Status |
|--------|--------|
| work starts and no PR exists yet | `In progress` |
| an issue leaves the scope of the PR and is unassigned | `Backlog` |

```bash
gh api graphql -f issue="$(gh issue view <n> --json id --jq .id)" -f status="<status id>" -f query='
  mutation($issue: ID!, $status: ID!) {
    setIssueStatus(input: {issueId: $issue, statusId: $status}) { issue { number status { name } } }
  }'
```

The status id comes from the Capabilities query. Never set `Done`, `Not planned`, or `Duplicate` this way: the mutation closes the issue, and an open status on a closed issue reopens it. Close through section 6.

Read a status:

```bash
gh api graphql -F owner='{owner}' -F repo='{repo}' -F n=<n> -f query='
  query($owner: String!, $repo: String!, $n: Int!) {
    repository(owner: $owner, name: $repo) { issue(number: $n) { status { name } } }
  }' --jq '.data.repository.issue.status.name'
```

## 6. Closing

| Outcome | How |
|---------|-----|
| fixed by a PR | a `Closes #N` line in the PR body, one keyword per line; never close by hand |
| duplicate | `gh issue close <n> --duplicate-of <m>` |
| will not be done, invalid, or obsolete | `gh issue close <n> --reason "not planned" --comment "<why>"` |

The close reason carries the outcome; do not add a `duplicate` or `wontfix` label to an issue you close.

## 7. Evidence

The body must stand alone: a reader with nothing else can reproduce the problem. Attachments add to it, never replace it.

- **Screenshot or recording** — `--attach './shot.png#<alt text>'` on `gh issue create`, `gh issue edit`, or `gh issue comment`.
- **Long material** (a full log, benchmark output, a reproduction transcript, a report) — keep the excerpt that proves the point in the body and attach the rest as an issue artifact:
  ```bash
  gh issue artifact create <n> './run.log#Failing run log'
  gh issue artifact list <n> --json number,name,type
  gh issue artifact view <n> <artifact number> --json body --jq .body
  ```
  Artifacts are in preview: when the command is missing or refused, post the material as a comment instead.
- Before solving an issue, list its artifacts and read the documents: they carry context the body only summarizes.
- Never attach secrets, tokens, or unredacted personal data.

## References

- [REST fallback](${CLAUDE_PLUGIN_ROOT}/skills/github-issues/references/rest-fallback.md) — types and relations through `gh api` for a `gh` older than 2.94
- [Issue Fields](${CLAUDE_PLUGIN_ROOT}/skills/github-issues/references/fields.md) — discover, read, and set issue fields
