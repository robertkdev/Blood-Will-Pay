# Procedural Chapters Plan

## Current baseline

The campaign now starts with procedural generation. Chapter 1 and every later chapter keep the accepted 5-stage cadence:

1. Creep reward round
2. Normal RGA challenge/puzzle
3. Normal RGA challenge/puzzle
4. Boss
5. Mirror fight against the board the player took into the boss fight

Player-facing naming stays on the original chapter pattern: `Chapter 1`, `Chapter 2`, and so on. The top bar and logs should not switch to an endless-mode label.

The player-facing default board is now three slots. The combat HUD shows `Board x/3` on a fresh run and increases the denominator as player level adds board slots. The same HUD also exposes a lightweight `Win Odds NN%` preview derived from visible player/enemy board ratings so players can reason about whether their current RGA answer is likely to work.

## Fast board assembly theory

Use a deterministic budgeted-board generator per run seed:

- `target_rating_for(chapter, stage)` assigns a numeric difficulty budget.
- Chapter 1 Round 1 uses the same generated creep stage rule as later chapters, anchored by `EASIEST_REFERENCE_RATING`.
- Chapter 1 Rounds 2 and 3 use the same budgeted-board generator as later normal RGA rounds, with conservative early target ratings instead of authored one-off stages.
- Creep, normal, boss, and mirror stages each keep their current stage shape; creep rounds use at least two lowercase creep reward enemies for multiple per-kill component chances.
- Normal boards and featured boss picks select a theme such as dive, siege, control, attrition, burst, or wide-value.
- The normal-board assembler first guarantees a frontline unit and a damage unit, then fills utility/theme slots; boss rounds use one featured enemy with capped stat scaling.
- Unit difficulty is scored from live unit cost plus generated level. Creeps use the easiest-reference rating scale.
- Active enemy trait tiers are priced into generated normal/boss `difficulty_rating` through `trait_pressure_rating` using `DifficultyRatingModel`.
- Generated enemy completed-item loadouts are assigned on normal/boss boards after item thresholds are crossed, and their estimated pressure is included in `difficulty_rating` through `item_pressure_rating` using the same shared model.
- The generator increments levels against the remaining budget after trait and item pressure so the full board lands near the target rating.
- Recent board signatures are remembered during sequence generation to avoid repeated boards in a short window.
- The result is still a normal `StageSpec`: `ids`, `kind`, and `rules`, with `levels`, `procedural`, `difficulty_model_version`, `target_rating`, `difficulty_rating`, `unit_rating`, `trait_pressure_rating`, `item_pressure_rating`, optional `items`, `item_loadout_summary`, `theme`, and normal-stage `rga_challenge` metadata.
- Early teaching fights stay procedural; audits should separate them by chapter/stage target rating instead of by authored one-off specs.
- Use `tests/rga_testing/validation/DifficultyRatingAudit.tscn` to inspect per-unit, per-creep, item, active-trait, and generated-board rating breakdowns.

This sits behind `RosterCatalog.get_spec()` starting at Chapter 1. `RosterCatalog` owns the runtime seed and generated StageSpec cache, so preview and combat agree.

Top-bar previews use that same `RosterCatalog.get_spec()` path. Hovering the chapter label summarizes the chapter's stages, and hovering a stage icon previews the stage kind, enemy board, RGA label, planning prompt, and rating metadata where available. These hovers render as the same gothic custom tooltip panels used by the other dense UI surfaces instead of native Godot tooltips.

## Difficulty ramp

Current formula:

- Procedural Chapter 1 is game Chapter 1.
- Chapter 1 Round 1 uses the generated creep target derived from the creep stage multiplier, with raw creep stats scaled down when needed.
- Chapter 1 Round 2 and Round 3 use conservative budgeted normal targets because their purpose is starter readability, not hidden punishment.
- The chapter base adds `18` per chapter and adds a `35` step every 5 chapters.
- Stage multipliers:
  - creep: `0.35`
  - first normal: `0.70`
  - second normal: `0.80`
  - boss: `0.85`
  - mirror: player-board driven, but tagged with the mirror target for logging

