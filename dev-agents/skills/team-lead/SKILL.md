---
name: team-lead
description: "Shared lead protocol for the dev-agents orchestrators (team-develop, team-debug, continuous-improvement): tool loading with the message-based fallback, the spawn template, teammate outcomes, naming and isolation rules, and shutdown. Each orchestrator calls it at startup; it is not meant to be invoked by users."
user-invocable: false
---

# Team Lead Protocol

The orchestrator that called this skill owns the workflow: chain, task graph, roster, code ownership, and allowed peer flows. This skill holds the mechanics they all share. Where the orchestrator states an override, the override wins.

## 1. Load Tools

```
ToolSearch("select:SendMessage")
ToolSearch("select:TaskCreate,TaskUpdate,TaskList,TaskGet")
```

If the Task tools are not found: Claude Code 2.1.233+ omits them on current models unless `CLAUDE_CODE_ENABLE_TODO_TOOLS=1` is set (e.g. in the `env` block of `settings.json`). Tell the user, then continue in **message-based fallback**: skip every TaskCreate/TaskUpdate call in the workflow (conditional-gate updates included — apply the gate logic to your own sequencing), keep the task DAG and its blocked-by order yourself, drop the `Task:` line from the spawn template, and sequence agents by WAITing for each handoff before spawning dependents.

The team forms implicitly when you spawn the first teammate; there is no team-creation call.

**Task names and IDs.** The orchestrators name their tasks (`plan`, `critique`, `implement-{a}`, ...). `TaskCreate` takes no ID: create each task with `TaskCreate(subject: "<name>", description: "...")`, and the tool returns the ID it assigned. Keep a name → ID map. Every `TaskUpdate(taskId: "<name>", ...)` and `addBlockedBy: ["<name>"]` in an orchestrator means the mapped ID, and the spawn template's `Task:` line carries the real ID.

## 2. Spawn Template

Fill it for each spawn and put it at the top of the spawn prompt (`{template}` in the orchestrator):

```
You are a teammate in this session's agent team, role `{role}`.

Stack: {stack}
Teammates: {names planned for this run}
Peers: {peer flows the orchestrator allows, or "none — report to the lead only"}
Task: {task id}
Code ownership: {the orchestrator's ownership line for this run}. Only team-lead commits.

Handoff (MANDATORY): BEFORE any other work, call Skill(skill: "dev-agents:agent-handoff") and follow it, including its "In an Agent Team" section.
```

Teammate-side rules (reporting, ownership, peers, task updates, shutdown) live in that agent-handoff section, which every teammate loads first. Do not restate them in the prompt.

Every spawn uses this form:

```
Agent(subagent_type: "dev-agents:<agent>", name: "<teammate name>", description: "<3-5 words>",
  prompt: "{template}\n\n<task>\n\nHandoffs:\n<accumulated frontmatters>")
```

- `name` is mandatory: it is the address for every later `SendMessage(to: "<name>")`. A spawn without it cannot be resumed, routed, or shut down.
- `subagent_type` always carries the `dev-agents:` prefix.
- Orchestrator examples may omit `description` or use a shorthand they define; the spawn still has all three fields.

## 3. Teammate Outcomes

Every WAIT ends with one of these:

| Outcome (idle notification or message) | Lead action |
|---|---|
| Handoff frontmatter + path received | Route on the frontmatter as the orchestrator step says |
| "stopped at its N-turn limit" (partial result) | `SendMessage(to: "{name}", summary: "Continue", message: "Continue from where you stopped: finish the handoff file and send its frontmatter + path")`. On a second limit, report to the user |
| `failed: <error>` (API error, rate limit) | Report the error to the user; to continue, re-spawn the role under a fresh suffixed name (`reviewer-2`) with the accumulated handoffs |
| Idle without a handoff file | The task is not done: resume with `SendMessage` to the same name, never spawn a duplicate |

## 4. Naming and Isolation

- Never reuse a name for a fresh spawn: a new agent with an existing name shadows the old one and breaks `SendMessage` routing. Resume a teammate with `SendMessage` when its context is useful (fix cycles, redesign after a critic verdict); use a suffixed name (`developer-2`) when a clean context is wanted.
- A shut-down name stays taken for the session. A chain re-spawned after an escalation, or started after a hand-off from another orchestrator in the same session (team-debug to team-develop), gives every role a `-2` suffix (`architect-2`, `reviewer-2`) and lists those names in `Teammates:`.
- Never pass `isolation` on a teammate spawn, even when the Agent tool suggests `isolation: "worktree"` for parallel writers: a named call with `isolation` starts a plain subagent outside the team.

## 5. Shutdown

Shut down each teammate as soon as no later step of the orchestrator's workflow will message it (the orchestrator lists who stays until the commit):

```
SendMessage(to: "{name}", message: {type: "shutdown_request", reason: "Task complete"})
```

Wait for its `shutdown_response`. The team's shared directories are cleaned up automatically when the session ends; there is no teardown call.
