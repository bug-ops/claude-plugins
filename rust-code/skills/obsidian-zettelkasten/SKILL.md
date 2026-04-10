---
name: obsidian-zettelkasten
description: "Format documentation as an Obsidian knowledge base using the Zettelkasten method. Triggers on: 'obsidian', 'zettelkasten', 'knowledge base', 'create vault', 'obsidian notes', 'convert to obsidian', 'format as obsidian', 'cross-reference notes', 'map of content', 'MOC', 'atomic notes'. Produces interlinked notes with YAML properties, wikilinks, tags, callouts, and Maps of Content."
---

# Obsidian Zettelkasten Formatter

Format project documentation, notes, and knowledge as an Obsidian vault using the Zettelkasten method with dense cross-referencing.

## Before Starting

1. Read `references/obsidian-syntax.md` for Obsidian-specific Markdown syntax
2. Read `references/zettelkasten-structure.md` for note types, linking patterns, and vault organization

## Workflow

### Phase 1: Analyze Source Material

1. Identify the input: source code, README, docs, conversations, or raw notes
2. Extract distinct concepts — each concept becomes one atomic note
3. Identify relationships between concepts (depends-on, implements, extends, contrasts, related-to)
4. Identify hierarchical groupings for Maps of Content (MOC)

### Phase 2: Design Vault Structure

Organize notes into a flat or shallow folder structure:

```
vault/
├── 00-MOC/                    # Maps of Content (index notes)
│   ├── MOC-Architecture.md
│   └── MOC-API.md
├── concepts/                  # Permanent notes (atomic ideas)
│   ├── dependency-injection.md
│   └── event-driven-architecture.md
├── references/                # Literature notes (source summaries)
│   ├── ref-clean-architecture-martin.md
│   └── ref-rust-book-ch10.md
├── guides/                    # How-to and tutorial notes
│   ├── guide-setup-project.md
│   └── guide-deployment.md
├── decisions/                 # ADRs and design decisions
│   ├── adr-001-database-choice.md
│   └── adr-002-auth-strategy.md
└── templates/                 # Note templates
    ├── tpl-concept.md
    ├── tpl-reference.md
    └── tpl-adr.md
```

Rules:
- Prefer flat structure over deep nesting — Obsidian search and links make folders optional
- Use prefixes (`MOC-`, `ref-`, `guide-`, `adr-`, `tpl-`) only when folders are not used
- Keep file names lowercase-kebab-case, descriptive, without dates in the name
- One idea per note — if a note covers two distinct topics, split it

### Phase 3: Write Notes

For each note, follow this structure:

#### 1. Properties (YAML Frontmatter)

Every note MUST start with YAML properties:

```yaml
---
aliases:
  - DI
  - Inversion of Control
tags:
  - architecture
  - design-pattern
created: 2026-04-10
related:
  - "[[service-locator]]"
  - "[[factory-pattern]]"
status: permanent
---
```

Required properties:
- `tags` — at least one tag per note, use nested tags for hierarchy (`#architecture/patterns`)
- `created` — date in `YYYY-MM-DD` format

Recommended properties:
- `aliases` — alternative names for autocomplete and linking
- `related` — explicit links to related notes (quoted wikilinks)
- `status` — one of: `fleeting`, `literature`, `permanent`, `moc`

#### 2. Title and Content

```markdown
# Dependency Injection

Dependency injection is a technique where an object receives its dependencies
from external sources rather than creating them internally.

## Core Principle

The consumer declares *what* it needs; the injector decides *how* to provide it.
This inverts the control flow — hence the alias ==Inversion of Control==.

## Relationship to Other Patterns

- Contrasts with [[service-locator]] — DI pushes dependencies, service locator pulls them
- Often implemented via [[factory-pattern]] or a DI container
- Enables [[testability]] by allowing mock injection

## In Rust

Rust achieves DI through trait objects and generics rather than runtime reflection:

> [!example] Trait-based DI in Rust
> ```rust
> trait Repository: Send + Sync {
>     fn find(&self, id: u64) -> Option<Entity>;
> }
>
> struct Service<R: Repository> {
>     repo: R,
> }
> ```

> [!tip] When to use
> Prefer generic parameters over `dyn Trait` when the concrete type is known at compile time.

## See Also

- [[MOC-Architecture]] — parent map
- [[clean-architecture]] — broader architectural context
```

#### 3. Linking Rules

Apply these rules to every note:

