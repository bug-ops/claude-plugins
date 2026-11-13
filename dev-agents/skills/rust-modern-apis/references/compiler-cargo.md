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

## Dependency with both git and registry source — 1.96

A single dependency can now name a git `repository` and an alternate `registry` at once:

```toml
[dependencies]
my-lib = { git = "https://github.com/me/my-lib", registry = "my-registry" }
```

Cargo uses the git checkout for local development and the registry coordinates when publishing. Before 1.96 these were mutually exclusive, so workspaces had to patch one in and out.

## `target.'cfg(..)'.rustdocflags` in config — 1.96

Rustdoc flags can now be scoped by `cfg` predicate in `.cargo/config.toml`, matching the long-standing `rustflags` behavior:

```toml
[target.'cfg(windows)']
rustdocflags = ["--cfg", "docsrs"]
```

Previously only `[target.<triple>].rustdocflags` and the unconditional `[build].rustdocflags` were honored.

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

## Incremental compilation off by default in CI — 1.99

Cargo now disables incremental compilation when it detects a CI environment (the `CI` env var). Cold CI builds get faster and caches shrink — incremental artifacts were pure overhead for throwaway build dirs. If your CI genuinely reuses a persistent target dir across runs and benefited from incremental, restore it explicitly:

```yaml
env:
  CARGO_INCREMENTAL: "1"
```

Audit CI configs after raising the toolchain to 1.99: pipelines that set `CARGO_INCREMENTAL=0` manually can drop the knob; pipelines with warm caches should measure before deciding.

## Built-in `debug` profile — 1.99

Cargo gained a built-in profile named `debug`, currently equivalent to `dev` — groundwork for renaming the default profile. `cargo build --profile debug` now works; a custom `[profile.debug]` section in existing manifests now collides with the built-in and needs renaming.

## Workspace `default-features` override — 1.99 (Edition 2024+)

A workspace member can now turn default features back off when inheriting a dependency:

```toml
# member Cargo.toml, edition 2024+
[dependencies]
serde = { workspace = true, default-features = false }
```

Previously `default-features = false` on an inherited dep was ignored with a warning if the workspace definition left defaults on. Removes a long-standing reason to duplicate full dependency specs in members that need a leaner feature set.

## Cargo lints and unused-dependency detection — 1.100

Cargo has its own lint system, configured in the manifest next to rustc and Clippy lints. The headline lint reports dependencies that no target uses — the common case for `cargo-machete` / `cargo-udeps`, now built in and warn-by-default:

```text
warning: unused dependency `tracing-subscriber`
  --> Cargo.toml:23:1
   = note: `cargo::unused_dependencies` is set to `warn` by default
```

```toml
# Cargo.toml — names are written without the `cargo::` prefix
[lints.cargo]
unused_dependencies = "deny"

# or once for the workspace; every member opts in with `[lints] workspace = true`
[workspace.lints.cargo]
unused_dependencies = "deny"
```

Other warn-by-default Cargo lints that surface after the toolchain bump: `unused_workspace_dependencies`, `unused_workspace_package_fields`, `missing_lints_inheritance` (a member without a `[lints]` table while `[workspace.lints]` exists), `redundant_homepage`, and `unknown_lints`. Text-direction codepoints in the manifest are deny-by-default.

What to know about `unused_dependencies`:

- It only fires when every target that could use the dependency was built. `cargo check` covers `[dependencies]` and `[build-dependencies]`; `cargo check --bin foo` skips `[dependencies]`; `[dev-dependencies]` are never reported. Keep `cargo-udeps` if dev-dependency coverage matters.
- Known false positives: a dependency declared only to enable a feature of a transitive crate, or only to pin a transitive version. Move those to `[target."cfg(false)".dependencies]`.
- These are warnings, so `RUSTFLAGS="-D warnings"` does not fail on them. `build.warnings = "deny"` (`CARGO_BUILD_WARNINGS=deny`, stable since 1.97) does.

## Dependency cooldowns (`min-publish-age`) — 1.100

The resolver can ignore versions published too recently (RFC 3923) — a supply-chain mitigation, since malicious releases are usually caught within hours or days.

