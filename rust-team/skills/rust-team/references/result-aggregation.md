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

1. **SendMessage history** — primary channel, messages received from teammates
2. **Handoff YAMLs** — if agents used rust-agent-handoff skill (`.local/handoff/`)
3. **Task statuses** — TaskList for completion status
4. **Git diff** — `git diff --stat` for files changed

## Aggregation Steps

1. Collect messages received from each teammate
2. Read handoff files if present in `.local/handoff/`
3. Check TaskList for final task statuses
4. Run `git diff --stat` against base branch
5. Merge into report template
6. Write to `.local/team-results/{team-name}-summary.md`
