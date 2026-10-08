# TypeScript — Architecture Inspection Rules

Language checklist for the `arch-inspect` protocol. Section numbers match the protocol's focus areas. JavaScript mode: skip the type-check-only evidence and treat "no type checking at all" (no `// @ts-check`, no `checkJs`) as a `type-system` finding for libraries and services.

## Evidence Commands

Read-only still allows running the toolchain: type checks, linters, and analyzers give evidence without touching tracked files. Prefer the project's `package.json` scripts; run binaries through `<pm> exec`. Run these before reading by hand:

| Evidence | Command |
|----------|---------|
| Effective compiler options (resolves `extends`) | `tsc --showConfig` |
| Type errors | toolchain.md **Type check** |
| Lint findings, including warnings | toolchain.md **Lint** (ESLint: add `--max-warnings 0` to surface warnings as failures) |
| Unused files, exports, dependencies, unlisted dependencies | toolchain.md **Unused files, exports, dependencies** (`knip`) |
| Import cycles | `madge --circular --extensions ts,tsx src` (add `--ts-config tsconfig.json` for path aliases), or `depcruise src` with the repo's dependency-cruiser config |
| Copy-paste duplication | `jscpd src` (when available) |
| Duplicate dependency versions | `npm find-dupes`, `pnpm dedupe --check`, `yarn dedupe --check` |
| Published package shape and types | toolchain.md **Package publish check** (`publint`, `attw --pack`) |
| Public API report diff | toolchain.md **Public API report** (`api-extractor run`) |

Without a dependency-cruiser config, `madge` is the zero-config option; do not create config files in the repository to run an audit.

## Every-Cycle Specifics

- **Modern APIs** — there is no knowledge skill; the source is the language and runtime features allowed by the version policy: `satisfies`, `using`/`await using`, `Object.groupBy`, `Array.prototype.toSorted`/`with`, `structuredClone`, `AbortSignal.timeout`/`AbortSignal.any`, `Promise.withResolvers`, `Error` `cause`, `node:test`, built-in `fetch`. Cite the API and file/line.
- **Version policy** — the floor is `engines.node`, `tsconfig` `target`/`lib`, and the minimum supported TypeScript version for published `.d.ts`. Raising any of them for a published package is a breaking change.

## 1. Type Safety

