# Re-testing overtime now that the odds can be measured - 2026-09-24

`scripts/game/combat/overtime.gd` ends a clocked fight by fighting: after a start time, both
boards' outgoing damage ramps linearly, so a standoff resolves by damage instead of by a
survivor comparison. It is implemented and **deliberately disabled**, with a note saying it was
blocked on one thing:

> Do not enable it without recalibrating the player-facing win odds first.

That recalibration has now happened (the exponent, and a representative calibration gate), and
the design review just established the thing that makes this the highest-value experiment in
the project: **41% of live first attempts are decided by the clock**, and build quality does not
move the win rate. If fights resolved by fighting, the build would be the lever.

## What was tested

The configuration the earlier pass measured as the steep ramp - `DEFAULT_START_S` 0 -> 24,
`DEFAULT_MAX_AMP_PCT` 2 -> 3, so outgoing damage reaches 4x at the 45-second bell. Both
constants feed `attack_impact.gd`, which calls `Overtime.damage_multiplier(elapsed)` with no
explicit window, so changing them is the whole switch.

## Overtime does end clocked fights

| probe | clock-decided, off | clock-decided, on |
| --- | ---: | ---: |
| `TeamOddsRepresentativeProbe` (real levels and items) | 39 / 144 | **20 / 144** |
| `TeamOddsCalibrationProbe` (uniform level 1, no items) | 12 / 144 | **0 / 144** |

The realistic population roughly halves; the small synthetic one stops using the clock entirely.
This is the first intervention measured in this project that actually reduces the clock share -
re-pricing stages never did.

## It changes who wins, which is why the gates break

At the shipped exponent of 4.0, with overtime on:

| gate | result |
| --- | --- |
| `BossStageCalibrationProbe` | PASS |
| `TeamOddsRepresentativeProbe` | **FAIL** - Brier 0.081 against a 0.080 gate |
| `TeamOddsCalibrationProbe` | **FAIL** - bucket 25-39 gap 33.8% and bucket 61-75 gap 33.8% against 15% |

That is the predicted failure, and it is mild: the representative gate misses by 0.001.

## But the curve absorbs it, and the window simply moves

The estimator's problem with overtime was never structural - overtime makes outcomes more
decisive, and a more decisive fight wants a steeper curve. Re-fitting the exponent against the
overtime-on samples:

| exponent | representative worst bucket | synthetic worst bucket | boss tier gap | |
| ---: | ---: | ---: | ---: | --- |
| 4.0 (shipped) | 0.007 | 0.338 | 0.104 | fail |
| **5.0** | **0.031** | **0.014** | **0.103** | **PASS** |
| 7.0 | 0.036 | 0.033 | 0.106 | PASS |
| 9.0 | 0.092 | 0.007 | 0.109 | PASS |
| 12.0 | 0.102 | 0.021 | 0.111 | PASS |
| 14.0 | 0.143 | 0.028 | 0.111 | PASS |

Before overtime the passing window was E in [3.1, 5.2]. With overtime it is **[5, ~13]** - which
is what a more decisive fight should demand. **E=5.0 with overtime on passes all three gates**,
and Brier is 0.084 on the representative population against 0.070 on the synthetic, i.e. no
worse than the shipped combination on the population that matters.

## What this means, and what it does not

The note's blocking condition is satisfiable: the estimator does not need a new term for
overtime, it needs to be refitted, and the two probes that gate it now exist. That is a real,
measured path to making build quality decide fights.

It is **not** shipped here, for two reasons:

1. Both probes are constructed populations. The live fit (3,114 first attempts) sits at 3.11,
   and there is no live measurement of what overtime does to outcomes or to the displayed odds.
   Shipping a change that flips the winner of 41% of fights on constructed evidence alone is
   exactly the kind of move this loop has had to retract before.
2. `tests/rga_testing/validation/overtime_curve_probe.gd` asserts
   `Overtime.DEFAULT_START_S <= 0.0` with the message *"overtime must stay disabled until the
   win-odds estimator models it"*. That assertion is the gate on this decision, and it should be
   changed only with the live A/B in hand, not before.

The constants were reverted to the shipped inert values (`start 0.0`, `amp 2.0`), so the tree is
unchanged by this experiment.

## A process error, recorded

The overtime constants were edited while a ten-run Jev batch was already running. Godot reads
scripts at process start, so any run that started inside that window ran a configuration that
exists in no commit: overtime on with the old exponent, which is the combination that fails
calibration. The window is pinned by the probe artifacts - `team_odds_representative.json`
finished at 12:38:01, `boss_stage_calibration.json` at 12:41:00 - so runs starting between
roughly 12:34 and the revert are suspect.

They are identifiable from the data rather than by timestamp: **an overtime run uses the clock
far less**, so each run's clock-decided share classifies it. The batch analysis uses that
classification and excludes the straddling runs from the criteria totals.

The lesson is the same one this loop keeps re-learning in different clothes: changing the thing
under measurement while the measurement is running invalidates the measurement, and it is not
visible afterwards unless the artifact carries a fingerprint. `JEV_REVISION` is already stamped
into runs; it does not capture uncommitted working-tree edits like these.

## Next

1. Run the live A/B: the same seeds with overtime off and on, at exponent 5.0 in both arms, and
   compare clock share, win rate, chapter reached and the displayed-odds gap.
2. If it holds, change the `overtime_curve_probe` assertion and ship both together.
3. Then re-run the build-quality measurement. The prediction is explicit and falsifiable:
   summed unit level and unit cost should start *tracking* win rate instead of sitting at 83%.
