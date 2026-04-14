# Team Debug Workflow

Step-by-step execution guide for multi-agent debug investigation.

## Overview

```
User (symptoms)
    ↓
[team-lead]
    ↓
[debugger] — root cause analysis
    ↓ (handoff)
[arch-reviewer] ─┐
[critic]         ├─ parallel review
[security]       ┘ (+ [perf] if performance symptoms)
    ↓ (all handoffs)
[reviewer] — consolidate findings
    ↓
  no_fixes_needed → present results to user
  fixes_required  → [debugger] fixes → [reviewer] re-review → repeat until approved
    ↓
Present results to user
User decides: commit / create issues / epic / hand off to team-develop
```

## Execution Rules

1. Each agent creates a handoff file via `rust-agent-handoff` skill and sends its **inline frontmatter block + path** to team-lead
2. Team-lead does NOT spawn the next agent until receiving the inline frontmatter from the current one
3. Team-lead accumulates all inline frontmatter blocks + paths and passes them to each subsequent agent
4. When multiple parallel agents run, team-lead waits for ALL of them before proceeding
5. **Shutdown agents immediately** after their task is complete — send `shutdown_request` as soon as the handoff is received and no further delegation is needed

## Step 1: Team Setup

```
ToolSearch("select:TaskCreate,TaskUpdate,TaskList,TaskGet,TeamCreate,TeamDelete,SendMessage")

TeamCreate({
  "team_name": "rust-debug-{issue-slug}",
  "description": "Debug: {symptom-summary}"
})
```

Create tasks upfront and set dependencies as defined in SKILL.md.

## Step 2: Spawn Debugger

```
Agent(
  description: "Debugger — root cause investigation",
  subagent_type: "rust-agents:rust-debugger",
  team_name: "rust-debug-{issue-slug}",
  name: "debugger",
  prompt: "<team communication template>\n\nBEFORE any other work: call Skill(skill: \"rust-agents:rust-agent-handoff\") and follow the protocol.\n\nInvestigate the following symptoms. Identify root cause(s), affected files/line ranges, reproduction path, and severity. Assess whether performance is implicated. Report only — do NOT apply fixes.\n\nSymptoms:\n{symptom-description}"
)
TaskUpdate(taskId: "investigate", owner: "debugger")
```

**WAIT** for debugger's handoff before proceeding.

## Step 3: Parallel Review

Evaluate whether performance symptoms are present. Then spawn all applicable reviewers simultaneously.

```
Agent(subagent_type: "rust-agents:rust-architect",           name: "arch-reviewer", ...)
Agent(subagent_type: "rust-agents:rust-critic",              name: "critic",        ...)
Agent(subagent_type: "rust-agents:rust-security-maintenance", name: "security",     ...)
# conditional:
Agent(subagent_type: "rust-agents:rust-performance-engineer", name: "perf",        ...)
```

**WAIT for ALL active reviewers** before proceeding.

## Step 4: Consolidation

```
Agent(
  subagent_type: "rust-agents:rust-code-reviewer",
  name: "reviewer",
  prompt: "<team communication template>\n\nConsolidate findings. Verdict must be 'fixes_required' or 'no_fixes_needed'.\n\nHandoffs:\n{all accumulated handoffs}"
)
```

**WAIT** for reviewer's handoff. Check `status` in inline frontmatter.

## Step 5: Fix-Review Cycle (if fixes_required)

```
SendMessage(to: "debugger", content: "Apply fixes per consolidated report...")
# WAIT for debugger fix handoff
SendMessage(to: "reviewer", content: "Re-review after fixes...")
# WAIT for reviewer re-review handoff
# Repeat until status: approved
```

## Step 6: Present Results

Compile structured report (see SKILL.md Step 7). Ask user before creating issues, epics, or commits.

## Step 7: Shutdown

```
SendMessage(type: "shutdown_request", to: "{each agent}", content: "Task complete")
# Wait for shutdown_response from each
TeamDelete()
```
