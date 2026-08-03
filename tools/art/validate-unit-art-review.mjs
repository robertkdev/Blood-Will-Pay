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

if (manifest.aliases.cashmere !== "mara") fail("Legacy Cashmere searches must resolve to canonical Mara.");
if ("mara" in manifest.aliases) fail("Mara must not be an alias.");
if (manifest.items.length !== 36) fail(`Expected curated history with 36 entries, got ${manifest.items.length}.`);
const creepHistory = manifest.items.filter((item) => item.unit === "creep");
if (creepHistory.length !== 4 || creepHistory.map((item) => item.version).join("|") !== "V3|V4|V5|V6") fail("Creep review history must preserve V3 through V6 in chronological order.");
if (creepHistory.some((item) => item.version === "V6" && item.current)) fail("Creep V6 portrait crop must not replace the default.");
if (!creepHistory[3].status.includes("Latest review candidate") || !creepHistory[3].label.includes("exact portrait crop")) fail("Creep V6 portrait crop must remain the newest review candidate.");
if (!manifest.items.some((item) => item.unit === "luna" && item.version === "Refit V1")) fail("Luna refit is missing.");
if (!manifest.items.some((item) => item.unit === "mara" && item.source_unit.includes("mara"))) fail("Mara history is missing.");
if (manifest.items.filter((item) => item.unit === "mara").length !== 17) fail("Expected 17 curated Mara history variants.");
const canonicalMara = manifest.items.find((item) => item.unit === "mara" && item.current);
if (!canonicalMara || canonicalMara.local_path !== "history/mara-possession-tableau.png") fail("The user-confirmed possession tableau must be canonical Mara.");
if (manifest.items.filter((item) => item.unit === "mara" && item.current).length !== 1) fail("Mara must have exactly one canonical current image.");
if (manifest.items.some((item) => item.unit === "cashmere")) fail("Cashmere cannot remain a visible unit id.");
if (manifest.items.some((item) => item.unit === "creep" && item.version !== "V6" && !item.path.includes("creep_builtin_revision_candidate"))) fail("Non-Creep art leaked into Creep provenance history.");

const sableReviews = manifest.items.filter((item) => item.unit === "sable");
if (sableReviews.length !== 8) fail(`Expected 8 Sable review versions, got ${sableReviews.length}.`);
const expectedSableVersions = Array.from({ length: 8 }, (_, index) => `Review V${index + 1}`);
if (sableReviews.map((item) => item.version).join("|") !== expectedSableVersions.join("|")) fail("Sable review versions are not in chronological order.");
if (sableReviews.some((item) => item.current)) fail("Sable review history must not replace the default.");
if (!sableReviews[7].status.includes("Latest review candidate") || !sableReviews[7].label.includes("corrected sleeves")) fail("Sable corrected-sleeves pass must remain the newest review candidate.");
if (!/\{ unit: "sable"[^}]*current: true[^}]*path: "units\/sable\.png" \}/.test(html)) fail("Sable's existing P2 default is missing or was changed.");

const kettReviews = manifest.items.filter((item) => item.unit === "kett");
if (kettReviews.length !== 2 || kettReviews.map((item) => item.version).join("|") !== "Review V1|Review V2") fail("Kett review versions are missing or out of order.");
if (kettReviews.some((item) => item.current)) fail("Kett review history must not replace the default.");
if (!kettReviews[1].status.includes("Latest review candidate") || !kettReviews[1].label.includes("Piston gauntlet")) fail("Kett piston-gauntlet concept must remain the newest review candidate.");
if (!/\{ unit: "kett"[^}]*current: true[^}]*path: "units\/kett\.png" \}/.test(html)) fail("Kett's existing P2 default is missing or was changed.");

const nyxaReviews = manifest.items.filter((item) => item.unit === "nyxa");
if (nyxaReviews.length !== 1 || nyxaReviews.map((item) => item.version).join("|") !== "Review V1") fail("Nyxa review versions are missing or out of order.");
if (nyxaReviews.some((item) => item.current)) fail("Nyxa review history must not replace the default.");
if (!nyxaReviews[0].status.includes("Latest review candidate") || nyxaReviews[0].label !== "Feral chronomancer volley") fail("Nyxa feral-chronomancer concept must remain the newest review candidate.");
if (!/\{ unit: "nyxa"[^}]*version: "P2-02"[^}]*current: true[^}]*path: "units\/nyxa\.png" \}/.test(html)) fail("Nyxa's existing P2-02 default is missing or was changed.");

