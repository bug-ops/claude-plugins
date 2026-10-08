# Rust — Architecture Inspection Rules

Language checklist for the `arch-inspect` protocol. Section numbers match the protocol's focus areas.

## Evidence Commands

Read-only still allows running the toolchain: `cargo check`, `cargo clippy`, `cargo doc`, `cargo semver-checks`, `cargo machete`, and `cargo hack` give evidence without touching tracked files. Run these before reading by hand:

```bash
cargo clippy --all-targets --all-features -- -W clippy::pedantic -W clippy::nursery   # structural lints
cargo doc --no-deps 2>&1 | grep -c warning                                             # doc coverage and broken links
cargo tree --duplicates                                                                # duplicate dependency versions
```

Then the toolchain.md commands **Public API breakage** (`cargo semver-checks`), **Unused dependencies** (`cargo machete`), and **Feature combinations** (`cargo hack`).

## Every-Cycle Specifics

- **Modern APIs** — scan with the `rust-modern-apis` trigger table; cite the API and file/line.
- **Version policy** — the floor is `rust-version` in `Cargo.toml` (or `[workspace.package]`). An MSRV bump is a breaking change.

## 1. Type Safety

- **Boolean blindness** — `process(true, false)` is unreadable; `process(Direction::Forward, Encoding::Raw)` is self-documenting.
- **Primitive-typed domains** — raw `String`, `u64`, `i32` in public APIs. `UserId(u64)` cannot be passed where `OrderId(u64)` is expected; a bare `u64` can.
- **`Option<Option<T>>`** — outer `None`, inner `None`, and `Some(None)` are indistinguishable in intent. Use an explicit enum.
- **Post-construction validation** — replace `is_valid()`/`validate()`/`check()` with a smart constructor `fn new(...) -> Result<Self, E>`.
- **Public struct fields** — `pub` fields bypass invariants; keep fields private behind a constructor.
- **Unsafe without justification** — every `unsafe` block needs a `// SAFETY:` comment explaining why the invariants hold. Absence is P1.
- **Typestate** — repeated `is_connected`/`is_initialized`/`is_open` checks → one type per state (or a `PhantomData` state parameter); transitions consume `self` and return the next state.

## 2. Modularity

- **Visibility** — `pub` where `pub(crate)` or `pub(super)` suffices.
- **Wildcard re-exports** — `pub use module::*`.
- **Workspace** — versions in a member `Cargo.toml` instead of `[workspace.dependencies]` (members use `dep = { workspace = true }`); non-alphabetical dependency tables.
- **Features** — Cargo features must be additive; a feature that disables code or changes semantics breaks `--all-features` builds in dependents.
- **Crate cohesion** — split crates that do unrelated things; merge thin wrappers. Crates cannot depend on each other cyclically, but modules inside a crate can — check `use` graphs inside large crates.

## 3. Testability

- **Concrete I/O types** — `std::fs::File`, `TcpStream`, or `reqwest::Client` in signatures; accept `impl Read`, `impl Write`, or a trait-abstracted client instead.
- **Time** — `SystemTime::now()`/`Instant::now()` in business logic; inject a `Clock` trait (`fn now(&self) -> SystemTime`).
- **Global mutable state** — `static mut`, `OnceLock` initialized with side effects, process-global registries.
- **Tests outside `#[cfg(test)]`** — test functions and helpers belong in `#[cfg(test)] mod tests` (or `tests/`), not in the release binary.

## 4. Readability

API naming (Rust API Guidelines):

- Getters use the field name: `user.name()`, not `user.get_name()`.
- `as_` conversions are free and return a reference or view; `to_` conversions allocate or are expensive and return owned data; `into_` conversions consume `self`. Mismatches mislead callers about cost and ownership.
- **`impl Into<X>` parameters** — implement `From<X>` on the destination type and accept `impl Into<X>` only in generic public APIs where ergonomics matter; `impl Into<X>` everywhere without `From` impls is noise.
- Single-letter bindings are acceptable in iterator adapters and short closures only.

## 5. DRY

- Duplicated error variants (`NotFound`, `Unauthorized`, `InvalidInput`) across crate error enums → a shared error module in the `core` crate.
- Code-level duplication → a shared function, generic, or `macro_rules!` macro.
- Redundant traits with overlapping methods → a supertrait hierarchy or a merge.

## 6. Async Concurrency

