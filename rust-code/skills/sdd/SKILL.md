---
name: sdd
description: "Spec-Driven Development workflow. Use when the user wants to create a specification, write requirements, design a feature, plan implementation, break work into tasks, or review spec quality. Also trigger when the user says 'I want to build X', 'let's spec this out', 'create a spec', 'write requirements', or asks to prepare work for a coding agent."
effort: medium
---

# Spec-Driven Development

Help users compose structured specifications that AI coding agents can reliably
execute. The core principle: **the quality of AI-generated code is directly
proportional to the quality of the specification.**

## How to Use

This skill accepts a phase argument via `$ARGUMENTS`:

- `/sdd init` — bootstrap SDD structure in the project
- `/sdd specify <description>` — create a specification (Phase 1)
- `/sdd plan [feature-dir]` — create a technical plan (Phase 2)
- `/sdd tasks [feature-dir]` — break into implementation tasks (Phase 3)
- `/sdd review [feature-dir]` — validate spec quality
- `/sdd` (no args) — ask the user what they need

Parse the first word of `$ARGUMENTS` to determine the phase. Everything after
the phase keyword is the feature description or path.

## Operating Mode

You are an **interactive dialog partner**, not a template filler.

1. Ask focused questions to understand intent
2. Build the spec incrementally, section by section
3. Surface edge cases and unstated assumptions
4. Get confirmation before moving to the next phase
5. Mark anything unclear with `[NEEDS CLARIFICATION: ...]`
6. Respond in the same language the user writes in

## File Layout

All spec artifacts live under `.local/specs/`:

```
.local/specs/
├── constitution.md          (project principles, created by init)
├── 001-feature-name/
│   ├── spec.md              (Phase 1 output)
│   ├── plan.md              (Phase 2 output)
│   └── tasks.md             (Phase 3 output)
└── 002-another-feature/
    └── ...
```

Templates are embedded in this skill (see **Templates** section below).
Read the relevant template before generating any artifact.

---

## Phase: init

Bootstrap SDD in the current project.

1. Check if `.local/specs/` exists. If yes, report state and ask what to do.
2. Create `.local/specs/` directory.
3. Scan the project to detect language, framework, test framework, patterns.
4. Guide the user through creating `.local/specs/constitution.md`:
   - Use the **Constitution Template** below for structure
   - Pre-fill with detected values
   - Ask the user to confirm and customize each section
5. Report what was created. Suggest: "Run `/sdd specify <description>` to create
   your first spec."

---

## Phase 1: specify

Create a feature specification. Focus on WHAT and WHY — no implementation.

**Steps:**

1. Read `.local/specs/constitution.md` if it exists.
2. Use the **Spec Template** below for structure.
3. Ask 2-3 clarifying questions before writing anything.
   Focus on: target users, success criteria, integration points, constraints.
4. Determine the next feature number by scanning `.local/specs/` directories.
5. Build the spec through interactive dialog. Cover:
   - User stories (AS A... I WANT... SO THAT...)
   - Functional requirements in EARS notation:
     ```
     WHEN <condition> THE SYSTEM SHALL <behavior>
     ```
   - Acceptance criteria in Given/When/Then
   - Non-functional requirements (performance, security, accessibility)
   - Edge cases and error handling
   - Agent boundaries (always / ask first / never)
   - Success criteria with measurable metrics
6. Mark all ambiguities: `[NEEDS CLARIFICATION: specific question]`
7. Save to `.local/specs/<NNN>-<feature-name>/spec.md`
8. Run the quality checklist (see below).
9. Suggest: "Ready for `/sdd plan` to create the technical plan?"

---

## Phase 2: plan

Create a technical plan. Focus on HOW.

**Steps:**

1. Read the feature's `spec.md`. If no feature specified, use the most recent.
2. Read `.local/specs/constitution.md` if it exists.
3. Use the **Plan Template** below for structure.
4. Verify no unresolved `[NEEDS CLARIFICATION]` markers. Resolve with user first.
5. Scan the codebase to understand existing architecture, stack, and patterns.
6. Discuss key technical decisions with the user:
   - Architecture approach
   - Data model changes
   - API design (if applicable)
   - Testing strategy