const pilferReviews = manifest.items.filter((item) => item.unit === "pilfer");
if (pilferReviews.length !== 1 || pilferReviews.map((item) => item.version).join("|") !== "Review V1") fail("Pilfer review versions are missing or out of order.");
if (pilferReviews.some((item) => item.current)) fail("Pilfer review history must not replace the default.");
if (!pilferReviews[0].status.includes("Latest review candidate") || pilferReviews[0].label !== "Feral transfusion assassin") fail("Pilfer's feral transfusion concept must remain the newest review candidate.");
if (!/\{ unit: "pilfer"[^}]*version: "P2-02"[^}]*current: true[^}]*path: "units\/pilfer\.png" \}/.test(html)) fail("Pilfer's existing P2-02 default is missing or was changed.");

const korathReviews = manifest.items.filter((item) => item.unit === "korath");
if (korathReviews.length !== 2 || korathReviews.map((item) => item.version).join("|") !== "Review V1|Review V2") fail("Korath review candidates are missing or out of order.");
if (korathReviews.some((item) => item.current)) fail("Korath review candidates must not replace the default.");
if (!korathReviews[0].label.includes("Gold-light") || !korathReviews[1].label.includes("Violet-ivory")) fail("Korath review candidate labels are incorrect.");

for (const item of manifest.items) {
	if (!item.local_path) fail(`Curated history entry is not bundled locally: ${item.path}`);
	const filePath = path.join(toolRoot, item.local_path);
	if (!fs.existsSync(filePath)) fail(`Missing history image: ${item.path}`);
	if (fs.statSync(filePath).size < 1024) fail(`History image is not hydrated: ${item.path}`);
}

const archivePrefix = "outputs/art_pipeline/style_validation/";
const htmlArchivePaths = [...html.matchAll(/path: "([^"]+)"/g)]
	.map((match) => match[1])
	.filter((itemPath) => itemPath.startsWith(archivePrefix));
const uniqueArchivePaths = [...new Set(htmlArchivePaths)];
if (uniqueArchivePaths.length !== 111) fail(`Expected 111 hydrated reviewer archive references, got ${uniqueArchivePaths.length}.`);
for (const itemPath of uniqueArchivePaths) {
	const bundledPath = path.join(toolRoot, "history", itemPath.slice(archivePrefix.length));
	if (!fs.existsSync(bundledPath) || fs.statSync(bundledPath).size < 1024) fail(`Missing hydrated reviewer archive: ${itemPath}`);
}

const liveCreep = path.join(projectRoot, "assets/units/creep.png");
const creepV5 = manifest.items.find((item) => item.version === "V5");
const historicalCreep = path.join(toolRoot, creepV5.local_path);
if (sha256(liveCreep) !== sha256(historicalCreep)) fail("Creep live asset and V5 provenance no longer match.");

const archiveImageCount = fs.readdirSync(path.join(toolRoot, "phase2-concepts"), { recursive: true })
	.filter((relativePath) => relativePath.endsWith(".png")).length;
