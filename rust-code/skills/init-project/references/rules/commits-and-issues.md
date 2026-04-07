# Commit Messages and Issue Guidelines

This file is read by `rust-team`, `rust-code-reviewer`, and `/rust-agents:solve-issue`.
Customize sections below for this project.

## Commit Message Format

Follow the [Conventional Commits 1.0.0 specification](https://www.conventionalcommits.org/en/v1.0.0/#specification).

### Structure

```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

### Rules (from the spec)

1. Every commit MUST have a type prefix followed by a colon and space.
2. `BREAKING CHANGE:` footer or `!` after the type/scope signals a breaking change.
3. Types other than `fix` and `feat` are allowed; they do not imply a semver bump unless they include `BREAKING CHANGE`.
4. Scopes are optional; when used, they MUST be a noun in parentheses: `feat(auth): ...`
5. Description MUST follow the `type: ` prefix — use imperative, present tense, no period at end.
6. Body and footers are separated from the description by a blank line.
7. `fix` maps to a **PATCH** semver bump; `feat` maps to a **MINOR** semver bump; `BREAKING CHANGE` maps to a **MAJOR** bump.

### Allowed Types

| Type | Semver | Use for |
|------|--------|---------|
| `feat` | MINOR | New feature visible to the user |
| `fix` | PATCH | Bug fix visible to the user |
| `docs` | — | Documentation only |
| `style` | — | Formatting, whitespace — no logic change |
| `refactor` | — | Code restructure without behavior change |
| `test` | — | Adding or correcting tests |
| `build` | — | Build system, dependency updates |
| `ci` | — | CI/CD pipeline changes |
| `perf` | — | Performance improvement |
| `chore` | — | Housekeeping (version bumps, lock files) |
| `release` | — | Release preparation commits |

### Breaking Changes

```
feat!: drop support for Rust < 1.70

BREAKING CHANGE: minimum supported Rust version is now 1.70
```

Or via footer only:

```
refactor: restructure config module

BREAKING CHANGE: Config::from_file() removed, use Config::load() instead
```

### Examples

```
feat(parser): add support for TOML config files

fix: prevent crash when input buffer is empty

docs: update installation steps in README

chore: bump serde to 1.0.200

feat!: replace async runtime with tokio

BREAKING CHANGE: removed smol dependency, applications must now use tokio runtime
```

### Anti-patterns

- Do not use past tense: ~~"added support"~~ → `feat: add support`
- Do not use vague types: ~~`update: ...`~~ — pick a specific type from the table
- Do not mention AI tools, co-authors, or generation in commit messages
- Do not use emoji in commit messages

## Issue Guidelines

### Severity Labels

| Severity | Label | Description | Action |
|----------|-------|-------------|--------|
| Critical | P0 | Broken core functionality, data loss, security | File immediately, dedicate fix session |
| High | P1 | Degraded UX, incorrect non-destructive behavior | File and prioritize for next PR |
| Medium | P2 | Suboptimal behavior, minor inconsistency | File with `bug` or `enhancement` |
| Low | P3 | Cosmetic, edge case unlikely in practice | Backlog |
| Nice-to-have | P4 | Research ideas, future enhancements | File with `research` label |

### Filing Protocol

1. **Reproduce** — confirm the issue is consistent, not a one-off fluke
2. **Check duplicates** before filing:
   ```bash
   gh issue list --state open --limit 100 --json number,title,labels
   ```
3. **File** via `gh issue create` with:
   - Title: short imperative description of the problem (not the fix)
   - Body: use the template below
   - Labels: priority label (P0–P4) + category (`bug`, `enhancement`, `research`)
4. **Link** related issues when they share a root cause

### Issue Title Conventions

- Describe the problem, not the fix: `parser crashes on empty input` not `fix parser crash`
- Use lowercase, no trailing period
- Be specific: mention the component or context if helpful

### Issue Body Template

```markdown
## Description
[What happened and why it matters]

## Reproduction Steps
1. [Step one]
2. [Step two]
3. Observe: [...]

## Expected Behavior
[What should happen]

## Actual Behavior
[What actually happened]

## Environment
- Version: [project version or commit]
- Features: [feature flags enabled]

## Logs / Evidence
[Relevant excerpts]
```

### Triage Rules

- Issues labeled `wontfix` or `duplicate` are skipped in future cycles
- When a previously filed issue is no longer reproducible, add a comment with verification result
- After a fix lands, re-run the original scenario and update the issue
