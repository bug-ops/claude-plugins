# Continuous Improvement

Project-specific instructions for the continuous improvement cycle.
This file is read by the `rust-ci-analyst` agent and the `/rust-agents:continuous-improvement` skill.
Customize the sections below for this project.

## Test Configuration

<!-- Specify how to run the project for live testing. -->
<!-- Examples: -->
<!-- cargo run --features full -- --config .local/config/testing.toml -->
<!-- cargo run -- serve --port 8080 -->

```bash
cargo run --features <flags> -- <args>
```

For debug output:

```bash
RUST_LOG=debug cargo run --features <flags> -- <args> 2>.local/testing/debug/session.log
```

## Project Subsystems

<!-- List key subsystems to track in coverage-status.md. -->
<!-- Workspace members are auto-detected from Cargo.toml, but add -->
<!-- logical subsystems that don't map 1:1 to crates. -->
<!-- Example: -->
<!-- - agent-loop — core decision loop -->
<!-- - llm-backends — provider integrations -->
<!-- - memory — persistence and retrieval -->

## Interfaces

<!-- List all supported I/O interfaces for cross-interface consistency testing. -->
<!-- Example: -->
<!-- - CLI: cargo run --features full -->
<!-- - TUI: cargo run --features full -- --tui -->
<!-- - Telegram: send prompts via bot -->
<!-- - Web API: POST /api/v1/chat -->

## Critical Paths

<!-- Features that MUST be live-tested before any PR that touches them. -->
<!-- These are prone to silent breakage not caught by unit tests. -->
<!-- Example: -->
<!-- - LLM request/response serialization (claude.rs, openai.rs) -->
<!-- - Database migrations -->
<!-- - Config parsing and validation -->

## Environment Setup

<!-- Required external dependencies for live testing. -->
<!-- Example: -->
<!-- - API keys: resolved from age vault (cargo run -- vault get KEY_NAME) -->
<!-- - Database: SQLite at .local/testing/data/test.db -->
<!-- - External services: Ollama running on localhost:11434 -->

## Reference Projects

<!-- List competitor or reference projects for competitive parity monitoring. -->
<!-- Format: Name — Stack — What to watch -->
<!-- Example: -->
<!-- - ProjectX — Rust — tool execution model, context management -->
<!-- - ProjectY — TypeScript — plugin system, UX patterns -->

## Testing Notes

<!-- Any project-specific testing instructions not covered above. -->
<!-- - Known limitations or permanent blockers -->
<!-- - Features that require special hardware or services -->
<!-- - Seasonal or time-sensitive test considerations -->