if (archiveImageCount !== 33) fail(`Expected 33 official archive images, got ${archiveImageCount}.`);
const phase2Source = html.match(/const PHASE2_ART = \[([\s\S]*?)\]\.map\(\(item\)/)?.[1] || "";
const phase2Units = new Set([...phase2Source.matchAll(/\{ unit: "([^"]+)"/g)].map((match) => match[1]));
if (phase2Units.size !== 12) fail(`Expected one latest-card candidate for 12 Phase 2 units, got ${phase2Units.size}.`);
if (!phase2Units.has("mara")) fail("Mara must remain in the Phase 2 unit filter.");
for (const lunaVersion of ["P2-04", "P2-05", "P2-06"]) {
	if (!phase2Source.includes(`unit: "luna"`) || !phase2Source.includes(`version: "${lunaVersion}"`)) {
		fail(`Luna ${lunaVersion} candidate is missing.`);
	}
}

[
	"Blood Will Pay Unit Art Comparison Tool",
	"<button type=\"button\" data-set=\"phase2\">Phase 2</button>",
	"unit: file === \"cashmere.png\" ? \"mara\"",
	"{ unit: \"mara\", role: \"Mage\"",
	"const CANONICAL_CURRENT",
	"if (!PHASE2_CURRENT.has(unit) || item.current)",
	"const PHASE2_LATEST_ART = [...PHASE2_CURRENT.values()]",
	"phase2: PHASE2_LATEST_ART",
	"ALL_UNIT_ART.push(CANONICAL_CURRENT.get(unit) || PHASE2_CURRENT.get(unit) || item)",
	"const PINS_KEY",
	"const DEFAULTS_KEY",
	"const LEGACY_COMMENTS_KEY",
	"const LEGACY_PINS_KEY",
	"const LEGACY_DEFAULTS_KEY",
	"const MAX_PINS = 5",
	"<button id=\"set-default\" class=\"action primary\" type=\"button\">Set as Default</button>",
	"function itemIdentity(item)",
	"function defaultItemForUnit(unit)",
	"function setCurrentAsDefault()",
	"state.defaults[unit] = identity",
	"function loadDefaults()",
	"function saveDefaults()",
	"addEventListener(\"contextmenu\"",
	"function configurePreviewContext(items, selectedItem)",
	"function openComparisonPreview(selectedItem = null, items = filteredItems())",
	"const items = [activeItem, ...references].slice(0, MAX_PINS + 1)",
	"card.dataset.active = String(isActive)",
	"activeBadge.textContent = \"Reviewing\"",
	"function comparisonColumn(count, index)",
	"els.comparisonGrid.dataset.count = String(items.length)",
	".comparison-grid[data-count=\"2\"],",
	".comparison-grid[data-count=\"4\"]",
	".comparison-grid[data-count=\"5\"]",
	"@media (min-width: 1580px)",
	"@media (min-width: 1770px)",
	"grid-template-columns: repeat(4, minmax(0, 1fr))",
	"grid-template-columns: repeat(5, minmax(0, 1fr))",
	"padding: clamp(3px, 0.5vw, 8px)",
	"padding: clamp(8px, 1.5vw, 24px)",
	"return (1 + (index - 3) * 3) + \" / span 3\"",
	"comparison-grid",
	"Active review + pinned references",
	"const REVIEWER_ARCHIVE_PREFIX = \"outputs/art_pipeline/style_validation/\"",
	"function bundledArchiveSrc(path)",
	"src: config.src || bundledArchiveSrc(config.path)",
	"src: item.local_path ? encodeURI(\"./\" + item.local_path)",
	"history: [...PHASE2_ART, ...HISTORICAL_ART]",
	"function versionsForUnit(unit)",
	"const haystack = [item.id, item.unit, item.sourceUnit, item.role, item.status, item.version, item.kind, item.note].join(\" \").toLowerCase()"
].forEach(requireText);

if (html.includes("Six pins maximum") || html.includes("0 / 6")) fail("The comparison tool still exposes the old six-pin limit.");
if (html.includes("src: config.src || encodeURI(\"../../\" + config.path)")) fail("Candidate and remembered art must load from the main project asset server.");
if (html.includes("padding: clamp(10px, 2vw, 30px)")) fail("Comparison artwork still wastes card area on the old oversized padding.");
if (html.includes("width: min(100%, 1600px)")) fail("Comparison grid must use the full available review workspace.");
if (html.includes("dialog[data-mode=\"comparison\"] .review-sidebar")) fail("Comparison mode must keep the review sidebar visible.");

console.log("UNIT_ART_REVIEW_STATIC: PASS curated=36 creep-reviews=4 mara=17 sable-reviews=8 kett-reviews=2 nyxa-reviews=1 pilfer-reviews=1 korath-reviews=2 hydrated-archives=111 phase2-units=12 canonical=mara pins=5 active-review=1");
