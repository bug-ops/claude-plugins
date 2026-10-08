# TypeScript — Project Init Facts

Applied by the `init-project` skill after `scaffold.sh` runs. Use it to review what the script generated.

## What the Scaffold Detects

- **Marker**: `package.json` or `tsconfig.json` at the root; otherwise one level down (`web/`, `nodejs/`) or under `packages/*/`.
- **Mode**: TypeScript when a `tsconfig.json` exists (root or any unit) or the root `package.json` mentions `typescript`; otherwise JavaScript mode (no type-check step).
- **Package manager**: the `packageManager` field; else the lockfile (`pnpm-lock.yaml`/`pnpm-workspace.yaml` → pnpm, `yarn.lock` → yarn, `bun.lock`/`bun.lockb` → bun, else npm). Yarn with `.yarnrc.yml` is treated as Berry.
- **Units**: workspace packages from `pnpm-workspace.yaml` `packages:` or the `workspaces` field (array, or yarn classic `{ "packages": [...] }`); negated patterns (`!…`) are skipped and `**` is expanded one level only. Without workspaces, the single package. Names come from each `package.json` `name`.
- **Not detected**: Nx/Turborepo projects without package manager workspaces, Deno workspaces (`deno.json` `workspace`), `**` packages nested deeper than one level — add them by hand.

## Verify Skill Review

- **Install**: frozen-lockfile install for the detected manager (`npm ci`, `pnpm install --frozen-lockfile`, `yarn install --immutable`, `bun install --frozen-lockfile`).
- **Build / Type check / Test**: the root `build`, `typecheck` (or `type-check`), and `test` scripts when present; otherwise the manager's recursive form for workspaces (`pnpm -r run <script>`, `npm run <script> --workspaces --if-present`), or `tsc --noEmit` for type checking. Replace with turbo/nx pipelines when the repo runs them (`turbo run build`, `nx run-many -t build`).
- **Run**: one `node <path>` per `bin` entry (built output — run the build first), else the `start` or `dev` script. Fix the list when:
  - the CLI runs from source through a loader (`tsx src/cli.ts`, `node --experimental-strip-types`) — use the project's script;
  - the project is a web app: start the dev or preview server (`<pm> run dev`, `<pm> run preview`) and drive it with `curl` or the Playwright suite (`playwright test`);
  - the project is a library: verification goes through the test suite plus a consumer smoke test of the packed tarball (`npm pack`, install it into a temp project, import the public entry points).
- **Env**: copy `.env.example` to `.env.local` (or the framework's equivalent) with test values; never commit real secrets.

## Rule Templates

- `branching.md` pre-PR block: the project's `package.json` scripts that CI runs (typecheck, lint, format check, test, build); fall back to the full check suite from `toolchain.md`.
- `continuous-improvement.md` Test Configuration: the build-then-run command or dev server with its port; debug output via `NODE_OPTIONS=--enable-source-maps`, the `debug` package's `DEBUG=<namespace>`, or the project's logger level variable (`LOG_LEVEL`, pino's level option).
- Interfaces and critical paths usually map to CLI entry points, HTTP route handlers, schema validation at API boundaries, client/server serialization, and database migrations (Prisma, Drizzle, Kysely).

## .gitignore

The scaffold adds `.local/` and `.claude/agent-memory-local/` only. Confirm the project also ignores `node_modules/`, build output (`dist/`, `build/`, `.next/`, `.svelte-kit/`), `coverage/`, `*.tsbuildinfo`, and `.env*` files other than `.env.example`. The lockfile is committed.
