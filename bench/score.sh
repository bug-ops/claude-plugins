#!/usr/bin/env bash
# Scores one run directory produced by bench/run.sh: one table row per task and arm. Indicative: one run per cell.
# Agent-produced code (cargo test, node --test) runs only in a throwaway copy of the workspace, with git hooks and
# fsmonitor disabled, but NOT in a sandbox: run the bench only on a machine or container you trust.
set -euo pipefail

BENCH_DIR=$(cd "$(dirname "$0")" && pwd -P)
EXCLUDE=(-- . ':!.local' ':!CHANGELOG.md')
GIT=(git -c core.fsmonitor= -c core.hooksPath=/dev/null)

expect_get() { sed -n "s/^$2=//p" "$BENCH_DIR/tasks/$1/expect" | head -n1; }

# validate_expect <task>: prints the problem and fails; a blocked task needs a protect list or its verdict would diff the whole tree.
validate_expect() {
  local task=$1 lang outcome
  [[ -f $BENCH_DIR/tasks/$task/expect ]] || { echo "no expect file"; return 1; }
  lang=$(expect_get "$task" lang)
  outcome=$(expect_get "$task" outcome)
  case $lang in rust | ts) ;; *) echo "bad lang '$lang'"; return 1 ;; esac
  case $outcome in
    changed | no_change) ;;
    blocked) [[ -n $(expect_get "$task" protect) ]] || { echo "blocked task has an empty protect list"; return 1; } ;;
    *) echo "bad outcome '$outcome'"; return 1 ;;
  esac
}

numstat_sum() { awk '{ a += $1; d += $2 } END { printf "+%d/-%d", a, d }'; }

# prepare_copy <workspace> <copy>: copies without following links, drops agent-built artifacts and git hooks.
prepare_copy() {
  cp -R "$1/." "$2/"
  rm -rf "$2/target" "$2/node_modules" "$2/.git/hooks"
  [[ -z $(find "$2" -type l | head -n1) ]]
}

# Hidden tests pass only when the runner prints the expected summary, so an early exit(0) or a crash cannot pass.
hidden_pass() {
  local task=$1 work=$2 ht lang expected out rc=0 res=fail
  ht=$(expect_get "$task" hidden_test)
  [[ -n $ht ]] || { echo n/a; return; }
  lang=$(expect_get "$task" lang)
  cp -R "$BENCH_DIR/tasks/$task/hidden/." "$work/"
  case $lang in
    rust)
      expected=$(grep -c '#\[test\]' "$BENCH_DIR/tasks/$task/hidden/$ht")
      out=$(cd "$work" && CARGO_TARGET_DIR="$work/target" cargo test --quiet --test "$(basename "$ht" .rs)" 2>&1) || rc=$?
      ((rc == 0)) && printf '%s\n' "$out" | grep -qE "^test result: ok\. $expected passed; 0 failed" && res=pass
      ;;
    ts)
      expected=$(grep -c '^test(' "$BENCH_DIR/tasks/$task/hidden/$ht")
      out=$(cd "$work" && node --test --test-reporter=tap "$ht" 2>&1) || rc=$?
      ((rc == 0)) && printf '%s\n' "$out" | grep -qx "# pass $expected" && printf '%s\n' "$out" | grep -qx '# fail 0' && res=pass
      ;;
  esac
  echo "$res"
}

outcome_verdict() {
  local task=$1 work=$2 stream=$3 expected reported protect=()
  expected=$(expect_get "$task" outcome)
  reported=$(jq -r 'select(.type == "result") | .result // empty' "$stream" 2>/dev/null |
    grep -E '^OUTCOME: (changed|no_change|blocked)$' | tail -n1 | sed 's/^OUTCOME: //' || true)
  if [[ $reported != "$expected" ]]; then echo "FAIL(${reported:-none}!=$expected)"; return; fi
  case $expected in
    no_change) "${GIT[@]}" -C "$work" diff --quiet bench-scaffold "${EXCLUDE[@]}" || { echo "FAIL(diff not empty)"; return; } ;;
    blocked)
      read -r -a protect <<<"$(expect_get "$task" protect)"
      "${GIT[@]}" -C "$work" diff --quiet bench-scaffold -- "${protect[@]}" || { echo "FAIL(protected file changed)"; return; }
      ;;
  esac
  echo ok
}

