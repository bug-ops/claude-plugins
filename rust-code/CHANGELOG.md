# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.25.2] - 2026-04-15

### Changed

- `team-debug` skill: added Step 3.5 Live Reproduction — when the debugger's handoff indicates that the root cause requires live testing, `rust-ci-analyst` is spawned to attempt reproduction following the continuous improvement protocol; result (confirmed / not reproduced / intermittent) is propagated to all parallel reviewers and included in the final report

## [1.25.1] - 2026-04-14

### Added

- `team-debug` skill: new multi-agent debugging workflow — debugger investigates root cause, parallel review by architect, critic, security, and conditionally performance engineer, code reviewer consolidates findings, debugger applies fixes, results presented to user for issue/epic creation and handoff to `team-develop`

### Changed

- `rust-team` skill renamed to `team-develop` for naming clarity and consistency with the new `team-debug` skill

## [1.24.1] - 2026-04-12

### Changed

- `continuous-improvement` skill: SDD agent is now invoked before filing GitHub issues for all non-trivial findings (P0–P2 bugs, enhancements, research/parity gaps)
  - Added Phase 3.5 Spec Creation step in `SKILL.md` — spawns `sdd` agent with full finding context before filing
  - Phase 5 Research & Parity updated: each research finding gets a spec before the issue is filed
  - `references/issue-management.md`: step 4 in Filing Protocol now mandates spec creation above threshold
  - `references/research-protocol.md`: SDD invocation step added before duplicate check
  - New `references/sdd-integration.md`: complete protocol — threshold table, non-interactive invocation template, spec naming convention, output contract, issue body template with spec reference

## [1.24.0] - 2026-04-12

### Added

- `spec-from-stream` skill: transforms stream-of-consciousness product descriptions into structured business requirements documents — BRD, SRS (ISO/IEC/IEEE 29148:2018), NFR (ISO/IEC 25010:2011), all formatted as Obsidian notes with full cross-linking
  - `references/brd-template.md`: Business Requirements Document template
  - `references/srs-template.md`: Software Requirements Specification template (ISO/IEC/IEEE 29148:2018)
  - `references/nfr-template.md`: Non-Functional Requirements template (ISO/IEC 25010:2011)
  - `references/question-bank.md`: guided gap-filling question bank with stop-signal detection
  - `references/vault-template.md`: Zettelkasten decomposition instructions for spec documents

### Removed

- `rust-team` skill: SDD agent step removed from the orchestration workflow — SDD is now a prerequisite step that must be run by the user **before** launching rust-team, not embedded inside it. Added prerequisite note to the skill. Updated dependency chain: developer now unblocks after critic (was: after sdd).

### Changed

- `sdd` agent: expanded from a formatting-only specialist to a full-cycle SDD orchestrator
  - Now covers the complete pipeline: stream-of-consciousness → BRD/SRS/NFR → spec/plan/tasks → knowledge base
  - Added `spec-from-stream` skill dependency
  - Upgraded model from `haiku` to `sonnet`, permission mode set to `acceptEdits`
  - Added routing logic to enter the pipeline at the correct phase based on user input
  - BRD/SRS/NFR artifacts feed directly into spec/plan/tasks generation (Phase B reads Phase A output)
  - Memory section added: agent captures user patterns and domain terms after each phase

## [1.23.2] - 2026-04-11

### Changed

- `rust-team` skill: added SDD agent step (Step 4.5 / Step 2.75) between critic approval and developer spawn — after the architecture critique is approved, the `rust-agents:sdd` agent creates or updates a structured specification in `.local/specs/` before implementation begins
- `rust-team`: updated task dependency chain — `specify` task now sits between `critique` and `implement`, blocking the developer until the spec is ready
- `rust-team`: handoff accumulation chain extended — SDD handoff is passed to all subsequent agents (developer, validators, reviewer)
- `rust-team`: Refactoring workflow template updated to include `critic` and `sdd` steps (`architect → critic → sdd → developer → ...`)

## [1.23.0] - 2026-04-10

### Added

- `obsidian-zettelkasten` skill: format documentation as Obsidian knowledge base using Zettelkasten method — atomic notes, wikilink cross-referencing, Maps of Content, YAML properties, callouts, tag taxonomy
  - `references/obsidian-syntax.md`: complete Obsidian Markdown syntax reference (properties, wikilinks, embeds, callouts, tags, math, Mermaid, HTML)
  - `references/zettelkasten-structure.md`: note types, linking patterns, vault conventions, templates, processing workflow

### Changed

