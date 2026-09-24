# Why runs stop, and the lever the rig is not using - 2026-09-23

Chapter 10 has never been reached. Measured over the current era, the reason is not a single
wall: **18 of 34 runs (53%) end by stalling after four attempts at one stage**, and the
enemy board does not change between attempts, so a stall is four swings at a fixed opponent.

Both halves of this note come from that measurement.

## The rig is not repeating a lost board out of laziness

The rules already forbid re-entering a lost stage with the board that lost it, but the rule
lives in a prompt: 47 of 148 recorded retries did exactly that. The rig now detects it and
enforces one shopping pass, which produced the data that matters. Reading the reentries:

| re-entry | bankroll | shelf | bought | board changed |
| --- | ---: | ---: | --- | --- |
| ch3 r3, attempt 2 | 26 | 5 | sari | no |
| ch3 r3, attempt 3 | 11 | 3 | - | no |
| ch4 r5, attempt 2 | 3 | 5 | - | no |
| ch6 r4, attempt 2 | 2 | 5 | - | no |
| ch6 r4, attempt 3 | 1 | 5 | - | no |

Those repeats are at **1-26 buckets**, with the board already at its capacity. There is nothing
to buy and no free slot, so repeating the board is the only move available. The same check on
the richest run of the session found reentries at 58,000, 96,000, 102,000 and 108,000 buckets
where the rig also bought nothing - so both populations exist, but they need different fixes.

## The real mechanism: the rig bleeds its bankroll across the retries

At the **first** attempt at the stage where a run finally ends, the rig is not broke. Across
the 19 stage-stall endings in the current era:

- median bankroll going in: **778 buckets**
- median wager: 4 - a **10%** stake
- runs that went in with fewer than 10 buckets: **0 of 19**
- runs that wagered at least half their bankroll: **0 of 19**

So the run arrives at its fatal stage with money, bets small, loses, and then spends the
bankroll down over four attempts - to 1, 2, 3, 11, 26 buckets in the case above - and stalls
with nothing left. The bankroll was never the constraint; converting it into a board that can
win the stage is.

## The lever the rig is not using: levelling the shop

The design document's shop odds make the shop level the gate on unit cost. At level 3 the
shelf is 65 / 30 / 5 / 0 / 0 - **cost 4 is impossible** - and at level 7 it is
20 / 28 / 30 / 17 / 5. The generator picks enemy units by rating from the whole catalogue, so
from chapter 2 onward the enemy can field cost-4 and cost-5 units while a level-3 player
cannot.

Measured across 30 current-era runs:

| | value |
| --- | ---: |
| buy-XP clicks per run | median **1**, mean 0.9, max 3 |
| runs that never bought XP | **13 of 30** |
| best unit level reached | median 3 |

The deepest runs are the same: chapter 8 with 3 XP purchases, chapter 6 with 1, chapter 6 with
2 - and one run reached chapter 7 with **zero** XP purchases. Meanwhile the state dumps show
the rig at level 3 in chapter 6 holding 93,000 buckets, and the runs that stall sit on
hundreds of thousands.

The policy already argues for this - *"Once capacity is capped by the chapter floor the reason
to level is the shelf: the level sets the cost distribution"* - and the user asked for it
directly: *"spending buckets on leveling up should be helpful because it increases your odds
of getting better units."* The rig is not acting on it, which is a strategy gap rather than an
economy one.

## Next

Put the decisive fact in front of the level decision: the enemy's cost tier, and whether the
current shop level can roll it at all. "The board facing you fields a cost-4 unit and your
shelf has a 0% chance of offering one" is a reason to spend 4 stakes that the current
candidate payload does not state, and the rig is carrying the money for it.
