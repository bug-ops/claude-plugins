# Luau — Security Audit Checklist

Language checklist for the `security-audit` protocol; section numbers match the protocol. Covers Roblox experiences, standalone Luau (Lune) tooling, and Lua mode. Read-only scope covers source files, `*.project.json`, `wally.toml`/`pesde.toml`/rockspecs, lockfiles, and `rokit.toml`; installing packages into a scratch clone, type-checking, linting, and running the tests are allowed. Extra reference frameworks: the Roblox Creator Hub security tactics and the "never trust the client" model, OWASP for Lua services. Exclude `Packages/`, `ServerPackages/`, `DevPackages/`, `roblox_packages/`, `lua_modules/`, and build output from every search unless the item says otherwise.

## 1. Dependency Vulnerabilities

```bash
cat wally.lock pesde.lock 2>/dev/null       # pinned versions and sources
luarocks list --outdated                    # Lua mode
```

- **No advisory feed** — Wally, pesde, and LuaRocks have no GHSA/OSV ecosystem. Record the locked version of every direct dependency, check its repository for security-labeled issues and fix releases, and report "no advisory source" in the handoff instead of "0 advisories".
- **Unmaintained** — archived repositories, no release for years with open security-relevant issues, packages superseded by their author (for example a persistence library replaced by its successor).
- **Duplicates** — the same package at several versions in the lockfile; two copies of a signal or promise library break identity checks.
- **Vendored copies** — packages copied into `src/` drift from upstream fixes; compare with the latest release.

## 2. Unsafe and Escape-Hatch Code (`unsafe`)

```bash
rg -n "loadstring|\bload\(|getfenv|setfenv|require\(\s*[0-9]+|:: any|--!nocheck|rawset|debug\.(setlocal|setupvalue|setmetatable)" -g '*.lua' -g '*.luau' .
rg -n "os\.execute|io\.popen|package\.loadlib|dofile" -g '*.lua' -g '*.luau' .
```

- **Dynamic code** — `loadstring` (and `ServerScriptService.LoadStringEnabled` on in the place), `load`/`dofile` on non-constant input in Lua mode: code execution.
- **Remote requires** — `require(<asset id>)` loads code that its owner can change at any time: a backdoor by construction. P0 when found in server code.
- **Environment manipulation** — `getfenv`/`setfenv` disable Luau optimizations and are a backdoor obfuscation pattern.
- **Type escape hatches** — `:: any` on remote arguments or decoded JSON is type confusion: downstream code trusts a shape nothing checked.
- **Native code (Lua mode)** — C rocks and `package.loadlib`: buffers and lengths from input reaching C.

## 3. Secrets and Sensitive Data

```bash
rg -n -i "api[_-]?key|secret|token|webhook|Authorization|x-api-key" -g '*.lua' -g '*.luau' -g '*.json' .
rg -n "GetSecret|HttpService" src
```

- **Replicated secrets** — any key, webhook URL, or admin list in `ReplicatedStorage`, `ReplicatedFirst`, `StarterPlayer`, `StarterGui`, `Workspace`, or attributes on replicated instances is readable by every player: P0.
- **Secrets in source** — Discord webhooks, external API keys, Open Cloud keys committed to the repository; the fix is the Secrets Store (`HttpService:GetSecret`) and rotation.
- **Secrets in logs** — `print`/`warn` of HTTP responses, headers, or secret values; server output is visible to collaborators and logging services.
- **Personal data** — chat logs, user ids with real-world data, or analytics payloads sent to external services without a stated purpose.

## 4. Input Validation and Injection

```bash
rg -n "OnServerEvent|OnServerInvoke|OnInvoke|SubscribeAsync|ProcessReceipt" -g '*.lua' -g '*.luau' src
```

- **Remote handlers** — for every server entry point check type checks on every argument, finite-number checks (`NaN`, `inf`), integer and range checks, string length caps, enum membership against server tables, Instance ownership and visibility, and a rate limit. A handler that acts on an unchecked argument is High; one that grants currency, items, or damage is Critical.
- **Client authority** — hits, damage, positions, cooldowns, purchase results, or leaderstats computed on the client and reported to the server.
- **`RemoteFunction:InvokeClient`** — the server waits on a client that can yield forever or error: denial of service of the calling thread.
- **Text** — user strings displayed to others without `TextService` filtering (policy violation); user strings used as DataStore keys, instance names, or `FindFirstChild` paths without validation.
- **Lua mode injection** — input concatenated into `os.execute`/`io.popen` commands, SQL strings, `load` chunks, or file paths.

## 5. Cryptography

