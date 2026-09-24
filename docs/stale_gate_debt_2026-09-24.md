# Gate debt: what is red, and why - 2026-09-24

The suites below are red for reasons that predate the work in progress. Each was attributed by
shelving the change under test and re-running, not by assumption. They are collected here
because they are the honest picture of the gate state, and because most of them are the same
kind of rot: **an assertion that matches on user-visible copy.**

## `CompactViewportVisualAuditSmoke` - clean, and it was 78

Fixed in `92d18915`. What it took is the useful part, because it is the pattern in the rest of
this file:

| cluster | n | what it was |
| --- | ---: | --- |
| "empty item slot ... lacks a ready-pocket docket" | 15 | copy rot - demanded `docket.text.contains("READY")` after that word was replaced by the slot number. Now asserts the number and the `cache_slot_state` meta. |
| "wager outcome metadata omitted Win / Wager / After: / W / L" | 50 | copy rot - demanded the old wager-summary wording. Now asserts a percent range and a win/loss comparison. |
| "shop card ... lacks a visible framebuffer gutter", "BottomStorageArea bottom edge is outside viewport" | 9 | **a real regression of mine.** A 40px action icon made the shelf bar tall enough to push the bottom storage area 8px past a 480px viewport at the maximum-scale tier. The icon is 22 now. Isolated by reverting only the icon change: 4 failures without it, 13 with it. |
| "survival landmark is occluded by the deployment badge" | 4 | a real overlap, one to nine pixels at every scaled tier. The assertion now prints both rects, and the player-side plate is lifted to 0.76-0.89 of its half. |

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

The compact audit is the case study: 65 of its 78 failures were copy-matching, so they hid a
genuine 9-failure regression of mine and a 4-failure layout overlap. Clearing the rot first is
what made the real defects visible.
