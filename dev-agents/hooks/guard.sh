#!/usr/bin/env bash
# dev-agents PreToolUse guard: enforces role rules that prompt text alone cannot guarantee.
#
# Rules (a denial is a PreToolUse JSON decision; no output means allow):
#   1. Read-only roles (critic, code-reviewer, arch-analyst, security-analyst, researcher,
#      live-tester) may not Edit/Write/NotebookEdit an existing file inside the project root,
#      except under <root>/.local/ and the Claude config dir (agent memory).
#      New files and paths outside the root are never blocked.
#   2. While <root>/.local/protected-tests exists, nobody may edit the dedicated test files it
#      lists (one root-relative path per line), and no dev-agents role may edit the marker itself.
#   3. A resolved dev-agents role may not run `git commit` or `git push` (only the lead commits).
#   4. `cargo add`, `npm|pnpm|yarn|bun add|install|i`, and `wally|pesde add` of a plain registry
#      name are denied when the package does not exist in its registry (slopsquatting guard).
#      Hand-edited manifests only produce a warning. Network errors allow with a warning.
#
# Root: the git toplevel of the target file's nearest existing ancestor, falling back to the
# payload `cwd`. Never $CLAUDE_PROJECT_DIR: a solve-issue worktree differs from the lead's cwd.
# Paths are canonicalized (symlinks resolved, `..` after a missing segment rejected) before any
# prefix check.
#
# Role: payload `agent_type` (`dev-agents:<role>` or the bare role). When `agent_type` is absent,
# `agent_id` or `teammate_name` is looked up in the team config whose `leadSessionId` equals the
# payload `session_id`. An unresolved role fails open for rules 1 and 3.
#
# UNVERIFIED ASSUMPTION: payloads of agent-team teammates carry `agent_type`, or an `agent_id` or
# `teammate_name` that matches a member of ~/.claude/teams/<team>/config.json. Plain subagent
# payloads carry `agent_type` (documented). If teammates carry neither, rules 1 and 3 do not
# apply to them; rules 2 and 4 are role-agnostic and still do.
#
# Requires bash and jq. Without jq the hook warns and allows.

KNOWN_ROLES=" architect developer testing-engineer performance-engineer security-maintenance code-reviewer cicd-devops debugger critic sdd-orchestrator live-tester tech-writer researcher arch-analyst security-analyst "
READ_ONLY_ROLES=" critic code-reviewer arch-analyst security-analyst researcher live-tester "
MANIFESTS=" Cargo.toml package.json wally.toml pesde.toml "
MAX_DEP_CHECKS=5

if ! command -v jq >/dev/null 2>&1; then
  echo '{"systemMessage":"dev-agents hooks: jq not found, role rules are not enforced"}'
  exit 0
fi

payload=$(cat)
field() { jq -r "$1 // empty" <<<"$payload" 2>/dev/null; }

tool=$(field .tool_name)
session_id=$(field .session_id)
cwd=$(field .cwd)
agent_type=$(field .agent_type)
agent_id=$(field '.agent_id // .teammate_name')
[[ -n $cwd && -d $cwd ]] || cwd=$PWD
cfg_dir=${CLAUDE_CONFIG_DIR:-$HOME/.claude}
warnings=""

deny() {
  jq -n --arg r "$1" \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
  exit 0
}

finish() {
  if [[ -n $warnings ]]; then
    jq -n --arg m "$warnings" \
      '{systemMessage:$m,hookSpecificOutput:{hookEventName:"PreToolUse",additionalContext:$m}}'
  fi
  exit 0
}

