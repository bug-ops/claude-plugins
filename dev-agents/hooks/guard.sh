#!/usr/bin/env bash
# dev-agents PreToolUse guard: enforces role rules that prompt text alone cannot guarantee.
#
# Rules (a denial is a PreToolUse JSON decision; no output means allow):
#   1. Read-only roles (critic, code-reviewer, arch-analyst, security-analyst, researcher,
#      live-tester) may not Edit/Write/NotebookEdit an existing file inside the project root,
#      except under <root>/.local/ and the Claude config dir (agent memory), and except a file
#      the same role created with Write in the same session (recorded at PreToolUse, so a denied
#      or failed Write still leaves a record). New files and paths outside the root are never
#      blocked.
#   2. While <root>/.local/protected-tests exists, nobody may edit the dedicated test files it
#      lists (one root-relative path per line), and no dev-agents role may edit the marker itself.
#   3. A resolved dev-agents role may not run `git commit` or `git push` (only the lead commits).
#   4. `cargo add`, `npm|pnpm|yarn|bun add|install|i`, and `wally|pesde add` of a plain registry
#      name are denied when the package does not exist in its registry (slopsquatting guard).
#      An existing crates.io or npm package younger than DEV_AGENTS_DEP_MIN_AGE_DAYS (30) or with
#      fewer than DEV_AGENTS_DEP_MIN_DOWNLOADS (100) recent downloads only warns. Hand-edited
#      manifests only produce warnings. Network errors allow with a warning.
#
# Rules 3 and 4 read the command through a small shell tokenizer (quotes, heredocs, `$(...)`,
# backticks, `bash -c`, `eval`, and the `env`/`sudo`/`xargs`/... prefixes, including every wrapper
# Claude Code's own permission matcher strips). Commands over 32 KB are
# not checked (warning). Known misses: aliases, functions, scripts, variables,
# `ssh host <<EOF` and `bash <(...)` bodies, a non-literal command word such as `"$(which git)"`.
#
# Root: the git toplevel of the target file's nearest existing ancestor, falling back to the
# payload `cwd`. Never $CLAUDE_PROJECT_DIR: a solve-issue worktree differs from the lead's cwd.
# Paths are canonicalized (symlinks resolved, `..` after a missing segment rejected) before any
# prefix check.
#
# Role: payload `agent_type` (`dev-agents:<role>` or the bare role; a user-defined agent named like a
# dev-agents role is treated as that role). When `agent_type` is absent,
# `agent_id` or `teammate_name` is looked up in the team config whose `leadSessionId` equals the
# payload `session_id`. An unresolved role fails open for rules 1 and 3.
#
# UNVERIFIED ASSUMPTION: payloads of agent-team teammates carry `agent_type`, or an `agent_id` or
# `teammate_name` that matches a member of ~/.claude/teams/<team>/config.json. Plain subagent
# payloads carry `agent_type` (documented). If teammates carry neither, rules 1 and 3 do not
# apply to them; rules 2 and 4 are role-agnostic and still do.
#
# Requires bash and jq. Without jq the hook warns (once per session) and allows.
# State (jq warning markers, created-file records, lookup temp files) lives in
# ${TMPDIR:-/tmp}/dev-agents-guard-$UID, used only when it is owned by the user and not a symlink.

LC_ALL=C
KNOWN_ROLES=" architect developer testing-engineer performance-engineer security-maintenance code-reviewer cicd-devops debugger critic sdd-orchestrator live-tester tech-writer researcher arch-analyst security-analyst "
READ_ONLY_ROLES=" critic code-reviewer arch-analyst security-analyst researcher live-tester "
MANIFESTS=" Cargo.toml package.json wally.toml pesde.toml "
MAX_DEP_CHECKS=5
MAX_TOKENIZE_BYTES=32768
LOOKUP_BUDGET_SECONDS=15
TOKENIZE_BUDGET_SECONDS=20
tmp_files=()
trap 'rm -f "${tmp_files[@]}"' EXIT

ensure_state_dir() {
  [[ -n ${STATE_DIR:-} ]] && return 0
  local d=${TMPDIR:-/tmp}/dev-agents-guard-$UID
  [[ -L $d ]] && return 1
  [[ -d $d ]] || mkdir -m 700 "$d" 2>/dev/null
  [[ -d $d && ! -L $d && -O $d ]] || return 1
  STATE_DIR=$d
}