That gives the generator a smooth ramp without needing infinite authored pools. Deep scaling comes from generated levels, board size, active trait pressure, generated completed-item loadouts after the item-pressure thresholds are crossed, and capped boss stat scaling. When a one-unit boss hits the cap before reaching the requested curve budget, the StageSpec reports an effective playable `target_rating` and preserves the original budget in `requested_target_rating`.

## Simulation contract

The probe at `tests/rga_testing/validation/EndlessChapterGenerationProbe.tscn` stress-runs generated chapters and fails if:

- a chapter does not have exactly 5 stages,
- a stage kind breaks the accepted creep / normal / normal / boss / mirror pattern,
- generated unit IDs cannot spawn,
- normal stages lack RGA challenge metadata,
- boss boards are not exactly one featured unit or exceed their recorded stat-scale cap,
- item-bearing generated boards lack `rules.items` or positive `item_pressure_rating`,
- generated difficulty does not equal `unit_rating + trait_pressure_rating + item_pressure_rating`,
- recent board signatures repeat inside the short repeat window,
- normal or effective boss generated rating misses target by more than 17%.

`tests/rga_testing/validation/DifficultyCoefficientGate.tscn` is the coefficient contract for that probe. It fails if trait or item effect coefficients fall out of sync with resources, generated specs use a stale `difficulty_model_version`, or generated `difficulty_rating` no longer equals recomputed unit + trait + item pressure.

Latest coefficient/generation results:

- `DifficultyCoefficientGate.tscn`: PASS, model `trait-item-coefficients-v1`, 22 trait coefficients, 36 item-effect coefficients.
- `EndlessChapterGenerationProbe.tscn`: PASS, 6 seeds, 240 chapters, 1200 boards, max relative error `0.160`.

Current results should be refreshed here after each major generator change.

## 2026-07-03 runtime integration

Runtime hook:

- `scripts/game/progression/roster_catalog.gd` now serves generated chapters through the same `get_spec(chapter, round)` path used by preview and combat.
- Generated chapters begin at `ProgressionConfig.PROCEDURAL_START_CHAPTER`, which is Chapter 1.
- `RosterCatalog` caches generated specs in chapter/round order to preserve short-window variety and keep repeated preview/combat calls stable.
- `ChapterCatalog.display_name_for()` labels generated chapters as `Chapter N` for UI/log use.
- `scripts/ui/combat/stage_progress_top_bar.gd` and `scripts/util/log_schema.gd` use the catalog display name.
- `scripts/ui/combat/controller/combat_controller.gd` now adds the visible board-capacity and win-odds row above the player board.
- `scripts/game/combat/team_odds_estimator.gd` is the shared odds helper for bounded 1-99% board previews.

Validation surfaces:

- `tests/rga_testing/validation/EndlessRuntimeIntegrationProbe.tscn` checks Chapter 1 generated specs, catalog stability, generated metadata, seed variation, spawner/rule compatibility, top-bar wiring, and mirror snapshot compatibility.
- `tests/rga_testing/validation/EndlessRuntimeIntegrationProbe.tscn` also checks that a fresh run starts at board cap 3, leveling adds a board slot, and stronger unit levels improve estimated odds.
- `tests/rga_testing/validation/TeamOddsCalibrationProbe.tscn` runs seeded random team matchups through the real lockstep combat simulator and compares displayed odds against observed wins by bucket. Latest pass: `144` combats, predicted mean `50.0%`, observed `48.6%`, overall gap `1.4%`, no timeouts.
- `tests/visual/EndlessEntryMainFlowSmoke.tscn` is a Main-flow smoke that selects a starter through the real entrypoint, validates the Chapter 1 procedural preview UI/enemies, checks the `Board x/3` and `Win Odds` labels, starts the opening combat, and expects progression into Chapter 1 Round 2 with generated RGA metadata.
