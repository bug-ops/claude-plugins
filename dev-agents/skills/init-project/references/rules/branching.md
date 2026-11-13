# Git Branching

Branch naming conventions for the project.
This file is read by `/dev-agents:solve-issue` to derive branch names from GitHub issues.
Customize the conventions below for this project.

## Branch Naming

These defaults are the ones `/dev-agents:solve-issue` uses without this file; change them here to override.

- Features with a milestone: `feat/m{N}/{feature-slug}` where N is the milestone number
- Features without a milestone: `feat/issue-{number}/{feature-slug}`
- Bug fixes (`bug` or `fix` label): `fix/{short-slug}`
- Slugs: lowercase, dash-separated, at most 30 characters
- Examples: `feat/m3/auth-module`, `feat/issue-42/auth-module`, `fix/null-pointer`

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
  cargo nextest run --workspace --all-features
  cargo test --doc --workspace --all-features
  RUSTFLAGS="-D warnings" RUSTDOCFLAGS="--deny rustdoc::broken_intra_doc_links" cargo doc --no-deps --workspace --all-features
  ```
  ```bash
  # TypeScript (replace pnpm with the project's package manager; prefer its package.json scripts)
  pnpm run typecheck
  pnpm run lint
  pnpm run format:check
  pnpm run test
  pnpm run build
  ```
  ```bash
  # Luau / Roblox (tools pinned in rokit.toml; drop the Rojo and definitions steps for Lune projects)
  rokit install
  curl -fsSL -o globalTypes.d.luau https://luau-lsp.pages.dev/type-definitions/globalTypes.None.d.luau
  stylua --check src
  selene src
  rojo sourcemap default.project.json -o sourcemap.json
  luau-lsp analyze --platform=roblox --definitions:@roblox=globalTypes.d.luau --sourcemap=sourcemap.json src
  lune run <test-runner-script>   # engine-independent tests; replace with the project's runner
  rojo build default.project.json -o build.rbxl
  ```
- Update `CHANGELOG.md` (`[Unreleased]` section if no version assigned)

<!-- Add project-specific gates below: -->
<!-- - Documentation updates (README, docs/) -->
<!-- - Serialization/API live testing gates -->
<!-- - Release preparation steps -->
