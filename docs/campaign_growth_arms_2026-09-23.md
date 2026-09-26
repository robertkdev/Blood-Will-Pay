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

---

# Re-run after the seed, generator and sweep fixes - 2026-09-23 (later)

Same two arms, a fresh seed block (21011-21020), and every fix from this session in place:
the procedural seed lock, the whole-team level tuning, the planning window, the controller
retry, the item identity fix, and the simulator lifecycle. This is the first arm reading where
the two runs of a seed faced the same enemies.

## Paired result

| seed | fresh | grown |
| --- | --- | --- |
| 21011 | ch2, peak 21 | ch2, peak 67 |
| 21012 | ch2, peak 13 | ch3, peak 1,032 |
| 21013 | ch1, peak 9 | ch3, peak 131 |
| 21014 | ch1, peak 7 | ch3, peak 53 |
| 21015 | ch5, peak 140 | ch2, peak 14 |
| 21016 | ch7, peak 1,022 | ch6, peak 642 |
| 21017 | ch7, peak 122 | ch2, peak 11 |
| 21018 | ch1, peak 7 | ch2, peak 93 |
| 21019 | ch2, peak 12 | ch3, peak 357 |
| 21020 | ch2, peak 27 | ch5, peak 3,028 |

| | fresh | grown |
| --- | ---: | ---: |
| mean chapter | 3.00 | 3.10 |
| median chapter | 2.0 | 3.0 |
| mean peak bankroll | 138 | **543** |
| best peak bankroll | 1,022 | **3,028** |
| reached chapter 5+ | 3 | 2 |
| reached chapter 7+ | 2 | 0 |
| technical failures | 1 | 0 |

Grown went deeper on 6 seeds, fresh on 3, one tie. The honest reading is that **the Ledger
buys money, not depth**: peak bankroll is four times higher and the best run is three times
richer, while mean depth is unchanged. The compounding ladder works - 3 starting buckets
becomes 3,028 - and depth is still decided by the gate stages rather than by the bankroll.
That is the same self-normalising-difficulty finding, now measured with the confounds removed.

## Boss curve with everything in place

First attempts, this batch only. Chapter cells under four fights are dropped.

| arm | ch1 boss | ch2 boss | ch3 boss |
| --- | ---: | ---: | ---: |
| fresh | 60.0% (n=10) | 100% (n=5) | - |
| grown | 80.0% (n=10) | 88.9% (n=9) | 83.3% (n=6) |

The chapter-2 spike is gone: it used to be the hardest fight in the game at 49.3% and it is
now the easiest early boss. Chapter 1 is the remaining problem in the other direction - it is
the *hardest* early boss for a fresh account at 60%, so the first boss still gates runs that
the design says should be cruising into chapter 2.

## Criteria with everything in place

| criterion | result |
| --- | --- |
| three-star at least one unit | 10 of 20 |
| max out at least one trait | **20 of 20** |
| fully build out a board | 18 of 20 |
| complete 8 items | reached once (9 completed in the richest run) |
| reach chapter 10 | **0 of 20** (best: chapter 7) |

The trait criterion is now universal and the three-star rate is up. The depth criterion is
not met: chapter 7 is the deepest the rig has ever reached, and chapter 10 has still never
been seen.

---

# All-in bar A/B: a half against three quarters - 2026-09-23 (later still)

The replay above said a Kelly-share bar of a half should raise the peak bankroll by a third
and the p90 threefold on identical fights. This is the live check: both arms grown, rank 67,
the same eight seeds, only the policy's all-in bar differing. The three-quarter bar is kept
as `tools/jev/policy/variants/wager_cautious_075.json`.

| seed | all-in at a half | all-in at three quarters |
| --- | --- | --- |
| 21011 | ch2, peak 24 | ch2, peak 67 |
| 21012 | ch2, peak 87 | ch3, peak 962 |
| 21013 | ch1, peak 16 | ch3, peak 30 |
| 21014 | ch3, peak 1,109 | ch4, peak 3,405 |
| 21015 | ch2, peak 16 | ch2, peak 14 |
| 21016 | ch6, peak **42,126** (aborted) | ch4, peak 21 |
| 21017 | ch2, peak 24 | ch3, peak 290 |
| 21018 | ch1, peak 14 | ch3, peak 13 |

| | a half | three quarters |
| --- | ---: | ---: |
| mean chapter | 2.38 | 3.00 |
| median peak bankroll | 55.5 | 48.5 |
| best peak bankroll | **42,126** | 3,405 |
| runs ending in chapter 1-2 | 4 of 8 | 2 of 8 |

