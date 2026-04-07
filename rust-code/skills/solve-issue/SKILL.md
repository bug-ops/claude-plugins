---
name: solve-issue
description: "Solve a GitHub issue end-to-end: fetch issue, create branch in worktree, launch rust-team agents. Use when: 'solve issue', 'fix issue', 'implement issue', 'work on #N'."
argument-hint: "<issue-number>"
---

# Solve GitHub Issue

Solve a GitHub issue end-to-end using the rust-team agent workflow.

**Issue**: $ARGUMENTS

## Steps

**1. Fetch issue data and assign**

Run: `gh issue view $ARGUMENTS --json number,title,body,labels,milestone`

Then assign the issue to yourself:

Run: `gh issue edit $ARGUMENTS --add-assignee @me`

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

**Note**: If the project has a `.claude/rules/branching.md` file, read it and follow those conventions instead of the defaults above. If `.claude/rules/commits-and-issues.md` exists, read it for commit message format and issue filing rules.

**3. Sync main branch**

Run: `git fetch origin main`

**4. Create worktree**

Use the `EnterWorktree` tool with:
- `branch`: the branch name derived above
- `base`: `origin/main`

This triggers the WorktreeCreate hook and switches the session cwd automatically. **Never** use `git worktree add` directly.

**5. Launch rust-teamlead**

Spawn the `rust-agents:rust-teamlead` agent with the full issue context:

```
Agent(
  description: "Teamlead for issue #$ARGUMENTS",
  subagent_type: "rust-agents:rust-teamlead",
  prompt: "Implement GitHub issue #$ARGUMENTS.\n\nIssue title: {title}\nIssue body:\n{body}\n\nWorking branch: {branch-name}\n\nFollow project rules in `.claude/CLAUDE.md` and `.claude/rules/` if they exist."
)
```

Wait for the teamlead agent to complete and report back.

## Notes

- Always use `EnterWorktree` (never `git worktree add`) — the hook switches session cwd
- If project-specific branching rules exist in `.claude/rules/`, follow them
- After rust-team completes, follow any PR checklist defined in the project rules
