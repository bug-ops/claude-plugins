# Compiler and Cargo improvements

These are not APIs you write against, but they affect builds and might unlock optimizations when MSRV is raised.

## `lld` is the default linker on `x86_64-unknown-linux-gnu` — 1.90

**Significant build-time improvement** on Linux, free when you raise MSRV to 1.90+.

LLD is substantially faster than GNU `ld`, especially for large Rust binaries with lots of generic code. Incremental builds benefit the most — typical measurements show 30-60% linker time reduction on debug builds with many dependencies.

No code changes required. If your CI runs on `x86_64-unknown-linux-gnu`, just raise MSRV and rebuild.

**Opt out** if you hit issues:

```toml
# .cargo/config.toml
[target.x86_64-unknown-linux-gnu]
linker = "gcc"  # or specify your system linker
```

## `cargo publish` multi-package stabilized — 1.90

```bash
cargo publish -p crate-a -p crate-b
```

Publishes multiple workspace members in one command, handling dependency ordering correctly. Before 1.90, you had to invoke `cargo publish` per crate and wait for crates.io propagation between them.

Significant quality-of-life improvement for workspaces with multiple publishable crates.

## `cargo fix` / `cargo clippy --fix` respect target selection — 1.89

Previously, these applied to all targets in the workspace (binaries, examples, tests, benches). Now they default to the same target as `cargo build` — just the library/binary.

Use `--all-targets` to restore the old behavior.

## `cargo tree` long-form `--format` flags — 1.93

```bash
cargo tree --format '{name}@{version} {license}'
# Same as before, but {license} and similar long names now work alongside {p} etc.
```

## `cargo clean --workspace` — 1.93

Cleans only the current workspace's build artifacts, not all targets mixed into the shared target dir. Useful when you have multiple workspaces sharing a target directory (e.g., via `CARGO_TARGET_DIR`).

## `CARGO_CFG_DEBUG_ASSERTIONS` env var in build scripts — 1.93

Build scripts now see `CARGO_CFG_DEBUG_ASSERTIONS=1` when building with debug assertions enabled. Lets `build.rs` conditionally compile native code or emit different bindings for debug vs release.

## `build.build-dir` config — 1.91 stabilized

Lets you configure where build artifacts go independently of `target-dir`:

```toml
# .cargo/config.toml
[build]
target-dir = "target"      # final outputs (binaries, libraries)
build-dir = "/tmp/build"   # intermediate artifacts (.o files, etc.)
```

Useful for:
- Keeping the final artifacts on a slow disk (NAS, bind-mount) while intermediates live on fast SSD.
- Separating CI cache targets from local dev.
- Reducing repo size for tools that scan `target/`.

## TOML v1.1 in Cargo.toml — 1.94

Cargo now parses TOML v1.1 for manifests. Notable additions usable in 1.94+:
- Inline table multiline support.
- Newline handling in basic strings (LF in literal strings).

Using v1.1-specific features in `Cargo.toml` raises your dev-time MSRV (because older Cargo can't parse the manifest), but the **published** manifest is still compatible with older parsers — Cargo re-serializes to v1.0 at publish time.

## `--remap-path-prefix` consistent in diagnostics — 1.94

Compiler diagnostics now respect `--remap-path-prefix` consistently across local and dependency code. Before, dependency paths sometimes appeared as absolute paths even with remap active. Now uniformly remapped.

Matters for reproducible builds and CI log sanitization.

## `unused_visibilities` lint — 1.94 (warn-by-default)

Warns on visibility modifiers on `const _` declarations, which are effectively nameless and can't be referred to from outside anyway:

```rust
pub const _: () = ();  // warning: unused visibility
const _: () = ();      // fine
```

Mostly a code-cleanup lint.

## `unused_must_use` no longer warns on `Result<(), Uninhabited>` — 1.92

Covered in [results.md](results.md). Not a warning change for existing correct code, but unblocks patterns where `E = Infallible`.

## Updates to minimum LLVM — 1.87 → LLVM 20; 1.91 → LLVM 21; 1.92 → LLVM 20 minimum external

If you're building the compiler or linking against rustc's LLVM, these version bumps matter. For most projects, transparent.

## Stabilized target features

- **1.89**: AVX-512, AES-KL/WIDEKL, SHA-512/SM3/SM4 (x86); LoongArch f/d/frecipe/lasx/lbt/lsx/lvz.
- **1.91**: SSE4A, TBM (x86).
- **1.93**: s390x vector features.
- **1.94**: 29 RISC-V features for RVA22U64 / RVA23U64 profiles.

Relevant only if you're writing SIMD intrinsics or targeting these platforms. Enables `#[target_feature]` and `is_x86_feature_detected!` for newer feature flags.

## ABI changes

### `wasm32-unknown-unknown` C ABI — 1.89

`extern "C"` on `wasm32-unknown-unknown` now uses a standards-compliant C ABI. **Compatibility break** for existing wasm-bindgen users — upgrade to `wasm-bindgen >= 0.2.89` before raising MSRV to 1.89+.

### Frame pointers on aarch64-linux — 1.89

Non-leaf frame pointers are enabled by default on aarch64-linux. Slight code size increase but dramatically improves profiling with tools like `perf`.
