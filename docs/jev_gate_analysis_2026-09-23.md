# The chapter gates a Jev run cannot influence - 2026-09-23

Everything here is measured from the recorded Jev runs under
`E:\CodexStorage\task-artifacts\gamble-battle-jev-run-20260922\runs` (158 deep runs at
the time of writing) and from the transcripts inside them. First attempts only: a retry
is a different bet and is measured separately.

## What the runs look like

- Chapter reached: 1 = 45 runs, 2 = 74, 3 = 14, 4 = 5, 5 = 9, 6 = 3, 7 = 1, **9 = 3,
  10 = never**.
- Peak bankroll: median 11, p90 63.
- Where runs die: 43% on a BOSS, 29% on a MIRROR, 28% on a normal stage. By cause: 45%
  wiped, 37% lost on the clock ladder, 17% stalled after four attempts.
- The most common single stages to die on are chapter 1 stage 4 (21 runs) and chapter 2
  stage 4 (20 runs) - both bosses, together 37% of deep-run deaths.

## Board strength against the design target

Board rating divided by the stage's `target_rating`, first attempts:

| target | n | p50 | p90 | max | won |
| --- | --- | --- | --- | --- | --- |
| 25-62 | 197 | 1.5-3.4x | - | 4.02 | 100% |
| 100 | 115 | 1.18 | 1.48 | 1.76 | 56.5% |
| 251 | 92 | 0.89 | 1.12 | 1.51 | 73.9% |
| 265 | 97 | 0.58 | 0.70 | 0.82 | 77.3% |
| 297 | 86 | 0.80 | 0.96 | 1.27 | 72.1% |
| 350 | 117 | 0.71 | 0.82 | 1.06 | 46.2% |
| 435 | 48 | 0.74 | 0.85 | 0.88 | 70.8% |
| 519 | 27 | 0.84 | 0.89 | 0.99 | 74.1% |
| 835 | 10 | 0.96 | 1.16 | 1.26 | 90.0% |

From target 251 upward the board sits below the design target almost everywhere and the
fights are still mostly won, because the power model reads the player low by 12-20 points
(measured separately over 1073 first attempts). Two bands break that pattern: target 100,
where the board is 1.18x and wins 56.5%, and target 350, where it is 0.71x and wins 46.2%.

## The chapter 2 stage 4 boss is not a build check

117 recorded first attempts at that stage, won 46.2%. Nothing the player or the generator
brings separates the wins from the losses:

| cut | winners | losers |
| --- | --- | --- |
| board size | 6 | 6 |
| two-stars on board | 2 | 2 |
| items on board | 2 | 2 |
| active traits | 0 | 0 |
| board power p25 / p50 / p75 | 227 / 256 / 271 | 231 / 240 / 273 |
| peak bankroll before the fight | 7 | 7 |

Win rate by enemy-over-player power ratio, same stage: 0.9 -> 38%, 1.0 -> 43%, 1.2 -> 50%,
1.3 -> 60%, 1.5 -> 42%, 1.6 -> 30%. There is no usable trend in a band that spans 0.9 to
1.7.

Peak bankroll before the stage does not predict it either: runs that had peaked at under
6 buckets won 61%, runs that had peaked at 6-9 won 32%, runs at 10 or more won 42%, and
all three groups arrived with boards of 240-270 power.

## A hypothesis that did not survive

The generator picks enemy units by rating from the whole catalog, so it can field cost-4
and cost-5 units while the player's shop level still caps the shelf at cost 3. At the
chapter 2 boss, 61 of 117 fights had a cost-4 enemy unit against a player board that was
82% cost-1. That looked like the explanation.

It is not one. Those 61 fights were won 46% of the time and the 56 fights without a
capstone were won 46% of the time. Across every stage from target 130 up, fights where
the enemy out-caps the player (403 of 803, 50%) were won 74% against 81% otherwise -
worth about seven points, not the wall. Recorded beside `_select_unit_ids` so it is not
re-chased.

## What this implies

The first hard gate in a run is close to a coin flip that neither resources, board
composition, board power, nor enemy composition moves. For a game whose loop is a wager
on the fight, that is the wrong kind of beat: the player cannot build toward passing it,
so the gate reads as luck. It also compounds - four attempts at 46% is an 8.5% chance of
stalling there on every run, and the rig reached chapter 9 three times in 158 runs.

Two directions worth measuring next, in preference order:

1. Move the gate into the steep part of its own curve. The rig's chapter 2 boards span
   roughly 200-290 power and win ~46% against a target of 350; a target near 220-240
   would put that same spread across the win/loss line, so the better half of the spread
   passes and the weaker half does not. The caveat is measured: the curve is flat through
   200-300, so this may convert a hard coin flip into an easy one rather than into a
   check. It is worth one batch to find out.
2. Give the player a lever that exists at that chapter. The candidates the data supports
   are board slots (capacity is 6 there, and the rig always fills it), item count (2 by
   that stage, from two creep stages), and shop level (the rig reaches level 2-3 by then,
   where cost-3 is a 5% roll and cost-4 is impossible).

## Experiment in flight: the first procedural boss at 0.75

`FIRST_PROCEDURAL_BOSS_TARGET_SCALE` in `endless_chapter_generator.gd` scales the chapter
two boss target to 0.75, taking it from 350 to 262. The chapter one runway boss and every
chapter from three up are untouched, and the generation probe still passes
(max relative error 0.120 against a 0.17 gate).

Measured so far: one ten-run batch. The board the rig brings to that stage now *meets* the
target instead of sitting well under it - power 264 against a target of 262, where before
it was power 240 against 350 - and four of the six attempts at the stage were won, against
46 of 103 before. That sample is far too small to claim anything about the win rate: six
attempts is a confidence interval from about a quarter to nine tenths. The board-to-target
ratio is also partly a restatement of the change, not independent evidence.

The confirmation metric is the stage win rate at n of about 100, which is what the 46.2%
figure rests on. At roughly one hundred fights per four to five ten-run batches, that is
the work still outstanding. If the rate does not move, revert the constant: it is one
line, and the reasoning above is why it was tried.

## Standing limits on this kind of measurement

Live fights cannot be replayed. `CombatEngine.process(delta)` takes the render frame's
delta, so the number and size of steps inside a fight vary between runs; integration and
every seeded draw move with them, and the creep rewards share that engine's RNG. Two runs
of one seed with the same served decisions still produced a `veil` and a `core` from the
same reward roll. Only the fixed-step `LockstepSimulator` the calibration probes use is
reproducible, so live runs have to be measured by sample: the per-stage cuts above rest
on 100+ fights each, and single ten-run batches cannot attribute a change.
