# The displayed odds are wrong in the ratio, not in the curve - 2026-09-23

The model that prices the win-odds panel and fits every generated enemy is
`CombatPowerModel`. The previous pass measured its output as 20 points pessimistic against
live outcomes and named it as the lever behind three requirements at once. This pass tried to
fix it and established precisely where the error is, and where it is not.

**No behaviour change shipped in this pass.** Every candidate change either left the model
miscalibrated or required loosening a gate, and loosening the gate is exactly the mistake the
`overtime.gd` note warns about. The measurements below are the deliverable.

## 1. Fitted against the live record, the odds curve is far too flat

For every recorded first attempt both boards' ratings are known and so is who won, so the
curve's steepness is a one-parameter fit: win odds = r^k / (1 + r^k) in the ratio of the two
ratings. Over 3,144 first attempts, K = 3.11. The shipped constant is 1.55.

Mean absolute calibration error over ratio bands holding at least 40 fights:

| exponent | all | normal | boss | mirror |
| --- | ---: | ---: | ---: | ---: |
| 1.55 (shipped) | 0.218 | 0.313 | 0.143 | 0.131 |
| 2.50 | 0.201 | 0.286 | 0.147 | 0.112 |
| 3.00 | 0.196 | 0.278 | 0.148 | 0.102 |

Normal and mirror improve steeply; boss is flat. A steeper curve is a real improvement on the
boards players actually field.

## 2. The checked-in calibration probe cannot arbitrate, and that is now proven

`TeamOddsCalibrationProbe` passes at a 0.0% gap, and rejects every steeper exponent. The
reason is its population: it fights uniform level-1 boards with no items on an open field,
which is the one population the model is comfortable with and precisely the model's blind
spot.

That was tested rather than asserted. The probe's teams were changed to carry what real boards
carry - levels 1-3, up to two items per unit, up to six bodies - with the levels and items
passed to the simulation so the fight and the prediction describe the same boards. Result at
the shipped exponent 1.55:

| exponent | Brier | buckets over the 15% gate |
| --- | ---: | --- |
| 1.55 | 0.068 | 25-39 over-predicted by 27.2, 51-60 under-predicted by 34.8 |
| 2.50 | 0.053 | 25-39 by 20.8, 51-60 by 30.6, 61-75 by 17.7 |
| 3.00 | 0.049 | 51-60 by 28.0, 61-75 by 16.2 |

Two things follow. Brier improves monotonically with the exponent on a representative
population, which confirms the curve is too flat. But **no exponent satisfies the gate**,
because the residual error runs in both directions at once: one band is over-predicted while
another is under-predicted. A single steepness parameter cannot fix a curve that is wrong in
two directions, so the defect is in the **ratio** the curve is drawn through, not in the curve.

## 3. What that means for the rating

The ratio is the player's rating over the enemy's, and the model under-reads what the player
accumulates. The recorded boards show it directly: at a model ratio of 0.8-1.0, a board with
more than one item won 71% of 220 fights against 47% of 30 for one with fewer, and a board
above five summed unit levels won 72% of 232 against 28% of 18. Those are 25- and 44-point
lifts the model does not see, which is why the same ratio maps to such different outcomes and
why re-pricing a stage is nearly inert.

So the next change is to the rating, not the exponent: weight item effects and unit levels
the way the fight values them. The enriched probe population above is the gate that will
measure it, and it is the population a player-facing odds number has to be right about.

## 4. A side finding the probes all inherit

While building the measurement, an exact mirror - identical boards on both sides - resolved to
the player 30 times out of 30, across every arm and every enemy stat scale tried up to 2x. A
perfectly even fight should not be a certainty, and every probe in this directory fights
boards through the same deterministic simulator. Live mirror stages are won about 77% of the
time, so the live game does not behave this way. This needs its own investigation before the
probe gates are treated as clean evidence.
