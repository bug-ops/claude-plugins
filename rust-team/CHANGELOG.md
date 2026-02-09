# Changelog

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
