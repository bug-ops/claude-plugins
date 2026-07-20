# rust-cicd-devops Output Schema

Summary: what was set up + jobs + matrix. Example: `"CI pipeline: check/test/coverage/security jobs; matrix ubuntu+macos"`

## Output Sections

**CI/CD Summary** (required): what was configured + key decisions.

**Workflows** (required): per file — path, `created|modified`, jobs list.

**Secrets Required** (if any): name + purpose.

**Matrix / Caching** (if configured): OS list, Rust versions, cache layers enabled.
