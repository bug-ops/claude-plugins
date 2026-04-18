# SDD Integration Protocol

Governs how the CI analyst invokes the `sdd` agent to produce specification
documents before filing GitHub issues. Every non-trivial finding must have a
spec before it becomes an issue — the spec is the source of truth; the issue
is a pointer to it.

---

## Threshold: When to Create a Spec

| Finding type | Priority | Spec required | SDD phases |
|---|---|---|---|
| Bug — broken core / data loss | P0 | Yes | specify |
| Bug — degraded UX / incorrect behavior | P1 | Yes | specify |
| Bug — suboptimal / minor inconsistency | P2 | Yes | specify |
| Enhancement request | P2–P3 | Yes | specify + plan |
| Research / parity gap | P4 | Yes | specify |
| Cosmetic / one-liner / typo | P3–P4 | No | — |
| Dependency update (patch/minor) | P2–P3 | No | — |
| Dependency update (major / security) | P0–P1 | Yes | specify |

When in doubt, prefer creating a spec. Specs are cheap; missing context is expensive.

---

## Invocation

Spawn the `sdd` agent as a subagent. Pass enough context so it can run
non-interactively — include the finding description, reproduction steps,
expected vs actual, and desired SDD phases.

### Template prompt

```
You are running in non-interactive mode as part of a CI cycle.
Do NOT ask clarifying questions — use the provided context to produce
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

Run `/sdd specify <title>` to produce a spec.md in `.local/specs/`.
<If enhancement: also run `/sdd plan` after spec is confirmed.>

Use the Spec Template from the sdd skill. Pre-fill all sections from
the context above. Mark any missing information as
`[NEEDS CLARIFICATION: ...]` rather than blocking.

Respond with the path to the created spec file when done.
```

### Subagent call

```
Agent({
  subagent_type: "rust-agents:sdd",
  description: "Create spec for: <title>",
  prompt: <filled template above>
})
```

---

## Spec Naming

Determine the next spec number by scanning `.local/specs/` directories:

```bash
ls .local/specs/ | grep -E '^[0-9]{3}-' | sort | tail -1
```

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
- **See Also**: links to reference projects, papers, crates that inspired the finding

---

## Output Contract

The subagent MUST:
1. Create `.local/specs/<NNN>-<slug>/spec.md`
2. Add an entry to `.local/specs/MOC-specs.md`
3. Return the spec file path in its final message

The CI analyst MUST:
1. Extract the spec path from the subagent result
2. Include `Spec: <path>` in the GitHub issue body
3. Record the spec path in `.local/testing/journal.md` alongside the finding

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
- Features: <flags>

## Logs / Evidence
<excerpts>

## Spec
.local/specs/<NNN>-<slug>/spec.md
```

---

## Skipping Spec Creation

For findings that do not meet the threshold (cosmetic P3–P4, routine patch
updates), file the issue directly with the standard template from
[issue-management.md](issue-management.md). Do not spawn the sdd agent.
