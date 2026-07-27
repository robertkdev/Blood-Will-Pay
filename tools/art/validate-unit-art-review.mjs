import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import vm from "node:vm";

const toolRoot = path.resolve(process.argv[2] || ".");
const projectRoot = path.resolve(process.argv[3] || process.cwd());
const htmlPath = path.join(toolRoot, "unit-art-review.html");
const dataPath = path.join(toolRoot, "unit-art-history-data.js");
const html = fs.readFileSync(htmlPath, "utf8");
const dataSource = fs.readFileSync(dataPath, "utf8");
const context = { window: {} };
vm.runInNewContext(dataSource, context, { filename: dataPath });

const manifest = context.window.GAMBLE_BATTLE_UNIT_ART_HISTORY;
const fail = (message) => { throw new Error(message); };
const requireText = (value) => {
	if (!html.includes(value)) fail(`Missing tool behavior: ${value}`);
};
const sha256 = (filePath) => crypto.createHash("sha256").update(fs.readFileSync(filePath)).digest("hex");

if ("mara" in manifest.aliases || manifest.aliases.cashmere) fail("Mara must be the canonical unit name, not an alias.");
if (manifest.items.length !== 5) fail(`Expected curated history with 5 entries, got ${manifest.items.length}.`);
if (manifest.items.filter((item) => item.unit === "creep").length !== 3) fail("Creep must have exactly V3, V4, and V5 provenance entries.");
if (!manifest.items.some((item) => item.unit === "luna" && item.version === "Refit V1")) fail("Luna refit is missing.");
if (!manifest.items.some((item) => item.unit === "mara" && item.source_unit === "mara")) fail("Mara history is missing.");
if (manifest.items.some((item) => item.unit === "creep" && !item.path.includes("creep_builtin_revision_candidate"))) fail("Non-Creep art leaked into Creep history.");
if (manifest.items.some((item) => item.unit === "cashmere" || item.source_unit === "cashmere")) fail("Legacy Cashmere identifiers must remain provenance paths only, not visible unit metadata.");

for (const item of manifest.items) {
	if (!item.local_path) fail(`Curated history entry is not bundled locally: ${item.path}`);
	const filePath = item.local_path ? path.join(toolRoot, item.local_path) : path.join(projectRoot, item.path);
	if (!fs.existsSync(filePath)) fail(`Missing history image: ${item.path}`);
	if (fs.statSync(filePath).size < 1024) fail(`History image is not hydrated: ${item.path}`);
}

const liveCreep = path.join(projectRoot, "assets/units/creep.png");
const creepV5 = manifest.items.find((item) => item.version === "V5");
const historicalCreep = path.join(toolRoot, creepV5.local_path);
if (sha256(liveCreep) !== sha256(historicalCreep)) fail("Creep live asset and V5 provenance no longer match.");

for (const relativePath of [
	"phase2-concepts/units/luna.png",
	"phase2-concepts/versions/luna/p2-01.png",
	"phase2-concepts/versions/cashmere/p2-01.png"
]) {
	const filePath = path.join(toolRoot, relativePath);
	if (!fs.existsSync(filePath) || fs.statSync(filePath).size < 1024) fail(`Missing hydrated official archive image: ${relativePath}`);
}

const archiveImageCount = fs.readdirSync(path.join(toolRoot, "phase2-concepts"), { recursive: true })
	.filter((relativePath) => relativePath.endsWith(".png")).length;
if (archiveImageCount !== 30) fail(`Expected 30 official P2/S3 archive images, got ${archiveImageCount}.`);

[
	"Gamble Battle Unit Art Comparison Tool",
	"./unit-art-history-data.js",
	"Comment on this version",
	"previous-version",
	"next-version",
	"HISTORY_SEARCH_ALIASES",
	"contentKey",
	"src: item.local_path ? encodeURI(\"./\" + item.local_path)",
	"const haystack = [item.id, item.unit, item.sourceUnit, item.role, item.status, item.version, item.kind, item.note].join(\" \").toLowerCase()"
].forEach(requireText);

console.log("UNIT_ART_REVIEW_STATIC: PASS curated=5 p2=30 canonical=mara creep_v5=deduped");
