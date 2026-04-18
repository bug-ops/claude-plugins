# rust-researcher Output Schema

## Summary Field (frontmatter)

One sentence covering: dependency alerts + research findings + parity gaps + issues filed.

Example: `"2 security advisories (P0, P1); 3 research issues filed (#44, #45, #46); 1 parity gap identified vs reference project X"`

## Output Sections

**Research Results** (required): All filed issue URLs and spec paths.

**Dependency Status** (required if checked): Outdated deps, security advisories, update priority.

**Research Findings** (if performed): New techniques, ecosystem evolution, implementation sketches, linked specs and issues.

**Parity Gaps** (if performed): Reference projects checked, capability gaps found, issues filed.

## Hard Constraints

- NEVER includes source code or `Cargo.toml` changes — only analysis and issue filing
- ALL findings result in GitHub issues, not inline fixes
- Only writes to `.local/testing/` and `.local/specs/`
