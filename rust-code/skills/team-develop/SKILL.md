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

> For complex features: run `/rust-agents:sdd` **before** team-develop to produce a spec in `.local/specs/`. Architect and developer pick it up automatically. team-develop does not run SDD itself.

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
3. **If still ambiguous**, ask the user — list the two candidate chains and request a choice.

### Escalation Rule

If during execution an agent reports a problem that breaks the assumptions of the chosen chain — e.g. the debugger in a bug-fix finds the root cause is an architectural defect, the developer in a refactoring breaks behavior in a way that needs design rethink, the perf engineer finds the hot path requires structural changes — the lead **stops the chain** and:

1. Sends `shutdown_request` to all idle agents.
2. Summarizes the finding to the user.
3. Proposes upgrade to the heavier chain (most commonly `new-feature` or `refactoring`) and waits for confirmation before re-spawning.

Do not silently morph the chain mid-flight — the user must approve the scope change.

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

Pick one based on Step 0 classification. Steps 2–10 above describe the **New Feature** chain. The three reduced chains below reuse the same team setup, communication template, handoff protocol, fix-review cycle (Step 8), commit rules (Step 9), and shutdown (Step 10) — only the task graph and spawned agents differ.

### Workflow: Bug Fix

`debugger → developer → tester → reviewer → commit`. No architect, no critic, no perf/security validators.

| Task | Owner | Description |
|---|---|---|
| diagnose | debugger | Root cause, repro steps, fix sketch |
| implement | developer | Apply the fix |
| validate-tests | tester | Add regression test, verify coverage |
| review | reviewer | Code review |
| fix-issues | developer | Conditional (changes_requested) |
| re-review | reviewer | Conditional |
| commit | team-lead | Commit and PR |

```
TaskUpdate(taskId: "implement",      addBlockedBy: ["diagnose"])
TaskUpdate(taskId: "validate-tests", addBlockedBy: ["implement"])
TaskUpdate(taskId: "review",         addBlockedBy: ["validate-tests"])
TaskUpdate(taskId: "fix-issues",     addBlockedBy: ["review"])
TaskUpdate(taskId: "re-review",      addBlockedBy: ["fix-issues"])
TaskUpdate(taskId: "commit",         addBlockedBy: ["re-review"])
```

Spawn order:

1. `Agent(subagent_type: "rust-agents:rust-debugger", name: "debugger", ...)` — diagnose. WAIT for handoff.
2. `Agent(subagent_type: "rust-agents:rust-developer", name: "developer", ...)` — pass debugger handoff. WAIT.
3. `Agent(subagent_type: "rust-agents:rust-testing-engineer", name: "tester", ...)` — regression test. WAIT.
4. `Agent(subagent_type: "rust-agents:rust-code-reviewer", name: "reviewer", ...)` — review. WAIT.
5. Fix-review cycle (Step 8) if needed.
6. Commit (Step 9), shutdown (Step 10).

Skip `diagnose` (start at developer) if the task already names the root cause and proposed fix.

### Workflow: Refactoring

`architect (lite) → developer → tester → reviewer → commit`. No critic, no perf/security validators — refactoring preserves behavior, so adversarial review and perf analysis are overhead.

| Task | Owner | Description |
|---|---|---|
| plan | architect | Target structure, migration steps. Skip if scope already concrete |
| implement | developer | Apply refactor |
| validate-tests | tester | Existing suite must pass unchanged; verify no behavioral drift |
| review | reviewer | Code review |
| fix-issues | developer | Conditional |
| re-review | reviewer | Conditional |
| commit | team-lead | Commit and PR |

```
TaskUpdate(taskId: "implement",      addBlockedBy: ["plan"])
TaskUpdate(taskId: "validate-tests", addBlockedBy: ["implement"])
TaskUpdate(taskId: "review",         addBlockedBy: ["validate-tests"])
TaskUpdate(taskId: "fix-issues",     addBlockedBy: ["review"])
TaskUpdate(taskId: "re-review",      addBlockedBy: ["fix-issues"])
TaskUpdate(taskId: "commit",         addBlockedBy: ["re-review"])
```

Spawn order:

1. `Agent(rust-architect, "Refactor plan for: {desc}")` — WAIT. **Skip entirely** if user already named the renames/moves/extractions.
2. `Agent(rust-developer)` — WAIT.
3. `Agent(rust-testing-engineer, "Run full test suite, confirm no behavioral changes")` — WAIT.
4. `Agent(rust-code-reviewer)` — WAIT.
5. Fix-review cycle if needed; commit; shutdown.

### Workflow: Security

`security → developer → reviewer → commit`. Security agent leads (analysis only — does not edit code). Developer applies fixes.

