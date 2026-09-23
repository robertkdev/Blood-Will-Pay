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

## Experiment run and reverted: the first procedural boss at 0.75

The first recommendation above was tried and did not hold up. `target_rating_for` scaled
the chapter two boss target to 0.75, taking it from 350 to 262, with the chapter one
runway boss and every chapter from three up untouched and the generation probe still
passing at 0.120 relative error against a 0.17 gate.

Result, measured on the stage itself rather than on run depth:

| | runs in era | attempts at that boss | won |
| --- | --- | --- | --- |
| target 350 | 179 | 103 | 44.7% |
| target 262 | 25 | 14 | 57.1% (95% CI 31-83%) |

The intervals overlap, so this is not a demonstrated improvement, and it is well short of
the ~74% the target-251 and target-297 bands predicted for the same boards. The reason is
the finding above: that stage's win rate is close to flat in board-over-target ratio, so
moving the ratio from 0.69 to 1.01 barely moves the outcome. Lowering the target makes the
stage easier on paper and almost not at all in play.

The constant was reverted in `6fb20467`. Two lessons worth keeping:

1. A stage whose outcome does not track the build cannot be fixed by re-pricing the
   build. The lever is identified further down: the fight is awarded on the clock, and
   the generator refits every stage into a near-peer, so the stat budget never gets to
   be the difference.
2. Resolving a twelve-point shift at this stage would take a few hundred attempts per
   arm, not the twenty-five runs spent here. This stage is too rare to test at the scale
   the other findings in this document were tested at (100+ fights each), which is why
   the recommendation was recorded as a hypothesis and not as a fix in the first place.

## The mechanism: the clock decides almost half of the post-chapter-one fights

First attempts at stages of target 130 or higher: 979 fights, of which **478 (49%) ran to
the 45-second cap** and were awarded by `OutcomeLadder` instead of by the fight.

The ladder compares survivors, then absolute remaining health, then a seeded roll. The
recorded results follow it exactly:

| survivor margin (player - enemy) | n | won |
| --- | --- | --- |
| -4 to -1 | 71 | 0% |
| 0 (tied) | 72 | **24%** |
| +1 to +8 | 335 | 100% |

Any nonzero margin is decisive, which is the rule working. The tie is not even: 72 fights
went to equal survivors, and the player lost three of every four. The second criterion is
remaining health, and the generated enemy is a small board of stat-inflated units - four
bodies at the chapter two boss against the player's six - so at equal survivor counts it
simply has more health left.

That last point rules out the obvious fix. Rewriting the second criterion to be scale-free
does not help: health per surviving unit still favours the beefier board (four survivors at
200 health beat four at 100), and health as a fraction of each team's own maximum still
favours it (800 of 3200 against 400 of 2400). Every health-based comparison rewards the
shape the generator chose. The asymmetry is in the *board shape*, not in the ladder: a boss
board of four fat units against a player board of six flat ones wins the clock whenever the
fight is close, and the fight is close because the board was fitted to be a near-peer.

At the chapter two boss specifically: 87 of 128 attempts ran to the clock, the survivor
margin was spread 24 negative / 22 tied / 41 positive, and the stage's overall 45% is
that spread. The stage is not being lost on the stat budget; it is a survivor race
settled on a near-tie.

## The deeper pattern: difficulty is self-normalising

The generator fits every board to the stage's target rating. That means the opponent is
always built as a near-peer of the target, whatever the target is - and the recorded fights
show it:

| target | n | damage share p25 / p50 / p75 | won |
| --- | --- | --- | --- |
| 251 | 113 | 0.44 / 0.56 / 0.70 | 73% |
| 297 | 103 | 0.43 / 0.56 / 0.70 | 73% |
| 350 | 128 | 0.44 / 0.52 / 0.61 | 45% |
| 369 | 35 | 0.57 / 0.66 / 0.78 | 94% |
| 435 | 62 | 0.45 / 0.55 / 0.60 | 66% |
| 519 | 33 | 0.45 / 0.57 / 0.65 | 70% |
| 604 | 21 | 0.48 / 0.50 / 0.62 | 62% |

Damage share sits near one half at every target, and 38% of all fights are decided inside
a 40-60% share. Adjacent stages a fifth apart in target can differ wildly in outcome -
350 wins 45% and 369 wins 94% - which is a property of the board that was generated, not
of the number in the target.

This is the cleanest explanation of everything measured above: because every stage is
refitted to be a near-peer, the player's build barely moves the win rate, the gates come
out as coin flips, and the run distribution is "die in chapter 1-2, or occasionally go
deep" rather than a build-driven progression. It is also why re-pricing one boss changed
almost nothing.

The two properties compound. A board fitted to the target with as few bodies as the size
ladder allows is narrow and heavy, so it wins the clock tie-break; and because it is fitted
at all, it is always close enough to the player for that tie-break to decide the stage.

The design levers this points at, with the trade-offs already measured in the code:

- **Make the boss board scale in breadth with its target.** `_desired_size_for_target`
  returns 4 for every boss below rating 520 and only widens above that, but the player's
  boss board is 6-7 bodies by chapter 2-3. A wider boss board would carry less health per
  unit and stop winning clock ties by shape. The code already carries the breadth ladder
  for normal stages and an earlier paired comparison that found it overshot the target
  slightly (power 302.5 -> 321.0, player odds 40% -> 37%), so this trades one imbalance for
  another unless the target is fitted after the shape is chosen.
- **Fit the shape first, then the rating.** Everything above follows from fitting the
  board to a number. Choosing a per-stage board shape first - how many bodies, at what
  level - and then letting the stat fit close the gap would give the win rate something to
  track, which is what a build-driven progression needs.

## Standing limits on this kind of measurement

Live fights cannot be replayed. `CombatEngine.process(delta)` takes the render frame's
delta, so the number and size of steps inside a fight vary between runs; integration and
every seeded draw move with them, and the creep rewards share that engine's RNG. Two runs
of one seed with the same served decisions still produced a `veil` and a `core` from the
same reward roll. Only the fixed-step `LockstepSimulator` the calibration probes use is
reproducible, so live runs have to be measured by sample: the per-stage cuts above rest
on 100+ fights each, and single ten-run batches cannot attribute a change.
