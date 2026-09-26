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

`phase: 1` is PREVIEW, so the game was willing to show the market. That first read was still not
enough to name the cause - it only said the market was visible. The follow-up probe looked
*inside* it, and the answer was not what the first pass guessed:

```json
{"chapter": 5, "phase": 1, "pending_choice": true, "overlay_visible": true,
 "overlay_children": 2, "overlay_button_count": 4,
 "overlay_buttons": ["@Button@17535", "@Button@17536", "@Button@17537", "@Button@17538"],
 "contract_buttons": [],
 "market_stack": ["@Label@2295:Label:0", "ContractStatus:Label:0", "@VBoxContainer@2296:VBoxContainer:4"]}
```

The market was fully drawn and fully pressable: four buttons, and the choices container held four
children. But every button had been renamed to `@Button@<id>`. The authored `ContractChoice0..`
and `ContractPass` names were gone, and the rig searches by name - so it saw an empty market.
`contract_buttons: []` against `overlay_button_count: 4` is the whole bug in one line.

An earlier attempt at this called the market empty and rebuilt it on that assumption. That was
wrong, and the probe is what corrected it.

## The cause

`CombatController._show_contract_market()` replaced the previous chapter's choices with
`queue_free()`. A deferred free leaves the old buttons in the tree for the rest of the frame, so
the replacements are added alongside them, collide on name, and Godot renames the new ones to
`@Button@<id>`. The market keeps working for a player - the buttons are there and they press -
and becomes invisible to anything that looks for `ContractPass`.

That is also why it looked intermittent: the first market of a run builds into an empty
container and keeps its names, while every rebuild collides.

## The fix

* The market frees its old choices immediately, so `ContractChoice*` and `ContractPass` survive
  the rebuild.
* The rig stops depending on those names at all. It finds the market's choices by structure -
  through the named `ContractStatus` sibling - and the pacing rig takes PASS as a named button
  when present, otherwise the last pressable choice. A name can never blind the rig again.
* The rig answers a held-down Continue through a bounded gate resolver before calling it a
  failure, instead of pressing the dead button. The Jev rig answers contracts and legacy
  choices; the pacing rig answers contracts; the base harness has neither to answer.
* `contract_market_missing` records the phase, whether the overlay exists and is visible, its
  child count, the market's own stack, every button inside it, and Continue's state.

## Verification

`ContractMarketRecoverySmoke` builds a market, hides it, rebuilds it through the game's own
refresh, and asserts the authored names survive - then stages the recorded dead state and proves
one planning refresh restores a pressable market, PASS clears the choice, and Continue reopens.

Measured both ways:

| build | result |
| --- | --- |
| deferred free | **fails**: "rebuild left 4 market buttons with auto-generated names" - the same four the live run recorded |
| immediate free | passes |

A real four-seed Jev batch on the same seeds as the ten-run scorecard, at 8x:

| seed | before | after |
| --- | --- | --- |
| 21356 | **aborted**, ch 9, peak 40.9M, **5 technical failures** | `stage_stall`, ch 9, peak **1,005,828,633**, **0 failures** |
| 21359 | ch 6, peak 15.4M | ch 2, peak 126, 0 failures |
| 21353 | ch 7, peak 809,259 | ch 2, peak 36, 0 failures |
| 21358 | ch 6, peak 15.4M | ch 7, peak 565,575, 0 failures |

Seed 21356 resolves all eight chapter contracts now, where chapters 3, 5, 7 and 9 used to record
`contract_market_missing`, and it ends on a fight outcome instead of an abort. Across all four
runs: **0 technical failures**.

The spread did not collapse - one run reached a billion buckets, another died in chapter 2 on 36.
Jev samples its decisions, and the controller's own note already records the same seed going
chapter nine and then chapter one on identical code, so the wide spread is the rig, not a
regression.

Clean and unchanged: `ContractSystemVisualCapture`, `NaturalBonkoTwoStageMainFlowSmoke`,
`PhaseTransitionSmoke`. `PostCombatPlanningBeatSmoke` keeps its three result-card failures.

## Open

* **Chapter 10 is still unreached.** The depth record is chapter 9, and every deep run now ends on
  the chapter-9 boss gate rather than on a rig failure - which is what the depth ledger already
  said the wall was. That is now a design question, not a harness one.
* The three `PostCombatPlanningBeatSmoke` result-card failures contradict a newer passing
  smoke and are owed a rewrite.
