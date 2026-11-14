#!/usr/bin/env bash
# Feeds synthetic PreToolUse payloads to dev-agents/hooks/guard.sh and checks allow/deny.
# Registry lookups use a stub curl, so the run is offline and deterministic.
set -euo pipefail

guard=$(cd "$(dirname "$0")/../.." && pwd -P)/dev-agents/hooks/guard.sh
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
work=$(cd "$work" && pwd -P)
status=0

mkdir -p "$work/bin" "$work/config/teams/t1" "$work/config/teams/t2" \
  "$work/repo/src" "$work/repo/.local" "$work/repo/tests" "$work/other/src" "$work/memory" "$work/home"
git -C "$work/repo" init -q
git -C "$work/other" init -q
git -C "$work/config" init -q
mkdir -p "$work/config/agent-memory/x"
touch "$work/config/agent-memory/x/MEMORY.md"
touch "$work/repo/src/a.rs" "$work/repo/tests/t.rs" "$work/other/src/b.rs" "$work/memory/MEMORY.md"
printf 'tests/t.rs\n' >"$work/repo/.local/protected-tests"

cat >"$work/bin/curl" <<'EOF'
#!/usr/bin/env bash
url=${*: -1}
[[ $1 == -q ]] || exit 7
case $url in
  *zzz-neterr*) exit 6 ;;
  *zzz-missing*) printf '\n404' ;;
  *) printf '{}\n200' ;;
esac
EOF
chmod +x "$work/bin/curl"

cat >"$work/config/teams/t1/config.json" <<'EOF'
{"leadSessionId":"sess-1","members":[
 {"agentId":"critic-1@t1","name":"critic-1","agentType":"dev-agents:critic"},
 {"agentId":"developer-1@t1","name":"developer-1","agentType":"dev-agents:developer"}]}
EOF
cat >"$work/config/teams/t2/config.json" <<'EOF'
{"leadSessionId":"sess-2","members":[
 {"agentId":"critic-2@t2","name":"critic-2","agentType":"dev-agents:critic"}]}
EOF

extra_env=()

run() {
  env -u CARGO_HOME -u NPM_CONFIG_USERCONFIG "${extra_env[@]+"${extra_env[@]}"}" PATH="$work/bin:$PATH" HOME="$work/home" CLAUDE_CONFIG_DIR="$work/config" CLAUDE_PROJECT_DIR=/nonexistent \
    bash "$guard" <<<"$1"
}

payload() {
  jq -nc --arg tool "$1" --arg input "$2" --arg cwd "$3" --arg at "${4:-}" --arg aid "${5:-}" --arg sid "${6:-sess-1}" '
    {tool_name: $tool, session_id: $sid, cwd: $cwd, tool_input: ($input | fromjson)}
    + (if $at != "" then {agent_type: $at} else {} end)
    + (if $aid != "" then {agent_id: $aid} else {} end)'
}

expect() {
  local want=$1 name=$2 out got=allow reason
  out=$(run "$3")
  jq -e '.hookSpecificOutput.permissionDecision == "deny"' <<<"$out" >/dev/null 2>&1 && got=deny
  if [[ $got == "$want" ]]; then
    reason=$(jq -r '.hookSpecificOutput.permissionDecisionReason // empty' <<<"$out" 2>/dev/null)
    echo "ok   $name${reason:+ -> $reason}"
  else
    echo "FAIL $name: expected $want, got $got: $out" >&2
    status=1
  fi
}

expect_warning() {
  local want=$1 name=$2 out got=no
  out=$(run "$3")
  jq -e '.systemMessage // empty' <<<"$out" >/dev/null 2>&1 && got=yes
  if [[ $got == "$want" ]]; then
    echo "ok   $name"
  else
    echo "FAIL $name: expected warning=$want, got $got: $out" >&2
    status=1
  fi
}

file_in() { jq -nc --arg p "$1" '{file_path: $p}'; }
cmd_in() { jq -nc --arg c "$1" '{command: $c}'; }
repo=$work/repo

# Rule 1 and D1/D2: read-only role, root from the target file, canonical paths
expect deny "D1 read-only role edits existing file in another repo than cwd" \
  "$(payload Edit "$(file_in "$work/other/src/b.rs")" "$repo" dev-agents:critic)"
expect deny "rule 1 bare role name resolves" \
  "$(payload Write "$(file_in "$repo/src/a.rs")" "$repo" critic)"
