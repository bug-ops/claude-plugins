# Duration APIs

## `Duration::from_mins(u64)` — 1.91

**Replaces:** `Duration::from_secs(60 * N)`

```rust
// Before
const TIMEOUT: Duration = Duration::from_secs(60 * 5);

// After (1.91+)
const TIMEOUT: Duration = Duration::from_mins(5);
```

Const-stable. Panics if overflow (i.e. `u64::MAX / 60 + 1` and above), but practical minute counts never reach this.

## `Duration::from_hours(u64)` — 1.91

**Replaces:** `Duration::from_secs(60 * 60 * N)`

```rust
// Before
let retry_budget = Duration::from_secs(60 * 60);

// After (1.91+)
let retry_budget = Duration::from_hours(1);
```

Const-stable. Panics if overflow.

## `Duration::from_nanos_u128(u128) -> Duration` — 1.93

**Replaces:** manually splitting very large nanosecond counts into secs + subsec_nanos.

```rust
// Before — Duration::from_nanos takes u64, overflows at ~584 years in nanoseconds
let big_ns: u128 = /* ... */;
let secs = (big_ns / 1_000_000_000) as u64;
let nanos = (big_ns % 1_000_000_000) as u32;
let d = Duration::new(secs, nanos);

// After (1.93+)
let d = Duration::from_nanos_u128(big_ns);
```

Panics if the value exceeds `Duration::MAX` (u64::MAX seconds plus 999_999_999 nanoseconds).

## Notes on applicability

- `from_mins`/`from_hours` work in `const` contexts — so `const TIMEOUT: Duration = Duration::from_mins(5);` compiles.
- `tokio::time::interval(Duration::from_mins(N))` is a natural use site.
- For sub-second durations, `from_millis`/`from_micros`/`from_nanos` already existed since early stable — this set just completes the human-facing units.

## No `from_days` / `from_weeks`

There is no `Duration::from_days` or `from_weeks` as of 1.95. Use `Duration::from_hours(24 * N)` for days. Calendar-aware ranges (months, years) require `chrono` or `time` — `Duration` is wall-clock only.
