---
name: solve-issue
description: "Solve a GitHub issue end-to-end: fetch the issue, create a branch in a worktree, launch the team-develop agents."
when_to_use: "'solve issue', 'fix issue', 'implement issue', 'work on #N'."
argument-hint: "<issue-number>"
arguments: issue
allowed-tools: Bash(gh issue view *), Bash(gh issue edit *), Bash(git fetch *), Bash(git branch *), Bash(test *), Bash(echo *)
---

# Solve GitHub Issue

Solve a GitHub issue end-to-end using the team-develop agent workflow.

**Issue**: $issue

## Preflight (collected automatically when this skill loads)

- Current branch: !`git branch --show-current 2>/dev/null || echo not-a-git-repo`
- Branching rules: !`test -f .claude/rules/branching.md && echo present || echo absent`
- Commit rules: !`test -f .claude/rules/commits-and-issues.md && echo present || echo absent`

## Steps

**1. Fetch issue data and assign**

Run: `gh issue view $issue --json number,title,body,labels,milestone`

Then assign the issue to yourself:

Run: `gh issue edit $issue --add-assignee @me`

Parse:
- `number` → issue number
- `title` → used to derive branch slug (lowercase, spaces→hyphens, strip special chars)
- `labels` → detect `bug`/`fix` label to choose branch prefix (`fix/` vs `feat/`)
- `milestone` → extract milestone number N for `feat/mN/` branch names (if present)

**2. Determine branch name**

Branch naming convention:
- Bug/fix labels → `fix/<short-slug>` (max 30 chars)
- Feature / no label with milestone → `feat/m{N}/<feature-slug>` where N comes from the milestone number
- Feature / no label without milestone → `feat/issue-{number}/<feature-slug>`

Slug derivation: take the issue `title`, lowercase it, replace non-alphanumeric runs with `-`, trim leading/trailing dashes, truncate to 30 chars.

**Note**: If the preflight shows `.claude/rules/branching.md` as present, read it and follow those conventions instead of the defaults above. If `.claude/rules/commits-and-issues.md` is present, read it for commit message format and issue filing rules.

**3. Sync main branch**

Run: `git fetch origin main`

**4. Create worktree**

Use the `EnterWorktree` tool with:
- `branch`: the branch name derived above
- `base`: `origin/main`

This triggers the WorktreeCreate hook and switches the session cwd automatically. **Never** use `git worktree add` directly.

**5. Run team-develop workflow**

Invoke the team-develop skill to orchestrate development directly (you are the team lead):

```
Skill(skill: "rust-agents:team-develop", args: "Implement GitHub issue #{number}: {title}\n\nIssue body:\n{body}\n\nWorking branch: {branch-name}\n\nFollow project rules in `.claude/CLAUDE.md` and `.claude/rules/` if they exist.")
```

## Notes

- Always use `EnterWorktree` (never `git worktree add`) — the hook switches session cwd
- If project-specific branching rules exist in `.claude/rules/`, follow them
- After team-develop completes, follow any PR checklist defined in the project rules
