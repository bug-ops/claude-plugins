---
name: security-audit
description: "Vulnerability and security-hardening audit protocol for Rust and TypeScript projects. Maps the attack surface, then activates expert knowledge across dependency advisories, unsafe and escape-hatch code, secret exposure, injection and input validation, cryptography misuse, authentication and authorization, crash and resource-exhaustion denial of service, network and filesystem hardening, supply-chain trust, and verification gates. Language-specific scanners and vectors come from the stack profile. Called by security-analyst at startup via Skill(...); invoked directly as /security-audit [focus] it delegates the audit to a background security-analyst."
argument-hint: "[dependencies|unsafe|secrets|input|crypto|auth|panics|supply-chain|network|filesystem|gates|full]"
---

# Security Audit Protocol

You are performing a **read-only** security and vulnerability audit. Do NOT modify source files, manifests, or lockfiles. Identify vulnerabilities and file GitHub issues for findings. Fixes happen in a separate remediation session.

**Focus**: $ARGUMENTS (default: `full`)

## Direct Invocation

This protocol is loaded at startup via `Skill()` by `security-analyst` (which runs the audit) and by `security-maintenance` (which uses it as the vulnerability catalogue while fixing). When it is invoked directly (`/dev-agents:security-audit`) in a session that is **neither** of those agents, do not run the audit in the current context: delegate it so the findings, not the tool noise, land in the conversation.

```
Agent(subagent_type: "dev-agents:security-analyst", description: "security-audit $ARGUMENTS",
  prompt: "Call Skill(skill: \"dev-agents:security-audit\", args: \"$ARGUMENTS\") and follow it end to end. Report findings and filed issue URLs; do not modify source files.")
```

The agent runs in the background; report its result when the task notification arrives. If you **are** `security-analyst`, continue with the protocol below. If you are `security-maintenance`, read the protocol as the catalogue of vectors to check and prove closed; do not file audit issues from it.

## Language Profile (MANDATORY)

This protocol is language-neutral. For every profile detected by the `stack` skill, apply `${CLAUDE_PLUGIN_ROOT}/skills/stack/references/<profile>/security-audit.md`: under the same section numbers it holds the scanners and their commands, search patterns, advisory database, and language-specific vectors. Each section below is incomplete without it. In a polyglot repository, audit each language's code against its own profile and report findings per profile.

| Focus | What is audited |
|-------|-----------------|
| `dependencies` | Known advisories, unmaintained/deprecated/yanked packages, license violations, duplicate versions |
| `unsafe` | Unsafe and escape-hatch code: memory-unsafe blocks, FFI and native modules, type-system bypasses, dynamic code evaluation |
| `secrets` | Hardcoded keys/tokens/passwords, secrets in logs, errors, and client-shipped code, `.gitignore` gaps |
| `input` | SQL/NoSQL/command injection, path traversal, untrusted deserialization, prototype pollution, integer overflow, ReDoS, unvalidated external input |
| `crypto` | Weak algorithms, custom crypto, non-CSPRNG randomness, plaintext passwords, non-constant-time comparison |
| `auth` | Broken authn/authz, user enumeration, timing side-channels, insecure session/token handling |
| `panics` | Crash and resource-exhaustion DoS: panics, uncaught exceptions, and unhandled rejections on untrusted input; unbounded allocation or recursion; a blocked runtime or event loop |
| `supply-chain` | Build- and install-time code, registry sources and git dependencies, lockfile integrity, typosquatting and dependency confusion, provenance and vetting |
| `network` | SSRF, TLS verification, request/connection limits, CORS/CSRF, XSS and CSP, header and log injection, insecure defaults |
| `filesystem` | TOCTOU and symlink races, temp files, permission modes, zip-slip, decompression bombs |
| `gates` | Escape-hatch forbids, strict lint profiles, sanitizers, fuzz and property tests on parsers, scanners in CI |
| `full` | All categories |

## Core Principle

