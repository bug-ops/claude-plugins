---
name: security-audit
description: "Vulnerability and security-hardening audit protocol for Rust projects. Activates expert knowledge across dependency advisories, unsafe code, secret exposure, injection and input validation, cryptography misuse, authentication and authorization, panic-based denial of service, and supply-chain trust. Called by rust-security-analyst at startup via Skill(...). When invoked directly as /security-audit [focus], the current session runs the audit without spawning subagents."
argument-hint: "[dependencies|unsafe|secrets|input|crypto|auth|panics|supply-chain|full]"
---

# Security Audit Protocol

You are performing a **read-only** security and vulnerability audit. Do NOT modify source files, `Cargo.toml`, or `Cargo.lock`. Identify vulnerabilities and file GitHub issues for findings. Fixes happen in a separate remediation session.

**Focus**: $ARGUMENTS (default: `full`)

| Focus | What is audited |
|-------|-----------------|
| `dependencies` | RUSTSEC advisories, unmaintained/yanked crates, license violations, duplicate versions |
| `unsafe` | `unsafe` without `// SAFETY:`, `transmute`, raw-pointer arithmetic, FFI boundaries, hand-written `Send`/`Sync` |
| `secrets` | Hardcoded keys/tokens/passwords, secrets in logs and error messages, `.gitignore` gaps |
| `input` | SQL/command injection, path traversal, untrusted deserialization, integer overflow, unvalidated external input |
| `crypto` | Weak algorithms, custom crypto, non-CSPRNG randomness, plaintext passwords, non-constant-time comparison |
| `auth` | Broken authn/authz, user enumeration, timing side-channels, insecure session/token handling |
| `panics` | `unwrap`/`expect`/indexing/unbounded allocation on untrusted input (denial of service) |
| `supply-chain` | `build.rs` and proc-macro trust, dependency surface, unsafe footprint via `cargo geiger` |
| `full` | All categories |

## Core Principle

**Every trust boundary is an attack surface, and all external input is hostile until validated.** The audit ranks findings by *exploitability*, not by theoretical elegance: a known-exploitable advisory or a hardcoded credential outranks a defense-in-depth suggestion. Prove each finding with a concrete attack scenario — an input and the damage it causes. A vulnerability you cannot describe an attack for is a hardening note, not a P0.

Start with what is already known-vulnerable: run the dependency scanners first, because a matched RUSTSEC advisory is a confirmed vulnerability with zero false-positive risk, whereas code-pattern findings require judgment.

---

## 1. Dependency Vulnerabilities

**Goal**: no dependency with a known, published vulnerability ships in the build.

Run the scanners and read the output as the highest-confidence source of findings:

```bash
cargo audit                    # RUSTSEC advisory database, reads Cargo.lock
cargo deny check advisories    # same DB, plus deny.toml policy
cargo deny check bans          # duplicate/banned versions
cargo deny check licenses      # license policy violations
cargo outdated --root-deps-only  # direct deps behind latest
```

**Matched advisories** — every `cargo audit` hit is a confirmed vulnerability. Record the RUSTSEC id, the affected crate and version, the fixed version, and whether it is reachable (a vulnerability in a dev-only or unused code path is lower severity than one on the request path).

**Unmaintained crates** — an advisory of kind `unmaintained` means no security fixes will arrive. Flag it, and note whether a maintained alternative exists.

**Yanked versions** — a version yanked from crates.io in `Cargo.lock` means the release was withdrawn, often for a security or correctness defect. Treat as a finding.

**Duplicate/multiple versions** — several major versions of the same crate inflate the audit surface and can mean an old, vulnerable copy is linked in transitively. Report clusters flagged by `cargo deny check bans`.

**License violations** — a copyleft or unknown license pulled in transitively is a legal-exposure finding; report it under this category even though it is not a memory-safety issue.

Aggregate advisories: file **one** issue listing all current `cargo audit` hits rather than one issue per advisory, unless a single advisory is Critical and warrants its own tracked remediation.

---

## 2. Unsafe Code

**Goal**: every `unsafe` block is minimal, justified, and cannot be driven into undefined behavior by any caller.

```bash
cargo geiger                   # counts unsafe usage per crate
rg -n "unsafe " --type rust
```

**`unsafe` without `// SAFETY:`** — every `unsafe` block and every `unsafe fn` must carry a `// SAFETY:` comment stating the invariants that make it sound. Absence is a P1 finding: the invariant is either undocumented (unreviewable) or unknown (unsound).

**`std::mem::transmute`** — the most dangerous primitive in the language. Flag every use. Most are replaceable with a safe conversion (`as`, `from_bits`, `bytemuck`); the rest need an airtight size-and-validity argument.

**Raw-pointer arithmetic and dereference** — `ptr.add`, `ptr.offset`, `*ptr` reachable from public input can produce out-of-bounds access. Verify the bound is checked against the same length the pointer was derived from.

**FFI boundaries** — `extern "C"` functions taking pointers and lengths trust the caller completely. Any FFI entry point reachable from untrusted data (network, file, IPC) is a high-severity surface; verify length and null checks precede every dereference.

