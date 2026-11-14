---
name: team-debug
description: "Debug Rust, TypeScript, and Luau/Lua issues using a multi-agent investigation team: debugger + live-tester (conditional) investigate root cause in parallel, security review always, architect and perf reviews conditionally, code reviewer consolidates findings, results presented to the user. Requires CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1; CLAUDE_CODE_ENABLE_TODO_TOOLS=1 enables shared task-list coordination on Claude Code 2.1.233+."
when_to_use: "'debug issue', 'investigate bug', 'root cause', 'production incident', 'team debug', 'why does this panic', 'why does this throw'."
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
- tsconfig.json: !`test -f tsconfig.json && echo present || echo missing`
- package.json: !`test -f package.json && echo present || echo missing`
- Luau/Lua markers: !`test -f default.project.json -o -f wally.toml -o -f pesde.toml -o -f .luaurc -o -f .luarc.json -o -f selene.toml -o -f stylua.toml && echo present || echo missing`

Check the values above before spawning anything. STOP and tell the user when:

1. Agent teams flag is not `1` — without agent teams, `Agent()` calls spawn background subagents (Claude Code 2.1.232+ default), teammates never form, and every WAIT step below stalls
2. Current branch is `main`/`master` — create a fix branch first
3. Cargo.toml, tsconfig.json, package.json, and the Luau/Lua markers are all `missing` — no supported stack (monorepo with manifests only in subdirectories: ask the user which stack to pass)

**Stack**: derive `{stack}` from the markers — `Cargo.toml` → `rust`; `tsconfig.json` or `package.json` → `typescript`; Luau/Lua markers → `luau`; several → all of them, comma-separated (`rust,typescript`; a roblox-ts project is `typescript,luau`). Narrow it when the symptoms clearly sit in one language. Every spawn prompt carries it (see the Spawn Template), so teammates skip their own detection.

Agent teams never form in non-interactive sessions (`claude -p`, SDK): a named spawn there runs as an ordinary subagent. Do not run this skill headless.

## Step 1: Load the Lead Protocol

Call `Skill(skill: "dev-agents:team-lead")` and follow it: tool loading and the message-based fallback, the spawn template, teammate outcomes, naming, isolation, and shutdown. Do not spawn anything before it is loaded (without the `Skill` tool, Read `${CLAUDE_PLUGIN_ROOT}/skills/team-lead/SKILL.md`). Every teammate here is report-only.

## Step 2: Task Setup

Create all tasks upfront by name (the `team-lead` name → ID rule) and set dependencies (message-based fallback: skip the TaskCreate/TaskUpdate calls; the table stays your execution order):

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

- **live-test**: keep if symptoms include runtime behavior (panics, uncaught exceptions, crashes, wrong output, flaky tests, integration failures, async deadlocks). For pure compile-time symptoms (build errors, type mismatches, linker failures), mark `live-test` completed immediately and `removeBlockedBy: ["live-test"]` from review tasks.
- **review-arch**: keep if symptoms mention recurring/systemic/regression-after-refactor/multiple-callers/wrong-abstraction/design-flaw, OR if investigation handoffs flag an architectural concern. Otherwise mark completed and `removeBlockedBy: ["review-arch"]` from consolidate.
- **review-perf**: keep if symptoms include latency/slow/timeout/memory-leak/CPU-spike/throughput/regression/benchmark-failure. Otherwise mark completed.

## Spawn Template

Every spawn prompt starts with the `team-lead` spawn template (`{template}` below), filled for this run:

- **Teammates**: the names this run spawns (`debugger`, and as applicable `live-tester`, `arch-reviewer`, `security`, `perf`, `reviewer`)
- **Peers**: `none — report to the lead only`
- **Code ownership**: `report-only — no teammate edits source`

## Step 3: Investigation Phase (parallel when live testing applies)

Spawn `debugger` unconditionally. If live testing applies, spawn `live-tester` simultaneously.

```
Agent(
  description: "Debugger — static root cause",
  subagent_type: "dev-agents:debugger",
  name: "debugger",
  prompt: "{template}\n\nInvestigate symptoms via static analysis. Report root cause(s), affected files/lines, reproduction path, severity, perf-degradation flag. Do NOT apply fixes.\n\nSymptoms:\n{symptom-description}"
)
TaskUpdate(taskId: "investigate", owner: "debugger", status: "in_progress")
```

If live testing applies:

