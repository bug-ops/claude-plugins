# NFR Template — Non-Functional Requirements Specification

Based on ISO/IEC 25010:2011 (SQuaRE) quality model and ISO/IEC/IEEE 29148:2018.
Adapted for Obsidian formatting with YAML properties, callouts, and wikilinks.

## Standards Lineage

- **ISO/IEC 25010:2011** — product quality model (8 characteristics, 31 sub-characteristics)
- **ISO/IEC 25023:2016** — measurement of system and software product quality
- **ISO/IEC/IEEE 29148:2018** — requirements engineering (NFR as part of SRS Section 3.3-3.6)
- This template extracts NFRs into a standalone document for complex projects

## When to Generate

Generate standalone NFR spec when:
- Non-functional requirements are substantial (>5 quality attributes matter)
- Architecture decisions depend on quality trade-offs
- SLA / compliance requirements need formal specification
- Multiple teams need to reference quality targets independently

## ISO 25010 Quality Model Reference

| Characteristic | Sub-characteristics |
|---------------|-------------------|
| **Functional Suitability** | Completeness, Correctness, Appropriateness |
| **Performance Efficiency** | Time behaviour, Resource utilization, Capacity |
| **Compatibility** | Co-existence, Interoperability |
| **Usability** | Recognizability, Learnability, Operability, Error protection, UI aesthetics, Accessibility |
| **Reliability** | Maturity, Availability, Fault tolerance, Recoverability |
| **Security** | Confidentiality, Integrity, Non-repudiation, Accountability, Authenticity |
| **Maintainability** | Modularity, Reusability, Analysability, Modifiability, Testability |
| **Portability** | Adaptability, Installability, Replaceability |

## Template Structure

````markdown
---
aliases:
  - "{Project} NFR"
  - "{Project} Quality Requirements"
tags:
  - nfr
  - requirements/non-functional
  - {domain-tag}
  - status/draft
created: {YYYY-MM-DD}
project: "{Project Name}"
status: draft
standard: "ISO/IEC 25010:2011"
related:
  - "[[BRD-{slug}-{date}]]"
  - "[[SRS-{slug}-{date}]]"
---

# {Project Name}: Non-Functional Requirements Specification

> [!abstract]
> Quality attribute requirements for {Project Name}.
> Based on ISO/IEC 25010:2011 quality model. Traceable to [[BRD-{slug}-{date}]].

## 1. Introduction

### 1.1 Purpose

This document specifies the non-functional (quality) requirements for {Project Name}.
It complements [[SRS-{slug}-{date}]] which covers functional requirements.

### 1.2 Scope

Quality attributes covered in this document and their relevance to the project.

### 1.3 Definitions

| Term | Definition |
|------|-----------|
| SLA | Service Level Agreement |
| RTO | Recovery Time Objective |
| RPO | Recovery Point Objective |
| P99 | 99th percentile latency |
| {term} | {definition} |

### 1.4 References

- [[BRD-{slug}-{date}]] — Business Requirements Document
- [[SRS-{slug}-{date}]] — Software Requirements Specification
- ISO/IEC 25010:2011 — Systems and software Quality Requirements and Evaluation

### 1.5 Priority and Trade-offs

> [!tip] Quality Attribute Priority
> When quality attributes conflict, prioritize in this order:
> 1. {highest priority attribute — e.g., Security}
> 2. {second — e.g., Reliability}
> 3. {third — e.g., Performance}
> 4. {fourth — e.g., Usability}

## 2. Performance Efficiency

### 2.1 Time Behaviour

| ID | Requirement | Target | Measurement | Conditions |
|----|------------|--------|-------------|-----------|
| NFR-PERF-001 | {Operation} response time | < {X}ms (P95) | {APM tool / load test} | {N concurrent users, normal load} |
| NFR-PERF-002 | {Page/API} load time | < {X}s | {Lighthouse / k6} | {Network conditions} |

### 2.2 Resource Utilization

| ID | Requirement | Target | Measurement |
|----|------------|--------|-------------|
| NFR-PERF-010 | CPU usage under normal load | < {X}% | {Monitoring tool} |
| NFR-PERF-011 | Memory usage per instance | < {X} MB | {Monitoring tool} |

