#!/usr/bin/env bash
# Scaffold project infrastructure for the rust-agents plugin.
# Creates .local/ directories, knowledge base files, and .gitignore entry.
# Usage: scaffold.sh [--force]
set -euo pipefail

FORCE=false
[[ "${1:-}" == "--force" ]] && FORCE=true

# --- Pre-flight ---

if [[ ! -f "Cargo.toml" ]]; then
  echo "ERROR: Cargo.toml not found in current directory. Run from workspace root."
  exit 1
fi

if [[ -d ".local" ]] && [[ "$FORCE" == false ]]; then
  echo "INFO: .local/ already exists. Pass --force to overwrite files."
  echo "Existing structure:"
  find .local -maxdepth 2 -type d | sort
  exit 0
fi

# --- Extract workspace members from Cargo.toml ---

CRATES=()
if grep -q '^\[workspace\]' Cargo.toml 2>/dev/null; then
  # Workspace project: join the members array (single- or multi-line) and expand simple globs like "crates/*"
  members_raw=$(awk '/^members[[:space:]]*=/{f=1} f{print} f&&/\]/{exit}' Cargo.toml | tr '\n' ' ' | sed 's/^[^[]*\[//; s/\].*$//' | tr ',' ' ' | tr -d '"')
  for crate in $members_raw; do
    if [[ "$crate" == *"*"* ]]; then
      for dir in $crate; do
        [[ -d "$dir" ]] && CRATES+=("$(basename "$dir")")
      done
    elif [[ -n "$crate" ]]; then
      CRATES+=("$(basename "$crate")")
    fi
  done
fi

# Fallback: single-crate project
if [[ ${#CRATES[@]} -eq 0 ]]; then
  PROJECT_NAME=$(sed -n 's/^name[[:space:]]*=[[:space:]]*"\(.*\)"/\1/p' Cargo.toml | head -1)
  CRATES=("${PROJECT_NAME:-project}")
fi

echo "Detected crates: ${CRATES[*]}"

# --- Create directories ---

dirs=(
  # Agent communication (rust-agent-handoff)
  .local/handoff
  # Implementation plans and specs (sdd)
  .local/plan
  # Team execution reports (rust-team)
  .local/team-results
  # Testing infrastructure (ci-analyst, continuous-improvement)
  .local/testing/debug
  .local/testing/data
  .local/testing/playbooks
  .local/testing/scripts
  .local/testing/sessions
)

for d in "${dirs[@]}"; do
  mkdir -p "$d"
done
echo "Directories created."

# --- Helper: write file if not exists or force ---

write_if_missing() {
  local path="$1"
  if [[ -f "$path" ]] && [[ "$FORCE" == false ]]; then
    echo "SKIP: $path (exists)"
    return
  fi
  cat > "$path"
  echo "CREATED: $path"
}

# --- journal/ directory ---

mkdir -p ".local/testing/journal"
echo "Ensured .local/testing/journal/ exists."

# --- coverage-status.md (dynamic per-crate sections) ---

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

for crate in "${CRATES[@]}"; do
cat <<SECTION

## ${crate}

| Component | Status | Last session | Version | Issues | Result |
|---|---|---|---|---|---|

---
SECTION
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
  printf '\n# Local agent memory (rust-agents analysts, memory: local)\n.claude/agent-memory-local/\n' >> .gitignore
  echo "UPDATED: .gitignore (added .claude/agent-memory-local/)"
fi

# --- .claude/rules directory ---

mkdir -p .claude/rules
echo "Ensured .claude/rules/ exists."

# --- .claude/skills/verify/SKILL.md (project verify skill) ---

PROJECT_NAME=$(sed -n 's/^name[[:space:]]*=[[:space:]]*"\(.*\)"/\1/p' Cargo.toml | head -1)
PROJECT_NAME="${PROJECT_NAME:-$(basename "$PWD")}"

# Collect binary targets: src/main.rs, src/bin/*.rs, and workspace members with src/main.rs
BINS=()
[[ -f src/main.rs ]] && BINS+=("$PROJECT_NAME")
for f in src/bin/*.rs; do [[ -f "$f" ]] && BINS+=("$(basename "${f%.rs}")"); done
for crate_dir in crates/* .; do
  [[ -f "$crate_dir/src/main.rs" && "$crate_dir" != "." ]] && BINS+=("$(basename "$crate_dir")")
done

mkdir -p .claude/skills/verify
if [[ -f .claude/skills/verify/SKILL.md ]] && [[ "$FORCE" == false ]]; then
  echo "SKIP: .claude/skills/verify/SKILL.md (exists)"
else
{
cat <<HEADER
---
name: verify
description: Build, run, and drive ${PROJECT_NAME} to verify a change end to end. Use when asked to verify a change, run the binary, smoke-test a feature, or check that the project still works.
---

# Verify ${PROJECT_NAME}

The handle is direct invocation of the built binaries; the evidence is stdout, stderr, exit codes, and logs. Update this file whenever a step below steers you wrong — it is the project's shared build/run/test recipe (rust-live-tester and the bundled /verify skill both read it).

## Build

\`\`\`bash
cargo build --workspace --all-features
\`\`\`

## Test

\`\`\`bash
cargo nextest run --workspace --all-features --lib --bins || cargo test --workspace --all-features
\`\`\`

## Run

HEADER
if [[ ${#BINS[@]} -eq 0 ]]; then
cat <<'NOBIN'
No binary targets detected. Verify through the test suite and doc-tests (`cargo test --doc`), or add the run command for your integration entry point here.
NOBIN
else
for bin in "${BINS[@]}"; do
cat <<BIN
\`\`\`bash
cargo run --bin ${bin} -- --help   # replace --help with the flow under verification
\`\`\`

BIN
done
fi
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
echo "Scaffold complete. ${#CRATES[@]} crate(s) detected."
echo ""
echo "Structure created:"
echo "  .local/handoff/          — agent communication (rust-agent-handoff)"
echo "  .local/plan/             — implementation plans (sdd)"
echo "  .local/team-results/     — team reports (rust-team)"
echo "  .local/testing/          — CI cycle knowledge base (ci-analyst)"
echo "    debug/  data/  playbooks/  scripts/  sessions/"
echo "    journal/  coverage-status.md  process-notes.md  regressions.md"
