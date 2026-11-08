---
name: agent-handoff
description: Handoff protocol for the dev-agents multi-agent system. Subagents communicate via Markdown+frontmatter files in .local/handoff/. ALWAYS read on agent startup.
---

# Agent Handoff Protocol

Subagents work in isolated context. This protocol enables communication via Markdown+frontmatter files.

## File Path

`.local/handoff/{TS}-{agent}.md` where `TS=$(date +%Y-%m-%dT%H-%M-%S)` and `{agent}` is your suffix:

`architect` · `developer` · `testing` · `performance` · `security` · `review` · `cicd` · `debug` · `critic` · `live-tester` · `researcher` · `arch-analyst` · `security-analyst`

## On Startup

1. `TS=$(date +%Y-%m-%dT%H-%M-%S)`
2. Read `${CLAUDE_SKILL_DIR}/references/{agent}.md` for your Output schema. Exception: `arch-analyst` and `security-analyst` take their Output schema from their audit skill (`arch-inspect` / `security-audit`) — skip this read.
3. Parent handoff frontmatter arrives inline in your task description — that is routing metadata. Read a full body only when you need detailed context: `cat .local/handoff/{id}.md`
4. For grandparent+ chain read frontmatter only: `awk 'BEGIN{n=0}/^---/{n++;if(n==2)exit}n==1&&!/^---/{print}' file.md`

## Before Finishing

1. `mkdir -p .local/handoff && HANDOFF_ID="${TS}-{agent}"`
2. Write `.local/handoff/${HANDOFF_ID}.md`:

~~~markdown
---
id: {HANDOFF_ID}
parent: {parent-id | [id1, id2] | null}
agent: {suffix}
status: {completed | blocked | needs_discussion}
summary: "One sentence: what was done + key artifact"
next_agent: {suffix | null}
next_task: "Short imperative task, or empty"
follow_ups: {number of Follow-ups entries, 0 when none}
---

## Context
Stack: {profiles and reference files read, per the stack skill — e.g. `rust (toolchain, developer)`; omit for agents that do not load stack}
{<=2 sentences: constraints or decisions the next agent cannot get from the frontmatter chain. Do NOT restate the task or parent summaries.}

## Output
{Per references/{agent}.md schema.}
~~~

Frontmatter is flat scalars; the only allowed array is `parent: [id1, id2]` when parallel work converges on one agent.

Conditional sections: `## Blockers` if `status: blocked`; `## Acceptance Criteria` if `next_task` needs more than one line; `## Follow-ups` if `follow_ups` is above 0. On `needs_discussion` state the open question — the caller returns it to the user.

### Follow-ups

Work outside this task's scope that must not be lost: a defect you found, a capability the code needs but the task does not cover, tech debt, or a `TODO` marker you placed in code. Every `TODO`/`FIXME` you add has an entry. One entry per item:

`F1` — `defect | enhancement | tech-debt | todo | security` — `file:line` — what is wrong or missing — evidence (failing input, command, log line) — expected vs. actual (defects) — why it is outside this task — suggested priority `P0`–`P4`

In `team-develop` and `team-debug` runs you never file issues yourself: the lead collects every handoff with `follow_ups` above 0, the critic checks each entry against the evidence and the declared architecture, plan, and spec, and the reviewer files the confirmed ones (in `team-debug`, which has no critic, the reviewer checks them and files after the user approves). Record only what you can back with evidence or a reference — an unsupported entry is rejected. Agents with their own filing protocol (`live-tester`, `researcher`, `arch-analyst`, `security-analyst`) keep it only in standalone and `continuous-improvement` runs. An item that blocks your own task is not a follow-up — hand off with `status: blocked`. Additions the critic asked to remove are not follow-ups unless the user chose to keep the idea for later.

3. Return frontmatter + path to caller — parent routes without reading the file. The block goes where your caller reads results: `SendMessage` to the lead when you are a teammate, the `SubagentHandback` call when you have that tool, otherwise your final message:

~~~markdown
## Handoff
**File:** `.local/handoff/{HANDOFF_ID}.md`
**Frontmatter:**
```yaml
{the frontmatter block above}
```
~~~

## Compactness Rules

Every handoff body is re-read by downstream agents — each extra line costs tokens on every read:

- Never restate the task, parent summaries, or anything the frontmatter chain already carries.
- Never list what `git diff` shows: no function/test name listings, no code snippets. Counts + paths + one-line descriptions. Exception: debugger — the fix snippet IS the payload.
- Omit empty or inapplicable sections entirely. No decorative estimates or filler prose.
- Aim for <=40 lines of body; never pad.
