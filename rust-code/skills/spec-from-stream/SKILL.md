---
name: spec-from-stream
description: >
  Transforms a user's stream-of-consciousness description of a product idea, feature, or system
  into a structured specification package: BRD, SRS (ISO/IEC/IEEE 29148), NFR (ISO/IEC 25010),
  formatted as Obsidian notes. Can decompose documents into a Zettelkasten knowledge base.
  The agent uses the stream as a starting point, fills in what it can, then asks guided
  questions one at a time to close gaps.
  Trigger when the user says things like "I have an idea", "I want to build", "let me describe
  what I need", "turn this into a spec", "write requirements for this", "make a BRD from this",
  "SRS", "functional requirements", "non-functional requirements", "NFR",
  "decompose into notes", "make a vault", "knowledge base",
  or provides a messy description and wants it organized into actionable requirements.
  Works in any language the user writes in.
---

# Spec from Stream

Transform unstructured product/feature descriptions into a structured specification package
formatted as Obsidian-compatible notes with dense cross-referencing.

## Before Starting

Read the reference files relevant to the requested output:

| Output | Reference file | When to read |
|--------|---------------|-------------|
| Always | `references/question-bank.md` | Before Phase 4 (gap-filling questions) |
| BRD | `references/brd-template.md` | Before Phase 5 |
| SRS | `references/srs-template.md` | Before Phase 5b (ISO/IEC/IEEE 29148:2018) |
| NFR | `references/nfr-template.md` | Before Phase 5b (ISO/IEC 25010:2011) |
| Vault | `references/vault-template.md` | Before Phase 6 (Zettelkasten decomposition) |

## Document Types

| Document | Standard | Purpose | Filename |
|----------|----------|---------|----------|
| **BRD** | — | WHAT to build and WHY (business perspective) | `BRD-{slug}-{date}.md` |
| **SRS** | ISO/IEC/IEEE 29148:2018 | HOW it works (functional spec, interfaces, verification) | `SRS-{slug}-{date}.md` |
| **NFR** | ISO/IEC 25010:2011 | Quality attributes (performance, security, reliability...) | `NFR-{slug}-{date}.md` |

Default output: BRD only. Generate SRS and/or NFR when explicitly requested or when
the project complexity warrants it (suggest to the user if appropriate).

## Workflow

### Phase 1: Intake

Accept the user's raw input — it can be:

- A stream-of-consciousness text dump
- A voice-transcription-style description
- A series of bullet points
- A conversation where the idea emerges gradually
- Even a single sentence ("I want an app that does X")

Do NOT ask clarifying questions yet. First, process what you have.

### Phase 2: Parse & Assess Coverage

Silently map the raw input onto the BRD template sections. For each section, assess:

- **GREEN**: Enough information to write a meaningful section
- **YELLOW**: Partial information — can be inferred but needs confirmation
- **RED**: Critical gap — cannot proceed without user input

Build an internal coverage map (do not show it to the user). Example:

```
Executive Summary    → GREEN
Problem Statement    → YELLOW (why not stated, inferred from context)
Target Users         → RED (not mentioned at all)
Functional Reqs      → YELLOW (high-level list, no acceptance criteria)
Non-Functional Reqs  → RED
Scope & Boundaries   → RED
Integrations         → GREEN
Constraints          → YELLOW
Success Criteria     → RED
```

### Phase 3: Present Draft & Start Dialogue

Present the user with a summary of what you understood:

1. Restate the core idea in 2-3 sentences (confirm you got it right)
2. List sections you CAN fill (GREEN) — briefly
3. List YELLOW sections with your assumptions
4. List RED sections as gaps that need input

Then immediately ask the **first** gap-filling question — pick the highest-priority RED gap
according to the Question Priority order in Phase 4.

### Phase 4: Guided Gap-Filling

Close RED and YELLOW gaps through a conversation.

#### Question Strategy

- **One question at a time** — never overwhelm with a list
- **Offer concrete options** — instead of open-ended "what's your target audience?", offer choices
- **Derive from context** — reference what the user already said
- **Suggest defaults** — propose typical solutions, let user override
- **Know when to stop** — if the user signals they're done (see `references/question-bank.md#Stop Signals`),
  move ALL remaining RED/YELLOW gaps to Open Questions and proceed to generation

#### Question Priority (most critical first)

1. **Problem & Users** — what problem, for whom
2. **Core functionality** — what the system must do (MVP)
3. **Boundaries** — what is explicitly NOT in scope
4. **Success criteria** — how to know it's done correctly
5. **Constraints** — deadlines, budget, team size, tech preferences
6. **Integrations** — external systems, APIs, data sources
7. **Non-functional requirements** — only if critical

#### Dialogue Style

- Match the user's language (Russian, English, etc.)
- Be conversational, not interrogative — you're a co-author, not an interviewer
- After each answer, briefly acknowledge it and ask the next question
- Treat the user as the domain expert — you're the structuring engine

