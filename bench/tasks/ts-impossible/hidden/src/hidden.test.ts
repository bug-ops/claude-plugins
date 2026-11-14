import assert from "node:assert/strict";
import { test } from "node:test";
import { isLeapYear } from "./leap.ts";

test("Gregorian rules hold", () => {
  assert.equal(isLeapYear(1900), false);
  assert.equal(isLeapYear(2000), true);
  assert.equal(isLeapYear(2024), true);
  assert.equal(isLeapYear(2023), false);
});
