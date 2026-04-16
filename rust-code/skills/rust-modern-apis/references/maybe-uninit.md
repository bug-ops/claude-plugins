# MaybeUninit APIs

## Context

`MaybeUninit<T>` is Rust's safe tool for expressing "memory that exists but isn't initialized." It's the foundation for avoiding UB when doing manual memory management — writing before reading, handling partially-initialized arrays, implementing custom allocators, FFI boundaries.

1.93 stabilized several slice operations that make working with arrays of `MaybeUninit<T>` much less painful.

## `<[MaybeUninit<T>]>::assume_init_drop()` — 1.93

**Runs `Drop::drop` on every element, treating them as initialized.**

```rust
let mut buf: [MaybeUninit<String>; 5] = [const { MaybeUninit::uninit() }; 5];
// Initialize all 5 elements...
for slot in &mut buf {
    slot.write("hello".to_string());
}
// Clean up — drops all 5 Strings
unsafe { buf.as_mut_slice().assume_init_drop() };
```

Requires `unsafe` (caller promises all elements are actually initialized).

## `<[MaybeUninit<T>]>::assume_init_ref()` / `assume_init_mut()` — 1.93

**View the uninit slice as an initialized slice.** Transmute-like, but without raw pointers.

```rust
let mut buf: [MaybeUninit<u8>; 4] = [MaybeUninit::uninit(); 4];
buf[0].write(1);
buf[1].write(2);
buf[2].write(3);
buf[3].write(4);

let initialized: &[u8] = unsafe { buf.as_slice().assume_init_ref() };
assert_eq!(initialized, &[1, 2, 3, 4]);
```

Caller must ensure all elements are initialized. UB otherwise.

## `<[MaybeUninit<T>]>::write_copy_of_slice(&[T]) -> &mut [T]` — 1.93

**Bulk-initialize from a `Copy` source slice, return the initialized slice.**

```rust
let mut buf: [MaybeUninit<u8>; 4] = [MaybeUninit::uninit(); 4];
let src: &[u8] = b"abcd";
let written: &mut [u8] = buf.write_copy_of_slice(src);
assert_eq!(written, b"abcd");
```

Panics if lengths don't match. Safe — no `unsafe` needed, because `Copy` means there's no drop to worry about and all bytes are valid.

**Replaces:** manual loops + `ptr::copy_nonoverlapping` + `assume_init`.

## `<[MaybeUninit<T>]>::write_clone_of_slice(&[T]) -> &mut [T]` — 1.93

**Same as `write_copy_of_slice` but for `T: Clone` (non-Copy).**

```rust
let mut buf: [MaybeUninit<String>; 2] = [
    MaybeUninit::uninit(),
    MaybeUninit::uninit(),
];
let src = ["hello".to_string(), "world".to_string()];
let written: &mut [String] = buf.write_clone_of_slice(&src);
```

Handles panic safety correctly: if `Clone::clone` panics mid-loop, already-cloned elements are dropped before propagating. Manual implementations almost always get this wrong.

**This is a meaningful safety improvement** for custom collection implementations, growable buffers, ring buffers, etc. It replaces hand-written code that's historically been a source of UB bugs in the ecosystem.

## `Box::new_zeroed` / `Rc::new_zeroed` / `Arc::new_zeroed` — 1.92

## `Box::new_zeroed_slice` / `Rc::new_zeroed_slice` / `Arc::new_zeroed_slice` — 1.92

Covered in detail in [sync.md](sync.md). Summary here:

```rust
// Allocate large zero-initialized buffer directly on heap — no stack bounce
let buf: Box<[u8]> = Box::new_zeroed_slice(1_000_000);
let buf: Box<[u8]> = unsafe { buf.assume_init() };
```

Particularly useful for ML/tensor code where you need large zeroed buffers and want to avoid `vec![0.0; N].into_boxed_slice()` (which round-trips through `Vec` first).

## `MaybeUninit` representation — 1.92 (documentation clarification)

1.92 documented the exact representation of `MaybeUninit<T>`:

- Same size and alignment as `T`.
- Safe to transmute `&[MaybeUninit<T>; N]` ↔ `&[T; N]` IF all elements are initialized (though `assume_init_ref` is the blessed way).

No API change, but closes a spec gap. If you're reading crate code that transmutes arrays of `MaybeUninit`, the soundness is now officially blessed rather than "clearly intended."

## When to use MaybeUninit at all

- **Custom collections** where you grow capacity before filling (similar to `Vec`'s internal layout).
- **FFI** where a C function fills a buffer and returns the count written.
- **Performance-critical code** where eliminating the default-initialization pass matters (huge buffers, ML workloads).

For everyday code with `unsafe_code = "deny"`, you generally don't use `MaybeUninit` directly — these methods are escape hatches for the few `unsafe` blocks you do need.

## Relation to `Vec::spare_capacity_mut()` (preexisting)

`Vec::spare_capacity_mut() -> &mut [MaybeUninit<T>]` has been stable for a while. The new write methods above work directly on that slice, making the "fill spare capacity" pattern much cleaner:

```rust
let mut v: Vec<u8> = Vec::with_capacity(1024);
let spare = v.spare_capacity_mut();
let src: &[u8] = read_bytes();
let written = spare.write_copy_of_slice(&src[..spare.len()]);
unsafe { v.set_len(written.len()) };
```
