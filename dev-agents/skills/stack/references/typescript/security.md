# TypeScript — Security & Maintenance Rules

Applies to TypeScript and JavaScript mode alike; in JavaScript mode the type-system items become JSDoc and `// @ts-check` items.

## Dependency Security

### Advisory audit

Run the dependency audit from `toolchain.md` for the project's package manager. Scope it to what ships when triaging: `npm audit --omit=dev`, `pnpm audit --prod`. `npm audit signatures` verifies registry signatures and provenance attestations of the installed tree. `osv-scanner scan source -r .` (v2 syntax; v1: `osv-scanner -r .`) cross-checks every lockfile in the repo against OSV, including GHSA.

### Install policy

Lifecycle scripts (`preinstall`, `install`, `postinstall`) of dependencies run arbitrary code on every install; disable them by default and allow only reviewed packages.

```ini
# .npmrc (npm, yarn classic)
ignore-scripts=true
```

```yaml
# pnpm-workspace.yaml, or "pnpm"."onlyBuiltDependencies" in package.json (pnpm 10 blocks dependency build scripts by default)
onlyBuiltDependencies:
  - esbuild
  - sharp
```

Bun runs dependency scripts only for packages in `trustedDependencies`. Install in CI with the frozen-lockfile mode (`npm ci`, `pnpm install --frozen-lockfile`, `yarn install --immutable`, `bun install --frozen-lockfile`) so the lockfile cannot drift. pnpm's `minimumReleaseAge` delays adoption of freshly published versions, the window in which most hijacked releases are caught.

### License and source policy

npm ships no license gate; enforce an allowlist in CI with the project's license checker or Socket's policy. Scoped private packages resolve through `@scope:registry=<url>` in `.npmrc`, and the scope is claimed on the public registry so it cannot be squatted (dependency confusion).

### Outdated dependencies

```bash
<pm> outdated
npx npm-check-updates          # majors included; review changelogs before applying
```

Apply updates with the project's package manager, never by hand-editing the lockfile; commit the lockfile.

## Unsafe Code Management

Escape hatches in this profile: `any`, `as` casts and `!` assertions on unvalidated data, `@ts-expect-error`, `eval`/`new Function`/string `setTimeout`, the `vm` module (not a security boundary), `Buffer.allocUnsafe` (returns uninitialized memory), native addons (`.node`, N-API), and `dangerouslySetInnerHTML`/`v-html`/`{@html}`/`innerHTML`. Each one carries the reason comment from `toolchain.md` and sits behind a narrow, typed wrapper.

```ts
/** Wraps the only place raw HTML enters the DOM; input is sanitized here, nowhere else. */
export function renderTrustedHtml(el: HTMLElement, dirty: string): void {
  // Sanitized: DOMPurify strips scripts, event handlers, and javascript: URLs.
  el.innerHTML = DOMPurify.sanitize(dirty);
}
```

**Measure the footprint:** `eslint` with `@typescript-eslint/no-explicit-any` and the `no-unsafe-*` rules reports every escape hatch; `rg -n "as unknown as|@ts-expect-error|eval\(|new Function"` finds the rest.

## Input Validation

```ts
import { z } from "zod";

export const UserInput = z.object({
  email: z.string().email().max(254),
  password: z.string().min(8).max(128),
});
export type UserInput = z.infer<typeof UserInput>;

const input = UserInput.parse(req.body);
```

Valibot, ArkType, TypeBox, or Ajv are equivalent; use the one the project has. Cap request bodies at the framework layer (`express.json({ limit: "100kb" })`, Fastify `bodyLimit`).

## SQL Injection Prevention

```ts
// ❌ DANGEROUS
await pool.query(`SELECT * FROM users WHERE id = '${userId}'`);
await prisma.$queryRawUnsafe(`SELECT * FROM users WHERE id = '${userId}'`);

// ✅ SAFE: parameterized query
await pool.query("SELECT * FROM users WHERE id = $1", [userId]);
await prisma.$queryRaw`SELECT * FROM users WHERE id = ${userId}`;
```

