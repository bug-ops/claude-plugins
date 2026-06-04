---
name: team-develop
description: "Orchestrate Rust development using agent teams with peer-to-peer communication. Use when: 'create rust team', 'start team development', 'launch agent team', 'team workflow', 'collaborative development'. Requires rust-agents plugin and CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1."
argument-hint: "[task-description]"
---

# Team Develop Orchestration

You act as **team lead**. Coordinate specialist agents to implement the task.

**Task**: $ARGUMENTS

> You do NOT implement code yourself. ALL implementation is delegated. If you are about to write or edit a source file — STOP. Spawn the appropriate agent.
> The lead drift warning from official docs: "Sometimes the lead starts implementing tasks itself instead of waiting for teammates." This must never happen.

## Prerequisites

1. `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` in environment or `settings.json`
2. `rust-agents` plugin installed
3. Not on `main`/`master` (create a feature branch first)
4. Working directory clean
5. `Cargo.toml` exists

> For complex features that need a written spec before any code: pick the `spec-driven` chain in Step 0 — team-develop runs the SDD pipeline end-to-end (architect → critic → sdd → reviewer → follow-up issue) and produces a versioned spec under `specs/{feature-slug}/`. Run `/rust-agents:sdd` standalone only when you want SDD outside of a team. The existing pre-existing spec convention (`.local/specs/`) still works for the `new-feature` chain — architect and developer pick it up automatically.

## Step 0: Classify Task

Before any team setup, classify the task from `$ARGUMENTS` and confirm with the user. The full pipeline (Steps 1–10) is wasteful for bug fixes, refactors, and security work — pick the right chain up front.

