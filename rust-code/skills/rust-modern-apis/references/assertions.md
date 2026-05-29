# Assertion macros

## `assert_matches!` / `debug_assert_matches!` — 1.96

**Assert that a value matches a pattern, with a `Debug` dump of the value on failure.**

Stabilized in `core::assert_matches` (re-exported from `std::assert_matches`). They are **not** in the prelude — you must import them explicitly. This deliberately avoids a name clash with the popular `assert_matches` crate that many test suites already depend on.

```rust
use std::assert_matches::assert_matches;

// Before — assert!(matches!(..)) discards the value; the failure says only "false"
assert!(matches!(response, Response::Ok { .. }));
// panic message: assertion failed: matches!(response, Response::Ok { .. })

// After (1.96+) — failure prints the actual value via Debug
assert_matches!(response, Response::Ok { .. });
// panic message:
//   assertion `left matches right` failed
//     left: Response::Error { code: 500 }
//    right: Response::Ok { .. }
```

The macro supports a match guard and a trailing custom message, mirroring `matches!` and `assert!`:

```rust
assert_matches!(parse(input), Ok(n) if n > 0);
assert_matches!(state, State::Ready, "expected ready, got {state:?}");
```

`debug_assert_matches!` is the `debug_assert!`-style sibling: active only when `debug_assertions` is on, compiled out in release builds. Use it for hot-path invariants worth checking in tests/dev but not in production.

### When to prefer

- **In tests**, prefer `assert_matches!` over `assert!(matches!(..))` whenever the matched value is `Debug` — the failure output tells you *what* you got, not just that a match failed.
- Replace hand-rolled `match x { Pat => {} _ => panic!("got {x:?}") }` test scaffolding with a single `assert_matches!`.

### When NOT to

- If the value is not `Debug`, the macro still works but the failure message can't show it — there's less advantage over `assert!(matches!(..))`.
- If the project already imports the `assert_matches` crate, don't add `use std::assert_matches::assert_matches;` alongside it — that creates an ambiguous import. For MSRV 1.96+, prefer the std macro and drop the dependency.
- MSRV below 1.96: keep the `assert_matches` crate or `assert!(matches!(..))`.
- `assert_matches!` binds names from the pattern only within the optional guard; to use a binding after the assertion, destructure separately (e.g. `let Ok(value) = result else { unreachable!() };`).
