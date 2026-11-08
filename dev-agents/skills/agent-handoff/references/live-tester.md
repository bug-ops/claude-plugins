# live-tester Output Schema

Summary: features tested + anomalies + issues filed. Example: `"Tested 5 features (3 passed, 2 partial); filed 2 bug issues (#42 P1, #43 P2)"`

## Output Sections

**Testing Results** (required): per feature — status (Tested/Partial/Blocked), outcome, linked issues.

**Issues Filed** (required in standalone and `continuous-improvement` runs): number — title — priority — category. In `team-develop`/`team-debug` runs file nothing: bugs outside the task go under Follow-ups.

**Coverage Status** (required): what changed in `.local/testing/coverage-status.md`.

Non-bug discoveries for orchestrator routing (e.g. to researcher) go under the protocol's Follow-ups section.
