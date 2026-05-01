---
name: team-debug
description: "Debug Rust issues using a multi-agent investigation team. Workflow: debugger + live-tester (conditional) investigate root cause in parallel → security review always, architect and perf reviews conditionally → code reviewer consolidates findings → results presented to user. Requires rust-agents plugin and CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1."
argument-hint: "[symptom-description]"
---

# Team Debug Orchestration

You act as **team lead** for a debugging investigation. Coordinate specialist agents to diagnose the issue.

**Symptoms**: $ARGUMENTS

> You do NOT investigate or fix code yourself. ALL analysis is delegated. If you are about to read source files or edit code — STOP. Spawn the appropriate agent.

## Prerequisites

1. `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` in environment or `settings.json`
2. `rust-agents` plugin installed
3. Not on `main`/`master` (create a fix branch first)
4. `Cargo.toml` exists

## Step 1: Load Tools

```
ToolSearch("select:TaskCreate,TaskUpdate,TaskList,TaskGet,TeamCreate,TeamDelete,SendMessage")
```

## Step 2: Team Setup

```json
TeamCreate({"team_name": "rust-debug-{issue-slug}", "description": "Debug: {symptom-summary}"})
```

Create all tasks upfront and set dependencies:

| Task | Owner | Description |
|------|-------|-------------|
| investigate | debugger | Root cause via static reasoning |
| live-test | live-tester | Root cause via live execution (conditional) |
| review-arch | architect | Architectural review (conditional) |
| review-security | security | Security implications |
| review-perf | perf | Performance implications (conditional) |
| consolidate | reviewer | Unified report from all findings |

```
TaskUpdate(taskId: "review-arch",     addBlockedBy: ["investigate","live-test"])
TaskUpdate(taskId: "review-security", addBlockedBy: ["investigate","live-test"])
TaskUpdate(taskId: "review-perf",     addBlockedBy: ["investigate","live-test"])
TaskUpdate(taskId: "consolidate",     addBlockedBy: ["review-arch","review-security","review-perf"])
```

### Conditional task gates

- **live-test**: keep if symptoms include runtime behavior (panics, crashes, wrong output, flaky tests, integration failures, async deadlocks). For pure compile-time symptoms (build errors, type mismatches, linker failures), mark `live-test` completed immediately and `removeBlockedBy: ["live-test"]` from review tasks.
- **review-arch**: keep if symptoms mention recurring/systemic/regression-after-refactor/multiple-callers/wrong-abstraction/design-flaw, OR if investigation handoffs flag an architectural concern. Otherwise mark completed and `removeBlockedBy: ["review-arch"]` from consolidate.
- **review-perf**: keep if symptoms include latency/slow/timeout/memory-leak/CPU-spike/throughput/regression/benchmark-failure. Otherwise mark completed.

## Team Communication Template

Substitute `{team-name}` and `{agent-role}`, then include verbatim in every spawn prompt:

```
You are a teammate in team `{team-name}`, role `{agent-role}`.

Tasks: ToolSearch("select:TaskCreate,TaskUpdate,TaskList,TaskGet"); update your task to in_progress on start, completed on finish.

Communication: SendMessage(type: "message", to: "team-lead", content: "...", summary: "..."). Respond to shutdown_request with SendMessage(type: "shutdown_response", to: "team-lead", approve: true).

Code ownership: only debugger edits source. Only team-lead commits.

Handoff (MANDATORY): BEFORE any other work, call Skill(skill: "rust-agents:rust-agent-handoff"). Before messaging team-lead, write your handoff file and include inline frontmatter + path in the message.
```

## Step 3: Investigation Phase (parallel when live testing applies)

Spawn `rust-debugger` unconditionally. If live testing applies, spawn `rust-live-tester` simultaneously.

```
Agent(
  description: "Debugger — static root cause",
  subagent_type: "rust-agents:rust-debugger",
  team_name: "rust-debug-{issue-slug}",
  name: "debugger",
  prompt: "{template}\n\nInvestigate symptoms via static analysis. Report root cause(s), affected files/lines, reproduction path, severity, perf-degradation flag. Do NOT apply fixes.\n\nSymptoms:\n{symptom-description}"
)
TaskUpdate(taskId: "investigate", owner: "debugger", status: "in_progress")
```

If live testing applies:

