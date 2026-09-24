# The heuristic lane's two deadlocks, fixed - 2026-09-24

`docs/harness_failures_heuristic_lane_2026-09-23.md` recorded four causes of run failure in the
heuristic lane and named an ordered fix list. Two of them are structural, and both are now
fixed and measured. This matters beyond tidiness: with the Jev lane blocked on TypeSafe credits
(`docs/mirror_body_count_fix_2026-09-24.md`), the heuristic lane is the only instrument that
can play a full game, and it was throwing technical failures at a rate of one every two fights.

## 1. The policy clicked shop slots the game had disabled

`_buy_best_two_stage_offer` scored offers on price and role fit and then clicked the winner,
without checking whether the game had disabled that card. A disabled slot - most often because
the bench is full and the purchase has nowhere to land - produced a failed click and a
technical failure instead of a decision.

It now skips a slot whose card is present and disabled. The check is deliberately conservative:
a slot whose card cannot be located is treated as selectable, so a scene-layout change can
never silently switch the policy to buying nothing.

## 2. A full board and a full bench is a deadlock

The fielding pass wants to bench a board unit in order to field a better one. When the bench is
already at `BenchConstants.BENCH_CAPACITY` (10) there is nowhere for the benched body to go, so
the drag fails and the run records a failure - every single round, forever.

Measured, it was one repeated pair: **"failed to bench vykos before fielding egress"**,
recorded every round from chapter 6 to chapter 10 in one run, 18 times.

It now declines the swap while the bench is full. That is the honest answer for a correctness
fix; the strategy fix - sell a bench body to make room - is a different change and is recorded
as open in `docs/depth_anatomy_2026-09-24.md`.

## Measured

Same seed, same lane, same profile, three configurations. Failures per fight is the honest
measure because a deeper run simply has more chances to fail:

| configuration | chapter | fights | failures | per fight | breakdown |
| --- | ---: | ---: | ---: | ---: | --- |
| baseline | 8 | 40 | 21 | **0.53** | contract 6, bench 9, disabled slot 6 |
| disabled-slot guard only | 10 | 52 | 26 | 0.50 | contract 8, bench 18 |
| **both guards** | 3 | 15 | **2** | **0.13** | contract 2 |

Both structural classes go to **zero**. The disabled-slot class disappears with the first fix
and the bench class with the second; the per-fight failure rate falls by three quarters.

The chapter figures are **not** an effect of this change and are not reported as one. The same
seed produced chapter 8, then chapter 10, then chapter 3 across the three runs, which is the
same-seed spread this project has measured at 1.75 chapters - and it is the reason the failure
*rate* is used above rather than the raw count.

## What is left

`competent contract market did not expose an actionable PASS choice`, twice per run, is the one
remaining failure class. The game does create a `ContractPass` button
(`combat_controller.gd`), and the harness waits up to three seconds for it, so this is a
timing or visibility race rather than a missing control - but the assertion requires the button
to exist **and** be enabled, and it is consistently failing at the same rate, so it is a real
open defect rather than noise. It is the next item in the lane.

## Gates

| gate | result |
| --- | --- |
| `NaturalBonkoTwoStageMainFlowSmoke` | no failures |
| `RGATesting` | 95 rows, 0 failed |
