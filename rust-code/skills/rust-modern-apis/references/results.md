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

## `Result<(), Uninhabited>` no longer triggers `unused_must_use` — 1.92

**Compatibility improvement.** If you have `Result<(), !>` or `Result<(), Infallible>` (or the unstable `!`), the compiler no longer warns when you drop it — because there's no error case to forget.

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
