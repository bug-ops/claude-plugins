# Rust — Security & Maintenance Rules

## Dependency Security

### cargo-deny (recommended tool)

```bash
cargo install cargo-deny
cargo deny check             # All checks
cargo deny check advisories  # Vulnerabilities
cargo deny check licenses    # Licenses
```

**deny.toml:**
```toml
[advisories]
vulnerability = "deny"
unmaintained = "warn"

[licenses]
unlicensed = "deny"
allow = ["MIT", "Apache-2.0", "BSD-3-Clause"]

[bans]
multiple-versions = "warn"
```

### cargo-outdated

```bash
cargo outdated
cargo outdated --root-deps-only
```

Apply updates with `cargo update` (semver-compatible) or by bumping the version in `[workspace.dependencies]`; commit `Cargo.lock`.

## Unsafe Code Management

Every `unsafe fn` documents its contract in a `/// # Safety` section; every `unsafe` block carries `// SAFETY:` stating why the contract holds.

```rust
/// # Safety
/// Caller must ensure bytes are valid UTF-8.
pub unsafe fn bytes_to_str(bytes: &[u8]) -> &str {
    // SAFETY: Caller guarantees valid UTF-8
    std::str::from_utf8_unchecked(bytes)
}
```

**Detect unsafe:**
```bash
cargo geiger
```

## Input Validation

```rust
use validator::Validate;

#[derive(Validate)]
pub struct UserInput {
    #[validate(email)]
    email: String,
    #[validate(length(min = 8, max = 128))]
    password: String,
}
```

## SQL Injection Prevention

```rust
// ❌ DANGEROUS
let sql = format!("SELECT * FROM users WHERE id = '{}'", user_id);

// ✅ SAFE: Parameterized query
query_as("SELECT * FROM users WHERE id = $1")
    .bind(user_id)
    .fetch_one(pool)
    .await
```

## Path Traversal Prevention

```rust
pub fn read_safe(filename: &str) -> Result<String> {
    let filename = Path::new(filename)
        .file_name()
        .ok_or_else(|| anyhow!("invalid filename"))?;

    let base_dir = Path::new("/var/data");
    let path = base_dir.join(filename);
    let canonical = path.canonicalize()?;

    if !canonical.starts_with(base_dir) {
        return Err(anyhow!("path traversal attempt"));
    }

    Ok(std::fs::read_to_string(canonical)?)
}
```

## Secrets Management

```rust
// ❌ NEVER
const API_KEY: &str = "sk-1234567890abcdef";

// ✅ Load at startup from a secret store or the environment, never from source
fn config() -> Result<Config> {
    Ok(Config {
        api_key: env::var("API_KEY").context("API_KEY not set")?,
    })
}
```

## Password Hashing

```rust
use argon2::{Argon2, PasswordHasher, PasswordVerifier};

pub fn hash_password(password: &str) -> Result<String> {
    let salt = SaltString::generate(&mut OsRng);
    Ok(Argon2::default()
        .hash_password(password.as_bytes(), &salt)?
        .to_string())
}
```

## Error Handling Security

```rust
// ❌ BAD: Leaks info
pub fn auth(user: &str, pass: &str) -> Result<Token> {
    let u = db::find(user)?;  // Reveals "not found"
    verify(pass, &u.hash)?;
    Ok(token(u.id))
}

// ✅ GOOD: Generic message
pub fn auth(user: &str, pass: &str) -> Result<Token> {
    let u = db::find(user)
        .map_err(|e| { log::error!("{}", e); anyhow!("auth failed") })?;
    verify(pass, &u.hash)
        .map_err(|_| anyhow!("auth failed"))?;
    Ok(token(u.id))
}
```

## Checklist Additions

- [ ] `cargo deny check` passes
- [ ] All `unsafe` documented (`# Safety` on `unsafe fn`, `// SAFETY:` on blocks)
- [ ] Passwords hashed with the `argon2` crate
- [ ] Clippy restriction lints (`unwrap_used`, `expect_used`, `indexing_slicing`, `arithmetic_side_effects`) enabled on request-path crates

## Tools

```bash
cargo deny check
cargo outdated
cargo geiger
cargo update
```
