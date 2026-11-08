# architect Output Schema

Summary: decision type + key types + structure. Example: `"Designed workspace with core/cli crates; Email newtype + User builder; JWT auth architecture"`

## Output Sections

**Decision Type** (required): `new_project` | `refactoring` | `review`

**Architecture Summary** (required): decisions made + rationale, compressed.

**Structure** (required): `single_crate` or `workspace`; if workspace — crate names with one-line purpose.

**Key Types** (required): name — pattern — purpose, one line each.

**Files Created** (required): paths only.

**Scope** (required): requirement sources (request, issues, spec), and one line per planned item that goes beyond them, marked `needs user approval` or `approved by user (<reference>)`. `Matches request` when there are none.

**Spec / ADRs** (if any): paths.
