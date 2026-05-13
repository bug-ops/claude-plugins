---
name: arch-inspect
description: "Architecture and code quality audit protocol for Rust projects. Activates expert knowledge across type safety, modularity, testability, readability, DRY, and async concurrency. Called by rust-arch-analyst at startup via Skill(...). When invoked directly as /arch-inspect [focus], the current session runs the audit without spawning subagents."
argument-hint: "[type-system|modularity|testability|readability|dry|async|full]"
---

# Architecture Inspection Protocol

You are performing a **read-only** architecture and code quality audit. Do NOT modify source files. Identify structural debt and file GitHub issues for findings.

**Focus**: $ARGUMENTS (default: `full`)

| Focus | What is audited |
|-------|-----------------|
| `type-system` | Type safety, illegal states, newtypes, typestate, sealed traits |
| `modularity` | Crate/module boundaries, visibility, workspace structure, crate cohesion |
| `testability` | Trait-based deps, pure functions, test structure, hidden globals |
| `readability` | API naming, function complexity, naming conventions, comments |
| `dry` | Duplicated error variants, copy-pasted domain logic, redundant traits |
| `async` | Unbounded concurrency, missing timeouts, missing backpressure |
| `full` | All categories |

## Core Principle

**Type safety is the primary defense against entire classes of bugs.** Every invariant expressible in the type system is a bug that cannot exist at runtime. Audit this first and treat violations as the highest priority findings.

---

## 1. Type Safety

**Goal**: make illegal states unrepresentable. If invalid data can be constructed, it will be.

**Boolean blindness** — `bool` parameters destroy call-site readability and force callers to guess meaning. Every `bool` parameter is a candidate for a named enum. `process(true, false)` is unreadable; `process(Direction::Forward, Encoding::Raw)` is self-documenting.

**Stringly-typed and primitive-typed domains** — raw `String`, `u64`, `i32` in public APIs where a newtype would encode domain meaning. `UserId(u64)` cannot be accidentally passed where `OrderId(u64)` is expected; a bare `u64` can.

**`Option<Option<T>>`** — models three states as four. The outer `None`, inner `None`, and `Some(None)` states are indistinguishable in intent. Use an explicit enum.

**Post-construction validation** — `is_valid()`, `validate()`, `check()` methods on constructed types mean invalid values can exist and be passed around. Use smart constructors (`fn new(...) -> Result<Self, E>`) so an instance existing at all is proof of validity.

**Public struct fields** — callers bypass invariants. Private fields with a constructor are the only way to guarantee structural validity.

**Unsafe without justification** — every `unsafe` block must have a `// SAFETY:` comment explaining why the invariants hold. Absence is a P1 finding.

**Missed typestate opportunities** — repeated runtime checks of the same state flag (`is_connected`, `is_initialized`, `is_open`) across multiple call sites indicate a state machine that should be encoded in types. Each state becomes a type; invalid transitions become compile errors.

---

## 2. Modularity

**Goal**: each module and crate has one clear responsibility; dependencies flow inward toward the domain.

**Crate boundary violations** — infrastructure code (HTTP, database, filesystem) importing from domain internals, or domain code depending on infrastructure. The domain crate must have no knowledge of how it is delivered or stored.

**Overly broad visibility** — `pub` where `pub(crate)` or `pub(super)` suffices creates accidental coupling. Every unnecessary `pub` is a surface that callers can depend on, making future refactoring harder.

**Wildcard re-exports** — `pub use module::*` hides where items come from, makes API boundaries opaque, and causes unexpected breakage when the source module changes.

**Workspace structure violations** — dependency versions in crate `Cargo.toml` instead of `[workspace.dependencies]` creates version drift risk. Non-alphabetical order makes diffs noisy and reviews harder. Feature flags that disable behavior (rather than add it) are not additive and break the feature flag contract.

**Crate cohesion** — a crate that does too many unrelated things should be split. A crate that does too little (thin wrapper with no added invariants) should be merged. Boundaries should align with domain concepts, not technical layers.

---

## 3. Testability

**Goal**: every unit of logic can be exercised in isolation without external side effects or ordering constraints.

**Concrete I/O types in signatures** — a function taking `std::fs::File`, `TcpStream`, or `reqwest::Client` directly cannot be tested without real I/O. A function taking `impl Read`, `impl Write`, or a trait-abstracted client can be tested with an in-memory substitute.

**Time dependencies without abstraction** — `SystemTime::now()` and `Instant::now()` called directly in business logic make time-dependent behavior untestable. A `Clock` trait (`fn now(&self) -> SystemTime`) allows injecting a fake clock in tests.

**Global mutable state** — `static mut`, unguarded `OnceLock` with side effects, or process-global registries cause test interference when tests run in parallel. Each test must be able to set up its own isolated state.

**Test functions outside `#[cfg(test)]`** — test code compiled into the release binary inflates binary size and can expose test-only dependencies. All tests belong inside `#[cfg(test)] mod tests`.

