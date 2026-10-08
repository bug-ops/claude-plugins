# Rust — Debugging Rules

## Prevention Techniques — Rust Forms

- **Typestate**: `struct Connection<S> { state: PhantomData<S>, .. }` with `impl Connection<Open> { fn send(..) }`; transitions consume `self` and return the next state.
- **Newtype**: `struct AccountId(u64)`, `struct Amount(u64)` — no `Deref` to the inner type, so arguments cannot be swapped.
- **PhantomData markers**: `struct Id<T> { raw: u64, _marker: PhantomData<T> }` → `Id<User>` vs `Id<Order>`.
- **Sealed enums**: replace `bool` and raw `&str` modes with an `enum`; `match` without a wildcard arm so a new variant fails to compile everywhere.
- **Smart constructors**: `EmailAddress::parse(raw) -> Result<Self, InvalidEmail>` with a private field.
- **Builder**: typestate builder whose `build()` exists only on `Builder<HasName, HasEmail>`.
- **Ownership redesign**: replace `Arc<Mutex<_>>` shared mutation with `tokio::sync::mpsc` channels and an owning task.
- **Unavoidable shared state**: `#[must_use]` on guard-returning functions, `debug_assert!` on the invariant.

## Compilation Errors

| Error | Cause | Fix direction |
|-------|-------|---------------|
| `cannot borrow as mutable while also borrowed as immutable` | Overlapping borrow scopes | Separate scopes; release immutable borrow before taking mutable |
| `value does not live long enough` | Returning reference to local | Return owned value or extend the source's lifetime |
| `missing lifetime specifier` | Function returns reference whose lifetime can't be inferred | Annotate explicit lifetimes |
| Macro errors with cryptic messages | Generated code is wrong | Run the macro-expansion command from `toolchain.md` to see the generated code |

`rustc --explain E0382` (or any error code) gives the official explanation. Fix the first error first — later errors are often cascades.

## Runtime Debugging

```bash
RUST_BACKTRACE=1 cargo run     # Standard backtrace
RUST_BACKTRACE=full cargo run  # Full backtrace including std frames
```

Common panic sources: `unwrap()` / `expect()` on `None`/`Err`, slice indexing out of bounds, integer overflow in debug builds, division by zero, `RefCell::borrow_mut()` while already borrowed.

Defensive patterns: `unwrap_or_default()`, `ok_or(Error::NotFound)?`, `slice.get(i)` returning `Option`, `checked_add` / `saturating_add` for arithmetic on user-facing metrics.

## Native Debuggers

- **macOS**: `lldb target/debug/your-app` — `b main` / `b file.rs:42` / `run` / `n` (next) / `s` (step into) / `p var` / `bt`
- **Linux**: `gdb target/debug/your-app` — `break main` / `run` / `next` / `print var` / `backtrace`
- `rust-lldb` / `rust-gdb` wrappers add pretty-printers for `Vec`, `String`, `Option`.

Always build in debug mode — release mode strips symbols (or set `debug = true` in `[profile.release]` when the bug only reproduces optimized).

## Async Debugging

```bash
cargo install tokio-console
RUSTFLAGS="--cfg tokio_unstable" cargo run    # In your app
tokio-console                                  # In another terminal
```

In code: `console_subscriber::init()` at the start of `main`.

Common issues:
- **Task never completes** — wrap with `tokio::time::timeout(Duration::from_secs(N), op)` to identify the hang
- **Blocking in async** — replace `std::thread::sleep` with `tokio::time::sleep`; use `tokio::task::spawn_blocking` for CPU-bound work
- **Lost errors** — a `JoinHandle` dropped without `.await` discards the task's panic and `Result`

## Structured Logging with tracing

Use `#[tracing::instrument(skip(secret_field))]` on async functions. Set log level via `RUST_LOG=debug cargo run`. Skip sensitive fields explicitly so they don't leak into spans.

## Memory Debugging

- AddressSanitizer: `RUSTFLAGS="-Z sanitizer=address" cargo +nightly run --target <host-triple>` — detects use-after-free, buffer overflow, leaks
- Bounded caches: prefer `VecDeque` with `max_size` over unbounded `Vec`
- Reference cycles with `Rc`/`Arc`: use `Weak` for back-pointers

## CI-Only Failures

Usual environment differences: toolchain channel or version (`rust-toolchain.toml` vs the workflow), feature set (`--all-features` vs default), target OS (path separators, case-sensitive filesystems), `RUSTFLAGS` set in CI (`-D warnings`), and a stale or missing `Cargo.lock`.

## Anti-patterns

- Using `unwrap()` everywhere "to debug later"
- `println!`/`dbg!` debugging left in code instead of `tracing`
- Debugging in release mode (no symbols)
- Ignoring compiler warnings
