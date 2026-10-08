# TypeScript — Developer Rules

## Code Quality Requirements

**Every exported function**: clear single responsibility, explicit parameter and return types, TSDoc comment, at least one test.

**Types first**:
- Model domain values with branded types (`type UserId = string & { readonly __brand: "UserId" }`) or classes with private constructors, not bare `string`/`number`.
- Model alternatives as discriminated unions with a literal `kind`/`type` tag; switch exhaustively and end with a `never` check (`const _exhaustive: never = value`).
- `readonly` properties and `ReadonlyArray`/`readonly T[]` by default; mutate only where needed.
- `unknown` at trust boundaries (JSON, network, `catch`, user input), narrowed by a schema validator the project already uses (zod, valibot, arktype, typebox) or a type guard. Never `any`; never `as` to assert an unvalidated shape.
- Prefer `satisfies` over `as` for checking literals against a type.
- No `enum` in new code unless the project uses them; prefer `as const` objects or string literal unions.

**Error handling**:
- Throw `Error` subclasses (or return a typed `Result` union if the project uses one) — never throw strings or plain objects.
- Preserve causes: `new AppError("context", { cause: err })`.
- Every promise is awaited, returned, or explicitly handled; no floating promises. `void promise` only with a comment explaining why the result is irrelevant.
- `catch (err)` treats `err` as `unknown` and narrows before use.

**Async rules**:
- Never block the event loop: no synchronous fs/crypto/compression in request paths (`readFileSync`, `pbkdf2Sync`, ...); offload CPU-heavy work to worker threads.
- Bound concurrency for collections: `p-limit`/`p-map` with a limit, or batched `Promise.all` — not unbounded `Promise.all(items.map(...))` over user-sized input.
- `Promise.allSettled` when one failure must not abort the rest.
- Every network and I/O call has a timeout or `AbortSignal` (`AbortSignal.timeout(ms)`); propagate the caller's signal.

## DRY Extraction Targets

- Same logic in 2+ places → shared function or module
- Same error class in 2+ modules → common error module
- Same test setup repeated → shared fixture/helper under the test directory (`test/helpers/`, `vitest` `setupFiles`, fixtures)
- Same validation/parsing pattern → one schema or branded-type constructor

## Incremental Verification

Run the type check (`tsc --noEmit` or the project's `typecheck` script) after each function, type, or module; run the affected test file with `vitest run <file>` (or the configured runner).

## Never Weaken Checks — TypeScript Forms

- Do not `.skip`, `.only`, delete, or loosen a failing test; never commit `.only`
- Do not add `// @ts-ignore`, `// @ts-expect-error`, `// eslint-disable`, or `any` to silence an error
- Do not loosen `tsconfig` (`strict`, `noImplicitAny`, `skipLibCheck` to hide own-code errors) or lint rules
- Do not swallow errors with empty `catch {}` or `.catch(() => {})`
- Do not update snapshots to make a failing test pass without confirming the new output is correct

## Dependencies Added

In the handoff list name, version, dependency kind (`dependencies` / `devDependencies` / `peerDependencies`), and reason. Use the project's package manager; the lockfile change goes in the same commit.

## Anti-patterns

- `any`, `as unknown as T`, and `!` non-null assertions without a comment proving the shape
- Floating promises and `async` callbacks passed to `forEach`
- Mutating function arguments or shared module state
- `export default` in libraries when the project uses named exports
- Barrel files (`index.ts` re-exporting everything) that create import cycles or defeat tree-shaking
- Optional booleans as mode switches where a union of literal modes documents intent
- Unbounded `Promise.all` over user-sized input
- `console.log` left in library or production code instead of the project's logger
- `== null` vs `=== undefined` mixed inconsistently — follow the project's rule
