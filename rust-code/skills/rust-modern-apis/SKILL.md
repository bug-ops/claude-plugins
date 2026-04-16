---
name: rust-modern-apis
description: Reference for stable Rust APIs added in versions 1.89 through 1.94 (August 2025 - March 2026). Use this skill whenever writing, reviewing, or refactoring Rust code — especially when you notice patterns that were verbose before newer APIs existed, when MSRV allows it, or when the user mentions modernizing Rust code, upgrading MSRV, or using "the latest Rust features". Also trigger when reviewing Rust code for improvements, migrations, or when a user asks "can this be simpler in modern Rust?" Proactively suggest newer APIs when you see patterns like manual UTF-8 truncation, path extension manipulation, advisory file locking via external crates, ignoring `retain` removal results, or verbose `try_into().unwrap()` for fixed arrays.
---

# Modern Rust APIs (1.89 – 1.94)

This skill is a lookup table for stable Rust APIs added after 1.88. Use it when writing or reviewing Rust code — replace older verbose patterns with newer concise ones where the project's MSRV allows.

## How to use this skill

1. **Check the project's MSRV first.** Look at `Cargo.toml` for `rust-version = "X.Y"`. Only suggest APIs available at or below the MSRV. If MSRV is lower than an API's version, either skip the suggestion or note that "raising MSRV to X.Y unlocks this."

2. **Scan the code for trigger patterns** (see section below). Each trigger maps to a newer API. When you see one, suggest the replacement with a brief before/after.

3. **For detailed API info**, read the matching reference file in `references/`. Files are organized by domain, not by version.

4. **Don't over-apply.** Some patterns are fine as-is. Only suggest a change when the new API is clearly better (shorter, safer, or fixes a subtle bug).

## Trigger patterns — fastest lookup

Scan for these code shapes first. Each points to a concrete API that replaces it.

