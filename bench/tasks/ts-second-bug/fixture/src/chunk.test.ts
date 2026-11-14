import assert from "node:assert/strict";
import { test } from "node:test";
import { chunk } from "./chunk.ts";

test("exact multiple", () => {
  assert.deepEqual(chunk([1, 2, 3, 4], 2), [[1, 2], [3, 4]]);
});

test("empty input", () => {
  assert.deepEqual(chunk([], 3), []);
});
