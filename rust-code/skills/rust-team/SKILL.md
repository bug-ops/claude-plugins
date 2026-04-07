---
name: rust-team
description: "Orchestrate Rust development using agent teams with peer-to-peer communication. Use when: 'create rust team', 'start team development', 'launch agent team', 'team workflow', 'collaborative development'. Requires rust-agents plugin and CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1."
argument-hint: "[task-description]"
---

# Rust Team Orchestration

You are now acting as **team lead**. Coordinate specialist agents to implement the task below.

**Task**: $ARGUMENTS

> You do NOT implement code yourself. ALL implementation is delegated to specialist agents.
> If you find yourself about to write or edit a source file — STOP. Spawn the appropriate agent instead.
> The official docs warn: "Sometimes the lead starts implementing tasks itself instead of waiting for teammates." — this must never happen.

## Prerequisites

Before starting, verify:

1. `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` — in environment or `settings.json`
2. `rust-agents` plugin — must be installed
3. Git branch — if on `main`/`master`, create a feature branch first
4. Working directory clean — no uncommitted changes
5. `Cargo.toml` exists

## Step 1: Load Task Tools

```
ToolSearch("select:TaskCreate,TaskUpdate,TaskList,TaskGet,TeamCreate,TeamDelete,SendMessage")
```

## Step 2: Team Setup

```json
TeamCreate({
  "team_name": "rust-dev-{feature-slug}",
  "description": "Rust development: {task-summary}"
})
```

Create ALL tasks upfront, then set dependencies:

| Task | Owner | Description |
|------|-------|-------------|
| plan | architect | Architecture design |
| critique | critic | Adversarial critique of architecture **(MANDATORY)** |
| implement | developer | Implementation |
| validate-tests | tester | Test coverage |
| validate-perf | perf | Performance analysis |
| validate-security | security | Security audit |
| validate-critique | impl-critic | Adversarial critique of implementation **(MANDATORY)** |
| review | reviewer | Code review |
| fix-issues | developer | Fix ALL review issues |
| re-review | reviewer | Verify fixes |
| commit | teamlead | Commit and PR |

```
TaskUpdate(taskId: "critique",        addBlockedBy: ["plan"])
TaskUpdate(taskId: "implement",       addBlockedBy: ["critique"])
TaskUpdate(taskId: "validate-tests",  addBlockedBy: ["implement"])
TaskUpdate(taskId: "validate-perf",   addBlockedBy: ["implement"])
TaskUpdate(taskId: "validate-security", addBlockedBy: ["implement"])
TaskUpdate(taskId: "validate-critique", addBlockedBy: ["implement"])
TaskUpdate(taskId: "review",          addBlockedBy: ["validate-tests","validate-perf","validate-security","validate-critique"])
TaskUpdate(taskId: "fix-issues",      addBlockedBy: ["review"])
TaskUpdate(taskId: "re-review",       addBlockedBy: ["fix-issues"])
TaskUpdate(taskId: "commit",          addBlockedBy: ["re-review"])
```

## Team Communication Template

Include this block verbatim in every agent spawn prompt (substitute `{team-name}` and `{agent-role}`):

```
You are operating as a teammate in a Rust agent team.

## Team Context
- Team: {team-name}
- Your role: {agent-role}
- Team config: ~/.claude/teams/{team-name}/config.json

## Task Management
0. FIRST: call ToolSearch("select:TaskCreate,TaskUpdate,TaskList,TaskGet") to load task tool schemas
1. Check TaskList for your assigned task
2. TaskUpdate(status: "in_progress") when starting
3. TaskUpdate(status: "completed") when done

## Communication
- Send results to team lead: SendMessage(type: "message", to: "team-lead", content: "...", summary: "...")
- Message specific agents: SendMessage(type: "message", to: "{name}", content: "...", summary: "...")
- Never use broadcast for routine updates
- Include file paths and line numbers in messages
- Respond to shutdown_request with: SendMessage(type: "shutdown_response", to: "team-lead", approve: true)

## Code Ownership Rules
- Only developer edits source files. All other agents analyze and report only.
- Only team lead creates commits and PRs. No other agent runs git commit or gh pr.

## Handoff Protocol (MANDATORY)
BEFORE any other work: call Skill(skill: "rust-agents:rust-agent-handoff") and follow the protocol
(your suffix is listed in the agent identifiers table in the skill).

Before finishing: write handoff file and include inline frontmatter block + path in your message to team-lead.
```

## Step 3: Spawn Architect

```
Agent(
  description: "Architect for {feature}",
  subagent_type: "rust-agents:rust-architect",
  team_name: "rust-dev-{feature-slug}",
  name: "architect",
  prompt: "{team-communication-template}\n\nDesign architecture for: {feature-description}"
)
TaskUpdate(taskId: "plan", owner: "architect", status: "in_progress")
```

**WAIT** for architect's message containing handoff frontmatter + path. Then: `TaskUpdate(taskId: "plan", status: "completed")`.

