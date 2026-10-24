# Luau — Debugging Rules

Applies to Roblox, standalone Luau (Lune), and Lua mode (skip the type-error section in Lua mode unless the project runs `lua-language-server --check`). Roblox bugs live on two machines: always establish whether the failure is on the server, the client, or in the replication between them.

## Prevention Techniques — Luau Forms

- **State types**: one type per state with a singleton tag (`{ kind: "lobby" } | { kind: "match", startedAt: number }`); transition functions accept only the valid source state.
- **Tagged wrappers**: `{ kind: "UserId", value: number }` (frozen) created only by a validating constructor, where mixing ids is a real risk.
- **Validators at boundaries**: one validator per remote payload and per stored document; handlers receive typed values only.
- **Exhaustive branches**: every `if/elseif` over a tag ends with `error("unhandled kind: " .. tostring(v.kind))`.
- **Ownership of cleanup**: every connection, thread, and created instance is registered with a cleanup object owned by the player session, round, or component that created it.
- **Lint as prevention**: selene rules (`undefined_variable`, `shadowing`, `incorrect_standard_library_use`, `deprecated`) and `--!strict` turn typo, nil, and deprecated-API bugs into check failures.

## Type Errors (luau-lsp / luau-analyze)

Reproduce with the type-check command from `toolchain.md`, not only the editor — the editor may run a different luau-lsp version, solver, or definitions file. On Roblox, regenerate `sourcemap.json` first: a stale sourcemap is the most common cause of phantom errors.

| Message | Cause | Fix direction |
|---------|-------|---------------|
| `Type 'X' could not be converted into 'Y'` | Value shape mismatch; read the nested reason at the end | Fix the producer's type; never `:: any` the consumer |
| `Unknown require: ...` / module typed as `any` | Path not in the sourcemap, or alias missing from `.luaurc` | Regenerate the sourcemap; fix the alias or the Rojo project mapping |
| `Unknown global 'game'` (or other engine globals) | Roblox definitions not loaded | Pass the Roblox definitions/platform flag from `toolchain.md` |
| `Key 'x' not found in table 'T'` | Missing field, or a table literal typed too narrowly | Add the field to the type; annotate the literal at creation |
| `Value of type 'T?' could be nil` | Optional not refined | Handle `nil` explicitly with an `if` refinement |
| `Generic type 'T' expects N type arguments` / recursive type errors | Generic alias misuse | Simplify the alias; annotate to cut inference |
| Errors that differ between machines | Old vs new type solver, or different luau-lsp versions | Pin luau-lsp in `rokit.toml`; match the solver setting |

## Runtime Errors (Roblox)

| Message | Cause | Fix direction |
|---------|-------|---------------|
| `attempt to index nil with 'X'` | Missing child, unloaded character, streamed-out part, failed lookup | Find which lookup produced `nil`; handle absence or wait with a timeout |
| `Infinite yield possible on 'Parent:WaitForChild("X")'` | Instance never created, renamed, created on the other realm, or streamed out | Check the realm and name; add a timeout and handle `nil` |
| `attempt to yield across metamethod/C-call boundary` | Yielding inside a metamethod, `table.sort` comparator, or non-yieldable callback | Move the yield out; precompute before the call |
| `Requested module experienced an error while loading` | The required module threw at require time | Read the first error above it in the output — the real failure |
| `Requested module was required recursively` | Require cycle | Break the cycle; inject the dependency |
| `Module code did not return exactly one value` | Module returns nothing or several values | Return exactly one table or function |
| `Script timeout: exhausted allowed execution time` | Loop without yielding | Bound the loop or yield (`task.wait()`) between chunks |
| `Remote event invocation queue exhausted for X` | Client fires before the server connected a handler | Connect handlers before clients can fire; check the server started |
| DataStore errors (throttling, request rejected, value too large, cannot store type) | Request budget exhausted, payload over limit, non-serializable values (Instances, mixed tables, `NaN`) | Read the error code; respect `GetRequestBudgetForRequestType`; serialize to plain tables |

