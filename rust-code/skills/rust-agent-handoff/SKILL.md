---
name: rust-agent-handoff
description: Handoff protocol for Rust multi-agent system. Subagents communicate via Markdown+frontmatter files in .local/handoff/. ALWAYS read on agent startup.
---

# Rust Agent Handoff Protocol

Subagents work in isolated context. This protocol enables communication via Markdown+frontmatter files.

## File Path

`.local/handoff/{TS}-{agent}.md` where `TS=$(date +%Y-%m-%dT%H-%M-%S)`.

## Frontmatter Schema

| Field | Type | Description |
|-------|------|-------------|
| `id` | string | `{TS}-{agent}` — must match filename (without `.md`) |
| `parent` | null \| string \| `[id1,id2]` | Parent handoff id(s) |
| `agent` | string | One of suffixes below |
| `status` | string | `completed` \| `blocked` \| `needs_discussion` |
| `summary` | string | One sentence: what was done + key artifact |
| `next_agent` | string \| null | Recommended next agent |
| `next_task` | string | Short imperative task for next agent |
| `next_priority` | string | `high` \| `medium` \| `low` |

All fields are flat scalars — no nested structures.

## Agent Suffixes

| Agent | Suffix | | Agent | Suffix |
|-------|--------|-|-------|--------|
| rust-architect | `architect` | | rust-debugger | `debug` |
| rust-developer | `developer` | | rust-critic | `critic` |
| rust-testing-engineer | `testing` | | rust-live-tester | `live-tester` |
| rust-performance-engineer | `performance` | | rust-researcher | `researcher` |
| rust-security-maintenance | `security` | | rust-cicd-devops | `cicd` |
| rust-code-reviewer | `review` | | | |

## On Startup

1. `TS=$(date +%Y-%m-%dT%H-%M-%S)`
2. Read `references/{agent}.md` for your output schema
3. If parent handoff(s) provided inline in task description — that gives routing metadata. Read full file body for detailed context: `cat .local/handoff/{id}.md`
4. For grandparent+ chain (frontmatter only): `awk 'BEGIN{n=0}/^---/{n++;if(n==2)exit}n==1&&!/^---/{print}' file.md`

## Before Finishing

1. `mkdir -p .local/handoff && HANDOFF_ID="${TS}-{agent}"`
2. Write `.local/handoff/${HANDOFF_ID}.md`:

~~~markdown
---
id: {HANDOFF_ID}
parent: {parent-id or null}
agent: {agent}
status: completed
summary: "One sentence: what was done + key artifact"
next_agent: {next or null}
next_task: ""
next_priority: high
---

## Context
{Task received + brief summary of parents — lets future agents skip ancestor reads.}

## Output
{Per references/{agent}.md schema.}
~~~

Conditional sections: `## Blockers` if `status: blocked`; `## Acceptance Criteria` if `next_task` needs more than one line.

3. Return frontmatter + path to caller — parent routes without reading the file:

~~~markdown
## Handoff
**File:** `.local/handoff/{HANDOFF_ID}.md`
**Frontmatter:**
```yaml
{the frontmatter block above}
```
~~~

## Status Values

| Status | Meaning | Next |
|--------|---------|------|
| `completed` | Done | Proceed to next agent |
| `blocked` | Cannot proceed | Describe in `## Blockers`, return to caller |
| `needs_discussion` | Decision needed | Return to user |

## Routing & Parallel Merge

Parent passes frontmatter inline in the next agent's task description — no file reads for routing. Full body reads happen only inside the agent needing detailed context. When multiple parents converge on one agent, set `parent: [id1, id2]` as inline array.
