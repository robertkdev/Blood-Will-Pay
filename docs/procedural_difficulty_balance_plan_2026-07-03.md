# Procedural Difficulty Balance Plan

## Current audit surface

Run:

```text
tests/rga_testing/validation/DifficultyRatingAudit.tscn
```

Output:

```text
user://difficulty_rating_audit.json
```

On Windows MCP runs, that resolves to:

```text
C:\Users\Flipm\AppData\Roaming\Godot\app_userdata\Gamble Battle\difficulty_rating_audit.json
```

The audit reports:

- every playable unit rating at levels `1,2,3,4,5,10`,
- every creep rating at the same levels,
- other unit resources that resolve through `UnitFactory`,
- component/completed/special item stat and effect rating estimates,
- generated sample boards for multiple seeds and chapters,
- active enemy traits on each sampled board,
- generator difficulty, target, rating error, trait pressure, item pressure, and audit-adjusted rating.

## Current generator rating

Unit and creep ratings:

- Playable unit: `round((6 + cost * 6) * 1.45^(level - 1))`
- Creep: `round(EASIEST_REFERENCE_RATING * 1.35^(level - 1))`
- `EASIEST_REFERENCE_RATING = 100` anchors the target curve; Chapter 1 Round 1 is generated from the same creep stage rule as later chapters.

Chapter target:

- `chapter_base = 100 + (chapter - 1) * 18 + floor((chapter - 1) / 5) * 35`
- Round multipliers:
  - creep: `0.35`
  - first RGA: `0.70`
  - second RGA: `0.80`
  - boss: `0.85`
  - mirror: `1.05`

Creep stages contain at least two lowercase creep reward enemies, then compare raw creep rating against the stage target. If the raw creep board overshoots the target, the generator emits `rules.stat_scale`; `StageRuleRunner` applies that target-derived scale to spawned creep combat stats. This keeps starter-safe reward rounds procedural while allowing multiple per-kill component reward chances instead of hardcoding a single Chapter 1 creep or stat override.

Boss stages keep the one-featured-enemy shape, but the generator now caps boss stat inflation. The first boss may scale at most `2.25x`; later caps rise slowly by target band and selected unit cost, with a hard cap of `3.25x`. If a capped single boss cannot honestly reach the requested curve budget, `target_rating` is lowered to the effective playable rating and `requested_target_rating` records the original budget for audit context.

Generated normal/boss board difficulty now includes:

- `unit_rating`: sum of selected unit level ratings,
- `trait_pressure_rating`: active enemy trait pressure from trait thresholds,
- `item_pressure_rating`: pressure from generated completed-item enemy loadouts,
- `difficulty_rating = unit_rating + trait_pressure_rating + item_pressure_rating`.

## Trait pressure

The generator prices only active trait tiers. It uses the same trait thresholds as `TraitCompiler` by loading `data/traits/<Trait>.tres`.

Current estimate source:

- `scripts/game/progression/difficulty_rating_model.gd`
- `DifficultyRatingModel.MODEL_VERSION = trait-item-coefficients-v1`
- `TRAIT_COEFFICIENTS` contains explicit per-trait pressure coefficients for all 22 trait resources.

The model still uses a compact shape per trait: a board-rating scale, base percentage, tier step, threshold flat value, and count flat value. The important change is that the values are now named coefficients per trait instead of one hidden formula for every trait. This keeps Chronomancer, Cartel, Harmony, Titan, economy traits, and support traits separately tunable as combat telemetry improves.

## Items

Generated normal and boss boards can assign completed enemy item loadouts once the target rating crosses the item thresholds. The generator emits `rules.items`, `rules.item_pressure_rating`, and `rules.item_loadout_summary`; `StageRuleRunner` applies those loadouts during enemy spawning.

The generator and audit estimate item pressure from `DifficultyRatingModel`:

- stat weights for the supported item stat keys,
- explicit effect ratings for all 36 completed-item runtime effect IDs,
- total completed-item rating = stat pressure + effect pressure.

Latest audit read: 36 completed items range from rating `48` to `118`, average `67.58`. Low examples include `hemothorn` at `48` and `relay`/`conductor` at `50`; high examples include `stone` at `118`, `lifetaker` at `101`, and `wardheart` at `88`.