**Hand-written `unsafe impl Send`/`Sync`** — asserts thread-safety the compiler could not prove. Each one must justify why concurrent access is actually sound; an incorrect one is a data race, which is UB.

**`from_utf8_unchecked` / `get_unchecked`** — skip validation and bounds checks. Sound only when a preceding check guarantees the invariant; flag any use where that guarantee is not immediately adjacent and obvious.

---

## 3. Secrets and Sensitive Data

**Goal**: no credential is committed, logged, or embedded in the binary.

```bash
gitleaks detect --no-banner    # scans working tree and history
rg -n -i "api[_-]?key|secret|password|token|BEGIN (RSA|EC|OPENSSH) PRIVATE KEY" --type rust
```

**Hardcoded credentials** — a string literal that is an API key, password, private key, or connection string with embedded credentials. This is a P0 the moment it is in git history: rotation, not deletion, is the fix, and that belongs in the issue text.

**Secrets in logs and errors** — a `tracing`/`log` call or an `Error`/`Debug` impl that prints a token, password, key, or full request body. Secrets leak through logs into aggregation systems that have a wider audience than the database. Look for `{:?}` on types holding credentials and for `Display` impls that echo input.

**`.gitignore` gaps** — `.env`, `*.key`, `*.pem`, `secrets/`, and credential config files must be ignored. A gap means the next `git add .` commits a secret. Verify coverage rather than assuming it.

**Secrets not zeroized** — a credential held in a `String`/`Vec<u8>` lingers in memory after use and can surface in a core dump. For long-lived secret material, note the absence of a `zeroize`-backed type as a hardening finding.

---

## 4. Input Validation and Injection

**Goal**: no untrusted input reaches an interpreter, filesystem path, or allocation size without validation.

**SQL injection** — string-built queries. `format!`, `+`, or `write!` assembling SQL with runtime values is the signature; the fix is always parameterized queries (`$1` bind parameters). Grep the pattern and confirm each hit uses binding:

```bash
rg -n 'format!\(.*(SELECT|INSERT|UPDATE|DELETE|WHERE)' --type rust -i
```

**Command injection** — `std::process::Command` with an argument or, worse, a shell string (`sh -c`) built from external input. Passing user data as a discrete `.arg()` is safe; interpolating it into a shell string is not.

**Path traversal** — a filesystem path joined from external input without canonicalization lets `../../etc/passwd` escape the intended directory. The safe pattern extracts `file_name()`, joins onto a fixed base, canonicalizes, and re-checks `starts_with(base)`. Flag any `Path::join`/`PathBuf::from` on request data missing this guard.

**Untrusted deserialization** — `serde_json`/`bincode`/`rmp` decoding attacker-controlled bytes without a size cap or depth limit enables memory-exhaustion and, for formats that carry type info, worse. Verify a length bound precedes the decode.

**Integer overflow and lossy casts** — `as` truncation (`len as u32`), and arithmetic on externally-supplied sizes used for allocation or indexing. In release builds arithmetic wraps silently; a wrapped length used as an allocation size or slice bound is a memory-safety bug. Prefer `checked_*`/`try_into()` and flag `as` casts on untrusted magnitudes.

**Missing bounds on external quantities** — a count, size, or offset from the network used directly to allocate (`Vec::with_capacity(n)`) or loop lets a small malicious message request gigabytes. Every externally-supplied quantity needs an explicit ceiling.

---

## 5. Cryptography

**Goal**: standard, current primitives used correctly; no home-grown crypto.

**Weak or broken algorithms** — MD5, SHA-1, DES, RC4, or ECB mode anywhere near a security decision. Grep for the crate names (`md5`, `sha1`) and flag their use for anything beyond non-security checksums.

**Home-grown cryptography** — a hand-written cipher, MAC, or "encryption" by XOR/rotation. Custom crypto is wrong by default; the finding is "replace with a vetted crate" (`ring`, `RustCrypto`, `age`).

**Non-CSPRNG for secrets** — `rand::thread_rng()`/`rand::random()` used to generate keys, tokens, nonces, or salts. Security-sensitive randomness must come from a CSPRNG (`OsRng`, `rand::rngs::OsRng`). A predictable token is a guessable token.

**Plaintext or weakly-hashed passwords** — passwords stored raw, or hashed with a fast hash (SHA-256) instead of a password KDF (`argon2`, `bcrypt`, `scrypt`). A fast hash is brute-forceable; a bare hash with no salt is rainbow-table fodder.

**Non-constant-time comparison** — `==` on secrets (MACs, tokens, password hashes) leaks length and content through timing. Secret comparison must use a constant-time equality (`subtle::ConstantTimeEq`, `ring::constant_time`).

**Reused or hardcoded IV/nonce** — a fixed or counter-from-zero nonce with a stream cipher or GCM breaks confidentiality. Flag any hardcoded nonce/IV literal.

---

## 6. Authentication and Authorization

**Goal**: identity is verified before every privileged action, and the check cannot be bypassed or side-channeled.

**Missing authorization checks** — a handler that authenticates *who* the caller is but never checks *whether they may* perform the action. Enumerate privileged endpoints and confirm each gates on an ownership or role check, not merely on being logged in.

