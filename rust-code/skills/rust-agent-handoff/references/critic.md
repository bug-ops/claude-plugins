# rust-critic Output Schema

```yaml
output:
  verdict: significant  # approved | minor | significant | critical

  # Omit empty groups — do not include empty lists
  critical_gaps:
    - id: C1
      dimension: failure_mode_analysis
      gap: "Exact description of the flaw"
      evidence: "File:line or logical chain proving this gap"
      recommendation: "Concrete action to resolve"

  significant_gaps:
    - id: S1
      dimension: scalability_stress
      gap: "Exact description of the gap"
      evidence: "File:line or logical chain proving this gap"
      recommendation: "Concrete action to resolve"

  minor_gaps:
    - id: M1
      dimension: completeness_check
      gap: "Exact description of the gap"
      evidence: "File:line or logical chain"
      recommendation: "Concrete action to resolve"

  strengths:
    - "Specific solid aspect of the design"

  questions_for_authors:
    - "Open question that must be answered before proceeding"
```

## Dimension Values

| Value | Description |
|-------|-------------|
| `assumption_audit` | Implicit assumptions and their validity |
| `counterexample_hunt` | Concrete inputs/sequences that break the design |
| `scalability_stress` | Behavior at 10x/100x/1000x load or data volume |
| `failure_mode_analysis` | How this fails and the blast radius |
| `alternative_hypotheses` | Whether the problem framing is correct |
| `completeness_check` | What the design does not address but must |
| `dependency_risk` | Exposure to external crates and versioning |
| `second_order_effects` | Non-obvious consequences of the design |

## Verdict Values

| Verdict | Meaning | Next Action |
|---------|---------|-------------|
| `approved` | No blocking issues found | Proceed to next phase |
| `minor` | Only minor gaps found | Proceed with awareness |
| `significant` | Important gaps found | Author must address before completion |
| `critical` | Fundamental flaws found | Must redesign before implementation |

## Field Descriptions

| Field | Required | Description |
|-------|----------|-------------|
| `verdict` | yes | Overall critique verdict |
| `critical_gaps` | if any | Fundamental flaws blocking implementation |
| `significant_gaps` | if any | Important issues to address before completion |
| `minor_gaps` | if any | Low-priority improvements |
| `strengths` | encouraged | Solid aspects worth acknowledging |
| `questions_for_authors` | if any | Open questions requiring author response |

## Full Handoff Example

```yaml
id: 2025-01-09T14-30-45-critic
parent: 2025-01-09T14-00-00-architect
agent: critic
timestamp: "2025-01-09T14:30:45"
status: completed

context:
  task: "Critique architect's design for user management system"
  subject: "Type-driven user management: Email newtype + User builder pattern"

output:
  verdict: significant

  critical_gaps: []

  significant_gaps:
    - id: S1
      dimension: failure_mode_analysis
      gap: "Email::parse panics on inputs > 254 bytes due to unwrap in internal utf8 check"
      evidence: "src/email.rs:42 — str::from_utf8_unchecked(bytes) with no bounds check"
      recommendation: "Add length validation before utf8 check; return Err instead of panic"

    - id: S2
      dimension: scalability_stress
      gap: "User builder has O(n) field validation on every set(), creating O(n²) build cost"
      evidence: "UserBuilder::with_permissions() calls validate_all() internally"
      recommendation: "Defer validation to build(); validate once at the end"

  minor_gaps:
    - id: M1
      dimension: completeness_check
      gap: "Email type does not implement Display; debug output exposes raw string"
      evidence: "No Display impl in src/email.rs; only Debug via #[derive]"
      recommendation: "impl Display for Email to control output format"

  strengths:
    - "Newtype pattern correctly prevents mixing Email with arbitrary String values"
    - "Builder's type safety: NonExistent state prevents partial User construction"
    - "thiserror usage appropriate for library error types"

  questions_for_authors:
    - "What is the maximum expected email length? Is 254 bytes (RFC 5321) enforced?"
    - "Should Email be Clone? It currently derives Clone, leaking the raw string."
    - "What is the intended MSRV? Builder uses const generics (1.65+)."

next:
  agent: rust-architect
  task: "Address S1 (panic in Email::parse) and S2 (O(n²) builder)"
  priority: high
  acceptance_criteria:
    - "Email::parse returns Err on invalid input; never panics"
    - "Builder validation deferred to build()"
    - "Display impl for Email"
```
