import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { readFile } from "node:fs/promises";
import test from "node:test";

const manifestUrl = new URL("../public/source-manifest.json", import.meta.url);

function pngDimensions(buffer) {
  const signature = buffer.subarray(0, 8).toString("hex");
  assert.equal(signature, "89504e470d0a1a0a", "expected a real PNG signature");
  return {
    width: buffer.readUInt32BE(16),
    height: buffer.readUInt32BE(20),
  };
}

test("the public gallery exactly matches the repository source manifest", async () => {
  const manifest = JSON.parse(await readFile(manifestUrl, "utf8"));

  assert.equal(manifest.units.length, 12);
  assert.equal(new Set(manifest.units.map((unit) => unit.id)).size, 12);
  assert.match(manifest.boardStatus, /NO BOARD VERDICT/);

  for (const unit of manifest.units) {
    assert.doesNotMatch(
      unit.sourcePath,
      /(?:_96px|_face|_silhouettes|thumbnail|cache|rejected|comparisons|runs)/i,
      `${unit.id} points at a derivative, cache, or obsolete review artifact`,
    );

    const imageUrl = new URL(`../public/units/${unit.id}.png`, import.meta.url);
    const image = await readFile(imageUrl);
    const hash = createHash("sha256").update(image).digest("hex");
    const dimensions = pngDimensions(image);

    assert.equal(hash, unit.sha256, `${unit.id} source hash drifted`);
    assert.deepEqual(
      dimensions,
      { width: unit.width, height: unit.height },
      `${unit.id} native dimensions drifted`,
    );
  }
});
