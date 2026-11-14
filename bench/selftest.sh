#!/usr/bin/env bash
# Free guard tests for run.sh: they never pass --yes-spend, so the paid API is never reached.
set -uo pipefail

HERE=$(cd "$(dirname "$0")" && pwd -P)
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
FAILS=0

expect_fail() { # <name> <must-not-vanish-path|-> <command...>
  local name=$1 keep=$2 out
  shift 2
  if out=$("$@" 2>&1); then echo "FAIL  $name (command succeeded)"; FAILS=1; return; fi
  if [[ $keep != - && ! -e $keep ]]; then echo "FAIL  $name ($keep was deleted)"; FAILS=1; return; fi
  echo "PASS  $name"
  LAST_OUT=$out
}

expect_ok() {
  local name=$1
  shift
  if "$@" >/dev/null 2>&1; then echo "PASS  $name"; else echo "FAIL  $name"; FAILS=1; fi
}

real=$T/real-looking
mkdir -p "$real/projects/p"
echo '{}' >"$real/settings.json"
echo data >"$real/projects/p/session.jsonl"
BENCH_CONFIG_DIR=$real expect_fail "check refuses a user-data dir without the marker" "$real/projects/p/session.jsonl" "$HERE/run.sh" --check
BENCH_CONFIG_DIR=$real expect_fail "init refuses a non-empty dir" "$real/settings.json" "$HERE/run.sh" --init

fresh=$T/fresh
BENCH_CONFIG_DIR=$fresh expect_ok "init creates a fresh dir with the marker" "$HERE/run.sh" --init
[[ -f $fresh/.dev-agents-bench ]] || { echo "FAIL  marker missing after init"; FAILS=1; }
BENCH_CONFIG_DIR=$fresh expect_ok "check passes on a bench-created dir" "$HERE/run.sh" --check

BENCH_CONFIG_DIR=$fresh CLAUDE_CONFIG_DIR=$fresh expect_fail "check refuses the caller's own CLAUDE_CONFIG_DIR" "$fresh/.dev-agents-bench" "$HERE/run.sh" --check
BENCH_CONFIG_DIR=$fresh expect_fail "a paid run needs --yes-spend" - "$HERE/run.sh" rust-bug
[[ $LAST_OUT == *"--yes-spend"* ]] || { echo "FAIL  the refusal does not mention --yes-spend"; FAILS=1; }
BENCH_CONFIG_DIR=$fresh expect_fail "the probe needs --yes-spend" - "$HERE/run.sh" --probe
[[ $LAST_OUT == *"--yes-spend"* ]] || { echo "FAIL  the probe refusal does not mention --yes-spend"; FAILS=1; }
if [[ -z $(find "$HERE/results" -newer "$T" 2>/dev/null) ]]; then echo "PASS  no results were created"; else echo "FAIL  results were created"; FAILS=1; fi

hidden_case() { # <name> <expected> <line appended to the fixed source, or empty>
  local label=$1 expected=$2 hook=$3
  if (
    source "$HERE/score.sh"
    work=$(mktemp -d "$T/work.XXXXXX")
    cp -R "$HERE/tasks/ts-second-bug/fixture/." "$work/"
    (cd "$work" && patch -s -p1 <"$HERE/tasks/ts-second-bug/reference.diff")
    [[ -z $hook ]] || printf '%s\n' "$hook" >>"$work/src/chunk.ts"
    [[ $(hidden_pass ts-second-bug "$work") == "$expected" ]]
  ); then echo "PASS  $label"; else echo "FAIL  $label"; FAILS=1; fi
}
hidden_case "hidden test passes for a correct fix" pass ""
hidden_case "correct pass count with a non-zero runner exit still fails" fail 'process.on("exit", () => { process.exitCode = 1; });'

allow=$(grep '^ALLOWED=' "$HERE/run.sh")
bad=
for pattern in 'Bash(cat' 'Bash(awk' 'Bash(find' 'Bash(grep' 'Bash(rg' 'node -e' 'git -c' 'Bash(ls*)'; do
  [[ $allow != *"$pattern"* ]] || bad="$bad [$pattern]"
