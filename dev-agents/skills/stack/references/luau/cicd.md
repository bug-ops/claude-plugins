# Luau — CI/CD Rules

SHAs below were resolved on 2026-10-24. Re-resolve them for the version you add (see Action Pinning in the agent prompt); never copy them blindly. Every CLI comes from the project's `rokit.toml`, so CI and developers run the same versions. Prefer the project's scripts (`justfile`, Lune scripts) over raw tool calls — they are the full check suite from `toolchain.md`.

## Complete GitHub Actions Workflow (Roblox)

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
      - uses: actions/cache@55cc8345863c7cc4c66a329aec7e433d2d1c52a9 # v6.1.0
        with:
          path: |
            ~/.rokit/bin
            ~/.rokit/tool-storage
          key: rokit-${{ runner.os }}-${{ hashFiles('rokit.toml') }}
      - uses: CompeyDev/setup-rokit@1d9390883f7ebce19d48f5b8d006e11d387c92ab # v0.2.1
      - run: wally install
      - run: rojo sourcemap default.project.json -o sourcemap.json
      - run: wally-package-types --sourcemap sourcemap.json Packages/   # when the project uses it
      - run: curl -fsSL -o globalTypes.d.luau https://luau-lsp.pages.dev/type-definitions/globalTypes.None.d.luau
      - run: stylua --check src
      - run: selene src
      - run: luau-lsp analyze --platform=roblox --definitions:@roblox=globalTypes.d.luau --sourcemap=sourcemap.json src
      - run: rojo build default.project.json -o build.rbxl
```

- `setup-rokit` runs `rokit install` from the manifest it finds in `path`. Leave its own `cache` input off: it uses an unpinned `actions/cache` tag internally; the pinned cache step above covers the same directories.
- The Roblox definitions change with every engine release; downloading them on each run tracks the live engine. Pin a copy in the repository only when reproducible type checks matter more than tracking (and refresh it with Dependabot-like automation).
- selene with `std = "roblox"` fetches its standard library on first run; set `roblox-std-source = "pinned"` in `selene.toml` when CI must work offline.
- pesde projects: replace `wally install` with `pesde install --locked` (check `pesde install --help` for the frozen-lockfile flag of the installed version).

Standalone Luau (Lune): drop the Rojo, sourcemap, and definitions steps; type-check with `luau-lsp analyze --platform=standard src` and run tests with `lune run <runner>`.

Lua mode: use `leafo/gh-actions-lua` and `leafo/gh-actions-luarocks` (pin by SHA) with a matrix over the Lua versions the rockspec supports; run `luarocks make`, `busted`, `luarocks lint <rockspec>`.

## In-Engine Tests (Open Cloud Luau Execution)

Tests that need the engine run in a real server through Open Cloud:

```yaml
  engine-tests:
    name: Engine tests
    if: github.event_name == 'push' || github.event.pull_request.head.repo.full_name == github.repository
    needs: check
    runs-on: ubuntu-latest
    timeout-minutes: 15
    environment: roblox-test
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
      - uses: CompeyDev/setup-rokit@1d9390883f7ebce19d48f5b8d006e11d387c92ab # v0.2.1
      - run: wally install
      - run: rojo build test.project.json -o test.rbxl
      - run: rbxcloud experience publish -f test.rbxl -t saved -p "$TEST_PLACE_ID" -u "$TEST_UNIVERSE_ID"
      - run: rbxcloud luau execute -u "$TEST_UNIVERSE_ID" -i "$TEST_PLACE_ID" -f scripts/run-tests.luau
    env:
      RBXCLOUD_API_KEY: ${{ secrets.ROBLOX_TEST_API_KEY }}
      TEST_UNIVERSE_ID: ${{ vars.TEST_UNIVERSE_ID }}
      TEST_PLACE_ID: ${{ vars.TEST_PLACE_ID }}
