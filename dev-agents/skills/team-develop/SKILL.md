---
name: team-develop
description: "Orchestrate Rust, TypeScript, and Luau/Lua development using agent teams with peer-to-peer communication: classify the task into a chain, spawn specialist teammates, run the fix-review cycle, commit and open a PR. Requires CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1; CLAUDE_CODE_ENABLE_TODO_TOOLS=1 enables shared task-list coordination on Claude Code 2.1.233+."
when_to_use: "'create dev team', 'start team development', 'launch agent team', 'team workflow', 'collaborative development', 'implement this with the team'."
argument-hint: "[task-description]"
allowed-tools: Bash(printenv *), Bash(git branch *), Bash(git status *), Bash(test *), Bash(echo *), Bash(wc *), Bash(tr *)
---

# Team Develop Orchestration

You act as **team lead**. Coordinate specialist agents to implement the task.

**Task**: $ARGUMENTS

> You do NOT implement code yourself. ALL implementation is delegated. If you are about to write or edit a source file — STOP. Spawn the appropriate agent. The only files the lead edits are the changelog, the version field of the version manifests (release metadata), the `.local/protected-tests` marker (Step 4.6), and `progress.json` (task-loop chain), never source files or the dependency sections of a manifest.
> The lead drift warning from official docs: "Sometimes the lead starts implementing tasks itself instead of waiting for teammates." This must never happen.

## Preflight (collected automatically when this skill loads)

- Agent teams flag: !`printenv CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS || echo unset`
- Task tools flag: !`printenv CLAUDE_CODE_ENABLE_TODO_TOOLS || echo unset`
- Current branch: !`git branch --show-current 2>/dev/null || echo not-a-git-repo`
- Uncommitted changes: !`git status --porcelain 2>/dev/null | wc -l | tr -d ' '`
- Cargo.toml: !`test -f Cargo.toml && echo present || echo missing`
- tsconfig.json: !`test -f tsconfig.json && echo present || echo missing`
- package.json: !`test -f package.json && echo present || echo missing`
- Luau/Lua markers: !`test -f default.project.json -o -f wally.toml -o -f pesde.toml -o -f .luaurc -o -f .luarc.json -o -f selene.toml -o -f stylua.toml && echo present || echo missing`

Check the values above before spawning anything. STOP and tell the user when:

