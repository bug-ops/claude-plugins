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

## Reproducers

A throwaway `#[test]` or `examples/` program under a scratch path, run with `cargo test <name>` or `cargo run --example <name>`. Prove panics with the exact input; never commit the reproducer.