**Every trust boundary is an attack surface, and all external input is hostile until validated.** The audit ranks findings by *exploitability*, not by theoretical elegance: a known-exploitable advisory or a hardcoded credential outranks a defense-in-depth suggestion. Prove each finding with a concrete attack scenario — an input and the damage it causes. A vulnerability you cannot describe an attack for is a hardening note, not a P0.

Start with what is already known-vulnerable: run the dependency scanners first, because a matched advisory is a confirmed vulnerability with zero false-positive risk, whereas code-pattern findings require judgment.

Pattern searches only find what matches a pattern. Before the category passes, build the attack surface map (§0) and audit each boundary on it; every category below is then applied per boundary, not just per grep hit.

Reference frameworks for completeness checks: OWASP Top 10, CWE Top 25, and the language references the profile names. When a finding maps to a CWE, cite it.

**Unchanged HEAD** — never skip the audit and never re-audit the module you covered last. Read prior `journal/ci-*.md` entries (and `journal/archive/`) attributed to your role, pick the modules least recently audited, and audit those. Record the modules covered in the handoff.

**Scope structure (optional)** — when the project's CI rules define one, judge findings against it:

- **Trust boundaries** — where untrusted input enters; a finding is real only when an input on a listed boundary reaches the sink.
- **Accepted risks** — re-verify each cycle that the accepted condition still holds (for example, no unsafe code exists); do not re-file it. A change in the condition is a new finding.
- **Sensitive assets** — what an attacker would target; weight severity by reach to these.
- **Minimum floor** — a project checklist is a floor, re-derived against the code every cycle (new modules, dependencies, and entry points expand it), never a list to rubber-stamp.
- **CI-gated scanners** — when CI already runs a scanner on every push, a clean local run adds no signal; spend the effort on what CI does not cover (escape-hatch review, injection, crypto misuse, supply-chain trust).

---

## 0. Attack Surface Map

**Goal**: every place untrusted data or an untrusted party enters the program is listed before any pattern search starts.

Enumerate and record, with file paths:

- **Network listeners and handlers** — HTTP/gRPC routes, server actions, WebSocket handlers, raw socket readers; note authentication requirements per route.
- **Outbound requests** — any client whose URL, host, or headers derive from input (SSRF surface).
- **CLI arguments, environment, config files** — parsed by whom, validated where.
- **Files and archives read** — uploads, imports, plugin/config directories, anything extracted.
- **Deserialization sites** — every decode of external bytes, with its size and depth limits (or their absence).
- **IPC, signals, sockets, shared memory, worker messages** — local surfaces that are often assumed trusted.
- **Unsafe, FFI, and native-code boundaries** — where the language's guarantees stop.
- **Build- and install-time code** — build scripts, macros, code generators, package lifecycle scripts.
- **Client-delivered code** — anything bundled and shipped to browsers, where every embedded value is public.
- **Privileged operations** — process spawning, filesystem writes outside a sandbox, credential use, database mutations; for each, which boundary above can reach it.

Trace each entry point to the first privileged operation it can reach. That path is the audit unit for §4–§10: a finding is real when an input on a listed boundary reaches the sink.

---

## 1. Dependency Vulnerabilities

**Goal**: no dependency with a known, published vulnerability ships in the build.

Run the profile's scanners and read the output as the highest-confidence source of findings.

**Matched advisories** — every scanner hit is a confirmed vulnerability. Record the advisory id, the affected package and version, the fixed version, and whether it is reachable (a vulnerability in a dev-only or unused code path is lower severity than one on the request path).

**Unmaintained packages** — an unmaintained or deprecated marker means no security fixes will arrive. Flag it, and note whether a maintained alternative exists.

**Withdrawn versions** — a yanked, unpublished, or deprecated-for-security version in the lockfile means the release was withdrawn, often for a security or correctness defect. Treat as a finding.

**Duplicate/multiple versions** — several major versions of the same package inflate the audit surface and can mean an old, vulnerable copy is linked in transitively. Report the clusters.

**License violations** — a copyleft or unknown license pulled in transitively is a legal-exposure finding; report it under this category even though it is not a memory-safety issue.

Aggregate advisories: file **one** issue listing all current advisory hits rather than one issue per advisory, unless a single advisory is Critical and warrants its own tracked remediation.

