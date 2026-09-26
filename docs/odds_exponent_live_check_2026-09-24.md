# The steeper curve in a live batch: the rig presses its bets, and the ratio is what is left
# - 2026-09-24

Four Jev runs on a fresh seed block, grown profile (5991 Omens, rank 67), speed 8, code at
`86866d92` - the commit that steepened `ODDS_EXPONENT` from 1.55 to 4.0.

| seed | terminal | deepest chapter seen | fights | first attempts | peak bankroll | technical failures |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| 21201 | stage_stall | 6 | 37 | 29 | 4,702 | 0 |
| 21202 | stage_stall | 3 | 20 | 14 | 3,386 | 0 |
| 21203 | loss | 3 | 16 | 12 | 1,590 | 0 |
| 21204 | **engine crash** | 5 | 26 | 23 | - | run ended by crash |

All four runs are analysed. Seed 21204 lost its aggregated `run_summary.json` to the crash,
but its `run_events.jsonl` survived with 339 events including all 26 fights, so it is only the
summary artifact that is gone - **not the run's evidence**. An earlier draft of this note
claimed the crash erased its own evidence; that was wrong and is corrected here.

## The betting changed the way the requirement asked

The standing complaint was that the rig goes into rounds with buckets neither bet nor spent -
"it only bets when it is behind" - and the recorded baseline was stark: at the stage where a
run finally ends, the median wager was **4 buckets against a median bankroll of 778, a 10%
stake, and 0 of 19 runs wagered at least half their bankroll** (`docs/why_runs_stall_2026-09-23.md`).

Pooled over the 78 first attempts in all four runs, stake as a share of the bankroll actually
in hand:

| shown odds | n | mean stake | median stake | all-in |
| --- | ---: | ---: | ---: | ---: |
| below 0.50 | 29 | 12% | 3% | 0 / 29 |
| 0.50 - 0.70 | 21 | 69% | 100% | 12 / 21 |
| 0.70 - 0.90 | 10 | 100% | 100% | 10 / 10 |
| 0.90 and up | 18 | 100% | 100% | 18 / 18 |

**40 of the 49 fights it rated above 50% were all-in (82%)**, against 0 of 19 before. It still holds
back below 0.50, which is the behaviour the design asks for rather than a defect.

Peak bankrolls of 4,702 / 3,386 / 1,590 across three runs are also far above the pre-change
medians (48-665), which is what compounding a pressed stake should look like. Three runs is
not evidence of a distribution, and it is not reported as one.

## The remaining error is the ratio, not the curve

First attempts only, shown odds against what happened:

| shown odds | n | mean shown | observed | gap |
| --- | ---: | ---: | ---: | ---: |
| 0-0.29 | 9 | 0.17 | 0.67 | +0.50 |
| 0.30-0.49 | 20 | 0.43 | 0.75 | +0.32 |
| 0.50-0.69 | 21 | 0.57 | 0.86 | +0.29 |
| 0.70-0.89 | 10 | 0.77 | 1.00 | +0.23 |
| 0.90-1.00 | 18 | 0.98 | 1.00 | +0.02 |
| **all** | **78** | **0.609** | **0.859** | **+0.250** |

**This is not comparable to the 3,144-fight baseline** (mean shown 0.584, observed 0.780, gap
0.197) - different seed block, 78 fights against 3,144 - so it is not claimed as a regression
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

## A crash that costs a run, but not its evidence

Seed 21204 died with **signal 11** and never wrote a `run_summary.json`:

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

The run's fight data survived in `run_events.jsonl`, because the harness streams events rather
than buffering them - which is the only reason this run is in the tables above instead of
being a hole. The loss is the aggregated summary and the terminal outcome. That is still
worth fixing: `run_summary.json` is what the batch driver reads, so a crashed run reports as a
missing result, and the crash itself is silent unless someone opens `godot.log`.

This is the most serious defect in the batch, and it is exactly the shape the request named -
`max team size on both sides`. No prior crash record exists in `docs/`.

### The reporting half is fixed

`Start-JevRun.ps1` reported a crashed run as a row of nulls - no chapter, no battle count, no
terminal - which is what made this run look like a hole in the batch. The harness already
writes a per-round `run_checkpoint.json` for exactly this case and `analyze_jev_run.py`
already falls back to it; only the runner did not.

It now does, and marks why. Re-running the result block from the edited script against the two
run directories on disk:

| run | terminal | chapter | battles | flags |
| --- | --- | ---: | ---: | --- |
| 21204 (crashed) | `in_progress` | 5 | 27 | `summary_is_partial: true`, `summary_source: run_checkpoint.json` |
| 21201 (completed) | `stage_stall` | 6 | 36 | `summary_is_partial: false` |

So an incomplete run is now legible as incomplete, with its data, instead of
indistinguishable from a run that produced nothing. The crash itself is untouched.

## Next

1. Reproduce and fix the 21204 crash itself. Nine-unit board, item pass, `remove_all` on
   `Repo` twice returning 0 both times, then `alloc_static` on a null pointer. The reporting
   half is done, so the next crash will not also cost the batch a row.
2. Build the concentrated-item probe described above and measure whether the ratio error is
   item effects.
3. Re-run this seed block once the crash is fixed; 21204 is not a result, it is a gap.
