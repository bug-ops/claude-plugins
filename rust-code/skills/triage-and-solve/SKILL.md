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

**2. Sort by priority**

Assign a priority score to each issue in two tiers:

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
  Score 0 (P0) — #42 critical bug in agent loop  [LEAD]
  Score 2 (P2) — #38 fix memory compaction edge case   [GROUPED with #42]
  Score 8 — #55 enhance skill matching      [next group]
  Score 10 — #61 research runtime alternatives   [tail of queue]
  ...

Selected group: [#42, #38]
Rationale: both touch core agent/memory paths, no cross-dependencies, P0+P2
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
- `research` issues are never skipped — they stay in the queue, just at the tail; once no higher-priority work remains, they get solved like any other issue
- If all issues have equal priority, prefer the one with the most recent activity
- The dependency graph is best-effort based on issue text — false negatives are acceptable
- When in doubt, err toward a single-issue group rather than an oversized group
