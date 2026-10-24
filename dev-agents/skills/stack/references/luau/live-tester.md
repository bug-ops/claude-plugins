# Luau — Live Tester Rules

Live testing runs what users get. For a Roblox experience that is a server and clients inside the engine — an agent cannot click through Studio, so live tests run headless where possible and the rest becomes an explicit manual checklist. Lua mode applies the CLI/server rules unchanged.

## Off-Limits Files

Read-only for the whole session: `*.luau`, `*.lua`, `*.project.json`, `wally.toml`, `pesde.toml`, rockspecs, every lockfile, `rokit.toml`, `.luaurc`/`.config.luau`, `selene.toml`, `stylua.toml`, CI workflows. Scratch scripts and test places go under `.local/testing/`.

## Project Discovery

1. Mode and entry points: Rojo project files (which folders map to `ServerScriptService`, `StarterPlayerScripts`, `ReplicatedStorage`); Lune scripts (`.lune/`, `scripts/`); Lua executables and rockspec `build.install.bin`.
2. Test infrastructure: a test project file (`test.project.json`), a test runner script, Jest Roblox config, Open Cloud CI job and its test place (ids in CI variables).
3. Interfaces: remotes (one definitions module or IDL file), chat commands, UI flows, HTTP endpoints called by the game, CLI commands of Lune/Lua tools.
4. Persistence: DataStore names and key formats, so test runs use a test experience or a separate scope.
5. Env and test configs: `.local/config/`, test universe and place ids, local secrets configured in the test experience.

## Running the Project

```bash
rojo build default.project.json -o .local/testing/build.rbxl      # the artifact: does the tree map cleanly?
rojo build test.project.json -o .local/testing/test.rbxl          # place with test code mapped in
rbxcloud luau execute -u <test-universe> -i <test-place> -f .local/testing/scripts/<probe>.luau   # server-side probe in a real server
lune run <script> [args]                                          # Lune tools and engine-independent flows
lua <entry>.lua [args]                                            # Lua mode CLIs
```

- **Server-side flows**: an Open Cloud Luau Execution probe script requires the game's modules in a real server, calls server handlers directly with crafted players/arguments, and prints results. Needs the project's test experience and a key provided by the user through the environment — never use production places or keys.
- **Place files without the engine**: Lune `@lune/roblox` reads a built place to check structure (scripts present, remotes created, no unexpected scripts from free models).
- **Client and multi-client flows**: not automatable here. Write them as numbered manual steps (Studio → Test → Clients and Servers, N players) in the session report, with expected results, and mark the coverage row `Blocked (manual)` until a human confirms.

## Debug Output

- Probe scripts print structured lines (`[probe] remote=BuyItem result=rejected reason=type`) and return a summary value; fetch task logs after completion.
- Read the server output for errors and warnings during the probe; Lune and Lua tools write to stdout/stderr — capture both to `.local/testing/debug/`.

## Crash and Warning Signatures

- `attempt to index nil with`, `Infinite yield possible on`, `Requested module experienced an error while loading`, `Requested module was required recursively`
- `Script timeout: exhausted allowed execution time`
- `Remote event invocation queue exhausted`, `Maximum event re-entrancy depth exceeded`
- DataStore throttling and request-rejected errors, `ProcessReceipt` errors
- Deprecation warnings for engine APIs
- Lune: uncaught errors with Luau stack traces, non-zero exit codes; Lua: `lua: <file>:<line>:` error prefixes

## Remote Abuse Probes

For each server entry point, run the hostile-client matrix through a probe: wrong types, `nil`, `NaN`, `math.huge`, negative and fractional numbers, 100 KB strings, deeply nested tables, Instances the player does not own, and a burst of 1000 calls. Expected: rejected without errors in the output and without state change. Any accepted bad input is a bug (P0/P1 when it grants value).

## Resource Usage

Server memory and heartbeat time during a probe (`Stats` service values printed by the probe); per-player tables after simulated join/leave cycles must return to their baseline size. Lune/Lua: `/usr/bin/time -l` (macOS) or `-v` (Linux).

## Cross-Interface Pairs

- Remote handler vs chat/admin command reaching the same action
- Studio Play Solo vs a multi-client server (replication, ownership)
- Built place vs the Rojo live-sync state a developer tests in Studio
- Lune tool output vs the in-engine behavior of the same shared module

## Dependency Moves (Unchanged HEAD)

`git log --since=<last-session-date> --oneline -- wally.lock pesde.lock rokit.toml` lists dependency and tool moves; engine releases change behavior without any repository change — note the engine version (`version()` printed by the probe) in the journal.

## Benchmarks

Detect: Lune benchmark scripts, a benchmark place, or a bench folder. Record printed numbers with the engine or Lune version in the journal and compare by hand.

## Environment Hygiene

Rebuild place files and regenerate `sourcemap.json` before a comprehensive session; reinstall packages from the lockfile (`wally install`, `pesde install`) without changing manifests. Probe runs write only to test-experience DataStores, and clean up the keys they create.
