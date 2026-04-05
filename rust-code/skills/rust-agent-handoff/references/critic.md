# rust-critic Output Schema

## Summary Field (frontmatter)

One sentence covering: verdict + critical/significant gap count + most important finding.

Example: `"Significant: 2 gaps (Email::parse panics on >254 bytes; O(n²) builder validation)"`

## Output Sections

**Verdict** (required): `approved` | `minor` | `significant` | `critical`

**Critical Gaps** (if any): For each — id (C1, C2...), dimension, exact gap description, evidence (file:line or logical chain), concrete recommendation.

**Significant Gaps** (if any): For each — id (S1, S2...), dimension, gap, evidence, recommendation.

**Minor Gaps** (if any): For each — id (M1, M2...), dimension, gap, evidence, recommendation.

**Strengths** (encouraged): Specific solid aspects worth acknowledging.

**Questions for Authors** (if any): Open questions that must be answered before proceeding.

Omit empty sections entirely — do not include section headings with no content.

## Dimension Values

| Value | Description |
|-------|-------------|
| `assumption_audit` | Implicit assumptions and their validity |
| `counterexample_hunt` | Concrete inputs/sequences that break the design |
| `scalability_stress` | Behavior at 10x/100x/1000x load |
| `failure_mode_analysis` | How this fails and the blast radius |
| `alternative_hypotheses` | Whether the problem framing is correct |
| `completeness_check` | What the design does not address but must |
| `dependency_risk` | Exposure to external crates and versioning |
| `second_order_effects` | Non-obvious consequences of the design |

## Verdict Values

| Verdict | Meaning | Next action |
|---------|---------|-------------|
| `approved` | No blocking issues | Proceed |
| `minor` | Only minor gaps | Proceed with awareness |
| `significant` | Important gaps | Author must address before completion |
| `critical` | Fundamental flaws | Must redesign before implementation |
