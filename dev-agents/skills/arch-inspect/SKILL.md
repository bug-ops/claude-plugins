---
name: arch-inspect
description: "Architecture and code quality audit protocol for Rust and TypeScript projects. Activates expert knowledge across type safety, modularity, testability, readability, DRY, async concurrency, error-handling design, API stability, observability, and lint/manifest hygiene, with language checklists from the stack profile. Called by arch-analyst at startup via Skill(...); invoked directly as /arch-inspect [focus] it delegates the audit to a background arch-analyst."
argument-hint: "[type-system|modularity|testability|readability|dry|async|errors|api|observability|hygiene|full]"
---

# Architecture Inspection Protocol

You are performing a **read-only** architecture and code quality audit. Do NOT modify source files. Identify structural debt and file GitHub issues for findings.

**Focus**: $ARGUMENTS (default: `full`)

## Direct Invocation

This protocol is loaded by `arch-analyst` at startup via `Skill()`. When it is invoked directly (`/dev-agents:arch-inspect`) in a session that is **not** that agent, do not run the audit in the current context: delegate it so the findings, not the tool noise, land in the conversation.

```
Agent(subagent_type: "dev-agents:arch-analyst", description: "arch-inspect $ARGUMENTS",
  prompt: "Call Skill(skill: \"dev-agents:arch-inspect\", args: \"$ARGUMENTS\") and follow it end to end. Report findings and filed issue URLs; do not modify source files.")
```

The agent runs in the background; report its result when the task notification arrives. If you **are** `arch-analyst`, continue with the protocol below.

## Language Profile

The sections below define what each focus area audits. The concrete patterns, evidence commands, and examples live in the profile file: apply `${CLAUDE_PLUGIN_ROOT}/skills/stack/references/<profile>/arch-inspect.md` for each profile the `stack` skill detected (Read it now if you have not), and audit each language's files against its own profile. No profile detected → run the generic protocol, never invent toolchain commands, and say so in the handoff.

| Focus | What is audited |
|-------|-----------------|
| `type-system` | Type safety, illegal states, domain types, state machines in types, escape hatches |
| `modularity` | Package/module boundaries, visibility and exports, workspace structure, dependency direction, cohesion |
| `testability` | Injected dependencies, pure functions, test structure, hidden globals |
| `readability` | API naming, function complexity, naming conventions, comments |
| `dry` | Duplicated error types, copy-pasted domain logic, redundant interfaces, untracked debt markers |
| `async` | Unbounded concurrency, missing timeouts, lost task failures, missing backpressure, blocking the executor, cancellation |
| `errors` | Error type design, untyped errors in library APIs, leaked dependency types, lost cause chains |
| `api` | Semver hygiene of the public surface, extensibility of public types, dependency types in signatures, version policy |
| `observability` | Tracing spans on I/O boundaries, structured logging, metrics, error context |
| `hygiene` | Centralized lint config, compiler strictness, doc enforcement, unused dependencies, build-matrix failures, doc warnings |
| `full` | All categories |

## Core Principle

**Type safety is the primary defense against entire classes of bugs.** Every invariant expressible in the type system is a bug that cannot exist at runtime. Audit this first and treat violations as the highest priority findings.

## Every-Cycle Requirements

These checks run explicitly on every cycle, including cycles where HEAD is unchanged since the last audit. Never report zero findings by default; state what was checked.

- **DRY** — grep for duplicated logic and types (near-identical branches, repeated validation, parallel types for one shape) before concluding there are none.
- **Type safety** — re-check domain-type coverage for ids and unit-bearing fields, and look for id-shaped fields added since the last audit; do not mark a standing gap as covered without re-checking.
- **Modern APIs** — use the profile's modern-API source and cite the specific API and file/line where a newer stable API replaces a manual workaround.
- **Version-policy impact** — for each modern-API finding, say whether the stack's version policy (MSRV for Rust, `engines`/`target` for TypeScript) already covers it. If it needs a higher floor, say so in the finding: raising it is a breaking change and part of the fix's cost. File as `enhancement`, P3 or lower, unless the old pattern is a correctness or safety liability.

