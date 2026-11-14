# bench: chain vs single-agent baseline

Measures whether the `team-develop` chain beats one `developer` agent on six tiny Rust and TypeScript tasks. It runs on demand through `claude -p` (never in CI: it costs money) and does not use `claude plugin eval`.

## Run

```bash
bench/run.sh --init                                                      # once, free: creates the config dir and its marker
CLAUDE_CONFIG_DIR=~/.cache/dev-agents-bench/claude-config claude auth login   # once
bench/selftest.sh       # free: proves the config-dir and spend guards
bench/run.sh --check    # free: the isolated config dir is pristine
bench/run.sh --probe --yes-spend    # about 3 USD max: checks the harness assumptions
bench/run.sh --yes-spend            # all tasks, both arms, then the metrics table
bench/run.sh rust-bug --arm chain --yes-spend --plugin-dir /path/to/other/dev-agents   # base-vs-branch
```

Every paid invocation prints its worst-case spend and refuses to start without `--yes-spend`. `BENCH_MAX_USD` (default 15) caps each run and `BENCH_TOTAL_MAX_USD` (default 60) caps the whole invocation; the bench stops before the run that would cross it.

**Credentials (A3, unconfirmed).** `claude auth status` passes in a fresh config dir, so credentials are shared with, or inherited from, your normal login: a separate `auth login` is not proven to isolate billing. Do not rely on `--yes-spend` alone to know which account pays. `ANTHROPIC_*` variables are not forwarded to the run unless `BENCH_PASS_ANTHROPIC_ENV=1`; the probe prints the `apiKeySource` it observed.

Requirements: `claude` 2.1.325+, `jq`, `git`, `cargo`, and Node 22.18+ (TypeScript fixtures run with built-in type stripping, no dependencies). Toolchains resolve from the caller's `PATH`; `run.sh` records `command -v cargo node git` in the results. Run the bench with no other Claude Code session open: self-check 3 cannot tell a concurrent session's agent-memory writes from a leak, and `run.sh` warns at start.

## Arms

- **chain**: `/dev-agents:team-develop <task>` with `chain-preamble.md` appended to the system prompt (no questions, stop after the local commit, print an `OUTCOME:` line). Budget: `BENCH_MAX_USD` (default 15).
- **single**: `--agent dev-agents:developer` with the `Agent` tool denied and the same task text. Budget: the chain arm's measured `total_cost_usd` (matched budget via `--max-budget-usd`; if the cap is not exact the probe reports it).

Every arm gets its own fresh `mktemp -d` workspace scaffolded from `tasks/<task>/fixture/` with a repo-local git identity; arms never share a workspace. Workspaces stay in `$TMPDIR` for scoring; delete them with `rm -rf $(cat bench/results/*/*/workspace.path)`.

## Isolation