```
Agent(
  description: "Live tester — runtime root cause",
  subagent_type: "rust-agents:rust-live-tester",
  team_name: "rust-debug-{issue-slug}",
  name: "live-tester",
  prompt: "{template}\n\nExecute binary, reproduce reported symptoms, document repro steps, observed vs expected, anomalies. Do NOT fix.\n\nSymptoms:\n{symptom-description}"
)
TaskUpdate(taskId: "live-test", owner: "live-tester", status: "in_progress")
```

WAIT for both handoff frontmatters + paths. Each must contain: root cause hypothesis, affected files/lines, repro, severity, performance flag.

After receiving handoffs:
- **review-perf**: if neither report confirms perf angle, mark completed.
- **review-arch**: if a handoff flags architectural concern and condition wasn't met before, activate now. Otherwise mark completed and `removeBlockedBy: ["review-arch"]` from consolidate.

## Step 4: Parallel Review

Spawn all applicable reviewers simultaneously, passing investigation handoffs to each.

If `review-arch` is active:

```
Agent(subagent_type: "rust-agents:rust-architect", name: "arch-reviewer", team_name: "...",
  prompt: "{template}\n\nReview findings architecturally: deeper design issue or local defect? Reconcile static vs runtime conclusions. Report only.\n\nHandoffs:\n- Debugger: .local/handoff/{ts}-debug.md\n- Live tester: .local/handoff/{ts}-live-tester.md (if applicable)")
TaskUpdate(taskId: "review-arch", owner: "arch-reviewer", status: "in_progress")
```

Always:

```
Agent(subagent_type: "rust-agents:rust-security-maintenance", name: "security", team_name: "...",
  prompt: "{template}\n\nReview security implications: data exposure, privilege escalation, memory safety, dependency vulns. Report only.\n\nHandoffs: {as above}")
TaskUpdate(taskId: "review-security", owner: "security", status: "in_progress")
```

If `review-perf` is active:

```
Agent(subagent_type: "rust-agents:rust-performance-engineer", name: "perf", team_name: "...",
  prompt: "{template}\n\nReview performance implications: hot paths, allocations, async bottlenecks. Use runtime evidence where available. Report only.\n\nHandoffs: {as above}")
TaskUpdate(taskId: "review-perf", owner: "perf", status: "in_progress")
```

WAIT for all active reviewers.

## Step 5: Consolidation

Pass all accumulated handoffs to code reviewer.

```
Agent(subagent_type: "rust-agents:rust-code-reviewer", name: "reviewer", team_name: "...",
  prompt: "{template}\n\nConsolidate findings into a unified fix scope:\n- Cross-reference static vs runtime evidence (defer to runtime if they diverge)\n- Prioritize: critical (must fix now) vs follow-up (file as issues)\n- Exact files and line ranges to change\n- Flag security findings\n- Note architectural issues warranting a separate /team-develop cycle\n- Verdict: 'fixes_required' or 'no_fixes_needed'\n\nHandoffs: {all accumulated}")
TaskUpdate(taskId: "consolidate", owner: "reviewer", status: "in_progress")
```

WAIT for reviewer's handoff. Proceed to Step 6.

## Step 6: Present Results

Compile a structured report. Do NOT apply fixes, create issues, or commit automatically.

```markdown
## Debug Investigation Complete

### Root Cause
{from debugger, refined by reviewers}

### Critical Fixes Required
{must-fix items with files/line ranges}

### Follow-up Issues
{architectural / security / perf concerns — not critical now}

### Recommendation
- Fix critical items via /team-develop or manual patch
- Create GitHub issue per follow-up item
- Group into an epic if 3+ related issues exist
```

Ask the user — choose one or combination:
1. Create GitHub issues for follow-up items (and optionally an epic if 3+)?
2. Hand off to `/team-develop` to implement critical fixes now?
3. Both — file issues for follow-up, then start `team-develop` for critical fixes?

Do nothing until the user responds.

## Step 7: Shutdown

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
After investigation: [debugger, (live-tester)]
After parallel:      [debugger, (live-tester), (arch-reviewer), security, (perf)]
Reviewer gets all of the above.
```

## References

- [team-workflow.md](references/team-workflow.md): Detailed step-by-step guide
- [communication-protocol.md](references/communication-protocol.md): Message templates, peer-to-peer patterns
