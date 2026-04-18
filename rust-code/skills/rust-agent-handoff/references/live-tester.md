# rust-live-tester Output Schema

## Summary Field (frontmatter)

One sentence covering: features tested + anomalies found + issues filed.

Example: `"Tested 5 features (3 passed, 2 partial); filed 2 bug issues (#42 P1, #43 P2); coverage-status.md updated"`

## Output Sections

**Testing Results** (required): For each feature tested — status (Tested/Partial/Blocked), outcome, linked issues.

**Issues Filed** (required): For each new issue — number, title, priority label, category.

**Coverage Status Update** (required): Changes made to `.local/testing/coverage-status.md`.

**Out-of-Scope Findings** (if any): Items discovered during testing that are not bugs — e.g., dependency concerns, research topics — passed to the orchestrator for routing to `rust-researcher`.

## Hard Constraints

- NEVER includes source code changes — only live execution, analysis, and issue filing
- ALL bug findings result in GitHub issues, not inline fixes
- Only writes to `.local/testing/`