---

## 2. Unsafe and Escape-Hatch Code

**Goal**: every construct that bypasses the language's guarantees is minimal, justified, and cannot be driven into undefined behavior, type confusion, or code execution by any caller.

**Undocumented bypass** — every unsafe block, cast on unvalidated data, or suppression must carry the profile's justification comment stating the invariant. Absence is a P1 finding: the invariant is either undocumented (unreviewable) or unknown (unsound).

**Reinterpretation of data** — any construct that tells the compiler a value has a type it was never checked to have. Flag every use; most are replaceable with a checked conversion or a schema.

**FFI and native boundaries** — foreign functions taking pointers, lengths, or buffers trust the caller completely. Any such entry point reachable from untrusted data is a high-severity surface; verify length and null checks precede every access.

**Dynamic code evaluation** — evaluating a string as code is code execution for whoever controls the string. Flag every use reachable from input.

**Uninitialized or unchecked memory** — APIs that skip initialization, validation, or bounds checks are sound only when an adjacent check guarantees the invariant.

The profile lists the constructs, the search commands, and the language-specific variants (thread-safety assertions, drop-time panics, sandbox APIs that are not security boundaries).

---

## 3. Secrets and Sensitive Data

**Goal**: no credential is committed, logged, embedded in the binary, or shipped to a client.

```bash
gitleaks detect --no-banner    # scans working tree and history
```

Then run the profile's source search for credential-shaped literals.

**Hardcoded credentials** — a string literal that is an API key, password, private key, or connection string with embedded credentials. This is a P0 the moment it is in git history: rotation, not deletion, is the fix, and that belongs in the issue text.

**Secrets in logs and errors** — a log call, error message, or debug representation that prints a token, password, key, or full request body. Secrets leak through logs into aggregation systems that have a wider audience than the database.

**Secrets in client-delivered code** — any value compiled into a browser bundle, mobile app, or published package is public. Check the profile's public-configuration conventions.

**`.gitignore` gaps** — `.env`, `*.key`, `*.pem`, `secrets/`, and credential config files must be ignored. A gap means the next `git add .` commits a secret. Verify coverage rather than assuming it.

**Secrets lingering in memory** — long-lived secret material held in ordinary strings survives use and can surface in a core dump or heap snapshot. Note it as a hardening finding where the profile offers a zeroizing type.

**Secrets in argv, environment, and CI logs** — a `--token` flag is visible to every user via `ps`; an environment variable is inherited by every child process and printed by crash reporters; a CI step that echoes its environment publishes the secret. Prefer files with restricted permissions, a secret store, or stdin, and check workflow logs for masked-value gaps.

---

## 4. Input Validation and Injection

**Goal**: no untrusted input reaches an interpreter, filesystem path, object prototype, or allocation size without validation.

**SQL and NoSQL injection** — queries assembled from runtime values by string building. The fix is always bound parameters; for document stores, reject operator objects in input. Grep with the profile's pattern and confirm each hit binds.

**Command injection** — a process spawned with a shell string built from external input. Passing user data as a discrete argument is safe (with an end-of-options marker when it may start with `-`); interpolating it into a shell string is not.

**Path traversal** — a filesystem path joined from external input without canonicalization lets `../../etc/passwd` escape the intended directory. The safe pattern extracts the file name, joins onto a fixed base, canonicalizes, and re-checks that the result is under the base.

**Untrusted deserialization** — decoding attacker-controlled bytes without a size cap or depth limit enables memory exhaustion; formats or libraries that reconstruct types or functions enable code execution. Verify a length bound precedes every decode.

**Object and prototype pollution** — merging, cloning, or assigning keys from untrusted input into shared objects lets an attacker set properties every object inherits. Applies where the language has mutable prototypes.

**Integer overflow and lossy conversions** — arithmetic or narrowing conversions on externally supplied sizes used for allocation or indexing. A wrapped or truncated length is a memory-safety or logic bug.

**Missing bounds on external quantities** — a count, size, or offset from the network used directly to allocate or loop lets a small malicious message request gigabytes. Every externally supplied quantity needs an explicit ceiling.