done
if [[ -z $bad && $allow == *'Bash(ls)'* && $allow == *'Bash(ls .local/handoff)'* ]]; then
  echo "PASS  allowlist has no cat, awk, find, grep, rg, node -e, git -c, or wildcard ls; handoff listing is exact-form"
else echo "FAIL  allowlist is unsafe or lacks the exact ls forms:$bad"; FAILS=1; fi

expect_case() { # <name> <0|1 expected validity> <expect file content, or - for none>
  local label=$1 want=$2 content=$3 dir
  dir=$(mktemp -d "$T/tasks.XXXXXX")
  mkdir -p "$dir/tasks/x"
  [[ $content == - ]] || printf '%s\n' "$content" >"$dir/tasks/x/expect"
  if (
    source "$HERE/score.sh"
    BENCH_DIR=$dir
    got=0
    validate_expect x >/dev/null || got=1
    [[ $got == "$want" ]]
  ); then echo "PASS  $label"; else echo "FAIL  $label"; FAILS=1; fi
}
expect_case "blocked task with an empty protect list is rejected" 1 $'lang=ts\noutcome=blocked\nprotect='
expect_case "blocked task without a protect key is rejected" 1 $'lang=ts\noutcome=blocked'
expect_case "missing expect file is rejected" 1 -
expect_case "blocked task with a protect list is accepted" 0 $'lang=ts\noutcome=blocked\nprotect=src/a.ts'
all_valid=1
for task_dir in "$HERE"/tasks/*/; do
  shipped=$(basename "$task_dir")
  (source "$HERE/score.sh"; validate_expect "$shipped" >/dev/null) || { echo "FAIL  expect of $shipped is invalid"; all_valid=0; FAILS=1; }
done
((all_valid == 0)) || echo "PASS  every shipped task has a valid expect file"

sed -n '/^init_event()/,/^}/p' "$HERE/run.sh" >"$T/init-event.sh"
init_line='{"type":"system","subtype":"init","plugins":[]}'
{ for _ in 1 2 3 4 5 6; do echo '{"type":"other"}'; done; echo "$init_line"; } >"$T/late-init.jsonl"
{ echo "$init_line"; for _ in 1 2 3; do echo '{"type":"other"}'; done; } >"$T/early-init.jsonl"
if (
  # shellcheck source=/dev/null
  source "$T/init-event.sh"
  [[ -n $(init_event "$T/early-init.jsonl") && -z $(init_event "$T/late-init.jsonl") ]]
); then echo "PASS  the init poll reads only the head of the stream"; else echo "FAIL  the init poll is not bounded"; FAILS=1; fi

# A chain arm that fails fast (cost 0, claude exit 1) must be reported as such, not as a budget problem; a stub claude keeps this free.
mkdir -p "$T/bin" "$T/home"
cat >"$T/bin/claude" <<'STUB'
#!/usr/bin/env bash
case $1 in
  plugin) echo '[]' ;;
  auth) exit 0 ;;
  -p)
    cat >/dev/null
    echo '{"type":"system","subtype":"init","plugins":[],"agents":[],"mcp_servers":[]}'
    echo '{"type":"result","is_error":true,"total_cost_usd":0}'
    exit 1
    ;;
esac
STUB
chmod +x "$T/bin/claude"
marker=$(mktemp "$T/before.XXXXXX")
expect_fail "a chain arm with no cost is reported as invalid" - env HOME="$T/home" PATH="$T/bin:$PATH" BENCH_CONFIG_DIR="$fresh" "$HERE/run.sh" --yes-spend rust-bug
if [[ $LAST_OUT == *"chain arm of rust-bug is invalid"* && $LAST_OUT != *"cap reached"* ]]; then
  echo "PASS  the failure names the chain arm, not the total cap"
else echo "FAIL  misleading failure: $LAST_OUT"; FAILS=1; fi
for r in "$HERE"/results/*/; do
  [[ ! $marker -nt $r ]] || continue
  [[ ! -d $r/rust-bug-single ]] || { echo "FAIL  the single arm was started"; FAILS=1; }
  rm -rf "$(cat "$r"rust-bug-chain/workspace.path 2>/dev/null)" "$r"
done
rmdir "$HERE/results" 2>/dev/null || true

exit "$FAILS"