- `sdd` agent: added `obsidian-zettelkasten` skill dependency, all spec artifacts now use Obsidian-flavored Markdown
- `sdd` skill: all templates converted to Obsidian format — YAML frontmatter properties replace blockquote metadata, wikilinks replace plain links, Mermaid replaces ASCII diagrams, callouts replace raw blockquotes, MOC-specs index note added to init phase, Obsidian format check added to review phase. Formatting rules delegated to `obsidian-zettelkasten` (no duplication)
- `rust-architect` agent: removed `sdd` skill dependency and Phase 0 (Specification). Architect produces architectural plans only; specifications are created by the dedicated `sdd` agent

## [1.22.0] - 2026-04-10

- `rust-ci`, `rust-tech-writer` optimise model token usage

## [1.22.0] - 2026-04-07

### Changed

- `rust-team` skill: main session now acts as team lead directly — no separate `rust-teamlead` subagent layer. Fixes teamlead self-implementing instead of delegating.
- `rust-team` skill: fully self-contained — embedded team communication template, spawn instructions, fix-review cycle, report format. No more `cat references/` commands that failed outside plugin directory.
- `solve-issue` skill: step 5 now invokes `rust-team` skill directly instead of spawning `rust-teamlead` subagent.
- All agent spawn templates: corrected `SendMessage` recipient from `"teamlead"` to `"team-lead"` (matches `TEAM_LEAD_NAME` constant in Claude Code source).

### Removed

- `rust-teamlead` agent definition — redundant with the main session acting as team lead.

## [1.21.2] - 2026-04-07

### Fixed

- `solve-issue` skill: step 5 now spawns `rust-agents:rust-teamlead` agent instead of invoking `/rust-agents:rust-team` skill directly — prevents main Claude from acting as orchestrator without teamlead constraints, fixing the issue where teamlead was implementing code itself
- `solve-issue` skill: removed description of `rust-team` internal agent sequence (separation of concerns)
- `triage-and-solve` skill: removed description of `solve-issue` internal steps (separation of concerns)

## [1.21.1] - 2026-04-07

### Changed

- `solve-issue` skill: removed `disable-model-invocation` restriction
- `continuous-improvement` skill: removed `disable-model-invocation` restriction

## [1.21.0] - 2026-04-07

### Added

- `init-project` skill: new `.claude/rules/commits-and-issues.md` rule template — centralizes Conventional Commits 1.0.0 format specification and issue filing protocol in one place
- `rust-teamlead` agent: explicit requirement to follow Conventional Commits 1.0.0 and read `.claude/rules/commits-and-issues.md` before composing commit messages
- `rust-code-reviewer` agent: commit message format added to approval criteria checklist
- `solve-issue` skill: reads `.claude/rules/commits-and-issues.md` when present for commit and issue conventions

### Changed

- `continuous-improvement/references/issue-management.md`: added pointer to canonical `.claude/rules/commits-and-issues.md` to avoid duplication

## [1.20.0] - 2026-04-07

### Added

- `tech-writer` agent (agent 13): autonomous technical writer specializing in user-facing documentation with mdBook, progressive disclosure storytelling
- `mdbook-tech-writer` skill: write, structure, and maintain high-quality technical documentation using mdBook

## [1.19.7] - 2026-04-05

### Changed

- `rust-agent-handoff` skill: handoff format migrated from flat YAML to Markdown+YAML frontmatter (`.yaml` → `.md`)
  - Frontmatter contains only flat scalar routing metadata: `id`, `parent`, `agent`, `status`, `summary`, `next_agent`, `next_task`, `next_priority`
  - New `summary` field in frontmatter: one sentence of what was done — enables ancestor chain traversal via frontmatter-only reads instead of full file reads
  - Body uses free Markdown sections (`## Context`, `## Output`, `## Blockers`, `## Acceptance Criteria`) — eliminates YAML indentation errors in complex output
  - New inline frontmatter passing: agents return frontmatter block in response so parent can route without reading any files
  - New frontmatter-only read command (`awk`) for ancestor chain traversal — reduces token cost for deep chains by ~70%
  - All `references/*.md` rewritten: YAML output schemas replaced with Markdown section templates; domain knowledge preserved

## [1.19.6] - 2026-04-05

### Changed

