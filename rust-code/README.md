# Rust Agents Plugin

[![Version](https://img.shields.io/badge/version-1.12.0-blue)](https://github.com/bug-ops/claude-plugins)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)
[![Rust Edition](https://img.shields.io/badge/rust-Edition%202024-orange)](https://doc.rust-lang.org/edition-guide/rust-2024/)

A comprehensive collection of specialized Rust development agents for Claude Code. This plugin provides expert assistance across all aspects of Rust development, from architecture design to deployment.

## Features

- **8 specialized agents** covering the entire Rust development lifecycle
- **5 productivity skills** for enhanced workflows:
  - **rust-lifecycle** — Full development workflow orchestration
  - **rust-agent-handoff** — Inter-agent context sharing
  - **rust-release** — Automated release preparation
  - **readme-generator** — Professional README generation
  - **mdbook-tech-writer** — Technical documentation with mdBook
- **rust-analyzer LSP integration** for real-time code intelligence with Claude
- **Proactive triggers** — agents are suggested automatically based on your task
- **Rust Edition 2024** support with modern tooling
- **Async combinator patterns** for elegant concurrent code

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
**Model**: opus | **Specialization**: Idiomatic code, ownership patterns, feature implementation

Focuses on:
- Writing idiomatic Rust code
- Ownership and borrowing patterns
- Error handling implementation
- Module organization
- Feature development

**Use when**: Implementing features, writing business logic, refactoring code.

### rust-testing-engineer
**Model**: opus | **Specialization**: Comprehensive test coverage with nextest and criterion

Expert in:
- Unit and integration testing
- Test infrastructure with cargo-nextest
- Performance benchmarking with criterion
- Test-driven development (TDD)
- Mock and fixture patterns

**Use when**: Writing tests, setting up test infrastructure, benchmarking performance.

### rust-performance-engineer
**Model**: opus | **Specialization**: Performance optimization, profiling, build speed improvements

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
**Model**: opus | **Specialization**: Quality assurance, standards compliance, constructive feedback

Focuses on:
- Code quality review
- Adherence to Rust idioms
- Performance considerations
- Security review
- Best practices enforcement

**Use when**: Reviewing code changes, ensuring quality standards, pre-commit review.

### rust-cicd-devops
**Model**: opus | **Specialization**: GitHub Actions, cross-platform testing, efficient workflows

Expert in:
- GitHub Actions workflows
- Cross-platform CI/CD
- Code coverage integration
- Caching strategies
- Release automation

**Use when**: Setting up CI/CD, optimizing workflows, automating releases.

### rust-debugger
**Model**: opus | **Specialization**: Systematic error diagnosis, runtime debugging, panic analysis

Expert in:
- Borrow checker and lifetime error interpretation
- LLDB/GDB debugging on macOS/Linux
- Panic and backtrace analysis
- Async runtime debugging (Tokio, tokio-console)
- Memory leak detection and investigation
- Production incident response

**Use when**: Encountering compilation errors, runtime panics, unexpected behavior, performance anomalies, or production issues.

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

### rust-lifecycle

Complete development workflow orchestrator for managing multi-phase Rust projects.

**Triggers**: 'rust-lifecycle', 'start feature', 'full development workflow', 'orchestrate development'

**Workflow phases**:
1. **Planning** (rust-architect) — Architecture design and technical decisions
2. **Implementation** (rust-developer) — Feature development
3. **Parallel validation** — Performance analysis, security audit, test coverage
4. **Code review** (rust-code-reviewer) — Quality assurance
5. **Fix issues** (rust-developer) — Address ALL review feedback (mandatory)
6. **Re-review** — Final approval check
7. **Commit + PR** — Automated git operations

**Key features**:
- Multi-phase workflow with handoff protocol
- Parallel validation for faster feedback
- Mandatory issue resolution before commits
- Automatic PR creation and updates
- Git branch management
- Progress tracking with task lists

> [!IMPORTANT]
> The lifecycle enforces quality by requiring ALL code review issues to be fixed before committing. No shortcuts.

**Use when**: Starting complex features, implementing multi-file changes, managing full development cycles.

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
