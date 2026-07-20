---
name: rust-agent-handoff
description: Handoff protocol for Rust multi-agent system. Subagents communicate via Markdown+frontmatter files in .local/handoff/. ALWAYS read on agent startup.
---

# Rust Agent Handoff Protocol

Subagents work in isolated context. This protocol enables communication via Markdown+frontmatter files.

## File Path

`.local/handoff/{TS}-{agent}.md` where `TS=$(date +%Y-%m-%dT%H-%M-%S)` and `{agent}` is your suffix:

`architect` · `developer` · `testing` · `performance` · `security` · `review` · `cicd` · `debug` · `critic` · `live-tester` · `researcher` · `arch-analyst` · `security-analyst`

## On Startup

1. `TS=$(date +%Y-%m-%dT%H-%M-%S)`
2. Read `references/{agent}.md` for your Output schema. Exception: `arch-analyst` and `security-analyst` take their Output schema from their audit skill (`arch-inspect` / `security-audit`) — skip this read.
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
---

## Context
{<=2 sentences: constraints or decisions the next agent cannot get from the frontmatter chain. Do NOT restate the task or parent summaries.}

## Output
{Per references/{agent}.md schema.}
~~~

Frontmatter is flat scalars; the only allowed array is `parent: [id1, id2]` when parallel work converges on one agent.

Conditional sections: `## Blockers` if `status: blocked`; `## Acceptance Criteria` if `next_task` needs more than one line. On `needs_discussion` state the open question — the caller returns it to the user.

3. Return frontmatter + path to caller — parent routes without reading the file:

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
