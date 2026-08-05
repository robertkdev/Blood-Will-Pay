# Interaction latency contract

Gamble Battle is a desktop playground: once an input is accepted, the player
should see a state change immediately and should not have to guess whether a
rapid second input was lost or applied twice. This contract separates the
first visible response from the heavier work required to settle the next
playable state.

| Interaction | Visible-response budget | Settled-state budget | Observable response |
| --- | ---: | ---: | --- |
| Result dismissal | 16.7 ms (one 60 Hz frame) | 400 ms | Result scrim/card hides, then planning or terminal loss is stable |
| Shop purchase, reroll, lock, Buy XP | 100 ms | 250 ms | Card/progress/lock/economy feedback changes |
| Drag/deploy | 100 ms | 250 ms | Drag lifecycle or board placement feedback changes |
| Menu open/close | 100 ms | 250 ms | Overlay visibility and pause state change |
| High-frequency repeat guard | 50 ms | N/A | Repeated accepted input is consumed without duplicate settlement |

`33.4 ms` is the frame-stall warning threshold. The result probe also allows
`50 ms` for its first process-frame observation because the MCP editor lane can
schedule that observation on the second display frame; the player-facing hide
timestamp remains governed by the stricter `16.7 ms` budget. A response is measured from
the point the player-facing handler accepts the input, not from an earlier
mouse-down or a test harness call. A visible response is the first observable
render/state change. A settled response is the point at which the next legal
player action can be taken without a second cleanup or a stale view.

## Results-screen defect

The old skip path called `_on_intermission_finished()` directly from the
result input handler. That method synchronously exited the arena, finalized
combat, rebuilt the preview, refreshed all views, settled the economy, and
refreshed the shop. The card therefore could remain visibly stuck until all of
that work completed.

`CombatController` now hides the result banner in the accepted-input handler,
records the visible-response timestamp, and crosses a two-step process-frame
barrier before running the existing post-combat settlement. The barrier is
deliberately small: it gives the hide state a render opportunity without
changing outcome, progression, odds, shop costs, or economy rules. A finish
guard and repeat counter make rapid Enter/Space input idempotent with respect
to post-combat settlement.

The latest fresh Main runtime run (captured at `2026-08-02 02:01:13`) measured
`3.197 ms` accepted-input to result hide, `20.187 ms` to the first
process-frame observation, `202.968 ms` of deferred cleanup, and
`236.262 ms` to stable planning. Eight repeated accept inputs were consumed
and cleanup ran exactly once. The same run measured `0.197 ms` for lock
feedback, `19.050 ms` for purchase feedback, `1.298 ms` for drag/deploy
feedback (`146.879 ms` settled), and `1.052 ms` for the menu transition.
The before/after boundary is observable even though the old path had no
timestamp telemetry: before the fix, `_skip_result_hold()` entered the full
cleanup synchronously, so no player-facing hide could render until that work
returned; after the fix, the hide is recorded before deferred cleanup. Earlier
fresh runs reached `2.568 ms` visible response with `219.983 ms` cleanup and
`249.513 ms` settled, and `4.655 ms` visible response with
`302.436 ms` cleanup and `353.235 ms` settled. Those measurements are why
the settled budget is bounded at `400 ms` rather than treated as an
unmeasured assumption.

## Evidence and reusable probe

Run `tests/visual/InteractionLatencySmoke.tscn` through the Godot MCP against
the real `scenes/Main.tscn` entrypoint. The probe writes:

- `outputs/visual_debug/interaction_latency/interaction_latency_manifest.json`
- timestamped `VisionSnapshot` JSON/software captures for the result card and
  the first frames after dismissal

`visual-harness-interaction-latency.yaml` is the VDH scenario. Its capture
command packages the already-fresh MCP captures into the VDH `captures.json`
shape without starting a second capture writer; this keeps the temporal
filmstrip and the authoritative viewport files from racing each other.

The manifest distinguishes the input path, accepted timestamp, immediate
hide, first-frame response, deferred cleanup duration, settled duration, repeat
count, and cleanup count. On the current Main runtime, the measured cleanup is
about `302 ms` and the stable planning phase is about `353 ms`; the `400 ms`
settled budget leaves a bounded runtime margin while the visible result hide
still targets one frame. It also probes shop, drag/deploy, and system-menu feedback
when the real run reaches planning. Software snapshots are control-tree
evidence; an authoritative framebuffer verdict still requires a valid MCP
editor/game capture lane.

Do not call this contract green from logs alone. Record the measured values
and capture kind from a fresh runtime run, inspect the filmstrip, and keep any
framebuffer or MCP-lane blocker explicit in the handoff.
