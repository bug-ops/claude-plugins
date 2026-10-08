# Rust Toolchain Profile

## Project Facts

- **Manifest**: `Cargo.toml`. A `[workspace]` table means a workspace; members live under `members = [...]`.
- **Edition**: read `edition` from the manifest (2024 for new code).
- **Version policy (MSRV)**: `rust-version = "X.Y"` in `Cargo.toml` (or `[workspace.package]`). Never use an API, syntax, or lint newer than the declared MSRV. Raising MSRV is a breaking change.
- **Dependencies**: in a workspace, versions are declared once in the root `[workspace.dependencies]` and crates use `dep = { workspace = true }`; keep entries alphabetical. Check the latest version (context7 or crates.io) before adding one.
- **Dependency APIs**: never call one from memory. Check the version pinned in `Cargo.toml`/`Cargo.lock`, then verify the signature with `cargo doc --open`, docs.rs for that exact version, or the compiler. When `cargo check` disagrees with your memory, the compiler is right.

## Commands

| Purpose | Command |
|---------|---------|
| Fast compile check | `cargo check --workspace --all-targets` |
| Format check / fix | `cargo +nightly fmt --check` / `cargo +nightly fmt` |
| Lint | `cargo clippy --all-targets --all-features --workspace -- -D warnings` |
| Tests | `cargo nextest run --workspace --all-features --lib --bins` |
| Doc tests | `cargo test --doc --workspace --all-features` |
| Doc gate | `RUSTFLAGS="-D warnings" RUSTDOCFLAGS="--deny rustdoc::broken_intra_doc_links" cargo doc --no-deps --workspace --all-features` |
| Dependency audit | `cargo deny check` (fallback: `cargo audit`) |
| Unused dependencies | `cargo machete` |
| Public API breakage | `cargo semver-checks` |
| Feature combinations | `cargo hack check --feature-powerset --no-dev-deps` |
| Macro expansion | `cargo expand module::path` |

**Full check suite** (run before handing off code; must match CI): format check, lint, tests, doc tests, doc gate. When `.claude/rules/branching.md` or the CI workflow defines its own feature set or env vars, use those exactly.

## Documentation Conventions

- Every `pub` item gets a `///` doc comment that explains *what* and *why*.
- Non-trivial public APIs include an `# Examples` section with a runnable doctest.
- Module docs (`//!`) describe the module's responsibility and place in the architecture.
- Trait docs state the contract: what implementors guarantee, what callers may assume.
- Feature-gated items: `#[cfg_attr(docsrs, doc(cfg(feature = "...")))]`.

## Markers and Comment Syntax

- Line comments: `// TODO(#123): ...`, `// TODO(review): ...`, `// ASSUMPTION: ...`.
- `unsafe` blocks carry `// SAFETY: <invariant>` on the line above.
- An `unwrap()`/`expect()` in library code carries a one-line comment saying why it cannot panic.

## Knowledge Skills

- `rust-modern-apis` — stable Rust APIs added in 1.89–1.99 with a trigger-pattern table. Load it whenever you write, review, or audit Rust code; respect the MSRV when applying it.
