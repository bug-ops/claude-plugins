#!/usr/bin/env bash
# shellcheck disable=SC2016  # backticks in single quotes are Markdown, not expansions
# Scaffold project infrastructure for the dev-agents plugin.
# Detects Rust and TypeScript stacks, creates .local/ directories, knowledge base files,
# .gitignore entries, and a project verify skill.
# Usage: scaffold.sh [--force]
set -euo pipefail

FORCE=false
[[ "${1:-}" == "--force" ]] && FORCE=true

# --- Helpers ---

in_dir() { if [[ "$1" == "." ]]; then printf '%s' "$2"; else printf '%s/%s' "$1" "$2"; fi; }
cd_prefix() { if [[ "$1" != "." ]]; then printf 'cd %s && ' "$1"; fi; }
root_suffix() { if [[ "$1" != "." ]]; then printf ' (`%s/`)' "$1"; fi; }
dir_label() { basename "$(cd "$(in_dir "$1" "$2")" && pwd)"; }
json_flat() { tr '\n\r\t' '   ' < "$1"; }

json_name() {
  awk 'match($0, /"name"[[:space:]]*:[[:space:]]*"[^"]*"/) {
    s = substr($0, RSTART, RLENGTH); sub(/^"name"[[:space:]]*:[[:space:]]*"/, "", s); sub(/"$/, "", s); print s; exit
  }' "$1"
}

cargo_pkg_name() {
  awk '/^\[/ { p = ($0 ~ /^\[package\][[:space:]]*$/) }
    p && /^name[[:space:]]*=/ { sub(/^name[[:space:]]*=[[:space:]]*"/, ""); sub(/".*$/, ""); print; exit }' "$1"
}

cargo_bin_names() {
  awk '/^\[/ { b = ($0 ~ /^\[\[bin\]\]/) }
    b && /^name[[:space:]]*=/ { sub(/^name[[:space:]]*=[[:space:]]*"/, ""); sub(/".*$/, ""); print }' "$1"
}

