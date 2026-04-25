# Rust Agents Plugin

[![Version](https://img.shields.io/badge/version-1.26.6-blue)](https://github.com/bug-ops/claude-plugins)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)
[![Rust Edition](https://img.shields.io/badge/rust-Edition%202024-orange)](https://doc.rust-lang.org/edition-guide/rust-2024/)

A comprehensive collection of specialized Rust development agents for Claude Code. This plugin provides expert assistance across all aspects of Rust development, from architecture design to deployment.

## Features

- **13 specialized agents** covering the entire Rust development lifecycle including continuous improvement and technical writing
- **16 productivity skills** for enhanced workflows:
  - **team-develop** — Multi-agent development orchestration with peer-to-peer communication
  - **team-debug** — Multi-agent root cause investigation: debugger + live-tester (runtime, conditional) in parallel → security always, architect and perf conditionally → consolidated report → user decides next steps
  - **rust-agent-handoff** — Inter-agent context sharing
  - **solve-issue** — Solve GitHub issues end-to-end via worktree + team-develop
  - **triage-and-solve** — Triage open issues by priority, group, and solve
  - **continuous-improvement** — Orchestrator: spawns rust-live-tester and rust-researcher by focus, produces a consolidated cycle summary
  - **live-testing** — Live binary execution, anomaly detection, coverage tracking, cross-interface testing, bug filing
  - **research-protocol** — Dependency monitoring, research & innovation, competitive parity, research issue filing
  - **init-project** — Scaffold project infrastructure for the rust-agents plugin
  - **rust-release** — Automated release preparation
  - **readme-generator** — Professional README generation
  - **mdbook-tech-writer** — Technical documentation with mdBook
  - **obsidian-zettelkasten** — Obsidian knowledge base formatting with Zettelkasten method
  - **sdd** — Full-cycle Spec-Driven Development: BRD/SRS/NFR → spec/plan/tasks
  - **spec-from-stream** — Business requirements from stream-of-consciousness input
  - **fast-yaml** — YAML validation, formatting, and conversion
  - **rust-modern-apis** — Lookup table for stable Rust APIs added in 1.89–1.94; loaded explicitly at session startup by rust-developer and rust-code-reviewer
- **rust-analyzer LSP integration** for real-time code intelligence with Claude
- **Proactive triggers** — agents are suggested automatically based on your task
- **Rust Edition 2024** support with modern tooling

## Agents

### rust-architect
**Model**: opus | **Specialization**: Workspace design, type-driven architecture, strategic decisions

Expert in designing scalable, maintainable Rust applications with focus on:
- Type-driven design with GATs, sealed traits, phantom types, typestate patterns
- Multi-crate workspace design with optimal module boundaries
- Dependency management and selection
- Error handling architecture (thiserror vs anyhow)
- MSRV policy and Rust Edition 2024
- Architecture Decision Records (ADR)

**Use when**: Starting new projects, restructuring existing codebases, making architectural decisions.

### rust-developer
**Model**: sonnet | **Specialization**: Idiomatic code, ownership patterns, feature implementation

Focuses on:
- Writing idiomatic Rust code
- Ownership and borrowing patterns
- Error handling implementation
- Module organization
- Feature development

**Use when**: Implementing features, writing business logic, refactoring code.

### rust-testing-engineer
**Model**: sonnet | **Specialization**: Comprehensive test coverage with nextest and criterion

Expert in:
- Unit and integration testing
- Test infrastructure with cargo-nextest
- Performance benchmarking with criterion
- Test-driven development (TDD)
- Mock and fixture patterns

**Use when**: Writing tests, setting up test infrastructure, benchmarking performance.

### rust-performance-engineer
**Model**: sonnet | **Specialization**: Performance optimization, profiling, build speed improvements

Focuses on:
- Runtime performance optimization
- Build speed improvements with sccache
- Memory optimization
- Profiling with flamegraph
- Async performance tuning

**Use when**: Optimizing performance, reducing build times, profiling bottlenecks.

### rust-security-maintenance
**Model**: opus | **Specialization**: Security scanning, dependency management, vulnerability assessment

Expert in:
- cargo-audit and cargo-deny for vulnerability scanning
- Dependency security and updates
- Secure coding practices
- Supply chain security
- Security-focused code review

**Use when**: Security audits, dependency updates, addressing vulnerabilities.

### rust-code-reviewer
**Model**: sonnet | **Specialization**: Quality assurance, standards compliance, constructive feedback

Focuses on:
- Code quality review
- Adherence to Rust idioms
- Performance considerations
- Security review
- Best practices enforcement

**Use when**: Reviewing code changes, ensuring quality standards, pre-commit review.

### rust-cicd-devops
**Model**: sonnet | **Specialization**: GitHub Actions, cross-platform testing, efficient workflows

Expert in:
- GitHub Actions workflows
- Cross-platform CI/CD
- Code coverage integration
- Caching strategies
- Release automation

**Use when**: Setting up CI/CD, optimizing workflows, automating releases.

### rust-debugger
**Model**: sonnet | **Specialization**: Systematic error diagnosis, runtime debugging, panic analysis

Expert in:
- Borrow checker and lifetime error interpretation
- LLDB/GDB debugging on macOS/Linux
- Panic and backtrace analysis
- Async runtime debugging (Tokio, tokio-console)
- Memory leak detection and investigation
- Production incident response

**Use when**: Encountering compilation errors, runtime panics, unexpected behavior, performance anomalies, or production issues.

### rust-critic
**Model**: opus | **Specialization**: Adversarial design critique, assumption stress-testing, gap analysis

Expert in finding logical gaps, flawed assumptions, scalability limits, and missing edge cases in:
- Architectural designs and implementation proposals
- Type hierarchies and domain models
- API contracts and error handling strategies
- Concurrency and performance trade-offs

**Use when**: Reviewing architectural decisions before committing, stress-testing ideas, or validating designs after rust-architect.

> [!NOTE]
> rust-critic only produces structured critique reports — it never writes code. Use it before implementation to catch design issues early.

### sdd
**Model**: sonnet | **Specialization**: Full-cycle Spec-Driven Development orchestrator

Guides the complete journey from raw idea to implementation-ready specification package:
- **Phase A** — Business requirements: BRD, SRS (ISO/IEC/IEEE 29148), NFR (ISO/IEC 25010)
- **Phase B** — Technical spec: constitution, spec/plan/tasks per feature
- **Phase C** — Knowledge base: Obsidian vault with Zettelkasten decomposition

**Use when**: Transforming any idea or description into structured requirements and implementation-ready specs. Accepts stream-of-consciousness, raw notes, meeting transcripts, or existing BRDs.

> [!TIP]
> Run `/sdd` before `/team-develop` to ensure complex features are well-specified before coding starts.

### rust-live-tester
**Model**: sonnet | **Specialization**: Live binary execution, anomaly detection, coverage tracking

Read-only live testing specialist:
- Syncs with remote, discovers project structure and feature flags
- Executes the project binary end-to-end with real inputs (not just unit tests)
- Detects anomalies and regressions; reviews logs for WARN/ERROR/panics
- Verifies cross-interface consistency (CLI, TUI, API, bots)
- Maintains coverage status and testing journal in `.local/testing/`
- Files GitHub bug issues for every confirmed finding

**Use when**: Running a testing cycle, verifying new functionality live, checking for regressions.

> [!IMPORTANT]
> rust-live-tester never modifies source code — it only files GitHub issues and updates `.local/testing/`. All fixes happen in separate `/rust-agents:team-develop` sessions.

### rust-researcher
**Model**: sonnet | **Specialization**: Dependency monitoring, research & innovation, competitive parity

Read-only research and monitoring specialist:
- Monitors dependency health with `cargo outdated` and `cargo deny check advisories`
- Researches new architectural patterns, crates, and Rust ecosystem evolution
- Tracks competitive parity against reference projects
- Spawns `sdd` agent to produce specs for significant findings before filing issues
- Files research and dependency GitHub issues with P0–P4 priority labels

**Use when**: Auditing dependencies, researching new techniques, running a competitive parity scan.

> [!IMPORTANT]
> rust-researcher never modifies source code or `Cargo.toml` — it only files GitHub issues and updates `.local/specs/`. Implementation happens in separate sessions.

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

Agents use the `rust-agent-handoff` skill for context sharing through Markdown files in `.local/handoff/` directory.

File naming format: `{YYYY-MM-DDTHH-MM-SS}-{agent}.md`

> [!TIP]
> Timestamp-first naming allows chronological sorting with `ls` to easily find the latest handoff files.

```markdown
---
id: 2025-01-09T14-30-45-architect
agent: rust-architect
status: completed
summary: Designed type-driven user management system
next_agent: rust-developer
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

Team-based development orchestration for Rust projects using Claude Code agent teams. Coordinates all specialist agents with peer-to-peer communication via SendMessage.

**Triggers**: 'create rust team', 'start team development', 'launch agent team', 'team workflow', 'collaborative development'

**Workflow**: architect → critic → developer → parallel(tester, perf, security, impl-critic) → reviewer → fix cycle → commit

**Requires**: `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`

> [!IMPORTANT]
> For complex features, run `/rust-agents:sdd` **before** launching team-develop to produce a spec in `.local/specs/`. team-develop does not run the SDD agent itself — SDD is a prerequisite step, not part of the workflow.

### team-debug

Multi-agent debugging workflow for systematic root cause investigation and fix cycles.

**Triggers**: 'debug issue', 'investigate bug', 'root cause', 'production incident', 'team debug'

**Workflow**:
1. `rust-debugger` investigates symptoms → identifies root cause, affected files, severity
2. Parallel review: `rust-architect` (design implications) + `rust-critic` (hypothesis challenge) + `rust-security-maintenance` (security angle) + `rust-performance-engineer` (if performance symptoms detected)
3. `rust-code-reviewer` consolidates all findings → structured report: critical fixes + follow-up issues
4. User decides: create issues / group into epic / hand off to `team-develop` / do both

**Requires**: `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`

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

### rust-agent-handoff

Handoff protocol for multi-agent Rust development. Enables structured communication between agents through Markdown files in `.local/handoff/` directory.

**Triggers**: Automatically loaded by Rust agents when context sharing is needed.

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

### rust-release

Automated release preparation for Rust projects.

**Triggers**: 'prepare release', 'bump version', 'release patch', 'release minor', 'release major', 'version bump', 'create release'

**Features**:
- Semantic version bumping (patch, minor, major)
- CHANGELOG.md generation and updates
- Documentation refresh before release
- Single-crate and workspace support

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

**Usage**: `/rust-agents:solve-issue <issue-number>`

**Workflow**:
1. Fetches issue metadata via `gh issue view`
2. Derives branch name from issue labels and milestone
3. Creates an isolated worktree via `EnterWorktree`
4. Launches `/rust-agents:team-develop` with full issue context

> [!TIP]
> If the project has `.claude/rules/branching.md`, solve-issue follows those conventions instead of the defaults.

### triage-and-solve

Triage open GitHub issues by priority, group compatible ones into a single PR, then solve via solve-issue.

**Usage**: `/rust-agents:triage-and-solve`

**Workflow**:
1. Fetches unassigned open issues
2. Sorts by priority labels (critical → high → bug → enhancement → research)
3. Detects project subsystems from `Cargo.toml` workspace members
4. Groups compatible issues (max 3 per group)
5. Confirms with user before proceeding
6. Launches `/rust-agents:solve-issue` for the selected group (which internally uses `team-develop`)

### continuous-improvement

Orchestrate a full CI cycle by spawning `rust-live-tester` and `rust-researcher` as a named agent team, tracking tasks, and producing a consolidated summary.

**Usage**: `/rust-agents:continuous-improvement [testing|research|dependencies|parity|full]`

| Focus | Agents spawned |
|-------|----------------|
| `testing` | rust-live-tester only |
| `dependencies` | rust-researcher (deps phase) |
| `research` | rust-researcher (research phase) |
| `parity` | rust-researcher (parity phase) |
| `full` | rust-live-tester, then rust-researcher |

**Workflow**: `TeamCreate` → `TaskCreate` per agent → spawn with `team_name`/`name` → wait for `SendMessage` with handoff → `TaskUpdate(completed)` → `SendMessage(shutdown_request)` → `TeamDelete`

**Requires**: `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`

> [!NOTE]
> If the project has `.claude/rules/continuous-improvement.md`, its contents are passed to both sub-agents as project-specific overrides (test configs, subsystems, reference projects, etc.).

> [!TIP]
> Specs created during CI cycles accumulate in `.local/specs/`. When a fix session starts, the spec is already there — just run `/sdd plan` on it to get a technical plan and task list.

### init-project

Scaffold project infrastructure for the rust-agents plugin.

**Usage**: `/rust-agents:init-project [--force]`

**Creates**:
- `.local/handoff/` — agent communication (rust-agent-handoff)
- `.local/plan/` — implementation plans (sdd)
- `.local/team-results/` — team reports (team-develop, team-debug)
- `.local/testing/` — CI cycle knowledge base with journal, coverage status, process notes, regressions, playbooks
- `.claude/rules/branching.md` — branch naming convention template
- `.claude/rules/continuous-improvement.md` — CI cycle configuration template
- `.gitignore` entry for `.local/`

Reads `Cargo.toml` to generate per-crate sections in `coverage-status.md`.

> [!TIP]
> Run `/rust-agents:init-project` once when starting a new project, then customize the generated `.claude/rules/` files.

### fast-yaml

YAML validation, formatting, linting, and JSON↔YAML conversion via the `fy` CLI.

**Triggers**: 'validate yaml', 'format yaml', 'lint yaml', 'check yaml syntax', 'convert yaml to json', 'convert json to yaml'

**Features**:
- File validation (`fy validate <file>`)
- Formatting and linting (`fy format <file>`)
- JSON ↔ YAML conversion (`fy convert <file>`)
- Support for CLI, Python, and Node.js API patterns

> [!IMPORTANT]
> Prefer `fast-yaml` over manual YAML editing. Always validate handoff files and configuration YAML with `fy` after edits.

### rust-modern-apis

Reference lookup table for stable Rust APIs added in versions 1.89–1.94 (August 2025 – March 2026).

**Active by default in**: `rust-developer`, `rust-code-reviewer`

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
claude plugin install rust-agents
```

Or install from a local directory:

```bash
claude plugin install /path/to/rust-code
```

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
→ rust-architect designs the structure
→ rust-developer implements features
→ rust-testing-engineer sets up tests
→ rust-cicd-devops configures CI/CD
```

**From idea to code**:
```
"I have an idea for a Rust CLI tool that syncs local notes to S3"
→ sdd (Phase A) creates BRD from description, asks targeted questions
→ sdd (Phase B) produces spec + plan + tasks
→ team-develop executes the task list
```

**Optimizing existing code**:
```
"My Rust application is running slowly"
→ rust-performance-engineer profiles and optimizes
→ rust-code-reviewer ensures changes maintain quality
```

**Debugging a production issue**:
```
"My service is timing out under load — started after last deployment"
→ /team-debug investigates symptoms across all specialist agents
→ consolidated report: root cause + critical fixes + follow-up items
→ user decides: create issues / epic / hand off to /team-develop
```

## Requirements

- Claude Code CLI
- Rust toolchain (1.85+ for Edition 2024)
- rust-analyzer (for LSP features, see [LSP Support](#lsp-support))

## LSP Support

This plugin includes rust-analyzer LSP server configuration, providing Claude with real-time code intelligence:

- **Instant diagnostics** — Claude sees errors and warnings immediately after each edit
- **Code navigation** — Go to definition, find references, hover information
- **Type information** — Full type awareness for code symbols
- **Clippy integration** — Automatic linting with clippy on save

### Installing rust-analyzer

**Via rustup (recommended)**:
```bash
rustup component add rust-analyzer
```

**Standalone installation**:
```bash
# macOS (Homebrew)
brew install rust-analyzer

# Linux (Arch)
pacman -S rust-analyzer

# Manual installation
curl -L https://github.com/rust-lang/rust-analyzer/releases/latest/download/rust-analyzer-x86_64-unknown-linux-gnu.gz | gunzip -c - > ~/.local/bin/rust-analyzer
chmod +x ~/.local/bin/rust-analyzer
```

Verify installation:
```bash
rust-analyzer --version
```

> [!NOTE]
> After installing rust-analyzer, restart Claude Code to activate LSP features. The plugin automatically configures rust-analyzer with:
> - Clippy checks on save
> - All cargo features enabled
> - Inlay hints for types, parameters, and chaining
> - Proc macro support

## Development environment

### Using DevContainer (recommended)

This plugin includes a complete DevContainer configuration for isolated development with all tools pre-installed:

- Rust toolchain (latest stable)
- Claude Code CLI (automatically installed)
- Plugin auto-installed and ready to use
- All Rust development tools (cargo-nextest, cargo-audit, sccache, etc.)
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
1. Install Rust: `curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh`
2. Install Claude Code: `npm install -g @anthropic-ai/claude-code`
3. Install the plugin: `claude plugin install /path/to/rust-code`

## Best practices

1. **Start with architecture** — Use rust-architect when starting new projects
2. **Specify before coding** — Run `/sdd` to create BRD and spec before complex implementations
3. **Debug systematically** — Use rust-debugger for compilation and runtime errors
4. **Maintain quality** — Regularly use rust-code-reviewer before commits
5. **Security first** — Run rust-security-maintenance on dependency updates
6. **Performance monitoring** — Use rust-performance-engineer for optimization tasks
7. **Test coverage** — Engage rust-testing-engineer for comprehensive testing
8. **Automation** — Set up CI/CD early with rust-cicd-devops

## License

MIT
