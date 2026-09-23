---
name: continuous-improvement
description: "Orchestrate a continuous improvement cycle: spawn rust-live-tester for live testing, rust-researcher for dependency monitoring and research, rust-arch-analyst for code quality and architecture review, and rust-security-analyst for vulnerability scanning. Read-only; aggregates findings into a cycle journal. Runs as an agent team when CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1, otherwise (including headless `claude -p`, /loop, /schedule) as background subagents."
when_to_use: "'run a CI cycle', 'continuous improvement', 'live-test the latest changes', 'monitor dependencies', 'audit architecture and security', 'what should we improve next'."
argument-hint: "[testing|research|dependencies|parity|arch|security|full]"
allowed-tools: Bash(printenv *), Bash(ls *), Bash(test *), Bash(echo *), Bash(grep *), Bash(sort *), Bash(tail *)
---

# Continuous Improvement Orchestrator

Run a continuous improvement cycle for the current Rust project by coordinating four specialized agents:

- **`rust-live-tester`** — syncs with remote, executes the project binary live, detects anomalies and regressions, tracks coverage, files bug issues
- **`rust-researcher`** — monitors dependency health, researches new techniques, tracks competitive parity, files research and dependency issues
- **`rust-arch-analyst`** — audits existing codebase for type system anti-patterns, DRY violations, architectural debt, API naming issues, and async concurrency problems; files improvement issues (read-only)
- **`rust-security-analyst`** — scans existing codebase for vulnerabilities: dependency advisories, unsafe code, exposed secrets, injection and input-validation gaps, crypto misuse, broken auth, panic-based DoS, and supply-chain risk; files security issues (read-only)

**Focus**: $ARGUMENTS

| Focus value | Agents spawned |
|-------------|----------------|
| `testing` | rust-live-tester only |
| `dependencies` | rust-researcher only (deps phase) |
| `research` | rust-researcher only (research phase) |
| `parity` | rust-researcher only (parity phase) |
| `arch` | rust-arch-analyst only (type-system, modularity, testability, readability, dry, async) |
| `security` | rust-security-analyst only (dependencies, unsafe, secrets, input, crypto, auth, panics, supply-chain) |
| `full` | rust-live-tester + rust-researcher + rust-arch-analyst + rust-security-analyst in parallel |

## Hard Rules

1. **NEVER modify source code** in this orchestrator session — delegate all execution to agents
2. **NEVER run live tests, research, or security scans directly** — spawn the appropriate agent
3. All spawned agents are read-only with respect to source code; they only write to `.local/`

## Project-Specific Rules

If the preflight shows `.claude/rules/continuous-improvement.md` as present, pass its contents to each spawned agent so they can apply project-specific overrides.

## Preflight (collected automatically when this skill loads)

- Agent teams flag: !`printenv CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS || echo unset`
- Task tools flag: !`printenv CLAUDE_CODE_ENABLE_TODO_TOOLS || echo unset`
- Cargo.toml: !`test -f Cargo.toml && echo present || echo missing`
- Project CI rules: !`test -f .claude/rules/continuous-improvement.md && echo present || echo absent`
- Last cycle journal: !`ls .local/testing/journal/ 2>/dev/null | grep -E '^ci-[0-9]{3}\.md$' | sort | tail -1 | grep . || echo none`

STOP if Cargo.toml is `missing`.

## Step 0: Pick the Engine, Load Tools, Create the Cycle Journal

This cycle is read-only fan-out: every agent works alone and reports back, so it runs on either engine.

| Agent teams flag | Engine | How agents report |
|---|---|---|
| `1` in an interactive session | **teams** — named spawns become teammates, the team forms implicitly on the first spawn | `SendMessage` to `team-lead` with handoff frontmatter + path |
| `unset`, or a non-interactive session (`claude -p`, SDK, `/loop`, `/schedule`) | **subagents** — the same `Agent()` calls run as background subagents | The agent's report arrives with its task notification, or in auto mode as its `SubagentHandback` message; require the handoff frontmatter + path in it |

Tell the user which engine is active. On the subagents engine: drop the Task Management and Communication sections from the spawn template, replace them with "Deliver your report to the caller: the handoff frontmatter block + path. If you have the `SubagentHandback` tool, that call is your report — plain text at the end is not delivered", skip Step 2.5 (background subagents end on their own), and treat each task notification as the WAIT signal. Never run `team-develop` or `team-debug` this way — they need peer messaging.

On the teams engine, load the tools:

