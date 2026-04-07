# Rust Agents Plugin

[![Version](https://img.shields.io/badge/version-1.21.1-blue)](https://github.com/bug-ops/claude-plugins)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)
[![Rust Edition](https://img.shields.io/badge/rust-Edition%202024-orange)](https://doc.rust-lang.org/edition-guide/rust-2024/)

A comprehensive collection of specialized Rust development agents for Claude Code. This plugin provides expert assistance across all aspects of Rust development, from architecture design to deployment.

## Features

- **12 specialized agents** covering the entire Rust development lifecycle including team orchestration and continuous improvement
- **11 productivity skills** for enhanced workflows:
  - **rust-team** — Multi-agent team orchestration with peer-to-peer communication
  - **rust-agent-handoff** — Inter-agent context sharing
  - **solve-issue** — Solve GitHub issues end-to-end via worktree + rust-team
  - **triage-and-solve** — Triage open issues by priority, group, and solve
  - **continuous-improvement** — CI cycle: live testing, anomaly detection, research, dependency monitoring
  - **init-project** — Scaffold project infrastructure for the rust-agents plugin
  - **rust-release** — Automated release preparation
  - **readme-generator** — Professional README generation
  - **mdbook-tech-writer** — Technical documentation with mdBook
  - **sdd** — Spec-Driven Development workflow
  - **fast-yaml** — YAML validation, formatting, and conversion
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
**Model**: sonnet | **Specialization**: Spec-Driven Development, requirements, PRDs, task planning

Guides the full specification lifecycle:
- Turning vague ideas into actionable requirements
- Writing product requirements documents (PRDs)
- Breaking work into implementation tasks for coding agents
- Reviewing specification quality and completeness

**Use when**: Starting a new feature with unclear requirements, preparing tasks for coding agents, or formalizing a design before implementation.

### rust-ci-analyst
**Model**: opus | **Specialization**: Continuous improvement cycles, live testing, anomaly detection, competitive parity

Read-only analyst for the continuous improvement loop:
- Live testing of project features (not just unit tests)
- Anomaly detection and issue triage with P0-P4 priority labels
- Dependency monitoring (cargo-outdated, cargo-deny)
- Competitive parity analysis against reference projects
- Maintains testing knowledge base in `.local/testing/`

**Use when**: Running a CI cycle, testing new functionality live, monitoring dependencies, or performing competitive analysis.

> [!IMPORTANT]
> rust-ci-analyst never modifies source code — it only files GitHub issues and updates testing documentation. All fixes happen in separate `/rust-agents:rust-team` sessions.

### rust-teamlead
**Model**: sonnet | **Specialization**: Multi-agent team orchestration for complex Rust development tasks

Coordinates specialist agents using Claude Code experimental agent teams:
- Creates and manages teams via TeamCreate/TeamDelete
- Assigns tasks and monitors progress via TaskCreate/TaskList
- Spawns agents incrementally as workflow progresses
- Aggregates results from handoff files and agent messages
- **Only agent** allowed to commit and create PRs

**Use when**: Complex features requiring cross-agent collaboration, full development workflow (architect → critic → developer → validators → reviewer → commit).

> [!NOTE]
> Requires `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` in environment or `settings.json`.

## Handoff Protocol

Agents use the `rust-agent-handoff` skill for context sharing through YAML files in `.local/handoff/` directory.

File naming format: `{YYYY-MM-DDTHH-MM-SS}-{agent}.yaml`

> [!TIP]
> Timestamp-first naming allows chronological sorting with `ls` to easily find the latest handoff files.

```yaml
# Example: .local/handoff/2025-01-09T14-30-45-architect.yaml
id: 2025-01-09T14-30-45-architect
agent: architect
status: completed

context:
  task: "Design user management system"

output:
  summary: "Designed type-driven user management"
  files_created:
    - Cargo.toml
    - crates/core/src/lib.rs

next:
  agent: rust-developer
  task: "Implement Email and User types"
```

Handoff files preserve context when one agent delegates work to another, ensuring no information is lost between agent transitions.

## Skills

This plugin includes productivity skills that enhance your workflow:

### rust-team

Team-based development orchestration for Rust projects using Claude Code agent teams. Coordinates all specialist agents with peer-to-peer communication via SendMessage.

**Triggers**: 'create rust team', 'start team development', 'launch agent team', 'team workflow', 'collaborative development'

**Workflow**: architect → critic → developer → parallel(tester, perf, security, impl-critic) → reviewer → fix cycle → commit

**Requires**: `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`

> [!TIP]
> Run `/sdd` before `/rust-team` for complex features to ensure the implementation is well-specified before coding starts.

### rust-agent-handoff

Handoff protocol for multi-agent Rust development. Enables structured communication between agents through YAML files in `.local/handoff/` directory.

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

### sdd

Spec-Driven Development workflow for turning ideas into implementation-ready specifications.

**Triggers**: 'sdd', 'create specification', 'write requirements', 'design feature', 'plan implementation', 'I want to build X', 'let's design'

**Workflow phases**:
1. **Init** — project context and goals
2. **Specify** — requirements, constraints, acceptance criteria
3. **Plan** — architecture and implementation approach
4. **Tasks** — break down into coding agent tasks
5. **Review** — specification quality check

**Features**:
- Structured PRD generation
- Task breakdown for rust-team handoff
- Iterative refinement with user input

### solve-issue

Solve a GitHub issue end-to-end: fetch issue data, create a branch in a worktree, and launch rust-team agents.

**Usage**: `/rust-agents:solve-issue <issue-number>`

**Workflow**:
1. Fetches issue metadata via `gh issue view`
2. Derives branch name from issue labels and milestone
3. Creates an isolated worktree via `EnterWorktree`
4. Launches `/rust-agents:rust-team` with full issue context

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
6. Launches `/rust-agents:solve-issue` for the selected group

### continuous-improvement

Run a continuous improvement cycle: sync, live-test, detect anomalies, monitor dependencies, research, file issues.

**Usage**: `/rust-agents:continuous-improvement [testing|research|dependencies|parity|full]`

**Phases**:
- **Sync** — pull latest changes, update coverage status
- **Live Testing** — exercise features end-to-end (not just unit tests)
- **Issue Filing** — classify anomalies with P0-P4 labels, file via `gh issue create`
- **Dependency Monitoring** — `cargo outdated`, `cargo deny check advisories`
- **Research & Parity** — search for new techniques, monitor reference projects

**Reference docs**:
- Testing methodology, issue management protocol, research protocol

> [!NOTE]
> If the project has `.claude/rules/continuous-improvement.md`, it provides project-specific details (test configs, subsystems, reference projects) that override generic defaults.

### init-project

Scaffold project infrastructure for the rust-agents plugin.

**Usage**: `/rust-agents:init-project [--force]`

**Creates**:
- `.local/handoff/` — agent communication (rust-agent-handoff)
- `.local/plan/` — implementation plans (sdd)
- `.local/team-results/` — team reports (rust-team)
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

**Optimizing existing code**:
```
"My Rust application is running slowly"
→ rust-performance-engineer profiles and optimizes
→ rust-code-reviewer ensures changes maintain quality
```

**Debugging an issue**:
```
"I'm getting a borrow checker error I don't understand"
→ rust-debugger analyzes and explains the error
→ rust-developer implements the fix
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
2. **Debug systematically** — Use rust-debugger for compilation and runtime errors
3. **Maintain quality** — Regularly use rust-code-reviewer before commits
4. **Security first** — Run rust-security-maintenance on dependency updates
5. **Performance monitoring** — Use rust-performance-engineer for optimization tasks
6. **Test coverage** — Engage rust-testing-engineer for comprehensive testing
7. **Automation** — Set up CI/CD early with rust-cicd-devops

## License

MIT
