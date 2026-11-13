# Custom allocator APIs

## Context

Rust 1.100 stabilized the core of the long-unstable `allocator_api`: the `Allocator` trait and allocator-aware `Box<T, A>` and `Vec<T, A>`. It is deliberately an MVP — everything else moved to the still-unstable `allocator_ext` feature (see "What is NOT stable" below). Before 1.100, stable code needed the `allocator-api2` polyfill crate or allocator-specific collection types such as `bumpalo::collections::Vec`.

This is per-value allocation. Swapping the process-wide allocator (`#[global_allocator]` with mimalloc/jemalloc) is still `GlobalAlloc` and unchanged.

## `std::alloc::Allocator` — 1.100

**An `unsafe trait` for allocators that are chosen per `Box`/`Vec` instance.**

```rust
pub unsafe trait Allocator {
    // required
    fn allocate(&self, layout: Layout) -> Result<NonNull<[u8]>, AllocError>;
    unsafe fn deallocate(&self, ptr: NonNull<u8>, layout: Layout);

    // provided (default: allocate + copy + deallocate)
    fn allocate_zeroed(&self, layout: Layout) -> Result<NonNull<[u8]>, AllocError>;
    unsafe fn grow(&self, ptr: NonNull<u8>, old_layout: Layout, new_layout: Layout)
        -> Result<NonNull<[u8]>, AllocError>;
    unsafe fn grow_zeroed(&self, ptr: NonNull<u8>, old_layout: Layout, new_layout: Layout)
        -> Result<NonNull<[u8]>, AllocError>;
    unsafe fn shrink(&self, ptr: NonNull<u8>, old_layout: Layout, new_layout: Layout)
        -> Result<NonNull<[u8]>, AllocError>;
}
```

How it differs from `GlobalAlloc`:

- Failure is `Err(AllocError)`, not a null pointer. `AllocError` is a stable unit struct implementing `Error`.
- `allocate` returns `NonNull<[u8]>` — the block may be larger than requested, and the slice length is its real size.
- Zero-sized layouts are legal and the implementation must handle them.
- Every method takes `&self`, so a stateful allocator needs interior mutability.
- The allocating and deallocating methods must not unwind.

Stable implementors: `Global` (the registered global allocator, the default `A`), `System`, `&A`, `&mut A`, and `Box<T, A>` / `Rc<T, A>` / `Arc<T, A>` where `T: Allocator`. So a shared pool can be passed as `&pool` or `Arc<Pool>`, and `&dyn Allocator` / `Box<dyn Allocator>` work as type-erased handles.

## `Box::new_in` / `Vec::new_in` / `Vec::with_capacity_in` — 1.100

**Place a single `Box` or `Vec` in a specific allocator.**

```rust
// Before (stable) — polyfill crate with its own Box/Vec types
use allocator_api2::{boxed::Box, vec::Vec};
let v: Vec<u32, &Arena> = Vec::with_capacity_in(8, &arena);

// After (1.100+) — the std types
use std::alloc::System;

let five: Box<i32, System> = Box::new_in(5, System);
let mut v: Vec<u32, &Arena> = Vec::with_capacity_in(8, &arena);
v.extend([1, 2, 3]);
let node: Box<dyn Node, &Arena> = Box::new_in(Leaf(1), &arena); // unsizing works
```

`Vec<T>` is `Vec<T, Global>` and `Box<T>` is `Box<T, Global>`; existing code is unaffected. `Box::allocator(&b)` (associated function) and `vec.allocator()` return `&A`.

### Minimal arena

