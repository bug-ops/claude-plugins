---
name: solve-issue
description: "Solve one GitHub issue or a group of issues in a single PR end-to-end: fetch the issues, create a branch in a worktree, launch the team-develop agents."
when_to_use: "'solve issue', 'fix issue', 'implement issue', 'work on #N', 'solve #N and #M together'."
argument-hint: "<issue-number>[,<issue-number>...][;<issue-number>...]"
arguments: issues
allowed-tools: Bash(gh issue view *), Bash(gh issue edit *), Bash(git fetch *), Bash(git branch *), Bash(test *), Bash(echo *)
---

# Solve GitHub Issue

Solve one GitHub issue, or a group of issues in a single PR, end-to-end using the team-develop agent workflow.

**Issues**: $issues

The argument is one issue number or a list in the format `/dev-agents:triage-and-solve` produces: commas separate issues of one track in solve order (blockers first), semicolons separate tracks that parallel developers implement independently. A list without semicolons is a single track. Keep the order and the tracks through every step.

## Preflight (collected automatically when this skill loads)

- Current branch: !`git branch --show-current 2>/dev/null || echo not-a-git-repo`
- Branching rules: !`test -f .claude/rules/branching.md && echo present || echo absent`
- Commit rules: !`test -f .claude/rules/commits-and-issues.md && echo present || echo absent`

## Steps

**1. Fetch issue data and assign**

Split the argument into tracks on semicolons and each track into issues on commas, trim spaces and a leading `#`, and drop duplicates while keeping the first occurrence. For each number, in order:

Run: `gh issue view <number> --json number,title,body,labels,milestone,state`

A closed issue is dropped with a warning, and a track left empty is dropped; if no open issue is left, stop and report. Assign every remaining issue to yourself:

Run: `gh issue edit <number> --add-assignee @me`

Parse per issue:
- `number`, `title`, `body` → passed to team-develop
- `labels` → detect `bug`/`fix` label to choose branch prefix (`fix/` vs `feat/`)
- `milestone` → extract milestone number N for `feat/mN/` branch names (if present)

For a group, detect **tracking parents**: an issue whose open sub-issues are all in the list (`gh api repos/{owner}/{repo}/issues/<number>/sub_issues --jq '[.[] | select(.state == "open") | .number]'`). A tracking parent is closed by the PR but not implemented on its own.

**2. Determine branch name**

Branch naming convention:
- Bug/fix labels → `fix/<short-slug>` (max 30 chars)
- Feature / no label with milestone → `feat/m{N}/<feature-slug>` where N comes from the milestone number
- Feature / no label without milestone → `feat/issue-{number}/<feature-slug>`

Slug derivation: take the issue `title`, lowercase it, replace non-alphanumeric runs with `-`, trim leading/trailing dashes, truncate to 30 chars.

For a group, derive the name from the first issue of the first track that is not a tracking parent; use `fix/` only when every issue carries a `bug`/`fix` label, and `feat/m{N}/` only when every issue shares milestone N.

**Note**: If the preflight shows `.claude/rules/branching.md` as present, read it and follow those conventions instead of the defaults above. If `.claude/rules/commits-and-issues.md` is present, read it for commit message format and issue filing rules.

**3. Sync main branch**

Run: `git fetch origin main`

**4. Create worktree**

Use the `EnterWorktree` tool with:
- `branch`: the branch name derived above
- `base`: `origin/main`

This triggers the WorktreeCreate hook and switches the session cwd automatically. **Never** use `git worktree add` directly.

**5. Run team-develop workflow**

Invoke the team-develop skill to orchestrate development directly (you are the team lead).

Single issue:

```
Skill(skill: "dev-agents:team-develop", args: "Implement GitHub issue #{number}: {title}\n\nIssue body:\n{body}\n\nWorking branch: {branch-name}\n\nFollow project rules in `.claude/CLAUDE.md` and `.claude/rules/` if they exist.")
```

Group — one section per track, one subsection per implemented issue, in solve order:

```
Skill(skill: "dev-agents:team-develop", args: "Implement GitHub issues in one branch and one PR. Tracks are independent: implement them with parallel developers, one developer per track, each owning only its track's files. Within a track, issues go in the listed order and each may build on the ones before it.\n\n## Track 1: #{n1}, #{n2}\n\n### Issue #{n1}: {title1}\n\n{body1}\n\n### Issue #{n2}: {title2}\n\n{body2}\n\n## Track 2: #{n3}\n\n### Issue #{n3}: {title3}\n\n{body3}\n\nTracking parents closed by this PR, not implemented separately: #{p}\n\nThe PR body closes every issue above and every tracking parent, one closing keyword per line:\nCloses #{n1}\nCloses #{n2}\nCloses #{n3}\nCloses #{p}\n\nWorking branch: {branch-name}\n\nFollow project rules in `.claude/CLAUDE.md` and `.claude/rules/` if they exist.")
```

Omit the tracking-parents line when there are none. With a single track, drop the track headings and the parallel-developers sentence.

## Notes

- Always use `EnterWorktree` (never `git worktree add`) — the hook switches session cwd
- If project-specific branching rules exist in `.claude/rules/`, follow them
- After team-develop completes, follow any PR checklist defined in the project rules
- `Closes #1, #2` on one line auto-closes only the first issue — each closing keyword goes on its own line
