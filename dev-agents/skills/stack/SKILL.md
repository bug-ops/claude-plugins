---
name: stack
description: "Language profile loader for dev-agents. Detects the project's language stack (Rust, TypeScript/JavaScript, or both) and points each agent to its binding language rules: toolchain commands plus role-specific idioms, anti-patterns, and checklists. Every dev-agents agent loads it at startup; it is not meant to be invoked by users."
user-invocable: false
---

# Stack Profile

Agents in this plugin carry process only. The language rules you apply — commands, idioms, anti-patterns, checklists — live in this skill's references. They are binding: treat them as part of your system prompt.

References directory: `${CLAUDE_SKILL_DIR}/references/`
Plugin root (for knowledge skills a profile names): `${CLAUDE_PLUGIN_ROOT}`

## 1. Detect the stack

1. If your task prompt contains a `Stack:` line (e.g. `Stack: rust` or `Stack: rust,typescript`), use it as given. Orchestrators always pass it.
2. Otherwise detect from the repository root with Glob (not recursive into `node_modules/` or `target/`):

| Marker | Profile |
|--------|---------|
| `Cargo.toml` | `rust` |
| `tsconfig.json`, or `package.json` listing `typescript` in any dependency block | `typescript` |
| `package.json` without TypeScript | `typescript`, JavaScript mode — skip type-check-only steps |

3. Monorepos: also check one level down (`*/Cargo.toml`, `*/package.json`, `packages/*/package.json`) when the root has no marker.
4. Files in your task scope (the diff under review, the files you are told to change) add their profile even when the root marker belongs to another language: `.rs` → `rust`; `.ts`, `.tsx`, `.mts`, `.cts`, `.js`, `.jsx`, `.mjs`, `.cjs` → `typescript`. Use the nearest manifest above those files for toolchain commands.
5. Several profiles match → polyglot. Load every matching profile and apply each one only to the files of its language.
6. Nothing matches → continue with the generic process from your agent prompt. Never invent toolchain commands; say `Stack: none detected` in your handoff.

## 2. Read the references

For every detected profile, Read both files BEFORE the first source read or edit:

1. `${CLAUDE_SKILL_DIR}/references/<profile>/toolchain.md` — manifest, check/lint/format/test/doc/audit commands, version policy, extra knowledge skills.
2. `${CLAUDE_SKILL_DIR}/references/<profile>/<role-file>` — from the table below.

| Agent / skill | Role file |
|---------------|-----------|
| architect | `architect.md` |
| developer | `developer.md` |
| testing-engineer | `testing.md` |
| performance-engineer | `performance.md` |
| security-maintenance | `security.md` |
| code-reviewer | `reviewer.md` |
| cicd-devops | `cicd.md` |
| debugger | `debugger.md` |
| critic | `critic.md` |
| live-tester | `live-tester.md` |
| researcher | `researcher.md` |
| arch-analyst | `arch-inspect.md` |
| security-analyst | `security-audit.md` |
| release skill | `release.md` |
| init-project skill | `init.md` |

Available profiles: `rust`, `typescript`. A profile that has no file for your role still has `toolchain.md` — read it.

3. Load the profile's knowledge skills NOW, in the same startup step — not later, not "when needed":

| Profile | Knowledge skills | Roles that load them |
|---------|------------------|----------------------|
| `rust` | `rust-modern-apis` | architect, developer, code-reviewer, arch-analyst |
| `typescript` | — | — |

Call `Skill(skill: "dev-agents:<name>")`; without the `Skill` tool, Read `${CLAUDE_PLUGIN_ROOT}/skills/<name>/SKILL.md` instead.

**Startup gate** — do not read or edit project source until all three hold for every detected profile: `toolchain.md` read, role file read, knowledge skills for your role loaded.

## 3. Project rules win

Project-level instructions override profile defaults: `CLAUDE.md`, `.claude/rules/*.md`, the project's own CI workflow, and scripts in the manifest (`justfile`, `Makefile`, `package.json` scripts). When the project defines a CI-matching command, run that instead of the profile default.

## 4. Record what you loaded

Start the `## Context` section of your handoff (or your final report when you write no handoff) with one line:

```
Stack: rust (toolchain, developer, rust-modern-apis)
```

List each profile, the reference files you read, and the knowledge skills you loaded. Downstream agents and the lead use it to verify that language rules were applied.

## 5. Memory hygiene

When you write agent memory, prefix each entry with the profile it applies to: `[rust]`, `[typescript]`, or `[any]`. Ignore remembered entries tagged for a profile that is not in the current stack.
