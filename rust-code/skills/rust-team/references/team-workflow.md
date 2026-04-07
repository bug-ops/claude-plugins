# Team Workflow

Step-by-step execution guide for team-based Rust development.

## Step 1: Team Setup

Use the `TeamCreate` tool. Required parameter is `team_name` — do NOT use `name`, `agents`, or any other parameter names:

```json
{
  "team_name": "rust-dev-{feature-slug}",
  "description": "Rust development: {task-summary}"
}
```

First load task tool schemas, then create all tasks upfront with TaskCreate, then set dependencies with TaskUpdate:

```
ToolSearch("select:TaskCreate,TaskUpdate,TaskList,TaskGet")
```

### Task Structure

| Task | Owner | Blocks | Description |
|------|-------|--------|-------------|
| plan | architect | - | Architecture design |
| critique | critic | plan | **Adversarial critique of architecture (MANDATORY)** |
| implement | developer | critique | Implementation |
| validate-tests | tester | implement | Test coverage |
| validate-perf | perf | implement | Performance analysis |
| validate-security | security | implement | Security audit |
| validate-critique | impl-critic | implement | **Adversarial critique of implementation (MANDATORY)** |
| review | reviewer | validate-* | Code review |
| fix-issues | developer | review | Fix ALL review issues |
| re-review | reviewer | fix-issues | Verify fixes |
| commit | team-lead | re-review | Commit and PR |

### Dependency Setup

```
TaskUpdate(taskId: "critique", addBlockedBy: ["plan"])
TaskUpdate(taskId: "implement", addBlockedBy: ["critique"])
TaskUpdate(taskId: "validate-tests", addBlockedBy: ["implement"])
TaskUpdate(taskId: "validate-perf", addBlockedBy: ["implement"])
TaskUpdate(taskId: "validate-security", addBlockedBy: ["implement"])
TaskUpdate(taskId: "validate-critique", addBlockedBy: ["implement"])
TaskUpdate(taskId: "review", addBlockedBy: ["validate-tests", "validate-perf", "validate-security", "validate-critique"])
TaskUpdate(taskId: "fix-issues", addBlockedBy: ["review"])
TaskUpdate(taskId: "re-review", addBlockedBy: ["fix-issues"])
TaskUpdate(taskId: "commit", addBlockedBy: ["re-review"])
```

## Execution Rules

1. Each agent creates a handoff file (`.md`) via `rust-agent-handoff` skill and sends its **inline frontmatter block + path** to team-lead in the completion message
2. Teamlead does NOT spawn the next agent until receiving the inline frontmatter block from the current one — routing decisions are made from frontmatter, no file reads
3. Teamlead accumulates all inline frontmatter blocks + paths and passes them to each subsequent agent
4. When multiple parallel agents run, team-lead waits for ALL of them before proceeding
5. **Shutdown agents immediately after their task is complete and they are no longer needed** — do not keep idle agents alive until the end. Send `shutdown_request` as soon as the agent's handoff is received and no further work will be delegated to it. This conserves resources and keeps the active team minimal.

## Step 2: Spawn Architect

Teamlead spawns architect and **waits** for completion.

```
Agent(
  description: "Architect for {feature}",
  subagent_type: "rust-agents:rust-architect",
  team_name: "rust-dev-{feature-slug}",
  name: "architect",
  prompt: "<team communication template>\n\nBEFORE any other work: call `Skill(skill: "rust-agents:rust-agent-handoff")` and follow the protocol.\n\nDesign architecture for: {feature-description}"
)
TaskUpdate(taskId: "plan", owner: "architect")
```

**WAIT**: do not proceed until architect sends message with handoff file path (e.g. `.local/handoff/{timestamp}-architect.md`). Mark task completed only after receiving the handoff path.

## Step 2.5: Spawn Critic (MANDATORY)

Critic runs after every architect phase. Skip only for trivial single-file bug fixes.

