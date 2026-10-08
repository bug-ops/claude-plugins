# TypeScript — Architect Rules

TypeScript types are erased at runtime: every invariant needs a type-level encoding AND a single runtime construction point (smart constructor or schema) at the trust boundary. JavaScript mode: express the same designs with JSDoc (`@typedef`, `@template`, `@param`) under `// @ts-check` or `checkJs`, and lean harder on runtime constructors.

## Type-Level Toolkit

| Invariant | TypeScript construct |
|-----------|----------------------|
| Domain value (id, email, amount) | Branded type + smart constructor; brand key is a module-private `unique symbol` |
| Closed set of alternatives | Discriminated union with a literal `kind` tag, switched exhaustively with a `never` check |
| Compile-time marker, zero cost | Phantom type parameter carried by a brand field (`readonly [state]: S`) |
| State-machine correctness | Typestate: phantom state parameter, transitions return a new value typed with the next state |
| Extension point external code must not implement | Closed union of known variants, or a class with a `#private` field (structural typing cannot forge it) |
| Type chosen by the caller | Generic parameter |
| Type determined by the implementor | Indexed access / associated property type (`Handler["output"]`) or `infer` from the implementation |
| Constant tables checked against a type | `as const satisfies Record<Key, Spec>` |

```ts
declare const userIdBrand: unique symbol;
export type UserId = string & { readonly [userIdBrand]: true };

export type ParseError = { kind: "empty" } | { kind: "too-long"; max: number };
export type Result<T, E> = { ok: true; value: T } | { ok: false; error: E };

export function parseUserId(raw: string): Result<UserId, ParseError> {
  if (raw.length === 0) return { ok: false, error: { kind: "empty" } };
  if (raw.length > 64) return { ok: false, error: { kind: "too-long", max: 64 } };
  return { ok: true, value: raw as UserId };
}
```

The only `as` to a branded type lives inside its constructor. External data (`JSON.parse`, request bodies, env, `fetch` responses) is `unknown` until a schema the project already uses (zod, valibot, arktype, typebox) parses it; derive the static type from the schema (`z.infer<typeof Schema>`) instead of declaring it twice. No `isValid()` on a constructed value.

Typestate:

```ts
declare const state: unique symbol;
type Draft = "draft";
type Sent = "sent";
export type Email<S> = { readonly to: string; readonly body: string; readonly [state]: S };

export declare function send(email: Email<Draft>): Promise<Email<Sent>>;
```

Do not export the brand or state symbols; export constructors and transition functions only.

## API Naming

- `toX()` for conversions (`toJSON`, `toString`); `fromX()` / `parseX()` static or module-level factories; `tryParseX()` only if the project distinguishes throwing from non-throwing variants.
- Getters are plain `readonly` properties or `get` accessors — no `getName()` methods for stored data.
- Predicates and type guards: `isX(value): value is X`, `hasX`; assertion functions `assertX(value): asserts value is X`.
- Types and interfaces in PascalCase without `I`/`T` prefixes; named exports over `export default` in libraries.
- Options objects over positional optional parameters once a function has more than two.

## Scale-Appropriate Layout

| Scale | Package strategy | Type complexity |
|-------|------------------|-----------------|
| MVP/Prototype | Single package, folders per domain | Branded ids, discriminated unions |
| Small | Single package, subpath entry points in `exports` | + Schemas at every boundary, builders/options objects |
| Medium | 2–5 packages in a pnpm/npm/yarn workspace with TS project references | + Typestate for critical paths |
| Large | Monorepo with a task runner (turbo, nx), library-first, API reports per package | Full type-driven design |

**MVP / Prototype** (single package):
```
my-project/
├── package.json
├── tsconfig.json
├── src/{index.ts, domain/, services/}
└── test/
```

**Medium / Large** (workspace):
```
my-project/
├── package.json             # private root, scripts and dev tooling only
├── pnpm-workspace.yaml
├── tsconfig.base.json       # shared compilerOptions
├── tsconfig.json            # solution file: "files": [], "references": [...]
├── packages/{core, cli, server}/
├── .local/handoff/
└── docs/
```

## Workspace Conventions

Defaults — follow the project's existing convention when one exists:

1. **One package manager**, pinned in the root `packageManager` field; the root `package.json` is `"private": true`.
2. **Internal dependencies** use the workspace protocol (`"@acme/core": "workspace:*"`); shared third-party versions are pinned once (pnpm `catalog:` entries in `pnpm-workspace.yaml`, or a single root constraint) when the repo uses catalogs.
3. **Project references**: each package `tsconfig.json` extends `tsconfig.base.json`, sets `composite: true`, and lists `references` to the packages it imports; type-check the graph with `tsc -b`.
4. **Dependency direction**: `core` imports nothing internal; apps import libraries, never the reverse. No cycles between packages — enforce with `dependency-cruiser` or the task runner's boundary rules when configured.
5. **Optional capabilities are additive** — separate entry points or packages, never a flag that removes API.

