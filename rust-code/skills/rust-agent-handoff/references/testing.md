# rust-testing-engineer Output Schema

Summary: tests added + coverage change + result. Example: `"Added 17 tests (12 unit, 3 integration, 2 property); coverage 45%->78%; all pass"`

## Output Sections

**Testing Summary** (required): what was tested + key findings.

**Tests** (required): counts by category (unit/integration/property), results (passed/failed/skipped), coverage before -> after vs target.

**Test Files** (required): paths with per-file test count. No test function name listings — names are visible in the diff.

**Gaps** (if any): uncovered paths worth attention.
