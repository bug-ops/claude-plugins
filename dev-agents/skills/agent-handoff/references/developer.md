# developer Output Schema

Summary: what was implemented + key files/types. Example: `"Implemented Email newtype + User builder; 2 new files in src/user/, all tests pass"`

## Output Sections

**Implementation Summary** (required): what was implemented + key decisions.

**Files Changed** (required): one line per file — path, `created|modified|deleted`, what/why; mention key types inline. No code listings.

**Dependencies Added** (if any): name, version, reason. Follow the dependency rules in the stack profile's `toolchain.md`.

**Deviations** (if any): every change not required by the plan, spec, or task — what, where, why, approved by `architect` or `user` with a reference (message, handoff, or issue comment). A change without an approver must not be in the diff.

**TODOs** (if any): remaining work items.
