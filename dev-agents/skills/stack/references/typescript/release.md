# TypeScript — Release Mechanics

Applied by the `release` skill to every `package.json` in scope. Commands from `toolchain.md` are referenced by name; `<pm>` is the detected package manager.

## Project Structure

- **Single package**: root `package.json`.
- **Monorepo**: `pnpm-workspace.yaml` (`packages:` globs) or the `workspaces` field in the root `package.json` (array, or `{ "packages": [...] }` in yarn classic). The root package is usually `"private": true` and unversioned.
- Versioned units are the workspace packages without `"private": true`. Private packages (apps, internal tooling) are not published; bump them only when the project keeps them in lockstep.
- List packages: `pnpm -r ls --depth -1`, `npm query .workspace`, or read the workspace globs directly.

## Release Tooling

Check before editing anything — when a tool owns versions, drive it instead:

| Marker | Tool | Version step |
|--------|------|--------------|
| `.changeset/` with `config.json` | Changesets | `<pm> exec changeset status` to preview, then `<pm> exec changeset version` — consumes the pending changeset files, bumps each package by its recorded bump type, rewrites internal dependency ranges, and writes per-package `CHANGELOG.md` |
| `release-please-config.json`, `.release-please-manifest.json` | release-please | Versions come from the release PR the bot opens; do not bump by hand |
| `.releaserc*`, `release` key in `package.json` | semantic-release | Versions are computed in CI from commits; this skill only finalizes docs |
| `lerna.json` | Lerna | `lerna version <bump> --no-git-tag-version --no-push` |
| `nx.json` with a `release` section | Nx Release | `nx release version <bump>` (follow the project's config for git operations) |

With Changesets the bump type comes from the changeset files, not from the skill argument — show the user `changeset status` and confirm. If no changesets are pending, stop and ask.

## Version Source of Truth

- Each publishable `package.json` has its own `version` field. Lockstep monorepos keep them equal; Changesets `fixed`/`linked` groups encode that.
- `npm pkg get version` reads it in the current package.

## Manifest Updates

1. `version` in each versioned `package.json` (Edit tool). For a single npm package, `npm version <patch|minor|major> --no-git-tag-version` updates `package.json` and `package-lock.json` without committing or tagging.
2. Internal dependencies between workspace packages:
   - `workspace:*`, `workspace:^`, `workspace:~` (pnpm, yarn, bun) — leave as is; the manager rewrites them to the real version at publish.
   - Plain semver ranges (`"@scope/core": "^1.4.0"`) — raise them when the new version falls outside the range or the dependent needs the new features.
3. `peerDependencies` on sibling packages — update deliberately; widening is non-breaking, narrowing is breaking.

## Lockfile Refresh

Run the manager's install so the lockfile records the new workspace versions:

| Manager | Command |
|---------|---------|
| npm | `npm install --package-lock-only` |
| pnpm | `pnpm install --lockfile-only` |
| yarn (berry) | `yarn install --mode=update-lockfile` |
| yarn (classic) | `yarn install` |
| bun | `bun install` |

Stage every changed `package.json` and the lockfile.

## Secondary Version Carriers

- `jsr.json` / `deno.json` `version` for packages also published to JSR.
- Version constants in source (`export const VERSION = "X.Y.Z"`, CLI `--version` output) unless generated from `package.json` at build time.
- CDN links in docs (`https://unpkg.com/pkg@X.Y.Z`, `https://cdn.jsdelivr.net/npm/pkg@X.Y.Z`).
- Native bindings from the same repo (Rust core via napi-rs or wasm-pack): the platform packages under `npm/` and the Rust crate move in lockstep — follow the Rust release file too.
- Add `--include="*.json"` to the documentation grep, excluding `node_modules/` and lockfiles.

## Pre-Release Gates

1. **Full check suite** from `toolchain.md`, including the build.
2. **Package contents**: `npm pack --dry-run` in each published package. In pnpm workspaces only `pnpm pack`/`pnpm publish` rewrite `workspace:` ranges — run `pnpm pack --pack-destination <tmp-dir>` and inspect the tarball's `package.json`. Confirm the file list: built output and type declarations present; no `src/` maps pointing at missing files, tests, fixtures, `.env`, or credentials. The `files` field (allowlist) beats `.npmignore`.
3. **Package correctness**: `publint` (entry points, `exports` map, `type`, file existence) and `attw --pack .` (`@arethetypeswrong/cli`: types resolve correctly for `node10`, `node16` CJS/ESM, and `bundler` resolution).
4. **API compatibility**: when the project runs API Extractor, `api-extractor run` must match the committed API report; a changed report means the API changed, and the bump must reflect it. Without it, diff the emitted `.d.ts` files against the last release (`npm pack pkg@<previous>` and compare).
5. **Version policy**: `engines.node` still matches the CI matrix minimum. Raising `engines.node`, the minimum TypeScript version for consumers of the types, or dropping CJS/ESM entry points is a breaking change.

## Semver Notes

- npm caret ranges treat `0.Y.Z` → `0.(Y+1).0` as breaking; `^0.5.0` does not match `0.6.0`.
- Breaking: removing or renaming an export or an `exports` subpath, narrowing an accepted parameter type, widening a returned type, adding a required property to an input type, changing default export shape, switching module format, raising `engines.node` or a `peerDependencies` minimum.
- Type-only changes are API changes: consumers compile against the `.d.ts`.

## Tags, Dist-Tags, and Publishing

- Lockstep: one tag `vX.Y.Z`. Independent monorepo versions: one tag per package, `<name>@X.Y.Z` (Changesets convention, e.g. `@scope/core@1.4.0`) — follow the project's existing tag history first.
- Publishing runs from CI after the tag (`npm publish`, `pnpm publish -r`, `changeset publish`), never from this skill.
- Provenance: publish from GitHub Actions with `permissions: id-token: write` and `npm publish --provenance` (or `"publishConfig": { "provenance": true }`), or configure npm trusted publishing (OIDC) so no long-lived `NPM_TOKEN` is needed.
- Scoped public packages need `"publishConfig": { "access": "public" }` (or `--access public`) on first publish.
- Dist-tags: a pre-release (`X.Y.Z-rc.1`) is published with `--tag next` (or `beta`, `rc`) so `latest` keeps pointing at the stable line. Repair a wrong tag with `npm dist-tag add <pkg>@<version> latest`.
- npm versions are immutable and cannot be reused after unpublish; a bad release is fixed forward or marked with `npm deprecate <pkg>@<version> "<reason>"`.
