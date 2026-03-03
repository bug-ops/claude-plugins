# Lifecycle Workflow Steps

Detailed step-by-step execution guide for each phase of development.

## Step 1: Create Phase Tasks

For each phase of work, create all tasks upfront:

```bash
# Using TaskCreate for each step
# Example: Phase 1 tasks

# 1. Architecture & Planning
TaskCreate(
  subject: "Phase 1: Architecture design",
  description: "Design system architecture, type hierarchies, and module structure for $FEATURE_DESCRIPTION",
  activeForm: "Designing phase 1 architecture"
)
# Returns taskId: "phase-1-plan"

# 2. Adversarial Critique (MANDATORY)
TaskCreate(
  subject: "Phase 1: Adversarial critique",
  description: "Critique architect's design: find logical gaps, flawed assumptions, failure modes. Handoff: .local/handoff/{timestamp}-architect.yaml",
  activeForm: "Critiquing phase 1 architecture"
)
# Returns taskId: "phase-1-critique"

# 3. Implementation
TaskCreate(
  subject: "Phase 1: Implementation",
  description: "Implement phase 1 following architecture spec. Handoff: .local/handoff/{timestamp}-architect.yaml",
  activeForm: "Implementing phase 1"
)
# Returns taskId: "phase-1-implement"

# 4. Parallel validation tasks
TaskCreate(
  subject: "Phase 1: Performance analysis",
  description: "Analyze performance characteristics. Handoff: .local/handoff/{timestamp}-developer.yaml",
  activeForm: "Analyzing phase 1 performance"
)
# Returns taskId: "phase-1-validate-perf"

TaskCreate(
  subject: "Phase 1: Security audit",
  description: "Security review of phase 1. Handoff: .local/handoff/{timestamp}-developer.yaml",
  activeForm: "Auditing phase 1 security"
)
# Returns taskId: "phase-1-validate-security"

TaskCreate(
  subject: "Phase 1: Test coverage",
  description: "Ensure comprehensive test coverage. Handoff: .local/handoff/{timestamp}-developer.yaml",
  activeForm: "Adding phase 1 tests"
)
# Returns taskId: "phase-1-validate-tests"

TaskCreate(
  subject: "Phase 1: Adversarial critique of implementation",
  description: "Critique developer's implementation: find logical gaps, edge cases, and design issues introduced during coding. Handoff: .local/handoff/{timestamp}-developer.yaml",
  activeForm: "Critiquing phase 1 implementation"
)
# Returns taskId: "phase-1-validate-critique"

# 4. Code review
TaskCreate(
  subject: "Phase 1: Code review",
  description: "Initial review of phase 1. Handoffs: performance, security, testing reports",
  activeForm: "Reviewing phase 1 code"
)
# Returns taskId: "phase-1-review"

# 6. Fix ALL review issues (MANDATORY)
TaskCreate(
  subject: "Phase 1: Fix ALL review issues",
  description: "Address ALL review feedback including low-priority items. Handoff: .local/handoff/{timestamp}-review.yaml",
  activeForm: "Fixing ALL phase 1 review issues"
)
# Returns taskId: "phase-1-fix-issues"

# 7. Re-review after fixes
TaskCreate(
  subject: "Phase 1: Re-review",
  description: "Verify all review issues have been addressed. Handoff: .local/handoff/{timestamp}-developer.yaml",
  activeForm: "Re-reviewing phase 1 after fixes"
)
# Returns taskId: "phase-1-re-review"

# 8. Commit & PR (only after approved)
TaskCreate(
  subject: "Phase 1: Commit and PR",
  description: "Create commit and update PR for phase 1 (only after re-review approved)",
  activeForm: "Committing phase 1"
)
# Returns taskId: "phase-1-commit"
```

## Step 2: Set Up Dependencies

After creating all tasks, configure dependencies using TaskUpdate:

