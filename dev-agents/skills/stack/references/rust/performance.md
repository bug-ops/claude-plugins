# Rust — Performance Rules

## Profiling Tools

```bash
cargo install flamegraph
cargo flamegraph --bin your-app -- args                   # CPU profiling, opens flamegraph.svg
cargo install samply && samply record ...                 # Cross-platform alternative
instruments -t "Time Profiler" target/release/your-app    # macOS-native
perf record -g target/release/your-app && perf report     # Linux-native
```

**Memory profiling**: `dhat` — `#[global_allocator] static ALLOC: dhat::Alloc = dhat::Alloc;` plus `let _profiler = dhat::Profiler::new_heap();` at the top of `main`.

## Benchmarking

```bash
cargo bench                    # Run criterion benches
```

In `benches/foo.rs`: `criterion_group!` + `criterion_main!`, use `c.bench_function("name", |b| b.iter(|| op(black_box(&data))))`. Always wrap inputs in `black_box` to defeat constant folding. `cargo bench` builds with the `bench` profile (optimized); never time a debug build.

## Build Speed

### sccache — 10x+ speedup for repeated builds

```bash
brew install sccache
# ~/.cargo/config.toml:
[build]
rustc-wrapper = "sccache"
# Verify hits: sccache --show-stats
```

### XProtect exclusion — 3–4x speedup on macOS

System Settings → Privacy & Security → Developer Tools → add Terminal.app (and your IDE if used). Without this every cargo build re-scans every artifact through XProtect.

### Dependency feature trimming

`tokio = { version = "1", features = ["full"] }` brings in everything. Replace with the minimum set the crate actually uses (`["rt", "net", "time"]` etc.). Use `cargo machete` to find unused dependencies and `cargo tree --duplicates` to spot version conflicts that cause double compilation.

```bash
cargo build --timings    # Visualize per-crate compile time
cargo bloat --release    # Find binary bloat
```

## Release Profile

```toml
[profile.release]
opt-level = 3
lto = "thin"          # "fat" for max perf, "thin" for build-speed compromise
codegen-units = 1     # Slower build, better optimization
strip = true          # Strip debug symbols from binary
```

## Memory Optimization

Pre-allocate with `Vec::with_capacity(known_size)`. Reuse buffers across loop iterations (`buffer.clear()` instead of allocating). Use `Cow<str>` when ownership depends on input. Prefer iterators with `collect::<Vec<_>>()` (uses `size_hint`) over manual `push` loops.

## Concurrency Tuning

CPU-bound work runs through `tokio::task::spawn_blocking`; target `num_cpus × 2` blocking tasks.

Stream combinator performance:

| Combinator | Use case | Order preserved |
|------------|----------|-----------------|
| `buffer_unordered(N)` | Fastest, when order doesn't matter | No |
| `buffered(N)` | When input order must be preserved | Yes |
| `for_each_concurrent(N, f)` | Side effects, no return | N/A |

Per-operation timeout: `tokio::time::timeout(Duration::from_secs(N), op)`.

## Anti-Patterns

- Cloning in hot loops
- Blocking calls in async context (`std::thread::sleep`, blocking I/O)
- Benchmarking without `--release`
- Not using sccache for repeated builds
- Unbounded `join_all` instead of `buffer_unordered(N)`
- Spawning tasks in a loop instead of using stream combinators
- Missing `tokio::time::timeout` on network operations

## Tools Quick Reference

```bash
cargo flamegraph                # CPU profiling
cargo bench                     # Criterion benches
cargo build --timings           # Build performance
sccache --show-stats            # Cache hit rate
cargo bloat --release           # Binary bloat
cargo tree --duplicates         # Duplicate deps
cargo machete                   # Unused deps
```
