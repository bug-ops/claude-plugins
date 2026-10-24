# Luau — Performance Rules

On Roblox the budget is the frame: at 60 FPS everything a client runs per frame shares about 16.6 ms, and the server's heartbeat runs every simulation step for every player. Measure on the realm that is slow (server or client) and on the weakest target device the experience supports.

## Profiling Tools

| Tool | Where | Use for |
|------|-------|---------|
| MicroProfiler (`Ctrl+F6` in client or Studio; server dumps through the Developer Console) | Roblox | Frame breakdown: scripts vs physics vs rendering vs replication; spikes |
| Script Profiler (Developer Console / Studio; `ScriptProfilerService` for scripted capture) | Roblox | Per-function Luau CPU time, client and server |
| Developer Console (`F9`) Memory, Network, Scripts tabs | Roblox | Memory by category, replication traffic, script activity per second |
| Luau Heap view (Developer Console) | Roblox | Heap snapshots and growth by object type |
| `os.clock()` timing in a Lune script | Lune | Pure-logic hot paths outside the engine |
| `luajit -jp` / LuaJIT profiler, `collectgarbage("count")` | Lua mode | CPU and memory of standalone Lua |

## Measuring in Code

```luau
debug.profilebegin("Inventory.recompute")   -- labels the block in the MicroProfiler
recomputeInventory(player)
debug.profileend()

debug.setmemorycategory("Inventory")        -- attributes this thread's allocations in the Memory tab
```

Wrap every system that runs per frame or per player in a profile label so regressions are attributable. Remove ad-hoc `os.clock()` prints after measuring.

## Benchmarking

- Engine-independent code: a Lune script that warms up, runs N iterations, and reports the median of several runs with `os.clock()`.
- Engine code: the project's benchmark plugin or a Studio command-bar loop; record device, build, and place version with every number.
- Compare before/after on the same machine and place; a single run is noise.
- Keep benchmark scripts under `.local/` or the project's bench folder, never in shipped code.

## Luau Execution

- **Native code generation** — `--!native` at the top of a script or `@native` on a function compiles it to machine code on the server (and on supported clients); use it for numeric hot paths (math, buffers, tight loops). Type annotations improve native code; `getfenv`/`setfenv` and heavy metatable use defeat it. Measure — native code helps CPU-bound loops, not engine-call-heavy code.
- **Optimization level** — live games run at the highest optimization level; Studio may not, so profile hot paths in a published test place.
- **Hot-path idioms** — cache engine lookups (`local Vector3new = Vector3.new` only where measured), prefer numeric `for` loops and generalized iteration over closures, avoid creating tables and closures per frame, preallocate arrays with `table.create(n)`, reuse buffers.
- **`buffer`** — binary data and network payloads as `buffer` instead of strings or tables reduces allocation and replication size.
- **Fast paths** — builtins (`math.*`, `table.insert`, `string.byte`) called on their global names are optimized; overriding or wrapping them disables that.

## Roblox Engine Costs

- **Replication** — every property change on a replicated instance is sent to every client that can see it. Batch updates, avoid per-frame property writes on many parts, keep server-only state off replicated instances, use `UnreliableRemoteEvent` for high-rate cosmetic state.
- **Remotes** — fewer, larger, batched messages beat many small ones; send compact payloads (numbers and buffers over long strings and nested tables).
- **Physics** — anchored parts are cheap, unanchored ones are simulated; set network ownership deliberately; avoid server raycasts per client request without limits.
- **Instance churn** — creating and destroying many instances per second; pool them (reparent instead of recreate) where profiling shows churn.
- **Lookups** — `GetDescendants`/`FindFirstChild` scans in loops → `CollectionService` tags and cached references.
- **Streaming** — with `StreamingEnabled`, client code must not assume instances exist; design for streamed-out content instead of forcing persistent models.

## Parallel Luau

- Split CPU-heavy, independent work into `Actor`s; inside, call `task.desynchronize()` before the parallel part and `task.synchronize()` before touching the DataModel.
- Communicate through `Actor:SendMessage` or `SharedTable`; keep messages small.
- Parallelism helps only when the work dominates the frame; measure the serial cost first.

## Memory Optimization

- Release per-player data on `PlayerRemoving`; release per-instance data on `Destroying`.
- Disconnect connections; closures in connections are the most common retention path.
- Weak tables (`__mode = "k"`) for caches keyed by instances.
- Large static data (item catalogs) loaded once into frozen tables, shared through one module.

## Anti-Patterns

- Per-frame `while true do task.wait() end` loops where an event or a `Heartbeat` handler with a time accumulator would do
- `wait()` (throttled) for timing-sensitive logic
- Table and closure allocation inside `Heartbeat`/`RenderStepped`
- Per-frame remote fires per entity
- `GetDescendants` over `Workspace` in a loop
- Many independent scripts each running their own per-frame loop
- `--!native` everywhere without measurement (increases memory and compile time)
- String concatenation in loops (`..` per iteration) instead of `table.concat` or `buffer`

## Tools Quick Reference

```bash
lune run bench/<script>        # pure-logic benchmark outside the engine
rojo build -o bench.rbxl       # build a place to profile in Studio with the MicroProfiler
```

In-engine profiling (MicroProfiler, Script Profiler, Luau Heap) needs Studio or a live client. An agent without them prepares the reproducer place and the measurement steps, and reports which numbers still need a manual session.
