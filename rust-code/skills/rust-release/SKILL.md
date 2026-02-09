---
name: rust-release
description: "Prepare Rust project release with version bump, changelog update, and documentation refresh. Triggers on: 'prepare release', 'bump version', 'release patch', 'release minor', 'release major', 'version bump', 'create release'. Supports single-crate and workspace projects."
---

# Rust Release Preparation

Automates release workflow: version bump, changelog finalization, documentation and README update, commit, push, and PR creation.

## Quick Reference

| Command | Description |
|---------|-------------|
| `/rust-release patch` | Bump patch version (0.5.7 -> 0.5.8) |
| `/rust-release minor` | Bump minor version (0.5.7 -> 0.6.0) |
| `/rust-release major` | Bump major version (0.5.7 -> 1.0.0) |

## Workflow

### Step 1: Parse Arguments and Detect Bump Type

The first argument determines the version bump type. If no argument is provided, ask the user.

Valid values: `patch`, `minor`, `major`.

```
BUMP_TYPE = first argument (patch | minor | major)
```

### Step 2: Detect Project Structure

Determine if the project is a single crate or a workspace.

```bash
# Check for workspace
grep -q "\[workspace\]" Cargo.toml && echo "workspace" || echo "single-crate"
```

For **workspace** projects, collect all member Cargo.toml paths:

```bash
# List workspace members
cargo metadata --no-deps --format-version 1 | jq -r '.packages[].manifest_path'
```

For **single-crate** projects, only the root `Cargo.toml` needs updating.

### Step 3: Calculate New Version

Read current version from the root `Cargo.toml`:

```bash
grep '^version' Cargo.toml | head -1 | sed 's/.*"\(.*\)"/\1/'
```

Apply semver bump:

| Bump Type | Current | New |
|-----------|---------|-----|
| `patch` | X.Y.Z | X.Y.(Z+1) |
| `minor` | X.Y.Z | X.(Y+1).0 |
| `major` | X.Y.Z | (X+1).0.0 |

**Display the calculated version to the user and ask for confirmation before proceeding.**

### Step 4: Create Release Branch

```bash
# Ensure working directory is clean
git status --porcelain

# Create release branch from current branch
git checkout -b release/vX.Y.Z
```

> [!WARNING]
> If working directory has uncommitted changes, warn the user and ask whether to stash or commit them first.

### Step 5: Update Version in Manifests

#### Single-crate project

Update `version = "X.Y.Z"` in the root `Cargo.toml` package section.

Use the Edit tool to replace the version string in `[package]` section:

```
old: version = "OLD_VERSION"
new: version = "NEW_VERSION"
```

#### Workspace project

1. Update root `Cargo.toml` workspace version (if `[workspace.package].version` exists)
2. Update each member's `Cargo.toml` version field
3. Update internal dependency versions that reference workspace members

After editing, verify the change compiles:

```bash
cargo check
```

### Step 6: Update Cargo.lock

```bash
cargo update --workspace
```

### Step 7: Update CHANGELOG.md

Read `CHANGELOG.md` and apply these transformations:

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

Extract `OWNER/REPO` from existing links in the changelog or from `Cargo.toml` repository field.

Extract `PREV` version from the previous latest version header.

### Step 8: Update README and Documentation

Invoke the `/readme-generator` skill to refresh the README with updated version numbers, badges, and installation instructions.

After the README generator completes, verify that version references in the README match the new version.

Additionally, search for and update version references in other documentation files:

```bash
# Find files referencing the old version
grep -r "OLD_VERSION" --include="*.md" --include="*.toml" --include="*.yml" --include="*.yaml" .
```

Update any hardcoded version references found (excluding CHANGELOG.md which was already updated).

### Step 9: Run Pre-Release Checks

Run the standard quality checks to verify nothing is broken:

```bash
# Format check
cargo +nightly fmt --check

# Tests
cargo nextest run

# Clippy
cargo clippy --all-targets --all-features -- -D warnings

# Build release
cargo build --release
```

> [!IMPORTANT]
> All checks must pass. If any check fails, fix the issue before proceeding.

### Step 10: Commit, Push, and Create PR

Stage all changed files and create a commit:

```bash
git add Cargo.toml Cargo.lock CHANGELOG.md README.md
# Add any other files that were updated
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
- [ ] CHANGELOG.md has release section with date
- [ ] README reflects new version
- [ ] All CI checks pass
- [ ] Ready for tagging after merge
EOF
)"
```

> [!IMPORTANT]
> The commit message and PR must NOT contain references to AI generation or co-authorship.

### Step 11: Summary

After all steps complete, display a summary:

```
Release vX.Y.Z

Branch: release/vX.Y.Z
PR: <PR_URL>

Updated files:
- Cargo.toml (version bump)
- Cargo.lock (dependency resolution)
- CHANGELOG.md (version section added)
- README.md (refreshed via readme-generator)
- [any other updated files]

After PR merge:
  git tag vX.Y.Z && git push origin vX.Y.Z
```

## Edge Cases

### Empty [Unreleased] Section

If `[Unreleased]` has no content, warn the user:

> No changes documented in [Unreleased] section. Consider adding release notes before proceeding.

Ask if they want to continue anyway or write release notes first.

### Pre-release Versions

For versions below 1.0.0, all bump types are valid. No special handling needed — semver rules still apply.

### Workspace Version Sync

In workspace projects, if `workspace.package.version` is used and members inherit via `version.workspace = true`, only the root version needs updating. Verify with:

```bash
grep -r "version.workspace = true" --include="Cargo.toml" .
```

## Anti-patterns

- Do not create git tags — that is CI/CD responsibility (tags are created after PR merge)
- Do not modify files outside the project directory
- Do not skip pre-release checks even for patch versions
- Do not mention AI tools in commit messages or PR descriptions
