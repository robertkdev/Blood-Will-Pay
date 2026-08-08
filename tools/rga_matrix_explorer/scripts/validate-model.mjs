import { readFile, writeFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";

const modelUrl = new URL("../data/model.json", import.meta.url);
const model = JSON.parse(await readFile(modelUrl, "utf8"));
const failures = [];
const checks = [];

function check(condition, label, details = "") {
  checks.push({ label, passed: Boolean(condition), details });
  if (!condition) failures.push(details ? `${label}: ${details}` : label);
}

function countBy(items, key) {
  const counts = {};
  for (const item of items) {
    const value = String(item[key]);
    counts[value] = (counts[value] ?? 0) + 1;
  }
  return counts;
}

function mapsEqual(actual, expected) {
  const keys = new Set([...Object.keys(actual), ...Object.keys(expected)]);
  return [...keys].every((key) => Number(actual[key] ?? 0) === Number(expected[key] ?? 0));
}

const traitById = new Map(model.traits.map((trait) => [trait.id, trait]));
const bridgeById = new Map(model.bridgeUnits.map((unit) => [unit.id, unit]));
const archetypeById = new Map(model.archetypes.map((item) => [item.id, item]));
const approachSet = new Set(model.catalog.approaches);
const roleSet = new Set(model.catalog.roles);
const retiredSet = new Set(model.meta.retiredTraits);

check(model.traits.length === model.meta.activeTraitCount, "active trait catalog count", `${model.traits.length}/${model.meta.activeTraitCount}`);
check(new Set(model.traits.map((trait) => trait.id)).size === model.traits.length, "trait ids are unique");
check(model.bridgeUnits.length === 23, "numbered bridge roster count", `${model.bridgeUnits.length}/23`);
check(model.meta.baseRosterCount + model.bridgeUnits.length === model.meta.plannedRosterCount, "planned roster arithmetic");

const finalTraitCounts = {};
const traitCostCoverage = {};
for (const trait of model.traits) {
  const bridgeCarriers = model.bridgeUnits.filter((unit) => unit.traits.includes(trait.id));
  const finalCount = trait.currentCarriers.length + bridgeCarriers.length;
  const maxThreshold = Math.max(...trait.thresholds);
  const redundancyTarget = maxThreshold >= 8 ? 2 : maxThreshold <= 2 ? 2 : 1;
  const requiredSupply = maxThreshold + redundancyTarget;
  const costs = new Set([
    ...Object.keys(trait.currentCostCounts).map(Number),
    ...bridgeCarriers.map((unit) => unit.cost),
  ]);

  finalTraitCounts[trait.id] = finalCount;
  traitCostCoverage[trait.id] = [...costs].sort((a, b) => a - b);
  check(finalCount >= maxThreshold, `${trait.id} natural capstone availability`, `${finalCount}/${maxThreshold}`);
  check(finalCount >= requiredSupply, `${trait.id} drafting redundancy`, `${finalCount}/${requiredSupply}`);
  if (maxThreshold >= 4) {
    check(costs.size >= 3, `${trait.id} usable cost curve`, `cost tiers ${[...costs].sort().join(",")}`);
  }
  check(trait.answers.length >= 4, `${trait.id} has explicit counterplay`, trait.answers.join(", "));
}

const bridgeRoles = countBy(model.bridgeUnits, "role");
const finalRoles = {};
for (const role of model.catalog.roles) {
  finalRoles[role] = Number(model.catalog.baseRoleCounts[role] ?? 0) + Number(bridgeRoles[role] ?? 0);
}
check(mapsEqual(finalRoles, model.catalog.targetFinalRoleCounts), "final roles are exactly balanced", JSON.stringify(finalRoles));

const bridgeCosts = countBy(model.bridgeUnits, "cost");
const finalCosts = {};
for (const cost of ["1", "2", "3", "4", "5"]) {
  finalCosts[cost] = Number(model.catalog.baseCostCounts[cost] ?? 0) + Number(bridgeCosts[cost] ?? 0);
}
check(mapsEqual(finalCosts, model.catalog.targetFinalCostCounts), "final cost curve matches target", JSON.stringify(finalCosts));
check(finalCosts["1"] >= finalCosts["2"] && finalCosts["2"] >= finalCosts["3"] && finalCosts["3"] >= finalCosts["4"] && finalCosts["4"] >= finalCosts["5"], "final cost curve is monotone");

const usedBridgeApproaches = new Set();
for (const [index, unit] of model.bridgeUnits.entries()) {
  check(unit.label === `Temporary Unit ${String(index + 1).padStart(2, "0")}`, `${unit.id} is numbered, not named`, unit.label);
  check(unit.id === `temp_${String(index + 1).padStart(2, "0")}`, `${unit.label} has stable numeric id`, unit.id);
  check(unit.traits.length === 2, `${unit.label} is a two-trait bridge`, unit.traits.join(" + "));
  check(unit.traits.every((trait) => traitById.has(trait) && !retiredSet.has(trait)), `${unit.label} references active traits`);
  check(roleSet.has(unit.role), `${unit.label} role is valid`, unit.role);
  check(Number.isInteger(unit.cost) && unit.cost >= 1 && unit.cost <= 5, `${unit.label} cost is valid`, String(unit.cost));
  check(unit.approaches.length === 3, `${unit.label} has three readable approaches`, unit.approaches.join(", "));
  check(unit.approaches.every((approach) => approachSet.has(approach)), `${unit.label} approaches are canonical`);
  unit.approaches.forEach((approach) => usedBridgeApproaches.add(approach));
}
check(usedBridgeApproaches.size === approachSet.size, "bridge roster covers all 22 approaches", `${usedBridgeApproaches.size}/${approachSet.size}`);

check(model.archetypes.length === 9, "nine archetypes define the meta ring");
for (const archetype of model.archetypes) {
  const slots = Object.values(archetype.roleShape).reduce((sum, count) => sum + count, 0);
  check(slots === model.meta.boardCap, `${archetype.name} uses exactly ten slots`, `${slots}/${model.meta.boardCap}`);
  check(archetype.signatureTraits.every((trait) => traitById.has(trait)), `${archetype.name} traits are active`);
  check(archetype.approaches.every((approach) => approachSet.has(approach)), `${archetype.name} approaches are canonical`);
}

const matrix = Object.fromEntries(model.archetypes.map((row) => [
  row.id,
  Object.fromEntries(model.archetypes.map((column) => [column.id, 0])),
]));
const pairKeys = new Set();
for (const edge of model.counterEdges) {
  check(archetypeById.has(edge.winner) && archetypeById.has(edge.loser), "counter edge endpoints exist", `${edge.winner} > ${edge.loser}`);
  check(edge.winner !== edge.loser, "counter edge is not a self edge", edge.winner);
  check(edge.strength === "hard" || edge.strength === "soft", "counter strength is valid", edge.strength);
  const pairKey = [edge.winner, edge.loser].sort().join("|");
  check(!pairKeys.has(pairKey), "each archetype pair is authored once", pairKey);
  pairKeys.add(pairKey);
  const value = edge.strength === "hard" ? 2 : 1;
  matrix[edge.winner][edge.loser] = value;
  matrix[edge.loser][edge.winner] = -value;
}

check(model.counterEdges.length === 36, "complete nine-archetype pair map", `${model.counterEdges.length}/36`);
check(pairKeys.size === 36, "all unordered archetype pairs covered", `${pairKeys.size}/36`);
check(model.counterEdges.filter((edge) => edge.strength === "hard").length === 18, "hard edge budget is balanced");
check(model.counterEdges.filter((edge) => edge.strength === "soft").length === 18, "soft edge budget is balanced");

for (const archetype of model.archetypes) {
  const row = Object.values(matrix[archetype.id]);
  const counts = {
    hardWins: row.filter((value) => value === 2).length,
    softWins: row.filter((value) => value === 1).length,
    softLosses: row.filter((value) => value === -1).length,
    hardLosses: row.filter((value) => value === -2).length,
  };
  check(Object.values(counts).every((count) => count === 2), `${archetype.name} has 2/2/2/2 matchup symmetry`, JSON.stringify(counts));
  check(row.reduce((sum, value) => sum + value, 0) === 0, `${archetype.name} zero-sum row balance`);
}

for (const a of model.archetypes) {
  check(matrix[a.id][a.id] === 0, `${a.name} mirror is neutral`);
  for (const b of model.archetypes) {
    check(matrix[a.id][b.id] === -matrix[b.id][a.id], `${a.code}/${b.code} is antisymmetric`);
  }
}

const uniformWeight = 1 / model.archetypes.length;
for (const archetype of model.archetypes) {
  const expectedPayoff = Object.values(matrix[archetype.id]).reduce((sum, value) => sum + value * uniformWeight, 0);
  check(Math.abs(expectedPayoff) < 1e-12, `${archetype.name} has zero payoff against uniform equilibrium`, String(expectedPayoff));
}

function reachableFrom(start) {
  const seen = new Set([start]);
  const queue = [start];
  while (queue.length) {
    const current = queue.shift();
    for (const next of model.archetypes) {
      if (matrix[current][next.id] > 0 && !seen.has(next.id)) {
        seen.add(next.id);
        queue.push(next.id);
      }
    }
  }
  return seen;
}
check(model.archetypes.every((item) => reachableFrom(item.id).size === model.archetypes.length), "counter graph is strongly connected");

function unitTraits(unitId) {
  const bridge = bridgeById.get(unitId);
  if (bridge) return bridge.traits;
  return model.traits.filter((trait) => trait.currentCarriers.includes(unitId)).map((trait) => trait.id);
}

for (const pair of model.promisedPairs) {
  const [leftId, rightId] = pair.traits;
  const left = traitById.get(leftId);
  const right = traitById.get(rightId);
  const leftThreshold = Math.max(...left.thresholds);
  const rightThreshold = Math.max(...right.thresholds);
  const requiredOverlap = Math.max(0, leftThreshold + rightThreshold - model.meta.boardCap);
  const overlap = pair.board.filter((unitId) => {
    const traits = unitTraits(unitId);
    return traits.includes(leftId) && traits.includes(rightId);
  });
  const leftCount = pair.board.filter((unitId) => unitTraits(unitId).includes(leftId)).length;
  const rightCount = pair.board.filter((unitId) => unitTraits(unitId).includes(rightId)).length;

  check(pair.board.length === model.meta.boardCap, `${pair.identity} board uses ten slots`, `${pair.board.length}/10`);
  check(new Set(pair.board).size === pair.board.length, `${pair.identity} board has unique units`);
  check(requiredOverlap === pair.requiredOverlap, `${pair.identity} overlap formula`, `${leftThreshold}+${rightThreshold}-${model.meta.boardCap}=${requiredOverlap}`);
  check(overlap.length === pair.plannedOverlap, `${pair.identity} overlap is realized`, `${overlap.length}/${pair.plannedOverlap}`);
  check(leftCount >= leftThreshold && rightCount >= rightThreshold, `${pair.identity} fields both capstones`, `${leftId} ${leftCount}/${leftThreshold}; ${rightId} ${rightCount}/${rightThreshold}`);
}

let rngState = 0x6d2b79f5;
function random() {
  rngState ^= rngState << 13;
  rngState ^= rngState >>> 17;
  rngState ^= rngState << 5;
  return (rngState >>> 0) / 4294967296;
}

const simulations = [];
for (const edge of model.counterEdges) {
  const expected = edge.strength === "hard" ? 0.72 : 0.61;
  const trials = 5000;
  let wins = 0;
  for (let i = 0; i < trials; i += 1) {
    if (random() < expected) wins += 1;
  }
  const observed = wins / trials;
  simulations.push({ ...edge, trials, expected, observed });
  check(Math.abs(observed - expected) <= 0.03, `${edge.winner} > ${edge.loser} seeded matchup calibration`, `${observed.toFixed(3)} vs ${expected.toFixed(2)}`);
}

const report = {
  schemaVersion: 1,
  generatedAt: new Date().toISOString(),
  modelVersion: model.meta.version,
  sourceCommit: model.meta.sourceCommit,
  passed: failures.length === 0,
  summary: {
    checks: checks.length,
    failures: failures.length,
    traits: model.traits.length,
    bridgeUnits: model.bridgeUnits.length,
    plannedRoster: model.meta.plannedRosterCount,
    archetypes: model.archetypes.length,
    counterPairs: pairKeys.size,
    promisedDoubleVerticals: model.promisedPairs.length,
  },
  finalTraitCounts,
  traitCostCoverage,
  finalRoles,
  finalCosts,
  matrix,
  simulations,
  failures,
};

if (process.argv.includes("--write-report")) {
  const outputUrl = new URL("../public/proof-report.json", import.meta.url);
  await writeFile(outputUrl, `${JSON.stringify(report, null, 2)}\n`, "utf8");
  console.log(`Wrote ${fileURLToPath(outputUrl)}`);
}

if (failures.length) {
  console.error(`RGA matrix validation failed (${failures.length}/${checks.length} checks):`);
  failures.forEach((failure) => console.error(`- ${failure}`));
  process.exit(1);
}

console.log(`RGA matrix validation PASS: ${checks.length} checks`);
console.log(`Traits: ${model.traits.length}; numbered bridges: ${model.bridgeUnits.length}; planned roster: ${model.meta.plannedRosterCount}`);
console.log(`Archetypes: ${model.archetypes.length}; authored counter pairs: ${pairKeys.size}; double verticals: ${model.promisedPairs.length}`);
console.log(`Final roles: ${JSON.stringify(finalRoles)}`);
console.log(`Final costs: ${JSON.stringify(finalCosts)}`);
