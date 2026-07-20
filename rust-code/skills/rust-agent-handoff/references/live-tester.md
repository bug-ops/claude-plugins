# rust-live-tester Output Schema

Summary: features tested + anomalies + issues filed. Example: `"Tested 5 features (3 passed, 2 partial); filed 2 bug issues (#42 P1, #43 P2)"`

## Output Sections

**Testing Results** (required): per feature — status (Tested/Partial/Blocked), outcome, linked issues.

**Issues Filed** (required): number — title — priority — category.

**Coverage Status** (required): what changed in `.local/testing/coverage-status.md`.

**Out-of-Scope Findings** (if any): non-bug discoveries for orchestrator routing (e.g. to researcher).
