# The displayed win odds are wrong, and they are wrong downward - 2026-09-23

The wager panel shows a win percentage before the fight, and both the human player and
the Jev rig read it. Measured against what actually happened, that number is
systematically pessimistic: over 1,134 recorded first attempts the shown odds averaged
0.584 and the player won 0.780.

## The gap, by odds bucket

First attempts only, every recorded run:

| shown odds | n | shown | observed | gap |
| --- | ---: | ---: | ---: | ---: |
| 0.2-0.3 | 57 | 0.260 | 0.491 | -0.231 |
| 0.3-0.4 | 141 | 0.352 | 0.532 | -0.180 |
| 0.4-0.5 | 292 | 0.452 | 0.671 | -0.219 |
| 0.5-0.6 | 246 | 0.533 | 0.780 | -0.248 |
| 0.6-0.7 | 75 | 0.644 | 0.973 | -0.329 |
| 0.7-0.8 | 75 | 0.740 | 1.000 | -0.260 |
| 0.8-0.9 | 85 | 0.858 | 1.000 | -0.142 |
| 0.9-1.0 | 161 | 0.979 | 1.000 | -0.021 |

Overall: mean shown 0.584, mean observed 0.780, gap -0.197, Brier 0.185. Only the top
bucket is honest. Every other bucket understates the player's chance by 14 to 33 points,
and the understatement is worst exactly in the 0.4-0.8 band a wager decision is made in.

`live_win_odds` tracks `shown_win_odds` to three decimals, so this is not display
staleness - the number the panel shows is the number the rig prices against.

## What it does to the rig

The rig sizes its wager from the shown rate (Kelly against the locked quote). A rate that
understates the true chance by twenty points produces a fraction of the wager the same
rate would justify, which is the recorded behaviour the design review kept reporting:
buckets left unspent, a bankroll that compounds far more slowly than the ladder allows,
and long losing streaks that the rig never presses through because it never believes it
is ahead.

The wager cannot map to the predictor while the predictor is wrong, and the predictor is
wrong in the direction that makes the rig cautious.

## Where the error lives

Split by encounter kind, first attempts:

| kind | n | shown | observed | gap |
| --- | ---: | ---: | ---: | ---: |
| NORMAL | 529 | 0.580 | 0.885 | **-0.305** |
| BOSS | 244 | 0.384 | 0.582 | -0.198 |

Normal stages are the worst-calibrated fights in the game: the label says a coin flip and
the player wins nearly nine times in ten.

## Why, as far as the recorded evidence goes

Two measured mechanisms are already in the record and both point the same way.

1. **The label is a closed-form power ratio; the fight is not.** `TeamOddsEstimator`
   converts team power through one bounded curve. The fight itself is a simulation whose
   result is decided by the clock in 53% of post-chapter-one first attempts, and 98% of
   those clocked fights end with both boards still standing. A power ratio cannot describe
   a race that is settled by survivor count.
2. **The two are calibrated on different populations.** The checked-in calibration probes
   pass with a small gap, but they fight synthetic uniform-level boards in an open field
   with no items. Live boards carry items, mixed levels, traits, and placement, and the
   recorded live gap is five to ten times the probe's.

## What this implies for the next change

The honest repair is to price the displayed odds off live outcomes rather than off a
power ratio, or to make the fight resolve by combat so that a power ratio describes it.
Both are larger changes than a label tweak, and the second is the same defect the
`overtime.gd` note already recorded: boards that cannot finish each other make the clock
the decider, and the clock is not the quantity the label models.

Until that is fixed, the wager screen is telling the player they are less likely to win
than they are, and the rig is acting on it.

## Reproducing

Read `fights` out of every `findings.json` under the recorded run root, keep
`stage_attempt == 1`, and compare `shown_win_odds` against `won`.
