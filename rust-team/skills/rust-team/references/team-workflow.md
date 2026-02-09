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

## Execution Rules

1. Each agent creates a handoff YAML via `rust-agent-handoff` skill and sends its path to teamlead
2. Teamlead does NOT spawn the next agent until receiving the handoff path from the current one
3. Teamlead accumulates all handoff paths and passes the full list to each subsequent agent
4. When multiple parallel agents run, teamlead waits for ALL of them before proceeding

## Step 2: Spawn Architect

Teamlead spawns architect and **waits** for completion.

```
Task(
  subagent_type: "rust-agents:rust-architect",
  team_name: "rust-dev-{feature-slug}",
  name: "architect",
  prompt: "<team communication template>\n\nDesign architecture for: {feature-description}"
)
TaskUpdate(taskId: "plan", owner: "architect")
```

**WAIT**: do not proceed until architect sends message with handoff file path (e.g. `.local/handoff/{timestamp}-architect.yaml`). Mark task completed only after receiving the handoff path.

## Step 3: Spawn Developer

Only after receiving architect's handoff. Teamlead passes it in the spawn prompt.

```
Task(
  subagent_type: "rust-agents:rust-developer",
  team_name: "rust-dev-{feature-slug}",
  name: "developer",
  prompt: "<team communication template>\n\nImplement based on architect's plan.\n\nHandoffs:\n- Architect: .local/handoff/{timestamp}-architect.yaml"
)
TaskUpdate(taskId: "implement", owner: "developer")
```

**WAIT**: do not proceed until developer sends message with handoff file path (e.g. `.local/handoff/{timestamp}-developer.yaml`).

## Step 4: Parallel Validation

Only after receiving developer's handoff. Teamlead passes accumulated handoff paths (architect + developer) to all three validators. Validators analyze and report but do NOT modify source files.

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

**WAIT**: do not proceed until ALL THREE validators send their handoff file paths. Collect:
- `.local/handoff/{timestamp}-testing.yaml`
- `.local/handoff/{timestamp}-performance.yaml`
- `.local/handoff/{timestamp}-security.yaml`

## Step 5: Code Review

Only after receiving all three validator handoffs. Teamlead passes full accumulated list (architect + developer + 3 validators) to reviewer.

```
Task(
  subagent_type: "rust-agents:rust-code-reviewer",
  team_name: "rust-dev-{feature-slug}",
  name: "reviewer",
  prompt: "<team communication template>\n\nReview implementation.\n\nHandoffs:\n- Architect: .local/handoff/{timestamp}-architect.yaml\n- Developer: .local/handoff/{timestamp}-developer.yaml\n- Testing: .local/handoff/{timestamp}-testing.yaml\n- Performance: .local/handoff/{timestamp}-performance.yaml\n- Security: .local/handoff/{timestamp}-security.yaml"
)
TaskUpdate(taskId: "review", owner: "reviewer")
```

**WAIT**: do not proceed until reviewer sends handoff file path (e.g. `.local/handoff/{timestamp}-review.yaml`).

## Step 6: Fix-Review Cycle

Teamlead reads the reviewer's handoff to check the verdict.

**If reviewer's handoff contains issues (status: changes_requested)**:

1. Teamlead passes reviewer's handoff to developer:
   ```
   SendMessage(
     type: "message",
     recipient: "developer",
     content: "Fix all issues from review. Review handoff: .local/handoff/{timestamp}-review.yaml"
   )
   ```
   TaskUpdate(taskId: "fix-issues", owner: "developer")

2. **WAIT** for developer to complete fixes and send new handoff path

3. Teamlead passes developer's new handoff to reviewer for re-review:
   ```
   SendMessage(
     type: "message",
     recipient: "reviewer",
     content: "Re-review after fixes. Developer handoff: .local/handoff/{timestamp2}-developer.yaml"
   )
   ```
   TaskUpdate(taskId: "re-review", owner: "reviewer")

4. **WAIT** for reviewer to send new handoff path

5. Read reviewer's new handoff — if still has issues, repeat from step 1

**If reviewer's handoff is approved (status: approved)**: proceed to commit.

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