```rust
use std::alloc::{AllocError, Allocator, Layout};
use std::cell::{Cell, UnsafeCell};
use std::ptr::NonNull;

struct Arena {
    buf: UnsafeCell<[u8; 4096]>,
    used: Cell<usize>,
}

// SAFETY: blocks stay valid while the `&Arena` borrow lives; nothing is reused.
unsafe impl Allocator for &Arena {
    fn allocate(&self, layout: Layout) -> Result<NonNull<[u8]>, AllocError> {
        let start = self.used.get().next_multiple_of(layout.align());
        let end = start.checked_add(layout.size()).ok_or(AllocError)?;
        if end > 4096 {
            return Err(AllocError);
        }
        self.used.set(end);
        // SAFETY: `start <= 4096`, so the pointer stays inside the buffer.
        let ptr = unsafe { NonNull::new_unchecked(self.buf.get().cast::<u8>().add(start)) };
        Ok(NonNull::slice_from_raw_parts(ptr, layout.size()))
    }

    unsafe fn deallocate(&self, _ptr: NonNull<u8>, _layout: Layout) {}
}
```

Implement the trait on a reference, a zero-sized handle, or a smart pointer — not on a type that owns its buffer inline. A `Vec<T, Arena>` holding the arena by value would move the buffer every time the `Vec` moves, leaving its own pointer dangling.

## Raw-parts round trips with the allocator — 1.100

**The allocator-carrying forms of `into_raw`/`from_raw` (1.99 added the `NonNull` forms for `Global`).**

```rust
let (ptr, alloc): (*mut T, A) = Box::into_raw_with_allocator(b);
let b = unsafe { Box::from_raw_in(ptr, alloc) };

let (ptr, alloc): (NonNull<T>, A) = Box::into_non_null_with_allocator(b);
let b = unsafe { Box::from_non_null_in(ptr, alloc) };

let (ptr, len, cap, alloc) = v.into_parts_with_allocator();      // NonNull<T>
let v = unsafe { Vec::from_parts_in(ptr, len, cap, alloc) };

let (ptr, len, cap, alloc) = v.into_raw_parts_with_allocator();  // *mut T
let v = unsafe { Vec::from_raw_parts_in(ptr, len, cap, alloc) };
```

The memory must be handed back to the same allocator or an *equivalent* one (the trait docs define equivalence: a reference or smart pointer to an allocator is equivalent to it; all `Global` instances are equivalent). Rebuilding with a different allocator is undefined behavior.

## What is NOT stable in 1.100

Checked against a 1.100.0 toolchain — each of these fails to compile on stable:

- `Rc::new_in`, `Arc::new_in`, `VecDeque::new_in` and the `_in` constructors of every other collection (feature `allocator_ext`). `String` has no allocator parameter at all.
- Fallible and uninit constructors: `Box::try_new_in`, `Box::new_uninit_in`, `Box::pin_in`, `Vec::try_with_capacity_in`.
- `collect()` into `Vec<T, A>` for a non-`Global` `A` — `FromIterator` exists only for `Global`. Build with `Vec::with_capacity_in` + `extend`.
- `Default` for `Box<T, A>` / `Vec<T, A>` with a non-`Global` `A`; `vec![in alloc; ..]` syntax; `Vec::new_in` in `const` context.

`Clone` for `Box<T, A>` and `Vec<T, A>` requires `A: Clone`.

## When to suggest it

- **Arena / bump allocation** for request- or frame-scoped data freed all at once.
- **Pool or fixed-buffer allocation** in embedded and real-time code, where the global heap is unavailable or unpredictable.
- **Instrumented allocators** in tests and benchmarks — count or cap the allocations of one data structure without touching the global allocator.
- **Dropping the `allocator-api2` polyfill** when MSRV reaches 1.100 and only `Box`/`Vec` are used. Before swapping, check that the arena crate in use implements the std trait (often behind a feature flag).

## When NOT to suggest it

- The goal is a faster allocator for the whole program — that is `#[global_allocator]`.
- The code needs `Rc`, `Arc`, `String`, `VecDeque`, or map types in the allocator — keep the polyfill or arena-crate collections until `allocator_ext` stabilizes.
- A public API would gain an `A: Allocator` parameter without a concrete user. A function taking `&mut Vec<T>` does not accept `Vec<T, A>`; prefer `&mut [T]` at boundaries, and add the parameter only for a demonstrated need.

## Compatibility note

Several `Box` trait impls were generalized over the allocator in 1.100. Code that relied on inference picking `Global` can now fail with "type annotations needed" — annotate the binding as `Box<T>`.
