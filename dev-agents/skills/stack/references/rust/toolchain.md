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
| Tests | `cargo nextest run --workspace --all-features` (unit, binary, and `tests/` integration targets) |
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
- `unsafe` blocks carry `// SAFETY: <invariant>` on the line above, enforced by `undocumented_unsafe_blocks` (see [Lint Policy](#lint-policy)).
- An `unwrap()`/`expect()` in library code that cannot panic carries `#[expect(clippy::unwrap_used, reason = "...")]` (or `expect_used`); see [Lint Policy](#lint-policy).

## Lint Policy

The lints, `clippy.toml`, and `.cargo/config.toml` baseline live in [init.md](init.md#lint-baseline). Coding rules that follow from it:

- **Markers are lints**: `undocumented_unsafe_blocks` enforces `// SAFETY:`; the `reason` of `#[expect(clippy::unwrap_used, reason = "...")]` is the "cannot panic" comment, and the compiler checks it. Reviews judge the reason's quality, not its presence.
- **Exceptions**: `#[expect(lint, reason = "...")]`, never `#[allow]`.
- **`clippy.toml` lookup**: clippy uses the nearest `clippy.toml` with no inheritance. An entry in a crate-level file does not apply to sibling crates, and root settings do not reach a crate that has its own file.
- **API bans**: when a bug class is "called API X where Y was required" (wrong constructor, char vs byte index, path-based `std::fs`, blocking call in async), the first-choice structural fix is a `disallowed-methods` / `disallowed-types` entry in `clippy.toml` with `reason = "<why> (#issue); use <replacement>"`, plus the replacement API if it does not exist yet. On a `disallowed_methods` error, follow the reason; the only exception form is `#[expect(clippy::disallowed_methods, reason = "<why this call site differs>")]`.

## Knowledge Skills

- `rust-modern-apis` — stable Rust APIs added in 1.89–1.100 with a trigger-pattern table. Loaded by the roles `stack/SKILL.md` lists (architect, developer, code-reviewer, arch-analyst); respect the MSRV when applying it.