```
ToolSearch("select:SendMessage")
ToolSearch("select:TaskCreate,TaskUpdate,TaskList,TaskGet")
```

If the Task tools are not found: Claude Code 2.1.233+ omits them on current models unless `CLAUDE_CODE_ENABLE_TODO_TOOLS=1` is set (e.g. in the `env` block of `settings.json`). Tell the user, then continue in **message-based fallback**: skip every TaskCreate/TaskUpdate call in this workflow, drop the Task Management section from the spawn template, and track each agent's completion by its handoff message.

Determine the next cycle number from the preflight "Last cycle journal" value: `none` means `001`; otherwise increment by one. Create `.local/testing/journal/` if it does not exist.

### Agent outcomes

| Outcome | Lead action |
|---|---|
| Handoff frontmatter + path received | Record in the journal (Step 3) |
| "stopped at its N-turn limit" (partial result) | `SendMessage(to: "{name}", message: "Continue from where you stopped: finish the handoff file and send its frontmatter + path")` once; then record what arrived |
| `failed: <error>` | Record the failure in the journal under that agent's section; do not re-spawn automatically |

Never reuse an agent name for a fresh spawn in the same session; use a suffixed name (`researcher-2`).

Create `.local/testing/journal/ci-NNN.md`:

```markdown
---
cycle: NNN
date: YYYY-MM-DD
focus: <focus>
team: <team-name>
---

## Continuous Improvement Cycle NNN — YYYY-MM-DD

### Playbooks

- [Testing playbooks](.local/testing/playbooks/)
- [Competitive parity](.local/testing/playbooks/competitive-parity.md)
- [Regression scenarios](.local/testing/regressions.md)

### Findings

| # | Type | Title | Priority | Issue | Spec |
|---|------|-------|----------|-------|------|

### Live Testing

_(populated by rust-live-tester)_

### Research & Monitoring

_(populated by rust-researcher)_

### Architecture & Code Quality

_(populated by rust-arch-analyst)_

### Security Audit

_(populated by rust-security-analyst)_

### Next Cycle Priorities

_(populated after cycle completes)_
```

Save `{journal-path}` = `.local/testing/journal/ci-NNN.md` for use in agent prompts and Step 3.

Create tasks upfront based on focus:

| Task | Owner | Condition |
|------|-------|-----------|
| `live-testing` | rust-live-tester | focus is `testing` or `full` |
| `research` | rust-researcher | focus is `research`, `dependencies`, `parity`, or `full` |
| `architecture` | rust-arch-analyst | focus is `arch` or `full` |
| `security` | rust-security-analyst | focus is `security` or `full` |

## Agent Communication Template

Include this block verbatim in every agent spawn prompt (substitute `{agent-role}` and `{journal-path}`; drop the Task Management section in message-based fallback):

```
You are operating as a teammate in this session's CI cycle team.

## Team Context
- Your role: {agent-role}
- Cycle journal: {journal-path}

## Task Management
0. FIRST: call ToolSearch("select:TaskCreate,TaskUpdate,TaskList,TaskGet") to load task tool schemas
1. Check TaskList for your assigned task
2. TaskUpdate(status: "in_progress") when starting
3. TaskUpdate(status: "completed") when done

## Journal
Append each finding as a new row in the Findings table of `{journal-path}`:
`| N | <type> | <title> | <P0-P4> | #<issue> | <spec-path or —> |`

## Communication
- Send results to the lead: SendMessage(to: "team-lead", message: "...", summary: "...")
- Respond to a shutdown_request with: SendMessage(to: "team-lead", message: {type: "shutdown_response", request_id: "<echo the request_id>", approve: true})
- Include file paths and issue URLs in your final message

