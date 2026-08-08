# RGA, Trait, and Bridge-Unit Plan — 2026-07-24

Status: planning model, ready for kit implementation and runtime balance calibration.

Interactive source: `tools/rga_matrix_explorer/`
Canonical data: `tools/rga_matrix_explorer/data/model.json`
Deterministic proof: `tools/rga_matrix_explorer/public/proof-report.json`

## Authority and snapshot

This plan follows the live private Google design document at revision
`AIroW35YQkR-K4F1zPhHop5agS5jvC2dVdpSXfiAzfxbmpmb_mJcEXI0XMTTAncHv0ivXgwp7c24LoEc3t8RMic`
and its accepted blood-economy roster snapshot on
`codex/019f922e-cee-blood-economy-conversion` commit
`1debe922aa4482ebdc48bddf3cb6783cfa80da4b`.

The source roster has 49 units, 21 active traits, and a 10-unit board cap.
Mogul is retired. Teller and Ivara are removed. Laith is the one-cost Arcanist
mage. The bridge roster deliberately uses numbered temporary identities so
production naming cannot disguise a weak trait or RGA contract.

## What is mathematically proven

The RGA is a nine-archetype complete tournament:

1. Bastion Siege
2. Dive Reset
3. Zone Control
4. Attrition Engine
5. Wombo Engage
6. Control Prison
7. Wide Trait Engine
8. Long-Range Siege
9. Anti-Meta Flex

For nine archetypes there are `C(9, 2) = 36` unordered matchups. Each is
authored once. The score matrix is antisymmetric (`M = -Mᵀ`), with hard edges
worth `±2`, soft edges worth `±1`, and mirrors worth `0`.

Every row has the same multiset:

`{ +2, +2, +1, +1, 0, -1, -1, -2, -2 }`

Therefore every row sums to zero, every archetype owns exactly two hard wins
and two soft wins, and every archetype suffers exactly two soft losses and two
hard losses. Since `M × 1 = 0`, the uniform mixed strategy is an equilibrium
of this zero-sum planning model with value zero. The graph is also strongly
connected, so no isolated counter island or dominant composition exists.

The seeded matchup calibration runs 5,000 trials per authored pair. Hard edges
target 72% and soft edges target 61%; every observed rate must remain within
three percentage points. This proves the planning model is internally
consistent. It does **not** claim that unfinished Godot kits already produce
those rates; real combat telemetry remains the calibration gate.

## Trait supply contracts

Natural capstone, drafting redundancy, and paired-vertical fieldability are
separate acceptance contracts. No threshold is lowered to make the plan pass.
Eight-unit verticals receive at least two carriers beyond cap; three- through
six-unit verticals receive at least one; one- and two-unit traits retain at
least two alternatives beyond their threshold.

| Trait | Job family | Tiers | Current | Added | Planned |
|---|---|---:|---:|---:|---:|
| Aegis | defense | 2/4/6/8 | 4 | 6 | 10 |
| Arcanist | spell | 2/4/6/8 | 4 | 6 | 10 |
| Blessed | sustain | 2/4/6 | 5 | 3 | 8 |
| Bulwark | control answer | 2/4 | 4 | 1 | 5 |
| Cartel | cost shape | 2 | 5 | 0 | 5 |
| Catalyst | item engine | 1 | 4 | 0 | 4 |
| Chronomancer | tempo | 1 | 4 | 0 | 4 |
| Executioner | threshold offense | 2/4/6/8 | 8 | 2 | 10 |
| Exile | exact count | 1/3/5 | 6 | 0 | 6 |
| Fortified | defense | 2/4/6/8 | 6 | 4 | 10 |
| Harmony | exact count | 2 | 4 | 0 | 4 |
| Kaleidoscope | wide | 2 | 5 | 0 | 5 |
| Liaison | formation | 1/3/5 | 5 | 1 | 6 |
| Mentor | carry engine | 1/2/3/4 | 4 | 1 | 5 |
| Overload | spell tempo | 2/4/6 | 5 | 2 | 7 |
| Sanguine | sustain | 2/4/6 | 6 | 1 | 7 |
| Scholar | spell tempo | 2/4/6 | 6 | 1 | 7 |
| Striker | attack ramp | 2/4/6/8 | 4 | 6 | 10 |
| Titan | health ramp | 2/4/6/8 | 5 | 5 | 10 |
| Trader | drafting | 2/4/6 | 3 | 4 | 7 |
| Vindicator | shred | 2/4/6 | 5 | 3 | 8 |

The 23 additions also repair roster shape:

- Roles finish at exactly 12 Assassin, 12 Brawler, 12 Mage, 12 Marksman,
  12 Support, and 12 Tank.
- Costs finish at 21 one-cost, 18 two-cost, 16 three-cost, 11 four-cost, and
  6 five-cost units.
- All 22 canonical approaches appear on at least one bridge concept.

## Numbered bridge roster

Each bridge has exactly two active traits. Its hook is a hypothesis to prototype,
not final tuning or final copy.