**Unchanged HEAD** — do not re-audit the subsystem you audited last. Read prior `journal/ci-*.md` entries (and `journal/archive/`) attributed to your role, pick the modules least recently audited or audited only superficially, and audit those. Record the modules covered in the handoff.

Gather evidence with the toolchain before reading by hand — run the profile's **Evidence Commands**; the tools enumerate what a manual pass misses.

---

## 1. Type Safety

**Goal**: make illegal states unrepresentable. If invalid data can be constructed, it will be.

**Boolean blindness** — boolean parameters destroy call-site readability and force callers to guess meaning. Every boolean parameter is a candidate for a named variant type.

**Primitive-typed domains** — raw strings and numbers in public APIs where a distinct domain type would encode meaning. A user id that cannot be passed where an order id is expected eliminates a class of bugs; two bare integers cannot.

**Ambiguous absence** — nested or overlapping "missing" states model three intents with more representations than meanings. Use an explicit variant type.

**Post-construction validation** — `validate`/`isValid`/`check` methods on constructed values mean invalid values can exist and be passed around. Parse at the boundary with a constructor that fails, so an instance existing at all is proof of validity.

**Publicly mutable fields** — callers bypass invariants. Private state behind a validating constructor is the only way to guarantee structural validity.

**Escape hatches without justification** — every construct that disables the type checker (the profile lists them) must carry a comment proving the invariant it relies on. Absence is a P1 finding.

**Missed typestate opportunities** — repeated runtime checks of the same state flag (`connected`, `initialized`, `open`) across multiple call sites indicate a state machine that should be encoded in types. Each state becomes a type; invalid transitions become compile errors.

---

## 2. Modularity

**Goal**: each module and package has one clear responsibility; dependencies flow inward toward the domain.

**Boundary violations** — infrastructure code (HTTP, database, filesystem) importing from domain internals, or domain code depending on infrastructure. The domain package must have no knowledge of how it is delivered or stored.

**Overly broad visibility** — exporting what only the package needs creates accidental coupling. Every unnecessary public item is a surface callers can depend on, making future refactoring harder.

**Wildcard re-exports** — blanket re-exports hide where items come from, make API boundaries opaque, and cause unexpected breakage when the source module changes.

**Dependency cycles** — modules that import each other cannot be understood, tested, or split independently.

**Workspace structure violations** — dependency versions declared per package instead of once at the workspace root create version drift risk. Unordered dependency lists make diffs noisy. Build-time switches that remove behavior instead of adding it break consumers that enable everything.

**Cohesion** — a package that does too many unrelated things should be split. A package that does too little (thin wrapper with no added invariants) should be merged. Boundaries should align with domain concepts, not technical layers.

---

## 3. Testability

**Goal**: every unit of logic can be exercised in isolation without external side effects or ordering constraints.

**Concrete I/O types in signatures** — a function bound to a real file, socket, or HTTP client cannot be tested without real I/O. A function taking an abstraction can be tested with an in-memory substitute.

**Ambient dependencies** — reading the clock, randomness, or environment directly in business logic makes behavior untestable. Inject a clock or source.

**Global mutable state** — process-wide mutable singletons and registries cause test interference when tests run in parallel. Each test must be able to set up its own isolated state.

**Test code in production artifacts** — test helpers compiled or shipped with the release build inflate it and can expose test-only dependencies.

**Complex logic with no test path** — public functions with significant branching and no test coverage are a maintenance liability. Note these as P2 findings even if technically valid.

---

## 4. Readability

**Goal**: a new contributor understands intent from names and structure alone, without needing comments.

**API naming conventions** — names follow the language's API guidelines (the profile lists them). Names that mislead callers about cost, ownership, mutation, or async behavior are findings.

**Function length and complexity** — functions exceeding ~50 lines are candidates for decomposition. The metric is cognitive load, not line count: a function with many nested branches, multiple levels of error handling, and mixed abstraction levels is a readability problem regardless of length.

**Single-letter bindings** outside short iterators and callbacks obscure intent. Name what the variable represents, not its type.

**Comment quality** — comments must explain WHY, not WHAT. A comment restating what the next line does is noise. Non-obvious invariants, external constraints, and workarounds for upstream bugs deserve comments. Self-evident code does not.

