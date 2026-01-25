# Task Management Guide

How to work with Claude Code Task Manager for lifecycle orchestration.

## Task Structure

Each phase creates a set of interdependent tasks using TaskCreate and manages dependencies with TaskUpdate.

### Task Naming Convention

Tasks follow this pattern: `{phase}-{step}-{agent}`

Examples:
- `phase-1-plan` - Phase 1 planning by architect
- `phase-1-implement` - Phase 1 implementation by developer
- `phase-1-validate-perf` - Phase 1 performance validation
- `phase-1-review` - Phase 1 initial code review
- `phase-1-fix-issues` - Phase 1 fix ALL review issues (MANDATORY)
- `phase-1-re-review` - Phase 1 re-review after fixes
- `phase-1-commit` - Phase 1 commit (only after approved)

### Task Dependencies

```
phase-N-plan
    ↓ (blockedBy)
phase-N-implement
    ↓ (blockedBy)
phase-N-validate-* (parallel)
    ↓ (blockedBy)
phase-N-review
    ↓ (blockedBy)
phase-N-fix-issues ← MANDATORY
    ↓ (blockedBy)
phase-N-re-review
    ↓ (blockedBy)
phase-N-commit ← Only after approved
```

## Task Progress Monitoring

Check task status anytime:

```bash
# List all tasks
TaskList()

# View specific task details
TaskGet(taskId: "phase-1-implement")

# Check background agent progress
# (use TaskOutput with agent IDs from Task tool results)
```

## Error Handling

If any task fails or gets blocked:

```bash
# Mark task as blocked
TaskUpdate(
  taskId: "phase-1-implement",
  status: "pending",
  metadata: {
    blocked_reason: "Compilation errors - needs architecture revision"
  }
)

# Create unblocking task
TaskCreate(
  subject: "Fix compilation errors",
  description: "Resolve build failures before continuing phase 1",
  activeForm: "Fixing build errors"
)
```

## Multi-Phase Development

For features requiring multiple phases:

1. **Repeat** task creation for each phase (phase-2-*, phase-3-*, etc.)
2. **Chain phases**: `phase-2-plan` blockedBy `phase-1-commit`
3. **Iterate** through the same workflow
4. **Final cleanup**: After all phases complete, ask user for confirmation to run cleanup

```bash
# After final phase commit
echo ""
echo "==================================================================="
echo "All phases completed successfully!"
echo "==================================================================="
echo ""
echo "Ready for final cleanup?"
echo "This will run the project-cleanup agent to:"
echo "  - Consolidate .local/handoff documentation"
echo "  - Archive historical files"
echo "  - Prepare for session reset"
echo ""
read -p "Run cleanup now? (y/N): " CONFIRM

if [ "$CONFIRM" = "y" ] || [ "$CONFIRM" = "Y" ]; then
  Task(
    subagent_type: "project-cleanup",
    prompt: "Consolidate development artifacts and documentation",
    run_in_background: false
  )
fi
```
