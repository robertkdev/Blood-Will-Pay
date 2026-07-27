import { copyFile, mkdir, utimes, writeFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";

const root = fileURLToPath(new URL("../", import.meta.url));
const rawRoot = new URL("../visual-evidence/raw/", import.meta.url);
const stagedRoot = new URL("../visual-evidence/staged/", import.meta.url);
const sourceSha =
  "5450cb438712b6ddb75c0ab9c94c37ef2248567ee1479efbe31851230b76bbd9";

await mkdir(stagedRoot, { recursive: true });

const captures = [
  {
    file: "desktop-top-before.png",
    event: "gallery_loaded",
    state: "desktop",
    label: "Before: desktop identities below the fold",
    group: "overview",
    viewport: "desktop-1440x1000",
    timestamp_ms: 0,
    role: "before",
    pair: "desktop_identity",
  },
  {
    file: "desktop-top.png",
    event: "gallery_loaded",
    state: "desktop",
    label: "After: desktop identities visible",
    group: "overview",
    viewport: "desktop-1440x1000",
    timestamp_ms: 100,
    role: "after",
    pair: "desktop_identity",
  },
  {
    file: "desktop-knoll-modal.png",
    event: "inspect_knoll",
    state: "desktop_inspection",
    label: "Knoll full-size inspection",
    group: "overview",
    viewport: "desktop-1440x1000",
    timestamp_ms: 200,
  },
  {
    file: "mobile-top-before.png",
    event: "gallery_loaded",
    state: "mobile",
    label: "Before: mobile identity below the fold",
    group: "overview",
    viewport: "mobile-390x844",
    timestamp_ms: 300,
    role: "before",
    pair: "mobile_identity",
  },
  {
    file: "mobile-top.png",
    event: "gallery_loaded",
    state: "mobile",
    label: "After: mobile identity visible",
    group: "overview",
    viewport: "mobile-390x844",
    timestamp_ms: 400,
    role: "after",
    pair: "mobile_identity",
  },
  {
    file: "mobile-locked-filter.png",
    event: "filter_locked",
    state: "mobile_locked",
    label: "Locked filter: two directions",
    group: "overview",
    viewport: "mobile-390x844",
    timestamp_ms: 500,
  },
];

for (const capture of captures) {
  const stagedFile = new URL(capture.file, stagedRoot);
  await copyFile(
    new URL(capture.file, rawRoot),
    stagedFile,
  );
  const now = new Date();
  await utimes(stagedFile, now, now);
}

const manifest = {
  captures: captures.map(({ file, ...capture }) => ({
    path: `staged/${file}`,
    event: capture.event,
    metadata: {
      runtime: "Vinext local web runtime in Codex in-app browser",
      source: "http://localhost:3000/",
      source_sha256: sourceSha,
      build: "npm test / vinext build",
    },
    state: capture.state,
    label: capture.label,
    role: capture.role ?? "actual",
    camera: "browser",
    group: capture.group,
    viewport: capture.viewport,
    timestamp_ms: capture.timestamp_ms,
    layer: "final",
    ...(capture.pair ? { pair: capture.pair } : {}),
  })),
};

await writeFile(
  `${root}\\visual-evidence\\captures.json`,
  `${JSON.stringify(manifest, null, 2)}\n`,
  "utf8",
);

console.log(
  `Prepared ${manifest.captures.length} browser captures at ${root}\\visual-evidence`,
);
