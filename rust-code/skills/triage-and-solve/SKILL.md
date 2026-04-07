---
name: triage-and-solve
description: "Triage open GitHub issues by priority, group compatible ones into a single PR, then solve via /solve-issue. Use when: 'triage issues', 'what should I work on', 'pick next issue', 'prioritize issues'."
argument-hint: "[--limit N] [--label filter]"
disable-model-invocation: true
---

# Triage and Solve

Triage open GitHub issues by priority, group compatible ones into a single PR, then solve the highest-priority group via /rust-agents:solve-issue.

## Steps

**1. Fetch unassigned open issues**

Run: `gh issue list --state open --limit 100 --search "no:assignee" --json number,title,body,labels,milestone,assignees`

Only unassigned issues are eligible for triage. The `no:assignee` search filter excludes assigned issues at the source; as a safety check, skip any result where `assignees` is non-empty.

**2. Sort by criticality**

Assign priority score to each issue based on labels:

| Label | Score |
|-------|-------|
| `critical` | 1 |
| `high` | 2 |
| `bug` | 3 |
| `fix` | 3 |
| `enhancement` | 4 |
| `research` | 5 |
| no priority label | 6 |

If an issue has multiple labels, use the lowest (highest priority) score.

**3. Detect project subsystems**

Discover subsystems dynamically from the project structure:

1. Read `Cargo.toml` at the workspace root
2. Extract `[workspace] members` list — each member is a subsystem
3. If no workspace members, treat the project as a single-crate project (skip subsystem grouping)

This provides the subsystem list for grouping without hardcoding project-specific names.

**4. Analyze dependencies and grouping potential**

For each issue, fetch its full details including comments:
`gh issue view <number> --json number,title,body,labels,comments`

Analyze both the issue body **and all comments** — comments often contain additional findings, reproduction details, root cause analysis, workarounds, or scope clarifications that are not in the original body. A comment may reveal that the issue is broader or narrower than the title suggests, or that it overlaps with another issue.

For each issue, read its body and comments to detect:
- Explicit "depends on #N" or "blocked by #N" references
- Same subsystem — match issue title/body/labels against the workspace members discovered in step 3
- Same file scope — infer from paths, module names, or component references in the issue text

Build a dependency graph:
- Mark issues that are blocked as ineligible to lead a group
- Identify clusters of issues in the same subsystem with no blocking dependencies between them

**5. Select the highest-priority group**

A group is a set of issues that:
- Share the same subsystem or are logically cohesive (same PR makes sense)
- Have no blocking dependencies on issues outside the group
- The group leader has the lowest priority score among available groups

Rules for group size:
- Maximum 3 issues per group to keep PRs focused
- Single-issue groups are valid
- Prefer smaller, focused groups over large omnibus ones

Print a summary table:

```
Group candidates (sorted by priority):
  Score 1 — #42 critical bug in agent loop  [LEAD]
  Score 3 — #38 fix memory compaction edge case   [GROUPED with #42]
  Score 4 — #55 enhance skill matching      [next group]
  ...

Selected group: [#42, #38]
Rationale: both touch core agent/memory paths, no cross-dependencies, score 1+3
```

**6. Confirm before proceeding**

Display the selected group and ask the user to confirm:
```
Proceed with /solve-issue for issues: #42, #38?
[y to continue, or enter different issue numbers]
```

Wait for confirmation. If the user provides different issue numbers, use those instead.

**7. Launch /solve-issue**

Invoke the `/rust-agents:solve-issue` skill with the comma-separated list of issue numbers as the argument.

Example: if selected group is [#42, #38], run `/rust-agents:solve-issue 42,38`

## Notes

- Issues with `wontfix` or `duplicate` labels are skipped entirely
- If all issues have equal priority, prefer the one with the most recent activity
- The dependency graph is best-effort based on issue text — false negatives are acceptable
- When in doubt, err toward a single-issue group rather than an oversized group