safe_id() { echo "${1//[^A-Za-z0-9_-]/_}"; }

payload=$(cat)

if ! command -v jq >/dev/null 2>&1; then
  re_sid='"session_id"[[:space:]]*:[[:space:]]*"([^"]*)"'
  if [[ $payload =~ $re_sid && -n ${BASH_REMATCH[1]} ]] && ensure_state_dir; then
    marker=$STATE_DIR/nojq-$(safe_id "${BASH_REMATCH[1]}")
    [[ -e $marker ]] && exit 0
    : >"$marker"
  fi
  echo '{"systemMessage":"dev-agents hooks: jq not found, role rules are not enforced"}'
  exit 0
fi

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

created_record() { [[ -n $session_id ]] && ensure_state_dir && echo "$STATE_DIR/created-$(safe_id "$session_id")"; }

record_created() {
  local f
  [[ $1 == *[[:cntrl:]]* ]] && return 0
  f=$(created_record) || return 0
  printf '%s\t%s\n' "$role" "$1" >>"$f"
}

created_by_role() {
  local f
  f=$(created_record) || return 1
  grep -qxF -- "$role"$'\t'"$1" "$f" 2>/dev/null
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

  if is_read_only && under_root "$target" "$root" "" &&
    ! under_root "$target" "$root" /.local && ! is_agent_memory "$target" "$root"; then
    if [[ ! -e $target ]]; then
      [[ $tool == Write ]] && record_created "$target"
    elif ! created_by_role "$target"; then
      deny "Read-only role '$role' may not modify existing files outside .local/ except a reproducer it created in this session. Report the finding in the handoff; a reproducer must be a new file."
    fi
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
    registry_lookup "$kind" "$name"
    if [[ $REG_STATUS == missing ]]; then
      warnings+="Dependency '$name' added to $base was not found in the $kind registry; verify the name before keeping it. "
    fi
  done <<<"$new"
}

positive_int_env() { [[ ${!1:-} =~ ^[0-9]+$ ]] && echo "$((10#${!1}))" || echo "$2"; }

# Sets HTTP_CODE (empty on a curl failure) and HTTP_BODY, a temp file that never enters a bash variable.
http_get() {
  local dir=${TMPDIR:-/tmp}
  ensure_state_dir && dir=$STATE_DIR
  HTTP_CODE=""
  HTTP_BODY=$(mktemp "$dir/lookup.XXXXXX" 2>/dev/null) || return 1
  tmp_files+=("$HTTP_BODY")
  HTTP_CODE=$(curl -q -s --compressed --max-filesize 67108864 --connect-timeout 2 -m 5 -A dev-agents-hooks -o "$HTTP_BODY" -w '%{http_code}' "$1" 2>/dev/null) || HTTP_CODE=""
}

# Sets REG_STATUS (exists|missing|unknown); an existing package that is young or little used adds a warning.
registry_lookup() {
  local kind=$1 name=$2 url
  REG_STATUS=unknown
  ((SECONDS <= LOOKUP_BUDGET_SECONDS)) || return 0
  case $kind in
    cargo) url="https://crates.io/api/v1/crates/$name" ;;
    npm) url="https://registry.npmjs.org/$name" ;;
    wally) url="https://api.wally.run/v1/package-metadata/$name" ;;
    pesde) url="https://registry.pesde.dev/v0/packages/${name//\//%2F}/latest/any" ;;
    *) return 0 ;;
  esac
  http_get "$url" || return 0
  case $HTTP_CODE in
    200) REG_STATUS=exists ;;
    404) REG_STATUS=missing ;;
    500) [[ $kind == wally ]] && grep -q 'No such file or directory' "$HTTP_BODY" && REG_STATUS=missing ;;
  esac
  [[ $REG_STATUS == exists ]] && registry_maturity "$kind" "$name"
  rm -f "$HTTP_BODY"
  return 0
}

