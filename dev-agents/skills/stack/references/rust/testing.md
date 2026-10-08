# Rust — Testing Rules

## Tools

- Runner: `cargo-nextest` (the tests command in `toolchain.md`); `cargo test --doc` for doctests, which nextest does not run.
- Coverage: `cargo llvm-cov --html` (report), `cargo llvm-cov nextest --lcov --output-path lcov.info` (machine-readable).
- Property tests: `proptest`. Parametric tests: `rstest` (`#[rstest]` + `#[case]`) or `test_case`.
- Async tests: `#[tokio::test]`; `#[tokio::test(start_paused = true)]` with `tokio::time::advance` for time-dependent code.
- Benchmarks: `criterion` in `benches/`, run with `cargo bench`.
- Mutation testing (optional, for critical modules): `cargo mutants`.

## Test Layout

**CRITICAL: unit tests go in a `#[cfg(test)]` module in the SAME FILE as the code.** Integration tests live in `tests/`; shared setup lives in `tests/common/mod.rs` (imported with `mod common;`).

**Naming**: `test_{function_name}_{scenario}`.

```rust
// src/calculator.rs

pub fn add(a: i32, b: i32) -> i32 { a + b }

pub fn divide(a: f64, b: f64) -> Result<f64, String> {
    if b == 0.0 { return Err("division by zero".into()); }
    Ok(a / b)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_add_positive_numbers() {
        assert_eq!(add(2, 3), 5);
    }

    #[test]
    fn test_divide_by_zero() {
        let result = divide(10.0, 0.0);
        assert!(result.is_err());
    }
}
```

## Integration Tests

```rust
// tests/api_tests.rs
mod common;

#[tokio::test]
async fn test_full_user_workflow() {
    let config = common::test_config();
    let app = App::new(config).await.unwrap();

    let user_id = app.create_user("test@example.com").await.unwrap();
    let user = app.get_user(user_id).await.unwrap();
    assert_eq!(user.email, "test@example.com");
}
```

## Async Tests

```rust
#[tokio::test]
async fn test_async_fetch_user() {
    let user = fetch_user(1).await.unwrap();
    assert_eq!(user.id, 1);
}
```

## Test Doubles

Substitute at a trait boundary; define the fake once and reuse it.

```rust
pub trait UserRepository {
    fn find_user(&self, id: u64) -> Result<User>;
}

#[cfg(test)]
pub struct MockUserRepository {
    users: HashMap<u64, User>,
}

#[cfg(test)]
impl UserRepository for MockUserRepository {
    fn find_user(&self, id: u64) -> Result<User> {
        self.users.get(&id).cloned().ok_or_else(|| anyhow!("not found"))
    }
}
```

## Property-Based Tests

```rust
use proptest::prelude::*;

proptest! {
    #[test]
    fn test_parse_email_never_panics(email in "\\PC*") {
        let _ = parse_email(&email);
    }

    #[test]
    fn test_addition_commutative(a in 0..1000i32, b in 0..1000i32) {
        assert_eq!(add(a, b), add(b, a));
    }
}
```

## Benchmarks

```rust
// benches/my_benchmark.rs
use std::hint::black_box;
use criterion::{criterion_group, criterion_main, Criterion};

fn benchmark_process_data(c: &mut Criterion) {
    let data = vec![1, 2, 3, 4, 5];
    c.bench_function("process_data", |b| {
        b.iter(|| process_data(black_box(&data)))
    });
}

criterion_group!(benches, benchmark_process_data);
criterion_main!(benches);
```

## DRY in Tests

Shared fixtures in `tests/common/mod.rs`; define `MockUserRepository`-style fakes once; repeated setup in one `#[cfg(test)]` block → a `fn test_fixture()` helper inside the module.

## Redundancy Audit Commands

| Step | Command |
|------|---------|
| Enumerate the suite | `cargo nextest list --workspace` (or `cargo test --workspace -- --list --format=terse`); pipe through `wc -l` for the baseline |
| Unit-test sweep scope | the touched module's `#[cfg(test)]` block plus matching files in `tests/` |
| Coverage diff | `cargo llvm-cov nextest --lcov --output-path all.info`, then the same run with the suspected test filtered out (`-- --skip {suspected_test}`); compare |
| Per-test timing | `cargo nextest run --message-format libtest-json` (experimental: needs `NEXTEST_EXPERIMENTAL_LIBTEST_JSON=1`); nextest also prints `SLOW` for long tests |
| Slow-test quarantine | `#[ignore = "slow: <reason>"]` or a feature gate for nightly-only runs |

Rust forms of the redundancy types: placeholders are `#[test] fn smoke() {}`, `assert!(true)`, `assert_eq!(1, 1)`, an empty `#[tokio::test]`; stdlib tests assert things like `Vec::push` behavior; property overlap means a unit test inside a `proptest!` strategy's domain; a deliberate parametric expansion is e.g. a macro generating one test per SIMD width. A documented regression carries `// regression for #1234`.

Report example:

```
src/parser.rs
  L412 — `test_parse_empty_input_returns_none` [exact duplicate]
    Duplicate of `test_parse_blank_string` (L398), same input "" and same assertion.
    Recommendation: drop; keep `test_parse_blank_string` (clearer name).

  L520..L580 — `test_parse_int_{1..6}` [parametric duplicate]
    Six tests for `parse_int` differing only in input values (1, 42, -1, 0, i32::MAX, i32::MIN).
    Recommendation: collapse to a single `#[rstest]` driven by `#[case]` rows, or a table-driven test.

tests/integration.rs
  L67 — `test_user_create_then_fetch` [subset duplicate]
    Subset of `test_user_full_workflow` (L120) which already asserts create→fetch→update→delete.
    Recommendation: drop.
```

## Anti-patterns

- Integration tests in `#[cfg(test)]` modules; unit tests in `tests/`
- Tests taking >1 second without `#[ignore]` with a reason or a feature gate
- Copy-pasted setup across test files instead of `tests/common/`
- Tests of the mock itself (`assert_eq!(mock.return_value, mock.return_value)`)
- Placeholder tests: empty `#[test] fn ...`, `assert!(true)`, `assert_eq!(1, 1)`
- Unit test duplicating what an existing `proptest!` strategy already covers
- `std::thread::sleep` in async tests instead of paused tokio time
- `unwrap()` hiding which step failed in a long test — prefer `expect("step description")`
