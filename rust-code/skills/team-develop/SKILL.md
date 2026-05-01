---
name: team-develop
description: "Orchestrate Rust development using agent teams with peer-to-peer communication. Use when: 'create rust team', 'start team development', 'launch agent team', 'team workflow', 'collaborative development'. Requires rust-agents plugin and CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1."
argument-hint: "[task-description]"
---

# Team Develop Orchestration

You act as **team lead**. Coordinate specialist agents to implement the task.

**Task**: $ARGUMENTS

> You do NOT implement code yourself. ALL implementation is delegated. If you are about to write or edit a source file — STOP. Spawn the appropriate agent.
> The lead drift warning from official docs: "Sometimes the lead starts implementing tasks itself instead of waiting for teammates." This must never happen.

## Prerequisites

1. `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` in environment or `settings.json`
2. `rust-agents` plugin installed
3. Not on `main`/`master` (create a feature branch first)
4. Working directory clean
5. `Cargo.toml` exists

> For complex features: run `/rust-agents:sdd` **before** team-develop to produce a spec in `.local/specs/`. Architect and developer pick it up automatically. team-develop does not run SDD itself.

## Step 1: Load Tools

```
ToolSearch("select:TaskCreate,TaskUpdate,TaskList,TaskGet,TeamCreate,TeamDelete,SendMessage")
```

## Step 2: Team Setup

```json
TeamCreate({"team_name": "rust-dev-{feature-slug}", "description": "Rust dev: {task-summary}"})
```

Create all tasks upfront and set dependencies:

| Task | Owner | Description |
|------|-------|-------------|
| plan | architect | Architecture design |
| critique | critic | **Adversarial critique of architecture (MANDATORY)** |
| implement | developer | Implementation |
| validate-tests | tester | Test coverage |
| validate-perf | perf | Performance analysis |
| validate-security | security | Security audit |
| validate-critique | impl-critic | **Adversarial critique of implementation (MANDATORY)** |
| review | reviewer | Code review |
| fix-issues | developer | Fix all review issues |
| re-review | reviewer | Verify fixes |
| commit | teamlead | Commit and PR |

```
TaskUpdate(taskId: "critique",          addBlockedBy: ["plan"])
TaskUpdate(taskId: "implement",         addBlockedBy: ["critique"])
TaskUpdate(taskId: "validate-tests",    addBlockedBy: ["implement"])
TaskUpdate(taskId: "validate-perf",     addBlockedBy: ["implement"])
TaskUpdate(taskId: "validate-security", addBlockedBy: ["implement"])
TaskUpdate(taskId: "validate-critique", addBlockedBy: ["implement"])
TaskUpdate(taskId: "review",            addBlockedBy: ["validate-tests","validate-perf","validate-security","validate-critique"])
TaskUpdate(taskId: "fix-issues",        addBlockedBy: ["review"])
TaskUpdate(taskId: "re-review",         addBlockedBy: ["fix-issues"])
TaskUpdate(taskId: "commit",            addBlockedBy: ["re-review"])
```

## Team Communication Template

Substitute `{team-name}` and `{agent-role}`, then include verbatim in every spawn prompt:

```
You are a teammate in team `{team-name}`, role `{agent-role}`.

Tasks: ToolSearch("select:TaskCreate,TaskUpdate,TaskList,TaskGet"); update your task to in_progress on start, completed on finish.

Communication: SendMessage(type: "message", to: "team-lead", content: "...", summary: "..."). Respond to shutdown_request with SendMessage(type: "shutdown_response", to: "team-lead", approve: true).

Code ownership: only developer edits source. Only team-lead commits.

Handoff (MANDATORY): BEFORE any other work, call Skill(skill: "rust-agents:rust-agent-handoff"). Before messaging team-lead, write your handoff file and include inline frontmatter + path in the message.
```

## Step 3: Architect

```
Agent(subagent_type: "rust-agents:rust-architect", name: "architect", team_name: "rust-dev-{slug}",
  prompt: "{template}\n\nDesign architecture for: {feature-description}")
TaskUpdate(taskId: "plan", owner: "architect", status: "in_progress")
```

WAIT for handoff frontmatter + path. `TaskUpdate(taskId: "plan", status: "completed")`.

## Step 4: Critic (MANDATORY)

```
Agent(subagent_type: "rust-agents:rust-critic", name: "critic", team_name: "rust-dev-{slug}",
  prompt: "{template}\n\nCritique the architecture. Report findings — do NOT write code.\n\nHandoffs:\n{accumulated frontmatters}")
TaskUpdate(taskId: "critique", owner: "critic", status: "in_progress")
```

WAIT for critic. Check verdict from inline frontmatter:
- `critical` or `significant` → pass critic handoff back to architect for redesign, re-run critic
- `approved` or `minor` → proceed to developer

## Step 5: Developer(s)

Check `.local/specs/` for an existing spec, then analyze the architect's plan: **can implementation be split into independent subtasks?**

