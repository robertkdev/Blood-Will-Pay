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

## Why the clock decides most fights

This is the finding the rest of the report kept circling, measured rather than
inferred. **The damage a board deals in forty-five seconds is smaller than the health
the other board is holding.**

From `data/identity/primary_role_profiles/*.tres`, a board of one of each role holds
**7,420 HP** and deals a combined **106.4 basic-attack DPS** against comparable armor:

| Role | HP | AD | Atk speed | DPS vs own armor | Self time-to-kill |
| --- | --- | --- | --- | --- | --- |
| Assassin | 980 | 40.6 | 0.70 | 21.9 | 44.8s |
| Brawler | 1,400 | 56.0 | 0.70 | 24.5 | 57.1s |
| Mage | 1,050 | 31.5 | 0.70 | 16.3 | 64.3s |
| Marksman | 1,190 | 48.3 | 0.70 | 23.3 | 51.0s |
| Support | 1,190 | 14.0 | 0.70 | 6.8 | 176.1s |
| Tank | 1,610 | 35.0 | 0.70 | 13.6 | 118.3s |

Every one of those self time-to-kill figures is at or above the 45-second clock, and
the durable roles are two to four times past it. The same-role cases matter most:
**a mirror fight is a board against itself**, so by construction it cannot be won by a
wipe inside the clock.

Real fights match the arithmetic. In the shipped-speed run the chapter 1 boss resolved
three times, and after the full 45 seconds **both boards still had all four units
alive** with the player having dealt 2,000-2,300 damage. Against 7,420 HP that is
roughly 42% attack uptime once movement, range and target switching are accounted
for, which puts the practical time-to-wipe near 165 seconds - about **3.7 times the
clock**.

That also explains the watchdog reading. The 12-second no-progress timeout requires no
damage *and* no meaningful movement; damage lands continuously, so it never fires.
Nothing is stalled. The boards simply cannot out-damage each other's health pool.

### What was tried

Measured against the calibration probe's 144 dated matchups, with the frozen 26-fight
standoff set as a second reading. **Every experiment below was reverted.** The shipped
build is unchanged: the calibration fingerprint is
`24efe26953c85f40c84d243cce55e999c64dcd692f2e023d1a27b15fa6118b7c` before and after.

| Change | Clock-decided fights | Shown-odds calibration |
| --- | --- | --- |
| none (shipped, 45s clock) | 12 of 144, 26 of 26 | PASS, worst bucket gap 12.4% |
| overtime, start 30s, +200% | 11 of 144, 14 of 26 | PASS, gaps unchanged |
| overtime, start 24s, +300% | 0 of 144, 2 of 26 | FAIL, 28.8% bucket gap |
| clock raised to the documented 105s | 9 of 144 outran the sim's own 60s limit | FAIL, 28.8% bucket gap |
| `attack_damage` x2.5 on all six roles | **12 of 144 - no change at all** | FAIL, bucket population collapsed to 4 |
| `max_hp` halved on all six roles | **1 of 144** | FAIL, 25.2% bucket gap |

Three things follow, and the first is the surprising one:

1. **Basic-attack damage is not the lever.** Raising it by two and a half times left
   the clock-decided count at exactly 12. The estimator noticed (its bucket
   populations shifted sharply) while the fights did not.

   Ability damage explains the asymmetry and is worth stating plainly, because it is
   not a defect. Abilities compute as `DAMAGE_BASE[level] + AD_RATIO * attack_damage`,
   so they partly follow attack damage already; but the ones that scale from
   `spell_power` do not, and `spell_power` is `0.0` in every role profile. The Google
   design doc specifies exactly that - *"Unless overridden by the role profile: move
   speed 120, spell power 0, critical damage 1.5x"* - so a flat magic caster is
   documented behaviour and spell power is meant to arrive through items, not through
   role profiles. Raising `attack_damage` therefore did nothing for the magic half of
   the roster. Brute is the other extreme: `brute_slam` deals no damage at all, it is
   a knockup.
2. **Health is the lever.** Halving it took clock-decided fights from 12 to 1.
   Whatever keeps those boards standing is the size of their health pool relative to
   the damage that reaches it.
