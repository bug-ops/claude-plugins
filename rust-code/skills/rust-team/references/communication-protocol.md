# Communication Protocol

Agent-to-agent communication rules for Rust development teams.

## Message Types

- **message** (default) — direct message to a specific teammate
- **broadcast** — message to ALL teammates (use only for critical blockers)

**Principle**: any agent can message any other agent when needed. The matrices below show TYPICAL flows, not restrictions.

## Code and Commit Ownership

- **Only developer modifies code** — all other agents (architect, critic, tester, perf, security, reviewer, debugger) analyze and report findings but NEVER edit source files. When issues are found, agents message developer who applies the changes.
- **Only teamlead commits** — no other agent runs git add, git commit, git push, or gh pr create. Teamlead creates commits and PRs after re-review approval.

## Primary Communication Matrix

Mandatory flows that define the core workflow:

| From | To | Content | When |
|------|----|---------|------|
| teamlead | architect | Task + feature description | Start |
| architect | teamlead | Architecture plan, handoff file path | Plan complete |
| teamlead | critic | Task + architect handoff file path | After architect (optional) |
| critic | teamlead | Critique report, handoff file path | Critique complete |
| critic | architect | Critical/significant gaps found | If redesign needed |
| architect | developer | Type designs, module structure, patterns | After planning |
| teamlead | developer | Task + architect handoff file path | After architect |
| developer | teamlead | Implementation status, handoff file path | Complete/blocked |
| developer | tester | Implementation details, test hints | After implementing |
| developer | perf | Hot paths, allocation patterns | After implementing |
| developer | security | Unsafe blocks, input handling | After implementing |
| tester | teamlead | Coverage results, handoff file path | Validation complete |
| perf | teamlead | Performance findings, handoff file path | Validation complete |
| security | teamlead | Vulnerability report, handoff file path | Validation complete |
| reviewer | teamlead | Review verdict, handoff file path | Review complete |
| reviewer | developer | Code feedback, fix requests | During review |
| developer | reviewer | Fix confirmations | During fixes |

## Cross-Consultation Flows

Agents consult peers for expertise as needed:

| From | To | Content | When |
|------|----|---------|------|
| architect | security | Security constraints, compliance | During design |
| architect | perf | Performance-critical paths, bottlenecks | During design |
| architect | debugger | Known failure patterns, fragile areas | During design |
| architect | cicd | Deployment constraints, build requirements | During design |
| tester | security | Security test scenarios, fuzzing targets | During validation |
| tester | developer | Failing tests, reproduction steps | If issues found |
| perf | developer | Optimization suggestions, hot spots | If issues found |
| security | developer | Vulnerability fixes, severity levels | If issues found |
| reviewer | architect | Design concerns, architectural issues | During review |
| debugger | architect | Root cause is architectural | After analysis |
| debugger | perf | Performance-related failures | After analysis |
| cicd | developer | Build failures, dependency issues | If CI fails |
| cicd | security | Supply chain concerns, dependency alerts | If vulnerabilities |

## Teammate Discovery

Read `~/.claude/teams/{team-name}/config.json` to find teammates by name.

## Guidelines

- Keep messages concise and actionable
- Include file paths and line numbers
- Reference handoff files when available (`.local/handoff/`)
- Use `message` for all routine communication
- Reserve `broadcast` for critical blockers only

## Team Communication Template

Include this in every agent spawn prompt:

```
You are operating as a teammate in a Rust agent team.

## Team Context
- Team: {team-name}
- Your role: {agent-role}
- Team config: ~/.claude/teams/{team-name}/config.json

## Task Management
0. FIRST: call ToolSearch("select:TaskCreate,TaskUpdate,TaskList,TaskGet") to load task tool schemas
1. Check TaskList for your assigned task
2. TaskUpdate(status: "in_progress") when starting
3. TaskUpdate(status: "completed") when done
4. Check TaskList for next available task

## Communication
- Send results to teamlead: SendMessage(type: "message", recipient: "teamlead", content: "...", summary: "...")
- Message specific agents: SendMessage(type: "message", recipient: "{name}", content: "...", summary: "...")
- Never use broadcast for routine updates
- Include file paths and line numbers in messages
- Respond to shutdown_request with shutdown_response(approve: true)

## Code Ownership Rules
- Only developer edits source files. All other agents analyze and report only.
- Only teamlead creates commits and PRs. No other agent runs git commit or gh pr.

## Handoff Protocol (MANDATORY)

Execute these steps **in exact order** before any other work:

### Step 1 — Load handoff skill
```
Skill(skill: "rust-agents:rust-agent-handoff")
```
This loads the full protocol. Read it completely.

### Step 2 — Capture timestamp
```bash
TS=$(date +%Y-%m-%dT%H-%M-%S) && echo "TS=$TS"
```
Save this value — you will use it to name your handoff file.

### Step 3 — Read your agent output schema
```bash
cat "references/<your-agent>.md"
```
See the handoff skill for the mapping of agent name → references file.

### Step 4 — Read provided handoff(s)
If handoff paths were given in your task, read each one with `cat <path>` before starting work.

### On completion — Write handoff YAML
Before sending any message to teamlead, write your handoff file:
```bash
mkdir -p .local/handoff
# File: .local/handoff/${TS}-<agent>.yaml
# id field inside MUST equal filename without .yaml
```
Then include the handoff file path in your message to teamlead.
```