expect allow "rule 1 new file is allowed" \
  "$(payload Write "$(file_in "$repo/tests/new_repro.rs")" "$repo" dev-agents:critic)"
expect allow "rule 1 write under .local is allowed" \
  "$(payload Write "$(file_in "$repo/.local/handoff/x.md")" "$repo" dev-agents:critic)"
expect deny "D2 .local/../src traversal on an existing file" \
  "$(payload Edit "$(file_in "$repo/.local/../src/a.rs")" "$repo" dev-agents:critic)"
expect deny "D2 unresolvable .. after a missing directory" \
  "$(payload Write "$(file_in "$repo/.local/missing/../../src/a.rs")" "$repo" dev-agents:critic)"
expect allow "D2 agent memory outside the root is never blocked" \
  "$(payload Write "$(file_in "$work/memory/MEMORY.md")" "$repo" dev-agents:critic)"
expect allow "M9 agent memory inside a git root that holds the config dir is exempt" \
  "$(payload Write "$(file_in "$work/config/agent-memory/x/MEMORY.md")" "$work/config" dev-agents:critic)"
expect allow "rule 1 developer role may edit source" \
  "$(payload Edit "$(file_in "$repo/src/a.rs")" "$repo" dev-agents:developer)"
expect allow "unresolved role fails open" \
  "$(payload Edit "$(file_in "$repo/src/a.rs")" "$repo")"
expect allow "other plugin agent type fails open" \
  "$(payload Edit "$(file_in "$repo/src/a.rs")" "$repo" other:critic)"

# Rule 2 and D3: protected tests and marker
expect deny "rule 2 protected test denied for the main session" \
  "$(payload Edit "$(file_in "$repo/tests/t.rs")" "$repo")"
expect deny "rule 2 protected test denied for developer" \
  "$(payload Edit "$(file_in "$repo/tests/./t.rs")" "$repo" dev-agents:developer)"
expect allow "rule 2 unlisted test file allowed" \
  "$(payload Write "$(file_in "$repo/tests/other.rs")" "$repo" dev-agents:developer)"
expect deny "D3 role cannot edit the marker" \
  "$(payload Write "$(file_in "$repo/.local/protected-tests")" "$repo" dev-agents:developer)"
expect allow "D3 main session may edit the marker" \
  "$(payload Write "$(file_in "$repo/.local/protected-tests")" "$repo")"

# D4: team lookup by leadSessionId when agent_type is absent
expect deny "D4 teammate resolved through the matching team" \
  "$(payload Edit "$(file_in "$repo/src/a.rs")" "$repo" "" critic-1@t1 sess-1)"
expect allow "D4 same agent_id with another session_id fails open" \
  "$(payload Edit "$(file_in "$repo/src/a.rs")" "$repo" "" critic-1@t1 sess-3)"
expect allow "D4 member of a different team is not resolved" \
  "$(payload Edit "$(file_in "$repo/src/a.rs")" "$repo" "" critic-2@t2 sess-1)"

# Rule 3: git commit and push
expect deny "rule 3 developer git commit" \
  "$(payload Bash "$(cmd_in 'git add -A && git commit -m x')" "$repo" dev-agents:developer)"
expect deny "rule 3 git push with global flags" \
  "$(payload Bash "$(cmd_in 'git -C . push origin HEAD')" "$repo" dev-agents:testing-engineer)"
expect deny "rule 3 bash -c wrapper" \
  "$(payload Bash "$(cmd_in "bash -c 'git commit -m x'")" "$repo" dev-agents:debugger)"
expect allow "rule 3 git status allowed" \
  "$(payload Bash "$(cmd_in 'git status && git diff')" "$repo" dev-agents:developer)"
expect allow "rule 3 mention inside grep allowed" \
  "$(payload Bash "$(cmd_in 'grep "git commit" README.md')" "$repo" dev-agents:developer)"
expect allow "rule 3 main session may commit" \
  "$(payload Bash "$(cmd_in 'git commit -m x')" "$repo")"

# Rule 4: registry existence
expect deny "rule 4 cargo add of a missing crate" \
  "$(payload Bash "$(cmd_in 'cargo add serde zzz-missing-crate --features derive')" "$repo")"
expect allow "rule 4 cargo add of existing crates, feature value not treated as a crate" \
  "$(payload Bash "$(cmd_in 'cargo add serde --features zzz-missing-feature')" "$repo")"
