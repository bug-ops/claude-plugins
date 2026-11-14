# architect Output Schema

Summary: decision type + key types + structure. Example: `"Designed workspace with core/cli crates; Email newtype + User builder; JWT auth architecture"`

## Output Sections

**Decision Type** (required): `new_project` | `refactoring` | `review`. With `status: no_change_needed` the other required sections shrink to `## Evidence`.

**Architecture Summary** (required): decisions made + rationale, compressed.

**Structure** (required): `single_crate` or `workspace`; if workspace — crate names with one-line purpose.

**Key Types** (required): name — pattern — purpose, one line each.

**Contracts** (required when the plan adds public functions or endpoints): per item — preconditions, postconditions, undefined behaviour. The tester derives acceptance and property tests from it.

**Size Estimate** (required): size class and points per the table in [triage-and-solve](../../triage-and-solve/SKILL.md) (step 5, "Map the estimate to a size class"), with the files and subsystems counted. Do not copy the table.

**Files Created** (required): paths only.

**Scope** (required): requirement sources (request, issues, spec), and one line per planned item that goes beyond them, marked `needs user approval` or `approved by user (<reference>)`. `Matches request` when there are none.

**Spec / ADRs** (if any): paths.