```toml
# .cargo/config.toml
[registry]
global-min-publish-age = "7 days"   # default "0"; units: seconds … months

[registries.internal]
min-publish-age = "0"               # per-registry override

[resolver]
incompatible-publish-age = "deny"   # default; "allow" disables the check
```

- Versions already in `Cargo.lock` are kept; the cooldown only affects new resolution (`cargo update`, generating a lockfile). Cargo reports what it held back.
- Urgent security fix inside the window: `CARGO_RESOLVER_INCOMPATIBLE_PUBLISH_AGE=allow cargo update foo --precise 1.2.4`.
- Registries that do not record a publish time are never held back, and `cargo install` ignores the setting.
- It reduces risk; it does not replace `cargo audit` / `cargo deny` or reviewing dependency updates.

## `cargo install` uses the packaged lockfile — 1.100

`cargo install` now resolves with the `Cargo.lock` shipped inside the `.crate` by default, and `--locked` is a no-op. Installs are reproducible without the flag; existing `cargo install --locked foo` lines in CI and docs keep working.

## New build-dir layout — 1.100

Intermediate artifacts are now grouped per package and build configuration instead of by file type:

```text
before:  target/debug/deps/libfoo-<hash>.rlib      target/debug/.fingerprint/foo-<hash>/
after:   target/debug/build/foo/<hash>/out/libfoo-<hash>.rlib
         target/debug/build/foo/<hash>/fingerprint/
```

Final artifacts are still uplifted to `target/<profile>/<name>`; unit-test binaries now live under `build/<pkg>/<hash>/out/`. The layout is not a stable interface. After raising the toolchain, audit anything that walks the build dir:

- Scripts globbing `target/*/deps/*` to find test binaries, `.rlib`s, or `.d` files — use `cargo build --message-format=json` (or `cargo test --no-run --message-format=json`) and read the artifact paths from the messages.
- Coverage, debugger launch configs, and UI-test harnesses that pass `-L target/debug/deps`.
- CI cache rules keyed on `deps/` or `.fingerprint/` subdirectories.

The change removes spurious rebuilds and stale-artifact confusion when one build dir is shared between feature sets or git worktrees.

## Sample-based PGO: `-Cprofile-sample-use` — 1.100

