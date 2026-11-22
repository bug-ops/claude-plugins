#!/usr/bin/env bash
# Acceptance tests for the guard.sh tokenizer (#74), registry age/download warnings (#73),
# session-scoped jq warning (M8), and the read-only role's own-file exemption (M11).
# Helpers (stub curl, payload, expect) are copied from test-hooks.sh because that file runs its
# cases at top level and cannot be sourced. The stub curl here also honours -o and -w.
set -uo pipefail

guard=$(cd "$(dirname "$0")/../.." && pwd -P)/dev-agents/hooks/guard.sh
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
work=$(cd "$work" && pwd -P)
status=0

mkdir -p "$work/bin" "$work/config/teams/t1" "$work/repo/src" "$work/repo/.local" "$work/repo/tests" \
  "$work/home" "$work/tmp"
git -C "$work/repo" init -q
touch "$work/repo/src/a.rs" "$work/repo/tests/t.rs"
printf 'tests/t.rs\ntests/future.rs\n' >"$work/repo/.local/protected-tests"

ago() {
  date -u -d "$1 days ago" +%Y-%m-%dT%H:%M:%S 2>/dev/null || date -u -v-"$1"d +%Y-%m-%dT%H:%M:%S
}
export STUB_YOUNG_TS
STUB_YOUNG_TS=$(ago 1)

cat >"$work/bin/curl" <<'EOF'
#!/usr/bin/env bash
[[ $1 == -q ]] || exit 7
url=${*: -1}
args=("$@")
out="" wfmt=""
for ((i = 0; i < ${#args[@]}; i++)); do
  case ${args[i]} in
    -o) out=${args[i + 1]} ;;
    -w) wfmt=${args[i + 1]} ;;
  esac
done
old='2020-01-01T00:00:00'
code=200
body='{}'
case $url in
  *zzz-neterr*) exit 6 ;;
  *zzz-missing*) body='' code=404 ;;
  *crates.io*zzz-young*) body="{\"crate\":{\"created_at\":\"$STUB_YOUNG_TS.123456+00:00\",\"recent_downloads\":50000}}" ;;
  *crates.io*zzz-lowdl*) body="{\"crate\":{\"created_at\":\"$old.123456+00:00\",\"recent_downloads\":3}}" ;;
  *crates.io*zzz-oldpop*) body="{\"crate\":{\"created_at\":\"$old.123456+00:00\",\"recent_downloads\":500000}}" ;;
  *crates.io*zzz-huge*)
    {
      printf '{"crate":{"created_at":"%s.123456+00:00","recent_downloads":99999},"pad":"' "$old"
      head -c 5000000 /dev/zero | tr '\0' 'a'
      printf '"}'
    } >"${TMPDIR:-/tmp}/stub-huge.$$"
    body=$(cat "${TMPDIR:-/tmp}/stub-huge.$$")
    rm -f "${TMPDIR:-/tmp}/stub-huge.$$" ;;
  *api.npmjs.org*zzz-npmyoung*) body='{"downloads":99999}' ;;
  *api.npmjs.org*zzz-npmlow*) body='{"downloads":3}' ;;
  *api.npmjs.org*zzz-npmpop*) body='{"downloads":500000}' ;;
  *api.npmjs.org*zzz-dlerr*) body='' code=500 ;;
  *registry.npmjs.org*zzz-npmyoung*) body="{\"time\":{\"created\":\"$STUB_YOUNG_TS.000Z\"}}" ;;
  *registry.npmjs.org*zzz-npmlow* | *registry.npmjs.org*zzz-npmpop* | *registry.npmjs.org*zzz-dlerr*) body="{\"time\":{\"created\":\"$old.000Z\"}}" ;;
esac
if [[ -n $out ]]; then
  printf '%s' "$body" >"$out"
  printf '%s' "${wfmt//%\{http_code\}/$code}"
else
  printf '%s%s' "$body" "${wfmt//%\{http_code\}/$code}"
fi
EOF
chmod +x "$work/bin/curl"

cat >"$work/config/teams/t1/config.json" <<'EOF'
{"leadSessionId":"sess-1","members":[]}
EOF

extra_env=()
repo=$work/repo

