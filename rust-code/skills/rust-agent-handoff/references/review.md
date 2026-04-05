# rust-code-reviewer Output Schema

## Summary Field (frontmatter)

One sentence covering: verdict + issue counts + key finding.

Example: `"Changes requested: 1 critical (SQL injection in src/auth.rs:42), 2 important issues"`

## Output Sections

**Review Status** (required): `approved` | `changes_requested`

**Review Summary** (required): Overall assessment of the code quality and key findings.

**Files Reviewed** (required): For each file — path and verdict (`approved` | `needs_changes`).

**Critical Issues** (if any): Must fix before merge. For each — file:line, issue, concrete fix.

**Important Issues** (if any): Should fix. For each — file:line, issue, suggested fix.

**Suggestions** (if any): Nice to have. For each — file:line, suggestion.

**Positives** (encouraged): Specific good things worth acknowledging.

## Issue Priority

| Priority | Blocks merge? |
|----------|--------------|
| Critical — security, data loss, logic errors | Yes |
| Important — missing tests, bad error handling | Request changes |
| Suggestion — style, minor optimizations | No |

## Approval Criteria

Approve when: no critical issues, logic is correct, tests pass, important issues addressed or acknowledged.

Do NOT block on: nitpicks, personal style preferences, non-blocking suggestions.