```bash
# Critique blocks on planning (MANDATORY - cannot skip)
TaskUpdate(taskId: "phase-1-critique", addBlockedBy: ["phase-1-plan"])

# Implementation blocks on critique (not on plan directly)
TaskUpdate(taskId: "phase-1-implement", addBlockedBy: ["phase-1-critique"])

# All validation tasks block on implementation
TaskUpdate(taskId: "phase-1-validate-perf", addBlockedBy: ["phase-1-implement"])
TaskUpdate(taskId: "phase-1-validate-security", addBlockedBy: ["phase-1-implement"])
TaskUpdate(taskId: "phase-1-validate-tests", addBlockedBy: ["phase-1-implement"])

# Critique of implementation blocks on implementation
TaskUpdate(taskId: "phase-1-validate-critique", addBlockedBy: ["phase-1-implement"])

# Review blocks on all validation tasks including implementation critique
TaskUpdate(
  taskId: "phase-1-review",
  addBlockedBy: [
    "phase-1-validate-perf",
    "phase-1-validate-security",
    "phase-1-validate-tests",
    "phase-1-validate-critique"
  ]
)

# Fix issues blocks on initial review
TaskUpdate(taskId: "phase-1-fix-issues", addBlockedBy: ["phase-1-review"])

# Re-review blocks on fixes
TaskUpdate(taskId: "phase-1-re-review", addBlockedBy: ["phase-1-fix-issues"])

# Commit blocks on re-review approval (not just initial review)
TaskUpdate(taskId: "phase-1-commit", addBlockedBy: ["phase-1-re-review"])
```

## Step 3: Execute Tasks in Order

### Planning Phase

Start with planning task:

```bash
# Mark planning task as in progress
TaskUpdate(taskId: "phase-1-plan", status: "in_progress")

# Launch architect agent in background
Task(
  subagent_type: "rust-agents:rust-architect",
  prompt: "Design architecture for phase 1: $FEATURE_DESCRIPTION. Create detailed plan with type hierarchies, module structure, and implementation phases.",
  run_in_background: true
)
# Agent will create handoff file: .local/handoff/{timestamp}-architect.yaml
```

### Critique Phase (MANDATORY)

When planning completes:

```bash
# Mark planning as completed
TaskUpdate(taskId: "phase-1-plan", status: "completed")

# Start critique (now unblocked)
TaskUpdate(taskId: "phase-1-critique", status: "in_progress")

# Get handoff path from architect agent output
ARCHITECT_HANDOFF=".local/handoff/2026-01-25T15-30-00-architect.yaml"

# Launch critic agent
Task(
  subagent_type: "rust-agents:rust-critic",
  prompt: "Critique architect's design for phase 1. Find logical gaps, flawed assumptions, scalability limits, and missing edge cases. Handoff: $ARCHITECT_HANDOFF",
  run_in_background: true
)
# Agent will create handoff file: .local/handoff/{timestamp}-critic.yaml
```

### Handle Critique Verdict

When critique completes:

```bash
# Read critique handoff
CRITIC_HANDOFF=".local/handoff/2026-01-25T15-45-00-critic.yaml"
VERDICT=$(grep '^  verdict:' "$CRITIC_HANDOFF" | awk '{print $2}')

if [ "$VERDICT" = "critical" ]; then
  echo "CRITICAL verdict: architect must redesign before implementation."
  # Reopen plan task — architect must address all critical gaps
  TaskUpdate(taskId: "phase-1-plan", status: "in_progress")
  Task(
    subagent_type: "rust-agents:rust-architect",
    prompt: "Redesign phase 1 architecture addressing ALL critical gaps from critique. Handoff: $CRITIC_HANDOFF",
    run_in_background: true
  )
  # After redesign, re-run critique again (repeat until verdict is approved/minor/significant)

elif [ "$VERDICT" = "significant" ]; then
  echo "SIGNIFICANT verdict: architect must address significant gaps before implementation."
  # Reopen plan task — architect must address significant gaps
  TaskUpdate(taskId: "phase-1-plan", status: "in_progress")
  Task(
    subagent_type: "rust-agents:rust-architect",
    prompt: "Update architecture for phase 1, addressing ALL significant gaps from critique. Handoff: $CRITIC_HANDOFF",
    run_in_background: true
  )
  # After architect updates, re-run critique again

elif [ "$VERDICT" = "approved" ] || [ "$VERDICT" = "minor" ]; then
  echo "Critique verdict: $VERDICT. Proceeding to implementation."
  # Mark critique as completed, implementation is now unblocked
  TaskUpdate(taskId: "phase-1-critique", status: "completed")
fi
```

