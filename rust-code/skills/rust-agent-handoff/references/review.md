# rust-code-reviewer Output Schema

```yaml
output:
  review_status: approved  # approved | changes_requested
  summary: "Review summary"
  
  files_reviewed:
    - path: src/user.rs
      verdict: approved
    - path: src/auth.rs
      verdict: needs_changes
  
  critical_issues:
    - id: 1
      file: src/auth.rs
      line: 42
      issue: "SQL injection vulnerability"
      fix: "Use sqlx::query! macro"
  
  important_issues:
    - id: 2
      file: src/user.rs
      line: 15
      issue: "Missing error context"
      fix: "Add .context() to Result"
  
  suggestions:
    - id: 3
      file: src/email.rs
      line: 8
      suggestion: "Consider using Cow<str>"
  
  positive:
    - "Excellent use of newtype pattern"
    - "Good test coverage"
```

## Field Descriptions

| Field | Required | Description |
|-------|----------|-------------|
| `review_status` | yes | Overall review decision |
| `summary` | yes | Brief review summary |
| `files_reviewed` | yes | List of reviewed files |
| `critical_issues` | if any | Must fix before merge |
| `important_issues` | if any | Should fix |
| `suggestions` | if any | Nice to have |
| `positive` | encouraged | Good things to acknowledge |

## Issue Priority

| Priority | Description | Blocks Merge? |
|----------|-------------|---------------|
| `critical` | Security, data loss, logic errors | Yes |
| `important` | Missing tests, bad error handling | Request changes |
| `suggestion` | Style, minor optimizations | No |
| `nitpick` | Formatting preferences | No |

## Approval Criteria

Approve when:
- No critical issues
- Logic is correct
- Important issues addressed or acknowledged
- Tests pass
- Meets quality bar

Do NOT block on:
- Nitpicks
- Personal style preferences
- Non-blocking suggestions

## Multiple Parent Sources Example

When reviewing code that involved multiple work streams:

```yaml
id: 2025-01-09T17-00-00-review
parent:
  - 2025-01-09T14-30-45-architect  # Original design spec
  - 2025-01-09T15-30-00-developer  # Implementation
  - 2025-01-09T16-00-00-testing    # Tests added
agent: review
```

Use this when:
- Reviewing implementation against architecture spec + tests
- Re-review after multiple parallel fixes (from different developers)
- Security review needs both implementation and test context
- Validating that implementation meets design intent and has proper test coverage