```jsonc
// tsconfig.base.json
{
  "compilerOptions": {
    "strict": true,
    "noUncheckedIndexedAccess": true,
    "exactOptionalPropertyTypes": true,
    "verbatimModuleSyntax": true,
    "isolatedModules": true,
    "declaration": true,
    "declarationMap": true,
    "module": "nodenext",
    "target": "es2023"
  }
}
```

## Public API Surface

- The `exports` map in `package.json` is the API boundary: list each public entry point; anything not listed is unreachable. Put the `types` condition first in each entry.
- Decide the module format up front: ESM-only (`"type": "module"`) by default; dual ESM/CJS only when CJS consumers on runtimes without `require(esm)` must be supported — and then guard against the dual-package hazard (two module instances, `instanceof` and singletons break).
- `"files"` allow-lists what ships; `"sideEffects": false` when true, so bundlers can tree-shake.
- Exported types are API: changing a union, narrowing a parameter, or widening a return type is a breaking change. Annotate return types of exported functions explicitly so inferred internal types do not leak.
- Public types never expose a dependency's types unless that dependency is a `peerDependency`.
- Verify the packed artifact with the package publish check and public API report from `toolchain.md`.

## Runtime Targets

- Decide where each package runs: Node.js, browser, edge/workers, Bun/Deno, or isomorphic. Set `lib` and `types` per target so APIs from the wrong runtime fail to type-check (no `dom` in server packages, no `@types/node` in browser packages).
- Isomorphic packages use only web-standard APIs (`fetch`, `URL`, `AbortController`, Web Crypto, Web Streams) or isolate runtime-specific code behind `exports` conditions (`node`, `browser`, `worker`, `default`).
- `module`/`moduleResolution`: `nodenext` for code Node runs or resolves directly (libraries, servers); `bundler` for code always consumed through a bundler (apps on Vite, Next.js).
- Code run directly by Node's type stripping: enable `erasableSyntaxOnly` (TypeScript 5.8+) — no `enum`, `namespace`, or constructor parameter properties.
- `engines.node` is the version floor; raising it is a breaking change for published packages.

## Async Concurrency Patterns

| Pattern | Use Case | Primitive |
|---------|----------|-----------|
| All succeed or fail together | Batch writes | `Promise.all` |
| Independent operations, collect every outcome | Parallel API calls | `Promise.allSettled` |
| First result wins | Fastest replica | `Promise.any` (first success) / `Promise.race` (first settle) |
| Timeout + operation | Network call | `AbortSignal.timeout(ms)`, combined with the caller's signal via `AbortSignal.any` |
| Bounded concurrency over a collection | Rate-limited processing | `p-limit` / `p-map` with `concurrency`, or batched `Promise.all` |
| Stream with backpressure | File/network pipelines | `stream/promises` `pipeline` with async generators |
| CPU-bound work | Hashing, parsing, image work | `worker_threads` (pool: `piscina`) — never on the event loop |

Cancellation: every long-running async API accepts an `AbortSignal` and propagates it. Graceful shutdown: handle `SIGTERM`, stop accepting work, drain in-flight requests, close pools.

## Checklist Additions

- [ ] Runtime target per package decided; `lib`/`types` set to match
- [ ] Module format (ESM-only vs dual) and `moduleResolution` decided
- [ ] `engines.node` and minimum TypeScript version decided
- [ ] `exports` map designed; internal modules unreachable
- [ ] Trust boundaries identified, each with one schema
- [ ] Package dependency graph acyclic; project references mirror it

## Tools

Beyond `toolchain.md` (type check, public API report, package publish check, unused exports via `knip`):

```bash
tsc -b                                    # Build/type-check the project-reference graph
tsc --noEmit --extendedDiagnostics        # Type-check time and memory per phase
tsc --noEmit --generateTrace <dir>        # Trace slow types
npx madge --circular src                  # Import cycles (or dependency-cruiser)
pnpm why <pkg>                            # Why a dependency is present (npm explain <pkg>)
```

## Anti-Patterns

- `enum` and `namespace` in new code — use literal unions / `as const` objects and ES modules
- Bare `string`/`number` for ids and unit-bearing values instead of branded types
- Optional-property bags (`{ status?: ...; error?: ...; data?: ... }`) where a discriminated union encodes the valid combinations
- `T | null | undefined` used as three distinct states
- Class hierarchies where a discriminated union + functions would do
- Barrel files re-exporting a whole package (import cycles, defeated tree-shaking)
- Consumers deep-importing `pkg/dist/internal/...` because the `exports` map is missing an entry
- `any` or dependency-owned types in the public API
- Cycles between workspace packages, or a `core` package that imports an app
- Deep conditional/mapped types that make errors unreadable and type-checking slow where a plain type suffices