- **Unbounded `join_all`** over a `Vec` of futures → `StreamExt::buffer_unordered(N)` (or `JoinSet` with a semaphore).
- **Missing timeouts** → `tokio::time::timeout` around each network/I/O call, or the client's own timeout setting.
- **Discarded `JoinHandle`** — a `tokio::spawn` result that is not stored loses panics silently (P1). Bind the handle; abort it on drop if the result is genuinely unneeded.
- **Missing backpressure** — `mpsc::unbounded_channel` between a fast producer and a slow consumer → bounded `mpsc::channel(N)` with the send error handled.
- **Blocking inside async** — `std::fs`, `std::thread::sleep`, synchronous HTTP/database clients, or CPU-bound loops in an `async fn` → `tokio::fs`, `tokio::time::sleep`, async clients, or `spawn_blocking`.
- **Lock held across `.await`** — a `std::sync::Mutex`/`RwLock` guard alive across an await point blocks the thread and can deadlock the runtime → `tokio::sync` locks, or scope the guard so it drops before the await.
- **Cancellation safety** — futures in `select!` or under `timeout` that perform multi-step mutations.
- **Graceful shutdown** — no `CancellationToken` (tokio-util) or shutdown channel propagated to long-running tasks.
- **Public futures without `Send`** — a library `async fn` capturing `Rc`, `RefCell`, or a non-`Send` guard cannot be spawned on a multi-threaded runtime. Check public async signatures compile under a `Send` bound.

## 7. Error-Handling Design

- **`anyhow`/`Box<dyn Error>` in library public APIs** — libraries expose a `thiserror` enum; `anyhow` belongs in binaries and tests.
- **Leaked dependency types** — `reqwest::Error`, `sqlx::Error`, `serde_json::Error` as a variant payload; wrap with `#[source]` behind an opaque variant.
- **Missing `#[source]` chains** — `Io(String)` destroys the chain (no downcast, no root cause); keep the source typed.
- **Catch-all variants** — `Error::Other(String)`, `Custom(String)`.
- **Lossy `From` conversions** — `impl From<io::Error> for AppError` applied via `?` at every layer; add `.map_err(...)` or `.context(...)` where the operation is known.
- **Panics as error handling** — `unwrap`/`expect`/`panic!` on recoverable conditions in library code; return `Result`.

## 8. API Stability

- **Missing `#[non_exhaustive]`** on public enums and structs that will grow.
- **Unsealed traits** — seal internal-implementation traits with a private supertrait (`mod sealed { pub trait Sealed {} }`).
- **Dependency types in public signatures** — `hyper::Body`, `chrono::DateTime` pin the dependency's major version to your semver.
- **Unchecked semver** — `cargo semver-checks` absent from CI; run it during the audit.
- **Features that remove behavior** — a non-additive feature (see 2) breaks dependents built with `--all-features`.
- **MSRV policy** — `rust-version` absent, or present but not tested in CI (no job on the MSRV toolchain). Check `rust-modern-apis` usage against it.

## 9. Observability

- **Spans** — boundary functions carry `#[tracing::instrument]` with sensitive fields skipped (`skip(password)`, `skip_all` plus explicit `fields(...)`).
- **Unstructured logging** — `println!`/`eprintln!` in library or service code; `log::info!("user {} did {}", ...)` formatting instead of `tracing` fields (`info!(user_id, action, "...")`).
- **Swallowed errors** — `let _ = fallible()`, `.ok()` discarding a `Result`, a `match` arm that logs nothing.
- **New work paths** — new I/O or CPU-heavy paths without a `tracing` span.

## 10. Lint and Manifest Hygiene

- **No `[workspace.lints]`** — per-crate `#![warn(...)]` drifts. Baseline: `[workspace.lints.clippy]` with `pedantic` (selectively allowed) and `[workspace.lints.rust]` with `unsafe_code = "forbid"` where possible; members opt in with `[lints] workspace = true`.
- **`missing_docs` not enforced** — `#![warn(missing_docs)]` plus the toolchain.md **Doc gate** (`--deny rustdoc::broken_intra_doc_links`).
- **Blanket `#[allow(...)]`** — crate-level allows of `dead_code`, `unused`, or Clippy groups. Prefer a scoped `#[expect(lint, reason = "...")]` (Rust 1.81+, respect MSRV).
- **Unused and duplicate dependencies** — `cargo machete` hits and `cargo tree --duplicates` clusters.
- **Feature combinations** — each `cargo hack check --feature-powerset` failure is a finding.
- **Rustdoc warnings** — broken intra-doc links and code blocks without a language; count them.

## Filing

- Before/After blocks use ` ```rust `.
- P1 patterns in this profile: `unsafe` without `// SAFETY:`, `static mut` or side-effecting global state, discarded `JoinHandle`, publicly constructible invalid states.
- False positives: a `bool` parameter with no alternative domain meaning; a `get_` prefix required by an external trait contract.
