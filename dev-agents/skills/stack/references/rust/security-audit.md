# Rust — Security Audit Checklist

Language checklist for the `security-audit` protocol; section numbers match the protocol. Read-only scope covers source files, `Cargo.toml`, and `Cargo.lock`; compiling, `cargo clippy`, and running the tests are allowed. Extra reference frameworks: the ANSSI secure Rust guidelines and the Rustonomicon for `unsafe`. When CI already runs `cargo audit` on every push, a clean local run adds no signal.

## 1. Dependency Vulnerabilities

```bash
cargo audit                    # RUSTSEC advisory database, reads Cargo.lock
cargo deny check advisories    # same DB, plus deny.toml policy
cargo deny check bans          # duplicate/banned versions
cargo deny check licenses      # license policy violations
cargo outdated --root-deps-only  # direct deps behind latest
```

- **Matched advisories** — every `cargo audit` hit is a confirmed vulnerability; record the RUSTSEC id. File one issue listing all current `cargo audit` hits.
- **Unmaintained crates** — an advisory of kind `unmaintained`.
- **Yanked versions** — a version yanked from crates.io present in `Cargo.lock`.
- **Duplicates** — clusters flagged by `cargo deny check bans`.

## 2. Unsafe Code

```bash
cargo geiger                   # counts unsafe usage per crate
rg -n "unsafe " --type rust
```

- **`unsafe` without `// SAFETY:`** — every `unsafe` block and every `unsafe fn` must carry a `// SAFETY:` comment stating the invariants that make it sound. Absence is P1.
- **`std::mem::transmute`** — the most dangerous primitive in the language. Flag every use. Most are replaceable with a safe conversion (`as`, `from_bits`, `bytemuck`); the rest need an airtight size-and-validity argument.
- **Raw-pointer arithmetic and dereference** — `ptr.add`, `ptr.offset`, `*ptr` reachable from public input can produce out-of-bounds access. Verify the bound is checked against the same length the pointer was derived from.
- **FFI boundaries** — `extern "C"` functions taking pointers and lengths; verify length and null checks precede every dereference.
- **Hand-written `unsafe impl Send`/`Sync`** — asserts thread-safety the compiler could not prove. Each one must justify why concurrent access is sound; an incorrect one is a data race, which is UB.
- **`from_utf8_unchecked` / `get_unchecked`** — skip validation and bounds checks. Sound only when a preceding check guarantees the invariant; flag any use where that guarantee is not immediately adjacent and obvious.
- **`Vec::set_len`, `MaybeUninit`, uninitialized reads** — exposing uninitialized memory is UB even without a dereference. Verify every `set_len` is preceded by a full initialization of the new range and every `assume_init` by a proof.
- **Panics inside `Drop` and forgotten guards** — a panic in `Drop` during unwinding aborts the process; `mem::forget` on a guard (`MutexGuard`, scoped-thread or RAII cleanup) skips the invariant restoration the guard exists for. Flag both.

## 3. Secrets and Sensitive Data

```bash
rg -n -i "api[_-]?key|secret|password|token|BEGIN (RSA|EC|OPENSSH) PRIVATE KEY" --type rust
```

- **Secrets in logs and errors** — `tracing`/`log` calls or `Error`/`Debug` impls that print credentials. Look for `{:?}` on types holding credentials and for `Display` impls that echo input.
- **Not zeroized** — a credential held in a `String`/`Vec<u8>`; for long-lived secret material, note the absence of a `zeroize`-backed type (`secrecy`, `Zeroizing`) as a hardening finding.

## 4. Input Validation and Injection

```bash
rg -n 'format!\(.*(SELECT|INSERT|UPDATE|DELETE|WHERE)' --type rust -i
```

- **SQL injection** — `format!`, `+`, or `write!` assembling SQL with runtime values; the fix is `$1` bind parameters (`sqlx::query!`, `.bind()`).
- **Command injection** — `std::process::Command` with a shell string (`sh -c`) built from input; user data as a discrete `.arg()` is safe.
- **Path traversal** — flag any `Path::join`/`PathBuf::from` on request data missing the `file_name()` → join → `canonicalize()` → `starts_with(base)` guard.
- **Untrusted deserialization** — `serde_json`/`bincode`/`rmp`/`prost` decoding attacker bytes without a length bound before the decode.
- **Integer overflow and lossy casts** — `as` truncation (`len as u32`) and arithmetic on external sizes. In release builds arithmetic wraps silently; a wrapped length used as an allocation size or slice bound is a memory-safety bug. Prefer `checked_*`/`try_into()` and flag `as` casts on untrusted magnitudes.
- **Missing bounds** — `Vec::with_capacity(n)` or a loop driven by a network-supplied `n`.
- **ReDoS** — the `regex` crate is linear-time, but `fancy-regex`, `pcre2`, and `onig` backtrack. Also flag `Regex::new` per request instead of once (`LazyLock`).

## 5. Cryptography

- **Weak algorithms** — grep for the crate names (`md5`, `sha1`, `des`, `rc4`).
- **Vetted libraries** — `ring`, RustCrypto crates, `age`, `rustls`.
- **Non-CSPRNG** — `rand::thread_rng()`/`rand::random()` for keys, tokens, nonces, or salts; require `OsRng` (`rand::rngs::OsRng`).
- **Password KDF** — `argon2`, `bcrypt`, `scrypt` crates.
- **Constant-time comparison** — `subtle::ConstantTimeEq`, `ring::constant_time`; `==` on MACs, tokens, or hashes is a finding.

