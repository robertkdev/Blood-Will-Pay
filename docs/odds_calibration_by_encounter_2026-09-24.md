# The quoted odds were honest about mirrors and lying about waves - 2026-09-24

The objective asks that the odds be accurate enough for the wager to map to them, and the rig's
own summary kept flagging it. Pooling every recorded run:

```
2,381 fights, 123 runs   predicted mean 0.5714   actual 0.7203   gap +0.149
```

A single global correction is the wrong answer, though. Joining each `fight_start` to its
`combat_diagnostic` by `fight_index` - 4,494 fights, the quoted odds the rig actually acted on
against the engine's verdict - splits it apart:

| kind | n | quoted | actual | gap | log-odds residual |
| --- | ---: | ---: | ---: | ---: | ---: |
| NORMAL | 1,775 | 0.589 | 0.856 | **+0.268** | **+1.427** |
| BOSS | 1,128 | 0.409 | 0.563 | +0.154 | +0.620 |
| MIRROR | 1,035 | 0.544 | 0.538 | **-0.006** | -0.024 |
| CREEPS | 556 | 0.985 | 1.000 | +0.015 | ~0 |

The rating ratio is a fair predictor of a mirror - both sides are the same board - and of a
creep wave. It is badly optimistic about a normal wave and mildly optimistic about a boss,
because a generated board's rating does not convert into the field strength its rating claims.

That also explains why the existing probes disagreed: `TeamOddsRepresentativeProbe` pits two
*random* teams against each other, a symmetric population that cannot show this bias at all.
It is a real simulation and it stayed calibrated while live play did not.

## The fix

`TeamOddsEstimator.ENCOUNTER_ODDS_BIAS` carries the measured residual per kind and
`quote_win_percent()` applies it to the quoted odds. `CombatController` settles the encounter
kind before it quotes, which it already did for the payout table.

Mirror and creep waves are left alone - they were already honest. Applying the table to the same
4,494 fights:

| kind | n | before | after | actual | gap before | gap after |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| NORMAL | 1,775 | 0.589 | 0.827 | 0.856 | +0.268 | **+0.029** |
| BOSS | 1,128 | 0.409 | 0.535 | 0.563 | +0.154 | **+0.028** |
| MIRROR | 1,035 | 0.544 | 0.539 | 0.538 | -0.006 | -0.000 |
| CREEPS | 556 | 0.985 | 0.985 | 1.000 | +0.015 | +0.015 |
| **pooled** | **4,494** | **0.582** | **0.707** | **0.727** | **+0.145** | **+0.020** |

Only the quoted odds move. Payouts are priced by the encounter tier, and the generator fits
enemy boards to a rating target without ever reading the estimate, so difficulty is untouched.

## What it did to a five-seed batch

Same seeds as the ten-run scorecard, 8x, artifact root `gamble-battle-jev-run-20260924b`:

| seed | terminal | chapter | battles | peak bankroll | failures |
| --- | --- | ---: | ---: | ---: | ---: |
| 21356 | **target_reached** | **10** | 56 | **230,683,256,528** | 0 |
| 21359 | stage_stall | 6 | 36 | 2,645,768 | 0 |
| 21355 | stage_stall | 6 | 36 | 1,607,112 | 0 |
| 21353 | loss | 3 | 13 | 1,180 | 0 |
| 21358 | loss | 2 | 6 | 269 | 0 |

**Chapter 10 reached for the first time**, on the seed that used to abort at chapter 9, and its
round-4 boss was won before the harness stopped on its target. Five runs, **zero technical
failures**, and every run shape the objective names is present in one batch: a 230-billion run,
two early losses on three-figure banks, and two runs grinding to chapter 6.

## Caveat

The correction is fitted on the rig's own play, which is stronger than a first-time player's, so
it describes the boards this rig actually fields rather than a floor for everyone. And the
146-fight verification batch is too small to confirm the residual collapse on its own: the
quoted mean moved as the table predicts (0.582 -> 0.675) and the NORMAL residual fell
(1.427 -> 1.028), but the in-sample fit across 4,494 fights is the evidence, not that batch.