## Handoff Protocol (MANDATORY)
BEFORE any other work: call Skill(skill: "rust-agents:rust-agent-handoff") and follow the protocol.
Before finishing: write handoff file and include inline frontmatter block + path in your message to the lead.
```

## Step 1: Spawn agents

Spawn all applicable agents in a **single message** so they run in parallel.

| Agent | Spawn when |
|-------|------------|
| rust-live-tester | focus is `testing` or `full` |
| rust-researcher | focus is `research`, `dependencies`, `parity`, or `full` |
| rust-arch-analyst | focus is `arch` or `full` |
| rust-security-analyst | focus is `security` or `full` |

**rust-live-tester**:

```
TaskCreate(id: "live-testing", description: "Live testing cycle")
Agent({
  subagent_type: "rust-agents:rust-live-tester",
  description: "Live testing cycle",
  name: "live-tester",
  prompt: "{agent-communication-template}

Run the live-testing skill for this project.
Focus: <testing | full — pick based on $ARGUMENTS>.
Read the handoff chain for context on what changed recently.
Project-specific rules: <paste .claude/rules/continuous-improvement.md if it exists, else omit>
Write your handoff with a Testing Results section listing all findings and filed issue URLs."
})
TaskUpdate(taskId: "live-testing", owner: "live-tester", status: "in_progress")
```

**rust-researcher**:

```
TaskCreate(id: "research", description: "Research and monitoring cycle")
Agent({
  subagent_type: "rust-agents:rust-researcher",
  description: "Research and monitoring cycle",
  name: "researcher",
  prompt: "{agent-communication-template}

Run the research-protocol skill for this project.
Focus: <research | dependencies | parity | full — pick based on $ARGUMENTS>.
Read the handoff chain for context on what changed recently.
Project-specific rules: <paste .claude/rules/continuous-improvement.md if it exists, else omit>
Write your handoff with a Research Results section listing all findings and filed issue URLs and spec paths."
})
TaskUpdate(taskId: "research", owner: "researcher", status: "in_progress")
```

**rust-arch-analyst**:

```
TaskCreate(id: "architecture", description: "Architecture and code quality review")
Agent({
  subagent_type: "rust-agents:rust-arch-analyst",
  description: "Architecture and code quality review",
  name: "arch-analyst",
  prompt: "{agent-communication-template}

Run a full architecture and code quality audit of this project.
This is a READ-ONLY analysis pass — do NOT modify source files. Use the audit checklist in your agent definition.
Project-specific rules: <paste .claude/rules/continuous-improvement.md if it exists, else omit>
Write your handoff with an Architecture Review section listing all findings and filed issue URLs."
})
TaskUpdate(taskId: "architecture", owner: "arch-analyst", status: "in_progress")
```

**rust-security-analyst**:

```
TaskCreate(id: "security", description: "Vulnerability and security-hardening audit")
Agent({
  subagent_type: "rust-agents:rust-security-analyst",
  description: "Vulnerability and security-hardening audit",
  name: "security-analyst",
  prompt: "{agent-communication-template}

Run a full vulnerability and security-hardening audit of this project.
This is a READ-ONLY analysis pass — do NOT modify source files, Cargo.toml, or Cargo.lock. Use the security-audit checklist from your agent definition (run the dependency scanners first, then the code-pattern categories).
Project-specific rules: <paste .claude/rules/continuous-improvement.md if it exists, else omit>
Write your handoff with a Security Review section listing all findings, severities, and filed issue URLs."
})
TaskUpdate(taskId: "security", owner: "security-analyst", status: "in_progress")
```

**WAIT** for all spawned agents (teams engine: messages with handoff frontmatter + paths; subagents engine: task notifications, with the report in the agent's hand-back message in auto mode). Then update their tasks to `completed`. Apply the Agent outcomes table from Step 0 to partial or failed results.

## Step 2.5: Shutdown Agents (teams engine only)

After each agent completes its task, shut it down immediately:

```
SendMessage(to: "{agent-name}", message: {type: "shutdown_request", reason: "Cycle complete, shutting down"})
```

Wait for `shutdown_response`. The team's shared directories are cleaned up automatically when the session ends — there is no separate teardown call.

## Step 3: Complete Cycle Summary

Aggregate results from agent messages and complete the remaining sections of `{journal-path}`:

```markdown
### Live Testing

- Features tested: <list>
- Issues filed: <links>
- Coverage changes: <components moved to Tested/Partial/Untested>

### Research & Monitoring

- Dependency advisories: <count and priority>
- Research issues filed: <links>
- Parity gaps identified: <count>

### Architecture & Code Quality

- Anti-patterns found: <count by category: type system / DRY / API naming / workspace / async>
- Issues filed: <links>
- Top structural concern: <one-sentence summary>

### Security Audit

- Vulnerabilities found: <count by severity: Critical / High / Medium / Low>
- Scanner results: cargo audit <N advisories> | cargo deny <pass/fail> | gitleaks <clean/N hits>
- Issues filed: <links>
- Top security risk: <one-sentence summary; note if immediate rotation/patch is required>

### Next Cycle Priorities

- <top 3 items based on Findings table>
```

Print `{journal-path}` to the console so the user can locate the cycle record.
