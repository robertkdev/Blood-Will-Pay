# Jev play run and findings - 2026-09-21

Jev (TypeSafe `jev-1.13.0`, requested `jev-latest`) played Blood Will Pay through
the real `scenes/Main.tscn` runtime on the current `main` checkout
(`71c588f6`, plus the onboarding and import passes described below). This report
records what was built, the rules Jev played by, what happened, and what the run
says about the game.

> **Corrections applied after the third pass.** Parts of this report described work
> that was later reverted or measured to be unsupported. Where that happened the
> original text is corrected in place and the reason is stated, rather than left
> standing:
>
> - The chapter-2 breadth ladder described as a change is **not shipped**. Commit
>   `10010944` made it opt-in after a paired comparison showed it did not lower the
>   requirement, and the shipped ladder was restored. Anything below that reads as
>   "the shape fix removed the cliff" is superseded.
> - This report's reserve-target finding asserted a 75-stake-unit planning target
>   taken from a simulation sweep. That sweep is not a measurement of this build's
>   income, and nothing in the game asks for 75 units. The claim is withdrawn.
> - The level-versus-breadth percentages quoted here have no checked-in artifact
>   behind them and have not been re-verified on the current build.
> - A loss in one run is recorded here as an outcome, not as a defect.

## What plays the game

| Piece | Path | Role |
| --- | --- | --- |
| Agent harness | `tests/agent/JevRunHarness.tscn` | Drives `scenes/Main.tscn` with the same clicks and drags a player makes, asks the controller at each planning decision, executes the answer |
| Jev controller | `tools/jev/jev_run_controller.py` | Long-lived TypeSafe client over a file bridge; writes `decisions.jsonl` with model, answer, confidence, and timings |
| Rules | `tools/jev/policy/jev_run_rules.json` | Single source of truth, injected into every question; prose form in `docs/agent-workflows/jev-run-rules.md` |
| Runner | `tools/jev/run_jev_scene.mjs` | Supervises the run through the configured Godot MCP runner (`godot-mcp`), logs stdout/stderr, stops the process |
| Entry point | `tools/jev/Start-JevRun.ps1` | One command: starts the controller, runs a campaign, stops both |
| Analysis | `tools/jev/analyze_jev_run.py` | Deterministic report and findings from the run directory |

Decisions routed to Jev: starter choice, every shop purchase, every level
purchase, the wager, and the chapter contract. Deployment, fielding order, and
rerolls stay with the harness's documented rule-based helpers so a Jev run and a
heuristic run can be compared on the same seed. Combat is not player-controlled
(`CombatController.auto_combat` defaults to true), so these planning decisions are
the whole of play.

## Playing the real game, not a model of it

The rig drives the shipped build, and the transcript says so. Every run records its
own fidelity in `run_start`:

| Fidelity fact | Value |
| --- | --- |
| Entrypoint | `scenes/Main.tscn` (`player_facing_entrypoint: true`) |
| Input path | `engine_parsed_mouse_events` - clicks are `InputEventMouseButton` events pushed through `Input.parse_input_event` and `Input.flush_buffered_events`, so hit-testing, focus, disabled state, mouse filters and drag lifecycle all run |
| Handler fallback | `false` - the base harness can fall back to emitting a button's `pressed` signal directly; that fallback is disabled here, so a click that misses the control fails loudly instead of passing |
| Drag lifecycle fallback | `false` - drags must survive the real mouse sequence |
| Combat speed | `time_scale 1.0` (shipped) |
| Planning beat | `real_planning_timer: true` - the shipped 120-second countdown runs, and it auto-starts the fight if it expires |
| Shop rolls | unseeded by default (`shop_seed_explicit: false`); pass `-Seed` only to make two runs comparable |

Systems exercised are the real ones: the `Shop`, `Economy`, `Roster` and `Items`
autoloads, the real chapter/stage progression, the real `CombatManager` and
`CombatEngine` (its own log lines are what the transcript records), the real mirror
snapshot and the real chapter-contract market.

What still is not the shipped player experience: deployment, fielding order and item
equipping are executed by the harness's rule-based helpers rather than by Jev, and
the run reads structured state (buckets, offers, traits) instead of pixels, so it
measures economics, decisions and pacing - not first-time visual comprehension. A
116-second planning beat is now part of the recorded evidence, which is a real
pacing signal the earlier fast runs could not produce.

