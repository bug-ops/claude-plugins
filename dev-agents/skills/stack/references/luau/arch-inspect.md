# Luau — Architecture Inspection Rules

Language checklist for the `arch-inspect` protocol. Section numbers match the protocol's focus areas. Lua mode: skip the Luau type-check evidence and treat "no type information at all" (no LuaLS annotations, no `lua-language-server --check` in CI) as a `type-system` finding for libraries.

## Evidence Commands

Read-only still allows running the toolchain: the type checker, linter, and formatter check give evidence without touching tracked files. Generating `sourcemap.json` writes an untracked, ignored file — allowed; write it to `.local/` when the project does not ignore it. Run these before reading by hand:

| Evidence | Command |
|----------|---------|
| Type errors | toolchain.md **Type check** |
| Strictness per file | `rg --files-without-match -e '--!strict' -g '*.luau' src` (files without the directive), `rg -n -- '--!(nonstrict|nocheck)' src` |
| Lint findings | toolchain.md **Lint** (`selene .`) |
| Format drift | toolchain.md **Format check** |
| Require graph and cycles | `rg -n 'require\(' src` — build the edge list by hand; flag client→server and shared→realm edges |
| Escape hatches | `rg -n ':: any|getfenv|setfenv|loadstring|_G\.|shared\.' src` |
| Copy-paste duplication | `jscpd --format lua src` (when available) |
| Dependency drift | compare `wally.lock`/`pesde.lock` against the latest registry versions (researcher commands) |

Do not create config files in the repository to run an audit.

## Every-Cycle Specifics

- **Modern APIs** — there is no knowledge skill; the source is the Luau features the runtime supports: string interpolation, `if-then-else` expressions, compound assignment, generalized iteration, `table.clone`/`table.freeze`, `buffer`, floor division, `task.*`, `@native`, user-defined type functions where the solver supports them. Cite the API and file/line.
- **Version policy** — Roblox code targets the live engine: the floor is "what Roblox ships today", so deprecated engine APIs are findings. Lune code targets the version pinned in `rokit.toml`. Lua libraries target the Lua versions in the rockspec `dependencies`.

## 1. Type Safety

- **Weak modes** — files without `--!strict`, files in `--!nonstrict`/`--!nocheck`; `.luaurc` `languageMode` not `strict` for new code.
- **`any` and its leaks** — `:: any` casts, untyped function parameters in public modules, `{ [any]: any }` tables, untyped remote handlers.
- **Unvalidated boundaries** — remote arguments, `JSONDecode` output, DataStore values, `GetAttribute` results, and `MessagingService` payloads used without a validator. Each remaining cast carries a reason comment; absence is P1 on server code.
- **Boolean blindness** — `spawnEnemy(true, false)` → an options table with a singleton-string union: `spawnEnemy({ kind = "boss", aggro = "passive" })`.
- **Optional-field bags instead of tagged unions** — `{ loading: boolean, data: T?, err: string? }` allows invalid combinations; model states as a union on a `kind` tag.
- **Primitive-typed domains** — bare `number` user ids, currency, and item ids passed around interchangeably; a validating constructor, and a tagged wrapper where mixing them is a real risk.
- **Post-construction validation** — `obj:isValid()` checks on built objects → validate in `X.new`.
- **Mutable shared tables** — config and constant tables returned from modules without `table.freeze`; callers mutating another module's state.

## 2. Modularity

- **Realm boundaries** — server code under `ReplicatedStorage`, client modules requiring server modules, shared modules branching on `RunService:IsServer()`.
- **Dependency direction** — domain logic requiring Roblox services directly (`DataStoreService`, `Players`) instead of receiving them; UI modules owning game rules.
- **Require cycles** — every cycle is a finding; Roblox errors on cyclic `require`.
- **Entry points** — many independent Scripts with implicit start order; services started from several places.
- **Package boundaries** — requiring into another package's internal files (`Packages._Index...`) instead of its entry point; vendored copies of packages that also appear in `wally.toml`.
- **Cohesion** — a `Utils`/`Shared` module that everything requires and that mixes unrelated helpers.

## 3. Testability

- **Require-time side effects** — modules that connect events, start loops, read DataStores, or call `WaitForChild` chains when required; tests cannot require them in isolation.
- **Concrete engine access** — business logic calling `DataStoreService`, `HttpService`, `MarketplaceService` directly → pass a small interface so a fake can replace it.
- **Ambient dependencies** — `os.time()`, `os.clock()`, `math.random()`, `Random.new()` without a seed, `Players.LocalPlayer` read inside logic → inject a clock, a random source, the player.
- **Engine-bound logic** — pure rules (damage formulas, inventory math, matchmaking) living inside Scripts instead of ModuleScripts that Lune or a headless runner can test.
- **Global mutable state** — `_G`, `shared`, module-level caches that leak between specs.

## 4. Readability

