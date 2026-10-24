---
name: triage-and-solve
description: "Triage open GitHub issues by priority (P0-P4 labels first, category labels as fallback) and by their blocked-by/sub-issue relations, group dependent and compatible ones into a single PR sized by estimated change volume, then solve via /solve-issue."
when_to_use: "'triage issues', 'what should I work on', 'pick next issue', 'prioritize issues'."
argument-hint: "[--limit N] [--label filter]"
disable-model-invocation: true
---

# Triage and Solve

Triage open GitHub issues by priority and relations, group dependent and compatible ones into a single PR whose diff stays reviewable, then solve the highest-priority group via /dev-agents:solve-issue.

## Steps

**1. Fetch unassigned open issues**

Run: `gh issue list --state open --limit 100 --search "no:assignee" --json number,title,body,labels,milestone,assignees`

Only unassigned issues are eligible for triage. The `no:assignee` search filter excludes assigned issues at the source; as a safety check, skip any result where `assignees` is non-empty.

**2. Sort by priority**

Assign each issue its own priority score in two tiers; step 3 refines it into the effective score used for selection.

**Tier 1 — explicit `P0`-`P4` labels (authoritative).** Check whether the project uses P-labels: any fetched issue carrying a `P0`-`P4` label means it does. When present, the P-label is the primary metric — score equals the P-number:

| Label | Score |
|-------|-------|
| `P0` | 0 |
| `P1` | 1 |
| `P2` | 2 |
| `P3` | 3 |
| `P4` | 4 |

Every issue with a P-label outranks every issue without one. Within the same P-level, break ties with the Tier 2 table (e.g., a `P1` + `bug` issue goes before a `P1` + `enhancement` issue).

**Tier 2 — category labels (fallback).** For issues without a P-label, and for projects that do not use P-labels at all:

| Label | Score |
|-------|-------|
| `critical` | 5 |
| `high` | 6 |
| `bug` / `fix` | 7 |
| `enhancement` | 8 |
| no priority label | 9 |
| `research` | 10 |

If an issue has multiple labels, use the lowest (highest priority) score within its tier — with one exception: `research` overrides other category labels.

**Research goes to the tail.** `research` issues are real work and must stay in the queue — never drop them — but they always sort to the end, after unlabeled issues. The only thing that moves a research issue up is an explicit P-label (Tier 1 wins: the project stated its priority).

**3. Load issue relations**

For each issue, read its GitHub relations — these are authoritative:

```bash
gh api repos/{owner}/{repo}/issues/<n>/dependencies/blocked_by --jq '[.[] | {number, state, repo: .repository_url, assignees: [.assignees[].login]}]'
gh api repos/{owner}/{repo}/issues/<n>/dependencies/blocking --jq '[.[] | {number, state}]'
gh api repos/{owner}/{repo}/issues/<n>/sub_issues --jq '[.[] | {number, state}]'
gh api repos/{owner}/{repo}/issues/<n>/parent --jq '.number'   # 404 = no parent
```

Then fetch full details including comments: `gh issue view <number> --json number,title,body,labels,comments`. Analyze the body **and all comments** — comments often carry root cause analysis, reproduction details, or scope changes, and may reveal that the issue is broader or narrower than its title or overlaps another issue. Collect text references ("depends on #N", "blocked by #N", "part of #N", "after #N lands"); any that has no matching relation is a **missing relation**, created in step 7.

Build the dependency graph and classify every blocker:

| Blocker state | Effect on the blocked issue |
|---------------|-----------------------------|
| closed | satisfied — ignore the edge |
| open, unassigned, in this repository | prerequisite — must land in the same group or an earlier one |
| open, assigned, or in another repository | external — the blocked issue and everything depending on it sit out this pass |

A dependency cycle is a triage defect: report it and leave its issues out of selection.

**Effective score.** Priority propagates along relations, iterated until stable:
- A blocker takes the best (lowest) score among itself and the issues it blocks, transitively — a `P0` blocked by a `P3` makes the `P3` next
- A parent with open sub-issues is not a work item — it is triaged through them; each sub-issue takes the better of its own and its parent's score

**4. Detect project subsystems**

Discover subsystems dynamically from the project structure:

1. Rust: read `Cargo.toml` at the workspace root and take the `[workspace] members` list — each member is a subsystem
2. TypeScript: take the workspace packages from `pnpm-workspace.yaml` or the `workspaces` field of `package.json` — each package is a subsystem
3. Luau/Lua: each Rojo project file (`*.project.json`) or Wally/pesde package is a subsystem; inside one Roblox place, the top-level `src/` folders (`server`, `client`, `shared`) are
4. Polyglot repos: combine the lists
5. If none yields members, treat the project as a single unit (skip subsystem grouping)

This provides the subsystem list for grouping without hardcoding project-specific names.

**5. Estimate change volume**

Group size is bounded by how much the PR changes the current codebase, not by an issue count: the diff must stay small enough to review in one sitting and verify with one test pass.

For each candidate, locate the code it changes in the working tree — Grep/Glob for the paths, symbols, error messages, and config keys named in the body and comments — and estimate:
- Files touched, including tests and docs that must follow
- Changed lines, production and test code
- Ripple: call sites of every signature, type, or config key the fix changes (Grep or LSP references)
- Subsystems touched

Map the estimate to a size class:

| Class | Points | Typical shape |
|-------|--------|---------------|
| S | 1 | up to ~50 lines in 1–2 files of one module |
| M | 2 | up to ~200 lines in a few files of one subsystem |
| L | 4 | up to ~500 lines, or an interface change rippling through its call sites |
| XL | — | beyond L, or 3+ subsystems — always a group of its own; propose splitting it into sub-issues |

