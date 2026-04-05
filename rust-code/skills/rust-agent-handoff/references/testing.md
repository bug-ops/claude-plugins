# rust-testing-engineer Output Schema

## Summary Field (frontmatter)

One sentence covering: tests added + coverage change + result.

Example: `"Added 17 tests (12 unit, 3 integration, 2 property); coverage 45%→78%; all pass"`

## Output Sections

**Testing Summary** (required): What testing work was done and key findings.

**Tests Added** (required): Count by category — unit, integration, property.

**Coverage** (required): Before %, after %, target %.

**Test Results** (required): Total, passed, failed, skipped counts.

**Test Files** (required): For each file — path and list of test function names added.

**Gaps** (if any): Identified coverage gaps or paths not covered.

## Coverage Targets

| Category | Target |
|----------|--------|
| Critical paths | 80%+ |
| Business logic | 70%+ |
| Overall | 60%+ |

## Test Naming Convention

`test_{function}_{scenario}` — e.g. `test_email_parse_valid`, `test_user_builder_missing_required`