For MongoDB, reject operator objects from request data (`{ "$ne": null }`): validate fields as primitives with a schema before they reach a filter.

## Command Injection Prevention

```ts
// ❌ DANGEROUS: shell parses the string
exec(`convert ${file} out.png`);

// ✅ SAFE: no shell, discrete arguments, end of options marked
execFile("convert", ["--", file, "out.png"]);
```

## Path Traversal Prevention

```ts
import { realpath, readFile } from "node:fs/promises";
import path from "node:path";

const BASE_DIR = "/var/data";

export async function readSafe(filename: string): Promise<string> {
  const name = path.basename(filename);
  const resolved = await realpath(path.join(BASE_DIR, name));
  if (!resolved.startsWith(BASE_DIR + path.sep)) {
    throw new Error("path traversal attempt");
  }
  return readFile(resolved, "utf8");
}
```

## Secrets Management

```ts
// ❌ NEVER
const API_KEY = "sk-1234567890abcdef";

// ✅ Validated once at startup, server-only module
import "server-only";
import { z } from "zod";

const Env = z.object({ API_KEY: z.string().min(1) });
export const env = Env.parse(process.env);
```

Never put a secret behind a public env prefix (`NEXT_PUBLIC_`, `VITE_`, `PUBLIC_`, `REACT_APP_`, Nuxt `runtimeConfig.public`): the bundler inlines it into client JavaScript. Use framework server-only boundaries (`server-only`, SvelteKit `$env/static/private` and `$lib/server`).

## Password Hashing

```ts
import argon2 from "argon2";

export async function hashPassword(password: string): Promise<string> {
  return argon2.hash(password, { type: argon2.argon2id });
}

export async function verifyPassword(hash: string, password: string): Promise<boolean> {
  return argon2.verify(hash, password);
}
```

Without a native dependency, `crypto.scrypt` from `node:crypto` with a random 16-byte salt is acceptable. `bcrypt` truncates input at 72 bytes.

## Error Handling Security

```ts
// ❌ BAD: leaks which part failed
const user = await db.findUser(name);
if (!user) throw new HttpError(404, "user not found");
if (!(await verifyPassword(user.hash, pass))) throw new HttpError(401, "wrong password");

// ✅ GOOD: one generic failure, details logged server-side
const user = await db.findUser(name);
const ok = await verifyPassword(user?.hash ?? DUMMY_HASH, pass);
if (!user || !ok) {
  log.warn({ name }, "login failed");
  throw new HttpError(401, "authentication failed");
}
```

Production error handlers return no stack traces (`NODE_ENV=production`, a custom Express/Fastify error handler).

## Checklist Additions

- [ ] Dependency audit clean for production dependencies; `npm audit signatures` passes
- [ ] Dependency install scripts disabled or allowlisted; CI installs with a frozen lockfile
- [ ] No secret behind a public env prefix or in a client-imported module
- [ ] Every escape hatch (`any`, unvalidated `as`, `eval`, `innerHTML`, `Buffer.allocUnsafe`) documented and wrapped
- [ ] Passwords hashed with argon2id (or scrypt)
- [ ] Security headers and a CSP set (`helmet` or the framework equivalent); cookies `httpOnly`, `secure`, `sameSite`
- [ ] Lint rules on request-path code: `no-floating-promises`, `no-misused-promises`, `no-explicit-any`, `no-unsafe-*`, `no-implied-eval`

## Tools

```bash
<pm> audit                     # Advisories (see toolchain.md for the level flag)
npm audit signatures           # Registry signatures and provenance
osv-scanner scan source -r .   # OSV / GHSA cross-check
<pm> outdated
npx lockfile-lint --path package-lock.json --allowed-hosts npm --validate-https
```
