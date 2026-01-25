# rust-cicd-devops Output Schema

```yaml
output:
  summary: "CI/CD configuration"
  
  workflows:
    - file: .github/workflows/ci.yml
      jobs: [check, test, coverage, security]
      status: created  # created | modified
  
  secrets_required:
    - name: CODECOV_TOKEN
      purpose: "Code coverage reporting"
  
  caching:
    rust_cache: true
    sccache: true
    estimated_speedup: "60%"
  
  matrix:
    os: [ubuntu-latest, macos-latest, windows-latest]
    rust: [stable, "1.85"]
  
  estimated_times:
    check_job: "2-3 min"
    test_job: "5-10 min"
    full_pipeline: "8-15 min"
```

## Field Descriptions

| Field | Required | Description |
|-------|----------|-------------|
| `summary` | yes | Brief description of CI/CD work |
| `workflows` | yes | Workflow files created/modified |
| `secrets_required` | if any | GitHub secrets needed |
| `caching` | yes | Caching configuration |
| `matrix` | if cross-platform | Build matrix setup |
| `estimated_times` | yes | Expected job durations |

## Standard CI Jobs

| Job | Purpose | Timeout |
|-----|---------|---------|
| `check` | fmt + clippy | 10 min |
| `test` | cargo nextest | 30 min |
| `coverage` | cargo llvm-cov | 20 min |
| `security` | cargo deny | 10 min |
| `msrv` | Minimum Rust version | 15 min |

## Caching Strategy

**Two-tier caching:**
1. `Swatinem/rust-cache` — Cargo registry + target
2. `sccache` — Compiled artifacts

**Cache key pattern:**
```yaml
key: ${{ runner.os }}-cargo-${{ hashFiles('**/Cargo.lock') }}
```

## Required Secrets

| Secret | Required For |
|--------|--------------|
| `CODECOV_TOKEN` | Coverage reporting |
| `CRATES_IO_TOKEN` | Publishing (optional) |

## Multiple Parent Sources Example

When setting up CI/CD based on multiple inputs:

```yaml
id: 2025-01-09T21-00-00-cicd
parent:
  - 2025-01-09T16-00-00-testing    # Test requirements
  - 2025-01-09T20-00-00-security   # Security check requirements
  - 2025-01-09T19-00-00-performance  # Performance benchmarks
agent: cicd
```

Use this when:
- Setting up CI pipeline with requirements from testing + security + performance
- Integrating multiple validation steps from different agents
- Configuring cross-platform builds based on architecture decisions
- Adding coverage/security/performance gates based on agent recommendations
