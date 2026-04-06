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
  # Workspace project: extract members
  while IFS= read -r line; do
    # Strip quotes, whitespace, trailing comma
    crate=$(echo "$line" | sed 's/[",]//g' | xargs)
    # Expand simple globs like "crates/*"
    if [[ "$crate" == *"*"* ]]; then
      for dir in $crate; do
        [[ -d "$dir" ]] && CRATES+=("$(basename "$dir")")
      done
    elif [[ -n "$crate" ]]; then
      CRATES+=("$(basename "$crate")")
    fi
  done < <(sed -n '/^members\s*=\s*\[/,/\]/{ /members\s*=\s*\[/d; /\]/d; p; }' Cargo.toml)
fi

# Fallback: single-crate project
if [[ ${#CRATES[@]} -eq 0 ]]; then
  PROJECT_NAME=$(sed -n 's/^name\s*=\s*"\(.*\)"/\1/p' Cargo.toml | head -1)
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

# --- journal.md ---

write_if_missing ".local/testing/journal.md" <<'EOF'
# Testing Journal

Tracks live testing status for all features and components.
Updated after each testing session as part of the continuous improvement cycle.

---
EOF

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

# --- .claude/rules directory ---

mkdir -p .claude/rules
echo "Ensured .claude/rules/ exists."

echo ""
echo "Scaffold complete. ${#CRATES[@]} crate(s) detected."
echo ""
echo "Structure created:"
echo "  .local/handoff/          — agent communication (rust-agent-handoff)"
echo "  .local/plan/             — implementation plans (sdd)"
echo "  .local/team-results/     — team reports (rust-team)"
echo "  .local/testing/          — CI cycle knowledge base (ci-analyst)"
echo "    debug/  data/  playbooks/  scripts/  sessions/"
echo "    journal.md  coverage-status.md  process-notes.md  regressions.md"