- Throwaway `CLAUDE_CONFIG_DIR` (default `$BENCH_CONFIG_DIR` or `~/.cache/dev-agents-bench/claude-config`): the installed plugin, user settings, hooks, agents, and agent memory are not loaded. `--check` deletes sessions, teams, tasks, and agent memory inside it, so it only touches a directory that `--init` created (marker file `.dev-agents-bench`), and refuses `~/.claude` and the caller's `CLAUDE_CONFIG_DIR`. `HOME` is not overridden, so toolchains and git keep working. `CLAUDE_CODE_DISABLE_CLAUDE_MDS=1` and `--strict-mcp-config` are set. Environment passed to the run: everything inherited except a parent session's switches (`CLAUDECODE`, `CLAUDE_PID`, `CLAUDE_EFFORT`, `CLAUDE_CODE_{CHILD_SESSION,ENABLE_TODO_TOOLS,ENTRYPOINT,EXECPATH,EXPERIMENTAL_AGENT_TEAMS,MESSAGING_SOCKET,MESSAGING_TOKEN,SESSION_ATTENDED,SESSION_ID,SUBAGENT_EFFORT}`) and all `ANTHROPIC_*` variables (unless `BENCH_PASS_ANTHROPIC_ENV=1`). Provider and auth variables such as `CLAUDE_CODE_USE_BEDROCK`, `CLAUDE_CODE_USE_VERTEX`, `CLAUDE_CODE_USE_FOUNDRY`, and `CLAUDE_CODE_OAUTH_TOKEN` pass through; `CLAUDE_CONFIG_DIR`, `CARGO_HOME`, and `CLAUDE_CODE_DISABLE_CLAUDE_MDS` are overridden.
- Containment (ASSUMPTION, confirmed only by `--probe`): `--settings` enables the Claude Code sandbox for Bash (`failIfUnavailable`, no network, `denyRead` for the repo, `~/.ssh`, `~/.aws`, `~/.gnupg`, `~/.claude`) and `blockReadsOutsideWorkingDirectories` for the Read tool; the plugin copy is added as a working dir so skills can read their references. The docs do not say that the sandbox keys apply under `-p`. The sandbox covers Bash only, so Read and Write stay limited by the permission mode, not the sandbox.
- The plugin under test is copied to a fresh temp directory per run, so no path in the session points into the repo. Hidden tests live in `tasks/<task>/hidden/` and are copied into a throwaway copy of the workspace only by `score.sh`.
- Checks: `--check` (config dir has no plugins, agents, skills, CLAUDE.md, hooks, or MCP servers; stale memory and sessions wiped); the init event must list only the plugin under test, built-in plugins, and `dev-agents:*` agents with no MCP servers (the run is killed otherwise); after the run no file under the real `~/.claude/agent-memory` may be newer than the run start, and no tool input may contain the repo path or `/hidden/`. A failed check marks the run invalid and aborts.
- Permissions: `acceptEdits`, `--permission-prompts none`, `autoAllowBashIfSandboxed: false` so the allowlist still gates, an allowlist narrowed to what the six tasks need (named git subcommands, `cargo test|check|build|fmt|clippy`, `node --test`, `npm test`/`npm run`, exact-form `ls` (`ls`, `ls -la`, `ls .local/handoff`, `ls -t .local/handoff`), `mkdir -p`, `date`; no `cat`, `awk`, `grep`, `rg`, `find`, `node -e`, or `git -c`: wildcard patterns for those match extra arguments, quotes, and `..`), and `AskUserQuestion` denied.
- Handoff reads: the chain arm reads `.local/handoff/*.md` through the Read tool, which `blockReadsOutsideWorkingDirectories` confines to the workspace and plugin copy, with sandbox `denyRead` as a second barrier for the hidden tests. The handoff protocol text names `cat` and `awk` for these reads; they are denied, so agents have to fall back to Read. This is a fairness limitation: the chain arm reads far more handoffs than the single arm, so any friction from the fallback costs it extra turns. Treat chain cost as an upper bound until `--probe` shows how agents cope.
- Leak check also flags tool inputs that name `.ssh`, `.aws`, `.gnupg`, `.config`, or `.claude`; a path computed at run time is not caught.

## Tasks

| Task | Expected outcome | Tests the chain on |
|---|---|---|
| `rust-bug` | changed | known root cause (even-length median) |
| `ts-scope-creep` | changed | a hidden test pins the exported API; extras fail it |
| `rust-no-change` | no_change | reported panic that does not exist |
| `ts-impossible` | blocked | visible test contradicts the documented behaviour |
| `rust-edge-case` | changed | feature with a seeded edge case (reversed range) |
| `ts-second-bug` | changed | second known-root-cause bug (dropped trailing chunk) |

Each task has `task.md` (asks for the final `OUTCOME: changed|no_change|blocked` line), `expect`, `reference.diff`, `fixture/`, and `hidden/`.

## Metrics

`score.sh <run-dir>` prints one row per task and arm: hidden-test pass; outcome vs `expect` (no-change needs an empty diff, blocked needs the protected files untouched, a missing `OUTCOME:` line fails); cost, tokens (input + output, cache excluded), and turns from the result event; fix-review rounds (reviewer handoffs minus 1, chain only); critic and reviewer findings matching the seeded defect vs not (chain only); diff size (`git add -A -N`, excluding `.local/` and `CHANGELOG.md`) against `reference.diff`. One run per cell, so treat differences as indicative.

## Not measured

Agent teams never form in `-p`, so teammates run as plain subagents and every human checkpoint takes its default. Peer messaging, teammate resume, task-list coordination, and team-develop Steps 9-10 (push, PR) are absent; gate changes are covered only as far as subagents execute them.

## Cost

Worst case is `BENCH_MAX_USD` per chain run plus the matched single run, times six tasks (180 USD at the default), but `BENCH_TOTAL_MAX_USD` (default 60) stops the invocation first. Use `--arm`, task names, and lower caps to cut it.

Scoring executes agent-written code on your machine; run the bench only on a machine or container you trust. `score.sh` runs it (`cargo test`, `node --test`) in a throwaway copy with git hooks and fsmonitor disabled, symlinks rejected, and `target`/`node_modules` removed. A hidden test passes only when the runner prints the expected pass count, so an early exit cannot pass; output forged by candidate code is not excluded.

## Baseline

Record a baseline for the current plugin: run `--probe` first and read its PASS/FAIL list, then `bench/run.sh`, and paste the table into the PR. Gate removals and prompt trims in `dev-agents/` need an eval comparison: rerun with `--plugin-dir` pointing at the base checkout and at the branch.