normalize_role() {
  local r=${1#dev-agents:}
  [[ -n $r && $KNOWN_ROLES == *" $r "* ]] && echo "$r"
  return 0
}

resolve_role() {
  local r
  if [[ -n $agent_type ]]; then
    normalize_role "$agent_type"
    return 0
  fi
  [[ -n $agent_id && -n $session_id ]] || return 0
  r=$(jq -r --arg sid "$session_id" --arg id "$agent_id" '
    select(.leadSessionId == $sid) | .members[]?
    | select(.agentId == $id or .name == $id or ((.agentId // "") | split("@")[0]) == $id)
    | .agentType // empty' "$cfg_dir"/teams/*/config.json 2>/dev/null | head -n 1)
  normalize_role "$r"
}

nearest_existing_dir() {
  local d=$1
  while [[ ! -d $d ]]; do d=$(dirname "$d"); done
  echo "$d"
}

# Prints the canonical absolute path; fails when a `..` remains after a missing segment.
canon_path() {
  local p=$1 rest="" dir resolved link n=0
  [[ $p == /* ]] || p="$cwd/$p"
  while [[ -L $p && $n -lt 10 ]]; do
    link=$(readlink "$p")
    [[ $link == /* ]] && p=$link || p="$(dirname "$p")/$link"
    n=$((n + 1))
  done
  dir=$p
  while [[ ! -d $dir ]]; do
    rest="/$(basename "$dir")$rest"
    dir=$(dirname "$dir")
  done
  [[ $rest == */../* || $rest == */.. ]] && return 1
  resolved=$(cd -P "$dir" && pwd -P) || return 1
  [[ $resolved == / ]] && resolved=""
  echo "$resolved$rest"
}

root_for() {
  local top
  top=$(git -C "$(nearest_existing_dir "$1")" rev-parse --show-toplevel 2>/dev/null) ||
    top=$cwd
  (cd "$top" && pwd -P) || echo "$top"
}

role=$(resolve_role)
is_read_only() { [[ -n $role && $READ_ONLY_ROLES == *" $role "* ]]; }

same_file() { [[ $1 == "$2" || ( -e $1 && -e $2 && $1 -ef $2 ) ]]; }

in_config_dir() {
  local c
  c=$(canon_path "$cfg_dir") || return 1
  [[ $1 == "$c"/* ]]
}

lower() { tr '[:upper:]' '[:lower:]' <<<"$1"; }

# Case-insensitive volume: `.GIT` resolves in any git root only when the filesystem folds case.
case_insensitive_root() { [[ -e $1/.GIT ]]; }

# True when $1 is $2/<something> and, on a case-insensitive root, ignoring case; $3 is a subpath.
under_root() {
  local t=$1 r=$2 sub=${3:-}
  if case_insensitive_root "$r"; then
    t=$(lower "$t")
    r=$(lower "$r")
    sub=$(lower "$sub")
  fi
  [[ $t == "$r$sub"/* ]]
}

is_agent_memory() {
  under_root "$1" "$2" /.claude/agent-memory || under_root "$1" "$2" /.claude/agent-memory-local ||
    in_config_dir "$1"
}

check_file_edit() {
  local path target root marker line protected
  path=$(field '.tool_input.file_path // .tool_input.notebook_path')
  [[ -n $path ]] || finish

  if ! target=$(canon_path "$path"); then
    root=$(root_for "$cwd")
    if is_read_only || [[ -f $root/.local/protected-tests ]]; then
      deny "Path '$path' contains '..' after a missing directory and cannot be resolved; use a canonical path."
    fi
    finish
  fi
  root=$(root_for "$target")
  marker="$root/.local/protected-tests"

  if [[ -f $marker ]]; then
    if [[ -n $role ]] && same_file "$target" "$marker"; then
      deny "Only the team lead edits .local/protected-tests. Report a test that needs unprotecting with status: blocked."
    fi
    while IFS= read -r line || [[ -n $line ]]; do
      line=${line%$'\r'}
      line=${line#./}
      [[ -z $line || $line == *..* ]] && continue
      protected=$(canon_path "$root/$line") || continue
      if same_file "$target" "$protected"; then
        deny "Protected acceptance test (listed in .local/protected-tests). In a team-develop run: do not edit; report a test that contradicts the spec with status: blocked. If no team-develop run is active, the marker is stale: delete .local/protected-tests."
      fi
    done <"$marker"
  fi

  if is_read_only && [[ -e $target ]] && under_root "$target" "$root" "" &&
    ! under_root "$target" "$root" /.local && ! is_agent_memory "$target" "$root"; then
    deny "Read-only role '$role' may not modify existing files outside .local/. Report the finding in the handoff; a reproducer must be a new file."
  fi

  warn_manifest_edit "$target" "$root"
  finish
}

dep_key_regex='^[[:space:]]*"?([A-Za-z0-9@/_.-]+)"?[[:space:]]*[:=][[:space:]]*("[\^~<>=*]?[0-9][^"]*"|\{)'
non_dep_keys=" version edition rust-version name license description node npm dependencies devDependencies peerDependencies optionalDependencies bundledDependencies scripts engines overrides resolutions dev-dependencies build-dependencies "

valid_name() {
  case $1 in
    cargo) [[ $2 =~ ^[A-Za-z0-9_-]+$ ]] ;;
    npm) [[ $2 =~ ^(@[a-z0-9][a-z0-9._~-]*/)?[a-z0-9][a-z0-9._~-]*$ && $2 != *..* && $2 != *.tgz && $2 != *.tar && $2 != *.tar.gz && $2 != *.zip ]] ;;
    wally | pesde) [[ $2 =~ ^[a-z0-9_-]+/[a-z0-9_-]+$ ]] ;;
    *) return 1 ;;
  esac
}

manifest_registry() {
  case $1 in
    Cargo.toml) echo cargo ;;
    package.json) echo npm ;;
    wally.toml) echo wally ;;
    pesde.toml) echo pesde ;;
  esac
}

