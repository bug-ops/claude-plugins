# rust-code-reviewer Output Schema

Summary: verdict + issue counts + key finding. Example: `"Changes requested: 1 critical (SQL injection in src/auth.rs:42), 2 important issues"`

## Output Sections

**Review Status** (required): `approved` | `changes_requested`

**Review Summary** (required): overall assessment, compressed.

**Issues** (if any): grouped Critical (must fix before merge) / Important (should fix) / Suggestions (non-blocking). Per issue: file:line — issue — fix.

**Files Reviewed** (required): list only files with `needs_changes`; summarize approved files as a count.