---

## 5. DRY and Technical Debt

**Goal**: every piece of domain knowledge has exactly one authoritative location; no deferred work is left untracked.

**Duplicated error types** across packages — when `NotFound`, `Unauthorized`, or `InvalidInput` appear in several error definitions, error handling logic must be duplicated at every boundary. Consolidate into a shared error module in the core package.

**Copy-pasted domain logic** — the same computation or transformation appearing in multiple packages is the most dangerous form of duplication: the copies diverge silently over time. Move it to a core or domain package.

**Code-level duplication** — repeated blocks of logic within a single package that differ only in a parameter or type. Extract into a shared function or generic. Three or more copies of the same pattern is the threshold for mandatory extraction.

**Redundant interfaces** — two interfaces with overlapping contracts force implementors to implement both and callers to import both. Establish a clear hierarchy or merge.

**Technical debt markers** — `TODO`, `FIXME`, `HACK`, `XXX`, and `DEPRECATED` comments are explicit admissions of known problems. Each one must be triaged: either scheduled for resolution (file an issue and link it in the comment) or removed if no longer relevant. A codebase where these accumulate has no mechanism for paying down debt. Flag clusters of markers in the same module as P2 — they indicate areas of sustained neglect.

---

## 6. Async Concurrency

**Goal**: bounded concurrency, explicit error strategy, defined timeout on every I/O operation.

**Unbounded fan-out** — launching one concurrent operation per input item has no back-pressure. One slow upstream makes everything wait; a large input causes resource exhaustion. Bound concurrency explicitly.

**Missing timeouts** — every network and I/O call must have an explicit deadline. An operation with no timeout will block indefinitely on a slow or unresponsive peer, eventually exhausting the connection pool or worker budget.

**Lost task failures** — a background task whose result nobody observes loses its failures silently.

**Missing backpressure** — unbounded queues or buffers between a fast producer and a slow consumer will exhaust memory.

**Blocking the executor** — synchronous I/O, sleeps, or CPU-bound loops on an async path stall every task scheduled on the same worker or event loop.

**Shared state across suspension points** — locks or check-then-act sequences that span an await cause stalls, deadlocks, or races.

**Cancellation safety** — an operation cancelled mid-way (timeout, race, abort) that performs a multi-step mutation leaves partial state. Each step must be cancel-safe or the mutation must be atomic/rolled back.

**Graceful shutdown** — no shutdown signal propagated to long-running tasks means in-flight work is killed mid-write on SIGTERM. Verify a shutdown path drains or aborts tasks deliberately.

---

## 7. Error-Handling Design

**Goal**: errors carry enough context to act on, and a library's error type is part of its API, not an implementation leak.

**Untyped errors in library public APIs** — callers cannot match on the failure. Libraries expose distinguishable failure cases; catch-all error containers belong in applications and tests.

**Leaked dependency types** — a dependency's error type in a public error definition makes the dependency a semver-visible part of the API. Wrap it behind an opaque case, keeping it as the cause.

**Lost cause chains** — wrapping that stringifies the underlying error destroys the chain: no inspection, no root cause in logs. Keep the cause attached.

**Stringly errors and catch-all variants** — a single `Other(message)`-style case used everywhere is a sign the error model was never designed. Enumerate the failures callers must distinguish.

**Lost operation context** — blanket conversion at every layer loses which operation failed. Add context at the boundary where the operation is known.

**Crashing as error handling** — aborting the process or panicking on recoverable conditions in library code turns a caller's bad input into a crash. Return or raise a recoverable error.

---

## 8. API Stability

**Goal**: the public surface can evolve without breaking downstream consumers by accident.

**Closed types that will grow** — public types where adding a case or field forces a major version bump. Mark them as extensible, or document them as deliberately closed.

**Interfaces open to outside implementation** — a public interface meant only for internal implementation lets downstream implement it, so adding a member is a breaking change. Seal interfaces that are not extension points.

**Dependency types in public signatures** — a public function taking or returning a dependency's type pins that dependency's major version to your own semver. Re-export deliberately or wrap.

**Unchecked semver** — no public-API check in CI means breakage ships in minor releases. Run the profile's API check during the audit and report any detected break.

