# Luau — Security & Maintenance Rules

On Roblox the threat model is fixed: every client is under the player's full control. Exploiters read every replicated script, fire any remote with any arguments at any rate, and move their own character freely. The server is the only authority. Lua mode replaces this with the classic server/CLI threat model (untrusted input, shell, filesystem, `load`).

## Dependency Security

### Advisory audit

There is no advisory database for Wally, pesde, or LuaRocks packages. Compensate:

- Review the source of every new dependency and every version bump diff (`wally.lock`/`pesde.lock` change → read the package changes).
- Prefer packages from known maintainers with public repositories; pin exact versions in the lockfile and commit it.
- Watch the upstream repositories of critical packages (persistence, networking, promise, signal) for security fixes.
- Lua mode: OSV has no LuaRocks coverage either; treat C modules (rocks with native code) like any native dependency.

### Marketplace assets and plugins

- Free models, inserted scripts, and Studio plugins are the main supply-chain vector on Roblox: search the place for `require(<number>)`, `getfenv`, `loadstring`, obfuscated strings (long `\` escape sequences, `string.char` chains), and scripts hidden in unusual services.
- Keep `ServerScriptService.LoadStringEnabled` off.
- Only install Studio plugins from trusted creators; plugins run with the developer's Studio permissions.

### Outdated dependencies

```bash
wally install && git diff --stat wally.lock     # after raising ranges in wally.toml (review every change)
pesde outdated                                   # pesde projects
luarocks list --outdated                         # Lua mode
```

## Escape-Hatch Code Management

Every one of these needs a justification comment and review: `loadstring`/`load` on any non-constant string, `getfenv`/`setfenv`, `debug.*` beyond profiling and tracebacks, `:: any` on data from a trust boundary, `--!nocheck`, `rawset`/`rawget` bypassing a protective metatable. Lua mode adds `os.execute`, `io.popen`, `package.loadlib`, and C modules.

## Remote and Input Validation

Validate in this order on every `OnServerEvent`/`OnServerInvoke`:

1. **Types** — `typeof(arg) == "<expected>"` for each argument; reject extra or missing arguments; reject Instances the player does not own or cannot see.
2. **Values** — finite numbers (`x == x and x ~= math.huge and x ~= -math.huge`), integer where required (`x % 1 == 0`), ranges, string length limits, enum membership against a server-side table.
3. **Authorization** — the player owns the object, can afford the purchase, is in range (server-side distance check), the cooldown has elapsed (server-side clock).
4. **Rate** — a per-player, per-remote limiter; drop and log excess requests.

```luau
local function isFiniteNumber(x: unknown): boolean
	return typeof(x) == "number" and x == x and x ~= math.huge and x ~= -math.huge
end
```

Never use the client's report of hits, damage, currency, or position as truth; recompute or sanity-check on the server.

## Persistence Integrity

- Session locking for player data (ProfileStore or an equivalent lock on the key) so two servers never write the same profile — the root cause of item duplication.
- `UpdateAsync` for every read-modify-write; never `GetAsync` + `SetAsync` for shared keys.
- Validate loaded documents against the current schema; migrate old versions explicitly.
- Trades and gifts: one transaction updates both sides, or a two-phase protocol that survives a server crash in between.

## Monetization

- `MarketplaceService.ProcessReceipt` is idempotent: record the `PurchaseId` in the player's data before (or atomically with) granting, return `Enum.ProductPurchaseDecision.PurchaseGranted` only after the save succeeds, `NotProcessedYet` otherwise.
- Check game-pass ownership on the server (`UserOwnsGamePassAsync`), cache it per session, never trust a client flag.

## Secrets Management

- API keys for external services live in the Secrets Store and are read on the server with `HttpService:GetSecret`; never in source, attributes, or replicated instances.
- Open Cloud API keys used by CI live in the CI secret store with the narrowest scope (one experience, one operation) and an IP allowlist where possible.
- Never send secrets or other players' private data to clients; never log them.

## Text and Policy Compliance

- Text from one player shown to another goes through `TextService:FilterStringAsync` and the right `GetChatForUserAsync`/`GetNonChatStringForBroadcastAsync` call; unfiltered display violates Roblox policy.
- Gate features with `PolicyService:GetPolicyInfoForPlayerAsync` where the policy requires it (paid random items, external links, social features).

## Lua Mode: Injection and Filesystem

- **Command injection** — `os.execute` and `io.popen` run a shell: never concatenate input; quote with a vetted helper or avoid the shell.
- **Code injection** — `load`/`loadstring`/`dofile` on input is code execution; a sandbox needs a restricted environment table (`load(chunk, name, "t", env)` on 5.2+, `setfenv` on 5.1) AND text-mode only (`"t"`) to block bytecode.
- **Path traversal** — normalize and check paths before `io.open`; reject `..` segments and absolute paths from input.
- **SQL** — parameterized queries in LuaSQL/pgmoon/OpenResty drivers, never string concatenation.

## Error Handling Security

- Server errors never reach the client with stack traces or internal state; remote handlers return a generic failure.
- A malformed request rejects quietly (and is logged with the player id); it never crashes the handler with an uncaught error that floods the output.
- `pcall` around persistence and purchases records the failure and keeps the player's state consistent.

## Checklist Additions

- [ ] Every server entry point (remotes, `ProcessReceipt`, `MessagingService` subscriptions, HTTP callbacks) validates types, values, authorization, and rate
- [ ] No authority on the client; server recomputes outcomes
- [ ] No secrets, server logic, or admin checks in replicated code
- [ ] Player data session-locked, written with `UpdateAsync`, saved on leave and shutdown
- [ ] `ProcessReceipt` idempotent
- [ ] User text filtered; policy-gated features checked
- [ ] No `loadstring`, `require(assetId)` of untrusted assets, or `getfenv`/`setfenv`
- [ ] Dependency and asset diffs reviewed

## Tools

```bash
rg -n "OnServerEvent|OnServerInvoke|ProcessReceipt|SubscribeAsync" src   # server entry points
rg -n "loadstring|getfenv|setfenv|require\(\s*[0-9]+" .                  # escape hatches and remote requires
rg -n "GetAsync|SetAsync|UpdateAsync|IncrementAsync" src                 # persistence writes
selene .                                                                 # lint, including deprecated APIs
gitleaks detect --source .                                               # secrets in the repository
```
