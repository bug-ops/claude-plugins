# Rust — Code Review Rules

## Checklist Additions

### Error Handling
- [ ] Every `Result` handled; none discarded with `let _ =` or `.ok()` without reason?
- [ ] No `unwrap()`/`expect()` in library code without a comment justifying it?
- [ ] Library errors use `thiserror` with `#[source]` chains; application code adds `.context(...)`?

### Safety
- [ ] Every `unsafe` block has a `// SAFETY:` comment stating the invariant?
- [ ] SQL built with bound parameters (`sqlx::query!`, `bind`), never `format!`?

### Formatting
- 🔵 NITPICK formatting findings are fixed by running `cargo +nightly fmt`.

## Modern API Review (MANDATORY)

Using the `rust-modern-apis` trigger table, scan the code under review for trigger patterns. Flag outdated patterns as 🟢 SUGGESTION with a before/after snippet. Respect the project's MSRV — only flag patterns replaceable within the declared `rust-version`.

## Rust-Specific Review Points

### Ownership & Borrowing

```rust
// 🟡 IMPORTANT: Unnecessary ownership transfer
// ❌ BAD
pub fn validate(user: User) -> bool {
    user.email.contains('@')
}

// ✅ GOOD
pub fn validate(user: &User) -> bool {
    user.email.contains('@')
}
```

### Async/Await

```rust
// 🔴 CRITICAL: Blocking in async
async fn bad() {
    std::thread::sleep(Duration::from_secs(1));  // BAD!
}

// ✅ GOOD
async fn good() {
    tokio::time::sleep(Duration::from_secs(1)).await;
}
```

### Comment Hygiene

```rust
// 🟢 SUGGESTION: Redundant comment, no complexity to justify it
// ❌ BAD
// Increment the retry counter by one.
retry_count += 1;

/// Adds two numbers together.
pub fn add(a: i32, b: i32) -> i32 {
    a + b
}

// ✅ GOOD
retry_count += 1;

/// Adds two numbers, saturating instead of overflowing at the integer bounds.
pub fn add(a: i32, b: i32) -> i32 {
    a + b
}

// ✅ GOOD — warranted: non-obvious invariant, kept to one line
// SAFETY: buf is pre-validated as UTF-8 by the caller above.
let s = unsafe { std::str::from_utf8_unchecked(buf) };
```

## Tools

```bash
cargo expand module::path      # Macro expansion
cargo semver-checks            # API compatibility
cargo clippy -- -D warnings    # Linting
```
