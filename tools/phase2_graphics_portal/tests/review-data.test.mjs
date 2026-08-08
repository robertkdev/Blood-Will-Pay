import assert from "node:assert/strict";
import test from "node:test";

import {
  MAX_COMMENT_LENGTH,
  isReviewDecision,
  isUnitId,
  normalizeComment,
} from "../lib/reviews.ts";

test("accepts only known unit ids and review decisions", () => {
  assert.equal(isUnitId("korath"), true);
  assert.equal(isUnitId("unknown"), false);
  assert.equal(isReviewDecision("approve"), true);
  assert.equal(isReviewDecision("needs_work"), true);
  assert.equal(isReviewDecision("maybe"), false);
});

test("normalizes valid comments and rejects empty or oversized input", () => {
  assert.equal(normalizeComment("  Strong silhouette.\r\nKeep it.  "), "Strong silhouette.\nKeep it.");
  assert.equal(normalizeComment("   "), null);
  assert.equal(normalizeComment("x".repeat(MAX_COMMENT_LENGTH + 1)), null);
});
