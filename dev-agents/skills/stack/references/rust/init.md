# Rust — Project Init Facts

Applied by the `init-project` skill after `scaffold.sh` runs. Use it to review what the script generated.

## What the Scaffold Detects

- **Marker**: `Cargo.toml` at the root, or one level down (`src-tauri/Cargo.toml`, `native/Cargo.toml`) when the root has none.
- **Units**: with `[workspace]`, every `members` entry (simple globs such as `crates/*` are expanded); the root crate is included when the root manifest also has `[package]`. Without a workspace, the single `[package]`. Names come from each member's `[package] name`.
- **Not detected**: `exclude`d members, `default-members`, nested workspaces, members with `**` globs — add them to `coverage-status.md` by hand.

## Verify Skill Review

- **Build/Test**: `cargo build --workspace --all-features` and the test command from `toolchain.md`. If the project has mutually exclusive features, `--all-features` fails — replace it with the CI feature set (see `.claude/rules/branching.md` or the CI workflow).
- **Run**: one `cargo run --bin <name>` per binary target found in `src/main.rs` (named after the package), `src/bin/*.rs`, `src/bin/*/main.rs`, and `[[bin]] name = ...`. Fix the list when:
  - a `[[bin]]` entry points at `src/main.rs` (the package-named entry is then a duplicate — delete it);
  - the binary needs features (`cargo run --features full --bin <name> -- ...`) or `required-features`;
  - `default-run` is set (plain `cargo run` works);
  - the entry point is an example (`cargo run --example <name>`).
- **Library-only crates**: verification goes through the test suite and doc tests (`cargo test --doc`); add an example binary under `examples/` when an end-to-end flow needs a driver.

## Rule Templates

- `branching.md` pre-PR block: the full check suite from `toolchain.md`, with the CI feature set and env vars.
- `continuous-improvement.md` Test Configuration: `cargo run --features <flags> -- <args>`; debug output via `RUST_LOG=debug` (tracing/env_logger) and `RUST_BACKTRACE=1` for panics.
- Interfaces and critical paths usually map to binary crates, `serde` (de)serialization boundaries, and database migrations (`sqlx migrate`, `diesel migration`).

## .gitignore

The scaffold adds `.local/` and `.claude/agent-memory-local/` only. Confirm the project also ignores `/target`; `Cargo.lock` is committed for binaries and workspaces (and, per current Cargo guidance, may be committed for libraries too).