### Phase 5: Generate BRD

Generate the BRD when one of these conditions is met:

1. All RED and YELLOW gaps are resolved
2. User sends a stop signal
3. User explicitly asks to generate the document

Read `references/brd-template.md` and generate the document following its structure exactly.

If RED sections remain unresolved, convert them into specific open questions
inside the `> [!question]` callout — never leave template placeholders.

Write the file and present it to the user.

### Phase 5b: Generate SRS and/or NFR (Optional)

Triggered when the user requests detailed requirements documents:
"сделай SRS", "functional requirements", "non-functional requirements", "NFR",
"full spec", "detailed requirements", "полный пакет документов".

Read the corresponding reference templates before generating:
- `references/srs-template.md` for SRS
- `references/nfr-template.md` for NFR

#### SRS Generation Rules

1. **Source**: extract from BRD Functional Requirements and Integrations sections
2. **Expand**: each BRD requirement becomes a detailed spec with rationale, acceptance criteria,
   dependencies, and traceability back to BRD
3. **Add interfaces**: derive from BRD integrations table
4. **Add verification**: create Verification Matrix and Traceability Matrix
5. **Standard**: follow ISO/IEC/IEEE 29148:2018 structure from template
6. **Language**: "shall" for mandatory, "should" for recommended, "may" for optional

#### NFR Generation Rules

1. **Source**: extract from BRD Non-Functional Requirements and Constraints sections
2. **Structure**: follow ISO/IEC 25010:2011 quality model — 8 characteristics
3. **Measurable**: every NFR must have a quantitative target and verification method
4. **Skip irrelevant**: omit categories that don't apply, but document WHY (`> [!note] Not Applicable`)
5. **Trade-offs**: define quality attribute priority order
6. **Gap-filling**: if BRD lacks NFR details, ask targeted questions (one at a time, with options)

#### Cross-Linking

All documents MUST be interlinked:

- BRD `related:` includes `"[[SRS-{slug}-{date}]]"` and `"[[NFR-{slug}-{date}]]"`
- SRS References section links to BRD and NFR
- NFR References section links to BRD and SRS
- Every SRS requirement has `Source: [[BRD-{slug}-{date}]], FR-NNN`
- SRS Traceability Matrix maps BRD → SRS → NFR requirement IDs

### Phase 6: Decompose into Obsidian Knowledge Base (Optional)

Triggered when the user requests decomposition:
"разбей на заметки", "сделай vault", "convert to knowledge base", "atomic notes".

Read `references/vault-template.md` and follow its instructions exactly.
Decompose ALL generated documents (BRD + SRS + NFR if present) into atomic notes.

---

## Obsidian Formatting Rules (Mandatory)

Every generated document MUST follow these rules:

### YAML Properties

- Every file starts with `---` delimited YAML frontmatter
- Required: `tags` (at least document type + domain tag), `created` (YYYY-MM-DD), `status`
- Recommended: `aliases`, `project`, `related`, `standard` (for SRS/NFR)
- Internal links in properties require quotes: `related: "[[other-note]]"`

### Callouts

| Type | Use for |
|------|---------|
| `> [!abstract]` | Document summary at the top |
| `> [!warning]` | Assumptions that need confirmation |
| `> [!danger]` | Explicit exclusions, breaking constraints |
| `> [!tip]` | Best practices, recommendations |
| `> [!question]` | Open questions, unresolved items |
| `> [!note]` | General supplementary information, "Not Applicable" sections |
| `> [!example]` | Usage examples, scenarios |
| `> [!info]` | Contextual background |

### Links

- Use `[[wikilinks]]` for references to related documents, specs, or project notes
- Link on first mention only — don't link every occurrence
- Use display text for readability: `[[long-document-name|short name]]`

### Tags

- Use nested tags for hierarchy: `#brd`, `#srs`, `#nfr`, `#domain/subdomain`
- Always add tags to YAML properties, not only inline
- Use lowercase-kebab-case for tags

### General

- One `# H1` title per document
- Code blocks with language annotations
- No raw URLs — use `[text](url)` format
- Tables for structured comparisons
- Task lists (`- [ ]`) for success criteria and open questions

---

## Language Policy

- **Conversation**: always in the user's language (detect from their first message)
- **All output documents**: always in **English**, regardless of conversation language
- This applies to: BRD, SRS, NFR, spec.md, plan.md, tasks.md, MOC, vault notes — everything
- Glossary terms may include the original-language term in parentheses
  if the English translation is ambiguous (e.g., "Counterparty (Контрагент)")
- Questions during gap-filling are asked in the user's language

## Interaction Style

- Be conversational during gap-filling, formal in output documents
- Don't lecture about "best practices" — just produce good documents
- If the user gives a one-liner, that's fine — more questions needed,
  but don't make them feel like their input was insufficient
- Treat the user as the domain expert — you're the structuring engine
