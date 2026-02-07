# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