### Implementation Phase

When critique is approved or minor:

```bash
# Start implementation (now unblocked)
TaskUpdate(taskId: "phase-1-implement", status: "in_progress")

# Get handoff path from architect agent output (latest after any redesign)
ARCHITECT_HANDOFF=".local/handoff/2026-01-25T15-30-00-architect.yaml"

# Launch developer agent
Task(
  subagent_type: "rust-agents:rust-developer",
  prompt: "Implement phase 1. Handoff: $ARCHITECT_HANDOFF",
  run_in_background: true
)
```

### Validation Phase (Parallel)

When implementation completes:

```bash
# Mark implementation as completed
TaskUpdate(taskId: "phase-1-implement", status: "completed")

# Get developer handoff
DEVELOPER_HANDOFF=".local/handoff/2026-01-25T16-00-00-developer.yaml"

# Start parallel validation (all now unblocked)
TaskUpdate(taskId: "phase-1-validate-perf", status: "in_progress")
TaskUpdate(taskId: "phase-1-validate-security", status: "in_progress")
TaskUpdate(taskId: "phase-1-validate-tests", status: "in_progress")

# Launch validation agents in parallel (background)
Task(
  subagent_type: "rust-agents:rust-performance-engineer",
  prompt: "Analyze performance. Handoff: $DEVELOPER_HANDOFF",
  run_in_background: true
)

Task(
  subagent_type: "rust-agents:rust-security-maintenance",
  prompt: "Security audit. Handoff: $DEVELOPER_HANDOFF",
  run_in_background: true
)

Task(
  subagent_type: "rust-agents:rust-testing-engineer",
  prompt: "Ensure test coverage. Handoff: $DEVELOPER_HANDOFF",
  run_in_background: true
)

Task(
  subagent_type: "rust-agents:rust-critic",
  prompt: "Critique developer's implementation for phase 1. Find logical gaps, missing edge cases, and design issues introduced during coding. Handoff: $DEVELOPER_HANDOFF",
  run_in_background: true
)
```

### Initial Review

When all validation completes:

```bash
# Mark validation tasks as completed
TaskUpdate(taskId: "phase-1-validate-perf", status: "completed")
TaskUpdate(taskId: "phase-1-validate-security", status: "completed")
TaskUpdate(taskId: "phase-1-validate-tests", status: "completed")
TaskUpdate(taskId: "phase-1-validate-critique", status: "completed")

# Collect all handoff files
PERF_HANDOFF=".local/handoff/2026-01-25T16-15-00-performance.yaml"
SECURITY_HANDOFF=".local/handoff/2026-01-25T16-15-30-security.yaml"
TESTING_HANDOFF=".local/handoff/2026-01-25T16-16-00-testing.yaml"
CRITIQUE_HANDOFF=".local/handoff/2026-01-25T16-16-30-critic.yaml"

# Start review
TaskUpdate(taskId: "phase-1-review", status: "in_progress")

Task(
  subagent_type: "rust-agents:rust-code-reviewer",
  prompt: "Review phase 1. Handoffs: $PERF_HANDOFF, $SECURITY_HANDOFF, $TESTING_HANDOFF, $CRITIQUE_HANDOFF",
  run_in_background: true
)
```

## Step 4: Fix ALL Review Issues (MANDATORY)

