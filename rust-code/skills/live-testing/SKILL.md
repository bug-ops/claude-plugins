---
name: live-testing
description: "Live testing protocol for Rust projects: sync, discover project structure, execute binary end-to-end, detect anomalies, track coverage, file bug issues. Used by the rust-live-tester agent."
argument-hint: "[feature-name|regression|full]"
---

# Live Testing Protocol

Execute live tests on the current Rust project: run the real binary, verify behavior end-to-end, detect regressions, and file issues for every anomaly found.

**Focus**: $ARGUMENTS (default: `full` — all phases)

## Mandatory Reading

Read all reference files before starting:

- [Testing Methodology](references/testing-methodology.md) — execution protocol, priority order, testing gate, what to check after each session
- [Issue Management](references/issue-management.md) — anomaly classification, P0-P4 labels, filing template
- [SDD Integration](references/sdd-integration.md) — when and how to spawn the `sdd` agent before filing

## Hard Rules

1. **NEVER modify source code** — not even one-liners
2. **ALL findings become GitHub issues** — fixes happen in separate sessions
3. **You MAY write ONLY to `.local/testing/`** — journal, coverage status, playbooks, debug logs

## Phase 1: Sync

```bash
git pull origin main
```

- Review new commits to identify what changed since the last cycle
- Examine changed files to understand scope
- Update `.local/testing/coverage-status.md` — mark changed components as `Untested`
- Prioritize testing changed functionality first

## Phase 2: Project Discovery

Before testing, understand the project:

1. Read `Cargo.toml` — extract workspace members, features, default-run target
2. Look for test configs: `.local/config/`, `tests/`, `.cargo/config.toml`
3. Identify executable entry points and supported interfaces (CLI, TUI, API, bots)
4. Check for feature flags — `cargo run --features <flags>` may be needed

## Phase 3: Live Testing

**Unit and integration tests alone are NOT sufficient.** This phase requires real binary execution with real I/O and real user-like interactions. See [Testing Methodology](references/testing-methodology.md) for the full execution guide.

**Priority order:**
1. New/changed functionality (from recent PRs) — highest probability of regressions
2. `Untested` or `Partial` components from `coverage-status.md`
3. Known-tricky scenarios from `regressions.md`
4. Cross-interface consistency (if project has multiple I/O modes)

**Testing gate:** When a large portion of components are Untested or Partial, testing takes priority over everything else. Do not proceed to Phase 4 until critical components are verified.

**After each test session, review:**
- Logs: WARN, ERROR, panics, unexpected retries, timeouts
- Output correctness: expected vs actual behavior
- Resource usage: memory, CPU, latency, tokens if applicable
- Feature interactions: combinations that unit tests cannot cover

## Phase 4: Anomaly Detection and Issue Filing

For each anomaly found:

1. **Reproduce** — confirm the issue is consistent, not a one-off
2. **Document** — exact steps, config, relevant log excerpts
3. **Classify** — P0 (critical) to P4 (nice-to-have); see [Issue Management](references/issue-management.md)
4. **Spec** — for P0–P2: spawn `sdd` agent before filing; see [SDD Integration](references/sdd-integration.md)
5. **Check duplicates** — `gh issue list --state open --limit 100 --json number,title,labels`
6. **File** — `gh issue create` with priority + category labels, reproduction steps, evidence
7. **Record** — add finding to `.local/testing/journal.md`, update `coverage-status.md`

## Phase 5: Cross-Interface Consistency

If the project supports multiple interfaces (CLI, TUI, web, API, bots):

- Exercise the same scenario across all applicable interfaces
- Compare output content, formatting, behavior, state changes
- File issues when behavior diverges across interfaces

## Session Exit

Before finishing:

1. Update `.local/testing/coverage-status.md` for all components touched
2. Append session retrospective to `.local/testing/process-notes.md`
3. Print a summary: features tested, issues filed, coverage changes
4. Write handoff with **Testing Results** section listing all filed issue URLs
