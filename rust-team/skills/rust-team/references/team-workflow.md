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

Wait for architect to complete. Architect sends plan to teamlead via SendMessage.

## Step 3: Spawn Developer

After architect completes:

```
Task(
  subagent_type: "rust-agents:rust-developer",
  team_name: "rust-dev-{feature-slug}",
  name: "developer",
  prompt: "<team communication template>\n\nImplement based on architect's plan. Architect handoff: {handoff-path-or-summary}"
)
TaskUpdate(taskId: "implement", owner: "developer")
```

Developer can message architect directly for clarifications via SendMessage.

## Step 4: Parallel Validation

After developer completes, spawn validators in parallel. Validators analyze and report findings but do NOT modify source files — they message developer with actionable feedback.

```
Task(
  subagent_type: "rust-agents:rust-testing-engineer",
  team_name: "rust-dev-{feature-slug}",
  name: "tester",
  prompt: "<team communication template>\n\nValidate test coverage. Report findings — do NOT edit source files. Developer handoff: {handoff-path-or-summary}"
)

Task(
  subagent_type: "rust-agents:rust-performance-engineer",
  team_name: "rust-dev-{feature-slug}",
  name: "perf",
  prompt: "<team communication template>\n\nAnalyze performance. Report findings — do NOT edit source files. Developer handoff: {handoff-path-or-summary}"
)

Task(
  subagent_type: "rust-agents:rust-security-maintenance",
  team_name: "rust-dev-{feature-slug}",
  name: "security",
  prompt: "<team communication template>\n\nSecurity audit. Report findings — do NOT edit source files. Developer handoff: {handoff-path-or-summary}"
)
```

Validators DM developer with findings. Developer applies all code changes.

## Step 5: Code Review

After all validators complete:

```
Task(
  subagent_type: "rust-agents:rust-code-reviewer",
  team_name: "rust-dev-{feature-slug}",
  name: "reviewer",
  prompt: "<team communication template>\n\nReview implementation. Validation results: {tester-summary}, {perf-summary}, {security-summary}"
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
