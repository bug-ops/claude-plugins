# TypeScript — Performance Rules

Applies to Node.js services and CLIs, libraries, and browser frontends. Profile the emitted JavaScript, not the TypeScript source: build first, then run `node dist/...` (or the framework's production server). Never profile through `tsx`/`ts-node` — transpilation shows up in the profile.

## Profiling Tools

```bash
node --cpu-prof dist/app.js                 # writes CPU.*.cpuprofile; open in Chrome DevTools or speedscope
node --cpu-prof --cpu-prof-dir=prof dist/app.js
node --inspect dist/app.js                  # attach Chrome DevTools via chrome://inspect
node --prof dist/app.js && node --prof-process isolate-*.log   # V8 tick profiler, text report
0x dist/app.js                              # interactive flamegraph HTML
clinic doctor -- node dist/app.js           # triage: CPU, event loop, GC, I/O
clinic flame -- node dist/app.js            # flamegraph
clinic bubbleprof -- node dist/app.js       # async I/O wait analysis
node --perf-basic-prof dist/app.js & perf record -g -p $!   # Linux perf with JS symbols
```

Drive servers with a load generator while profiling (`autocannon -c 100 -d 20 http://localhost:3000/path`). clinic.js maintenance has slowed — confirm it runs on the project's Node major before relying on it; `--cpu-prof` and 0x are the dependable fallback.

**Browser**: Chrome DevTools Performance panel (record a trace on a production build with CPU throttling), React/Vue/Svelte devtools profilers for render cost.

**Memory profiling**:

```bash
node --heap-prof dist/app.js                          # sampling allocation profile (*.heapprofile)
node --heapsnapshot-signal=SIGUSR2 dist/app.js        # kill -USR2 <pid> writes a .heapsnapshot
node --heapsnapshot-near-heap-limit=2 dist/app.js     # snapshot before an OOM crash
node --trace-gc dist/app.js                           # GC frequency and pause times
```

Leak hunting: take three snapshots (baseline, after load, after more load), compare in DevTools Memory → "Comparison", look for retained object counts that only grow. `v8.writeHeapSnapshot()` writes one programmatically.

## Measuring in Code

```ts
import { monitorEventLoopDelay, performance } from "node:perf_hooks";

const loopDelay = monitorEventLoopDelay({ resolution: 20 });
loopDelay.enable();

const start = performance.now();
await handleBatch(items);
const elapsedMs = performance.now() - start;

// histogram values are nanoseconds
console.log({ elapsedMs, loopP99Ms: loopDelay.percentile(99) / 1e6 });
```

`performance.mark`/`performance.measure` with a `PerformanceObserver` for spans; `performance.eventLoopUtilization()` for how busy the loop is. Sustained p99 event-loop delay in the tens of milliseconds on a server means something is blocking the loop.

## Benchmarking

Use the harness the repo already has; otherwise vitest bench for vitest projects, tinybench or mitata elsewhere.

```ts
// parse.bench.ts — run with `vitest bench`
import { bench, describe } from "vitest";
import { parseFast, parseLegacy } from "./parse.js";

describe("parse", () => {
  bench("fast", () => { parseFast(input); });
  bench("legacy", () => { parseLegacy(input); });
});
```

```ts
import { Bench } from "tinybench";

const bench = new Bench({ time: 200 });
bench.add("fast", () => { sink = parseFast(input); });
await bench.run();
console.table(bench.table());
```

```ts
import { bench, do_not_optimize, run } from "mitata";

bench("fast", () => do_not_optimize(parseFast(input)));
await run();
```

Rules: consume every result (`do_not_optimize`, or assign to a module-level sink) so V8 cannot eliminate the work; let the harness warm up the JIT; vary inputs so the call site does not stay artificially monomorphic; run with `NODE_ENV=production` and no `--inspect`. Save a baseline and compare across runs (`vitest bench --outputJson` / `--compare`). End-to-end CLI timing: `hyperfine --warmup 3 'node dist/cli.js args'`.

## V8 Optimization

- **Hidden classes**: initialize every property in the constructor (or object literal) in the same order; never `delete` a property on a hot object (set it to `undefined` or use a `Map`); do not add properties after construction.
- **Monomorphic call sites**: hot functions should see objects of one shape. Mixing shapes makes the inline cache polymorphic, and past four shapes megamorphic — property access falls back to slow lookups. Normalize objects at the boundary (one class or one factory).
- **Array element kinds**: keep arrays homogeneous (all small integers, all doubles, or all objects); avoid holes (`new Array(n)` then sparse writes) — build with `push` or `Array.from({ length: n }, fn)`. Use typed arrays (`Float64Array`, `Uint8Array`) for numeric data.
- Avoid `arguments`, `eval`, and `with` in hot code.
- Investigate with `node --trace-opt --trace-deopt dist/app.js | grep <functionName>`; a function that deopts repeatedly in a hot loop is a target.

## Build Speed

```bash
tsc --noEmit --extendedDiagnostics          # check time, memory, files and types counts
tsc --noEmit --generateTrace trace && npx @typescript/analyze-trace trace   # hot spots in the checker
```

- `incremental: true` (with `tsBuildInfoFile`) caches type-check results between runs; cache the `.tsbuildinfo` in CI.
- Project references (`composite: true`, `references`, `tsc -b`) split a monorepo so only changed projects re-check.
- `isolatedModules: true` lets esbuild/swc/the bundler transpile file by file; run `tsc --noEmit` as a separate, parallel check. `isolatedDeclarations` makes `.d.ts` emit parallelizable too.
- `skipLibCheck: true` skips checking every `.d.ts` (dependencies and your own hand-written ones) — a large speedup, at the cost of missing conflicting or broken declaration files. Acceptable for apps; for published libraries keep a CI job that type-checks consumers or runs `attw`.
- `types: [...]` in `tsconfig` limits auto-included `@types/*`; make sure `include` does not pull in `dist/` or generated files.
- Expensive types: deep recursive conditional types, huge unions, and large intersections slow the checker — prefer `interface extends` over intersections, add explicit return types on exported functions, and cap recursion.
- Evaluate the native TypeScript compiler (`tsgo`, the TypeScript 7 line) when the project's TypeScript version and tooling support it.
- Typed lint rules re-run the type checker; keep them scoped, or move formatting and syntax rules to biome/oxlint.
- Install speed: pnpm's content-addressable store; `knip` to remove unused dependencies; `pnpm why <pkg>` / `npm ls <pkg>` to find duplicate versions.

## Bundle Size (libraries and frontends)

```bash
esbuild src/index.ts --bundle --minify --outdir=dist-analyze --metafile=meta.json --analyze   # size per input module
npx size-limit                                   # enforce budgets from .size-limit.json
npx source-map-explorer dist/*.js                # attribute bytes via source maps
```

- Vite/Rollup: `rollup-plugin-visualizer`; Next.js: `@next/bundle-analyzer`; webpack: `webpack-bundle-analyzer`.
- Tree-shaking needs ESM output, named imports, and `"sideEffects": false` (or a list) in `package.json`. Barrel files and CommonJS dependencies defeat it.
- Prefer per-function imports or ESM builds of utility libraries (`lodash-es`, not `lodash`); check that a dependency is not bundled twice at two versions.
- Split heavy, rarely used code behind dynamic `import()`.
- Budgets live in CI (`size-limit`), so growth fails a PR instead of being found later.

## Web Vitals (frontends)

Targets at the 75th percentile of real users: LCP ≤ 2.5 s, INP ≤ 200 ms, CLS ≤ 0.1. Measure field data with the `web-vitals` library (`onLCP`, `onINP`, `onCLS`) and lab data with Lighthouse / Lighthouse CI (`lhci autorun`). INP problems are long tasks on the main thread — split them, defer non-critical work, move heavy computation to a Web Worker. Virtualize long lists; avoid re-rendering subtrees whose props did not change.

## Production Build

- Run with `NODE_ENV=production` (frameworks and React ship slower dev builds otherwise).
- Compile to a modern `target` (`es2022` or the runtime's level) so async/await, classes, and spread are not down-leveled.
- Minify browser bundles; ship source maps as separate files.
- Node flags: `--max-old-space-size=<MB>` to raise the heap limit (only after ruling out a leak); `UV_THREADPOOL_SIZE` (default 4) when async `fs`, `dns.lookup`, `crypto.pbkdf2`/`scrypt`, or `zlib` calls queue up.

## Memory Optimization

- No spread or `concat` inside `reduce`/loops (`acc = [...acc, x]` is O(n²)); push into one array.
- Hoist closures, regexes, and object literals out of hot loops.
- No `JSON.parse(JSON.stringify(x))` deep clones in hot paths — avoid the copy or use `structuredClone`.
- Build large strings with an array and `join`, or stream them.
- Stream files and HTTP bodies with `pipeline` from `node:stream/promises` instead of buffering whole payloads; `Buffer.concat` once at the end, not per chunk.
- Bound every cache (`lru-cache` with `max`); `WeakMap` for metadata keyed by objects; remove event listeners you add.

## Concurrency Tuning

CPU-bound work moves off the event loop to `worker_threads` through a pool (piscina) sized at `os.availableParallelism()`. Sync APIs (`readFileSync`, `pbkdf2Sync`, `zlib.*Sync`), huge `JSON.parse`/`JSON.stringify`, and backtracking-prone regexes block the loop.

| Primitive | Use case | Order preserved |
|-----------|----------|-----------------|
| `p-map(items, fn, { concurrency: N })` | Map a collection with bounded concurrency | Yes |
| `p-limit(N)` + `Promise.all` | Wrap individual calls with a shared limit | Yes |
| `Readable.from(items).map(fn, { concurrency: N })` | Streaming pipelines (experimental stream API) | Yes |
| `Promise.allSettled` over a bounded batch | One failure must not abort the rest | Yes |

Per-operation timeout: `fetch(url, { signal: AbortSignal.timeout(5_000) })`. Batch deadline: combine with `AbortSignal.any([AbortSignal.timeout(perOpMs), batchSignal])` and pass the signal down.

## Anti-Patterns

- Profiling or benchmarking through `tsx`/`ts-node`, a dev server, or a debug build
- Unbounded `Promise.all(items.map(...))` over user-sized input
- Sync fs/crypto/zlib or large JSON work on the request path
- `delete` on hot objects; adding properties after construction
- Spread/`concat` accumulation inside loops
- Unbounded `Map`/object caches and leaked event listeners
- Barrel imports and CommonJS utility libraries in browser bundles
- Toggling `skipLibCheck` or loosening `strict` to speed up builds without measuring first
- Missing `AbortSignal` timeouts on network calls

## Tools Quick Reference

```bash
node --cpu-prof / --heap-prof           # CPU and allocation profiles
0x / clinic flame                       # Flamegraphs
autocannon                              # HTTP load
vitest bench / tinybench / mitata       # Microbenchmarks
hyperfine                               # CLI end-to-end timing
tsc --extendedDiagnostics               # Type-check cost
tsc --generateTrace                     # Checker hot spots
esbuild --metafile --analyze            # Bundle composition
size-limit                              # Bundle budgets
lhci autorun                            # Lighthouse CI
```
