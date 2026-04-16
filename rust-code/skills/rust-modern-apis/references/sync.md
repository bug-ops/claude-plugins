# Synchronization and lazy init APIs

## `LazyLock::get` / `LazyCell::get` — 1.94

**Check initialization without forcing it.**

```rust
static COUNTER: LazyLock<Mutex<u64>> = LazyLock::new(|| Mutex::new(0));

// Before — no way to peek at state, always triggered init
let c = &*COUNTER;  // forces init

// After (1.94+)
if let Some(c) = COUNTER.get() {
    // only true if something else already initialized it
    *c.lock().unwrap() += 1;
}
```

Useful for diagnostics, conditional shutdown logic, and avoiding accidental eager initialization in test code.

## `LazyLock::get_mut` / `LazyCell::get_mut` — 1.94

**Mutable access to the cached value if already initialized, without forcing init.**

Returns `Option<&mut T>` rather than `&mut T` (the non-`get` version forces init and returns `&T`).

```rust
// Repopulate or clear a cache only if it was ever populated
if let Some(cache) = LAZY_CACHE.get_mut() {
    cache.clear();
}
```

Note: `get_mut` requires `&mut LazyLock<T>`, so it's mostly useful for `LazyLock` fields in structs (not globals).

## `LazyLock::force_mut` / `LazyCell::force_mut` — 1.94

**Force initialization AND return `&mut T`.** Combines `force()` + `get_mut().unwrap()`.

```rust
// Before
let _ = LazyLock::force(&mut lazy);
let val: &mut T = lazy.get_mut().unwrap();

// After (1.94+)
let val: &mut T = lazy.force_mut();
```

## `RwLockWriteGuard::downgrade` — 1.92

**Atomically convert an exclusive write lock to a shared read lock.**

```rust
use std::sync::RwLock;

let lock = RwLock::new(HashMap::new());

{
    let mut write = lock.write().unwrap();
    write.insert("key", "value");

    // Before — drop write, re-acquire read, but another writer could sneak in
    drop(write);
    let read = lock.read().unwrap();

    // After (1.92+) — atomic downgrade, no window for other writers
    let read = RwLockWriteGuard::downgrade(write);
    // read is now a RwLockReadGuard over the same data
}
```

### Important caveat

**Only available on `std::sync::RwLock`.** Not on:

- `tokio::sync::RwLock` — completely different lock type for async contexts
- `parking_lot::RwLock` — has its own `RwLockWriteGuard::downgrade` with similar semantics but a different import path
- `async-lock::RwLock`, `async-std::sync::RwLock` — separate ecosystems

Before suggesting `downgrade`, check the import. Most async Rust code uses `tokio::sync::RwLock`, where this does NOT apply.

## `Box::new_zeroed` / `Rc::new_zeroed` / `Arc::new_zeroed` — 1.92

## `Box::new_zeroed_slice` / `Rc::new_zeroed_slice` / `Arc::new_zeroed_slice` — 1.92

**Allocate zero-initialized memory on the heap without an intermediate stack buffer.**

```rust
// Before — creates on stack, copies to heap
let big: Box<[u8; 1_000_000]> = Box::new([0; 1_000_000]);  // stack overflow risk!

// After (1.92+) — allocates zeroed directly on the heap
let big: Box<MaybeUninit<[u8; 1_000_000]>> = Box::new_zeroed();
let big = unsafe { big.assume_init() };  // now Box<[u8; ...]>
```

### Key points

- Returns `Box<MaybeUninit<T>>`, not `Box<T>`. You must `assume_init` (unsafe) once you've confirmed the zero bit pattern is valid for `T`.
- Valid `T`s: types where all-zero is a valid value — integer types, `bool` (true for `false`), `Option<NonZero*>` (zeros to `None`), tuples/arrays/structs of these.
- Invalid `T`s: references (null is UB), `NonZero*` directly, enums without a zero discriminant.
- **For `unsafe_code = "deny"` projects**, this API is still useful for the slice form with primitives:

```rust
// Useful even under deny(unsafe_code):
let tensor_buf: Box<[f32]> = Box::new_zeroed_slice(1_000_000);
let tensor_buf = unsafe { tensor_buf.assume_init() };
// Only one unsafe block; the alternative required manual allocation or vec![0.0; N].into_boxed_slice()
// which zeroes via memset anyway, but goes through Vec first.
```

For deeply `unsafe_code = "deny"` codebases, `vec![0.0; n].into_boxed_slice()` is still the simplest alternative (the compiler optimizes the zero-fill to `memset`).

## `Default` for `Pin<Box<T>>` / `Pin<Rc<T>>` / `Pin<Arc<T>>` — 1.91

`Pin::default()` now works if the underlying `Box<T>`/`Rc<T>`/`Arc<T>` implements `Default`.

```rust
// Before
let p: Pin<Box<MyFuture>> = Box::pin(MyFuture::default());

// After (1.91+)
let p: Pin<Box<MyFuture>> = Default::default();
```

Small convenience. Mostly useful when types are inferred (e.g., `Self::default()` in a struct that contains a pinned field).

## `std::sync::Once::wait` / `Once::wait_force` — 1.86

## `OnceLock::wait` — 1.86

Block until a `Once` completes initialization (without triggering it from this thread). `wait_force` also panics if init fails.

Niche. Useful for coordinating initialization across many threads where non-leader threads want to block on leader completion.

## Tokio/parking_lot equivalents

If you're using `tokio::sync` or `parking_lot`, none of these std additions apply directly. Those crates have their own analogs:

- `parking_lot::OnceCell`, `parking_lot::RwLock::downgrade` (preexisting)
- `tokio::sync::OnceCell`
- `once_cell::sync::Lazy` — legacy, replaced by std `LazyLock` since 1.80

For projects with mixed sync and async code, keep the std versions for sync-only code paths.
