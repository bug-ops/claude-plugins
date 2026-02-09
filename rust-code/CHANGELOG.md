# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.11.0] - 2026-02-09

### Added
- New `rust-release` skill for automated release preparation workflow
  - Supports patch/minor/major semver version bumps
  - Creates release branch, updates all Cargo.toml manifests
  - Finalizes CHANGELOG.md with versioned section and comparison links
  - Refreshes README via `/readme-generator` skill integration
  - Runs pre-release quality checks (fmt, nextest, clippy, build)
  - Creates commit, pushes branch, and opens PR via `gh`
  - Handles both single-crate and workspace projects
  - Reference documentation for changelog format conventions

## [1.10.2] - 2026-02-07

### Added
- JSON → YAML conversion documentation in `fast-yaml` skill
  - Added `fy convert yaml` CLI command documentation
  - Python API examples for JSON → YAML conversion with helper functions
  - Node.js/TypeScript API examples including batch conversion and CLI script
  - Bidirectional conversion patterns for both YAML ↔ JSON directions

### Changed
- Updated `fast-yaml` skill description to include JSON → YAML triggers
- Enhanced Quick Reference table with both conversion directions
- Updated CLI commands reference with comprehensive bidirectional conversion examples

## [1.10.1] - 2026-02-07

### Fixed
- Changed memory scope from `project`/`local` to `user` for all agents to resolve access issues with ~/.claude/ directory

## [1.10.0] - 2026-02-07

### Added
- New `fast-yaml` skill for YAML validation, formatting, and conversion
  - Complete CLI reference with batch processing and parallel execution support
  - Python API documentation with linting and parallel processing capabilities
  - Node.js/TypeScript API reference for modern JavaScript projects
  - YAML 1.2.2 specification guide with migration examples from YAML 1.1
  - Supports validation, formatting, linting, and YAML-to-JSON conversion
  - Triggers on keywords: validate yaml, format yaml, lint yaml, check yaml syntax, convert yaml to json

## [1.9.6] - 2026-02-07

### Added
- Added `memory` frontmatter field to all 8 agents for persistent memory support (introduced in Claude Code v2.1.33)
  - `project` scope for 6 agents: rust-architect, rust-developer, rust-testing-engineer, rust-performance-engineer, rust-security-maintenance, rust-cicd-devops
  - `local` scope for 2 agents: rust-code-reviewer, rust-debugger

### Changed
- Agent frontmatter now includes memory configuration to enable context persistence across sessions

## [1.9.5] - 2026-02-07

### Added
- Feature flags testing strategy in rust-cicd-devops agent
- Comprehensive CI/CD workflow examples for testing with different feature combinations

## Earlier versions

See git history for changes in versions 1.9.4 and earlier.
