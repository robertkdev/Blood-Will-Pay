# Jev's ten-run scorecard on the fixed build - 2026-09-24

The TypeSafe credits came back, so the Jev lane - the actual subject of this objective - ran ten
games for the first time since the mirror, boss-escalation, level-price and deadlock changes.
It is the best reading the project has had.

## The ten runs

| seed | terminal | chapter | battles | peak bankroll | max unit level | 3-stars | maxed traits | full board | items |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | --- | ---: |
| 21351 | stage_stall | 2 | 14 | 180 | 3 | 1 | 4 | yes | 1 |
| 21352 | loss | 2 | 9 | 934 | 2 | 0 | 3 | yes | 2 |
| 21353 | stage_stall | 7 | 42 | 809,259 | 3 | 4 | 3 | yes | 6 |
| 21354 | stage_stall | 7 | 38 | 2,486 | 4 | 1 | 4 | yes | **8** |
| 21355 | stage_stall | 3 | 16 | 289 | 2 | 0 | 3 | yes | 3 |
| 21356 | aborted | **9** | 47 | **40,894,385** | 4 | 5 | 3 | yes | **9** |
| 21357 | stage_stall | 2 | 13 | 50 | 3 | 1 | 3 | yes | 1 |
| 21358 | stage_stall | 6 | 32 | 15,411,218 | 4 | 6 | 3 | yes | 6 |
| 21359 | stage_stall | 6 | 34 | 3,965,062 | 4 | 8 | 3 | yes | 5 |
| 21360 | stage_stall | 3 | 17 | 43 | 3 | 1 | 3 | yes | 2 |

## Against the criteria

| criterion | result | previous best |
| --- | --- | --- |
| 3-star at least one unit | **8 of 10** | 6 of 10 |
| max out at least one trait | **10 of 10** | 10 of 10 |
| fully build out a board | **10 of 10** | 9 of 10 |
| complete 8 items | **reached twice** (9 and 8) | once, in an earlier era |
| reach chapter 10 | no - but **chapter 9**, the deepest Jev run on record | chapter 8 |
| technical failures | **9 of 10 runs clean**; one aborted with 5 | common |

## The run shapes the objective names are all present

- **Super rich**: 40.9M, 15.4M, 3.97M and 809,259 buckets.
- **Loses early**: seed 21357 out at peak 50; seed 21352 a `loss` at peak 934.
- **Struggles and hangs on**: 21355 and 21354 reaching chapters 3 and 7 on three-figure banks.
- **Way overpowered**: 21356 at chapter 9 holding 40.9M, eight three-stars on 21359.

That is a long-tailed distribution with genuine variety, which is what "gamble-shaped" means.

## A correction to my own item finding

`docs/item_rate_against_chapter_10_2026-09-24.md` measured 0.71 completed items per chapter and
extrapolated to 7.1 by chapter 10, calling the rate about 12% short. **That was wrong**, and the
error was pooling shallow runs with deep ones. Among the runs that actually got somewhere:

| seed | chapter | items | items / chapter |
| --- | ---: | ---: | ---: |
| 21353 | 7 | 6 | 0.86 |
| 21354 | 7 | 8 | 1.14 |
| 21356 | 9 | 9 | 1.00 |
| 21358 | 6 | 6 | 1.00 |
| 21359 | 6 | 5 | 0.83 |

The realised rate on a run that survives is **about 0.97 items per chapter**, which reaches eight
items by chapter eight. The item criterion was never the problem - depth was, and the rate only
looked short because it was averaged over runs that died in chapter 2.

## What is left

1. **Seed 21356 is the one failure that matters.** It reached chapter 9 with 40.9M buckets and
   ended `aborted` with five technical failures rather than a fight outcome. That is the deepest
   run on record and it was lost to a harness abort, so the abort is now the highest-value
   defect: it costs the best runs, which are the ones worth keeping.
2. **Chapter 10.** Chapter 9 is the new record. The depth ledger says the boss gate is the whole
   cost and the curve is already right, so this is the design decision recorded there.
3. The contract-market PASS race, still open in the heuristic lane.
