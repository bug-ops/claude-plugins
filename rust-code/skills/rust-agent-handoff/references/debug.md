# rust-debugger Output Schema

Summary: error type + root cause location + fix status. Example: `"Runtime panic in src/processor.rs:42 — off-by-one in loop bound; fix applied"`

## Output Sections

**Debug Summary** (required): what was investigated + key finding.

**Error Type** (required): `compilation` | `runtime` | `async` | `memory`

**Root Cause** (required): file:line — issue — why it happens.

**Reproduction** (required): steps + minimal failing case.

**Solution** (required): the fix; before/after snippet allowed — here the fix IS the payload.

**Regression Test** (required): if written — name + location; snippet only if not yet in the diff.

**Related Issues** (if any): similar patterns elsewhere to verify.
