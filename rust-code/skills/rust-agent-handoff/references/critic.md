# rust-critic Output Schema

Summary: verdict + gap counts + top finding. Example: `"Significant: 2 gaps (Email::parse panics on >254 bytes; O(n^2) builder validation)"`

## Output Sections

**Verdict** (required): `approved` (no blocking issues) | `minor` (proceed with awareness) | `significant` (author must address before completion) | `critical` (redesign before implementation)

**Gaps** (if any): grouped by severity — Critical (C1..), Significant (S1..), Minor (M1..). One entry per gap: id — dimension — gap — evidence (file:line or logical chain) — recommendation.

Dimensions: `assumption_audit` `counterexample_hunt` `scalability_stress` `failure_mode_analysis` `alternative_hypotheses` `completeness_check` `dependency_risk` `second_order_effects`

**Questions for Authors** (if any): open questions that must be answered before proceeding.

**Deferred Items** (if any): id (D1..) — feature — deferral reason — exact TODO marker to place: `// TODO(critic): ...` in Rust, `<!-- TODO(critic): ... -->` in docs; if no location known, nearest relevant module.
