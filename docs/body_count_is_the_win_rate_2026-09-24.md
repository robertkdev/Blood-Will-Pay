# The fight is decided by how many more bodies you field - 2026-09-24

This is the answer to the question the whole review has been circling. The player's win rate is
a **step function of the body-count difference**, and almost nothing else moves it.

## The table

First attempts only, every recorded run, 2,474 fights. "Bodies" is the player's board size minus
the enemy's at the moment the fight starts.

| bodies | n | first-attempt win rate |
| ---: | ---: | ---: |
| -1 | 38 | 29% |
| **0** | **472** | **53%** |
| **+1** | **303** | **92%** |
| +2 | 252 | 85% |
| +3 | 438 | 86% |
| +4 | 541 | 92% |
| +5 | 176 | 97% |
| +6 | 196 | **100%** |
| +7 | 48 | **100%** |

Even bodies is a coin flip. One extra body is worth about 40 points of win rate. Six is
unlosable.

## Why this explains everything else

Every earlier measurement in this review is a corollary of that table:

- **The model's power ratio does not predict fights** because it is a sum of stats, and stats are
  not what decides. Measured directly on the newly instrumented fights, the at-clock survivor
  margin correlates **+0.47** with the body-count difference, **+0.32** with summed unit levels,
  **+0.21** with item count, and only **+0.12** with the model's power ratio.
- **Cutting the mirror's stats by 20% did not change the outcome** (last turn's reverted
  experiment) because the mirror has the *same number of bodies*. Its stat budget was never the
  thing that made it a coin flip.
- **Levelling, items, traits and cost tiers are flat** in every measurement taken, because none
  of them changes the body count.
- **The player wins 83% overall** because they usually bring more bodies: the counts run from
  -1 to +7, and the mass sits at +3 and above.
- **Widening the boss board** - the change earlier in this loop that moved the calibration
  probe's prepared tier from 77.8% to 72.2% - was on the right axis for the reason nobody had
  established: it reduced the player's body advantage.

## What decides a clock fight

With the new instrumentation (below), over 75 clock-decided fights in six fresh runs, the
settlement ladder is exactly as deterministic as its design says:

| at-clock survivors | n | player won |
| --- | ---: | ---: |
| player behind | 17 | **0%** |
| tied | 7 | 86% |
| player ahead | 51 | **100%** |

And the stat ratio does not move the at-clock margin at all: mean margin +2.07 at a power ratio
below 0.9, +2.00 at parity, +2.29 above 1.1. A board the model rates 10% *weaker* still ends the
clock with two more bodies standing.

## The instrumentation that made this measurable

The harness has parsed the engine's own `Combat resolved:` line for a long time - it is the only
record of a fight's real survivor counts, because the board is rebuilt during settlement - but
it was only used inside the failure record and never written into the fight event. So every
analysis in this project was reading `post_settlement_*`, which describes the *next* stage.

`combat_diagnostic` now also carries `resolution_line`, `resolution_player_alive`,
`resolution_enemy_alive`, `resolution_*_damage` and `clock_decided`, and the cached resolution
is cleared at the start of each fight so a fight that ends without a settlement line cannot
inherit the previous one's numbers. Verified live: 12 of 12 diagnostics on the first run carried
a resolution line with at-clock counts, and `clock_decided` read true at elapsed 45.1s.

This is what the depth review asked for and could not previously do. The earlier note's caveat -
that the at-clock comparison could not be measured - is now closed.

## What this makes actionable

The primary difficulty knob in this game is **the enemy's body count relative to the player's**,
and it is already the thing the generator's width ladder sets. That reframes the requirements:

1. **"Stage 10 should be easy to hit."** Chapter 2 stage 5 is the mirror, which copies the
   player's board and therefore always has the same body count - so it is a coin flip *by
   construction*, and no stat change can fix it. Making it winnable means the mirror fields one
   fewer body, which by the table above is worth roughly +40 points of win rate.
2. **"Harder as it goes on."** Difficulty should scale through the width ladder, not the stat
   target - which is consistent with every failed re-pricing experiment in this review.
3. **"Higher cost units should make a difference."** They do not, unless they change the body
   count - and the level curve only adds board slots, which the chapter cap floors already
   grant for free.

## An observation, explicitly not an attribution

The six runs that carried the new instrumentation reached a mean chapter of **4.5**, with two at
**chapter 8** - the deepest clean results in the record, against a historical clean best of
chapter 5 and a mean near 3. All six ended on a stage stall with zero technical failures.

Nothing about this turn's change can explain that: it adds event fields and clears a cache. The
same-seed spread is 1.75 chapters, so a six-run mean has a standard error near 0.7 and this is
about two of them. It is recorded as an observation because it is the best evidence yet that
chapter 8 is reachable and chapter 10 is not absurd, and it is explicitly **not** claimed as an
effect of anything.

## Gates

| gate | result |
| --- | --- |
| six live runs | 0 technical failures, all six completed with a summary |
| instrumentation coverage | 12/12 diagnostics on the first run carried at-clock counts |