**XML external entities** — an XML parser with entity expansion or external entity resolution enabled on untrusted documents leaks files and pivots to SSRF (XXE, billion-laughs). Confirm the parser configuration disables both.

**Regular-expression denial of service** — a backtracking engine fed a user-supplied pattern or a crafted input hangs the worker. Also flag patterns compiled per request instead of once.

---

## 5. Cryptography

**Goal**: standard, current primitives used correctly; no home-grown crypto.

**Weak or broken algorithms** — MD5, SHA-1, DES, RC4, or ECB mode anywhere near a security decision. Flag their use for anything beyond non-security checksums.

**Home-grown cryptography** — a hand-written cipher, MAC, or "encryption" by XOR/rotation. Custom crypto is wrong by default; the finding is "replace with a vetted library" (the profile names them).

**Non-CSPRNG for secrets** — a general-purpose PRNG used to generate keys, tokens, nonces, IDs, or salts. Security-sensitive randomness must come from the OS CSPRNG. A predictable token is a guessable token.

**Plaintext or weakly-hashed passwords** — passwords stored raw, or hashed with a fast hash (SHA-256) instead of a password KDF (argon2, bcrypt, scrypt). A fast hash is brute-forceable; a bare hash with no salt is rainbow-table fodder.

**Non-constant-time comparison** — `==` on secrets (MACs, tokens, password hashes) leaks length and content through timing. Secret comparison must use a constant-time equality.

**Reused or hardcoded IV/nonce** — a fixed or counter-from-zero nonce with a stream cipher or GCM breaks confidentiality. Flag any hardcoded nonce/IV literal.

---

## 6. Authentication and Authorization

**Goal**: identity is verified before every privileged action, and the check cannot be bypassed or side-channeled.

**Missing authorization checks** — a handler that authenticates *who* the caller is but never checks *whether they may* perform the action. Enumerate privileged endpoints and confirm each gates on an ownership or role check, not merely on being logged in.

**User enumeration** — an auth path that returns distinguishable errors for "user not found" versus "wrong password" lets an attacker enumerate valid accounts. The response and timing for both cases must be identical. This pairs with the constant-time note in §5.

**Timing side-channels in auth** — an early return before password verification (short-circuiting on missing user) leaks account existence through response time even when the message is generic. Verify the verify step runs unconditionally.

**Insecure session/token handling** — tokens without expiry, session ids that are sequential or predictable, JWTs accepted with `alg: none`, without signature verification, or with an algorithm chosen by the token header, decoded instead of verified, or transmitted in URLs (where they land in logs and history). Flag each.

**Privilege escalation surfaces** — a role or permission field deserialized directly from client input, or an admin flag settable through a mass-assignment path.

---

## 7. Crash and Resource-Exhaustion Denial of Service

**Goal**: no untrusted input can crash the process, stall it, or exhaust its memory.

**Crash on untrusted input** — a parse, lookup, or conversion that panics or throws an uncaught error on malformed input is a remote crash: one bad request kills the worker. On the request path, every such site is a P2 DoS finding. (Crashes in tests, examples, build scripts, and startup are fine — scope the audit to request-handling code.)

**Unchecked indexing on external offsets** — an index from input used without a bounds check.

**Unbounded allocation** — covered in §4; an allocation sized by attacker-controlled input is memory-exhaustion DoS.

**Unbounded recursion** — a recursive parser (nested JSON, expression trees) with no depth limit overflows the stack on deeply-nested input. Verify a depth cap exists.

**Process-wide failure mode** — when one failure terminates the whole process rather than one task (abort-on-panic, crash-on-unhandled-rejection), every finding in this section rises in severity.

**Runtime starvation** — blocking or CPU-heavy work on an async runtime or event loop stalls every request on it; one slow request degrades all of them. Flag each, and any per-request task spawning or fan-out without a bound.

**Cancellation leaving state inconsistent** — work abandoned mid-way (timeout, race, client disconnect) after a partial write or half-completed transaction leaves corrupted state that a later request can exploit. Check multi-step mutations for cancel safety or an explicit rollback.

