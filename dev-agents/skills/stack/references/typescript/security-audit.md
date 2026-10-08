# TypeScript — Security Audit Checklist

Language checklist for the `security-audit` protocol; section numbers match the protocol. Covers TypeScript and JavaScript on Node.js, Bun, and the browser. Read-only scope covers source files, `package.json`, lockfiles, and `.npmrc`; installing into a scratch clone, type-checking, linting, and running the tests are allowed. Extra reference frameworks: the OWASP Node.js and Cheat Sheet series, the Node.js security best practices guide. `<pm>` is the project's package manager from `toolchain.md`. Exclude `node_modules/`, build output, and minified bundles from every search.

## 1. Dependency Vulnerabilities

```bash
npm audit --omit=dev --json        # or: pnpm audit --prod --json / yarn npm audit / bun audit
npm audit signatures               # registry signatures and provenance attestations
osv-scanner scan source -r .       # OSV + GHSA across all lockfiles (v1: osv-scanner -r .)
<pm> outdated                      # direct deps behind latest
<pm> why <pkg>                     # who pulls a vulnerable transitive in (npm explain <pkg> for npm)
```

- **Matched advisories** — record the GHSA id (and CVE). Re-run without the production filter to report dev-only hits separately at lower severity; build tooling still runs on CI machines with secrets.
- **Deprecated and unmaintained** — `npm WARN deprecated` lines on install, a `deprecated` field in `npm view <pkg>`, or no release and open security issues for years.
- **Unpublished or withdrawn versions** — a lockfile entry whose version no longer resolves, or a version deprecated with a security message.
- **Duplicates** — several majors of one package (`npm ls <pkg>`, `pnpm why <pkg>`, `yarn why <pkg>`); an old copy pinned transitively is how patched advisories keep shipping. `overrides` (npm), `pnpm.overrides`, or `resolutions` (yarn) are the remediation; an existing override that pins a vulnerable version is itself a finding.
- **Licenses** — no built-in gate; check the license field of new transitive dependencies or the project's license tool.

## 2. Unsafe and Escape-Hatch Code (`unsafe`)

```bash
rg -n --type ts --type js "\bany\b|as unknown as|@ts-ignore|@ts-expect-error|\beval\(|new Function\(|Buffer\.allocUnsafe|require\(['\"]vm['\"]\)|node:vm"
rg -n "dangerouslySetInnerHTML|v-html|\{@html|innerHTML|outerHTML|insertAdjacentHTML|document\.write|bypassSecurityTrust"
```

- **Undocumented bypass** — `any`, `as` on external data, `!` assertions, `@ts-ignore`, and lint suppressions without the reason comment from `toolchain.md`. An `as` cast on `JSON.parse`, `fetch().json()`, `req.body`, or `postMessage` data is type confusion: downstream code trusts a shape nothing checked.
- **Dynamic evaluation** — `eval`, `new Function`, `setTimeout`/`setInterval` with a string, `vm.runInContext` and `vm.runInNewContext` on input. The Node.js docs state `vm` is not a security mechanism; sandbox escape is code execution.
- **Native addons** — `.node` binaries, `node-gyp` builds, N-API, `ffi-napi`; same scrutiny as FFI: buffers and lengths from input reaching native code.
- **Uninitialized memory** — `Buffer.allocUnsafe(n)`, `Buffer.allocUnsafeSlow(n)`, and legacy `new Buffer(n)` return old heap contents; returned to a client before full overwrite it leaks secrets.
- **HTML escape hatches** — listed in the second search; covered under §9 XSS.

## 3. Secrets and Sensitive Data

```bash
rg -n -i "api[_-]?key|secret|password|token|BEGIN (RSA|EC|OPENSSH) PRIVATE KEY" --type ts --type js
rg -n --hidden "NEXT_PUBLIC_|VITE_|PUBLIC_|REACT_APP_|EXPO_PUBLIC_" -g '!node_modules' -g '!.git'
```

