# Ten-run scorecard against the stated criteria - 2026-09-24

Ten grown-profile Jev runs (5991 Omens, rank 67), starter bonko, speed 8, on the gameplay
code from `86866d92` - steeper odds curve and the chapter-scaled boss width in place. Fresh
seed block, plus seed 21204, which is the seed that crashed earlier in the day.

## The ten runs

| seed | terminal | chapter | battles | peak bankroll | max unit level | 3-stars | maxed traits | full board | items | clock-decided |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | --- | ---: | ---: |
| 21204 | loss | 4 | 25 | 22 | 2 | 0 | 4 | yes | 2 | 60% |
| 21211 | loss | 2 | 6 | 132 | 3 | 1 | 3 | yes | 1 | 50% |
| 21212 | stage_stall | 4 | 24 | 58,490 | 3 | 2 | 3 | yes | 3 | 33% |
| **21213** | stage_stall | **8** | 43 | **182,873,492** | 4 | 3 | 3 | yes | 7 | **0%** |
| 21214 | loss | 1 | 3 | 16 | 2 | 0 | 3 | no | 1 | 33% |
| 21215 | loss | 4 | 20 | 31 | 3 | 1 | 3 | yes | 2 | 55% |
| 21216 | stage_stall | 5 | 32 | 4,268 | 4 | 2 | 3 | yes | 4 | 22% |
| 21217 | loss | 2 | 11 | 266 | 3 | 1 | 4 | yes | 1 | 27% |
| 21218 | stage_stall | 2 | 11 | 99 | 2 | 0 | 3 | yes | 1 | 27% |
| 21219 | stage_stall | 2 | 13 | 160 | 2 | 0 | 3 | yes | 2 | 77% |

**Zero technical failures across all ten runs**, and the crash that killed seed 21204 earlier
in the day did not recur on the same seed - consistent with the replay evidence that it is not
deterministic.

## One run is contaminated, and it is identifiable from the data

Seed 21213 ran while the overtime constants were briefly edited (see
`docs/overtime_retest_2026-09-24.md`), so it ran a configuration that exists in no commit.
`JEV_REVISION` cannot see uncommitted edits, but the fight data can:

| run | fights reaching 40s or more | mean fight length | clock-decided |
| --- | ---: | ---: | ---: |
| 21213 | 4 / 43 (9%) | 28.5s | 0% |
| 21212 | 11 / 24 (46%) | 35.5s | 33% |
| 21216 | 13 / 32 (41%) | 33.0s | 22% |
| 21219 | 10 / 13 (77%) | 39.0s | 77% |

Overtime ramps damage from 24s, so the fights that used to run to the bell now end in the
24-40s window. 21213's distribution is shifted there and its clock share is zero. Every clean
run keeps a fat tail past 40s.

Pooled over the nine clean runs, **42% of fights are decided by the clock** - which reproduces
the 41% measured over the whole recorded era, and is the check that the classification is
right: the run with overtime on is the one with 0%.

## Against the criteria

| criterion | result |
| --- | --- |
| 3-star at least one unit | **6 of 10** (5 of 9 clean) |
| max out at least one trait | **10 of 10** |
| fully build out a board | **9 of 10** |
| complete 8 items | **not reached** - best is 7, on the contaminated run; best clean is 4 |
| reach chapter 10 | **not reached** - best clean is chapter 5; the all-time best is chapter 8, on the contaminated run |

The first three criteria the objective names are met. The two added later - eight completed
items, and chapter 10 as a good run - are both still unmet, and the item count is the binding
one: across ten runs the items completed were 2, 1, 3, 7, 1, 2, 4, 1, 1, 2. A run needs eight
by chapter 10 and the best clean run produced four across a whole run.

## The run shapes the objective asks for

- **Super rich**: 58,490 buckets on seed 21212, ending on a stage stall rather than a loss.
- **Loses early**: 16 buckets out in chapter 1; 22 and 31 on chapter-4 losses.
- **Struggles and hangs on**: 132 and 266 buckets reaching chapter 2, 4,268 reaching chapter 5.
- **Way overpowered**: 182,873,492 buckets and chapter 8 - but that is the contaminated run, so
  it is not evidence about the shipped game. It is, however, the strongest hint in the record
  that overtime is the lever: with the fight allowed to resolve, the same rig reached deeper
  and compounded three orders of magnitude further.

Peak bankrolls across the clean runs span 16 to 58,490, which is the long-tailed, occasionally
absurd distribution the design is asking for, and it is a better spread than the 48-665 medians
recorded before the odds were recalibrated.

## What is left

1. **Items.** Eight completed by chapter 10 is not close, and the item rate is the same
   `rolls_per_kill` knob the creep-reward work identified. This is now the single clearest
   numeric gap against the objective.
2. **Chapter 10.** Never reached by a clean run; best clean is chapter 5.
3. **Overtime.** Suggested by the contaminated run, measured deterministically, and needing the
   live same-seed A/B before it ships.
4. At exponent 5.0 with overtime on, the same build-quality measurement should be re-run; the
   prediction is that summed unit level and cost start tracking the win rate.