---

## 8. Supply-Chain Trust

**Goal**: understand and bound what third-party code executes at build, install, and run time.

**Build- and install-time code** — build scripts, compile-time macros, and package lifecycle scripts run arbitrary code on the developer's and CI machine with full permissions. Review every one that does network I/O, shells out, or writes outside its output directory. A malicious install or build script is the highest-leverage supply-chain attack.

**Dependency surface** — a large transitive graph is a large attack surface. Note single-maintainer, low-download, or recently-added dependencies on security-sensitive paths (crypto, parsing, auth) as candidates for vetting.

**Registry sources and git dependencies** — only the public registry and named private registries are allowed; a git dependency must pin a commit, since a branch or bare URL re-resolves to whatever the remote serves next. Applications commit their lockfile, otherwise every build resolves a different tree.

**Lockfile integrity** — resolved URLs point at the expected registry over HTTPS and every entry carries an integrity hash; a lockfile change that does not match a manifest change is a finding until explained.

**Typosquatting and dependency confusion** — the package name is the well-known one; internal package names resolve only from the private registry. A recently-added dependency with a near-duplicate name is a P1 until verified.

**Provenance and vetting** — for dependencies on security-sensitive paths, check the profile's vetting or provenance tooling.

---

## 9. Network and Service Hardening

**Goal**: the service cannot be turned into a proxy, cannot be starved by a single client, and does not trust the network more than it must.

**Server-side request forgery** — an outbound request whose URL, host, or port comes from input lets an attacker reach internal services and cloud metadata endpoints (`169.254.169.254`). Require an allowlist of hosts and schemes, resolve and re-check redirects, and block link-local and private ranges.

**TLS verification disabled** — certificate or hostname verification turned off, a custom verifier that accepts everything, or `http://` for credentialed traffic. Any of these on a non-test path is P1: the connection is plaintext to an active attacker.

**Missing request and connection limits** — no body-size cap, no header-count or header-size cap, no per-connection timeout, no maximum concurrent connections, no rate limit on expensive endpoints. Slowloris and oversized bodies exhaust memory or file descriptors with one client. Verify each limit exists at the framework or reverse-proxy layer.

**CORS and CSRF** — `Access-Control-Allow-Origin: *` with credentials, origin reflected without validation, or state-changing endpoints authenticated by cookies without a CSRF token or `SameSite` policy.

**Cross-site scripting and CSP** — untrusted data rendered as HTML, into a script context, or into a URL attribute (`javascript:` URLs) through a framework escape hatch; no Content-Security-Policy, or one that allows `unsafe-inline`/`unsafe-eval` for scripts.

**Header, CRLF, and log injection** — input written into response headers, redirect targets, or log lines without stripping `\r\n` lets an attacker forge headers or fake log entries. Unvalidated redirect targets are also open redirects.

**Insecure defaults** — binding `0.0.0.0` when only local access is needed, debug or metrics endpoints without authentication, verbose error bodies (stack traces, SQL) in production responses, default credentials in shipped config, cookies without `HttpOnly`/`Secure`.

---

## 10. Filesystem and Archives

**Goal**: file operations cannot be redirected, raced, or inflated by an attacker who controls names, links, or archive contents.

**TOCTOU and symlink races** — checking a path (exists, metadata, canonicalize) and then opening it lets an attacker swap a symlink in between. Open first, then validate the opened file, or operate on directory handles.

**Predictable temporary files** — hand-built names under `/tmp` are guessable and pre-creatable. Require atomic exclusive creation in a private directory.

**Permission modes** — secrets written with default umask are world-readable; `0o777` on directories invites tampering. Check the mode on every write of sensitive data.

**Zip-slip on extraction** — archive entries named `../../etc/cron.d/x` escape the destination unless each entry path is joined, canonicalized, and checked against the destination before writing. Applies to zip, tar, and custom formats.

**Decompression bombs** — decompressors and image decoders expand small inputs to gigabytes. Require a cap on decompressed size and on entry count.

---

## 11. Verification Gates

