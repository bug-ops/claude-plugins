# TypeScript — Debugging Rules

Applies to TypeScript and JavaScript mode (skip the type-error section in JavaScript mode). Runtime sections assume Node.js; browser bugs use the same ideas through the browser's DevTools.

## Prevention Techniques — TypeScript Forms

- **Typestate**: a phantom state parameter — `class Connection<S extends "open" | "closed">` with methods typed `send(this: Connection<"open">, ...)`; transitions return a new `Connection<"closed">`.
- **Branded types**: `type AccountId = string & { readonly __brand: "AccountId" }`, created only by a validating constructor (or a schema `.brand()` in zod).
- **Marker parameters**: `type Id<T extends string> = string & { readonly __kind: T }` → `Id<"User">` vs `Id<"Order">`.
- **Discriminated unions**: replace `boolean` flags and raw string modes with a tagged union; `switch` with a `const _exhaustive: never = value` default so a new case fails to compile.
- **Smart constructors**: `parseEmail(raw: string): Result<Email, InvalidEmail>` returning a branded type; validate `unknown` input with the project's schema library at the boundary.
- **Builder**: generic builder that tracks set fields in its type parameter; `build()` only accepts the complete state.
- **Ownership redesign**: replace shared mutable module state with a single owner (a class instance or worker) that receives messages; `readonly` everywhere else.
- **Lint as prevention**: `@typescript-eslint/no-floating-promises`, `switch-exhaustiveness-check`, `strict-boolean-expressions` turn whole bug classes into lint errors; compiler options `noUncheckedIndexedAccess` and `exactOptionalPropertyTypes` do the same for missing-index and `undefined` bugs.

## Type Errors (tsc)

Read long errors from the bottom: the elaboration chain ends at the property that actually mismatches. Fix the first error in a file first; later ones are often cascades. Reproduce with the type-check command from `toolchain.md`, not only the editor (the editor may use a different `tsconfig` or TypeScript version).

| Code | Message | Fix direction |
|------|---------|---------------|
| TS2322 / TS2345 | Type 'X' is not assignable to type 'Y' / argument not assignable | Read the last line of the chain; fix the producer's type, never cast the consumer |
| TS2339 | Property does not exist on type | Narrow the union first (`in`, tag check, type guard) |
| TS2532 / TS18048 | Object / value is possibly 'undefined' | Handle the missing case; with `noUncheckedIndexedAccess` check the index result |
| TS2307 | Cannot find module | Module resolution — see below; check `paths`, `moduleResolution`, installed package |
| TS7016 | Could not find a declaration file for module | Install `@types/*` or add a typed local declaration; never `declare module "x";` as a blanket `any` |
| TS2835 | Relative import paths need explicit file extensions | `nodenext` resolution: import `./file.js` from `./file.ts` |
| TS1479 | CommonJS file imports an ECMAScript module | Make the importer ESM (`"type": "module"` or `.mts`) or use dynamic `import()` |
| TS2589 | Type instantiation is excessively deep and possibly infinite | Simplify the recursive type, add an explicit annotation to cut inference |

Compiler diagnostics:

- `tsc --showConfig` — the effective config after `extends`; confirms which options actually apply.
- `tsc --explainFiles` — why each file is in the program (stray `include` globs, transitive imports).
- `tsc --traceResolution` — step-by-step module resolution for every import; grep for the failing specifier.
- `tsc --extendedDiagnostics` — check time, instantiation counts, memory; the first stop for a slow type check.
- `tsc --generateTrace <dir>` — per-file and per-type timing; analyze with `@typescript/analyze-trace` to find the expensive type.

## Runtime Debugging

- Stack traces must point at TypeScript sources: run with `node --enable-source-maps` (or `NODE_OPTIONS=--enable-source-maps`), and make sure the build emits source maps (`sourceMap: true`, bundler `sourcemap` option).
- More frames: `node --stack-trace-limit=100` or `Error.stackTraceLimit = Infinity` during diagnosis.
- Follow `error.cause` chains; log the whole error object, not just `message`.
- `node --trace-uncaught` shows where an uncaught value was thrown; `--trace-warnings` prints stacks for process warnings (e.g. `MaxListenersExceededWarning` — a listener leak); `--trace-deprecation` for deprecation warnings.
- Common crash sources: property access on `undefined` from an unvalidated `as` cast or `!` assertion, `JSON.parse` on unexpected input, out-of-range array index (`undefined`, not an exception), thrown non-`Error` values with no stack.

Defensive patterns: validate at the boundary with a schema, optional chaining with an explicit fallback only where absence is legitimate, `Number.isSafeInteger` / `BigInt` for large ids, `Array.prototype.at` plus an `undefined` check.

## Interactive Debugging

