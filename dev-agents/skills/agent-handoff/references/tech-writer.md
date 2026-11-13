# tech-writer Output Schema

Summary: what was written + doc type + build/check result. Example: `"Rewrote README install and feature-flag sections; links checked, doc-tests pass"`

## Output Sections

**Documentation Summary** (required): doc type (README, doc comments, mdBook, changelog narrative) + what changed and why.

**Files Changed** (required): one line per file — path, `created|modified`, what changed. No content listings.

**Verification** (required): the doc gate that ran (mdBook build, doc build, doc-tests, link check) and its result.

**Open Questions** (if any): facts the writer could not confirm from the code.
