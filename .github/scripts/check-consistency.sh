#!/usr/bin/env bash
# Checks cross-file consistency of the dev-agents plugin definitions.
set -euo pipefail

plugin=dev-agents
status=0

fail() {
  echo "ERROR: $*" >&2
  status=1
}

known=$(
  ls "$plugin"/skills
  sed -n 's/^name: //p' "$plugin"/agents/*.md
)

while IFS=: read -r file ref; do
  grep -qxF "${ref#"$plugin":}" <<<"$known" || fail "$file references unknown '$ref'"
done < <(grep -rnoE --include='*.md' "$plugin:[a-z][a-z-]*" "$plugin/agents" "$plugin/skills" |
  sed -E 's/^([^:]+):[0-9]+:/\1:/')

# stack and agent-handoff load references by computed name, not by link
while IFS= read -r ref; do
  skill=${ref#"$plugin/skills/"}
  skill=${skill%%/*}
  [[ $skill != stack && $skill != agent-handoff ]] || continue
  grep -rqF --include='*.md' --exclude=CHANGELOG.md --exclude="$(basename "$ref")" \
    "$(basename "$ref")" "$plugin" || fail "orphaned reference ${ref#"$plugin/"}"
done < <(find "$plugin/skills" -path '*/references/*' -name '*.md')

for file in "$plugin"/agents/*.md; do
  suffix=$(grep -oE 'your suffix: `[a-z-]+`' "$file" | grep -oE '`[a-z-]+`' | tr -d '`' || true)
  case $suffix in
    '' | arch-analyst | security-analyst) continue ;;
  esac
  [[ -f "$plugin/skills/agent-handoff/references/$suffix.md" ]] ||
    fail "$file declares handoff suffix '$suffix' without agent-handoff/references/$suffix.md"
  grep -qF "\`$suffix\`" "$plugin/skills/agent-handoff/SKILL.md" ||
    fail "agent-handoff/SKILL.md does not list suffix '$suffix' from $file"
done

exit "$status"