## Rules Jev played by

1. Keep a planning reserve; never spend to zero before a fight.
2. Buy selectively: a full-shop buyout and an indiscriminate purchase habit are the losing baseline.
3. Wager only above the quoted break-even: `CREEPS 1.5x` -> 66.7%, `NORMAL`/`MIRROR 2.0x` -> 50%, `ELITE`/`EVENT 2.5x` -> 40%, `BOSS 3.0x` -> 33.3%.
4. Two frontline bodies before damage, at most one support, duplicates beat another body when the board is full.
5. Buy level when it converts to board capacity.
6. Chapter contracts are optional; take one only when the price stays in the reserve.
7. Treat the shown win-odds range as a readiness signal, not as the wager price.
8. Never start a fight with the same board that already failed.

## Runs

All runs use seed `4401` and the shipped economy. `heuristic` is the harness's
built-in policy with no model in the loop.

| Run | Starter | Terminal | Final stage | Battles | Peak bankroll | Decisions |
| --- | --- | --- | --- | ---: | ---: | ---: |
| `jev-campaign-seed4401-20260921-093554` (after the fixes) | bonko | target reached | chapter 2 round 4 | 12 | 6 | 40 |
| `heuristic-campaign-seed4401-20260921-093053` (after the fixes) | bonko | target reached | chapter 2 round 4 | 10 | 7 | - |
| `jev-campaign-seed4401-20260921-082105` (final Jev run) | brute (Jev's choice) | stage stall | chapter 2 round 2 | 9 | 6 | 41 |
| `jev-campaign-seed4401-20260921-075736` | brute | loss | chapter 1 round 5 | 5 | 6 | 15 |
| `heuristic-campaign-seed4401-20260921-080256` | brute | loss | chapter 1 round 5 | 7 | 6 | - |
| `heuristic-campaign-seed4401-20260921-080609` | bonko | target reached | chapter 2 round 4 | 9 | 9 | - |
| `jev-campaign-seed4401-20260921-073802` (superseded rig) | brute | stage replay loop | chapter 2 round 3 | - | 6 | 74 |
| `jev-campaign-seed4401-20260921-081030` and `-081535` | bonko | loss | chapter 1 rounds 3 and 4 | 4 / 5 | 6 | 7 / 10 |

Raw runs, observations, decisions, and generated reports:
`E:\CodexStorage\task-artifacts\gamble-battle-jev-run-20260921\runs\`.

## Fixes in this change

**1. Forced results are now decisive (`scripts/game/combat/combat_engine.gd`).** Two
things were wrong on the timeout path. `_combat_timeout_outcome()` scored the fight
with the damage totals cached at the end of the previous frame, so a stale cache
could compare equal while the live fight did not. And `_fallback_timeout_outcome()`
returned `tie` whenever both boards were still standing, which refunds the whole
wager and lets the stage repeat forever. The totals are now refreshed before the
decision, and a fight that runs the clock is awarded by surviving units, then
damage dealt, then remaining health, with the seeded roll only for a perfectly
symmetrical board. A draw is now only possible on a genuine mutual wipe.

Evidence: the same stage that drew four times in a row now resolves. Across the
after-fix Jev run, 12 fights resolved with **zero draws**, 9 of them on the clock
(`E:\CodexStorage\task-artifacts\gamble-battle-jev-run-20260921\runs\jev-campaign-seed4401-20260921-093554`).

Regression: `tests/rga_testing/validation/StalemateResolutionProbe.tscn` drives two
durable boards into the timeout path and requires a decisive verdict -
`StalemateResolutionProbe: PASS cases=2 forced=2`.

**2. The planning reserve floor is two buckets (`scripts/game/shop/affordability.gd`).**
`PLANNING_RESERVE_FLOOR` was `1` while its own comment promised "enough health to
survive one ordinary 1-bet loss" - one bucket does not survive a one-bucket loss.
Since the minimum wager is one bucket, a floor of one turned the next fight into an
all-in. The floor is now `2`.

Evidence: the after-fix Jev run recorded zero spends to the floor and zero all-in
wagers, against two runs that died on a forced last-bucket wager
(`reserve_before = 1, applied = 1`).

**3. The loss screen no longer resumes a freed coroutine (`scripts/ui/loss_screen.gd`).**
`call_deferred` plus an internal `await` resumed after the screen was freed and
logged `Resumed function '_reassert_loss_scoreboard_typography()' after await, but
class instance is gone`. The layout pass is now scheduled as a one-shot
`process_frame` connection, which Godot drops automatically when the receiver is
freed; the method itself no longer awaits.

**4. Harness and strategy.** The harness now records the engine's own resolution
lines (so a forced result is explainable), captures the enemy board and damage per
fight, offers rerolls as a Jev decision, and reports combine progress and the
reserve each offer leaves. The rules gained a reserve floor of two buckets, a
focused reserve-floor question (a repeatedly missed conditional gets its own
question instead of another general line), a rule against replaying a failed
board, and the clock rule below. Jev's after-fix run used two rerolls and passed on
6 of 18 shop decisions.

Jev's controller behaviour on the final run: 41 decisions across starter, shop,
level, wager, contract, and one reserve-floor confirmation; API latency median
155 ms / p95 264 ms; observation-to-decision median 680 ms / p95 1.64 s; mean
answer confidence 0.52. Zero failed answers, zero invalid choices, zero technical
failures. The two earlier Bonko runs (7 and 10 decisions) ended at chapter 1
rounds 3 and 4 because Jev spent to one bucket, which the minimum wager then turned
into an all-in; that is what produced the reserve-floor rule and its focused
confirmation, and the final run recorded zero spends to the floor and zero all-in
wagers.

## Findings

### 1. A stage could draw forever, so the planning beat never ended (high, fixed)

The engine's no-progress and combat timeouts resolve through
`_fallback_timeout_outcome()`, which returns `tie` when both teams are alive with
equal total damage (`scripts/game/combat/combat_engine.gd`). `Economy.resolve_tie()`
restores the full pre-combat reserve, so a drawn stage costs nothing to repeat.

Evidence, final Jev run: chapter 2 round 2 resolved as a tie four times in a row
with the bankroll steady at 6 buckets. The board was **not** static - it grew from
four units to six and the bench filled with brutes, bonkos, repos, and a korath -
and every attempt still returned `tie` with `advanced = false`. The harness stopped
the run at that point (`stage_stall`) because a rule-following player had no
remaining move that changed the outcome. The superseded run looped chapter 2 round
3 the same way with an unchanged board.

Fixed by making the forced result decisive, as described above.

### 2. At one bucket the only legal wager is all-in, and that ended runs (high, fixed)

The wager slider's minimum is one bucket, so a player holding one bucket must risk
it. Both tank-starter runs arrived at the chapter 1 mirror with two buckets, spent
or levelled down to one, and then had to bet the last bucket: the loss zeroed the
bankroll and produced the terminal loss overlay.

Evidence: `wager_set` events with `reserve_before = 1, applied = 1` three times in
an earlier Jev run; `spend-to-floor` findings on a cost-1 purchase and a 4-bucket
level purchase; terminal `loss` with `buckets = 0`. In the final run the same rule
with a two-bucket floor plus the focused confirmation removed every all-in wager.

Fixed by raising the planning reserve floor to two buckets, so the shop refuses the
spend that would strand the player at one bucket. Letting a zero wager be selectable
remains an option the design owner may prefer; the floor fix needs no new control.

### 3. The loss screen resumed a coroutine after its node was gone (medium, fixed)

`err| ERROR: Resumed function '_reassert_loss_scoreboard_typography()' after
await, but class instance is gone. At script: res://scripts/ui/loss_screen.gd:896`
appeared three times across the two runs that reached the loss overlay.

Fixed by scheduling the layout pass as a one-shot frame connection.

### 3b. Most fights are decided by the clock (medium, open)

In the after-fix run 9 of 12 fights reached the 45-second cap and were awarded by
the tie-break ladder rather than by a wipe, and the same is true of the control
run. The boards at chapter 1-2 cannot kill each other inside the clock, so the
player-visible result often comes from a heuristic rather than from combat. Check
the damage-to-health ratio at this band; either shorten the durable phase or let
damage outpace sustain so fights close.

### 4. Peak bankroll in a real chapter 1 (observation, not a defect)

Withdrawn as a finding. It previously read that the shop policy in
`analysis/endless_economy/decision_quality_results.json` "only passes its gates at a
75-unit reserve", and that a real chapter 1 run reaching 6 buckets meant either a
denomination mismatch or an income curve an order of magnitude short.

That sweep models reserve *targets* inside a simulation. It is not a measurement of
this build's income, and no shipped rule asks a player to hold 75 units. Comparing a
live run against it was a comparison against a number the game never sets. What the
run actually shows is recorded here as an observation: a real chapter 1 run peaked at
6 buckets with `stake_unit = 1`.

Suggested change: drop the target from the policy and the analyzer (done), and set a
reserve target only from a measured live income curve.

### 5. Early prices remove the economic tension the gates assume (medium)

Jev passed on 1 of 8 shop decisions and the mean affordable offers per shop was
4.5 - every cheap offer is always affordable at chapter 1 prices (`cost 1` against
a 3-6 bucket bankroll). The decision-quality gate expects at least 30% of
economically implausible offers to be passed. In the sampled band there is little
to decline.

Suggested change: decide whether chapter 1 is meant to be a free-purchase runway;
if not, raise early prices or narrow income so the pass gate can be exercised.

### 6. Starter viability is uneven on the same seed (low)

Same rig, same seed, same rules: `brute` (tank) ended the run at chapter 1 round 5
in both the Jev and heuristic passes, while `bonko` (brawler) reached the chapter 2
round 4 target with 9 battles. Jev picked the tank opener because the rules did not
rank starters, which is itself a gap: the rules should give a starter criterion,
or the game should not present a starter that cannot clear the opening chapter.

### 7. The shown win odds matched results in this small sample (info)

Five pre-fight samples: predicted mean 0.596, observed 0.600, gap 0.004, Brier
0.158. The individual buckets swing widely at n = 1 each, so this is a baseline to
grow, not evidence of calibration.

## Evidence limits

## Second pass: real-game fidelity, the retry loop, and flex play

### Fidelity: the rig now drives the shipped game

The first pass called button handlers directly whenever a synthetic click missed,
which meant the game logic was real but the input path was not. Fixed:

| Change | Why |
| --- | --- |
| Clicks are `InputEventMouseButton` events pushed through `Input.parse_input_event` + `Input.flush_buffered_events` | hit-testing, focus, disabled state, mouse filters and drag lifecycle all run |
| `_allow_button_signal_fallback()` and `_allow_drag_lifecycle_fallback()` now return `false` | a click that misses the control fails loudly instead of passing silently |
| `Engine.time_scale = 1.0` by default (`-Speed` only for sweeps) | shipped combat speed; `Engine.time_scale` also scales the planning countdown |
| The shipped 120-second planning timer runs (`JEV_REAL_TIMER`, `-HoldPlanningTimer` only for sweeps) | the live beat that auto-starts the fight at zero is part of what "playable" means |
| Shop rolls are unseeded unless `-Seed` is passed | the shipped market is random; a seed is a comparison tool, not the default |
| Outcomes come from the engine's own `Combat resolved:` line | a defeat can leave the bankroll untouched, so a bankroll-only read reported losses as draws |

Every run writes these facts into `run_start`, so a transcript states its own
fidelity.

### The loop had a second cause: an unbounded early retry transfusion

`EARLY_RETRY_RECOVERY_MIN_BUCKETS = 6` with `EARLY_RETRY_RECOVERY_MAX_CHAPTER = 2`
meant any defeat in chapters 1-2 topped the bankroll back to six buckets. Failing
cost nothing, so a stage the player could not beat repeated forever - the same
player-visible symptom as the draw, from a different cause.

Evidence, before the fix: chapter 1 stage 5 defeats recorded
`reserve_before_wager 2`, `wager 1`, `buckets_after 6` four times in a row.

Fixed in `scripts/ui/combat/controller/combat_controller.gd`: the transfusion is
now granted once per stage (`_early_retry_transfusions_used`, cleared when a new run
passes through chapter 1 stage 1). Evidence after the fix: the first defeat at
chapter 1 stage 5 still refunds to 6 buckets, and the retries then cost the wager -
`reserve 6 -> 5`, `5 -> 4`, `4 -> 3`.

### Strategy: flex first, vertical as the gift, forcing as the gamble

The observation now carries the player's trait counts, each trait's next activation
threshold, and, per offer, whether the purchase would *add* a trait count or
*activate* a tier. Traits count unique units, so a duplicate is reported as an
upgrade play rather than a trait play. The rules (`tools/jev/policy/jev_run_rules.json`
and `docs/agent-workflows/jev-run-rules.md`) were rewritten around the requested
design:

- **Flex is the default**: take what the shop gives you, fill the missing role, add a
  trait count you already hold, keep several later shops useful.
- **A gifted vertical is a good thing**: when the board is stacked on a trait or one
  piece below the next threshold, take the piece that finishes it - that purchase may
  spend into the reserve, but never below the two-bucket floor.
- **Forcing is the paid gamble**: rerolling or buying for a plan you do not own is a
  coin flip that must be paid from the reserve, and is wrong when a flex pick you
  would take in an open shop is already in front of you.

### The real-speed run

`runs/jev-campaign-seed-1-20260921-124809`: Jev, shipped speed, live 120-second
beat, random shop, Bonko. Terminal **loss at chapter 2 round 3 with 0 buckets**,
10 battles, 0 technical failures, 0 engine errors.

| Measure | Value |
| --- | --- |
| Decisions | 32 (API median 153 ms, observation-to-decision median 210 ms) |
| Planning countdown used by the decisions | median 5.3 s of a 120 s beat (max 12.5 s) |
| Round wall time | median 63 s, p95 69 s |
| Shop decisions | 17, median 3 live options (>=15% probability) |
| Shops offering a tier-completing piece | 8 of 17 - and Jev took the vertical in all 8 |
| Shops with two or more flex offers | 7 of 17 |
| Shops with one or zero affordable offers | 5 of 17 |
| Fight resolutions | 11, zero draws, 3 decided by the clock, 8 by a wipe |

### What that says for an average player

**The gamble works.** The run is losable, decisive (no draws), and the vertical
payoff is reachable and taken: the shop handed a tier-completing piece in half the
planning beats and the player took every one. With the transfusion bounded, a stage
bails you out once and then charges you, which is what makes forcing a real risk.

**The pacing is lopsided.** The planning beat allows 120 seconds and the actual
decisions consume about 5. For a fast player that is mostly waiting next to a
countdown that will eventually auto-start the fight; for a slow player it is a real
deadline. Meanwhile a round takes about 63 seconds of wall time, most of it the
fight, and 3 of 11 fights ran to the 45-second cap and were decided by the tie-break
ladder rather than by a kill - so the longest part of the loop is sometimes a fight
that does not resolve.

**Chapter 2 losses in this sample were wipe-outs, not close fights.** In the four
runs behind this report, every loss that ended the run was a wipe-out
(`player_alive 0`, enemy damage 11-12k against the player's ~2.4k). Four runs is a
small sample, and a lost run is an outcome rather than proof of a defect; recorded
here as the observation it is.

## Third pass: the chapter-2 cliff, measured

`tests/rga_testing/validation/EncounterShapeProbe.tscn` (new) audits the *shape* of
generated encounters - board size, unit levels, and how much of the difficulty is
bought with the blanket `stat_scale` - alongside the game's own power model.

### What the measurements said

- The blanket stat multiplier was never the problem: generated boards sat at
  `stat_scale 1.00` almost everywhere (the chapter 1 boss even scales *down*, 0.86-0.89).
- The shape was the problem. Chapter 2 normal stages generated **three units at
  levels 2-3**, and `_desired_size_for_target()` only asked for four-plus units once
  the target passed 360, which happens in chapter 3. So difficulty in chapters 1-2
  was bought with unit levels.
- Levels beat breadth in the fight itself. Against chapter 2 stage 3 the same
  six-unit flex board measured **41% predicted odds all at level 1, 63% at level 2,
  81% at level 3**; a level-2 unit is worth about 1.75 level-1 units of the same
  identity. A pure breadth board is an underdog at chapter 2 by the game's own odds
  model - and the fight delivers worse than the model, because levels concentrate
  damage while spread bodies whittle.

### Changes

1. **Reverted, not shipped.** `endless_chapter_generator._desired_size_for_target()`
   was changed to ask for **four units from rating 260** (previously 360) so
   chapter 2-3 normal stages would be built from four-plus bodies at modest levels
   instead of three at high levels. The generated shapes did change as intended:
   chapter 2 stage 3 went from 3 units `{2,3,3}` at `stat_scale 1.00` to 4 units
   `{1,1,1,2}` at `stat_scale 1.00`, rating 276 against a 297 target.

   What it did **not** do is lower the requirement. `EncounterShapeComparisonProbe`
   generated both ladders on the same seed against the same affordable board and
   measured the breadth ladder *raising* generated power slightly (302 to 321, 301 to
   319) while leaving chapter 2 stage 2 untouched, so commit `10010944` made the
   ladder opt-in and restored the shipped one. The probe is kept as diagnostic
   evidence; it prints generated shape and modelled power and asserts nothing, so it
   cannot say which shape plays better, and it no longer prints `PASS`.
2. **Superseded.** The rules and the run document were updated to state level
   economics explicitly, including the line "a duplicate that completes a third copy
   outranks another new one-cost body". That framing is gone. The policy now names a
   second copy, a third copy, a stronger unit, an item, an extra slot and a trait
   breakpoint as competing ways to add power, and records that a purchase lands on
   the bench so it changes nothing until it is deployed.

### Still open

Whether chapter 2 should *require* one round of combines is a product call. The 43%
and 64% figures quoted here have no checked-in artifact behind them on the current
build, and the shape change above was reverted, so it removed nothing: **no
wipe-out fix is shipped.** What is established instead:

- Most fights are decided by the 45-second clock rather than by a kill: 83 of 146
  across nine recorded runs, and 4 of 5 in a run at shipped speed with the real
  timer.
- The 12-second no-progress watchdog never fired once in any of those runs, so this
  is not a stalled-fight problem. Boards simply stop being able to finish each other.
- TFT-style overtime escalation resolves those fights (26 clock-decided standoffs to
  2 on the frozen set) but changes who wins, and at the tuning that resolves them the
  player-facing win odds mis-calibrate by 28.8% against a 15% gate. It is built, off,
  and blocked on the odds estimator.

The harness observes structured game state (buckets, level, offers, roles) rather
than a screenshot, so it can measure planning economics and outcomes, not
first-time player comprehension or visual discoverability. Deployment, rerolls,
and item equipping are executed by rule-based helpers, so their quality is not
being judged. Runs used `Engine.time_scale = 8.0` for combat only; each decision
is made from the live planning state, and Jev's turn-around was measured
separately. One seed and two policies is enough to expose the stall and the
one-bucket trap, not enough to score overall balance.

## Validation of the fixes

| Check | Result |
| --- | --- |
| `tests/rga_testing/validation/StalemateResolutionProbe.tscn` | `PASS cases=2 forced=2` - durable boards forced the timeout path and both results were decisive |
| `tests/rga_testing/validation/ReserveFloorContractProbe.tscn` | `PASS floor=2` - planning and in-combat floor arithmetic |
| Heuristic campaign, seed 4401, Bonko | target reached, chapter 2 round 4, 10 battles, 0 technical failures |
| Jev campaign, seed 4401, Bonko | target reached, chapter 2 round 4, 12 battles, 0 technical failures, 12 resolutions and 0 draws |

Two limitations are worth naming. `tests/visual/EconomyTieAffordabilitySmoke.tscn`
and `tests/visual/ShopCorrectnessAuditSmoke.tscn` were updated to the two-bucket
contract, but neither can be observed through the MCP runner used here: a scene that
prints and quits inside the same frame loses that output when stdout is a pipe
(`tests/diagnostics/MinimalQuit.tscn`, untouched, loses its `PASS` line the same
way), so `ReserveFloorContractProbe` carries the observable assertions instead.
And `tests/rga_testing/RGATesting.tscn` exits after about 47 seconds without writing
its output or printing its completion line **both with and without this change**
(verified by stashing the combat edit and re-running), so it is a pre-existing
checkout condition rather than a regression from this work.

## Runtime notes

- This checkout needed the repository's own CI import gate before it would
  hydrate: `Godot_v4.5-stable_win64_console.exe --headless --editor --path .
  --quit`. It generated untracked `.import` sidecars only; no tracked file
  changed. `Tools\Test-GodotEditorHydration.ps1` then reported `ready: true`.
- Runs go through the configured Godot MCP runner; the pinned console binary in
  `godot-bin/` is used as `GODOT_PATH`. Every run was stopped and its process
  confirmed gone before the next one started.
- `run_project` launches the game with the debugger attached, so a script error
  stops play at a debugger prompt. The runner watches for `Debugger Break` and
  stops the run instead of hanging.
