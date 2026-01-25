# rust-testing-engineer Output Schema

```yaml
output:
  summary: "Testing work completed"
  
  tests_added:
    unit: 12
    integration: 3
    property: 2
  
  coverage:
    before: "45%"
    after: "78%"
    target: "80%"
  
  test_results:
    total: 47
    passed: 47
    failed: 0
    skipped: 0
  
  test_files:
    - path: src/email.rs
      tests: ["test_valid_email", "test_invalid_email"]
    - path: tests/integration/user_flow.rs
      tests: ["test_user_creation_flow"]
  
  gaps:
    - "Error handling paths need more coverage"
```

## Field Descriptions

| Field | Required | Description |
|-------|----------|-------------|
| `summary` | yes | Brief description of testing work |
| `tests_added` | yes | Count of tests by category |
| `coverage` | yes | Coverage before/after/target |
| `test_results` | yes | Test execution results |
| `test_files` | yes | Files with test names |
| `gaps` | no | Identified coverage gaps |

## Coverage Targets

| Category | Target |
|----------|--------|
| Critical paths | 80%+ |
| Business logic | 70%+ |
| Overall | 60%+ |

## Test Naming Convention

`test_{function}_{scenario}`

Examples:
- `test_email_parse_valid`
- `test_email_parse_missing_at`
- `test_user_builder_missing_required`

## Multiple Parent Sources Example

When receiving context from both architecture and implementation:

```yaml
id: 2025-01-09T16-00-00-testing
parent:
  - 2025-01-09T14-30-45-architect  # Architecture spec
  - 2025-01-09T15-30-00-developer  # Implementation
agent: testing
```

Use this when:
- Testing requires both design intent (architect) and implementation details (developer)
- Merging test strategy (from one testing handoff) with new implementation (from developer)
- Parallel work streams converge (e.g., API implementation + test infrastructure)
