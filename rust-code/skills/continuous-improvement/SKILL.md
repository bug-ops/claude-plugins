---
name: continuous-improvement
description: "Run a continuous improvement cycle: sync, live-test, detect anomalies, monitor dependencies, research, file issues. Read-only — never modifies source code."
argument-hint: "[testing|research|dependencies|parity|full]"
---

# Continuous Improvement Cycle

Run a continuous improvement cycle for the current Rust project. This is a read-only operational loop: test the project live, find gaps, file GitHub issues, research new techniques, and keep dependencies current.

**Focus**: $ARGUMENTS (default: `full` — runs all phases)

## Mandatory Reading

Read all reference files before starting — they contain the detailed execution guide:

- [Testing Methodology](references/testing-methodology.md) — live testing protocol, priority order, testing gate
- [Issue Management](references/issue-management.md) — anomaly classification, P0-P4 labels, filing protocol
- [Research Protocol](references/research-protocol.md) — innovation research, competitive parity, dependency monitoring

## Project-Specific Rules

Check if the project has a `.claude/rules/continuous-improvement.md` file. If it exists, read it — it contains project-specific CI cycle instructions (testing configs, subsystem lists, reference agents, environment setup, etc.) that **take precedence** over the generic defaults below. Follow both: this skill provides the universal framework, the project rules provide the concrete details.

## Hard Rules

1. **NEVER modify source code** — not even "quick fixes" or one-liners
2. **NEVER run this cycle in a subagent** — execute in main conversation context
3. **ALL findings become GitHub issues** — fixes happen in separate `/rust-agents:rust-team` sessions
4. **You MAY create/update files ONLY in `.local/testing/`** — journal, coverage status, playbooks

## Cycle Phases

### Phase 1: Sync (`testing`, `full`)

```bash
git pull origin main
```

- Review new commits to identify what changed
- Read `Cargo.toml` to discover workspace members and feature flags
- Update `.local/testing/coverage-status.md` — mark changed features as `Untested`

### Phase 2: Live Testing (`testing`, `full`)

Run the project binary with appropriate test configuration. Unit tests alone are NOT sufficient — exercise features end-to-end with real execution.

**Priority order:**
1. New/changed functionality (from recent PRs)
2. Regression testing (features not tested recently)
3. Cross-interface consistency (if project has multiple I/O modes)

**After each test session**, review:
- Logs: WARN, ERROR, panics, unexpected retries
- Resource usage: memory, CPU, tokens
- Correctness: expected vs actual behavior

**Document all results** in `.local/testing/journal.md` and update `.local/testing/coverage-status.md`.

### Phase 3: Issue Filing (`testing`, `full`)

For each anomaly found, file a GitHub issue via `gh issue create` with:
- Priority label (P0-P4) and category label (bug, enhancement, research)
- Reproduction steps, expected vs actual, relevant log excerpts
- See [Issue Management](references/issue-management.md) for details

### Phase 4: Dependency Monitoring (`dependencies`, `full`)

```bash
cargo outdated --workspace
cargo deny check advisories
```

File issues for needed updates with appropriate priority.

### Phase 5: Research & Parity (`research`, `parity`, `full`)

- Search for new techniques relevant to the project's domain
- Monitor reference projects for capabilities this project lacks
- Cross-reference findings with academic literature when applicable
- File `research` issues (check for duplicates first)

## Session Exit

Before finishing the cycle:
1. Update `.local/testing/coverage-status.md` for all features touched
2. Append retrospective to `.local/testing/process-notes.md`
3. Print a summary: features tested, issues filed, dependency alerts, research findings
