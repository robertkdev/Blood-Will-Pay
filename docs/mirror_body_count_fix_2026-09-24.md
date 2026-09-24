# The mirror fields one fewer body - 2026-09-24

The depth review's sharpest finding is that the player's win rate is a step function of the
body-count difference: even bodies 53%, one extra body 92%, six extra 100%, over 2,474 first
attempts (`docs/body_count_is_the_win_rate_2026-09-24.md`).

The mirror is the single most common run-ender in the game - 65 of 145 recorded runs - and it
is a coin flip *by construction*, because it copies the player's own board and therefore always
has the same number of bodies. This applies the finding to it.

## What changed

`MirrorBoardStore.mirror_indices(ch)` returns the snapshot's entries with its **weakest body
dropped**, rated by the same `CombatPowerModel` the generator fits against, at the level the
snapshot recorded. `MirrorRule.on_pre_spawn` builds the mirror's spawn list from it, and
`apply_snapshot_to_units` uses the same index list so the surviving bodies keep their own
snapshots. A one-body snapshot is left alone: an empty mirror is not a fight.

This is the lever the table supports. The previous attempt cut the mirror's **stats** by 20%
and was reverted, because it left the body count alone and a same-size mirror stays a coin flip
no matter how weak its units are.

## Gates

| gate | result |
| --- | --- |
| `EndlessRuntimeIntegrationProbe` | no failures |
| `RGATesting` | 95 rows, 0 failed |

The probe now asserts three things rather than one, and deliberately not all through the store's
own helper:

- the mirror fields exactly `snapshot - 1` bodies;
- the ids it spawns are the snapshot's minus the dropped one;
- **independently**, the dropped body is the one `TeamOddsEstimator.unit_rating` scores lowest.

Without the third, the first two only prove the store is self-consistent.

## Not verified live, and why

The live confirmation is a mirror first-attempt win rate that should move from roughly 57%
toward the table's 92% for a +1 body fight. **That measurement could not be taken**: the Jev
controller is failing on every run with

```
TypeSafeAPIError 402
billing_error: "Your organization has no available TypeSafe API credits. 
Please add more credits and/or set up auto-reload at https://console.typesafe.ai/settings/billing"
```

Three consecutive runs died on it at the very first decision, ~210ms in, having recorded zero
decisions. It ends the run as `controller_lost` after about thirteen minutes each, so the batch
was stopped rather than left to burn wall clock.

This is an external blocker on the Jev lane specifically. The heuristic lane needs no API, and
every deterministic probe still runs, so the rest of the loop is unaffected - but **the Jev
acceptance runs the objective depends on are stopped until credits are added.**

Because of that this change is **shipped on deterministic evidence only**, which is a lower bar
than everything else in this loop has had to clear, and it is flagged as such rather than
presented as confirmed. It is kept rather than reverted for three reasons: the relationship it
rests on is measured across 2,474 fights, it is the only change available that addresses the
single largest run-ender, and it implements a requirement the user stated explicitly. The
first thing to do once credits are restored is the mirror win-rate measurement; if it does not
move, this revert is the first commit of that turn.

## Also recorded

A `controller_lost` run costs about thirteen minutes of wall clock and produces no game data.
Whatever the per-run timeout is doing after the controller stops, it is worth failing fast on a
402 - the controller already knows and records `stopped: api_error` with the status in
`controller_summary.json`, so the harness could stop the run immediately instead of waiting.