- **Randomness** — `math.random` and `Random.new()` are not cryptographically secure; codes, tokens, or loot outcomes that players can profit from predicting are generated on the server and never exposed before use. `HttpService:GenerateGUID` is for uniqueness, not secrecy.
- **Home-made crypto** — hand-written hashing or "encryption" of remote payloads to stop exploiters is obfuscation, not security; the server must validate regardless.
- **External services** — HMAC signatures on webhooks and external API requests use a secret from the Secrets Store and a constant-time comparison where the project verifies incoming signatures.
- **Lua mode** — luaossl/lua-resty-* for TLS and crypto; flag MD5/SHA-1 for passwords and tokens.

## 6. Authentication and Authorization

- **Admin and moderation commands** — permission checks on the server by `UserId` (or group rank fetched on the server), never by name or a client-sent flag; admin lists not replicated.
- **Ownership checks** — every action on an object (plot, vehicle, pet, trade) verifies the requesting player owns it.
- **Game passes and developer products** — ownership checked on the server; `ProcessReceipt` idempotent and save-before-grant.
- **Cross-server messages** — `MessagingService` payloads are trusted only if every publisher is server code; validate them anyway.
- **Lua services** — session handling, token verification, and authorization per route in OpenResty/Lapis-style services.

## 7. Crash and Resource-Exhaustion DoS (`panics`)

- **Remote flooding** — no per-player rate limit on remotes that allocate, raycast, save, or broadcast; exploiters fire thousands of requests per second.
- **Unbounded payloads** — huge strings or deeply nested tables accepted from remotes and stored, replicated, or iterated.
- **Yielding handlers** — remote handlers that yield on the client's behalf (DataStore per request) exhaust request budgets for everyone.
- **Infinite loops without yield** — `Script timeout` kills the thread mid-update and can leave state half-written.
- **Errors in shared loops** — one player's bad data erroring inside a loop over all players stops the loop for everyone; isolate per-player work with `pcall`.
- **Server memory** — per-player tables never cleared on leave grow until the server is shut down.

## 8. Supply-Chain Trust

```bash
cat rokit.toml wally.toml pesde.toml 2>/dev/null
rg -n "require\(\s*[0-9]+" .
```

- **Marketplace assets** — free models, plugins, and inserted packages: hidden scripts, obfuscated code, remote requires, scripts in unusual containers (inside meshes, under `Lighting`, `Chat`, `TestService`).
- **Toolchain** — `rokit.toml` pins tools by GitHub release; a tool repository compromise ships to every developer and CI run. Pin exact versions, review tool updates, prefer well-known maintainers.
- **Registries** — Wally and pesde packages are published by account; typosquats and transferred packages are possible. Verify scope and repository of every new dependency.
- **CI deploy keys** — Open Cloud keys with publish scope used in workflows that run on pull requests from forks are a takeover path.

## 9. Network and Service Hardening

- **HttpService** — outbound requests to URLs built from player input (SSRF-like abuse of the game's quota and of internal endpoints behind it); external responses decoded without validation.
- **Webhooks** — Discord or other webhooks called directly from game servers leak the URL to anyone who obtains the place file; proxy through a service the project controls.
- **Replication** — server-only state placed on replicated instances (attributes, values) is visible to clients; streaming settings that let clients learn about hidden objects.
- **Lua services** — TLS verification enabled in HTTP clients, request size limits, timeouts.

## 10. Filesystem and Archives

- **Roblox** — not applicable to game code; check build scripts.
- **Lune and Lua tooling** — scripts that write to paths from arguments or downloaded data (`@lune/fs`, `io.open`) without containment; extraction of downloaded archives in build tooling; temporary files with predictable names.

## 11. Verification Gates

- `--!strict` across server code, and the type check in CI.
- selene in CI with `deprecated`, `undefined_variable`, and `global_usage` rules as errors.
- Tests for every remote validator: wrong types, `NaN`, `inf`, negative and fractional numbers, oversized strings, foreign Instances.
- A periodic scan of the place file (or the Rojo tree) for remote requires and obfuscated scripts.
- Secret scanning (gitleaks) on push; Open Cloud keys scoped and stored only in CI secrets.

## Triage Mapping

- Critical: currency, item, or damage authority on the client; an unvalidated remote that grants value; a remote require or backdoor; a secret in replicated code; `ProcessReceipt` that grants without saving.
- High: remote handlers missing type or ownership checks; no session locking on player data (duplication); unfiltered user text shown to others; admin checks by name.
- Medium: missing rate limits; `InvokeClient`; unbounded payloads; errors in shared loops.

**False positives**: `math.random` for cosmetic effects; `print` in Studio-only tooling; `:: any` around an untyped third-party API with a reason comment; `loadstring` in Studio plugins or command-bar utilities that never ship.

**Handoff scanner line**: `` advisory source: none for Wally/pesde/LuaRocks | remote handlers: <N reviewed / M missing validation> | remote requires: <N> | gitleaks: <N> ``.
