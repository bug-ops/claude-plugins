# Zettelkasten Structure and Linking Patterns

Principles and patterns for organizing an Obsidian vault using the Zettelkasten method.

## Core Principles

### 1. Atomicity

Each note captures exactly one idea, concept, or fact. If a note covers two topics, split it into two notes and link them.

**Test**: Can you summarize this note in one sentence? If not, it is not atomic.

### 2. Connectivity

Notes derive value from their connections, not from isolation. Every note must link to at least one other note. Dense linking creates a navigable knowledge graph.

### 3. Own Words

Permanent notes are written in your own words — not copy-pasted from sources. Literature notes summarize sources; permanent notes extract and reframe insights.

### 4. No Rigid Hierarchy

Avoid deep folder nesting. The graph of links IS the structure. Folders are optional conveniences, not organizational requirements.

## Note Types

### Fleeting Notes

Quick captures during reading, meetings, or coding. Raw, unprocessed, temporary.

```yaml
---
tags:
  - fleeting
created: 2026-04-10
source: "team standup"
---
```

- Process within 24-48 hours
- Extract ideas into permanent notes, then archive or delete
- Keep them short and timestamped

### Literature Notes

Summaries of a specific source (book, article, documentation, codebase). One note per source.

```yaml
---
aliases:
  - Clean Architecture
tags:
  - literature
  - architecture
created: 2026-04-10
author: Robert C. Martin
source: "ISBN 978-0134494166"
status: literature
---

# Clean Architecture (Robert C. Martin)

## Key Ideas

- **Dependency Rule**: source code dependencies point inward, toward higher-level policies
  → see [[dependency-inversion-principle]]
- **Entities** encapsulate enterprise-wide business rules
  → see [[domain-driven-design]]
- **Use Cases** contain application-specific business rules
  → see [[cqrs]]

## Critique

- Over-emphasizes layering for small projects → [[pragmatic-architecture]]
- Java-centric examples; Rust alternatives discussed in [[rust-clean-architecture]]
```

Rules:
- Prefix with `ref-` or place in `references/` folder
- Include `author` and `source` properties
- Every key idea links to a permanent note
- Add personal critique or commentary

### Permanent Notes

Your processed understanding of a concept. Written in your own words. The core of the Zettelkasten.

```yaml
---
aliases:
  - DIP
tags:
  - architecture
  - solid
created: 2026-04-10
related:
  - "[[dependency-injection]]"
  - "[[hexagonal-architecture]]"
status: permanent
---

# Dependency Inversion Principle

High-level modules should not depend on low-level modules. Both should depend on abstractions.

## In Practice

The principle inverts the typical source code dependency direction:

> [!example] Without DIP
> `Controller → Service → Repository → Database`
> Every layer depends on the one below.

> [!example] With DIP
> `Controller → ServiceTrait ← ServiceImpl → RepoTrait ← RepoImpl`
> Dependencies point toward abstractions.

## Relationship to Other Principles

- Enables [[dependency-injection]] — the mechanism for wiring abstractions to implementations
- Foundation of [[hexagonal-architecture]] — ports are the abstractions, adapters are the implementations
- Related to [[interface-segregation]] — narrow interfaces make inversion practical

## In Rust

Rust expresses DIP through traits:

- Define trait in the high-level crate
- Implement trait in the low-level crate
- High-level crate never imports low-level crate directly

See [[rust-trait-patterns]] for implementation details.
```

### Map of Content (MOC)

Index notes that organize related permanent notes into navigable clusters. MOCs replace traditional folder hierarchies.

```yaml
---
aliases:
  - SOLID Overview
tags:
  - moc
  - architecture
created: 2026-04-10
status: moc
---

# SOLID Principles

> [!abstract]
> The five SOLID principles of object-oriented design, adapted for Rust.

## The Principles

| Principle | Note | Rust Relevance |
|-----------|------|----------------|
| Single Responsibility | [[single-responsibility]] | One struct, one reason to change |
| Open/Closed | [[open-closed-principle]] | Trait extension over modification |
| Liskov Substitution | [[liskov-substitution]] | Trait object safety |
| Interface Segregation | [[interface-segregation]] | Small, focused traits |
| Dependency Inversion | [[dependency-inversion-principle]] | Trait-based abstractions |

## Context

- Part of [[MOC-Architecture]]
- Applied in [[clean-architecture]]
- Critiqued in [[pragmatic-architecture]]
```

