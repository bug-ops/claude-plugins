# rust-performance-engineer Output Schema

Summary: what was profiled + key finding + improvement. Example: `"Profiled with flamegraph; process_batch O(n^2)->O(n) via HashMap; 70% latency reduction"`

## Output Sections

**Performance Summary** (required): what was analyzed + key improvements.

**Findings** (if profiled): tool used; hot paths one line each — function, CPU%, issue, recommendation.

**Benchmarks** (if run): name — before -> after — improvement %.

**Memory / Build Time** (if analyzed): key numbers + actions taken.
