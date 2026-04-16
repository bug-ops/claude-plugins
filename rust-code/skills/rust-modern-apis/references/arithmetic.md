# Integer arithmetic APIs

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
