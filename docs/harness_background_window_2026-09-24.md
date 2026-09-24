# The harness runs in a background window - 2026-09-24

Reported directly: playing the game with the harness made the computer unusable, and specifically
"make jev simulate clicks without actually using my mouse".

## What was still wrong after the warp fix

`e5178fc6` stopped the harness warping the OS pointer. Measured, that half holds: with the warp
off the real cursor never moves at all (numbers below).

The window itself was the other half, and it was untouched. `project.godot` ships
`window/size/mode=3` - fullscreen - and the harness only ever called
`DisplayServer.window_set_size(...)`, which does nothing to the window mode. So every run still
covered a whole monitor, grabbed the foreground, and the person at the keyboard could not use the
machine for the length of the run.

There was also a live example of the consequence: a run from **2026-09-22 14:58** was still
sitting borderless over a whole display two days later. Its orchestrator was gone; only the
`godot-mcp` node server that spawned it remained, holding the window. It was measured
(`GetWindowRect` = 1922x1080 at `(0,-1080)`), then stopped.

## Why the obvious fix does not work

Leaving fullscreen cannot be done with `window_set_mode`, from the state the project boots in.
Probed on the pinned Godot 4.5 build:

```
S0 boot                 mode=3  size=(1920,1080)      # fullscreen, as shipped
S1 after_set_mode(0)    mode=4  size=(1920,1080)      # want WINDOWED, get EXCLUSIVE_FULLSCREEN
S2 .. S6 (70 frames)    mode=4  size=(1920,1080)      # and it stays there
```

Setting `WINDOW_FLAG_BORDERLESS` is what actually drops the window out:

```
A_borderless_size       mode=0  size=(956,540)  pos=(900,400)
```

## The fix

`tests/visual/actual_run_loop_smoke.gd` grows `_park_harness_window()`, called from `_ready()`:

* borderless, windowed, `WINDOW_FLAG_ALWAYS_ON_TOP` off, `WINDOW_FLAG_NO_FOCUS` on;
* 960x540, parked in the corner of the current screen;
* `CONTENT_SCALE_MODE_CANVAS_ITEMS` + `CONTENT_SCALE_ASPECT_KEEP` + `content_scale_size`
  1920x1080, so the **logical viewport stays exactly 1920x1080**. The game's layout and the
  coordinates the synthetic events carry are unchanged; only the OS window shrinks.
  (`KEEP`, not `EXPAND`: `EXPAND` let the shaved pixels move the logical viewport to
  1920x1084.)

Only the long play lanes ask for it (`_harness_compact_window()` returns true in
`jev_run_harness`, `first_shop_choice_quality_smoke`, `random_later_shop_progression_smoke`,
`natural_bonko_two_stage_main_flow_smoke`, `longitudinal_pacing_harness`). Everything else is
left exactly as it was, because the smokes that resize the window to probe responsive layouts
need the logical viewport to follow the window, and content scaling would stop that.

`BWP_HARNESS_WINDOW=fullscreen` (or `Start-JevRun.ps1 -Window fullscreen`) restores the old
presentation.

`Start-JevRun.ps1` also clears an MCP-spawned Godot still attached to this project before
starting, so a run that outlives its runner cannot pile up. It only touches processes whose
parent is a `godot-mcp` server, so a game the person launched themselves is never killed.

## Evidence

A full heuristic lane (`-Lane deep -Speed 2.0`), sampled from outside Godot every 120 ms for the
whole run:

| measurement | result |
| --- | --- |
| distinct OS cursor positions across 2,184 samples | **1** (X=1210, Y=501) |
| harness's own record | `cursor_max_shift_px: 0` over 2,153 samples |
| run window | 960x540 for 2,114 samples |
| `logical_viewport` | `(1920, 1080)` exactly |
| `os_window_size` | `(958, 540)` |
| click/drag failures | 0 |
| play vs the fullscreen baseline | 10 battles, ch 2-5, 0 failures (baseline: 11 battles, ch 2-4) |

Gates: `NaturalBonkoTwoStageMainFlowSmoke` exit 0, 0 error lines.

## Known limits

**A few seconds of boot fullscreen.** Godot presents the boot window before any scene code runs,
so a run still flashes exclusive fullscreen for ~4 s (34-36 of the 120 ms samples) while the
project loads, then parks. Removing that needs `--windowed` at spawn, and the `godot-mcp`
`run_project` schema takes only `projectPath` and `scene`, so it cannot be passed from
`run_jev_scene.mjs` without changing that shared tool.

## Not changed

The one-shot visual smokes keep their historical presentation (they are short, and the
window-resizing ones depend on it). `PostCombatPlanningBeatSmoke` is currently failing 8
assertions, including `combat shell lacks an explicit survival objective signal` - it asserts
`objective.text.contains("SURVIVE")` while the planning-text pass in `4b87056a` shipped `"LIVE"`.
That failure is deterministic and **identical with the window left untouched**, so it predates
this change and is not caused by it.
