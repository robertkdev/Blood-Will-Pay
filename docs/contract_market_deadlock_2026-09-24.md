# What actually ended the chapter-9 run - 2026-09-24

Seed 21356 is the deepest Jev run on record: chapter 9, 47 battles, 40.9M buckets. It ended
`aborted` with five technical failures rather than a fight outcome. The scorecard note called
this the highest-value defect because it costs the best runs.

## The recorded reason was wrong

The prior note guessed "buying a champion contract opens an unhandled ChampionTarget overlay
that leaves the Continue button disabled". The run's own events refute it: **every**
`contract_resolved` in that run is `ContractPass`. The rig never bought a champion contract, so
it never reached the bearer pass.

## What the events show

Eight `contract_market_missing` events, two each at chapters 3, 5, 7 and 9, and four resolved
contracts at chapters 2, 4, 6 and 8. The run died at chapter 9 round 4 with, in order:

```
natural two-stage chapter 9 round 4 continue button disabled   (x3)
natural two-stage Start Battle did not enter combat
JevRunHarness: campaign stopped  fight_result=start_not_entered
```

The rig pressed a dead Continue three times and then aborted the deepest run it had.

## The state, finally measured

The event used to carry only a chapter number, which is why the reason stayed a guess. It now
carries the market's state. Reproduced by replaying 21356:

```json
{"chapter": 3, "phase": 1, "pending_choice": true,
 "overlay_found": true, "overlay_visible": true, "overlay_children": 2,
 "layer_found": true, "continue_disabled": true}
```

`phase: 1` is PREVIEW, so the game was willing to show the market. The overlay existed and was
visible, the choice was still pending, Continue was disabled - and no `Contract*` button was
anywhere on screen.

## The cause

`CombatController._show_contract_market()` returned early whenever the overlay was already
visible:

```gdscript
	if _contract_overlay.visible:
		return
```

So a market that had lost its choices could never be rebuilt. The overlay stayed up with an
empty choice list, Continue stayed disabled, and nothing on screen could clear it - a dead end
for the rig and for a player who lands in the same state.

## The fix

* The market rebuilds when it is visible but has nothing to press
  (`_contract_overlay.visible and _contract_choices.get_child_count() > 0`).
* The rig answers a held-down Continue through a bounded gate resolver before calling it a
  failure, instead of pressing the dead button. The Jev rig answers contracts and legacy
  choices; the pacing rig answers contracts; the base harness has neither to answer.
* `contract_market_missing` now records the phase, whether the overlay exists and is visible,
  its child count, the market's own stack, and Continue's state.

## Verification

`ContractMarketRecoverySmoke` stages the exact recorded dead state - overlay up, choice pending,
Continue held down, choices cleared - then proves one planning refresh restores a pressable
market, that PASS clears the choice, and that Continue reopens.

Measured both ways:

| build | result |
| --- | --- |
| without the market repair | **fails**: "a visible but empty contract market stayed dead through a planning refresh" |
| with it | passes |

Clean and unchanged: `ContractSystemVisualCapture`, `NaturalBonkoTwoStageMainFlowSmoke`,
`PhaseTransitionSmoke`. `PostCombatPlanningBeatSmoke` keeps its three result-card failures.

## Open

* **The replay is not a faithful deep-run reproduction.** It substitutes unrecorded decisions,
  so it diverges - one attempt reached chapter 3 and reproduced the dead market, a second died
  in chapter 1. A real chapter-10 Jev run is still what proves the fix on the deep path.
* The three `PostCombatPlanningBeatSmoke` result-card failures contradict a newer passing
  smoke and are owed a rewrite.
