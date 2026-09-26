# Why a deep run stops, and which lane stops it - 2026-09-23

Requested directly: the rig should record when and why a run fails so the failures can be
read rather than inferred. This is the first pass that does it by cause, and it separates the
two lanes, because the answer is different in each.

## The run that prompted this

`heuristic` lane, seed 21102, grown profile (5991 Omens), speed 4x:

| | |
| --- | --- |
| terminal | `technical_failure` |
| final chapter / stage | **10 / 4** |
| battles | **63** |
| peak bankroll | 11 |
| technical failures | **41** |

Chapter 10 had never been reached before this run - the previous best in the whole record was
chapter 8. **This is an observation, not an attribution.** The heuristic lane is deterministic,
so the run is cleanly reproducible, but one run is not evidence that the boss-width change on
the same day caused it, and it should not be reported as though it were. What it does show is
that chapter 10 is reachable, which is the requirement that had never been demonstrated.

The run is also not a clean outcome. It ends on `technical_failure`, and the failures are the
interesting part.

## The 41 failures, by cause

| count | failure |
| ---: | --- |
| 12 | `natural fielding failed to bench luna before fielding marble` |
| 8 | `competent contract market did not expose an actionable PASS choice` |
| 10 | `competent shop slot N is disabled` / `natural two-stage buy 0 failed on slot N` |
| 11 | other one-off shop/fielding assertions |

## The bench is full, so the shop disables, so the policy stalls

The largest single mechanism is visible in the shop failure payloads, which carry full state.
Every one shows the same shape:

```
"bench":["mara","marble","mortem","morrak","berebell","velour","korath","grint","vykos","volt"],
"board":["bonko","rooket","teller","nyxa","kett","juno_vale","cinder","luna","sable"],
"cap":9, "chapter":7, "gold":4, "level":4
```

Nine board slots, all occupied; **ten units on a nine-slot bench**. The shop's slots are
therefore disabled by the game, and the policy keeps selecting a disabled slot and failing.

That is a direct answer to the question asked about bench hoarding: in this lane it is not
flexible-play econ, it is a full bench that the policy never clears. Once the bench is at
capacity the shop cannot accept a purchase and the run can no longer spend, which is also why
this run reached chapter 10 on a peak bankroll of 11.

**This is a heuristic-lane defect, not a Jev-lane one.** The same check over the 118 recorded
`jev` runs that have a summary finds **0** with a shop-slot-disabled or failed-buy failure -
Jev's controller sells, so its bench does not wedge. The other fielding failure is rarer there
too but not absent: `failed to bench X before fielding Y` occurs 11 times across 4 of the 118
Jev runs, against 12 times in this single heuristic run.

That matters for method as much as for gameplay. `docs/measurement_variance_2026-09-23.md`
names `JEV_MODE=heuristic` as the deterministic instrument a rig-side rule should be A/B'd
on. An instrument that deadlocks its own shop above chapter 6 cannot carry that load, so this
is a prerequisite for the comparisons the loop wants to run, not a cosmetic failure.

## What to fix, in order

1. **Sell from a full bench.** Before selecting a shop slot, if the bench is at capacity and
   the purchase would not combine, either sell the lowest-value bench unit or drop the buy.
   The failure payload already carries the ids needed to choose.
2. **Treat a disabled shop slot as a non-candidate.** Ten failures are the policy pressing a
   slot the game has already refused; that should be filtered before selection, and would
   have masked the real cause instead of pointing at it.
3. **The fielding swap at high chapter.** `failed to bench luna before fielding marble` repeats
   on a full nine-slot board at chapters 7-10. The invested-unit guard added earlier prevents
   the trade-down, but nothing covers "the board is full and the unit to remove cannot be
   identified", so the pair simply re-fails each round.
4. **The contract market PASS choice.** 8 failures, and the heuristic arm has no controller to
   answer the gate; the earlier fix only covered the first offer. Recorded, not yet fixed.

## Reproducing

```
.\tools\jev\Start-JevRun.ps1 -Lane deep -Mode heuristic -Seed 21102 -Starter bonko `
  -Speed 4 -LedgerOmens 5991 -ArtifactRoot E:\CodexStorage\task-artifacts
```

Then group `technical_failures` in the run directory's `run_summary.json`.