| Signal in task text | Type | Pipeline |
|---|---|---|
| "fix", "bug", "broken", "panic", "regression", crash, stack trace, file:line reference | `bug-fix` | [Workflow: Bug Fix](#workflow-bug-fix) |
| "refactor", "rename", "extract", "restructure", "cleanup", "move module" (behavior preserved) | `refactoring` | [Workflow: Refactoring](#workflow-refactoring) |
| "vulnerability", "CVE", "RUSTSEC", "audit", "unsafe review", credential leak | `security` | [Workflow: Security](#workflow-security) |
| "docs", "README", "mdBook", "doc comment", "rustdoc", "user guide", "API reference" | `docs` | [Workflow: Documentation](#workflow-documentation) |
| "bump", "update dependency", "cargo update", "upgrade {crate}", lockfile changes | `dependency` | [Workflow: Dependency Bump](#workflow-dependency-bump) |
| "optimize", "speed up", "reduce allocations", "profile", "benchmark", "hot path", latency/throughput numbers | `performance` | [Workflow: Performance](#workflow-performance) |
| "CI", "GitHub Actions", "workflow", "justfile", "clippy.toml", "rustfmt.toml", `.cargo/config.toml` | `ci-cd` | [Workflow: CI/CD](#workflow-cicd) |
| "implement", "add", "build", "design", new module/crate, greenfield | `new-feature` | Full pipeline (Steps 1–10 below) |
| "spec", "specification", "design doc", "RFC", "proposal", "BRD", "SRS", "NFR", "blueprint", "feasibility", "design only", "spec only", "research before implementing", "deep design", "draft a spec", "produce a spec" | `spec-driven` | [Workflow: Spec-Driven](#workflow-spec-driven) |
| Task already lists concrete required changes (file paths, exact edits) | reduce one level | Skip the lead agent (architect/debugger/security/perf) — start from developer in the matching chain |
| Ambiguous / multiple signals | see rules below | — |

State the detected type and matching chain, then **wait for confirmation** before spawning anything. Example:

```
Detected: bug-fix — task mentions "fix panic in parser at src/parse.rs:142".
Pipeline: debugger → developer → tester → reviewer → commit.
Proceed? [y / full / refactor / security / docs / dependency / performance / ci-cd]
```

Do NOT skip this step. Do NOT default silently to the full pipeline.

### Mixed-Signal Rule

When the task hits multiple rows of the table:

1. **Identify the goal verb** — the verb that names the *outcome*, not the means. "Refactor parser to fix panic" → goal is `fix` (bug-fix) — refactor is the technique. "Update tokio to patch RUSTSEC-2026-NNNN" → goal is patching the advisory (security), bump is the means.
2. **If two rows tie on goal verb**, pick the heavier chain — heavier here means "more validators". Order (light → heavy): `docs` < `ci-cd` < `dependency` < `bug-fix` < `refactoring` < `performance` < `security` < `new-feature`.
3. **`spec-driven` sits outside this order** — it is the explicit "design first, ship spec, defer code" mode. Pick it only when the user explicitly asks for a spec/RFC/design doc, or when the scope is large enough that the architect alone cannot commit to an implementable plan in one pass. If `spec-driven` and `new-feature` both fit, ask the user — the choice is "do we want a spec now and code later, or one combined PR?".
4. **If still ambiguous**, ask the user — list the candidate chains and request a choice.

### Escalation Rule

If during execution an agent reports a problem that breaks the assumptions of the chosen chain — e.g. the debugger in a bug-fix finds the root cause is an architectural defect, the developer in a refactoring breaks behavior in a way that needs design rethink, the perf engineer finds the hot path requires structural changes, or the architect in a `new-feature` cannot collapse the design into one implementable plan and asks for more upstream thinking — the lead **stops the chain** and:

1. Sends `shutdown_request` to all idle agents.
2. Summarizes the finding to the user.
3. Proposes upgrade to a heavier or different chain (most commonly `new-feature`, `refactoring`, or `spec-driven` when the scope outgrows a single implementation pass) and waits for confirmation before re-spawning.

The reverse downgrade is also valid: if the `spec-driven` sdd agent reports that the scope is small enough to implement directly, the lead pauses the chain and proposes downgrading to `new-feature` (skip spec, go straight to code). Do not silently morph the chain mid-flight — the user must approve the scope change either way.

## Step 1: Load Tools

```
ToolSearch("select:TaskCreate,TaskUpdate,TaskList,TaskGet,TeamCreate,TeamDelete,SendMessage")
```

## Step 2: Team Setup

```json
TeamCreate({"team_name": "rust-dev-{feature-slug}", "description": "Rust dev: {task-summary}"})
```

Create all tasks upfront and set dependencies:

| Task | Owner | Description |
|------|-------|-------------|
| plan | architect | Architecture design |
| critique | critic | **Adversarial critique of architecture (MANDATORY)** |
| implement | developer | Implementation |
| validate-tests | tester | Test coverage |
| validate-perf | perf | Performance analysis |
| validate-security | security | Security audit |
| validate-critique | impl-critic | **Adversarial critique of implementation (MANDATORY)** |
| review | reviewer | Code review |
| fix-issues | developer | Fix all review issues |
| re-review | reviewer | Verify fixes |
| commit | teamlead | Commit and PR |

```
TaskUpdate(taskId: "critique",          addBlockedBy: ["plan"])
TaskUpdate(taskId: "implement",         addBlockedBy: ["critique"])
TaskUpdate(taskId: "validate-tests",    addBlockedBy: ["implement"])
TaskUpdate(taskId: "validate-perf",     addBlockedBy: ["implement"])
TaskUpdate(taskId: "validate-security", addBlockedBy: ["implement"])
TaskUpdate(taskId: "validate-critique", addBlockedBy: ["implement"])
TaskUpdate(taskId: "review",            addBlockedBy: ["validate-tests","validate-perf","validate-security","validate-critique"])
TaskUpdate(taskId: "fix-issues",        addBlockedBy: ["review"])
TaskUpdate(taskId: "re-review",         addBlockedBy: ["fix-issues"])
TaskUpdate(taskId: "commit",            addBlockedBy: ["re-review"])
```

## Team Communication Template

Substitute `{team-name}` and `{agent-role}`, then include verbatim in every spawn prompt:

```
You are a teammate in team `{team-name}`, role `{agent-role}`.

Tasks: ToolSearch("select:TaskCreate,TaskUpdate,TaskList,TaskGet"); update your task to in_progress on start, completed on finish.

Communication: SendMessage(type: "message", to: "team-lead", content: "...", summary: "..."). Respond to shutdown_request with SendMessage(type: "shutdown_response", to: "team-lead", approve: true).

Code ownership: only developer edits source. Only team-lead commits.

Handoff (MANDATORY): BEFORE any other work, call Skill(skill: "rust-agents:rust-agent-handoff"). Before messaging team-lead, write your handoff file and include inline frontmatter + path in the message.
```

## Step 3: Architect

```
Agent(subagent_type: "rust-agents:rust-architect", name: "architect", team_name: "rust-dev-{slug}",
  prompt: "{template}\n\nDesign architecture for: {feature-description}")
TaskUpdate(taskId: "plan", owner: "architect", status: "in_progress")
```

WAIT for handoff frontmatter + path. `TaskUpdate(taskId: "plan", status: "completed")`.

## Step 4: Critic (MANDATORY)

```
Agent(subagent_type: "rust-agents:rust-critic", name: "critic", team_name: "rust-dev-{slug}",
  prompt: "{template}\n\nCritique the architecture. Report findings — do NOT write code.\n\nHandoffs:\n{accumulated frontmatters}")
TaskUpdate(taskId: "critique", owner: "critic", status: "in_progress")
```

WAIT for critic. Check verdict from inline frontmatter:
- `critical` or `significant` → pass critic handoff back to architect for redesign, re-run critic
- `approved` or `minor` → proceed to developer

## Step 5: Developer(s)

Check `.local/specs/` for an existing spec, then analyze the architect's plan: **can implementation be split into independent subtasks?**

Subtasks are independent when ALL hold: separate modules/crates, no shared mutable state, no cross-task type dependencies, can be tested in isolation.

**Independent** — spawn one developer per subtask:

```
TaskCreate(id: "implement-{a}", description: "Implement {a}")
TaskCreate(id: "implement-{b}", description: "Implement {b}")
TaskUpdate(taskId: "implement-{a}", addBlockedBy: ["critique"])
TaskUpdate(taskId: "implement-{b}", addBlockedBy: ["critique"])
// update validate-* to block on all implement-* tasks

Agent(subagent_type: "rust-agents:rust-developer", name: "developer-a", team_name: "...",
  prompt: "{template}\n\nAfter handoff: call Skill(skill: \"rust-agents:rust-modern-apis\") before writing any code.\n\nImplement only: {a description}. Do NOT touch modules owned by parallel developers.\n\nHandoffs:\n{accumulated frontmatters}")
Agent(subagent_type: "rust-agents:rust-developer", name: "developer-b", team_name: "...",
  prompt: "{template}\n\nAfter handoff: call Skill(skill: \"rust-agents:rust-modern-apis\") before writing any code.\n\nImplement only: {b description}. Do NOT touch modules owned by parallel developers.\n\nHandoffs:\n{accumulated frontmatters}")
```

WAIT for ALL parallel developers before validation. Accumulate all handoffs.

**Dependent** — single developer in sequence:

```
Agent(subagent_type: "rust-agents:rust-developer", name: "developer", team_name: "...",
  prompt: "{template}\n\nAfter handoff: call Skill(skill: \"rust-agents:rust-modern-apis\") before writing any code.\n\nImplement based on architect's plan.\n\nHandoffs:\n{accumulated frontmatters}")
TaskUpdate(taskId: "implement", owner: "developer", status: "in_progress")
```

WAIT for developer's handoff.

## Step 6: Parallel Validation (spawn all 4 simultaneously)

```
Agent(subagent_type: "rust-agents:rust-testing-engineer",     name: "tester",      team_name: "...",
  prompt: "{template}\n\nValidate test coverage. Report findings — do NOT edit source.\nHandoffs: {accumulated}")
Agent(subagent_type: "rust-agents:rust-performance-engineer", name: "perf",        team_name: "...",
  prompt: "{template}\n\nAnalyze performance. Report findings — do NOT edit source.\nHandoffs: {accumulated}")
Agent(subagent_type: "rust-agents:rust-security-maintenance", name: "security",    team_name: "...",
  prompt: "{template}\n\nSecurity audit. Report findings — do NOT edit source.\nHandoffs: {accumulated}")
Agent(subagent_type: "rust-agents:rust-critic",               name: "impl-critic", team_name: "...",
  prompt: "{template}\n\nCritique implementation: logical gaps, missing edge cases. Report only — do NOT write code.\nHandoffs: {accumulated}")
```

WAIT for ALL FOUR handoff messages.

## Step 7: Code Review

```
Agent(subagent_type: "rust-agents:rust-code-reviewer", name: "reviewer", team_name: "...",
  prompt: "{template}\n\nAfter handoff: call Skill(skill: \"rust-agents:rust-modern-apis\") before reviewing code.\n\nReview implementation.\n\nHandoffs:\n{all accumulated frontmatters}")
```

WAIT for reviewer's handoff.

## Step 8: Fix-Review Cycle

Check `status` from reviewer's inline frontmatter (no file read needed):

If `status: changes_requested`:

```
SendMessage(type: "message", to: "developer",
  content: "Fix all issues from review.\n\nReviewer frontmatter:\n{inline}\nFile: {path}")
```

WAIT for developer's new handoff. Pass to reviewer:

```
SendMessage(type: "message", to: "reviewer",
  content: "Re-review after fixes.\n\nDeveloper frontmatter:\n{inline}\nFile: {path}")
```

WAIT for reviewer. Repeat until `status: approved`.

## Step 9: Commit and PR

Only after reviewer approves. Read `.claude/rules/commits-and-issues.md` if it exists.

```bash
git add -p   # or specific files
git commit -m "$(cat <<'EOF'
type(scope): description

Body if needed.
EOF
)"
gh pr create --title "..." --body "..."
```

## Step 10: Shutdown

Shut down each agent immediately after its task is complete:

```
SendMessage(type: "shutdown_request", to: "{agent-name}", content: "Task complete")
```

Wait for `shutdown_response`, then:

```
TeamDelete()
```

## Handoff Accumulation

Pass inline frontmatter to each subsequent agent — no file reads for routing:

```
After architect:    [architect]
After critic:       [architect, critic]
After developer(s): [architect, critic, developer-a, developer-b, ...]
After validators:   [architect, critic, developer(s), tester, perf, security, impl-critic]
Reviewer gets all of the above.
```

When parallel developers are used, accumulate all their handoffs before spawning any validator.

## Workflow Templates

Pick one based on Step 0 classification. Steps 2–10 above describe the **New Feature** chain. The reduced chains below reuse the same team setup, communication template, handoff protocol, fix-review cycle (Step 8), commit rules (Step 9), and shutdown (Step 10) — only the task graph and spawned agents differ.

**Mandatory critic gate**: every chain in which `rust-developer` writes code (New Feature, Bug Fix, Refactoring, Security, Dependency Bump, Performance) MUST run an `impl-critic` (`rust-critic`, report-only) on the validation step after the developer and before code review — adversarial critique of the implementation is never skipped. Chains with no `rust-developer` phase (Documentation, CI/CD, Spec-Driven) are exempt because no implementation code is produced.

### Workflow: Bug Fix

`debugger → developer → (tester, impl-critic) → reviewer → commit`. No architect, no perf/security validators.

| Task | Owner | Description |
|---|---|---|
| diagnose | debugger | Root cause, repro steps, fix sketch |
| implement | developer | Apply the fix |
| validate-tests | tester | Add regression test, verify coverage |
| validate-critique | impl-critic | **Adversarial critique of the fix: missed edge cases, incomplete root-cause coverage (MANDATORY)** |
| review | reviewer | Code review |
| fix-issues | developer | Conditional (changes_requested) |
| re-review | reviewer | Conditional |
| commit | team-lead | Commit and PR |

```
TaskUpdate(taskId: "implement",         addBlockedBy: ["diagnose"])
TaskUpdate(taskId: "validate-tests",    addBlockedBy: ["implement"])
TaskUpdate(taskId: "validate-critique", addBlockedBy: ["implement"])
TaskUpdate(taskId: "review",            addBlockedBy: ["validate-tests", "validate-critique"])
TaskUpdate(taskId: "fix-issues",        addBlockedBy: ["review"])
TaskUpdate(taskId: "re-review",         addBlockedBy: ["fix-issues"])
TaskUpdate(taskId: "commit",            addBlockedBy: ["re-review"])
```

Spawn order:

1. `Agent(subagent_type: "rust-agents:rust-debugger", name: "debugger", ...)` — diagnose. WAIT for handoff.
2. `Agent(subagent_type: "rust-agents:rust-developer", name: "developer", ...)` — pass debugger handoff. WAIT.
3. Spawn **in parallel** after developer, both report-only (do NOT edit source):
   - `Agent(subagent_type: "rust-agents:rust-testing-engineer", name: "tester", ...)` — regression test.
   - `Agent(subagent_type: "rust-agents:rust-critic", name: "impl-critic", ...)` — critique the fix: missed edge cases, incomplete root-cause coverage.
   WAIT for BOTH handoffs.
4. `Agent(subagent_type: "rust-agents:rust-code-reviewer", name: "reviewer", ...)` — review, with tester + impl-critic handoffs accumulated. WAIT.
5. Fix-review cycle (Step 8) if needed.
6. Commit (Step 9), shutdown (Step 10).

Skip `diagnose` (start at developer) if the task already names the root cause and proposed fix.

### Workflow: Refactoring

`architect (lite) → developer → (tester, impl-critic) → reviewer → commit`. No perf/security validators — refactoring preserves behavior, so perf analysis is overhead; the critic verifies behavior was actually preserved (no silent semantic drift introduced by the refactor).

| Task | Owner | Description |
|---|---|---|
| plan | architect | Target structure, migration steps. Skip if scope already concrete |
| implement | developer | Apply refactor |
| validate-tests | tester | Existing suite must pass unchanged; verify no behavioral drift |
| validate-critique | impl-critic | **Adversarial critique: confirm the refactor preserves behavior, no hidden semantic changes (MANDATORY)** |
| review | reviewer | Code review |
| fix-issues | developer | Conditional |
| re-review | reviewer | Conditional |
| commit | team-lead | Commit and PR |

```
TaskUpdate(taskId: "implement",         addBlockedBy: ["plan"])
TaskUpdate(taskId: "validate-tests",    addBlockedBy: ["implement"])
TaskUpdate(taskId: "validate-critique", addBlockedBy: ["implement"])
TaskUpdate(taskId: "review",            addBlockedBy: ["validate-tests", "validate-critique"])
TaskUpdate(taskId: "fix-issues",        addBlockedBy: ["review"])
TaskUpdate(taskId: "re-review",         addBlockedBy: ["fix-issues"])
TaskUpdate(taskId: "commit",            addBlockedBy: ["re-review"])
```

Spawn order:

1. `Agent(rust-architect, "Refactor plan for: {desc}")` — WAIT. **Skip entirely** if user already named the renames/moves/extractions.
2. `Agent(rust-developer)` — WAIT.
3. Spawn **in parallel** after developer, both report-only (do NOT edit source):
   - `Agent(rust-testing-engineer, "Run full test suite, confirm no behavioral changes")`.
   - `Agent(subagent_type: "rust-agents:rust-critic", name: "impl-critic", "Critique the refactor: confirm behavior is preserved, flag any hidden semantic drift")`.
   WAIT for BOTH handoffs.
4. `Agent(rust-code-reviewer)` — with tester + impl-critic handoffs accumulated. WAIT.
5. Fix-review cycle if needed; commit; shutdown.

### Workflow: Security

`security → developer → impl-critic → reviewer → commit`. Security agent leads (analysis only — does not edit code). Developer applies fixes. Critic validates the fix after implementation.

| Task | Owner | Description |
|---|---|---|
| audit | security | Vulnerability analysis, severity, fix recommendations |
| implement | developer | Apply fixes per security handoff |
| validate-critique | impl-critic | **Adversarial critique of the fix: incomplete mitigation, new attack surface, missed edge cases (MANDATORY)** |
| review | reviewer | Verify fixes; check for missed vectors and regressions |
| fix-issues | developer | Conditional |
| re-review | reviewer | Conditional |
| commit | team-lead | Commit and PR |

```
TaskUpdate(taskId: "implement",         addBlockedBy: ["audit"])
TaskUpdate(taskId: "validate-critique", addBlockedBy: ["implement"])
TaskUpdate(taskId: "review",            addBlockedBy: ["validate-critique"])
TaskUpdate(taskId: "fix-issues",        addBlockedBy: ["review"])
TaskUpdate(taskId: "re-review",         addBlockedBy: ["fix-issues"])
TaskUpdate(taskId: "commit",            addBlockedBy: ["re-review"])
```

Spawn order:

1. `Agent(rust-security-maintenance, "Audit: {scope}")` — WAIT. For RUSTSEC advisories include advisory ID and link in the spawn prompt.
2. `Agent(rust-developer, "Apply fixes from security handoff")` — WAIT.
3. `Agent(subagent_type: "rust-agents:rust-critic", name: "impl-critic", "Critique the security fix: incomplete mitigation, new attack surface, missed edge cases. Report only — do NOT write code")` — WAIT.
4. `Agent(rust-code-reviewer)` — with security + impl-critic handoffs accumulated. WAIT.
5. Fix-review cycle if needed; commit; shutdown.

Skip `audit` (start at developer) if the task already specifies the CVE/RUSTSEC and the required fix.

### Workflow: Documentation

`tech-writer → reviewer → commit`. No developer (tech-writer edits docs directly), no tester/security/perf — documentation does not affect runtime behavior. Applies to README, mdBook chapters, rustdoc comments, CHANGELOG narrative.

| Task | Owner | Description |
|---|---|---|
| write | tech-writer | Write or edit documentation |
| review | reviewer | Verify accuracy against code, check links/examples build |
| fix-issues | tech-writer | Conditional |
| re-review | reviewer | Conditional |
| commit | team-lead | Commit and PR |

```
TaskUpdate(taskId: "review",     addBlockedBy: ["write"])
TaskUpdate(taskId: "fix-issues", addBlockedBy: ["review"])
TaskUpdate(taskId: "re-review",  addBlockedBy: ["fix-issues"])
TaskUpdate(taskId: "commit",     addBlockedBy: ["re-review"])
```

Spawn order:

1. `Agent(subagent_type: "rust-agents:tech-writer", name: "writer", ...)` — write/edit docs. WAIT for handoff. Reviewer (not developer) handles fix-issues; reassign ownership in the fix-review cycle (Step 8) accordingly.
2. `Agent(subagent_type: "rust-agents:rust-code-reviewer", name: "reviewer", ...)` — verify accuracy against current code, check `cargo doc --no-deps` builds without broken intra-doc links, doc-tests pass. WAIT.
3. Fix-review cycle (Step 8) — but route fix messages to `writer` instead of `developer`.
4. Commit (Step 9), shutdown (Step 10).

If the change is rustdoc-only on `pub` items and includes new doctests, also spawn `Agent(rust-testing-engineer)` between writer and reviewer to confirm `cargo test --doc` passes.

### Workflow: Dependency Bump

`developer → (security, tester, impl-critic) → reviewer → commit`. Security audit is mandatory (new advisories can ship with bumps); full test suite must pass; critic validates any API-breakage adapter code.

| Task | Owner | Description |
|---|---|---|
| update | developer | Apply bump in `Cargo.toml`, regenerate `Cargo.lock`, resolve compile errors |
| audit | security | `cargo audit`, `cargo deny check`, check for new RUSTSEC advisories or yanked crates |
| validate-tests | tester | Run full workspace test suite, integration tests, doctests |
| validate-critique | impl-critic | **Adversarial critique of API-breakage adapters: incorrect migration, behavior drift, missed edge cases (MANDATORY)** |
| review | reviewer | Review diff of `Cargo.toml` / `Cargo.lock`, any API breakage adapters |
| fix-issues | developer | Conditional |
| re-review | reviewer | Conditional |
| commit | team-lead | Commit and PR |

```
TaskUpdate(taskId: "audit",             addBlockedBy: ["update"])
TaskUpdate(taskId: "validate-tests",    addBlockedBy: ["update"])
TaskUpdate(taskId: "validate-critique", addBlockedBy: ["update"])
TaskUpdate(taskId: "review",            addBlockedBy: ["audit", "validate-tests", "validate-critique"])
TaskUpdate(taskId: "fix-issues",        addBlockedBy: ["review"])
TaskUpdate(taskId: "re-review",         addBlockedBy: ["fix-issues"])
TaskUpdate(taskId: "commit",            addBlockedBy: ["re-review"])
```

Spawn order:

1. `Agent(rust-developer, "Bump: {crate@version or `cargo update`}")` — WAIT.
2. Spawn `rust-security-maintenance`, `rust-testing-engineer`, and `rust-critic` (name: "impl-critic", critique API-breakage adapters — report only) **in parallel** after developer. WAIT for all three handoffs.
3. `Agent(rust-code-reviewer)` with all four handoffs accumulated. WAIT.
4. Fix-review cycle if needed; commit; shutdown.

For major version bumps (semver-breaking): escalate to `refactoring` chain — API breakage usually needs architect-level decisions on adapter shape.

### Workflow: Performance

`perf → developer → (perf verify, tester, impl-critic) → reviewer → commit`. Performance engineer leads (profiles, identifies hot paths, proposes plan) AND verifies the result (re-profiles after the fix).

| Task | Owner | Description |
|---|---|---|
| profile | perf | Baseline measurements, flamegraph/criterion, identify hot path, propose plan |
| implement | developer | Apply optimization per perf handoff |
| verify | perf | Re-measure; confirm improvement and no regression elsewhere |
| validate-tests | tester | Run full suite — optimization must not change semantics |
| validate-critique | impl-critic | **Adversarial critique: logical gaps and edge cases introduced by the optimization, correctness vs. readability trade-offs (MANDATORY)** |
| review | reviewer | Review for correctness and clarity (perf code often trades readability) |
| fix-issues | developer | Conditional |
| re-review | reviewer | Conditional |
| commit | team-lead | Commit and PR with before/after numbers |

```
TaskUpdate(taskId: "implement",         addBlockedBy: ["profile"])
TaskUpdate(taskId: "verify",            addBlockedBy: ["implement"])
TaskUpdate(taskId: "validate-tests",    addBlockedBy: ["implement"])
TaskUpdate(taskId: "validate-critique", addBlockedBy: ["implement"])
TaskUpdate(taskId: "review",            addBlockedBy: ["verify", "validate-tests", "validate-critique"])
TaskUpdate(taskId: "fix-issues",        addBlockedBy: ["review"])
TaskUpdate(taskId: "re-review",         addBlockedBy: ["fix-issues"])
TaskUpdate(taskId: "commit",            addBlockedBy: ["re-review"])
```

Spawn order:

1. `Agent(rust-performance-engineer, name: "perf", "Profile and propose plan for: {target}")` — WAIT for baseline + plan in handoff.
2. `Agent(rust-developer)` — apply per perf handoff. WAIT.
3. Spawn **same `perf` agent again** (new task `verify`), `rust-testing-engineer`, and `rust-critic` (name: "impl-critic", critique optimization for logical gaps and edge cases — report only) **in parallel** after developer. WAIT for all three.
4. `Agent(rust-code-reviewer)` with all handoffs. WAIT.
5. Fix-review cycle; commit; shutdown.

Commit body must include the measured before/after numbers from perf's verify handoff. If `verify` shows no improvement or regression, do NOT proceed to review — message developer to retry or escalate to `refactoring` (structural change needed).

### Workflow: CI/CD

`cicd → reviewer → commit`. CI/CD engineer edits workflows/tooling directly. No Rust agents — these changes don't touch `src/`.

| Task | Owner | Description |
|---|---|---|
| change | cicd | Edit workflows / configs |
| review | reviewer | Review YAML/config diff; verify on a test branch where possible |
| fix-issues | cicd | Conditional |
| re-review | reviewer | Conditional |
| commit | team-lead | Commit and PR |

```
TaskUpdate(taskId: "review",     addBlockedBy: ["change"])
TaskUpdate(taskId: "fix-issues", addBlockedBy: ["review"])
TaskUpdate(taskId: "re-review",  addBlockedBy: ["fix-issues"])
TaskUpdate(taskId: "commit",     addBlockedBy: ["re-review"])
```

Spawn order:

1. `Agent(subagent_type: "rust-agents:rust-cicd-devops", name: "cicd", ...)` — apply changes. WAIT for handoff.
2. `Agent(rust-code-reviewer)` with cicd handoff. Reviewer should validate YAML with `fy validate`. WAIT.
3. Fix-review cycle (route fix messages to `cicd`, not `developer`); commit; shutdown.

If the CI change also touches `src/` (e.g. adding a new lint that triggers code fixes), escalate to `refactoring` — `cicd` does not edit Rust sources.

### Workflow: Spec-Driven

`architect → critic → sdd → reviewer → commit-spec → follow-up issue`. Design-only mode: no implementation code is written. The chain produces a versioned specification under `specs/{feature-slug}/` and a GitHub issue that hands the spec off to a future implementation pass (usually a `new-feature` team-develop run that picks up the spec from `specs/`).

| Task | Owner | Description |
|---|---|---|
| plan | architect | Architecture plan — design only, no code. State assumptions, alternatives, trade-offs |
| critique | critic | **Adversarial critique of the plan (MANDATORY)** |
| specify | sdd | Convert plan + critic findings into a formal spec package (BRD / SRS / NFR / spec / plan / tasks) under `specs/{feature-slug}/` |
| review | reviewer | Final spec review: completeness, traceability (BRD→SRS→spec→tasks), consistency, acceptance criteria coverage, no implicit assumptions |
| fix-issues | sdd | Conditional — refine spec per reviewer findings |
| re-review | reviewer | Conditional |
| commit-spec | team-lead | Commit `specs/{feature-slug}/` and push branch |
| create-issue | team-lead | Open follow-up implementation issue with spec link and recommended chain |

```
TaskUpdate(taskId: "critique",     addBlockedBy: ["plan"])
TaskUpdate(taskId: "specify",      addBlockedBy: ["critique"])
TaskUpdate(taskId: "review",       addBlockedBy: ["specify"])
TaskUpdate(taskId: "fix-issues",   addBlockedBy: ["review"])
TaskUpdate(taskId: "re-review",    addBlockedBy: ["fix-issues"])
TaskUpdate(taskId: "commit-spec",  addBlockedBy: ["re-review"])
TaskUpdate(taskId: "create-issue", addBlockedBy: ["commit-spec"])
```

**Code-ownership override for this chain** — replace the line in the Team Communication Template:

```
Code ownership: NO source files are edited in this chain. Only sdd writes/edits files (spec artifacts under specs/{feature-slug}/). Only team-lead commits and opens issues.
```

Spawn order:

1. `Agent(subagent_type: "rust-agents:rust-architect", name: "architect", ..., "Design plan only — NO implementation code, NO edits to src/. Produce a written plan covering: scope, assumptions, alternatives considered, trade-offs, open questions. Target: {desc}")` — WAIT for handoff.
2. `Agent(subagent_type: "rust-agents:rust-critic", name: "critic", ..., "Critique the plan. Report findings — do NOT write code.\nHandoffs:\n{architect}")` — WAIT. Apply the same verdict gate as Step 4 of the full pipeline: `critical` or `significant` → pass critic handoff back to architect, re-run critic; `approved` or `minor` → proceed to sdd.
3. `Agent(subagent_type: "rust-agents:sdd", name: "sdd", ..., "Convert the approved plan and critic findings into a complete spec package under specs/{feature-slug}/. Run the full BRD → SRS → NFR → spec → plan → tasks pipeline. Cite the architect plan and critic concerns as inputs in the spec body. Do NOT write or edit any source files outside specs/{feature-slug}/.\nHandoffs:\n{architect, critic}")` — WAIT.
4. `Agent(subagent_type: "rust-agents:rust-code-reviewer", name: "reviewer", ..., "Final review of the spec at specs/{feature-slug}/. Check: completeness (all BRD requirements traced to SRS items, all SRS items traced to spec sections, all spec sections traced to tasks), internal consistency, acceptance criteria are testable, NFRs are measurable, open questions are explicit, no implicit assumptions. Verify spec files are well-formed (fy validate on any YAML, links resolve). Do NOT review for code quality — there is no code yet.\nHandoffs:\n{architect, critic, sdd}")` — WAIT.
5. **Fix-review cycle** (Step 8) — but route fix messages to `sdd` instead of `developer`. Reassign `fix-issues.owner` to `sdd` in TaskUpdate. Repeat until reviewer returns `status: approved`.
6. **Commit spec** — team-lead stages and commits `specs/{feature-slug}/` only:

   ```bash
   git add specs/{feature-slug}/
   git commit -m "$(cat <<'EOF'
   spec({feature-slug}): add specification

   Spec package produced by team-develop spec-driven chain.
   Follow-up implementation tracked in the linked issue.
   EOF
   )"
   git push -u origin {branch}
   ```

7. **Create follow-up issue** — `gh issue create` with body that links the spec, summarizes scope, and recommends the next chain:

   ```bash
   gh issue create --title "Implement: {feature title}" --body "$(cat <<'EOF'
   ## Spec
   See `specs/{feature-slug}/` (added in {commit-sha} on branch `{branch}`).

   ## Summary
   {one-paragraph scope from the spec}

   ## Acceptance criteria
   {bulleted list lifted from spec — testable items only}

   ## Suggested next step
   Run `/rust-agents:team-develop new-feature` on this issue. The architect and developer will pick up `specs/{feature-slug}/` automatically.
   EOF
   )" --label spec-driven --label implementation
   ```

   If the repository does not have the `spec-driven` or `implementation` labels, drop the `--label` flags (do not auto-create labels).

8. Shutdown (Step 10), `TeamDelete()`.

**Escalation from spec-driven**:

- If sdd reports during `specify` that the architect's plan is small enough to implement directly (a few files, no open questions, no architectural choices left) — pause the chain and propose downgrading to `new-feature` per the Escalation Rule. Do not silently produce a spec for a one-day task.
- If the reviewer reports during `review` that the spec is fundamentally incomplete and the architect needs to revisit scope (not just the sdd refining wording) — loop back to architect, not to sdd. Re-run critic and sdd afterward.

Skip the `architect → critic` lead-in (start at sdd) only if the user has already produced an approved plan or RFC and explicitly says "just turn this into a spec". Otherwise the architect+critic gate is mandatory — sdd needs an adversarially-vetted plan as input, not raw user notes.