### 2.3 Capacity

| ID | Requirement | Target | Growth |
|----|------------|--------|--------|
| NFR-PERF-020 | Concurrent users | {N} | {growth rate}/month |
| NFR-PERF-021 | Data volume | {X} GB/year | {growth rate} |
| NFR-PERF-022 | Requests per second | {N} RPS | {peak multiplier}x normal |

## 3. Reliability

### 3.1 Availability

| ID | Requirement | Target | Measurement |
|----|------------|--------|-------------|
| NFR-REL-001 | System uptime | {99.9%} | {Monitoring window: monthly/quarterly} |
| NFR-REL-002 | Planned maintenance window | {Day, time, max duration} | {Calendar} |

### 3.2 Fault Tolerance

| ID | Requirement | Behaviour |
|----|------------|-----------|
| NFR-REL-010 | Single component failure | {Graceful degradation / failover} |
| NFR-REL-011 | Database connection loss | {Retry with backoff / circuit breaker} |

### 3.3 Recoverability

| ID | Requirement | Target |
|----|------------|--------|
| NFR-REL-020 | Recovery Time Objective (RTO) | < {X} minutes |
| NFR-REL-021 | Recovery Point Objective (RPO) | < {X} minutes of data loss |
| NFR-REL-022 | Backup frequency | Every {N} hours |

## 4. Security

### 4.1 Confidentiality

| ID | Requirement | Implementation |
|----|------------|---------------|
| NFR-SEC-001 | Data encryption at rest | {AES-256 / etc} |
| NFR-SEC-002 | Data encryption in transit | {TLS 1.3+} |
| NFR-SEC-003 | PII handling | {Masking / pseudonymization / deletion policy} |

### 4.2 Authentication & Authorization

| ID | Requirement | Implementation |
|----|------------|---------------|
| NFR-SEC-010 | Authentication method | {SSO/OAuth2/JWT/API key} |
| NFR-SEC-011 | Session management | {Timeout: X min, max concurrent: N} |
| NFR-SEC-012 | Role-based access control | {Roles and their permissions} |

### 4.3 Integrity

| ID | Requirement | Implementation |
|----|------------|---------------|
| NFR-SEC-020 | Input validation | {All user inputs validated server-side} |
| NFR-SEC-021 | Audit logging | {All mutations logged with user, timestamp, diff} |

### 4.4 Compliance

> [!warning] Regulatory Requirements
> - {GDPR / CCPA / HIPAA / PCI DSS / SOC 2 / etc.}
> - {Industry-specific regulations}

## 5. Usability

### 5.1 Learnability

| ID | Requirement | Target |
|----|------------|--------|
| NFR-USE-001 | New user onboarding time | < {X} minutes to complete core task |
| NFR-USE-002 | Documentation coverage | {All features documented with examples} |

### 5.2 Operability

| ID | Requirement | Target |
|----|------------|--------|
| NFR-USE-010 | Core task completion (clicks) | < {N} clicks for {primary workflow} |
| NFR-USE-011 | Error message clarity | {All errors actionable: what went wrong + what to do} |

### 5.3 Accessibility

| ID | Requirement | Standard |
|----|------------|----------|
| NFR-USE-020 | Accessibility compliance | {WCAG 2.1 Level AA / Section 508 / none} |
| NFR-USE-021 | Keyboard navigation | {All interactive elements keyboard-accessible} |

### 5.4 Internationalization

| ID | Requirement | Details |
|----|------------|---------|
| NFR-USE-030 | Supported languages | {List of languages} |
| NFR-USE-031 | RTL support | {Required / not required} |

## 6. Compatibility

### 6.1 Interoperability

| ID | Requirement | Standard/Protocol |
|----|------------|-------------------|
| NFR-COM-001 | {System} integration | {REST/GraphQL/gRPC, data format} |
| NFR-COM-002 | Export formats | {CSV, JSON, PDF, etc.} |

### 6.2 Co-existence

