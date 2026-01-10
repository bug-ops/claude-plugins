# Claude Plugins Collection

A curated collection of specialized plugins for Claude Code CLI, designed to enhance development workflows with domain-specific expertise.

## Overview

This repository contains plugins that extend Claude Code's capabilities with specialized agents, tools, and workflows for various development domains. Each plugin provides a set of expert agents tailored to specific aspects of software development.

## Available plugins

### Rust Agents Plugin (`rust-code`)

[![Version](https://img.shields.io/badge/version-1.5.1-blue)](./rust-code)
[![License](https://img.shields.io/badge/license-MIT-green)](./rust-code/LICENSE)

A comprehensive collection of eight specialized Rust development agents covering the entire Rust development lifecycle.

**Location**: [`./rust-code`](./rust-code)

**Key features**:
- 8 specialized agents with opus model for high-quality responses
- Inter-agent handoff protocol with timestamp-first YAML files for chronological sorting
- Proactive triggers for automatic agent selection
- Rust Edition 2024 support

**Agents included**:
| Agent | Specialization |
|-------|---------------|
| rust-architect | Workspace design, type-driven architecture, strategic decisions |
| rust-developer | Idiomatic code, ownership patterns, feature implementation |
| rust-testing-engineer | Test coverage with nextest and criterion |
| rust-performance-engineer | Performance optimization, profiling, build speed |
| rust-security-maintenance | Security scanning, vulnerability assessment, dependency management |
| rust-code-reviewer | Quality assurance, standards compliance, code review |
| rust-cicd-devops | GitHub Actions, cross-platform testing, workflows |
| rust-debugger | Error diagnosis, runtime debugging, panic analysis |

**Best for**: Rust projects requiring expert guidance in architecture, performance, security, testing, or DevOps.

[→ Read full documentation](./rust-code/README.md)

## Installation

### Installing a plugin

Install a specific plugin using Claude Code CLI:

```bash
# Install from local directory
cd claude-plugins
claude plugin install ./rust-code

# Or specify full path
claude plugin install /path/to/claude-plugins/rust-code
```

### Prerequisites

- [Claude Code CLI](https://docs.claude.com/claude-code) installed and configured
- Appropriate toolchain for the plugin you're using (e.g., Rust toolchain for rust-code plugin)

## Usage

Once installed, agents from the plugins become available in Claude Code:

```bash
# Start Claude Code
claude

# View available agents
/agents

# Agents will be automatically suggested based on your task
```

### Example workflow

```
User: "I want to create a new Rust web service with database integration"
Claude: → rust-architect designs the structure
        → rust-developer implements features
        → rust-testing-engineer sets up tests
        → rust-cicd-devops configures CI/CD
```

> [!TIP]
> Agents can delegate work to other agents using the handoff protocol, preserving context between transitions.

## Repository structure

```
claude-plugins/
├── README.md              # This file
├── .gitignore
├── .local/                # Working documents and reports (gitignored)
├── rust-code/             # Rust Agents Plugin
│   ├── README.md
│   ├── .claude-plugin/
│   ├── .devcontainer/
│   └── agents/
└── [future-plugins]/      # Additional plugins
```

## Development environment

### Using DevContainer

Each plugin may include DevContainer configurations for isolated development. See individual plugin documentation for details.

## Plugin development guidelines

When creating new plugins for this repository:

1. **Structure**:
   - Each plugin in its own directory
   - Include `.claude-plugin/` configuration
   - Provide comprehensive README.md
   - Use `.devcontainer/` for development environment (optional but recommended)

2. **Documentation**:
   - All documentation in English
   - Clear usage examples
   - Installation instructions
   - Requirements and dependencies

3. **Agents**:
   - Focused, single-responsibility agents
   - Clear specialization boundaries
   - Appropriate model selection
   - Distinct color coding for easy identification
   - Include handoff protocol for multi-agent workflows

4. **Best practices**:
   - Follow [Microsoft Rust Guidelines](https://microsoft.github.io/rust-guidelines/agents/all.txt) for Rust-related plugins
   - Use `.local/` directory for working documents
   - Include version information
   - Add comprehensive examples

## Contributing

Contributions are welcome! To add a new plugin or improve existing ones:

1. Create a new directory for your plugin
2. Include `.claude-plugin/` configuration
3. Write comprehensive documentation
4. Test thoroughly with Claude Code
5. Submit a pull request

## Roadmap

Future plugin ideas:
- Python development agents
- Web development (React, Vue, Svelte)
- Database management and optimization
- Cloud infrastructure (AWS, Azure, GCP)
- DevOps and platform engineering
- Documentation and technical writing

## License

MIT
