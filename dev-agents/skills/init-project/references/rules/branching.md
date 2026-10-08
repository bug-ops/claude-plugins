# Git Branching

Branch naming conventions for the project.
This file is read by `/dev-agents:solve-issue` to derive branch names from GitHub issues.
Customize the conventions below for this project.

## Branch Naming

- Features: `feat/m{N}/{issue-number}-{feature-slug}` where N is the milestone number
- Bug fixes: `fix/{issue-number}-{short-slug}`
- Hotfixes: `hotfix/{issue-number}-{short-slug}`
- If no issue exists, omit the issue number segment
- If no milestone, use `feat/issue-{number}/{feature-slug}`
- Examples: `feat/m3/42-auth-module`, `fix/58-null-pointer`, `hotfix/99-crash-on-startup`

## Workflow

- For each new issue, use `/dev-agents:solve-issue <number>` to create a branch and start development
- For multi-issue batches, use `/dev-agents:triage-and-solve` to prioritize and group

## Before Creating a PR

<!-- Customize with project-specific pre-commit checks. -->
<!-- Use the full check suite from the dev-agents stack profile (toolchain.md), or the exact commands the CI workflow runs. -->
<!-- Keep one block per stack the project uses; delete the others. -->

- Run pre-commit checks (must match CI):
  ```bash
  # Rust
  cargo +nightly fmt --check
  cargo clippy --workspace --all-targets --all-features -- -D warnings
  cargo nextest run --workspace --all-features --lib --bins
  ```
  ```bash
  # TypeScript (replace pnpm with the project's package manager; prefer its package.json scripts)
  pnpm run typecheck
  pnpm run lint
  pnpm run format:check
  pnpm run test
  pnpm run build
  ```
- Update `CHANGELOG.md` (`[Unreleased]` section if no version assigned)

<!-- Add project-specific gates below: -->
<!-- - Documentation updates (README, docs/) -->
<!-- - Serialization/API live testing gates -->
<!-- - Release preparation steps -->