## 6. Authentication and Authorization

- **JWT verification** — the `jsonwebtoken` crate's `Validation` pins the accepted algorithm (`Validation::new(Algorithm::RS256)`); any use of `insecure_disable_signature_validation` outside tests is a finding.

## 7. Crash and Resource-Exhaustion DoS (`panics`)

- **`unwrap`/`expect` on untrusted input** — on the request path every one is a P2 DoS finding. Panics in tests, examples, `build.rs`, and `main` startup are fine.
- **Slice indexing on external offsets** — `slice[i]` with `i` from input panics out of bounds; use `.get(i)` and handle `None`.
- **Unbounded allocation** — `Vec::with_capacity(n)` or `vec![0; n]` with attacker-controlled `n`.
- **`panic = "abort"`** — set in a `[profile]`: any reachable panic terminates the whole process rather than one task, raising the severity of every §7 finding.
- **Async runtime starvation** — blocking calls (`std::fs`, `std::thread::sleep`, sync database clients, CPU-heavy loops) inside `async fn`, or a `std::sync::Mutex` guard held across `.await`. Flag any `tokio::spawn` in a per-request loop without a bound (`Semaphore`, `JoinSet` with a cap); offload blocking work with `spawn_blocking`.
- **Cancellation** — a future dropped mid-way by `select!` or `tokio::time::timeout` after a partial write.

## 8. Supply-Chain Trust

```bash
find . -name build.rs -not -path './target/*'
cargo tree -f "{p} {f}"        # inspect the dependency graph and features
```

- **`build.rs`** — review every dependency's build script that does network I/O, shells out, or reads outside `OUT_DIR`.
- **Proc-macros** — execute at compile time; a new or low-reputation proc-macro dependency gets the same scrutiny as a `build.rs`.
- **Vetting** — `cargo vet`/`cargo crev` status for dependencies on security-sensitive paths.
- **Unsafe footprint** — `cargo geiger` on the dependency tree; a crypto or parsing dependency with heavy unmarked `unsafe` is worth recording.
- **Sources** — `deny.toml` `[sources]` allows only crates.io and named private registries; a `git = ...` dependency must pin a `rev`, not a `branch` or bare URL. Binaries commit `Cargo.lock`.
- **Typosquatting** — the crate name is the well-known one (`serde_json`, not `serde-json2`).

## 9. Network and Service Hardening

- **TLS verification disabled** — `danger_accept_invalid_certs`, `danger_accept_invalid_hostnames` (`reqwest`), a custom rustls `ServerCertVerifier` that accepts everything.
- **Limits** — body limits (`axum::extract::DefaultBodyLimit`, `tower_http::limit::RequestBodyLimitLayer`), timeouts (`tower_http::timeout`), concurrency limits (`tower::limit`).
- **Header and log injection** — check every `header(name, user_value)` and every `info!("{}", raw_input)`; prefer structured fields (`info!(user = %name)`).

## 10. Filesystem and Archives

- **TOCTOU** — open first, then validate via `File::metadata`; use `O_NOFOLLOW` through `std::os::unix::fs::OpenOptionsExt::custom_flags`, or directory handles (`cap-std`).
- **Temporary files** — the `tempfile` crate (atomic create, `O_EXCL`), never hand-built names under `/tmp`.
- **Permission modes** — `set_permissions` / `OpenOptionsExt::mode()` on every write of sensitive data; flag `0o777`.
- **Zip-slip** — `zip` and `tar` entries: join, canonicalize, check `starts_with(dest)`, or use the crate's sanitized-path API (`ZipFile::enclosed_name`).
- **Decompression bombs** — `flate2`, `zstd`, `zip`, and image decoders; read through `take(limit)` and cap the entry count.

## 11. Verification Gates

- `#![forbid(unsafe_code)]` (or `unsafe_code = "forbid"` in `[lints]`) on every crate that has no legitimate `unsafe`.
- Clippy restriction lints on request-path crates: `unwrap_used`, `expect_used`, `indexing_slicing`, `arithmetic_side_effects`, `cast_possible_truncation`, `panic`, `todo`, `unimplemented`, `mem_forget`, `unreachable`.
- Miri (`cargo +nightly miri test`) on modules containing `unsafe`; ThreadSanitizer/AddressSanitizer in CI for FFI-heavy crates.
- A `cargo-fuzz` target for every parser of untrusted input, and `proptest` round-trip tests for encoders/decoders.
- `cargo audit`/`cargo deny` in CI, with `Cargo.lock` committed.

## Triage Mapping

- Critical: a Critical RUSTSEC advisory on the request path.
- High: `unsafe` UB, `unsafe` without `// SAFETY:`.
- Medium: `unwrap`/`expect`/indexing panic-DoS on the request path.

**False positives**: `unsafe` in a vendored/vetted dependency, `unwrap` in tests or `main` startup, a `format!` query that only interpolates a compile-time constant, `md5`/`sha1` used for a non-security checksum.

**Handoff scanner line**: `` `cargo audit`: <N advisories> | `cargo deny`: <pass/fail> ``. References cite `RUSTSEC-YYYY-NNNN`.