warn_manifest_edit() {
  local target=$1 root=$2 base kind old new line name value checked=0
  base=$(basename "$target")
  [[ $MANIFESTS == *" $base "* ]] || return 0
  kind=$(manifest_registry "$base")
  has_alt_registry "$kind" "$root" && return 0
  old=$(field '.tool_input.old_string')
  [[ -z $old && -f $target ]] && old=$(<"$target")
  new=$(field '.tool_input.new_string // .tool_input.content')
  while IFS= read -r line; do
    [[ $line =~ $dep_key_regex ]] || continue
    name=${BASH_REMATCH[1]}
    value=${BASH_REMATCH[2]}
    [[ $non_dep_keys == *" $name "* ]] && continue
    [[ $value == '{' && $kind == npm ]] && continue
    [[ $line =~ (path|git|workspace|registry)[[:space:]]*= ]] && continue
    grep -qxF -- "$line" <<<"$old" && continue
    [[ $name == @* ]] && continue
    valid_name "$kind" "$name" || continue
    checked=$((checked + 1))
    ((checked > MAX_DEP_CHECKS)) && break
    if [[ $(registry_status "$kind" "$name") == missing ]]; then
      warnings+="Dependency '$name' added to $base was not found in the $kind registry; verify the name before keeping it. "
    fi
  done <<<"$new"
}

registry_status() {
  local kind=$1 name=$2 url out code
  case $kind in
    cargo) url="https://crates.io/api/v1/crates/$name" ;;
    npm) url="https://registry.npmjs.org/$name" ;;
    wally) url="https://api.wally.run/v1/package-metadata/$name" ;;
    pesde) url="https://registry.pesde.dev/v0/packages/${name//\//%2F}/latest/any" ;;
    *) echo unknown; return 0 ;;
  esac
  out=$(curl -q -s --connect-timeout 2 -m 5 -A dev-agents-hooks -w $'\n%{http_code}' "$url" 2>/dev/null) || {
    echo unknown
    return 0
  }
  code=${out##*$'\n'}
  case $code in
    200) echo exists ;;
    404) echo missing ;;
    500) [[ $kind == wally && $out == *"No such file or directory"* ]] && echo missing || echo unknown ;;
    *) echo unknown ;;
  esac
}

default_npm_url='https?://registry\.(npmjs\.org|yarnpkg\.com)/?'

# True when a file sets a registry other than the default one (auth lines for it do not count).
npm_file_sets_registry() {
  local f
  for f in "$@"; do
    [[ -f $f ]] || continue
    grep -iE '^[[:space:]]*(@[^:=]+:)?registry[[:space:]]*=|npmRegistryServer|npmScopes|\[install\.scopes\]' "$f" |
      grep -viE "(registry[[:space:]]*=|npmRegistryServer:)[[:space:]]*\"?$default_npm_url\"?[[:space:]]*$" |
      grep -q . && return 0
  done
  return 1
}

cargo_file_sets_registry() {
  local f
  for f in "$@"; do
    [[ -f $f ]] || continue
    grep -qE '^\[registries\]|replace-with[[:space:]]*=' "$f" && return 0
    grep -E '^\[registries\.' "$f" | grep -vqE '^\[registries\.crates-io\]' && return 0
  done
  return 1
}

# True when the project, the user, or the environment configures a non-default registry.
has_alt_registry() {
  local kind=$1 root=$2 d cargo_home=${CARGO_HOME:-$HOME/.cargo}
  case $kind in
    npm)
      env | grep -iE '^npm_config_.*registry=' | grep -viE "=$default_npm_url\$" | grep -q . && return 0
      npm_file_sets_registry "$root/.npmrc" "$root/.yarnrc.yml" "$root/.yarnrc" "$root/bunfig.toml" \
        "$HOME/.npmrc" "$HOME/.yarnrc.yml" "$HOME/.yarnrc" "${NPM_CONFIG_USERCONFIG:-/nonexistent}" ;;
    cargo)
      env | grep -E '^CARGO_(REGISTRIES|SOURCE)_' | grep -vE '^CARGO_REGISTRIES_CRATES_IO_' | grep -q . && return 0
      d=$root
      while [[ -n $d ]]; do
        cargo_file_sets_registry "$d/.cargo/config.toml" "$d/.cargo/config" && return 0
        [[ $d == / ]] && break
        d=$(dirname "$d")
      done
      cargo_file_sets_registry "$cargo_home/config.toml" "$cargo_home/config" ;;
    *) return 1 ;;
  esac
}

value_flags=" -F --features -p --package --rename --manifest-path --target -t --branch --tag --rev -Z --config --prefix --save-prefix --userconfig --cache --otp -C --dir --filter --cwd --cache-dir -c --alias -a "

