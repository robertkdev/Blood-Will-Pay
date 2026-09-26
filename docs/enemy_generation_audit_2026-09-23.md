# Enemy generation audit - 2026-09-23

An independent read of the enemy team generation algorithm for defects rather than balance
preferences. Four findings, each reproduced from the code and the recorded runs. Two are
fixed here, two are recorded with a repro for the next pass.

## 1. A pinned procedural seed was discarded before the first fight (fixed)

`RosterCatalog.start_new_run()` called `_reset_procedural_runtime(true)` with `randomize_seed`
hard-coded, ignoring `_procedural_seed_locked` - even though `set_procedural_seed` sets that
lock and `clear_runtime()` already consults it. `Main._reset_run_state` calls
`start_new_run()` from `_ready`, so a caller that pinned a seed before building the scene had
it thrown away before the opening fight.

Evidence, revision-controlled at `5746feb8` with explicit seed 21009: chapter 1 stage 2
fielded `brute1` in one run and `bo1` in another. Pooled over both recorded roots, **340 of
745 (46%)** same-seed chapter/stage groups fielded a different enemy board, and seed 4401
chapter 1 stage 4 produced 31 distinct boards.

This is the defect behind "a seeded run still is not a replicate", which had been attributed
to frame-delta integration. It also invalidated every same-seed A/B the project has run for
the enemy side: the arms were not facing the same encounters.

Fix: `start_new_run()` respects the lock, the way `clear_runtime()` does. Verified - a pinned
seed now yields the identical enemy board across four consecutive run resets, while an
unpinned run still randomises. `EndlessRuntimeIntegrationProbe`, `ActiveRunResumeProbe` and
`EndlessChapterGenerationProbe` all still pass.

## 2. The recorded per-fight battle seed was never played (fixed)

`JevRunHarness._apply_battle_seed` wrote `battle_seed` into the dictionary returned by
`RosterCatalog.get_spec`, which hands back `duplicate(true)`. The mutation never reached the
cached spec, so `CombatManager` found no `battle_seed` and derived its own from the procedural
seed. Every `battle_seed` event in every transcript names a value the engine never saw.

Fix: `RosterCatalog.set_stage_battle_seed` writes into the cache, and the harness calls it and
records `applied_to_live_spec`. Verified: a seed written for chapter 1 stage 2 reads back from
the live spec.

## 3. Level tuning compared two different quantities (fixed)

`EndlessChapterGenerator._tune_levels` initialised `current` from `_score_ids_with_levels`,
which is a trait-adjusted *team* score, then scored each candidate as
`current + (unit_rating(level+1) - unit_rating(level))` - a bare *single-unit* rating with no
trait multiplier. The stopping rule and the "best" comparison therefore ran on a number that
was not the board's score.

Reproduced on a recorded board: chapter 2 stage 3, target 297, seed 21004. The generator
produced `morrak1 / egress4 / pilfer1` with a realised power of 296.48 - one unit at level 4
and two at level 1. Whole-team rescoring does not choose that shape; the final `stat_scale`
fit repairs the *budget* and cannot repair the *allocation*.

Fix: every candidate is scored by rescoring the whole team with the promotion applied.
Measured effect on the generator's own gate: mean absolute rating error falls from 69.75 to
**54.85**, maximum relative error 0.119 against the 0.17 gate.

## 4. The boss calibration probe tested a boss that never escalated (fixed)

This one invalidated evidence rather than gameplay, and it was the highest-value item left.

Bosses carry two escalation phases (`BossRule.default_escalation_config`: a health-threshold
phase that revives two units and multiplies health and offence, then a second at a lower
threshold). They are injected by `on_pre_spawn` (writes `rules.escalation`) and applied to the
engine by `on_pre_engine_config` -> `engine.configure_encounter_escalation(...)`.

`LockstepSimulator` calls only `StageRuleRunner.post_spawn` (line 427) and
`engine.configure(...)` (line 61). It never calls `pre_spawn` or `pre_engine_config`.
`EncounterEscalationRuntime.configure` disables itself when the phase list is empty, so in
every probe sample the boss does not escalate.

`BossStageCalibrationProbe` predicts with
`TeamOddsEstimator.BOSS_ESCALATION_PREVIEW_FACTOR` (1.25) - the escalating boss - and then
fights the non-escalating one. Its 108-sample gate (56.92% predicted, 58.33% observed) is
therefore two different encounters agreeing with each other by construction.

This is consistent with the live measurement that motivated the audit: recorded live boss
fights are far harder than the probe's gradient implies, and the live displayed odds miss
observed outcomes by 20 points while the probe's miss is 1.4.

Fix direction: make the simulator run the full stage-rule lifecycle for the enemy spec before
`engine.configure`, then assert a non-empty phase list and a fired-phase event in the probe,
and recalibrate. Expect boss difficulty to move once the probe measures the real fight.

### Fixed and re-measured

`LockstepSimulator` now runs the same order `CombatManager` does: `pre_spawn` -> spawn ->
`post_spawn`, then `pre_engine_config` -> `configure` -> `start` -> `on_battle_start`. The
ordering is load-bearing: `configure_encounter_escalation` stores the config while
`engine.state` is still null, and `engine.configure()` is what applies it to the runtime with
the real state. The simulator also exposes `enemy_escalation_configured_phases`,
`enemy_escalation_enabled` and `enemy_escalation_fired_phases` in its result, and the probe
asserts that every boss sample had phases configured and that at least one sample fired one.

Evidence after the fix, `BossStageCalibrationProbe`: PASS, 108 samples,
**escalation configured 108/108, fired in 84**, predicted 61.0%, observed 64.8%, gap 3.8%,
Brier 0.090.

The difficulty moved exactly where escalation should move it. Preparation tiers:

| tier | before (no escalation) | after (real escalation) |
| --- | ---: | ---: |
| underprepared | 33.3% | **16.7%** |
| prepared | 63.9% | 77.8% |
| strong | 77.8% | **100.0%** |

The underprepared tier now loses five of six, which is what two escalation phases that heal,
multiply health and offence, and return dead units should do to a board that cannot close.
The strong tier sweeping is a design signal worth its own look: a board that bursts the boss
below the first threshold still has to survive two revives.

Both gates that consume the simulator still pass: `TeamOddsTimeoutReplayProbe` (13 historical
tuples, 0 current timeouts) and `TeamOddsCalibrationProbe` (144 samples, 0.0% gap, Brier
0.103, worst bucket 12.4%). `RGATesting` passes with 0 failed rows.

Live confirmation that this is the encounter the game actually runs: a recorded fight logs
`[BOSS PHASE 1] THE HOUSE DOUBLES DOWN - 1 reinforcement(s) return`.
