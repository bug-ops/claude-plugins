# rust-architect Output Schema

## Summary Field (frontmatter)

One sentence covering: decision type + key types designed + structure choice.

Example: `"Designed workspace with core/cli crates; Email newtype + User builder; JWT auth architecture"`

## Output Sections

**Decision Type** (required): `new_project` | `refactoring` | `review`

**Architecture Summary** (required): High-level description of the decisions made and rationale.

**Structure** (required): `single_crate` or `workspace`. If workspace — list crates with name and purpose.

**Key Types** (required): For each important type — name, pattern, purpose.

**Files Created** (required): Bullet list of files created.

**Spec** (if applicable): Path to spec file in `.local/specs/` or `specs/`.

**ADRs** (if any): Links to Architecture Decision Records created.

## Type Patterns

| Pattern | Use Case |
|---------|----------|
| `newtype` | Wrap primitive with validation (Email, UserId) |
| `typestate` | State machine with compile-time guarantees |
| `sealed` | Trait that can't be implemented outside crate |
| `gat` | Generic Associated Types for streaming |
| `builder` | Complex struct construction |
