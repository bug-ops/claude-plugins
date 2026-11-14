#!/usr/bin/env bash
# Runs bench tasks through the team-develop chain and a single developer agent on `claude -p`.
# See bench/README.md. Free self-check: --check. One cheap paid run of every assumption: --probe.
set -euo pipefail

BENCH_DIR=$(cd "$(dirname "$0")" && pwd -P)
REPO_DIR=$(dirname "$BENCH_DIR")
CFG=${BENCH_CONFIG_DIR:-$HOME/.cache/dev-agents-bench/claude-config}
MAX_USD=${BENCH_MAX_USD:-15}
TOTAL_MAX_USD=${BENCH_TOTAL_MAX_USD:-60}
SENTINEL=.dev-agents-bench
PLUGIN_SRC=$REPO_DIR/dev-agents
PROBE_TOKEN=BENCH-PROBE-7f3a91c2
ALLOWED='Read,Glob,Grep,Edit,Write,Agent,Skill,TodoWrite,Bash(git status*),Bash(git diff*),Bash(git log*),Bash(git show*),Bash(git add*),Bash(git commit*),Bash(git checkout*),Bash(git branch*),Bash(git rev-parse*),Bash(git ls-files*),Bash(cargo --version),Bash(cargo test*),Bash(cargo check*),Bash(cargo build*),Bash(cargo fmt*),Bash(cargo clippy*),Bash(node --version),Bash(node --test*),Bash(npm test*),Bash(npm run *),Bash(ls),Bash(ls -la),Bash(ls .local/handoff),Bash(ls -t .local/handoff),Bash(mkdir -p *),Bash(date*)'
SINGLE_NOTE='Work autonomously and never ask a question. Do not commit, push, open a PR, or edit CHANGELOG.md.'

MODE=run
ARM=both
YES_SPEND=0
SPENT=0
TASKS=()
ARGS=()
RC=0
SCRATCH=$(mktemp -d)
trap 'rm -rf "$SCRATCH"' EXIT

die() { echo "bench: $*" >&2; exit 1; }

