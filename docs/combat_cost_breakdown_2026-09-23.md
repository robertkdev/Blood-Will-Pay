# Where a max-size fight actually spends its CPU - 2026-09-23

`combat_performance_2026-09-23.md` established that the shipped game is not the source of the
reported choppiness - at 1x a max-size fight uses a couple of percent of a frame - and that the
number worth attacking, if the sweep needs to be faster, is the **90 ms of CPU per game-second
at 12v12**. That is now the bottleneck for the loop itself: the deep, rich runs this review is
trying to produce take ten to twenty minutes of wall clock each because their fights run long at
8x.

This pass measured where that CPU goes and found the single dominant term.

## Top-level breakdown, 12v12, 319 steps

Per-section microseconds accumulated inside `CombatEngine.process()`:

| section | ms | share |
| --- | ---: | ---: |
| **movement** | **567** | **59%** |
| buff and ability ticks | 117 | 12% |
| retarget | 117 | 12% |
| cooldown advance | 91 | 10% |
| attacks | 44 | 5% |
| bookkeeping, outcome, position emit, frame setup | 21 | 2% |

## Inside movement

The movement service already carries its own phase diagnostics; they are now switched on and
printed by `tests/perf/PerfLargeBoard.tscn`, so this sub-breakdown is reproducible without any
new instrumentation:

| phase | ms | share of movement |
| --- | ---: | ---: |
| **slot_assign** | **462** | **81%** |
| player_steps | 46 | 8% |
| collision | 25 | 4% |
| enemy_steps | 23 | 4% |
| groups, prev_slots, setup, alive, caps, targets | 25 | 4% |

## Inside slot assignment

`slot_assign` splits into `pairs`, `rotate` and `output`. `rotate` is essentially all of it:
~400 ms of the 425 ms player side. Cost per call, by the size of the attacker group, over the
319 steps of the run:

| group size | calls | µs per call |
| --- | ---: | ---: |
| 2 | 373 | 13 |
| 5 | 137 | 262 |
| 8 | 22 | 1,960 |
| 11 | 56 | 3,868 |
| 12 | 6 | 4,983 |

So **62 of roughly 1,100 slot calls - six percent - spend 246 ms of the 425 ms player-side
total.** The cause is structural: the rotate phase tries every rotation base and solves the
exact assignment for each, so an n-body group costs n x DP(n), and DP(n) is 2^n x n for sizes
9 to 12 (sizes 6 and 8 have hand-specialized paths).

## An optimization that was tried and reverted, and why that matters

The obvious constant-factor work was done - packed predecessor arrays instead of typed int
arrays, a precomputed free-column list per mask instead of a loop over all columns with a bit
test, and a suffix-minimum lower bound to abandon a rotation that cannot beat the incumbent.
All three are exact on paper.

They changed the fight. `PerfLargeBoard`'s state signature moved from
`-8732586936770176011:430` to `4447872735192625278:432`, the fight ran 351 frames instead of
319, and the surviving board changed. The change was reverted and the original signature is
back.

The lesson is worth more than the optimization: **this solver's tie-breaking is sensitive
enough that an exact-on-paper rewrite still changed the outcome**, and every balance number in
this project is measured through that solver. Any optimization here needs the state signature
as its equivalence gate, not a perf number, and the work is not done until the signature is
byte-identical.

## What to attack next

The rotate search itself, not the DP's inner loop. Two directions, both of which need the
signature gate:

- Bound the search. The incumbent is already threaded into each rotation, so a cheap lower
  bound on a rotation's achievable cost can skip the DP entirely for most rotations - but the
  bound has to be tight enough to matter, and the attempted suffix-minimum version was both too
  weak to skip much and, empirically, not equivalent.
- Reuse across rotations. Consecutive rotation bases differ by one slot step, so their cost
  matrices are related; nothing in the current code exploits that.

The shipped game does not need any of this. It is the sweep that does.
