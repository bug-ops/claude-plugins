---
name: rust-team
description: "Orchestrate Rust development using agent teams with peer-to-peer communication. Use when: 'create rust team', 'start team development', 'launch agent team', 'team workflow', 'collaborative development'. Requires rust-agents plugin and CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1."
argument-hint: "[task-description]"
---

# Rust Team Orchestration

Team-based development orchestration for Rust projects using Claude Code agent teams. Coordinates specialist agents from the `rust-agents` plugin with peer-to-peer communication via SendMessage.

**Task**: $ARGUMENTS

## Prerequisites

Before starting, verify:

1. **Experimental flag**: `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` must be set in environment or `settings.json`
2. **rust-agents plugin**: Must be installed (`claude plugin install rust-agents`)
3. **Git branch**: If on `main`/`master`, create a feature branch first
4. **Working directory clean**: No uncommitted changes
5. **Rust project**: `Cargo.toml` must exist

## Quick Start

```
/rust-team Implement user authentication with JWT tokens
```

## Orchestration Model Comparison

| Feature | rust-agents:rust-lifecycle | rust-team:rust-team |
|---------|--------------------------|---------------------|
| Communication | One-way (subagent → parent) | Peer-to-peer (SendMessage) |
| Agent visibility | Isolated contexts | Shared team, can message any peer |
| Task management | Parent manages all | Shared task list, agents self-coordinate |
| Context sharing | Handoff YAML files only | Messages + handoff files |
| Fix-review cycle | Parent relays feedback | Developer <-> reviewer direct DM |
| User interaction | Via parent only | Direct (Shift+Up/Down to any agent) |
| Prerequisite | None | CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1 |

## Code and Commit Ownership

- **Only developer modifies code** — all other agents analyze and report but never edit source files
- **Only teamlead commits** — no other agent runs git commit or gh pr

## Workflow

```
TeamCreate
    |
Spawn architect → WAIT for architect handoff
    |
Spawn developer (pass architect handoff) → WAIT for developer handoff
    |
Spawn tester, perf, security in parallel (pass architect + developer handoffs)
    → WAIT for ALL 3 validator handoffs
    |
Spawn reviewer (pass all 5 handoffs) → WAIT for reviewer handoff
    |
If issues: pass reviewer handoff to developer → WAIT for developer handoff
           pass developer handoff to reviewer → WAIT for reviewer handoff
           repeat until approved
    |
Teamlead commits → PR → shutdown → report
```

## Task Structure

| Task | Owner | BlockedBy | Description |
|------|-------|-----------|-------------|
| plan | architect | - | Architecture design |
| implement | developer | plan | Implementation |
| validate-tests | tester | implement | Test coverage |
| validate-perf | perf | implement | Performance analysis |
| validate-security | security | implement | Security audit |
| review | reviewer | validate-* | Code review |
| fix-issues | developer | review | Fix ALL review issues |
| re-review | reviewer | fix-issues | Verify fixes |
| commit | teamlead | re-review | Commit and PR |

## Workflow Templates

### New Feature
architect → developer → parallel(tester, perf, security) → reviewer → fix cycle → commit

### Bug Fix
debugger → developer → tester → reviewer → commit

### Refactoring
architect → developer → parallel(tester, perf) → reviewer → commit

### Security Audit
security → developer(fixes) → reviewer → commit

## Detailed Documentation

- [Team Workflow](references/team-workflow.md) — step-by-step execution guide
- [Communication Protocol](references/communication-protocol.md) — message types, communication matrix, spawn template
- [Result Aggregation](references/result-aggregation.md) — report format and aggregation sources

## Exit Criteria

Team development completes when:
- All tasks marked `completed`
- All teammates shut down via `shutdown_request`
- Team deleted via `TeamDelete`
- Summary saved to `.local/team-results/{team-name}-summary.md`
