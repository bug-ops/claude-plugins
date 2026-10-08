# TypeScript — Code Review Rules

## Checklist Additions

### Error Handling
- [ ] No floating promises; every promise awaited, returned, or explicitly handled?
- [ ] `catch` blocks narrow `unknown` before use, and never swallow errors silently?
- [ ] Errors are `Error` subclasses with `cause` preserved?

### Type Safety
- [ ] No `any`, no unvalidated `as` casts, no `!` non-null assertions without a comment proving the shape?
- [ ] External data (`JSON.parse`, `fetch` responses, env vars, request bodies) validated by a schema before use?
- [ ] Discriminated unions switched exhaustively with a `never` check?
- [ ] No `@ts-ignore`; every `@ts-expect-error` and lint suppression carries a reason?
- [ ] No loosened `tsconfig` or lint configuration in the diff?

### Safety & Security
- [ ] No `innerHTML`/`dangerouslySetInnerHTML`/`{@html}`/`v-html` with untrusted data?
- [ ] No `eval`, `new Function`, or string-built `setTimeout`?
- [ ] Object merges from untrusted input guarded against prototype pollution (`__proto__`, `constructor`)?
- [ ] SQL built with parameters or a query builder, never template strings?
- [ ] `child_process` calls use `execFile`/`spawn` with argument arrays, not shell strings with user input?
- [ ] Secrets never shipped in client bundles (`NEXT_PUBLIC_`, `VITE_`, `PUBLIC_` prefixes)?

### Testing
- [ ] No `.only` or `.skip` left in tests?
- [ ] Snapshot changes reviewed line by line, not accepted wholesale?

### Formatting
- 🔵 NITPICK formatting findings are fixed by running the project's formatter (`prettier --write` or `biome format --write`).

## Modern Language Review

Flag 🟢 SUGGESTION where a newer feature allowed by `engines.node` and `target`/`lib` replaces a workaround: `satisfies` instead of `as`, `structuredClone` instead of JSON round-trips, `Array.prototype.at`, `Object.hasOwn`, `Array.prototype.toSorted`/`toReversed`/`with` instead of copy-then-mutate, `AbortSignal.timeout`, `Promise.withResolvers`, `using`/`await using` for disposables when the target supports them. Respect the version policy — never suggest a feature the declared runtime does not support.

## TypeScript-Specific Review Points

### Unvalidated Casts

```ts
// 🔴 CRITICAL: cast lies about the runtime shape
// ❌ BAD
const user = (await res.json()) as User;

// ✅ GOOD
const user = UserSchema.parse(await res.json());
```

### Floating Promises

```ts
// 🔴 CRITICAL: rejection is unhandled, ordering is lost
// ❌ BAD
items.forEach(async (item) => {
  await save(item);
});

// ✅ GOOD
for (const item of items) {
  await save(item);
}
```

### Exhaustiveness

```ts
// 🟡 IMPORTANT: a new variant silently falls through
// ❌ BAD
function label(s: Status): string {
  if (s.kind === "active") return "Active";
  return "Inactive";
}

// ✅ GOOD
function label(s: Status): string {
  switch (s.kind) {
    case "active":
      return "Active";
    case "inactive":
      return "Inactive";
    default: {
      const _exhaustive: never = s;
      return _exhaustive;
    }
  }
}
```

### Comment Hygiene

```ts
// 🟢 SUGGESTION: Redundant comment, no complexity to justify it
// ❌ BAD
// Increment the retry counter by one.
retryCount += 1;

/** Adds two numbers together. */
export function add(a: number, b: number): number {
  return a + b;
}

// ✅ GOOD
retryCount += 1;

/** Adds two numbers, clamping the result to `Number.MAX_SAFE_INTEGER`. */
export function add(a: number, b: number): number {
  return Math.min(a + b, Number.MAX_SAFE_INTEGER);
}
```

## Tools

```bash
<pm> exec tsc --noEmit         # Type check
<pm> exec eslint .             # Lint (or: biome check .)
<pm> exec knip                 # Unused exports and dependencies
<pm> exec attw --pack          # Published type correctness (libraries)
```
