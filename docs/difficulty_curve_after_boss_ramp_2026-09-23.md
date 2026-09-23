# The difficulty curve after raising the late boss budget - 2026-09-23

The curve was inverted: measured over the current era, first-attempt win rate rose with the
chapter (71.4% in chapter 1 up to 94.4% in chapter 6), so the game got **easier** as it went.
Two changes went in: the boss multiplier stops plateauing and keeps climbing past the old
2.65 (1.00 / 1.80 / 2.20 / 2.55 / 2.95 / 3.35 then +0.40 per chapter), and the opening boss
fields three bodies instead of four because it was a capacity check - a player with three
bodies won 43.8% of 16 first attempts at it and one with four won 87.5% of 8.

## What the change did to the curve

Twenty runs, fresh and grown, a fresh seed block. All first attempts by chapter:

| chapter | before | after |
| --- | ---: | ---: |
| 1 | 84.4% (n=141) | 83.8% (n=80) |
| 2 | 78.7% (n=141) | 83.1% (n=83) |
| 3 | 82.1% (n=84) | 77.6% (n=58) |
| 4 | 84.6% (n=39) | 79.3% (n=29) |
| 5 | 90.0% (n=30) | 84.2% (n=19) |
| 6 | 94.4% (n=18) | 92.3% (n=13) |
| 7 | - | 87.5% (n=8) |

Boss fights only, after the change: 65.0% (n=20) / 66.7% (n=15) / 58.3% (n=12) / 83.3%
(n=6) / 50.0% (n=4) for chapters 1-5.

## Read this honestly

**The change did not produce a descending curve, and the reason matters more than the
result.** Chapter 5's win rate fell 5.8 points and chapter 6's 2.1 points for a target raise
of 11% and 26% respectively. That is the third time this review has measured a near-flat
response to re-pricing a stage, and it is now the strongest evidence in the record that
**the target rating is not the lever.**

The reason is the rating model. The generator fits the enemy to `CombatPowerModel`, and that
model under-reads what a player actually accumulates: at chapter 5 the recorded board
measures 556 power against a 673 target, i.e. the player is *below* target on paper, and
wins 84%. The same under-read is why the displayed odds are 20 points pessimistic
(`jev_prediction_calibration_2026-09-23.md`). One mis-scaled model produces both symptoms:
the enemy is fitted to a number the player beats by more than the number says, and the panel
tells the player they are less likely to win than they are.

Raising the target is therefore mostly absorbed: the generator re-fits the same
under-weighted board to a larger number and the fight hardly changes.

The one change that did move the shape is the side effect of the higher targets: because
board width is chosen from the target, late bosses now widen from a pinned four bodies to six
at chapter 6 and seven at chapter 7, which is closer to the nine the player fields. The boss
gates that moved most (chapter 5, chapter 6) are the ones where the board widened, not the
ones where the rating rose most.

## Where the curve stands against the requirements

| requirement | state |
| --- | --- |
| not harder early than late | **met at the top of the curve, not at the bottom.** Chapter 1 is no longer the hardest boss (65.0%); chapters 5-6 are still the easiest |
| harder as it goes on | not met; the curve is flat to mildly inverted |
| stage 10 easy to hit | chapter 2 round 5 reached by most runs |
| chapter 10 a good run | **not reached.** Chapter 8 is the deepest ever recorded, by the grown arm |

## Criteria in the same twenty runs

| criterion | result |
| --- | --- |
| three-star at least one unit | 12 of 20 (best unit level 4) |
| max out at least one trait | 20 of 20 |
| fully build out a board | 18 of 20 |
| complete 8 items | **reached** - 8 completed items in one run, though not by chapter 10 |
| reach chapter 10 | 0 of 20 |

## Next

Fix the power model instead of the target. Items, unit levels and slots are what the board
accumulates between chapters, and the model's weighting of them is what has to change. That
single correction is the lever for three separate requirements: a target that orders
difficulty, a displayed win rate that matches outcomes, and a wager that can be priced off
the predictor.

The evidence for the size of the error is already measured: `TeamOddsCalibrationProbe`
passes on synthetic item-less uniform boards with a 0.0% gap, while the recorded live boards
miss by 20 points. The probe and the live record do not disagree about the model's
arithmetic; they disagree about what the model is looking at.
