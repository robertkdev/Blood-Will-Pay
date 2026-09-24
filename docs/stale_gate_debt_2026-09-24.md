# Gate debt: what is red, and why - 2026-09-24

Four suites are failing for reasons that predate the work in progress. Each was attributed by
shelving the change under test and re-running, not by assumption. They are collected here
because they are the honest picture of the gate state, and because three of them are the same
kind of rot: **an assertion that matches on user-visible copy.**

## `CompactViewportVisualAuditSmoke` - 78 failures

Three clusters, none of them new:

| cluster | cause |
| --- | --- |
| "empty item slot ... lacks a ready-pocket docket" | asserts `docket.text.contains("READY")`. The planning-text pass reduced that docket to the slot number and moved the state to `pocket_status` meta, so the assertion is reading copy that was deliberately removed. |
| "wager outcome metadata omitted Win / Wager / After: / W / L" | asserts the old wager-summary wording ("Wager 1 bucket • Win 24-54% • After: W10/L8"), which the same pass replaced with the bare numbers. |
| "HUD surface ... bottom edge is outside viewport", "survival landmark is occluded by the deployment badge" | real layout findings at compact and scaled viewports. These are the ones worth actually fixing. |

Verified identical with and without the directive change made alongside this note: 78 either way.

## `PostCombatPlanningBeatSmoke` - 3 failures

All three sit in the result-card block, which was written for a layout that swapped to a
full-field combat screen. `PhaseTransitionSmoke` - which passes - asserts the opposite about the
same nodes (`BattleResultAftermath` must be **hidden** behind the result card, "result replaced
the finished battlefield"). That block needs a rewrite against the shared-field design, not a
patch.

## `UIThemeSmoke` - 5 failures

Two are stale copy from the planning-text pass (`"Opening wager: 1 blood"` versus the shipped
`"Opening wager: 1 bucket"`, and a deferred-betting tooltip sentence that has been reworded).
Three are real: cell-seam contrast, a missing weighted non-colour major-line cue, and a held
docket that must contain `HELD` after the docket was reduced to a number.

## `BettingEconomySmoke` - 6 failures

All six are economy assertions (`reset_run should start with configured starting gold`, the
all-in escrow and payout chain). They do not reference the odds or the shelf controls, and they
are identical at the commit before the current work. Most likely the live account the Jev
batches spend against - they run with `-LedgerOmens -1`, which leaves the live profile alone but
still plays it.

## `ArenaPressureVisualSmoke` - 1 failure

Reduced-motion collision composition. Unchanged with the screen backdrop reverted.

## What this says

Copy-matching is the single largest source of false red in this project. Three of these four
suites are failing on wording that was intentionally removed. Where a control matters, the fix
is to assert its **identity or state** - a node name, `pocket_status`, `cache_slot_state` - not
the sentence it happens to be showing. The shelf action buttons were given stable names for
exactly this reason, and `_button_for_action_text()` now resolves them that way.