```
Agent(
  description: "Critic for architecture review",
  subagent_type: "rust-agents:rust-critic",
  team_name: "rust-dev-{feature-slug}",
  name: "critic",
  prompt: "<team communication template>\n\nBEFORE any other work: call `Skill(skill: "rust-agents:rust-agent-handoff")` and follow the protocol.\n\nCritique the architecture. Report findings — do NOT write code.\n\nHandoffs:\n- Architect: .local/handoff/{timestamp}-architect.md"
)
TaskUpdate(taskId: "critique", owner: "critic")
```

**WAIT**: do not proceed until critic sends message with handoff file path (e.g. `.local/handoff/{timestamp}-critic.md`).

If critic's verdict is `critical` or `significant`: pass critic's handoff back to architect for redesign, then re-run critic. Once verdict is `approved` or `minor`, proceed to developer.

## Step 3: Spawn Developer

Only after receiving architect's handoff (and critic's handoff if critic was used). Teamlead passes all accumulated handoffs in the spawn prompt.

```
Agent(
  description: "Developer for implementation",
  subagent_type: "rust-agents:rust-developer",
  team_name: "rust-dev-{feature-slug}",
  name: "developer",
  prompt: "<team communication template>\n\nBEFORE any other work: call `Skill(skill: "rust-agents:rust-agent-handoff")` and follow the protocol.\n\nImplement based on architect's plan.\n\nHandoffs:\n- Architect: .local/handoff/{timestamp}-architect.md"
)
TaskUpdate(taskId: "implement", owner: "developer")
```

**WAIT**: do not proceed until developer sends message with handoff file path (e.g. `.local/handoff/{timestamp}-developer.md`).

## Step 4: Parallel Validation

Only after receiving developer's handoff. Teamlead passes accumulated handoff paths (architect + critic + developer) to all four validators. Validators analyze and report but do NOT modify source files.

```
Agent(
  description: "Tester for validation",
  subagent_type: "rust-agents:rust-testing-engineer",
  team_name: "rust-dev-{feature-slug}",
  name: "tester",
  prompt: "<team communication template>\n\nBEFORE any other work: call `Skill(skill: "rust-agents:rust-agent-handoff")` and follow the protocol.\n\nValidate test coverage. Report findings — do NOT edit source files.\n\nHandoffs:\n- Architect: .local/handoff/{timestamp}-architect.md\n- Developer: .local/handoff/{timestamp}-developer.md"
)

Agent(
  description: "Perf for validation",
  subagent_type: "rust-agents:rust-performance-engineer",
  team_name: "rust-dev-{feature-slug}",
  name: "perf",
  prompt: "<team communication template>\n\nBEFORE any other work: call `Skill(skill: "rust-agents:rust-agent-handoff")` and follow the protocol.\n\nAnalyze performance. Report findings — do NOT edit source files.\n\nHandoffs:\n- Architect: .local/handoff/{timestamp}-architect.md\n- Developer: .local/handoff/{timestamp}-developer.md"
)

Agent(
  description: "Security for validation",
  subagent_type: "rust-agents:rust-security-maintenance",
  team_name: "rust-dev-{feature-slug}",
  name: "security",
  prompt: "<team communication template>\n\nBEFORE any other work: call `Skill(skill: "rust-agents:rust-agent-handoff")` and follow the protocol.\n\nSecurity audit. Report findings — do NOT edit source files.\n\nHandoffs:\n- Architect: .local/handoff/{timestamp}-architect.md\n- Developer: .local/handoff/{timestamp}-developer.md"
)

Agent(
  description: "Critic for implementation review",
  subagent_type: "rust-agents:rust-critic",
  team_name: "rust-dev-{feature-slug}",
  name: "impl-critic",
  prompt: "<team communication template>\n\nBEFORE any other work: call `Skill(skill: "rust-agents:rust-agent-handoff")` and follow the protocol.\n\nCritique developer's implementation: find logical gaps, missing edge cases, and design issues introduced during coding. Report findings — do NOT write code.\n\nHandoffs:\n- Architect: .local/handoff/{timestamp}-architect.md\n- Developer: .local/handoff/{timestamp}-developer.md"
)
TaskUpdate(taskId: "validate-critique", owner: "impl-critic")
```

