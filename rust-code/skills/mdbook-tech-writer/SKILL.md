---
name: mdbook-tech-writer
description: >-
  Write, structure, and maintain high-quality technical documentation using mdBook.
  Use when creating or editing mdBook projects, writing Rust/software project documentation,
  structuring SUMMARY.md, drafting chapters, API references, tutorials, architecture docs,
  or any mdBook-related content. Triggers on "mdbook", "documentation", "write docs",
  "technical writing", "book.toml", "SUMMARY.md", "chapter", "tutorial", "API reference",
  "architecture doc", "user guide", or "developer guide".
---

# mdBook Technical Writer

Write professional technical documentation for software projects using mdBook.
This skill covers the full lifecycle: planning, structuring, writing, reviewing, and maintaining docs.

## Before Starting

1. Read `references/mdbook-structure.md` for mdBook conventions, `book.toml` config, and `SUMMARY.md` patterns.
2. Read `references/writing-style.md` for technical writing rules and Rust ecosystem conventions.
3. Use templates from `templates/` as starting points for different chapter types.

## Workflow

### Phase 1: Audit & Plan

Assess the project before writing:

1. **Scan the codebase** — identify public APIs, key modules, entry points, configuration, and CLI commands.
2. **Identify audience segments** — developers using the library, operators deploying it, contributors.
3. **Map existing docs** — check for README, inline doc comments (`///`), existing markdown files.
4. **Create a documentation plan** — list chapters needed, assign priority (P0 = blocks adoption, P1 = important, P2 = nice to have).

Output: a `docs-plan.md` with audience matrix and chapter list.

### Phase 2: Structure the Book

Create the mdBook project structure:

```
docs/
├── book.toml
├── src/
│   ├── SUMMARY.md
│   ├── introduction.md
│   ├── getting-started/
│   │   ├── installation.md
│   │   ├── quick-start.md
│   │   └── configuration.md
│   ├── guides/
│   │   ├── basic-usage.md
│   │   └── advanced-usage.md
│   ├── architecture/
│   │   ├── overview.md
│   │   ├── design-decisions.md
│   │   └── internals.md
│   ├── api-reference/
│   │   └── (module-per-file)
│   ├── operations/
│   │   ├── deployment.md
│   │   ├── monitoring.md
│   │   └── troubleshooting.md
│   ├── contributing.md
│   └── changelog.md
└── theme/ (optional customizations)
```

Rules for `SUMMARY.md`:
- Group chapters into logical parts using `# Part Title`
- Use indentation for sub-chapters (max 3 levels deep)
- Every linked file must exist; mdBook creates empty files for missing entries
- Use `-` prefix for all entries, not `*`
- Prefix and suffix chapters (outside parts) appear on every page

Rules for `book.toml`:
- Always set `[book]` title, authors, description, language
- Enable `[output.html.search]` for searchability
- Set `[output.html]` git-repository-url for "edit this page" links
- Configure `[build]` build-dir if CI/CD needs it

### Phase 3: Write Chapters

For each chapter, follow this process:

1. **Choose the template** from `templates/` matching the chapter type.
2. **Write the first draft** following the writing style guide.
3. **Add code examples** — every code block must be:
   - Complete and compilable (or clearly marked as pseudocode)
   - Annotated with the language identifier (` ```rust `, ` ```toml `, etc.)
   - Using `# ` prefix for hidden lines in Rust examples (mdBook convention)
   - Tested if possible (link to actual test files or use `mdbook test`)
4. **Add cross-references** — use relative links `[text](../path/file.md#anchor)`.
5. **Add admonitions** where needed — use mdBook's built-in or preprocessor syntax.

### Phase 4: Review & Polish

After writing, perform these checks:

1. **Build test**: Run `mdbook build` and fix all warnings.
2. **Link check**: Verify all internal and external links work.
3. **Code test**: Run `mdbook test` to verify Rust code examples compile.
4. **Consistency check**: Terminology, formatting, heading levels, voice.
5. **Reader test**: Can someone with zero context follow the getting-started guide end-to-end?
6. **Search test**: Do key terms appear in search results?

## Chapter Types & Templates

| Type | Template | When to use |
|------|----------|-------------|
| Getting Started | `templates/getting-started.md` | Installation, first steps, quick wins |
| Concept/Guide | `templates/guide.md` | Explaining how/why something works |
| Tutorial | `templates/tutorial.md` | Step-by-step hands-on walkthrough |
| API Reference | `templates/api-reference.md` | Per-module or per-type documentation |
| Architecture | `templates/architecture.md` | System design, internals, decisions |
| Operations | `templates/operations.md` | Deployment, config, monitoring, troubleshooting |
| Changelog | `templates/changelog.md` | Version history following Keep a Changelog |

## Writing Principles (Quick Reference)

Full details in `references/writing-style.md`. Key rules:

1. **Lead with the user's goal**, not the tool's feature.
2. **One idea per paragraph**. Short paragraphs (3-5 sentences max).
3. **Active voice, imperative mood** for instructions: "Run the command" not "The command should be run".
4. **Show, then explain**: code example first, explanation after.
5. **Progressive disclosure**: basic → intermediate → advanced within each chapter.
6. **No orphan headings**: every H2 must have content before the next H2.
7. **Consistent terminology**: define terms on first use, use the same term throughout.
8. **Meaningful link text**: "see the [configuration guide](config.md)" not "click [here](config.md)".

## mdBook-Specific Features to Use

- **`{{#include}}`** — include code from actual source files to keep examples in sync
- **`{{#rustdoc_include}}`** — include Rust code with line range from source
- **Hidden lines** — prefix with `# ` in Rust blocks to hide boilerplate
- **`{{#playground}}`** — embed Rust Playground links for interactive examples
- **Preprocessors** — `mdbook-mermaid` for diagrams, `mdbook-toc` for auto TOC, `mdbook-admonish` for callouts
- **Search** — enabled by default, ensure key terms are in headings and first paragraphs
- **Print page** — all chapters merge into one; ensure each chapter works standalone

## Quality Checklist (Per Chapter)

Before marking a chapter complete:

- [ ] Title is descriptive and matches SUMMARY.md entry
- [ ] Opens with 1-2 sentences explaining what the reader will learn
- [ ] Prerequisites listed if any
- [ ] All code examples are complete and tested
- [ ] Hidden lines used for boilerplate in Rust examples
- [ ] Cross-references to related chapters included
- [ ] No broken internal links
- [ ] Consistent heading hierarchy (H1 = chapter title, H2 = sections, H3 = subsections)
- [ ] Admonitions used for warnings, tips, important notes
- [ ] No walls of text — broken up with code, lists, or diagrams where helpful

## Iteration Strategy

For large documentation projects:

1. **Skeleton first** — create all files with H1 + one-line description
2. **P0 chapters** — write getting-started and most-needed guides
3. **Dog-food** — have someone follow the docs; fix every point of confusion
4. **P1 chapters** — architecture, advanced guides, operations
5. **P2 chapters** — deep dives, edge cases, contributor docs
6. **Maintain** — update docs as part of every feature PR