| Code pattern spotted | Modern replacement | Version | Details |
|----------------------|-------------------|---------|---------|
| `Duration::from_secs(60 * N)` or ad-hoc minute math | `Duration::from_mins(N)` | 1.91 | [time.md](references/time.md) |
| `Duration::from_secs(60 * 60 * N)` | `Duration::from_hours(N)` | 1.91 | [time.md](references/time.md) |
| `path.with_extension("X.tmp")` (trying to ADD suffix) | `path.with_added_extension("tmp")` | 1.91 | [paths.md](references/paths.md) |
| Manual `file_stem` + `format!` to compose meta paths | `path.with_added_extension(...)` | 1.91 | [paths.md](references/paths.md) |
| `file_stem()` returning wrong thing for `.tar.gz` | `Path::file_prefix()` | 1.91 | [paths.md](references/paths.md) |
| `path.to_string_lossy() == "literal"` | `path == Path::new("literal")` or `path == "literal"` | 1.91 | [paths.md](references/paths.md) |
| `Ipv4Addr::new(a, b, c, d)` from `[u8; 4]` | `Ipv4Addr::from_octets(bytes)` | 1.91 | [net.md](references/net.md) |
| `Ipv6Addr::new(a, b, c, d, e, f, g, h)` from segments | `Ipv6Addr::from_segments(segs)` | 1.91 | [net.md](references/net.md) |
| Manual `is_char_boundary` loop for UTF-8 truncation | `str::floor_char_boundary(n)` / `ceil_char_boundary(n)` | 1.91 | [strings.md](references/strings.md) |
| `checked_add(x).unwrap()` where overflow = bug | `strict_add(x)` | 1.91 | [arithmetic.md](references/arithmetic.md) |
| `iter.into_iter().chain(other)` as free pattern | `std::iter::chain(iter, other)` | 1.91 | [iterators.md](references/iterators.md) |
| `[val; N]` requiring `Copy` for non-Copy types | `core::array::repeat(val)` | 1.91 | [iterators.md](references/iterators.md) |
| `retain` where you need to see/count removed items | `extract_if(..)` (Vec since 1.87, BTree since 1.91) | 1.87+ | [collections.md](references/collections.md) |
| `fs2::FileExt::try_lock_exclusive` or custom lock | `File::try_lock()` / `File::lock()` | 1.89 | [io-files.md](references/io-files.md) |
| External `pid-lock`/`fd-lock` crate | Built-in `File::lock` | 1.89 | [io-files.md](references/io-files.md) |
| `Result<Result<T, E>, E>` manual flatten | `Result::flatten()` | 1.89 | [results.md](references/results.md) |
| `slice.try_into::<[T; N]>().unwrap()` | `slice.as_array::<N>()` / `as_mut_array::<N>()` | 1.93 | [slices.md](references/slices.md) |
| `slice.windows(N)` with const N giving `&[T]` | `slice.array_windows::<N>()` giving `&[T; N]` | 1.94 | [slices.md](references/slices.md) |
| `write_copy_of_slice` / `write_clone_of_slice` on `MaybeUninit` | Stabilized `<[MaybeUninit<T>]>::write_copy_of_slice` | 1.93 | [maybe-uninit.md](references/maybe-uninit.md) |
| One-off `impl Display` for temporary formatter | `std::fmt::from_fn(|f| ...)` | 1.93 | [formatting.md](references/formatting.md) |
| `pop()` then `if !cond { push_back }` | `pop_front_if(cond)` / `pop_back_if(cond)` | 1.93 (VecDeque), 1.86 (Vec) | [collections.md](references/collections.md) |
| Checking `LazyLock` was initialized without blocking | `LazyLock::get()` / `LazyCell::get()` | 1.94 | [sync.md](references/sync.md) |
| Mutating `LazyLock` after init with `&mut` access | `LazyLock::force_mut()` / `get_mut()` | 1.94 | [sync.md](references/sync.md) |
| `peekable.peek().filter(...).map(...)` with consume | `peekable.next_if_map(|v| ...)` | 1.94 | [iterators.md](references/iterators.md) |
| `duration.as_nanos() > u64::MAX` concerns | `Duration::from_nanos_u128(n)` | 1.93 | [time.md](references/time.md) |
| Magic number `4` for UTF-8 byte length | `char::MAX_LEN_UTF8` | 1.93 | [strings.md](references/strings.md) |
| Magic number `2` for UTF-16 unit length | `char::MAX_LEN_UTF16` | 1.93 | [strings.md](references/strings.md) |
| `BTreeMap`/`BTreeSet` full scan to evict | `BTreeMap::extract_if(..)` / `BTreeSet::extract_if(..)` | 1.91 | [collections.md](references/collections.md) |
| `Default` not implemented for `Pin<Box<T>>` etc | Now works for `Pin<Box<T>>`, `Pin<Rc<T>>`, `Pin<Arc<T>>` | 1.91 | [sync.md](references/sync.md) |
| Unsafe `Box::new(MaybeUninit::zeroed().assume_init())` | `Box::new_zeroed()` (unsafe-free alternative) | 1.92 | [maybe-uninit.md](references/maybe-uninit.md) |

## Version → MSRV gate

When suggesting an API, check MSRV first. Quick reference:

- **MSRV 1.87+**: `Vec::extract_if`, `LinkedList::extract_if`
- **MSRV 1.88+**: `HashMap::extract_if`, `HashSet::extract_if`
- **MSRV 1.89+**: `File::lock` family, `Result::flatten`, `NonNull::from_ref`/`from_mut`
- **MSRV 1.90+**: unsigned `checked_sub_signed`, `CStr` cross-comparisons, `lld` default linker on Linux
- **MSRV 1.91+**: `Duration::from_mins`/`from_hours`, `Path` API expansion, `strict_*` arithmetic, `BTreeMap/Set::extract_if`, `ceil_char_boundary`, `iter::chain`, `array::repeat`, `Ipv*::from_octets`
- **MSRV 1.92+**: `RwLockWriteGuard::downgrade` (std only), `Box/Arc/Rc::new_zeroed`, `NonZero::div_ceil`
- **MSRV 1.93+**: `slice::as_array`, `fmt::from_fn`, `VecDeque::pop_front_if`/`pop_back_if`, `String::into_raw_parts`, `Vec::into_raw_parts`, `Duration::from_nanos_u128`, `char::MAX_LEN_UTF8`/`MAX_LEN_UTF16`, `MaybeUninit` slice API, `asm_cfg`
- **MSRV 1.94+**: `slice::array_windows`, `LazyCell/Lock::get/get_mut/force_mut`, `Peekable::next_if_map`, `TryFrom<char> for usize`