# Prints directories under $1 matching glob $2 (`**` is treated as `*`).
expand_dirs() {
  local root=$1 pat=${2%/}
  pat=${pat//\*\*/*}
  (
    cd "$root" || exit 0
    for d in $pat; do
      if [[ -d "$d" ]]; then printf '%s\n' "${d#./}"; fi
    done
  )
}

split_words() { set -f; for w in $1; do printf '%s\n' "$w"; done; }

# --- Stack detection (root first, then one level down) ---

RUST_ROOTS=()
TS_ROOTS=()

if [[ -f Cargo.toml ]]; then
  RUST_ROOTS+=(.)
else
  for f in */Cargo.toml; do
    if [[ -f "$f" ]]; then RUST_ROOTS+=("${f%/Cargo.toml}"); fi
  done
fi

if [[ -f package.json || -f tsconfig.json ]]; then
  TS_ROOTS+=(.)
else
  for d in */ packages/*/; do
    d=${d%/}
    case "$d" in node_modules|target|dist|build|packages) continue ;; esac
    if [[ -f "$d/package.json" || -f "$d/tsconfig.json" ]]; then TS_ROOTS+=("$d"); fi
  done
fi

STACKS=""
[[ ${#RUST_ROOTS[@]} -gt 0 ]] && STACKS="rust"
[[ ${#TS_ROOTS[@]} -gt 0 ]] && STACKS="${STACKS:+$STACKS }typescript"

if [[ -z "$STACKS" ]]; then
  echo "ERROR: no Cargo.toml, package.json, or tsconfig.json found at the repository root or one level down. Run from the repository root."
  exit 1
fi

if [[ -d ".local" ]] && [[ "$FORCE" == false ]]; then
  echo "Detected stacks: $STACKS"
  echo "INFO: .local/ already exists. Pass --force to overwrite files."
  echo "Existing structure:"
  find .local -maxdepth 2 -type d | sort
  exit 0
fi

POLYGLOT=false
[[ "$STACKS" == "rust typescript" ]] && POLYGLOT=true

# --- Unit enumeration (parallel arrays: root, dir relative to root, name) ---

RS_ROOT=(); RS_DIR=(); RS_NAME=()
TS_ROOT=(); TS_DIR=(); TS_NAME=()

add_rust_unit() {
  local name
  name=$(cargo_pkg_name "$3")
  RS_ROOT+=("$1"); RS_DIR+=("$2"); RS_NAME+=("${name:-$(dir_label "$1" "$2")}")
}

add_ts_unit() {
  local name=""
  if [[ -n "$3" ]]; then name=$(json_name "$3"); fi
  TS_ROOT+=("$1"); TS_DIR+=("$2"); TS_NAME+=("${name:-$(dir_label "$1" "$2")}")
}

collect_rust() {
  local root=$1 manifest members pat d
  manifest=$(in_dir "$root" Cargo.toml)
  if grep -q '^\[package\]' "$manifest"; then add_rust_unit "$root" . "$manifest"; fi
  if grep -q '^\[workspace\]' "$manifest"; then
    members=$(awk '/^members[[:space:]]*=/{f=1} f{print} f&&/\]/{exit}' "$manifest" \
      | sed 's/#.*//' | tr '\n' ' ' | sed 's/^[^[]*\[//; s/\].*$//' | tr ',' ' ' | tr -d "\"'")
    while IFS= read -r pat; do
      [[ -z "$pat" ]] && continue
      while IFS= read -r d; do
        if [[ -f "$(in_dir "$root" "$d")/Cargo.toml" ]]; then
          add_rust_unit "$root" "$d" "$(in_dir "$root" "$d")/Cargo.toml"
        fi
      done < <(expand_dirs "$root" "$pat")
    done < <(split_words "$members")
  fi
  return 0
}

ts_workspace_patterns() {
  local yaml pkg flat ws
  yaml=$(in_dir "$1" pnpm-workspace.yaml)
  pkg=$(in_dir "$1" package.json)
  if [[ -f "$yaml" ]]; then
    awk -v q="'" '
      function clean(v) { gsub(/"/, "", v); gsub(q, "", v); gsub(/^[[:space:]]+|[[:space:]]+$/, "", v); return v }
      /^packages:/ {
        inpk = 1
        if (match($0, /\[.*\]/)) {
          n = split(substr($0, RSTART + 1, RLENGTH - 2), a, ",")
          for (i = 1; i <= n; i++) { v = clean(a[i]); if (v != "") print v }
          inpk = 0
        }
        next
      }
      inpk && /^[^[:space:]#-]/ { inpk = 0 }
      inpk && /^[[:space:]]*-/ { v = $0; sub(/^[[:space:]]*-[[:space:]]*/, "", v); sub(/[[:space:]]+#.*$/, "", v); v = clean(v); if (v != "") print v }
    ' "$yaml"
    return 0
  fi
  [[ -f "$pkg" ]] || return 0
  flat=$(json_flat "$pkg")
  ws=$(printf '%s\n' "$flat" | sed -nE 's/.*"workspaces"[[:space:]]*:[[:space:]]*\[([^]]*)\].*/\1/p')
  if [[ -z "$ws" ]]; then
    ws=$(printf '%s\n' "$flat" | sed -nE 's/.*"workspaces"[[:space:]]*:[[:space:]]*\{[^}]*"packages"[[:space:]]*:[[:space:]]*\[([^]]*)\].*/\1/p')
  fi
  printf '%s\n' "$ws" | grep -o '"[^"]*"' | tr -d '"' || true
}

collect_ts() {
  local root=$1 pat d pkg found=false
  while IFS= read -r pat; do
    case "$pat" in ''|'!'*) continue ;; esac
    while IFS= read -r d; do
      pkg="$(in_dir "$root" "$d")/package.json"
      if [[ -f "$pkg" ]]; then add_ts_unit "$root" "$d" "$pkg"; found=true; fi
    done < <(expand_dirs "$root" "$pat")
  done < <(ts_workspace_patterns "$root")
  if [[ "$found" == false ]]; then
    pkg=$(in_dir "$root" package.json)
    if [[ -f "$pkg" ]]; then add_ts_unit "$root" . "$pkg"; else add_ts_unit "$root" . ""; fi
  fi
}

for r in ${RUST_ROOTS[@]+"${RUST_ROOTS[@]}"}; do collect_rust "$r"; done
for r in ${TS_ROOTS[@]+"${TS_ROOTS[@]}"}; do collect_ts "$r"; done

echo "Detected stacks: $STACKS"
[[ ${#RS_NAME[@]} -gt 0 ]] && echo "Rust units: ${RS_NAME[*]}"
[[ ${#TS_NAME[@]} -gt 0 ]] && echo "TypeScript units: ${TS_NAME[*]}"

# --- Create directories ---

dirs=(
  # Agent communication (agent-handoff)
  .local/handoff
  # Implementation plans and specs (sdd)
  .local/plan
  # Team execution reports (team-develop)
  .local/team-results
  # Testing infrastructure (live-tester, continuous-improvement)
  .local/testing/debug
  .local/testing/data
  .local/testing/journal
  .local/testing/playbooks
  .local/testing/scripts
  .local/testing/sessions
)

for d in "${dirs[@]}"; do
  mkdir -p "$d"
done
echo "Directories created."

write_if_missing() {
  local path="$1"
  if [[ -f "$path" ]] && [[ "$FORCE" == false ]]; then
    echo "SKIP: $path (exists)"
    cat > /dev/null
    return 0
  fi
  cat > "$path"
  echo "CREATED: $path"
}

# --- coverage-status.md (one section per unit) ---

coverage_section() {
  cat <<SECTION

## $1

| Component | Status | Last session | Version | Issues | Result |
|---|---|---|---|---|---|

---
SECTION
}

{
cat <<'HEADER'
# Component Coverage Status

**Permanent artifact. Never delete or archive.**
Last updated: (not yet started)

Status legend:
- **Tested** — all primary scenarios verified live; no known gaps
- **Partial** — at least one happy-path verified; edge cases remain
- **Untested** — never live-tested, or reset after significant code change
- **Blocked** — cannot test due to missing dependency, infra, or API key

---
HEADER

i=0
while [[ $i -lt ${#RS_NAME[@]} ]]; do
  if [[ "$POLYGLOT" == true ]]; then coverage_section "${RS_NAME[$i]} (rust)"; else coverage_section "${RS_NAME[$i]}"; fi
  i=$((i + 1))
done
i=0
while [[ $i -lt ${#TS_NAME[@]} ]]; do
  if [[ "$POLYGLOT" == true ]]; then coverage_section "${TS_NAME[$i]} (typescript)"; else coverage_section "${TS_NAME[$i]}"; fi
  i=$((i + 1))
done
} | write_if_missing ".local/testing/coverage-status.md"

# --- process-notes.md ---

write_if_missing ".local/testing/process-notes.md" <<'EOF'
# Testing Process Notes

Evolving log of testing methodology: what works, what doesn't, ideas to try.

## Effective Techniques

(None yet — populate after first CI cycle)

## Failed / Low-Value Approaches

(None yet — document approaches that didn't work so they aren't repeated)
EOF

# --- regressions.md ---

write_if_missing ".local/testing/regressions.md" <<'EOF'
# Regression Scenarios

Minimal reproduction prompts for previously found bugs.
Re-run after every significant change to catch regressions.

## How to use

1. Start the project with test configuration
2. Run each scenario below in order
3. Compare actual behavior with expected
4. If regression detected — create issue, link back to original bug

## Catalog

<!-- Template:
### [REG-NNN] Title (original issue #NNN)
**Prompt**: `exact prompt or command`
**Steps**: Additional setup/context if needed
**Expected**: Correct behavior description
**Last verified**: YYYY-MM-DD, vX.Y.Z
**Status**: Pass / Fail / Skipped
-->
EOF

# --- playbooks/competitive-parity.md ---

write_if_missing ".local/testing/playbooks/competitive-parity.md" <<'EOF'
# Competitive Parity Monitoring

Living document tracking feature and protocol parity against reference projects.
Update after every parity scan.

---

## Reference Projects — Last Checked

| Project | Stack | Key features to watch | Last checked | Version |
|---|---|---|---|---|

---

## Known Gaps

| Feature | Project(s) with it | Research backing | Status | Issue | Priority |
|---|---|---|---|---|---|
EOF

# --- .gitignore ---

if [[ -f ".gitignore" ]]; then
  if ! grep -q '\.local/' .gitignore 2>/dev/null; then
    printf '\n# Working directory (agent handoffs, plans, testing)\n.local/\n' >> .gitignore
    echo "UPDATED: .gitignore (added .local/)"
  else
    echo "SKIP: .gitignore (already has .local/)"
  fi
else
  printf '# Working directory (agent handoffs, plans, testing)\n.local/\n' > .gitignore
  echo "CREATED: .gitignore"
fi

if ! grep -q 'agent-memory-local' .gitignore 2>/dev/null; then
  printf '\n# Local agent memory (dev-agents analysts, memory: local)\n.claude/agent-memory-local/\n' >> .gitignore
  echo "UPDATED: .gitignore (added .claude/agent-memory-local/)"
fi

# --- .claude/rules directory ---

mkdir -p .claude/rules
echo "Ensured .claude/rules/ exists."

# --- Verify skill: Rust section ---

verify_rust() {
  local root=$1 cdp i udir manifest f b bins="" seen=" "
  cdp=$(cd_prefix "$root")
  i=0
  while [[ $i -lt ${#RS_NAME[@]} ]]; do
    if [[ "${RS_ROOT[$i]}" == "$root" ]]; then
      udir=$(in_dir "$root" "${RS_DIR[$i]}")
      manifest="$udir/Cargo.toml"
      if [[ -f "$udir/src/main.rs" ]]; then bins="$bins${RS_NAME[$i]}"$'\n'; fi
      for f in "$udir"/src/bin/*.rs "$udir"/src/bin/*/main.rs; do
        if [[ -f "$f" ]]; then
          f=${f%/main.rs}; f=${f%.rs}; bins="$bins$(basename "$f")"$'\n'
        fi
      done
      bins="$bins$(cargo_bin_names "$manifest")"$'\n'
    fi
    i=$((i + 1))
  done

  printf '## Rust%s\n\n' "$(root_suffix "$root")"
  cat <<EOF
### Build

\`\`\`bash
${cdp}cargo build --workspace --all-features
\`\`\`

### Test

\`\`\`bash
${cdp}cargo nextest run --workspace --all-features --lib --bins || cargo test --workspace --all-features
\`\`\`

### Run

EOF
  local count=0
  while IFS= read -r b; do
    [[ -z "$b" || "$seen" == *" $b "* ]] && continue
    seen="$seen$b "
    count=$((count + 1))
    cat <<EOF
\`\`\`bash
${cdp}cargo run --bin ${b} -- --help   # replace --help with the flow under verification
\`\`\`

EOF
  done <<< "$bins"
  if [[ $count -eq 0 ]]; then
    printf 'No binary targets detected. Verify through the test suite and doc-tests (`cargo test --doc`), or add the run command for your integration entry point here.\n\n'
  fi
}

# --- Verify skill: TypeScript section ---

ts_pm() {
  local root=$1 pkg pm=""
  pkg=$(in_dir "$root" package.json)
  if [[ -f "$pkg" ]]; then
    pm=$(awk 'match($0, /"packageManager"[[:space:]]*:[[:space:]]*"[a-z]+/) { s = substr($0, RSTART, RLENGTH); sub(/.*"/, "", s); print s; exit }' "$pkg")
  fi
  if [[ -z "$pm" ]]; then
    if [[ -f "$(in_dir "$root" pnpm-lock.yaml)" || -f "$(in_dir "$root" pnpm-workspace.yaml)" ]]; then pm=pnpm
    elif [[ -f "$(in_dir "$root" yarn.lock)" ]]; then pm=yarn
    elif [[ -f "$(in_dir "$root" bun.lock)" || -f "$(in_dir "$root" bun.lockb)" ]]; then pm=bun
    else pm=npm
    fi
  fi
  if [[ "$pm" == yarn && -f "$(in_dir "$root" .yarnrc.yml)" ]]; then pm=yarn-berry; fi
  printf '%s\n' "$pm"
}

ts_mode() {
  local root=$1 pkg i
  pkg=$(in_dir "$root" package.json)
  if [[ -f "$(in_dir "$root" tsconfig.json)" ]]; then echo typescript; return 0; fi
  if [[ -f "$pkg" ]] && grep -q '"typescript"[[:space:]]*:' "$pkg"; then echo typescript; return 0; fi
  i=0
  while [[ $i -lt ${#TS_NAME[@]} ]]; do
    if [[ "${TS_ROOT[$i]}" == "$root" && -f "$(in_dir "$root" "${TS_DIR[$i]}")/tsconfig.json" ]]; then
      echo typescript; return 0
    fi
    i=$((i + 1))
  done
  echo javascript
}

has_script() {
  local scripts re="\"$2\"[[:space:]]*:"
  [[ -f "$1" ]] || return 1
  scripts=$(json_flat "$1" | sed -nE 's/.*"scripts"[[:space:]]*:[[:space:]]*\{([^}]*)\}.*/\1/p')
  [[ $scripts =~ $re ]]
}

ts_bins() {
  local flat single
  flat=$(json_flat "$1")
  single=$(printf '%s\n' "$flat" | sed -nE 's/.*"bin"[[:space:]]*:[[:space:]]*"([^"]*)".*/\1/p')
  if [[ -n "$single" ]]; then printf '%s\n' "$single"; return 0; fi
  printf '%s\n' "$flat" | sed -nE 's/.*"bin"[[:space:]]*:[[:space:]]*\{([^}]*)\}.*/\1/p' \
    | grep -o ':[[:space:]]*"[^"]*"' | sed -E 's/^:[[:space:]]*"//; s/"$//' || true
}

pm_install() {
  case "$1" in
    npm) if [[ -f "$(in_dir "$2" package-lock.json)" ]]; then echo "npm ci"; else echo "npm install"; fi ;;
    pnpm) echo "pnpm install --frozen-lockfile" ;;
    yarn) echo "yarn install --frozen-lockfile" ;;
    yarn-berry) echo "yarn install --immutable" ;;
    bun) echo "bun install --frozen-lockfile" ;;
  esac
}

pm_run() { case "$1" in yarn|yarn-berry) echo "yarn run $2" ;; *) echo "$1 run $2" ;; esac; }

pm_exec() {
  case "$1" in
    npm) echo "npx" ;;
    pnpm) echo "pnpm exec" ;;
    yarn|yarn-berry) echo "yarn" ;;
    bun) echo "bunx" ;;
  esac
}

pm_recursive() {
  case "$1" in
    npm) echo "npm run $2 --workspaces --if-present" ;;
    pnpm) echo "pnpm -r run $2" ;;
    yarn) echo "yarn workspaces run $2" ;;
    yarn-berry) echo "yarn workspaces foreach --all run $2" ;;
    bun) echo "bun run --filter '*' $2" ;;
  esac
}

code_block() { printf '```bash\n%s%s\n```\n\n' "$1" "$2"; }

verify_ts() {
  local root=$1 pkg pm mode cdp label ws=false i udir p count=0
  pkg=$(in_dir "$root" package.json)
  pm=$(ts_pm "$root")
  mode=$(ts_mode "$root")
  cdp=$(cd_prefix "$root")
  if [[ -n "$(ts_workspace_patterns "$root")" ]]; then ws=true; fi
  if [[ "$mode" == typescript ]]; then label=TypeScript; else label=JavaScript; fi

  printf '## %s%s\n\n' "$label" "$(root_suffix "$root")"
  printf 'Package manager: `%s`. Prefer the `package.json` scripts; they encode the CI setup.\n\n' "${pm%-berry}"

  printf '### Install\n\n'
  code_block "$cdp" "$(pm_install "$pm" "$root")"

  printf '### Build\n\n'
  if has_script "$pkg" build; then code_block "$cdp" "$(pm_run "$pm" build)"
  elif [[ "$ws" == true ]]; then code_block "$cdp" "$(pm_recursive "$pm" build)"
  else printf 'No build script detected; the package runs from source or through its framework dev server.\n\n'
  fi

  if [[ "$mode" == typescript ]]; then
    printf '### Type check\n\n'
    if has_script "$pkg" typecheck; then code_block "$cdp" "$(pm_run "$pm" typecheck)"
    elif has_script "$pkg" type-check; then code_block "$cdp" "$(pm_run "$pm" type-check)"
    else code_block "$cdp" "$(pm_exec "$pm") tsc --noEmit"
    fi
  fi

  printf '### Test\n\n'
  if has_script "$pkg" test; then code_block "$cdp" "$(pm_run "$pm" test)"
  elif [[ "$ws" == true ]]; then code_block "$cdp" "$(pm_recursive "$pm" test)"
  else printf 'No test script detected. Add the configured runner (`vitest run`, `node --test`) here.\n\n'
  fi

  printf '### Run\n\n'
  i=0
  while [[ $i -lt ${#TS_NAME[@]} ]]; do
    if [[ "${TS_ROOT[$i]}" == "$root" ]]; then
      udir=$(in_dir "$root" "${TS_DIR[$i]}")
      if [[ -f "$udir/package.json" ]]; then
        while IFS= read -r p; do
          [[ -z "$p" ]] && continue
          count=$((count + 1))
          code_block "$cdp" "node $(in_dir "${TS_DIR[$i]}" "${p#./}") --help   # build first; replace --help with the flow under verification"
        done < <(ts_bins "$udir/package.json")
      fi
    fi
    i=$((i + 1))
  done
  if [[ $count -eq 0 ]]; then
    if has_script "$pkg" start; then code_block "$cdp" "$(pm_run "$pm" start)"
    elif has_script "$pkg" dev; then code_block "$cdp" "$(pm_run "$pm" dev)   # dev server; drive it with curl or the e2e suite"
    else printf 'No `bin` entry or start/dev script detected. Add the run command for your entry point here, or verify through the test suite.\n\n'
    fi
  fi
}

# --- .claude/skills/verify/SKILL.md (project verify skill) ---

PROJECT_NAME=""
if [[ -f Cargo.toml ]]; then PROJECT_NAME=$(cargo_pkg_name Cargo.toml); fi
if [[ -z "$PROJECT_NAME" && -f package.json ]]; then PROJECT_NAME=$(json_name package.json); fi
PROJECT_NAME="${PROJECT_NAME:-$(basename "$PWD")}"

mkdir -p .claude/skills/verify
if [[ -f .claude/skills/verify/SKILL.md ]] && [[ "$FORCE" == false ]]; then
  echo "SKIP: .claude/skills/verify/SKILL.md (exists)"
else
{
cat <<HEADER
---
name: verify
description: Build, run, and drive ${PROJECT_NAME} to verify a change end to end. Use when asked to verify a change, run the project, smoke-test a feature, or check that the project still works.
---

# Verify ${PROJECT_NAME}

Stacks: ${STACKS}

The handle is direct invocation of the built entry points (binaries, CLIs, servers); the evidence is stdout, stderr, exit codes, and logs. Update this file whenever a step below steers you wrong — it is the project's shared build/run/test recipe (live-tester and the bundled /verify skill both read it).

HEADER
for r in ${RUST_ROOTS[@]+"${RUST_ROOTS[@]}"}; do verify_rust "$r"; done
for r in ${TS_ROOTS[@]+"${TS_ROOTS[@]}"}; do verify_ts "$r"; done
cat <<'FOOTER'
## Evidence

- Capture exit code, stdout/stderr, and the log lines that prove the behavior
- Exercise the changed path with a boundary or error input, not only the happy path
- Point destructive commands at a temp directory or a dry-run flag

## Gotchas

- (record traps you hit: required env vars, ports, fixtures, slow first builds)
FOOTER
} > .claude/skills/verify/SKILL.md
echo "CREATED: .claude/skills/verify/SKILL.md"
fi

echo ""
echo "Scaffold complete. Stacks: ${STACKS}. $(( ${#RS_NAME[@]} + ${#TS_NAME[@]} )) unit(s) detected."
echo ""
echo "Structure created:"
echo "  .local/handoff/          — agent communication (agent-handoff)"
echo "  .local/plan/             — implementation plans (sdd)"
echo "  .local/team-results/     — team reports (team-develop)"
echo "  .local/testing/          — CI cycle knowledge base (continuous-improvement)"
echo "    debug/  data/  journal/  playbooks/  scripts/  sessions/"
echo "    coverage-status.md  process-notes.md  regressions.md"
echo "  .claude/skills/verify/   — project build/run/test recipe"
