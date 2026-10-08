---
name: research-protocol
description: "Research and monitoring protocol for Rust and TypeScript projects: dependency health, security advisories, competitive parity, innovation research, issue filing. Used by the researcher agent; invoked directly it delegates to a background researcher."
argument-hint: "[dependencies|research|parity|full]"
---

# Research and Monitoring Protocol

Monitor the project's dependency health, track the competitive landscape, and surface new techniques that could benefit the project. File GitHub issues for every actionable finding.

**Focus**: $ARGUMENTS (default: `full` — all phases)

## Direct Invocation

This protocol is loaded by `researcher` at startup via `Skill()`. When it is invoked directly (`/dev-agents:research-protocol`) in a session that is **not** that agent, do not run the audit in the current context: delegate it so the findings, not the tool noise, land in the conversation.

```
Agent(subagent_type: "dev-agents:researcher", description: "research-protocol $ARGUMENTS",
  prompt: "Call Skill(skill: \"dev-agents:research-protocol\", args: \"$ARGUMENTS\") and follow it end to end. Report findings and filed issue URLs; do not modify source files.")
```

The agent runs in the background; report its result when the task notification arrives. If you **are** `researcher`, continue with the protocol below.

## Mandatory Reading

Read all reference files before starting:

- [Research Protocol](${CLAUDE_PLUGIN_ROOT}/skills/research-protocol/references/research-protocol.md) — research methodology, competitive parity, dependency monitoring
- [Issue Management](${CLAUDE_PLUGIN_ROOT}/skills/continuous-improvement/references/issue-management.md) — anomaly classification, P0-P4 labels, filing template
- [SDD Integration](${CLAUDE_PLUGIN_ROOT}/skills/continuous-improvement/references/sdd-integration.md) — when and how to spawn the `sdd` agent before filing

## Stack Profile

For each detected profile (the `Stack:` line in your prompt, or the `stack` skill's detection), apply `${CLAUDE_PLUGIN_ROOT}/skills/stack/references/<profile>/researcher.md` together with that profile's `toolchain.md`: outdated and advisory commands, registries and advisory databases, package health signals, ecosystem research topics, common vulnerability classes. Polyglot project: monitor every profile's dependency tree.

## Hard Rules

1. **NEVER modify source code** — not even dependency versions in a manifest or lockfile
2. **ALL findings become GitHub issues** — implementation happens in separate sessions
3. **You MAY write ONLY to `.local/testing/` and `.local/specs/`** — under the main repository root, even from a git worktree

**Journal:** append findings to `{journal-path}` when the prompt passes one; standalone, use the journal per [Testing Methodology](${CLAUDE_PLUGIN_ROOT}/skills/live-testing/references/testing-methodology.md#journal).

**Unchanged HEAD:** when the cycle prompt says HEAD is unchanged, run a delta check only. See [Research Protocol](${CLAUDE_PLUGIN_ROOT}/skills/research-protocol/references/research-protocol.md#delta-check-on-unchanged-head).

## Phase 1: Dependency Monitoring (`dependencies`, `full`)

Run the profile's version-drift and security-advisory commands for every detected profile.

Update priority and issue filing — see [Research Protocol](${CLAUDE_PLUGIN_ROOT}/skills/research-protocol/references/research-protocol.md#dependency-monitoring).

For major version bumps or security advisories: spawn `sdd` agent before filing (see [SDD Integration](${CLAUDE_PLUGIN_ROOT}/skills/continuous-improvement/references/sdd-integration.md)). Routine patch/minor updates: file directly.

## Phase 2: Research & Innovation (`research`, `full`)

Search for new techniques relevant to the project's domain:

- Architectural patterns, concurrency models, state machines
- Performance techniques: fewer copies and allocations, data layout, parallelism, startup time, artifact size
- Safety practices: compile-time and type-level guarantees, typestate, capability-based design
- Ecosystem evolution: new libraries, deprecated dependencies, emerging standards, language and runtime releases
- Tooling improvements: profiling, debugging, testing frameworks
- Plus the language-specific topics in the profile's `researcher.md`

Also treat dependency functionality coverage as a research question: does a major dependency offer capabilities the project does not use? See [Research Protocol](${CLAUDE_PLUGIN_ROOT}/skills/research-protocol/references/research-protocol.md#dependency-functionality-coverage).

For each finding:
1. Assess: impact on project quality vs implementation complexity
2. Spawn `sdd` agent to produce a spec (all research findings require a spec)
3. Check for duplicate issues before filing
4. File research issue with source links, implementation sketch, spec path, and a priority label at creation (see [Issue Management](${CLAUDE_PLUGIN_ROOT}/skills/continuous-improvement/references/issue-management.md#priority-label-mandatory)); file it in the same pass as the spec

## Phase 3: Competitive Parity (`parity`, `full`)

Identify reference projects in the same domain, review their recent changelogs, and assess capability gaps. See [Research Protocol](${CLAUDE_PLUGIN_ROOT}/skills/research-protocol/references/research-protocol.md#competitive-parity-monitoring) for the full scan procedure.

Parity gap severity:
- **P1** — active incompatibility with a first-class integration target
- **P2** — meaningful capability that 2+ reference projects have and users would notice
- **P3** — useful feature, low urgency
- **P4** — cosmetic or niche difference

Update `.local/testing/playbooks/competitive-parity.md` after each scan.

## Optional Phases

When applicable to the project (see [Research Protocol](${CLAUDE_PLUGIN_ROOT}/skills/research-protocol/references/research-protocol.md)):

- **Competitor gap analysis** — `competitor-gap` label, exhaustion criterion, discovery of new competitors
- **CVE and vulnerability-class sweep** — monthly, separate from the parity scan; P0 if the class is unprotected

## Session Exit

Before finishing:

1. Append a methodology-only retrospective to `.local/testing/process-notes.md`; a technique that proved effective becomes a playbook, a failed one is documented and dropped
2. Print a summary: dependency advisories found, research issues filed, parity gaps identified
3. Write handoff with **Research Results** section listing all filed issue URLs and spec paths
