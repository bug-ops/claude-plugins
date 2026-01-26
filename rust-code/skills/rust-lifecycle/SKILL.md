---
name: rust-lifecycle
description: Orchestrate complete Rust project development lifecycle with multi-phase workflow, parallel validation, and code review. Use when starting new features, implementing complex changes, or managing multi-phase development.
---

# Rust Development Lifecycle Orchestration

Complete development workflow orchestrator for Rust projects. Manages multi-phase development with architecture design, implementation, parallel validation, code review, and automated PR management.

## Workflow Overview

```
Phase Planning (Architect)
    ↓
Phase Implementation (Developer)
    ↓
Parallel Validation
├── Performance Analysis
├── Security Audit
└── Test Coverage
    ↓
Code Review
    ↓
Fix ALL Issues (Developer) ← MANDATORY
    ↓
Re-Review (Code Reviewer)
    ↓
Commit + PR Update ← Only after approved
    ↓
Next Phase or Completion
```

> [!IMPORTANT]
> After code review, ALL issues must be fixed (even low-priority ones) before committing.
> This is a mandatory step - no commits without addressing all feedback.

## Prerequisites Check

Before starting the lifecycle, verify:

1. **Git branch**: If on `main`/`master`, create a feature branch
2. **Working directory clean**: No uncommitted changes (or commit them first)
3. **Project type**: Rust project with `Cargo.toml`

```bash
# Check current branch
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [ "$CURRENT_BRANCH" = "main" ] || [ "$CURRENT_BRANCH" = "master" ]; then
  echo "⚠️  Currently on $CURRENT_BRANCH. Creating feature branch..."
  # Branch name from task or timestamp
  BRANCH_NAME="feature/$(date +%Y%m%d-%H%M%S)"
  git checkout -b "$BRANCH_NAME"
  echo "✓ Created and switched to $BRANCH_NAME"
fi

# Verify Rust project
if [ ! -f "Cargo.toml" ]; then
  echo "❌ Not a Rust project (Cargo.toml not found)"
  exit 1
fi

echo "✓ Prerequisites check passed"
```

## Quick Start

### Single Feature Development

```
/rust-lifecycle Implement user authentication with JWT tokens
```

### Multi-Phase Complex Feature

```
/rust-lifecycle Build real-time collaboration system:
- Phase 1: WebSocket infrastructure
- Phase 2: Message queue and persistence
- Phase 3: Conflict resolution
- Phase 4: Frontend integration
```

### Bug Fix with Validation

```
/rust-lifecycle Fix memory leak in connection pool:
- Phase 1: Diagnosis and fix
- Phase 2: Performance validation and testing
```

## Detailed Documentation

For step-by-step instructions and detailed guidance, see the reference files:

### [Workflow Steps](references/workflow-steps.md)

Complete execution guide for each phase:
- **Step 1**: Create Phase Tasks - TaskCreate examples for all workflow steps
- **Step 2**: Set Up Dependencies - TaskUpdate configuration for task dependencies
- **Step 3**: Execute Tasks in Order - Planning, implementation, validation, and review
- **Step 4**: Fix ALL Review Issues - Mandatory fix cycle with re-review
- **Step 5**: Commit and PR - Final commit creation and PR update

Read this for detailed bash commands and agent invocation patterns.

### [Task Management](references/task-management.md)

Task Manager usage and monitoring:
- Task structure and naming conventions
- Task dependencies and blocking relationships
- Progress monitoring with TaskList, TaskGet, TaskOutput
- Error handling and recovery
- Multi-phase task chaining

Read this for Task Manager API usage and troubleshooting.

### [Best Practices & Examples](references/best-practices.md)

Guidelines and practical examples:
- Best practices for lifecycle orchestration
- Usage examples for different scenarios
- Handoff protocol integration patterns
- Exit criteria and completion workflows
- Common patterns (single-phase, multi-phase, fix-validate, refactoring)

Read this for strategic guidance and real-world usage patterns.

## Task Structure Overview

Each phase creates these tasks with dependencies:

| Task | Blocks | Description |
|------|--------|-------------|
| `phase-N-plan` | - | Architecture design by rust-architect |
| `phase-N-implement` | plan | Implementation by rust-developer |
| `phase-N-validate-*` | implement | Parallel validation (perf, security, tests) |
| `phase-N-review` | validate-* | Initial code review |
| `phase-N-fix-issues` | review | **Fix ALL issues (MANDATORY)** |
| `phase-N-re-review` | fix-issues | Verify all issues resolved |
| `phase-N-commit` | re-review | Commit and PR update |

## Key Features

✅ **Task-based orchestration** - Full visibility into workflow with Claude Code Task Manager
✅ **Parallel validation** - Performance, security, and testing run concurrently
✅ **Mandatory review fixes** - ALL issues must be addressed before commit
✅ **Handoff protocol** - Context sharing between agents via YAML files
✅ **Background execution** - All agents run in background, unblocked automatically
✅ **Multi-phase support** - Chain multiple phases for complex features
✅ **Automated PR management** - Creates and updates PRs after each phase

## Integration with Rust Agents

This skill orchestrates all rust-agents plugin agents:

- **rust-architect** - Architecture design and planning
- **rust-developer** - Implementation and fixes
- **rust-performance-engineer** - Performance validation
- **rust-security-maintenance** - Security audit
- **rust-testing-engineer** - Test coverage verification
- **rust-code-reviewer** - Code review and re-review

All agents use the `rust-agent-handoff` skill for context sharing.

## Exit Criteria

Lifecycle completes when:
- ✅ All phase tasks marked `completed`
- ✅ Final PR updated with all commits
- ✅ Optional cleanup executed (with user confirmation)

Returns summary with:
- Phases completed count
- Commits created
- PR URL
- Handoff files location (`.local/handoff/`)

## Next Steps

1. **Run the skill** with your feature description
2. **Monitor progress** with TaskList as agents execute
3. **Review handoff files** in `.local/handoff/` for detailed reports
4. **Iterate phases** - each phase builds on previous work
5. **Run cleanup** when all phases complete (optional, requires confirmation)

For detailed execution instructions, start with [Workflow Steps](references/workflow-steps.md).
