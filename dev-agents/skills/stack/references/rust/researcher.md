# Rust — Researcher Rules

## Off-Limits Files

Never edit `*.rs`, `Cargo.toml`, `Cargo.lock`, `deny.toml`, `rust-toolchain.toml`, or CI workflows — not even to bump a dependency version.

## Dependency Monitoring Commands

```bash
cargo outdated --workspace              # version drift (cargo-outdated); --root-deps-only hides transitive noise
cargo deny check advisories             # security advisories (RUSTSEC), unmaintained and yanked crates
cargo audit                             # fallback when cargo-deny is not configured
cargo update --dry-run                  # semver-compatible updates the lockfile would take
cargo tree --duplicates                 # several versions of one crate in the graph
cargo tree --invert <crate>             # who pulls a crate in
```

Workspaces declare versions once in `[workspace.dependencies]`: one bump touches every member — say so in the issue.

## Sources

| Need | Source |
|------|--------|
| Versions, release dates, downloads, reverse dependencies | crates.io (`https://crates.io/crates/<name>`, API `https://crates.io/api/v1/crates/<name>`) |
| Docs for an exact version | docs.rs (`https://docs.rs/<name>/<version>`) |
| Discovery by category, alternatives | lib.rs, crates.io categories and keywords |
| Advisories | RustSec Advisory Database (rustsec.org), GitHub Advisory Database (Rust ecosystem), NVD |
| Language and toolchain evolution | Rust release notes and the Rust blog, `rust-modern-apis` skill for APIs already summarized |

## Package Health Signals

- Last release date and commit activity; issue and PR response time; number of maintainers (bus factor)
- RUSTSEC `unmaintained` or `unsound` informational advisories; yanked versions in `Cargo.lock`
- The update's `rust-version` vs the project's MSRV — a dependency raising MSRV above the project's is a blocker unless the project raises MSRV (a breaking change); state it in the issue
- `unsafe` surface (`cargo geiger`), `no_std` support, default-feature weight, compile-time cost, proc-macro count
- Download trend and reverse-dependency count as an adoption signal, never as the only one

## Update Priority Triggers

| Trigger | Priority |
|---------|----------|
| RUSTSEC vulnerability advisory for a locked version | Immediate (P0/P1) |
| `unsound` advisory affecting code paths the project uses | Immediate (P1) |
| Yanked version in `Cargo.lock` | Next PR (P2) |
| `unmaintained` advisory | Backlog research issue to evaluate a replacement (P3) |
| Duplicate major versions of a heavy crate in the tree | Backlog (P3/P4) |

Semver note: for `0.x` crates a minor bump (`0.4` → `0.5`) is breaking; treat it as a major bump.

## Dependency Functionality Coverage — Rust Examples

- `serde`: borrowed zero-copy deserialization (`#[serde(borrow)]`), `#[serde(deny_unknown_fields)]` for strict config parsing
- `tokio` / `tokio-util`: `CancellationToken`, `tokio::time::timeout`, `JoinSet` replacing hand-rolled task bookkeeping
- `tracing`: `#[instrument]` spans and structured fields replacing ad-hoc log strings
- `reqwest`: per-request and connect timeouts, retry middleware
- `sqlx`: compile-time checked queries (`query!`) replacing runtime-built SQL
- `clap`: derive API, value parsers, and `env` fallback replacing manual argument parsing
- Derive macros (`thiserror`, `strum`, `derive_more`) replacing hand-written trait impls
- The reverse: crates replaced by std (`once_cell` → `std::sync::LazyLock`/`OnceLock`, `lazy_static`) — check against `rust-modern-apis` and the MSRV

## Rust Research Topics

- Zero-copy parsing and borrowed data; memory layout (`#[repr]`, arena allocators, small-vector types)
- SIMD (`std::arch`, portable SIMD crates); allocator choice (`mimalloc`, `jemalloc`) for allocation-heavy workloads
- Compile-time guarantees: typestate, sealed traits, const generics, GATs
- Async ecosystem shifts (runtime features, `async fn` in traits, structured concurrency crates)
- Deprecated or archived crates in the tree and their maintained successors (e.g. `serde_yaml` → `serde_norway`)
- New stable language and std features after the MSRV; edition changes

## Reference Projects

Same tech stack first: Rust projects in the domain, found through crates.io/lib.rs categories, GitHub topics, and the dependents of the project's key crates.

## Vulnerability Classes Common in Rust

- Unsoundness in `unsafe` code or in a dependency's `unsafe` (use-after-free, data races through `Send`/`Sync` misuse)
- Panics on untrusted input — denial of service through `unwrap`, slice indexing, arithmetic overflow in debug builds
- Integer overflow wrapping silently in release builds
- Unbounded allocation from attacker-controlled lengths (deserialization bombs, decompression bombs)
- Path traversal in archive extraction and static file serving
- TOCTOU races on the filesystem; symlink following
- Command injection through `std::process::Command` with shell wrappers
- Regex denial of service in non-linear engines (`fancy-regex`, `pcre2`); the `regex` crate itself is linear-time
