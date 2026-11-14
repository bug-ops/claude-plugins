# SDD Integration Protocol

Governs how the live-tester and the researcher invoke the `sdd-orchestrator` agent to produce specification
documents before filing GitHub issues. arch-analyst and security-analyst file their findings directly with the templates of their own protocols; no sdd-orchestrator step applies to them. Every enhancement and research finding above the threshold below must have a
spec before it becomes an issue, and the issue carries that spec in its body.
The issue is the source of truth: `.local/` is gitignored, so a spec path alone
is unreadable for everyone else and is lost when a cloud or scheduled run ends.
The `.local/specs/` file is a local draft only.

---

## Threshold: When to Create a Spec

| Finding type | Priority | Spec required | SDD phases |
|---|---|---|---|
| Bug (any priority) | P0–P4 | No — the Issue Template already carries reproduction, expected, and actual behavior | — |
| Enhancement request | P0–P2 | Yes | specify + plan |
| Research / parity gap | P1–P2 | Yes | specify |
| Enhancement, research, or parity gap | P3–P4 | No — standard Issue Template | — |
| Cosmetic / one-liner / typo | P3–P4 | No | — |
| Dependency update (patch/minor) | P2–P3 | No | — |
| Dependency update (major) | P3–P4 | No | — |
| Dependency security advisory | P0–P1 | Yes | specify |

Each sdd-orchestrator spawn preloads about 1,200 lines of skills: spawn only where the table says Yes.

Where the sdd-orchestrator agent cannot be spawned (a background subagent run in which the Agent tool is unavailable, or the spawn fails), file the issue with the standard Issue Template and a `## Specification` section reading `Spec pending: sdd could not be spawned in this run`, record `—` in the journal Spec column, and never draft the spec inline.

---

## Invocation

Spawn the `sdd-orchestrator` agent as a subagent. Pass enough context so it can run
non-interactively — include the finding description, reproduction steps,
expected vs actual, and desired SDD phases.

### Template prompt

```
You are running in non-interactive mode as part of a live-testing, research, or CI session:
follow your Non-Interactive Mode. Do NOT ask clarifying questions — use the provided context to produce
the spec artifact(s) directly.

## Finding

**Type**: <bug | enhancement | research>
**Priority**: <P0–P4>
**Title**: <one-line summary>

**Description**:
<what was observed, why it matters>

**Reproduction / Evidence**:
<steps, log excerpts, test output>

**Expected behavior**:
<what should happen>

**Actual behavior**:
<what actually happened>

## Task

<Inside a CI cycle: Cycle mode — do not edit MOC-specs.md. Outside a cycle: add the MOC-specs.md entry even though the directory already exists.>

Run `/sdd specify <title>` to produce a spec.md in `.local/specs/<NNN>-<slug>/` (directory already created by the caller).
<If enhancement: then run `/sdd plan` on it; open markers go to its Risks / Open Questions.>

Use the Spec Template from the sdd skill. Pre-fill all sections from
the context above. Mark any missing information as
`[NEEDS CLARIFICATION: ...]` rather than blocking.

Report the path to the created spec file when done.
```

### Subagent call

```
Agent({
  subagent_type: "dev-agents:sdd-orchestrator",
  description: "Create spec for: <title>",
  prompt: <filled template above>
})
```

---

## Spec Naming

Claim the next spec number atomically, so parallel spawns never share one: `mkdir` fails when another agent holds the claim.

```bash
mkdir -p .local/specs
n=$(ls .local/specs | grep -E '^[0-9]{3}-' | sort | tail -1 | cut -c1-3)
n=$((10#${n:-0}))
until mkdir ".local/specs/.claim-$(printf '%03d' $((n+1)))" 2>/dev/null; do n=$((n+1)); done
printf '%03d\n' $((n+1))
```

Create `.local/specs/<NNN>-<slug>/` with that number, remove the claim with `rmdir .local/specs/.claim-<NNN>`, and pass the directory to the sdd-orchestrator agent.

Slug format: `NNN-<kebab-case-title>` (max 40 chars, no special chars).

Examples:
- `023-vault-key-rotation-panic`
- `024-streaming-response-truncation`
- `025-async-tool-call-parity`

---

## Research Findings

For research/parity gaps the spec captures WHAT capability is missing and WHY
it matters — not HOW to implement it. This is intentional: the HOW belongs in
a later `/sdd plan` session when the team decides to tackle it.

Research spec structure (use Spec Template, focus on these sections):
- **Problem Statement**: what gap exists and why it matters
- **User Stories**: who benefits and how
- **Functional Requirements**: what the system must do once gap is closed
- **Non-Functional Requirements**: performance, security constraints if known
- **See Also**: links to reference projects, papers, libraries that inspired the finding

---

## Output Contract

The subagent MUST:
1. Create `.local/specs/<NNN>-<slug>/spec.md` (and `plan.md` beside it for an enhancement)
2. Add an entry to `.local/specs/MOC-specs.md`, except inside a CI cycle (the prompt carries `Cycle mode:`), where the orchestrator adds the entries and the subagent leaves the file alone
3. Return the spec file path in its report

The originating agent MUST:
1. Extract the spec path from the subagent result and Read the spec
2. Embed the full spec content in the GitHub issue body under `## Specification`, and for an enhancement the `plan.md` content under `## Plan` (template below); never a bare path, because `.local/` is gitignored
3. Record the spec path alongside the finding — inside a CI cycle in the handoff `## Findings` row (the orchestrator writes `.local/testing/journal/ci-NNN.md`); standalone, in the session journal per [Testing Methodology](../../live-testing/references/testing-methodology.md#journal)

---

## Spec Authorship

The originating agent never drafts a spec inline: delegate to `sdd-orchestrator` and use the path it returns. Once the spec exists, file its implementation issue in the same pass (do not defer it to a later cycle) with the spec content embedded in the issue body. Record the issue number and the spec path together in the same journal Findings row (`Issue` and `Spec` columns).

---

## Issue Body Template (with spec)

```
## Description
<what was observed and why it matters>

## Reproduction Steps
1. ...
2. ...

## Expected Behavior
<...>

## Actual Behavior
<...>

## Environment
- Version: <commit or tag>
- Config: <test config>
- Features / build mode: <flags, env, build profile>

## Logs / Evidence
<excerpts>

## Specification

<details>
<summary>Spec: <title></summary>

<full content of .local/specs/<NNN>-<slug>/spec.md>

</details>

## Plan

<details>
<summary>Plan: <title></summary>

<full content of .local/specs/<NNN>-<slug>/plan.md; enhancements only, omit the section otherwise>

</details>
```

GitHub caps an issue body at 65,536 characters. When the spec and plan do not fit, put the overflow in the first issue comment and say so under its heading; `/dev-agents:solve-issue` fetches issue comments.

---

## Skipping Spec Creation

For findings that do not meet the threshold (cosmetic P3–P4, routine patch
updates), file the issue directly with the standard template from
[issue-management.md](issue-management.md). Do not spawn the sdd-orchestrator agent.