7. Save to `.local/specs/<feature>/plan.md`
8. Suggest: "Ready for `/sdd tasks` to break this into implementation tasks?"

---

## Phase 3: tasks

Break the plan into discrete implementation tasks.

**Steps:**

1. Read both `spec.md` and `plan.md` for the feature.
2. Read `.local/specs/constitution.md` if it exists.
3. Use the **Tasks Template** below for structure.
4. Create ordered tasks. Each task must be:
   - **Small** — one logical unit, roughly one agent session
   - **Testable** — acceptance criteria as checkboxes
   - **Ordered** — explicit dependencies
   - **Self-contained** — enough context to implement alone

   Task format:
   ```markdown
   ### T001: <title>

   **Context**: Why this task exists
   **Spec reference**: FR-XXX / US-XXX
   **Acceptance criteria**:
   - [ ] <criterion>
   - [ ] <criterion>
   **Dependencies**: none | T000
   **Files**: <paths>
   **Complexity**: low | medium | high
   ```

5. Include T000 for scaffolding/setup if needed.
6. Present tasks for review. Ask:
   - "Does the ordering make sense?"
   - "Any tasks too large to split?"
7. Save to `.local/specs/<feature>/tasks.md`
8. Suggest: "Spec complete. Start implementing with:
   `Implement T001 from .local/specs/<feature>/tasks.md following the spec and plan.`"

---

## Phase: review

Validate specification quality.

1. Read all artifacts for the feature (spec.md, plan.md, tasks.md).
2. Read `.local/specs/constitution.md` if it exists.
3. Run quality checklist:

   **Completeness:**
   - [ ] Every user story has acceptance criteria
   - [ ] No unresolved `[NEEDS CLARIFICATION]` markers
   - [ ] Edge cases documented
   - [ ] Non-functional requirements specified
   - [ ] Agent boundaries defined

   **Clarity:**
   - [ ] Requirements use structured format (EARS / Given-When-Then)
   - [ ] No vague language ("should", "might", "appropriate")
   - [ ] Success criteria are measurable

   **Consistency:**
   - [ ] No contradictions between sections
   - [ ] Plan covers all spec requirements
   - [ ] Tasks cover all plan components
   - [ ] Complies with constitution

   **Implementability:**
   - [ ] Self-contained — agent with no context could execute
   - [ ] Tasks ordered by dependency
   - [ ] Each task fits one agent session

4. Report as:
   ```markdown
   ## Spec Review: <feature>
   ### Score: X/10
   ### Strengths
   ### Issues Found
   ### Recommended Actions
   ```
5. Offer to fix issues interactively.

---

## Scaling Depth

Match spec depth to task complexity. Not everything needs the full workflow.

| Size | Approach |
|------|----------|
| Typo / one-liner | No spec needed |
| Small bug / single function | 3-5 sentences + acceptance criteria |
| Feature (1-3 files) | Phase 1 only |
| Multi-component feature | Phase 1 + 2 + 3 |
| New system / architecture | Full workflow with constitution |

## Anti-Patterns to Detect

- **Vague requirements** → Ask for specifics, add examples
- **Implementation in spec** → "Let's capture what, not how, first"
- **Missing edge cases** → "What if this input is empty/huge/concurrent?"
- **Wall of text** → Break into structured sections
- **Assumed context** → "The coding agent won't know that — let's document it"
- **Over-specification** → Keep under 200 instructions to avoid compliance decay

## Three-Tier Boundary System

Every spec must define agent boundaries:

```markdown
### Always (without asking)
- Run tests after changes
- Follow existing code style

### Ask First
- Adding new dependencies
- Changing database schema

### Never
- Commit secrets or credentials
- Delete user data without backup
```

Ask: "Are there things the agent should absolutely never touch?"

---

## Templates

### Constitution Template