Lua mode: `attempt to call a nil value (global 'x')` usually means a missing `local` or a version-specific function (`unpack` vs `table.unpack`, `setfenv` on 5.2+); `module 'x' not found` lists every searched path — compare it with `package.path` and the rockspec.

## Runtime Debugging

- Read both outputs: the server output and the client output (Studio shows them separately in a Play Solo test; in a live server use the Developer Console, `F9`, Server/Client tabs).
- Stack traces: `xpcall(fn, debug.traceback)` around the suspect call; `debug.traceback()` in a log line shows who called a function.
- Capture errors globally: `ScriptContext.Error` (server) and `LogService.MessageOut` for diagnosis builds.
- Instrument the boundary: log remote name, player, and the argument types (`typeof`) at the start of each handler under investigation.
- Common crash sources: unvalidated remote arguments, `nil` from `FindFirstChild`, characters respawning while a handler holds the old one, streamed-out instances on the client, `pcall` results ignored.

## Interactive Debugging

- Roblox Studio debugger: breakpoints (including conditional breakpoints and logpoints), call stack, watch, and stepping work in Play and Run modes; set breakpoints on the realm that runs the code.
- Studio test modes: Play Solo for single-player flows, Start with multiple players (Test tab → Clients and Servers) for replication and multi-client races.
- Lune and Lua: print-based diagnosis with `debug.traceback`; for Lua, the project's debugger adapter (Local Lua Debugger, MobDebug) when configured.
- An agent without Studio cannot attach the Studio debugger: write a minimal reproducer that runs headless (Lune for pure logic, the project's in-engine runner for engine behavior) and report what still needs a manual Studio session.

## Async Debugging

- **Lost errors** — errors inside `task.spawn`, `task.defer`, or `coroutine.wrap` print to the output and never reach the caller; Promise rejections without `:catch` print an unhandled-rejection warning. Wrap the thread body in `xpcall` while diagnosing.
- **Hang** — a `WaitForChild` without timeout, an `InvokeServer` the server never answers, a Promise never resolved: add timeouts to locate it, then fix the producer.
- **Ordering** — `task.defer` runs after the current resumption cycle, `task.spawn` immediately; deferred events (`Workspace.SignalBehavior`) change handler timing — check the place setting when ordering differs between places.
- **Re-entrancy** — handlers that fire the event they listen to; `Maximum event re-entrancy depth exceeded` in the output.
- **Races across yields** — log state before and after each yield in the suspect sequence; the bug is usually a value read before the yield and trusted after.

## Structured Logging

Use the project's logger module (levels, prefixes, player id, place version) instead of bare `print`. Strip or gate debug logs in production; never log tokens, Secrets Store values, or full DataStore documents with personal data.

## Memory Debugging

- Developer Console Memory tab: per-category usage; `debug.setmemorycategory("Name")` at the start of a system labels its allocations.
- Luau heap snapshots (Developer Console, Luau Heap view) — compare two snapshots taken before and after repeating the suspect action.
- Usual leaks: connections never disconnected (they keep closures, characters, and UI alive), module-level tables keyed by players or instances never cleared on `PlayerRemoving`/`Destroying`, threads waiting forever, instances parented to `nil` but still referenced. Weak tables (`setmetatable(t, { __mode = "k" })`) for metadata keyed by instances.
- Lua mode: `collectgarbage("count")` before and after a repeated operation; a steady rise after full collections (`collectgarbage("collect")`) is a leak.

## CI-Only Failures

Usual environment differences: tool versions (`rokit.toml` not used in CI), a missing or stale `sourcemap.json`, missing Roblox definitions for the type checker, `Packages/` not installed before the type check, Open Cloud execution limits or API key scopes, case-sensitive paths on Linux runners, and Wally registry outages.

## Anti-patterns

- `:: any` or `--!nocheck` added "to debug later"
- `print` debugging left in shipped code
- Wrapping a failing call in `pcall` and ignoring the result to stop the error
- Raising `WaitForChild` timeouts or retry counts instead of finding the missing producer
- Debugging only on the client when the authority (and the bug) is on the server