**Version policy** — a minimum toolchain/runtime version that is absent, or declared but not tested in CI, means the compatibility claim is untested. Note the gap and whether modern-API usage respects the declared floor.

---

## 9. Observability

**Goal**: a production failure can be diagnosed from telemetry without reproducing it.

**Uninstrumented I/O boundaries** — request handlers, outbound calls, and database queries without a tracing span lose latency attribution and request correlation. Sensitive fields must be excluded from span attributes.

**Unstructured logging** — printing to stdout/stderr in library or service code, or interpolating values into the message instead of attaching fields, defeats log querying.

**Swallowed errors** — discarded results, empty handlers, or branches that log nothing leave failures invisible. Every discarded error needs a log line or a justification comment.

**New work paths without spans** (optional, when the project requires tracing) — a newly added path that does meaningful work (I/O, network call, database query, CPU-heavy transform) and ships without a span is invisible to trace analysis; file it as P3, or P2 on a hot path.

**No metrics on saturable resources** — connection pools, queues, and worker counts without gauges make capacity problems undiagnosable. Note absence for services; libraries may expose hooks instead.

---

## 10. Lint and Manifest Hygiene

**Goal**: the compiler and linters enforce the project's standards on every build, so reviewers do not have to.

**Scattered or weak lint configuration** — per-file lint settings drift; one central configuration with the strict rule sets enabled (selectively relaxed) is the baseline.

**Compiler strictness not maximized** — strictness options left off let whole bug classes through.

**Documentation not enforced** — public items without docs in a library; no doc build gate that fails on broken links.

**Blanket suppressions** — file- or package-wide disables hide real defects. Each suppression needs a scoped target and a reason.

**Unused and duplicate dependencies** — they inflate build time, install size, and attack surface; both are findings.

**Build matrix failures** — supported configurations (feature combinations, module formats, runtime versions) that do not build mean some users cannot use the package. Report each failing combination.

**Doc build warnings** — broken links and malformed doc comments indicate documentation that was never rendered. Count them.

---

## Triage and Filing

For each finding, assess priority:

- **P1** — causes bugs or prevents correct extension: invalid states representable, escape hatches without justification, global mutable state, silently lost task failures (the profile names its P1 patterns)
- **P2** — structural debt that multiplies as the codebase grows: DRY violations, missing type abstractions, untestable design, boundary violations, missing timeouts
- **P3** — maintainability and readability: API naming, comment quality, function length

File a GitHub issue for every P1 and P2 finding. Batch multiple P3 findings of the same kind into one issue. The literal priority label is set at creation (create the label first if missing; never use another priority scheme); finding symptoms count even without a proven root cause. Use the profile's code-fence language (`rust`, `ts`) for the Before/After blocks:

```bash
gh issue create \
  --title "<concise title>" \
  --label "<P1|P2|P3|P4>,architecture,code-quality" \
  --body "$(cat <<'EOF'
## Finding
<description>

## Location
<file:line>

## Before
```<lang>
<current code>
```

## After
```<lang>
<improved code>
```

## Why
<rationale>
EOF
)"
```

Skip false positives: if a boolean parameter clearly has no alternative domain meaning, or a name is dictated by an external interface contract, note it briefly and move on.

---

## Handoff Output

Write your handoff with an **Architecture Review** section:

```markdown
## Architecture Review

### Summary
- Findings: <N total> (P1: N, P2: N, P3: N, P4: N)
- Issues filed: <links>
- Modules audited: <list; feeds least-recently-audited selection next cycle>
- Every-cycle checks: DRY <result> | type safety <result> | modern APIs <result> | version policy <result>

### Findings by Category
| Category | Count | Top Issue |
|----------|-------|-----------|
| Type safety | N | <link or —> |
| Modularity | N | ... |
| Testability | N | ... |
| Readability | N | ... |
| DRY violations | N | ... |
| Async concurrency | N | ... |
| Error-handling design | N | ... |
| API stability | N | ... |
| Observability | N | ... |
| Lint / manifest hygiene | N | ... |

### Top Structural Concern
<One sentence: the single most impactful finding>
```
