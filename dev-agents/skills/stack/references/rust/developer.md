# Rust — Developer Rules

## Code Quality Requirements

**Every function**: clear single responsibility, `Result<T, E>` for fallible ops, `///` doc on public APIs, at least one test in `#[cfg(test)]`.

**Every struct**: `Debug` always; `Clone` only if needed; doc explaining purpose; builder if >3 constructor parameters.

**Ownership preference**: `&T` → `&mut T` → `T` → `.clone()` (last resort, document why).

**Error handling**:
- Library code: `thiserror` with `#[error]` variants and `#[source]` chains
- Application code: `anyhow` with `.context(...)` on every fallible call
- Never `unwrap()` in library code without a comment justifying why it cannot panic

**Async rules**:
- Never block the runtime: `tokio::time::sleep`, not `std::thread::sleep`
- CPU-bound work goes through `tokio::task::spawn_blocking`
- Always bound concurrency: prefer `stream::iter(...).buffer_unordered(N)` over `join_all(...)` for collections
- Always set timeouts on network/IO operations

## DRY Extraction Targets

- Same logic in 2+ places → shared function or trait
- Same error variant in 2+ modules → common error type
- Same test setup repeated → `tests/common/`
- Same validation/parsing pattern → validated newtype or helper

## Incremental Verification

Run `cargo check` after each function, `impl` block, or module.

## Never Weaken Checks — Rust Forms

- Do not delete, `#[ignore]`, or loosen a failing test
- Do not add `#[allow(...)]` to silence a lint; a justified exception needs a comment, same as `unwrap()`
- Do not discard `Result`s with `let _ =` or `.ok()` to silence warnings

## Dependencies Added

In the handoff list name, version, and reason. Workspace rule: version in root `Cargo.toml`, `workspace = true` in the crate, alphabetical order.

## Anti-patterns

- `.unwrap()` without a comment justifying why it is safe
- Cloning data unnecessarily
- Ignoring compiler warnings
- Public APIs without `///` doc comments
- `bool` parameters where an enum would document intent
- Public struct fields that allow invalid states
- Unbounded `join_all` instead of `buffer_unordered(N)`
- `#[allow(...)]` without a comment justifying the exception
