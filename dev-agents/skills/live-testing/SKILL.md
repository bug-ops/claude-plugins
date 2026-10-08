---
name: live-testing
description: "Live testing protocol for Rust and TypeScript projects: sync, discover project structure, execute the built binary, CLI, server, or web app end-to-end, detect anomalies, track coverage, file bug issues. Used by the live-tester agent; invoked directly it delegates to a background live-tester."
argument-hint: "[feature-name|regression|full]"
---

# Live Testing Protocol

Execute live tests on the current project: run the real artifact, verify behavior end-to-end, detect regressions, and file issues for every anomaly found.

**Focus**: $ARGUMENTS (default: `full` — all phases)

## Direct Invocation

This protocol is loaded by `live-tester` at startup via `Skill()`. When it is invoked directly (`/dev-agents:live-testing`) in a session that is **not** that agent, do not run the audit in the current context: delegate it so the findings, not the tool noise, land in the conversation.

```
Agent(subagent_type: "dev-agents:live-tester", description: "live-testing $ARGUMENTS",
  prompt: "Call Skill(skill: \"dev-agents:live-testing\", args: \"$ARGUMENTS\") and follow it end to end. Report findings and filed issue URLs; do not modify source files.")
```

The agent runs in the background; report its result when the task notification arrives. If you **are** `live-tester`, continue with the protocol below.

## Mandatory Reading

Read all reference files before starting:

- [Testing Methodology](${CLAUDE_PLUGIN_ROOT}/skills/live-testing/references/testing-methodology.md) — execution protocol, priority order, testing gate, journal, what to check after each session
- [Issue Management](${CLAUDE_PLUGIN_ROOT}/skills/continuous-improvement/references/issue-management.md) — anomaly classification, P0-P4 labels, filing template
- [SDD Integration](${CLAUDE_PLUGIN_ROOT}/skills/continuous-improvement/references/sdd-integration.md) — when and how to spawn the `sdd` agent before filing

## Stack Profile

For each detected profile (the `Stack:` line in your prompt, or the `stack` skill's detection), apply `${CLAUDE_PLUGIN_ROOT}/skills/stack/references/<profile>/live-tester.md` together with that profile's `toolchain.md`: manifest fields to read, build and run commands, log verbosity, crash signatures, benchmark and cleanup commands. Polyglot project: apply each profile to the components of its language.

## Project Verify Skill

If `.claude/skills/verify/SKILL.md` exists (created by `/dev-agents:init-project`), call `Skill(skill: "verify")` before Phase 2 and use its build, run, and test commands as the authoritative recipe. When a command there is wrong or a step is missing, fix that file — it is the project's shared verification recipe.

## Hard Rules

1. **NEVER modify source code** — not even one-liners; this covers sources, manifests, lockfiles, build and CI configs
2. **ALL findings become GitHub issues** — including symptoms without a known root cause; fixes happen in separate team sessions
3. **You MAY write ONLY to `.local/testing/`** — journal, coverage status, playbooks, debug logs, helper scripts — under the main repository root, even from a git worktree

## Phase 1: Sync

```bash
git pull origin main
```

- Review new commits to identify what changed since the last session
- Examine changed files to understand scope
- Update `.local/testing/coverage-status.md` — add `Untested` rows for new features, reset rows of significantly changed components to `Untested`
- Compare `git rev-parse HEAD` with the HEAD recorded in the last handoff or journal; equal means unchanged-HEAD mode (see Phase 3)
- Prioritize testing changed functionality first
- Journal: append to `{journal-path}` when the prompt passes one; standalone, create the next journal file per [Testing Methodology](${CLAUDE_PLUGIN_ROOT}/skills/live-testing/references/testing-methodology.md#journal)

## Phase 2: Project Discovery

Before testing, understand the project:

1. Read the manifest(s) the profile names — workspace members, entry points and build targets, feature flags or build modes
2. Look for test configs: `.local/config/`, `tests/`, env files, and the profile's config locations
3. Identify executable entry points and supported interfaces (CLI, TUI, server/API, web UI, bots)
4. Note the flags, env vars, or build modes needed to reach the feature under test

## Phase 3: Live Testing

**Unit and integration tests alone are NOT sufficient.** This phase requires real execution of the built artifact with real I/O and real user-like interactions. See [Testing Methodology](${CLAUDE_PLUGIN_ROOT}/skills/live-testing/references/testing-methodology.md) for the full execution guide.

**Priority order:**
1. New/changed functionality (from recent PRs) — highest probability of regressions
2. `Untested` or `Partial` components from `coverage-status.md`
3. Known-tricky scenarios from `regressions.md`
4. Cross-interface consistency (if project has multiple I/O modes)

**Unchanged HEAD:** never skip the session; follow [Testing Methodology](${CLAUDE_PLUGIN_ROOT}/skills/live-testing/references/testing-methodology.md#unchanged-head).

**Optional checks** (benchmarks, live drift gate): see [Testing Methodology](${CLAUDE_PLUGIN_ROOT}/skills/live-testing/references/testing-methodology.md#optional-checks).

**Testing gate:** When a large portion of components are Untested or Partial, testing takes priority over everything else. Do not proceed to Phase 4 until critical components are verified.

**After each test session, review:**
- Logs: WARN, ERROR, crashes (the profile's crash signatures), unexpected retries, timeouts
- Output correctness: expected vs actual behavior
- Resource usage: memory, CPU, latency, tokens if applicable
- Feature interactions: combinations that unit tests cannot cover

## Phase 4: Anomaly Detection and Issue Filing

For each anomaly found:

1. **Reproduce** — confirm the issue is consistent, not a one-off
2. **Document** — exact steps, config, relevant log excerpts
3. **Classify** — P0 (critical) to P4 (nice-to-have); see [Issue Management](${CLAUDE_PLUGIN_ROOT}/skills/continuous-improvement/references/issue-management.md)
4. **Spec** — for P0–P2: spawn `sdd` agent before filing; see [SDD Integration](${CLAUDE_PLUGIN_ROOT}/skills/continuous-improvement/references/sdd-integration.md)
5. **Check duplicates** — `gh issue list --state open --limit 100 --json number,title,labels`
6. **File** — `gh issue create` with the literal `P0`-`P4` label set at creation (create the label if missing), a category label, reproduction steps, evidence; file the implementation issue in the same pass as the spec. A symptom without a root cause is still filed
7. **Record** — append finding row (issue and spec together) to the journal (`{journal-path}` in a CI cycle, the standalone journal otherwise), update `coverage-status.md`

## Phase 5: Cross-Interface Consistency

If the project supports multiple interfaces (CLI, TUI, web, API, bots):

- Exercise the same scenario across all applicable interfaces
- Compare output content, formatting, behavior, state changes
- File issues when behavior diverges across interfaces

## Session Exit

Before finishing:

1. Update `.local/testing/coverage-status.md` for all components touched (rows in place, no cycle headers)
2. Run the [Process Self-Improvement Loop](${CLAUDE_PLUGIN_ROOT}/skills/live-testing/references/testing-methodology.md#process-self-improvement-loop)
3. Print a summary: features tested, issues filed, coverage changes
4. Write handoff with **Testing Results** section listing all filed issue URLs
