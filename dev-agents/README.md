# dev-agents

[![Version](https://img.shields.io/badge/version-2.0.0-blue)](https://github.com/bug-ops/claude-plugins)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)
[![Stacks](https://img.shields.io/badge/stacks-Rust%20%7C%20TypeScript-orange)](#stack-profiles)

Language-agnostic development agents for Claude Code, with stack profiles for Rust and TypeScript/JavaScript. Agents carry the process — design, implementation, testing, review, security, CI/CD, debugging, continuous improvement; the `stack` skill supplies the language rules each role applies. Polyglot repositories get both profiles.

Formerly `rust-agents` (1.x) — see [Migrating from rust-agents 1.x](#migrating-from-rust-agents-1x).

## Features

- **15 specialized agents** covering the entire development lifecycle including continuous improvement and technical writing
- **Stack profiles** — `stack` skill detects Rust, TypeScript, or both, and loads per-role language rules (toolchain commands, idioms, anti-patterns, checklists); adding a language is adding one references directory
- **20 productivity skills** for enhanced workflows:
  - **stack** — Stack detection and per-language reference loader; loaded by every agent at startup
  - **team-develop** — Multi-agent development orchestration with peer-to-peer communication
  - **team-debug** — Multi-agent root cause investigation: debugger + live-tester (runtime, conditional) in parallel → security always, architect and perf conditionally → consolidated report → user decides next steps
  - **agent-handoff** — Inter-agent context sharing
  - **solve-issue** — Solve GitHub issues end-to-end via worktree + team-develop
  - **triage-and-solve** — Triage open issues by priority, group, and solve
  - **continuous-improvement** — Orchestrator: spawns live-tester, researcher, arch-analyst, and security-analyst by focus, produces a consolidated cycle summary
  - **live-testing** — Live execution of the built artifact, anomaly detection, coverage tracking, cross-interface testing, bug filing
  - **research-protocol** — Dependency monitoring, research & innovation, competitive parity, research issue filing
  - **arch-inspect** — Architecture and code-quality audit protocol: type safety, modularity, testability, readability, DRY, async concurrency
  - **security-audit** — Vulnerability audit protocol: dependency advisories, unsafe and escape-hatch code, secrets, injection, crypto, auth, crash-DoS, supply chain
  - **init-project** — Scaffold project infrastructure for the dev-agents plugin (Rust, TypeScript, polyglot)
  - **release** — Release preparation: version bump, changelog, docs refresh
  - **readme-generator** — Professional README generation
  - **mdbook-tech-writer** — Technical documentation with mdBook
  - **obsidian-zettelkasten** — Obsidian knowledge base formatting with Zettelkasten method
  - **sdd** — Full-cycle Spec-Driven Development: BRD/SRS/NFR → spec/plan/tasks
  - **spec-from-stream** — Business requirements from stream-of-consciousness input
  - **fast-yaml** — YAML validation, formatting, and conversion
  - **rust-modern-apis** — Lookup table for stable Rust APIs added in 1.89–1.99; loaded by the Rust profile for architect, developer, code-reviewer, and arch-analyst
- **LSP integration** — rust-analyzer and typescript-language-server for real-time code intelligence
- **Proactive triggers** — agents are suggested automatically based on your task

## Stack Profiles

Every agent (except `sdd` and `tech-writer`) loads the `stack` skill first. It decides which profiles apply and which reference files the agent must read before touching code:

1. **Detection** — an explicit `Stack: rust,typescript` line in the task prompt wins (orchestration skills always pass it). Otherwise: `Cargo.toml` → `rust`; `tsconfig.json` or a `package.json` that lists TypeScript → `typescript`; a plain-JS `package.json` → `typescript` in JavaScript mode. Files in the task scope (`.rs`, `.ts`, `.tsx`, `.js`, ...) add their profile, so a Rust repository with Node bindings gets both.
2. **Loading** — for each profile the agent reads `references/<profile>/toolchain.md` (manifest, check/lint/format/test/doc/audit commands, version policy) and its role file (`developer.md`, `reviewer.md`, `security-audit.md`, ...), then loads the profile's knowledge skills (`rust-modern-apis` for Rust).
3. **Project rules win** — `CLAUDE.md`, `.claude/rules/`, the CI workflow, and manifest scripts override profile defaults.
4. **Evidence** — every handoff starts its Context with `Stack: rust (toolchain, developer, rust-modern-apis)`, so the lead and downstream agents can verify the rules were applied.

| Profile | Covers | Version policy | Knowledge skills |
|---|---|---|---|
| `rust` | Cargo workspaces, Edition 2024 | `rust-version` (MSRV) | `rust-modern-apis` |
| `typescript` | TypeScript and JavaScript on Node.js, Bun, browser; npm/pnpm/yarn/bun | `engines.node`, `tsconfig` `target`/`lib`, TypeScript version | — |

To add a language: create `skills/stack/references/<language>/` with `toolchain.md` and one file per role, and extend the detection table in `skills/stack/SKILL.md`.

## Agents

### architect
**Model**: opus | **Specialization**: Type-driven architecture, module and package boundaries, strategic decisions

Expert in designing scalable, maintainable applications with focus on:
- Type-driven design: illegal states unrepresentable, typestate, sealed/closed hierarchies
- Workspace and monorepo layout with optimal module and package boundaries
- Dependency management and selection
- Error handling architecture
- Version policy (MSRV, `engines`/`target`)
- Architecture Decision Records (ADR)

Rust profile: GATs, sealed traits, phantom types, Cargo workspaces, thiserror vs anyhow. TypeScript profile: branded types, discriminated unions, pnpm workspaces and project references, `exports` maps.

**Use when**: Starting new projects, restructuring existing codebases, making architectural decisions.

### developer
**Model**: sonnet | **Specialization**: Idiomatic, type-safe feature implementation

Focuses on:
- Writing idiomatic code for the detected stack
- Type safety: newtypes or branded types, exhaustive matching, no escape hatches
- Error handling implementation
- Incremental verification and regression-test-first bug fixes
- Feature development

**Use when**: Implementing features, writing business logic, refactoring code.

### testing-engineer
**Model**: sonnet | **Specialization**: Comprehensive test coverage, test infrastructure, benchmarks

Expert in:
- Unit, integration, and end-to-end testing
- Test infrastructure (cargo-nextest; vitest/jest/node:test, playwright)
- Benchmarking (criterion; vitest bench, tinybench)
- Test-driven development (TDD) and redundancy audits
- Fake and fixture patterns

**Use when**: Writing tests, setting up test infrastructure, benchmarking performance.

### performance-engineer
**Model**: sonnet | **Specialization**: Performance optimization, profiling, build speed improvements

Focuses on:
- Runtime performance optimization
- Build speed improvements (sccache; tsc incremental builds)
- Memory optimization
- Profiling (flamegraph, samply; `node --cpu-prof`, clinic.js)
- Async performance tuning and bundle size

**Use when**: Optimizing performance, reducing build times, profiling bottlenecks.

### security-maintenance
**Model**: opus | **Specialization**: Security scanning, dependency management, vulnerability assessment

Expert in:
- Vulnerability scanning (cargo-audit, cargo-deny; npm/pnpm audit, osv-scanner)
- Dependency security and updates
- Secure coding practices
- Supply chain security
- Security-focused code review

**Use when**: Security audits, dependency updates, addressing vulnerabilities.

### code-reviewer
**Model**: sonnet | **Specialization**: Quality assurance, standards compliance, constructive feedback

Focuses on:
- Code quality review and a full check-suite run
- Adherence to the stack's idioms and modern-API usage
- Performance considerations
- Security review
- Best practices enforcement

**Use when**: Reviewing code changes, ensuring quality standards, pre-commit review.

### cicd-devops
**Model**: sonnet | **Specialization**: GitHub Actions, cross-platform testing, efficient workflows

Expert in:
- GitHub Actions workflows
- Cross-platform CI/CD
- Code coverage integration
- Caching strategies
- Release automation

**Use when**: Setting up CI/CD, optimizing workflows, automating releases.

### debugger
**Model**: sonnet | **Specialization**: Systematic error diagnosis, runtime debugging, crash analysis

Expert in:
- Compiler and type-checker error interpretation (borrow checker; long tsc errors)
- Debuggers: LLDB/GDB; `node --inspect` with source maps
- Panic, exception, and async stack trace analysis
- Async runtime debugging (Tokio, tokio-console; unhandled rejections, event-loop stalls)
- Memory leak detection and investigation
- Production incident response

**Use when**: Encountering compilation or type errors, runtime panics or exceptions, unexpected behavior, performance anomalies, or production issues.

### critic
**Model**: opus | **Specialization**: Adversarial design critique, assumption stress-testing, gap analysis

Expert in finding logical gaps, flawed assumptions, scalability limits, and missing edge cases in:
- Architectural designs and implementation proposals
- Type hierarchies and domain models
- API contracts and error handling strategies
- Concurrency and performance trade-offs

**Use when**: Reviewing architectural decisions before committing, stress-testing ideas, or validating designs after architect.

> [!NOTE]
> critic only produces structured critique reports — it never writes code. Use it before implementation to catch design issues early.

### sdd
**Model**: sonnet | **Specialization**: Full-cycle Spec-Driven Development orchestrator

Guides the complete journey from raw idea to implementation-ready specification package:
- **Phase A** — Business requirements: BRD, SRS (ISO/IEC/IEEE 29148), NFR (ISO/IEC 25010)
- **Phase B** — Technical spec: constitution, spec/plan/tasks per feature
- **Phase C** — Knowledge base: Obsidian vault with Zettelkasten decomposition

**Use when**: Transforming any idea or description into structured requirements and implementation-ready specs. Accepts stream-of-consciousness, raw notes, meeting transcripts, or existing BRDs.

> [!TIP]
> For complex features that need a written spec, pick the `spec-driven` chain in `/team-develop` — it runs the full SDD pipeline (architect → critic → sdd → reviewer) and opens a follow-up implementation issue. Use `/sdd` standalone only outside a team context.

### live-tester
**Model**: sonnet | **Specialization**: Live execution, anomaly detection, coverage tracking

Read-only live testing specialist:
- Syncs with remote, discovers project structure and feature flags
- Executes the built artifact end-to-end with real inputs (binary, CLI, server, web app — not just unit tests)
- Detects anomalies and regressions; reviews logs for WARN/ERROR/panics/uncaught exceptions
- Verifies cross-interface consistency (CLI, TUI, API, bots)
- Maintains coverage status and testing journal in `.local/testing/`
- Files GitHub bug issues for every confirmed finding

**Use when**: Running a testing cycle, verifying new functionality live, checking for regressions.

> [!IMPORTANT]
> live-tester never modifies source code — it only files GitHub issues and updates `.local/testing/`. All fixes happen in separate `/dev-agents:team-develop` sessions.

### researcher
**Model**: sonnet | **Specialization**: Dependency monitoring, research & innovation, competitive parity

Read-only research and monitoring specialist:
- Monitors dependency health (`cargo outdated`, `cargo deny check advisories`; `<pm> outdated`, `npm audit`)
- Researches new architectural patterns, packages, and ecosystem evolution
- Tracks competitive parity against reference projects
- Spawns `sdd` agent to produce specs for significant findings before filing issues
- Files research and dependency GitHub issues with P0–P4 priority labels

**Use when**: Auditing dependencies, researching new techniques, running a competitive parity scan.

> [!IMPORTANT]
> researcher never modifies source code or manifests — it only files GitHub issues and updates `.local/specs/`. Implementation happens in separate sessions.

### arch-analyst
**Model**: opus | **Specialization**: Architecture and code-quality audits for existing codebases

Read-only architecture analyst for continuous improvement cycles:
- Scans for type system anti-patterns (boolean blindness, stringly-typed domains, post-construction validation)
- Flags DRY violations, API naming issues, and workspace/module/package structure problems
- Reviews async concurrency for unbounded work, missing timeouts, missing backpressure
- Every finding includes a file path, line numbers, and improvement rationale
- Files GitHub improvement issues; never modifies source code

**Use when**: Auditing an existing project's structural health, or as part of a `continuous-improvement` cycle (`arch`/`full` focus).

> [!IMPORTANT]
> arch-analyst never modifies source code — it only files GitHub issues via the `arch-inspect` audit protocol. Fixes happen in separate `/dev-agents:team-develop` sessions.

### security-analyst
**Model**: opus | **Specialization**: Vulnerability scanning and security-hardening audits for existing codebases

Read-only security analyst for continuous improvement cycles:
- Runs dependency scanners first (cargo audit/deny, npm/pnpm audit, gitleaks) for confirmed, zero-false-positive findings
- Scans for exposed secrets, unjustified `unsafe` and escape hatches, injection and path traversal, XSS and prototype pollution, crypto misuse, broken authn/authz
- Flags crash-based denial of service (panics on untrusted input, unhandled rejections, event-loop blocking) and supply-chain risk (`build.rs`, proc-macros, install scripts)
- Every finding carries a severity (Critical/High/Medium/Low) and a concrete attack scenario that proves it is exploitable
- Files GitHub security issues; never modifies source code or dependencies

**Use when**: Auditing an existing project's security posture, or as part of a `continuous-improvement` cycle (`security`/`full` focus).

> [!IMPORTANT]
> security-analyst never modifies source code, manifests, or lockfiles — it only files GitHub issues via the `security-audit` protocol. Remediation (including secret rotation) happens in separate `/dev-agents:team-develop` sessions.

### tech-writer
**Model**: sonnet | **Specialization**: User-facing documentation with mdBook and progressive disclosure

Technical writer specializing in user-facing documentation:
- mdBook project lifecycle: planning, structuring, writing, reviewing
- Progressive disclosure — from simple and intuitive to advanced
- Chapter templates for guides, tutorials, API references, architecture docs
- Storytelling and practical examples to guide users through the product
- mdBook-specific features: `{{#include}}`, hidden lines, playground links, admonishments

**Use when**: Creating or maintaining project documentation, writing user guides, onboarding docs, tutorials, or any user-facing mdBook content.

## Handoff Protocol

Agents use the `agent-handoff` skill for context sharing through Markdown files in `.local/handoff/` directory.

File naming format: `{YYYY-MM-DDTHH-MM-SS}-{agent}.md`

> [!TIP]
> Timestamp-first naming allows chronological sorting with `ls` to easily find the latest handoff files.

```markdown
---
id: 2025-01-09T14-30-45-architect
agent: architect
status: completed
summary: Designed type-driven user management system
next_agent: developer
next_task: Implement Email and User types in core crate
---

## Context

Design user management system with role-based access control.

## Output

- Cargo.toml — workspace manifest
- crates/core/src/lib.rs — User and Role types

## Acceptance Criteria

- [ ] Email validated at construction
- [ ] Role-based permission checks compile-time safe
```

Handoff files preserve context when one agent delegates work to another, ensuring no information is lost between agent transitions.

## Skills

This plugin includes productivity skills that enhance your workflow:

### team-develop

Team-based development orchestration for Rust and TypeScript projects using Claude Code agent teams. The lead derives the stack from the preflight and passes `Stack:` to every teammate. Coordinates all specialist agents with peer-to-peer communication via SendMessage.

**Triggers**: 'create dev team', 'start team development', 'launch agent team', 'team workflow', 'collaborative development'

**Step 0 — task classification**: before any team setup, the lead inspects the task and maps it to one of nine chains, then asks the user to confirm. The full pipeline is never the silent default.

| Chain | Pipeline |
|---|---|
| `new-feature` | architect → critic → developer → parallel(tester, perf, security, impl-critic) → reviewer → fix cycle → commit |
| `spec-driven` | architect → critic → sdd → reviewer → commit spec → open follow-up implementation issue (no code) |
| `bug-fix` | debugger → developer → tester → reviewer → commit |
| `refactoring` | architect (lite) → developer → tester → reviewer → commit |
| `security` | security → developer → reviewer → commit |
| `docs` | tech-writer → reviewer → commit |
| `dependency` | developer → parallel(security, tester) → reviewer → commit |
| `performance` | perf → developer → parallel(perf-verify, tester) → reviewer → commit (before/after numbers in body) |
| `ci-cd` | cicd → reviewer → commit |

Mixed-signal and escalation rules: ties on the goal verb pick the heavier chain (`docs < ci-cd < dependency < bug-fix < refactoring < performance < security < new-feature`); `spec-driven` sits outside this order and is chosen explicitly. Mid-flight chain breaks (e.g. debugger finds an architectural defect, or sdd finds the scope is too small to need a spec) pause the chain and propose an upgrade or downgrade — never a silent scope morph.

**Requires**: `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`; on Claude Code 2.1.233+ also `CLAUDE_CODE_ENABLE_TODO_TOOLS=1` for shared task-list coordination (without it the lead falls back to message-based coordination). Interactive sessions only: agent teams do not form under `claude -p` or the SDK. Prerequisites (flags, branch, clean tree, stack markers `Cargo.toml`/`tsconfig.json`/`package.json`) are collected automatically when the skill loads

> [!IMPORTANT]
> The `spec-driven` chain is the canonical way to produce a spec from team-develop — it writes a versioned spec package to `specs/{feature-slug}/`, commits it, and opens a GitHub issue handing the spec off to a future `new-feature` run. Run `/dev-agents:sdd` standalone only outside a team. The legacy `.local/specs/` convention still works as a manual input to the `new-feature` chain.

### team-debug

Multi-agent debugging workflow for systematic root cause investigation and fix cycles.

**Triggers**: 'debug issue', 'investigate bug', 'root cause', 'production incident', 'team debug'

**Workflow**:
1. `debugger` investigates symptoms → identifies root cause, affected files, severity
2. Parallel review: `architect` (design implications) + `critic` (hypothesis challenge) + `security-maintenance` (security angle) + `performance-engineer` (if performance symptoms detected)
3. `code-reviewer` consolidates all findings → structured report: critical fixes + follow-up issues
4. User decides: create issues / group into epic / hand off to `team-develop` / do both

**Requires**: `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`; on Claude Code 2.1.233+ also `CLAUDE_CODE_ENABLE_TODO_TOOLS=1` for shared task-list coordination (without it the lead falls back to message-based coordination). Interactive sessions only: agent teams do not form under `claude -p` or the SDK. Prerequisites (flags, branch, clean tree, stack markers `Cargo.toml`/`tsconfig.json`/`package.json`) are collected automatically when the skill loads

> [!TIP]
> `team-debug` stops after the consolidated review and waits for user input — no fixes are applied automatically. The report becomes the task description when handing off to `team-develop`.

### sdd

Full-cycle Spec-Driven Development: turns any input into an implementation-ready specification package.

**Triggers**: 'I have an idea', 'I want to build', 'requirements', 'BRD', 'SRS', 'NFR', 'spec', 'plan', 'tasks', 'make a vault'

**Pipeline**:
1. **Phase A** — Business requirements via `spec-from-stream`: intake → gap-filling → BRD/SRS/NFR
2. **Phase B** — Technical spec via `sdd` skill: constitution → spec → plan → tasks → review
3. **Phase C** — Knowledge base via `obsidian-zettelkasten`: atomic notes + MOC + cross-references

**Commands**: `/sdd init` · `/sdd specify` · `/sdd plan` · `/sdd tasks` · `/sdd review`

### spec-from-stream

Transforms stream-of-consciousness product descriptions into structured business requirements documents.

**Triggers**: 'I have an idea', 'turn this into a spec', 'write requirements', 'make a BRD', 'SRS', 'NFR', 'functional requirements', 'non-functional requirements', 'decompose into notes'

**Output documents**:
- **BRD** — What to build and why (always generated)
- **SRS** — Functional requirements per ISO/IEC/IEEE 29148:2018 (on request)
- **NFR** — Quality attributes per ISO/IEC 25010:2011 (on request)

**Workflow**: intake → coverage assessment → guided gap-filling (one question at a time) → document generation → optional Zettelkasten decomposition

All documents are Obsidian-formatted with YAML frontmatter, callouts, wikilinks, and full cross-linking.

### agent-handoff

Handoff protocol for multi-agent development. Enables structured communication between agents through Markdown files in `.local/handoff/` directory.

**Triggers**: Automatically loaded by every team agent when context sharing is needed. The Context section opens with the `Stack:` evidence line.

**Key features**:
- Timestamp-based file naming for chronological sorting
- Parent chain tracking for full context history
- Agent-specific output schemas
- Status tracking (completed, blocked, needs_discussion)

See [Handoff Protocol](#handoff-protocol) section above for details.

### readme-generator

Professional README generator with ecosystem-specific best practices.

**Triggers**: 'create readme', 'generate readme', 'write readme', 'improve readme', 'update readme', 'fix readme'

**Supported project types**:
- Rust libraries (crates.io badge, docs.rs, MSRV, feature flags)
- Rust CLI tools (multi-platform install: cargo, brew, apt)
- TypeScript/JavaScript (npm/yarn/pnpm/bun, bundle size)
- Python (pip/poetry/conda, Python versions)

**Features**:
- Auto-detects project type from manifest files
- Applies ecosystem-specific conventions
- GitHub callouts for warnings and tips
- Badge generation (crates.io, docs.rs, npm, PyPI)
- Quality checklist enforcement

> [!TIP]
> Use `/readme-generator` when setting up new projects or improving existing documentation.

### release

Release preparation for Rust crates and workspaces and for npm packages and workspaces; stack mechanics come from `stack/references/<profile>/release.md`.

**Triggers**: 'prepare release', 'bump version', 'release patch', 'release minor', 'release major', 'version bump', 'create release'

**Features**:
- Semantic version bumping (patch, minor, major)
- CHANGELOG.md generation and updates
- Documentation refresh before release
- Single-package and workspace support (Cargo workspaces; npm/pnpm/yarn workspaces, changesets)

### mdbook-tech-writer

Technical documentation writer using mdBook for Rust and software projects.

**Triggers**: 'mdbook', 'documentation', 'write docs', 'technical writing', 'book.toml', 'SUMMARY.md', 'chapter', 'tutorial', 'API reference', 'architecture doc'

**Features**:
- Full mdBook project lifecycle: planning, structuring, writing, reviewing
- Chapter templates for guides, tutorials, API references, architecture docs
- Writing style guide with Rust ecosystem conventions
- mdBook-specific features: `{{#include}}`, hidden lines, playground links, admonishments
- Quality checklist per chapter

> [!TIP]
> Use `/mdbook-tech-writer` when creating or maintaining project documentation with mdBook.

### solve-issue

Solve a GitHub issue end-to-end: fetch issue data, create a branch in a worktree, and launch team-develop agents.

**Usage**: `/dev-agents:solve-issue <issue-number>`

**Workflow**:
1. Fetches issue metadata via `gh issue view`
2. Derives branch name from issue labels and milestone
3. Creates an isolated worktree via `EnterWorktree`
4. Launches `/dev-agents:team-develop` with full issue context

> [!TIP]
> If the project has `.claude/rules/branching.md`, solve-issue follows those conventions instead of the defaults.

### triage-and-solve

Triage open GitHub issues by priority, group compatible ones into a single PR, then solve via solve-issue.

**Usage**: `/dev-agents:triage-and-solve`

**Workflow**:
1. Fetches unassigned open issues
2. Sorts by priority: `P0`–`P4` labels first when the project uses them, then category labels (critical → high → bug → enhancement); `research` issues always go to the tail of the queue
3. Detects project subsystems from Cargo workspace members and npm/pnpm workspace packages
4. Groups compatible issues (max 3 per group)
5. Confirms with user before proceeding
6. Launches `/dev-agents:solve-issue` for the selected group (which internally uses `team-develop`)

### continuous-improvement

Orchestrate a full CI cycle by spawning `live-tester`, `researcher`, `arch-analyst`, and `security-analyst` as a named agent team, tracking tasks, and producing a consolidated summary.

**Usage**: `/dev-agents:continuous-improvement [testing|research|dependencies|parity|arch|security|full]`

| Focus | Agents spawned |
|-------|----------------|
| `testing` | live-tester only |
| `dependencies` | researcher (deps phase) |
| `research` | researcher (research phase) |
| `parity` | researcher (parity phase) |
| `arch` | arch-analyst only (type-system, modularity, testability, readability, dry, async) |
| `security` | security-analyst only (dependencies, unsafe, secrets, input, crypto, auth, panics, supply-chain) |
| `full` | live-tester + researcher + arch-analyst + security-analyst in parallel |

**Workflow**: `TaskCreate` per agent → spawn teammates with `name` (the team forms implicitly) → wait for `SendMessage` with handoff → `TaskUpdate(completed)` → `SendMessage(shutdown_request)`; team directories are cleaned up automatically at session end

**Engines**: with `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` in an interactive session the agents run as an agent team (add `CLAUDE_CODE_ENABLE_TODO_TOOLS=1` on Claude Code 2.1.233+ for shared task-list coordination). Without the flag, or in a non-interactive session, the same agents run as background subagents and report back when they finish (in auto mode through the `SubagentHandback` call). This is the only orchestration skill that works headless, which makes it suitable for recurring runs. Use Claude Code 2.1.280 or later for unattended runs: earlier versions could lose background reports or leave a `-p` run hanging:

```bash
# one-off unattended cycle
claude -p --permission-mode auto --permission-prompts none "/dev-agents:continuous-improvement full"
```

```text
# recurring, inside an interactive session
/loop 24h /dev-agents:continuous-improvement full
```

> [!NOTE]
> If the project has `.claude/rules/continuous-improvement.md`, its contents are passed to both sub-agents as project-specific overrides (test configs, subsystems, reference projects, etc.).

> [!TIP]
> Specs created during CI cycles accumulate in `.local/specs/`. When a fix session starts, the spec is already there — just run `/sdd plan` on it to get a technical plan and task list.

### arch-inspect

Architecture and code-quality audit protocol used by `arch-analyst`. Invoked directly, it delegates the audit to a background `arch-analyst` and reports its findings.

**Usage**: `/dev-agents:arch-inspect [type-system|modularity|testability|readability|dry|async|errors|api|observability|hygiene|full]`

**Audit categories**:
| Focus | What is audited |
|-------|-----------------|
| `type-system` | Type safety, illegal states, newtypes, typestate, sealed traits |
| `modularity` | Crate/module boundaries, visibility, workspace structure, crate cohesion |
| `testability` | Trait-based deps, pure functions, test structure, hidden globals |
| `readability` | API naming, function complexity, naming conventions, comments |
| `dry` | Duplicated error variants, copy-pasted domain logic, redundant traits |
| `async` | Unbounded concurrency, missing timeouts, missing backpressure |
| `full` | All categories |

> [!NOTE]
> `arch-inspect` is read-only — it identifies structural debt and files GitHub issues, never modifies source files.

### security-audit

Vulnerability and security-hardening audit protocol used by `security-analyst`. Invoked directly, it delegates the audit to a background `security-analyst` and reports its findings.

**Usage**: `/dev-agents:security-audit [dependencies|unsafe|secrets|input|crypto|auth|panics|supply-chain|network|filesystem|gates|full]`

**Audit categories**:
| Focus | What is audited |
|-------|-----------------|
| `dependencies` | Advisories (RUSTSEC, GHSA), unmaintained/yanked/deprecated packages, license violations, duplicate versions |
| `unsafe` | Unsafe and escape-hatch code: Rust `unsafe` without `// SAFETY:`, FFI, hand-written `Send`/`Sync`; TypeScript `any`, unvalidated casts, `eval` |
| `secrets` | Hardcoded keys/tokens/passwords, secrets in logs and errors, `.gitignore` gaps |
| `input` | SQL/command injection, path traversal, untrusted deserialization, prototype pollution, XSS, SSRF, ReDoS, integer overflow |
| `crypto` | Weak algorithms, custom crypto, non-CSPRNG randomness, plaintext passwords, non-constant-time comparison |
| `auth` | Broken authn/authz, user enumeration, timing side-channels, insecure session/token handling |
| `panics` | Crash and resource-exhaustion DoS: panics, uncaught exceptions, unhandled rejections, blocked runtime or event loop, unbounded allocation |
| `supply-chain` | `build.rs` and proc-macro trust, install scripts, typosquatting and dependency confusion, provenance, dependency surface |
| `full` | All categories |

> [!NOTE]
> `security-audit` is read-only — it identifies vulnerabilities and files GitHub issues, never modifies source files, manifests, or lockfiles. Findings are ranked by exploitability; each carries a severity and a concrete attack scenario.

### init-project

Scaffold project infrastructure for the dev-agents plugin.

**Usage**: `/dev-agents:init-project [--force]`

**Creates**:
- `.local/handoff/` — agent communication (agent-handoff)
- `.local/plan/` — implementation plans (sdd)
- `.local/team-results/` — team reports (team-develop, team-debug)
- `.local/testing/` — CI cycle knowledge base with journal, coverage status, process notes, regressions, playbooks
- `.claude/rules/branching.md` — branch naming convention template
- `.claude/rules/continuous-improvement.md` — CI cycle configuration template
- `.claude/skills/verify/SKILL.md` — project build/test/run recipe with detected binary targets, shared by `live-tester` and the bundled `/verify` skill (created only when absent)
- `.gitignore` entries for `.local/` and `.claude/agent-memory-local/`

Detects the stack and reads `Cargo.toml` workspace members or npm/pnpm workspace packages to generate per-unit sections in `coverage-status.md` and the run commands in the verify skill.

> [!TIP]
> Run `/dev-agents:init-project` once when starting a new project, then customize the generated `.claude/rules/` files.

### fast-yaml

YAML validation, formatting, linting, and JSON↔YAML conversion via the `fy` CLI.

**Triggers**: 'validate yaml', 'format yaml', 'lint yaml', 'check yaml syntax', 'convert yaml to json', 'convert json to yaml'

**Features**:
- File validation (`fy parse <file>`, `fy lint <file>`)
- Formatting and linting (`fy format <file>`)
- JSON ↔ YAML conversion (`fy convert <file>`)
- Support for CLI, Python, and Node.js API patterns

> [!IMPORTANT]
> Prefer `fast-yaml` over manual YAML editing. Always validate handoff files and configuration YAML with `fy` after edits.

### rust-modern-apis

Reference lookup table for stable Rust APIs added in versions 1.89–1.99 (August 2025 – October 2026).

**Loaded by the Rust profile for**: `architect`, `developer`, `code-reviewer`, `arch-analyst`

**Trigger patterns** (detected automatically):

| Code pattern | Modern replacement | Since |
|---|---|---|
| `Duration::from_secs(60 * N)` | `Duration::from_mins(N)` | 1.91 |
| `path.with_extension("X.tmp")` to add suffix | `path.with_added_extension("tmp")` | 1.91 |
| Manual `is_char_boundary` loop for UTF-8 truncation | `str::floor_char_boundary(n)` | 1.91 |
| External `fd-lock`/`pid-lock` crate | Built-in `File::try_lock()` | 1.89 |
| `Result<Result<T,E>,E>` manual flatten | `Result::flatten()` | 1.89 |
| `slice.try_into::<[T; N]>().unwrap()` | `slice.as_array::<N>()` | 1.93 |
| `checked_add(x).unwrap()` where overflow = bug | `strict_add(x)` | 1.91 |
| `1 << (BITS - 1 - x.leading_zeros())` for highest set bit | `x.isolate_highest_one()` | 1.97 |
| `Self::BITS - x.leading_zeros()` for value bit width | `x.bit_width()` | 1.97 |

**Workflow**:
1. Checks project MSRV from `Cargo.toml` (`rust-version`)
2. Scans code for trigger patterns
3. Suggests replacement with before/after snippet
4. Only recommends APIs available at or below the project's MSRV

> [!TIP]
> If a better API requires a higher MSRV, the skill notes "raising MSRV to X.Y unlocks this" rather than silently skipping the suggestion.

### obsidian-zettelkasten

Format documentation as an Obsidian knowledge base using the Zettelkasten method with dense cross-referencing.

**Triggers**: 'obsidian', 'zettelkasten', 'knowledge base', 'create vault', 'obsidian notes', 'convert to obsidian', 'atomic notes', 'MOC', 'map of content'

**Features**:
- Atomic note decomposition from source material (docs, code, conversations)
- YAML properties with tags, aliases, dates, and related links
- Wikilink-based cross-referencing with heading and block links
- Maps of Content (MOC) for navigable topic clusters
- Note type taxonomy: permanent, literature, fleeting, MOC, ADR, guide
- Templates for consistent note structure
- Quality checklist: orphan detection, link density, tag consistency

**Reference docs**:
- `obsidian-syntax.md` — Complete Obsidian Markdown syntax reference
- `zettelkasten-structure.md` — Note types, linking patterns, vault conventions

> [!TIP]
> Use `/obsidian-zettelkasten` when converting project documentation, research notes, or technical knowledge into a navigable Obsidian vault.

## Installation

Install this plugin using Claude Code:

```bash
claude plugin marketplace add bug-ops/claude-plugins
claude plugin install dev-agents@claude-dev-agents
```

Or load it from a local directory:

```bash
claude --plugin-dir /path/to/dev-agents
```

## Migrating from rust-agents 1.x

2.0.0 renames the plugin, its marketplace, every Rust-prefixed agent, and two skills. Behavior for Rust projects is unchanged; the Rust rules moved from the agent prompts into `skills/stack/references/rust/`.

1. Remove the old marketplace and install the new one:

   ```bash
   claude plugin marketplace remove claude-rust-agents
   claude plugin marketplace add bug-ops/claude-plugins
   claude plugin install dev-agents@claude-dev-agents
   ```

2. Update references in your settings, scripts, and project rules:

| 1.x | 2.0.0 |
|---|---|
| `rust-agents@claude-rust-agents` | `dev-agents@claude-dev-agents` |
| `/rust-agents:<skill>` | `/dev-agents:<skill>` |
| `rust-agents:rust-architect`, `rust-developer`, `rust-testing-engineer`, `rust-performance-engineer`, `rust-security-maintenance`, `rust-code-reviewer`, `rust-cicd-devops`, `rust-debugger`, `rust-critic`, `rust-live-tester`, `rust-researcher`, `rust-arch-analyst`, `rust-security-analyst` | `dev-agents:` + the name without the `rust-` prefix (`dev-agents:architect`, ...) |
| skill `rust-agent-handoff` | `agent-handoff` |
| skill `rust-release` | `release` |

Agent memory is keyed by agent name: entries under the old `rust-*` names are not carried over.

## Usage

Agents are automatically available in Claude Code after installation.

```bash
# Start Claude Code
claude

# View available agents
/agents

# Agents will be automatically suggested based on your task
```

### Example workflows

**Starting a new project**:
```
"I want to create a new Rust web service with database integration"
→ stack detects rust; every agent loads the Rust profile
→ architect designs the structure
→ developer implements features
→ testing-engineer sets up tests
→ cicd-devops configures CI/CD
```

**From idea to code**:
```
"I have an idea for a Rust CLI tool that syncs local notes to S3"
→ sdd (Phase A) creates BRD from description, asks targeted questions
→ sdd (Phase B) produces spec + plan + tasks
→ team-develop executes the task list
```

**TypeScript project**:
```
"Add request validation to the Fastify API"
→ stack detects typescript; developer applies the TypeScript profile (schemas at trust boundaries, no `any`)
→ code-reviewer runs typecheck, lint, and tests, then reviews against the TypeScript checklist
```

**Optimizing existing code**:
```
"My Rust application is running slowly"
→ performance-engineer profiles and optimizes
→ code-reviewer ensures changes maintain quality
```

**Debugging a production issue**:
```
"My service is timing out under load — started after last deployment"
→ /team-debug investigates symptoms across all specialist agents
→ consolidated report: root cause + critical fixes + follow-up items
→ user decides: create issues / epic / hand off to /team-develop
```

## Requirements

- Claude Code CLI 2.1.233 or newer (the orchestration skills follow its agent-team and Task-tool behavior)
- The toolchain of your stack: Rust 1.85+ (Edition 2024); or Node.js LTS with the project's package manager
- Language servers for LSP features: rust-analyzer, typescript-language-server (see [LSP Support](#lsp-support))

### Claude Code settings that affect the plugin

| Setting or variable | Effect |
|---|---|
| `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` | Required by `team-develop` and `team-debug`; selects the teams engine in `continuous-improvement` |
| `CLAUDE_CODE_ENABLE_TODO_TOOLS=1` | Restores the shared task list (`TaskCreate`/`TaskUpdate`) on Claude Code 2.1.233+; without it the leads coordinate by messages |
| `CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS` (default 20) | The largest fan-out in `team-develop` is 6 agents; lower limits produce `Concurrent subagent limit reached` |
| `CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH` (default 3) | Teammates spawn at most foreground subagents; keep the default |
| `CLAUDE_CODE_SUBAGENT_MODEL` / `CLAUDE_CODE_SUBAGENT_MODEL_FORCE=1` | Since 2.1.251 an agent definition's `model:` wins over `CLAUDE_CODE_SUBAGENT_MODEL`; `_FORCE` applies one model to every agent, teammate and workflow agent, ignoring the definitions (useful to run a whole team on a cheaper model) |
| `subagentPromptCacheTtl: "1h"` | In-process teammates default to a 5-minute prompt cache; `1h` cuts re-cache cost on long `team-develop` runs. `developer`, `architect` and `live-tester` also declare `experimental.cacheTtl: 1h` |
| `autoMemoryEnabled: false` / `CLAUDE_CODE_DISABLE_AUTO_MEMORY` | Turns the agents' `memory:` scopes into no-ops |

Agent-team limitations that apply to the team skills: one team per session, no nested teams, teammates spawn only foreground subagents, in-process teammates are not restored by `/resume`, and permission prompts from teammates are answered in the lead session.

## LSP Support

The plugin configures two language servers in `.lsp.json`. Each starts the first time Claude edits a file with one of its extensions; a missing binary shows as `Executable not found in $PATH` in the `/plugin` Errors tab and does not affect the other server.

| Server | Extensions | Install |
|---|---|---|
| `rust-analyzer` | `.rs` | `rustup component add rust-analyzer` (or `brew install rust-analyzer`) |
| `typescript-language-server` | `.ts`, `.tsx`, `.mts`, `.cts`, `.js`, `.jsx`, `.mjs`, `.cjs` | `npm install -g typescript-language-server typescript` |

What Claude gains:

- **Instant diagnostics** — Claude sees errors and warnings immediately after each edit
- **Code navigation** — Go to definition, find references, hover information
- **Type information** — Full type awareness for code symbols

rust-analyzer is configured with Clippy checks on save, all Cargo features, inlay hints, and proc-macro support.

> [!NOTE]
> If you also have the official `rust-analyzer-lsp` or `typescript-lsp` plugin enabled, two servers handle the same files. Keep one of them.

## Development environment

### Using DevContainer (recommended)

This plugin includes a complete DevContainer configuration for isolated development with all tools pre-installed:

- Rust toolchain (latest stable) and Node.js LTS
- Claude Code CLI (automatically installed)
- Plugin auto-installed and ready to use
- Rust development tools (cargo-nextest, cargo-audit, sccache, etc.)
- TypeScript tooling (typescript, typescript-language-server, pnpm)
- VS Code extensions for Rust and Markdown

**Quick start:**
1. Install [Docker Desktop](https://www.docker.com/products/docker-desktop) and [VS Code](https://code.visualstudio.com/)
2. Install the [Dev Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers)
3. Open this project in VS Code
4. Press `F1` → Select "Dev Containers: Reopen in Container"
5. Wait for the container to build (first time: ~10 minutes)
6. Start using Claude Code: `claude`

### Manual setup

If not using DevContainer:
1. Install the toolchain of your stack: Rust via [rustup](https://rustup.rs), Node.js LTS via your version manager
2. Install Claude Code: `npm install -g @anthropic-ai/claude-code`
3. Load the plugin: `claude --plugin-dir /path/to/dev-agents`

## Best practices

1. **Start with architecture** — Use architect when starting new projects
2. **Specify before coding** — Run `/sdd` to create BRD and spec before complex implementations
3. **Debug systematically** — Use debugger for compilation and runtime errors
4. **Maintain quality** — Regularly use code-reviewer before commits
5. **Security first** — Run security-maintenance on dependency updates
6. **Performance monitoring** — Use performance-engineer for optimization tasks
7. **Test coverage** — Engage testing-engineer for comprehensive testing
8. **Automation** — Set up CI/CD early with cicd-devops

## License

MIT