- **Naming** — one convention per project (`camelCase` or engine-style `PascalCase` methods); `PascalCase` for modules returning classes or services; `UPPER_SNAKE_CASE` only for true constants. Booleans read as questions (`isAlive`, `hasPass`).
- **Accessor names that lie** — `getX()` that yields or hits a DataStore (should be `loadX`/`fetchX`, documented as yielding).
- **Long positional parameter lists** — more than three parameters → one options table.
- **Complexity evidence** — deeply nested `if` chains in remote handlers, functions longer than a screen, `and/or` ternary chains.
- **Comment quality** — LuaLS or Moonwave doc comments that restate types already in the signature.

## 5. DRY

- **Parallel type definitions** — the same payload type written in client and server modules → one shared types module or generated network code.
- **Repeated validation** — the same `typeof`/range checks in several remote handlers → one validator per payload.
- **Re-implemented utilities** — signals, cleanup objects, promise helpers, table utilities copied into several modules when a package or shared module exists.
- **Debt markers** — clusters of `:: any`, `--!nocheck`, and `selene: allow` in one module mark sustained neglect.

## 6. Async Concurrency

- **Deprecated scheduling** — `wait`, `spawn`, `delay` (throttled, unpredictable resumption) → `task.*`.
- **Lost errors** — `task.spawn`/coroutine errors that only reach the output window; Promise rejections without `:catch`.
- **Check-then-act across yields** — state read before a yielding call and trusted after it (inventory, currency, player presence).
- **Unbounded fan-out** — a thread per player or per item on large collections; per-frame `task.spawn`.
- **Missing timeouts** — `WaitForChild` without a timeout on optional instances; HTTP calls without a deadline; Promises without `:timeout`.
- **Leaked connections and threads** — `Connect` without an owner; threads not cancelled on cleanup (`task.cancel`).
- **Parallel Luau misuse** — DataModel writes in desynchronized code; shared tables mutated from several actors without a protocol.
- **Shutdown** — no `BindToClose`, or one that does not wait for in-flight saves.

## 7. Error-Handling Design

- **Unchecked `pcall`** — the success flag ignored or the error value discarded.
- **Thrown non-strings without structure** — `error({})` tables with no type or message; errors that lose position because of level `0`.
- **Swallowed errors** — `pcall(fn)` used to "make it stop crashing" with no logging or fallback.
- **Library error model** — callers matching on error message substrings → a tagged error or `Result` type.
- **Crashing on recoverable input** — `assert` on client-supplied values in server code (a malformed request should be rejected, not crash the handler with a stack trace in the output).

## 8. API Stability

- **Semver of exports** — for published packages, everything in the returned table and every `export type` is API. Breaking: removing a field, renaming a method, adding a required option, narrowing a parameter type, changing yielding behavior (a function that starts yielding breaks callers inside non-yieldable contexts).
- **Realm changes** — moving a Wally package from `shared` to `server` realm breaks client consumers.
- **Closed unions that will grow** — consumers' exhaustive branches break when a tag is added.
- **Wire and storage formats** — remote payload shapes and DataStore schemas are API across server versions and between client and server; changes need versioning.

## 9. Observability

- **Unstructured logging** — `print` and `warn` scattered through production code with no prefix, player id, or event name; a logger module with levels is the target.
- **Error reporting** — `ScriptContext.Error` not hooked for aggregation in production experiences; server errors not tagged with the place version.
- **Profiling markers** — hot systems without `debug.profilebegin`/`debug.profileend` labels and memory categories (`debug.setmemorycategory`), so MicroProfiler and memory views stay anonymous.
- **Analytics** — key funnel events not emitted through the project's analytics layer (`AnalyticsService` or its wrapper) where the project tracks them.

## 10. Lint and Manifest Hygiene

- **Linter configuration** — `selene.toml` missing, wrong `std` for the target (Roblox vs Lua version), warnings allowed to accumulate, broad `allow` lists.
- **Blanket suppressions** — file-wide `-- selene: allow(...)`, `--!nocheck` on whole folders.
- **Formatter** — no `stylua.toml`, or CI without the format check.
- **Toolchain pins** — tools installed globally instead of pinned in `rokit.toml`; CI using different versions than developers.
- **Manifests** — `Packages/` or `sourcemap.json` committed; `wally.lock` not committed for games; dependencies declared with unbounded ranges; dev-only packages (test frameworks) in runtime `[dependencies]`.
- **Doc warnings** — Moonwave or LuaLS doc-generation warnings when the project builds docs; count them.

## Filing

- Before/After blocks use ` ```luau ` (` ```lua ` in Lua mode).
- P1 patterns in this profile: unvalidated remote arguments on server code, server authority delegated to the client, secrets in replicated code, DataStore writes without session locking or `UpdateAsync` where duplication is possible, unchecked `pcall` around persistence.
- False positives: `:: any` at the boundary of an untyped third-party package with a reason comment; `print` in Studio-only debug tools and command bars; `--!nonstrict` on generated files.
