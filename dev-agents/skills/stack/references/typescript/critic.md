# TypeScript — Critic Targets

Types are erased at runtime: every claim of the form "the type guarantees X" must trace back to a runtime check at the trust boundary. JavaScript mode: there is no compile-time safety net, so every type-level target below is a runtime target.

## Counterexample Targets

- **Non-null assertions** (`value!`) — what input makes `value` `null`/`undefined`? Optional chaining that silently yields `undefined` further down?
- **Unvalidated casts** — `as T`, `as unknown as T`, `JSON.parse(...) as T`, `response.json() as T`, typed `process.env` reads: what payload violates `T`? Which code then trusts the wrong shape?
- **Floating promises** — un-awaited calls, `async` callbacks in `forEach`/event handlers: where does a rejection go? In Node an unhandled rejection terminates the process by default; in the browser it vanishes.
- **Unchecked index access** — `arr[i]`, `record[key]`, `map.get(k)!` typed as defined when `noUncheckedIndexedAccess` is off: which index or key is missing? Empty arrays (`arr[0]`, `reduce` without initial value throws on `[]`).
- **Number precision and NaN** — integers above `Number.MAX_SAFE_INTEGER` (ids, timestamps in ns, 64-bit database values) lose precision; money as floating point; `Number("")` is `0`; `parseInt` without radix; `NaN` propagation and `NaN !== NaN`; division by zero yields `Infinity`; mixing `bigint` and `number` throws; `JSON.stringify` throws on `bigint`.
- **Event-loop blocking** — synchronous fs/crypto/compression, large `JSON.parse`/`JSON.stringify`, catastrophic regex backtracking (ReDoS) on user input: what input stalls every other request?
- **Prototype pollution** — deep merge, `Object.assign`, or `obj[userKey] = value` with keys like `__proto__`, `constructor`, `prototype`; `in` and plain-object lookups that hit inherited properties. Safe forms: `Map`, `Object.create(null)`, `Object.hasOwn`.
- **Coercion and identity** — `==` coercion, default `Array.prototype.sort` comparing as strings (`[10, 9, 1].sort()`), `typeof null === "object"`, shallow spread copies sharing nested state, `instanceof` across realms or duplicated package instances.
- **Lost `this`** — class methods passed as callbacks without binding.
- **Exhaustiveness** — `switch` over a union with no `never` check: what happens when a new variant arrives from the server?

## Scalability Red Flags

- Unbounded `Promise.all(items.map(...))` over user-sized input (socket/file-descriptor exhaustion, rate limits)
- Module-level caches, `Map`s, or arrays in long-lived servers without eviction or size bounds
- Event listeners and timers never removed (`MaxListenersExceededWarning`, closures retaining large objects)
- Hidden O(n²): `array.includes`/`find` inside loops, `{ ...acc }` or `[...acc]` inside `reduce`
- `JSON.parse(JSON.stringify(x))` deep clones on hot paths (`structuredClone` exists, but cloning itself may be the problem)
- One CPU-heavy request on the single event-loop thread stalling every other request

## Completeness

- Errors are `Error` subclasses with `cause` preserved; the error contract is documented (`@throws`) or typed as a `Result` union.
- Long-running async APIs accept and propagate an `AbortSignal`; every network call has a timeout.
- Resource cleanup: `try`/`finally` or `using`/`await using` with `Symbol.dispose`/`Symbol.asyncDispose` (TypeScript 5.2+, and the runtime must provide the symbols) for handles, connections, locks.
- Graceful shutdown: `SIGTERM` handling, draining in-flight work, closing pools; `unhandledRejection`/`uncaughtException` policy defined.
- Serialization: `Date`, `Map`, `Set`, `bigint`, and class instances do not round-trip through JSON — is the wire format defined?
- Consumers: ESM and CJS consumers, browser and Node targets, minimum `engines.node` — all accounted for?

## Dependency Risk

- Which packages have advisories (`npm audit` / the dependency audit in `toolchain.md`), are deprecated, or have a single inactive maintainer?
- Which dependencies run install scripts (`preinstall`/`postinstall`), ship native addons, or were recently transferred to a new owner? Supply-chain scanners (Socket, `osv-scanner` against the lockfile) surface these signals.
- Does a major upgrade go ESM-only and break CJS consumers? Does `engines.node` of a dependency exceed the project's?
- Are `@types/*` versions aligned with the runtime package version?
- `peerDependencies` ranges: will consumers end up with two copies of a framework (React, a schema library) and broken `instanceof`/context?
- Duplicate or conflicting transitive versions?

Investigation commands (read-only):

```bash
npm ls <pkg>          # installed versions in the tree (pnpm why <pkg>, yarn why <pkg>)
npm explain <pkg>     # why a package is installed
npm view <pkg> time maintainers deprecated   # publish history and ownership
```

## Second-Order Effects

- Type-check time: deep conditional/mapped types and large unions slow `tsc` and the editor for every consumer (`tsc --extendedDiagnostics` to measure).
- Bundle size: new dependencies, barrel imports, or `sideEffects` regressions in client bundles.
- API evolution: exported types are API — adding a union member to a returned type breaks consumers' exhaustive switches; inferred return types leak internals into the public surface.
- Dual-package hazard: shipping both ESM and CJS can load two instances of module state.
- Inference: overloads and generics that force consumers into explicit type arguments or `as`.

## Reproducers

A throwaway `*.test.ts` under a scratch path run with `vitest run <file>` (or the configured runner, `node --test` in JS mode), or a standalone `.mjs` script. For input-space claims, a `fast-check` property test finds the minimal counterexample. Never commit the reproducer.