# Warns only on positive evidence: a missing field in a 200 response never warns.
registry_maturity() {
  local kind=$1 name=$2 created dl="" window min_age min_dl age unverified=0
  case $kind in
    cargo)
      created=$(jq -r '.crate.created_at // empty | .[0:19] + "Z" | fromdateiso8601' "$HTTP_BODY" 2>/dev/null)
      dl=$(jq -r '.crate.recent_downloads // empty' "$HTTP_BODY" 2>/dev/null)
      window="the last 90 days (crates.io)" ;;
    npm)
      created=$(jq -r '.time.created // empty | .[0:19] + "Z" | fromdateiso8601' "$HTTP_BODY" 2>/dev/null)
      rm -f "$HTTP_BODY"
      window="the last month (npm)"
      HTTP_CODE=""
      if ((SECONDS <= LOOKUP_BUDGET_SECONDS)); then
        http_get "https://api.npmjs.org/downloads/point/last-month/$name"
      fi
      if [[ $HTTP_CODE == 200 ]]; then
        dl=$(jq -r '.downloads // empty' "$HTTP_BODY" 2>/dev/null)
      else
        unverified=1
      fi ;;
    *) return 0 ;;
  esac
  min_age=$(positive_int_env DEV_AGENTS_DEP_MIN_AGE_DAYS 30)
  min_dl=$(positive_int_env DEV_AGENTS_DEP_MIN_DOWNLOADS 100)
  if [[ $created =~ ^[0-9]+$ ]]; then
    age=$((($(date +%s) - created) / 86400))
    ((age < min_age)) && warnings+="Package '$name' was first published $age day(s) ago on the $kind registry (threshold $min_age); verify it is the package you mean. "
  fi
  if [[ $dl =~ ^[0-9]+$ ]]; then
    ((dl < min_dl)) && warnings+="Package '$name' has only $dl downloads in $window (threshold $min_dl); verify it is the package you mean. "
  fi
  ((unverified)) && warnings+="Downloads of '$name' not verified (the npm downloads API failed). "
  return 0
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

# Sets dep_kind and dep_names (plain, literal package names) for the add/install command whose
# manager word is words[$1]; dep_kind stays empty when the command is not a registry install.
plain_dep_names() {
  local mgr sub kind skip=0 w name j=$1 k n=${#words[@]}
  dep_kind=""
  dep_names=()
  mgr=${words[j]##*/}
  j=$((j + 1))
  while ((j < n)) && [[ ${words[j]} == -* || ${words[j]} == +* ]]; do
    if [[ ${words[j]} != +* ]] && value_flag "$mgr" "${words[j]}"; then j=$((j + 2)); else j=$((j + 1)); fi
  done
  sub=${words[j]:-}
  if [[ $mgr == yarn && $sub == workspace ]]; then
    j=$((j + 2))
    sub=${words[j]:-}
  fi
  case "$mgr $sub" in
    "cargo add") kind=cargo ;;
    "npm add" | "npm install" | "npm i" | "pnpm add" | "pnpm install" | "pnpm i" | "yarn add" | "yarn install" | "yarn i" | "bun add" | "bun install" | "bun i") kind=npm ;;
    "wally add") kind=wally ;;
    "pesde add") kind=pesde ;;
    *) return 0 ;;
  esac
  for ((k = j + 1; k < n; k++)); do
    case ${words[k]} in
      --path | --path=* | --git | --git=* | --registry | --registry=* | --index | --index=*) return 0 ;;
    esac
  done
  dep_kind=$kind
  for ((k = j + 1; k < n; k++)); do
    w=${words[k]}
    if ((skip)); then skip=0; continue; fi
    if [[ $w == -* ]]; then
      value_flag "$mgr" "$w" && skip=1
      continue
    fi
    [[ ${lits[k]} == 1 && $w != *:* ]] || continue
    name=$(strip_version "$kind" "$w")
    valid_name "$kind" "$name" && dep_names+=("$name")
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