Rules:
- MOCs contain links and brief descriptions — not long-form content
- Each link has a one-line explanation
- Group links under semantic headings
- Link between MOCs to form a navigable hierarchy

## Linking Patterns

### Direct Reference

Link when note A directly discusses or builds on note B:

```markdown
Dependency injection is the primary mechanism for applying
the [[dependency-inversion-principle]] at runtime.
```

### Contrast Link

Link when two concepts are alternatives or opposites:

```markdown
Unlike [[service-locator]], dependency injection pushes dependencies
to the consumer rather than having the consumer pull them.
```

### See Also

Group related links at the bottom of a note for discoverability:

```markdown
## See Also

- [[MOC-Architecture]] — parent map
- [[factory-pattern]] — alternative creation pattern
- [[testability]] — key benefit of DI
```

### Embed for Context

Embed a section when the reader needs that context inline:

```markdown
For the full pattern, see:

![[dependency-injection#In Rust]]
```

### Block Reference

Reference a specific paragraph when precision matters:

```markdown
As noted in [[clean-architecture#^dependency-rule]], source code
dependencies must point inward.
```

## Tag Taxonomy

Design a consistent tag vocabulary before creating notes. Tags complement links — they enable cross-cutting discovery.

### Structure

Use nested tags for hierarchy:

```
#architecture
#architecture/patterns
#architecture/patterns/creational
#architecture/decisions

#rust
#rust/async
#rust/traits
#rust/error-handling

#status/draft
#status/review
#status/final
```

### Rules

- Tags categorize; links connect. Use both
- Define top-level tags upfront, extend as needed
- Maximum 3-4 nesting levels
- Avoid tag synonyms (`#arch` vs `#architecture`) — pick one and alias the other
- Add tags to YAML properties, not only inline — properties enable structured search and Dataview queries

## Vault Conventions

### File Naming

- Use lowercase-kebab-case: `dependency-injection.md`
- Descriptive names that identify the concept: `event-driven-architecture.md`, not `note-2026-04-10.md`
- No dates in file names — dates go in `created` property
- Prefix optional: `ref-` for literature, `adr-` for decisions, `guide-` for how-tos

### Folder Structure

Minimal folders, maximum linking:

```
vault/
├── 00-MOC/          # Maps of Content
├── concepts/        # Permanent notes
├── references/      # Literature notes
├── guides/          # How-to notes
├── decisions/       # ADRs
├── daily/           # Daily notes (optional)
└── templates/       # Note templates
```

Folders are discovery aids, not the primary organizational mechanism. A note in `concepts/` can link to any note in any folder.

### Templates

Create templates for each note type to enforce consistent structure:

**Concept template** (`tpl-concept.md`):

```yaml
---
aliases: []
tags: []
created: {{date:YYYY-MM-DD}}
related: []
status: permanent
---

# {{title}}

[One-sentence definition]

## Core Idea

[Explanation in your own words]

## Relationships

- Related to [[]]
- Contrasts with [[]]
- Part of [[]]

## See Also

- [[MOC-]] — parent map
```

**Literature template** (`tpl-reference.md`):

```yaml
---
aliases: []
tags:
  - literature
created: {{date:YYYY-MM-DD}}
author:
source:
status: literature
---

# {{title}}

## Key Ideas

- Idea 1 → see [[]]
- Idea 2 → see [[]]

## Summary

[Brief summary in own words]

## Critique

[Personal assessment, limitations, relevance]
```

**ADR template** (`tpl-adr.md`):

```yaml
---
aliases: []
tags:
  - decision
created: {{date:YYYY-MM-DD}}
status: permanent
decision-status: accepted
---

# ADR: {{title}}

## Context

[What is the issue that we're seeing that motivates this decision?]

## Decision

[What is the change that we're proposing and/or doing?]

## Consequences

[What becomes easier or more difficult to do because of this change?]

## Alternatives Considered

- [[alternative-1]] — why rejected
- [[alternative-2]] — why rejected
```

## Processing Workflow

When converting raw material into a Zettelkasten:

1. **Capture** — create fleeting notes from source material
2. **Extract** — identify distinct concepts from fleeting notes
3. **Write** — create one permanent note per concept in own words
4. **Link** — connect to existing notes (find at least 2-3 connections)
5. **Index** — add to relevant MOC or create new MOC if a cluster forms
6. **Tag** — apply consistent tags from the taxonomy
7. **Review** — check for orphans, weak links, and opportunities to split or merge
