import assert from "node:assert/strict";
import { test } from "node:test";
import { isLeapYear } from "./leap.ts";

test("2000 is a leap year", () => {
  assert.equal(isLeapYear(2000), true);
});

test("1900 is a leap year", () => {
  assert.equal(isLeapYear(1900), true);
});
