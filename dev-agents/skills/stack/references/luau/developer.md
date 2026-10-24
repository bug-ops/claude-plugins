# Luau — Developer Rules

## Code Quality Requirements

**Every public function**: clear single responsibility, typed parameters and return type, a doc comment, at least one test.

**Types first**:
- `--!strict` at the top of every new Luau file; never downgrade an existing file's mode.
- Model alternatives as tagged unions on a singleton string field; branch on the tag and end with an `error` naming the unhandled value.
- Freeze constant and shared tables (`table.freeze`); mark properties callers must not write as `read` in the type when the project runs the new solver.
- `unknown` at trust boundaries (remote arguments, JSON, DataStore values, attributes, user text); narrow with `typeof` checks or the project's validator before use. Never `:: any` to silence the checker; a `::` cast to a concrete type needs a one-line reason.
- Instances: check the class before use (`inst:IsA("BasePart")`), and type `FindFirstChild` results as optional — they can be `nil`.
- Lua mode: LuaLS annotations (`---@param`, `---@return`, `---@class`) on every public function.

**Error handling**:
- Raise errors with `error(message, level)` (level `2` blames the caller) or return a tagged `Result` when failure is expected; never `error` with a bare table that loses the position unless the project defines a structured error type.
- Protect every yielding engine call that can fail (DataStores, `HttpService`, `MarketplaceService`, `TeleportService`, `MessagingService`) with `pcall`, and retry with backoff where the API documents throttling.
- Use `xpcall(fn, debug.traceback)` when the stack matters for diagnosis.
- Never let an error inside a remote handler or `task.spawn` thread vanish: log it with context (player, remote name).

**Async rules (Roblox and Lune)**:
- `task.wait`, `task.spawn`, `task.defer`, `task.delay` — never the deprecated `wait`, `spawn`, `delay`.
- No yielding inside metamethods, `table.sort` comparators, or callbacks the engine expects to return immediately (`BindToClose` has a hard deadline; `RemoteFunction.OnServerInvoke` blocks the caller).
- Every `:Connect` has an owner that disconnects it; prefer `:Once` for one-shot handlers; destroy instances you create.
- Every `WaitForChild` that can legitimately miss has a timeout and a handled `nil`.
- Bound concurrent work over player-sized collections; do not spawn one thread per item without a limit.

## DRY Extraction Targets

- Same logic in 2+ places → shared module under `shared/` (or the realm folder that owns it)
- Same remote validation in 2+ handlers → one validator module per payload type
- Same cleanup boilerplate → the project's cleanup object (Trove, Janitor, Maid)
- Same test setup repeated → a helper module next to the specs

## Incremental Verification

Run the type check (`toolchain.md` **Type check**; regenerate `sourcemap.json` first on Roblox) after each function, type, or module; run `selene` on the touched files; run the affected spec file with the project's test runner.

## Never Weaken Checks — Luau Forms

- Do not skip (`itSKIP`, `xit`, `it.skip`), delete, or loosen a failing test; never commit focused tests (`itFOCUS`, `fit`, `it.only`)
- Do not downgrade `--!strict` to `--!nonstrict`/`--!nocheck`, or add `:: any` to silence an error
- Do not add `-- selene: allow(...)` without a reason comment, or loosen `selene.toml`
- Do not wrap a call in `pcall` and ignore the result to make an error disappear
- Do not raise DataStore retry counts or timeouts to hide a logic bug

## Dependencies Added

In the handoff list name, version, manifest section (`[dependencies]`, `[server-dependencies]`, `[dev-dependencies]` in `wally.toml`; the pesde or rockspec equivalent), realm, and reason. Run the install so the lockfile and generated package folders update; the lockfile change goes in the same commit, the generated folders never.

## Anti-patterns

- `wait()`, `spawn()`, `delay()`, `Instance.new(class, parent)` with the parent argument (set `Parent` last)
- Global variables; `_G` or `shared` used to pass state between scripts
- Mutating a module's returned table from outside, or caching `Players.LocalPlayer` in server code
- Connections without disconnects; threads without cancellation; instances created and never destroyed
- String-built remote names or `FindFirstChild` paths scattered across modules instead of one definitions module
- `pcall` without reading its first return value
- Polling loops (`while true do ... task.wait() end`) where an event exists (`Changed`, `GetPropertyChangedSignal`, `ChildAdded`)
- `print` left in production code instead of the project's logger
- Lua mode: implicit globals from a missing `local`, `table.getn`, `unpack` vs `table.unpack` mismatched to the target version
