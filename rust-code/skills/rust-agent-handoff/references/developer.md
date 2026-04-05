# rust-developer Output Schema

## Summary Field (frontmatter)

One sentence covering: what was implemented + key files/types produced.

Example: `"Implemented Email newtype + User builder; 2 new files in src/user/, all tests pass"`

## Output Sections

**Implementation Summary** (required): What was implemented and key decisions made during implementation.

**Files Changed** (required): For each file — path, action (`created` | `modified` | `deleted`), brief description of changes.

**Types Implemented** (required): For each type — name, location, whether unit tests exist.

**Dependencies Added** (if any): Name, version, reason for addition.

Follow workspace dependency rules: version in root `Cargo.toml`, features in crate `Cargo.toml` with `workspace = true`, alphabetical order.

**TODOs** (if any): Remaining work items not addressed.