1. Agent teams flag is not `1` — without agent teams, `Agent()` calls spawn background subagents (Claude Code 2.1.232+ default), teammates never form, and every WAIT step below stalls
2. Current branch is `main`/`master` — create a feature branch first
3. Uncommitted changes is not `0` — the working tree must be clean (a `task-loop` resume may carry `progress.json` and the `in_progress` task's files: list them to the user and continue)
4. Cargo.toml, tsconfig.json, package.json, and the Luau/Lua markers are all `missing` — no supported stack (monorepo with manifests only in subdirectories: ask the user which stack to pass)

**Stack**: derive `{stack}` from the markers — `Cargo.toml` → `rust`; `tsconfig.json` or `package.json` → `typescript`; Luau/Lua markers → `luau`; several → all of them, comma-separated (`rust,typescript`; a roblox-ts project is `typescript,luau`). Narrow it when the task clearly touches one language only. State it next to the detected chain in Step 0; every spawn prompt carries it (see the Spawn Template), so teammates skip their own detection.

Agent teams never form in non-interactive sessions (`claude -p`, SDK): a named spawn there runs as an ordinary subagent. Do not run this skill headless.

> For complex features that need a written spec before any code: pick the `spec-driven` chain in Step 0 — team-develop runs the SDD pipeline end-to-end (architect → critic → sdd-orchestrator → reviewer → follow-up issue) and produces a versioned spec under `specs/{feature-slug}/`. Run `/dev-agents:sdd` standalone only when you want SDD outside of a team. Existing spec sources, in order: a committed package under `specs/`, a `## Specification` section in the issue body (continuous-improvement findings), a local draft under `.local/specs/` (gitignored, this machine only). In `new-feature`, Step 3 passes the matching one to every agent; in the reduced chains an issue-body spec reaches every agent with the task text.

## Step 0: Classify Task

Before any team setup, classify the task from `$ARGUMENTS` and confirm with the user. The full pipeline (Steps 1–10) is wasteful for bug fixes, refactors, and security work — pick the right chain up front.

| Signal in task text | Type | Pipeline |
|---|---|---|
| "fix", "bug", "broken", "panic", "regression", crash, stack trace, file:line reference | `bug-fix` | [Workflow: Bug Fix](#workflow-bug-fix) |
| "refactor", "rename", "extract", "restructure", "cleanup", "move module" (behavior preserved) | `refactoring` | [Workflow: Refactoring](#workflow-refactoring) |
| "vulnerability", "CVE", "RUSTSEC", "GHSA", "npm audit", "audit", "unsafe review", credential leak | `security` | [Workflow: Security](#workflow-security) |
| "docs", "README", "mdBook", "doc comment", "rustdoc", "TSDoc", "user guide", "API reference" | `docs` | [Workflow: Documentation](#workflow-documentation) |
| "bump", "update dependency", "cargo update", "npm update", "pnpm update", "wally install", "pesde update", "upgrade {package}", lockfile changes | `dependency` | [Workflow: Dependency Bump](#workflow-dependency-bump) |
| "optimize", "speed up", "reduce allocations", "profile", "benchmark", "hot path", latency/throughput numbers | `performance` | [Workflow: Performance](#workflow-performance) |
| "CI", "GitHub Actions", "workflow", "justfile", "clippy.toml", "rustfmt.toml", `.cargo/config.toml`, `eslint.config.*`, `tsconfig.json`, `biome.json`, `selene.toml`, `stylua.toml`, `rokit.toml` | `ci-cd` | [Workflow: CI/CD](#workflow-cicd) |
| "implement", "add", "build", "design", new module/crate/package, greenfield | `new-feature` | Full pipeline (Steps 1–10 below) |
| "implement the tasks of", "task by task", "one task per session", a `tasks.md` or `specs/{slug}/` path to implement | `task-loop` | [Workflow: Task Loop](#workflow-task-loop) |
| "spec", "specification", "design doc", "RFC", "proposal", "BRD", "SRS", "NFR", "blueprint", "feasibility", "design only", "spec only", "research before implementing", "deep design", "draft a spec", "produce a spec" | `spec-driven` | [Workflow: Spec-Driven](#workflow-spec-driven) |
| Task already lists concrete required changes (file paths, exact edits) | reduce one level | Skip the lead agent (architect/debugger/security/perf) — start from developer in the matching chain |
| Ambiguous / multiple signals | see rules below | — |

State the detected type and matching chain, then **wait for confirmation** before spawning anything. Ask with the `AskUserQuestion` tool, the detected chain first:

```
Detected: bug-fix — task mentions "fix panic in parser at src/parse.rs:142".
Stack: rust (Cargo.toml present).
Pipeline: debugger → developer → tester → reviewer → commit.

AskUserQuestion(questions: [{header: "Chain", question: "Which chain should the team run?", multiSelect: false, options: [
  {label: "bug-fix (Recommended)", description: "debugger → developer → tester → reviewer"},
  {label: "refactoring", description: "Runner-up signal: \"restructure\" in the task"},
  {label: "new-feature", description: "Full pipeline, Steps 1–10"}]}])
```

Offer the detected chain, the runner-up from the [Mixed-Signal Rule](#mixed-signal-rule) when there is one, and `new-feature` unless it is already listed — at most four options. The automatic `Other` answer takes any other chain name from the table. Where `AskUserQuestion` is unavailable (headless runs), ask in text and wait for the answer.

Do NOT skip this step. Do NOT default silently to the full pipeline.

### Mixed-Signal Rule

When the task hits multiple rows of the table:

1. **Identify the goal verb** — the verb that names the *outcome*, not the means. "Refactor parser to fix panic" → goal is `fix` (bug-fix) — refactor is the technique. "Update tokio to patch RUSTSEC-2026-NNNN" → goal is patching the advisory (security), bump is the means.
2. **If two rows tie on goal verb**, pick the heavier chain — heavier here means "more validators". Order (light → heavy): `docs` < `ci-cd` < `dependency` < `bug-fix` < `refactoring` < `performance` < `security` < `new-feature`.
3. **`task-loop` sits outside this order** too: pick it only when the task names an approved spec or `tasks.md` to implement task by task.
4. **`spec-driven` sits outside this order** — it is the explicit "design first, ship spec, defer code" mode. Pick it only when the user explicitly asks for a spec/RFC/design doc, or when the scope is large enough that the architect alone cannot commit to an implementable plan in one pass. If `spec-driven` and `new-feature` both fit, ask the user — the choice is "do we want a spec now and code later, or one combined PR?".
5. **If still ambiguous**, ask the user — the candidate chains as `AskUserQuestion` options, as above.

### Escalation Rule

If during execution an agent reports a problem that breaks the assumptions of the chosen chain — e.g. the debugger in a bug-fix finds the root cause is an architectural defect, the developer in a refactoring breaks behavior in a way that needs design rethink, the perf engineer finds the hot path requires structural changes, or the architect in a `new-feature` cannot collapse the design into one implementable plan and asks for more upstream thinking — the lead **stops the chain** and:

1. Sends `shutdown_request` to all idle agents. Names of shut-down agents are not reused: the re-spawned chain follows the suffix rule of the `team-lead` protocol (Naming and Isolation).
2. Summarizes the finding to the user.
3. Proposes upgrade to a heavier or different chain (most commonly `new-feature`, `refactoring`, or `spec-driven` when the scope outgrows a single implementation pass) and waits for confirmation before re-spawning.

The reverse downgrade is also valid: if the `spec-driven` sdd-orchestrator agent reports that the scope is small enough to implement directly, the lead pauses the chain and proposes downgrading to `new-feature` (skip spec, go straight to code). Do not silently morph the chain mid-flight — the user must approve the scope change either way.

### No-Change Outcome

A `no_change_needed` handoff (the architect or the debugger found that the request is already satisfied or behaves as intended; the `## Evidence` section holds the reproduction attempt or the code that already satisfies it) stops the chain. The lead sends `shutdown_request` to every idle agent, reports the evidence to the user, and creates no branch work, commit, or PR. In `bug-fix`, `refactoring`, `new-feature`, and `spec-driven` this applies to the first handoff of the chain; a developer or validator never returns it.

## Step 1: Load the Lead Protocol

Call `Skill(skill: "dev-agents:team-lead")` and follow it: tool loading and the message-based fallback, the spawn template, teammate outcomes, naming, isolation, and shutdown. Do not spawn anything before it is loaded (without the `Skill` tool, Read `${CLAUDE_PLUGIN_ROOT}/skills/team-lead/SKILL.md`).

## Step 2: Task Setup

Create all tasks upfront by name (the `team-lead` name → ID rule) and set dependencies (message-based fallback: skip the TaskCreate/TaskUpdate calls; the table stays your execution order):

| Task | Owner | Description |
|------|-------|-------------|
| plan | architect | Architecture design |
| critique | critic | **Adversarial critique of architecture (MANDATORY)** |
| approve-plan | team-lead | User approval of the plan (Step 4.5; skipped when the task lists exact changes) |
| acceptance-tests | tester | Failing acceptance tests from the criteria and contracts (Step 4.6) |
| verify-contract | live-tester | Verification contract (Step 4.6; only when the project has a runnable surface) |
| implement | developer | Implementation |
| validate-tests | tester | Test coverage |
| validate-live | live-tester | Run the verification contract against the built artifact (Step 6; only with `verify-contract`) |
| validate-perf | perf | Performance analysis |
| validate-security | security | Security audit |
| validate-critique | impl-critic | **Adversarial critique of implementation (MANDATORY)** |
| review | reviewer | Code review |
| fix-issues | developer | Fix all review issues |
| re-review | reviewer | Verify fixes |
| sync-spec | sdd-orchestrator | Write approved Deviations into the spec, mark completed tasks (Step 8.5; only with a committed `specs/` `{spec}`) |
| commit | team-lead | Commit and PR |

```
TaskUpdate(taskId: "critique",          addBlockedBy: ["plan"])
TaskUpdate(taskId: "approve-plan",      addBlockedBy: ["critique"])
TaskUpdate(taskId: "acceptance-tests",  addBlockedBy: ["approve-plan"])
TaskUpdate(taskId: "verify-contract",   addBlockedBy: ["approve-plan"])
TaskUpdate(taskId: "implement",         addBlockedBy: ["acceptance-tests"])
TaskUpdate(taskId: "validate-tests",    addBlockedBy: ["implement"])
TaskUpdate(taskId: "validate-perf",     addBlockedBy: ["implement"])
TaskUpdate(taskId: "validate-security", addBlockedBy: ["implement"])
TaskUpdate(taskId: "validate-critique", addBlockedBy: ["implement"])
TaskUpdate(taskId: "validate-live",     addBlockedBy: ["implement", "verify-contract"])
TaskUpdate(taskId: "review",            addBlockedBy: ["validate-tests","validate-perf","validate-security","validate-critique","validate-live"])
TaskUpdate(taskId: "fix-issues",        addBlockedBy: ["review"])
TaskUpdate(taskId: "re-review",         addBlockedBy: ["fix-issues"])
TaskUpdate(taskId: "sync-spec",         addBlockedBy: ["review"])
TaskUpdate(taskId: "commit",            addBlockedBy: ["re-review", "sync-spec"])
```

Create `approve-plan`, `acceptance-tests`, `verify-contract`, `validate-live`, and `sync-spec` only when their step applies, and leave deleted tasks out of every `addBlockedBy` list.

## Spawn Template

Every spawn prompt starts with the `team-lead` spawn template (`{template}` below), filled for this run:

- **Teammates**: the names the chosen chain spawns (new-feature: `architect, critic, developer, tester, perf, security, impl-critic, reviewer`, plus `live-tester` when Step 4.6 creates `verify-contract`). Once the tracks are known (given in the task, or decided in Step 5), the line lists `developer-a, developer-b, ...` instead of `developer`. `sdd-orchestrator` joins the line when Step 8.5 applies; a re-spawned track developer takes the suffix on its full name (`developer-a-2`, see the `team-lead` protocol)
- **Peers**: `developer → architect: approval request for an addition beyond the plan; the architect answers, and anything that widens the scope goes to the lead`. Chains without an architect: `none — report to the lead only`. Issue numbers for filed markers, review findings, and scope decisions always travel through the lead
- **Code ownership** by chain: `only developer edits source` (new-feature, bug-fix, refactoring, security, dependency, performance; a parallel developer edits only its own track's files, and dependency manifests and lockfiles belong to the one track the lead names, see Step 5); `only writer edits docs and doc comments` (docs); `only cicd edits workflows and tooling config` (ci-cd); spec-driven has its own line in its workflow; in Step 8.5, `sdd-orchestrator` edits only the files of the spec package

**Fix routing**: a message to "the developer" (scope gate, Step 6.5, Step 8) goes to the developer that owns the file in question: `developer` in a single-developer run, `developer-{track}` by file ownership in a parallel run (a finding that spans tracks goes to each owner). In chains whose owner is `writer`, `cicd`, or `sdd-orchestrator`, the same rule routes to that agent.

On every handoff with `follow_ups` above 0, add its path to the follow-up list for Step 7. Parallel developers stay apart through module ownership; validators are report-only. The prompt rules always apply; the plugin's hooks back read-only roles, protected tests, and lead-only commits best-effort where the payload identifies the role (see the README Hooks section).

**Spawn form**: every spawn uses the `team-lead` form. The shorthand `Agent(<agent>, "<task>")` in the reduced chains means `Agent(subagent_type: "dev-agents:<agent>", name: "<name>", description: ..., prompt: "{template}\n\n<task>\n\nHandoffs: ...")`, with the name from this table, which is also the Owner column of each chain:

| Agent | Teammate name |
|---|---|
| `architect`, `debugger`, `sdd-orchestrator` | same as the agent |
| `developer` | `developer`; `developer-a`, `developer-b`, ... for parallel tracks |
| `critic` | `critic` on a plan, `impl-critic` on an implementation |
| `testing-engineer` | `tester` |
| `performance-engineer` | `perf` |
| `security-maintenance` | `security` |
| `code-reviewer` | `reviewer` |
| `tech-writer` | `writer` |
| `cicd-devops` | `cicd` |

## Step 2.5: Clarify (new-feature and spec-driven)

Before spawning the architect, scan the task text and `{spec}` for gaps in six categories: scope boundaries, data and state, error behaviour, NFR targets, integrations, acceptance. Rank the gaps by impact × uncertainty and ask at most four in one `AskUserQuestion` call, each a multiple-choice question with a recommended option. Skip the step when no gap ranks high or the task lists exact changes. Pass the answers to the architect in a `Clarifications:` line (in spec-driven also to `sdd-orchestrator`, which writes them into the spec); when `{spec}` already exists, the architect records them in the plan as spec updates.

## Step 3: Architect

Before spawning, look for a spec that matches the task in the sources listed at the top (an issue that names `specs/{slug}/` points to it). Found → it is `{spec}`: a path, or `issue #N body`. The architect designs within it, and `{spec}` goes into every later `Requirement source:` line and developer prompt. Not found → omit the Spec line.

```
Agent(subagent_type: "dev-agents:architect", name: "architect",
  prompt: "{template}\n\nDesign architecture for: {feature-description}\n\nSpec: {spec}\n\nClarifications: {answers from Step 2.5, or none}")
TaskUpdate(taskId: "plan", owner: "architect", status: "in_progress")
```

WAIT for handoff frontmatter + path. A `no_change_needed` status ends the chain (No-Change Outcome). Otherwise `TaskUpdate(taskId: "plan", status: "completed")`.

## Step 4: Critic (MANDATORY)

```
Agent(subagent_type: "dev-agents:critic", name: "critic",
  prompt: "{template}\n\nCritique the architecture, including plan scope against the request (dimension 9), and assess the Follow-ups entries in the handoffs. Report findings — do NOT write code.\n\nRequirement source: {feature-description, issue numbers, spec path}\n\nHandoffs:\n{accumulated frontmatters}")
TaskUpdate(taskId: "critique", owner: "critic", status: "in_progress")
```

WAIT for critic. First settle scope: every item marked `needs user approval` in the architect's Scope section or flagged `obtain user approval` in the critic's Scope Ledger goes to the user through `AskUserQuestion` (keep or drop, one question per item, up to four per call). Then check `verdict` in the critic's inline frontmatter:
- `critical` or `significant` → `SendMessage(to: "architect", ...)` with the critic handoff and the user's scope decisions for redesign (resume, do not re-spawn), then `SendMessage(to: "critic", ...)` to re-run the critique. At most 3 critique rounds (a round = redesign + re-run): when the third still returns `critical` or `significant`, ask the user with `AskUserQuestion` — continue for another round, accept the plan as is, or stop
- `approved` or `minor` → send the user's scope decisions, if any, to the architect to record in the plan (dropped items leave it), then proceed to Step 4.5

**Evidence check** (here, in Step 6 for the impl-critic, and in Step 8 for the reviewer): before relaying a CRITICAL or SIGNIFICANT correctness finding about existing code, check its `evidence` field. Re-run the stated command or reproducer and compare the output with the claim. A finding with no evidence, or one that does not reproduce, goes back to its author once (`SendMessage`) to supply evidence or withdraw it; if it still lacks evidence it becomes a Question for Authors. Findings about a plan or design (scope, architecture fit, plan conformance) keep reference evidence and need no run.

## Step 4.5: Plan Approval (new-feature)

After the critic gate passes and scope is settled, show the user a one-screen summary of the plan with `AskUserQuestion`: goal, approach, files, contracts, out of scope, risks, and the architect's size estimate. Options: `approve (Recommended)`, `adjust` (the answer goes to the architect for redesign and counts as a critique round: re-run the critic), `stop`. Skip the step when the task already lists the exact changes. `TaskUpdate(taskId: "approve-plan", status: "completed")` after approval.

**Size.** The architect's estimate uses the size classes and points of [triage-and-solve](../triage-and-solve/SKILL.md) (step 5, "Map the estimate to a size class"). In a run started directly (not one that carries a triage estimate from `solve-issue`), an estimate above the 4-point review budget makes the lead propose splitting the work along the plan's tasks into stacked PRs, as an extra option in the same question.

## Step 4.6: Acceptance Tests and Verification Contract (new-feature, and any developer chain started with `{spec}`)

Runs after Step 4.5 and before any developer starts (in a reduced chain started with `{spec}`, right after its lead step, or before the developer when it has none). Spawn the tester, and in parallel the live-tester when the project has a runnable surface.

**Acceptance tests (`acceptance-tests`).** A separate tester agent turns the acceptance criteria (spec or task) and the plan's Contracts into failing tests, in dedicated test files the developer never edits after this step (the profile's `testing.md` names them and the stub idiom). It lists every test with its expected failure reason in its handoff.

```
Agent(subagent_type: "dev-agents:testing-engineer", name: "tester",
  prompt: "{template}\n\nTests-first mode: write failing acceptance tests from the acceptance criteria and the plan's Contracts. Dedicated test files only, no in-module tests. Tests target the API as the plan declares it, even though it does not exist yet. Do NOT edit source.\n\nRequirement source: {feature-description, issue numbers, spec path}\nHandoffs:\n{accumulated frontmatters}")
```

Spawn it with the ownership line `Code ownership: tester creates and edits only the acceptance test files it lists; developers edit source. Only team-lead commits.` WAIT for its handoff. A criterion the tester cannot express as a test (no testable behaviour) is reported in the handoff and goes to the user through `AskUserQuestion`.

**Stubs.** When the tests target a new public API, they cannot compile or type-check yet. Resume or spawn the developer (the track owner in a parallel run) with a stub-only task: add empty signature stubs for every item the tests use, in non-test source files (`todo!()`, `throw new Error("not implemented")`, or the profile's equivalent from `testing.md`), with no behaviour. Then `SendMessage` the tester to run each test and confirm it compiles and fails for its listed reason (the stub, not a typo or an unrelated error), fixing its tests where not. Skip this paragraph when the tests need no new API.

The lead then commits the test files and the stubs as one separate commit and writes the marker `.local/protected-tests` in the working tree: one path per line, relative to the repository root, dedicated test files only (stubs are not listed: the developer replaces them in Step 5). While the marker exists, the plugin's hook denies Edit, Write, and NotebookEdit on a listed path to every caller, best-effort (see the README Hooks section); the prompt rule applies in every case. Delete the marker when the chain ends (commit, stop, or escalation). Every developer prompt names the protected files and says: a test that contradicts the spec is reported with `status: blocked`, never edited. To unprotect a test the user accepts as wrong, the lead removes its line, the resumed tester fixes the test, the lead commits it, and then re-adds the line.

The acceptance-test commit is local only: it must pass format and lint, and each test must fail for its listed reason. It is never pushed red; Step 9 pushes the branch only after the full check suite passes on the final diff. This is the one exception to "full check suite before every commit".

**Verification contract (`verify-contract`).** When the project has a runnable surface (CLI, server, web app, Roblox through Open Cloud probes), spawn the live-tester (`name: "live-tester"`) to write a verification contract from the acceptance criteria: scenarios with commands or steps and a pass criterion each, stored under `.local/testing/contracts/`. Skip for libraries without a runnable surface. Step 6 runs the contract as `validate-live`.

## Step 5: Developer(s)

Analyze the architect's plan (and `{spec}` from Step 3, if any): **can implementation be split into independent subtasks?**

Subtasks are independent when ALL hold: separate modules/crates/packages, no shared mutable state, no cross-task type dependencies, can be tested in isolation.

**Tracks given in the task** (from `/dev-agents:solve-issue` for a group of issues) are the independent subtasks in every chain that has a developer step, not only this one — one developer per track (`developer-a`, `developer-b`, ...), implementing its issues in the listed order. Each track gets its file ownership from the architect's plan, or from the debugger's diagnosis in chains without an architect; when the plan shows two tracks editing the same file or depending on each other's types, merge them into one track instead of letting their developers collide. The changelog and the version field of the version manifests stay with the team lead, edited after all tracks finish and before Step 6, so the validators and the reviewer see them. For `Cargo.toml` and `package.json` the lead changes only the version field, never the dependency sections; when no track owns the lockfile, the lead regenerates it in the same edit (`cargo update -w --offline`, `npm install --package-lock-only`), and when a track owns it, the lead asks that track's developer to regenerate it. Dependency manifests and lockfiles belong to exactly one named track (the one whose issues need the dependency, or the first track when several do): its developer adds every dependency the plan lists for any track, and the lead names that track in every spawn prompt. A developer of another track that needs a dependency reports it to the lead, who forwards it to the owning developer.

**Independent** — spawn one developer per subtask:

```
TaskCreate(subject: "implement-{a}", description: "Implement {a}")
TaskCreate(subject: "implement-{b}", description: "Implement {b}")
TaskUpdate(taskId: "implement-{a}", addBlockedBy: ["acceptance-tests"])
TaskUpdate(taskId: "implement-{b}", addBlockedBy: ["acceptance-tests"])
// delete the base task: TaskUpdate(taskId: "implement", status: "deleted")
// update validate-* to block on all implement-* tasks (validate-live also keeps verify-contract)

Agent(subagent_type: "dev-agents:developer", name: "developer-a",
  prompt: "{template}\n\nImplement only: {a description}. Do NOT touch modules owned by parallel developers.\n\nSpec: {spec}\n\nProtected tests: {paths from .local/protected-tests, or omit the line} — never edit them.\n\nHandoffs:\n{accumulated frontmatters}")
Agent(subagent_type: "dev-agents:developer", name: "developer-b",
  prompt: "{template}\n\nImplement only: {b description}. Do NOT touch modules owned by parallel developers.\n\nSpec: {spec}\n\nProtected tests: {paths from .local/protected-tests, or omit the line} — never edit them.\n\nHandoffs:\n{accumulated frontmatters}")
```

WAIT for ALL parallel developers before validation. Accumulate all handoffs.

A developer already spawned for the Step 4.6 stubs is resumed with `SendMessage` (same task text, plus the protected files) instead of spawned a second time.

**Dependent** — single developer in sequence:

```
Agent(subagent_type: "dev-agents:developer", name: "developer",
  prompt: "{template}\n\nImplement based on architect's plan.\n\nSpec: {spec}\n\nProtected tests: {paths from .local/protected-tests, or omit the line} — never edit them.\n\nHandoffs:\n{accumulated frontmatters}")
TaskUpdate(taskId: "implement", owner: "developer", status: "in_progress")
```

WAIT for developer's handoff.

## Step 6: Parallel Validation (spawn all simultaneously)

```
Agent(subagent_type: "dev-agents:testing-engineer",     name: "tester",
  prompt: "{template}\n\nValidate test coverage. Report findings — do NOT edit source.\nHandoffs: {accumulated}")
// the tester and live-tester from Step 4.6 are still alive: resume them with SendMessage instead of spawning a second one
Agent(subagent_type: "dev-agents:performance-engineer", name: "perf",
  prompt: "{template}\n\nAnalyze performance. Report findings — do NOT edit source.\nHandoffs: {accumulated}")
Agent(subagent_type: "dev-agents:security-maintenance", name: "security",
  prompt: "{template}\n\nSecurity audit. Report findings — do NOT edit source.\nHandoffs: {accumulated}")
Agent(subagent_type: "dev-agents:critic",               name: "impl-critic",
  prompt: "{template}\n\nCritique implementation: logical gaps, missing edge cases, and diff scope against the plan (dimension 9), and assess the Follow-ups entries in the handoffs. Report only — do NOT write code.\nRequirement source: {feature-description, issue numbers, spec path}\nFirst pass: review the diff against the requirement source only, and write your findings down before reading any handoff.\nSecond pass: read the handoffs only to filter your findings against scope and recorded deviations. Follow-ups to assess: {handoff paths with follow_ups > 0, or none}\nHandoffs: {accumulated}")
Agent(subagent_type: "dev-agents:live-tester", name: "live-tester",   // only when verify-contract exists
  prompt: "{template}\n\nRun your verification contract under .local/testing/contracts/ against the built artifact in the working tree (do not switch branches). Report the result per criterion — do NOT edit source.\nHandoffs: {accumulated}")
```

WAIT for ALL validator handoff messages (four, five with `validate-live`). A failed contract criterion blocks review: send it to the owning developer like a review finding. Apply the Evidence check (Step 4) to the impl-critic handoff before the scope gate.

**Follow-up assessment.** The other validators ran in parallel with the impl-critic, so it has not seen their follow-ups: when any validator handoff has `follow_ups` above 0, `SendMessage(to: "impl-critic", ...)` with those paths for Follow-up Assessment and WAIT for its updated handoff.

**Scope gate.** Read the impl-critic's Scope Ledger. Route each entry before review: `obtain user approval` → `AskUserQuestion` (keep or remove); `obtain architect approval` → `SendMessage(to: "architect", ...)` for a decision; in a chain without an architect, take the item to the user through `AskUserQuestion` instead. Then send each owning developer (Fix routing) one message: remove every `remove` entry and every rejected item, and record every approved item under **Deviations** with its approver. WAIT for the developer's handoff. Skip the gate when the ledger says `No untraced items`.

## Step 6.5: Correctness Gate (lead-side, when available)

If the bundled `code-review` skill is listed in this session, run it yourself before spawning the reviewer. It catches plain correctness bugs in the uncommitted diff, so `code-reviewer` can focus on idiomatic, language-specific review:

```
Skill(skill: "code-review", args: "high")
```

The skill picks its own mode. Usually it forks into a background subagent: WAIT for its task notification. When the `ReportFindings` tool is available (desktop app) it runs inline in your context and reports the findings in the same turn; pass `args: "medium"` there to keep the lead's context lean. Either way, send confirmed findings to the developer with `SendMessage` (same shape as Step 8) and WAIT for the fix handoff before Step 7. Never run this inside a teammate: teammates cannot start background work.

## Step 7: Code Review

```
Agent(subagent_type: "dev-agents:code-reviewer", name: "reviewer",
  prompt: "{template}\n\nReview implementation. Triage every follow-up and every new TODO/FIXME/HACK/XXX marker in the diff, and file the issues (your Follow-up Sources and Filing sections).\n\nRequirement source: {feature-description, issue numbers, spec path}\nFirst pass: review the diff against the requirement source only, and write your findings down before reading any handoff.\nSecond pass: read the handoffs only to filter your findings against scope and recorded deviations.\n\nFollow-ups to triage: {handoff paths with follow_ups > 0, or none}\nCritic follow-up assessments: {critic and impl-critic handoff paths}\n\nHandoffs:\n{all accumulated frontmatters}")
```

WAIT for reviewer's handoff. Apply the Evidence check (Step 4) to its CRITICAL and IMPORTANT correctness findings before Step 8. Security items the reviewer reports for the private advisory process go to the user; never open a public issue for them.

## Step 8: Fix-Review Cycle

Check `verdict` in the reviewer's inline frontmatter (no file read needed):

CRITICAL and IMPORTANT findings block approval. A SUGGESTION or NITPICK outside the change (code the diff did not touch, or a concern the task does not cover) never reaches the developer: the reviewer files it through its Filing path and it opens no round. An in-scope SUGGESTION is fixed, or declined with a one-line reason under `Declined Suggestions` in the developer handoff, and the reviewer accepts a reasoned decline. An in-scope NITPICK never opens a fix round: the formatter and linter fix it, and one they cannot fix (naming) rides along with a fix round when one happens, otherwise the reviewer files it as a follow-up issue.

If `verdict: changes_requested`, send each finding to the developer that owns its file (Fix routing):

```
SendMessage(to: "developer", summary: "Fix review issues",
  message: "Fix every CRITICAL and IMPORTANT issue from review. For each in-scope SUGGESTION, fix it or decline it with a one-line reason under Declined Suggestions in your handoff. Run the formatter and linter for NITPICKs; fix the rest only if listed here.\n\nReviewer frontmatter:\n{inline}\nFile: {path}\nIssue numbers for markers the reviewer filed: {list, rewrite each marker as TODO(#N)}")
```

WAIT for the developer's new handoff. When the fix diff changes logic (not only names, comments, or formatting), `SendMessage` the fix diff to `impl-critic` and `tester` (where the chain has them) to re-check it, and to `live-tester` when it ran in Step 6, and WAIT for all of them. Apply the Evidence check (Step 4) to what they report. Run the Scope gate (Step 6) again on every new Scope Ledger entry from the impl-critic re-check, and settle each before the reviewer re-review. Then pass to the reviewer:

```
SendMessage(to: "reviewer", summary: "Re-review after fixes",
  message: "Re-review after fixes. Check only your previous findings and the fix diff; report no new SUGGESTION or NITPICK on code the fix did not change. Accept a reasoned decline of a SUGGESTION and list it under Declined Suggestions; file every NITPICK the fix left unresolved as a follow-up issue.\n\nDeveloper frontmatter:\n{inline}\nFile: {path}")
```

WAIT for the reviewer. Repeat until `verdict: approved`, at most 3 rounds (a round = fix + re-review). When the third re-review still returns `changes_requested`, ask the user with `AskUserQuestion` — continue for another round, accept the current state, or stop.

## Step 8.5: Spec Sync (when `{spec}` is a committed `specs/` package)

After the reviewer approves and before Step 9, spawn `sdd-orchestrator` (`name: "sdd-orchestrator"`; spec-driven runs reuse theirs) with the Deviations of every developer handoff, the approved Scope Ledger entries, and the completed tasks. It follows the delta model of the `sdd` skill (Delta Model): it writes the approved Deviations into the spec package as a delta, merges the delta into the capability spec, archives it, and marks the completed tasks in `tasks.md`. It edits only files under the spec package and reports in a handoff. `TaskUpdate(taskId: "sync-spec", status: "completed")`. Skip the step when `{spec}` is an issue body or a `.local/specs/` draft.

## Step 9: Commit and PR

Only after reviewer approves and Step 8.5 is done. Delete `.local/protected-tests` if it still exists; the commit includes the spec files Step 8.5 changed. When the approved handoff lists NITPICKs the formatter fixes, have the developer run the profile's formatter and linter first, with no re-review. Read `.claude/rules/commits-and-issues.md` if it exists.

Claude Code tells you to run the project `verify` skill before committing. The reviewer's check-suite run on the approved diff (plus `live-tester`, if it ran on the final diff) covers it; run the skill's "Before a commit" path only when no check-suite run has seen the final diff.

```bash
git add <explicit paths>   # never `git add -p`: interactive
git commit -m "$(cat <<'EOF'
type(scope): description

Body if needed.
EOF
)"
git push -u origin {branch}
gh pr create --title "..." --body "..."
```

When the task came from GitHub issues, the PR body closes each one with its own `Closes #{number}` line.

The PR body lists every issue from the reviewer's Follow-up Issues section under a `Follow-up issues` heading (one per line, `#N — title`). After the PR exists, link each one back: `gh issue comment N --body "Found while working on #<PR>"`. Report the follow-up issue numbers to the user with the PR URL.

## Step 10: Shutdown

Per the `team-lead` protocol (Shutdown), shut down an agent once no later step will message it. These stay alive until the commit, because the scope gate, Step 6.5, the critique re-run, and the fix cycle address them: the architect (when the chain has one), every developer or chain owner (`writer`, `cicd`, `sdd-orchestrator`), `impl-critic`, `tester`, `live-tester` (when it ran), and `reviewer`. The plan `critic` also stays until the Step 4 gate passes. Shut down the rest after their handoff. After the commit, shut down everyone left.

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

Pick one based on Step 0 classification. Steps 2–10 above describe the **New Feature** chain. The reduced chains below reuse the same team setup, spawn template, handoff protocol, follow-up routing (Step 7), fix-review cycle (Step 8), commit rules (Step 9), and shutdown (Step 10) — only the task graph and spawned agents differ.

**Mandatory critic gate**: every chain in which `developer` writes code (New Feature, Bug Fix, Refactoring, Security, Dependency Bump, Performance) MUST run an `impl-critic` (`critic`, report-only) on the validation step after the developer and before code review — adversarial critique of the implementation is never skipped. Chains with no `developer` phase (Documentation, CI/CD, Spec-Driven) are exempt because no implementation code is produced. Every `critic` and `impl-critic` spawn prompt, in every chain, carries a `Requirement source:` line (the task text, issue numbers, spec path) and asks for scope conformance (dimension 9) and an assessment of the Follow-ups entries in the handoffs it receives; the follow-up assessment and scope gate after the validators apply to every chain with an `impl-critic`. In chains without a critic the reviewer checks follow-ups itself.

### Workflow: Bug Fix

`debugger → developer → (tester, impl-critic) → reviewer → commit`. No architect, no perf/security validators.

| Task | Owner | Description |
|---|---|---|
| diagnose | debugger | Root cause, repro steps, fix sketch |
| verify-contract | live-tester | Conditional: verification contract for the bug scenario (Step 4.6 form; only with a runnable surface) |
| implement | developer | Apply the fix |
| validate-tests | tester | Verify the regression test fails without the fix and passes with it; report coverage gaps |
| validate-critique | impl-critic | **Adversarial critique of the fix: missed edge cases, incomplete root-cause coverage (MANDATORY)** |
| validate-live | live-tester | Conditional: run the contract against the built artifact; a failed criterion blocks review |
| review | reviewer | Code review |
| fix-issues | developer | Conditional (changes_requested) |
| re-review | reviewer | Conditional |
| commit | team-lead | Commit and PR |

```
TaskUpdate(taskId: "implement",         addBlockedBy: ["diagnose"])
TaskUpdate(taskId: "verify-contract",   addBlockedBy: ["diagnose"])
TaskUpdate(taskId: "validate-tests",    addBlockedBy: ["implement"])
TaskUpdate(taskId: "validate-critique", addBlockedBy: ["implement"])
TaskUpdate(taskId: "validate-live",     addBlockedBy: ["implement", "verify-contract"])
TaskUpdate(taskId: "review",            addBlockedBy: ["validate-tests", "validate-critique", "validate-live"])
TaskUpdate(taskId: "fix-issues",        addBlockedBy: ["review"])
TaskUpdate(taskId: "re-review",         addBlockedBy: ["fix-issues"])
TaskUpdate(taskId: "commit",            addBlockedBy: ["re-review"])
```

Spawn order:

1. `Agent(subagent_type: "dev-agents:debugger", name: "debugger", ...)` — diagnose. WAIT for handoff; `no_change_needed` ends the chain (No-Change Outcome).
2. When the project has a runnable surface (CLI, server, web app, Roblox through Open Cloud probes), spawn `live-tester` (`name: "live-tester"`) to write the verification contract for the bug scenario, as in Step 4.6; skip it for libraries. Then `Agent(subagent_type: "dev-agents:developer", name: "developer", ...)` — pass debugger handoff. WAIT for both.
3. Spawn **in parallel** after developer, all report-only (do NOT edit source):
   - `Agent(subagent_type: "dev-agents:testing-engineer", name: "tester", ...)` — verify the developer's regression test and report coverage gaps.
   - `Agent(subagent_type: "dev-agents:critic", name: "impl-critic", ...)` — critique the fix: missed edge cases, incomplete root-cause coverage.
   - `SendMessage(to: "live-tester", ...)` — run the contract against the built artifact when step 2 spawned it.
   WAIT for ALL handoffs. A failed contract criterion blocks review.
4. `Agent(subagent_type: "dev-agents:code-reviewer", name: "reviewer", ...)` — review, with tester + impl-critic handoffs accumulated. WAIT.
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

1. `Agent(architect, "Refactor plan for: {desc}")` — WAIT. **Skip entirely** if user already named the renames/moves/extractions.
2. `Agent(developer)` — WAIT.
3. Spawn **in parallel** after developer, both report-only (do NOT edit source):
   - `Agent(testing-engineer, "Run full test suite, confirm no behavioral changes")`.
   - `Agent(subagent_type: "dev-agents:critic", name: "impl-critic", "Critique the refactor: confirm behavior is preserved, flag any hidden semantic drift")`.
   WAIT for BOTH handoffs.
4. `Agent(code-reviewer)` — with tester + impl-critic handoffs accumulated. WAIT.
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

1. `Agent(security-maintenance, "Audit: {scope}")` — WAIT. For RUSTSEC or GHSA advisories include advisory ID and link in the spawn prompt.
2. `Agent(developer, "Apply fixes from security handoff")` — WAIT.
3. `Agent(subagent_type: "dev-agents:critic", name: "impl-critic", "Critique the security fix: incomplete mitigation, new attack surface, missed edge cases. Report only — do NOT write code")` — WAIT.
4. `Agent(code-reviewer)` — with security + impl-critic handoffs accumulated. WAIT.
5. Fix-review cycle if needed; commit; shutdown.

Skip `audit` (start at developer) if the task already specifies the CVE/RUSTSEC/GHSA and the required fix.

### Workflow: Documentation

`tech-writer → reviewer → commit`. No developer (tech-writer edits docs directly), no tester/security/perf — documentation does not affect runtime behavior. Applies to README, mdBook chapters, API doc comments (rustdoc, TSDoc), CHANGELOG narrative.

| Task | Owner | Description |
|---|---|---|
| write | writer | Write or edit documentation |
| review | reviewer | Verify accuracy against code, check links/examples build |
| fix-issues | writer | Conditional |
| re-review | reviewer | Conditional |
| commit | team-lead | Commit and PR |

```
TaskUpdate(taskId: "review",     addBlockedBy: ["write"])
TaskUpdate(taskId: "fix-issues", addBlockedBy: ["review"])
TaskUpdate(taskId: "re-review",  addBlockedBy: ["fix-issues"])
TaskUpdate(taskId: "commit",     addBlockedBy: ["re-review"])
```

Spawn order:

1. `Agent(subagent_type: "dev-agents:tech-writer", name: "writer", ...)` — write/edit docs. WAIT for handoff. The writer (not developer) handles fix-issues; reassign ownership in the fix-review cycle (Step 8) accordingly.
2. `Agent(subagent_type: "dev-agents:code-reviewer", name: "reviewer", ...)` — verify accuracy against current code, run the stack profile's doc gate (e.g. `cargo doc --no-deps` without broken intra-doc links and passing doc-tests for Rust, a TypeDoc/`tsc` build for TypeScript, the Luau type check for Luau). WAIT.
3. Fix-review cycle (Step 8) — but route fix messages to `writer` instead of `developer`.
4. Commit (Step 9), shutdown (Step 10).

If the change is API-doc-only and includes new runnable examples (Rust doctests), also spawn `Agent(testing-engineer)` between writer and reviewer to confirm they pass (`cargo test --doc`).

### Workflow: Dependency Bump

`developer → (security, tester, impl-critic) → reviewer → commit`. Security audit is mandatory (new advisories can ship with bumps); full test suite must pass; critic validates any API-breakage adapter code.

| Task | Owner | Description |
|---|---|---|
| update | developer | Apply bump in the manifest (`Cargo.toml`, `package.json`, `wally.toml`, `pesde.toml`, `*.rockspec`), regenerate the lockfile, resolve compile and type errors |
| audit | security | Dependency audit from the stack profile (`cargo deny check` / `cargo audit`, `npm audit` / `pnpm audit`): new advisories (RUSTSEC, GHSA), yanked or deprecated packages |
| validate-tests | tester | Run full workspace test suite, integration tests, doctests |
| validate-critique | impl-critic | **Adversarial critique of API-breakage adapters: incorrect migration, behavior drift, missed edge cases (MANDATORY)** |
| review | reviewer | Review diff of the manifest and lockfile, any API breakage adapters |
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

1. `Agent(developer, "Bump: {package@version, `cargo update`, or `npm update`}")` — WAIT.
2. Spawn `security-maintenance`, `testing-engineer`, and `critic` (name: "impl-critic", critique API-breakage adapters — report only) **in parallel** after developer. WAIT for all three handoffs.
3. `Agent(code-reviewer)` with all four handoffs accumulated. WAIT.
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

1. `Agent(performance-engineer, name: "perf", "Profile and propose plan for: {target}")` — WAIT for baseline + plan in handoff.
2. `Agent(developer)` — apply per perf handoff. WAIT.
3. Resume `perf` with `SendMessage` (new task `verify`; never spawn a second `perf`), and spawn `testing-engineer`, and `critic` (name: "impl-critic", critique optimization for logical gaps and edge cases — report only) **in parallel** after developer. WAIT for all three. Keep `perf` alive until Step 10 for this reason.
4. `Agent(code-reviewer)` with all handoffs. WAIT.
5. Fix-review cycle; commit; shutdown.

Commit body must include the measured before/after numbers from perf's verify handoff. If `verify` shows no improvement or regression, do NOT proceed to review — message developer to retry or escalate to `refactoring` (structural change needed).

### Workflow: CI/CD

`cicd → reviewer → commit`. CI/CD engineer edits workflows/tooling directly. No developer — these changes don't touch source code.

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

1. `Agent(subagent_type: "dev-agents:cicd-devops", name: "cicd", ...)` — apply changes. WAIT for handoff.
2. `Agent(code-reviewer)` with cicd handoff. Reviewer should validate YAML with `fy lint`. WAIT.
3. Fix-review cycle (route fix messages to `cicd`, not `developer`); commit; shutdown.

If the CI change also touches source code (e.g. adding a new lint that triggers code fixes), escalate to `refactoring` — `cicd` does not edit application sources.

### Workflow: Spec-Driven

`architect → critic → sdd-orchestrator → reviewer → commit-spec → follow-up issue`. Design-only mode: no implementation code is written. The chain produces a versioned specification under `specs/{feature-slug}/` and a GitHub issue that hands the spec off to a future implementation pass (usually a `new-feature` team-develop run that picks up the spec from `specs/`).

| Task | Owner | Description |
|---|---|---|
| plan | architect | Architecture plan — design only, no code. State assumptions, alternatives, trade-offs |
| critique | critic | **Adversarial critique of the plan (MANDATORY)** |
| specify | sdd-orchestrator | Convert plan + critic findings into a spec package under `specs/{feature-slug}/`: spec, plan (with Contracts), and tasks by default; BRD / SRS / NFR only when the task asks for them or the work is a new system |
| review | reviewer | Final spec review: completeness, traceability (BRD→SRS→spec→tasks), consistency, acceptance criteria coverage, no implicit assumptions |
| fix-issues | sdd-orchestrator | Conditional — refine spec per reviewer findings |
| re-review | reviewer | Conditional |
| commit-spec | team-lead | Commit `specs/{feature-slug}/`, push the branch, open the spec PR |
| create-issue | team-lead | Open follow-up implementation issue with spec link, spec PR, and recommended chain |

```
TaskUpdate(taskId: "critique",     addBlockedBy: ["plan"])
TaskUpdate(taskId: "specify",      addBlockedBy: ["critique"])
TaskUpdate(taskId: "review",       addBlockedBy: ["specify"])
TaskUpdate(taskId: "fix-issues",   addBlockedBy: ["review"])
TaskUpdate(taskId: "re-review",    addBlockedBy: ["fix-issues"])
TaskUpdate(taskId: "commit-spec",  addBlockedBy: ["re-review"])
TaskUpdate(taskId: "create-issue", addBlockedBy: ["commit-spec"])
```

**Code ownership for this chain** (the `Code ownership:` line of the spawn template):

```
Code ownership: no source files are edited in this chain; only sdd-orchestrator writes, and only spec artifacts under specs/{feature-slug}/. Only team-lead commits and opens issues.
```

Spawn order:

0. Run Step 2.5 (Clarify) and pass the answers to `architect` and `sdd-orchestrator` in a `Clarifications:` line.
1. `Agent(subagent_type: "dev-agents:architect", name: "architect", ..., "Design plan only — NO implementation code, NO edits to source files. Produce a written plan covering: scope, assumptions, alternatives considered, trade-offs, open questions. Target: {desc}")` — WAIT for handoff.
2. `Agent(subagent_type: "dev-agents:critic", name: "critic", ..., "Critique the plan. Report findings — do NOT write code.\nHandoffs:\n{architect}")` — WAIT. Apply the same verdict gate as Step 4 of the full pipeline: `critical` or `significant` → pass critic handoff back to architect, re-run critic; `approved` or `minor` → proceed to sdd-orchestrator.
3. `Agent(subagent_type: "dev-agents:sdd-orchestrator", name: "sdd-orchestrator", ..., "Convert the approved plan and critic findings into a complete spec package under specs/{feature-slug}/. Produce spec → plan (with Contracts) → tasks; run BRD → SRS → NFR first only when {the task text asks for them, or the work is a new system — otherwise omit this clause}. When a capability spec already exists under specs/, write a delta file per the sdd skill's Delta Model instead of rewriting it. Cite the architect plan and critic concerns as inputs in the spec body. You run non-interactively: follow your Non-Interactive Mode. Spec root: specs/{feature-slug}/ (no NNN prefix, no MOC or constitution links). Do NOT write or edit any source files outside specs/{feature-slug}/.\nHandoffs:\n{architect, critic}")` — WAIT.
4. `Agent(subagent_type: "dev-agents:code-reviewer", name: "reviewer", ..., "Final review of the spec at specs/{feature-slug}/. Check: completeness (every spec requirement traced to the plan and to tasks; BRD and SRS links only when those documents exist), internal consistency, acceptance criteria are testable, NFRs are measurable, open questions are explicit, no implicit assumptions. Verify spec files are well-formed (fy lint on any YAML, links resolve). Do NOT review for code quality — there is no code yet.\nHandoffs:\n{architect, critic, sdd-orchestrator}")` — WAIT.
5. **Fix-review cycle** (Step 8) — but route fix messages to `sdd-orchestrator` instead of `developer`. Reassign `fix-issues.owner` to `sdd-orchestrator` in TaskUpdate. Repeat until the reviewer returns `verdict: approved`, within the Step 8 round limit.
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
   gh pr create --title "spec({feature-slug}): add specification" --body "..."
   ```

   The spec reaches the default branch only through this PR; an implementation run started from the default branch sees `specs/{feature-slug}/` only after it merges.

7. **Create follow-up issue** — `gh issue create` with body that links the spec, summarizes scope, and recommends the next chain:

   ```bash
   gh issue create --title "Implement: {feature title}" --body "$(cat <<'EOF'
   ## Spec
   See `specs/{feature-slug}/`, added by spec PR #{spec-pr}.

   ## Summary
   {one-paragraph scope from the spec}

   ## Acceptance criteria
   {bulleted list lifted from spec — testable items only}

   ## Suggested next step
   After spec PR #{spec-pr} merges, run `/dev-agents:solve-issue` on this issue (new-feature chain); its Step 3 passes `specs/{feature-slug}/` to the architect and developer.
   EOF
   )" --label spec-driven --label implementation
   ```

   If the repository does not have the `spec-driven` or `implementation` labels, drop the `--label` flags (do not auto-create labels).

8. Shutdown (Step 10) — teammates exit gracefully; team directories are cleaned up automatically at session end.

**Escalation from spec-driven**:

- If sdd-orchestrator reports during `specify` that the architect's plan is small enough to implement directly (a few files, no open questions, no architectural choices left) — pause the chain and propose downgrading to `new-feature` per the Escalation Rule. Do not silently produce a spec for a one-day task.
- If the reviewer reports during `review` that the spec is fundamentally incomplete and the architect needs to revisit scope (not just the sdd-orchestrator refining wording) — loop back to architect, not to sdd-orchestrator. Re-run critic and sdd-orchestrator afterward.

Skip the `architect → critic` lead-in (start at sdd-orchestrator) only if the user has already produced an approved plan or RFC and explicitly says "just turn this into a spec". Otherwise the architect+critic gate is mandatory — sdd-orchestrator needs an adversarially-vetted plan as input, not raw user notes.

### Workflow: Task Loop

`lead (smoke test) → tester (acceptance tests) → developer-t{NNN} → lead (checks, commit, progress) → per group: (tester, impl-critic, reviewer)`. Implements an approved spec's `tasks.md` one task per fresh developer session, one commit per task, with a machine-readable `progress.json`. The loop, its resume rule, and the validator set are in [task-loop.md](references/task-loop.md): read it before spawning anything in this chain.
