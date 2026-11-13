# Result and error handling APIs

## `Result::flatten` — 1.89

**Replaces:** manual match / `.and_then(|x| x)` for `Result<Result<T, E>, E>`.

```rust
// Before
let x: Result<Result<i32, MyError>, MyError> = /* ... */;
let flat: Result<i32, MyError> = x.and_then(|inner| inner);
// or
let flat = match x {
    Ok(Ok(v)) => Ok(v),
    Ok(Err(e)) | Err(e) => Err(e),
};

// After (1.89+)
let flat: Result<i32, MyError> = x.flatten();
```

Matches `Option::flatten` (stable since 1.40). The outer `E` and inner `E` must be the same type.

### Common use sites

#### `try_join!` and `join!` returning nested Results

```rust
use tokio::try_join;

let (a, b) = try_join!(
    async { fetch_a().await },       // Result<A, Error>
    async { fetch_b().await }?,      // double-? pattern
)?;
```

With `flatten`:

```rust
let a: Result<A, Error> = outer_await().await.flatten();
```

#### `spawn_blocking` / thread handles

`JoinHandle::join()` returns `Result<T, JoinError>`, and if T is itself a Result you get `Result<Result<U, E>, JoinError>`. If `E: From<JoinError>`, you can flatten into a single result:

```rust
// Note: requires E: From<JoinError> conversion — often not the case directly
let outcome: Result<U, Error> = handle.await??;  // still the idiomatic double-?
```

The `flatten()` method only helps when both error types are already identical. For mixed error types, the `?` operator with `From` conversions is still the go-to.

## `Option::map_or_default` / `Result::map_or_default` — 1.98

**Replaces:** `.map(f).unwrap_or_default()` and `.map_or_else(Default::default, f)`.

```rust
// Before
let len = input.map(|s| s.len()).unwrap_or_default();
let len = input.map_or_else(usize::default, |s| s.len());

// After (1.98+)
let len = input.map_or_default(|s| s.len());
```

Works identically on `Result` (the `Err` value is discarded, like `Result::map_or`). Prefer it over `.map_or(0, f)`-style literals when the zero value genuinely is "the default" — the intent reads better and survives a type change. Keep an explicit literal when the fallback is a domain constant that just happens to equal the default.

## `bool::ok_or` / `bool::ok_or_else` — 1.98

**Bool-to-`Result` conversion in one step — replaces `then_some(()).ok_or(err)` and open-coded `if` blocks.**

```rust
// Before
if !path.exists() {
    return Err(Error::Missing);
}
// or the combinator spelling
path.exists().then_some(()).ok_or(Error::Missing)?;

// After (1.98+)
path.exists().ok_or(Error::Missing)?;           // Result<(), Error>
(buf.len() >= MIN).ok_or_else(|| Error::short(buf.len()))?;
```

Returns `Ok(())` when the bool is `true`, `Err(err)` when `false`. Mirrors `Option::ok_or` naming, so it reads naturally in `?` chains for precondition checks and validators. Use `ok_or_else` when constructing the error is non-trivial.

## Never type `!` in any type position — 1.100

**`!` is a first-class type: `Result<T, !>`, `type Error = !`, `Option<!>`. Replaces `std::convert::Infallible` and empty-enum stand-ins.**

```rust
// Before — a library type standing in for "cannot happen"
use std::convert::Infallible;

impl TryFrom<f64> for Meters {
    type Error = Infallible;
    fn try_from(v: f64) -> Result<Self, Infallible> { Ok(Meters(v)) }
}

// After (1.100+) — the language type; previously `!` was only allowed as `-> !`
impl TryFrom<f64> for Meters {
    type Error = !;
    fn try_from(v: f64) -> Result<Self, !> { Ok(Meters(v)) }
}

let Ok(m) = Meters::try_from(1.5); // irrefutable: the `Err` arm cannot exist
```

What to know when applying it:

- **`Infallible` is now `type Infallible = !`.** They are the same type, so `Result<T, Infallible>` and `Result<T, !>` are interchangeable in both directions and switching a signature is not a breaking change on 1.100+. The std docs prefer `!` unless older toolchains must be supported.
- **Unwrap by destructuring, not `?`.** There is no blanket `From<!> for T`: `r?` on a `Result<T, !>` compiles only if the target error type has its own `From<!>` / `From<Infallible>` impl. `let Ok(v) = r;` always works. `Result::into_ok` is still unstable.
- **`!` implements** `Debug`, `Display`, `Error`, `Clone`, `Copy`, `Eq`, `Ord`, `Hash`, and (new in 1.100) `AsRef<T>` / `AsMut<T>` — but **not `Default`**.
- **Coercion.** A value of type `!` coerces to any type, so `match never {}` scaffolding is no longer needed: `fn absurd(n: !) -> u32 { n }`.
- **Coherence.** A crate with both `impl Tr for Infallible` and `impl Tr for !` (typically a nightly-gated pair) now fails with E0119 — delete one.

Reach for `!` in trait impls whose associated error type can never occur (`FromStr`, `TryFrom`, infallible `Service`/`Handler` impls) and in generic code that wants the compiler to prove an arm unreachable. Keep `Infallible` while the MSRV is below 1.100.

