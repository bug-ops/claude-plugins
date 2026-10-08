---
name: init-project
description: "Initialize a Rust, TypeScript, or polyglot project for the dev-agents plugin: scaffold .local/ working directories, .claude/rules/ project rules, testing knowledge base, a project verify skill, and .gitignore entries. Run once when starting a new project."
argument-hint: "[--force]"
disable-model-invocation: true
allowed-tools: Bash(bash "${CLAUDE_SKILL_DIR}/scripts/scaffold.sh" *)
---

# Initialize Project for dev-agents

Scaffold all directories, project rules, and knowledge base files required by the `dev-agents` plugin — agent handoffs, team results, implementation plans, testing infrastructure, branching conventions, and a project `verify` skill. Works for Rust (`Cargo.toml`), TypeScript/JavaScript (`package.json`, `tsconfig.json`), and polyglot repositories.

**Argument**: `$ARGUMENTS` — pass `--force` to overwrite existing files.

## Steps

**1. Pre-flight checks**

- Verify at least one stack marker exists at the repository root or one level down: `Cargo.toml`, `package.json`, or `tsconfig.json`
- If `.local/` already exists and `--force` was NOT passed, report what exists and skip creation

**2. Run scaffold script**

```bash
bash "${CLAUDE_SKILL_DIR}/scripts/scaffold.sh" $ARGUMENTS
```

The script detects the stacks (`Detected stacks: ...` line), enumerates units — workspace crates for Rust; workspace packages for TypeScript from `pnpm-workspace.yaml` or the `workspaces` field, else the single package — and creates all directories, knowledge base files, the `.gitignore` entries (`.local/`, `.claude/agent-memory-local/`), and `.claude/skills/verify/SKILL.md` (only when absent). `coverage-status.md` gets one section per unit; the verify skill gets build/test/run commands per stack.

**3. Apply the stack profiles**

For every detected stack, Read `${CLAUDE_PLUGIN_ROOT}/skills/stack/references/<profile>/init.md` (`rust`, `typescript`) and `toolchain.md` next to it. Use them to review the generated files: correct the verify skill's run commands, unit names, and package manager where the scaffold guessed wrong, and add logical subsystems to `coverage-status.md`.

**4. Create project rules**

For each rule template in [references/rules/](references/rules/), create the corresponding file in `.claude/rules/` ONLY if it does not exist (or `--force`):

| Template | Target | Used by |
|----------|--------|---------|
| [branching.md](references/rules/branching.md) | `.claude/rules/branching.md` | `/dev-agents:solve-issue` |
| [commits-and-issues.md](references/rules/commits-and-issues.md) | `.claude/rules/commits-and-issues.md` | `team-develop`, `code-reviewer`, `/dev-agents:solve-issue` |
| [continuous-improvement.md](references/rules/continuous-improvement.md) | `.claude/rules/continuous-improvement.md` | `live-tester`, `researcher`, `arch-analyst`, `security-analyst`, `/dev-agents:continuous-improvement` |

Read each template and write to the target path. Create `.claude/rules/` directory if needed. While writing:

- Fill the pre-PR check block in `branching.md` with the full check suite from each detected profile's `toolchain.md` — or, when the project's CI workflow or `package.json` scripts define the checks, with those exact commands.
- Keep the example blocks for detected stacks only; drop the others.

**5. Print summary**

Report what was created (including the detected stacks and units) and next steps:
0. Review `.claude/skills/verify/SKILL.md` — it is the build/run/test recipe shared by `live-tester`, the bundled `/verify` skill, and anyone who wants to check a change end-to-end; fix the run commands if the scaffold guessed wrong
1. Edit `.claude/rules/branching.md` with project branching conventions
2. Edit `.claude/rules/commits-and-issues.md` to confirm or customize commit type list and issue labels
3. Edit `.claude/rules/continuous-improvement.md` with test configs, subsystems, reference projects
4. Run `/dev-agents:continuous-improvement` to start the first CI cycle
5. Use `/dev-agents:solve-issue <number>` to solve GitHub issues

## References

- [File Templates](references/templates.md) — knowledge base file formats and entry templates
- [Branching Rules](references/rules/branching.md) — branch naming convention template
- [Commits and Issues](references/rules/commits-and-issues.md) — Conventional Commits format and issue filing protocol
- [CI Rules](references/rules/continuous-improvement.md) — continuous improvement cycle template
- Stack profiles: `${CLAUDE_PLUGIN_ROOT}/skills/stack/references/<profile>/init.md` — per-language scaffold facts
