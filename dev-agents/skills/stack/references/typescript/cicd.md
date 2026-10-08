# TypeScript — CI/CD Rules

SHAs below were resolved on 2026-10-08. Re-resolve them for the version you add (see Action Pinning in the agent prompt); never copy them blindly. Examples use pnpm; for npm drop the `pnpm/action-setup` step, use `cache: npm` and `npm ci`; for yarn use `cache: yarn` and `yarn install --immutable`; for bun use `bun install --frozen-lockfile`. Prefer the repo's `package.json` scripts over raw tool calls — they are the full check suite from `toolchain.md`.

## Complete GitHub Actions Workflow

**.github/workflows/ci.yml:**

```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:

permissions:
  contents: read

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

jobs:
  check:
    name: Check
    runs-on: ubuntu-latest
    timeout-minutes: 10
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
      - uses: pnpm/action-setup@ea17c68df8912ef543352723c149a84f56e3d413 # v6.1.0
      - uses: actions/setup-node@949feb2413d6458794dcd2491c4babbbce0c15c1 # v7.1.0
        with:
          node-version-file: .nvmrc
          cache: pnpm
      - run: pnpm install --frozen-lockfile
      - run: pnpm run typecheck
      - run: pnpm run lint
      - run: pnpm run format:check

  test:
    name: Test (${{ matrix.os }}, Node ${{ matrix.node }})
    needs: [check]
    runs-on: ${{ matrix.os }}
    timeout-minutes: 20
    strategy:
      fail-fast: false
      matrix:
        os: [ubuntu-latest, macos-latest, windows-latest]
        node: [22, 24]
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
      - uses: pnpm/action-setup@ea17c68df8912ef543352723c149a84f56e3d413 # v6.1.0
      - uses: actions/setup-node@949feb2413d6458794dcd2491c4babbbce0c15c1 # v7.1.0
        with:
          node-version: ${{ matrix.node }}
          cache: pnpm
      - run: pnpm install --frozen-lockfile
      - run: pnpm test
      - run: pnpm run build

  coverage:
    name: Coverage
    needs: [check]
    runs-on: ubuntu-latest
    timeout-minutes: 20
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
      - uses: pnpm/action-setup@ea17c68df8912ef543352723c149a84f56e3d413 # v6.1.0
      - uses: actions/setup-node@949feb2413d6458794dcd2491c4babbbce0c15c1 # v7.1.0
        with:
          node-version-file: .nvmrc
          cache: pnpm
      - run: pnpm install --frozen-lockfile
      - run: pnpm exec vitest run --coverage
      - uses: codecov/codecov-action@303a32d7a59b442fa8d48b6a1cc6825c09c847a5 # v7.1.1
        with:
          token: ${{ secrets.CODECOV_TOKEN }}
          files: coverage/lcov.info

  security:
    name: Security
    runs-on: ubuntu-latest
    timeout-minutes: 10
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
      - uses: pnpm/action-setup@ea17c68df8912ef543352723c149a84f56e3d413 # v6.1.0
      - run: pnpm audit --audit-level high
      - if: github.event_name == 'pull_request'
        uses: actions/dependency-review-action@a1d282b36b6f3519aa1f3fc636f609c47dddb294 # v5.0.0
        with:
          fail-on-severity: high
```

- `pnpm/action-setup` reads the pnpm version from the `packageManager` field; it must run before `actions/setup-node` so `cache: pnpm` finds the binary.
- Node matrix: every Node LTS line inside the `engines.node` range (check the Node.js release schedule — drop end-of-life lines, add a new LTS when it lands). Apps that deploy one runtime test only that version via `node-version-file`.
- Coverage: vitest with `coverage: { provider: "v8", reporter: ["text", "lcov"] }` in the config writes `coverage/lcov.info`; jest uses `--coverage` with the `lcov` reporter. Thresholds belong in `codecov.yml`, not in the runner config twice.
- JavaScript mode: drop the `typecheck` step; keep lint, format, and tests.
- Frameworks: `vue-tsc --noEmit` / `svelte-check` replace `tsc` in the typecheck script; e2e jobs install browsers with `pnpm exec playwright install --with-deps chromium` (Playwright advises against caching browsers — restore time roughly equals download time).

## Caching Strategies

### Package manager store

`actions/setup-node` with `cache: pnpm|npm|yarn` caches the store keyed on the lockfile (`cache-dependency-path` for lockfiles outside the root). Never cache `node_modules` directly.

### Build and tool caches

```yaml
- uses: actions/cache@55cc8345863c7cc4c66a329aec7e433d2d1c52a9 # v6.1.0
  with:
    path: |
      **/*.tsbuildinfo
      .eslintcache
    key: tools-${{ runner.os }}-${{ hashFiles('pnpm-lock.yaml') }}-${{ github.sha }}
    restore-keys: tools-${{ runner.os }}-${{ hashFiles('pnpm-lock.yaml') }}-
```

Pair with `incremental: true` in `tsconfig` and `eslint --cache`. Save caches only from `main` (`actions/cache/restore` on PRs, or a `save` step guarded by `if: github.ref == 'refs/heads/main'`).

### Monorepos

- Turborepo: `turbo run lint test build --affected` (needs `fetch-depth: 0` on checkout) and remote caching via `TURBO_TOKEN` / `TURBO_TEAM` secrets.
- Nx: `nx affected -t lint test build`.
- pnpm alone: `pnpm --filter "...[origin/main]" run test`.

## Security Scanning

