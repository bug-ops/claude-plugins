# rust-code-reviewer Output Schema

Summary: verdict + issue counts per severity + key finding. Example: `"Changes requested: 1 critical (SQL injection in src/auth.rs:42), 2 important, 3 suggestions, 1 nitpick"`

## Output Sections

**Review Status** (required): `approved` | `changes_requested`. `approved` only with zero unresolved findings (each finding fixed or deferred with a GitHub issue URL).

**Review Summary** (required): overall assessment, compressed.

**Issues** (if any): grouped Critical / Important / Suggestion / Nitpick — ALL findings of ALL severities, including unresolved findings consolidated from validator handoffs; low severity is never a reason to omit one. Deferred items carry their GitHub issue URL. Per issue: file:line — issue — fix.

**Files Reviewed** (required): list only files with `needs_changes`; summarize approved files as a count.
