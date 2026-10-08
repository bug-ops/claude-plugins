---
name: release
description: "Prepare a release for Rust and TypeScript projects: version bump across every manifest, changelog finalization, documentation refresh, pre-release verification gates, and a release PR. Supports single-package projects, workspaces/monorepos, and polyglot repositories."
when_to_use: "'prepare release', 'bump version', 'release patch', 'release minor', 'release major', 'version bump', 'create release'."
argument-hint: "[patch|minor|major]"
---

# Release Preparation

Automates the release workflow: version bump, changelog finalization, documentation and README update, verification gates, commit, push, and PR creation. Tagging and publishing happen after the PR merges.

## Quick Reference

| Command | Description |
|---------|-------------|
| `/release patch` | Bump patch version (0.5.7 -> 0.5.8) |
| `/release minor` | Bump minor version (0.5.7 -> 0.6.0) |
| `/release major` | Bump major version (0.5.7 -> 1.0.0) |

## Workflow

### Step 1: Parse Arguments and Detect Bump Type

The first argument determines the version bump type. If no argument is provided, ask the user.

Valid values: `patch`, `minor`, `major`.

```
BUMP_TYPE = first argument (patch | minor | major)
```

### Step 2: Load the Stack Profile

Call `Skill(skill: "dev-agents:stack")` and detect the stack (`rust`, `typescript`, or both). For every detected profile, Read:

- `${CLAUDE_PLUGIN_ROOT}/skills/stack/references/<profile>/toolchain.md` — full check suite, version policy
- `${CLAUDE_PLUGIN_ROOT}/skills/stack/references/<profile>/release.md` — manifests, version inheritance, lockfile refresh, publish gates, tag naming

If the `Skill` tool is not available, Read `${CLAUDE_PLUGIN_ROOT}/skills/stack/SKILL.md` and follow its detection table. Apply each profile's release mechanics to the manifests of its language only. If no profile matches, stop and ask the user where the version lives — never guess manifest edits.

### Step 3: Detect Project Structure

Using the profile's release mechanics, determine:

1. **Versioned units** — the single package, or every workspace member that carries a version. Skip units marked unpublished/private unless the project versions them anyway.
2. **Version source of truth** — one root version inherited by members, or one version per unit.
3. **Versioning mode** — lockstep (all units share one version) or independent (per-unit versions, often driven by a release tool such as changesets). In a polyglot repository (e.g. a Rust core with npm bindings), assume lockstep across profiles unless the project documents otherwise.
4. **Release tooling already in place** — a tool that owns version bumps and changelogs (see the profile file). When one exists, drive it instead of editing manifests by hand, and tell the user.

### Step 4: Calculate New Version

Read the current version from the source of truth found in Step 3. Apply the semver bump:

| Bump Type | Current | New |
|-----------|---------|-----|
| `patch` | X.Y.Z | X.Y.(Z+1) |
| `minor` | X.Y.Z | X.(Y+1).0 |
| `major` | X.Y.Z | (X+1).0.0 |

Check the bump against the changes being released: a breaking change in the public API, a raised minimum toolchain/runtime version (see the version policy in `toolchain.md`), or a removed feature/export requires `major` (or `minor` below 1.0.0, where the minor position is the breaking one). If the `[Unreleased]` notes or the profile's API-compatibility gate disagree with the requested bump, say so.

**Display the calculated version (per unit in independent mode) to the user and ask for confirmation before proceeding.**

### Step 5: Create Release Branch

```bash
# Ensure working directory is clean
git status --porcelain

# Create release branch from current branch
git checkout -b release/vX.Y.Z
```

> [!WARNING]
> If working directory has uncommitted changes, warn the user and ask whether to stash or commit them first.

### Step 6: Update Version in Manifests

Follow the profile's release mechanics for every detected profile:

1. Update the source-of-truth version (root or per unit).
2. Update every member that does not inherit it.
3. Update internal dependency references between units that pin a version.
4. Update secondary version carriers the profile lists (registry manifests, version constants, bindings packages).

Use the Edit tool for each change. After editing, run the profile's fast check to confirm the manifests still resolve.

### Step 7: Refresh Lockfiles

Run the profile's lockfile refresh so every lockfile records the new versions. Never edit a lockfile by hand.

### Step 8: Update CHANGELOG.md

Read `CHANGELOG.md` and apply these transformations (format details: [references/changelog-format.md](references/changelog-format.md)):

1. **Add new version header** under `## [Unreleased]`:

```markdown
## [Unreleased]

## [X.Y.Z] - YYYY-MM-DD
```

Where `YYYY-MM-DD` is today's date.

