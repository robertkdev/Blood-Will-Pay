import { copyFile, mkdir, utimes, writeFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";

const root = fileURLToPath(new URL("../", import.meta.url));
const rawRoot = new URL("../visual-evidence/raw/", import.meta.url);
const stagedRoot = new URL("../visual-evidence/staged/", import.meta.url);
const sourceSha =
  "6bd90847f345beea49337beeb7be79f52cf105a4";

await mkdir(stagedRoot, { recursive: true });

const captures = [
  {
    file: "desktop-version-current.png",
    event: "inspect_veyra_current",
    state: "version_review",
    label: "Veyra P2-03 current candidate with version rail",
    group: "version-review",
    viewport: "desktop-1904x708",
    timestamp_ms: 0,
    role: "reference",
    pair: "version_switch",
  },
  {
    file: "desktop-version-closed-egg.png",
    event: "inspect_veyra_closed_egg",
    state: "version_review",
    label: "Veyra P2-01 closed egg historical candidate",
    group: "version-review",
    viewport: "desktop-1904x708",
    timestamp_ms: 100,
    role: "actual",
    pair: "version_switch",
  },
];

for (const capture of captures) {
  const stagedFile = new URL(capture.file, stagedRoot);
  await copyFile(new URL(capture.file, rawRoot), stagedFile);
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
    role: capture.role,
    camera: "browser",
    group: capture.group,
    viewport: capture.viewport,
    timestamp_ms: capture.timestamp_ms,
    layer: "final",
    pair: capture.pair,
  })),
};

await writeFile(
  `${root}\\visual-evidence\\captures.json`,
  `${JSON.stringify(manifest, null, 2)}\n`,
  "utf8",
);

console.log(
  `Prepared ${manifest.captures.length} version-review captures at ${root}\\visual-evidence`,
);
