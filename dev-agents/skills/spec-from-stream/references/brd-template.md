# BRD Template — Business Requirements Document

High-level business requirements document describing WHAT to build and WHY.
This is the primary output of the spec-from-stream skill, produced in Phase 5.

## When to Generate

Always. BRD is the default output document generated from stream-of-consciousness input.

## Template Structure

````markdown
---
aliases:
  - {Short project name}
  - {Acronym if applicable}
tags:
  - brd
  - {domain-tag}
  - {domain-tag/subtag}
  - status/draft
created: {YYYY-MM-DD}
project: "{Project Name}"
status: draft
related:
  - "[[{related-doc-1}]]"
---

# {Project Name}: Business Requirements Document

> [!abstract]
> Generated from stream-of-consciousness input on {date}.
> This document is designed to be consumed by both humans and AI agent teams.

## Executive Summary

One paragraph: what is being built, why, and for whom.

## Problem Statement

- What problem exists today?
- Who experiences this problem?
- What is the impact of not solving it?
- What are current workarounds (if any)?

> [!warning] Assumptions
> If present, inferred aspects that need confirmation:
> - {assumption 1}
> - {assumption 2}

## Target Users

For each user type, describe: role, goals, pain points.

### Primary Users
{Who uses it daily}

### Secondary Users
{Occasional users, admins}

### Stakeholders
{Who cares about results but doesn't use it directly}

## Functional Requirements

Group by feature area or user flow. Each requirement follows the format:

### {Feature Area 1}

- **FR-001**: As a {user}, I need {capability} so that {benefit}
  - *Acceptance criteria*: {specific, testable conditions}
  - *Priority*: Must / Should / Could

- **FR-002**: ...

### {Feature Area 2}

- **FR-003**: ...

> [!tip] Priority Legend
> - **Must** — without this the system is pointless (MVP)
> - **Should** — important but can ship without it (v1.1)
> - **Could** — nice to have (backlog)

## Non-Functional Requirements

Only include what's relevant to this project.

> [!note] Sections below are included only when applicable

### Performance
{Response times, throughput — if relevant}

### Scalability
{Expected load, growth — if relevant}

### Security & Privacy
{Auth, data protection, compliance — if relevant}

### Availability
{Uptime, disaster recovery — if relevant}

### Usability
{Accessibility, i18n — if relevant}

## Scope & Boundaries

### In Scope
What this project delivers.

### Out of Scope

> [!danger] Explicit Exclusions
> What this project does NOT deliver. Critical for agent teams to avoid scope creep.

- {item 1}
- {item 2}

## Integrations & Dependencies

| System | Direction | Data | Status |
|--------|-----------|------|--------|
| {External API/service} | Read / Write / Both | {What data} | {Exists / TBD} |

## Constraints & Assumptions

### Technical Constraints
{Language, platform, infra}

### Business Constraints
{Timeline, budget, team}

### Assumptions

> [!warning] Assumptions
> If any of these are wrong, requirements change:
> - {assumption 1}
> - {assumption 2}

## Success Criteria

How do we know the project is successful?

- [ ] {Measurable outcome 1}
- [ ] {Measurable outcome 2}
- [ ] {Definition of Done for the overall project}

## Open Questions

> [!question] Unresolved Items
> Agent teams should flag these before making autonomous decisions.

- [ ] {Question 1}
- [ ] {Question 2}

## Glossary

| Term | Definition |
|------|-----------|
| {term} | {definition} |

## See Also

- {Links to related documents, specs, or notes as wikilinks: [[related-doc]]}
````

## Output Rules

- Filename: `BRD-{project-name-slug}-{YYYY-MM-DD}.md`
- All functional requirements must have acceptance criteria
- All assumptions grouped in `> [!warning] Assumptions` callouts
- Open questions section must exist (even if empty)
- Self-contained — an agent reading only this file should understand what to build
- Never contain template placeholders — unresolved gaps become open questions
