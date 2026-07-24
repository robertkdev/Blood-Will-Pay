import assert from "node:assert/strict";
import test from "node:test";

async function render(pathname = "/") {
  const workerUrl = new URL("../dist/server/index.js", import.meta.url);
  workerUrl.searchParams.set("test", `${process.pid}-${Date.now()}-${pathname}`);
  const { default: worker } = await import(workerUrl.href);

  return worker.fetch(
    new Request(`http://localhost${pathname}`, {
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

test("server-renders the complete RGA explorer shell", async () => {
  const response = await render();
  assert.equal(response.status, 200);
  assert.match(response.headers.get("content-type") ?? "", /^text\/html\b/i);

  const html = await response.text();
  assert.match(html, /<title>Gamble Battle — RGA Matrix Explorer<\/title>/i);
  assert.match(html, /Every strategy has prey/);
  assert.match(html, /Counter matrix/);
  assert.match(html, /Trait atlas/);
  assert.match(html, /Bridge roster/);
  assert.match(html, /Team lab/);
  assert.match(html, /621/);
  assert.match(html, /property="og:image" content="\/og-card\.png"/i);
  assert.match(html, /name="twitter:card" content="summary_large_image"/i);
  assert.doesNotMatch(html, /codex-preview|Building your site|react-loading-skeleton/i);
});

test("renders the nine-by-nine matchup surface with accessible controls", async () => {
  const response = await render();
  const html = await response.text();
  assert.match(html, /RGA counter matrix/);
  assert.match(html, /Bastion Siege versus Dive Reset: Favored · Hard/);
  assert.match(html, /Anti-Meta Flex/);
  assert.match(html, /Selected matchup/);
  assert.match(html, /planning-model win expectation/);
});
