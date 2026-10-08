# TypeScript — Testing Rules

Applies to TypeScript and JavaScript mode. In JavaScript mode skip type-level tests; everything else applies unchanged.

## Tools

Use what the repo configures; for new setups default to Vitest.

- Runner: `vitest` (the unit-tests command in `toolchain.md`), or `jest`, or `node --test` (`node:test` + `node:assert/strict`). Never introduce a second runner.
- Environment: Vitest `environment: "node"` by default; `jsdom` or `happy-dom` only for DOM code; Vitest browser mode or Playwright component testing when real browser behavior matters.
- Coverage: `vitest run --coverage` with `@vitest/coverage-v8` (`coverage.provider: "v8"`, thresholds in `coverage.thresholds`); `jest --coverage`; `node --test --experimental-test-coverage`.
- HTTP: `msw` (`setupServer` from `msw/node`) to intercept at the network layer.
- Time: `vi.useFakeTimers()` / `jest.useFakeTimers()`; `mock.timers` in `node:test`.
- Property tests: `fast-check` (`@fast-check/vitest` for `test.prop`).
- Parametric tests: `it.each` / `test.each` / `describe.each`; Vitest `test.for`.
- Type-level tests: Vitest `expectTypeOf` / `assertType` in `*.test-d.ts` run with `vitest --typecheck`; or `tsd` (`expectType`, `expectError`) for published packages; `tstyche` where configured.
- End-to-end and component: `@playwright/test` (the end-to-end command in `toolchain.md`).
- Benchmarks: `bench` from `vitest` run with `vitest bench` (tinybench underneath); `mitata` for standalone micro-benchmarks.
- Mutation testing (optional, for critical modules): Stryker (`stryker run`, with `@stryker-mutator/vitest-runner` or the jest runner).

## Test Layout

Follow the repo's convention; the common ones:

- Co-located: `src/user.ts` → `src/user.test.ts` (or `.spec.ts`) — default for unit tests.
- Separate tree: `test/unit/`, `test/integration/`, or `__tests__/` directories (jest default).
- Integration tests separated by directory or by a Vitest project (`test.projects` in the config) so they can run with their own setup and timeouts.
- End-to-end tests in `e2e/` or `tests/` as `playwright.config.ts` `testDir` says; never picked up by the unit runner.
- Shared helpers in `test/helpers/` (or `test/fixtures/`); global setup through `setupFiles`.

**Naming**: `describe("functionName")` with `it("returns X when Y")` — the `describe` block is the function, the `it` text is the scenario.

```ts
// src/calculator.ts
export function add(a: number, b: number): number {
  return a + b;
}

export function divide(a: number, b: number): number {
  if (b === 0) throw new RangeError("division by zero");
  return a / b;
}
```

```ts
// src/calculator.test.ts
import { describe, expect, it } from "vitest";
import { add, divide } from "./calculator.js";

describe("add", () => {
  it("adds positive numbers", () => {
    expect(add(2, 3)).toBe(5);
  });
});

describe("divide", () => {
  it("throws RangeError on division by zero", () => {
    expect(() => divide(10, 0)).toThrow(RangeError);
  });
});
```

## Integration Tests

```ts
// test/integration/user-workflow.test.ts
import { afterAll, beforeAll, expect, it } from "vitest";
import { createApp, type App } from "../../src/app.js";
import { testConfig } from "../helpers/config.js";

let app: App;

beforeAll(async () => {
  app = await createApp(testConfig());
});

afterAll(async () => {
  await app.close();
});

it("creates then fetches a user", async () => {
  const id = await app.createUser("test@example.com");
  const user = await app.getUser(id);
  expect(user.email).toBe("test@example.com");
});
```

Real databases and brokers come from Testcontainers or a compose file started by global setup — never from a developer's machine state.

## Async Tests

- Return or `await` every promise; an un-awaited `expect(...).rejects` passes even when the promise resolves.
- `await expect(fetchUser(-1)).rejects.toThrow(NotFoundError)`.
- Use `expect.assertions(n)` when assertions run inside callbacks.

Fake timers instead of real sleeps:

```ts
import { afterEach, beforeEach, expect, it, vi } from "vitest";

beforeEach(() => {
  vi.useFakeTimers();
  vi.setSystemTime(new Date("2026-01-01T00:00:00Z"));
});

afterEach(() => {
  vi.useRealTimers();
});

it("expires the session after 30 minutes", async () => {
  const session = createSession();
  await vi.advanceTimersByTimeAsync(30 * 60 * 1000);
  expect(session.isExpired()).toBe(true);
});
```

## Test Doubles — Fakes over Mocks

Inject dependencies through an interface and pass an in-memory fake. Reserve `vi.mock()` / `jest.mock()` module mocking for third-party boundaries that cannot be injected; never module-mock your own code to reach a branch.

```ts
export interface UserRepository {
  findUser(id: UserId): Promise<User | undefined>;
}

export class InMemoryUserRepository implements UserRepository {
  readonly #users = new Map<UserId, User>();

  constructor(users: readonly User[] = []) {
    for (const user of users) this.#users.set(user.id, user);
  }

  async findUser(id: UserId): Promise<User | undefined> {
    return this.#users.get(id);
  }
}
```

- `vi.fn()` / `vi.spyOn()` for callbacks and observable side effects; set `restoreMocks: true` (or `mockReset`) in the config so spies never leak between tests.
- Type doubles fully — `vi.fn<(id: UserId) => Promise<User>>()`; no `as any` to satisfy a parameter. Build test data with typed factories (`makeUser(overrides: Partial<User> = {})`).

HTTP at the network boundary with MSW:

