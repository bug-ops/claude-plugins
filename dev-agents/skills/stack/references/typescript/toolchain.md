# TypeScript Toolchain Profile

Covers TypeScript and plain JavaScript on Node.js, Bun, and the browser. JavaScript mode (no `tsconfig.json`, no `typescript` dependency): skip type-check-only steps, keep everything else; JSDoc types plus `// @ts-check` are the type-safety tool there.

## Project Facts

- **Manifest**: `package.json`. Compiler config: `tsconfig.json` (follow `extends` and `references`).
- **Package manager**: the `packageManager` field wins; otherwise the lockfile decides — `pnpm-lock.yaml` → pnpm, `yarn.lock` → yarn, `bun.lock`/`bun.lockb` → bun, `package-lock.json` → npm. Use only that manager; never mix lockfiles, never edit a lockfile by hand.
- **Workspaces**: `pnpm-workspace.yaml` or the `workspaces` field; task runners `turbo.json` / `nx.json`. Run commands from the package that owns the change, or through the runner's filter (`pnpm --filter <pkg>`, `turbo run <task> --filter=<pkg>`).
- **Runtime and framework**: `engines.node`, `.nvmrc`/`.node-version`, `bun`/`deno.json`; framework from dependencies (React/Next.js, Svelte/SvelteKit, Vue/Nuxt, Vite, Express/Fastify/Hono). Follow the framework's conventions over generic advice.
- **Version policy**: never use a language feature, `lib` API, or Node API newer than `engines.node`, `tsconfig` `target`/`lib`, and the installed `typescript` version allow. Raising `engines.node` or the minimum TypeScript version of a published package is a breaking change.
- **Module system**: `"type": "module"` in `package.json` and `module`/`moduleResolution` in `tsconfig` (`nodenext`, `bundler`) decide import syntax and whether relative imports need the `.js` extension. Match them.
- **Strictness**: `strict: true` is the baseline; `noUncheckedIndexedAccess`, `exactOptionalPropertyTypes`, `noImplicitOverride` when the project has them. Never loosen compiler options to make code compile.
- **Dependencies**: add with the project's manager (`pnpm add`, `pnpm add -D` for dev-only); runtime dependencies only for code that ships. Check the current version (context7 or the registry) before adding one; prefer packages with bundled types over `@types/*` when both exist.
- **Dependency APIs**: never call one from memory. Check the installed version (`node_modules/<pkg>/package.json`) and verify the signature in its `.d.ts` files or the docs for that version. When `tsc` disagrees with your memory, the compiler is right.

## Commands

Prefer the project's `package.json` scripts (`<pm> run typecheck`, `lint`, `test`, `build`); they encode the CI setup. Defaults when no script exists — run local binaries through `<pm> exec` / `npx`, never global installs:

| Purpose | Command |
|---------|---------|
| Type check | `tsc --noEmit` (`tsc -b` with project references; `vue-tsc --noEmit`, `svelte-check` for those frameworks) |
| Lint | `eslint .` or `biome check .` — whichever the repo configures |
| Format check / fix | `prettier --check .` / `prettier --write .`, or `biome format .` / `biome format --write .` |
| Unit tests | `vitest run`, `jest`, or `node --test` — whichever the repo configures |
| End-to-end tests | `playwright test` (when configured) |
| Build | `<pm> run build` |
| Dependency audit | `npm audit --audit-level=high`, `pnpm audit --audit-level high`, `yarn npm audit`, `bun audit` |
| Outdated dependencies | `<pm> outdated` |
| Unused files, exports, dependencies | `knip` |
| Package publish check | `publint`, `attw --pack` (`@arethetypeswrong/cli`), `npm pack --dry-run` |
| Public API report | `api-extractor run` (when configured) |

**Full check suite** (run before handing off code; must match CI): type check, lint, format check, unit tests, build when the package is built or published. When the CI workflow runs other scripts or env vars, use those exactly.

## Documentation Conventions

- Every exported symbol gets a TSDoc `/** ... */` comment that explains *what* and *why*.
- Use `@param`, `@returns`, `@throws` for non-obvious contracts; add `@example` for non-trivial public APIs.
- Module overview: a file-level `/** @packageDocumentation */` comment for package entry points.
- Interface and type docs state the contract: what implementors guarantee, what callers may assume.
- Doc gate: the TypeDoc or API Extractor build when the repo configures one; otherwise `tsc` must pass with the comments intact.

## Markers and Comment Syntax

- Line comments: `// TODO(#123): ...`, `// TODO(review): ...`, `// ASSUMPTION: ...`.
- Type-system escape hatches carry a reason: `// @ts-expect-error -- <reason>` (never `@ts-ignore`), `as` casts and `!` non-null assertions get a one-line comment on why the runtime shape is guaranteed.
- Lint suppressions name the rule and the reason: `// eslint-disable-next-line <rule> -- <reason>`; never file-wide disables.

## Knowledge Skills

None. Verify newer language and runtime features against `engines.node`, `target`/`lib`, and the installed `typescript` version instead.
