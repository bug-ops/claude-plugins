# Slice APIs

## `<[T]>::as_array::<N>() -> Option<&[T; N]>` — 1.93

## `<[T]>::as_mut_array::<N>() -> Option<&mut [T; N]>` — 1.93

## `<*const [T]>::as_array::<N>()` / `<*mut [T]>::as_mut_array::<N>()` — 1.93

**Replaces:** `slice.try_into::<[T; N]>()` where the length check is a runtime concern.

### Why it's better than `try_into`

`try_into` requires importing `TryFrom`/`TryInto`, returns `Result`, and often gets unwrapped immediately because the length is implied:

```rust
// Before
let header: [u8; 4] = bytes[0..4].try_into().unwrap();

// After (1.93+)
let header: &[u8; 4] = bytes[0..4].as_array::<4>().unwrap();
// or without borrowing:
let header: [u8; 4] = *bytes[0..4].as_array::<4>().unwrap();
```

### Subtle difference: borrow, not copy

`as_array` returns `Option<&[T; N]>` — a reference into the slice. `try_into` returns `[T; N]` by value (requires `T: Copy` typically). This matters:

- **Performance**: `as_array` is zero-cost; `try_into` may copy N elements.
- **Borrowing**: `as_array` keeps the slice borrowed, so you can't mutate the source during the array's lifetime.

If you actually need an owned array, dereference: `*slice.as_array::<N>().unwrap()` (requires `Copy`) or clone.

### Length mismatch

Returns `None` if the slice length isn't exactly N. For "at least N", use `split_first_chunk::<N>()` (stable earlier) or `as_chunks::<N>()`.

## `<[T]>::array_windows::<N>() -> impl Iterator<Item = &[T; N]>` — 1.94

See [strings.md](strings.md) for the full explanation — it's the overlapping-windows sibling of `array_chunks`/`as_chunks`.

## `<[T]>::as_chunks::<N>() -> (&[[T; N]], &[T])` — 1.88

## `<[T]>::as_chunks_mut::<N>()` — 1.88

## `<[T]>::as_rchunks::<N>()` / `<[T]>::as_rchunks_mut::<N>()` — 1.88

## `<[T]>::as_chunks_unchecked::<N>()` / `<[T]>::as_chunks_unchecked_mut::<N>()` — 1.88

**Compile-time-sized non-overlapping chunks.**

Returns a tuple: `(chunks_array, remainder_slice)`. The chunks are `&[[T; N]]` — a slice of arrays, not a slice of slices. Direct indexing by chunk without bounds checks on the inner array.

```rust
let bytes = [1, 2, 3, 4, 5, 6, 7];
let (chunks, rest) = bytes.as_chunks::<3>();
assert_eq!(chunks, &[[1, 2, 3], [4, 5, 6]]);
assert_eq!(rest, &[7]);

for chunk in chunks {
    let [a, b, c] = chunk;  // direct destructure, compile-time-known size
}
```

`as_rchunks` aligns from the end rather than the start — remainder is at the front. Pick based on which end of the slice is "ragged."

`unchecked` variants assume the slice length is a multiple of N; UB if not. Only use in `unsafe` blocks with a proven invariant.

### Replaces

```rust
// Before — type is &[T], length lost at type level
for chunk in slice.chunks_exact(N) {
    // chunk: &[T]
    process(chunk.try_into::<[T; N]>().unwrap());
}

// After — type is &[T; N], no conversion needed
let (chunks, _remainder) = slice.as_chunks::<N>();
for chunk in chunks {
    process(chunk);
}
```

## `<[T]>::split_off` / `split_off_mut` / `split_off_first` / `split_off_first_mut` / `split_off_last` / `split_off_last_mut` — 1.87

**Slice-variant of `Vec::split_off`, but returns `Option<&[T]>` rather than mutating the slice.**

Often shorter than manual index juggling:

```rust
// Before
let (head, tail) = slice.split_at(slice.len() - 1);
let last = tail.first().unwrap();

// After (1.87+)
let last = slice.split_off_last().unwrap();  // or split_last (preexisting)
```

Note: `split_last` / `split_first` already existed. The `_off` variants sometimes fit different mutation patterns.

## `<[T]>::element_offset(&T) -> Option<usize>` — 1.94

**Index of an element given a reference into the slice.**

```rust
let v = vec![10, 20, 30, 40];
let r: &i32 = &v[2];
assert_eq!(v.element_offset(r), Some(2));

// Reference not into the slice:
let other = 99;
assert_eq!(v.element_offset(&other), None);
```

Returns `None` if the reference doesn't point into the slice. Useful in visitor/callback patterns where you have a reference and need to know its position without tracking the index explicitly.

## `[T; N]::each_ref` / `each_mut` — const now — 1.91

Existing `each_ref`/`each_mut` methods are now usable in `const` contexts.

```rust
const REFS: [&i32; 3] = [&1, &2, &3].each_ref();  // now const
```

## MaybeUninit slice operations — see [maybe-uninit.md](maybe-uninit.md)

Several methods like `assume_init_drop`, `assume_init_ref`, `assume_init_mut`, `write_copy_of_slice`, `write_clone_of_slice` on `<[MaybeUninit<T>]>` were stabilized in 1.93. See the dedicated reference.
