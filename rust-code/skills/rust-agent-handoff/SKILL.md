---
name: rust-agent-handoff
description: Handoff protocol for Rust multi-agent development system. Use when working as rust-architect, rust-developer, rust-testing-engineer, rust-performance-engineer, rust-security-maintenance, rust-code-reviewer, rust-cicd-devops, rust-debugger, or rust-critic. ALWAYS read on agent startup.
---

# Rust Agent Handoff Protocol

Subagents work in **isolated context** — they cannot see each other's conversations. This protocol enables structured communication through flat YAML files.

## Directory Structure

```
.local/
└── handoff/
    ├── 2025-01-09T14-30-45-architect.yaml
    ├── 2025-01-09T15-00-00-developer.yaml
    └── ...
```

## File Naming Convention

> [!IMPORTANT]
> **Filename MUST equal `{id}.yaml`** - The handoff file name must exactly match the `id` field inside the YAML file.

**Format:** `{id}.yaml` where `id = {timestamp}-{agent}`

**Example:**
- Handoff id: `2025-01-09T14-30-45-architect`
- Filename: `2025-01-09T14-30-45-architect.yaml`

| Agent | Agent suffix in id |
|-------|-------------------|
| rust-architect | `architect` |
| rust-developer | `developer` |
| rust-testing-engineer | `testing` |
| rust-performance-engineer | `performance` |
| rust-security-maintenance | `security` |
| rust-code-reviewer | `review` |
| rust-cicd-devops | `cicd` |
| rust-debugger | `debug` |
| rust-critic | `critic` |

## Communication Model

```
Parent Agent (or User)
    │
    ├── Task(rust-architect): "Design system"
    │       ↓
    │   rust-architect executes
    │       - reads handoff if path provided
    │       - does work
    │       - writes handoff file
    │       - RETURNS result with handoff path
    │       ↓
    ├── receives result, reads handoff path
    │
    ├── Task(rust-developer): "Implement. Handoff: <path>"
    │       ↓
    │   rust-developer executes
    │       ...
```

**Key point:** Subagents cannot call each other directly. They return results to parent, who orchestrates the next call.

## On Startup — ALWAYS

Execute these steps **in order** before any other work:

### Step 1 — Capture timestamp

```bash
TS=$(date +%Y-%m-%dT%H-%M-%S)
echo "Timestamp: $TS"
```

Save `$TS` — you will use it to name your handoff file later.

### Step 2 — Read your agent-specific output schema

```bash
cat "references/<agent>.md"  # e.g. references/architect.md
```

This tells you the exact YAML structure your handoff `output:` section must follow.

### Step 3 — Read provided handoff(s)

**If handoff file path(s) provided in task description:**

Single handoff:
```bash
cat <provided-path>
```

Multiple handoffs (when merging contexts):
```bash
cat <path1>
cat <path2>
# ...
```

Then read the parent chain to understand the full context:

```bash
PARENT_ID=$(grep '^parent:' <provided-path> | awk '{print $2}' | tr -d '"')
if [ "$PARENT_ID" != "null" ] && [ -n "$PARENT_ID" ]; then
  cat ".local/handoff/${PARENT_ID}.yaml"
fi
```

Check for `output.spec` in the chain — if present, read the spec file too.

**If no handoff provided:**
Start fresh — this is a new task.

## Before Finishing — ALWAYS:

### 1. Write Handoff File

> [!IMPORTANT]
> **Filename MUST equal `{id}.yaml`** - Use `$TS` from startup to construct both the id and filename.

```bash
# Ensure TS variable is set (get new timestamp if empty)
if [ -z "$TS" ]; then
  TS=$(date +%Y-%m-%dT%H-%M-%S)
  echo "⚠️  TS was empty, generated new timestamp: $TS"
fi

# Construct handoff id (used BOTH as id field AND filename prefix)
HANDOFF_ID="${TS}-<agent>"  # e.g., "2025-01-09T14-30-45-architect"

# Write handoff file: filename = {id}.yaml
mkdir -p .local/handoff
cat > ".local/handoff/${HANDOFF_ID}.yaml" << EOF
id: ${HANDOFF_ID}
parent: <parent-id-or-null>
agent: <agent>
timestamp: "$(date -u +%Y-%m-%dT%H:%M:%S)"
status: completed

# ... rest of YAML content
EOF
```

**Key points:**
- Filename: `.local/handoff/{id}.yaml`
- id field inside YAML: `{id}` (exact same value, no `.yaml` extension)
- Example: File `2025-01-09T14-30-45-architect.yaml` contains `id: 2025-01-09T14-30-45-architect`

### 2. Return Handoff Path to Caller

End your response with clear handoff information:

```
## Handoff

**Status:** completed
**Handoff file:** `.local/handoff/2025-01-09T14-30-45-architect.yaml`
**Recommended next:** rust-developer
**Task for next agent:** Implement Email and User types per architecture spec
```

The parent agent will use this to orchestrate the next step.

## Base Schema (All Agents)

> [!NOTE]
> For file `.local/handoff/2025-01-09T14-30-45-architect.yaml`, the `id` field MUST be `2025-01-09T14-30-45-architect` (filename without `.yaml` extension)

```yaml
id: 2025-01-09T14-30-45-architect  # MUST match filename (without .yaml)
parent: 2025-01-09T14-00-00-developer  # Single source, or null if fresh start
# parent: [2025-01-09T14-00-00-developer, 2025-01-09T13-30-00-architect]  # Multiple sources (array)
agent: architect  # architect | developer | testing | performance | security | review | cicd | debug | critic
timestamp: "2025-01-09T14:30:45"
status: completed  # completed | blocked | needs_discussion

context:
  task: "Original task description"
  phase: "01"  # optional phase number

output:
  # Agent-specific output (see schemas below)

next:  # Recommendation for parent agent
  agent: rust-developer  # suggested next agent, or null if done
  task: "Task description for next agent"
  priority: high  # high | medium | low
  acceptance_criteria:
    - "Criterion 1"
    - "Criterion 2"
```

