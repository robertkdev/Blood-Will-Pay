# Harness defects that were costing runs - 2026-09-23

The rig is judged alongside the game, because a run can fail either way. This is the
list of failures that were the rig's, found by reading the two-arm batch and the
previous 240 recorded runs. Two of them killed runs that were winning.

## 1. The transient-failure retry could never work (fixed)

`jev_run_controller.py` caught an exception from the first TypeSafe call and fell back
to `client.judge(...)`. The pinned SDK (0.6.0) has no such method - `TypeSafeClient`
exposes only `close`, `models` and `system_one` - so the fallback raised `AttributeError`
on its own first statement.

Evidence: 15,729 recorded decisions, **zero** ever logged as `retried`. Four runs ended
in `api_error`, two of them with `AttributeError` as the reported cause.

Cost: seed 21008 reached chapter 6 round 4 with 1,143 buckets and a full nine-body
board, lost that stage, and then died on `controller_lost` when three consecutive
planning decisions timed out. The run was thrown away by the rig.

Fix: the call takes the SDK's own `RetryPolicy`, which covers 5xx statuses, connection
errors and timeouts. Other exceptions still propagate.

## 2. The sweep ate the rig's planning window (fixed)

The planning countdown advances on the engine's scaled delta, so a sweep at 8x burns
the 120-second window eight times faster in wall-clock terms. The rig needs one TypeSafe
round-trip per decision; a shop with a dozen offers needs more wall time than the sweep
leaves for it. The beat then closes, Start Battle is never pressed, and the harness
aborts.

Evidence: seed 21009 at rank 67 recorded `planning_seconds_at_start` 100.04 followed by
16 decisions and `planning_seconds_at_end` 0.0, then `start_not_entered`, three
`continue button disabled` failures, and `harness_abort` at chapter 6 with 23,491
buckets. Both of the deepest runs in the batch died this way, at the same stage.

This is worse than a wasted run: it biases every depth measurement against rich runs,
because more buckets means more rerolls and purchases, which means more decisions.

Fix: the harness scales the planning window by the sweep factor, so the rig gets the
wall-clock budget a player gets. The lift is absolute, not multiplicative - the setter
runs once per beat, and compounding it produced a 251,658,240-second window during
verification.

Verified on the failing case: seed 21009 at rank 67 went from a chapter-6 abort with five
technical failures to a legitimate `stage_stall` at chapter 5 round 5 with zero technical
failures, 29 battles and a 1,118-bucket peak.

## 3. The rig equipped the wrong copy of a unit (fixed)

The item decision generated a candidate per unit id, but a board can hold two copies of
one unit: 305 of 438 recorded fight snapshots do. The saturated copy was correctly skipped
when candidates were built, and then the equip was applied to the **first** board unit with
that id - which was often the saturated one. The game refused it with `no_slot`, the
component stayed in the inventory, and the run paid a decision for it.

Evidence: 204 `[Items] equip blocked: no_slot` lines across 8 of 254 recorded runs, and a
board with two Bonkos is the ordinary case, not the exception.

Fix: candidates carry the unit instance key as well as the id, the id is unique per copy,
the second copy is labelled `id#2` so the choice is legible, and the equip resolves on the
instance that was priced.

Verified live on the seed that produced the most refusals (seed 21002, previously 48):
`equip blocked` count **0**, and 6 of 6 `item_equipped` events landed with `ok: true`.

## 3b. Fielding a preferred unit can fail to bench its replacement (open)

Found while verifying the item fix, on the live run above. `_field_preferred_units` decided
to bench `knoll` for `grint` at chapter 3 round 4, and the drag to the bench failed three
times in a row, which the harness records as three technical failures. The run then stalled
on that same stage.

Evidence: `chapter 3 round 4 natural fielding failed to bench knoll before fielding grint`
three times, and no `fallback board_to_bench route_ok=` line, so the failure is before or
inside the route fallback rather than a refusal from the game. The board at that point held
two Bonkos and the bench held two Grints and a Knoll, so id-keyed view lookup is the first
thing to check.

This is in the shared base harness (`natural_bonko_two_stage_main_flow_smoke.gd`), so it
affects every smoke test that fields units, not only the Jev rig.

## 4. The wager rule is more cautious than the evidence (open)

The policy sizes the stake by Kelly at the measured band rate and caps all-in at a Kelly
share of three quarters. Measured over 759 positive-EV first attempts, the median stake
is 75% of the bankroll at 1-3 buckets but falls to 58% at 64+ buckets, and only 31% of
positive-EV fights are staked in full. Combined with displayed odds that understate the
true win rate by 20 points, this is the recorded "buckets sitting idle while ahead"
behaviour.

## 5. One harness boot defect (fixed)

The Ledger-depth work declared `AccountProfileStoreScript` in a class that already
inherited it, which failed the first run of the fresh arm at `Parser Error` before the
run started. Fixed by using the inherited constant.
