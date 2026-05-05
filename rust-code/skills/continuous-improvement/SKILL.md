---
name: continuous-improvement
description: "Orchestrate a continuous improvement cycle: spawn rust-live-tester for live testing and rust-researcher for dependency monitoring and research. Aggregates findings and produces a cycle summary."
argument-hint: "[testing|research|dependencies|parity|full]"
---

# Continuous Improvement Orchestrator

Run a continuous improvement cycle for the current Rust project by coordinating two specialized agents:

- **`rust-live-tester`** — syncs with remote, executes the project binary live, detects anomalies and regressions, tracks coverage, files bug issues
- **`rust-researcher`** — monitors dependency health, researches new techniques, tracks competitive parity, files research and dependency issues

**Focus**: $ARGUMENTS

| Focus value | Agents spawned |
|-------------|----------------|
| `testing` | rust-live-tester only |
| `dependencies` | rust-researcher only (deps phase) |
| `research` | rust-researcher only (research phase) |
| `parity` | rust-researcher only (parity phase) |
| `full` | rust-live-tester, then rust-researcher |

## Hard Rules

1. **NEVER modify source code** in this orchestrator session — delegate all execution to agents
2. **NEVER run live tests or research directly** — spawn the appropriate agent
3. Both agents are read-only with respect to source code; they only write to `.local/`

## Project-Specific Rules

Check if the project has a `.claude/rules/continuous-improvement.md` file. If it exists, pass its contents to each spawned agent so they can apply project-specific overrides.

## Step 0: Load Tools, Setup Team, and Create Cycle Journal

```
ToolSearch("select:TaskCreate,TaskUpdate,TaskList,TaskGet,TeamCreate,TeamDelete,SendMessage")
```

```json
TeamCreate({
  "team_name": "ci-cycle-{YYYYMMDD}",
  "description": "Continuous improvement cycle — focus: {focus}"
})
```

Determine the next cycle number:

```bash
ls .local/testing/journal/ 2>/dev/null | grep -E '^ci-[0-9]{3}\.md$' | sort | tail -1
```

If the directory is empty or missing: use `001`; otherwise increment by one. Create `.local/testing/journal/` if it does not exist.

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

### Next Cycle Priorities

_(populated after cycle completes)_
```

Save `{journal-path}` = `.local/testing/journal/ci-NNN.md` for use in agent prompts and Step 3.

Create tasks upfront based on focus:

| Task | Owner | Condition |
|------|-------|-----------|
| `live-testing` | rust-live-tester | focus is `testing` or `full` |
| `research` | rust-researcher | focus is `research`, `dependencies`, `parity`, or `full` |

## Agent Communication Template

Include this block verbatim in every agent spawn prompt (substitute `{team-name}`, `{agent-role}`, `{journal-path}`):

```
You are operating as a teammate in a CI cycle team.

## Team Context
- Team: {team-name}
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
- Send results to team lead: SendMessage(type: "message", to: "ci-lead", content: "...", summary: "...")
- Respond to shutdown_request with: SendMessage(type: "shutdown_response", to: "ci-lead", approve: true)
- Include file paths and issue URLs in your final message

## Handoff Protocol (MANDATORY)
BEFORE any other work: call Skill(skill: "rust-agents:rust-agent-handoff") and follow the protocol.
Before finishing: write handoff file and include inline frontmatter block + path in your message to ci-lead.
```

## Step 1: Spawn rust-live-tester (testing, full)

Skip this step if focus is `research`, `dependencies`, or `parity`.

```
TaskCreate(id: "live-testing", description: "Live testing cycle")
Agent({
  subagent_type: "rust-agents:rust-live-tester",
  description: "Live testing cycle",
  team_name: "{team-name}",
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

**WAIT** for live-tester's message with handoff frontmatter + path. Then: `TaskUpdate(taskId: "live-testing", status: "completed")`.

## Step 2: Spawn rust-researcher (research, dependencies, parity, full)

Skip this step if focus is `testing`.

```
TaskCreate(id: "research", description: "Research and monitoring cycle")
Agent({
  subagent_type: "rust-agents:rust-researcher",
  description: "Research and monitoring cycle",
  team_name: "{team-name}",
  name: "researcher",
  prompt: "{agent-communication-template}

Run the research-protocol skill for this project.
Focus: <research | dependencies | parity | full — pick based on $ARGUMENTS>.
Read the handoff chain for context. If rust-live-tester ran before you, its handoff may contain dependency concerns or research topics to prioritize.
Project-specific rules: <paste .claude/rules/continuous-improvement.md if it exists, else omit>
Write your handoff with a Research Results section listing all findings and filed issue URLs and spec paths."
})
TaskUpdate(taskId: "research", owner: "researcher", status: "in_progress")
```

**WAIT** for researcher's message with handoff frontmatter + path. Then: `TaskUpdate(taskId: "research", status: "completed")`.

## Step 2.5: Shutdown Agents

After each agent completes its task, shut it down immediately:

```
SendMessage(type: "shutdown_request", to: "{agent-name}", content: "Cycle complete, shutting down")
```

Wait for `shutdown_response`. After all agents shut down: `TeamDelete()`.

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

### Next Cycle Priorities

- <top 3 items based on Findings table>
```

Print `{journal-path}` to the console so the user can locate the cycle record.