3. **Any change that makes fights resolve breaks the shown odds, and always in the
   same direction.** Overtime at the steep tuning, a longer clock, and halved health
   each drop clock-decided fights and each push the mid-band estimate out by 25-29%
   against a 15% gate, with near-even boards losing far more often than advertised.
   The estimator is calibrated against fights that mostly do not resolve; make them
   resolve and it is wrong.

### The decision this needs

Two calls, and they are coupled:

1. **Set a target fight length.** Nothing in the design document or the repo states
   how long a fight should last. The clock is 45 seconds and a wipe currently needs
   roughly 70 seconds of full uptime, far more with realistic uptime. Any health or
   damage change is unanchored until that number exists.
2. **Recalibrate the shown win odds against resolved fights.** This is not optional
   cleanup: every lever that makes fights resolve moves the mid-band estimate by
   25-29% against a 15% gate, and those odds are what the whole wagering loop is
   priced on. Shipping a rebalance without it replaces "the clock decides" with "the
   odds lie", which is worse in a game built on wagering.

`team_odds_calibration_probe` is the acceptance check for both, and its 15% bucket
gate is the number to hold.

## Declared seed set: flex versus committing to a trait

The design intent is that flex play is the default, a gifted vertical is a good
thing, and forcing is a gamble. That is testable, so it was tested on a declared seed
set rather than on one convenient run.

**Setup.** Seeds 4401, 7717 and 90210; starter Bonko; `Engine.time_scale = 8.0` for a
fast sweep, with the real planning timer; both arms on the same harness build and the
same neutral candidate list, differing only in the `playstyle.flex` and
`playstyle.force` text (`tools/jev/policy/variants/force_first.json`).

Two forcing variants were played, because the first one turned out never to force:
`commit` rerolls only when the shop offers nothing for the chased trait, and
`force-always` rerolls whenever a reroll is affordable, usable offers or not.

| Arm | Seed | Terminal | Battles | Ended at | Buys | Passes | Rerolls |
| --- | --- | --- | --- | --- | --- | --- | --- |
| flex | 4401 | stage_stall | 6 | 1:4 | 3 | 1 | 0 |
| flex | 7717 | stage_stall | 6 | 1:4 | 3 | 1 | 0 |
| flex | 90210 | loss | 10 | 2:2 | 11 | 5 | 0 |
| commit | 4401 | loss | 11 | 2:3 | 12 | 5 | 0 |
| commit | 7717 | stage_stall | 6 | 1:4 | 3 | 1 | 0 |
| commit | 90210 | loss | 5 | 1:4 | 2 | 3 | 0 |
| force-always | 4401 | loss | 8 | 2:2 | 9 | 3 | 1 |
| force-always | 7717 | stage_stall | 6 | 1:4 | 3 | 1 | 0 |
| force-always | 90210 | loss | 5 | 1:4 | 2 | 3 | 0 |

| Arm | Reached chapter 2 | Rerolls | Battles |
| --- | --- | --- | --- |
| flex | 1 of 3 | 0 | 6, 6, 10 |
| commit | 1 of 3 | 0 | 11, 6, 5 |
| force-always | 1 of 3 | 1 | 8, 6, 5 |

**Result: null, and the seed dominates the stance.** Every arm reached chapter 2 in
exactly one of three seeds. The single-run difference that prompted the comparison -
the variant reaching 2:3 while flex stalled at 1:4 on seed 4401 - did not replicate;
on 7717 and 90210 the arms are identical or flex goes further.

The more useful reading is in the per-seed rows. On seed 7717 all three arms produced
the *same* run (stage stall at 1:4, six battles, three buys, one pass). On 90210 the
two committing arms were identical to each other and flex differed. Only on 4401 did
all three diverge. With five offers per shop at chapter 1-2 prices, the affordable
purchase is usually the same one under any of these stances, so the encounter seed
decides far more than the policy does.

### Forcing happens, and costs nothing measurable

The first variant never forced at all. The chase rule was conditional on the shop
offering nothing usable, and with a tier-completing piece appearing in about half of
all beats that condition almost never held - zero rerolls across six runs.