- All agents: added explicit DRY (Don't Repeat Yourself) guidance to prevent code duplication
  - `rust-developer`: new "DRY" section with mandatory Grep/Glob search before implementing any function, trait, or module; anti-patterns updated
  - `rust-code-reviewer`: DRY violations added as 🟡 IMPORTANT review criterion; new DRY checklist in Code Quality Checklist
  - `rust-architect`: new "DRY at Architecture Level" section — scan for existing abstractions before designing new ones; shared logic must go to core/domain crate
  - `rust-testing-engineer`: new "DRY in Tests" section — shared fixtures in `tests/common/`, reuse mocks, extract repeated setup to helpers
  - `rust-critic`: DRY violations (duplicated logic, copy-pasted error variants) added to "Alternative Hypotheses" red flags

## [1.19.5] - 2026-04-05

### Fixed

- `rust-team` skill: added mandatory reading step at startup — model now explicitly reads `references/team-workflow.md`, `references/communication-protocol.md`, and `references/result-aggregation.md` before proceeding

## [1.19.4] - 2026-04-05

### Fixed

- `rust-teamlead` agent: spawn prompt template in agent definition used ambiguous `run /rust-agent-handoff` — replaced with explicit `Skill(skill: "rust-agents:rust-agent-handoff")` call and step-by-step handoff instructions (timestamp capture, schema reading, YAML write before finishing)
- `rust-teamlead` agent: teamlead's own handoff chain section also used `run /rust-agent-handoff` — replaced with `Skill(...)` call
- All 9 specialist agents (architect, developer, testing, performance, security, reviewer, cicd, debugger, critic): added `# Startup Protocol (MANDATORY)` section with explicit `Skill(skill: "rust-agents:rust-agent-handoff")` call, timestamp capture, schema read, and handoff write instructions — agents previously had the skill listed in frontmatter but no instruction to invoke it

## [1.19.3] - 2026-04-05

### Fixed

- `rust-team` skill: replaced ambiguous `run /rust-agent-handoff` in agent spawn prompts with explicit `Skill(skill: "rust-agents:rust-agent-handoff")` call — agents now correctly load and follow the handoff protocol
- `rust-team` skill: communication-protocol template now includes step-by-step handoff instructions with timestamp capture, schema reading, and mandatory YAML write before finishing

## [1.19.2] - 2026-04-05

### Fixed

- `rust-agent-handoff` skill: corrected `reference/` path typo to `references/` in startup instructions — agents now correctly read agent-specific output schemas
- `rust-agent-handoff` skill: consolidated duplicate `## On Startup` sections into a single ordered sequence to prevent agents from missing timestamp capture or schema reading steps

## [1.19.1] - 2026-04-04

### Changed

- `rust-architect` agent: added Phase 0 (Specification) — create/update spec via `/sdd` skill after analysis when developing new functionality
- `rust-architect` agent: added Specification section to Pre-Implementation Checklist
- `rust-agent-handoff` skill: added `spec` field to architect output schema for propagating spec path through handoff chain
- `rust-agent-handoff` skill: agents now check `output.spec` in handoff chain and read spec before starting work

## [1.19.0] - 2026-04-03

### Added
- `rust-teamlead` agent — team orchestrator for multi-agent collaborative development (merged from rust-team plugin)
- `rust-team` skill — full team workflow with communication protocol, task structure, and result aggregation (merged from rust-team plugin)

## [1.18.0] - 2026-04-03

### Removed
- `rust-lifecycle` skill — use `rust-team` skill instead for full development workflow orchestration

## [1.17.2] - 2026-03-27

### Fixed
- Add `ToolSearch("select:TaskCreate,TaskUpdate,TaskList,TaskGet")` as first step in `rust-lifecycle` workflow-steps.md — task tools are deferred and must be loaded before use; without schema load the LLM emits wrong parameter names (e.g. `id` instead of `taskId`)

## [1.17.1] - 2026-03-26

### Changed
- Replace deprecated `TaskOutput` references with `Read` on task output file path in `rust-lifecycle` skill

## [1.17.0] - 2026-03-21

### Added
- `effort` frontmatter for all agents: `high` for architect (deep architectural reasoning), `medium` for all others (security, critic, developer, testing, performance, cicd, debugger, code-reviewer, sdd)
- `effort` frontmatter for skills: `medium` for sdd, `low` for fast-yaml
- `maxTurns` frontmatter for critic (15) and code-reviewer (20) to prevent unbounded iterations
- `maxTurns` prevents unbounded iterations in review-only agents

## [1.16.0] - 2026-03-17

### Added
- `sdd` agent: Spec-Driven Development specialist for creating structured specifications, technical plans, and implementation task breakdowns
- `sdd` skill: Self-contained SDD workflow with embedded constitution, spec, plan, and tasks templates; supports `init`, `specify`, `plan`, `tasks`, and `review` phases

### Changed
- `rust-architect`: added `sdd` skill to enable structured spec output in SDD format when planning features

## [1.15.4] - 2026-03-13

### Changed
- `rust-architect`: added `ultrathink` directive before the Architecture Decision Framework to trigger extended thinking on architectural decisions
- `rust-critic`: added `ultrathink` step in the Critique Process before applying the eight dimensions to surface non-obvious failure modes
- `rust-debugger`: downgraded model from `opus` to `sonnet` — debugging is iterative tool use, not deep reasoning; sonnet's speed is an advantage

## [1.15.2] - 2026-03-10

### Changed
- `rust-code-reviewer`: downgraded model from `opus` to `sonnet` — review tasks are pattern-based and do not require deep reasoning

## [1.15.1] - 2026-03-04

### Fixed
- `readme-generator` skill: added warning that GitHub callouts (`[!NOTE]`, `[!TIP]`, etc.) render
  as plain blockquotes on PyPI and npm — avoid using them for Python and TypeScript/JavaScript packages

## [1.15.0] - 2026-03-04

### Changed
- `rust-lifecycle` skill: `rust-critic` now runs a second time in the parallel validation phase
  after implementation, alongside `rust-performance-engineer`, `rust-security-maintenance`, and
  `rust-testing-engineer`
- Added `phase-N-validate-critique` task that blocks on `phase-N-implement` and unblocks
  `phase-N-review`, matching the dependency pattern of other validation tasks
- `rust-code-reviewer` now receives the critic's implementation handoff alongside performance,
  security, and testing handoffs for a more complete review context
- Updated workflow diagram and task structure table in `SKILL.md` to reflect the new step

## [1.14.1] - 2026-03-04

### Fixed
- `rust-critic` workflow diagrams: removed square brackets that implied optional invocation; added explicit `(MANDATORY)` marker and `[!IMPORTANT]` callout to enforce mandatory critic step

## [1.14.0] - 2026-03-01

### Changed
- `rust-lifecycle` skill: `rust-critic` is now a mandatory step in the workflow, running after
  every `rust-architect` phase before implementation begins
- Workflow diagram and task table updated to include `phase-N-critique` task between plan and implement
- `phase-N-implement` now blocks on `phase-N-critique`, not on `phase-N-plan` directly
- Added verdict-based branching logic: `critical` and `significant` verdicts force architect redesign
  and critic re-run before implementation can proceed; only `approved` or `minor` unblock implementation
- `workflow-steps.md` updated with full execution guide for the critique phase including verdict handling

## [1.11.0] - 2026-02-09

### Added
- New `rust-release` skill for automated release preparation workflow
  - Supports patch/minor/major semver version bumps
  - Creates release branch, updates all Cargo.toml manifests
  - Finalizes CHANGELOG.md with versioned section and comparison links
  - Refreshes README via `/readme-generator` skill integration
  - Runs pre-release quality checks (fmt, nextest, clippy, build)
  - Creates commit, pushes branch, and opens PR via `gh`
  - Handles both single-crate and workspace projects
  - Reference documentation for changelog format conventions

## [1.10.2] - 2026-02-07

### Added
- JSON → YAML conversion documentation in `fast-yaml` skill
  - Added `fy convert yaml` CLI command documentation
  - Python API examples for JSON → YAML conversion with helper functions
  - Node.js/TypeScript API examples including batch conversion and CLI script
  - Bidirectional conversion patterns for both YAML ↔ JSON directions

### Changed
- Updated `fast-yaml` skill description to include JSON → YAML triggers
- Enhanced Quick Reference table with both conversion directions
- Updated CLI commands reference with comprehensive bidirectional conversion examples

## [1.10.1] - 2026-02-07

### Fixed
- Changed memory scope from `project`/`local` to `user` for all agents to resolve access issues with ~/.claude/ directory

## [1.10.0] - 2026-02-07

### Added
- New `fast-yaml` skill for YAML validation, formatting, and conversion
  - Complete CLI reference with batch processing and parallel execution support
  - Python API documentation with linting and parallel processing capabilities
  - Node.js/TypeScript API reference for modern JavaScript projects
  - YAML 1.2.2 specification guide with migration examples from YAML 1.1
  - Supports validation, formatting, linting, and YAML-to-JSON conversion
  - Triggers on keywords: validate yaml, format yaml, lint yaml, check yaml syntax, convert yaml to json

## [1.9.6] - 2026-02-07

### Added
- Added `memory` frontmatter field to all 8 agents for persistent memory support (introduced in Claude Code v2.1.33)
  - `project` scope for 6 agents: rust-architect, rust-developer, rust-testing-engineer, rust-performance-engineer, rust-security-maintenance, rust-cicd-devops
  - `local` scope for 2 agents: rust-code-reviewer, rust-debugger

### Changed
- Agent frontmatter now includes memory configuration to enable context persistence across sessions

## [1.9.5] - 2026-02-07

### Added
- Feature flags testing strategy in rust-cicd-devops agent
- Comprehensive CI/CD workflow examples for testing with different feature combinations

## Earlier versions

See git history for changes in versions 1.9.4 and earlier.