Raise the class by one when the change rewrites most of an existing module: reviewing it means re-reading the whole module. An issue whose scope cannot be located in the code is at least M.

**Review budget per group: 4 points across at most two cohesive subsystems.** Estimate the group by the union of its changes — issues editing the same files share review effort, so overlapping issues cost less together than apart.

**6. Select the highest-priority group**

1. **Leader** — the issue with the lowest effective score that is not blocked by an external blocker or a cycle
2. **Prerequisite closure** — add every open in-repo blocker of the leader, transitively. If the closure exceeds the budget, cut it in topological order: this group takes the deepest prerequisites (those with no open blockers) up to the budget, and the rest of the chain goes to the following groups. A leader is never shipped without its prerequisites
3. **Fill** — while the budget allows, add in effective-score order: issues whose every open blocker is already in the group (do not split a chain that fits), open sibling sub-issues of the same parent, then issues sharing the group's files or subsystem, then the next issues by effective score that share no file with the group — each becomes its own track (step 5)
4. **Order** — the group is solved in topological order (blockers first), ties by effective score
5. **Tracks** — split the group into tracks that parallel developers implement in the same session. Issues go into one track when a relation links them (blocked-by or blocking) or their estimated file sets intersect; repeat until no two tracks share an issue link or a file. Each track keeps the group order. Files every track must touch — changelog, manifests, lockfiles — are not a reason to merge tracks: the team lead edits them after the tracks finish. A group whose issues all chain together is one track

Parallel tracks speed up implementation, not review: the budget covers the whole PR.

When the group closes the last open sub-issues of a parent, the parent closes with it — list it after the group's issues; solve-issue treats it as a tracking parent and does not implement it separately.

Print a summary table:

```
Group candidates (sorted by effective score):
  P0      #42 agent loop drops tool results   M   blocked by #57             [LEAD]
  P3->P0  #57 split ToolResult enum            S   blocks #42                 [PREREQUISITE]
  P2      #38 memory compaction edge case      M   blocked by #91 (assigned)  [WAITING]
  P2      #64 reject empty --config path       S                              [FILL]
  8       #55 enhance skill matching           M                              [next group]
  10      #61 research runtime alternatives    S                              [tail of queue]

Selected group (solve order): #57, #42, #64 — S + M + S = 4 points, subsystems: core, cli
Rationale: #57 blocks the P0 #42 and both edit core/src/tools.rs; #64 fits the remaining budget and shares no file with them
Tracks: [#57, #42] core/src/tools.rs, core/src/agent.rs | [#64] cli/src/args.rs
Missing relations to create: #42 blocked by #57 (stated in a comment only)
Remaining chain: none
```

When a mandatory prerequisite pushes the group over budget, say so and show where the chain was cut under `Remaining chain`.

**7. Confirm before proceeding**

Display the selected group, its solve order, the tracks, the estimate, and the missing relations, then ask with the `AskUserQuestion` tool — one call, the recommended option first:

```
AskUserQuestion(questions: [
  {header: "Group", question: "Solve #57, #42 | #64 in one PR?", multiSelect: false, options: [
    {label: "Solve group (Recommended)", description: "Tracks [#57, #42] and [#64], 4 points"},
    {label: "Leader chain only", description: "#57, #42 — drop the fill issues"},
    {label: "Next group", description: "Skip this group and show the next candidate"},
    {label: "Cancel", description: "Stop without solving anything"}]},
  {header: "Relations", question: "Create the missing relations on GitHub?", multiSelect: false, options: [
    {label: "Create all (Recommended)", description: "#42 blocked by #57"},
    {label: "Skip", description: "Leave them as text references"}]}
])
```

Drop `Leader chain only` when the group has no fill issues, and the `Relations` question when nothing is missing. The automatic `Other` answer takes different issue numbers: use those instead, keep the topological order, rebuild the tracks, and warn when the new set drops a prerequisite or blows the budget. `Next group` repeats steps 6–7 with the selected issues excluded. Where `AskUserQuestion` is unavailable (headless runs), ask the same questions in text and wait for the answer.

When the answer is `Create all`, create the missing relations as real GitHub relationships — the API takes the database `id`, not the issue number:

```bash
id=$(gh api repos/{owner}/{repo}/issues/<blocker> --jq .id)
gh api -X POST repos/{owner}/{repo}/issues/<blocked>/dependencies/blocked_by -F issue_id="$id"

id=$(gh api repos/{owner}/{repo}/issues/<child> --jq .id)
gh api -X POST repos/{owner}/{repo}/issues/<parent>/sub_issues -F sub_issue_id="$id"
```

**8. Launch /solve-issue**

Invoke the `/dev-agents:solve-issue` skill with the group's issue numbers: commas separate issues of one track in solve order, semicolons separate tracks, tracking parents go last in the track of their sub-issues. solve-issue passes every issue and track to team-develop for one PR.

Example: for tracks [#57, #42] and [#64], run `/dev-agents:solve-issue 57,42;64`

## Notes

- Issues with `wontfix` or `duplicate` labels are skipped entirely
- `research` issues are never skipped — they stay in the queue, just at the tail; once no higher-priority work remains, they get solved like any other issue
- If all issues have equal priority, prefer the one with the most recent activity
- GitHub relations are authoritative; text references are best-effort and become real relations once confirmed
- Volume estimates are approximate — when in doubt, take the smaller group, but never by dropping a prerequisite of an issue in it; an oversized chain is cut only in topological order
