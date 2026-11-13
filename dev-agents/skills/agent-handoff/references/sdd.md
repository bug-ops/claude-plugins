# sdd Output Schema

Summary: spec package produced + phases run + open markers. Example: `"Spec package under specs/vault-rotation/: BRD, SRS, NFR, spec, plan, tasks; 3 NEEDS CLARIFICATION markers"`

## Output Sections

**Specification Summary** (required): feature, phases run, and key decisions taken from the plan and the critic findings.

**Spec Files** (required): one line per file — path, `created|modified`. Root is `specs/{feature-slug}/` in a `team-develop` run.

**Open Markers** (if any): each `[NEEDS CLARIFICATION: ...]` with the section that holds it.

**Scope Note** (if any): the scope was too small or too large for the requested pipeline, with the reason (pair with `status: needs_discussion`).
