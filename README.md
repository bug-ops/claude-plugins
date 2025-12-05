# Claude Plugins Collection

A curated collection of specialized plugins for Claude Code CLI, designed to enhance development workflows with domain-specific expertise.

## Overview

This repository contains plugins that extend Claude Code's capabilities with specialized agents, tools, and workflows for various development domains. Each plugin provides a set of expert agents tailored to specific aspects of software development.

## Available Plugins

### 🦀 Rust Agents Plugin (`rust-code`)

A comprehensive collection of eight specialized Rust development agents covering the entire Rust development lifecycle.

**Location**: [`./rust-code`](./rust-code)

**Agents Included**:
- **rust-architect** - Workspace design, dependency strategy, architectural decisions
- **rust-developer** - Idiomatic code, ownership patterns, feature implementation
- **rust-testing-engineer** - Test coverage with nextest and criterion
- **rust-performance-engineer** - Performance optimization, profiling, build speed improvements
- **rust-security-maintenance** - Security scanning, vulnerability assessment, dependency management
- **rust-code-reviewer** - Quality assurance, standards compliance, code review
- **rust-cicd-devops** - GitHub Actions, cross-platform testing, efficient workflows
- **rust-debugger** - Systematic error diagnosis, runtime debugging, panic analysis, async debugging

**Best for**: Rust projects requiring expert guidance in architecture, performance, security, testing, or DevOps.

[→ Read full documentation](./rust-code/README.md)

## Installation

### Installing a Plugin

Install a specific plugin using Claude Code CLI:

```bash
# Install from local directory
cd claude-plugins
/plugin install ./rust-code

# Or specify full path
/plugin install /path/to/claude-plugins/rust-code
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
# Or you can explicitly request a specific agent
```

### Example Workflow

```
User: "I want to create a new Rust web service with database integration"
Claude: → Suggests rust-architect to design the structure
        → Then rust-developer to implement features
        → rust-testing-engineer to set up tests
        → rust-cicd-devops to configure CI/CD
```

## Development Environment

### Using DevContainer

Each plugin may include DevContainer configurations for isolated development. See individual plugin documentation for details.

### Working Directory Structure

```
claude-plugins/
├── README.md              # This file
├── .gitignore
├── .local/               # Working documents and reports (gitignored)
├── rust-code/            # Rust Agents Plugin
│   ├── README.md
│   ├── .claude-plugin/
│   ├── .devcontainer/
│   └── agents/
└── [future-plugins]/     # Additional plugins
```

## Plugin Development Guidelines

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

4. **Best Practices**:
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
