---
name: team-debug
description: "Debug Rust issues using a multi-agent investigation team. Provide symptom description as input. Workflow: debugger + live-tester (conditional) investigate root cause in parallel → security review always, architect and perf reviews conditionally → code reviewer consolidates findings → results presented to user. Requires rust-agents plugin and CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1."
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
| investigate | debugger | Root cause analysis via static code reasoning |
| live-test | live-tester | Root cause analysis via live binary execution (conditional) |
| review-arch | architect | Architectural review of findings (conditional) |
| review-security | security | Security implications review |
| review-perf | perf | Performance implications review (conditional) |
| consolidate | reviewer | Accumulate all findings, produce unified report |

```
TaskUpdate(taskId: "review-arch",     addBlockedBy: ["investigate","live-test"])
TaskUpdate(taskId: "review-security",  addBlockedBy: ["investigate","live-test"])
TaskUpdate(taskId: "review-perf",      addBlockedBy: ["investigate","live-test"])
TaskUpdate(taskId: "consolidate",      addBlockedBy: ["review-arch","review-security","review-perf"])
```

> **Live testing**: If symptoms include runtime behavior that cannot be determined from static analysis — panics, crashes, wrong output, flaky tests, integration failures, async deadlocks — keep `live-test` in the task graph and spawn `rust-live-tester` in parallel with `rust-debugger`.
> If symptoms are purely compile-time (build errors, type mismatches, linker failures), mark `live-test` as `completed` immediately after creation (skip the agent spawn), and update dependencies: `TaskUpdate(taskId: "review-arch", removeBlockedBy: ["live-test"])` etc.

> **Architectural review**: Spawn architect if **either** condition is true:
> 1. Symptoms mention: recurring, systemic, regression after refactor, multiple callers affected, wrong abstraction, design flaw
> 2. After investigation phase: debugger or live-tester handoff explicitly flags an architectural concern
> If neither condition applies before investigation, keep `review-arch` pending until handoffs arrive, then decide. If skipping, mark `review-arch` as `completed` and remove it from consolidate's blockers: `TaskUpdate(taskId: "consolidate", removeBlockedBy: ["review-arch"])`.

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

## Step 3: Investigation Phase (parallel when live testing applies)

Spawn `rust-debugger` unconditionally. If live testing applies (see condition above), spawn `rust-live-tester` at the same time — do NOT wait for one before spawning the other.

```
Agent(
  description: "Debugger — root cause investigation via static analysis",
  subagent_type: "rust-agents:rust-debugger",
  team_name: "rust-debug-{issue-slug}",
  name: "debugger",
  prompt: "{team-communication-template}\n\nInvestigate the following symptoms and identify root cause(s). Analyze stack traces, logs, code paths, and reproduction steps as available. Report findings — do NOT apply fixes yet.\n\nSymptoms:\n{symptom-description}"
)
TaskUpdate(taskId: "investigate", owner: "debugger", status: "in_progress")
```

**If live testing applies** (spawn simultaneously with debugger above):

```
Agent(
  description: "Live tester — runtime root cause investigation",
  subagent_type: "rust-agents:rust-live-tester",
  team_name: "rust-debug-{issue-slug}",
  name: "live-tester",
  prompt: "{team-communication-template}\n\nExecute the binary and reproduce the reported symptoms at runtime. Observe actual behavior: panics, unexpected output, test failures, assertion violations. Document exact reproduction steps, observed vs. expected output, and any anomalies. Report findings — do NOT fix code.\n\nSymptoms:\n{symptom-description}"
)
TaskUpdate(taskId: "live-test", owner: "live-tester", status: "in_progress")
```

**WAIT for BOTH agents** (debugger AND live-tester, if spawned) before proceeding. Collect both handoff frontmatters + paths.

Each handoff must contain:
- Root cause hypothesis (static reasoning / runtime evidence respectively)
- Affected files and line ranges
- Reproduction path
- Severity assessment
- Whether performance degradation is involved (to confirm `review-perf` inclusion)

