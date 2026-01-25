# rust-developer Output Schema

```yaml
output:
  summary: "What was implemented"
  
  files_changed:
    - path: src/user.rs
      action: created  # created | modified | deleted
      changes: "Implemented User struct with builder"
    - path: src/email.rs
      action: created
      changes: "Email newtype with validation"
  
  types_implemented:
    - name: Email
      location: src/email.rs
      tests: true
    - name: User
      location: src/user.rs
      tests: true
  
  dependencies_added:
    - name: thiserror
      version: "2.0"
      features: []
  
  todos:
    - "Add serialization support"
```

## Field Descriptions

| Field | Required | Description |
|-------|----------|-------------|
| `summary` | yes | Brief description of implementation work |
| `files_changed` | yes | List of files with actions taken |
| `types_implemented` | yes | Types that were implemented |
| `dependencies_added` | no | New dependencies added to Cargo.toml |
| `todos` | no | Remaining work items |

## File Actions

| Action | Description |
|--------|-------------|
| `created` | New file created |
| `modified` | Existing file changed |
| `deleted` | File removed |

## Dependency Format

When adding dependencies, follow workspace rules:
- Version in workspace root `Cargo.toml`
- Features in crate `Cargo.toml` with `workspace = true`
- Alphabetical order in all sections

## Multiple Parent Sources Example

When implementing based on multiple design documents or review feedback:

```yaml
id: 2025-01-09T15-30-00-developer
parent:
  - 2025-01-09T14-30-45-architect  # Original design
  - 2025-01-09T15-00-00-review     # Code review feedback
agent: developer
```

Use this when:
- Implementing after receiving review feedback (architect + review)
- Merging multiple architectural decisions into single implementation
- Addressing feedback from multiple reviewers in parallel
- Fixing bugs identified by debugger while maintaining architecture constraints
