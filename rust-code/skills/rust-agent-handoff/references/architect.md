# rust-architect Output Schema

```yaml
output:
  decision_type: new_project  # new_project | refactoring | review
  summary: "Brief description of architectural decisions"
  structure: workspace  # single_crate | workspace
  
  crates:
    - name: core
      purpose: "Domain types and business logic"
    - name: cli
      purpose: "Command-line interface"
  
  key_types:
    - name: Email
      pattern: newtype  # newtype | typestate | sealed | gat
      purpose: "Validated email address"
    - name: User
      pattern: builder
      purpose: "User entity with validated fields"
  
  files_created:
    - Cargo.toml
    - crates/core/src/lib.rs
  
  adrs:
    - ".local/adr/001-workspace-structure.md"
```

## Field Descriptions

| Field | Required | Description |
|-------|----------|-------------|
| `decision_type` | yes | Type of architectural work |
| `summary` | yes | Brief description of decisions made |
| `structure` | yes | Project structure choice |
| `crates` | if workspace | List of crates with purposes |
| `key_types` | yes | Important types designed |
| `files_created` | yes | Files created during architecture |
| `adrs` | no | Architecture Decision Records created |

## Type Patterns

| Pattern | Use Case |
|---------|----------|
| `newtype` | Wrap primitive with validation (Email, UserId) |
| `typestate` | State machine with compile-time guarantees |
| `sealed` | Trait that can't be implemented outside crate |
| `gat` | Generic Associated Types for streaming |
| `builder` | Complex struct construction |

## Multiple Parent Sources Example

When designing based on multiple architectural decisions:

```yaml
id: 2025-01-09T14-30-45-architect
parent:
  - 2025-01-09T13-00-00-architect  # Previous architecture phase
  - 2025-01-09T13-30-00-review     # Architecture review feedback
agent: architect
```

Use this when:
- Iterating on architecture after review feedback
- Merging multiple architectural proposals or ADRs
- Evolving design based on multiple constraint sources
- Incorporating learnings from previous architecture phases
