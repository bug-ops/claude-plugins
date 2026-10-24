# Luau — Critic Targets

Types are erased at runtime and Luau's checker is structural: every claim of the form "the type guarantees X" must trace back to a runtime check at the trust boundary. On Roblox, assume every client is modified: anything the server receives from a remote, and anything stored in a replicated instance, is attacker-controlled. Lua mode: there is no compile-time safety net, so every type-level target below is a runtime target.

## Counterexample Targets

- **Nil from lookups** — `FindFirstChild`, `WaitForChild` with a timeout, `Players:GetPlayerByUserId`, table indexing (`t[key]` is `nil` for missing keys, never an error): what input makes the value `nil` two calls later? Optional chains hidden behind `::` casts?
- **Remote payloads** — wrong types, `nil`, `NaN` (`x ~= x`), `math.huge`, negative or fractional counts, huge strings, deeply nested tables, Instances the client does not own, tables with metatables stripped: which handler acts before checking?
- **Client authority** — damage, currency, cooldowns, hit detection, positions, or purchase outcomes decided on the client and reported to the server.
- **Yield points** — a function that yields (`WaitForChild`, `InvokeServer`, DataStore and HTTP calls, `task.wait`) in the middle of a check-then-act sequence: what changes while it is suspended (player left, character respawned, round ended, another request arrived)?
- **Player lifecycle** — `PlayerRemoving` firing before an async load finishes; a player rejoining while the old session still saves; `BindToClose` running out of time with saves in flight; characters respawning while handlers hold references.
- **Persistence races** — `GetAsync` then `SetAsync` from two servers (lost updates), no session lock (item duplication across servers), throttled writes dropped without retry, values over the size limit, schema changes without migration.
- **Numbers** — all numbers are doubles: integer ids above 2^53 lose precision, `%` and `//` on negatives, `math.floor` vs truncation, division by zero yields `inf`/`nan` silently, `tostring` of large or fractional numbers in currency displays. Lua mode on 5.3+: integer vs float subtypes (`3 // 1` vs `3.0 // 1`), integer overflow wraps.
- **Truthiness** — only `nil` and `false` are falsy: `0` and `""` are truthy; `a and b or c` returns `c` when `b` is `false`; `#t` on tables with holes is undefined behavior.
- **Iteration** — mutating a table while iterating it with `pairs`/`next`; relying on `pairs` order; removing from an array inside a forward `ipairs` loop.
- **Exhaustiveness** — tagged unions branched with `if/elseif` without a final `error`: what happens when a new tag arrives from an old client or an old saved document?

## Scalability Red Flags

- Per-frame work (`Heartbeat`, `RenderStepped`, `while true do task.wait() end`) that scales with player or instance count
- Remotes fired per frame or per entity instead of batched or sent through `UnreliableRemoteEvent`
- DataStore calls per action instead of a cached session with periodic saves — request budgets run out under load
- Module-level caches keyed by player or instance that are never cleared on leave or destroy
- `GetDescendants`/`FindFirstChild` scans over the whole `Workspace` in hot paths instead of `CollectionService` tags
- Replicating large instance trees or attribute churn every frame to every client
- Server-side physics or raycasts per client request without rate limits

## Completeness

- Errors: every `pcall` result checked; a documented policy for what happens when persistence fails (kick, retry, read-only mode).
- Cleanup: connections, threads, tweens, and created instances are released on player leave, round end, and object destruction.
- Shutdown: `BindToClose` saves every session within the engine deadline; servers closed for an update do not lose data.
- Data versioning: stored documents carry a schema version and a migration path; old clients talking to a new server are handled during rolling updates.
- Content policy: user text filtered through `TextService`; age- and region-gated features checked with `PolicyService`.
- Monetization: `ProcessReceipt` is idempotent (records the purchase id before granting) and returns `NotProcessedYet` on failure.

## Dependency Risk

- Which Wally/pesde/LuaRocks packages are unmaintained, single-maintainer, or archived? There is no advisory database for these registries — check the repository directly.
- Are dependency versions pinned in the lockfile, and does the lockfile match the manifest?
- Free-model or marketplace assets in the place (inserted scripts, plugins): do they `require` remote asset ids or contain obfuscated code? A backdoor is server-side code execution.
- Does the project depend on a package that monkey-patches globals or yields at require time?
- Toolchain pins in `rokit.toml`: does a tool upgrade (Rojo, luau-lsp) change sourcemap or type-checking behavior?

Investigation commands (read-only):

```bash
rg -n "require\(\s*[0-9]+" .            # requires of remote asset ids
rg -n "loadstring|getfenv|setfenv" src
rg -n "OnServerEvent|OnServerInvoke" src  # every server entry point a client can reach
```

## Second-Order Effects

- Type-check time and editor latency: very large unions and deeply generic types slow luau-lsp for every contributor.
- Replication cost: new attributes, values, or remote traffic multiply by player count.
- API evolution: a new tag in a shared union breaks every exhaustive branch in client code that is cached by players on an older server version.
- Engine changes: deprecated APIs (`wait`, `spawn`, legacy chat) and new defaults (streaming, character destroy behavior) change behavior without a code change — what does the project assume?
- Memory: closures captured in long-lived connections keep characters, tools, and UI alive.

## Reproducers

A throwaway spec under a scratch path run with the project's test runner, or a Lune script for engine-independent logic (`lune run <script>`). Engine-dependent claims: a minimal place built with Rojo and executed through the project's in-engine runner. Never commit the reproducer.