```ts
import { http, HttpResponse } from "msw";
import { setupServer } from "msw/node";
import { afterAll, afterEach, beforeAll } from "vitest";

const server = setupServer(
  http.get("https://api.example.com/users/:id", ({ params }) =>
    HttpResponse.json({ id: params.id, email: "test@example.com" }),
  ),
);

beforeAll(() => server.listen({ onUnhandledRequest: "error" }));
afterEach(() => server.resetHandlers());
afterAll(() => server.close());
```

Override per test with `server.use(...)`; `onUnhandledRequest: "error"` turns any accidental real request into a failure.

## Property-Based Tests

```ts
import { fc, test } from "@fast-check/vitest";
import { expect } from "vitest";

test.prop([fc.string()])("parseEmail never throws", (raw) => {
  expect(() => parseEmail(raw)).not.toThrow();
});

test.prop([fc.integer(), fc.integer()])("add is commutative", (a, b) => {
  expect(add(a, b)).toBe(add(b, a));
});
```

Without the integration package: `fc.assert(fc.property(fc.string(), (raw) => { ... }))`. A failing run prints a seed and a shrunk counterexample — pin it as a regular regression test.

## Type-Level Tests

For exported generic types and overloaded signatures in libraries:

```ts
// src/result.test-d.ts
import { expectTypeOf, test } from "vitest";
import { ok, type Result } from "./result.js";

test("ok infers the value type", () => {
  expectTypeOf(ok(42)).toEqualTypeOf<Result<number, never>>();
  expectTypeOf(ok).parameter(0).not.toBeAny();
});
```

`// @ts-expect-error` inside a type test asserts that a call must not compile; it is the one place the marker needs no further reason.

## End-to-End and Component Tests

```ts
import { expect, test } from "@playwright/test";

test("user signs in", async ({ page }) => {
  await page.goto("/login");
  await page.getByLabel("Email").fill("test@example.com");
  await page.getByRole("button", { name: "Sign in" }).click();
  await expect(page.getByRole("heading", { name: "Dashboard" })).toBeVisible();
});
```

- Locate by role, label, or text (`getByRole`, `getByLabel`, `getByTestId` last); never by CSS structure.
- Web-first assertions (`await expect(locator)...`) retry; never `page.waitForTimeout`.
- Each test sets up its own state (API seeding, `storageState` for auth); no ordering between tests.
- DOM component tests outside Playwright use Testing Library queries with the same role-first priority.

## Benchmarks

```ts
// src/process.bench.ts
import { bench, describe } from "vitest";

describe("processData", () => {
  const data = Array.from({ length: 1_000 }, (_, i) => i);
  bench("current", () => {
    processData(data);
  });
});
```

## DRY in Tests

- Shared setup → `test/helpers/` modules or `setupFiles`; shared HTTP handlers → one `test/msw/handlers.ts`
- One fake per interface, one factory per domain type
- Repeated `beforeEach` bodies across files → a fixture helper or Vitest `test.extend` fixtures

## Redundancy Audit Commands

| Step | Command |
|------|---------|
| Enumerate the suite | `vitest list` (`--json` for machine output); jest only lists files (`jest --listTests`) — grep `it(`/`test(` bodies; `node:test` has no listing, grep instead |
| Unit-test sweep scope | the touched module's co-located `*.test.ts` plus matching files under `test/` |
| Coverage diff | `vitest run --coverage --coverage.reporter=json-summary` twice, the second time with the suspected test temporarily marked `.skip` locally (never committed); compare `coverage-summary.json` |
| Per-test timing | `vitest run --reporter=json --outputFile=report.json` (per-test `duration`); `jest --json`; Vitest flags tests above `slowTestThreshold` |
| Slow-test quarantine | a separate Vitest project or tag-filtered run for nightly jobs, not `.skip` |

TypeScript forms of the redundancy types: placeholders are `it("works", () => {})`, `expect(true).toBe(true)`, `it.todo` left from scaffolding; stdlib tests assert `Array.prototype.map` or `JSON.parse` behavior; mock self-tests assert `expect(mockFn()).toBe(valueTheMockWasGiven)`; parametric duplicates collapse into `it.each`. Oversized snapshots (`toMatchSnapshot()` of a whole response when two fields matter) count as oversized fixtures.

Report example:

```
src/parser.test.ts
  L88 — `parseInput > returns undefined for empty input` [exact duplicate]
    Duplicate of `parseInput > returns undefined for blank string` (L74), same input "" and same assertion.
    Recommendation: drop; keep the blank-string test (clearer name).

  L120..L170 — `parseInt > parses 1` … `parses MAX_SAFE_INTEGER` [parametric duplicate]
    Six tests differing only in input values.
    Recommendation: collapse into one `it.each` table of `[input, expected]` rows.

test/integration/user.test.ts
  L40 — `creates then fetches a user` [subset duplicate]
    Subset of `full user workflow` (L95), which asserts create→fetch→update→delete.
    Recommendation: drop.
```

## Anti-patterns

- `.only` committed; `.skip` / `it.todo` without a linked issue
- Un-awaited `expect(...).rejects` / `.resolves` — the test passes regardless
- Real `setTimeout` sleeps or `page.waitForTimeout` instead of fake timers or web-first assertions
- `vi.mock` of the project's own modules instead of injecting a fake; mocks not restored between tests
- Real network calls in unit or integration tests; MSW without `onUnhandledRequest: "error"`
- A spy-call assertion (`toHaveBeenCalled`) as the only assertion when an outcome can be checked
- `as any` / `as unknown as T` to build test data instead of typed factories
- Whole-object snapshots accepted with `-u` without reading the diff
- Tests relying on module-level state or file execution order (Vitest isolates files, not tests within a file)
- `toBeTruthy()` / `toBeDefined()` where an exact value is known
- Copy-pasted setup across test files instead of `test/helpers/`
