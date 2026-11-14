import assert from "node:assert/strict";
import { test } from "node:test";
import * as mod from "./slugify.ts";

test("collapses separator runs and trims", () => {
  assert.equal(mod.slugify("Hello,  World!"), "hello-world");
  assert.equal(mod.slugify("  a  b!! "), "a-b");
});

test("public API is unchanged", () => {
  assert.deepEqual(Object.keys(mod), ["slugify"]);
  assert.equal(mod.slugify.length, 1);
});