2. **Move content** from `[Unreleased]` section into the new version section. If `[Unreleased]` is empty, add a placeholder:

```markdown
## [X.Y.Z] - YYYY-MM-DD

### Changed

- Version bump to X.Y.Z
```

3. **Update comparison links** at the bottom of the file:

```markdown
[Unreleased]: https://github.com/OWNER/REPO/compare/vX.Y.Z...HEAD
[X.Y.Z]: https://github.com/OWNER/REPO/compare/vPREV...vX.Y.Z
```

Extract `OWNER/REPO` from existing links in the changelog or from the manifest's repository field.

Extract `PREV` version from the previous latest version header.

When a release tool generates per-package changelogs (independent mode), let it write them and only finalize the root changelog if the project keeps one.

### Step 9: Update README and Documentation

Invoke the `/dev-agents:readme-generator` skill to refresh the README with updated version numbers, badges, and installation instructions.

After the README generator completes, verify that version references in the README match the new version.

Additionally, search for and update version references in other documentation files:

```bash
# Find files referencing the old version (add the manifest types from the profile file)
grep -r "OLD_VERSION" --include="*.md" --include="*.yml" --include="*.yaml" .
```

Update any hardcoded version references found (excluding CHANGELOG.md which was already updated). Leave lockfiles, vendored dependencies, and build output alone.

### Step 10: Run Pre-Release Gates

All must pass; if any fails, fix the issue before proceeding. For every detected profile:

1. **Full check suite** from `toolchain.md` — format, lint, type/compile check, tests, doc gate. When the project's CI or `.claude/rules/branching.md` defines its own commands, run those exactly.
2. **Release build** — the profile's optimized/production build.
3. **Package dry run** — the profile's publish dry run; inspect what would ship.
4. **API compatibility** — the profile's breaking-change check against the last released version; it must agree with the bump type.
5. **Version policy** — the declared minimum toolchain/runtime still builds, or its raise is documented as breaking.

> [!IMPORTANT]
> Do not skip gates for patch releases. A gate that cannot run (tool not installed, no previous release) is reported in the summary, not silently dropped.

### Step 11: Commit, Push, and Create PR

Stage all changed files and create a commit:

```bash
# Manifests and lockfiles listed in the profile's release mechanics, plus docs
git add CHANGELOG.md README.md <manifests> <lockfiles>
git add <other_updated_files>

git commit -m "release: prepare vX.Y.Z"
```

Push the release branch to remote:

```bash
git push -u origin release/vX.Y.Z
```

Create a Pull Request using `gh`:

```bash
gh pr create --title "release: vX.Y.Z" --body "$(cat <<'EOF'
## Summary

- Bump version from OLD_VERSION to X.Y.Z
- Update CHANGELOG.md with release notes
- Refresh README and documentation

## Checklist

- [ ] Version updated in all manifests
- [ ] Lockfiles refreshed
- [ ] CHANGELOG.md has release section with date
- [ ] README reflects new version
- [ ] Package dry run and API compatibility check pass
- [ ] All CI checks pass
- [ ] Ready for tagging after merge
EOF
)"
```

> [!IMPORTANT]
> The commit message and PR must NOT contain references to AI generation or co-authorship.

### Step 12: Summary

After all steps complete, display a summary:

```
Release vX.Y.Z

Branch: release/vX.Y.Z
PR: <PR_URL>

Updated files:
- <manifests> (version bump)
- <lockfiles> (refreshed)
- CHANGELOG.md (version section added)
- README.md (refreshed via readme-generator)
- [any other updated files]

Gates: <passed / skipped with reason>

After PR merge:
  git tag vX.Y.Z && git push origin vX.Y.Z
```

Use the profile's tag naming when units are versioned independently (one tag per released unit).

## Edge Cases

### Empty [Unreleased] Section

If `[Unreleased]` has no content, warn the user:

> No changes documented in [Unreleased] section. Consider adding release notes before proceeding.

Ask if they want to continue anyway or write release notes first.

### Pre-release Versions

For versions below 1.0.0, all bump types are valid; semver rules still apply, with the minor position signalling breaking changes. Pre-release identifiers (`1.2.0-rc.1`) follow the profile's rules for registries and dist channels.

### Inherited Versions

When members inherit a workspace-level version, only the root version changes. The profile file lists how to confirm inheritance.

## Anti-patterns

- Do not create git tags — that is CI/CD responsibility (tags are created after PR merge)
- Do not publish to a registry from this skill — publishing runs from CI after the tag
- Do not modify files outside the project directory
- Do not skip pre-release gates even for patch versions
- Do not hand-edit lockfiles
- Do not mention AI tools in commit messages or PR descriptions