usage() {
  cat <<'EOF'
usage: bench/run.sh [--init | --check | --probe] [--yes-spend] [--plugin-dir PATH] [--arm chain|single|both] [task...]
  --init        free: create the bench config dir (must not exist or be empty) and its marker file
  --check       free: verify the isolated config dir is pristine, then exit
  --probe       cheap paid run (about 3 USD max) that checks the harness assumptions; needs --yes-spend
  --yes-spend   confirm that this invocation calls the paid API (never implied)
  --plugin-dir  plugin under test (default: <repo>/dev-agents); it is copied per run
  --arm         which arm to run (default both; single reuses the chain's measured cost as its budget)
env: BENCH_CONFIG_DIR (isolated Claude config dir), BENCH_MAX_USD (per-run cap, default 15),
     BENCH_TOTAL_MAX_USD (whole-invocation cap, default 60), BENCH_PASS_ANTHROPIC_ENV=1 (forward ANTHROPIC_* to the child)
EOF
}

warn_solo() {
  echo "bench: WARNING: close every other Claude Code session first; self-check 3 cannot tell their agent-memory writes from leaks" >&2
}

require_tools() {
  local t
  for t in claude jq git; do command -v "$t" >/dev/null || die "missing required tool: $t"; done
}

refuse_real_config_dir() {
  local canonical caller
  canonical=$(cd "$CFG" && pwd -P)
  [[ $canonical != "$(cd "$HOME" && pwd -P)/.claude" ]] || die "BENCH_CONFIG_DIR must not be the real ~/.claude"
  if [[ -n ${CLAUDE_CONFIG_DIR:-} && -d $CLAUDE_CONFIG_DIR ]]; then
    caller=$(cd "$CLAUDE_CONFIG_DIR" && pwd -P)
    [[ $canonical != "$caller" ]] || die "BENCH_CONFIG_DIR must not be the caller's CLAUDE_CONFIG_DIR"
  fi
}

init_config() {
  mkdir -p "$CFG"
  refuse_real_config_dir
  [[ -z $(ls -A "$CFG") ]] || die "$CFG is not empty; --init only creates a fresh bench config dir"
  : >"$CFG/$SENTINEL"
  echo "bench: created $CFG; now run: CLAUDE_CONFIG_DIR=$CFG claude auth login"
}

check_config() {
  local d
  [[ -d $CFG ]] || die "no bench config dir at $CFG; run: bench/run.sh --init"
  refuse_real_config_dir
  [[ -f $CFG/$SENTINEL ]] || die "$CFG has no $SENTINEL marker, so it is not a bench-created dir; nothing was deleted. Use --init on a fresh path"
  for d in agent-memory projects teams tasks todos; do rm -rf "${CFG:?}/$d"; done
  for d in agents skills CLAUDE.md; do
    [[ ! -e $CFG/$d ]] || die "$CFG/$d exists; the bench config dir must stay pristine"
  done
  if [[ -f $CFG/settings.json ]]; then
    jq -e '[has("hooks"), has("enabledPlugins"), has("mcpServers")] | any | not' "$CFG/settings.json" >/dev/null ||
      die "$CFG/settings.json defines hooks, enabledPlugins, or mcpServers"
  fi
  CLAUDE_CONFIG_DIR=$CFG claude plugin list --json | jq -e 'type == "array" and length == 0' >/dev/null ||
    die "plugins are installed in $CFG; the bench config dir must have none"
}

require_auth() {
  CLAUDE_CONFIG_DIR=$CFG claude auth status >/dev/null 2>&1 ||
    die "not logged in; run once: CLAUDE_CONFIG_DIR=$CFG claude auth login"
}

# `auth status` also passes with shared or inherited credentials (A3 is unconfirmed), so only an explicit flag authorizes spend.
confirm_spend() {
  local worst=$1
  echo "bench: this invocation calls the paid API: worst case $worst USD (per-run cap $MAX_USD, total cap $TOTAL_MAX_USD)" >&2
  ((YES_SPEND == 1)) || die "not started: add --yes-spend to confirm"
}

add_spend() {
  SPENT=$(awk -v s="$SPENT" -v c="${1:-0}" 'BEGIN { printf "%.4f", s + c }')
}

remaining_budget() {
  awk -v t="$TOTAL_MAX_USD" -v s="$SPENT" -v m="$1" 'BEGIN { r = t - s; if (r > m) r = m; printf "%.4f", (r > 0 ? r : 0) }'
}

stage_plugin() {
  local d
  d=$(mktemp -d "$SCRATCH/plugin.XXXXXX")
  cp -R "$PLUGIN_SRC/." "$d/"
  echo "$d"
}

scaffold() {
  local fixture=$1 name=$2 ws
  ws=$(mktemp -d)
  cp -R "$fixture/." "$ws/"
  git -C "$ws" init -q
  git -C "$ws" config user.name bench
  git -C "$ws" config user.email bench@example.invalid
  git -C "$ws" config commit.gpgsign false
  git -C "$ws" add -A
  git -C "$ws" commit -q -m scaffold
  git -C "$ws" tag bench-scaffold
  git -C "$ws" checkout -q -b "bench/$name"
  echo "$ws"
}

# ASSUMPTION: the documented sandbox keys also take effect under `claude -p`; failIfUnavailable aborts the run otherwise.
write_sandbox_settings() {
  local home
  home=$(cd "$HOME" && pwd -P)
  mkdir -p "$SCRATCH/cargo-home"
  jq -n --arg repo "$REPO_DIR" --arg home "$home" --arg cargo "$SCRATCH/cargo-home" '{
    sandbox: {
      enabled: true, failIfUnavailable: true, allowUnsandboxedCommands: false, autoAllowBashIfSandboxed: false,
      filesystem: {denyRead: [$repo, ($home + "/.ssh"), ($home + "/.aws"), ($home + "/.gnupg"), ($home + "/.claude"), ($home + "/.claude.json")],
                   allowWrite: [$cargo]},
      network: {allowedDomains: []}
    },
    permissions: {blockReadsOutsideWorkingDirectories: true}
  }' >"$SCRATCH/settings.json"
}

