# Communication Protocol

Agent-to-agent communication rules for Rust development teams.

## Messaging

Every message is a direct message to one recipient. `SendMessage(to, message, summary)` delivers to a single teammate by name, or to the lead as `to: "main"`. There is no broadcast — to reach several teammates, send one message per recipient. Messages are delivered automatically; recipients do not poll an inbox.

**Principle**: any agent can message any other agent when needed. The matrices below show TYPICAL flows, not restrictions.

## Code and Commit Ownership

- **Only developer modifies code** — all other agents (architect, critic, tester, perf, security, reviewer, debugger) analyze and report findings but NEVER edit source files. When issues are found, agents message developer who applies the changes.
- **Only team-lead commits** — no other agent runs git add, git commit, git push, or gh pr create. Teamlead creates commits and PRs after re-review approval.

## Primary Communication Matrix

Mandatory flows that define the core workflow:

| From | To | Content | When |
|------|----|---------|------|
| team-lead | architect | Task + feature description | Start |
| architect | team-lead | Architecture plan, **inline frontmatter + handoff path** | Plan complete |
| team-lead | critic | Task + architect inline frontmatter + handoff path | After architect (optional) |
| critic | team-lead | Critique report, **inline frontmatter + handoff path** | Critique complete |
| critic | architect | Critical/significant gaps found | If redesign needed |
| architect | developer | Type designs, module structure, patterns | After planning |
| team-lead | developer | Task + accumulated inline frontmatters + handoff paths | After architect |
| developer | team-lead | Implementation status, **inline frontmatter + handoff path** | Complete/blocked |
| developer | tester | Implementation details, test hints | After implementing |
| developer | perf | Hot paths, allocation patterns | After implementing |
| developer | security | Unsafe blocks, input handling | After implementing |
| tester | team-lead | Coverage results, **inline frontmatter + handoff path** | Validation complete |
| perf | team-lead | Performance findings, **inline frontmatter + handoff path** | Validation complete |
| security | team-lead | Vulnerability report, **inline frontmatter + handoff path** | Validation complete |
| reviewer | team-lead | Review verdict, **inline frontmatter + handoff path** | Review complete |
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
- All completion messages to the lead **must include the inline frontmatter block** — the lead routes from it without reading files
- Send a direct message per recipient; there is no broadcast

## Team Communication Template

Include this in every agent spawn prompt:

```
You are operating as a teammate in a Rust agent team.

## Team Context
- Your role: {agent-role}
- Team config: ~/.claude/teams/{team-name}/config.json (team name is session-derived)

## Task Management
0. FIRST: call ToolSearch("select:TaskCreate,TaskUpdate,TaskList,TaskGet") to load task tool schemas
1. Check TaskList for your assigned task
2. TaskUpdate(status: "in_progress") when starting
3. TaskUpdate(status: "completed") when done
4. Check TaskList for next available task

## Communication
- Send results to the lead: SendMessage(to: "main", message: "...", summary: "...")
- Message specific agents: SendMessage(to: "{name}", message: "...", summary: "...")
- Include file paths and line numbers in messages
- Respond to a shutdown_request with SendMessage(to: "main", message: {type: "shutdown_response", request_id: "<echo the request_id>", approve: true})

## Code Ownership Rules
- Only developer edits source files. All other agents analyze and report only.
- Only team-lead creates commits and PRs. No other agent runs git commit or gh pr.

## Handoff Protocol (MANDATORY)

BEFORE any other work: call `Skill(skill: "rust-agents:rust-agent-handoff")` and follow the protocol (the skill defines your suffix).

Before sending any message to the lead: write your handoff file and include the **inline frontmatter block + file path** in your message content.
```
