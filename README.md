# Claude Plugins Collection

A curated collection of specialized plugins for Claude Code CLI, designed to enhance development workflows with domain-specific expertise.

## Overview

This repository contains plugins that extend Claude Code's capabilities with specialized agents, tools, and workflows for various development domains. Each plugin provides a set of expert agents tailored to specific aspects of software development.

## Available plugins

### dev-agents (`dev-agents`)

[![Version](https://img.shields.io/badge/version-2.0.0-blue)](./dev-agents)
[![License](https://img.shields.io/badge/license-MIT-green)](./dev-agents/LICENSE)

Language-agnostic development agents covering the whole development lifecycle, with stack profiles for **Rust** and **TypeScript/JavaScript**. Agents carry the process; the `stack` skill detects the project's language and loads the matching rules: toolchain commands, idioms, anti-patterns, and checklists per role. Polyglot repositories load both profiles.

Formerly `rust-agents` (1.x). See the [migration notes](./dev-agents/README.md#migrating-from-rust-agents-1x).

**Location**: [`./dev-agents`](./dev-agents)

**Key features**:
- 15 specialized agents (opus/sonnet) that apply per-language rules from the `stack` skill
- 20 productivity skills:
  - **stack** — Stack detection and per-language reference loader (Rust, TypeScript); loaded by every agent at startup
  - **team-develop** — Multi-agent development orchestration with peer-to-peer communication; Step 0 classifies tasks into one of nine chains (`new-feature`, `spec-driven`, `bug-fix`, `refactoring`, `security`, `docs`, `dependency`, `performance`, `ci-cd`) and runs only the agents that chain needs
  - **team-debug** — Multi-agent root cause investigation: debugger → parallel review → consolidated report → user decides next steps
  - **agent-handoff** — Inter-agent context sharing
  - **solve-issue** — Solve GitHub issues end-to-end via worktree + team-develop
  - **triage-and-solve** — Triage open issues by priority, group, and solve
  - **continuous-improvement** — Orchestrates live-tester + researcher + arch-analyst + security-analyst agents for a full CI cycle
  - **live-testing** — Live execution of the built artifact, anomaly detection, coverage tracking, bug filing
  - **research-protocol** — Dependency monitoring, research & innovation, competitive parity
  - **arch-inspect** — Architecture and code-quality audit protocol (type safety, modularity, testability, readability, DRY, async)
  - **security-audit** — Vulnerability audit protocol (dependency advisories, unsafe and escape-hatch code, secrets, injection, crypto, auth, crash-DoS, supply chain)
  - **init-project** — Scaffold project infrastructure for the plugin (Rust, TypeScript, polyglot)
  - **release** — Release preparation: version bump, changelog, docs refresh
  - **readme-generator** — Professional README generation
  - **mdbook-tech-writer** — Technical documentation with mdBook
  - **obsidian-zettelkasten** — Obsidian knowledge base with Zettelkasten method
  - **sdd** — Spec-Driven Development workflow
  - **spec-from-stream** — Business requirements from stream-of-consciousness (BRD/SRS/NFR)
  - **fast-yaml** — YAML validation, formatting, and conversion
  - **rust-modern-apis** — Lookup table for stable Rust APIs added in 1.89–1.99 (loaded by the Rust profile)
- rust-analyzer and typescript-language-server LSP integration
- Proactive triggers for automatic agent selection

**Agents included**:
| Agent | Model | Specialization |
|-------|-------|---------------|
| architect | opus | Type-driven architecture, module and package boundaries, strategic decisions |
| developer | sonnet | Idiomatic, type-safe feature implementation |
| testing-engineer | sonnet | Test coverage, test infrastructure, benchmarks |
| performance-engineer | sonnet | Profiling, optimization, build speed |
| security-maintenance | opus | Security scanning, vulnerability assessment, dependency management |
| code-reviewer | sonnet | Quality assurance, standards compliance, code review |
| cicd-devops | sonnet | GitHub Actions, cross-platform testing, workflows |
| debugger | sonnet | Error diagnosis, runtime debugging, crash analysis |
| critic | opus | Adversarial design critique, assumption stress-testing |
| sdd | sonnet | Full-cycle SDD orchestrator: BRD/SRS/NFR → spec/plan/tasks → knowledge base |
| live-tester | sonnet | Live execution, anomaly detection, coverage tracking, bug filing |
| tech-writer | sonnet | User-facing documentation with mdBook, progressive disclosure |
| researcher | sonnet | Dependency monitoring, security advisories, research, competitive parity |
| arch-analyst | opus | Architecture audits: type system anti-patterns, DRY violations, structure, async defects |
| security-analyst | opus | Vulnerability audits: dependency advisories, unsafe code, secrets, injection, crypto misuse, auth, supply chain |

**Best for**: Rust and TypeScript projects (including polyglot repositories) requiring expert guidance in architecture, performance, security, testing, DevOps, or multi-agent team workflows.

[→ Read full documentation](./dev-agents/README.md)

## Installation

### Quick start: Install from marketplace

The easiest way to install plugins is via the marketplace:

```bash
# Add the marketplace
claude plugin marketplace add bug-ops/claude-plugins

# Install the dev-agents plugin
claude plugin install dev-agents@claude-dev-agents
```

This method provides automatic updates and centralized plugin management.

### Alternative: Install from local directory

For development or testing, load the plugin directly from a local path:

```bash
# Load for one session
claude --plugin-dir ./dev-agents

# Or install from the local directory
claude plugin install /path/to/claude-plugins/dev-agents
```

### Prerequisites

- [Claude Code CLI](https://docs.claude.com/claude-code) installed and configured
- The toolchain of the stack you work in:
  - Rust: Rust 1.85+, rust-analyzer for LSP support
  - TypeScript: Node.js LTS, the project's package manager, typescript-language-server for LSP support

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
Claude: → /team-develop detects stack rust, classifies as new-feature
        → architect → critic → developer → validators → reviewer → commit

User: "Add rate limiting to the Express API"
Claude: → /team-develop detects stack typescript, classifies as new-feature
        → same chain; every agent loads the TypeScript profile

User: "Draft a spec for a multi-tenant billing module — no code yet"
Claude: → /team-develop classifies as spec-driven
        → architect → critic → sdd → reviewer → commit spec → open follow-up implementation issue

User: "My service is timing out under load"
Claude: → /team-debug: debugger investigates → parallel review (arch, critic, security, perf)
        → consolidated report (root cause + critical fixes + follow-up items) → user decides next steps
```

> [!TIP]
> Agents can delegate work to other agents using the handoff protocol, preserving context between transitions.

## Repository structure

```
claude-plugins/
├── README.md                   # This file
├── .gitignore
├── .claude-plugin/
│   └── marketplace.json        # Marketplace catalog
├── .local/                     # Working documents and reports (gitignored)
├── dev-agents/                 # dev-agents plugin (includes team orchestration)
│   ├── README.md
│   ├── .claude-plugin/
│   │   └── plugin.json
│   ├── .lsp.json              # rust-analyzer and typescript-language-server
│   ├── .devcontainer/
│   ├── agents/                # 15 specialist agents
│   └── skills/                # 20 skills; stack/references/{rust,typescript}/ hold the language rules
└── [future-plugins]/           # Additional plugins
```

## Marketplace

This repository provides a Claude Code plugin marketplace at `.claude-plugin/marketplace.json`.

### Using the marketplace

```bash
# Add marketplace from GitHub
claude plugin marketplace add bug-ops/claude-plugins

# List available plugins
claude plugin list

# Install a plugin
claude plugin install dev-agents@claude-dev-agents

# Update marketplace and plugins
claude plugin marketplace update claude-dev-agents
```

### Adding to project settings

For team use, add the marketplace to `.claude/settings.json`:

```json
{
  "extraKnownMarketplaces": {
    "claude-dev-agents": {
      "source": {
        "source": "github",
        "repo": "bug-ops/claude-plugins"
      }
    }
  },
  "enabledPlugins": {
    "dev-agents@claude-dev-agents": true
  }
}
```

This ensures team members are prompted to install the marketplace and plugins when they trust the project.

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

To add a language to dev-agents, add `dev-agents/skills/stack/references/<language>/` with a `toolchain.md` and one file per role, then extend the detection table in `stack/SKILL.md`.

## Roadmap

Future ideas:
- More stack profiles for dev-agents: Python, Go
- Database management and optimization
- Cloud infrastructure (AWS, Azure, GCP)

## License

MIT