- `node --inspect-brk dist/main.js` (pause on first line) or `--inspect` (attach later), then `chrome://inspect` or the VS Code debugger; a `debugger;` statement sets an ad-hoc breakpoint.
- TypeScript sources directly: `tsx --inspect-brk src/main.ts`, or Node's built-in type stripping where the project's Node version supports it.
- Tests: `vitest --inspect-brk --no-file-parallelism`; `node --inspect-brk ./node_modules/.bin/jest --runInBand`.
- Debug unminified builds; production bundles need uploaded source maps to be readable.

## Async Debugging

- **Unhandled rejection** — Node terminates on it by default. V8 async stack traces only follow `await` chains: a rejection created inside a `.then` callback, an event emitter, or a callback API loses the caller frames. Convert the chain to `async`/`await` and add `cause` to see the origin. `process.on("unhandledRejection", ...)` is a diagnosis aid, never a fix.
- **Hang / promise never settles** — race the suspect with a deadline (`AbortSignal.timeout(ms)` or `Promise.race` with a timer) to locate it; look for a missing `resolve`, an un-awaited stream, or a lock never released.
- **Process will not exit** — open handles (servers, sockets, timers, intervals, DB pools): `process.getActiveResourcesInfo()`, the `why-is-node-running` package, `vitest --reporter=hanging-process`, `jest --detectOpenHandles`. Close resources in teardown; `unref()` only for genuinely background timers.
- **Blocked event loop** — measure with `perf_hooks.monitorEventLoopDelay()`; find the synchronous culprit with a CPU profile (`node --cpu-prof`).
- **Lost context** — use `AsyncLocalStorage` to carry request ids into logs across awaits.

## Structured Logging

Use the project's logger (pino, winston) with child loggers per request and the `redact` option for secrets and tokens. `DEBUG=<namespace>` enables the `debug` package's output in dependencies; `NODE_DEBUG=http,net` traces Node core modules.

## Memory Debugging

- Heap snapshots: `node --inspect` + DevTools Memory tab, `v8.writeHeapSnapshot()`, `node --heapsnapshot-signal=SIGUSR2`, or `--heapsnapshot-near-heap-limit=<n>` to capture right before an OOM.
- Three-snapshot technique: warm up, snapshot, repeat the suspect operation many times, snapshot, repeat, snapshot; compare and follow the retainers of objects that keep growing.
- Allocation sampling: `node --heap-prof`; GC pressure: `--trace-gc`.
- Raising `--max-old-space-size` confirms a growth pattern; it is never the fix.
- Usual leaks: unbounded `Map`/array caches (use `lru-cache` with `max`), listeners never removed, timers/intervals never cleared, closures capturing large objects, request-scoped data stored in module scope. `WeakMap`/`WeakRef` for metadata keyed by objects.

## Module Resolution and ESM/CJS Interop

| Error | Cause | Fix direction |
|-------|-------|---------------|
| `ERR_MODULE_NOT_FOUND` | ESM import without file extension, or wrong path after build | Use `.js` extensions in relative imports; check the emitted `dist` layout |
| `ERR_REQUIRE_ESM` / `ERR_REQUIRE_ASYNC_MODULE` | `require()` of an ESM package (older Node) or of an ESM graph with top-level `await` | Make the caller ESM or use `await import()` |
| `ERR_PACKAGE_PATH_NOT_EXPORTED` | Deep import not listed in the package's `exports` map | Import a public entry point |
| `ERR_UNKNOWN_FILE_EXTENSION ".ts"` | Node run on `.ts` without a loader or type stripping | Run the built output, `tsx`, or a Node version with type stripping |
| `Cannot use import statement outside a module` | ESM syntax in a file Node treats as CJS | `"type": "module"`, `.mjs`/`.mts`, or compile to CJS |
| `__dirname is not defined in ES module scope` | CJS global used in ESM | `import.meta.dirname` / `fileURLToPath(import.meta.url)` |
| `x.default is not a function` / default import is an object | CJS ↔ ESM default-export interop | Match `esModuleInterop`/`module` settings; use a named or namespace import |

Diagnosis: read the nearest `package.json` `type` and the dependency's `exports`/`main`/`types`; resolve the specifier directly (`import.meta.resolve("pkg")`, `require.resolve("pkg")`); compare with `tsc --traceResolution`. For a published package, `attw --pack` reveals type/runtime resolution mismatches. Two copies of a package (dual-package hazard, duplicated versions) break `instanceof` and singletons — check with `<pm> why <pkg>` / `npm ls <pkg>`.

## CI-Only Failures

Usual environment differences: Node version (`.nvmrc` / `engines` vs `setup-node`), install mode (`npm ci`, `pnpm install --frozen-lockfile` failing on lockfile drift), case-sensitive filesystems on Linux runners, timezone and locale (`TZ=UTC`), test parallelism exposing shared state, and env vars that exist only locally.

## Anti-patterns

- `as any` / `!` added "to debug later"
- `console.log` debugging left in code instead of the project's logger
- Debugging minified output without source maps
- `process.on("uncaughtException")` / `unhandledRejection` handlers that swallow and continue
- `@ts-ignore` to get past a type error during diagnosis
- Raising heap limits or test timeouts instead of finding the leak or hang
