# Changelog Format Reference

Based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/) with Semantic Versioning.

## Section Order

```markdown
## [X.Y.Z] - YYYY-MM-DD

### Added
### Changed
### Deprecated
### Removed
### Fixed
### Security
### Quality
### Dependencies
### Performance
```

Only include sections that have content. Never add empty sections.

## Comparison Links

Located at the bottom of CHANGELOG.md. Must be updated on every release.

### Format

```markdown
[Unreleased]: https://github.com/OWNER/REPO/compare/vLATEST...HEAD
[LATEST]: https://github.com/OWNER/REPO/compare/vPREVIOUS...vLATEST
[PREVIOUS]: https://github.com/OWNER/REPO/compare/vOLDER...vPREVIOUS
```

### Update Algorithm

When releasing version X.Y.Z (previous latest was A.B.C):

1. Change `[Unreleased]` link target from `vA.B.C...HEAD` to `vX.Y.Z...HEAD`
2. Add new line: `[X.Y.Z]: https://github.com/OWNER/REPO/compare/vA.B.C...vX.Y.Z`
3. Place it between `[Unreleased]` and `[A.B.C]` lines

### Example

Before:
```markdown
[Unreleased]: https://github.com/owner/repo/compare/v0.5.7...HEAD
[0.5.7]: https://github.com/owner/repo/compare/v0.5.6...v0.5.7
```

After releasing 0.5.8:
```markdown
[Unreleased]: https://github.com/owner/repo/compare/v0.5.8...HEAD
[0.5.8]: https://github.com/owner/repo/compare/v0.5.7...v0.5.8
[0.5.7]: https://github.com/owner/repo/compare/v0.5.6...v0.5.7
```

## Date Format

Always use ISO 8601: `YYYY-MM-DD`

Get current date:
```bash
date +%Y-%m-%d
```

## Quality Section (Project-specific)

Projects may include a Quality section with metrics:

```markdown
### Quality

- **Tests**: N (up from M)
- **Clippy**: Zero warnings
- **Coverage**: X%
```

This section is optional and project-dependent.
