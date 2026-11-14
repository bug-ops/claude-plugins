# code-reviewer Output Schema

Summary: verdict + issue counts per severity + key finding. Example: `"Changes requested: 1 critical (SQL injection in src/auth.rs:42), 2 important, 3 suggestions, 1 nitpick"`

## Output Sections

**Review Status** (required): `approved` | `changes_requested`, also set as the frontmatter `verdict:` the lead routes on (`status:` stays `completed`). A `team-debug` consolidation uses `verdict: fixes_required | no_fixes_needed` instead. `approved` only with zero unresolved findings (each finding fixed, deferred with a GitHub issue URL, or, for an in-scope SUGGESTION, declined with a reason you accepted) and every chain follow-up triaged.

**Review Summary** (required): overall assessment, compressed.

**Issues** (if any): grouped Critical / Important / Suggestion / Nitpick — ALL findings of ALL severities, including unresolved findings consolidated from validator handoffs; low severity is never a reason to omit one. Deferred items carry their GitHub issue URL. Per issue: file:line — issue — fix. Each CRITICAL or IMPORTANT correctness finding about existing code also carries `evidence:` — a failing test or reproducer under a scratch path, or a command with its observed output; without it the finding is a Question for Authors.

**Questions for Authors** (if any): findings you could not back with executable evidence, as open questions.

**Declined Suggestions** (if any): one line per in-scope SUGGESTION the developer declined and the reviewer accepted — finding (file:line) — the developer's reason.

**Follow-up Issues** (if any): one line per triaged follow-up — issue URL (or `advisory`, `duplicate of #N`, `closed: <reason>`) — source (agent + handoff entry, or TODO marker at file:line) — priority. Includes every marker the developer must rewrite to `TODO(#N)`.

**Files Reviewed** (required): list only files with `needs_changes`; summarize approved files as a count.
