# The boss board now grows with the chapter - 2026-09-23

The boss board's width was chosen from its rating, which pinned every boss from chapter 2
through chapter 5 at exactly four bodies while the player's board grew from four slots
towards seven. That is the range where runs end. The width now follows the chapter instead,
and the rating multiplier stays the difficulty knob. This is a small, measured change; the
larger finding underneath it is that the gate which judges boss difficulty cannot currently
see the game, and that is recorded at the bottom.

## What changed

`EndlessChapterGenerator._desired_size_for_target` now takes the chapter and reads
`BOSS_WIDTH_BY_CHAPTER`. The rating-only ladder is kept for callers that have no chapter,
so the old and new shapes can be measured against each other with one call-site swap.

`EncounterShapeComparisonProbe` gained a `BossShape` report, because the shape ladder had no
instrument: `EndlessChapterGenerationProbe` covers rating error but never quits its tree, so
its stdout is lost before the runner sees it. The report prints width, target, fitted rating
and relative error for chapters 1-10.

## Measured shape, both ladders, one seed

Same generator, same seed `730711`, same target curve; only the width source differs.

| chapter | target | width before | width after | rating error |
| --- | ---: | ---: | ---: | ---: |
| 1 | 100 | 3 | 3 | 0.070 |
| 2 | 238 | 4 | 4 | 0.055 |
| 3 | 361 | 4 | **5** | 0.003 |
| 4 | 500 | 4 | **5** | 0.002 |
| 5 | 673 | 4 | **6** | 0.001 |
| 6 | 1055 | 6 | 6 | 0.006 |
| 7 | 1301 | 7 | 7 | 0.012 |
| 8 | 1573 | 8 | **7** | 0.012 |
| 9 | 1870 | 9 | **8** | 0.001 |
| 10 | 2193 | 9 | 9 | 0.089 |

The old ladder is `3 / 4 / 4 / 4 / 4 / 6 / 7 / 8 / 9 / 9`: no width change at all across the
four chapters that hold most recorded runs, then a jump from four to six. The new ladder is
`3 / 4 / 5 / 5 / 6 / 6 / 7 / 7 / 8 / 9`. Chapters 8 and 9 get one body narrower, because the
rating formula had pushed the boss past the widest board the player realistically reaches
(seven slots at shop level 4, nine only at level 6).

Worst relative rating error is **0.089 against the 0.17 gate, before and after** - widening
does not disturb the fit, which was the risk. `_stat_scale_for_target` can scale both up and
down, so a wider board at the same target is a shape change rather than a budget change.

## Effect on the boss calibration gate

`BossStageCalibrationProbe`, 108 samples over chapters 1-4, before -> after:

| measure | before | after |
| --- | ---: | ---: |
| predicted / observed | 0.607 / 0.648 | 0.604 / 0.630 |
| overall gap | 0.041 | 0.025 |
| Brier | 0.092 | 0.099 |
| timeouts | 0 | 0 |
| escalation configured / fired | 108 / 84 | 108 / 81 |
| underprepared tier win rate | 0.167 | 0.167 |
| prepared tier win rate | 0.778 | **0.722** |
| strong tier win rate | 1.000 | 1.000 |

Every assertion still passes. The only movement is the middle tier, which lost 5.6 points of
win rate over 36 fights - the width increase landing where a real board sits.

## The finding that matters more: the gate's strongest tier is not a real board

The strong tier did not move because it cannot. The probe builds its tiers as
`desired_size = 2 + tier * 2` at `level = tier + 1`, so tier 3 is six level-3 bodies, and it
does not calibrate that board against anything a run fields. Measured, per chapter and tier,
against the boss the generator produced:

| chapter | tier | player power | boss power | ratio | win rate |
| --- | ---: | ---: | ---: | ---: | ---: |
| 1 | 1 / 2 / 3 | 243 / 494 / 1543 | 98 | 2.5 / 5.1 / 15.8 | 0.33 / 1.00 / 1.00 |
| 2 | 1 / 2 / 3 | 133 / 626 / 1549 | 252 | 0.5 / 2.5 / 6.2 | 0.00 / 0.78 / 1.00 |
| 3 | 1 / 2 / 3 | 265 / 338 / 2253 | 363 | 0.7 / 0.9 / 6.2 | 0.33 / 0.33 / 1.00 |
| 4 | 1 / 2 / 3 | 125 / 706 / 1484 | 510 | 0.3 / 1.4 / 2.9 | 0.00 / 0.78 / 1.00 |

The board a recorded run actually fields at the boss stage rates **102 / 249 / 339 / 430 /
557** over chapters 1-5 (the measurement behind `BOSS_MULTIPLIER_RAMP`). So the probe's
"strong" tier is 3.5x to 15.8x the real board, and its "prepared" tier is also over the top at
chapters 2 and 4. Two consequences:

- The gate's `strong tier >= 0.55` assertion cannot fail, and its `prepared tier >= 0.30`
  assertion is close to vacuous. A gate that cannot fail is not evidence, and no boss-side
  change should be accepted or rejected on those rows.
- This is the same defect class the odds review already recorded from the other side:
  `TeamOddsCalibrationProbe` passed at a 0.0% gap while the live record missed by 20 points,
  because the probes fight boards that are not the boards players field.

Nothing above changes the decision to widen the boss - the design reason stands on its own,
and no gate moved - but it does mean the widening is **not** claimed to have made bosses
harder. That claim needs a probe whose tiers are anchored to the recorded band.

## Gates run

| gate | result |
| --- | --- |
| `BossStageCalibrationProbe` | all assertions pass; 108 samples, gap 0.025, escalation 108/108 configured, 81 fired, 0 timeouts |
| `TeamOddsCalibrationProbe` | PASS, 144 samples, gap 0.0, Brier 0.103, 0 timeouts |
| `TeamOddsTimeoutReplayProbe` | PASS, 0 unacceptable timeouts, 26 acceptable engine-combat-timeout resolutions, 0 no-progress timeouts, replays deterministic |
| `EncounterShapeComparisonProbe` | DIAGNOSTIC (asserts nothing by design), worst rating error 0.089 against the 0.17 gate |
| `RGATesting` | 95 rows, 0 failed |

## Next

- Anchor `BossStageCalibrationProbe`'s tiers to the recorded board bands so its difficulty
  assertions can fail. Until then, no boss change can be validated by it.
- The identified lever for the odds, the level curve and the boss target at once is still
  the rating: weight item effects and unit levels the way the fight values them, and measure
  it on an odds probe population that carries levels, items and six-to-nine bodies. That
  gate does not exist in the tree yet.