run() {
  env -u CARGO_HOME -u NPM_CONFIG_USERCONFIG "${extra_env[@]+"${extra_env[@]}"}" PATH="$work/bin:$PATH" HOME="$work/home" \
    TMPDIR="$work/tmp" CLAUDE_CONFIG_DIR="$work/config" CLAUDE_PROJECT_DIR=/nonexistent bash "$guard" <<<"$1"
}

# sid "-" omits session_id from the payload
payload() {
  jq -nc --arg tool "$1" --arg input "$2" --arg cwd "$3" --arg at "${4:-}" --arg sid "${5:-sess-1}" '
    {tool_name: $tool, cwd: $cwd, tool_input: ($input | fromjson)}
    + (if $sid != "-" then {session_id: $sid} else {} end)
    + (if $at != "" then {agent_type: $at} else {} end)'
}

decision() { jq -e '.hookSpecificOutput.permissionDecision == "deny"' <<<"$1" >/dev/null 2>&1 && echo deny || echo allow; }

expect() {
  local want=$1 name=$2 out got
  out=$(run "$3")
  got=$(decision "$out")
  if [[ $got == "$want" ]]; then echo "ok   $name"; else
    echo "FAIL $name: expected $want, got $got: $out" >&2
    status=1
  fi
}

# want: yes|no; optional needle that the warning must contain
expect_warning() {
  local want=$1 name=$2 out got=no needle=${4:-} msg
  out=$(run "$3")
  msg=$(jq -r '.systemMessage // empty' <<<"$out" 2>/dev/null)
  [[ -n $msg ]] && got=yes
  if [[ $got == yes && -n $needle && $msg != *"$needle"* ]]; then got="yes-without-'$needle'"; fi
  if [[ $got == "$want" || ( $want == yes && -n $needle && $got == yes ) ]]; then echo "ok   $name"; else
    echo "FAIL $name: expected warning=$want${needle:+ containing '$needle'}, got $got: $out" >&2
    status=1
  fi
}

cmd_in() { jq -nc --arg c "$1" '{command: $c}'; }
file_in() { jq -nc --arg p "$1" '{file_path: $p}'; }
bash_as() { payload Bash "$(cmd_in "$2")" "$repo" "$1" "${3:-sess-1}"; }
dev="dev-agents:developer"
nl=$'\n'

# ---- #74: the 14 bypass shapes (deny) ----
expect deny "#74 git -C with a quoted dir" "$(bash_as $dev 'git -C "dir with space" commit -m x')"
expect deny "#74 command git" "$(bash_as $dev 'command git commit -m x')"
expect deny "#74 xargs git" "$(bash_as $dev 'xargs git commit')"
expect deny "#74 exec git" "$(bash_as $dev 'exec git push')"
expect deny "#74 if/then" "$(bash_as $dev 'if true; then git commit -m x; fi')"
expect deny "#74 brace group" "$(bash_as $dev '{ git commit -m x; }')"
expect deny "#74 sudo git" "$(bash_as $dev 'sudo git commit -m x')"
expect deny "#74 absolute path git" "$(bash_as $dev '/usr/bin/git commit -m x')"
expect deny "#74 quoted git" "$(bash_as $dev '"git" commit -m x')"
expect deny "#74 backslash continuation" "$(bash_as $dev "git \\${nl} commit -m x")"
expect deny "#74 time git" "$(bash_as $dev 'time git commit -m x')"
expect deny "#74 nice git" "$(bash_as $dev 'nice git push')"
expect deny "#74 env with an option" "$(bash_as $dev 'env -i git commit -m x')"
expect deny "#74 eval git" "$(bash_as $dev 'eval git commit -m x')"

# ---- #74: prefix variants with a value-taking option ----
expect deny "#74 env -u takes a value" "$(bash_as $dev 'env -u FOO git commit -m x')"
expect deny "#74 sudo -u takes a value" "$(bash_as $dev 'sudo -u root git push')"
expect deny "#74 xargs -n takes a value" "$(bash_as $dev 'xargs -n1 git commit')"
expect deny "#74 nice -n takes a value" "$(bash_as $dev 'nice -n 5 git push')"
expect deny "#74 exec -a takes a value" "$(bash_as $dev 'exec -a x git push')"
expect deny "#74 time -p" "$(bash_as $dev 'time -p git commit -m x')"
expect deny "#74 git -c global with value" "$(bash_as $dev 'git -c user.name=x commit -m x')"
expect deny "#74 git --git-dir value" "$(bash_as $dev 'git --git-dir .git push')"
expect deny "#74 assignment prefix" "$(bash_as $dev 'FOO=1 git commit -m x')"
expect deny "#74 while loop" "$(bash_as $dev 'while true; do git push; done')"
expect deny "#74 negation" "$(bash_as $dev '! git commit -m x')"
expect deny "#74 nested bash -c" "$(bash_as $dev "bash -c \"bash -c 'git commit -m x'\"")"
expect deny "#74 env -S split string" "$(bash_as $dev "env -S 'git commit -m x'")"

