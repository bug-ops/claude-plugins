# Rust Library README Template

> [!IMPORTANT]
> Rust libraries MUST document MSRV and feature flags. These are ecosystem requirements, not optional.

## Structure

```markdown
# crate-name

[![Crates.io](https://img.shields.io/crates/v/{crate})](https://crates.io/crates/{crate})
[![docs.rs](https://img.shields.io/docsrs/{crate})](https://docs.rs/{crate})
[![CI](https://img.shields.io/github/actions/workflow/status/{owner}/{repo}/ci.yml?branch=main)](https://github.com/{owner}/{repo}/actions)
[![MSRV](https://img.shields.io/crates/msrv/{crate})](https://github.com/{owner}/{repo})
[![License](https://img.shields.io/crates/l/{crate})](LICENSE)

One-line description from Cargo.toml.

## Installation

Add to your `Cargo.toml`:

\`\`\`toml
[dependencies]
{crate} = "{version}"
\`\`\`

Or with cargo-add:

\`\`\`bash
cargo add {crate}
\`\`\`

> [!IMPORTANT]
> Requires Rust {msrv} or later.

## Usage

\`\`\`rust
use {crate}::prelude::*;

fn main() {
    // Basic example
}
\`\`\`

## Features

Enable optional features in `Cargo.toml`:

\`\`\`toml
[dependencies]
{crate} = { version = "{version}", features = ["feature1", "feature2"] }
\`\`\`

> [!TIP]
> Start with default features. Add extras only when needed to keep compile times fast.

| Feature | Description | Default |
|---------|-------------|---------|
| `feature1` | Description | No |
| `feature2` | Description | Yes |

## Examples

Run examples from the repository:

\`\`\`bash
cargo run --example example_name
\`\`\`

## MSRV Policy

> [!NOTE]
> Minimum Supported Rust Version: **{msrv}**. MSRV increases are minor version bumps.

## License

Licensed under {license} - see [LICENSE](LICENSE) for details.
```

## Rust-Specific Requirements

### MSRV Documentation

Always document MSRV. Extract from `Cargo.toml`:

```toml
rust-version = "1.70"
```

If not specified, recommend adding it.

### Feature Flags

Document all features from `[features]` section. Use table format:

```markdown
| Feature | Description | Default |
|---------|-------------|---------|
| `serde` | Serialization support | No |
| `async` | Async runtime support | No |
| `full` | All features enabled | No |
```

For crates with many features, use `document-features`:

> [!TIP]
> `document-features` auto-generates feature docs from Cargo.toml comments. Keeps README in sync automatically.

```rust
//! # Features
//!
#![doc = document_features::document_features!()]
```

### Examples Directory

If `examples/` exists, list runnable examples:

```markdown
## Examples

- `basic.rs` - Simple usage
- `advanced.rs` - Complex patterns
- `async_example.rs` - Async usage

Run with:
\`\`\`bash
cargo run --example basic
\`\`\`
```

### docs.rs Integration

Link to docs.rs for API documentation:

```markdown
See [API documentation](https://docs.rs/{crate}) for complete reference.
```

### Workspace Crates

For workspace members, document relationship:

```markdown
This crate is part of the [{workspace}](https://github.com/{owner}/{repo}) workspace.

Related crates:
- `{crate}-core` - Core types
- `{crate}-derive` - Derive macros
```

## Badge Priority Order

1. crates.io version (required)
2. docs.rs (required)
3. CI status (recommended)
4. MSRV (recommended)
5. License (recommended)
6. Downloads (optional)
7. Code coverage (optional)

Maximum 6 badges in the hero section.

## Installation Variations

### With Features

```markdown
\`\`\`toml
# With default features
{crate} = "{version}"

# With specific features
{crate} = { version = "{version}", features = ["serde", "async"] }

# Without default features
{crate} = { version = "{version}", default-features = false }
\`\`\`
```

### Git Dependency

Only if crate is not published:

```markdown
\`\`\`toml
{crate} = { git = "https://github.com/{owner}/{repo}" }
\`\`\`
```

## Code Examples

### Minimal Example

Show the simplest possible usage:

```rust
use {crate}::Thing;

let thing = Thing::new();
println!("{:?}", thing);
```

### Error Handling

Show proper error handling:

```rust
use {crate}::{Thing, Error};

fn main() -> Result<(), Error> {
    let thing = Thing::try_new()?;
    Ok(())
}
```

### Async Example

If async is supported:

```rust
use {crate}::AsyncThing;

#[tokio::main]
async fn main() {
    let thing = AsyncThing::new().await;
}
```