- **Client bundle leakage** — any value read through a public env prefix (`NEXT_PUBLIC_`, `VITE_`, SvelteKit `PUBLIC_` / `$env/static/public`, `REACT_APP_`, `EXPO_PUBLIC_`, Nuxt `runtimeConfig.public`) or a bundler `define` of `process.env` is inlined into client JavaScript. A secret there is P0. Also check: server modules imported from client components without `server-only`, Next.js server action return values, serialized props, and production source maps published with the bundle.
- **Secrets in logs and errors** — `console.log(req)`, logging full request/response objects or headers (`authorization`, `cookie`), error responses that serialize the error object or `config` of an HTTP client (axios errors carry request headers). Check logger redaction (`pino` `redact` paths).
- **Published packages** — `npm pack --dry-run` lists what ships; `.env`, keys, or test fixtures with credentials in the tarball are leaks. An allowlist `files` field in `package.json` beats `.npmignore`.
- **Lingering secrets** — strings are immutable and cannot be zeroized; keep long-lived key material in `Buffer`s that are `fill(0)`ed after use, or in `KeyObject`s, as a hardening note.

## 4. Input Validation and Injection

```bash
rg -n '(query|execute|raw|\$queryRawUnsafe|\$executeRawUnsafe)\(\s*`' --type ts --type js
rg -n "child_process|\bexec\(|execSync\(|shell:\s*true" --type ts --type js
```

- **SQL injection** — template literals or concatenation into `pool.query`, `knex.raw`, Sequelize `literal`/`query`, Prisma `$queryRawUnsafe`/`$executeRawUnsafe`, TypeORM `query`. Tagged-template APIs (Prisma `$queryRaw`, `sql` tags of postgres.js/Drizzle/Slonik) are parameterized; `Unsafe`/`raw` variants are not.
- **NoSQL injection** — request data passed into MongoDB filters lets `{ "$ne": null }` or `$where` through; require primitive-typed schema validation (or Mongoose `sanitizeFilter`) before the filter.
- **Command injection** — `exec`/`execSync` and `spawn(..., { shell: true })` parse a shell string. `execFile`/`spawn` with an argument array are safe from the shell, but still need `--` when an argument can begin with `-` (argument injection, e.g. `git`, `tar`, `curl`). On Windows, `.bat`/`.cmd` targets imply a shell.
- **Path traversal** — `path.join`/`path.resolve` with request data and no containment check; the guard is `path.resolve` (or `fs.realpath` to follow symlinks) then `startsWith(base + path.sep)` or `path.relative` not starting with `..`. Check static-file serving (`express.static`, `res.sendFile` without `root`), upload filenames, and `import()`/`require()` of computed paths.
- **Unsafe deserialization** — `node-serialize`, `funcster`, or `serialize-javascript` output passed to `eval`; `v8.deserialize` on external bytes; `js-yaml` `load` with a custom schema enabling functions (v3 `load` was unsafe by default; v4 `load` is safe). Bodies without a size cap (`express.json` defaults to 100kb; raw `req.on("data")` accumulation has none).
- **Prototype pollution** — deep merge, `Object.assign`, `lodash.merge`/`set`/`defaultsDeep` (patched only in recent versions), query-string parsers that build nested objects (`qs` with `a[__proto__][x]=1`), and `obj[key] = value` loops over untrusted keys. Safe patterns: schema validation that strips unknown keys, `Object.create(null)` or `Map` for dictionaries, rejecting `__proto__`/`constructor`/`prototype` keys. Pollution of a property later read as an option (`shell`, `env`, `isAdmin`) escalates to RCE or auth bypass.
- **Integers and sizes** — `parseInt` without radix or range check, numbers above `Number.MAX_SAFE_INTEGER` losing precision (IDs as numbers), `Buffer.alloc(n)`/`new Array(n)`/`.repeat(n)` with `n` from input.
- **XXE** — `libxmljs` with `noent: true` or DTD loading; check entity-expansion limits in `fast-xml-parser` and `xml2js` versions in use.
- **ReDoS** — V8's regex engine backtracks: nested quantifiers (`(a+)+`, `(.*a){n}`) on input, and `new RegExp(userInput)` without escaping. Linear-time alternative: the `re2` package. `recheck` or `safe-regex` flag vulnerable patterns. Also flag `new RegExp` built per request from constants.

## 5. Cryptography

- **Weak algorithms** — `createHash("md5" | "sha1")` for passwords, signatures, or tokens; `createCipheriv` with an `-ecb` mode or `des`/`rc4`; legacy `crypto.createCipher` (no IV, MD5 key derivation; removed in Node 22).
- **Vetted libraries** — `node:crypto` and Web Crypto (`crypto.subtle`), `jose` for JOSE/JWT, `@noble/*` for pure-JS primitives, `libsodium-wrappers`.
- **Non-CSPRNG** — `Math.random()` for tokens, IDs, OTPs, nonces, salts, or password reset links is predictable. Require `crypto.randomUUID()`, `crypto.randomBytes()`, `crypto.randomInt()`, or `crypto.getRandomValues()`. `nanoid` (default import) is CSPRNG-backed; `nanoid/non-secure` is not.
- **Password KDF** — `argon2`, `@node-rs/argon2`, `bcrypt`/`bcryptjs` (72-byte input limit), or `crypto.scrypt`. Plain `createHash("sha256")` of a password is a finding.
- **Constant-time comparison** — `===` on HMACs, API keys, or tokens leaks timing. Require `crypto.timingSafeEqual`, which throws on length mismatch: compare fixed-length digests (HMAC both values first), and never short-circuit on length before it.
- **IV/nonce** — `createCipheriv("aes-256-gcm", key, iv)` with a constant or reused `iv`; require `randomBytes(12)` per message and check the auth tag is verified (`setAuthTag` before `final`).

## 6. Authentication and Authorization

- **JWT** — `jsonwebtoken` `jwt.decode()` used where `jwt.verify()` is needed (decode does not check the signature); `verify` without an explicit `algorithms` list (HS/RS key confusion, `alg: none` in old versions); missing `audience`/`issuer` checks; `ignoreExpiration: true`. With `jose`, `jwtVerify` takes `algorithms`, `issuer`, `audience`. Tokens in `localStorage` are readable by any XSS; prefer `httpOnly` cookies.
- **Authorization placement** — Next.js middleware alone is not an authorization layer (route handlers and server actions are callable directly); check every route handler, server action, tRPC/GraphQL resolver for its own check. GraphQL: field-level authorization, introspection and query depth/complexity limits in production.
- **Mass assignment** — `prisma.user.update({ data: req.body })`, `Model.create(req.body)`, `{ ...req.body }` spreads into persisted objects let clients set `role` or `isAdmin`.
- **Sessions** — `express-session` with the default `MemoryStore` in production, a hardcoded `secret`, no `cookie.secure`/`httpOnly`/`sameSite`, or no session regeneration on login (fixation).

## 7. Crash and Resource-Exhaustion DoS (`panics`)

- **Unhandled rejections** — since Node 15 an unhandled rejection terminates the process by default, so one rejecting request crashes every in-flight request. Express 4 does not route async handler rejections to the error middleware (Express 5 does); every `async` handler on Express 4 without a wrapper is a finding. Also: `.catch`-less promise chains, `void` fire-and-forget calls, `async` callbacks passed to `EventEmitter` listeners or `forEach`.
- **Uncaught exceptions** — a `throw` inside a callback, timer, or stream `error` event without a listener (`'error'` events with no handler throw). A `process.on("uncaughtException")` handler that keeps serving leaves the process in an undefined state — it must log and exit.
- **Crash on malformed input** — `JSON.parse` on request data outside `try`, property access on unvalidated nested input (`TypeError: Cannot read properties of undefined`) in code without a request-scoped error boundary.
- **Event-loop blocking** — one CPU-bound or synchronous call stalls every request: `fs.*Sync`, `child_process.execSync`, `crypto.pbkdf2Sync`/`scryptSync`, `zlib.*Sync`, large `JSON.parse`/`JSON.stringify`, sorting or regex over unbounded input. Move to the async API or `worker_threads`; `perf_hooks.monitorEventLoopDelay` measures the stall.
- **Unbounded recursion** — recursive walkers over nested input throw `RangeError: Maximum call stack size exceeded`; require a depth cap.
- **Unbounded fan-out and buffering** — `Promise.all(items.map(...))` over an input-sized array, accumulating a request or upload body in memory without a cap, `stream.pipe` without backpressure handling (prefer `stream.pipeline`).
- **Cancellation** — handlers that keep writing after the client disconnects; multi-step mutations without a transaction when an `AbortSignal` or timeout fires mid-way.

## 8. Supply-Chain Trust

```bash
npm query ":attr(scripts, [postinstall])"     # deps with postinstall scripts (npm 8.16+)
npx lockfile-lint --path package-lock.json --allowed-hosts npm --validate-https
rg -n '"(github:|git\+|git://|https://github)' package.json
```

- **Install scripts** — `preinstall`/`install`/`postinstall` of dependencies run with the developer's and CI's credentials; this is the vector of most npm worm and hijack incidents. Check `.npmrc` `ignore-scripts=true`, pnpm `onlyBuiltDependencies` (pnpm 10 blocks dependency build scripts by default), Bun `trustedDependencies`. Every allowlisted package needs a reason.
- **Lockfile integrity** — every entry has an `integrity` hash and a `resolved` URL on the expected registry over HTTPS; CI installs with the frozen mode (`npm ci`, `pnpm install --frozen-lockfile`, `yarn install --immutable`). A lockfile diff that adds hosts, or changes `resolved`/`integrity` without a version change, is a finding until explained.
- **Git and URL dependencies** — `github:org/repo` or tarball URLs without a commit SHA re-resolve on every install.
- **Typosquatting** — names one edit away from popular packages, scope confusion (`@type/node` vs `@types/node`), and packages recently transferred to a new maintainer.
- **Dependency confusion** — unscoped internal package names, or a private scope without a `@scope:registry=` mapping in `.npmrc`, resolve from the public registry first if someone publishes there. The scope must be claimed on npmjs.com.
- **Provenance** — `npm audit signatures` verifies attestations; published packages of the project itself should use trusted publishing (OIDC) or `npm publish --provenance` from CI rather than a long-lived `NPM_TOKEN`.
- **Release-age gating** — pnpm `minimumReleaseAge` or an equivalent policy delays adoption of freshly published versions.
- **Behavioral signals** — Socket (GitHub app or CLI) flags install scripts, network and filesystem access, obfuscated code, and maintainer changes in dependency updates.
- **Bundled CDN scripts** — `<script src>` from third-party CDNs without Subresource Integrity (`integrity` attribute).

## 9. Network and Service Hardening

- **SSRF** — `fetch(url)`, `axios`, `got`, `undici` with a URL, host, or port from input; image proxies, webhooks, URL previews, PDF renderers (Puppeteer `page.goto`). Validate the resolved IP (not the hostname) against private and link-local ranges (`ipaddr.js`), use `redirect: "manual"` and re-check each hop, and pin the resolved address to defeat DNS rebinding.
- **TLS verification disabled** — `rejectUnauthorized: false` in `https.Agent`/`tls.connect`/database clients, `NODE_TLS_REJECT_UNAUTHORIZED=0` in code, scripts, or CI env.
- **Limits** — body limits (`express.json({ limit })`, Fastify `bodyLimit`, `multer` `limits`), `server.requestTimeout`, `server.headersTimeout`, `--max-http-header-size`, rate limiting on login and expensive routes (`express-rate-limit`, `@fastify/rate-limit`).
- **CORS and CSRF** — `cors({ origin: true, credentials: true })` reflects any origin; a callback that matches origins with `includes`/unanchored regex is bypassable. Cookie-authenticated mutations need `SameSite` plus a CSRF token or origin check; framework built-ins (SvelteKit `csrf.checkOrigin`, Next.js server action origin check) must not be disabled.
- **XSS** — framework escape hatches with untrusted data: React `dangerouslySetInnerHTML`, Vue `v-html`, Svelte `{@html}`, Angular `bypassSecurityTrust*`, direct `innerHTML`/`document.write`; `href`/`src` bound to user URLs without an `http(s):` scheme allowlist (`javascript:` URLs); markdown renderers with HTML enabled. Sanitize with DOMPurify; server-rendered JSON embedded in `<script>` must escape `</script>` and `<!--`.
- **CSP and headers** — no `Content-Security-Policy`, or one with `'unsafe-inline'`/`'unsafe-eval'` in `script-src`; prefer nonces with `'strict-dynamic'`. `helmet` (Express) or `@fastify/helmet` sets CSP, HSTS, `X-Content-Type-Options`, `frame-ancestors`; Trusted Types where the app targets Chromium.
- **Header and log injection** — Node's `setHeader` rejects CR/LF, but redirect targets from input (`res.redirect(req.query.next)`) are open redirects, and string-concatenated log lines allow forged entries; use structured loggers.
- **Insecure defaults** — `app.listen(port)` binds all interfaces; Express `x-powered-by` left on; stack traces in production error responses; `trust proxy` misconfigured so `req.ip` (and rate limits keyed on it) is attacker-controlled via `X-Forwarded-For`; debug endpoints, GraphQL playgrounds, or source maps exposed in production.

## 10. Filesystem and Archives

- **TOCTOU** — `fs.existsSync`/`fs.stat` then `fs.open`; open first and `fstat` the handle (`filehandle.stat()`), use `fs.constants.O_NOFOLLOW` where supported, or the `wx` flag for exclusive creation.
- **Temporary files** — `fs.mkdtemp(path.join(os.tmpdir(), "prefix-"))` for a private directory, never hand-built names under `os.tmpdir()`.
- **Permission modes** — `fs.writeFile(path, secret, { mode: 0o600 })`; flag `0o777` and `chmod` with broad modes.
- **Zip-slip** — `adm-zip`, `unzipper`, `yauzl`, `tar`, `decompress`: check each entry path stays inside the destination before writing, and that the library version includes its traversal fixes (several had CVEs). Symlink entries need the same check.
- **Decompression bombs** — `zlib` inflate without `maxOutputLength`; `sharp` image input without `limitInputPixels`; archive extraction without total-size and entry-count caps.

## 11. Verification Gates

- `strict: true` in `tsconfig.json`, with `@typescript-eslint` `no-explicit-any`, `no-unsafe-assignment`/`-member-access`/`-call`/`-return`/`-argument` as errors on request-path code.
- Lint rules: `no-floating-promises`, `no-misused-promises`, `no-eval`, `no-implied-eval`, `no-new-func`; `eslint-plugin-security` and `eslint-plugin-no-unsanitized` for DOM sinks, or Biome `noGlobalEval` and `noDangerouslySetInnerHtml`.
- Runtime hardening where the deployment allows: the Node.js permission model (`--permission` with `--allow-fs-read`/`--allow-fs-write`), `--disable-proto=delete` against `__proto__`-based pollution.
- `fast-check` property tests for every parser of untrusted input and round-trip tests for encoders/decoders; a coverage-guided fuzzer (Jazzer.js) where already set up.
- The dependency audit, `npm audit signatures`, and a frozen-lockfile install in CI; secret scanning (gitleaks) on push.

## Triage Mapping

- Critical: a Critical GHSA advisory on the request path, a secret behind a public env prefix or in a published tarball, `eval`/`vm`/`child_process` reachable with input.
- High: XSS through an escape hatch, prototype pollution reaching an option sink, `jwt.decode` used for auth, `Math.random` tokens, a malicious or unexplained install script.
- Medium: unhandled-rejection or event-loop-blocking DoS on the request path, ReDoS, missing body limits.

**False positives**: `any` in `.d.ts` shims for untyped third-party modules, `Math.random` for UI jitter or sampling, `innerHTML` with compile-time constant markup, `execSync` in build scripts and CLIs that only run on the developer's machine, `md5` for cache keys and ETags.

**Handoff scanner line**: `` `<pm> audit`: <N advisories (prod / dev)> | `audit signatures`: <pass/fail> | `osv-scanner`: <N> ``. References cite `GHSA-xxxx-xxxx-xxxx` and the CVE.