`force-always` removes the condition, and it works: seed 4401 rerolled once, the first
forced reroll in this whole investigation. It changed nothing measurable. That run
ended at 2:2 with eight battles, where the conditional variant reached 2:3 with
eleven; both reached chapter 2. On the other two seeds it behaved identically to the
conditional variant.

So at chapter 1-2 prices: flex is the reliable play, forcing is rarely *compelled*,
and when it is exercised it is neither punished nor rewarded at this sample. The
design intent says a paid chase should be a gamble; nothing here contradicts that, but
one forced reroll in nine runs cannot confirm it either.

### Caveat on this sample

Three seeds across three arms is nine runs, and the clock still decides fights in
every one of them (1 to 5 clock-decided fights out of 6 to 12). Strategy differences
are being measured through an outcome layer that is itself unresolved, so treat this
null as "no effect detectable at this sample" rather than "no effect". The runs are
also a fast sweep at `time_scale = 8.0`, not shipped speed.

## Jev is behind the scripted baseline

The rig has always been able to replay a seed with the built-in rule-based policy as a
control, but that arm recorded no shop telemetry at all - it returned before any event
was written - so no comparison against it could actually be read. With that fixed
(`062f63b2`), the same three seeds now compare:

| Arm | Reached chapter 2 | Battles | Buys | Passes |
| --- | --- | --- | --- | --- |
| Jev, flex | 1 of 3 | 6, 6, 10 | 3, 3, 11 | 1, 1, 5 |
| Jev, commit | 1 of 3 | 11, 6, 5 | 12, 3, 2 | 5, 1, 3 |
| Jev, force | 1 of 3 | 8, 6, 5 | 9, 3, 2 | 3, 1, 3 |
| **scripted baseline** | **2 of 3** | 6, 11, 12 | 3, 6, 8 | 5, 8, 9 |

**The built-in policy reaches chapter 2 on two of three seeds; no Jev arm manages more
than one.** On seed 7717 the scripted policy reaches 2:2 with twelve battles while all
three Jev arms stall at 1:4 with six; on 90210 it reaches 2:2 with the longest run of
the set. Only on 4401 do the arms converge.

This is the first direct evidence about whether Jev's strategy is any good, and the
answer at this sample is no - it is losing to a deterministic script on the same
seeds. What the script does differently is pass more: 22 passes across the three seeds
against Jev flex's 7, while buying comparable amounts. That lines up with the policy's
own claim that buying every affordable offer is the losing baseline, and suggests Jev
is taking offers the script declines.

Three seeds is not enough to call this settled, and the clock still decides fights in
every run here. But it is a better starting point for improving the policy than any
aggregate win rate: there is now a specific, reproducible opponent to beat.

## First policy iteration: a pass rule, and what it did and did not change

The baseline's most obvious difference was that it passed far more, so the shipped
policy gained an explicit pass rule: *"Pass when the offer neither fills a missing
role, nor advances a trait you hold, nor is a same-level duplicate you are two copies
into. A defensive pass is a real move."* The digest had to be trimmed to fit
afterwards - see the budget note below.

| Arm | Reached chapter 2 | Battles | Buys | Passes | Pass rate |
| --- | --- | --- | --- | --- | --- |
| flex, before | 1 of 3 | 6, 6, 10 | 17 | 7 | 0.29 |
| flex, with the pass rule | 2 of 3 | 12, 9, 5 | 24 | 11 | 0.31 |
| scripted baseline | 2 of 3 | 6, 11, 12 | 17 | 22 | 0.56 |

**The headline improved and the mechanism did not.** Jev moved from one seed reaching
chapter 2 to two, matching the scripted baseline on the same seeds - and one seed
regressed, 90210 going from 2:2 to 1:4.

But the stated reason was wrong. The pass *rate* barely moved: 0.29 before, 0.31
after, against the baseline's 0.56. Jev did not become more selective. It bought
absolutely more (24 against 17) because it survived longer and therefore visited more
shops, and it passed more for the same reason. **Comparing raw buy and pass counts
across runs of different length is the same mistake as counting purchase decisions as
shops** - the totals scale with the number of beats, so the rate is the honest
measure and the totals are not.