## Agent-Specific Output Schemas

Each agent has a specific output schema. Read the references file for your agent:

| Agent | references File |
|-------|----------------|
| rust-architect | [references/architect.md](references/architect.md) |
| rust-developer | [references/developer.md](references/developer.md) |
| rust-testing-engineer | [references/testing.md](references/testing.md) |
| rust-performance-engineer | [references/performance.md](references/performance.md) |
| rust-security-maintenance | [references/security.md](references/security.md) |
| rust-code-reviewer | [references/review.md](references/review.md) |
| rust-cicd-devops | [references/cicd.md](references/cicd.md) |
| rust-debugger | [references/debug.md](references/debug.md) |
| rust-critic | [references/critic.md](references/critic.md) |



## Workflow Examples

### New Project Flow (Parent Orchestrates)

```
Parent Agent
    │
    ├─► Task(rust-architect): "Design user system"
    │   └─► returns: handoff A
    │
    ├─► Task(rust-developer): "Implement. Handoff: A"
    │   └─► returns: handoff B
    │
    ├─► Task(rust-testing-engineer): "Add tests. Handoff: B"
    │   └─► returns: handoff C
    │
    ├─► Task(rust-code-reviewer): "Review. Handoff: C"
    │   └─► returns: handoff D (approved)
    │
    └─► Task(rust-cicd-devops): "Setup CI. Handoff: D"
        └─► returns: handoff E (done)
```

### Bug Fix Flow

```
Parent Agent
    │
    ├─► Task(rust-debugger): "Investigate crash"
    │   └─► returns: handoff with root cause
    │
    ├─► Task(rust-developer): "Fix bug. Handoff: ..."
    │   └─► returns: handoff with fix
    │
    ├─► Task(rust-testing-engineer): "Add regression test. Handoff: ..."
    │   └─► returns: handoff with tests
    │
    └─► Task(rust-code-reviewer): "Review fix. Handoff: ..."
        └─► returns: approved
```

### Review Iteration

```
Parent Agent
    │
    ├─► Task(rust-code-reviewer): "Review PR"
    │   └─► returns: changes_requested, issues list
    │
    ├─► Task(rust-developer): "Fix review issues. Handoff: ..."
    │   └─► returns: fixes applied
    │
    └─► Task(rust-code-reviewer): "Re-review. Handoff: ..."
        └─► returns: approved
```

### Parallel Work Merge

```
Parent Agent
    │
    ├─► Task(rust-architect): "Design API"
    │   └─► returns: handoff A
    │
    ├─► [Parallel] Task(rust-developer): "Implement API. Handoff: A"
    │   │         Task(rust-testing-engineer): "Design test strategy. Handoff: A"
    │   │
    │   └─► returns: handoff B (implementation)
    │       returns: handoff C (test strategy)
    │
    └─► Task(rust-testing-engineer): "Implement tests. Handoff: [B, C]"
        └─► parent: [handoff-B-id, handoff-C-id]
```

## Response Format (Return to Parent)

When finishing, structure your response so parent can easily extract handoff info:

```markdown
## Summary

[Brief description of what was done]

## Work Completed

- [Item 1]
- [Item 2]

## Handoff

| Field | Value |
|-------|-------|
| Status | `completed` / `blocked` / `needs_discussion` |
| Handoff file | `.local/handoff/2025-01-09T14-30-45-developer.yaml` |
| Recommended next | `rust-testing-engineer` (or `none` if done) |
| Task for next | Add unit tests for Email and User types |
```

Parent agent parses this to decide next step.

## Status Values

| Status | Meaning | Next Action |
|--------|---------|-------------|
| `completed` | Work done successfully | Proceed to next agent |
| `blocked` | Cannot proceed | Return to caller with blocker |
| `needs_discussion` | Decisions needed | Return to user for input |

## Best Practices

1. **Always write handoff file** before finishing, even if blocked
2. **Always return handoff path** in your response to parent
3. **Include acceptance criteria** for recommended next agent
4. **references file paths** created/modified
5. **Keep summaries concise** — details in specific fields
6. **Read provided handoff(s)** first thing on startup
7. **Read parent chain** to understand full context (see example below)
8. **Don't assume next agent** — parent decides orchestration
9. **Multiple parents** — Use array when merging contexts from parallel work or multiple sources
10. **When reading multiple handoffs** — Synthesize information, note conflicts in your output

### Reading Parent Chain Example

```bash
# Read the provided handoff
CURRENT_HANDOFF=".local/handoff/2025-01-09T15-00-00-developer.yaml"
cat "$CURRENT_HANDOFF"

# Extract and read parent (simple approach)
PARENT_ID=$(grep '^parent:' "$CURRENT_HANDOFF" | awk '{print $2}' | tr -d '" ')
if [ "$PARENT_ID" != "null" ] && [ -n "$PARENT_ID" ]; then
  echo "Reading parent context..."
  cat ".local/handoff/${PARENT_ID}.yaml"

  # Can continue recursively if needed
  GRANDPARENT_ID=$(grep '^parent:' ".local/handoff/${PARENT_ID}.yaml" | awk '{print $2}' | tr -d '" ')
  if [ "$GRANDPARENT_ID" != "null" ] && [ -n "$GRANDPARENT_ID" ]; then
    cat ".local/handoff/${GRANDPARENT_ID}.yaml"
  fi
fi
```

This helps you understand the full decision chain and context from previous agents.
