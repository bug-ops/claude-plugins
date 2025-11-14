# Rust Agents Plugin

A comprehensive collection of specialized Rust development agents for Claude Code. This plugin provides expert assistance across all aspects of Rust development, from architecture design to deployment.

## Overview

This plugin includes seven specialized agents, each focused on a specific aspect of Rust development:

### 1. Rust Architect (`rust-architect`)
**Specialization**: Workspace structure, dependency strategy, and architectural decisions

Expert in designing scalable, maintainable Rust applications with focus on:
- Multi-crate workspace design with optimal module boundaries
- Dependency management and selection
- Error handling architecture (thiserror vs anyhow)
- MSRV policy and Rust Edition 2024
- Architecture Decision Records (ADR)

**Use when**: Starting new projects, restructuring existing codebases, making architectural decisions.

### 2. Rust Developer (`rust-developer`)
**Specialization**: Idiomatic code, ownership patterns, daily feature implementation

Focuses on:
- Writing idiomatic Rust code
- Ownership and borrowing patterns
- Error handling implementation
- Module organization
- Feature development

**Use when**: Implementing features, writing business logic, refactoring code.

### 3. Rust Testing Engineer (`rust-testing-engineer`)
**Specialization**: Comprehensive test coverage with nextest and criterion

Expert in:
- Unit and integration testing
- Test infrastructure with cargo-nextest
- Performance benchmarking with criterion
- Test-driven development (TDD)
- Mock and fixture patterns

**Use when**: Writing tests, setting up test infrastructure, benchmarking performance.

### 4. Rust Performance Engineer (`rust-performance-engineer`)
**Specialization**: Performance optimization, profiling, build speed improvements

Focuses on:
- Runtime performance optimization
- Build speed improvements with sccache
- Memory optimization
- Profiling and benchmarking
- Async performance tuning

**Use when**: Optimizing performance, reducing build times, profiling bottlenecks.

### 5. Rust Security & Maintenance (`rust-security-maintenance`)
**Specialization**: Security scanning, dependency management, vulnerability assessment

Expert in:
- cargo-audit for vulnerability scanning
- Dependency security and updates
- Secure coding practices
- Supply chain security
- Security-focused code review

**Use when**: Security audits, dependency updates, addressing vulnerabilities.

### 6. Rust Code Reviewer (`rust-code-reviewer`)
**Specialization**: Quality assurance, standards compliance, constructive feedback

Focuses on:
- Code quality review
- Adherence to Rust idioms
- Performance considerations
- Security review
- Best practices enforcement

**Use when**: Reviewing code changes, ensuring quality standards, pre-commit review.

### 7. Rust CI/CD & DevOps (`rust-cicd-devops`)
**Specialization**: GitHub Actions, cross-platform testing, efficient workflows

Expert in:
- GitHub Actions workflows
- Cross-platform CI/CD
- Code coverage integration
- Caching strategies
- Release automation

**Use when**: Setting up CI/CD, optimizing workflows, automating releases.

## Installation

Install this plugin using Claude Code:

```bash
/plugin install rust-agents
```

Or install from a local directory:

```bash
/plugin install /path/to/rust-plugin
```

## Usage

Agents are automatically available in Claude Code. You can:

1. **View available agents**: Use `/agents` command
2. **Invoke specific agent**: Claude will automatically suggest the most appropriate agent based on your task
3. **Manual invocation**: You can request a specific agent by mentioning it in your prompt

### Example Workflows

**Starting a new project**:
```
"I want to create a new Rust web service with database integration"
→ Claude suggests rust-architect to design the structure
→ Then rust-developer to implement features
→ rust-testing-engineer to set up tests
→ rust-cicd-devops to configure CI/CD
```

**Optimizing existing code**:
```
"My Rust application is running slowly"
→ rust-performance-engineer profiles and optimizes
→ rust-code-reviewer ensures changes maintain quality
```

**Security audit**:
```
"Check my project for security vulnerabilities"
→ rust-security-maintenance runs audit
→ rust-code-reviewer provides security-focused review
```

## Requirements

- Claude Code CLI
- Rust toolchain (for the agents to analyze and work with Rust projects)

## Development Environment

### Using DevContainer (Recommended)

This plugin includes a complete DevContainer configuration for isolated development with all tools pre-installed:

**Features:**
- ✅ Rust toolchain (latest stable)
- ✅ Claude Code CLI (automatically installed)
- ✅ Plugin auto-installed and ready to use
- ✅ All Rust development tools (cargo-nextest, cargo-audit, sccache, etc.)
- ✅ VS Code extensions for Rust and Markdown
- ✅ Consistent environment across all platforms

**Quick Start:**
1. Install [Docker Desktop](https://www.docker.com/products/docker-desktop) and [VS Code](https://code.visualstudio.com/)
2. Install the [Dev Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers)
3. Open this project in VS Code
4. Press `F1` → Select "Dev Containers: Reopen in Container"
5. Wait for the container to build (first time: ~10 minutes)
6. Start using Claude Code: `claude`

**What's Included:**
- Rust 1.85 (auto-updated to latest stable)
- cargo-nextest, cargo-tarpaulin, cargo-criterion
- cargo-audit, cargo-deny (security)
- cargo-flamegraph, cargo-bloat (profiling)
- sccache (build caching)
- Claude Code CLI with rust-agents plugin pre-installed

See `.local/DEVCONTAINER.md` for detailed documentation.

### Manual Setup

If not using DevContainer:
1. Install Rust: `curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh`
2. Install Claude Code: `npm install -g @anthropic-ai/claude-code`
3. Install the plugin: `/plugin install /path/to/rust-plugin`

## Agent Configuration

All agents are configured to use the `sonnet` model for optimal balance between speed and capability. Each agent has its own color coding for easy identification in the Claude Code interface.

## Best Practices

1. **Start with architecture**: Use `rust-architect` when starting new projects
2. **Maintain quality**: Regularly use `rust-code-reviewer` before commits
3. **Security first**: Run `rust-security-maintenance` on dependency updates
4. **Performance monitoring**: Use `rust-performance-engineer` for optimization tasks
5. **Test coverage**: Engage `rust-testing-engineer` for comprehensive testing
6. **Automation**: Set up CI/CD early with `rust-cicd-devops`

## Contributing

This plugin is based on agents from the `~/.claude/agents` directory. To update or modify agents, edit the source files in that directory and reinstall the plugin.

## License

MIT

## Author

Andrei G (andrei.g@my.com)

## Version

1.0.0
