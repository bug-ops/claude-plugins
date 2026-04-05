# rust-security-maintenance Output Schema

## Summary Field (frontmatter)

One sentence covering: audit scope + critical/high finding count + cargo-deny status.

Example: `"Security audit: 0 critical, 1 high (SQL injection in src/auth.rs); cargo-deny pass"`

## Output Sections

**Security Summary** (required): What was audited and key findings.

**Vulnerability Counts** (required): Critical, high, medium, low counts.

**cargo-deny Status** (required): pass/fail, advisory count, license issue count.

**Dependencies Audit** (required): Outdated count, unmaintained count, list of actions needed (package, current version, latest, action).

**Unsafe Blocks** (if any present): Total, reviewed, approved, needs-refactor counts.

**Issues Found** (if any): For each — severity, location (file:line), issue description, concrete fix.

## Severity Response Times

| Level | Response | Examples |
|-------|----------|----------|
| Critical | Immediate | RCE, auth bypass |
| High | 24 hours | SQL injection, XSS |
| Medium | 1 week | Information disclosure |
| Low | Next release | Minor issues |

## Security Checklist

- `cargo deny check` passes
- No hardcoded secrets
- All `unsafe` blocks have `// SAFETY:` comment
- Input validation on all external data
- SQL uses parameterized queries
- Passwords hashed with argon2