| ID | Requirement | Details |
|----|------------|---------|
| NFR-COM-010 | Browser support | {Chrome, Firefox, Safari — last N versions} |
| NFR-COM-011 | OS support | {Windows, macOS, Linux — versions} |
| NFR-COM-012 | Mobile support | {iOS, Android — versions} |

## 7. Maintainability

### 7.1 Modularity & Modifiability

| ID | Requirement | Details |
|----|------------|---------|
| NFR-MNT-001 | Architecture style | {Monolith / microservices / modular monolith} |
| NFR-MNT-002 | Code coverage target | > {X}% |
| NFR-MNT-003 | API versioning | {Semantic versioning / URL-based / header-based} |

### 7.2 Testability

| ID | Requirement | Details |
|----|------------|---------|
| NFR-MNT-010 | Unit test coverage | > {X}% of business logic |
| NFR-MNT-011 | Integration test coverage | {Key workflows covered} |
| NFR-MNT-012 | CI/CD pipeline | {Build + test on every commit} |

### 7.3 Analysability

| ID | Requirement | Details |
|----|------------|---------|
| NFR-MNT-020 | Structured logging | {JSON logs with correlation IDs} |
| NFR-MNT-021 | Observability stack | {Metrics, traces, logs — tools} |
| NFR-MNT-022 | Health check endpoints | {/health, /ready} |

## 8. Portability

### 8.1 Adaptability

| ID | Requirement | Details |
|----|------------|---------|
| NFR-POR-001 | Deployment environments | {Cloud provider(s), on-prem, hybrid} |
| NFR-POR-002 | Containerization | {Docker, Kubernetes, none} |

### 8.2 Installability

| ID | Requirement | Details |
|----|------------|---------|
| NFR-POR-010 | Deployment method | {CI/CD, manual, IaC} |
| NFR-POR-011 | Configuration management | {Env vars, config files, secrets manager} |

## 9. Verification Matrix

| ID | Method | Environment | Frequency |
|----|--------|-------------|-----------|
| NFR-PERF-001 | Load test (k6/Gatling) | Staging | Per release |
| NFR-REL-001 | Uptime monitoring | Production | Continuous |
| NFR-SEC-001 | Security audit | All | Quarterly |
| NFR-USE-020 | Accessibility scan (axe) | Staging | Per release |

## 10. Open Questions

> [!question] Unresolved Quality Requirements
> - [ ] {Question 1}
> - [ ] {Question 2}

## See Also

- [[BRD-{slug}-{date}]] — business requirements (source)
- [[SRS-{slug}-{date}]] — functional requirements
- [[MOC-{project}]] — project knowledge base (if vault exists)
````

## NFR Statement Rules

Every non-functional requirement MUST be:

1. **Measurable** — has a quantitative target (time, percentage, count, etc.)
2. **Testable** — has a verification method and environment
3. **Specific** — no vague "the system should be fast"
4. **Prioritized** — tied to trade-off ordering in Section 1.5
5. **Traceable** — linked to BRD via ID
6. **Realistic** — achievable within constraints

## Bad vs Good NFR Examples

| Bad (vague) | Good (measurable) |
|------------|-------------------|
| "The system should be fast" | "API response time < 200ms (P95) under 1000 concurrent users" |
| "The system must be secure" | "All data encrypted at rest (AES-256) and in transit (TLS 1.3+)" |
| "The system should be reliable" | "System uptime ≥ 99.9% measured monthly, RTO < 15 min" |
| "The system must be easy to use" | "New user completes primary workflow in < 5 minutes without training" |

## Numbering Convention

```
NFR-{category}-{NNN}
  category = PERF | REL | SEC | USE | COM | MNT | POR
  NNN      = sequential number within category

Examples:
  NFR-PERF-001   — first performance requirement
  NFR-SEC-010    — tenth security requirement
  NFR-MNT-022    — twenty-second maintainability requirement
```

## Sections to Skip

Not every project needs all 8 quality characteristics. Skip sections that are
genuinely irrelevant — but explicitly note WHY they're skipped:

```markdown
## 8. Portability

> [!note] Not Applicable
> This project runs exclusively on {platform}. Portability requirements are not applicable.
```

Do not omit sections silently — the reader must know the omission was deliberate.
