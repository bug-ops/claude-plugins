# Integer arithmetic APIs

## `bool: TryFrom<{integer}>` — 1.95

**Strict integer-to-bool conversion that fails on anything other than 0 or 1.**

```rust
// Before — easy to write the wrong thing
let b: bool = (n != 0);                  // accepts any non-zero (lossy)
let b: bool = matches!(n, 0 | 1);        // not a bool, just true/false
let b: bool = match n { 0 => false, 1 => true, _ => return Err(...) };

// After (1.95+) — one expression, explicit error on invalid input
let b: bool = bool::try_from(n)?;
```

Stabilized for all integer widths: `TryFrom<u8>`, `TryFrom<u16>`, `TryFrom<u32>`, `TryFrom<u64>`, `TryFrom<u128>`, `TryFrom<usize>`, and the signed equivalents.

### When to use

Reach for `bool::try_from(n)` when:
- The integer encodes a boolean field at a wire/storage boundary (protocol bytes, database columns, FFI).
- Any value other than 0/1 is a corrupt-input error — propagate, don't coerce.

Stick with `n != 0` when:
- The semantics genuinely are "non-zero means true" (C-style truthiness in legacy interop).
- Keep the lossy conversion explicit at the call site.

The `TryFromIntError` produced has no payload (zero-sized), so the cost is exactly the branch — same as a manual match.

## `strict_*` family — 1.91

**Replaces:** `checked_*().unwrap()` or `checked_*().expect("overflow")`.

Stabilized: `strict_add`, `strict_sub`, `strict_mul`, `strict_div`, `strict_div_euclid`, `strict_rem`, `strict_rem_euclid`, `strict_neg`, `strict_shl`, `strict_shr`, `strict_pow`, plus mixed-signedness variants (`i{N}::strict_add_unsigned`, `u{N}::strict_add_signed`, `i{N}::strict_abs`, etc.).

### Semantics

- **In debug builds**: panics on overflow (same as default `+`, `-`, `*`).
- **In release builds**: still panics. This is the key difference from default wrapping ops — no UB, no silent wrap.

```rust
// Before
let total = a.checked_add(b).expect("total overflow");

// After (1.91+) — same behavior, clearer intent
let total = a.strict_add(b);
```

### When to prefer over `checked_*`

Use `strict_*` when:
- You're certain overflow indicates a bug (not a recoverable condition).
- You want uniform "panic on overflow" behavior across debug and release.
- The code benefits from reading as straightforward arithmetic, not as a fallible operation.

Use `checked_*` when:
- Overflow is a recoverable error (you return `None`/`Err`).
- You need to branch on success/failure.

Use `wrapping_*` / `overflowing_*` when:
- Wrapping is the intended behavior (cryptographic ops, fixed-point arithmetic, hash functions).

Use `saturating_*` when:
- Clamping to `MIN`/`MAX` is the correct semantic.

### Security-sensitive code

In sanitizer/vault/crypto paths, `strict_*` is often the right choice: "if this overflows, we have a bug or a malicious input — halt." It makes the security contract explicit. `checked_*().unwrap()` communicates the same thing but requires the reader to parse two operations.

## `<iN>::strict_add_unsigned` / `<uN>::strict_add_signed` — 1.91

Mixed-sign arithmetic that would otherwise require casts:

```rust
let base: i32 = 100;
let offset: u32 = 50;

// Before
let r = base.checked_add(i32::try_from(offset).ok()?).ok_or(Error::Overflow)?;

// After (1.91+)
let r = base.strict_add_unsigned(offset);  // panics on overflow OR sign issue
```

Similarly `checked_add_signed`, `overflowing_add_signed`, `wrapping_add_signed`, `saturating_add_signed` for full coverage.

## `u{N}::checked_sub_signed` / `overflowing_sub_signed` / `saturating_sub_signed` / `wrapping_sub_signed` — 1.90

Unsigned minus signed, where the signed operand can make the result underflow:

```rust
let x: u32 = 5;
let y: i32 = -3;
// Mathematically: 5 - (-3) = 8

assert_eq!(x.checked_sub_signed(y),       Some(8));
assert_eq!(x.saturating_sub_signed(10),   0);     // 5 - 10 would underflow
assert_eq!(x.overflowing_sub_signed(10),  (u32::MAX - 4, true));
```

Completes the mixed-signedness arithmetic set.

## `u{N}::carrying_add` / `borrowing_sub` / `carrying_mul` / `carrying_mul_add` — 1.91

**For implementing bigint-style arithmetic with explicit carry/borrow propagation.**

```rust
// Adding a 128-bit number by 64-bit limbs
let (lo, carry) = a_lo.carrying_add(b_lo, false);
let (hi, _)     = a_hi.carrying_add(b_hi, carry);
```

Rare in application code — mostly for crypto, math libraries, and low-level protocol implementations.

## `<iN>::unchecked_neg` / `unchecked_shl` / `unchecked_shr` — 1.93

**Unsafe counterparts to the `strict_*` family.** Skip overflow checks entirely; UB if the precondition is violated.

Only use in `unsafe` blocks where you have a proven invariant. For application code under `#![deny(unsafe_code)]`, these are off-limits.

## `{integer}::midpoint` — 1.91 (i), earlier for u

Computes `(a + b) / 2` without overflow, rounding toward negative infinity:

