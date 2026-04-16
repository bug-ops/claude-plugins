# String and char APIs

## `str::floor_char_boundary(usize)` / `str::ceil_char_boundary(usize)` — 1.91

**Replaces:** manual loops finding UTF-8 byte boundaries for safe truncation.

### The problem

Slicing `&str` requires byte indices that fall on character boundaries. Blindly slicing at byte N panics if N is mid-character. Classic use cases: truncating to a display/protocol byte limit (Telegram 4096 chars, Discord 2000 chars, SMS 160 bytes, UI rendering).

### Usage

```rust
let s = "café";  // 5 bytes: c, a, f, 0xc3, 0xa9

// floor_char_boundary: rounds DOWN to the nearest char boundary
assert_eq!(s.floor_char_boundary(4), 3);  // byte 4 is mid-char, round down to 3
let safe = &s[..s.floor_char_boundary(4)]; // "caf"

// ceil_char_boundary: rounds UP
assert_eq!(s.ceil_char_boundary(4), 5);
let safe = &s[..s.ceil_char_boundary(4)]; // "café" (the full string)

// If the index is already on a boundary, it's returned as-is
assert_eq!(s.floor_char_boundary(3), 3);
assert_eq!(s.ceil_char_boundary(3), 3);

// Out-of-range: clamps to len() rather than panicking
assert_eq!(s.floor_char_boundary(100), s.len());
```

### Migration example

```rust
// Before — verbose and easy to get wrong
fn truncate_utf8(s: &str, max_bytes: usize) -> &str {
    if s.len() <= max_bytes {
        return s;
    }
    let mut end = max_bytes;
    while end > 0 && !s.is_char_boundary(end) {
        end -= 1;
    }
    &s[..end]
}

// After (1.91+)
fn truncate_utf8(s: &str, max_bytes: usize) -> &str {
    &s[..s.floor_char_boundary(max_bytes)]
}
```

### When to use which

- **`floor_char_boundary`** for truncation ("show at most N bytes"): always gives you ≤ N bytes.
- **`ceil_char_boundary`** for splitting/pagination where you'd rather include the partial char than split it: always gives you ≥ N bytes (or the full length if you'd exceed it).

## `char::MAX_LEN_UTF8` / `char::MAX_LEN_UTF16` — 1.93

**Replaces:** the magic numbers `4` and `2`.

```rust
// Before
let mut buf = [0u8; 4];  // max UTF-8 encoding length

// After (1.93+)
let mut buf = [0u8; char::MAX_LEN_UTF8];
```

Small change, but makes intent explicit in code that does UTF encoding/decoding.

## `<[T]>::array_windows::<N>() -> impl Iterator<Item = &[T; N]>` — 1.94

**Replaces:** `slice.windows(N)` where N is a compile-time constant.

### Why it's better than `.windows(N)`

`windows(N)` returns `&[T]` — a slice of runtime-known length N. You lose the type-level info. To index safely you still need length-matched indexing.

`array_windows::<N>()` returns `&[T; N]` — an array reference of exactly N elements. Direct field access by index, no panics possible.

```rust
let xs = [1, 2, 3, 4, 5];

// Before — slice, length known only at runtime
for w in xs.windows(3) {
    // w: &[i32] — even though we know it's length 3, the type doesn't
    println!("{} {} {}", w[0], w[1], w[2]);  // bounds checks
}

// After (1.94+) — array, length known at compile time
for w in xs.array_windows::<3>() {
    let [a, b, c] = w;  // destructure directly
    println!("{a} {b} {c}");  // no bounds checks needed
}
```

### Relation to `as_chunks` (1.88)

`array_chunks::<N>` / `as_chunks::<N>` was already stable — those are non-overlapping chunks. `array_windows` is the sliding (overlapping) variant. Pick based on whether windows overlap.

### Common use sites

- **N-gram analysis** (NLP, token windowing)
- **Delta analysis** (`array_windows::<2>()` to compute pairwise diffs)
- **Stateful parsers** with lookahead of fixed size
- **SIMD**: `array_windows::<4>()` or `::<8>()` lets you feed a fixed-size view into a vectorized kernel

## `<[T]>::ceil_char_boundary` parallel for slices

There's no slice equivalent — `ceil_char_boundary`/`floor_char_boundary` are `str`-specific because they rely on UTF-8 invariants.

## Related note: `unicode-width` is still separate

None of these replace the `unicode-width` / `unicode-segmentation` crates. If you need display width (e.g., for aligning terminal output with wide characters like CJK or emojis), you still need those crates. `floor_char_boundary` gives you safe byte-level cutoffs, not grapheme- or width-aware cutoffs.
