# Luau Toolchain Profile

Covers Luau on Roblox (Rojo projects), standalone Luau (Lune scripts and tools), and plain Lua 5.1–5.5 / LuaJIT. Three modes, decided by the markers in `stack/SKILL.md`:

- **Roblox mode** — Rojo project files map the filesystem into the DataModel; the type checker needs the Roblox definitions and a sourcemap.
- **Standalone Luau mode** — Lune or the `luau` CLI runs the code; no DataModel, no engine APIs except through `@lune/roblox`.
- **Lua mode** — PUC Lua or LuaJIT with LuaRocks: skip Luau type-check steps; LuaLS annotations plus `lua-language-server --check` are the type-safety tool there.

roblox-ts projects (`package.json` with `roblox-ts`, sources in `.ts`) are `typescript,luau`: edit the TypeScript sources, never the compiled Luau in `out/`.

## Project Facts

- **Toolchain manager**: `rokit.toml` (`[tools]` entries `name = "owner/repo@version"`) pins every CLI — Rojo, Wally or pesde, StyLua, selene, luau-lsp, Lune. `rokit install` installs them; `rokit add <owner/repo>` adds one. Rokit also reads legacy `aftman.toml` and `foreman.toml`. Use the pinned tools, never global installs of other versions.
- **Project mapping**: `default.project.json` (and other `*.project.json`) maps folders to DataModel paths. `init.luau` makes a folder a module; `*.server.luau` / `*.client.luau` are Scripts / LocalScripts.
- **Packages**: `wally.toml` + `wally.lock` (Wally; installs into `Packages/`, `ServerPackages/`, `DevPackages/`), or `pesde.toml` + `pesde.lock` (pesde; targets `roblox`, `lune`, or `luau`). Lua mode: a rockspec and LuaRocks. Generated package folders are never edited or committed.
- **Language config**: `.luaurc` (JSON: `languageMode`, `aliases`, lint settings) or `.config.luau` (Luau table) — never both in one directory. Require-by-string: `./`/`../` relative paths and `@alias` paths; on Roblox `@self/Child` and `@game/...` are available.
- **Type solver**: on Roblox, `--!nocheck`/`--!nonstrict` scripts use the new solver by default; `--!strict` code stays on the old solver unless the place enables `UseNewLuauTypeSolver`. New-solver-only features (`read`/`write` property modifiers, type functions) need that setting and a matching luau-lsp configuration — check before using them.
- **Version policy**: Roblox code targets the live engine — deprecated APIs are defects, and new engine features are available immediately. Lune code targets the Lune version in `rokit.toml`. Lua libraries target the Lua versions in the rockspec `dependencies` and `.luarc.json` `runtime.version`; Luau syntax (`continue`, `+=`, type annotations, string interpolation) never appears in Lua-mode code and Lua 5.2+ syntax (`goto`, `<const>`, `<close>`, integer division semantics) never appears in Luau.
- **Dependencies**: add with the project's manager (`wally.toml` entry then `wally install`, `pesde add`, `luarocks install` + rockspec entry). Check the latest version (wally.run, pesde.dev, luarocks.org) and the package repository before adding one; dev-only packages (test frameworks) go to `[dev-dependencies]`.
- **Dependency APIs**: never call one from memory. Read the installed version's source under `Packages/` (or `roblox_packages/`, `lua_modules/`) and its README for that version. Engine APIs: check the Creator Hub reference; when the type checker with current definitions disagrees with your memory, the checker is right.

## Commands

Prefer the project's scripts (`justfile`, `Makefile`, `scripts/*.luau` run with Lune, pesde scripts); they encode the CI setup. Defaults when none exist:

| Purpose | Command |
|---------|---------|
| Install tools | `rokit install` |
| Install packages | `wally install` (then `wally-package-types --sourcemap sourcemap.json Packages/` when the project uses it); `pesde install`; `luarocks make` (Lua mode) |
| Sourcemap (Roblox) | `rojo sourcemap default.project.json -o sourcemap.json` |
| Roblox definitions | `curl -fsSL -o globalTypes.d.luau https://luau-lsp.pages.dev/type-definitions/globalTypes.None.d.luau` — `luau-lsp analyze` never downloads them; store the file where the project ignores it (or where CI caches it) |
| Type check (Roblox) | `luau-lsp analyze --platform=roblox --definitions:@roblox=globalTypes.d.luau --sourcemap=sourcemap.json src` |
| Type check (standalone Luau) | `luau-lsp analyze --platform=standard src` (or `luau-analyze --mode=strict src` from the Luau release) |
| Type check (Lua mode) | `lua-language-server --check=. --checklevel=Warning --check_format=pretty` (when the project uses LuaLS annotations) |
| Lint | `selene .` (`std = "roblox"` in `selene.toml` for Roblox; the generated std needs network on first run, `roblox-std-source = "pinned"` freezes it) |
| Format check / fix | `stylua --check .` / `stylua .` |
| Build (Roblox) | `rojo build default.project.json -o build.rbxl` |
| Unit tests (engine-independent) | `lune run <test-runner-script>` — whichever runner the project configures |
| Unit tests (in engine) | Jest Roblox (`roblox/jest`) executed in a built place: Open Cloud Luau Execution (`rbxcloud luau execute ...`) in CI, or Studio locally — see `testing.md` |
| Unit tests (Lua mode) | `busted` (coverage: `busted --coverage` + `luacov`) |
| Rockspec check (Lua mode) | `luarocks lint <rockspec>` |
| Outdated dependencies | `pesde outdated`; Wally has no command — compare `wally.lock` with the registry; `luarocks list --outdated` |

**Full check suite** (run before handing off code; must match CI): format check, lint, type check (with a fresh sourcemap on Roblox), engine-independent tests, and the Rojo build. In-engine tests run when the project has the CI setup for them (an Open Cloud key in CI secrets); otherwise state in the handoff that they were not run. When the CI workflow runs other scripts, use those exactly.

## Documentation Conventions

- Every public function and exported type of a module gets a doc comment explaining *what* and *why*: `--[=[ ... ]=]` Moonwave blocks (`@within`, `@param`, `@return`, `@yields`, `@error`) when the project uses Moonwave, otherwise `---` comments; LuaLS annotations (`---@param`, `---@return`, `---@class`) in Lua mode.
- Mark yielding functions (`@yields`) — a caller in a non-yieldable context must know.
- Module overview: a doc block at the top of each package entry point (`init.luau`).
- Type docs state the contract: what each tag of a union means, which fields callers may rely on.
- Doc gate: `moonwave build` (or the configured doc generator) when the repo builds docs; otherwise the type check must pass with the comments intact.

## Markers and Comment Syntax

- Line comments: `-- TODO(#123): ...`, `-- TODO(review): ...`, `-- ASSUMPTION: ...`.
- Type escape hatches carry a reason: `x :: any -- <reason>`; a file-level `--!nonstrict` or `--!nocheck` needs a comment on the next line explaining why.
- Lint suppressions name the rule and the reason: `-- selene: allow(<rule>) -- <reason>` on the narrowest scope; never file-wide.
- Formatter exclusions: `-- stylua: ignore` on the single statement, with a reason.

## Knowledge Skills

None. Verify newer Luau features against the Luau release notes and the Roblox engine release notes; verify engine APIs against the Creator Hub reference.
