---
name: rust-agent-handoff
description: Handoff protocol for Rust multi-agent development system. Use when working as rust-architect, rust-developer, rust-testing-engineer, rust-performance-engineer, rust-security-maintenance, rust-code-reviewer, rust-cicd-devops, rust-debugger, or rust-critic. ALWAYS read on agent startup.
---

# Rust Agent Handoff Protocol

Subagents work in **isolated context**. This protocol enables communication through Markdown+frontmatter files and inline frontmatter passing.

## File Location

```
.local/handoff/{id}.md    where id = {timestamp}-{agent}
```

Example: `.local/handoff/2025-01-09T14-30-45-architect.md`

## Frontmatter Schema

All fields are flat scalars — no nested structures in frontmatter.

| Field | Type | Description |
|-------|------|-------------|
| `id` | string | `{timestamp}-{agent}` — must match filename (without `.md`) |
| `parent` | null \| string \| `[id1,id2]` | Parent handoff id(s) |
| `agent` | string | See agent identifiers below |
| `status` | string | `completed` \| `blocked` \| `needs_discussion` |
| `summary` | string | One sentence: what was done and key artifact produced |
| `next_agent` | string \| null | Recommended next agent (`null` if done) |
| `next_task` | string | Short imperative task for next agent |
| `next_priority` | string | `high` \| `medium` \| `low` |

## Body Sections

**Required in every handoff:**

- `## Context` — task received, key constraints, brief summary of what parents produced (enables future agents to skip reading ancestor files)
- `## Output` — agent-specific content per `references/{agent}.md`

**Conditional:**

- `## Blockers` — only if `status: blocked`; what is blocking and what is needed
- `## Acceptance Criteria` — only if `next_task` needs more detail than one line

## Agent Identifiers

| Agent | Suffix |
|-------|--------|
| rust-architect | `architect` |
| rust-developer | `developer` |
| rust-testing-engineer | `testing` |
| rust-performance-engineer | `performance` |
| rust-security-maintenance | `security` |
| rust-code-reviewer | `review` |
| rust-cicd-devops | `cicd` |
| rust-debugger | `debug` |
| rust-critic | `critic` |

---

## On Startup — Always (in order)

### Step 1. Capture timestamp

```bash
TS=$(date +%Y-%m-%dT%H-%M-%S)
```

### Step 2. Read your output schema

```bash
cat "references/{agent}.md"
```

### Step 3. Read provided handoff(s)

**If frontmatter was passed inline in your task description** — that gives you routing metadata immediately. Still read the full file body for detailed context:

```bash
cat ".local/handoff/{provided-id}.md"
```

**For grandparent+ chain traversal — read frontmatter only** (10 lines vs full file):

```bash
# Extract only frontmatter from a handoff file
awk 'BEGIN{n=0}/^---/{n++;if(n==2)exit}n==1&&!/^---/{print}' ".local/handoff/${ID}.md"

# Extract parent id (handles both scalar and inline array)
grep '^parent:' ".local/handoff/${ID}.md" | sed 's/parent: *//; s/\[//g; s/\]//g; s/,/ /g' | tr -d '"'
# Returns: "null"  OR  "id1"  OR  "id1 id2"
```

**If no handoff provided:** start fresh.

---

## Before Finishing — Always (in order)

### Step 1. Write handoff file

```bash
[ -z "$TS" ] && TS=$(date +%Y-%m-%dT%H-%M-%S)
HANDOFF_ID="${TS}-{agent}"
mkdir -p .local/handoff
```

Write `.local/handoff/${HANDOFF_ID}.md` with this structure:

~~~markdown
---
id: {HANDOFF_ID}
parent: null
agent: {agent}
status: completed
summary: "One sentence: what was done and key artifact"
next_agent: null
next_task: ""
next_priority: high
---

## Context

{Describe the task received and summarize relevant output from parents.
Write enough so future agents can skip reading ancestor files.}

## Output

{Agent-specific content per references/{agent}.md}
~~~

### Step 2. Return frontmatter + path to caller

If `status: blocked` or `status: needs_discussion` — describe the reason in plain text **before** the Handoff block. The parent makes routing decisions from the response text alone; it will not read the handoff file.

End your response with this block:

~~~markdown
## Handoff

**File:** `.local/handoff/{HANDOFF_ID}.md`

**Frontmatter:**
```yaml
id: {HANDOFF_ID}
parent: {parent-id or null}
agent: {agent}
status: {status}
summary: "{summary}"
next_agent: {next_agent or null}
next_task: "{next_task}"
next_priority: {next_priority}
```
~~~

---

## Parent Agent: Calling the Next Agent

Pass the frontmatter **inline** in the task description — the next agent orients immediately without reading the file:

```
Task for rust-developer:

"Implement auth module per architecture spec."

Incoming handoff:
---
id: 2025-01-09T14-30-45-architect
summary: "Designed JWT auth with separated AuthService; 3 modules in src/auth/"
next_task: "Implement src/auth/ per ## Output in handoff"
---
File: .local/handoff/2025-01-09T14-30-45-architect.md
```

The next agent reads the file for detailed context but already knows what to do from the inline frontmatter.

---

## Communication Model

```
Parent Agent
    │
    ├─► Task(rust-architect): "Design system"
    │       ↓ works → writes .local/handoff/{id}-architect.md
    │       ↓ returns: ## Handoff block (frontmatter + path)
    │
    ├─► receives frontmatter inline — no file I/O for routing
    │
    ├─► Task(rust-developer): "Implement.\nIncoming handoff:\n---\n{frontmatter}\n---\nFile: {path}"
    │       ↓ reads inline frontmatter for orientation
    │       ↓ reads full file body for detailed context
    │       ↓ returns: ## Handoff block (frontmatter + path)
    │
    └─► ...
```

**Key:** Parent never reads handoff files — it passes frontmatter between agents. Full file reads happen only inside the agent that needs detailed context.

---

## Status Values

| Status | Meaning | Next action |
|--------|---------|-------------|
| `completed` | Work done | Proceed to next agent |
| `blocked` | Cannot proceed | Return to caller; describe blocker in `## Blockers` |
| `needs_discussion` | Decision needed | Return to user for input |

---

## Workflow Examples

### Linear flow

```
architect → developer → testing → review → cicd
```

Each agent reads full body of direct parent + frontmatter-only of ancestors.

### Bug fix

```
debugger → developer → testing → review
```

### Parallel merge

```
architect
    ├─► developer  (returns handoff B)
    └─► testing    (strategy; returns handoff C)
         ↓
    testing: "Implement tests."
             parent: [B-id, C-id]  ← inline array in frontmatter
```