**Goal**: the project has automated defenses that keep the classes above from returning. Their absence is a finding in its own right (Low, or Medium on request-path code).

Gate classes; the profile names the concrete gates:

- Escape hatches forbidden by the compiler or linter wherever the code has no legitimate use for them.
- A strict lint profile on request-path code (crash sites, unchecked indexing, unhandled async errors, dynamic evaluation).
- Dynamic checkers or sanitizers on code containing unsafe or native constructs.
- A fuzz or property-test target for every parser of untrusted input (§0 lists them), and round-trip tests for encoders/decoders.
- Dependency scanners in CI, not only on developer machines, with the lockfile committed and installs frozen.

Report the gate matrix (present / absent per crate or package) in the handoff even when every gate is present — it is the evidence that the audit's negative findings hold.

---

## Triage and Filing

Assign a severity and map it to the cycle-journal priority column:

| Severity | Priority | Criteria |
|----------|----------|----------|
| **Critical** | `P0` | Actively exploitable now: committed secret, RCE, auth bypass, Critical advisory on the request path, secret shipped in a client bundle |
| **High** | `P1` | Clear exploit vector: injection, XSS, unsafe-code UB or type confusion, path traversal, undocumented unsafe code, weak/absent password hashing |
| **Medium** | `P2` | Real but bounded: crash-DoS on request path, weak crypto, advisory in a non-critical path, missing authz on a low-value action |
| **Low** | `P3` | Hardening / defense-in-depth: unmaintained deps without a known advisory, missing zeroize, license policy drift |

File a GitHub issue for every Critical, High, and Medium finding. Batch same-kind Low findings into one issue. The literal `P0`-`P3` label is set at creation (create it if missing; never use another priority scheme). Findings without a proven root cause are still filed as symptoms.

**P0 branch** — before filing a Critical finding publicly, check whether the repository supports private reporting (`SECURITY.md` routes to a private channel, or GitHub private vulnerability reporting is enabled). If so, use that channel; otherwise file a public issue labeled `P0`.

```bash
gh issue create \
  --title "<severity>: <concise vulnerability title>" \
  --label "<P0|P1|P2|P3>,security,vulnerability" \
  --body "$(cat <<'EOF'
## Vulnerability
<what is wrong>

## Severity
<Critical | High | Medium | Low> — <one-line justification>

## Location
<file:line>  (or dependency + advisory id)

## Attack Scenario
<concrete input/state and the resulting damage — the proof this is real>

## Remediation
<the specific fix; for a leaked secret, say "rotate", not "delete">

## References
<advisory id (RUSTSEC / GHSA / CVE) / CWE-NNN / advisory URL, if applicable>
EOF
)"
```

Skip false positives and note them briefly: escape-hatch code in a vendored/vetted dependency, crash-on-error in tests or startup, a string-built query that only ever interpolates a compile-time constant, weak hashing used for a non-security checksum. The profile lists the language forms. A finding you cannot attach an attack scenario to is at most a Low hardening note.

Do not duplicate an existing open security issue — check first:

```bash
gh issue list --label security --state open
```

---

## Handoff Output

Write your handoff with a **Security Review** section:

```markdown
## Security Review

### Summary
- Findings: <N total> (Critical: N, High: N, Medium: N, Low: N)
- Issues filed: <links>
- Scanners: <per profile, each scanner and its result, e.g. `<tool>`: N advisories> | `gitleaks`: <clean/N hits>
- Modules audited: <list; feeds least-recently-audited selection next cycle>

### Findings by Category
| Category | Count | Top Issue |
|----------|-------|-----------|
| Dependency advisories | N | <link or —> |
| Unsafe / escape-hatch code | N | ... |
| Secrets | N | ... |
| Input / injection | N | ... |
| Cryptography | N | ... |
| Auth / authz | N | ... |
| Crash / resource DoS | N | ... |
| Supply chain | N | ... |
| Network hardening | N | ... |
| Filesystem / archives | N | ... |
| Verification gates | N absent | ... |

### Top Security Risk
<One sentence: the single most exploitable finding, and whether it needs immediate rotation/patch>
```
