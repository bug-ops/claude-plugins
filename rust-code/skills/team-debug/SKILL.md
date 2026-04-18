---
name: team-debug
description: "Debug Rust issues using a multi-agent investigation team. Provide symptom description as input. Workflow: debugger investigates root cause → parallel review by architect, critic, security, performance → code reviewer accumulates findings → results presented to user for issue/epic creation or handoff to team-develop. Requires rust-agents plugin and CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1."
argument-hint: "[symptom-description]"
---

# Team Debug Orchestration

You are now acting as **team lead** for a debugging investigation. Coordinate specialist agents to diagnose and fix the issue described below.

**Symptoms**: $ARGUMENTS

> You do NOT investigate or fix code yourself. ALL analysis and fixes are delegated to specialist agents.
> If you find yourself about to read source files or edit code — STOP. Spawn the appropriate agent instead.

## Prerequisites

Before starting, verify:

1. `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` — in environment or `settings.json`
2. `rust-agents` plugin — must be installed
3. Git branch — if on `main`/`master`, create a feature/fix branch first
4. `Cargo.toml` exists

## Step 1: Load Task Tools

```
ToolSearch("select:TaskCreate,TaskUpdate,TaskList,TaskGet,TeamCreate,TeamDelete,SendMessage")
```

## Step 2: Team Setup

```json
TeamCreate({
  "team_name": "rust-debug-{issue-slug}",
  "description": "Debug investigation: {symptom-summary}"
})
```

Create ALL tasks upfront, then set dependencies:

| Task | Owner | Description |
|------|-------|-------------|
| investigate | debugger | Root cause analysis |
| review-arch | architect | Architectural review of findings |
| review-critique | critic | Adversarial critique of findings |
| review-security | security | Security implications review |
| review-perf | perf | Performance implications review (conditional) |
| consolidate | reviewer | Accumulate all findings, produce unified report |

```
TaskUpdate(taskId: "review-arch",     addBlockedBy: ["investigate"])
TaskUpdate(taskId: "review-critique",  addBlockedBy: ["investigate"])
TaskUpdate(taskId: "review-security",  addBlockedBy: ["investigate"])
TaskUpdate(taskId: "review-perf",      addBlockedBy: ["investigate"])
TaskUpdate(taskId: "consolidate",      addBlockedBy: ["review-arch","review-critique","review-security","review-perf"])
```

> **Performance review**: If the symptoms include any of the following, keep `review-perf` in the task graph:
> latency, slow, timeout, memory leak, CPU spike, throughput, regression, benchmark failure.
> Otherwise, mark `review-perf` as `completed` immediately after creation (skip the agent spawn).

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
- Only debugger edits source files. All other agents analyze and report only.
- Only team lead commits. No other agent runs git commit or gh pr.

## Handoff Protocol (MANDATORY)
BEFORE any other work: call Skill(skill: "rust-agents:rust-agent-handoff") and follow the protocol
(your suffix is listed in the agent identifiers table in the skill).

Before sending any message to team-lead: write your handoff file and include the inline frontmatter block + file path in your message content.
```

## Step 3: Spawn Debugger (Investigation Phase)

```
Agent(
  description: "Debugger — root cause investigation",
  subagent_type: "rust-agents:rust-debugger",
  team_name: "rust-debug-{issue-slug}",
  name: "debugger",
  prompt: "{team-communication-template}\n\nInvestigate the following symptoms and identify root cause(s). Analyze stack traces, logs, code paths, and reproduction steps as available. Report findings — do NOT apply fixes yet.\n\nSymptoms:\n{symptom-description}"
)
TaskUpdate(taskId: "investigate", owner: "debugger", status: "in_progress")
```

**WAIT** for debugger's message containing inline handoff frontmatter + path. Then: `TaskUpdate(taskId: "investigate", status: "completed")`.

The handoff must contain:
- Root cause hypothesis
- Affected files and line ranges
- Reproduction path
- Severity assessment
- Whether performance degradation is involved (to confirm `review-perf` inclusion)

After receiving debugger's handoff, **re-evaluate `review-perf`**: if the debugger's report confirms no performance angle, mark `review-perf` as `completed` and skip perf agent spawn.

## Step 4: Parallel Review (spawn simultaneously)

Spawn all applicable reviewers at the same time. Pass debugger's inline frontmatter + path to each.

```
Agent(
  description: "Architect — review debug findings",
  subagent_type: "rust-agents:rust-architect",
  team_name: "rust-debug-{issue-slug}",
  name: "arch-reviewer",
  prompt: "{team-communication-template}\n\nReview the debugger's root cause findings from an architectural perspective. Identify whether the bug is a symptom of a deeper design issue or a local defect. Report only — do NOT write code.\n\nHandoffs:\n- Debugger: .local/handoff/{timestamp}-debugger.md"
)
TaskUpdate(taskId: "review-arch", owner: "arch-reviewer", status: "in_progress")