```markdown
# Project Constitution

> Non-negotiable principles governing ALL development in this project.
> Every specification, plan, and task MUST comply with this document.
> Update this file only through explicit team decision.

## I. Architecture

[Define your architectural patterns and constraints]

- Example: "Modular monolith with clear module boundaries"
- Example: "All modules communicate through public API only, no direct DB access"

## II. Technology Stack

[Lock down the core stack to prevent drift]

- Language: [e.g., Rust 1.80+]
- Framework: [e.g., Axum]
- Database: [e.g., PostgreSQL 16]
- Additional: [libraries, tools]

## III. Testing (NON-NEGOTIABLE)

[Define minimum testing standards]

- All features must have tests that pass before merge
- Prefer integration tests with real dependencies over mocks
- Coverage target: [e.g., > 80% for new code]
- Framework: [e.g., cargo test + nextest]

## IV. Code Style

[Reference existing conventions or define them]

- Follow existing patterns in the codebase
- [e.g., No unwrap() in production code — use proper error handling]
- [e.g., All public APIs must have doc comments]

## V. Security

- Never commit secrets, keys, or credentials
- All user input must be validated and sanitized
- [Additional security requirements]

## VI. Performance

- [e.g., API endpoints must respond within 200ms at p95]
- [e.g., Memory usage must stay under X for the main process]

## VII. Simplicity

- Prefer standard library and framework features over third-party alternatives
- New dependencies require justification
- Maximum [N] external dependencies per module

## VIII. Git Workflow

- Branch naming: [e.g., feat/<NNN>-<name>, fix/<NNN>-<name>]
- Commit messages: [e.g., conventional commits]
- One logical change per commit
```

---

### Spec Template

```markdown
# Feature: [Name]

> **Status**: Draft | In Review | Approved
> **Author**: [name]
> **Date**: [YYYY-MM-DD]
> **Branch**: [branch-name]

## 1. Overview

### Problem Statement
[What problem does this solve? Why does it matter?]

### Goal
[One sentence: what will be true when this is done?]

### Out of Scope
[Explicitly list what this feature does NOT include]

## 2. User Stories

### US-001: [Title]
AS A [role]
I WANT [capability]
SO THAT [benefit]

**Acceptance criteria:**
```
GIVEN [precondition]
WHEN [action]
THEN [expected result]
```

### US-002: [Title]
...

## 3. Functional Requirements

Use EARS notation. Prefix with FR-NNN.

| ID | Requirement | Priority |
|----|------------|----------|
| FR-001 | WHEN [condition] THE SYSTEM SHALL [behavior] | must |
| FR-002 | ... | should |

## 4. Non-Functional Requirements

| ID | Category | Requirement |
|----|----------|-------------|
| NFR-001 | Performance | [e.g., Response time < 200ms at p95] |
| NFR-002 | Security | [e.g., All inputs sanitized, auth required] |
| NFR-003 | Accessibility | [e.g., WCAG 2.1 AA compliance] |

## 5. Data Model

[Entity descriptions. Key attributes and relationships. No implementation details — describe WHAT data exists, not HOW it's stored.]

| Entity | Description | Key Attributes |
|--------|-------------|----------------|
| [Name] | [What it represents] | [Important fields] |

## 6. Edge Cases and Error Handling

| Scenario | Expected Behavior |
|----------|-------------------|
| [Input is empty] | [System responds with...] |
| [Concurrent access] | [System handles by...] |
| [External service unavailable] | [System degrades to...] |

## 7. Success Criteria

Measurable metrics that prove the feature works:

| ID | Metric | Target |
|----|--------|--------|
| SC-001 | [e.g., Task completion rate] | [e.g., > 95%] |
| SC-002 | [e.g., Error rate] | [e.g., < 0.1%] |

## 8. Agent Boundaries

### Always (without asking)
- [e.g., Run tests after changes]
- [e.g., Follow existing code patterns]

### Ask First
- [e.g., Adding new dependencies]
- [e.g., Changing public API]

### Never
- [e.g., Commit secrets]
- [e.g., Modify unrelated code]

## 9. Open Questions

- [NEEDS CLARIFICATION: ...]

## 10. References

- [Links to related specs, docs, designs, discussions]
```

---

### Plan Template