# ---- #74: false positives (allow) ----
expect allow "#74 FP quoted body line starts with git commit" \
  "$(bash_as $dev "gh issue create --body \"notes${nl}git commit is banned\"")"
expect allow "#74 FP heredoc body line starts with git push" \
  "$(bash_as $dev "gh issue create --body-file - <<'EOF'${nl}notes${nl}git push origin${nl}EOF")"
expect allow "#74 FP unquoted heredoc body without expansions is inert" \
  "$(bash_as $dev "cat <<EOF${nl}git push origin${nl}EOF")"
expect allow "#74 git status stays allowed" "$(bash_as $dev 'git status && git diff')"
expect allow "#74 commit as an argument of another subcommand" "$(bash_as $dev 'git log --grep commit')"
expect allow "#74 echo mention" "$(bash_as $dev 'echo git commit')"
expect allow "#74 main session may commit through a prefix" "$(bash_as '' 'sudo git commit -m x')"

# ---- S1: shell-interpreter heredocs ----
expect deny "S1 bash heredoc runs git commit" "$(bash_as $dev "bash <<'EOF'${nl}git commit -m x${nl}EOF")"
expect deny "S1 sh heredoc installs a missing package" "$(bash_as $dev "sh <<'EOF'${nl}npm install zzz-missing-pkg${nl}EOF")"
expect deny "S1 cat heredoc piped into bash" "$(bash_as $dev "cat <<'EOF' | bash${nl}git push${nl}EOF")"
expect allow "S1 gh heredoc with git push text" "$(bash_as $dev "gh issue create --body-file - <<'EOF'${nl}git push${nl}EOF")"

# ---- N1: expansions in heredoc bodies ----
expect deny "N1 unquoted heredoc: \$(git push) in the body runs" \
  "$(bash_as $dev "gh issue create --body-file - <<EOF${nl}status: \$(git push origin HEAD)${nl}EOF")"