**WAIT**: do not proceed until ALL FOUR validators send their handoff file paths. Collect:
- `.local/handoff/{timestamp}-testing.md`
- `.local/handoff/{timestamp}-performance.md`
- `.local/handoff/{timestamp}-security.md`
- `.local/handoff/{timestamp}-critic.md`

## Step 5: Code Review

Only after receiving all four validator handoffs. Teamlead passes full accumulated list (architect + critic + developer + 4 validators) to reviewer.

```
Agent(
  description: "Reviewer for code review",
  subagent_type: "rust-agents:rust-code-reviewer",
  team_name: "rust-dev-{feature-slug}",
  name: "reviewer",
  prompt: "<team communication template>\n\nBEFORE any other work: call `Skill(skill: "rust-agents:rust-agent-handoff")` and follow the protocol.\n\nReview implementation.\n\nHandoffs:\n- Architect: .local/handoff/{timestamp}-architect.md\n- Critic (architecture): .local/handoff/{timestamp}-critic.md\n- Developer: .local/handoff/{timestamp}-developer.md\n- Testing: .local/handoff/{timestamp}-testing.md\n- Performance: .local/handoff/{timestamp}-performance.md\n- Security: .local/handoff/{timestamp}-security.md\n- Critic (implementation): .local/handoff/{timestamp2}-critic.md"
)
TaskUpdate(taskId: "review", owner: "reviewer")
```

**WAIT**: do not proceed until reviewer sends handoff file path (e.g. `.local/handoff/{timestamp}-review.md`).

## Step 6: Fix-Review Cycle

Teamlead checks `status` from the **inline frontmatter block** in the reviewer's message — no file read needed.

**If `status: changes_requested`**:

1. Teamlead passes reviewer's frontmatter + path to developer:
   ```
   SendMessage(
     type: "message",
     recipient: "developer",
     content: "Fix all issues from review.\n\nReviewer frontmatter:\n{inline frontmatter block from reviewer's message}\nFile: .local/handoff/{timestamp}-review.md",
     summary: "Fix review issues"
   )
   ```
   TaskUpdate(taskId: "fix-issues", owner: "developer")

2. **WAIT** for developer to send new inline frontmatter + path

3. Teamlead passes developer's frontmatter + path to reviewer for re-review:
   ```
   SendMessage(
     type: "message",
     recipient: "reviewer",
     content: "Re-review after fixes.\n\nDeveloper frontmatter:\n{inline frontmatter block from developer's message}\nFile: .local/handoff/{timestamp2}-developer.md",
     summary: "Re-review after fixes"
   )
   ```
   TaskUpdate(taskId: "re-review", owner: "reviewer")

4. **WAIT** for reviewer to send new inline frontmatter + path

5. Check `status` from reviewer's frontmatter — if still `changes_requested`, repeat from step 1

**If `status: approved`**: proceed to commit.

## Step 7: Commit and PR

After re-review approved, **only team-lead** creates commit and PR. No other agent runs git or gh commands.

```
git add .
git commit -m "..."
gh pr create --title "..." --body "..."
TaskUpdate(taskId: "commit", status: "completed")
```

## Step 8: Shutdown and Report

```
# Shutdown all remaining active teammates
SendMessage(type: "shutdown_request", recipient: "{agent-name}", content: "Task complete, shutting down")

# Wait for confirmations, then:
TeamDelete()

# Save report
Write report to .local/team-results/{team-name}-summary.md
```

## Spawn Prompt Template

When spawning each agent, include the team communication template from [communication-protocol.md](communication-protocol.md) with substituted values for `{team-name}` and `{agent-role}`.