expect deny "rule 4 npm install of a missing package" \
  "$(payload Bash "$(cmd_in 'npm install -D zzz-missing-pkg@1.2.3')" "$repo")"
expect allow "rule 4 npm install without names" \
  "$(payload Bash "$(cmd_in 'npm install')" "$repo")"
expect allow "rule 4 cargo add --path is not checked" \
  "$(payload Bash "$(cmd_in 'cargo add zzz-missing-crate --path ../x')" "$repo")"
expect allow "rule 4 npm file: spec is not checked" \
  "$(payload Bash "$(cmd_in 'npm install file:../zzz-missing-pkg')" "$repo")"
expect allow "rule 4 network error allows" \
  "$(payload Bash "$(cmd_in 'cargo add zzz-neterr')" "$repo")"
expect deny "rule 4 pesde add of a missing package" \
  "$(payload Bash "$(cmd_in 'pesde add scope/zzz-missing')" "$repo")"
printf 'registry=https://example.invalid/\n' >"$repo/.npmrc"
expect allow "rule 4 project with an alternative npm registry is skipped" \
  "$(payload Bash "$(cmd_in 'npm install zzz-missing-pkg')" "$repo")"
rm "$repo/.npmrc"

# Review fixes: agent memory in the project, symlink '..', CRLF marker, case folding
mkdir -p "$repo/.claude/agent-memory-local/r" "$repo/.claude/agent-memory/r" "$work/out"
touch "$repo/.claude/agent-memory-local/r/MEMORY.md" "$repo/.claude/agent-memory/r/MEMORY.md"
expect allow "S1 agent-memory-local inside the root is exempt" \
  "$(payload Write "$(file_in "$repo/.claude/agent-memory-local/r/MEMORY.md")" "$repo" dev-agents:researcher)"
expect allow "S1 agent-memory inside the root is exempt" \
  "$(payload Write "$(file_in "$repo/.claude/agent-memory/r/MEMORY.md")" "$repo" dev-agents:live-tester)"

ln -s "$repo/tests" "$work/out/link"
expect deny "L1 symlink/.. resolves physically" \
  "$(payload Edit "$(file_in "$work/out/link/../src/a.rs")" "$repo" dev-agents:critic)"

printf 'tests/crlf.rs\r\n' >>"$repo/.local/protected-tests"
touch "$repo/tests/crlf.rs"
expect deny "S3 CRLF marker line still protects" \
  "$(payload Edit "$(file_in "$repo/tests/crlf.rs")" "$repo" dev-agents:developer)"

if [[ -e $repo/.GIT ]]; then
  expect deny "M1 case-variant protected test" \
    "$(payload Edit "$(file_in "$repo/tests/T.RS")" "$repo" dev-agents:developer)"
  expect deny "M1 case-variant marker" \
    "$(payload Write "$(file_in "$repo/.local/PROTECTED-TESTS")" "$repo" dev-agents:developer)"
  expect deny "M1 case-variant repo prefix" \
    "$(payload Edit "$(file_in "$work/REPO/src/a.rs")" "$repo" dev-agents:critic)"
else
  echo "skip M1 case-insensitivity cases (case-sensitive volume)"
fi

printf '@corp:registry=https://example.invalid/\n' >"$work/home/.npmrc"
expect allow "S2 user-level npm registry config skips the check" \
  "$(payload Bash "$(cmd_in 'npm install zzz-missing-pkg')" "$repo")"
rm "$work/home/.npmrc"
expect allow "S2 scoped package missing on public npm only warns" \
  "$(payload Bash "$(cmd_in 'npm install @corp/zzz-missing')" "$repo")"
expect_warning yes "S2 scoped package missing carries a warning" \
  "$(payload Bash "$(cmd_in 'npm install @corp/zzz-missing')" "$repo")"
expect allow "S2 tarball spec is not a registry name" \
  "$(payload Bash "$(cmd_in 'npm install zzz-missing.tgz')" "$repo")"
expect allow "S2 npm: alias is not a registry name" \
  "$(payload Bash "$(cmd_in 'npm install foo@npm:zzz-missing')" "$repo")"
expect allow "S5 redirect target is not a package" \
  "$(payload Bash "$(cmd_in 'npm install lodash > zzz-missing.txt')" "$repo")"
expect deny "S5 pnpm add -w still checks the package" \
  "$(payload Bash "$(cmd_in 'pnpm add -w zzz-missing-pkg')" "$repo")"