```
Agent(
  description: "Live tester — runtime root cause",
  subagent_type: "dev-agents:live-tester",
  name: "live-tester",
  prompt: "{template}\n\nAfter handoff: call Skill(skill: \"dev-agents:live-testing\") — it is the authoritative execution guide for this session.\n\nExecute binary, reproduce reported symptoms, document repro steps, observed vs expected, anomalies. Do NOT fix.\n\nSymptoms:\n{symptom-description}"
)
TaskUpdate(taskId: "live-test", owner: "live-tester", status: "in_progress")
```

WAIT for both handoff frontmatters + paths. Each must contain: root cause hypothesis, affected files/lines, repro, severity, performance flag.

**No-change outcome.** A debugger handoff with `status: no_change_needed` (the code behaves as intended; its `## Evidence` section holds the reproduction attempt) ends the investigation only when no `live-tester` was spawned or its handoff did not reproduce the symptoms: runtime evidence wins. Then skip Steps 4 and 5, send `shutdown_request` to every idle agent, and present the evidence to the user in place of the Step 6 report, with no fixes proposed. When the live-tester reproduced the symptoms, treat the debugger's handoff as a diverging diagnosis and pass both to the reviewer in Step 5.

After receiving handoffs:
- **review-perf**: if neither report confirms perf angle, mark completed.
- **review-arch**: if a handoff flags architectural concern and condition wasn't met before, activate now. Otherwise mark completed and `removeBlockedBy: ["review-arch"]` from consolidate.

## Step 4: Parallel Review

Spawn all applicable reviewers simultaneously, passing investigation handoffs to each.

If `review-arch` is active:

```
Agent(subagent_type: "dev-agents:architect", name: "arch-reviewer",
  prompt: "{template}\n\nReview findings architecturally: deeper design issue or local defect? Reconcile static vs runtime conclusions. Report only.\n\nHandoffs:\n- Debugger: .local/handoff/{ts}-debug.md\n- Live tester: .local/handoff/{ts}-live-tester.md (if applicable)")
TaskUpdate(taskId: "review-arch", owner: "arch-reviewer", status: "in_progress")
```

Always:

```
Agent(subagent_type: "dev-agents:security-maintenance", name: "security",
  prompt: "{template}\n\nReview security implications: data exposure, privilege escalation, memory safety, dependency vulns. Report only.\n\nHandoffs: {as above}")
TaskUpdate(taskId: "review-security", owner: "security", status: "in_progress")
```

If `review-perf` is active:

```
Agent(subagent_type: "dev-agents:performance-engineer", name: "perf",
  prompt: "{template}\n\nReview performance implications: hot paths, allocations, async bottlenecks. Use runtime evidence where available. Report only.\n\nHandoffs: {as above}")
TaskUpdate(taskId: "review-perf", owner: "perf", status: "in_progress")
```

WAIT for all active reviewers.

## Step 5: Consolidation

Pass all accumulated handoffs to code reviewer.

```
Agent(subagent_type: "dev-agents:code-reviewer", name: "reviewer",
  prompt: "{template}\n\nConsolidate findings into a unified fix scope:\n- Cross-reference static vs runtime evidence (defer to runtime if they diverge)\n- Prioritize: critical (must fix now) vs follow-up (file as issues)\n- Triage every Follow-ups entry in the handoffs (sources and issue format per your Follow-up Sources and Filing sections) but do NOT file yet — list them in Follow-up Issues; the user decides on filing\n- Exact files and line ranges to change\n- Flag security findings\n- Note architectural issues warranting a separate /team-develop cycle\n- Verdict: 'fixes_required' or 'no_fixes_needed'\n\nHandoffs: {all accumulated}")
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
{from the reviewer's Follow-up Issues section: architectural / security / perf concerns and every agent follow-up — not critical now}

### Recommendation
- Fix critical items via /team-develop or manual patch
- Create GitHub issue per follow-up item
- Group into an epic if 3+ related issues exist
```

Ask the user — choose one or combination:
1. Create GitHub issues for follow-up items (and optionally an epic if 3+)?
2. Hand off to `/team-develop` to implement critical fixes now?
3. Both — file issues for follow-up, then start `team-develop` for critical fixes?

Do nothing until the user responds. Keep the reviewer running until then: when the user chooses to file follow-ups, `SendMessage(to: "reviewer", ...)` to file them per its Filing Follow-up Issues protocol (and the epic, if chosen), WAIT for the issue URLs, and report them.

## Step 7: Shutdown

Shut down each agent as soon as its task is complete, per the `team-lead` protocol (Shutdown). Keep the reviewer until the user has answered Step 6.

## Handoff Accumulation

Pass inline frontmatter to each subsequent agent — no file reads for routing:

```
After investigation: [debugger, (live-tester)]
After parallel:      [debugger, (live-tester), (arch-reviewer), security, (perf)]
Reviewer gets all of the above.
```
