# Team Workflow

Step-by-step execution guide for team-based Rust development.

## Step 1: Team Setup

```
TeamCreate(team_name: "rust-dev-{feature-slug}")
```

Create all tasks upfront with TaskCreate, then set dependencies with TaskUpdate.

### Task Structure

| Task | Owner | Blocks | Description |
|------|-------|--------|-------------|
| plan | architect | - | Architecture design |
| implement | developer | plan | Implementation |
| validate-tests | tester | implement | Test coverage |
| validate-perf | perf | implement | Performance analysis |
| validate-security | security | implement | Security audit |
| review | reviewer | validate-* | Code review |
| fix-issues | developer | review | Fix ALL review issues |
| re-review | reviewer | fix-issues | Verify fixes |
| commit | teamlead | re-review | Commit and PR |

### Dependency Setup

```
TaskUpdate(taskId: "implement", addBlockedBy: ["plan"])
TaskUpdate(taskId: "validate-tests", addBlockedBy: ["implement"])
TaskUpdate(taskId: "validate-perf", addBlockedBy: ["implement"])
TaskUpdate(taskId: "validate-security", addBlockedBy: ["implement"])
TaskUpdate(taskId: "review", addBlockedBy: ["validate-tests", "validate-perf", "validate-security"])
TaskUpdate(taskId: "fix-issues", addBlockedBy: ["review"])
TaskUpdate(taskId: "re-review", addBlockedBy: ["fix-issues"])
TaskUpdate(taskId: "commit", addBlockedBy: ["re-review"])
```

## Handoff Chain

Each agent has the `rust-agent-handoff` skill and creates a handoff YAML in `.local/handoff/`. When an agent completes, it reports the handoff file path to teamlead via SendMessage. Teamlead accumulates all received paths and passes them to the next agent in the spawn prompt. When a step is blocked by multiple parallel agents, the next agent receives all their handoff paths.

## Step 2: Spawn Architect

```
Task(
  subagent_type: "rust-agents:rust-architect",
  team_name: "rust-dev-{feature-slug}",
  name: "architect",
  prompt: "<team communication template>\n\nDesign architecture for: {feature-description}"
)
TaskUpdate(taskId: "plan", owner: "architect")
```

Architect completes and sends handoff path to teamlead (e.g. `.local/handoff/{timestamp}-architect.yaml`).

## Step 3: Spawn Developer

Teamlead passes the architect's handoff path to developer:

```
Task(
  subagent_type: "rust-agents:rust-developer",
  team_name: "rust-dev-{feature-slug}",
  name: "developer",
  prompt: "<team communication template>\n\nImplement based on architect's plan. Architect handoff: .local/handoff/{timestamp}-architect.yaml"
)
TaskUpdate(taskId: "implement", owner: "developer")
```

Developer completes and sends handoff path to teamlead (e.g. `.local/handoff/{timestamp}-developer.yaml`).

## Step 4: Parallel Validation

Teamlead passes accumulated handoff paths to each validator. Validators analyze and report findings but do NOT modify source files.

```
Task(
  subagent_type: "rust-agents:rust-testing-engineer",
  team_name: "rust-dev-{feature-slug}",
  name: "tester",
  prompt: "<team communication template>\n\nValidate test coverage. Report findings — do NOT edit source files.\n\nHandoffs:\n- Architect: .local/handoff/{timestamp}-architect.yaml\n- Developer: .local/handoff/{timestamp}-developer.yaml"
)

Task(
  subagent_type: "rust-agents:rust-performance-engineer",
  team_name: "rust-dev-{feature-slug}",
  name: "perf",
  prompt: "<team communication template>\n\nAnalyze performance. Report findings — do NOT edit source files.\n\nHandoffs:\n- Architect: .local/handoff/{timestamp}-architect.yaml\n- Developer: .local/handoff/{timestamp}-developer.yaml"
)

Task(
  subagent_type: "rust-agents:rust-security-maintenance",
  team_name: "rust-dev-{feature-slug}",
  name: "security",
  prompt: "<team communication template>\n\nSecurity audit. Report findings — do NOT edit source files.\n\nHandoffs:\n- Architect: .local/handoff/{timestamp}-architect.yaml\n- Developer: .local/handoff/{timestamp}-developer.yaml"
)
```

Each validator sends their handoff path to teamlead upon completion. Developer applies all code changes based on validator messages.

## Step 5: Code Review

Teamlead passes all accumulated handoff paths to reviewer:

```
Task(
  subagent_type: "rust-agents:rust-code-reviewer",
  team_name: "rust-dev-{feature-slug}",
  name: "reviewer",
  prompt: "<team communication template>\n\nReview implementation. Handoffs:\n- Architect: .local/handoff/{timestamp}-architect.yaml\n- Developer: .local/handoff/{timestamp}-developer.yaml\n- Testing: .local/handoff/{timestamp}-testing.yaml\n- Performance: .local/handoff/{timestamp}-performance.yaml\n- Security: .local/handoff/{timestamp}-security.yaml"
)
TaskUpdate(taskId: "review", owner: "reviewer")
```

Reviewer sends feedback to developer via SendMessage.

## Step 6: Fix-Review Cycle

Developer fixes issues based on reviewer feedback. Direct developer <-> reviewer communication via SendMessage until reviewer approves.

```
TaskUpdate(taskId: "fix-issues", owner: "developer")
# Developer fixes, then:
TaskUpdate(taskId: "re-review", owner: "reviewer")
```

Repeat if reviewer requests further changes.

## Step 7: Commit and PR

After re-review approved, **only teamlead** creates commit and PR. No other agent runs git or gh commands.

```
git add .
git commit -m "..."
gh pr create --title "..." --body "..."
TaskUpdate(taskId: "commit", status: "completed")
```

## Step 8: Shutdown and Report

```
# Shutdown all teammates
SendMessage(type: "shutdown_request", recipient: "architect")
SendMessage(type: "shutdown_request", recipient: "developer")
SendMessage(type: "shutdown_request", recipient: "tester")
SendMessage(type: "shutdown_request", recipient: "perf")
SendMessage(type: "shutdown_request", recipient: "security")
SendMessage(type: "shutdown_request", recipient: "reviewer")

# Wait for confirmations, then:
TeamDelete()

# Save report
Write report to .local/team-results/{team-name}-summary.md
```

## Spawn Prompt Template

When spawning each agent, include the team communication template from [communication-protocol.md](communication-protocol.md) with substituted values for `{team-name}` and `{agent-role}`.