expect deny "pnpm --workspace is boolean: the name before it is checked" \
  "$(payload Bash "$(cmd_in 'pnpm add zzz-missing-pkg --workspace')" "$repo")"
expect deny "pnpm --workspace is boolean: the name after it is checked" \
  "$(payload Bash "$(cmd_in 'pnpm add --workspace zzz-missing-pkg')" "$repo")"
expect allow "npm -w takes a value: the workspace name is not a package" \
  "$(payload Bash "$(cmd_in 'npm install -w zzz-missing-ws lodash')" "$repo")"
expect deny "npm -w takes a value: the following name is checked" \
  "$(payload Bash "$(cmd_in 'npm install -w pkg-a zzz-missing-pkg')" "$repo")"
expect deny "S5 quoted package name" \
  "$(payload Bash "$(cmd_in 'npm install "zzz-missing-pkg"')" "$repo")"
expect deny "S5 cargo +toolchain add" \
  "$(payload Bash "$(cmd_in 'cargo +nightly add zzz-missing-crate')" "$repo")"
expect deny "S5 npm global flag before install" \
  "$(payload Bash "$(cmd_in 'npm --prefix x install zzz-missing-pkg')" "$repo")"

# S10: only a non-default registry disables rule 4
printf '//registry.npmjs.org/:_authToken=secret\n' >"$work/home/.npmrc"
expect deny "S10 npm auth line for the default registry keeps rule 4 on" \
  "$(payload Bash "$(cmd_in 'npm install zzz-missing-pkg')" "$repo")"
printf 'registry=https://registry.npmjs.org/\n' >"$work/home/.npmrc"
expect deny "S10 explicit default npm registry keeps rule 4 on" \
  "$(payload Bash "$(cmd_in 'npm install zzz-missing-pkg')" "$repo")"
printf 'registry=https://npm.example.invalid/\n' >"$work/home/.npmrc"
expect allow "S10 custom npm registry turns rule 4 off" \
  "$(payload Bash "$(cmd_in 'npm install zzz-missing-pkg')" "$repo")"
rm "$work/home/.npmrc"
mkdir -p "$work/home/.cargo"
printf '[registries.crates-io]\nprotocol = "sparse"\n' >"$work/home/.cargo/config.toml"
expect deny "S10 crates-io protocol setting keeps rule 4 on" \
  "$(payload Bash "$(cmd_in 'cargo add zzz-missing-crate')" "$repo")"
extra_env=(CARGO_REGISTRIES_CRATES_IO_PROTOCOL=sparse)
expect deny "S10 CARGO_REGISTRIES_CRATES_IO_* env keeps rule 4 on" \
  "$(payload Bash "$(cmd_in 'cargo add zzz-missing-crate')" "$repo")"
extra_env=()
printf '[registries.corp]\nindex = "sparse+https://cargo.example.invalid/"\n' >"$work/home/.cargo/config.toml"
expect allow "S10 custom cargo registry turns rule 4 off" \
  "$(payload Bash "$(cmd_in 'cargo add zzz-missing-crate')" "$repo")"
printf '[source.crates-io]\nreplace-with = "mirror"\n' >"$work/home/.cargo/config.toml"
expect allow "S10 cargo source replacement turns rule 4 off" \
  "$(payload Bash "$(cmd_in 'cargo add zzz-missing-crate')" "$repo")"
rm "$work/home/.cargo/config.toml"

manifest() { payload Write "$(jq -nc --arg p "$repo/$1" --arg c "$2" '{file_path: $p, content: $c}')" "$repo"; }
expect_warning yes "M5 hand-added missing crate warns" \
  "$(manifest Cargo.toml $'[dependencies]\nzzz-missing-ext = "1"\n')"
expect_warning no "M5 path dependency is not looked up" \
  "$(manifest Cargo.toml $'[dependencies]\nzzz-missing-int = { path = "../x" }\n')"
expect_warning no "M5 workspace dependency is not looked up" \
  "$(manifest Cargo.toml $'[dependencies]\nzzz-missing-ws = { workspace = true }\n')"
expect_warning no "M5 container keys are not looked up" \
  "$(manifest package.json $'{\n"devDependencies": {\n"scripts": {\n}}')"
expect_warning no "S10 scoped names in manifest edits are not looked up" \
  "$(manifest package.json '{"@corp/zzz-missing": "1.0.0"}')"
expect_warning no "M5 names with .. are rejected" \
  "$(manifest package.json '{"../../zzz-missing": "1.0.0"}')"

exit "$status"
