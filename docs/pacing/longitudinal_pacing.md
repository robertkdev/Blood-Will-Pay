# Longitudinal pacing harness

The pacing test measures the player rhythm across a real `scenes/Main.tscn` run. It is intentionally separate from combat balance, shop tuning, and results-screen production logic: the harness observes existing signals and visible controls, inserts bounded player-like dwell between actions, and writes JSON-shaped telemetry plus a Markdown verdict.

## Run it

Run the scene through the Godot MCP server, using the absolute project root for the checkout under test:

```text
run_project(
  projectPath="C:\\Users\\Flipm\\Documents\\gamble-battle",
  scene="tests/pacing/LongitudinalPacingHarness.tscn"
)
```

The harness owns two scoped samples:

- `natural_campaign_bonko` (`scope=campaign`): starts at the real title/unit-select flow, accepts Main's automatic opening battle, then follows shop, deployment, combat, results, recovery, and escalation until target stage 9, a bounded timeout, or a real terminal outcome.
- `natural_loss_retry` (`scope=loss_retry`): uses a test-only runtime weak-unit fixture after starter selection, observes the actual loss overlay, presses the production New Game/retry control, and verifies return to unit selection. This proves the retry rhythm; it is not a combat-balance claim.

Outputs are written to `user://pacing/longitudinal_pacing_suite.json` and `user://pacing/longitudinal_pacing_report.md` (on this machine: `%APPDATA%\\Godot\\app_userdata\\Gamble Battle\\pacing\\`). Every run preserves `sample`, `run`, `stages`, and the raw per-stage `events` list. Stage records retain chapter, round, global stage, `CREEPS`/`NORMAL`/`BOSS` kind, and derived metrics.

## Metric contract

The schema version is `gamble-battle.pacing.v1`. A run fails when an observed metric is outside its guardrail, a required campaign beat is missing, or the campaign cannot reach the minimum run shape. `-1` is the stage-level representation for an inapplicable/unobserved beat; scoped samples report `N/A` rather than failing on intentionally absent beats.

| Metric | Definition | Guardrail | Basis |
| --- | --- | ---: | --- |
| `time_to_first_decision_seconds` | Onboarding start to starter selection/first meaningful decision | 1–45 s | run |
| `onboarding_to_first_combat_seconds` | Onboarding start to first combat phase | 1–75 s | run |
| `planning_time_use_seconds` | Preview/shop entry to first player action or deployment | 1–60 s | p50 and p90 |
| `action_density_per_planning_minute` | Recorded shop/deploy actions divided by planning minutes | 1–30 actions/min | p50 |
| `combat_duration_seconds` | Combat start to victory/defeat/tie | 0.75–45 s; boss max 90 s | p50 and p90 |
| `result_dwell_seconds` | Outcome presentation to the next phase/action | 1–8 s | p50 and p90 |
| `recovery_seconds` | Result/post-combat to the next preview | 0–5 s | p50 and p90 |
| `shop_decision_seconds` | Player-facing preview to first shop/deploy/purchase action | 1–45 s | p50 and p90 |
| `max_dead_time_seconds` | Largest gap without a recorded phase/action event | 0–8 s | maximum |
| `boss_interval_stages` | Distance between observed bosses | 4–6 stages | p50; requires a campaign interval |
| `loss_retry_recovery_seconds` | Loss overlay visible to verified retry/unit-select recovery | 0–30 s | maximum |
| `run_length_stages` | Highest observed stage versus the campaign target | minimum 5; target 9 | target/reached |

The result skip metric is explicitly reported as `N/A` inside this longitudinal sample because result-dismissal latency is owned by `InteractionLatencySmoke.tscn`. Main does expose a player-facing Enter/Space advance control; the pacing harness does not duplicate or contradict that dedicated timing gate.

## Controlled falsification

`PacingMetricsContractTest.tscn` feeds the same analyzer four known traces:

- Normal: planning 4–8 s, combat 4–10 s, result dwell 2–3 s, recovery 1–2.5 s, shop 1–2.5 s: `PASS`.
- Known-fast: planning 0.25 s, combat 0.2 s, result dwell 0.2 s, and first decision 0.2 s: `FAIL` with `too_fast` findings.
- Known-slow: planning 75 s, combat 65 s, result dwell 12 s, dead time 20 s, and retry 40 s: `FAIL` with `too_slow` findings.
- Scoped loss/retry: a terminal fight and retry without a planning/shop beat: `PASS`, with those intentionally absent metrics reported as `N/A`.

The scene prints `normal=PASS fast=FAIL slow=FAIL loss_retry=PASS suite=FAIL`. `PacingRecorderParseTest.tscn` is a lightweight load/parse guard for the recorder dependency.

## Event model and maintenance

`pacing_recorder.gd` records phase transitions, stage changes, battle start/outcome, onboarding, shop offers/locks/cards/purchases, bench/deployment, result/retry controls, and player-facing start-battle controls. It also records timing gaps so dead time is visible rather than hidden inside an aggregate duration. The observer is attached by the test harness; no production gameplay, shop, or results-screen code is changed.

The first opening battle is intentionally treated as onboarding-to-combat because `Main.tscn` auto-starts it after starter selection. Later rounds use the natural production flow. Do not “fix” this in the harness by forcing a planning screen that players do not see. Extend the recorder only when a new player-facing beat or production signal is added, and add a controlled analyzer case when a threshold changes.
