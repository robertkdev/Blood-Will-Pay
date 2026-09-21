# Jev play run and findings - 2026-09-21

Jev (TypeSafe `jev-1.13.0`, requested `jev-latest`) played Blood Will Pay through
the real `scenes/Main.tscn` runtime on the current `main` checkout
(`71c588f6`, plus the onboarding and import passes described below). This report
records what was built, the rules Jev played by, what happened, and what the run
says about the game.

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
| `jev-campaign-seed4401-20260921-082105` (final Jev run) | brute (Jev's choice) | stage stall | chapter 2 round 2 | 9 | 6 | 41 |
| `jev-campaign-seed4401-20260921-075736` | brute | loss | chapter 1 round 5 | 5 | 6 | 15 |
| `heuristic-campaign-seed4401-20260921-080256` | brute | loss | chapter 1 round 5 | 7 | 6 | - |
| `heuristic-campaign-seed4401-20260921-080609` | bonko | target reached | chapter 2 round 4 | 9 | 9 | - |
| `jev-campaign-seed4401-20260921-073802` (superseded rig) | brute | stage replay loop | chapter 2 round 3 | - | 6 | 74 |
| `jev-campaign-seed4401-20260921-081030` and `-081535` | bonko | loss | chapter 1 rounds 3 and 4 | 4 / 5 | 6 | 7 / 10 |

Raw runs, observations, decisions, and generated reports:
`E:\CodexStorage\task-artifacts\gamble-battle-jev-run-20260921\runs\`.

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

### 1. A stage can draw forever, so the planning beat never ends (high)

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

Suggested change: escalate the encounter on a draw, count draws against a bounded
retry budget, or make the timeout fallback unreachable with a sudden-death damage
ramp, so "draw forever" is not a stable state. This is the exact player experience
that started this investigation: the planning phase appears to repeat without end.

### 2. At one bucket the only legal wager is all-in, and that ends runs (high)

The wager slider's minimum is one bucket, so a player holding one bucket must risk
it. Both tank-starter runs arrived at the chapter 1 mirror with two buckets, spent
or levelled down to one, and then had to bet the last bucket: the loss zeroed the
bankroll and produced the terminal loss overlay.

Evidence: `wager_set` events with `reserve_before = 1, applied = 1` three times in
an earlier Jev run; `spend-to-floor` findings on a cost-1 purchase and a 4-bucket
level purchase; terminal `loss` with `buckets = 0`. In the final run the same rule
with a two-bucket floor plus the focused confirmation removed every all-in wager.

Suggested change: let a zero wager be selectable, price the level purchase against
the chapter's income, or grant a floor of more than one bucket at a retry.

### 3. The loss screen resumes a coroutine after its node is gone (medium)

`err| ERROR: Resumed function '_reassert_loss_scoreboard_typography()' after
await, but class instance is gone. At script: res://scripts/ui/loss_screen.gd:896`
appeared three times across the two runs that reached the loss overlay.

Suggested change: guard the awaited callback against a freed instance or bind the
pending timer to the node's lifetime.

### 4. The documented reserve target is unreachable in a real chapter 1 (medium)

The shop policy in `analysis/endless_economy/decision_quality_results.json` only
passes its gates at a 75-unit reserve. A real chapter 1 run peaks at 6 buckets
(`peak_bankroll = 6` in all four runs, `stake_unit = 1`). Either the sweep's
"unit" is not a bucket, or the shipped income curve is an order of magnitude below
the model the shop gates were tuned against.

Suggested change: reconcile the sweep's denomination with the live economy and
re-run `decision_quality_model.py` against a real bankroll curve.

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

The harness observes structured game state (buckets, level, offers, roles) rather
than a screenshot, so it can measure planning economics and outcomes, not
first-time player comprehension or visual discoverability. Deployment, rerolls,
and item equipping are executed by rule-based helpers, so their quality is not
being judged. Runs used `Engine.time_scale = 8.0` for combat only; each decision
is made from the live planning state, and Jev's turn-around was measured
separately. One seed and two policies is enough to expose the stall and the
one-bucket trap, not enough to score overall balance.

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
