# Best Practices and Examples

Guidelines for effective lifecycle orchestration and practical usage examples.

## Best Practices

1. **Create all tasks upfront** - Full visibility into workflow
2. **Use background execution** - All agents run concurrently when unblocked
3. **Pass handoff files** - Every agent receives context from predecessors
4. **Fix ALL review issues (MANDATORY)** - This is non-negotiable. Every review comment, even low-priority suggestions, must be addressed before commit. No exceptions.
5. **Always re-review after fixes** - Verify all issues were properly addressed
6. **Commit only after re-review approval** - Never bypass the fix → re-review cycle
7. **Commit after each phase** - Incremental progress
8. **Update PR continuously** - Keep reviewers informed

## Usage Examples

### Single Feature Development

```
/rust-lifecycle Implement user authentication with JWT tokens
```

This creates a single-phase workflow:
- Architecture design
- Implementation
- Parallel validation (performance, security, testing)
- Code review → fixes → re-review
- Commit and PR

### Multi-Phase Complex Feature

```
/rust-lifecycle Build real-time collaboration system:
- Phase 1: WebSocket infrastructure
- Phase 2: Message queue and persistence
- Phase 3: Conflict resolution
- Phase 4: Frontend integration
```

Each phase goes through the complete workflow before moving to the next:
- Phase 1: WebSocket infrastructure (architecture → implementation → validation → review → fixes → commit)
- Phase 2: Message queue (starts after Phase 1 commit)
- Phase 3: Conflict resolution (starts after Phase 2 commit)
- Phase 4: Frontend integration (starts after Phase 3 commit)

### Bug Fix with Validation

```
/rust-lifecycle Fix memory leak in connection pool:
- Phase 1: Diagnosis and fix
- Phase 2: Performance validation and testing
```

Simpler workflow focused on fixing and validating:
- Phase 1: Developer diagnoses issue and implements fix
- Validation runs to ensure no regressions
- Review ensures fix is correct
- Phase 2: Extended performance testing to verify leak is resolved

## Integration with Handoff Protocol

All agents use the rust-agent-handoff skill automatically. Each agent:

1. Reads handoff file path from task description
2. Executes work following handoff protocol
3. Writes new handoff file
4. Returns handoff path in response

Parent orchestrator (this skill) extracts handoff paths and passes them to next agent in chain.

### Handoff File Chain Example

```
Architect creates:
  .local/handoff/2026-01-25T15-30-00-architect.yaml

Developer reads architect handoff, creates:
  .local/handoff/2026-01-25T16-00-00-developer.yaml

Performance engineer reads developer handoff, creates:
  .local/handoff/2026-01-25T16-15-00-performance.yaml

Security engineer reads developer handoff, creates:
  .local/handoff/2026-01-25T16-15-30-security.yaml

Testing engineer reads developer handoff, creates:
  .local/handoff/2026-01-25T16-16-00-testing.yaml

Code reviewer reads all validation handoffs, creates:
  .local/handoff/2026-01-25T16-30-00-review.yaml

Developer reads review handoff, creates fixes:
  .local/handoff/2026-01-25T17-00-00-developer.yaml

Code reviewer re-reviews, creates:
  .local/handoff/2026-01-25T17-15-00-review.yaml
  (status: approved)

Commit created with final handoff reference
```

## Exit Criteria

Lifecycle completes when:
- ✅ All phase tasks marked `completed`
- ✅ Final PR updated
- ✅ Optional cleanup executed (with user confirmation)

Returns summary of:
- Phases completed
- Commits created
- PR URL
- Handoff files location

## Common Patterns

### Pattern 1: Quick Single-Phase Feature

For simple features that don't need multiple phases:

```
/rust-lifecycle Add rate limiting middleware
```

Single iteration through the full workflow.

### Pattern 2: Incremental Multi-Phase

For complex features, break into logical phases:

```
/rust-lifecycle Implement OAuth2 authentication:
- Phase 1: Core OAuth2 flow and token management
- Phase 2: Provider integrations (Google, GitHub)
- Phase 3: Session management and refresh tokens
- Phase 4: Admin UI for OAuth app management
```

Each phase is independently tested and committed.

### Pattern 3: Fix-Validate Pattern

When fixing critical issues:

```
/rust-lifecycle Fix SQL injection vulnerability in user search:
- Phase 1: Patch the vulnerability with parameterized queries
- Phase 2: Add comprehensive security tests
```

Focused on fixing and validating, with extra emphasis on security validation.

### Pattern 4: Refactoring with Safety

Large refactorings benefit from the validation pipeline:

```
/rust-lifecycle Refactor database layer to async:
- Phase 1: Convert repository traits to async
- Phase 2: Update database implementations
- Phase 3: Migrate service layer
- Phase 4: Update integration tests
```

Each phase validated for performance, security, and test coverage before proceeding.