So the improvement is real in the headline and unexplained in the mechanism. At n=3
with one regression it could be noise, and a policy-text change moves every prompt at
once, so this cannot be attributed to the pass rule specifically. It needs more seeds
before it means anything.

One thing the iteration did prove: the digest budget check works. Adding the rule took
the digest to 5,223 characters against a 5,200 limit, which would have silently cut
the shown-odds rule off the end of every prompt. The check caught it, the policy was
trimmed to 5,123, and the test now evaluates the controller's own f-strings rather
than a hand-built approximation - two earlier versions of it under-counted and passed
while the real digest was being truncated.

## Six seeds: Jev is behind the scripted baseline, and it is not marginal

The three-seed result above was too small to trust, so the declared set was extended
to six seeds - 4401, 7717, 90210, 11111, 22222, 33333 - with the current policy
against the scripted baseline on each.

| Seed | Jev (current policy) | Scripted baseline |
| --- | --- | --- |
| 4401 | loss, 2:2, 12 battles, pass rate 0.28 | stage stall, 1:4, 6 battles, 0.62 |
| 7717 | loss, 2:2, 9 battles, 0.31 | loss, 2:2, 11 battles, 0.57 |
| 90210 | loss, 1:4, 5 battles, 0.50 | loss, 2:2, 12 battles, 0.53 |
| 11111 | stage stall, **2:3**, 10 battles, 0.20 | stage stall, 2:2, 10 battles, 0.53 |
| 22222 | stage stall, 1:4, 6 battles, 0.50 | **target reached**, 2:4, 9 battles, 0.42 |
| 33333 | stage stall, 1:4, 6 battles, 0.25 | **target reached**, 2:4, 10 battles, 0.54 |

| Arm | Reached chapter 2 | Reached the campaign target | Mean pass rate |
| --- | --- | --- | --- |
| Jev, current policy | 3 of 6 | 0 of 6 | 0.34 |
| scripted baseline | **5 of 6** | **2 of 6** | 0.54 |

The baseline reaches chapter 2 on five seeds to Jev's three, and it is the only arm
that has ever reached the campaign target in this investigation. Jev's one better
result - 11111, where it got a stage further - does not offset that.

### The obvious explanation is a difference, not yet a cause

The baseline passes on 54% of its shop decisions and Jev on 34%, and the arm that
passes more is the arm that goes further. That is a real difference between the arms
and it matches the policy's own claim that buying every affordable offer is the losing
baseline.

It does not hold *within* Jev, though, and that is worth stating before anyone tunes
against it. Jev's best run (11111, reaching 2:3) had its **lowest** pass rate at 0.20,
and one of its worst (90210, out at 1:4) had 0.50. Across six seeds the pass rate and
the outcome do not move together inside the arm. So "pass more" is where the two arms
differ, not a demonstrated lever - and the pass rule added above did not move the rate
anyway (0.29 to 0.31).

What this does establish is the thing strategy work needed: a reproducible, same-seed
opponent that Jev currently loses to, with a measured gap to close rather than an
aggregate win rate to argue about.

## Second policy iteration: buying up, tested and reverted

Reading the baseline's actual code rather than guessing at its behaviour turned up a
concrete difference. Its purchase scoring is
`cost * 80 + role_score - 35 if duplicate - 30 if second support`, so it **buys the
most expensive affordable unit**, weighted by the role the board lacks.

That is not an arbitrary preference. `scripts/game/units/unit_scaler.gd` multiplies
`max_hp`, `attack_damage`, `armor`, `magic_resist` and the rest by **1.5 per cost
step**, so a cost-3 body carries **2.25x** a cost-1's health and damage. The shipped
policy said to buy "the cheapest real power on the shelf", which is the opposite of
what the stats say.

So the policy was changed to say cost is power and to prefer the strongest body you
can afford. Measured over the same six seeds:

| Seed | Previous policy | Buying up |
| --- | --- | --- |
| 4401 | 2:2, 12 battles | 1:4, 6 battles |
| 7717 | 2:2, 9 battles | 2:3, 11 battles |
| 90210 | 1:4, 5 battles | 1:4, 6 battles |
| 11111 | 2:3, 10 battles | 1:4, 6 battles |
| 22222 | 1:4, 6 battles | 2:3, 13 battles |
| 33333 | 1:4, 6 battles | 1:4, 6 battles |

