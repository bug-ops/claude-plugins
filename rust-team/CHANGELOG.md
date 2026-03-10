# Changelog

## [0.2.8] - 2026-03-10

### Changed
- `rust-teamlead`: downgraded model from `opus` to `sonnet` — orchestration follows a fixed protocol and does not require deep reasoning

## [0.2.7] - 2026-03-09

### Fixed
- Add missing team tools to rust-teamlead frontmatter (`Agent`, `TeamCreate`, `TeamDelete`, `TaskCreate`, `TaskUpdate`, `TaskList`, `TaskGet`, `SendMessage`) — without explicit listing the agent lacked proper schema access and invented wrong parameter names
- Replace pseudocode `TeamCreate(team_name: "...")` with explicit JSON showing exact parameter name `team_name`; add warning against using `name` or `agents` parameters to prevent `InputValidationError`

## [0.2.6] - 2026-03-07

### Fixed
- Replace `Task(...)` with correct `Agent(...)` tool syntax in team-workflow.md spawn examples
- Add mandatory `description` parameter to all Agent spawn templates
- Add explicit tool syntax section to teamlead agent with required parameters
- Warn against using `general` subagent_type (correct name: `general-purpose`)
- Add missing `summary` field to SendMessage examples in fix-review cycle
- Add missing `content` field to shutdown_request SendMessage example

## [0.2.5] - 2026-03-04

### Changed
- `rust-critic` now runs a second time in the parallel validation phase after implementation,
  as `impl-critic` agent alongside tester, perf, and security
- Added `validate-critique` task with dependency on `implement`, blocking `review`
- Architecture critique (Step 2.5) promoted from optional to mandatory — skip only for trivial single-file bug fixes
- `rust-code-reviewer` now receives both critic handoffs (architecture + implementation) for full context
- Updated task structure tables, dependency setup, and workflow diagrams in `SKILL.md` and `team-workflow.md`

## [0.2.4] - 2026-03-02

### Changed
- Teamlead now rebases feature branch on origin/main before push, resolving any conflicts before creating PR

## [0.2.2] - 2026-02-09

### Fixed
- Add explicit /rust-agent-handoff instruction to all agent spawn prompts (agents do not invoke handoff protocol automatically)
- Teamlead now runs /rust-agent-handoff to read handoff files from agents
- Added rust-agent-handoff skill to teamlead frontmatter

## [0.2.1] - 2026-02-09

### Changed
- Enforce strict sequential execution: teamlead must WAIT for handoff file path before spawning next agent
- Fix-review cycle now explicitly routes all handoffs through teamlead (reviewer handoff → teamlead → developer → developer handoff → teamlead → reviewer)
- Workflow diagrams and templates rewritten with explicit WAIT gates at each step
- Task completion gated on handoff receipt: do not mark task completed until handoff path received

## [0.2.0] - 2026-02-09

### Added
- Explicit handoff chain protocol: teamlead accumulates all handoff file paths and passes full list to each subsequent agent
- Code ownership rules: only developer modifies code, only teamlead commits
- Handoff protocol section in team communication template for spawn prompts

### Changed
- Communication matrix updated with handoff file paths in agent-to-teamlead messages
- Validators and reviewer receive accumulated handoff paths from all preceding agents
- Handoff files promoted to primary aggregation source

## [0.1.0] - 2026-02-08

### Added
- Initial release of rust-team plugin
- rust-teamlead agent for team orchestration (model: opus)
- rust-team skill with workflow, communication protocol, and result aggregation references
- Teammate registry mapping 8 rust-agents specialists
- Support for 4 workflow templates: new feature, bug fix, refactoring, security audit
- Full agent-to-agent communication matrix with primary and cross-consultation flows
- Team communication template for agent spawn prompts
- Result aggregation to `.local/team-results/`
