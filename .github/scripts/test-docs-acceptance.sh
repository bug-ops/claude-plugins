#!/usr/bin/env bash
# Machine-checkable doc-level acceptance for #84, #85, #79 (M4, M7, M10) and #77.
set -uo pipefail

cd "$(dirname "$0")/../.." || exit 1
status=0
plugin=dev-agents
rust=$plugin/skills/stack/references/rust

check() { # <name> <command...>
  local name=$1
  shift
  if "$@" >/dev/null 2>&1; then echo "ok   $name"; else
    echo "FAIL $name" >&2
    status=1
  fi
}
has() { grep -qF -- "$2" "$1"; }

# #84: no #[allow( exception example outside the two files that list it as a pattern to flag
stray_allow() { [[ -z $(grep -rn --include='*.md' '#\[allow(' "$rust" | grep -vE "^$rust/(critic|arch-inspect)\.md:") ]]; }
check "#84 no #[allow( exception example in the rust references" stray_allow
check "#84 init.md has the Lint Baseline section" grep -q '^## Lint Baseline' "$rust/init.md"
check "#84 toolchain.md has the Lint Policy section" grep -q '^## Lint Policy' "$rust/toolchain.md"
for f in toolchain architect arch-inspect security-audit security; do
  check "#84 $f.md links to init.md#lint-baseline" has "$rust/$f.md" 'init.md#lint-baseline'
done
check "#84 init-project audits the Lint Baseline" has "$plugin/skills/init-project/SKILL.md" 'Lint Baseline'
check "#84 developer.md exception form is #[expect]" has "$rust/developer.md" '#[expect('

# #85: structural API ban as the first-choice fix
ci_item() { awk '/^2\. If a bug category recurs/{p=1;print;next} p&&/^[0-9]+\. /{exit} p' "$plugin/skills/continuous-improvement/SKILL.md"; }
ci_has() { ci_item | grep -qF -- "$1"; }
check "#85 continuous-improvement step 2 names disallowed-methods" ci_has disallowed-methods
check "#85 continuous-improvement step 2 carries the fast-yaml example" ci_has 'saphyr_parser::Parser::new'
check "#85 reviewer.md asks the disallowed-methods question" has "$rust/reviewer.md" 'disallowed-methods'
check "#85 developer.md exception is #[expect(clippy::disallowed_methods" has "$rust/developer.md" '#[expect(clippy::disallowed_methods'
check "#85 Lint Policy covers disallowed-methods" has "$rust/toolchain.md" 'disallowed-methods'

# #79 M4: read-only roles may keep their own reproducer
for a in 06-code-reviewer 09-critic 15-arch-analyst 16-security-analyst; do
  check "#79 M4 $a states the own-reproducer exception" has "$plugin/agents/$a.md" 'except a reproducer you created in this session'
done

# #79 M10: Stryker never installed implicitly
check "#79 M10 typescript testing.md guards Stryker with --no-install" has "$plugin/skills/stack/references/typescript/testing.md" 'npx --no-install stryker --version'

# #79 M7: hidden bench files carry the canary
canary_missing() { [[ -n $(ls -d bench/tasks/*/hidden 2>/dev/null) && -z $(grep -rL 'BENCH-HIDDEN-CANARY' bench/tasks/*/hidden) ]]; }
check "#79 M7 every bench hidden file has BENCH-HIDDEN-CANARY" canary_missing
canary_edges() {
  local f
  local n=0
  while IFS= read -r f; do
    n=$((n + 1))
    head -n 3 "$f" | grep -qF BENCH-HIDDEN-CANARY || return 1
    tail -n 3 "$f" | grep -qF BENCH-HIDDEN-CANARY || return 1
  done < <(find bench/tasks -path '*/hidden/*' -type f)
  ((n > 0))
}
check "#79 M7 canary is within the first 3 lines and the last 3 lines of every hidden file" canary_edges

# #77: CI runs both scripts after the consistency step; the README stops saying otherwise
line_of() { grep -nF -- "$1" .github/workflows/validate.yml | head -1 | cut -d: -f1; }
ordered() {
  local c h s
  c=$(line_of 'check-consistency.sh') h=$(line_of 'bash .github/scripts/test-hooks.sh') s=$(line_of 'bash bench/selftest.sh')
  [[ -n $c && -n $h && -n $s ]] && ((h > c && s > c))
}
check "#77 validate.yml runs test-hooks.sh and selftest.sh after the consistency step" ordered
no_ci_claim() { [[ -z $(grep -F 'does not run in CI' "$plugin/README.md") ]]; }
check "#77 README no longer says the hook tests do not run in CI" no_ci_claim

exit "$status"
