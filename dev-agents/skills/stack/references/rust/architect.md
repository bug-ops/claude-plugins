# Rust — Architect Rules

## Type-Level Toolkit

| Invariant | Rust construct |
|-----------|----------------|
| Domain value (id, email, amount) | Newtype with private field + smart constructor returning `Result<Self, Error>` |
| Closed set of alternatives | `enum` matched exhaustively |
| Compile-time marker, zero cost | Phantom type (`PhantomData<State>`) |
| State-machine correctness | Typestate: one type per state, transitions consume `self` |
| Extension point external code must not implement | Sealed trait: `mod private { pub trait Sealed {} }` as supertrait |
| Type chosen by the caller, many impls per type | Generic parameter |
| Type uniquely determined by the implementor | Associated type |
| Returned items borrow from `self` (streaming/lending) | GAT: `type Item<'a> where Self: 'a;` |

Sealed traits also allow adding methods later without a breaking change. No `is_valid()` on a constructed newtype — the constructor is the only validation point.

## API Naming

| Prefix | Cost | Example |
|--------|------|---------|
| `as_` | Free conversion | `str::as_bytes()` |
| `to_` | Expensive conversion | `str::to_lowercase()` |
| `into_` | Owned/consuming | `String::into_bytes()` |

Getters use the field name without `get_` prefix: `user.name()`, not `user.get_name()`. Implement `From<X>` rather than accepting `impl Into<X>` parameters.

## Scale-Appropriate Layout

Crate strategy: MVP — single crate, modules, basic newtypes; Small — single crate, feature flags, newtypes + builders; Medium — 2–5 crates in a workspace; Large — multi-workspace, library-first.

**MVP / Prototype** (single crate):
```
my-project/
├── Cargo.toml
├── src/{lib.rs, domain/, services/}
└── tests/
```

**Medium / Large** (workspace):
```
my-project/
├── Cargo.toml              # Virtual manifest
├── crates/{my-core, my-cli, my-server}/
├── .local/handoff/
└── docs/
```

## Workspace Cargo.toml Conventions

Defaults — follow the project's existing convention when one exists:

1. **Alphabetical order** — all dependencies sorted alphabetically
2. **Root manifest: versions only** — `[workspace.dependencies]` defines versions, no features
3. **Crate manifests: features only** — individual crates specify only the features they need with `workspace = true`
4. **Feature flags are additive only** — enabling a feature never removes API or changes behavior of other features

```toml
[workspace]
members = ["crates/*"]
resolver = "3"

[workspace.package]
edition = "2024"
rust-version = "1.85"

[workspace.lints.clippy]
all = "warn"
pedantic = "warn"

[workspace.dependencies]
anyhow = "1.0"
serde = "1.0"
thiserror = "2.0"
tokio = "1.42"
```

## Async Concurrency Patterns

| Pattern | Use Case | Combinator |
|---------|----------|------------|
| All succeed or fail together | Batch writes | `futures::try_join!` |
| Independent operations | Parallel API calls | `futures::join!` |
| First result wins | Timeout + operation | `futures::select!` |
| Bounded concurrent stream | Rate-limited processing | `StreamExt::buffer_unordered(N)` |
| Process stream concurrently | Parallel I/O | `StreamExt::for_each_concurrent(N, ...)` |

No `join_all` on unbounded collections. CPU-bound work goes through `tokio::task::spawn_blocking`.

## Edition 2024 Considerations

Key changes that affect API design:
- RPIT lifetime capture (breaking)
- Async closures
- Unsafe extern blocks
- Match ergonomics changes

Target Rust 1.85+ for Edition 2024. Set `rust-version` in `[workspace.package]` and respect it in feature recommendations (`rust-modern-apis` lists what each version adds).

## Checklist Additions

- [ ] Target Rust version (`rust-version`) and edition decided
- [ ] Associated types vs generics decision documented
- [ ] Sealed traits identified
- [ ] Crate boundaries follow domain boundaries; feature flags are additive only

## Tools

Beyond `toolchain.md` (public API breakage, dependency audit, macro expansion):

```bash
cargo doc --open            # Render API docs
cargo build --timings       # Build performance
cargo tree --duplicates     # Find duplicate dependency versions
```

## Anti-Patterns

- `bool` parameters — use enums
- Public struct fields that allow invalid states
- `Option<Option<T>>` — model states explicitly
- `impl Into<X>` parameters — implement `From<X>` instead
- Typestate with many states where an `enum` + `match` would be clearer