| Task | Owner | Description |
|---|---|---|
| audit | security | Vulnerability analysis, severity, fix recommendations |
| implement | developer | Apply fixes per security handoff |
| review | reviewer | Verify fixes; check for missed vectors and regressions |
| fix-issues | developer | Conditional |
| re-review | reviewer | Conditional |
| commit | team-lead | Commit and PR |

```
TaskUpdate(taskId: "implement",  addBlockedBy: ["audit"])
TaskUpdate(taskId: "review",     addBlockedBy: ["implement"])
TaskUpdate(taskId: "fix-issues", addBlockedBy: ["review"])
TaskUpdate(taskId: "re-review",  addBlockedBy: ["fix-issues"])
TaskUpdate(taskId: "commit",     addBlockedBy: ["re-review"])
```

Spawn order:

1. `Agent(rust-security-maintenance, "Audit: {scope}")` — WAIT. For RUSTSEC advisories include advisory ID and link in the spawn prompt.
2. `Agent(rust-developer, "Apply fixes from security handoff")` — WAIT.
3. `Agent(rust-code-reviewer)` — WAIT.
4. Fix-review cycle if needed; commit; shutdown.

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

`developer → security → tester → reviewer → commit`. Security audit is mandatory (new advisories can ship with bumps); full test suite must pass.

| Task | Owner | Description |
|---|---|---|
| update | developer | Apply bump in `Cargo.toml`, regenerate `Cargo.lock`, resolve compile errors |
| audit | security | `cargo audit`, `cargo deny check`, check for new RUSTSEC advisories or yanked crates |
| validate-tests | tester | Run full workspace test suite, integration tests, doctests |
| review | reviewer | Review diff of `Cargo.toml` / `Cargo.lock`, any API breakage adapters |
| fix-issues | developer | Conditional |
| re-review | reviewer | Conditional |
| commit | team-lead | Commit and PR |

```
TaskUpdate(taskId: "audit",          addBlockedBy: ["update"])
TaskUpdate(taskId: "validate-tests", addBlockedBy: ["update"])
TaskUpdate(taskId: "review",         addBlockedBy: ["audit", "validate-tests"])
TaskUpdate(taskId: "fix-issues",     addBlockedBy: ["review"])
TaskUpdate(taskId: "re-review",      addBlockedBy: ["fix-issues"])
TaskUpdate(taskId: "commit",         addBlockedBy: ["re-review"])
```

Spawn order:

1. `Agent(rust-developer, "Bump: {crate@version or `cargo update`}")` — WAIT.
2. Spawn `rust-security-maintenance` and `rust-testing-engineer` **in parallel** after developer. WAIT for both handoffs.
3. `Agent(rust-code-reviewer)` with all three handoffs accumulated. WAIT.
4. Fix-review cycle if needed; commit; shutdown.

For major version bumps (semver-breaking): escalate to `refactoring` chain — API breakage usually needs architect-level decisions on adapter shape.

### Workflow: Performance

`perf → developer → perf (verify) → tester → reviewer → commit`. Performance engineer leads (profiles, identifies hot paths, proposes plan) AND verifies the result (re-profiles after the fix).

| Task | Owner | Description |
|---|---|---|
| profile | perf | Baseline measurements, flamegraph/criterion, identify hot path, propose plan |
| implement | developer | Apply optimization per perf handoff |
| verify | perf | Re-measure; confirm improvement and no regression elsewhere |
| validate-tests | tester | Run full suite — optimization must not change semantics |
| review | reviewer | Review for correctness and clarity (perf code often trades readability) |
| fix-issues | developer | Conditional |
| re-review | reviewer | Conditional |
| commit | team-lead | Commit and PR with before/after numbers |

```
TaskUpdate(taskId: "implement",      addBlockedBy: ["profile"])
TaskUpdate(taskId: "verify",         addBlockedBy: ["implement"])
TaskUpdate(taskId: "validate-tests", addBlockedBy: ["implement"])
TaskUpdate(taskId: "review",         addBlockedBy: ["verify", "validate-tests"])
TaskUpdate(taskId: "fix-issues",     addBlockedBy: ["review"])
TaskUpdate(taskId: "re-review",      addBlockedBy: ["fix-issues"])
TaskUpdate(taskId: "commit",         addBlockedBy: ["re-review"])
```

Spawn order:

1. `Agent(rust-performance-engineer, name: "perf", "Profile and propose plan for: {target}")` — WAIT for baseline + plan in handoff.
2. `Agent(rust-developer)` — apply per perf handoff. WAIT.
3. Spawn **same `perf` agent again** (new task `verify`) and `rust-testing-engineer` **in parallel** after developer. WAIT for both.
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
