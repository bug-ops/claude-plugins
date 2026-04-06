# Testing Methodology

## Why Live Testing

Unit and integration tests run in CI automatically and verify isolated code paths. The continuous improvement cycle requires **live testing**: real binary execution, real I/O, real user-like interactions. This catches issues that unit tests structurally cannot:

- Serialization mismatches that only appear with real external services
- Configuration errors invisible in test environments
- UX regressions in interactive modes
- Performance degradation under realistic load
- Feature interactions that span multiple subsystems

## Testing Priority Order

1. **New functionality first** — features added or changed in the most recent PRs. New code has the least real-world exercise and is the most likely source of regressions
2. **Regression testing second** — features not tested in a long time (check `coverage-status.md`; components marked `Untested` or last tested more than 2 milestones ago)
3. **Everything else** — research, dependency updates, tooling improvements

Transition to research only when all recently-changed components are verified and no `Untested` critical components remain.

## Testing Gate

**Stability over novelty**: when a large portion of existing functionality is untested, testing takes absolute priority over new features, research, and dependency updates.

- Check `coverage-status.md` before starting any new work: if the ratio of Untested/Partial components is high, focus on testing
- Every new feature MUST be exercised in a live session before moving to the next cycle task
- When a batch of changes lands (multiple PRs):
  1. Identify which changes affect core behavior
  2. Test each critical component with targeted scenarios
  3. Review output and logs for regressions
  4. Only after confirming no critical anomalies — continue the cycle
- Small isolated changes (docs, cosmetic fixes, config-only) may skip live testing if covered by CI

## Project Discovery

Before testing, understand the project:

1. Read `Cargo.toml` — extract workspace members, features, default-run target
2. Look for test configs: `.local/config/`, `tests/`, `.cargo/config.toml`
3. Identify executable entry points and supported interfaces
4. Check for feature flags: `cargo run --features <flags>` may be needed
5. Look for project-specific testing instructions in `.claude/rules/` or CLAUDE.md

## How to Test

### Running the Project

Build and run with all features enabled (adapt to project):

```bash
cargo run --features <project-features> -- <args>
```

If the project has a test configuration file, use it. Common locations:
- `.local/config/testing.toml`
- `config/test.toml`
- `.env.test`

### Debug Output

For deeper investigation:

```bash
RUST_LOG=debug cargo run --features <flags> -- <args> 2>.local/testing/debug/session.log
```

### What to Check After Each Session

1. **Logs** — grep for WARN, ERROR, panics, unexpected retries, timeouts
2. **Output correctness** — verify responses, data formats, behavior match expectations
3. **Resource usage** — memory consumption, CPU, latency, token usage if applicable
4. **Feature interactions** — do features work correctly in combination, not just isolation

## Critical Path Testing

Features touching these areas are prone to silent breakage:
- **Serialization/deserialization** — request/response formats, data persistence
- **Network protocols** — API calls, protocol handshakes, transport layers
- **State machines** — transitions, edge states, recovery paths
- **Configuration parsing** — new options, defaults, validation

Before any PR touching these paths, run a live test and verify no errors in logs and correct behavior.

## Cross-Interface Consistency

If the project supports multiple interfaces (CLI, TUI, web, API, bots, channels):

- Exercise the same scenario across all applicable interfaces
- Compare: output content, formatting, behavior, state changes
- Common divergence patterns:
  - Feature works in one interface but silently skipped in another
  - Output rendered differently (truncation, formatting, missing fields)
  - State changes in one interface not reflected in another
  - Config option respected in one interface but ignored in another
- File issues when behavior diverges across interfaces

## Testing Innovation

Actively expand testing approaches:

| Technique | Description |
|-----------|-------------|
| Adversarial inputs | Craft inputs designed to break behavior (injection, contradictions, ambiguity) |
| Stress testing | Long sessions, rapid operations, large outputs, resource exhaustion |
| Cross-component | Test feature combinations that unit tests cannot cover |
| Regression replay | Re-run known-tricky scenarios after every significant change |
| Comparative | Same operation across different configurations or backends |
| Boundary | Extreme config values, disabled features, minimal resources |
| End-to-end | Simulate real user sessions and evaluate holistically |

When a technique proves effective, formalize it into a playbook in `.local/testing/playbooks/`. When a technique fails, document why in `process-notes.md` and stop using it.

## Test Environment Hygiene

Before comprehensive testing sessions, clean stale artifacts:
- Old debug dumps and session logs
- Stale test databases that could affect results
- Accumulated audit/overflow files

**Preserve persistent knowledge:** journal, coverage status, playbooks, process notes — never delete these.

After intensive testing sessions, consider running `cargo clean` to free disk space from incremental build artifacts.
