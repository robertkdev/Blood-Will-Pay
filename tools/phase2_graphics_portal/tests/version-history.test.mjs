import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { readFile } from "node:fs/promises";
import test from "node:test";

import { unitConcepts } from "../app/unitData.ts";
import {
  buildReviewExport,
  reviewExportToMarkdown,
} from "../lib/reviewExport.ts";

function pngDimensions(buffer) {
  assert.equal(
    buffer.subarray(0, 8).toString("hex"),
    "89504e470d0a1a0a",
    "expected a real PNG signature",
  );
  return {
    width: buffer.readUInt32BE(16),
    height: buffer.readUInt32BE(20),
  };
}

test("publishes 30 named, source-backed primary versions", async () => {
  const versions = unitConcepts.flatMap((concept) => concept.versions);
  assert.equal(unitConcepts.length, 12);
  assert.equal(versions.length, 30);
  assert.equal(
    new Set(
      unitConcepts.flatMap((concept) =>
        concept.versions.map((version) => `${concept.id}:${version.id}`),
      ),
    ).size,
    30,
  );

  for (const concept of unitConcepts) {
    assert.ok(
      concept.versions.some(
        (version) => version.id === concept.currentVersionId,
      ),
      `${concept.id} is missing its current version`,
    );

    for (const version of concept.versions) {
      assert.match(version.referenceName, new RegExp(`^${concept.name} `));
      assert.doesNotMatch(
        version.sourcePath,
        /(?:_96px|_face|_silhouettes|thumbnail|cache|rejected|comparisons|runs)/i,
      );
      const imageUrl = new URL(`../public${version.image}`, import.meta.url);
      const image = await readFile(imageUrl);
      assert.equal(
        createHash("sha256").update(image).digest("hex"),
        version.sha256,
        `${version.referenceName} hash drifted`,
      );
      assert.deepEqual(
        pngDimensions(image),
        { width: version.width, height: version.height },
        `${version.referenceName} dimensions drifted`,
      );
    }
  }
});

test("review export is version-bound, deterministic, and omits email", () => {
  const veyra = unitConcepts.find((concept) => concept.id === "veyra");
  assert.ok(veyra);
  const closedEgg = veyra.versions.find((version) => version.id === "p2-01");
  assert.ok(closedEgg);
  const rows = {
    decisions: [
      {
        unit_id: "veyra",
        concept_sha256: closedEgg.sha256,
        decision: "approve",
        reviewer_name: "Owner",
        updated_at: 100,
      },
    ],
    comments: [
      {
        id: "comment-1",
        unit_id: "veyra",
        concept_sha256: closedEgg.sha256,
        body: "Use this closed egg.",
        author_name: "Owner",
        created_at: 90,
      },
    ],
  };

  const reviewExport = buildReviewExport(unitConcepts, "source-head", rows);
  const markdown = reviewExportToMarkdown(reviewExport);
  const json = JSON.stringify(reviewExport);
  assert.equal(reviewExport.units.length, 12);
  assert.match(markdown, /Veyra P2-01 — Closed Egg/);
  assert.match(markdown, /Use this closed egg/);
  assert.doesNotMatch(json, /email/i);
  assert.equal(markdown, reviewExportToMarkdown(reviewExport));
});
