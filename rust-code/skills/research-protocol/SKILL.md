---
name: research-protocol
description: "Research and monitoring protocol for Rust projects: dependency health, security advisories, competitive parity, innovation research, issue filing. Used by the rust-researcher agent; invoked directly it delegates to a background rust-researcher."
argument-hint: "[dependencies|research|parity|full]"
---

# Research and Monitoring Protocol

Monitor the project's dependency health, track the competitive landscape, and surface new techniques that could benefit the project. File GitHub issues for every actionable finding.

**Focus**: $ARGUMENTS (default: `full` — all phases)

## Direct Invocation

This protocol is loaded by `rust-researcher` at startup via `Skill()`. When it is invoked directly (`/rust-agents:research-protocol`) in a session that is **not** that agent, do not run the audit in the current context: delegate it so the findings, not the tool noise, land in the conversation.

```
Agent(subagent_type: "rust-agents:rust-researcher", description: "research-protocol $ARGUMENTS",
  prompt: "Call Skill(skill: \"rust-agents:research-protocol\", args: \"$ARGUMENTS\") and follow it end to end. Report findings and filed issue URLs; do not modify source files.")
```

The agent runs in the background; report its result when the task notification arrives. If you **are** `rust-researcher`, continue with the protocol below.

## Mandatory Reading

Read all reference files before starting:

- [Research Protocol](references/research-protocol.md) — research methodology, competitive parity, dependency monitoring
- [Issue Management](references/issue-management.md) — anomaly classification, P0-P4 labels, filing template
- [SDD Integration](references/sdd-integration.md) — when and how to spawn the `sdd` agent before filing

## Hard Rules

1. **NEVER modify source code** — not even `Cargo.toml` dependency versions
2. **ALL findings become GitHub issues** — implementation happens in separate sessions
3. **You MAY write ONLY to `.local/testing/` and `.local/specs/`** — under the main repository root, even from a git worktree

**Unchanged HEAD:** when the cycle prompt says HEAD is unchanged, run a delta check only. See [Research Protocol](references/research-protocol.md#delta-check-on-unchanged-head).

## Phase 1: Dependency Monitoring (`dependencies`, `full`)

```bash
cargo outdated --workspace          # Version drift
cargo deny check advisories         # Security advisories (RUSTSEC)
```

Update priority and issue filing — see [Research Protocol](references/research-protocol.md#dependency-monitoring).

For major version bumps or security advisories: spawn `sdd` agent before filing (see [SDD Integration](references/sdd-integration.md)). Routine patch/minor updates: file directly.

## Phase 2: Research & Innovation (`research`, `full`)

Search for new techniques relevant to the project's domain:

- Architectural patterns, concurrency models, state machines
- Performance techniques: zero-copy, SIMD, memory layout
- Safety practices: compile-time guarantees, typestate, capability-based design
- Ecosystem evolution: new crates, deprecated dependencies, emerging standards
- Tooling improvements: profiling, debugging, testing frameworks

Also treat dependency functionality coverage as a research question: does a major dependency offer capabilities the project does not use? See [Research Protocol](references/research-protocol.md#dependency-functionality-coverage).

For each finding:
1. Assess: impact on project quality vs implementation complexity
2. Spawn `sdd` agent to produce a spec (all research findings require a spec)
3. Check for duplicate issues before filing
4. File research issue with source links, implementation sketch, spec path, and a priority label at creation (see [Issue Management](references/issue-management.md#priority-label-mandatory)); file it in the same pass as the spec

## Phase 3: Competitive Parity (`parity`, `full`)

Identify reference projects in the same domain, review their recent changelogs, and assess capability gaps. See [Research Protocol](references/research-protocol.md#competitive-parity-monitoring) for the full scan procedure.

Parity gap severity:
- **P1** — active incompatibility with a first-class integration target
- **P2** — meaningful capability that 2+ reference projects have and users would notice
- **P3** — useful feature, low urgency
- **P4** — cosmetic or niche difference

Update `.local/testing/playbooks/competitive-parity.md` after each scan.

## Optional Phases

When applicable to the project (see [Research Protocol](references/research-protocol.md)):

- **Competitor gap analysis** — `competitor-gap` label, exhaustion criterion, discovery of new competitors
- **CVE and vulnerability-class sweep** — monthly, separate from the parity scan; P0 if the class is unprotected

## Session Exit

Before finishing:

1. Append a methodology-only retrospective to `.local/testing/process-notes.md`; a technique that proved effective becomes a playbook, a failed one is documented and dropped
2. Print a summary: dependency advisories found, research issues filed, parity gaps identified
3. Write handoff with **Research Results** section listing all filed issue URLs and spec paths