Subtasks are independent when ALL hold: separate modules/crates, no shared mutable state, no cross-task type dependencies, can be tested in isolation.

**Independent** — spawn one developer per subtask:

```
TaskCreate(id: "implement-{a}", description: "Implement {a}")
TaskCreate(id: "implement-{b}", description: "Implement {b}")
TaskUpdate(taskId: "implement-{a}", addBlockedBy: ["critique"])
TaskUpdate(taskId: "implement-{b}", addBlockedBy: ["critique"])
// update validate-* to block on all implement-* tasks

Agent(subagent_type: "rust-agents:rust-developer", name: "developer-a", team_name: "...",
  prompt: "{template}\n\nImplement only: {a description}. Do NOT touch modules owned by parallel developers.\n\nHandoffs:\n{accumulated frontmatters}")
Agent(subagent_type: "rust-agents:rust-developer", name: "developer-b", team_name: "...",
  prompt: "{template}\n\nImplement only: {b description}. Do NOT touch modules owned by parallel developers.\n\nHandoffs:\n{accumulated frontmatters}")
```

WAIT for ALL parallel developers before validation. Accumulate all handoffs.

**Dependent** — single developer in sequence:

```
Agent(subagent_type: "rust-agents:rust-developer", name: "developer", team_name: "...",
  prompt: "{template}\n\nImplement based on architect's plan.\n\nHandoffs:\n{accumulated frontmatters}")
TaskUpdate(taskId: "implement", owner: "developer", status: "in_progress")
```

WAIT for developer's handoff.

## Step 6: Parallel Validation (spawn all 4 simultaneously)

```
Agent(subagent_type: "rust-agents:rust-testing-engineer",     name: "tester",      team_name: "...",
  prompt: "{template}\n\nValidate test coverage. Report findings — do NOT edit source.\nHandoffs: {accumulated}")
Agent(subagent_type: "rust-agents:rust-performance-engineer", name: "perf",        team_name: "...",
  prompt: "{template}\n\nAnalyze performance. Report findings — do NOT edit source.\nHandoffs: {accumulated}")
Agent(subagent_type: "rust-agents:rust-security-maintenance", name: "security",    team_name: "...",
  prompt: "{template}\n\nSecurity audit. Report findings — do NOT edit source.\nHandoffs: {accumulated}")
Agent(subagent_type: "rust-agents:rust-critic",               name: "impl-critic", team_name: "...",
  prompt: "{template}\n\nCritique implementation: logical gaps, missing edge cases. Report only — do NOT write code.\nHandoffs: {accumulated}")
```

WAIT for ALL FOUR handoff messages.

## Step 7: Code Review

```
Agent(subagent_type: "rust-agents:rust-code-reviewer", name: "reviewer", team_name: "...",
  prompt: "{template}\n\nReview implementation.\n\nHandoffs:\n{all accumulated frontmatters}")
```

WAIT for reviewer's handoff.

## Step 8: Fix-Review Cycle

Check `status` from reviewer's inline frontmatter (no file read needed):

If `status: changes_requested`:

```
SendMessage(type: "message", to: "developer",
  content: "Fix all issues from review.\n\nReviewer frontmatter:\n{inline}\nFile: {path}")
```

WAIT for developer's new handoff. Pass to reviewer:

```
SendMessage(type: "message", to: "reviewer",
  content: "Re-review after fixes.\n\nDeveloper frontmatter:\n{inline}\nFile: {path}")
```

WAIT for reviewer. Repeat until `status: approved`.

## Step 9: Commit and PR

Only after reviewer approves. Read `.claude/rules/commits-and-issues.md` if it exists.

```bash
git add -p   # or specific files
git commit -m "$(cat <<'EOF'
type(scope): description

Body if needed.
EOF
)"
gh pr create --title "..." --body "..."
```

## Step 10: Shutdown

Shut down each agent immediately after its task is complete:

```
SendMessage(type: "shutdown_request", to: "{agent-name}", content: "Task complete")
```

Wait for `shutdown_response`, then:

```
TeamDelete()
```

## Handoff Accumulation

Pass inline frontmatter to each subsequent agent — no file reads for routing:

```
After architect:    [architect]
After critic:       [architect, critic]
After developer(s): [architect, critic, developer-a, developer-b, ...]
After validators:   [architect, critic, developer(s), tester, perf, security, impl-critic]
Reviewer gets all of the above.
```

When parallel developers are used, accumulate all their handoffs before spawning any validator.

## Workflow Templates

- **New Feature**: architect → critic → developer → parallel(tester, perf, security, impl-critic) → reviewer → fix cycle → commit
- **Bug Fix**: debugger → developer → tester → reviewer → commit
- **Refactoring**: architect → critic → developer → parallel(tester, perf) → reviewer → commit
- **Security Audit**: security → developer(fixes) → reviewer → commit
