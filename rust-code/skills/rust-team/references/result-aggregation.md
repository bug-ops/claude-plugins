# Result Aggregation

How to collect and consolidate team development results.

## Output Location

```
.local/team-results/{team-name}-summary.md
```

## Report Template

```markdown
# Team Development Report: {feature}

## Overview
- Team: {team-name}
- Started: {timestamp}
- Completed: {timestamp}
- Agents: {list}

## Architecture Decisions
{from architect messages/handoff}

## Implementation Summary
{from developer messages/handoff}

## Validation Results

### Testing
{from tester — coverage results, gaps}

### Performance
{from perf — benchmarks, findings}

### Security
{from security — vulnerability report, severity}

## Code Review
{from reviewer — verdict, issues list, resolution status}

## Files Changed
{aggregated from git diff --stat}
```

## Aggregation Sources

1. **Handoff YAMLs** — each agent creates a handoff file via `rust-agent-handoff` skill in `.local/handoff/`. Teamlead receives handoff paths from agents in their completion messages.
2. **SendMessage history** — messages received from teammates
3. **Task statuses** — TaskList for completion status
4. **Git diff** — `git diff --stat` for files changed

## Aggregation Steps

1. Read handoff files from `.local/handoff/` (paths received from each agent)
2. Collect messages received from each teammate
3. Check TaskList for final task statuses
4. Run `git diff --stat` against base branch
5. Merge into report template
6. Write to `.local/team-results/{team-name}-summary.md`
