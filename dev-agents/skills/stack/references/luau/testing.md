# Luau — Testing Rules

Test at the lowest layer that can prove the behavior. Engine-independent logic (rules, math, parsing, state machines) runs headless and fast; engine behavior (instances, replication, DataStores, physics) needs a real place. Design modules so most logic lands in the first group.

## Tools

| Need | Tool |
|------|------|
| In-engine unit and integration tests (Roblox) | Jest Roblox — Wally `roblox/jest` and `roblox/jest-globals` in `[dev-dependencies]`, versions pinned exactly (`=3.x.y`); maintained by Roblox at `Roblox/jest-roblox` |
| Legacy in-engine tests | TestEZ (archived): keep running existing suites, write new ones in the project's current framework, migrate only as a planned task |
| Headless runs of in-engine tests in CI | Open Cloud Luau Execution against an uploaded place version (`rbxcloud luau execute`, or the project's script calling the API) |
| Engine-independent tests | Lune scripts with the project's runner; pure modules required directly |
| Lua mode | busted (`describe`/`it`, `spy`, `stub`, `mock`), coverage with luacov |
| Linting test code | selene with the test framework's globals declared (a std extension file) |

Jest Roblox imports its globals explicitly:

```luau
local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
```

Follow the Jest Roblox README for the runner script (`runCLI` with the project roots, a `jest.config.luau` per root) and for the Studio setup it needs locally.

## Test Layout

- Co-locate specs as `*.spec.luau` next to the module, or mirror `src/` under `tests/` — follow the project.
- Test-only code and packages (`DevPackages/`) are mapped into the DataModel only by a test project file (`test.project.json`), never by the production `default.project.json`.
- One spec file per module; `describe` per public function or behavior; `it` names state the expected behavior ("rejects a negative amount").
- Keep specs independent: no reliance on execution order, no state leaking through module-level tables (reset in `beforeEach`).

```luau
--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Wallet = require(script.Parent.Wallet)

describe("Wallet.spend", function()
	it("rejects amounts above the balance", function()
		local wallet = Wallet.new(10)
		local result = wallet:spend(11)
		expect(result.ok).toBe(false)
		expect(wallet.balance).toBe(10)
	end)
end)
```

## Integration Tests

- **Remotes**: call the server handler function directly with a fake player and crafted arguments; cover wrong types, `NaN`, `math.huge`, negative and fractional numbers, oversized strings, missing arguments, and Instances the player does not own.
- **Persistence**: test the data layer against a fake DataStore with the same API surface (in-memory `GetAsync`/`UpdateAsync`/`SetAsync`, plus injected failures and throttling), never against live production DataStores. Cover session-lock conflicts, failed saves, and schema migrations.
- **Purchases**: `ProcessReceipt` called twice with the same receipt grants once.
- **Player lifecycle**: join, leave during load, rejoin, and shutdown paths.

## Async Tests

- Yielding code under test: await completion explicitly (resolve the Promise with `:expect()`/`:await()`, or wait on a signal with a timeout) — never `task.wait(1)` and hope.
- Inject a clock or a scheduler for time-based logic; real waits make suites slow and flaky.
- Assert that spawned threads and connections are cleaned up (a disconnected flag, a cleanup object that is empty after `Destroy`).

## Test Doubles — Fakes over Mocks

- Pass engine services into modules (`Wallet.new(dataStore)`), then hand tests a small fake with the same methods. A fake DataStore, a fake `MarketplaceService`, a fake clock are reusable across specs.
- Jest Roblox `jest.fn()` spies for callbacks and call counts; avoid replacing whole modules unless the project already does.
- Never fake the unit under test; never assert on private fields when a public behavior shows the same thing.

## Property-Based Tests

No mainstream property-testing library exists for Luau; for parsers and validators, generate inputs in a loop with a seeded `Random.new(seed)` and assert invariants (round-trips, "never errors, only rejects"). Record the seed in the failure message so a failing case reproduces.

## Type-Level Tests

The type check is the type test: a fixture file under the test folder that uses the public API in the intended ways must pass `--!strict` analysis. For "this must not compile" cases there is no expect-error directive — document them in the PR instead.

## End-to-End Tests

Full gameplay flows (multiple clients, replication, UI) need Studio's multi-client test mode or a live test place; automate what Open Cloud Luau Execution can reach (server-side flows in one server) and list the rest as manual checks in the PR.

## Benchmarks

Benchmark scripts live outside specs: Lune scripts for pure logic, a benchmark place or plugin for engine code (see `performance.md`). Never assert timings in unit tests.

## DRY in Tests

- Shared fakes and builders in one test helpers module (`tests/helpers/`), mapped only by the test project file
- Payload generators for remote validation tests reused across every handler spec
- Repeated setup in `beforeEach`, not copied into every `it`

## Redundancy Audit Commands

| Step | Command |
|------|---------|
| Enumerate the suite | `rg -n '^\s*(it|test)\(' -g '*.spec.luau' -g '*_spec.lua'` (Jest Roblox and busted have no stable list command) |
| Unit-test sweep scope | the touched module's `*.spec.luau` plus matching files under `tests/` |
| Coverage diff | Lua mode: `busted --coverage` twice, the second time with the suspected test locally skipped (never committed); compare `luacov.report.out`. Luau: no coverage tool — reason from the behavior each test asserts |
| Per-test timing | Jest Roblox reports per-file durations in its output; busted `--output=json` |
| Slow-test quarantine | a separate test project file or tag for nightly runs, not `skip` |

## Anti-patterns

- Tests that only run in Studio by hand when the logic could run headless
- `task.wait(n)` to "let things settle" instead of awaiting the event
- Tests against live production DataStores or real purchases
- Specs that depend on the order of other specs or on leftover module state
- Focused (`fit`, `it.only`) or skipped tests committed
- Mocking every engine call instead of injecting a small fake
- Test packages mapped into the production place
