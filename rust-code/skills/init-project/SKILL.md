---
name: init-project
description: "Initialize a Rust project for the rust-agents plugin: scaffold .local/ working directories, .claude/rules/ project rules, testing knowledge base, and .gitignore. Run once when starting a new project."
argument-hint: "[--force]"
disable-model-invocation: true
---

# Initialize Rust Project for rust-agents

Scaffold all directories, project rules, and knowledge base files required by the `rust-agents` plugin — agent handoffs, team results, implementation plans, testing infrastructure, and branching conventions.

**Argument**: `$ARGUMENTS` — pass `--force` to overwrite existing files.

## Steps

**1. Pre-flight checks**

- Verify `Cargo.toml` exists at workspace root
- If `.local/` already exists and `--force` was NOT passed, report what exists and skip creation

**2. Run scaffold script**

```bash
bash "${CLAUDE_SKILL_DIR}/scripts/scaffold.sh" $ARGUMENTS
```

The script creates all directories, knowledge base files, and .gitignore entry. It reads `Cargo.toml` to generate per-crate sections in `coverage-status.md`.

**3. Create project rules**

For each rule template in [references/rules/](references/rules/), create the corresponding file in `.claude/rules/` ONLY if it does not exist (or `--force`):

| Template | Target | Used by |
|----------|--------|---------|
| [branching.md](references/rules/branching.md) | `.claude/rules/branching.md` | `/rust-agents:solve-issue` |
| [commits-and-issues.md](references/rules/commits-and-issues.md) | `.claude/rules/commits-and-issues.md` | `rust-teamlead`, `rust-code-reviewer`, `/rust-agents:solve-issue` |
| [continuous-improvement.md](references/rules/continuous-improvement.md) | `.claude/rules/continuous-improvement.md` | `rust-ci-analyst`, `/rust-agents:continuous-improvement` |

Read each template and write to the target path. Create `.claude/rules/` directory if needed.

**4. Print summary**

Report what was created and next steps:
1. Edit `.claude/rules/branching.md` with project branching conventions
2. Edit `.claude/rules/commits-and-issues.md` to confirm or customize commit type list and issue labels
3. Edit `.claude/rules/continuous-improvement.md` with test configs, subsystems, reference projects
4. Run `/rust-agents:continuous-improvement` to start the first CI cycle
5. Use `/rust-agents:solve-issue <number>` to solve GitHub issues

## References

- [File Templates](references/templates.md) — knowledge base file formats and entry templates
- [Branching Rules](references/rules/branching.md) — branch naming convention template
- [Commits and Issues](references/rules/commits-and-issues.md) — Conventional Commits format and issue filing protocol
- [CI Rules](references/rules/continuous-improvement.md) — continuous improvement cycle template
