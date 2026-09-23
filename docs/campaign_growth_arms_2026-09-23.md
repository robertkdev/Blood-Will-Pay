# Campaign growth, measured on two arms - 2026-09-23

The design promise is incremental: play, lose, and come back permanently stronger, so an
account that has grown on the Black Ledger reaches further than a fresh one. That had
never been tested, and could not have been: the rig spent no Omens at all before this
session, and the whole Edict tree was worth one starting bucket and one free reroll.

This is the first reading where the two profiles actually differ.

## Method

Two arms, the same ten seeds, the same starter, the same code, the same boss curve:

| arm | account | run start |
| --- | --- | --- |
| fresh | `JEV_LEDGER_OMENS=0`, rank 1 | 3 buckets, 3 board slots, no free reroll |
| grown | `JEV_LEDGER_OMENS=5991`, rank 67 | 6 buckets, 5 board slots, 1 free reroll |

The grown arm buys and equips the tree between runs: Debtor's Mercy, Wide Table and House
Courtesy are equipped, which is what produces the 6 buckets and 5 slots. Each arm runs
against its own profile file, so a fresh arm cannot wipe the live account.

One fresh run (seed 21001) failed to boot on a harness defect and is excluded; one fresh
run (seed 21008) was taken by the dead retry path at chapter 6 and is flagged below.

## Result

| | fresh | grown |
| --- | ---: | ---: |
| runs | 9 | 10 |
| mean chapter reached | **2.89** | **3.50** |
| median chapter | 3.0 | 3.0 |
| mean peak bankroll | 154 | **373** |
| best peak bankroll | 1,143 | **1,581** |
| runs reaching chapter 5+ | 1 | **3** |

Paired by seed, the grown account went deeper on 4 seeds, shallower on 2, and tied on 3.
The one clearly adverse seed pair (21008, fresh reached chapter 6 against grown's 4) has a
fresh run that died to `controller_lost` rather than to a fight, so it is not a clean
outcome either way.

## What the criteria look like now

Across all twenty runs of the new era, against the design benchmarks:

| criterion | result |
| --- | --- |
| three-star at least one unit | **9 of 20 runs** (best: five three-stars in one run) |
| max out at least one trait | **19 of 20 runs** |
| fully build out a board | **19 of 20 runs** |
| complete 8 items by chapter 10 | **not reached** - no run has reached chapter 10 |
| reach chapter 10 at all | **0 of 20** (best: chapter 6) |

So the depth criteria are met and the item criterion is untestable: the campaign has never
been seen past chapter 6 by the rig. The best unit level observed is 4, and the most
completed items in a run is 6. In the single run that reached stage 10, two items were
complete.

The board is also full in nearly every run - 19 of 20 filled their capacity - which means
capacity, not board quality, is now the binding constraint on the wide-board plan.

## Confounds to close before this is a verdict

1. **The sweep ate the planning window.** At 8x the 120-second planning countdown burns
   eight times faster, and a decision-heavy shop ran out of time and aborted the run. That
   killed the richest run in the record and is now fixed; the two arms above ran before the
   fix for the fresh arm and partly after it for the grown arm.
2. **Two deep runs were lost to harness defects**, not to the game - see
   `jev_harness_defects_2026-09-23.md`.
3. **A fresh account can still get rich.** Seed 21008 reached chapter 6 with 1,143 buckets
   on zero Omens. The Ledger is not yet the gate on a good run, and the growth effect is
   real but modest at rank 67.
4. The arms are 9 and 10 runs. Depth differences of half a chapter are inside the noise at
   that size.

## Next

- Re-run both arms with the planning-window fix and the controller retry in place, at
  matched run counts.
- The wager sizing rule still caps all-in at a Kelly share of three quarters, which is why
  the rig stakes around 58% of a large bankroll on fights it wins 78-88% of the time. With
  the displayed odds corrected or the sizing threshold lowered, the ladder compounds the
  way the design intends.
- Scale the Ledger further per rank. Rank 67 is the depth the whole project was farmed to;
  the ladder is worth climbing to 99 only if the payout keeps growing with it.
