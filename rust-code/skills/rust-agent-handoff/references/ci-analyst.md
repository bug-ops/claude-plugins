# rust-ci-analyst Output Schema

## Summary Field (frontmatter)

One sentence covering: features tested + anomalies found + issues filed + research findings.

Example: `"Tested 5 features (3 passed, 2 partial); filed 3 issues (#42 P1, #43 P2, #44 P3); 2 dependency alerts; 1 research finding"`

## Output Sections

**Cycle Summary** (required): What CI cycle phases were executed and key outcomes.

**Testing Results** (required): For each feature tested — status (Tested/Partial/Blocked), outcome, linked issues.

**Issues Filed** (required): For each new issue — number, title, priority label, category.

**Dependency Status** (if checked): Outdated deps, security advisories, update recommendations.

**Research Findings** (if performed): New techniques, competitive parity gaps, linked issues.

**Coverage Status Update** (required): Changes made to `.local/testing/coverage-status.md`.

## Priority Labels

| Label | Severity |
|-------|----------|
| P0 | Critical — broken core functionality, data loss, security |
| P1 | High — degraded UX, incorrect non-destructive behavior |
| P2 | Medium — suboptimal behavior, minor inconsistency |
| P3 | Low — cosmetic, unlikely edge case |
| P4 | Nice-to-have — research ideas, future enhancements |

## Hard Constraints

- NEVER includes code changes — only analysis, testing, and issue filing
- ALL findings result in GitHub issues, not inline fixes
- Testing knowledge base files (`.local/testing/`) are the only writable artifacts