```rust
// Before — naive addition overflows for large values
let mid = (a + b) / 2;

// After — overflow-safe
let mid = a.midpoint(b);
```

`u{N}::midpoint` was stabilized in 1.85, `i{N}::midpoint` in 1.91. Useful for binary search, geometric midpoints, and any average-of-two computation over untrusted inputs.

## `NonZero::count_ones` — 1.86

`count_ones` on a `NonZero<uN>` / `NonZero<iN>` returns `NonZero<u32>` instead of `u32` — the compiler knows the result is at least 1 (since the input had at least one bit set).

```rust
let n = NonZero::new(0b1010u32).unwrap();
let count: NonZero<u32> = n.count_ones();  // guaranteed ≥ 1
```

Mildly useful for bit manipulation where you'd otherwise add a runtime check.

## `NonZero<uN>::div_ceil` — 1.92

Ceiling division where the divisor is known non-zero at the type level. Skips the zero-check branch.

```rust
let chunks = total.div_ceil(NonZero::new(chunk_size).unwrap());
```

## Bit-manipulation methods — 1.97

**Replaces hand-rolled bit-twiddling idioms with named, `const fn` methods.** Stabilized on every integer type (`{u8..u128,usize}` and `{i8..i128,isize}`) with matching `NonZero<{integer}>` equivalents.

### `isolate_highest_one` / `isolate_lowest_one`

Return `self` with only the most / least significant set bit kept (`0` if `self == 0`; the `NonZero` variants can never be zero, so they drop that caveat).

```rust
// Before — extract the highest set bit
let hi = 1 << (u32::BITS - 1 - x.leading_zeros());   // UB-adjacent when x == 0
// After (1.97+)
let hi = x.isolate_highest_one();
assert_eq!(0b0110_0100u32.isolate_highest_one(), 0b0100_0000);

// Before — extract the lowest set bit
let lo = x & x.wrapping_neg();
// After (1.97+)
let lo = x.isolate_lowest_one();
assert_eq!(0b0110_0100u32.isolate_lowest_one(), 0b0000_0100);
```

### `highest_one` / `lowest_one`

Return the *index* of the highest / lowest set bit. `Option<u32>` on plain integers (`None` when `self == 0`); plain `u32` on `NonZero`.

```rust
assert_eq!(0b1_0000u32.highest_one(), Some(4));
assert_eq!(0b1_0000u32.lowest_one(),  Some(4));
assert_eq!(0u32.highest_one(),        None);
```

### `bit_width`

Minimum number of bits needed to represent `self` — i.e. `BITS - leading_zeros()`, or `0` when `self == 0`.

```rust
// Before
let w = u32::BITS - x.leading_zeros();
// After (1.97+)
let w = x.bit_width();
assert_eq!(0b111u32.bit_width(), 3);
assert_eq!(u32::MAX.bit_width(), 32);
```

All five are `const fn`, so they work in const contexts and `const` generics computations. Reach for them whenever you see the classic `leading_zeros` / `wrapping_neg` shift tricks — the named methods are clearer and avoid the `x == 0` edge cases those idioms mishandle.

Since 1.98, Clippy backs this up: `clippy::manual_isolate_lowest_one` (complexity, warn-by-default) flags the `x & x.wrapping_neg()` idiom and suggests `isolate_lowest_one`.

## `NonZero<{integer}>::from_str_radix` — 1.98

**Parse a non-zero integer in any base directly into `NonZero` — one step, `const fn`.**

```rust
use std::num::NonZero;

// Before — parse, then re-validate non-zeroness with a second error path
let id = u32::from_str_radix(hex, 16)
    .ok()
    .and_then(NonZero::new)
    .ok_or(Error::BadId)?;

// After (1.98+) — zero input yields Err(ParseIntError) directly
let id: NonZero<u32> = NonZero::from_str_radix(hex, 16)?;
```

A `"0"` input produces a `ParseIntError` (invalid-zero kind), so the two failure modes collapse into one error type. Being `const fn`, it also works for compile-time constants from env-provided strings.

## `{f32,f64}::algebraic_add` / `algebraic_sub` / `algebraic_mul` / `algebraic_div` / `algebraic_rem` — 1.98

**Float arithmetic that licenses algebraic (fast-math-style) optimizations — the stable answer to nightly `fadd_fast` and `-ffast-math` envy.**

```rust
// Before — strict IEEE ordering blocks vectorization of the reduction
let sum: f32 = xs.iter().sum();          // must add in sequence order

// After (1.98+) — compiler may reassociate, enabling SIMD reductions
let sum = xs.iter().fold(0.0f32, |acc, &x| acc.algebraic_add(x));
```

The compiler is allowed to reassociate, commute, and contract these operations (e.g. fuse into FMA), so results may differ between builds and optimization levels within a rounding tolerance — the operations are deliberately **non-deterministic** at the ULP level. Unlike `-ffast-math` there is no UB and no assumption that NaN/infinity never occur; only the *rounding/ordering* freedom is granted, scoped to exactly the operations you mark.

Use for throughput-bound kernels (dot products, norms, mixing loops) where bit-exact reproducibility isn't required. Avoid in code that must be deterministic across platforms/builds: hashes over floats, replay-based simulations, consensus/lockstep systems, and anything compared against golden outputs. All five are `const fn`.
