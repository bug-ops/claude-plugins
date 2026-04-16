# Rust release changelog (1.89 – 1.94)

Consolidated changes relevant to application code. For the full release notes, see [doc.rust-lang.org/stable/releases.html](https://doc.rust-lang.org/stable/releases.html).

Each version section lists:
- **Language/syntax** changes
- **Stabilized APIs** (grouped by category)
- **Compatibility notes** (things that might break existing code)

---

## Rust 1.89 (2025-08-07)

### Language

- Stabilized `feature(generic_arg_infer)` — explicitly inferred const arguments with `_`.
- New warn-by-default `mismatched_lifetime_syntaxes` lint (supersedes `elided_named_lifetimes`).
- `dangerous_implicit_autorefs` lint is now warn-by-default (deny in 1.90).
- Stabilized AVX-512 target features for x86.
- Stabilized SHA-512, SM3, SM4 target features for x86.
- Stabilized LoongArch target features (f, d, frecipe, lasx, lbt, lsx, lvz).
- Stabilized `repr128` (`#[repr(u128)]`, `#[repr(i128)]`).
- `format_args!()` results can now be stored in variables.
- Extended temporary lifetime extension through tuple struct / tuple variant constructors.
- `extern "C"` on wasm32-unknown-unknown now uses a standards-compliant ABI (**breaking for wasm-bindgen < 0.2.89**).

### Stabilized APIs

**I/O**:
- `File::lock`, `File::lock_shared`, `File::try_lock`, `File::try_lock_shared`, `File::unlock`
- `io::Seek for io::Take`

**Pointer/memory**:
- `NonNull::from_ref`, `NonNull::from_mut`
- `NonNull::without_provenance`, `NonNull::with_exposed_provenance`, `NonNull::expose_provenance`

**String/collection**:
- `OsString::leak`, `PathBuf::leak`
- `Result::flatten`

**Networking** (Linux-only):
- `std::os::linux::net::TcpStreamExt::quickack`, `set_quickack`

**Numerics**:
- `NonZero<char>`

**Iterator**:
- `Default` for `array::IntoIter`
- `Clone` for `slice::ChunkBy`

**Const-in-const**:
- `<[T; N]>::as_mut_slice` const
- `<[u8]>::eq_ignore_ascii_case` const
- `str::eq_ignore_ascii_case` const

### Compatibility notes

- `missing_fragment_specifier` is now a hard error in macros.
- Long-deprecated `std::intrinsics::drop_in_place` removed.
- Warnings about `stdcall`/`fastcall`/`cdecl` on non-x86-32 targets.
- `extern "C"` ABI change on wasm32-unknown-unknown (see Language above).

---

## Rust 1.90 (2025-09-18)

### Language

- Split `unknown_or_malformed_diagnostic_attributes` into four finer-grained lints.
- Allow constants whose final value has references to mutable/external memory (but reject them as patterns).
- Allow volatile access to non-Rust memory, including address 0.

### Compiler

- **`lld` used by default on `x86_64-unknown-linux-gnu`.** Major build-time improvement.
- Tier 3 `musl` targets now link dynamically by default.

### Stabilized APIs

**Numerics**:
- `u{N}::checked_sub_signed`, `overflowing_sub_signed`, `saturating_sub_signed`, `wrapping_sub_signed`

**CStr**:
- Cross-type `PartialEq` between `CStr`, `CString`, and `Cow<CStr>` — many impls
- `impl Copy for IntErrorKind`, `impl Hash for IntErrorKind`

**Const-in-const**:
- `<[T]>::reverse` const
- `f32::floor`/`ceil`/`trunc`/`fract`/`round`/`round_ties_even` const (same for f64)

### Cargo

- `cargo publish` supports multi-package publishing: `cargo publish -p a -p b`.
- `http.proxy-cainfo` config for proxy certificates.
- `cargo package` uses `gix` instead of libgit2.

### Compatibility notes

- `x86_64-apple-darwin` demoted to Tier 2 with host tools.
- `UnixStream` sets `MSG_NOSIGNAL` by default on Unix — breaks code relying on SIGPIPE.
- `core::iter::Fuse` `Default` impl now constructs `I::default()` internally instead of always being empty.
- On Unix, `env::home_dir` uses fallback if `HOME` is empty.
- `const-eval`: error when initializing a static writes to that static.

---

## Rust 1.91 (2025-10-30) — biggest release for application code

### Language

- Lower pattern bindings in written order; drop order based on primary bindings.
- Stabilized declaration of C-style variadic functions for `sysv64`, `win64`, `efiapi`, `aapcs` ABIs.
- New `dangling_pointers_from_locals` lint.
- `semicolon_in_expressions_from_macros` upgraded from warn to deny.
- Warn-by-default `integer_to_ptr_transmutes` lint.
- Stabilized `sse4a` and `tbm` target features.
- Stabilized LoongArch32 inline assembly.
- New `target_env = "macabi"` / `"sim"` cfgs (replacing `target_abi`).

### Stabilized APIs

**Paths**:
- `Path::file_prefix`
- `PathBuf::add_extension`, `PathBuf::with_added_extension`
- `impl PartialEq<str> for PathBuf`, `PartialEq<String> for PathBuf`, plus symmetric
- `impl PartialEq<str> for Path`, `PartialEq<String> for Path`, plus symmetric

**Time**:
- `Duration::from_mins`, `Duration::from_hours`

**IP addresses**:
- `Ipv4Addr::from_octets`
- `Ipv6Addr::from_octets`, `Ipv6Addr::from_segments`

**Strings**:
- `str::ceil_char_boundary`, `str::floor_char_boundary`

**Numerics** — `strict_*` family:
- `{integer}::strict_add`, `strict_sub`, `strict_mul`, `strict_div`, `strict_div_euclid`, `strict_rem`, `strict_rem_euclid`, `strict_neg`, `strict_shl`, `strict_shr`, `strict_pow`
- Mixed-sign: `i{N}::strict_add_unsigned`, `strict_sub_unsigned`, `strict_abs`; `u{N}::strict_add_signed`, `strict_sub_signed`
- `i{N}::midpoint` (complements existing `u{N}::midpoint`)

**Numerics** — bigint helpers:
- `u{N}::carrying_add`, `borrowing_sub`, `carrying_mul`, `carrying_mul_add`
- `u{N}::checked_signed_diff`

**Atomics**:
- `AtomicPtr::fetch_ptr_add`, `fetch_ptr_sub`, `fetch_byte_add`, `fetch_byte_sub`, `fetch_or`, `fetch_and`, `fetch_xor`

**Collections**:
- `BTreeMap::extract_if`, `BTreeSet::extract_if`

**Iterators**:
- `core::iter::chain` (free function)
- `core::array::repeat`

**Panic**:
- `PanicHookInfo::payload_as_str`

**Pin**:
- `impl<T> Default for Pin<Box<T>>` (and for `Pin<Rc<T>>`, `Pin<Arc<T>>`)

**Cell**:
- `Cell::as_array_of_cells`

**Misc**:
- `impl Debug for std::os::windows::ffi::EncodeWide`
- `impl Sum` / `Product` for `Saturating<u{N}>` (and `&` variants)

**Const-in-const**:
- `<[T; N]>::each_ref`, `each_mut` const
- `OsString::new` const, `PathBuf::new` const
- `TypeId::of` const
- `ptr::with_exposed_provenance`, `with_exposed_provenance_mut` const

### Cargo

- **Stabilized `build.build-dir`** config — separate intermediate artifacts location from final outputs.
- `--target host-tuple` literal expands to host machine triple.

### Compatibility notes

- Coroutine captures always drop-live.
- Apple linker: SDK root always passed; libraries in `/usr/local/lib` no longer auto-linked.
- Relaxed bounds like `TraitRef<AssocTy: ?Sized>` now correctly forbidden.
- Deprecation lints in name resolution now deny-by-default and report in dependencies.
- `semicolon_in_expressions_from_macros` now deny-by-default.
- Trait impl modifiers in inherent impls syntactically invalid.
- Stricter attribute parsing — errors on many previously-accepted invalid attributes.
- Edition 2024: temporary lifetime shortening applied to `pin!`, `format_args!`, `write!`, `writeln!` in `if let` scrutinees.
- Static closures (`static || {}`) syntactically invalid.
- Update to LLVM 21.

---

## Rust 1.92 (2025-12-11)

### Language

- Documented `MaybeUninit` representation and validity.
- Allow `&raw [mut | const]` for union fields in safe code.
- Prefer item bounds of associated types over where-bounds for auto-traits and `Sized`.
- `#[track_caller]` + `#[no_mangle]` can be combined.
- Made `never_type_fallback_flowing_into_unsafe` and `dependency_on_unit_never_type_fallback` deny-by-default.
- `unused_must_use` no longer warns on `Result<(), Uninhabited>` or `ControlFlow<Uninhabited, ()>`.

### Compiler

- Minimum external LLVM is now 20.
- Removed command-line args from PDB embedding (fixes incremental builds on non-PDB targets).

### Stabilized APIs

**Sync**:
- `RwLockWriteGuard::downgrade` (std only — not tokio, not parking_lot)

**Numerics**:
- `NonZero<u{N}>::div_ceil`

**Location**:
- `Location::file_as_c_str`

**Box / Rc / Arc**:
- `Box::new_zeroed`, `Box::new_zeroed_slice`
- `Rc::new_zeroed`, `Rc::new_zeroed_slice`
- `Arc::new_zeroed`, `Arc::new_zeroed_slice`

**BTreeMap**:
- `btree_map::Entry::insert_entry`
- `btree_map::VacantEntry::insert_entry`

**proc_macro**:
- `impl Extend<proc_macro::Group>` for `TokenStream` (and for `Literal`, `Punct`, `Ident`)

**Iterator**:
- `Iterator::eq{_by}` specialized for `TrustedLen` (internal optimization)

**Const-in-const**:
- `<[_]>::rotate_left`, `rotate_right` const

### Compatibility notes

- `unused_must_use` on `Result<(), Uninhabited>` removed (improvement, not breakage, but noted).
- Prevent downstream `impl DerefMut for Pin<LocalType>`.
- Don't apply temporary lifetime extension to arguments of non-extended `pin!` and formatting macros.
- `iter::Repeat::last` and `iter::Repeat::count` now panic (instead of looping infinitely).
- `invalid_macro_export_arguments` upgraded to deny-by-default, reports in dependencies.

---

## Rust 1.93 (2026-01-22)

### Language

- Stabilized declaration of C-style variadic functions for `system` ABI.
- Emit error when using some keywords as `cfg` predicate.
- Stabilized `asm_cfg` — `#[cfg]` within `asm!` blocks.
- Const-evaluation: support copying pointers byte-by-byte.
- LUB coercions handle function item types and differing-safety functions correctly.
- Allow `const` items containing mutable references to `static` (very unsafe, but not always UB).
- New warn-by-default `const_item_interior_mutations` lint.
- New warn-by-default `function_casts_as_integer` lint.

### Compiler

- Stabilized `-Cjump-tables=bool`.

### Stabilized APIs

**MaybeUninit** (big category):
- `<[MaybeUninit<T>]>::assume_init_drop`
- `<[MaybeUninit<T>]>::assume_init_ref`, `assume_init_mut`
- `<[MaybeUninit<T>]>::write_copy_of_slice`
- `<[MaybeUninit<T>]>::write_clone_of_slice`

**Slices**:
- `<[T]>::as_array::<N>`, `as_mut_array::<N>`
- `<*const [T]>::as_array`, `<*mut [T]>::as_mut_array`

**String / Vec**:
- `String::into_raw_parts`
- `Vec::into_raw_parts`

**VecDeque**:
- `VecDeque::pop_front_if`, `pop_back_if`

**Integers**:
- `<iN>::unchecked_neg`, `unchecked_shl`, `unchecked_shr`
- `<uN>::unchecked_shl`, `unchecked_shr`

**Time**:
- `Duration::from_nanos_u128`

**Character constants**:
- `char::MAX_LEN_UTF8`, `char::MAX_LEN_UTF16`

**Formatting**:
- `std::fmt::from_fn`, `std::fmt::FromFn`

### Cargo

- `CARGO_CFG_DEBUG_ASSERTIONS` env var available in build scripts based on profile.
- `cargo tree --format` supports long-form variable names.
- `cargo clean --workspace`.

### Compatibility notes

- `#[test]` attribute on invalid targets (trait methods, types) is now an error, previously silently ignored.
- `cargo publish` no longer keeps `.crate` tarballs as final artifacts when `build.build-dir` is set.
- `deref_nullptr` lint upgraded from warn-by-default to deny-by-default.
- `BTreeMap::append` no longer overwrites existing keys (**behavior change**).
- Don't require `T: RefUnwindSafe` for `vec::IntoIter<T>: UnwindSafe`.

---

## Rust 1.94 (2026-03-05)

### Language

- Impls and impl items inherit `dead_code` lint level of corresponding traits/items.
- Stabilized 29 RISC-V target features (RVA22U64/RVA23U64 profiles).
- New warn-by-default `unused_visibilities` lint (for visibility on `const _`).
- Update to Unicode 17.
- Fix incorrect lifetime errors for closures.

### Stabilized APIs

**Slices**:
- `<[T]>::array_windows::<N>`
- `<[T]>::element_offset`

**LazyCell / LazyLock**:
- `LazyCell::get`, `get_mut`, `force_mut`
- `LazyLock::get`, `get_mut`, `force_mut`

**Conversions**:
- `impl TryFrom<char> for usize`

**Iterator**:
- `std::iter::Peekable::next_if_map`, `next_if_map_mut`

**x86 SIMD**:
- `avx512fp16` intrinsics (excluding those needing unstable `f16`)
- AArch64 NEON fp16 intrinsics (excluding those needing `f16`)

**Math constants**:
- `f32::consts::EULER_GAMMA`, `f64::consts::EULER_GAMMA`
- `f32::consts::GOLDEN_RATIO`, `f64::consts::GOLDEN_RATIO`

**Const-in-const**:
- `f32::mul_add`, `f64::mul_add` const

### Cargo

- Stabilized the `include` key in Cargo config — load additional config files.
- Stabilized `pubtime` field in registry index.
- Cargo parses TOML v1.1 for manifests.
- `CARGO_BIN_EXE_<crate>` available at runtime.

### Compatibility notes

- Forbid freely casting lifetime bounds of `dyn` types.
- Changes to closure pattern-matching precise captures (may affect borrow checker and Drop ordering).
- Standard library macros imported via prelude, not `#[macro_use]` injection — may cause ambiguity errors for glob-imported same-named macros.
- Shebangs not stripped in expression-context `include!`.
- Cross-crate visibility of ambiguous glob reexports.
- Windows: `SystemTime::checked_sub_duration` returns `None` for times before 1/1/1601.
- Lifetime identifiers NFC-normalized.
- Cross-compiler consistent filename handling — may affect Cargo diagnostic paths.
- Switch to `annotate-snippets` for compiler error emission (minor visual changes).

---

## How to use this changelog

- **Looking up when an API stabilized**: skim the "Stabilized APIs" section under each version.
- **Explaining a compat break**: check "Compatibility notes" for the version the user upgraded through.
- **MSRV planning**: decide based on which "Stabilized APIs" you'd want — the `rust-version` you need is the max across all of them.

For day-to-day "what modern API replaces this pattern" use, prefer the trigger table in [../SKILL.md](../SKILL.md) and the topic-specific references.