```

- `rbxcloud` (`Sleitnick/rbxcloud`) is pinned in `rokit.toml` like every other tool; the execution step submits a task, then poll it and fetch its logs (`rbxcloud luau get-task`, `get-logs`) or use the project's script around the Open Cloud API. The test script must exit with a failure (error) when any test fails, so the task state reflects the result.
- Use a dedicated test experience, never the production place. The API key is scoped to that experience with `universe-places` write and `universe.place.luau-execution-session:write`, restricted by IP where possible, stored as an environment secret.
- Never run this job for pull requests from forks: the key would be exposed to untrusted code.
- Limits: a task runs at most 5 minutes, scripts up to 4 MB, task creation is rate-limited — keep suites small or split them.

## Deployment

```yaml
name: Deploy

on:
  push:
    tags: ["v*"]

permissions:
  contents: read

jobs:
  deploy:
    runs-on: ubuntu-latest
    timeout-minutes: 15
    environment: production
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
      - uses: CompeyDev/setup-rokit@1d9390883f7ebce19d48f5b8d006e11d387c92ab # v0.2.1
      - run: wally install
      - run: rojo build default.project.json -o game.rbxl
      - run: rbxcloud experience publish -f game.rbxl -t published -p "$PLACE_ID" -u "$UNIVERSE_ID"
    env:
      RBXCLOUD_API_KEY: ${{ secrets.ROBLOX_DEPLOY_API_KEY }}
      UNIVERSE_ID: ${{ vars.UNIVERSE_ID }}
      PLACE_ID: ${{ vars.PLACE_ID }}
```

- The underlying API is `POST https://apis.roblox.com/universes/v1/{universeId}/places/{placeId}/versions?versionType=Published` with the place file as the body; the project may call it with `curl` instead of `rbxcloud`.
- Gate production deploys behind a GitHub environment with required reviewers.
- Publish to a staging place first when the experience has one; publishing to production restarts no servers by itself — migrating servers is a separate, deliberate live-ops action.

## Caching Strategies

- Rokit tool binaries: `~/.rokit/bin` and `~/.rokit/tool-storage`, keyed on `rokit.toml`.
- Wally packages: `Packages/`, `ServerPackages/`, `DevPackages/`, keyed on `wally.lock`; pesde: `roblox_packages/` (or the target's folder), keyed on `pesde.lock`.
- The Roblox definitions file is small; do not cache it longer than a day if you cache it at all.

## Security Scanning

- No advisory scanner exists for Wally, pesde, or LuaRocks; CI cannot replace dependency review. Require review of every lockfile diff.
- gitleaks on push for API keys and webhook URLs.
- A scan for remote requires and dynamic code: `rg -n "require\(\s*[0-9]+|loadstring|getfenv|setfenv" src` failing the job on hits.
- Open Cloud keys only in environment-scoped secrets, never in repository variables or logs.

## Dependabot / Renovate

Dependabot has no Wally, pesde, or Rokit ecosystem. Use it for `github-actions` only:

```yaml
version: 2
updates:
  - package-ecosystem: github-actions
    directory: "/"
    schedule:
      interval: weekly
```

Renovate can update `rokit.toml`/`aftman.toml`/`wally.toml` versions through `customManagers` regex rules with the `github-releases` datasource for tools; review each tool update like a dependency update.

## Release Workflow (Packages)

Wally packages publish with `wally publish --token "$WALLY_TOKEN"` (token from a CI secret), pesde packages with `pesde publish`, LuaRocks with `luarocks upload <rockspec> --api-key=$LUAROCKS_API_KEY`. Trigger on a version tag after the full check suite passes; never publish from a pull request job.

## Common Issues & Solutions

**Type check passes locally, fails in CI:** a stale or missing `sourcemap.json`, `Packages/` not installed before analysis, different definitions, or a different luau-lsp version — regenerate in CI and pin tools in `rokit.toml`.

**selene fails on first run offline:** the Roblox std could not be generated — allow network or pin the std.

**`rokit install` rate-limited by GitHub:** pass the job token (the action's `token` input defaults to `github.token`) and cache the tool storage.

**Open Cloud task times out:** split the suite, or move engine-independent specs to Lune.
