# Rust Agents Plugin

[![Version](https://img.shields.io/badge/version-1.5.1-blue)](https://github.com/bug-ops/claude-plugins)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)
[![Rust Edition](https://img.shields.io/badge/rust-Edition%202024-orange)](https://doc.rust-lang.org/edition-guide/rust-2024/)

A comprehensive collection of specialized Rust development agents for Claude Code. This plugin provides expert assistance across all aspects of Rust development, from architecture design to deployment.

## Features

- **8 specialized agents** covering the entire Rust development lifecycle
- **Inter-agent handoff protocol** for context sharing via YAML files
- **Opus model** for all agents ensuring high-quality responses
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

Agents communicate through YAML files in `.local/handoff/` directory, enabling seamless context transfer between agents in multi-step workflows.

File naming format: `{YYYY-MM-DDTHH-MM-SS}-{agent}.yaml`

> [!TIP]
> Timestamp-first naming allows chronological sorting with `ls` to easily find the latest handoff files.

```yaml
# Example handoff file: .local/handoff/2025-01-09T14-30-45-architect.yaml
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