## What the live check says, honestly

The bankroll claim holds and then some: the half bar produced **42,126 buckets**, twelve times
the best run this project has ever recorded before it (3,028), with a 12,377-bucket wager on
a chapter-6 boss. The gambling shape the objective asks for is now present - super rich,
way overpowered, and early losses in the same batch.

The depth claim does **not** hold. Mean chapter reached is 2.38 against 3.00, and the half
bar ended four of eight runs in the first two chapters against two of eight. With eight seeds
per arm and a standard deviation near 1.4 chapters, that difference is about one standard
error and is not significant on its own - but it is the wrong sign, and it is consistent with
the finding this whole review keeps returning to: more money does not buy depth, because depth
is decided by gate stages.

So the bar stays at a half, for the reason the objective gives rather than for depth: the
distribution now spans "loses early" through "gets super rich", and the three-quarter bar's
distribution did not. The intermediate bar of 0.65 - the replay shows it captures about half
the peak gain with a third of the bankroll-loss risk - remains the option if the early
losses turn out to be too many.

## A harness defect that cost the richest run of the session

The 42,126-bucket run was aborted at chapter 6 round 4, not lost. The planning window was
healthy this time (960 -> 727 seconds), so the sweep fix held; the recorded failures are
three `continue button disabled` assertions and then `Start Battle did not enter combat`,
immediately after a `click_fallback` that needed three synthetic-mouse attempts to register
a shop click. The board was 9 of 9, the bankroll 39,326, and the button disabled.

That points at synthetic input or the fielding pass leaving the UI unable to accept Start
Battle, not at the game refusing a legal action. The fielding fallback is now reachable and
self-reporting, which should name the cause next time it happens.

---

# The ten-game scorecard, after the legacy gate was fixed - 2026-09-23 (latest)

Ten grown runs on a fresh seed block, with every fix from this session in place: the
procedural seed lock, the whole-team level tuning, the planning window, the controller retry,
the item identity fix, the simulator lifecycle, the chapter-one boss board, the continued boss
ramp, and the level-four legacy gate.

| seed | chapter | peak bankroll | three-stars | traits | board | level | items | legacies |
| --- | ---: | ---: | ---: | ---: | --- | ---: | ---: | ---: |
| 21031 | 6 | 1,820,484 | 6 | 3 | full | 4 | 6 | 2 |
| 21032 | 3 | 157 | 0 | 3 | full | 2 | 1 | 0 |
| 21033 | 6 | 90,766 | 5 | 4 | full | 4 | 5 | 1 |
| 21034 | 1 | 39 | 0 | 3 | full | 2 | 0 | 0 |
| 21035 | 4 | 24,524 | 1 | 3 | full | 3 | 2 | 0 |
| 21036 | 4 | 4,233 | 0 | 3 | full | 2 | 3 | 0 |
| 21037 | 2 | 36 | 0 | 3 | full | 2 | 2 | 0 |
| 21038 | 2 | 38 | 0 | 4 | full | 2 | 1 | 0 |
| 21039 | 4 | 21,056 | 1 | 3 | full | 3 | 4 | 0 |
| 21040 | 5 | 11,160 | 1 | 3 | full | 3 | 3 | 0 |

## Against the criteria the objective states

| criterion | result |
| --- | --- |
| after ten games, three-star at least one unit | **5 of 10** runs, six three-stars in the best one |
| max out at least one trait | **10 of 10** |
| fully build out a board | **10 of 10** |
| reach chapter 10 | 0; deepest this batch is chapter 6, and chapter 8 is the all-time best |
| technical failures | **0 across all ten runs** |

## The shapes the objective asks for are present

- **Super rich and way overpowered**: 1,820,484 buckets and six three-star units in one run;
  90,766, 24,524, 21,056 and 11,160 in four more.
- **Loses early**: chapter 1, and two runs out in chapter 2.
- **Struggles but hangs on**: two runs to chapter 4 and one to chapter 5 on four-figure
  bankrolls.

## The legacy gate is now verified in play, not assumed

Three legacies were bound across two runs, all of them `applied: true` and chosen by the model
rather than by the fallback: `martyr_seal` on a level-4 bonko and a level-4 mortem in one run,
and one more in the run that reached chapter 6 with 90,766 buckets. The runs that used to abort
at exactly this point now finish with real outcomes and zero technical failures.

One gap was closed while verifying: the heuristic arm has no controller to answer the gate, so
it would have held the planning beat for the full decision timeout. It now takes the first
offer there, the same way its item pass is first-fit.
