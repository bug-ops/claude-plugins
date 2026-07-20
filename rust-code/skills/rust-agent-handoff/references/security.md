# rust-security-maintenance Output Schema

Summary: audit scope + critical/high counts + cargo-deny status. Example: `"Security audit: 0 critical, 1 high (SQL injection in src/auth.rs); cargo-deny pass"`

## Output Sections

**Security Summary** (required): scope + key findings.

**Counts** (required): vulnerabilities by severity (critical/high/medium/low); cargo-deny pass/fail with advisory + license issue counts.

**Issues Found** (if any): severity — file:line — issue — concrete fix, one line each.

**Dependencies** (if audited): actionable items only — package, current -> latest, action. Skip healthy deps.

**Unsafe Blocks** (if present): total / reviewed / needs-refactor counts.
