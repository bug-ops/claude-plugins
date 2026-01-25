# rust-performance-engineer Output Schema

```yaml
output:
  summary: "Performance analysis and optimizations"
  
  profiling:
    tool: flamegraph  # flamegraph | instruments | dhat
    hot_paths:
      - function: process_batch
        cpu_percent: 35
        issue: "O(n²) complexity"
        recommendation: "Use HashMap for lookup"
  
  benchmarks:
    - name: process_single
      before_ms: 150
      after_ms: 45
      improvement: "70%"
  
  memory:
    peak_mb: 256
    allocations: 1500
    issues:
      - "Unnecessary cloning in loop"
  
  build_time:
    before_sec: 45
    after_sec: 12
    optimizations:
      - "Enabled sccache"
      - "Reduced features in tokio"
```

## Field Descriptions

| Field | Required | Description |
|-------|----------|-------------|
| `summary` | yes | Brief description of performance work |
| `profiling` | if done | Profiling tool and findings |
| `benchmarks` | if done | Before/after benchmark results |
| `memory` | if analyzed | Memory usage analysis |
| `build_time` | if optimized | Build time improvements |

## Profiling Tools

| Tool | Platform | Use Case |
|------|----------|----------|
| `flamegraph` | All | CPU profiling, hot path analysis |
| `instruments` | macOS | Time Profiler, Allocations |
| `dhat` | All | Heap profiling |
| `samply` | All | Sampling profiler |

## Common Optimizations

**Runtime:**
- Pre-allocate collections with `with_capacity()`
- Use `Cow<str>` for conditional ownership
- Avoid `.clone()` in hot paths

**Build time:**
- Enable sccache
- Minimize feature flags
- Use `cargo build --timings` to find slow crates

## Multiple Parent Sources Example

When optimizing based on multiple contexts:

```yaml
id: 2025-01-09T19-00-00-performance
parent:
  - 2025-01-09T14-30-45-architect  # Design constraints
  - 2025-01-09T15-30-00-developer  # Current implementation
  - 2025-01-09T18-00-00-debug      # Bottleneck analysis
agent: performance
```

Use this when:
- Optimizing implementation (developer) while respecting design constraints (architect)
- Following up on bottlenecks identified by debugger
- Applying performance fixes after testing reveals slow paths
- Ensuring optimizations don't violate architecture decisions