## Step 4: Spawn Critic (MANDATORY)

```
Agent(
  description: "Critic for architecture review",
  subagent_type: "rust-agents:rust-critic",
  team_name: "rust-dev-{feature-slug}",
  name: "critic",
  prompt: "{team-communication-template}\n\nCritique the architecture. Report findings — do NOT write code.\n\nHandoffs:\n{accumulated-inline-frontmatters}"
)
TaskUpdate(taskId: "critique", owner: "critic", status: "in_progress")
```

**WAIT** for critic's message. Check verdict from inline frontmatter:
- `critical` or `significant` → pass critic handoff back to architect for redesign, re-run critic
- `approved` or `minor` → proceed to developer

## Step 5: Spawn Developer

```
Agent(
  description: "Developer for implementation",
  subagent_type: "rust-agents:rust-developer",
  team_name: "rust-dev-{feature-slug}",
  name: "developer",
  prompt: "{team-communication-template}\n\nImplement based on architect's plan.\n\nHandoffs:\n{accumulated-inline-frontmatters}"
)
TaskUpdate(taskId: "implement", owner: "developer", status: "in_progress")
```

**WAIT** for developer's handoff message.

## Step 6: Parallel Validation (spawn all 4 simultaneously)

```
Agent(subagent_type: "rust-agents:rust-testing-engineer",   team_name: "...", name: "tester",    prompt: "...\nValidate test coverage. Report findings — do NOT edit source files.\nHandoffs:\n{accumulated-inline-frontmatters}")
Agent(subagent_type: "rust-agents:rust-performance-engineer", team_name: "...", name: "perf",    prompt: "...\nAnalyze performance. Report findings — do NOT edit source files.\nHandoffs:\n{accumulated-inline-frontmatters}")
Agent(subagent_type: "rust-agents:rust-security-maintenance", team_name: "...", name: "security", prompt: "...\nSecurity audit. Report findings — do NOT edit source files.\nHandoffs:\n{accumulated-inline-frontmatters}")
Agent(subagent_type: "rust-agents:rust-critic",              team_name: "...", name: "impl-critic", prompt: "...\nCritique implementation: find logical gaps, missing edge cases. Report only — do NOT write code.\nHandoffs:\n{accumulated-inline-frontmatters}")
```

**WAIT for ALL FOUR** handoff messages before proceeding.

## Step 7: Code Review

```
Agent(
  description: "Reviewer for code review",
  subagent_type: "rust-agents:rust-code-reviewer",
  team_name: "rust-dev-{feature-slug}",
  name: "reviewer",
  prompt: "{team-communication-template}\n\nReview implementation.\n\nHandoffs:\n{all-accumulated-inline-frontmatters}"
)
```

**WAIT** for reviewer's handoff.

## Step 8: Fix-Review Cycle

Check `status` from reviewer's inline frontmatter (no file read needed):

**If `status: changes_requested`:**
```
SendMessage(type: "message", to: "developer",
  content: "Fix all issues from review.\n\nReviewer frontmatter:\n{inline-frontmatter}\nFile: {path}")
```
WAIT for developer's new handoff → pass to reviewer:
```
SendMessage(type: "message", to: "reviewer",
  content: "Re-review after fixes.\n\nDeveloper frontmatter:\n{inline-frontmatter}\nFile: {path}")
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

## Step 10: Shutdown and Report

Shut down each agent immediately after its task is complete and no further work will be delegated to it:
```
SendMessage(type: "shutdown_request", to: "{agent-name}", content: "Task complete")
```
Wait for `shutdown_response`, then shut down next idle agent. After all agents shut down:
```
TeamDelete()
```

Write report to `.local/team-results/{team-name}-summary.md`:
```markdown
# Team Development Report: {feature}

## Overview
- Team: {team-name}
- Started / Completed: {timestamps}
- Agents: architect, critic, developer, tester, perf, security, impl-critic, reviewer

## Architecture Decisions
{from architect handoff}

## Implementation Summary
{from developer handoff}

## Validation Results
### Testing — {from tester}
### Performance — {from perf}
### Security — {from security}

## Code Review
{from reviewer — verdict, issues, resolution}

## Files Changed
{git diff --stat output}
```

## Handoff Accumulation

Pass inline frontmatter to each subsequent agent — no file reads for routing:

```
After architect:   handoffs = [architect frontmatter + path]
After critic:      handoffs = [architect, critic]
After developer:   handoffs = [architect, critic, developer]
After validators:  handoffs = [architect, critic, developer, tester, perf, security, impl-critic]
Reviewer gets all 7.
```

## Workflow Templates

### New Feature
architect → critic → developer → parallel(tester, perf, security, impl-critic) → reviewer → fix cycle → commit

### Bug Fix
debugger → developer → tester → reviewer → commit

### Refactoring
architect → developer → parallel(tester, perf) → reviewer → commit

### Security Audit
security → developer(fixes) → reviewer → commit