Agent(
  description: "Critic — adversarial review of debug findings",
  subagent_type: "rust-agents:rust-critic",
  team_name: "rust-debug-{issue-slug}",
  name: "critic",
  prompt: "{team-communication-template}\n\nAdversarially critique the debugger's root cause hypothesis. Challenge assumptions, find alternative explanations, identify missing edge cases. Report only — do NOT write code.\n\nHandoffs:\n- Debugger: .local/handoff/{timestamp}-debugger.md"
)
TaskUpdate(taskId: "review-critique", owner: "critic", status: "in_progress")

Agent(
  description: "Security — review security implications",
  subagent_type: "rust-agents:rust-security-maintenance",
  team_name: "rust-debug-{issue-slug}",
  name: "security",
  prompt: "{team-communication-template}\n\nReview the debugger's findings for security implications: data exposure, privilege escalation, memory safety violations, dependency vulnerabilities. Report only — do NOT write code.\n\nHandoffs:\n- Debugger: .local/handoff/{timestamp}-debugger.md"
)
TaskUpdate(taskId: "review-security", owner: "security", status: "in_progress")
```

**If `review-perf` is active** (performance symptoms confirmed):

```
Agent(
  description: "Perf — review performance implications",
  subagent_type: "rust-agents:rust-performance-engineer",
  team_name: "rust-debug-{issue-slug}",
  name: "perf",
  prompt: "{team-communication-template}\n\nReview the debugger's findings for performance implications: hot paths, allocations, async bottlenecks, regression vectors. Report only — do NOT edit source files.\n\nHandoffs:\n- Debugger: .local/handoff/{timestamp}-debugger.md"
)
TaskUpdate(taskId: "review-perf", owner: "perf", status: "in_progress")
```

**WAIT for ALL active parallel reviewers** before proceeding. Collect all inline handoff frontmatters + paths.

## Step 5: Consolidation Review

Pass ALL accumulated handoffs (debugger + all reviewers) to code reviewer.

```
Agent(
  description: "Reviewer — consolidate all findings",
  subagent_type: "rust-agents:rust-code-reviewer",
  team_name: "rust-debug-{issue-slug}",
  name: "reviewer",
  prompt: "{team-communication-template}\n\nConsolidate findings from the debugger and all specialist reviewers. Produce a unified fix scope:\n- Confirm or revise root cause based on critic's challenges\n- Prioritize fixes: critical (must fix now) vs. follow-up (file as issues)\n- List exact files and line ranges that need changes\n- Flag security findings requiring immediate attention\n- Note architectural issues that warrant a separate team-develop cycle\n- Conclude with verdict: 'fixes_required' or 'no_fixes_needed'\n\nHandoffs:\n- Debugger: .local/handoff/{timestamp}-debugger.md\n- Architect review: .local/handoff/{timestamp}-architect.md\n- Critic: .local/handoff/{timestamp}-critic.md\n- Security: .local/handoff/{timestamp}-security.md\n- Performance: .local/handoff/{timestamp}-performance.md  (if applicable)"
)
TaskUpdate(taskId: "consolidate", owner: "reviewer", status: "in_progress")
```

**WAIT** for reviewer's handoff. Then proceed directly to Step 6.

## Step 6: Present Results to User

After consolidation completes, compile and present a structured report to the user. Do NOT apply fixes, create issues, or commit automatically — the user decides next steps.

```markdown
## Debug Investigation Complete

### Root Cause
{root cause from debugger, refined by critic and architect}

### Critical Fixes Required
{items the reviewer flagged as must-fix, with files and line ranges}

### Follow-up Issues
{architectural concerns, security hardening, performance improvements — not critical to fix now}

### Recommendation
- Fix critical items now via `/team-develop` or manual patch
- Create GitHub issue for each follow-up item
- Group into an epic if 3+ related issues exist
```

Ask the user — choose one action or a combination:
1. **Create GitHub issues** for the follow-up items (and optionally an epic if 3+)?
2. **Hand off to `/team-develop`** to implement the critical fixes now?
3. **Both** — file issues for follow-up, then start `team-develop` for critical fixes?

Do nothing until the user explicitly responds.

## Step 7: Shutdown

Shut down each agent immediately after its task is complete and no further work will be delegated:

```
SendMessage(type: "shutdown_request", to: "{agent-name}", content: "Task complete")
```

Wait for `shutdown_response`, then shut down next idle agent. After all agents shut down:

```
TeamDelete()
```

## Handoff Accumulation

Pass inline frontmatter to each subsequent agent — no file reads for routing:

```
After debugger:      handoffs = [debugger frontmatter + path]
After parallel:      handoffs = [debugger, arch-reviewer, critic, security, (perf)]
Reviewer gets all of the above.
```

## References

- [team-workflow.md](references/team-workflow.md): Detailed step-by-step execution guide
- [communication-protocol.md](references/communication-protocol.md): Message templates, peer-to-peer patterns