- **Link on first mention**: When a concept appears for the first time in a note, wrap it in `[[wikilink]]`. Do not link every occurrence — only the first
- **Use display text for readability**: `[[dependency-injection|DI]]` when the full name is verbose
- **Link to headings**: `[[note#Heading]]` when referencing a specific section
- **Link to blocks**: `[[note#^block-id]]` for precise paragraph references
- **Backlinks are automatic**: Obsidian tracks incoming links — no need to manually add "referenced by" sections
- **Embed when context helps**: Use `![[note]]` or `![[note#Section]]` to inline content from another note

### Phase 4: Create Maps of Content

MOC notes are index pages that organize related concepts. Every vault needs at least one top-level MOC.

```markdown
---
aliases:
  - Architecture Overview
tags:
  - moc
  - architecture
created: 2026-04-10
status: moc
---

# Architecture

> [!abstract] Overview
> This map organizes architectural concepts, patterns, and decisions
> used in the project.

## Patterns

- [[dependency-injection]] — decoupling components via external wiring
- [[event-driven-architecture]] — async communication between services
- [[cqrs]] — separating read and write models

## Decisions

- [[adr-001-database-choice]] — why we chose PostgreSQL
- [[adr-002-auth-strategy]] — JWT vs session-based auth

## Principles

- [[clean-architecture]] — layered boundaries
- [[solid-principles]] — SOLID in Rust context

## Related Maps

- [[MOC-API]] — API design and endpoints
- [[MOC-Testing]] — testing strategy and patterns
```

Rules:
- MOC notes contain primarily links and brief descriptions — no long-form content
- Each link has a short em-dash description (`— why/what`)
- Group links under semantic headings
- Link between MOCs to form a navigable graph

### Phase 5: Review and Cross-Reference

1. **Orphan check**: Every note must have at least one incoming link (except top-level MOC)
2. **Tag consistency**: Use the same tag vocabulary across notes — check for typos and near-duplicates
3. **Link density**: Each permanent note should link to 2-5 other notes minimum
4. **Alias coverage**: Add aliases for acronyms, abbreviations, and alternative names
5. **Callout usage**: Use callouts for warnings, tips, examples — not as primary content

## Note Types

| Type | Purpose | Status | Template |
|------|---------|--------|----------|
| Permanent | Atomic concept in your own words | `permanent` | `tpl-concept.md` |
| Literature | Summary of a source (book, article, doc) | `literature` | `tpl-reference.md` |
| MOC | Index linking related notes | `moc` | — |
| Fleeting | Quick capture, to be processed | `fleeting` | — |
| ADR | Architecture Decision Record | `permanent` | `tpl-adr.md` |
| Guide | Step-by-step how-to | `permanent` | `tpl-guide.md` |

## Callout Quick Reference

Use Obsidian callouts for structured asides:

| Type | Use for |
|------|---------|
| `> [!note]` | General supplementary information |
| `> [!tip]` | Best practices, recommendations |
| `> [!warning]` | Pitfalls, common mistakes |
| `> [!example]` | Code examples, usage demonstrations |
| `> [!abstract]` | Summaries, TL;DR at top of MOCs |
| `> [!question]` | Open questions, FAQ entries |
| `> [!danger]` | Critical issues, breaking changes |
| `> [!quote]` | Direct quotations from sources |
| `> [!info]` | Contextual background |
| `> [!bug]` | Known issues |

Foldable callouts: `> [!tip]-` (collapsed) or `> [!tip]+` (expanded by default).

Nested callouts: use additional `>` levels.

## Quality Checklist

- [ ] Every note has YAML properties with at least `tags` and `created`
- [ ] Every note has exactly one `# H1` title
- [ ] Atomic: each note covers one concept
- [ ] First mention of each concept is a `[[wikilink]]`
- [ ] No orphan notes (except top-level MOC)
- [ ] Each permanent note links to 2-5 other notes
- [ ] MOC exists for each major topic area
- [ ] Tags use consistent vocabulary with nested hierarchy
- [ ] Aliases added for acronyms and alternative names
- [ ] Callouts used appropriately (not as primary content)
- [ ] No raw URLs — all external links use `[text](url)` format
- [ ] Code blocks have language annotations

## Anti-Patterns to Avoid

- **Folder-first organization**: Do not create deep folder hierarchies. Links and tags replace folders in Zettelkasten
- **Hub notes with no links out**: MOC notes must link to actual content, not just exist as placeholders
- **Copy-pasting source material**: Literature notes should be rewritten in your own words with links to permanent notes
- **Overlapping notes**: If two notes say the same thing, merge them and add an alias
- **Inline tags only**: Always add tags to YAML properties, not just inline `#tag` — properties enable structured search
- **Linking everything**: Not every word needs a link. Link concepts, not common words
- **Date-based file names**: Use descriptive names. Dates go in `created` property