findings() {
  local task=$1 work=$2 files patterns lines total confirmed f
  files=$(ls "$work"/.local/handoff/*-critic.md "$work"/.local/handoff/*-review.md 2>/dev/null || true)
  [[ -n $files ]] || { echo n/a; return; }
  patterns=$(mktemp)
  { expect_get "$task" seeded | tr ',' '\n'
    for f in $(expect_get "$task" defect_files | tr ',' ' '); do echo "${f##*/}"; done; } | sed '/^$/d' >"$patterns"
  # shellcheck disable=SC2086
  lines=$(grep -hE '^[[:space:]]*[-*][[:space:]]+(\*\*)?([CSM][0-9]+([^0-9]|$)|[^ ]+:[0-9]+)' $files || true)
  total=$(printf '%s' "$lines" | grep -c . || true)
  confirmed=$(printf '%s' "$lines" | grep -ciFf "$patterns" || true)
  rm -f "$patterns"
  echo "$confirmed/$((total - confirmed))"
}

review_rounds() {
  local n
  n=$(find "$1/.local/handoff" -name "*-review.md" 2>/dev/null | wc -l | tr -d " ")
  if [[ $n -eq 0 ]]; then echo n/a; else echo $((n - 1)); fi
}

stream_metrics() {
  local m
  m=$(jq -r 'select(.type == "result") | [(.total_cost_usd // "n/a"),
      (if .usage.input_tokens == null or .usage.output_tokens == null then "n/a" else .usage.input_tokens + .usage.output_tokens end),
      (.num_turns // "n/a")] | @tsv' "$1" 2>/dev/null | tail -n1 || true)
  [[ -n $m ]] || m=$'n/a\tn/a\tn/a'
  echo "$m"
}

print_row() { printf '%-18s %-7s %-6s %-30s %-9s %-9s %-6s %-7s %-9s %s\n' "$@"; }

row() {
  local d=$1 problem name task arm ws work stream cost tokens turns rounds fnd ref outcome diff hidden
  name=$(basename "$d")
  task=${name%-*}
  arm=${name##*-}
  [[ -f $d/workspace.path && -f $d/stream.jsonl ]] || return 0
  ws=$(cat "$d/workspace.path")
  stream=$d/stream.jsonl
  [[ -d $ws ]] || { printf '%-18s %-7s workspace %s is gone\n' "$task" "$arm" "$ws"; return; }
  if ! problem=$(validate_expect "$task"); then
    printf '%-18s %-7s INVALID expect: %s\n' "$task" "$arm" "$problem"
    return
  fi
  work=$(mktemp -d)
  if ! prepare_copy "$ws" "$work"; then
    rm -rf "$work"
    printf '%-18s %-7s INVALID: the workspace contains a symlink\n' "$task" "$arm"
    return
  fi
  "${GIT[@]}" -C "$work" add -A -N
  IFS=$'\t' read -r cost tokens turns <<<"$(stream_metrics "$stream")"
  rounds=n/a
  fnd=n/a
  if [[ $arm == chain ]]; then rounds=$(review_rounds "$work"); fnd=$(findings "$task" "$work"); fi
  ref=$(git apply --numstat --allow-empty "$BENCH_DIR/tasks/$task/reference.diff" | numstat_sum)
  outcome=$(outcome_verdict "$task" "$work" "$stream")
  diff="$("${GIT[@]}" -C "$work" diff --numstat bench-scaffold "${EXCLUDE[@]}" | numstat_sum) vs ref $ref"
  hidden=$(hidden_pass "$task" "$work")
  rm -rf "$work"
  print_row "$task" "$arm" "$hidden" "$outcome" "$cost" "$tokens" "$turns" "$rounds" "$fnd" "$diff"
}

main() {
  local run=${1:?usage: bench/score.sh <run-dir>} d
  print_row task arm hidden outcome usd tokens turns rounds conf/rej diff
  for d in "$run"/*/; do row "${d%/}"; done
  echo "tokens = input + output (cache excluded); conf/rej = critic and reviewer findings matching the seeded defect vs not; one run per cell, indicative only"
}

# sourced by selftest.sh for its tests, so only run when executed
if [[ ${BASH_SOURCE[0]} == "$0" ]]; then main "$@"; fi