| Arm | Reached chapter 2 |
| --- | --- |
| previous policy | **3 of 6** |
| buying up | 2 of 6 |

**The rule is factually right and it measured worse.** So it was reverted: the shipped
policy is back to the wording with the better record. Two seeds improved sharply and
two got sharply worse, which is what a six-seed sample looks like when the effect is
smaller than the variance - three-versus-two is one seed flipping, and neither number
settles anything.

The honest summary is that stating a true fact in the policy did not make Jev play
better, and the reason is not known. It may be that "prefer the strongest body"
competes with the role and trait rules and the model resolves that badly; it may be
noise. Either way, shipping a change that measured worse on the declared set would
have been the wrong call, so it is not shipped.

### A harness defect this surfaced

One of those six runs ended in a technical failure, not a result: a synthetic mouse
event missed a shop slot that was rendered, enabled and `mouse_filter 0`. The
inherited click path records that as a failure immediately, which makes the whole run
unusable. `_click_shop_slot` now retries a bounded three times and keeps only the
final attempt's failure, so one dropped event cannot invalidate a run while a slot
that genuinely cannot be clicked still fails loudly. Re-running seed 33333 with the
retry in place completed cleanly, and the run in the table above is that re-run.

## Player report: "creep rounds are broken, no items after the start"

The player who actually plays this reported that creep rounds stop paying out items
and called it an error. Checked in order.

**Creep stages exist in every chapter, and they do pay.** `EndlessChapterGenerator.get_spec`
routes `CREEP_STAGE` to `_make_creep_spec` for any chapter, and that spec carries
`DEFAULT_CREEP_REWARDS`. Measured on a real `Main.tscn` run by recording the item
inventory before every fight:

| fight | stage | kind | inventory before the fight |
| --- | --- | --- | --- |
| 1 | ch1:1 | CREEPS | `[]` |
| 2 | ch1:2 | NORMAL | `[orb]` |
| 7 | ch2:1 | CREEPS | `[orb]` |
| 8 | ch2:2 | NORMAL | `[orb, wand]` |

Both creep stages paid. The flat claim does not reproduce on this build.

**But there was a real defect in the same pool, and it is the opposite one.** In
`data/creeps/reward_pools/default.tres` the entries array referenced only
`drop_component`:

    entries = Array[...]([SubResource("7")])

`gold_pool_pick` and `reroll_pool_pick` were defined with weights 25 and 5 and never
referenced, and there was no `nothing` entry. `CreepRewardRuntime._pick_entry`
normalises over *the entries actually present*, so the only wired entry was picked
100% of the time: **every creep kill dropped a component, and gold and rerolls could
never drop at all.** The design document specifies 58.33% component, 16.67% nothing,
12.5 / 6.25 / 2.08% gold, 3.33 / 0.83% rerolls.

The pool now implements the document. `EconomyBalanceEvidenceProbe` samples 20,000
reward terminals and every terminal lands inside its six-sigma tolerance:

| terminal | configured | observed |
| --- | --- | --- |
| one component | 0.5833 | 0.5889 |
| +1 / +2 / +3 buckets | 0.1250 / 0.0625 / 0.0208 | 0.1240 / 0.0601 / 0.0223 |
| +1 / +2 rerolls | 0.0334 / 0.0083 | 0.0334 / 0.0086 |
| nothing | 0.1667 | 0.1630 |

**This makes components rarer, not more common** - from one guaranteed component per
creep kill down to 58.33%, in exchange for gold and rerolls that previously could not
appear. So it fixes a broken pool but it is not the fix the player was asking for.

Their complaint points at a different lever. There is **one creep stage per chapter**
of five stages, and it contains one creep, with `rolls_per_kill: 1`. That is roughly
**0.58 component rolls per chapter** - about one component every eight or nine fights,
which is what "no items after the start" describes from the player's side. Making
items arrive often enough to "slam items on the correct units" is a rate decision:
more rolls per kill, more creeps per creep stage, or more creep stages per chapter.
That is a product call, and the document does not settle it - it fixes the
probabilities per roll, not how many rolls a chapter grants.

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