After receiving both handoffs:
- **Re-evaluate `review-perf`**: if neither report confirms a performance angle, mark `review-perf` as `completed` and skip perf agent spawn.
- **Re-evaluate `review-arch`**: if condition 2 (architectural flag in handoff) triggers and condition 1 was not already met, now activate `review-arch`. If neither condition applies, mark `review-arch` as `completed` and `TaskUpdate(taskId: "consolidate", removeBlockedBy: ["review-arch"])`.

## Step 4: Parallel Review (spawn simultaneously)

Spawn all applicable reviewers at the same time. Pass investigation handoffs to each.

**If `review-arch` is active**:

```
Agent(
  description: "Architect — review debug findings",
  subagent_type: "rust-agents:rust-architect",
  team_name: "rust-debug-{issue-slug}",
  name: "arch-reviewer",
  prompt: "{team-communication-template}\n\nReview the investigation findings from an architectural perspective. Identify whether the bug is a symptom of a deeper design issue or a local defect. If both a static-analysis handoff and a live-testing handoff are provided, reconcile their conclusions before forming your assessment. Report only — do NOT write code.\n\nHandoffs:\n- Debugger (static): .local/handoff/{timestamp}-debugger.md\n- Live tester (runtime): .local/handoff/{timestamp}-live-tester.md  (if applicable)"
)
TaskUpdate(taskId: "review-arch", owner: "arch-reviewer", status: "in_progress")
```

Agent(
  description: "Security — review security implications",
  subagent_type: "rust-agents:rust-security-maintenance",
  team_name: "rust-debug-{issue-slug}",
  name: "security",
  prompt: "{team-communication-template}\n\nReview the investigation findings for security implications: data exposure, privilege escalation, memory safety violations, dependency vulnerabilities. Consider both static-analysis conclusions and runtime-observed behavior. Report only — do NOT write code.\n\nHandoffs:\n- Debugger (static): .local/handoff/{timestamp}-debugger.md\n- Live tester (runtime): .local/handoff/{timestamp}-live-tester.md  (if applicable)"
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
  prompt: "{team-communication-template}\n\nReview the investigation findings for performance implications: hot paths, allocations, async bottlenecks, regression vectors. Use runtime evidence from the live tester where available to prioritize findings. Report only — do NOT edit source files.\n\nHandoffs:\n- Debugger (static): .local/handoff/{timestamp}-debugger.md\n- Live tester (runtime): .local/handoff/{timestamp}-live-tester.md  (if applicable)"
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
  prompt: "{team-communication-template}\n\nConsolidate findings from all investigation and review agents. Produce a unified fix scope:\n- Cross-reference static analysis (debugger) with runtime evidence (live tester): if they align, confidence is high; if they diverge, flag the discrepancy and defer to runtime evidence\n- Prioritize fixes: critical (must fix now) vs. follow-up (file as issues)\n- List exact files and line ranges that need changes\n- Flag security findings requiring immediate attention\n- Note architectural issues that warrant a separate team-develop cycle\n- Conclude with verdict: 'fixes_required' or 'no_fixes_needed'\n\nHandoffs:\n- Debugger (static): .local/handoff/{timestamp}-debugger.md\n- Live tester (runtime): .local/handoff/{timestamp}-live-tester.md  (if applicable)\n- Architect review: .local/handoff/{timestamp}-architect.md  (if applicable)\n- Security: .local/handoff/{timestamp}-security.md\n- Performance: .local/handoff/{timestamp}-performance.md  (if applicable)"
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
After investigation: handoffs = [debugger, (live-tester)]
After parallel:      handoffs = [debugger, (live-tester), (arch-reviewer), security, (perf)]
Reviewer gets all of the above.
```

## References

- [team-workflow.md](references/team-workflow.md): Detailed step-by-step execution guide
- [communication-protocol.md](references/communication-protocol.md): Message templates, peer-to-peer patterns
