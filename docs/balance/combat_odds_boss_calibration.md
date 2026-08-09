# Combat Odds and Boss Calibration

## Decision record

This pass began from reviewed revision `2963d27` and was finalized in the
combined playtest branch after integrating the current player-facing visual
baseline. The live private design document `Blood Will Pay` was checked during
the audit; it describes dynamic odds as a current gap, so the implementation
below is the requested product correction rather than an attempt to copy an
unfinished document rule.

## Root causes

The old `TeamOddsEstimator` applied cost and level multipliers to units after
`UnitFactory` had already materialized those level-scaled combat stats. That
double-counted progression in the player-facing label. The endless generator
used a separate cost-plus-level heuristic, fixed boss sizing, and no runtime
stat-scale parity, so its `difficulty_rating` was not the same quantity that
the combat simulator fought.

The movement and collision audit did not find a causal rule change in this
workstream. `MovementService2` and `CollisionResolver` still use the shared
unit-radius tuning. The observed unit-visual sizing changes were cleanup/cache
handling, not a second combat-size model, so neither file was changed.

## Coupled model

`CombatPowerModel` is now the single source for odds, generated-board scoring,
and calibration metadata (`combat-power-v1`). It scores the actual spawned
combat stats: effective health after mitigation, attack output, critical
pressure, spell/true damage, sustain, defense, mana and range, then applies
trait pressure and converts the power ratio through one bounded odds curve.

The generator now selects a target-aware board size and roster, tunes levels,
and solves a bounded runtime `stat_scale` against the same model. The
`StageRuleRunner` applies that scale to the same combat fields before a real
fight. Lockstep calibration also applies stage rules, preventing a simulator
that fights unscaled units from certifying scaled boards.

Bosses retain a minimum four-unit board because the fresh calibration showed
that three-unit bosses were not hard for prepared 4/6-unit teams even when the
displayed odds were high. Higher targets add units within the normal board
capacity; this is a composition rule derived from the calibration rows, not a
boss-only odds exception.

Boss previews account for the live escalation phases through the shared
`TeamOddsEstimator.BOSS_ESCALATION_PREVIEW_FACTOR` (`1.25`). The first
procedural boss keeps a raw generator multiplier of `1.00` so the quoted odds
are not double-counted; later bosses use the authored `2.65` target. The
runtime, generator, lockstep simulator, and player-facing label all use this
same stage-aware contract.

## Fresh calibration evidence

The probe summaries are written to `user://team_odds_calibration.json` and
`user://boss_stage_calibration.json` during MCP runs. The checked-in probes
also retain per-row player/enemy power, stage specs, model version, predicted
odds, result, timeout and seed data.

Player-facing odds are presented as a range rather than a point promise.
`TeamOddsEstimator.CALIBRATION_ERROR_POINTS` adds a conservative `+/- 15`
percentage-point band around the model midpoint; the fresh 144-combat
calibration's largest populated-bucket miss was 12.4 points. The wager panel
continues to show exact reserves after a win or loss and explains that its
contractual payout is quoted from the midpoint. This keeps the economic terms
precise while making model uncertainty visible before blood is risked.

### Normal stages

The clean-base diagnostic had 144 rows, no timeouts, overall prediction 50.0%
versus 50.7% observed, and Brier score 0.136. Its worst populated odds bucket
gap was 17.7 percentage points. Final combined-build calibration uses a 1.55
power-ratio exponent and produced 50.0% predicted versus 52.08% observed,
Brier 0.1069, zero timeouts, and populated-bucket gaps between 7.6 and 12.4
percentage points. The threshold stayed at 15 points; it was not weakened to
make the model pass.

### Boss stages

The historical 36-row diagnostic produced only 6 wins (16.7%), with predicted
13.1% and Brier 0.155. The fresh boss-aware stratified dataset has 108 rows
across four chapters, three seeds, and low/mid/high preparation teams. It
produced 63 wins (58.33%), predicted 56.92%, Brier 0.12868, a 1.42-point
overall gap, and zero simulation timeouts. Preparation win rates were
33.33% / 63.89% / 77.78%; the tiers remain ordered and no tier is impossible.
This is the skill-plus-luck balance proof: better preparation raises the chance
of winning by 44.45 percentage points, while the low tier still wins sometimes
and the high tier still loses sometimes. Boss balance therefore does not depend
on forcing a campaign to an arbitrary late stage; the calibrated prediction,
ordered preparation gradient, and non-deterministic outcomes are the acceptance
gate.

The boss probe gates overall calibration, each preparation slice, and
hard-but-beatable bounds. The normal probe owns the broad odds-bucket gate;
the boss rows remain visible diagnostics rather than a misleading independent
bucket claim.

### Generator calibration

The old heuristic's first comparable run reached 226.23 mean absolute rating
error and 2.130 maximum relative error. The final deterministic generation
probe covers 6 seeds, 240 chapter records and 1,200 boards (720 non-creep
boards): mean absolute error 69.68, maximum absolute error 460, maximum
relative error 0.120, maximum board size 9, maximum level 15. Every generated
boss satisfies the four-unit minimum and carries the combat model version.

## Runtime validation

Validated through Godot MCP on Godot 4.5:

- `TeamOddsCalibrationProbe.tscn`: PASS, 144 rows, 0 timeouts.
- `BossStageCalibrationProbe.tscn`: PASS, 108 rows, 0 simulation timeouts;
  56.92% predicted versus 58.33% observed, Brier 0.12868.
- `EndlessChapterGenerationProbe.tscn`: PASS, 1,200 boards.
- `EndlessRuntimeIntegrationProbe.tscn`: PASS; generated chapter 1 stage 1
  advanced through the real `StageRuleRunner` path.
- `RoleMatrixProbe6v6.tscn`: PASS, 0 failed / 0 skipped / 0 errors.
- `RGATesting.tscn`: PASS, 48 rows, 0 failed / 0 skipped / 0 errors.
- `ActualRunLoopSmoke.tscn`: PASS across five full opening/reset cycles and a
  shop cycle on the combined build.
- Player-facing `Main.tscn`: title -> run start -> unit selection -> Bonko
  selection -> CombatView was exercised. The live node reported `Win Odds
  53%` and `Board 1/3`; a 1280x720 MCP capture showed the active arena and
  Team Metrics panel with no runtime error log entries.

The natural Bonko campaign is still retained as a deliberately honest baseline
and can lose at the first boss when it spends its runway. A separate competent
policy run through the same Main.tscn entrypoint reached stage 10, observed
bosses at stages 4 and 9, and resolved the second boss. That is optional
longitudinal/stress evidence, not the balance gate and not a claim that every
starter or policy is equally prepared.

## Regression entrypoints

Run the targeted scenes with Godot MCP from the project root. The normal and
boss probes are deterministic and fail on calibration drift, timeouts, missing
model metadata, impossible bosses, or generated-board error bounds. The
runtime integration probe verifies the display changes when real level rules
are applied, rather than mutating a unit's level field without applying its
combat stats.
