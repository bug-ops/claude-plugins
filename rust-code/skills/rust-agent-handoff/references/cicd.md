# rust-cicd-devops Output Schema

## Summary Field (frontmatter)

One sentence covering: what was set up + jobs configured + estimated pipeline time.

Example: `"CI pipeline: check/test/coverage/security jobs; matrix ubuntu+macos; ~10 min full run"`

## Output Sections

**CI/CD Summary** (required): What was configured and key decisions.

**Workflows** (required): For each file — path, jobs list, status (`created` | `modified`).

**Secrets Required** (if any): Name and purpose for each GitHub secret needed.

**Caching** (required): rust-cache enabled, sccache enabled, estimated speedup %.

**Matrix** (if cross-platform): OS list, Rust version list.

**Estimated Times** (required): Per-job and full pipeline estimates.

## Standard CI Jobs

| Job | Purpose | Timeout |
|-----|---------|---------|
| `check` | fmt + clippy | 10 min |
| `test` | cargo nextest | 30 min |
| `coverage` | cargo llvm-cov | 20 min |
| `security` | cargo deny | 10 min |
| `msrv` | Minimum Rust version | 15 min |

## Caching Strategy

Two-tier: `Swatinem/rust-cache` (Cargo registry + target) + `sccache` (compiled artifacts).

Cache key: `${{ runner.os }}-cargo-${{ hashFiles('**/Cargo.lock') }}`