**User enumeration** — an auth path that returns distinguishable errors for "user not found" versus "wrong password" lets an attacker enumerate valid accounts. The response and timing for both cases must be identical. This pairs with the constant-time note in §5.

**Timing side-channels in auth** — an early return before password verification (short-circuiting on missing user) leaks account existence through response time even when the message is generic. Verify the verify step runs unconditionally.

**Insecure session/token handling** — tokens without expiry, session ids that are sequential or predictable, JWTs accepted with `alg: none` or without signature verification, or tokens transmitted in URLs (where they land in logs and history). Flag each.

**Privilege escalation surfaces** — a role or permission field deserialized directly from client input, or an admin flag settable through a mass-assignment path.

---

## 7. Panic-Based Denial of Service

**Goal**: no untrusted input can crash the process or exhaust its memory.

**`unwrap`/`expect` on untrusted input** — a parse, lookup, or conversion that panics on malformed input is a remote crash: one bad request kills the worker. On the request path, every `unwrap`/`expect` on external data is a P2 DoS finding. (Panics in tests, examples, build scripts, and `main` startup are fine — scope the audit to request-handling code.)

**Slice indexing on external offsets** — `slice[i]` where `i` comes from input panics out of bounds. Use `.get(i)` and handle `None`.

**Unbounded allocation** — covered in §4; a `Vec::with_capacity(n)` or `vec![0; n]` with attacker-controlled `n` is memory-exhaustion DoS.

**Unbounded recursion** — a recursive parser (nested JSON, expression trees) with no depth limit stack-overflows on deeply-nested input. Verify a depth cap exists.

**`panic = "abort"` interactions** — if the project sets `panic = "abort"`, any reachable panic terminates the whole process rather than one task; this raises the severity of every §7 finding.

---

## 8. Supply-Chain Trust

**Goal**: understand and bound what third-party code executes at build and run time.

**`build.rs` scrutiny** — build scripts run arbitrary code on the developer's and CI machine with full permissions. Review every dependency's `build.rs` that does network I/O, shells out, or reads outside `OUT_DIR`. A malicious build script is the highest-leverage supply-chain attack.

```bash
find . -name build.rs -not -path './target/*'
cargo tree -f "{p} {f}"        # inspect the dependency graph and features
```

**Proc-macro trust** — proc-macros also execute at compile time. A new or low-reputation proc-macro dependency deserves the same scrutiny as a `build.rs`.

**Dependency surface** — a large transitive graph is a large attack surface. Note single-maintainer, low-download, or recently-added dependencies on security-sensitive paths (crypto, parsing, auth) as candidates for `cargo vet` review.

**Unsafe footprint** — `cargo geiger` quantifies how much `unsafe` the dependency tree pulls in. A crypto or parsing dependency with heavy unmarked `unsafe` is a risk worth recording.

---

## Triage and Filing

Assign a severity and map it to the cycle-journal priority column:

| Severity | Priority | Criteria |
|----------|----------|----------|
| **Critical** | `P0` | Actively exploitable now: committed secret, RCE, auth bypass, Critical RUSTSEC advisory on the request path |
| **High** | `P1` | Clear exploit vector: injection, `unsafe` UB, path traversal, undocumented `unsafe`, weak/absent password hashing |
| **Medium** | `P2` | Real but bounded: panic-DoS on request path, weak crypto, advisory in a non-critical path, missing authz on a low-value action |
| **Low** | `P3` | Hardening / defense-in-depth: unmaintained deps without a known advisory, missing zeroize, license policy drift |

File a GitHub issue for every Critical, High, and Medium finding. Batch same-kind Low findings into one issue.

```bash
gh issue create \
  --title "<severity>: <concise vulnerability title>" \
  --label "security,vulnerability" \
  --body "$(cat <<'EOF'
## Vulnerability
<what is wrong>

## Severity
<Critical | High | Medium | Low> — <one-line justification>

## Location
<file:line>  (or dependency + RUSTSEC id)

## Attack Scenario
<concrete input/state and the resulting damage — the proof this is real>

## Remediation
<the specific fix; for a leaked secret, say "rotate", not "delete">

## References
<RUSTSEC-YYYY-NNNN / CWE-NNN / advisory URL, if applicable>
EOF
)"
```

Skip false positives and note them briefly: `unsafe` in a vendored/vetted dependency, `unwrap` in tests or `main` startup, a `format!` query that only ever interpolates a compile-time constant, weak hashing used for a non-security checksum. A finding you cannot attach an attack scenario to is at most a Low hardening note.

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
- `cargo audit`: <N advisories> | `cargo deny`: <pass/fail> | `gitleaks`: <clean/N hits>

### Findings by Category
| Category | Count | Top Issue |
|----------|-------|-----------|
| Dependency advisories | N | <link or —> |
| Unsafe code | N | ... |
| Secrets | N | ... |
| Input / injection | N | ... |
| Cryptography | N | ... |
| Auth / authz | N | ... |
| Panic DoS | N | ... |
| Supply chain | N | ... |

### Top Security Risk
<One sentence: the single most exploitable finding, and whether it needs immediate rotation/patch>
```