```markdown
# Technical Plan: [Feature Name]

> **Spec**: [link to spec.md]
> **Date**: [YYYY-MM-DD]
> **Status**: Draft | Approved

## 1. Architecture

### Approach
[High-level description of the technical approach. Why this approach over alternatives?]

### Component Diagram
```
[ASCII or Mermaid diagram of how components interact]
```

### Key Design Decisions

| Decision | Choice | Rationale | Alternatives Considered |
|----------|--------|-----------|------------------------|
| [e.g., Storage] | [e.g., PostgreSQL] | [why] | [what else was considered] |

## 2. Project Structure

```
[Show where new/modified files will live in the project tree]
src/
├── new-module/
│   ├── ...
```

## 3. Data Model

[Concrete schema, types, or interfaces — now we define HOW]

```
[Code block with types/schema in the project's language]
```

### Migrations
[Database changes needed, if any]

## 4. API Design

[If applicable — endpoints, signatures, message formats]

| Method | Path | Description | Request | Response |
|--------|------|-------------|---------|----------|
| POST | /api/... | ... | `{...}` | `{...}` |

## 5. Integration Points

| System | Direction | Protocol | Notes |
|--------|-----------|----------|-------|
| [e.g., Auth service] | outbound | [e.g., gRPC] | [details] |

## 6. Security

- Authentication: [approach]
- Authorization: [approach]
- Input validation: [approach]
- Sensitive data: [how handled]

## 7. Testing Strategy

| Level | Framework | What to Test | Coverage Target |
|-------|-----------|-------------|-----------------|
| Unit | [e.g., pytest] | Business logic | [e.g., > 80%] |
| Integration | [e.g., testcontainers] | API + DB | Key paths |
| Contract | [e.g., pact] | Service boundaries | All endpoints |

## 8. Performance Considerations

- Expected load: [e.g., 100 req/s]
- Bottlenecks: [identified risks]
- Optimization plan: [if needed]

## 9. Rollout Plan

[How will this be deployed? Feature flags? Phased rollout?]

## 10. Constitution Compliance

[If `.local/specs/constitution.md` exists, confirm compliance with each principle]

| Principle | Status | Notes |
|-----------|--------|-------|
| [e.g., Test coverage > 80%] | Compliant | [details] |

## 11. Risks and Mitigations

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| [risk] | high/med/low | high/med/low | [plan] |
```

---

### Tasks Template

```markdown
# Implementation Tasks: [Feature Name]

> **Spec**: [link to spec.md]
> **Plan**: [link to plan.md]
> **Date**: [YYYY-MM-DD]
> **Total tasks**: [N]

## Progress

- [ ] T000: Project scaffolding
- [ ] T001: ...
- [ ] T002: ...

---

## Dependency Graph

```
T000 (scaffolding)
 ├── T001 (data model)
 │   ├── T002 (core logic)
 │   └── T003 (API layer)
 │       └── T004 (integration tests)
 └── T005 (UI components)
     └── T006 (E2E tests)
```

---

### T000: Project Scaffolding

**Context**: Set up the foundation — directories, configs, dependencies — so
subsequent tasks can focus on logic.
**Spec reference**: N/A (infrastructure)
**Acceptance criteria**:
- [ ] Directory structure created per plan
- [ ] Dependencies added (if any)
- [ ] Config files updated
- [ ] Project builds and existing tests pass
**Dependencies**: none
**Files**: [list]
**Complexity**: low

---

### T001: [Title]

**Context**: [Why this task exists, what it enables for later tasks]
**Spec reference**: [FR-XXX, US-XXX]
**Acceptance criteria**:
- [ ] [Testable criterion derived from spec]
- [ ] [Testable criterion]
- [ ] Tests written and passing
**Dependencies**: T000
**Files**: [specific paths]
**Complexity**: low | medium | high

---

[Continue for all tasks...]

---

## Implementation Notes

### Order of execution
[Any notes about optimal task ordering, parallelization opportunities]

### Common patterns
[Reference existing code patterns the agent should follow]

### Gotchas
[Known pitfalls, things the agent should watch out for]
```
