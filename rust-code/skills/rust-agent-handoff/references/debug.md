# rust-debugger Output Schema

## Summary Field (frontmatter)

One sentence covering: error type + root cause location + whether fix was applied.

Example: `"Runtime panic in src/processor.rs:42 — off-by-one in loop bound; fix applied"`

## Output Sections

**Debug Summary** (required): What was investigated and key finding.

**Error Type** (required): `compilation` | `runtime` | `async` | `memory`

**Root Cause** (required): File:line, issue description, explanation of why it happens.

**Reproduction** (required): Steps to reproduce + minimal failing case (code snippet).

**Solution** (required): Before/after showing the fix.

**Regression Test** (required): Test code that would catch this regression.

**Related Issues** (if any): Similar patterns elsewhere in the codebase to verify.

## Error Types and Tools

| Type | Tools |
|------|-------|
| `compilation` | `rustc --explain`, `cargo expand` |
| `runtime` | `RUST_BACKTRACE=1`, lldb/gdb |
| `async` | `tokio-console`, add timeouts |
| `memory` | ASAN, valgrind, dhat |

## Common Patterns

**Borrow checker:** Separate mutable/immutable scopes; `.clone()` as last resort.

**Async:** Never use `std::thread::sleep`; use `spawn_blocking` for CPU work; add timeouts to find hangs.