| Unit | Cost / role | Trait bridge | RGA bridge | Kit hypothesis |
|---|---|---|---|---|
| Temporary Unit 01 | 1 Tank | Titan + Blessed | Bastion / Attrition | Damage absorbed turns overheal into a short team bulwark. |
| Temporary Unit 02 | 2 Brawler | Titan + Blessed | Attrition / Bastion | Attacks bank healing, then detonate it as a risky frontline pulse. |
| Temporary Unit 03 | 4 Marksman | Titan + Blessed | Long-range / Bastion | Long shots fortify the most threatened ally. |
| Temporary Unit 04 | 1 Tank | Aegis + Vindicator | Control / Bastion | Blocking a marked threat's cast exposes its defenses. |
| Temporary Unit 05 | 2 Assassin | Aegis + Vindicator | Anti-meta / Dive | Dodges one committed cast and wounds the caster's resistances. |
| Temporary Unit 06 | 3 Marksman | Aegis + Vindicator | Long-range / Attrition | Volleys alternate personal ward and resistance fracture. |
| Temporary Unit 07 | 1 Mage | Arcanist + Overload | Wombo / Wide | Stores allied casts, then releases a shape based on the last caster. |
| Temporary Unit 08 | 4 Support | Arcanist + Overload | Wide / Wombo | Creates a visible focus zone for one safer allied cast. |
| Temporary Unit 09 | 1 Brawler | Striker + Trader | Attrition / Anti-meta | Uninterrupted attacks improve a rebate; retargeting clears it. |
| Temporary Unit 10 | 2 Marksman | Striker + Trader | Long-range / Attrition | Accurate volleys build both damage and a discount token. |
| Temporary Unit 11 | 3 Assassin | Striker + Trader | Dive / Anti-meta | A threshold kill grants one reposition and a reroll fragment. |
| Temporary Unit 12 | 4 Support | Striker + Trader | Wombo / Control | Contracts one engager; success amplifies, failure taxes the next cast. |
| Temporary Unit 13 | 2 Tank | Aegis + Fortified | Bastion / Control | Redirects one projectile while warded, then must recharge by tanking. |
| Temporary Unit 14 | 3 Assassin | Aegis + Fortified | Dive / Zone | A brittle entry ward breaks into silence instead of bonus damage. |
| Temporary Unit 15 | 3 Mage | Arcanist + Fortified | Attrition / Zone | A protected channel paints a breakable damage clock. |
| Temporary Unit 16 | 3 Marksman | Arcanist + Fortified | Long-range / Zone | Fires through a destructible fortified lane. |
| Temporary Unit 17 | 5 Mage | Arcanist + Executioner | Wombo / Long-range | A distant verdict only executes after prior spell setup. |
| Temporary Unit 18 | 5 Assassin | Arcanist + Executioner | Dive / Wombo | Spends stored spell power on one blink; a failed execute strands it. |
| Temporary Unit 19 | 1 Brawler | Titan + Striker | Attrition / Wombo | Body-check damage scales from health lost, not passive maximum health. |
| Temporary Unit 20 | 2 Marksman | Titan + Striker | Long-range / Attrition | Ammunition grows heavier while one durable target survives. |
| Temporary Unit 21 | 1 Assassin | Aegis + Bulwark | Anti-meta / Dive | Ignores first control only while escaping; aggression removes the exit. |
| Temporary Unit 22 | 1 Support | Liaison + Mentor | Wide / Control | A visible pupil link redirects one threat through lane geometry. |
| Temporary Unit 23 | 2 Brawler | Sanguine + Scholar | Attrition / Control | Spends mana as health to seed a DoT, healing only if it completes. |

## Proven 10-slot double verticals

For capstones `A` and `B` on a board of ten, the minimum shared carriers are:

`overlap ≥ max(0, A + B - 10)`

Each promised board meets that lower bound exactly, without emblems, hidden
capacity, or trait-count augmentation:

| Identity | Capstones | Required / planned overlap | Ten-unit board |
|---|---|---:|---|
| Disgraced Colossi | Titan 8 + Blessed 6 | 4 / 4 | Korath, U01, U02, U03, Brute, Caldera, Draxelle, Malachor, Marble, Saffron |
| Wardbreak Tribunal | Aegis 8 + Vindicator 6 | 4 / 4 | Kythera, U04, U05, U06, Bastionne, Quorra, Veyra, U13, Mortem, Sable |
| Prismatic Arcanists | Arcanist 8 + Overload 6 | 4 / 4 | Cinder, Orielle, U07, U08, Laith, Paisley, U15, U17, Noxley, Quillith |
| Hostile Takeover | Striker 8 + Trader 6 | 4 / 4 | U09, U10, U11, U12, Berebell, Draxelle, Kett, Morrak, Gable, Knoll |

## Validation gates

`npm test` in `tools/rga_matrix_explorer` runs:

- 621 deterministic model checks;
- the seeded 5,000-trial matchup calibration;
- production web build;
- rendered HTML and client-surface checks.

`tools/rga_matrix_explorer/godot_validation/RgaTraitMatrixPlanSmoke.tscn`
loads the same JSON in a minimal Godot project with no game autoloads. It
rechecks the tournament degrees and row sums, natural capstones and redundancy,
final role and cost curves, approach coverage, sequential bridge identities,
and all four exact ten-slot overlap proofs.

The visual-debug packet records desktop and mobile states for all explorer
sections. Its first clean-context review rejected the mobile matrix because the
horizontal continuation was not obvious. The repaired capture adds an explicit
swipe affordance, and the hash-bound second review passes panels P001–P009.

## Runtime work still required

This document proves the completeness and internal balance of the **plan**.
Before any temporary unit becomes production content:

1. implement one small vertical cluster at a time;
2. run deterministic combat matrices against all nine archetypes;
3. calibrate real hard edges toward 65–75% and soft edges toward 55–65%;
4. reject any kit that removes meaningful positioning or target-selection
   counterplay;
5. run broad human playtests for novelty, comprehension, pivot frequency, and
   whether the losing player can explain why the counter worked.

Maximum fun and replayability are design objectives, not theorems. The plan
makes them testable by guaranteeing counter circulation, capstone access,
drafting alternatives, role/cost diversity, and four concrete high-expression
team-composition promises.
