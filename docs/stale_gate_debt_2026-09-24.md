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

## `UIThemeSmoke` - clean, and it was 5

Fixed in `5d62facf`. Three were the usual copy rot: the forced opener had to say `Opening wager:
1 blood` (it says `1 bucket`), the bet row had to contain a tooltip sentence that has since been
reworded, and a held docket had to contain `HELD` after the docket was reduced to a slot number.

The other two were worse than stale - **they contradicted another passing gate.** This suite
demanded `terrain_seam_alpha >= 0.27` while the combat shell gates the same meta at `0.15-0.22`.
The authored value is `0.21`, so the combat gate matched the game. And it demanded
`major_seam_non_color_weight >= 3`, a number the design never used; the cue is the drawn weight,
two pixels for major seams against one for minor. Both now assert the contract the game actually
keeps, which is the first time those two suites have agreed.

## `BettingEconomySmoke`, `NaturalBuyXPVisualSmoke`, `BuyXPTransactionalFeedbackSmoke` - clean

Eight failures across three suites, fixed in `d17b4ef2`, and **one cause**: the starting reserve
is no longer a constant.

`Economy.reset_run()` sets `STARTING_BLOOD_BUCKETS + starting_blood_bucket_bonus(...)` - the
Debtor's Mercy Edict pays a first bucket and one more per 25 Ledger ranks, so the reserve keeps
growing with the account. That permanent growth across runs is the point of the campaign and the
user asked for it. Every absolute gold expectation went stale the moment the account played.

| suite | what it assumed |
| --- | --- |
| `BettingEconomySmoke` (6) | `reset_run` lands on `STARTING_GOLD`. It now computes the expected value the way the game does; its five dependent assertions (escrow, captured start, payout, remembered preferred bet, all-in loss) followed. |
| `NaturalBuyXPVisualSmoke` (1) | the guaranteed opener lands on exactly 6 gold. The pool is not a fixed multiple, so the account-independent contract is that the opener paid and cleared the safe-gold threshold. |
| `BuyXPTransactionalFeedbackSmoke` (1) | the denial sentence has been reworded. Now asserts a refusal that names the action and the reserve floor. |

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

Three more went to zero the same way, and between them they show every face of the problem:

* `CompactViewportVisualAuditSmoke` - copy rot hiding a real regression of mine and a real
  layout overlap.
* `UIThemeSmoke` - copy rot hiding two gates that disagreed about a value the game had settled.
* The three economy suites - no copy rot at all, just **absolute expectations in a game that
  now grows**. The account starts richer the more it has played, which is the feature.

A gate that reads deleted copy cannot notice any of that. A gate that reads the contract can.
What is still red is down to two things and both are understood: `PostCombatPlanningBeatSmoke`'s
result-card block, which contradicts a newer passing smoke and needs a rewrite, and
`ArenaPressureVisualSmoke`'s single reduced-motion failure.
