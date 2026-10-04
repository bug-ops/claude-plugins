# Testing Methodology

## Why Live Testing

Unit and integration tests run in CI automatically and verify isolated code paths. The continuous improvement cycle requires **live testing**: real binary execution, real I/O, real user-like interactions. This catches issues that unit tests structurally cannot:

- Serialization mismatches that only appear with real external services
- Configuration errors invisible in test environments
- UX regressions in interactive modes
- Performance degradation under realistic load
- Feature interactions that span multiple subsystems

## Cycle Start

Before any testing, in this order:

1. Sync with the remote: `git pull origin main` (or the project's default branch).
2. Read the new commits and the files they touched to scope what changed.
3. Add an `Untested` row to `coverage-status.md` for every new feature that has no row yet.
4. Compare `git rev-parse HEAD` with the HEAD recorded in the last handoff or cycle journal (`head:` frontmatter). Equal HEADs mean the cycle runs in unchanged-HEAD mode.

## Unchanged HEAD

Never skip the cycle and never replay the same regression scenarios. Redirect effort to stale coverage:

1. Collect the `Untested` and `Partial` rows of `coverage-status.md`, oldest `Last session` first, and live-test the top 3-5.
2. Re-verify every `Tested` row whose dependencies moved since its `Last session` date (`Cargo.lock` history, dependency-bump commits, the researcher's findings). A `Tested` status tied to old dependency versions is stale.
3. Update each touched row in place, even when re-verification finds nothing; a clean re-verification is a valid result.

## Testing Priority Order

1. **New functionality first** — features added or changed in the most recent PRs. New code has the least real-world exercise and is the most likely source of regressions
2. **Regression testing second** — features not tested in a long time (check `coverage-status.md`; components marked `Untested`, last tested more than 2 milestones ago, or whose dependencies moved since)
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

## Coverage Status File

`.local/testing/coverage-status.md` is a permanent master table: one row per feature or subsystem, always the current state. Rows are updated in place. No per-cycle headers, no round logs, no history; history lives in `journal/ci-NNN.md`.

| Component | Status | Last session | Version | Issues | Result |
|---|---|---|---|---|---|
| Feature / subsystem | Tested / Partial / Untested / Blocked / Removed | CI-NNN (YYYY-MM-DD) | vX.Y.Z | #NNN or — | One-line outcome or blocker |

- **Tested** — all primary scenarios verified live, no known gaps
- **Partial** — happy path verified, edge or secondary scenarios remain
- **Untested** — never live-tested, or reset after a significant change
- **Blocked** — cannot be tested; state the blocker in Result
- **Removed** — feature left the codebase; keep the row with the last version

Maintenance rules:

1. Add an `Untested` row before a feature PR merges.
2. Reset a row to `Untested` when its code changes significantly.
3. Update status and result right after the session that tested it; do not batch updates.
4. One row per logical feature, not per PR; merge related PRs into one issue list.
5. Never delete the file or its rows.

A feature PR should ideally ship a playbook under `playbooks/` and its coverage row (recommended, not enforced).

Legacy layout: if the project has `coverage.md` or a chronological `journal.md`, migrate once. Rename `coverage.md` to `coverage-status.md` and convert it to the table above; move `journal.md` entries into `journal/ci-NNN.md` files.

## Artifact Location

Write `.local/testing/` artifacts (playbooks, coverage status, journal, process notes) under the **main repository root**, even when running from a git worktree. They are shared project knowledge and must not live inside a disposable worktree. Handoffs stay in the current directory's `.local/handoff/`.

When `journal/` grows unwieldy, move old `ci-NNN.md` files to `journal/archive/`; never delete them. Cycle numbering counts both directories: the next number is the highest `ci-NNN` across `journal/` and `journal/archive/`, plus one.

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

Proven techniques and failures feed the loop below.

## Process Self-Improvement Loop

After every session, evaluate the testing process as well as the product:

1. Append a short retrospective to `.local/testing/process-notes.md`: methodology only (what was tried, whether it worked, what to try next). Findings go to issues and the journal.
2. A technique that proved effective becomes a playbook in `.local/testing/playbooks/`.
3. A technique that failed or added no value is documented in `process-notes.md` with the reason, then dropped.
4. Every bug gets its minimal reproduction in `.local/testing/regressions.md`; re-run the file after significant changes.
5. The same category of bug three or more times calls for a structural fix or an automated regression test; file an issue proposing it.
6. Improvements that need code changes (better diagnostics, test hooks, fixtures) are filed with the `testing-infra` label. Helper scripts and fixtures needed for live testing are written directly in `.local/testing/`.
7. Prune outdated entries in `process-notes.md` and `regressions.md` periodically.

## Optional Checks

Run when the project qualifies; skip silently otherwise.

- **Benchmarks (when `benches/` exists)** — run the benchmark suite each cycle, including unchanged-HEAD cycles, and compare with the previous cycle's recorded numbers. A regression above 10% is a P1 finding; smaller ones are P2. Record the numbers in the journal even when unchanged.
- **Live drift gate** — when the project depends on an external API or registry, run one cheap live call each cycle (a one-line `curl` or client invocation) and compare status and response shape with what the code expects. A mismatch is a finding even when CI fixtures pass.

## Test Environment Hygiene

Before comprehensive testing sessions, clean stale artifacts:
- Old debug dumps and session logs
- Stale test databases that could affect results
- Accumulated audit/overflow files

**Preserve persistent knowledge:** `journal/ci-*.md` files, coverage status, playbooks, process notes — never delete these.

After intensive testing sessions, consider running `cargo clean` to free disk space from incremental build artifacts.