> [!IMPORTANT]
> This step is MANDATORY. ALL review issues must be fixed, even low-priority ones, before proceeding to commit.

### Apply Fixes

When initial review completes:

```bash
# Mark review as completed
TaskUpdate(taskId: "phase-1-review", status: "completed")

# Read review handoff
REVIEW_HANDOFF=".local/handoff/2026-01-25T16-30-00-review.yaml"
cat "$REVIEW_HANDOFF"

# Start fix-issues task (now unblocked)
TaskUpdate(taskId: "phase-1-fix-issues", status: "in_progress")

# Launch developer to fix ALL issues
echo "🔧 Fixing ALL review issues (including low-priority)..."
Task(
  subagent_type: "rust-agents:rust-developer",
  prompt: "Fix ALL review issues from review handoff. Address EVERY item including low-priority suggestions. Handoff: $REVIEW_HANDOFF",
  run_in_background: true
)
```

### Re-Review After Fixes

When fixes complete:

```bash
# Mark fix-issues as completed
TaskUpdate(taskId: "phase-1-fix-issues", status: "completed")

# Get updated developer handoff
FIXES_HANDOFF=".local/handoff/2026-01-25T17-00-00-developer.yaml"

# Start re-review task (now unblocked)
TaskUpdate(taskId: "phase-1-re-review", status: "in_progress")

echo "🔍 Re-reviewing after fixes..."
Task(
  subagent_type: "rust-agents:rust-code-reviewer",
  prompt: "Verify ALL review issues have been addressed. Compare: $REVIEW_HANDOFF (original review) and $FIXES_HANDOFF (fixes). Ensure no issues remain.",
  run_in_background: true
)
```

### Handle Re-Review Result

When re-review completes:

```bash
# Read re-review handoff
RE_REVIEW_HANDOFF=".local/handoff/2026-01-25T17-15-00-review.yaml"
cat "$RE_REVIEW_HANDOFF"

# Check re-review status
RE_REVIEW_STATUS=$(grep '^  status:' "$RE_REVIEW_HANDOFF" | awk '{print $2}')

if [ "$RE_REVIEW_STATUS" = "changes_requested" ]; then
  echo "⚠️  Re-review found remaining issues. Repeat fix cycle..."

  # Repeat: mark fix-issues as pending, update with new handoff, fix again
  # Continue until approved

elif [ "$RE_REVIEW_STATUS" = "approved" ]; then
  echo "✅ Re-review approved! All issues resolved."

  # Mark re-review as completed
  TaskUpdate(taskId: "phase-1-re-review", status: "completed")

  # Proceed to commit (now unblocked)
fi
```

## Step 5: Commit and PR

> [!NOTE]
> Commits are created ONLY after re-review approval. This ensures all issues have been addressed.

When re-review is approved:

```bash
# Start commit task
TaskUpdate(taskId: "phase-1-commit", status: "in_progress")

# Create commit
git add .
git commit -m "Phase 1: $FEATURE_DESCRIPTION

- Architecture designed by rust-architect
- Implementation completed by rust-developer
- Validated: performance, security, tests
- Reviewed and approved

Handoff: $RE_REVIEW_HANDOFF"

# Update or create PR
if gh pr view &>/dev/null; then
  echo "Updating existing PR..."
  git push
else
  echo "Creating new PR..."
  gh pr create --title "Feature: $FEATURE_DESCRIPTION" --body "$(cat <<'EOF'
## Summary
Multi-phase Rust development

## Phase 1 Completed
- Architecture design ✓
- Implementation ✓
- Performance validation ✓
- Security audit ✓
- Test coverage ✓
- Code review approved ✓

## Handoff Files
See `.local/handoff/` for detailed phase reports
EOF
)"
fi

# Mark commit task as completed
TaskUpdate(taskId: "phase-1-commit", status: "completed")

echo "✓ Phase 1 complete. Commit created and PR updated."
```