**Complex logic with no test path** — public functions with significant branching and no test coverage are a maintenance liability. Note these as P2 findings even if technically valid.

---

## 4. Readability

**Goal**: a new contributor understands intent from names and structure alone, without needing comments.

**API naming conventions**:
- Getters use the field name directly: `user.name()`, not `user.get_name()`
- `as_` conversions are free and return a reference or view
- `to_` conversions are allocating or expensive and return owned data
- `into_` conversions are consuming
- Mismatches mislead callers about cost and ownership

**`impl Into<X>` parameters** — the correct pattern is to implement `From<X>` on the destination type and accept `impl Into<X>` only in generic public APIs where ergonomics matter. But adding `impl Into<X>` everywhere without `From` implementations is noise.

**Function length and complexity** — functions exceeding ~50 lines are candidates for decomposition. The metric is cognitive load, not line count: a function with many nested branches, multiple levels of error handling, and mixed abstraction levels is a readability problem regardless of length.

**Single-letter bindings** outside iterators and closures obscure intent. Name what the variable represents, not its type.

**Comment quality** — comments must explain WHY, not WHAT. A comment restating what the next line does is noise. Non-obvious invariants, external constraints, and workarounds for upstream bugs deserve comments. Self-evident code does not.

---

## 5. DRY and Technical Debt

**Goal**: every piece of domain knowledge has exactly one authoritative location; no deferred work is left untracked.

**Duplicated error variants** across crates — when `NotFound`, `Unauthorized`, or `InvalidInput` appear in multiple error enums, error handling logic must be duplicated at every call site boundary. Consolidate into a shared error module in the `core` crate.

**Copy-pasted domain logic** — the same computation or transformation appearing in multiple crates is the most dangerous form of duplication: the copies diverge silently over time. Move to a `core` or `domain` crate.

**Code-level duplication** — repeated blocks of logic within a single crate that differ only in a parameter or type. Extract into a shared function, macro, or generic. Three or more copies of the same pattern is the threshold for mandatory extraction.

**Redundant traits** — two traits with overlapping method contracts force implementors to implement both and callers to import both. Establish a clear hierarchy or merge.

**Technical debt markers** — `TODO`, `FIXME`, `HACK`, `XXX`, and `DEPRECATED` comments are explicit admissions of known problems. Each one must be triaged: either scheduled for resolution (file an issue and link it in the comment) or removed if no longer relevant. A codebase where these accumulate has no mechanism for paying down debt. Flag clusters of markers in the same module as P2 — they indicate areas of sustained neglect.

---

## 6. Async Concurrency

**Goal**: bounded concurrency, explicit error strategy, defined timeout on every I/O operation.

**Unbounded `join_all`** — spawning an unbounded number of concurrent futures with `join_all` on a `Vec` has no back-pressure. One slow upstream makes everything wait; a large input causes resource exhaustion. Use `StreamExt::buffer_unordered(N)` with an explicit bound.

**Missing timeouts** — every network and I/O call must have an explicit deadline. An operation with no timeout will block indefinitely on a slow or unresponsive peer, eventually exhausting the connection pool or thread budget.

**Discarded `JoinHandle`** — a `tokio::spawn` result that is not stored means panics in the spawned task are silently lost. Always bind the handle; abort it on drop if the result is genuinely unneeded.

**Missing backpressure** — unbounded channels (`mpsc::unbounded_channel`) between a fast producer and a slow consumer will exhaust memory. Use bounded channels and handle the send error explicitly.

---

## Triage and Filing

For each finding, assess priority:

- **P1** — causes bugs or prevents correct extension: invalid states representable, unsafe without SAFETY justification, global mutable state, discarded task panics
- **P2** — structural debt that multiplies as the codebase grows: DRY violations, missing type abstractions, untestable design, crate boundary violations, missing timeouts
- **P3** — maintainability and readability: API naming, comment quality, function length

File a GitHub issue for every P1 and P2 finding. Batch multiple P3 findings of the same kind into one issue:

```bash
gh issue create \
  --title "<concise title>" \
  --label "architecture,code-quality" \
  --body "$(cat <<'EOF'
## Finding
<description>

## Location
<file:line>

## Before
```rust
<current code>
```

## After
```rust
<improved code>
```

## Why
<rationale>
EOF
)"
```

Skip false positives: if a `bool` parameter clearly has no alternative domain meaning, or a `get_` prefix belongs to an external trait contract, note it briefly and move on.

---

## Handoff Output

Write your handoff with an **Architecture Review** section:

```markdown
## Architecture Review

### Summary
- Findings: <N total> (P1: N, P2: N, P3: N)
- Issues filed: <links>

### Findings by Category
| Category | Count | Top Issue |
|----------|-------|-----------|
| Type safety | N | <link or —> |
| Modularity | N | ... |
| Testability | N | ... |
| Readability | N | ... |
| DRY violations | N | ... |
| Async concurrency | N | ... |

### Top Structural Concern
<One sentence: the single most impactful finding>
```
