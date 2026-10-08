# Question Bank

Examples of good gap-filling questions by BRD section.
Use these as inspiration — adapt to the user's context and language, don't copy verbatim.

## Principles

1. **Derive from context** — if user said "dashboard for sales team", don't ask "who is the user?", ask "the sales team — managers, analysts, or leadership?"
2. **Offer concrete options** — not "what auth do you need?", but "auth model: (a) internal employees via SSO, (b) external customers with registration, (c) no auth for MVP"
3. **Suggest a default and let them override** — "PostgreSQL is typical for this kind of system. Works for you, or do you have preferences?"
4. **One topic per question** — never bundle "who are the users AND what's the deadline AND what about security"
5. **Respect "enough"** — if user signals they're done detailing, stop asking and mark remaining unknowns as Open Questions in the `> [!question]` callout
6. **Match user's language** — always ask in the same language the user writes in
7. **Acknowledge before asking** — briefly confirm you understood the previous answer before moving to the next question

## Section: Problem Statement

When the user described WHAT to build but not WHY:

- "What problem does this solve? What happens today without this system?"
- "Who suffers from this problem the most?"
- "Are there current workarounds? People using Excel / Slack / manual processes?"
- "What happens if this is NOT built? Lost money, time, customers?"

When the user described a problem but too vaguely:

- "You mentioned [X] works poorly. Can you give a specific example — last time it happened, what went wrong?"
- "How often does this problem occur — daily, weekly, under specific conditions?"

## Section: Target Users

When users aren't mentioned at all:

- "Who will use this daily? (a) your team, (b) company's clients, (c) end consumers, (d) other"
- "Anyone besides the main users — admins, moderators, analysts who view reports?"

When users mentioned but roles unclear:

- "You mentioned [managers]. Do they all have the same needs or are there different roles with different access levels?"
- "Roughly how many users expected? (a) <10, (b) 10-100, (c) 100-1000, (d) 1000+"

## Section: Functional Requirements

When description is too high-level ("need a dashboard"):

- "What are the 3 most important actions a user must be able to do in the system?"
- "Describe a typical scenario: user opens the system and... then what?"
- "You mentioned [feature X]. What exactly does the user see/do? Step by step."

When there's a list of features but no priorities:

- "If you had to ship v1 in 2 weeks, which 3 features from this list would you keep?"
- "Is there anything on this list without which the system is pointless? That's your Must."

When requirements need acceptance criteria:

- "For [feature X] — how do we know it works correctly? What specific outcome to verify?"
- "Any edge cases? E.g., what if [no data / user enters garbage / 100 concurrent requests]?"

## Section: Non-Functional Requirements

Only ask if context suggests they matter. Don't ask about performance for an internal tool with 5 users.

- "Expecting significant load? Or is this a small-team tool where performance isn't critical?"
- "Is the data sensitive? Personal data, financials, medical — any compliance requirements?"
- "Must the system run 24/7 or is maintenance downtime acceptable?"
- "Multi-language support needed or single language is enough?"

## Section: Scope & Boundaries

This is the most underestimated section. Push for it gently:

- "What is definitely NOT in this version? Sometimes it's easier to say what we're NOT doing."
- "You mentioned [X] — is that in scope for v1 or future?"
- "Mobile version needed or web/desktop only?"
- "Integration with [Y] — now or later?"

## Section: Integrations & Dependencies

When the user mentioned external systems vaguely:

- "You mentioned [system X]. What data flows between your system and [X]? Direction: read, write, or both?"
- "Any APIs you already know you'll need to call? Or services you need to receive data from?"
- "Authentication with external systems — do you have API keys/credentials, or is that TBD?"

When no integrations mentioned but likely needed:

- "Where does the input data come from? Manual entry, file upload, API, database?"
- "Where do results go? Displayed in UI, exported, sent to another system?"
- "Any notifications needed — email, Slack, push?"

## Section: Constraints & Assumptions

- "Any hard deadline? What's driving it?"
- "Team size and composition — who's building this?"
- "Any tech stack preferences or restrictions? E.g., must run on existing infra."
- "Budget constraints that affect technology choices? (e.g., no paid services, must use open source)"

## Section: Success Criteria

When the user hasn't defined "done":

- "How will you know the project is successful — what changes for the users?"
- "Any specific metrics? E.g., reduce processing time from X to Y, handle N requests/day."
- "What does the demo look like? If you showed this to your stakeholder in 2 weeks, what would impress them?"

## Stop Signals

Recognize when the user wants to wrap up and stop asking questions:

- "хватит деталей" / "enough detail"
- "остальное агенты разберутся" / "agents can figure it out"
- "давай финализируй" / "finalize it"
- "пиши документ" / "write the document"
- Short one-word answers to multiple questions in a row
- User explicitly changing the topic

When a stop signal is detected: move ALL remaining gaps to the `> [!question] Open Questions` section and generate the final BRD immediately.
