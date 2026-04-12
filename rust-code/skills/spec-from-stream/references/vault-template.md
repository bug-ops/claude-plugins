# Vault Template — Obsidian Knowledge Base Decomposition

Instructions for decomposing specification documents (BRD, SRS, NFR) into an
Obsidian vault with atomic notes following the Zettelkasten method.

## When to Generate

When the user requests decomposition after document generation:
"разбей на заметки", "сделай vault", "convert to knowledge base", "atomic notes"

## Step 1: Extract Concepts

Parse all generated documents and identify atomic concepts. Each becomes a separate note:

| Source Section | Note Types to Extract |
|---------------|----------------------|
| BRD: Problem Statement | `concepts/problem-{slug}.md` — one note per distinct problem |
| BRD: Target Users | `concepts/user-{role}.md` — one note per user role |
| BRD/SRS: Functional Requirements | `concepts/feature-{area}.md` — one note per feature area (NOT per FR) |
| NFR: Quality Attributes | `concepts/nfr-{category}.md` — only if substantial (skip trivial) |
| BRD: Integrations | `concepts/integration-{system}.md` — one per external system |
| BRD: Constraints / SRS: Design Constraints | `decisions/adr-{slug}.md` — each constraint as an ADR if it implies a decision |
| BRD: Glossary | `concepts/{term}.md` — one per domain term (if non-trivial) |

**Atomicity test**: can you summarize this note in one sentence? If not — split it.

## Step 2: Create MOC

Create a Map of Content as the entry point:

```markdown
---
aliases:
  - {Project Name} Overview
tags:
  - moc
  - brd
  - {domain-tag}
created: {YYYY-MM-DD}
status: moc
---

# {Project Name}

> [!abstract]
> Knowledge base for {Project Name}. Decomposed from specification documents.

## Documents

- [[BRD-{slug}-{date}]] — business requirements
- [[SRS-{slug}-{date}]] — functional requirements (if generated)
- [[NFR-{slug}-{date}]] — non-functional requirements (if generated)

## Problem

- [[problem-{slug}]] — {one-line description}

## Users

- [[user-{role-1}]] — {goals summary}
- [[user-{role-2}]] — {goals summary}

## Features

- [[feature-{area-1}]] — {what it does}
- [[feature-{area-2}]] — {what it does}

## Integrations

- [[integration-{system}]] — {direction and data}

## Decisions

- [[adr-{slug}]] — {what was decided}
```

## Step 3: Write Atomic Notes

Every note MUST have:

1. **YAML frontmatter** with `tags`, `created`, `status: permanent`, and `related` (quoted wikilinks)
2. **Exactly one `# H1` title**
3. **Links to 2-5 other notes** from this vault (including MOC and source documents)
4. **Callouts** where appropriate (`[!tip]`, `[!warning]`, `[!question]`)

### Feature Note Example

```markdown
---
aliases:
  - {Feature short name}
tags:
  - feature
  - {domain-tag}
created: {YYYY-MM-DD}
status: permanent
related:
  - "[[MOC-{project}]]"
  - "[[user-{primary-role}]]"
---

# {Feature Area Name}

{Brief description of what this feature area covers.}

## Requirements

- **FR-001**: As a [[user-{role}]], I need {capability} so that {benefit}
  - *Acceptance criteria*: {conditions}
  - *Priority*: Must

## Dependencies

- Requires [[integration-{system}]] for {what}
- Blocked by [[adr-{constraint}]] — {why}

## Open Questions

> [!question]
> - {Unresolved items specific to this feature}

## See Also

- [[MOC-{project}]] — parent map
- [[BRD-{slug}-{date}]] — full requirements document
```

### User Role Note Example

```markdown
---
aliases:
  - {Role short name}
tags:
  - user-role
  - {domain-tag}
created: {YYYY-MM-DD}
status: permanent
related:
  - "[[MOC-{project}]]"
---

# {User Role Name}

{Who this user is and their relationship to the system.}

## Goals

- {Primary goal}
- {Secondary goal}

## Pain Points

- {Current problem 1}
- {Current problem 2}

## Interacts With

- [[feature-{area-1}]] — {how they use it}
- [[feature-{area-2}]] — {how they use it}

## See Also

- [[MOC-{project}]] — parent map
```

## Step 4: Cross-Reference and Verify

After writing all notes, perform a quality pass:

1. **Orphan check** — every note has at least one incoming link (except top-level MOC)
2. **Link density** — each permanent note links to 2-5 other notes minimum
3. **Tag consistency** — same vocabulary across all notes, nested hierarchy (`#feature`, `#user-role`)
4. **First-mention linking** — wikilink on first mention of a concept, not every occurrence
5. **Source backlink** — every note links back to source document(s) in See Also

## Output Structure

```
{project-slug}/
├── MOC-{project-slug}.md              # Entry point
├── BRD-{project-slug}-{date}.md       # Original BRD (unchanged)
├── SRS-{project-slug}-{date}.md       # SRS (if generated, unchanged)
├── NFR-{project-slug}-{date}.md       # NFR (if generated, unchanged)
├── concepts/
│   ├── problem-{slug}.md
│   ├── user-{role-1}.md
│   ├── user-{role-2}.md
│   ├── feature-{area-1}.md
│   ├── feature-{area-2}.md
│   ├── integration-{system}.md
│   └── {domain-term}.md
└── decisions/
    └── adr-{slug}.md
```

File naming: lowercase-kebab-case, descriptive, no dates in filenames (dates in `created` property).
