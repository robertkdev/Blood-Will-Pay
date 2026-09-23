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

## 3. The rig offers item equips to units with no free slot (open)

The item decision can select a unit whose three item slots are full. The game blocks the
equip, the rig selects it again, and the component stays in the inventory.

Evidence: 204 `[Items] equip blocked: no_slot` lines across 8 of 254 recorded runs, all
of them `no_slot`. One run logged the same blocked equip on the same unit repeatedly.

Effect: a wasted decision and an unequipped component, in the runs where the board is
strongest and the item most matters. Not yet fixed - the fix belongs in the equip
candidate list, which should not offer a saturated unit.

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