### Compatibility: never type fallback is `!` on every edition

Editions 2015–2021 used to fall back to `()` when a diverging expression left a type variable unconstrained; 1.100 uses `!` everywhere (edition 2024 already did). Code that silently relied on `()` stops compiling:

```rust
fn load<T: Default>() -> Result<T, Error> { /* ... */ }

load()?;          // 1.100: error[E0277]: the trait bound `!: Default` is not satisfied
load::<()>()?;    // fix: name the type
```

Up to 1.99 this was the deny-by-default `dependency_on_unit_never_type_fallback` lint. The lint is removed in 1.100 — delete leftover `#[allow(dependency_on_unit_never_type_fallback)]` attributes, which now trigger `renamed_and_removed_lints`.

## `core::mem::DropGuard` — 1.100

**Run a closure on every scope exit — early `?` return, `break`, panic unwinding. Std replacement for the `scopeguard` crate and one-off `struct Guard; impl Drop` types.**

```rust
// Before — external crate (or a hand-written Drop type per call site)
let mut nums = scopeguard::guard(nums, |nums| nums.truncate(len));
// ...
scopeguard::ScopeGuard::into_inner(nums);

// After (1.100+)
use std::mem::DropGuard;

/// Parses all `strings` into `nums`; on failure `nums` is left unchanged.
fn parse_all(nums: &mut Vec<u32>, strings: &[&str]) -> Result<(), ParseIntError> {
    let len = nums.len();
    let mut nums = DropGuard::new(nums, move |nums| nums.truncate(len)); // rollback
    for s in strings {
        nums.push(s.parse()?); // early return drops the guard → closure runs
    }
    DropGuard::dismiss(nums);  // success: defuse, closure never runs
    Ok(())
}
```

`DropGuard<T, F: FnOnce(T)>` owns a value, derefs to it (`Deref` + `DerefMut`), and hands it to the closure by value on drop. `DropGuard::dismiss(guard) -> T` is an associated function (no clash with methods of `T`) that returns the value and drops the closure without calling it.

- A plain "defer" with no guarded value: `let _guard = DropGuard::new((), |()| cleanup());`.
- Bind it to a named variable. `let _ = DropGuard::new(..)` drops immediately and runs the closure on the spot.
- The closure runs during unwinding, but not on `process::exit`, `abort`, or `mem::forget`.
- There is no "only on unwind" / "only on success" mode — keep `scopeguard` if the code uses `guard_on_unwind` / `guard_on_success`.

Typical sites: all-or-nothing mutations, restoring a temporarily changed setting, releasing a resource acquired through FFI, and removing a partially written temp file.

## `Result<(), Uninhabited>` no longer triggers `unused_must_use` — 1.92

**Compatibility improvement.** If you have `Result<(), !>` or `Result<(), Infallible>` (the same type since 1.100), the compiler no longer warns when you drop it — because there's no error case to forget.

```rust
// Before — would trigger unused_must_use warning
fn infallible_op() -> Result<(), Infallible> { Ok(()) }
infallible_op();  // warning: unused Result

// After (1.92+)
infallible_op();  // no warning — no actual error to handle
```

Also applies to `ControlFlow<Uninhabited, ()>`.

Useful when you have a trait that returns `Result<T, E>` for flexibility, but a specific impl uses `Infallible`.

## `ControlFlow` is now `#[must_use]` — 1.87 (compatibility)

**Compatibility change.** `ControlFlow<B, C>` is now marked `#[must_use]`, so dropping it silently raises a warning.

If you were intentionally discarding the control flow from `try_fold` / `try_for_each`, you'll now get a warning. Usually indicates a bug — you probably meant to check whether the loop broke early.

```rust
// Now warns
let _ = items.iter().try_for_each(|x| process(x));

// Fix: check the result
if let ControlFlow::Break(early) = items.iter().try_for_each(process) {
    return early;
}
```

## `<str>::from_utf8` `const` — 1.87

`str::from_utf8` is now available in `const` contexts (previously needed `from_utf8_unchecked` with unsafe). Useful for building `&'static str` from bytes at compile time when validation is needed.

## `impl TryFrom<Vec<u8>> for String` — 1.87

See [collections.md](collections.md). Equivalent to `String::from_utf8`, reachable through the standard conversion trait.

## `PanicHookInfo::payload_as_str` — 1.91

In custom panic hooks, you can now get the panic payload as `&str` without manually downcasting:

```rust
std::panic::set_hook(Box::new(|info| {
    let msg = info.payload_as_str().unwrap_or("<non-string panic>");
    eprintln!("panic: {msg}");
    // ... send to crash reporter, etc.
}));
```

Before 1.91, you had to do `info.payload().downcast_ref::<&str>().or_else(|| info.payload().downcast_ref::<String>().map(|s| s.as_str()))` and similar gymnastics.

## General philosophy: prefer `?` over combinators for most error handling

These additions are useful, but the `?` operator with proper `From` impls on your error types remains the most idiomatic pattern. `flatten` and friends are for specific cases where you already have a nested structure and restructuring the call isn't an option.
