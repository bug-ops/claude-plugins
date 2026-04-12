# SRS Template — Software Requirements Specification

Based on IEEE 830-1998 (superseded) and ISO/IEC/IEEE 29148:2018.
Adapted for Obsidian formatting with YAML properties, callouts, and wikilinks.

## Standards Lineage

- **IEEE 830-1998** — original SRS recommended practice (withdrawn, superseded)
- **ISO/IEC/IEEE 29148:2018** — current international standard for requirements engineering
- This template follows 29148 structure with 830 naming conventions (widely recognized)

## When to Generate

Generate SRS separately from BRD when:
- BRD exists and functional requirements need detailed breakdown
- Requirements must be traceable (FR-ID → test case)
- Development team needs implementation-ready spec
- Formal sign-off or compliance review required

## Template Structure

````markdown
---
aliases:
  - "{Project} SRS"
  - "{Project} Functional Spec"
tags:
  - srs
  - requirements/functional
  - {domain-tag}
  - status/draft
created: {YYYY-MM-DD}
project: "{Project Name}"
status: draft
standard: "ISO/IEC/IEEE 29148:2018"
related:
  - "[[BRD-{slug}-{date}]]"
  - "[[NFR-{slug}-{date}]]"
---

# {Project Name}: Software Requirements Specification

> [!abstract]
> Functional requirements specification for {Project Name}.
> Based on ISO/IEC/IEEE 29148:2018. Traceable to [[BRD-{slug}-{date}]].

## 1. Introduction

### 1.1 Purpose

Describe the purpose of this SRS and its intended audience.
Identify the software product and version being specified.

### 1.2 Scope

- Product name and what it will / will not do
- Benefits, objectives, and goals
- Relationship to higher-level business requirements (link to [[BRD-{slug}-{date}]])

### 1.3 Definitions, Acronyms, and Abbreviations

| Term | Definition |
|------|-----------|
| {term} | {definition} |

### 1.4 References

- [[BRD-{slug}-{date}]] — Business Requirements Document
- [[NFR-{slug}-{date}]] — Non-Functional Requirements Specification
- {Other referenced documents}

### 1.5 Document Overview

Brief description of document organization.

## 2. Overall Description

### 2.1 Product Perspective

> [!info] System Context
> Describe where this software fits in a larger system or ecosystem.
> Include a context diagram if applicable.

- System interfaces
- User interfaces (high-level)
- Hardware interfaces
- Software interfaces
- Communication interfaces
- Memory / storage constraints
- Operations / site adaptation

### 2.2 Product Functions

High-level summary of major functional areas. Each area is detailed in Section 3.

- {Functional area 1} — {brief description}
- {Functional area 2} — {brief description}

### 2.3 User Classes and Characteristics

For each user class: role, technical proficiency, frequency of use, privileges.

| User Class | Description | Proficiency | Frequency |
|-----------|-------------|-------------|-----------|
| {Role 1} | {Who they are} | {Low/Medium/High} | {Daily/Weekly/Rare} |

### 2.4 Operating Environment

- OS / platform
- Hardware requirements
- Network requirements
- Third-party software dependencies

### 2.5 Design and Implementation Constraints

- Programming language / framework constraints
- Regulatory / compliance constraints
- Hardware limitations
- Interface conventions

### 2.6 Assumptions and Dependencies

> [!warning] Assumptions
> If any of these are wrong, requirements change:
> - {assumption 1}
> - {assumption 2}

## 3. Specific Requirements

### 3.1 External Interface Requirements

#### 3.1.1 User Interfaces

Describe screen layouts, page navigation, UI conventions.
Reference wireframes or mockups if available.

#### 3.1.2 Hardware Interfaces

Supported devices, peripherals, sensors.

#### 3.1.3 Software Interfaces

APIs consumed or provided: name, version, data format.

| Interface | System | Protocol | Data Format |
|-----------|--------|----------|-------------|
| {name} | {system} | {REST/gRPC/etc} | {JSON/Protobuf/etc} |

#### 3.1.4 Communication Interfaces

Network protocols, message formats, timing constraints.

### 3.2 Functional Requirements

Group by feature area, user flow, or use case.

#### 3.2.1 {Feature Area 1}

> [!info] Traceability
> Traces to: [[BRD-{slug}-{date}#Feature Area 1]]

**FR-001**: {Requirement statement — "The system shall..."}

- *Rationale*: {Why this requirement exists}
- *Source*: [[BRD-{slug}-{date}]], FR-001
- *Priority*: Must / Should / Could
- *Acceptance criteria*:
  1. {Testable condition 1}
  2. {Testable condition 2}
- *Dependencies*: {Other FRs or external systems}

**FR-002**: {Requirement statement}

- *Rationale*: ...
- *Source*: ...
- *Priority*: ...
- *Acceptance criteria*:
  1. ...

#### 3.2.2 {Feature Area 2}

...

### 3.3 Performance Requirements

> [!note]
> Detailed performance metrics are in [[NFR-{slug}-{date}#Performance Efficiency]].
> This section captures performance aspects tied to specific functional requirements.

- FR-001 must complete within {X}ms under {conditions}
- {Feature area} must support {N} concurrent operations

### 3.4 Logical Database Requirements

Data entities, relationships, integrity constraints, retention policies.

| Entity | Key Attributes | Relationships | Retention |
|--------|---------------|--------------|-----------|
| {entity} | {fields} | {references} | {policy} |

### 3.5 Design Constraints

Standards compliance, hardware limitations, protocol requirements.

### 3.6 Software System Attributes

> [!note]
> Full quality attribute specifications are in [[NFR-{slug}-{date}]].
> This section summarizes attributes that constrain functional design.

- Reliability: {constraints on functional behavior}
- Security: {auth/authz requirements affecting functional design}
- Maintainability: {coding standards, modularity requirements}

## 4. Verification and Validation

### 4.1 Verification Matrix

| Requirement | Method | Criteria | Status |
|------------|--------|----------|--------|
| FR-001 | {Test/Inspection/Analysis/Demo} | {Pass criteria} | {Pending} |
| FR-002 | ... | ... | ... |

### 4.2 Acceptance Test Outline

High-level test scenarios covering critical user flows.

## 5. Appendices

### 5.1 Traceability Matrix

| BRD Requirement | SRS Requirement(s) | NFR Requirement(s) |
|----------------|--------------------|--------------------|
| BRD-FR-001 | FR-001, FR-002 | NFR-PERF-001 |

### 5.2 Use Case Diagrams / Flows

{Mermaid diagrams or references to external diagrams}

## See Also

- [[BRD-{slug}-{date}]] — business requirements (source)
- [[NFR-{slug}-{date}]] — non-functional requirements
- [[MOC-{project}]] — project knowledge base (if vault exists)
````

## Requirement Statement Rules

Every functional requirement in Section 3.2 MUST follow these rules:

1. **Use "shall"** for mandatory requirements, "should" for recommended, "may" for optional
2. **One requirement per statement** — if you use "and", consider splitting
3. **Testable** — every requirement must have acceptance criteria that can be verified
4. **Traceable** — link back to BRD requirement ID in `Source` field
5. **Unique ID** — FR-{NNN} format, sequential within feature area
6. **Priority** — Must / Should / Could (MoSCoW without W)
7. **Rationale** — why this requirement exists (not just what)

## Numbering Convention

```
FR-{area}{NNN}
  area = two-letter feature area code (optional)
  NNN  = sequential number

Examples:
  FR-001, FR-002          — flat numbering
  FR-AU-001, FR-AU-002    — AU = Auth area
  FR-DB-001               — DB = Dashboard area
```
