# rust-performance-engineer Output Schema

## Summary Field (frontmatter)

One sentence covering: what was profiled + key finding + improvement achieved.

Example: `"Profiled with flamegraph; process_batch O(n²)→O(n) via HashMap; 70% latency reduction"`

## Output Sections

**Performance Summary** (required): What was analyzed and key improvements.

**Profiling Results** (if done): Tool used, hot paths found (function, CPU%, issue, recommendation).

**Benchmarks** (if done): For each benchmark — name, before ms, after ms, improvement %.

**Memory Analysis** (if analyzed): Peak MB, allocation count, issues found.

**Build Time** (if optimized): Before/after seconds, optimizations applied.

## Profiling Tools

| Tool | Use Case |
|------|----------|
| `flamegraph` | CPU profiling, hot path analysis |
| `instruments` | macOS Time Profiler / Allocations |
| `dhat` | Heap profiling |
| `samply` | Sampling profiler (all platforms) |

## Common Optimizations

**Runtime:** Pre-allocate with `with_capacity()`; use `Cow<str>` for conditional ownership; avoid `.clone()` in hot paths.

**Build time:** Enable sccache; minimize feature flags; use `cargo build --timings` to find slow crates.