# ---- shell tokenizer for rules 3 and 4 (bash 3.2: no associative arrays, mapfile, or negative indexes) ----
# State is shared through dynamic scoping: $s is the unread text, and each tok_loop frame owns the
# words, lits (1 = literal word), and heredoc queue of the command being read.
re_blank='^[[:blank:]]+'
re_op='^(&&|\|\||;;|\|&|[;&|()])'
re_redir='^(<<<|<<-?|<>|>>|>\||>&|<&|[<>])'
re_lit=$'^[^[:space:]$\'"\\\\;&|()<>`*?[]+'
re_glob='^[*?[]+'
re_sq="^'[^']*'"
re_ansi=$'^\\$\'([^\'\\\\]|\\\\.)*\''
re_dq_lit='^[^"\\$`]+'
re_brace='^\$\{[^}]*\}'
re_var='^\$([A-Za-z_][A-Za-z0-9_]*|[0-9@*#?$!-])'
re_comment=$'^#[^\n]*'
re_body_skip='^[^$`\\]+'
re_fd='^([0-9]+|\{[A-Za-z_][A-Za-z0-9_]*\})$'
re_arith_skip='^[^()$`]+'
re_assign='^[A-Za-z_][A-Za-z0-9_]*='
re_cflag='^-[A-Za-z]*c[A-Za-z]*$'
re_shell_valopt='^([-+][A-Za-z]*[oO]|--rcfile|--init-file)$'
# Prefilter patterns tolerate quotes and backslashes between letters (`g"i"t`, `c\ommit`) without rewriting the text.
re_gap=$'([\\\\"\']|\\\\\n)*'
fuzzy() { # <word> -> regex matching the word with quote or backslash noise between its letters
  local w=$1 out="" i
  for ((i = 0; i < ${#w}; i++)); do out+="${w:i:1}$re_gap"; done
  echo "$out"
}
re_git=$(fuzzy git)
re_subcmd="($(fuzzy commit)|$(fuzzy push))"
re_mgr="(^|[^[:alnum:]_-])($(fuzzy cargo)|$(fuzzy npm)|$(fuzzy pnpm)|$(fuzzy yarn)|$(fuzzy bun)|$(fuzzy wally)|$(fuzzy pesde))([^[:alnum:]_-]|\$)"
re_verb="(^|[^[:alnum:]_-])($(fuzzy add)|$(fuzzy install)|$(fuzzy i))([^[:alnum:]_-]|\$)"

tok_nest=0
interp_depth=0
dep_checks=0

tok_run() {
  tok_nest=$((tok_nest + 1))
  if ((tok_nest > 16)); then
    warn_unchecked "is nested too deeply"
    s=""
  fi
  tok_loop "$1"
  tok_nest=$((tok_nest - 1))
}

warn_unchecked() {
  [[ $warnings == *"was not checked"* ]] ||
    warnings+="Command $1 and was not checked for git commit/push or dependency installs. "
}

# Tokenizes nested shell text: a bash -c argument, eval arguments, env -S, or a heredoc fed to a shell.
tok_string() {
  if ((interp_depth >= 3)); then
    warn_unchecked "nests bash -c, eval, or heredoc scripts too deeply"
    return 0
  fi
  interp_depth=$((interp_depth + 1))
  local s=$1
  tok_run top
  interp_depth=$((interp_depth - 1))
}

tok_end_word() {
  ((have_word)) || return 0
  if ((want_delim)); then
    hd_delim+=("$word")
    hd_quoted+=("$quoted")
    hd_dash+=("$want_dash")
    want_delim=0
  elif ((want_here)); then
    hs_text+=("$word")
    want_here=0
  elif ((redir)); then
    redir=0
  else
    words+=("$word")
    lits+=("$((1 - nonlit))")
  fi
  word=""
  nonlit=0
  quoted=0
  have_word=0
}

tok_end_command() {
  tok_end_word
  if ((${#words[@]} > 0)); then tok_emit; fi
  words=()
  lits=()
  redir=0
  want_delim=0
  want_here=0
}

# Skips arithmetic text (so `<<` is a shift, not a heredoc); $s starts after the opening "((".
# Returns 1 when the span is not arithmetic (`((cmd) ; x)` closes its first paren without a second one).
tok_arith() {
  local depth=2
  while [[ -n $s ]]; do
    if [[ ${s:0:256} =~ $re_arith_skip ]]; then
      s=${s:${#BASH_REMATCH[0]}}
    elif [[ ${s:0:2} == '$(' && ${s:0:3} != '$((' ]]; then
      s=${s:2}
      tok_run sub
    elif [[ $s == '`'* ]]; then
      s=${s:1}
      tok_run bt
    elif [[ $s == '('* ]]; then
      depth=$((depth + 1))
      s=${s:1}
    elif [[ $s == ')'* ]]; then
      depth=$((depth - 1))
      s=${s:1}
      if ((depth == 1)) && [[ $s != ')'* ]]; then return 1; fi
      ((depth > 0)) || return 0
    else
      s=${s:1}
    fi
  done
}

tok_dollar() {
  have_word=1
  if [[ ${s:0:3} == '$((' ]]; then
    nonlit=1
    local saved=$s
    s=${s:3}
    if ! tok_arith; then
      s=${saved:2}
      tok_run sub
    fi
  elif [[ ${s:0:2} == '$(' ]]; then
    nonlit=1
    s=${s:2}
    tok_run sub
  elif [[ $s =~ $re_brace || ${s:0:256} =~ $re_var ]]; then
    nonlit=1
    s=${s:${#BASH_REMATCH[0]}}
  else
    word+='$'
    s=${s:1}
  fi
}

tok_squote() {
  local m
  quoted=1
  have_word=1
  if [[ $s =~ $re_sq ]]; then
    m=${BASH_REMATCH[0]}
    word+=${m:1:${#m}-2}
    s=${s:${#m}}
  else
    word+=${s:1}
    s=""
  fi
}

tok_dquote() {
  quoted=1
  have_word=1
  s=${s:1}
  while [[ -n $s ]]; do
    if [[ ${s:0:256} =~ $re_dq_lit ]]; then
      word+=${BASH_REMATCH[0]}
      s=${s:${#BASH_REMATCH[0]}}
    elif [[ $s == '"'* ]]; then
      s=${s:1}
      return 0
    elif [[ $s == '`'* ]]; then
      nonlit=1
      s=${s:1}
      tok_run bt
    elif [[ $s == '\'* ]]; then
      case ${s:1:1} in
        '$' | '`' | '"' | '\') word+=${s:1:1}; s=${s:2} ;;
        $'\n') s=${s:2} ;;
        *) word+='\'; s=${s:1} ;;
      esac
    else
      tok_dollar
    fi
  done
}

# Reads the body of one heredoc from $s into hd_text; the body and its terminator leave $s.
tok_heredoc_body() {
  local line cmp n=0 end=-1
  while IFS= read -r line; do
    cmp=$line
    if [[ $2 == 1 ]]; then
      while [[ $cmp == $'\t'* ]]; do cmp=${cmp#?}; done
    fi
    if [[ $cmp == "$1" ]]; then
      end=$n
      n=$((n + ${#line} + 1))
      break
    fi
    n=$((n + ${#line} + 1))
  done <<<"$s"
  if ((end < 0)); then
    hd_text=""
  else
    hd_text=${s:0:end}
    s=${s:n}
  fi
}

# Runs only the $(...) and backtick spans of an unquoted-delimiter heredoc body.
tok_scan_body() {
  local s=$1
  while [[ -n $s ]]; do
    if [[ ${s:0:256} =~ $re_body_skip ]]; then
      s=${s:${#BASH_REMATCH[0]}}
    elif [[ ${s:0:2} == '$(' ]]; then
      s=${s:2}
      tok_run sub
    elif [[ $s == '`'* ]]; then
      s=${s:1}
      tok_run bt
    elif [[ $s == '\'* ]]; then
      s=${s:2}
    else
      s=${s:1}
    fi
  done
}

tok_heredocs() {
  local i=0 hd_text
  while ((i < ${#hd_delim[@]})); do
    tok_heredoc_body "${hd_delim[i]}" "${hd_dash[i]}"
    if ((line_interp)); then
      tok_string "$hd_text"
    elif [[ ${hd_quoted[i]} == 0 ]]; then
      tok_scan_body "$hd_text"
    fi
    i=$((i + 1))
  done
  if ((line_interp)); then
    for hd_text in "${hs_text[@]}"; do tok_string "$hd_text"; done
  fi
  hd_delim=()
  hd_quoted=()
  hd_dash=()
  hs_text=()
  line_interp=0
}

tok_loop() {
  local mode=$1 op w saved
  local -a words lits hd_delim hd_quoted hd_dash hs_text
  local word="" nonlit=0 quoted=0 have_word=0 redir=0 want_delim=0 want_here=0 want_dash=0 parens=0 line_interp=0
  words=()
  lits=()
  hd_delim=()
  hd_quoted=()
  hd_dash=()
  hs_text=()
  while [[ -n $s ]]; do
    if ((SECONDS > TOKENIZE_BUDGET_SECONDS)); then
      warn_unchecked "took too long to tokenize"
      s=""
      break
    fi
    w=${s:0:256}
    if [[ $w =~ $re_blank ]]; then
      tok_end_word
      s=${s:${#BASH_REMATCH[0]}}
    elif [[ ${s:0:2} == $'\\\n' ]]; then
      s=${s:2}
    elif [[ $s == $'\n'* ]]; then
      tok_end_command
      s=${s:1}
      if ((${#hd_delim[@]} + ${#hs_text[@]} > 0)); then tok_heredocs; fi
      line_interp=0
    elif ((have_word == 0)) && [[ $w == '#'* && $s =~ $re_comment ]]; then
      s=${s:${#BASH_REMATCH[0]}}
    elif [[ $mode == bt && $s == '`'* ]]; then
      s=${s:1}
      tok_end_command
      return 0
    elif ((have_word == 0)) && [[ ${w:0:2} == '((' && ( ${#words[@]} -eq 0 || ${words[${#words[@]} - 1]} == for ) ]]; then
      saved=$s
      s=${s:2}
      if ! tok_arith; then
        s=${saved:1}
        parens=$((parens + 1))
        tok_end_command
      fi
    elif [[ $w =~ $re_op ]]; then
      op=${BASH_REMATCH[0]}
      s=${s:${#op}}
      if [[ $op == ')' && $mode == sub && $parens -eq 0 ]]; then
        tok_end_command
        return 0
      fi
      if [[ $op == '(' ]]; then parens=$((parens + 1)); fi
      if [[ $op == ')' && $parens -gt 0 ]]; then parens=$((parens - 1)); fi
      tok_end_command
    elif [[ $w =~ $re_redir ]]; then
      op=${BASH_REMATCH[0]}
      s=${s:${#op}}
      if ((have_word && !quoted && !nonlit)) && [[ $word =~ $re_fd ]]; then
        word=""
        have_word=0
      fi
      tok_end_word
      if [[ $op == '<<' || $op == '<<-' ]]; then
        want_delim=1
        want_dash=0
        if [[ $op == '<<-' ]]; then want_dash=1; fi
      elif [[ $op == '<<<' ]]; then
        want_here=1
      else
        redir=1
      fi
    elif [[ $s == "'"* ]]; then
      tok_squote
    elif [[ ${s:0:2} == "\$'" ]]; then
      if [[ $s =~ $re_ansi ]]; then
        word+=${BASH_REMATCH[0]:2:${#BASH_REMATCH[0]}-3}
        s=${s:${#BASH_REMATCH[0]}}
      else
        word+=${s:2}
        s=""
      fi
      quoted=1
      have_word=1
    elif [[ $s == '"'* ]]; then
      tok_dquote
    elif [[ $s == '`'* ]]; then
      nonlit=1
      have_word=1
      s=${s:1}
      tok_run bt
    elif [[ $s == '$'* ]]; then
      tok_dollar
    elif [[ $s == '\'* ]]; then
      quoted=1
      have_word=1
      word+=${s:1:1}
      s=${s:2}
    elif [[ $w =~ $re_glob ]]; then
      nonlit=1
      have_word=1
      s=${s:${#BASH_REMATCH[0]}}
    elif [[ $w =~ $re_lit ]]; then
      word+=${BASH_REMATCH[0]}
      have_word=1
      s=${s:${#BASH_REMATCH[0]}}
    else
      word+=${s:0:1}
      have_word=1
      s=${s:1}
    fi
  done
  tok_end_command
  if ((${#hs_text[@]} > 0)); then tok_heredocs; fi
}

# Applies rules 3 and 4 to the simple command in words/lits, after the transparent prefixes.
tok_emit() {
  local n=${#words[@]} i=0 j pw o valflags base
  while ((i < n)); do
    if [[ ${words[i]} =~ $re_assign ]]; then
      i=$((i + 1))
      continue
    fi
    pw=${words[i]##*/}
    case $pw in
      if | then | elif | else | while | until | do | '!' | '{' | '}') i=$((i + 1)) ;;
      env | command | exec | sudo | xargs | nice | time | timeout | nohup | stdbuf | builtin | noglob)
        case $pw in
          env) valflags=" -u -C " ;;
          exec) valflags=" -a " ;;
          sudo) valflags=" -u -g -h -p -C -D -r -t -U -T " ;;
          xargs) valflags=" -I -n -L -P -d -E -s -a " ;;
          nice) valflags=" -n " ;;
          timeout) valflags=" -s -k " ;;
          stdbuf) valflags=" -i -o -e " ;;
          *) valflags=" " ;;
        esac
        j=$((i + 1))
        while ((j < n)) && [[ ${words[j]} == -* ]]; do
          o=${words[j]}
          if [[ $o == -- ]]; then
            j=$((j + 1))
            break
          fi
          if [[ $pw == command && ( $o == -v || $o == -V ) ]]; then return 0; fi
          if [[ $pw == env ]]; then
            case $o in
              -S | --split-string) tok_string "${words[j + 1]:-}"; return 0 ;;
              -S?*) tok_string "${o#-S}"; return 0 ;;
              --split-string=*) tok_string "${o#*=}"; return 0 ;;
            esac
          fi
          if [[ $valflags == *" $o "* ]]; then j=$((j + 2)); else j=$((j + 1)); fi
        done
        # timeout takes a DURATION operand before the command.
        [[ $pw == timeout ]] && j=$((j + 1))
        i=$j ;;
      *) break ;;
    esac
  done
  ((i < n)) || return 0
  [[ ${lits[i]} == 1 ]] || return 0
  base=${words[i]##*/}
  case $base in
    git) [[ -n $role ]] && tok_git_rule "$i" ;;
    bash | sh | zsh | dash) tok_shell "$i" ;;
    eval) tok_string "${words[*]:i+1}" ;;
    cargo | npm | pnpm | yarn | bun | wally | pesde) tok_deps "$i" ;;
  esac
  return 0
}

tok_git_rule() {
  local j=$(($1 + 1)) n=${#words[@]}
  while ((j < n)) && [[ ${words[j]} == -* ]]; do
    case ${words[j]} in
      -C | -c | --git-dir | --work-tree | --namespace | --config-env) j=$((j + 2)) ;;
      *) j=$((j + 1)) ;;
    esac
  done
  [[ ${lits[j]:-0} == 1 ]] || return 0
  case ${words[j]} in
    commit | push) deny "Role '$role' may not run git commit or git push; only the team lead commits and pushes. Report the change set in the handoff." ;;
  esac
}

tok_shell() {
  local k=$(($1 + 1)) n=${#words[@]}
  while ((k < n)) && [[ ${words[k]} == [-+]* ]]; do
    if [[ ${words[k]} =~ $re_cflag ]]; then
      tok_string "${words[k + 1]:-}"
      return 0
    fi
    if [[ ${words[k]} =~ $re_shell_valopt ]]; then k=$((k + 2)); else k=$((k + 1)); fi
  done
  line_interp=1
}

tok_deps() {
  local name
  plain_dep_names "$1"
  ((${#dep_names[@]} > 0)) || return 0
  has_alt_registry "$dep_kind" "$root" && return 0
  for name in "${dep_names[@]}"; do
    dep_checks=$((dep_checks + 1))
    ((dep_checks <= MAX_DEP_CHECKS)) || return 0
    registry_lookup "$dep_kind" "$name"
    case $REG_STATUS in
      missing)
        if [[ $dep_kind == npm && $name == @* ]]; then
          warnings+="Scoped package '$name' was not found on the public npm registry; it may live on a private registry, check the name manually. "
        else
          deny "Package '$name' does not exist in the $dep_kind registry. LLM-suggested names are often hallucinated and can be pre-registered by attackers (slopsquatting). Verify the exact name with context7 or the registry website, then retry."
        fi ;;
      unknown) warnings+="Could not verify '$name' in the $dep_kind registry (network error or lookup time budget); check the name manually. " ;;
    esac
  done
}

# Cheap raw-text prefilter: only commands that mention a git commit/push or a package install are tokenized.
tok_wanted() {
  [[ -n $role && $1 =~ $re_git && $1 =~ $re_subcmd ]] && return 0
  [[ $1 =~ $re_mgr && $1 =~ $re_verb ]]
}

check_bash() {
  local cmd s
  cmd=$(field .tool_input.command)
  [[ -n $cmd ]] || finish
  tok_wanted "$cmd" || finish
  if ((${#cmd} > MAX_TOKENIZE_BYTES)); then
    warn_unchecked "is larger than $MAX_TOKENIZE_BYTES bytes"
    finish
  fi
  root=$(root_for "$cwd")
  s=$cmd
  tok_run top
  finish
}

case $tool in
  Edit | Write | NotebookEdit) check_file_edit ;;
  Bash) check_bash ;;
esac
exit 0
