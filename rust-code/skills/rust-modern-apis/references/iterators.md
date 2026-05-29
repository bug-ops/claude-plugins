# Iterator APIs

## `std::iter::chain(a, b)` — 1.91

**Free function form of `a.into_iter().chain(b)`.**

```rust
// Before
let combined = xs.into_iter().chain(ys.into_iter());

// After (1.91+)
let combined = std::iter::chain(xs, ys);
```

Useful when you want `chain` at the start of a pipeline rather than hanging off one of the operands. Parallels `iter::once`, `iter::empty`, `iter::repeat`.

## `core::array::repeat::<const N: usize, T: Clone>(val: T) -> [T; N]` — 1.91

**Replaces:** `[val.clone(), val.clone(), val.clone(), ...]` or `[val; N]` for non-`Copy` types.

```rust
// Before — won't compile for non-Copy
let v: [String; 3] = ["x".to_string(); 3];  // error: String is not Copy

// After (1.91+)
let v: [String; 3] = core::array::repeat("x".to_string());
```

For `Copy` types, plain `[val; N]` is still shorter. Use `array::repeat` specifically when `T: Clone` but not `Copy`.

Complements `std::iter::repeat` (infinite iterator) and `[T; N]::from_fn` (generate by index).

## `Peekable::next_if_map` / `next_if_map_mut` — 1.94

**Conditional `next` with transformation.**

```rust
// Before
let parsed = if let Some(&tok) = tokens.peek() {
    if let Some(n) = tok.as_number() {
        tokens.next();
        Some(n)
    } else {
        None
    }
} else {
    None
};

// After (1.94+)
let parsed = tokens.next_if_map(|tok| tok.as_number());
```

Advances the iterator only if the closure returns `Some`. The `_mut` variant passes `&mut item` to the closure, useful when the transformation needs to take ownership of part of the peeked value.

Matches the pattern of `Option::and_then` for iterators. Big readability win in hand-written parsers.

## `<iN>::midpoint` and related — 1.91

See [arithmetic.md](arithmetic.md).

## `iter::Repeat::last` / `iter::Repeat::count` panic behavior — 1.92

**Compatibility note.** Previously these would loop infinitely. Now they panic (because "last item of infinite iterator" is meaningless). If your code somehow did `iter::repeat(x).last()` expecting it to hang — it'll now panic. Almost certainly this was a bug.

## `TryFrom<char> for usize` — 1.94

Directly convert characters to `usize` when needed:

```rust
let c = '7';
let digit: usize = (c as u32).try_into().unwrap();  // Before — via u32

// After (1.94+)
let digit: usize = c.try_into().unwrap();
```

Minor convenience. The `char as u32` route still works and is shorter for the common case.

## `impl Default for array::IntoIter` — 1.89

Creates an empty iterator without needing `[T; 0].into_iter()`:

```rust
// Before
let empty: array::IntoIter<i32, 0> = [].into_iter();

// After (1.89+)
let empty: array::IntoIter<i32, 0> = Default::default();
```

Useful in generic contexts where you need to return an empty iterator of a specific type.

## `impl Clone for slice::ChunkBy` — 1.89

`ChunkBy` (the iterator returned by `slice::chunk_by`) now implements `Clone`. Lets you iterate twice or pass iterator clones to multiple consumers without re-computing the grouping.

## Specialized `Iterator::eq` / `eq_by` for `TrustedLen` — 1.92

Internal optimization — no API change. Iterator equality is now faster when both sides implement `TrustedLen` (most std iterators with known length). No code change needed; you just get the speedup for free.

## `impl Extend<Group/Literal/Punct/Ident> for TokenStream` — 1.92

For proc-macro authors: `TokenStream` can now be extended directly from token components without constructing intermediate `TokenTree`s.

```rust
let mut stream = TokenStream::new();
stream.extend([Literal::i32_unsuffixed(42)]);  // direct
```

## `allow storing format_args!() in a variable` — 1.89

**Small but significant.** Previously `format_args!` returned a value you couldn't name. Now you can:

```rust
let msg = format_args!("status: {}", status);
writeln!(out, "{msg}")?;
writeln!(log, "{msg}")?;
```

Avoids double-formatting when you need the same formatted output in multiple sinks. No heap allocation (unlike `format!`).

## `core::range` Copy-able range types — 1.95 / 1.96

**New range types that are `Copy` because they implement `IntoIterator` instead of `Iterator`.**

The classic `a..b` (`std::ops::Range`) is its own iterator, so it can't be `Copy` (iterating mutates it) and can't sit in a `Copy` struct. RFC 3550 splits the range from its iterator state. The replacements live in `core::range`:

| Syntax / role | `core::range` type | Iterator state | Stable since |
|---------------|--------------------|----------------|--------------|
| `a..=b`       | `RangeInclusive`   | `RangeInclusiveIter`   | 1.95 |
| `a..b`        | `Range`            | `RangeIter`            | 1.96 |
| `a..`         | `RangeFrom`        | `RangeFromIter`        | 1.96 |
| `..=b`        | `RangeToInclusive` | `RangeToInclusiveIter` | 1.96 |

```rust
use core::range::Range;

// Before — std::ops::Range is not Copy, so this struct can't derive Copy
struct Window { span: std::ops::Range<usize> }  // no Copy

// After (1.95/1.96+) — core::range::Range is Copy
#[derive(Clone, Copy)]
struct Window { span: Range<usize> }

let w = Window { span: Range::from(2..5) };
for i in w.span { /* ... */ }   // IntoIterator yields RangeIter; w.span still usable
```

Not a drop-in replacement everywhere — `..` literals and indexing still produce the `std::ops` types, and you convert with `From`/`into()`. Reach for `core::range::*` specifically when you need a range stored in a `Copy` type or passed by value repeatedly without re-cloning.

### NonZero range iteration — 1.96

Ranges bounded by `NonZero<uN>`/`NonZero<iN>` now iterate directly. Niche, but it removes the old dance of mapping over a primitive range and re-wrapping each element with `NonZero::new(..).unwrap()`.
