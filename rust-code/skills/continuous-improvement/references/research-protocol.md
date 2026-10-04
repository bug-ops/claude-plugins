# Research & Monitoring Protocol

## Delta Check on Unchanged HEAD

Dependency and parity state does not accumulate untested surface the way code does. When HEAD is unchanged since the last cycle, run a delta check only: new advisories, new releases of key dependencies and reference projects, and new activity since the dates in `competitive-parity.md`. Do not widen scope or repeat earlier scans.

## Research & Innovation

Proactively search for new techniques relevant to the project's domain:

- Architectural patterns (design patterns, concurrency models, state machines)
- Performance techniques (zero-copy, SIMD, memory layout optimization)
- Safety practices (compile-time guarantees, type-state patterns, capability-based design)
- Ecosystem evolution (new crates, deprecated dependencies, emerging standards)
- Tooling improvements (profiling, debugging, testing frameworks)

### Assessment Criteria

For each finding, evaluate:
1. Does it address a known gap or improve an existing capability?
2. What is the implementation complexity vs expected benefit?
3. Does it conflict with current architecture or design principles?
4. Is there a backing paper or established practice supporting it?

### Filing Research Issues

Before creating a research issue:

1. **Spawn SDD agent** — create a spec for the finding using the protocol in
   [SDD Integration](sdd-integration.md). Research specs capture WHAT capability
   is missing and WHY; not HOW to build it.
2. **Check duplicates**:
   ```bash
   gh issue list --label "research" --state open --limit 50
   ```
   If a closely related issue exists, add a comment with the new finding and
   the spec path instead of opening a duplicate.
3. **File** the research issue including:
   - Source material (links to papers, blog posts, crate docs)
   - How it applies to this project
   - Brief implementation sketch
   - Estimated complexity and benefit
   - `Spec: .local/specs/<NNN>-<slug>/spec.md`

Prioritize by: **impact on project quality > implementation simplicity > novelty**

## Dependency Monitoring

### Checking for Updates

```bash
cargo outdated --workspace          # Version drift
cargo deny check advisories         # Security advisories (RUSTSEC)
```

### Update Priority

| Priority | Trigger | Action |
|----------|---------|--------|
| Immediate | Security advisory (RUSTSEC), critical bug fix in core dep | File P0/P1 issue |
| Next PR | Minor/patch update with useful bug fixes or perf improvements | File P2 issue |
| Backlog | Major version bump requiring migration, cosmetic updates | File P3/P4 issue |

### After Filing Dependency Issues

Include in the issue:
- Current version vs available version
- Changelog highlights (breaking changes, security fixes)
- Migration effort estimate if major version
- Link to the advisory if security-related

Monitor changelogs for breaking changes in key dependencies. When a key dep releases a major version, assess migration effort and file an appropriately prioritized issue.

## Dependency Functionality Coverage

Beyond version health, ask whether each major dependency is used to its full capability. For every major crate in the dependency tree, read its docs and changelog for features the project could use but does not (built-in validation, cancellation or timeout primitives, structured tracing, zero-copy deserialization, derive macros that replace hand-rolled code). File a research or enhancement issue (not P0-P1) when an unused capability would measurably improve robustness, simplify code, or resolve an open issue. Do not file for stylistic preference.

## Competitive Parity Monitoring

### When to Run a Parity Scan

- A new major version of a reference project is released
- A relevant protocol or standard has a new version
- Monthly, as a dedicated scan (not mixed with feature testing)

### Identifying Reference Projects

For competitive parity, identify reference projects:
1. **Same tech stack** (Rust) — highest relevance, directly comparable
2. **Same domain** — feature and architecture inspiration regardless of language
3. **Academic research** — theoretical foundations for improvements

### What to Monitor

For each reference project, cover:
1. Core architecture and decision-making patterns
2. Memory and state management
3. Extension/plugin system design
4. Multi-backend or multi-provider support
5. Protocol and standard compliance
6. Safety, permissions, sandboxing
7. UX patterns and developer experience
8. Benchmarks and evaluation methodology
9. Performance characteristics

### How to Perform a Parity Scan

1. Check release notes / CHANGELOG for each reference project (last 1-2 releases)
2. For each new capability: assess whether this project has an equivalent
3. For protocol-level changes: verify compatibility
4. For feature gaps: identify capabilities present in 2+ reference projects that this project lacks
5. Cross-reference with academic literature when applicable
6. Check for duplicates before filing:
   ```bash
   gh issue list --label "research,enhancement" --state open --limit 100
   ```
7. File a `research` issue for each meaningful gap with:
   - Which project(s) implement it
   - Link to changelog / source / relevant PR
   - Link to backing paper if applicable
   - Brief implementation sketch

### Parity Gap Severity

| Label | Description |
|-------|-------------|
| P1 | Active incompatibility with a first-class integration target |
| P2 | Meaningful capability that 2+ reference projects have and users would notice |
| P3 | Useful feature in reference projects, low urgency |
| P4 | Cosmetic or niche difference |

### Parity Knowledge Base

Maintain `.local/testing/playbooks/competitive-parity.md` as a living document:
- One row per reference project with last-checked version and date
- Table of known gaps: feature / project(s) that have it / backing research / issue link / status
- Update after every parity scan

### Competitor Gap Analysis (optional)

For projects with direct competitors rather than reference libraries:

1. Compare each competitor's tool set, capabilities, configuration UX, and transport or protocol support with this project.
2. Check for an existing issue, then file each gap with the `competitor-gap` label (plus priority and `enhancement`), naming the competitor and the feature.
3. Record competitor, date, and gaps (or "no gaps") in the cycle journal.
4. A competitor is exhausted when a comparison yields no new gaps and every earlier gap is filed, fixed, or `wontfix`.
5. When all competitors are exhausted, search for a new analogue (GitHub, crates.io, npm, PyPI, registries, directories) that is actively maintained and overlaps in function. Add it to the competitor list in the project's CI rules and run the analysis on it immediately. If none qualifies, note the search date and queries in the journal and retry later.

## CVE and Vulnerability-Class Sweep (optional, monthly)

Find vulnerability classes before they are reported against this project by watching where equivalent code has already been hit. Run it as its own monthly pass, separate from the parity scan: parity gaps are missing features, CVE gaps are missing defenses, and they need different severity handling.

1. Search advisories (GitHub Advisory Database, NVD, RUSTSEC) published since the last sweep for the key dependencies and reference libraries.
2. For each advisory, identify the vulnerability class, not just the specific bug.
3. Map the class onto this project's own pipeline: does an existing validation already close the vector?
4. Confirm with a regression test or live scenario that reproduces the analogous attack; never assume coverage from a description.
5. Protected: add the regression test if missing, citing the CVE or GHSA id, and record the mitigation in the journal.
6. Unprotected: file a P0 security issue per Security Findings in [Issue Management](issue-management.md).
