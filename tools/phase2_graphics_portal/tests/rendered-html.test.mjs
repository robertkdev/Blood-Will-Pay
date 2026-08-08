import assert from "node:assert/strict";
import test from "node:test";

async function render() {
  const workerUrl = new URL("../dist/server/index.js", import.meta.url);
  workerUrl.searchParams.set("test", `${process.pid}-${Date.now()}`);
  const { default: worker } = await import(workerUrl.href);

  return worker.fetch(
    new Request("http://localhost/", {
      headers: { accept: "text/html" },
    }),
    {
      ASSETS: {
        fetch: async () => new Response("Not found", { status: 404 }),
      },
    },
    {
      waitUntil() {},
      passThroughOnException() {},
    },
  );
}

test("server-renders the Phase II concept archive", async () => {
  const response = await render();
  assert.equal(response.status, 200);
  assert.match(response.headers.get("content-type") ?? "", /^text\/html\b/i);

  const html = await response.text();
  assert.match(html, /<title>Phase II Concept Archive/);
  assert.match(html, /Candidate-only archive/);
  assert.match(html, /All 12/);
  assert.match(html, /Locked redesigns/);
  assert.match(html, /Knoll/);
  assert.match(html, /Malachor/);
  assert.match(html, /Direction locked/);
  assert.doesNotMatch(html, /codex-preview/);
  assert.doesNotMatch(html, /react-loading-skeleton/);
});

test("renders every selected concept name and source image", async () => {
  const response = await render();
  const html = await response.text();
  const names = [
    "Korath",
    "Veyra",
    "Cashmere",
    "Pilfer",
    "Nyxa",
    "Creep",
    "Knoll",
    "Quillith",
    "Kett",
    "Luna",
    "Malachor",
    "Sable",
  ];

  for (const name of names) {
    assert.match(html, new RegExp(`>${name}<`));
    assert.match(html, new RegExp(`/units/${name.toLowerCase()}\\.png`));
  }
});
