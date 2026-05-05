# Knowledge Base File Templates

Reference for the knowledge base files created by `scaffold.sh`. These templates define the initial structure — files evolve over time as CI cycles run.

## journal/ci-NNN.md

One file per CI cycle. Created by the CI orchestrator in Step 0; agents append to it during the cycle; Summary sections are completed in Step 3.

File template:

```markdown
---
cycle: NNN
date: YYYY-MM-DD
focus: testing|research|dependencies|parity|full
team: ci-cycle-YYYYMMDD
---

## Continuous Improvement Cycle NNN — YYYY-MM-DD

### Playbooks

- [Testing playbooks](.local/testing/playbooks/)
- [Competitive parity](.local/testing/playbooks/competitive-parity.md)
- [Regression scenarios](.local/testing/regressions.md)

### Findings

| # | Type | Title | Priority | Issue | Spec |
|---|---|---|---|---|---|

### Live Testing

- Features tested:
- Issues filed:
- Coverage changes:

### Research & Monitoring

- Dependency advisories:
- Research issues filed:
- Parity gaps identified:

### Next Cycle Priorities

-
```

Naming: `ci-001.md`, `ci-002.md`, … — three-digit zero-padded counter, incremented by the orchestrator at cycle start.

## coverage-status.md

Permanent component status table. One section per crate/subsystem, one row per feature.

Column definitions:

| Column | Content |
|--------|---------|
| Component | Feature name or PR reference |
| Status | Tested / Partial / Untested / Blocked |
| Last session | CI-NNN (YYYY-MM-DD) |
| Version | vX.Y.Z |
| Issues | #NNN or — |
| Result | One-line outcome or blocking reason |

Maintenance rules:
1. Add row for every new feature before merge (status = Untested)
2. Reset to Untested when feature code changes significantly
3. Update immediately after testing — don't batch
4. Never remove rows — removed features get status "Removed"
5. One row per logical feature, not per PR

## process-notes.md

Two main sections:

- **Effective Techniques** — approaches that work well for this project
- **Failed / Low-Value Approaches** — what didn't work and why (prevents repeating)

Append a brief retrospective after every CI session.

## regressions.md

Catalog of reproduction scenarios for previously found bugs. Each entry:

```markdown
### [REG-NNN] Title (original issue #NNN)
**Prompt**: `exact prompt or command`
**Steps**: Additional setup/context if needed
**Expected**: Correct behavior description
**Last verified**: YYYY-MM-DD, vX.Y.Z
**Status**: Pass / Fail / Skipped
```

Re-run all scenarios after every significant change.

## playbooks/competitive-parity.md

Two tables:

1. **Reference Projects** — name, stack, what to watch, last checked version/date
2. **Known Gaps** — feature, which project(s) have it, research backing, status, linked issue, priority

Update after every parity scan.