- `npm audit` / `pnpm audit` at `--audit-level high` (commands in `toolchain.md`) on every run.
- `actions/dependency-review-action` blocks PRs that add vulnerable or disallowed-license dependencies (`allow-licenses` / `deny-licenses` inputs).
- osv-scanner against the lockfile for a second advisory source; Socket for supply-chain signals (install scripts, typosquats, new maintainers) when the project uses it.
- Install with `--ignore-scripts` in jobs that do not need lifecycle scripts; pnpm only runs dependency build scripts that are explicitly allowed (`onlyBuiltDependencies`) — keep that list short.

## Dependabot / Renovate

**.github/dependabot.yml:**
```yaml
version: 2
updates:
  - package-ecosystem: npm         # also covers pnpm and yarn lockfiles
    directory: "/"
    schedule:
      interval: weekly
    groups:
      minor-patch:
        patterns: ["*"]
        update-types: [minor, patch]
  - package-ecosystem: github-actions
    directory: "/"
    schedule:
      interval: weekly
```

Renovate alternative (`renovate.json`): extend `config:recommended` and `helpers:pinGitHubActionDigests`, group minor and patch updates with a `packageRules` entry. Use one bot, not both.

## Minimum Version Check

```yaml
min-node:
  runs-on: ubuntu-latest
  timeout-minutes: 15
  steps:
    - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
    - id: engines
      run: echo "version=$(node -p "require('./package.json').engines.node.match(/\\d+(\\.\\d+)*/)[0]")" >> "$GITHUB_OUTPUT"
    - uses: pnpm/action-setup@ea17c68df8912ef543352723c149a84f56e3d413 # v6.1.0
    - uses: actions/setup-node@949feb2413d6458794dcd2491c4babbbce0c15c1 # v7.1.0
      with:
        node-version: ${{ steps.engines.outputs.version }}
        cache: pnpm
    - run: pnpm install --frozen-lockfile
    - run: pnpm test
```

Published libraries that promise a minimum TypeScript version also type-check a small consumer fixture with that `typescript` version installed.

## Release Workflow

Changesets: contributors add `.changeset/*.md` files; on `main` the action opens a "Version Packages" PR, and merging it publishes.

```yaml
name: Release

on:
  push:
    branches: [main]

concurrency: ${{ github.workflow }}-${{ github.ref }}

permissions:
  contents: read

jobs:
  release:
    runs-on: ubuntu-latest
    timeout-minutes: 20
    permissions:
      contents: write
      pull-requests: write
      id-token: write
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
      - uses: pnpm/action-setup@ea17c68df8912ef543352723c149a84f56e3d413 # v6.1.0
      - uses: actions/setup-node@949feb2413d6458794dcd2491c4babbbce0c15c1 # v7.1.0
        with:
          node-version-file: .nvmrc
          cache: pnpm
          registry-url: https://registry.npmjs.org
      - run: pnpm install --frozen-lockfile
      - run: pnpm run build
      - uses: changesets/action@ae32849d5ba541f9ae29e40e22a623bc13562f51 # v2.1.2
        with:
          publish-script: pnpm changeset publish
        env:
          NPM_CONFIG_PROVENANCE: "true"
```

- `changesets/action` v2 requires `@changesets/cli` v3. Projects on `@changesets/cli` v2 use the v1 line (`changesets/action@a45c4d594aa4e2c509dc14a9f2b3b67ba3780d0d # v1.9.0`) whose inputs are `publish:` / `version:`.
- Authentication: prefer npm trusted publishing (OIDC, configured per package on npmjs.com; needs `id-token: write` and a recent npm CLI — check npm's docs for the minimum) over a long-lived token. Otherwise pass `NODE_AUTH_TOKEN: ${{ secrets.NPM_TOKEN }}`; `registry-url` makes setup-node write the matching `.npmrc`.
- Provenance: `npm publish --provenance --access public`, `NPM_CONFIG_PROVENANCE=true`, or `"publishConfig": { "provenance": true }` — all need `id-token: write` and a public repository.
- Single-package repos without changesets: trigger on `release: published` and run `npm publish --provenance --access public` after the build.
- Run the package publish checks from `toolchain.md` (`publint`, `attw --pack`, `npm pack --dry-run`) before publishing.

## Configuration Matrix

TypeScript has no compile-time features; the configurations that break independently are:

- **Module formats**: dual ESM/CJS packages run `attw --pack` and a smoke test that packs the tarball (`npm pack`), installs it into a scratch project, and loads it with both `import` and `require`.
- **Optional peer dependencies**: test with and without each optional peer installed.
- **Runtimes**: when the package claims Bun, Deno, or browser support, add a job per runtime (`oven-sh/setup-bun`, `denoland/setup-deno`, Playwright for browsers), pinned by SHA like every other action.
- **Strictness**: libraries type-check their public `.d.ts` under the consumer settings they promise (`strict`, `exactOptionalPropertyTypes`, `moduleResolution: nodenext` and `bundler`).

## Common Issues & Solutions

**Slow builds:**
- Cache the package store and `*.tsbuildinfo`
- Run typecheck, lint, and tests as parallel jobs, not one serial job
- Shard long suites: `vitest run --shard=${{ matrix.shard }}/${{ strategy.job-total }}`, `playwright test --shard=1/4`
- Affected-only runs in monorepos (Turborepo, Nx, pnpm filters)

**Flaky tests:**
```yaml
- uses: nick-fields/retry@ad984534de44a9489a53aefd81eb77f87c70dc60 # v4.0.0
  with:
    max_attempts: 3
    timeout_minutes: 15
    command: pnpm test
```

Runner-level retries (`vitest --retry=2`, Playwright `retries` in config for CI) are narrower than retrying the whole step; both are stopgaps.

**Lockfile drift:** `--frozen-lockfile` / `npm ci` fail when `package.json` and the lockfile disagree — fix by running the install locally and committing the lockfile, never by dropping the flag.
