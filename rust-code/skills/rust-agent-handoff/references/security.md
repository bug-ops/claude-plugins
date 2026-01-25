# rust-security-maintenance Output Schema

```yaml
output:
  summary: "Security audit results"
  
  vulnerabilities:
    critical: 0
    high: 1
    medium: 3
    low: 5
  
  cargo_deny:
    status: pass  # pass | fail
    advisories: 0
    license_issues: 0
  
  dependencies:
    outdated: 12
    unmaintained: 1
    actions:
      - package: serde
        current: "1.0.190"
        latest: "1.0.195"
        action: update
  
  unsafe_blocks:
    total: 3
    reviewed: 3
    approved: 2
    needs_refactor: 1
  
  issues:
    - severity: high
      location: src/auth.rs:42
      issue: "SQL injection possible"
      fix: "Use parameterized query"
```

## Field Descriptions

| Field | Required | Description |
|-------|----------|-------------|
| `summary` | yes | Brief description of security work |
| `vulnerabilities` | yes | Count by severity |
| `cargo_deny` | yes | cargo-deny check results |
| `dependencies` | yes | Dependency audit results |
| `unsafe_blocks` | if present | Unsafe code review |
| `issues` | if found | Security issues found |

## Severity Levels

| Level | Response Time | Examples |
|-------|---------------|----------|
| `critical` | Immediate | RCE, auth bypass |
| `high` | 24 hours | SQL injection, XSS |
| `medium` | 1 week | Information disclosure |
| `low` | Next release | Minor issues |

## Security Checklist

- [ ] `cargo deny check` passes
- [ ] No hardcoded secrets
- [ ] All unsafe blocks documented with SAFETY comments
- [ ] Input validation on all external data
- [ ] SQL uses parameterized queries
- [ ] Passwords hashed with argon2

## Multiple Parent Sources Example

When conducting security audit across multiple contexts:

```yaml
id: 2025-01-09T20-00-00-security
parent:
  - 2025-01-09T14-30-45-architect  # Design security requirements
  - 2025-01-09T15-30-00-developer  # Implementation
  - 2025-01-09T17-00-00-review     # Code review findings
agent: security
```

Use this when:
- Auditing implementation against architecture security requirements
- Following up on security concerns raised in code review
- Validating fixes for vulnerabilities found by debugger
- Comprehensive security review needs design intent + implementation + review feedback
