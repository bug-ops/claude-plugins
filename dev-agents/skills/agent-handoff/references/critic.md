# critic Output Schema

Summary: verdict + gap counts + top finding. Example: `"Significant: 2 gaps (Email::parse panics on >254 bytes; O(n^2) builder validation)"`

## Output Sections

**Verdict** (required, also set as the frontmatter `verdict:` the lead routes on): `approved` (no blocking issues) | `minor` (proceed with awareness) | `significant` (author must address before completion) | `critical` (redesign before implementation)

**Gaps** (if any): grouped by severity — Critical (C1..), Significant (S1..), Minor (M1..). One entry per gap: id — dimension — gap — evidence (file:line or logical chain) — recommendation.

Dimensions: `assumption_audit` `counterexample_hunt` `scalability_stress` `failure_mode_analysis` `alternative_hypotheses` `completeness_check` `dependency_risk` `second_order_effects` `scope_conformance`

**Scope Ledger** (required when the subject is a plan, spec, or implementation):
- Baseline: the requirement sources used (request, issue numbers, spec path, plan handoff, approved deviations)
- Volume (implementation only): diff size vs. the plan or triage estimate, one line
- One entry per untraced or deviating item: id (L1..) — item — location (file:line or plan section) — `untraced` | `contradicts <source>` | `approved by architect|user (<reference>)` — required action: `remove` | `obtain architect approval` | `obtain user approval`
- `No untraced items` when the ledger is empty

Each untraced or contradicting ledger entry is also listed under Gaps with dimension `scope_conformance`.

**Follow-up Assessment** (when the handoffs you were given contain Follow-ups entries): one line per entry — source (handoff id + `F` id) — `confirmed` | `adjust: <priority or kind>` | `rejected: <reason>` — the evidence or reference behind the verdict.

**Questions for Authors** (if any): open questions that must be answered before proceeding.

**Deferrals**: required work you advise postponing goes under the protocol's Follow-ups section (kind `todo`), each entry naming the deferred work and its code location (the nearest relevant module when none is known). The critic writes no marker; the developer inserts it as `TODO(review): ...`.