`-Cprofile-sample-use=<file.prof>` is stable. Unlike instrumented PGO (`-Cprofile-generate` / `-Cprofile-use`), it needs no instrumented build: sample the normal release binary under `perf`, convert the data to a `.prof` (`llvm-profgen` or AutoFDO's `create_llvm_prof`), and feed that to the next build. Profiles can come straight from production, at the cost of lower profile quality than instrumentation. The companion debuginfo-for-profiling flag is still unstable. See the "Profile-guided Optimization" chapter of the rustc book.

## New rustc lints — 1.100

- **`repeated_reprs` (warn, part of `unused`)** — the same representation given twice (`#[repr(C)] #[repr(C)]`), usually a macro or merge leftover.
- **`aligned_fields_in_packed` (deny-by-default)** — a `repr(C, align(N))` type nested inside a `repr(C, packed)` type. This used to be a hard error; as a lint it can be `#[allow]`ed where the layout is known to match the target C compiler.
- **`dropping_references`, `dropping_copy_types`, `undropped_manually_drops`** now also fire for `ptr::drop_in_place` calls, not only `drop`.
- **`dependency_on_unit_never_type_fallback` is removed** — the code it warned about no longer compiles (see [results.md](results.md)); a leftover `#[allow]` triggers `renamed_and_removed_lints`.
- `unfulfilled_lint_expectations` no longer fires for `#[expect(dead_code)]` inside an item that is itself dead; `ambiguous_glob_imported_traits` fires in a few more cases.
- rustdoc: new `invalid_markdown_table` lint.

## Clippy 1.100 — new lints that suggest code changes

Warn-by-default:

- **`option_zip_none`** (suspicious) — `opt.zip(None)` or `None.zip(opt)` is always `None`; almost always a wrong argument.
- **`needless_nonzero_get`** (complexity) — `nz.get().leading_zeros()` or `4 / nz.get()` where `NonZero` offers the same method or operator directly.

Behavior changes in existing lints: `map_unwrap_or` (pedantic) now also rewrites `.map(f).unwrap_or_default()` to the 1.98 `map_or_default(f)`; `unwrap_used` with `allow-unwrap-in-tests` now covers integration tests; `needless_bool` catches the early-return guard form.

## Updates to minimum LLVM — 1.87 → LLVM 20; 1.91 → LLVM 21; 1.92 → LLVM 20 minimum external; 1.96 → LLVM 21 minimum external; 1.99 → LLVM 23

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

### `extern "custom"` — 1.100

A function ABI for calling conventions Rust does not know — compiler-rt style helpers, `__fentry__` hooks, hand-written trampolines:

```rust
#[unsafe(naked)]
pub unsafe extern "custom" fn raw_entry() {
    core::arch::naked_asm!("ret")
}

unsafe extern "custom" {
    fn __fentry__();
}
```

A definition must be `unsafe` and `#[unsafe(naked)]`; it cannot be called from Rust code, only from assembly or across FFI. Replaces declaring such symbols with a false `extern "C"` signature.

### x86 "Rust" ABI and target-feature checks — 1.100

The unspecified `extern "Rust"` ABI on x86 now passes values in SSE registers when the target always has them — transparent unless code relies on the Rust ABI across separately compiled artifacts. Enabling SSE/AVX on an x86 soft-float target, and ABI-altering `-Ctarget-feature` / `-Ctarget-cpu` values on ARM, are now hard errors. ARMv7-A hard-float targets no longer require the `d32` FPU feature by default (an erroneous baseline since 1.94); pass `-Ctarget-feature=+d32` if the code depended on it.

## New rustc lints — 1.98

Three new lints land in 1.98; two can break builds or CI with `-D warnings`:

- **`invalid_runtime_symbol_definitions` (deny-by-default)** — a Rust definition of a core runtime symbol (`memcmp`, `memset`, `strlen`, …) via `#[no_mangle]`/`#[export_name]` is now an error. Affects embedded/no_std crates that hand-roll these; use the `compiler-builtins` mechanisms or rename the symbol.
- **`suspicious_runtime_symbol_definitions` (warn-by-default)** — same territory, for definitions that only look suspicious (e.g. matching names with non-standard signatures).
- **`c_void_returns` (warn-by-default)** — flags `extern` functions declared as returning `core::ffi::c_void`. In C, `void f()` returns nothing; the Rust equivalent is `-> ()` (or no return type), not `-> c_void`. Fix bindings by dropping the return type.

## Clippy 1.98 — new lints that suggest code changes

Warn-by-default (will surface in any `cargo clippy` run after a toolchain bump):

- **`unnecessary_unwrap_unchecked`** (complexity) — `checked_op(..).unwrap_unchecked()` where a direct `_unchecked` variant of the operation exists.
- **`chunks_exact_to_as_chunks`** (style) — `chunks_exact(N)` with a constant N; suggests `as_chunks::<N>()` (see [slices.md](slices.md)).
- **`by_ref_peekable_peek`** (suspicious) — `.by_ref().peekable().peek()` discards the peeked state when the temporary `Peekable` drops; the peeked element is silently lost.
- **`for_unbounded_range`** (suspicious) — `for i in 0..` overflow-panics instead of terminating; usually a missing bound.
- **`manual_isolate_lowest_one`** (complexity) — `x & x.wrapping_neg()`; suggests the 1.97 `isolate_lowest_one` (see [arithmetic.md](arithmetic.md)).

Allow-by-default (opt-in via pedantic): `with_capacity_zero` (`Vec::with_capacity(0)` → `Vec::new()`), `unused_async_trait_impl` (async trait impl fn with no `.await`).

Moves and deprecations: `empty_enums` moved pedantic → nursery; `from_iter_instead_of_collect` deprecated — stop silencing it with `#[allow]`, the attribute now triggers `renamed_and_removed_lints`.

## Cargo security fixes — 1.96

Two advisories were resolved in the 1.96 toolchain. **Users of crates.io are unaffected by both** — they matter for alternate registries and custom tooling that unpacks or authenticates against arbitrary sources.

- **CVE-2026-5223** (medium) — crate tarball extraction could follow symlinks during unpacking.
- **CVE-2026-5222** (low) — credentials could be sent to a host after URL normalization.

If you operate a private registry or run `cargo` against untrusted sources, upgrade the toolchain to 1.96+.
