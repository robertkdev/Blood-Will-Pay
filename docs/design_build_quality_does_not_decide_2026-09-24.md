# Build quality is not what decides a fight - 2026-09-24

The request asked, directly: *higher cost units should make a difference, spending buckets on
leveling up should be helpful*, and *make sure you're tracking enough stuff so that we have
good balancing data (like if traits are useless which they very well might be right now)*.

Measured over the whole recorded era, the answer is that **none of them matter much**, and the
reason is the same for all three.

## Method

Every `jev` run with a surviving event stream: **125 runs, 2,351 fights, 1,803 first attempts**.
Each fight is paired from its `fight_start` event (board, per-unit levels, deployed traits,
shown odds) to its `combat_diagnostic` event (engine outcome, elapsed time). First attempts
only, so a stage that was retried does not count four times.

## 1. Two of every five fights are decided by the clock, not by the fight

**735 of 1,803 first attempts (41%)** reached the 45-second cap and were awarded by
`OutcomeLadder` rather than by one board killing the other. This is down from the 49% recorded
for stages of target 130 and up, and it is still enormous: in two fights out of five the
boards do not resolve each other and the result is a comparison of who is standing when the
timer stops.

## 2. Board quality moves the win rate by a few points at most

All chapters 3 and later, first attempts only.

| player's summed unit level | n | win rate |
| --- | ---: | ---: |
| 6-8 | 22 | 95% |
| 9-11 | 266 | 85% |
| 12+ | 504 | 83% |

| highest-cost unit on the board | n | win rate |
| --- | ---: | ---: |
| cost 1 | 358 | 84% |
| cost 2 | 345 | 83% |
| cost 3 | 89 | 85% |
| cost 4-5 | **0** | - |

| bodies on the board | n | win rate |
| --- | ---: | ---: |
| 2 | 68 | 87% |
| 3 | 179 | 82% |
| 4 | 176 | 84% |
| 5 | 156 | 83% |
| 6 | 113 | 88% |
| 7 | 698 | 81% |
| 8 | 200 | 84% |
| 9 | 207 | 81% |

Read those together: a board at summed level 12+ wins **83%**, a board at level 6-8 wins **95%**,
and a nine-body board wins no more often than a two-body one. Levelling units is not rewarded.
Buying expensive units is not rewarded - and cannot be, because **no player board in the entire
record has ever fielded a cost-4 or cost-5 unit**, which is the same asymmetry the earlier
cost-tier audit found from the other side (the enemy fields cost 4-5 in 22% of boss slots while
the player fielded 0 of 1,611).

This is the user's suspicion confirmed, not a hypothesis: **the shop's high tiers are
unreachable for the rig, and the units it can reach do not change the outcome.**

## 3. Traits are nearly flat too

Active trait count against win rate, first attempts, by chapter - remembering that the rig
almost always ends up with three:

| chapter | active traits | n | win rate |
| --- | ---: | ---: | ---: |
| 1 | 1 | 37 | 97% |
| 1 | 2 | 97 | 81% |
| 1 | 3 | 357 | 85% |
| 2 | 3 | 512 | 78% |
| 3 | 3 | 345 | 83% |
| 4 | 3 | 196 | 85% |
| 5 | 3 | 142 | 85% |
| 6 | 3 | 100 | 80% |

Per trait, within a chapter band, active against not-active on the same board:

| trait | chapter | active | not active | delta |
| --- | ---: | ---: | ---: | ---: |
| Cartel | 2 | 80% (n=492) | 46% (n=28) | **+33** |
| Harmony | 2 | 83% (n=286) | 64% (n=88) | **+20** |
| Harmony | 3 | 90% (n=166) | 72% (n=115) | **+18** |
| Cartel | 6 | 83% (n=78) | 68% (n=22) | +15 |
| Sanguine | 6 | 83% (n=36) | 70% (n=27) | +13 |
| Vindicator | 6 | 79% (n=42) | 92% (n=25) | -13 |
| Fortified | 6 | 78% (n=49) | 89% (n=18) | -11 |
| Executioner | 6 | 78% (n=69) | 89% (n=18) | -11 |

So traits are **weakly positive at best and not distinguishable from noise in most bands**.
Cartel on chapter 2 is the one large, well-sampled effect (+33 over 492 fights). Everything else
is inside a band that a chapter-3 board's 83% would swamp.

## What this means

These three results have one explanation, and it is the same one the difficulty review kept
landing on: the generator fits **every** generated board to the stage's target rating, so the
opponent is always a near-peer; a near-peer fight is close; a close fight goes to the clock;
and the clock compares survivors and then remaining health, which is a comparison of board
*shape* rather than board *quality*.

The consequence is that the player's build - levels, item investment, cost tier, traits - is
worth a few points of win rate, and the stage is worth everything. That is why re-pricing a
stage moved nothing, why the Ledger buys money instead of depth, and why the win-odds ratio
stays compressed no matter which exponent is fitted to it.

It is also a direct answer to the design goal. The game cannot be a build-driven, replayable
gamble while the build is not the thing that decides the fight.

## Confounds, stated

- All of this is observational. Chapter, chapter floor, and board shape are entangled: a
  two-body board is a chapter-1 board, so "board size does not matter" is partly "chapter
  matters more than board size".
- The per-trait rows compare a trait being active against the same trait being *present but
  below threshold* on the same board, which is a reasonable control but not a randomised one.
- The `cost 4-5` row is empty because the shop never offers it, not because it was tested.

## Next

1. **Make fights resolve.** `scripts/game/combat/overtime.gd` already implements a bounded,
   symmetric damage ramp that ends clocked fights by fighting, and it is explicitly disabled:
   *"Do not enable it without recalibrating the player-facing win odds first."* The odds have
   now been recalibrated and, more importantly, there is now a gate that can measure the
   consequence (`TeamOddsRepresentativeProbe`, plus `TeamOddsCalibrationProbe` and
   `BossStageCalibrationProbe`). Re-testing overtime against those three gates is the highest
   value experiment available: if it holds, build quality becomes the lever.
2. **Make the shop's high tiers reachable.** No player board has ever held a cost-4 unit. Either
   the level curve the rig climbs is wrong or the shop odds make the tier unreachable in
   practice; either way the "higher cost units should make a difference" requirement cannot be
   tested until one appears.
3. Re-run this measurement after either change and expect the win rate to start *tracking*
   summed level and cost instead of sitting at 83%.
