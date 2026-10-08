# TypeScript — Researcher Rules

Covers JavaScript mode as well; skip the type-related health signals for packages consumed only from plain JavaScript.

## Off-Limits Files

Never edit `package.json`, any lockfile, `tsconfig*.json`, `.npmrc`, `pnpm-workspace.yaml` (catalogs, overrides), source files, or CI workflows — not even to bump a dependency version.

## Dependency Monitoring Commands

Use the project's package manager (see `toolchain.md`):

```bash
<pm> outdated                          # version drift; pnpm: add -r in a workspace; npm exits non-zero when anything is outdated
npm audit --audit-level=high           # advisories (GHSA) against the lockfile; pnpm/yarn/bun equivalents in toolchain.md
npm audit --omit=dev                   # runtime-only exposure
npm audit signatures                   # registry signatures and provenance attestations of installed packages
npm view <pkg> versions --json         # published versions
npm view <pkg> time --json             # release dates
npm view <pkg> deprecated              # deprecation notice, if any
npm ls <pkg>  |  pnpm why <pkg>        # who pulls a package in
```

`osv-scanner` pointed at the lockfile cross-checks advisories against OSV, which aggregates GHSA and other sources. Overrides (`overrides`, `pnpm.overrides`, `resolutions`) pinned for an old advisory are findings once the upstream fix is released — the pin can go.

## Sources

| Need | Source |
|------|--------|
| Versions, metadata, dist-tags | npmjs.com, registry JSON `https://registry.npmjs.org/<pkg>` |
| Download counts | `https://api.npmjs.org/downloads/point/last-week/<pkg>` |
| Advisories | GitHub Advisory Database (npm ecosystem), OSV, NVD |
| Supply-chain signals | Socket (install scripts, network/filesystem access, obfuscation, typosquats), deps.dev, OpenSSF Scorecard |
| Size and weight | packagephobia (install size), bundlephobia (bundle size for front-end code) |
| Native replacements | e18e community guidance, the `module-replacements` dataset |
| Language and runtime evolution | TypeScript release notes, Node.js release schedule (LTS and end-of-life dates), TC39 proposals |

## Package Health Signals

- Last publish date, commit activity, maintainer count (bus factor), issue and PR response time
- `deprecated` field on the installed version; archived repository
- Types: bundled (`types` field or a `types` condition in `exports`) vs a `@types/*` package that lags the library; `attw --pack` results for type resolution correctness
- Module format: ESM-only, CJS-only, or dual `exports` — an ESM-only major breaks CJS consumers
- `engines.node` of the update vs the project's `engines.node` — a raised floor is a blocker or a breaking change for the project
- Install scripts (`preinstall`, `install`, `postinstall`), npm provenance present or absent
- Transitive dependency count and install size; bundle size and tree-shakability (`sideEffects`) for browser code
- Weekly download trend as an adoption signal, never as the only one

## Update Priority Triggers

| Trigger | Priority |
|---------|----------|
| GHSA advisory for a locked version in a runtime dependency | Immediate (P0/P1) |
| Malicious-version or compromised-maintainer report for any locked package | Immediate (P0) |
| Advisory only in a dev dependency not reachable at runtime | Next PR (P2) |
| `deprecated` notice on a direct dependency | Next PR or backlog (P2/P3), with the suggested successor |
| Node.js version in `engines` reaching end-of-life | Backlog research issue (P3) |
| Duplicate major versions of a heavy package in the tree | Backlog (P3/P4) |

Semver notes: for `0.x` packages a minor bump is breaking; `@types/*` versions track the library's major.minor, not semver of the types, so a "patch" can break compilation; `^` ranges let the lockfile drift — compare locked versions, not declared ranges.

## Dependency Functionality Coverage — TypeScript Examples

- Schema validators (zod, valibot, arktype): inferred types replacing hand-written duplicates, transforms and refinements replacing manual post-validation
- `fetch` / undici: `AbortSignal.timeout()` and `AbortSignal.any()` replacing hand-rolled timeout wrappers
- ORMs and query builders (Prisma, Drizzle, Kysely): transactions, typed raw queries, migrations the project reimplements
- Framework features (Next.js caching and server actions, SvelteKit form actions and load functions, Fastify schemas and hooks)
- Loggers (pino): child loggers, redaction, structured fields replacing string concatenation
- The reverse: packages replaced by the runtime — `node:test`, global `fetch`, `structuredClone`, `util.parseArgs`, `util.styleText`, `crypto.randomUUID` — check against the project's `engines.node`

## TypeScript Research Topics

- Type-level techniques: branded types, `satisfies`, `const` type parameters, template literal types, `using` declarations for resource cleanup
- Compiler and tooling evolution: the native TypeScript compiler (TypeScript 7 / `tsgo`), isolated declarations, Node's built-in type stripping
- Build tooling: Vite and Rolldown, tsup/tsdown, biome and oxlint, bundle analysis
- Runtime: Node LTS features, Bun and Deno compatibility, edge runtimes, worker threads for CPU-bound work
- Performance: streaming responses, bundle splitting and tree-shaking, startup time, event-loop utilization
- Ecosystem cleanup: dependencies replaceable by native APIs or lighter packages (e18e)

## Reference Projects

Same tech stack first: TypeScript projects in the domain, found through npm search and keywords, GitHub topics, and the dependents of the project's key packages.

## Vulnerability Classes Common in TypeScript/JavaScript

- Prototype pollution through deep merge, path setters, or query-string parsing
- ReDoS — catastrophic backtracking in user-facing regular expressions
- Command injection through `child_process.exec` or `shell: true` with interpolated input
- Path traversal in static file serving, archive extraction, and upload handling
- SSRF through server-side `fetch` of user-supplied URLs
- XSS through `dangerouslySetInnerHTML`, `v-html`, `{@html}`, `innerHTML`, or unescaped templates
- Unsafe deserialization and `eval`/`new Function` on untrusted input
- Supply chain: malicious versions, install scripts, typosquatting, dependency confusion between private and public scopes, protestware