expect deny "N1 unquoted heredoc: backtick git push in the body runs" \
  "$(bash_as $dev "gh issue create --body-file - <<EOF${nl}status: \`git push origin HEAD\`${nl}EOF")"
expect allow "N1 quoted heredoc: \$(git push) in the body is inert" \
  "$(bash_as $dev "gh issue create --body-file - <<'EOF'${nl}status: \$(git push origin HEAD)${nl}EOF")"

# ---- S2: non-literal words ----
expect allow "S2 package name with a command substitution suffix" "$(bash_as '' 'npm install zzz-missing-pkg$(echo -suffix)')"
expect allow "S2 package name from a command substitution" "$(bash_as '' 'npm install $(echo zzz-missing-pkg)')"
expect allow "S2 variable command word is a documented miss" "$(bash_as $dev '$GIT commit -m x')"
expect deny "S2 expansion in a later argument does not hide git commit" "$(bash_as $dev 'git commit -m "$(date)"')"
expect deny "S2 git commit inside a command substitution" "$(bash_as $dev 'echo $(git commit -m x)')"

# ---- rule 4 on the tokenizer ----
expect deny "M2 sudo npm install of a missing package" "$(bash_as '' 'sudo npm install zzz-missing-pkg')"
expect allow "F1 package-manager words inside a quoted body are not an install" \
  "$(bash_as '' 'gh issue create --body "steps; npm install zzz-missing-pkg fails"')"
expect deny "#73 yarn workspace app add of a missing package" "$(bash_as '' 'yarn workspace app add zzz-missing-pkg')"
expect allow "#73 yarn workspace name is not a package" "$(bash_as '' 'yarn workspace zzz-missing-ws add lodash')"

# ---- M2 documented behaviour ----
expect deny "M2 bare role name via payload still applies rule 3" "$(bash_as developer 'git commit -m x')"

# ---- #73: age and download warnings ----
expect allow "#73 young crate is never denied" "$(bash_as '' 'cargo add zzz-young')"
expect_warning yes "#73 young crate warns" "$(bash_as '' 'cargo add zzz-young')" zzz-young
expect_warning yes "#73 low-download crate names the 90-day window" "$(bash_as '' 'cargo add zzz-lowdl')" "90 days"
expect_warning no "#73 old popular crate is silent" "$(bash_as '' 'cargo add zzz-oldpop')"
expect_warning no "#73 200 without fields is silent" "$(bash_as '' 'cargo add serde')"
expect_warning no "#73 multi-MB body is handled silently" "$(bash_as '' 'cargo add zzz-huge')"
expect_warning yes "#73 young npm package warns" "$(bash_as '' 'npm install zzz-npmyoung')" zzz-npmyoung
expect_warning yes "#73 low-download npm package names the last-month window" "$(bash_as '' 'npm install zzz-npmlow')" "last month"
expect_warning no "#73 old popular npm package is silent" "$(bash_as '' 'npm install zzz-npmpop')"
expect_warning yes "#73 downloads API error warns not verified" "$(bash_as '' 'npm install zzz-dlerr')" "not verified"
expect allow "#73 downloads API error is never a denial" "$(bash_as '' 'npm install zzz-dlerr')"
extra_env=(DEV_AGENTS_DEP_MIN_AGE_DAYS=0)
expect_warning no "#73 min-age threshold is configurable" "$(bash_as '' 'cargo add zzz-young')"
extra_env=(DEV_AGENTS_DEP_MIN_DOWNLOADS=1)
expect_warning no "#73 min-downloads threshold is configurable" "$(bash_as '' 'cargo add zzz-lowdl')"
extra_env=()
expect_warning yes "#73 manifest edit gets the same warning" \
  "$(payload Write "$(jq -nc --arg p "$repo/Cargo.toml" --arg c $'[dependencies]\nzzz-young = "1"\n' '{file_path:$p,content:$c}')" "$repo")" zzz-young

# M1: lookup leaves the state dir as it found it (markers and records survive, temp files do not)
mkdir -p "$repo/src2"
expect allow "M1 setup: critic records a new file" \
  "$(payload Write "$(file_in "$repo/src2/rec.rs")" "$repo" dev-agents:critic sess-m1)"
state=$work/tmp/dev-agents-guard-$UID
before=$(find "$work/tmp" -type f | wc -l | tr -d ' ')
run "$(bash_as '' 'cargo add zzz-lowdl')" >/dev/null
after=$(find "$work/tmp" -type f | wc -l | tr -d ' ')
if [[ -d $state && $before -ge 1 && $before == "$after" ]]; then echo "ok   M1 lookup keeps state and leaves no temp files"; else
  echo "FAIL M1 lookup state: state dir '$state' exists=$([[ -d $state ]] && echo y || echo n), files before=$before after=$after" >&2
  status=1
fi

# ---- M11: read-only role may edit only files it created ----
critic="dev-agents:critic"
reviewer="dev-agents:code-reviewer"
mk() { mkdir -p "$(dirname "$1")"; : >"$1"; }
f=$repo/src/created_by_critic.rs
expect allow "M11 critic writes a new file" "$(payload Write "$(file_in "$f")" "$repo" $critic sess-m11)"
mk "$f"
expect allow "M11 critic edits the file it created" "$(payload Edit "$(file_in "$f")" "$repo" $critic sess-m11)"
expect deny "M11 another read-only role cannot edit that file" "$(payload Edit "$(file_in "$f")" "$repo" $reviewer sess-m11)"
expect deny "M11 the same role in another session cannot edit it" "$(payload Edit "$(file_in "$f")" "$repo" $critic sess-other)"
expect deny "M11 existing file never created by the role is denied" "$(payload Edit "$(file_in "$repo/src/a.rs")" "$repo" $critic sess-m11)"
mk "$repo/tests/future.rs"
payload Write "$(file_in "$repo/tests/future.rs")" "$repo" $critic sess-m11 >/dev/null
expect deny "M11 protected listed path stays denied after a Write" "$(payload Edit "$(file_in "$repo/tests/future.rs")" "$repo" $critic sess-m11)"
g=$repo/src/created_no_sid.rs
run "$(payload Write "$(file_in "$g")" "$repo" $critic -)" >/dev/null
mk "$g"
expect deny "M11 without a session id the old behaviour holds" "$(payload Edit "$(file_in "$g")" "$repo" $critic -)"
expect allow "M11 .local writes stay allowed" "$(payload Write "$(file_in "$repo/.local/handoff/x.md")" "$repo" $critic sess-m11)"

# ---- M8: jq missing warns once per session id ----
mkdir -p "$work/nojq" "$work/tmp-m8"
for t in bash env cat git dirname basename readlink realpath grep sed tr awk curl stat date id mkdir chmod mktemp rm head cut ls sort uniq wc find uname cp mv touch pwd sleep; do
  src=$(command -v "$t" 2>/dev/null || true)
  [[ -n $src && $src == /* ]] && ln -sf "$src" "$work/nojq/$t"
done
ln -sf "$work/bin/curl" "$work/nojq/curl"
nojq_warns() {
  local out
  out=$(env PATH="$work/nojq" HOME="$work/home" TMPDIR="$work/tmp-m8" CLAUDE_CONFIG_DIR="$work/config" \
    "$work/nojq/bash" "$guard" <<<"$1")
  [[ $out == *systemMessage* ]] && echo yes || echo no
}
nojq_expect() {
  local want=$1 name=$2 got
  got=$(nojq_warns "$3")
  if [[ $got == "$want" ]]; then echo "ok   $name"; else
    echo "FAIL $name: expected warning=$want, got $got" >&2
    status=1
  fi
}
p_a=$(payload Bash "$(cmd_in 'git status')" "$repo" $dev sess-A)
p_b=$(payload Bash "$(cmd_in 'git status')" "$repo" $dev sess-B)
p_n=$(payload Bash "$(cmd_in 'git status')" "$repo" $dev -)
nojq_expect yes "M8 first call of a session warns" "$p_a"
nojq_expect no "M8 second call of the same session is silent" "$p_a"
nojq_expect yes "M8 a new session id warns again" "$p_b"
nojq_expect yes "M8 no session id warns on every call (1)" "$p_n"
nojq_expect yes "M8 no session id warns on every call (2)" "$p_n"

# ---- N2 and prefilter: bounded runtime on large payloads ----
big_payload() { # <kind> -> writes $work/big.json
  local kind=$1
  {
    case $kind in
      dense) printf "bash <<'EOF'\n"; yes 'echo ab; ls "x" | wc' | head -c 200000 || true; printf '\nEOF\n' ;;
      inert) printf "gh issue create --body-file - <<'EOF'\n"; yes 'git commit text; cargo build' | head -c 200000 || true; printf '\nEOF\n' ;;
    esac
  } >"$work/big.cmd"
  jq -nc --rawfile c "$work/big.cmd" --arg cwd "$repo" --arg at "$dev" \
    '{tool_name:"Bash",session_id:"sess-big",cwd:$cwd,agent_type:$at,tool_input:{command:$c}}' >"$work/big.json"
}
bounded() { # <bash-binary> <limit-seconds>; returns 1 on timeout
  local start=$SECONDS pid
  env PATH="$work/bin:$PATH" HOME="$work/home" TMPDIR="$work/tmp" CLAUDE_CONFIG_DIR="$work/config" \
    "$1" "$guard" <"$work/big.json" >"$work/big.out" 2>&1 &
  pid=$!
  while kill -0 "$pid" 2>/dev/null; do
    if ((SECONDS - start >= $2)); then
      kill "$pid" 2>/dev/null
      wait "$pid" 2>/dev/null
      return 1
    fi
    sleep 1
  done
  wait "$pid"
}
big_check() { # <name> <kind> <bash-binary>
  big_payload "$2"
  if bounded "$3" 10; then echo "ok   $1"; else
    echo "FAIL $1: guard did not finish within 10 s" >&2
    status=1
  fi
}
big_check "prefilter 200 KB inert gh heredoc (bash)" inert bash
if [[ -x /bin/bash && $(/bin/bash -c 'echo $BASH_VERSION') == 3.2.* ]]; then
  big_check "N2 200 KB token-dense interpreter heredoc on /bin/bash 3.2" dense /bin/bash
  big_check "prefilter 200 KB inert gh heredoc on /bin/bash 3.2" inert /bin/bash
else
  echo "skip N2 /bin/bash 3.2 cases (/bin/bash is not bash 3.2 here)"
  big_check "N2 200 KB token-dense interpreter heredoc (bash)" dense bash
fi

exit "$status"
