# The steeper curve in a live batch: the rig presses its bets, and the ratio is what is left
# - 2026-09-24

Four Jev runs on a fresh seed block, grown profile (5991 Omens, rank 67), speed 8, code at
`86866d92` - the commit that steepened `ODDS_EXPONENT` from 1.55 to 4.0. Three completed.

| seed | terminal | chapter | battles | peak bankroll | technical failures |
| --- | --- | ---: | ---: | ---: | ---: |
| 21201 | stage_stall | 6 | 36 | 4,702 | 0 |
| 21202 | stage_stall | 3 | 19 | 3,386 | 0 |
| 21203 | loss | 3 | 15 | 1,590 | 0 |
| 21204 | **engine crash** | - | - | - | summary never written |

## The betting changed the way the requirement asked

The standing complaint was that the rig goes into rounds with buckets neither bet nor spent -
"it only bets when it is behind" - and the recorded baseline was stark: at the stage where a
run finally ends, the median wager was **4 buckets against a median bankroll of 778, a 10%
stake, and 0 of 19 runs wagered at least half their bankroll** (`docs/why_runs_stall_2026-09-23.md`).

Pooled over the 55 first attempts in these three runs, stake as a share of the bankroll
actually in hand:

| shown odds | n | mean stake | median stake | all-in |
| --- | ---: | ---: | ---: | ---: |
| below 0.50 | 18 | 8% | 2% | 0 / 18 |
| 0.50 - 0.70 | 15 | 73% | 100% | 10 / 15 |
| 0.70 - 0.90 | 9 | 100% | 100% | 9 / 9 |
| 0.90 and up | 13 | 100% | 100% | 13 / 13 |

**32 of the 37 fights it rated above 50% were all-in**, against 0 of 19 before. It still holds
back below 0.50, which is the behaviour the design asks for rather than a defect.

Peak bankrolls of 4,702 / 3,386 / 1,590 across three runs are also far above the pre-change
medians (48-665), which is what compounding a pressed stake should look like. Three runs is
not evidence of a distribution, and it is not reported as one.

## The remaining error is the ratio, not the curve

First attempts only, shown odds against what happened:

| shown odds | n | mean shown | observed | gap |
| --- | ---: | ---: | ---: | ---: |
| 0-0.29 | 5 | 0.18 | 0.60 | +0.42 |
| 0.30-0.49 | 13 | 0.43 | 0.69 | +0.26 |
| 0.50-0.69 | 15 | 0.57 | 0.87 | +0.30 |
| 0.70-0.89 | 9 | 0.76 | 1.00 | +0.24 |
| 0.90-1.00 | 13 | 0.98 | 1.00 | +0.02 |
| **all** | **55** | **0.630** | **0.855** | **+0.225** |

**This is not comparable to the 3,144-fight baseline** (mean shown 0.584, observed 0.780, gap
0.197) - different seed block, 55 fights against 3,144 - so it is not claimed as a regression
or an improvement. What it does show is the *shape* of what is left: the error is now
one-directional and largest in the middle bands, and the model is pessimistic nearly
everywhere.

The arithmetic says the curve cannot be the remaining lever. At a shown 0.57 the underlying
ratio is only 1.07 - the model rates the two boards as near-peers - and 87% observed would
need an exponent near 27, against the [3.1, 5.2] window the constructed populations allow. A
near-even ratio that resolves 87% of the time is a ratio problem: live boards are stronger
than the model's rating says they are.

The mechanism worth testing is item *effects*. `CombatPowerModel.unit_power` reads stats, and
`ItemDef` also carries `effects` - on-hit and ability payloads - that never reach it. The
representative probe applies item **stat** modifiers to its prediction while the simulated
fight also runs the effects, and it still calibrates, because it hands items to both boards
at random. Live play concentrates items on one carry, so the effect advantage is asymmetric
and the model never sees it. **That is a hypothesis, not a finding.** The experiment that
would settle it: give the representative probe a concentrated item-assignment mode - all
items on the strongest body - and check whether the model then under-predicts the way the
live record does.

## A crash that costs a whole run

Seed 21204 died with **signal 11** and never wrote a `run_summary.json`, so the run produced
no analysable data at all:

```
[Items] remove_all on=Repo -> returned=0
[Items] remove_all on=Repo -> returned=0
ERROR: Parameter "mem" is null.
   at: alloc_static (core/os/memory.cpp:111)
ERROR: Parameter "mem_new" is null.
   at: _alloc (./core/templates/cowdata.h:384)
CrashHandlerException: Program crashed with signal 11
```

Context at the crash: chapter 5 round 4, a **full nine-unit board** with a three-unit bench,
immediately after the item pass touched `Repo` twice. `remove_all` appears in
`shop_transactions.gd`, `roster.gd` and `combine_service.gd`, and the two consecutive calls
with nothing returned is itself suspicious.

This is the most serious defect in the batch, and it is exactly the shape the request named:
`the request asked what happens at max team size on both sides`. A crash loses the run's data
as well as the run, so it also removes evidence. No prior crash record exists in `docs/`.

## Next

1. Reproduce and fix the 21204 crash. Nine-unit board, item pass, `remove_all` twice - then
   make the harness write a partial summary before any run can end so a crash cannot erase
   its own evidence.
2. Build the concentrated-item probe described above and measure whether the ratio error is
   item effects.
3. Re-run this seed block once the crash is fixed; 21204 is not a result, it is a gap.