## Balance gates

Use these as acceptance gates before tuning by feel:

1. `DifficultyCoefficientGate.tscn` passes. This is the coefficient coverage gate: all trait resources need explicit trait coefficients, every completed item stat/effect needs a priced coefficient, no priced effect may be unused, generated specs must carry the active `difficulty_model_version`, and recomputed unit + trait + item pressure must match `rules.difficulty_rating`.
2. `DifficultyRatingAudit.tscn` passes and writes a report.
3. `CompletedItemEffectRegistrySmoke.tscn` passes with all completed-item effect IDs registered.
4. `CompletedItemRuntimeEffectsProbe.tscn` passes with all completed item effects producing runtime-visible state changes.
5. `EndlessChapterGenerationProbe.tscn` passes with normal/boss max relative error under `0.17`.
6. `EndlessRuntimeIntegrationProbe.tscn` passes for Chapter 1 default procedural runtime, top-bar naming, and generated loadout application.
7. `EndlessEntryMainFlowSmoke.tscn` passes: real entry flow, Chapter 1 generated preview, opening combat, and progression into Chapter 1 Round 2.
8. A broad first-chapter natural-flow smoke should confirm every starter reaches first shop, can buy/deploy a first-shop helper, and resolves the second fight without the first generated RGA boards overpopulating or trait-spiking.
9. `NaturalRepresentativeCampaignMainFlowSmoke.tscn` passes to Chapter 6 Round 1 for representative starters `axiom`, `brute`, `cashmere`, `repo`, `sari`, and `bonko` with no shop or technical failures.

## Current balance read

Latest audit after shared trait/item coefficient pricing:

- `DifficultyCoefficientGate.tscn`: PASS, model `trait-item-coefficients-v1`, 22 trait coefficients, 36 item-effect coefficients.
- `DifficultyRatingAudit.tscn`: PASS, 51 playable units, 4 creeps, 45 items, 120 sample boards.
- `GeneratedCampaignSpecProbe.tscn`: PASS, 150 sampled generated campaign rows.
- `EndlessChapterGenerationProbe.tscn`: PASS, 6 seeds, 240 chapters, 1200 boards, 720 non-creep boards, mean absolute error `17.50`, max absolute error `95`, max relative error `0.161`.
- `EndlessRuntimeIntegrationProbe.tscn`: PASS for procedural Chapter 1 runtime mapping, generated loadouts, target-scaled creep opener rules, and exact procedural mirror copies.
- `MirrorBoardProbe.tscn`: PASS, preserving exact-copy mirror behavior for stats, items, snapshot positions, and enemy-side formation mapping.
- `NaturalRepresentativeCampaignMainFlowSmoke.tscn`: PASS, 6/6 representative starters reached Chapter 6 Round 1 through the real Main flow with no shop or technical failures.
- `CompletedItemEffectRegistrySmoke.tscn`: PASS, 36 completed items with runtime effect IDs, 36 registered handlers.
- `CompletedItemRuntimeEffectsProbe.tscn`: PASS, 36 completed items.

The important change is that creep, trait, item, and boss pressure now flow through target/stage rules. Trait and item pressure use one shared coefficient source and pull generated levels downward instead of silently stacking on top of a near-target raw unit board; creep pressure uses target-derived `stat_scale`; generated mirrors exactly copy the last boss-entry board, including items and formation. The generator emits `difficulty_model_version` so stale specs and stale audit math fail visibly.

## Next balancing work

- Calibrate the explicit trait coefficients against RGA combat telemetry instead of treating the first coefficient table as final.
- Calibrate item coefficients by role and carrier fit once enough item-bearing generated combat telemetry exists.
- Keep the natural progression smokes broad enough to fail if any starter repeatedly loses before the player has meaningful shop agency.
- Track per-stage win/loss bands by chapter:
  - Chapter 1 Round 1 should be nearly guaranteed after starter selection.
  - Chapter 1 RGA rounds should teach board reading, not punish missing hidden trait math.
  - Boss rounds can spike, but the visible target/difficulty should explain the spike.
- Keep mirror difficulty separate: mirror is player-board driven and should be judged by whether the copied board is faithful, not by generator target alone.
