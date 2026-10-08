# Rust — Live Tester Rules

## Off-Limits Files

Read-only for the whole session: `*.rs`, `Cargo.toml`, `Cargo.lock`, `build.rs`, `.cargo/`, `rust-toolchain.toml`, `deny.toml`, `clippy.toml`, `rustfmt.toml`, CI workflows.

## Project Discovery

1. `Cargo.toml` — workspace `members`, `[features]` (including `default`), `default-run`, `[[bin]]` targets; binaries also come from `src/main.rs` and `src/bin/*.rs`.
2. `.cargo/config.toml` — command aliases, `[env]` variables, build target, runner.
3. `examples/` — often the fastest way to exercise a library crate end-to-end (`cargo run --example <name>`).
4. Test configs: `.local/config/`, `tests/`, `config/test.toml`, `.env.test`.
5. Feature-gated functionality is unreachable without its feature — map each feature under test to the flag that enables it.

## Running the Project

```bash
cargo run --features <project-features> -- <args>      # default binary
cargo run --bin <name> --features <flags> -- <args>    # a specific binary in the workspace
cargo run --release --features <flags> -- <args>       # performance-sensitive scenarios
```

- For repeated scenarios, build once (`cargo build --features <flags>`) and run `target/debug/<bin>` directly — avoids rebuild noise in timings and logs.
- Exercise at least the default feature set and `--all-features`; add `--no-default-features` when the project advertises it.
- Library-only crates: drive them through `examples/` or a scratch binary under `.local/testing/` that depends on the crate by path.

## Debug Output

```bash
RUST_LOG=debug cargo run --features <flags> -- <args> 2>.local/testing/debug/session.log
RUST_LOG=<crate_name>=trace,info RUST_BACKTRACE=1 target/debug/<bin> <args> 2>.local/testing/debug/session.log
```

`RUST_LOG` applies when the project uses `tracing-subscriber`'s `EnvFilter` or `env_logger`; otherwise use the verbosity flag or config key the project defines.

## Crash and Warning Signatures

Grep logs for:

- `panicked at` — any panic is at least P1 when user input can trigger it
- `stack overflow`, `memory allocation of ... failed`, `SIGSEGV`, `SIGABRT`
- tokio runtime misuse: `Cannot start a runtime from within a runtime`, `Cannot drop a runtime in a context where blocking is not allowed`
- `WARN` / `ERROR` lines from `tracing` or `log`; repeated retries; `timed out`
- A process that stops producing output without exiting — suspect a deadlock or a blocked async runtime; capture a backtrace before killing it

## Resource Usage

Peak memory and wall time: `/usr/bin/time -l <cmd>` (macOS) or `/usr/bin/time -v <cmd>` (Linux). Compare debug and `--release` numbers only against the same profile from earlier sessions.

## Cross-Interface Pairs

- CLI vs TUI vs server/API front ends over the same core crate
- Default features vs `--all-features` builds of the same scenario
- Different backends selected by features or config (storage, LLM provider, transport)

## Dependency Moves (Unchanged HEAD)

`git log --since=<last-session-date> --oneline -- Cargo.lock` lists dependency moves; `git diff <old>..HEAD -- Cargo.lock` shows which crates changed version.

## Benchmarks

Detect: a `benches/` directory or `[[bench]]` targets in `Cargo.toml` (criterion or divan).

```bash
cargo bench -- --save-baseline ci-NNN    # criterion: record this session
cargo bench -- --baseline ci-PREV        # criterion: compare with the previous session
```

Criterion keeps baselines under `target/criterion/`; record the headline numbers in the journal as well, since `target/` is disposable.

## Environment Hygiene

After intensive sessions, `cargo clean` frees incremental build artifacts (it also removes criterion baselines — record numbers in the journal first).
