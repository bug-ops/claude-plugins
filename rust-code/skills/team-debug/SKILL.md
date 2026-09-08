---
name: team-debug
description: "Debug Rust issues using a multi-agent investigation team: debugger + live-tester (conditional) investigate root cause in parallel, security review always, architect and perf reviews conditionally, code reviewer consolidates findings, results presented to the user. Requires CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1; CLAUDE_CODE_ENABLE_TODO_TOOLS=1 enables shared task-list coordination on Claude Code 2.1.233+."
when_to_use: "'debug issue', 'investigate bug', 'root cause', 'production incident', 'team debug', 'why does this panic'."
argument-hint: "[symptom-description]"
allowed-tools: Bash(printenv *), Bash(git branch *), Bash(test *), Bash(echo *)
---

# Team Debug Orchestration

You act as **team lead** for a debugging investigation. Coordinate specialist agents to diagnose the issue.

**Symptoms**: $ARGUMENTS

> You do NOT investigate or fix code yourself. ALL analysis is delegated. If you are about to read source files or edit code — STOP. Spawn the appropriate agent.

## Preflight (collected automatically when this skill loads)

- Agent teams flag: !`printenv CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS || echo unset`
- Task tools flag: !`printenv CLAUDE_CODE_ENABLE_TODO_TOOLS || echo unset`
- Current branch: !`git branch --show-current 2>/dev/null || echo not-a-git-repo`
- Cargo.toml: !`test -f Cargo.toml && echo present || echo missing`

Check the values above before spawning anything. STOP and tell the user when:

1. Agent teams flag is not `1` — without agent teams, `Agent()` calls spawn background subagents (Claude Code 2.1.232+ default), teammates never form, and every WAIT step below stalls
2. Current branch is `main`/`master` — create a fix branch first
3. Cargo.toml is `missing`

Agent teams never form in non-interactive sessions (`claude -p`, SDK): a named spawn there runs as an ordinary subagent. Do not run this skill headless.

## Teammate Outcomes

Every WAIT step below ends with one of these outcomes:

| Outcome (idle notification or message) | Lead action |
|---|---|
| Handoff frontmatter + path received | Route on the frontmatter as described in the step |
| "stopped at its N-turn limit" (partial result) | `SendMessage(to: "{name}", summary: "Continue", message: "Continue from where you stopped: finish the handoff file and send its frontmatter + path")`. On a second limit, report to the user |
| `failed: <error>` (API error, rate limit) | Report the error to the user; to continue, re-spawn the role under a fresh suffixed name (`security-2`) with the accumulated handoffs |
| Idle without a handoff file | The task is not done: resume with `SendMessage` to the same name, never spawn a duplicate |

Never reuse a name for a fresh spawn — a new agent with an existing name shadows the old one and breaks `SendMessage` routing.

## Step 1: Load Tools

```
ToolSearch("select:SendMessage")
ToolSearch("select:TaskCreate,TaskUpdate,TaskList,TaskGet")
```

If the Task tools are not found: Claude Code 2.1.233+ omits them on current models unless `CLAUDE_CODE_ENABLE_TODO_TOOLS=1` is set (e.g. in the `env` block of `settings.json`). Tell the user, then continue in **message-based fallback**: skip every TaskCreate/TaskUpdate call in this workflow (including the conditional-gate updates — apply the gate logic to your own sequencing instead), keep the task DAG and its blocked-by order yourself, drop the Tasks line from the spawn template, and sequence agents by WAITing for each handoff message before spawning dependents.

## Step 2: Task Setup

The team forms implicitly when you spawn the first teammate (requires `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`) — there is no team-creation call. Create all tasks upfront and set dependencies (message-based fallback: skip the TaskCreate/TaskUpdate calls; the table stays your execution order):

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

Substitute `{agent-role}` (drop the Tasks line in message-based fallback), then include verbatim in every spawn prompt:

```
You are a teammate in this session's agent team, role `{agent-role}`.

Tasks: ToolSearch("select:TaskCreate,TaskUpdate,TaskList,TaskGet"); update your task to in_progress on start, completed on finish.

Communication: SendMessage(to: "team-lead", message: "...", summary: "..."). Respond to a shutdown_request with SendMessage(to: "team-lead", message: {type: "shutdown_response", request_id: "<echo the request_id>", approve: true}).

Code ownership: only debugger edits source. Only team-lead commits.

Handoff (MANDATORY): BEFORE any other work, call Skill(skill: "rust-agents:rust-agent-handoff"). Before messaging the lead, write your handoff file and include inline frontmatter + path in the message.
```

## Step 3: Investigation Phase (parallel when live testing applies)

Spawn `rust-debugger` unconditionally. If live testing applies, spawn `rust-live-tester` simultaneously.

```
Agent(
  description: "Debugger — static root cause",
  subagent_type: "rust-agents:rust-debugger",
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
  name: "live-tester",
  prompt: "{template}\n\nAfter handoff: call Skill(skill: \"rust-agents:live-testing\") — it is the authoritative execution guide for this session.\n\nExecute binary, reproduce reported symptoms, document repro steps, observed vs expected, anomalies. Do NOT fix.\n\nSymptoms:\n{symptom-description}"
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
Agent(subagent_type: "rust-agents:rust-architect", name: "arch-reviewer",
  prompt: "{template}\n\nReview findings architecturally: deeper design issue or local defect? Reconcile static vs runtime conclusions. Report only.\n\nHandoffs:\n- Debugger: .local/handoff/{ts}-debug.md\n- Live tester: .local/handoff/{ts}-live-tester.md (if applicable)")
TaskUpdate(taskId: "review-arch", owner: "arch-reviewer", status: "in_progress")
```

Always:

```
Agent(subagent_type: "rust-agents:rust-security-maintenance", name: "security",
  prompt: "{template}\n\nReview security implications: data exposure, privilege escalation, memory safety, dependency vulns. Report only.\n\nHandoffs: {as above}")
TaskUpdate(taskId: "review-security", owner: "security", status: "in_progress")
```

If `review-perf` is active:

```
Agent(subagent_type: "rust-agents:rust-performance-engineer", name: "perf",
  prompt: "{template}\n\nReview performance implications: hot paths, allocations, async bottlenecks. Use runtime evidence where available. Report only.\n\nHandoffs: {as above}")
TaskUpdate(taskId: "review-perf", owner: "perf", status: "in_progress")
```

WAIT for all active reviewers.

## Step 5: Consolidation

Pass all accumulated handoffs to code reviewer.

```
Agent(subagent_type: "rust-agents:rust-code-reviewer", name: "reviewer",
  prompt: "{template}\n\nAfter handoff: call Skill(skill: \"rust-agents:rust-modern-apis\") before reviewing code.\n\nConsolidate findings into a unified fix scope:\n- Cross-reference static vs runtime evidence (defer to runtime if they diverge)\n- Prioritize: critical (must fix now) vs follow-up (file as issues)\n- Exact files and line ranges to change\n- Flag security findings\n- Note architectural issues warranting a separate /team-develop cycle\n- Verdict: 'fixes_required' or 'no_fixes_needed'\n\nHandoffs: {all accumulated}")
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
SendMessage(to: "{agent-name}", message: {type: "shutdown_request", reason: "Task complete"})
```

Wait for `shutdown_response`. The team's shared directories are cleaned up automatically when the session ends — there is no separate teardown call.

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
