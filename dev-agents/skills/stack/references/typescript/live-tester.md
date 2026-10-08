# TypeScript — Live Tester Rules

JavaScript mode applies unchanged: live testing runs the shipped artifact, so the type checker plays no part here.

## Off-Limits Files

Read-only for the whole session: `*.ts`, `*.tsx`, `*.mts`, `*.cts`, `*.js`, `*.jsx`, `*.mjs`, `*.cjs`, `*.vue`, `*.svelte`, `package.json`, every lockfile, `tsconfig*.json`, bundler and framework configs (`vite.config.*`, `next.config.*`, `svelte.config.*`, ...), lint/format configs, CI workflows.

## Project Discovery

1. `package.json` — `bin` (CLI entry points), `main`/`exports` (library entry points), `scripts` (`build`, `start`, `dev`, `preview`, `serve`), `engines.node`, `type`.
2. Workspaces (`pnpm-workspace.yaml`, `workspaces`) — which packages are apps (runnable) and which are libraries (driven through an app or a scratch consumer).
3. Framework from dependencies — Next.js, SvelteKit, Nuxt, Vite SPA, Express/Fastify/Hono server, Electron — decides the run commands and the production-like mode.
4. Env and test configs: `.env`, `.env.test`, `.env.local`, `.local/config/`, `playwright.config.*`, `vitest.config.*`.
5. Runtime: Node (`engines.node`, `.nvmrc`), Bun, Deno, or edge targets — test on the runtime the project ships for.

## Running the Project

Test the artifact users get: build first, then run the build output.

```bash
<pm> run build
node dist/cli.js <args>                 # CLI: the file `bin` points to
<pm> exec <bin-name> <args>             # CLI via its bin link inside the workspace
<pm> run start                          # server or Next.js app: production build
<pm> run preview                        # Vite/SvelteKit: serve the production build locally
<pm> run dev                            # dev server: only for HMR/dev-only flows, never as the sole check
```

- Running sources directly (`tsx src/cli.ts`, or `node src/cli.ts` on Node versions with type stripping on by default) is fine for quick probes, but a finding must reproduce against the build output — packaging bugs live only there.
- Libraries: `npm pack` (or `<pm> pack`) into `.local/testing/`, install the tarball into a scratch consumer project there, and exercise it as a user would — both `import` and `require` when the package claims dual ESM/CJS support, and with `"moduleResolution": "nodenext"` and `"bundler"` consumers when it ships types.
- Long-running servers: start in the background, capture stdout/stderr to `.local/testing/debug/`, exercise with `curl` or a script, then stop the process.

## UI Flows (Playwright)

For web apps, drive the real browser. Prefer the project's own `playwright.config.*` and existing page objects; for exploratory flows write a helper script under `.local/testing/`:

```ts
import { chromium } from "playwright";

const browser = await chromium.launch();
const page = await browser.newPage();
const problems: string[] = [];
page.on("console", (msg) => { if (msg.type() === "error" || msg.type() === "warning") problems.push(msg.text()); });
page.on("pageerror", (err) => problems.push(`pageerror: ${err.message}`));
page.on("requestfailed", (req) => problems.push(`requestfailed: ${req.url()}`));
page.on("response", (res) => { if (res.status() >= 500) problems.push(`${res.status()} ${res.url()}`); });

await page.goto("http://localhost:4173/");
await page.getByRole("button", { name: "Sign in" }).click();
await page.screenshot({ path: ".local/testing/debug/sign-in.png", fullPage: true });
console.log(problems.join("\n"));
await browser.close();
```

Check every flow at a desktop and a mobile viewport, with JavaScript-driven navigation and a hard reload of the same URL. `playwright codegen <url>` records a starting script for a new flow. Use test accounts from the project's seed or fixture files only.

## Debug Output

```bash
DEBUG=<namespace> node dist/cli.js <args> 2>.local/testing/debug/session.log   # `debug` package namespaces
NODE_DEBUG=http,net node dist/server.js 2>.local/testing/debug/session.log     # Node core modules
node --trace-warnings dist/server.js                                           # stack traces for process warnings
```

Logger level variables (`LOG_LEVEL` for pino/winston setups, framework flags) are project-specific — read the logger setup before guessing.

## Crash and Warning Signatures

Grep logs and browser console output for:

- `UnhandledPromiseRejection`, `uncaughtException`, `Error [ERR_...]` codes — an unhandled rejection crashes modern Node and is at least P1
- `FATAL ERROR: ... JavaScript heap out of memory`
- Packaging breakage visible only in the build: `ERR_MODULE_NOT_FOUND`, `ERR_REQUIRE_ESM`, `ERR_PACKAGE_PATH_NOT_EXPORTED`, `Cannot find module`, `ERR_UNKNOWN_FILE_EXTENSION`
- `(node:<pid>) Warning:` lines — `MaxListenersExceededWarning` signals a listener leak, `DeprecationWarning` an API about to break
- `EADDRINUSE`, `ECONNRESET`, `ECONNREFUSED`, `ETIMEDOUT`, `EMFILE` (file-descriptor leak)
- Browser: hydration mismatch errors, `pageerror` events, failed requests, 4xx/5xx from the app's own API
- A server that stops answering while its process stays alive — suspect a blocked event loop or an unresolved promise chain

## Resource Usage

Peak memory and wall time: `/usr/bin/time -l <cmd>` (macOS) or `/usr/bin/time -v <cmd>` (Linux). Long sessions: sample the server's RSS over time — steady growth under a constant workload is a leak finding. Web apps: compare the build output's bundle sizes with the previous session.

## Cross-Interface Pairs

- CLI vs HTTP API vs web UI over the same core package
- Server-rendered page vs the same page after client-side navigation
- Production build vs dev server (env handling, minification, tree-shaking removing side effects)
- ESM vs CJS consumers of a library; Node vs browser vs edge builds of the same package

## Dependency Moves (Unchanged HEAD)

`git log --since=<last-session-date> --oneline -- <lockfile>` lists dependency moves; `git diff <old>..HEAD -- package.json` shows declared range changes.

## Benchmarks

Detect: `*.bench.ts` files, a `bench` script, or `tinybench`/`mitata` in dev dependencies.

```bash
vitest bench --run --outputJson .local/testing/bench/ci-NNN.json
vitest bench --run --compare .local/testing/bench/ci-PREV.json
```

Script-based suites (`<pm> run bench`): record their printed numbers in the journal and compare by hand.

## Environment Hygiene

Stale build output gives false results: remove `dist/`, `.next/`, `.svelte-kit/`, `.turbo/`, and `node_modules/.vite` or `node_modules/.cache` before a comprehensive session. Reinstall only from the lockfile (`npm ci`, `pnpm install --frozen-lockfile`); never let an install rewrite the lockfile.
