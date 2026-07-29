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
- `EASIEST_REFERENCE_RATING = 100`, so Chapter 1 Round 1 starts from a fixed runway Beegle opener that preserves the old easiest creep-fight stat overrides.

Chapter target:

- `chapter_base = 100 + (chapter - 1) * 32 + floor((chapter - 1) / 5) * 55`
- Round multipliers:
  - creep: `1.00`
  - first RGA: `1.90`
  - second RGA: `2.25`
  - boss: `2.65`
  - chapter 1 boss: `2.15`
  - mirror: `2.65`
- Chapter 1 boss levels are capped at `2` so the first boss is a runway spike, not a late-run scaling check.

Generated normal/boss board difficulty now includes:

- `unit_rating`: sum of selected unit level ratings,
- `trait_pressure_rating`: active enemy trait pressure from trait thresholds,
- `difficulty_rating = unit_rating + trait_pressure_rating`.

## Trait pressure

The generator prices only active trait tiers. It uses the same trait thresholds as `TraitCompiler` by loading `data/traits/<Trait>.tres`.

Current estimate:

```text
trait_pressure = unit_rating * (0.06 + tier * 0.04)
               + active_threshold * 4
               + trait_count * 2
```

This is intentionally conservative. It catches the main problem where a board with apparently fair raw unit rating becomes unfair because it also activates Chronomancer, Bulwark, Mentor, Exile, or another threshold trait.

## Items

Generated procedural boards do not currently assign enemy items, so item pressure is audit-visible but not part of generated board difficulty yet.

The audit estimates item pressure from `ItemDef.stat_mods` plus a flat runtime-effect premium:

- flat durability stats: HP, armor, MR,
- offensive stats: AD%, AS%, crit, spell power,
- timing stats: start mana and mana regen,
- defensive multipliers: damage reduction, tenacity, lifesteal,
- runtime effects: `+18` rating per effect id until effect-specific coefficients are calibrated.

When generated enemies start receiving items, the generator should add `item_pressure_rating` to `difficulty_rating` and should expose `item_rating` in each StageSpec the same way it now exposes `unit_rating` and `trait_pressure_rating`.

## Balance gates

Use these as acceptance gates before tuning by feel:

1. `DifficultyRatingAudit.tscn` passes and writes a report.
2. `EndlessChapterGenerationProbe.tscn` passes with normal/boss max relative error under `0.17`.
3. `EndlessRuntimeIntegrationProbe.tscn` passes for Chapter 1 default procedural runtime and top-bar naming.
4. `EndlessEntryMainFlowSmoke.tscn` passes: real entry flow, Chapter 1 Round 1 generated at `100/100`, win into Chapter 1 Round 2.
5. A broad first-chapter natural-flow smoke should confirm every starter reaches first shop, can buy/deploy a first-shop helper, and resolves the second fight without the first generated RGA boards overpopulating or trait-spiking.
6. Once enemy items are enabled, add item-pressure assertions to `DifficultyRatingAudit.tscn` and rerun the Main-flow smoke with at least one item-bearing generated board.

## Current balance read

Latest audit after trait-aware scoring and the Chapter 1 runway patch:

- Chapter 1 Round 1 sample: fixed Beegle runway opener, target `100`, difficulty `100`.
- Chapter 1 Round 2 sample: starter-safe RGA director runway spec, with `target_rating` set to its measured `difficulty_rating`.
- Chapter 1 Round 3 sample: starter-safe RGA director runway spec, with `target_rating` set to its measured `difficulty_rating`.
- Chapter 1 boss sample: target `215` with authored level cap `2`; refresh `DifficultyRatingAudit.tscn` after the UI pass for exact post-cap sample rows.

The important change is that trait pressure now pulls generated levels downward instead of silently stacking on top of a near-target raw unit board. The Chapter 1 runway also keeps the first two RGA rounds authored around starter readability before the budgeted generator takes over.

## Next balancing work

- Calibrate trait coefficients against RGA combat telemetry instead of treating the current formula as final.
- Add role-specific item coefficients once generated enemies can receive items.
- Keep the first-chapter natural progression smoke broad enough to fail if any starter repeatedly loses before the player has meaningful shop agency.
- Track per-stage win/loss bands by chapter:
  - Chapter 1 Round 1 should be nearly guaranteed after starter selection.
  - Chapter 1 RGA rounds should teach board reading, not punish missing hidden trait math.
  - Boss rounds can spike, but the visible target/difficulty should explain the spike.
- Keep mirror difficulty separate: mirror is player-board driven and should be judged by whether the copied board is faithful, not by generator target alone.