Full changelog by version lives in [references/changelog.md](references/changelog.md) if you need to explain a release to the user or find something not in the trigger table.

## When a suggestion is NOT appropriate

Don't push the replacement if:

- **MSRV forbids it.** If `rust-version = "1.88"` and the API needs 1.91, either flag the MSRV gap or stay silent — don't produce code that won't compile.
- **Unsafe rules forbid it.** If the project has `unsafe_code = "deny"` (check `Cargo.toml` `[workspace.lints]`), skip APIs that require `unsafe` blocks even if they'd be shorter — e.g., `Box::new_zeroed` returns `Box<MaybeUninit<T>>` and requires `unsafe { assume_init() }` afterward.
- **The old pattern is load-bearing.** Sometimes `retain` with a side effect inside the closure is intentional for atomicity under a lock. Read the surrounding code before proposing `extract_if`.
- **The types don't match.** `tokio::sync::RwLock` does not have `downgrade` — that's `std::sync::RwLock` only. Similarly, `parking_lot::RwLock` has its own upgrade/downgrade API, not the std one.
- **Context is a test or benchmark.** Low value to change test code for style alone unless the test is flaky because of the old pattern.

## Migration mode: how to present changes

When you find a replacement candidate in code, present it as a before/after diff with a one-line "why":

```rust
// Before: with_extension replaces the last suffix, so for `foo.jsonl` → `foo.tmp` — fragile for paths like `foo.jsonl.gz`
let tmp = path.with_extension("tmp");

// After (MSRV 1.91+): adds a suffix without replacing; works for any path
let tmp = path.with_added_extension("tmp");
```

Don't produce walls of diffs for trivial cosmetic changes. Batch suggestions logically (all time/duration in one section, all path handling in another) if there are many.

## Reference files

Read these only when you need the details. Each file covers one domain across all versions:

- [references/changelog.md](references/changelog.md) — full release notes by version (1.89-1.94) — use when the user asks about a specific release
- [references/paths.md](references/paths.md) — `Path`/`PathBuf` API additions (1.91 mainly)
- [references/strings.md](references/strings.md) — `str` and `char` additions
- [references/time.md](references/time.md) — `Duration` additions
- [references/arithmetic.md](references/arithmetic.md) — integer arithmetic (`strict_*`, `unchecked_*`, `carrying_*`, etc.)
- [references/iterators.md](references/iterators.md) — iterator/chain/array helpers
- [references/collections.md](references/collections.md) — Vec/VecDeque/BTree/HashMap additions
- [references/slices.md](references/slices.md) — `[T]` and `[MaybeUninit<T>]` APIs
- [references/io-files.md](references/io-files.md) — `File::lock`, pipe, seek additions
- [references/sync.md](references/sync.md) — `LazyLock`, `RwLock`, `Pin<Box<T>>` Default, `Box::new_zeroed`
- [references/net.md](references/net.md) — IP address constructors and network APIs
- [references/formatting.md](references/formatting.md) — `fmt::from_fn`, debug formatting changes
- [references/results.md](references/results.md) — `Result::flatten` and error-handling additions
- [references/maybe-uninit.md](references/maybe-uninit.md) — `MaybeUninit` slice operations
- [references/compiler-cargo.md](references/compiler-cargo.md) — rustc/Cargo improvements (lld default, build-dir, etc.) that don't require code changes but affect builds