- **`any` and its leaks** — explicit `any`, implicit `any` from `JSON.parse`, `res.json()`, untyped third-party modules, and `Function`/`object`/`{}` as parameter types. Lint evidence: typescript-eslint `no-explicit-any` and the `no-unsafe-*` family (`no-unsafe-assignment`, `no-unsafe-member-access`, `no-unsafe-call`, `no-unsafe-return`, `no-unsafe-argument`).
- **Unvalidated casts** — `as T` on external data, `as unknown as T` double casts, `!` non-null assertions, `@ts-ignore`/`@ts-nocheck`. External data (`fetch`, request bodies, env vars, files, `postMessage`) is parsed by a schema (zod, valibot, arktype, or the project's choice) into a typed value. Each remaining escape hatch carries a comment proving the shape; absence is P1.
- **Boolean blindness** — `render(true, false)` → an options object with a string-literal union: `render({ mode: "preview", wrap: "none" })`. Prefer literal unions or `as const` objects over `enum`; under `erasableSyntaxOnly` (TypeScript 5.8+) `enum` is not allowed at all.
- **Primitive-typed domains** — bare `string`/`number` ids. Use branded types created only by a validating constructor:

```ts
type UserId = string & { readonly __brand: "UserId" };

export function parseUserId(raw: string): UserId {
  if (!/^usr_[a-z0-9]{12}$/.test(raw)) throw new InvalidIdError(raw);
  return raw as UserId; // brand applied only after the check above
}
```

- **Ambiguous absence** — `field?: T | null` has three states (missing, `undefined`, `null`) — the analogue of `Option<Option<T>>`. Pick one representation per meaning; `exactOptionalPropertyTypes` stops `undefined` from standing in for "missing".
- **Optional-field bags instead of discriminated unions** — `{ loading: boolean; data?: T; error?: Error }` allows `loading: false` with neither field set. Model states as a union on a `status`/`kind` discriminant and switch exhaustively (`switch-exhaustiveness-check`, or a `never` default).
- **Post-construction validation** — `isValid()`/`validate()` on an already-built object → parse at the boundary; a class with a `private constructor` and a static `create`/`parse` factory.
- **Publicly mutable fields** — public mutable properties and exposed arrays/maps → `readonly`, `#private` fields, `ReadonlyArray`/`Readonly<T>` in public types.
- **Typestate** — repeated `if (!this.connected)` checks → a union of state types (`Disconnected | Connected`) with transition functions that accept only the valid source state.

## 2. Modularity

- **Package boundaries** — deep imports into another workspace package (`@scope/pkg/src/internal/x`, `../../other-pkg/src`) bypass its public surface. The `exports` map in `package.json` is the boundary; a package without `exports` lets consumers reach every file.
- **Dependency direction** — domain modules importing HTTP frameworks, ORMs, or `node:fs`. Enforce with dependency-cruiser `forbidden` rules or ESLint `no-restricted-imports`; TypeScript project references (`composite`, `references`) make cross-package edges explicit.
- **Overly broad exports** — TypeScript has no crate-private visibility: anything exported from a module reachable through `exports` is public. Unused exports show up in `knip`; mark intentional non-public exports `@internal` (with API Extractor trimming or `stripInternal`) instead of leaving them silently public.
- **Import cycles** — every `madge --circular` / dependency-cruiser `no-circular` hit is a finding. Under ESM, cycles surface as `Cannot access 'X' before initialization` at runtime depending on import order; ESLint `import/no-cycle` (eslint-plugin-import or import-x) catches them per file.
- **Barrel files** — internal `index.ts` files that `export * from` every sibling hide where items come from, pull side-effectful modules into every import, slow test runners and dev servers, and create cycles. Biome flags them with `noBarrelFile`/`noReExportAll`. A package's single entry point that re-exports its deliberate public API is fine.
- **Workspace manifests** — the same dependency at different versions across packages → pnpm catalogs (`catalog:`) or a version-sync tool; internal packages referenced by version instead of the `workspace:` protocol; runtime imports of `devDependencies`; frameworks (React, Vue) in a library's `dependencies` instead of `peerDependencies`, which installs duplicate instances.
- **Cohesion** — a `utils`/`common`/`shared` package that every package imports and that mixes unrelated helpers is a split candidate.

## 3. Testability

- **Import-time side effects** — `export const db = new Pool(process.env.DATABASE_URL)` at module scope connects on import and forces every test to mock the module. Export a factory and inject the instance.
- **Concrete I/O** — business logic calling `fetch`, `node:fs`, or an SDK client directly → accept an interface (port) parameter; mock HTTP at the network boundary (MSW) only for integration tests.
- **Ambient dependencies** — `Date.now()`, `new Date()`, `Math.random()`, `crypto.randomUUID()`, `process.env` read inside logic → inject a clock/id source/config object. `vi.useFakeTimers()`/`vi.setSystemTime()` are a fallback, not a design.
- **Module-path mocking as a design smell** — heavy `vi.mock`/`jest.mock` of the project's own modules means dependencies are hidden imports instead of parameters.
- **Global mutable state** — module-level `let` caches, singletons, and patched globals leak between tests in the same file (vitest isolates per file by default, not per test).
- **Test code in published artifacts** — test helpers exported from the package entry, fixtures or `__tests__` included by the `files` field (check `npm pack --dry-run`), test utilities imported from `src`.

## 4. Readability

- **Naming** — `camelCase` values and functions, `PascalCase` types and classes, `UPPER_SNAKE_CASE` only for true module-level constants; no `I` prefix on interfaces, no type suffixes (`userArray`). Booleans and predicates read as questions (`isActive`, `hasAccess`); type guards return `value is T`.
- **Accessor names that lie** — `getX()` that performs I/O or heavy work (should be `loadX()`/`fetchX()` and async); `toX()` that mutates; `x` getters with side effects. Async functions do not carry an `Async` suffix unless a sync twin exists.
- **Long positional parameter lists** — more than three parameters, or several of the same type → one options object.
- **Type-level complexity** — deeply nested conditional and mapped types that only the author can read; prefer simpler explicit types at public boundaries.
- **Complexity evidence** — ESLint `complexity`, `max-depth`, `max-lines-per-function`; Biome `noExcessiveCognitiveComplexity`. Nested ternaries and `reduce` with multi-branch accumulators count as complexity.
- **Comment quality** — JSDoc `@param {string}` type annotations in `.ts` files duplicate the signature and drift; keep the description, drop the type.

## 5. DRY

- **Parallel type definitions** — a hand-written interface next to the schema that validates the same shape → derive it (`z.infer<typeof UserSchema>`); client and server copies of the same DTO → a shared package or generated types (OpenAPI/GraphQL codegen).
- **Duplicated error classes** — `NotFoundError` defined in several packages → one shared errors module.
- **Repeated validation** — the same regex or range check in several handlers → one schema or branded-type constructor.
- **Re-implemented utilities** — the same helper (debounce, retry, deep merge, date formatting) written in several packages.
- **Debt markers** — besides `TODO`/`FIXME`, clusters of `@ts-expect-error`, `eslint-disable`, and `any` in one module mark sustained neglect.

## 6. Async Concurrency

- **Floating promises** — un-awaited calls, `async` callbacks passed to `forEach` or to event handlers expecting `void`. Lint evidence: `no-floating-promises`, `no-misused-promises`. A background promise whose rejection nobody handles is a lost failure (P1); Node terminates the process on unhandled rejections by default.
- **Unbounded `Promise.all`** — `Promise.all(items.map(fetchItem))` over input-sized arrays → a concurrency limiter (`p-limit`, `p-map` with `concurrency`) or fixed-size batches. `Promise.all` also leaves the remaining operations running after the first rejection; pair it with a shared `AbortController` when they should stop.
- **Missing timeouts** — `fetch` and most clients have no caller-controlled deadline by default → `signal: AbortSignal.timeout(ms)`, combined with a caller's signal via `AbortSignal.any([...])`. Check database and queue clients for their own timeout options.
- **Missing `AbortSignal` propagation** — public async functions that do I/O should accept `{ signal?: AbortSignal }` and pass it to every inner call; a signal accepted but not forwarded is a finding.
- **Missing backpressure** — ignoring `writable.write()` returning `false`, hand-piped streams without `pipeline` from `node:stream/promises`, unbounded in-memory arrays used as queues, event emitters that buffer without limit.
- **Blocking the event loop** — `readFileSync`, `execSync`, `pbkdf2Sync`, `zlib` sync calls, or large `JSON.parse`/CPU loops on request paths → async APIs, `worker_threads`, or chunking. eslint-plugin-n `no-sync` flags the sync calls.
- **Check-then-act across `await`** — `if (!cache.has(k)) { cache.set(k, await load(k)) }` lets concurrent callers stampede; cache the promise, not the value.
- **Promise constructor misuse** — `new Promise(async (resolve, reject) => ...)` loses throws (`no-async-promise-executor`); callback APIs wrapped by hand where `util.promisify` or the `/promises` module exists.
- **Graceful shutdown** — no `SIGTERM` handler that stops accepting (`server.close()`), drains in-flight work, and closes pools; `process.exit()` called from library code; intervals and timers that keep the process alive without `unref()`.

## 7. Error-Handling Design

- **Thrown non-Errors** — `throw "message"`, `throw { code }`, `Promise.reject("x")` lose the stack. Lint evidence: `only-throw-error`, `prefer-promise-reject-errors`.
- **Lost `cause`** — `catch (err) { throw new Error("failed to load config") }` drops the original; use `new Error("failed to load config", { cause: err })` (needs `lib` ES2022). `new Error(String(err))` stringifies it.
- **Untyped `catch`** — `catch (e: any)` or `useUnknownInCatchVariables` disabled; narrow `unknown` before use.
- **Library error model** — callers parsing `err.message` to decide what happened. Expose `Error` subclasses with a `name` and a literal-union `code` property callers can switch on; prefer `code` checks over `instanceof` across package boundaries, where duplicate installs break `instanceof`.
- **Leaked dependency errors** — `AxiosError`, ORM-specific errors, or `ZodError` escaping a public API → wrap in the package's own error with `cause`.
- **Swallowed errors** — `catch {}`, `.catch(() => {})`, `.catch(console.error)` followed by code that assumes success.
- **Crashing on recoverable input** — `process.exit()` or uncaught throws from library code for bad caller input.

## 8. API Stability

- **Semver of exports** — everything reachable through `exports` (types included) is public API. Breaking: removing an export or `exports` subpath, adding `exports` to a package that had none, adding a required property to an exported input type, narrowing a parameter type, widening a return type.
- **Closed unions that will grow** — adding a member to an exported union breaks consumers' exhaustive switches. Document growable unions as open (consumers keep a default branch) or ship new members only in majors.
- **Interfaces open to implementation** — an exported `interface` consumers may implement breaks them when a member is added. Mark it `@sealed` (API Extractor) or expose a class with a private constructor or a factory instead.
- **Dependency types in public signatures** — exported functions returning `AxiosResponse` or ORM model types pin that dependency. Types from `devDependencies` in emitted `.d.ts` fail to compile for consumers; any `@types/*` package a public type references must be a `dependency`.
- **API report** — no `api-extractor` report (`*.api.md`) committed and checked in CI means export changes go unreviewed; run it during the audit and report diffs.
- **Package shape** — `attw --pack` problems (types resolving differently under `node16` CJS/ESM and `bundler`, "masquerading as ESM/CJS"), `publint` errors (`types` condition not first, missing files, wrong `main`/`module`), dual CJS/ESM packages with stateful modules (dual-package hazard), `"sideEffects": false` on modules that do have side effects.
- **Version policy** — `engines.node` absent or not covered by the CI Node matrix; no stated minimum TypeScript version while emitted `.d.ts` uses newer syntax.

## 9. Observability

- **Spans** — HTTP handlers, outbound calls, and queries without OpenTelemetry spans (auto-instrumentation for `http`, `undici`, database drivers, plus manual spans for business operations). Libraries depend only on `@opentelemetry/api`, never on the SDK.
- **Unstructured logging** — `console.log` in library or service code; template-string messages instead of fields: `logger.info({ userId, orderId }, "order placed")` (pino) rather than `` logger.info(`user ${userId} placed ${orderId}`) ``. Request-scoped context via child loggers or `AsyncLocalStorage`; secrets removed with the logger's redaction option.
- **Error logging** — logging `err.message` drops stack and `cause`; log the error object under the logger's error key.
- **Swallowed errors** — empty `catch`, `void promise` with no rejection handler, `.catch(() => undefined)`.
- **Metrics** — no gauges for pool usage, queue depth, or event-loop delay (`monitorEventLoopDelay` from `node:perf_hooks`) in services.

## 10. Lint and Manifest Hygiene

- **Compiler strictness** — check the effective config (`tsc --showConfig`): `strict` off or partially disabled; missing `noUncheckedIndexedAccess`, `exactOptionalPropertyTypes`, `noImplicitOverride`, `noFallthroughCasesInSwitch`; `allowJs` without `checkJs`; `isolatedModules`/`verbatimModuleSyntax` absent when a transpile-only tool (esbuild, swc, Vite, Node type stripping) builds the code. Monorepo packages should extend one shared base config.
- **`skipLibCheck: true`** — common for speed, but it also skips checking the package's own emitted `.d.ts` and hides conflicting `@types` versions. For published libraries without `attw`/declaration checks in CI, report it (P3).
- **Lint configuration** — no type-aware rules (typescript-eslint `recommendedTypeChecked`/`strictTypeChecked` with `projectService`), legacy `.eslintrc*` on ESLint 9+ instead of `eslint.config.*`, ESLint and Biome both enabled with overlapping rules, warnings allowed to accumulate (no `--max-warnings 0`).
- **Blanket suppressions** — file-wide `/* eslint-disable */`, `@ts-nocheck`, lint `ignores` covering source directories, `@ts-ignore` instead of `@ts-expect-error -- reason` (`ban-ts-comment` enforces descriptions).
- **Unused and duplicate dependencies** — `knip` unused/unlisted dependencies and exports; duplicate versions from the dedupe check; `@types/*` in `dependencies` that only tests use.
- **Build matrix** — each `exports` condition and entry point builds, every Node version in `engines` is tested, JS consumers can load what TS consumers can.
- **Doc warnings** — TypeDoc warnings (`treatWarningsAsErrors` when configured), API Extractor `ae-*` messages, TSDoc syntax errors (`eslint-plugin-tsdoc`); count them.
- **Manifest basics** — no lockfile committed, no `packageManager` field in a repo that pins its manager in CI, no `engines` on a published package.

## Filing

- Before/After blocks use ` ```ts ` (` ```js ` in JavaScript mode).
- P1 patterns in this profile: unvalidated `as`/`any` on external data, floating promises on request or job paths, `@ts-ignore`/`!` hiding a real nullability gap, import-time singletons holding mutable state, discriminated unions without exhaustive handling where a missed case corrupts data.
- False positives: a boolean option with no alternative domain meaning; a `getX` name required by an external interface or framework convention; an entry-point barrel that is the package's documented public API.
