# The harness no longer takes over the mouse - 2026-09-24

Reported directly: playing the game with the harness made the computer unusable for anything
else. That was accurate, and it was one line.

## Cause

`tests/visual/actual_run_loop_smoke.gd` - the base of the Jev and heuristic harness chain -
called `get_viewport().warp_mouse(position)` in three places:

```
_control_mouse_button    (drag lifecycle)
_control_mouse_motion    (drag lifecycle)
_move_mouse              (every click)
```

`warp_mouse` moves the **real OS pointer**. So a run grabbed the machine's cursor for its whole
duration, and the person at the keyboard could not use it. Added by `38fcef69` ("Fix loss retry
drag interactions"), which is why it was there.

Everything else in those helpers was already engine-level: the event carries `position` and
`global_position`, and `Input.parse_input_event` puts it into Godot's own input queue without
touching the OS. The warp was belt-and-braces on top of a path that did not need it.

## Fix

The three calls now go through `_warp_mouse_for_synthetic_input`, which **does nothing by
default**. `BWP_MOUSE_WARP=1` restores the old behaviour, and `Start-JevRun.ps1 -MouseWarp`
sets it.

## Verification

A full heuristic run with the warp disabled, against the previous run as a baseline:

| | chapter | battles | failures | click/drag failures |
| --- | ---: | ---: | ---: | ---: |
| with warp | 5 | 25 | 4 | 0 |
| **no warp** | 5 | 24 | 4 | **0** |

Every failure in both runs is the unrelated `competent contract market did not expose an
actionable PASS choice`. The synthetic path exercised everything that matters without moving the
cursor: 16 shop purchases, 11 items equipped, 2 board swaps, 2 repositioning passes.

So clicks, purchases, item equips, bench-to-board drags and repositioning all work through
Godot's own input queue, and the OS pointer is never touched.

Gates: `NaturalBonkoTwoStageMainFlowSmoke` clean, `RGATesting` 95 rows / 0 failed.

## Not changed

Other visual smokes still warp the cursor - `bar_items_traits_capture`, `BoardReviewCaptureHost`,
`drag_global_release_smoke`, `loss_screen_smoke`, `rapid_shop_pressure_smoke`,
`shop_card_hover_smoke`, `stats_panel_click_smoke`. They are one-shot capture and hover tests
rather than long-running game loops, so they are not what makes the machine unusable - but the
same one-line treatment is available for them if it turns out to matter.
