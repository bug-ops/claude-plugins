import assert from "node:assert/strict";
import { test } from "node:test";
import { chunk } from "./chunk.ts";

test("keeps the trailing partial group", () => {
  assert.deepEqual(chunk([1, 2, 3, 4, 5], 2), [[1, 2], [3, 4], [5]]);
});

test("size larger than the input", () => {
  assert.deepEqual(chunk([1, 2], 5), [[1, 2]]);
});
