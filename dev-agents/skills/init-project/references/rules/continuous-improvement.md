# Continuous Improvement

Project-specific instructions for the continuous improvement cycle.
This file is passed to the `live-tester`, `researcher`, `arch-analyst`, and `security-analyst` agents by the `/dev-agents:continuous-improvement` skill.
Customize the sections below for this project.

## Test Configuration

<!-- Specify how to run the project for live testing. Keep the block for each stack the project uses. -->
<!-- Examples: -->
<!-- cargo run --features full -- --config .local/config/testing.toml -->
<!-- cargo run -- serve --port 8080 -->
<!-- pnpm run build && node dist/cli.js --config .local/config/testing.json -->
<!-- pnpm run dev -- --port 5173 -->

```bash
# Rust
cargo run --features <flags> -- <args>
```

```bash
# TypeScript (use the project's package manager and scripts)
pnpm run build && node dist/<entry>.js <args>
```

For debug output:

```bash
# Rust
RUST_LOG=debug cargo run --features <flags> -- <args> 2>.local/testing/debug/session.log
```

```bash
# TypeScript (DEBUG applies to the `debug` package; use the project's logger level variable otherwise)
NODE_OPTIONS=--enable-source-maps DEBUG=* node dist/<entry>.js <args> 2>.local/testing/debug/session.log
```

## Project Subsystems

<!-- List key subsystems to track in coverage-status.md. -->
<!-- Units are auto-detected (Rust workspace crates, TypeScript workspace packages), but add -->
<!-- logical subsystems that don't map 1:1 to crates or packages. -->
<!-- Example: -->
<!-- - agent-loop — core decision loop -->
<!-- - llm-backends — provider integrations -->
<!-- - memory — persistence and retrieval -->

## Interfaces

<!-- List all supported I/O interfaces for cross-interface consistency testing. -->
<!-- Example: -->
<!-- - CLI: cargo run --features full -->
<!-- - TUI: cargo run --features full -- --tui -->
<!-- - Web UI: pnpm run dev, driven with Playwright -->
<!-- - Telegram: send prompts via bot -->
<!-- - Web API: POST /api/v1/chat -->

## Critical Paths

<!-- Features that MUST be live-tested before any PR that touches them. -->
<!-- These are prone to silent breakage not caught by unit tests. -->
<!-- Example: -->
<!-- - LLM request/response serialization (claude.rs, openai.rs) -->
<!-- - Database migrations -->
<!-- - Config parsing and validation -->
<!-- - Request validation schemas (zod/valibot) at API boundaries -->

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

## Security Scope

<!-- Guidance for the security-analyst vulnerability audit. -->

<!-- Trust boundaries — where untrusted input enters the system. -->
<!-- The audit prioritizes code reachable from these. -->
<!-- Example: -->
<!-- - HTTP request bodies (handlers in api/) -->
<!-- - CLI arguments and config files -->
<!-- - Messages deserialized from the message queue -->

<!-- Accepted risks — findings that are known and intentionally allowed, -->
<!-- so the audit does not re-file them each cycle. -->
<!-- Example: -->
<!-- - unsafe in ffi/ is reviewed and documented (SAFETY comments present) -->
<!-- - md5 in checksum.rs is a non-security content hash, not a security primitive -->
<!-- - dangerouslySetInnerHTML in Markdown.tsx renders sanitized (DOMPurify) output only -->

<!-- Sensitive assets — what an attacker would target. -->
<!-- Example: -->
<!-- - API keys resolved from the age vault -->
<!-- - User password hashes in the accounts table -->

## Testing Notes

<!-- Any project-specific testing instructions not covered above. -->
<!-- - Known limitations or permanent blockers -->
<!-- - Features that require special hardware or services -->
<!-- - Seasonal or time-sensitive test considerations -->