# build_args <plugin-copy> <budget-usd>; the plugin copy is an extra working dir so skills can Read their references.
build_args() {
  [[ -f $SCRATCH/settings.json ]] || write_sandbox_settings
  ARGS=(-p --output-format stream-json --verbose --plugin-dir "$1" --add-dir "$1" --strict-mcp-config
    --settings "$SCRATCH/settings.json"
    --permission-mode acceptEdits --permission-prompts none
    --allowed-tools "$ALLOWED" --max-budget-usd "$2")
}

init_event() {
  head -n5 "$1" | jq -c 'select(.type == "system" and .subtype == "init")' 2>/dev/null | head -n1 || true
}

init_problems() {
  jq -r '
    def names: map(if type == "object" then .name else . end | tostring);
    ((.plugins // []) | map(select(.source != "dev-agents@inline" and (.source | endswith("@builtin") | not))) | names | map("unexpected plugin: " + .))
    + ((.agents // []) | names | map(select(contains(":") and (startswith("dev-agents:") | not))) | map("unexpected agent: " + .))
    + (if ((.mcp_servers // []) | length) > 0 then ["MCP servers are loaded"] else [] end)
    | .[]'
}

verify_init() {
  local out=$1 init problems
  init=$(init_event "$out")
  [[ -n $init ]] || return 1
  problems=$(printf '%s' "$init" | init_problems)
  [[ -z $problems ]] || return 2
  return 0
}

# run_claude <workspace> <prompt-file> <out-dir>: runs ARGS in the workspace, aborts on a failed init check.
run_claude() {
  local ws=$1 prompt=$2 dir=$3 pid verified=0 rc v inherited=()
  # Unset only a parent session's switches (teams, todo tools, sockets, ids); provider and auth vars
  # (CLAUDE_CODE_USE_*, CLAUDE_CODE_OAUTH_TOKEN) pass through. ANTHROPIC_* can redirect billing, endpoint, or model: opt-in only.
  for v in CLAUDECODE CLAUDE_PID CLAUDE_EFFORT CLAUDE_CODE_CHILD_SESSION CLAUDE_CODE_ENABLE_TODO_TOOLS CLAUDE_CODE_ENTRYPOINT \
    CLAUDE_CODE_EXECPATH CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS CLAUDE_CODE_MESSAGING_SOCKET CLAUDE_CODE_MESSAGING_TOKEN \
    CLAUDE_CODE_SESSION_ATTENDED CLAUDE_CODE_SESSION_ID CLAUDE_CODE_SUBAGENT_EFFORT; do
    inherited+=(-u "$v")
  done
  if [[ ${BENCH_PASS_ANTHROPIC_ENV:-0} != 1 ]]; then
    for v in $(env | sed -n 's/^\(ANTHROPIC[A-Za-z_]*\)=.*/\1/p'); do inherited+=(-u "$v"); done
  fi
  : >"$dir/stream.jsonl"
  (cd "$ws" && exec env -u OLDPWD ${inherited[@]+"${inherited[@]}"} CLAUDE_CONFIG_DIR="$CFG" CLAUDE_CODE_DISABLE_CLAUDE_MDS=1 CARGO_HOME="$SCRATCH/cargo-home" \
    claude "${ARGS[@]}" <"$prompt" >"$dir/stream.jsonl" 2>"$dir/stderr.log") &
  pid=$!
  while kill -0 "$pid" 2>/dev/null; do
    if ((verified == 0)); then
      rc=0
      verify_init "$dir/stream.jsonl" || rc=$?
      if ((rc == 0)); then
        verified=1
      elif ((rc == 2)); then
        kill "$pid" 2>/dev/null || true
        wait "$pid" 2>/dev/null || true
        die "init check failed, run aborted: $(init_event "$dir/stream.jsonl" | init_problems | tr '\n' ';')"
      fi
    fi
    sleep 1
  done
  RC=0
  wait "$pid" || RC=$?
  if ((verified == 0)); then
    rc=0
    verify_init "$dir/stream.jsonl" || rc=$?
    ((rc != 2)) || die "init check failed: $(init_event "$dir/stream.jsonl" | init_problems | tr '\n' ';')"
    ((rc == 0)) || echo "bench: warning: no init event in $dir/stream.jsonl (A4 unconfirmed)" >&2
  fi
  ((RC == 0)) || echo "bench: warning: claude exited with $RC (see $dir/stderr.log)" >&2
}

memory_leaks() {
  find "$HOME/.claude/agent-memory" -type f -newer "$1" 2>/dev/null | head -n3 || true
}

tool_inputs_leaking() {
  local inputs
  inputs=$(jq -r 'select(.type == "assistant") | .message.content[]? | select(.type == "tool_use") | .input | tojson' "$1")
  {
    printf '%s\n' "$inputs" | grep -F -e "$REPO_DIR" -e '/hidden/' || true
    printf '%s\n' "$inputs" | grep -E '(\.ssh|\.aws|\.gnupg|\.config|\.claude)([/" ,}\\]|$)' || true
  }
}

post_checks() {
  local dir=$1 stamp=$2 leaks
  leaks=$(memory_leaks "$stamp")
  [[ -z $leaks ]] || die "run invalid: agent memory written under the real home: $leaks"
  leaks=$(tool_inputs_leaking "$dir/stream.jsonl")
  [[ -z $leaks ]] || die "run invalid: tool input references the repo path or /hidden/ (see $dir/stream.jsonl)"
}

result_cost() {
  jq -r 'select(.type == "result") | .total_cost_usd // empty' "$1" 2>/dev/null | tail -n1 || true
}

run_arm() {
  local task=$1 arm=$2 budget=$3 dir ws plugin stamp
  dir=$RESULTS/$task-$arm
  mkdir -p "$dir"
  ws=$(scaffold "$BENCH_DIR/tasks/$task/fixture" "$task")
  printf '%s\n' "$ws" >"$dir/workspace.path"
  plugin=$(stage_plugin)
  build_args "$plugin" "$budget"
  case $arm in
    chain)
      ARGS+=(--disallowed-tools AskUserQuestion --append-system-prompt "$(cat "$BENCH_DIR/chain-preamble.md")")
      printf '/dev-agents:team-develop %s\n' "$(cat "$BENCH_DIR/tasks/$task/task.md")" >"$dir/prompt.txt"
      ;;
    single)
      ARGS+=(--agent dev-agents:developer --disallowed-tools "Agent,AskUserQuestion")
      printf '%s\n\n%s\n' "$(cat "$BENCH_DIR/tasks/$task/task.md")" "$SINGLE_NOTE" >"$dir/prompt.txt"
      ;;
    *) die "unknown arm: $arm" ;;
  esac
  stamp=$dir/.start
  touch "$stamp"
  echo "bench: $task / $arm (budget $budget USD)" >&2
  run_claude "$ws" "$dir/prompt.txt" "$dir"
  add_spend "$(result_cost "$dir/stream.jsonl")"
  post_checks "$dir" "$stamp"
  rm -rf "$plugin"
}

record_toolchains() {
  { command -v cargo node git || true; } >"$RESULTS/toolchains.txt"
}

run_bench() {
  local task arm chain_cost budget arms_per_task=2 worst
  [[ ${#TASKS[@]} -gt 0 ]] || while IFS= read -r task; do TASKS+=("$task"); done < <(ls "$BENCH_DIR/tasks")
  for task in "${TASKS[@]}"; do [[ -d $BENCH_DIR/tasks/$task ]] || die "unknown task: $task"; done
  [[ $ARM == both ]] || arms_per_task=1
  worst=$(awk -v n="${#TASKS[@]}" -v a="$arms_per_task" -v m="$MAX_USD" -v t="$TOTAL_MAX_USD" 'BEGIN { w = n * a * m; print (w > t ? t : w) }')
  confirm_spend "$worst"
  require_auth
  mkdir -p "$RESULTS"
  record_toolchains
  for task in "${TASKS[@]}"; do
    chain_cost=
    if [[ $ARM != single ]]; then
      budget=$(remaining_budget "$MAX_USD")
      awk -v b="$budget" 'BEGIN { exit !(b > 0) }' || die "total cap $TOTAL_MAX_USD USD reached after $SPENT USD; stopping before $task"
      run_arm "$task" chain "$budget"
      chain_cost=$(result_cost "$RESULTS/$task-chain/stream.jsonl")
      if [[ $ARM == both ]] && ! awk -v c="${chain_cost:-0}" 'BEGIN { exit !(c > 0) }'; then
        die "chain arm of $task is invalid: no positive cost recorded (claude exit $RC; see $RESULTS/$task-chain/stderr.log); the single arm was not started"
      fi
    fi
    if [[ $ARM != chain ]]; then
      budget=$(remaining_budget "${chain_cost:-$MAX_USD}")
      awk -v b="$budget" 'BEGIN { exit !(b > 0) }' || die "total cap $TOTAL_MAX_USD USD reached after $SPENT USD; stopping before $task single arm"
      run_arm "$task" single "$budget"
    fi
  done
  echo "bench: spent $SPENT USD of the $TOTAL_MAX_USD USD total cap" >&2
  "$BENCH_DIR/score.sh" "$RESULTS"
}

PROBE_FAILED=0
report() {
  if [[ $2 == ok ]]; then echo "PASS  $1"; else echo "FAIL  $1 ($2)"; PROBE_FAILED=1; fi
}

probe_run() {
  local name=$1 budget=$2 prompt=$3 ws=$4 dir plugin
  shift 4
  dir=$RESULTS/probe-$name
  mkdir -p "$dir"
  printf '%s\n' "$prompt" >"$dir/prompt.txt"
  plugin=$(stage_plugin)
  build_args "$plugin" "$budget"
  ARGS+=("$@")
  touch "$dir/.start"
  run_claude "$ws" "$dir/prompt.txt" "$dir"
  add_spend "$(result_cost "$dir/stream.jsonl")"
}

result_ok() {
  jq -e 'select(.type == "result") | .is_error == false' "$1/stream.jsonl" >/dev/null 2>&1
}

probe() {
  local fx hidden ws dir cost res
  confirm_spend 3
  require_auth
  mkdir -p "$RESULTS"
  record_toolchains
  fx=$(mktemp -d "$SCRATCH/fixture.XXXXXX")
  mkdir -p "$fx/src"
  printf '[package]\nname = "probe"\nversion = "0.1.0"\nedition = "2021"\n' >"$fx/Cargo.toml"
  printf '#[test]\nfn works() {}\n' >"$fx/src/lib.rs"
  printf 'import { test } from "node:test";\ntest("works", () => {});\n' >"$fx/probe.test.mjs"
  hidden=$(mktemp -d)
  echo "$PROBE_TOKEN" >"$hidden/secret.txt"
  ws=$(scaffold "$fx" probe)
  dir=$RESULTS/probe-tools

  probe_run tools 1 "Use tools and nothing else. 1) Run 'cargo --version'. 2) Run 'node --version'. 3) Run 'cargo test --quiet' and 'node --test'. 4) Create probe.txt containing ok, then git add and git commit it with message probe. 5) Use the Read tool on $hidden/secret.txt and say whether it was denied. Finish with the line: OUTCOME: no_change" "$ws"
  [[ -z $(memory_leaks "$dir/.start") ]] && res=ok || res="agent memory written under the real home"
  report "A1 agent memory stays under the config dir" "$res"
  [[ -z $(tool_inputs_leaking "$dir/stream.jsonl") ]] && res=ok || res="repo path or /hidden/ in tool input"
  report "C2 no repo path in tool inputs" "$res"
  jq -e 'select(.type == "result") | has("total_cost_usd") and has("num_turns") and (.usage | has("input_tokens") and has("output_tokens"))' \
    "$dir/stream.jsonl" >/dev/null 2>&1 && res=ok || res="result event lacks cost, turns, or usage"
  report "A2 result event fields" "$res"
  init_event "$dir/stream.jsonl" | jq -e 'has("plugins") and has("agents") and has("mcp_servers")' >/dev/null 2>&1 && res=ok || res="init event lacks plugins, agents, or mcp_servers"
  report "A4 init event fields" "$res"
  grep -Eq 'cargo [0-9]+\.[0-9]+' "$dir/stream.jsonl" && grep -Eq 'v[0-9]+\.[0-9]+\.[0-9]+' "$dir/stream.jsonl" && res=ok || res="cargo or node not resolved from PATH"
  report "toolchains resolve" "$res"
  grep -Eq 'test result: ok' "$dir/stream.jsonl" && grep -Eq 'ℹ pass 1|# pass 1' "$dir/stream.jsonl" && res=ok || res="cargo test or node --test did not run inside the sandbox"
  report "ASSUMPTION sandbox + allowlist let cargo test and node --test run" "$res"
  [[ $(git -C "$ws" rev-list --count HEAD) -ge 2 ]] && res=ok || res="no commit was created"
  report "git commit works with the scaffold identity" "$res"
  ! grep -q "$PROBE_TOKEN" "$dir/stream.jsonl" && res=ok || res="the hidden file was readable"
  report "A5 Read outside the workspace is denied" "$res"
  cost=$(result_cost "$dir/stream.jsonl")
  awk -v c="${cost:-0}" 'BEGIN { exit !(c <= 1.0) }' && res=ok || res="cost $cost exceeds the 1 USD cap"
  report "A7 --max-budget-usd cap holds (cost ${cost:-n/a})" "$res"

  probe_run agent 1 "Reply with exactly: OK" "$ws" --agent dev-agents:developer --disallowed-tools "Agent,AskUserQuestion"
  result_ok "$RESULTS/probe-agent" && res=ok || res="--agent dev-agents:developer did not complete"
  report "A6a --agent with the plugin namespace" "$res"

  probe_run skill 1 "/dev-agents:stack" "$ws"
  result_ok "$RESULTS/probe-skill" && res=ok || res="/dev-agents:stack did not complete"
  report "A6b slash skill in -p" "$res"

  rm -rf "$hidden"
  echo "A3 (credentials per config dir) is NOT tested: observed apiKeySource=$(init_event "$dir/stream.jsonl" | jq -r '.apiKeySource // "unknown"'); 'claude auth status' passes in any config dir here"
  echo "bench: probe spent about $SPENT USD" >&2
  return "$PROBE_FAILED"
}

while (($#)); do
  case $1 in
    --init) MODE=init ;;
    --check) MODE=check ;;
    --probe) MODE=probe ;;
    --yes-spend) YES_SPEND=1 ;;
    --plugin-dir) PLUGIN_SRC=$(cd "${2:?--plugin-dir needs a path}" && pwd -P); shift ;;
    --arm) ARM=${2:?--arm needs a value}; shift ;;
    -h | --help) usage; exit 0 ;;
    -*) usage >&2; die "unknown option: $1" ;;
    *) TASKS+=("$1") ;;
  esac
  shift
done
case $ARM in chain | single | both) ;; *) die "--arm must be chain, single, or both" ;; esac
[[ -f $PLUGIN_SRC/.claude-plugin/plugin.json ]] || die "not a plugin directory: $PLUGIN_SRC"

RESULTS=$BENCH_DIR/results/$(date +%Y-%m-%dT%H-%M-%S)
require_tools
if [[ $MODE == init ]]; then init_config; exit 0; fi
check_config
case $MODE in
  check) echo "bench: config dir $CFG is pristine"; command -v cargo node git || true ;;
  probe) warn_solo; probe ;;
  run) warn_solo; run_bench ;;
esac
