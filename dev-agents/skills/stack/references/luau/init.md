# Luau — Project Init Facts

Applied by the `init-project` skill after `scaffold.sh` runs. Use it to review what the script generated.

## What the Scaffold Detects

- **Markers**: `default.project.json`, `wally.toml`, `pesde.toml`, `.luaurc`, `.luarc.json`, `selene.toml`, `stylua.toml`, or a `*.rockspec` at the root; otherwise one level down.
- **Mode**: Roblox when a `*.project.json` or `wally.toml` exists, or `pesde.toml` targets `roblox`; standalone Luau when `.luaurc`/`.config.luau` or a Lune/Luau `pesde.toml` exists; otherwise Lua mode.
- **Units**: one per detected root, named from `wally.toml`/`pesde.toml` `name`, the rockspec `package`, or the Rojo project `name`. Split Roblox units by hand into logical subsystems (server services, client controllers, shared modules) in `coverage-status.md`.
- **Not detected**: places under other project file names when no `default.project.json` exists, roblox-ts projects' Luau side (detected as `typescript` from `package.json` — add `luau` by hand when the repo also holds hand-written Luau), multi-place repositories with project files deeper than one level.

## Verify Skill Review

- **Install**: `rokit install`, then `wally install` / `pesde install` / `luarocks make`.
- **Build**: `rojo build <project> -o build.rbxl`; fix the project file name when the repo has several.
- **Type check**: the mode's command from `toolchain.md`, with the sourcemap and Roblox definitions steps first in Roblox mode.
- **Test**: the project's runner — Lune runner script, Jest Roblox through Open Cloud execution (needs test experience ids and a key in the environment), or `busted`.
- **Run**: Roblox has no headless run of the full game: `rojo serve` plus a Studio playtest for humans, Open Cloud probes for agents (see `live-tester.md`). Lune tools: `lune run <script>`; Lua CLIs: `lua <entry>`.

## Rule Templates

- `branching.md` pre-PR block: StyLua check, selene, type check, tests, Rojo build — the commands CI runs.
- `continuous-improvement.md` Test Configuration: the build command, the test experience universe and place ids (as environment variable names, never keys), the probe script folder `.local/testing/scripts/`.
- Interfaces and critical paths usually map to remotes, DataStore persistence, purchases (`ProcessReceipt`), teleports, and chat or admin commands.

## .gitignore

The scaffold adds `.local/` and `.claude/agent-memory-local/` only. Confirm the project also ignores `Packages/`, `ServerPackages/`, `DevPackages/`, `roblox_packages/`, `lua_modules/`, `sourcemap.json`, `globalTypes.d.luau` (when downloaded), and built place files (`*.rbxl`, `*.rbxlx`, `*.rbxm`, `*.rbxmx`). Lockfiles (`wally.lock`, `pesde.lock`) are committed for games.
