# Luau — Researcher Rules

Covers Roblox, standalone Luau (Lune), and Lua mode.

## Off-Limits Files

Never edit `wally.toml`, `pesde.toml`, rockspecs, any lockfile (`wally.lock`, `pesde.lock`), `rokit.toml`, `*.project.json`, `.luaurc`, `selene.toml`, `stylua.toml`, source files, or CI workflows — not even to bump a dependency version.

## Dependency Monitoring Commands

```bash
cat wally.lock                                  # locked Wally versions (name, version, checksum-free: review sources)
pesde outdated                                  # pesde projects
luarocks list --outdated                        # Lua mode, installed rocks
luarocks search <rock>                          # published versions on luarocks.org
gh release list -R <owner>/<repo> -L 5          # tool and package releases (Rojo, luau-lsp, selene, StyLua, Lune, packages)
```

Wally has no `outdated` command: compare each locked version with the registry index (`https://github.com/UpliftGames/wally-index`, one file per package) or the package page on wally.run. There is no advisory database for Wally, pesde, or LuaRocks — security signals come from the package repositories themselves.

## Sources

| Need | Source |
|------|--------|
| Wally versions | wally.run, the `UpliftGames/wally-index` repository |
| pesde versions | pesde.dev registry |
| LuaRocks versions | luarocks.org module pages |
| Engine changes | Roblox Creator Hub release notes, DevForum announcements (deprecations, new APIs, behavior changes with rollout dates) |
| Luau language | luau.org, the `luau-lang/luau` releases and RFCs (`luau-lang/rfcs`) |
| Toolchain | GitHub releases of Rojo, Rokit, luau-lsp, selene, StyLua, Lune, Wally, pesde |
| Advisories | Package repositories' security issues and release notes; Roblox security announcements |
| Lua language | lua.org release notes, LuaJIT repository |

## Package Health Signals

- Last release and commit activity, maintainer count, issue response time, archived repository
- Successor packages announced by the author (persistence, networking, and framework libraries are often superseded)
- Types: ships typed Luau (`--!strict`) vs untyped modules; `wally-package-types` needed for re-exported types
- Realm (`shared` vs `server`) and whether it yields at require time
- Use of deprecated engine APIs (`wait`, `spawn`, legacy chat) — a maintenance signal
- For Lua rocks: supported Lua versions in the rockspec, native C code, maintenance on the target version

## Update Priority Triggers

| Trigger | Priority |
|---------|----------|
| Security fix in a locked package on a server path (persistence, networking, purchase handling) | Immediate (P0/P1) |
| Malicious or compromised package or tool release | Immediate (P0) |
| Roblox deprecation with an enforcement date that affects the project | Next PR before the date (P1/P2) |
| Package archived or superseded by its author | Backlog research issue (P2/P3), with the successor |
| Toolchain major release (Rojo, luau-lsp, selene) with breaking changes | Backlog (P3) |
| Duplicate versions of a package in the lockfile | Backlog (P3/P4) |

Semver notes: Wally and pesde resolve caret-style ranges by default (`"1.2.3"` means `^1.2.3`); for `0.x` packages a minor bump is breaking. Compare locked versions, not declared ranges.

## Dependency Functionality Coverage — Luau Examples

- A persistence library: session locking, `BindToClose` saving, data migrations — which of these does the project actually rely on, and are they tested?
- A networking library or IDL: payload validation, rate limiting, unreliable channels.
- A promise or signal library: cancellation, error propagation, deferred vs immediate firing.

## Luau Research Topics

- New Luau type solver and type functions — what the project can simplify or must fix
- Native code generation coverage for the project's hot paths
- Engine features replacing hand-written systems (input actions, new character controllers, `UnreliableRemoteEvent`, built-in text chat, Open Cloud APIs for CI and live ops)
- Testing in the engine from CI (Open Cloud Luau execution)

## Reference Projects

Popular open-source Roblox games and libraries with Rojo setups, maintained Wally/pesde packages in the same domain, and Roblox's own open-source Luau packages. Record them in the project's competitive-parity playbook.

## Vulnerability Classes Common in Luau/Roblox

- Unvalidated remote arguments and client authority (economy exploits, damage, teleport)
- Item duplication through persistence races (no session lock, `GetAsync`+`SetAsync`)
- Backdoors from free models, plugins, and `require(assetId)`
- Secrets in replicated code (webhooks, API keys)
- Remote flooding without rate limits (server denial of service)
- Unfiltered user text (policy violation)
- Lua mode: command injection through `os.execute`/`io.popen`, code injection through `load`
