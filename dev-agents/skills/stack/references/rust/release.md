# Rust — Release Mechanics

Applied by the `release` skill to every Rust manifest. Commands from `toolchain.md` are referenced by name.

## Project Structure

```bash
# Workspace or single crate
grep -q "^\[workspace\]" Cargo.toml && echo "workspace" || echo "single-crate"

# Workspace members (manifest paths)
cargo metadata --no-deps --format-version 1 | jq -r '.packages[].manifest_path'
```

- **Single crate**: only the root `Cargo.toml` `[package]` version changes.
- **Workspace**: versioned units are the members; crates with `publish = false` are internal — bump them only when the project keeps them in lockstep.

## Version Source of Truth

```bash
# Single crate, or a workspace with [workspace.package].version
grep '^version' Cargo.toml | head -1 | sed 's/.*"\(.*\)"/\1/'

# Members that inherit the workspace version
grep -r "version.workspace = true" --include="Cargo.toml" .
```

When `[workspace.package].version` exists and members use `version.workspace = true`, only the root version changes (lockstep). Members with their own `version = "..."` are versioned independently.

## Manifest Updates

1. Root: `version = "X.Y.Z"` in `[package]` or `[workspace.package]`.
2. Each member that does not inherit: its `[package]` `version`.
3. Internal dependencies that pin a version alongside the path, in `[workspace.dependencies]` or in members:

   ```toml
   my-core = { path = "crates/my-core", version = "X.Y.Z" }
   ```

   A path dependency without `version` cannot be published; every published internal dependency needs one.

Optional helper: `cargo set-version --bump <patch|minor|major>` (cargo-edit) updates package versions and dependent references across the workspace. Review its diff; it does not replace the steps below.

After editing, run the fast compile check from `toolchain.md`.

## Lockfile Refresh

```bash
cargo update --workspace
```

Updates only the workspace's own entries in `Cargo.lock`. Stage `Cargo.toml` files and `Cargo.lock`.

## Secondary Version Carriers

- README install snippets: `my-crate = "X.Y"` — the readme-generator refresh covers them; double-check `[dependencies]` examples in docs and `lib.rs` crate docs.
- `html_root_url` attributes (`#![doc(html_root_url = "https://docs.rs/my-crate/X.Y.Z")]`) when present.
- Bindings shipped from the same repo (`pyproject.toml`, `package.json` of napi/wasm packages) — follow that profile's release file in lockstep.
- Add `--include="*.toml"` to the documentation grep.

## Pre-Release Gates

1. **Full check suite** from `toolchain.md`.
2. **Release build**: `cargo build --release --workspace`.
3. **Package dry run**: `cargo publish --dry-run -p <crate>` for each published crate (or `cargo publish --workspace --dry-run` on toolchains that support workspace publishing). It packages and builds the crate exactly as crates.io would, catching missing `version` on path dependencies, files excluded by `include`/`exclude`, and missing `license`/`description` metadata. Inspect the file list with `cargo package --list -p <crate>`.
4. **API compatibility**: `cargo semver-checks` compares the public API against the latest published version on crates.io. A reported breaking change requires a major bump (minor below 1.0.0). Not applicable before the first publish.
5. **MSRV**: if `rust-version` is declared, verify it still builds — `cargo +<msrv> check --workspace --all-features` or `cargo msrv verify` (cargo-msrv). Raising `rust-version` is a breaking change: call it out in the changelog and bump accordingly.
6. **Feature combinations** (crates with many features): the feature-combinations command from `toolchain.md`.

## Semver Notes

- Cargo treats `0.Y.Z` → `0.(Y+1).0` as breaking; `^0.5` does not match `0.6.0`.
- Breaking: removing or renaming a `pub` item, adding a required trait item, adding a field to an exhaustive `pub` struct, removing a feature, adding a variant to a non-`#[non_exhaustive]` `pub` enum, raising MSRV (by convention).
- Non-breaking: new `pub` items, new optional features, new variants on `#[non_exhaustive]` enums.

## Tags and Publishing

- Lockstep: one tag `vX.Y.Z`.
- Independent workspace versions: one tag per crate, `<crate>-vX.Y.Z` (release-plz convention) — follow the project's existing tag history first.
- Publishing (`cargo publish`) runs from CI after the tag; crates publish in dependency order (dependencies before dependents). crates.io versions are immutable — a bad release is yanked (`cargo yank --version X.Y.Z`), never overwritten.
