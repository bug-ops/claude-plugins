# Rust Team Plugin

[![Version](https://img.shields.io/badge/version-0.1.0-blue)](.)
[![License](https://img.shields.io/badge/license-MIT-green)](./LICENSE)

Agent team orchestration for Rust development using Claude Code experimental agent teams. Coordinates specialist agents from the `rust-agents` plugin with peer-to-peer communication.

## Prerequisites

- [Claude Code CLI](https://docs.claude.com/claude-code) installed
- [rust-agents plugin](../rust-code) installed: `claude plugin install rust-agents`
- Experimental agent teams enabled:
  ```bash
  export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1
  ```
  Or add to `settings.json`:
  ```json
  {
    "env": {
      "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
    }
  }
  ```
- Rust 1.85+ with rust-analyzer

## Installation

```bash
claude plugin install ./rust-team
```

## Usage

### Invoke via skill

```
/rust-team Implement user authentication with JWT tokens
```

### Invoke via agent

The `rust-teamlead` agent activates automatically when coordinating multiple agents for complex tasks.

## How It Works

1. User invokes `/rust-team:rust-team <task>` or teamlead activates
2. Teamlead creates a team via `TeamCreate`
3. Spawns specialist agents from `rust-agents` plugin as teammates
4. Agents communicate via `SendMessage` and coordinate via shared task list
5. User can interact with any teammate directly (Shift+Up/Down in terminal)
6. Teamlead aggregates results to `.local/team-results/`

### Workflow

```
TeamCreate -> Spawn architect -> architect plans
    |
Spawn developer -> developer implements
    |                    <-> (consults architect)
Spawn tester, perf, security (parallel)
    |          <-> (DM developer with findings)
Spawn reviewer -> reviews all
    |          <-> (DM developer with feedback)
Developer fixes -> reviewer re-reviews
    |
Teamlead commits -> PR -> shutdown -> report
```

## Comparison with rust-lifecycle

| Feature | rust-lifecycle | rust-team |
|---------|---------------|-----------|
| Communication | One-way (subagent to parent) | Peer-to-peer (SendMessage) |
| Agent visibility | Isolated contexts | Shared team |
| Task management | Parent manages all | Shared task list |
| Fix-review cycle | Parent relays feedback | Developer <-> reviewer direct |
| User interaction | Via parent only | Direct to any agent |
| Prerequisite | None | Agent teams experimental flag |

Use `rust-lifecycle` for standard workflows. Use `rust-team` when agents need to consult each other or when direct user-agent interaction is important.

## Agent

| Agent | Model | Description |
|-------|-------|-------------|
| rust-teamlead | opus | Team orchestrator. Creates teams, assigns tasks, coordinates specialists, aggregates results. |

## Specialist Agents (from rust-agents)

| Teammate Name | Agent | Role |
|---------------|-------|------|
| architect | rust-architect | Type-driven design, workspace architecture |
| developer | rust-developer | Idiomatic code, feature implementation |
| tester | rust-testing-engineer | Test coverage, nextest, criterion |
| perf | rust-performance-engineer | Profiling, benchmarks, optimization |
| security | rust-security-maintenance | Vulnerability scanning, dependency audit |
| reviewer | rust-code-reviewer | Quality assurance, standards compliance |
| cicd | rust-cicd-devops | GitHub Actions, cross-platform CI |
| debugger | rust-debugger | Error diagnosis, panic analysis |

## Workflow Templates

- **New feature**: architect -> developer -> parallel(tester, perf, security) -> reviewer -> fix cycle -> commit
- **Bug fix**: debugger -> developer -> tester -> reviewer -> commit
- **Refactoring**: architect -> developer -> parallel(tester, perf) -> reviewer -> commit
- **Security audit**: security -> developer(fixes) -> reviewer -> commit

## Skill Reference

| Skill | Description |
|-------|-------------|
| rust-team | Team orchestration entry point with workflow templates and communication protocol |

### Reference Files

- [team-workflow.md](skills/rust-team/references/team-workflow.md) — step-by-step execution
- [communication-protocol.md](skills/rust-team/references/communication-protocol.md) — message types and communication matrix
- [result-aggregation.md](skills/rust-team/references/result-aggregation.md) — report format

## Output

Team reports are saved to `.local/team-results/{team-name}-summary.md` with:
- Architecture decisions
- Implementation summary
- Validation results (testing, performance, security)
- Code review verdict
- Files changed
