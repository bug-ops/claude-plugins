# Rust — Critic Targets

## Counterexample Targets

- `unwrap()` and `expect()` — what makes these panic?
- Integer arithmetic — overflow, underflow, division by zero (release builds wrap silently unless `overflow-checks` is on)
- Slice indexing — out-of-bounds
- `unsafe` blocks — what invariant must hold, and does every caller uphold it?
- `RefCell::borrow_mut()` — where can this panic at runtime?
- Types that can hold invalid states (public fields, constructors that skip validation)

## Scalability Red Flags

- Unbounded collections (`Vec`, `HashMap` without eviction)
- `join_all` or `Vec<JoinHandle>` without bounding concurrent tasks
- Blocking calls (`std::thread::sleep`, sync I/O, CPU-heavy loops) inside async tasks
- `Mutex` held across `.await` or on hot paths

## Completeness

- Is `Display` implemented for error types?
- Are `Debug`, `Clone`, `PartialEq` implemented where needed?
- Is `Send + Sync` correctness analyzed?
- Are `Drop` semantics documented?

## Dependency Risk

- Which crates are `unmaintained` or `unsound` per `cargo audit`?
- Which dependencies pull in `unsafe` without your knowledge?
- What happens if this crate's API changes in the next major version?
- Is the crate's MSRV compatible with the project's `rust-version`?
- What transitive dependency version conflicts exist?

Investigation commands (read-only), beyond the dependency audit in `toolchain.md` (`cargo deny check`, `cargo audit`):

```bash
cargo tree --duplicates
cargo tree -i <crate>       # who pulls this crate in
cargo metadata --format-version 1
```

## Second-Order Effects

- Compile times: heavy generics (monomorphization), proc macros, and new dependencies in hot crates.
- API evolution: new public items, trait bounds, or non-sealed traits constrain future changes; check with `cargo semver-checks`.
- Type inference: generic-heavy APIs that force turbofish or annotations on callers.

## Scope and Bloat Signals

- New `pub` items, re-exports, or `pub` fields the plan does not name — public surface is a semver commitment
- New Cargo features, `[dependencies]` entries, or `build.rs` the plan does not call for
- Traits with one implementor, generic parameters with one instantiation, builders for types with two or three fields
- `#[allow(dead_code)]`, unused function parameters, `Option` arguments every caller passes as `None`
- Custom error variants nothing returns; `impl` blocks for traits nothing uses

## Reproducers

A throwaway `#[test]` in a new file under `tests/`, or a new `examples/` program (never an edit of an existing file), run with `cargo test <name>` or `cargo run --example <name>`. Prove panics with the exact input; never commit the reproducer.