value_flag() {
  [[ $2 != *=* ]] || return 1
  [[ $2 == -w || $2 == --workspace ]] && [[ $1 == npm ]] && return 0
  [[ $value_flags == *" $2 "* ]]
}

# Prints the registry kind and the plain package names of one add/install command, or nothing.
plain_dep_names() {
  local -a words=("$@")
  local mgr sub kind skip=0 w name i=0 j redirect_re='^[0-9]*[<>]' op_re='^[0-9]*(>>?|<)$'
  while ((i < ${#words[@]})) && [[ ${words[i]} == [A-Za-z_]*=* || ${words[i]} == env ]]; do i=$((i + 1)); done
  mgr=${words[i]:-}
  j=$((i + 1))
  while ((j < ${#words[@]})) && [[ ${words[j]} == -* || ${words[j]} == +* ]]; do
    if [[ ${words[j]} != +* ]] && value_flag "$mgr" "${words[j]}"; then j=$((j + 2)); else j=$((j + 1)); fi
  done
  sub=${words[j]:-}
  case "$mgr $sub" in
    "cargo add") kind=cargo ;;
    "npm add" | "npm install" | "npm i" | "pnpm add" | "pnpm install" | "pnpm i" | "yarn add" | "yarn install" | "yarn i" | "bun add" | "bun install" | "bun i") kind=npm ;;
    "wally add") kind=wally ;;
    "pesde add") kind=pesde ;;
    *) return 0 ;;
  esac
  for w in "${words[@]:j+1}"; do
    case $w in
      --path | --path=* | --git | --git=* | --registry | --registry=* | --index | --index=*) return 0 ;;
    esac
  done
  echo "$kind"
  for w in "${words[@]:j+1}"; do
    if ((skip)); then skip=0; continue; fi
    w=${w#[\'\"]}
    w=${w%[\'\"]}
    if [[ $w =~ $redirect_re ]]; then
      [[ $w =~ $op_re ]] && skip=1
      continue
    fi
    if [[ $w == -* ]]; then
      value_flag "$mgr" "$w" && skip=1
      continue
    fi
    [[ $w == *:* ]] && continue
    name=$(strip_version "$kind" "$w")
    valid_name "$kind" "$name" && echo "$name"
  done
}

strip_version() {
  local rest
  if [[ $2 == @* ]]; then
    rest=${2#@}
    echo "@${rest%%@*}"
  else
    echo "${2%%@*}"
  fi
}

check_bash() {
  local cmd root nl=$'\n' git_re segment kind name status checked=0
  local -a words names
  cmd=$(field .tool_input.command)
  [[ -n $cmd ]] || finish

  git_re="(^|[;&|(\`$nl]|\\\$\\(|(bash|sh|zsh)[[:space:]]+-c[[:space:]]+['\"])[[:space:]]*(env[[:space:]]+)?([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+)*git([[:space:]]+(-[Cc][[:space:]]+[^[:space:]]+|--?[A-Za-z][A-Za-z-]*(=[^[:space:]]*)?))*[[:space:]]+(commit|push)([[:space:]]|\$|[;&|)'\"])"
  if [[ -n $role && $cmd =~ $git_re ]]; then
    deny "Role '$role' may not run git commit or git push; only the team lead commits and pushes. Report the change set in the handoff."
  fi

  root=$(root_for "$cwd")
  while IFS= read -r segment; do
    read -r -a words <<<"$segment"
    names=()
    while IFS= read -r name; do names+=("$name"); done < <(plain_dep_names "${words[@]+"${words[@]}"}")
    ((${#names[@]} > 1)) || continue
    kind=${names[0]}
    has_alt_registry "$kind" "$root" && continue
    for name in "${names[@]:1}"; do
      checked=$((checked + 1))
      ((checked > MAX_DEP_CHECKS)) && break 2
      status=$(registry_status "$kind" "$name")
      case $status in
        missing)
          if [[ $kind == npm && $name == @* ]]; then
            warnings+="Scoped package '$name' was not found on the public npm registry; it may live on a private registry, check the name manually. "
          else
            deny "Package '$name' does not exist in the $kind registry. LLM-suggested names are often hallucinated and can be pre-registered by attackers (slopsquatting). Verify the exact name with context7 or the registry website, then retry."
          fi ;;
        unknown) warnings+="Could not verify '$name' in the $kind registry (network error); check the name manually. " ;;
      esac
    done
  done < <(tr ';&|' '\n' <<<"$cmd")
  finish
}

case $tool in
  Edit | Write | NotebookEdit) check_file_edit ;;
  Bash) check_bash ;;
esac
exit 0
