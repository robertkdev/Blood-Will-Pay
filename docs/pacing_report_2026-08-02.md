# Gamble Battle pacing verdict — 2026-08-02

## Verdict

The new longitudinal pacing harness is operational and produces a real `gamble-battle.pacing.v1` report from `scenes/Main.tscn`. The current campaign sample is **FAIL**, not because the timing analyzer is broken, but because the natural Bonko run lost at the first observed boss (`global_stage=4`) before it could prove the required boss cadence or longer-session run shape. The independent controlled loss/retry sample is **PASS** with `loss_retry_recovery_seconds=0.28`.

No production combat, shop, or results-screen logic was changed. The harness owns tests/tooling and a test-only runtime weak-unit fixture for the loss path.

## Evidence

Generated artifacts:

- `user://pacing/longitudinal_pacing_suite.json`
- `user://pacing/longitudinal_pacing_report.md`
- On the test machine: `C:\Users\Flipm\AppData\Roaming\Godot\app_userdata\Gamble Battle\pacing\longitudinal_pacing_report.md`

The campaign timeline observed the real Main flow: onboarding, automatic opening battle, result dwell, recovery, shop offers, purchases, deployment, two normal combats, then the boss combat. The loss/retry timeline observed the loss overlay and production New Game return to unit select.

## Campaign sample

| Stage | Kind | Planning s | Actions | Actions/min | Combat s | Result dwell s | Recovery s | Shop decision s | Dead gap s |
| ---: | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | CREEPS/opening | 0.23 | 0 | 0.00 | 4.97 | 1.97 | 0.09 | N/A | 4.91 |
| 2 | NORMAL | 6.11 | 2 | 19.64 | 18.28 | 2.05 | 0.09 | 2.15 | 2.04 |
| 3 | NORMAL | 6.12 | 2 | 19.61 | 19.13 | 2.04 | 0.17 | 2.17 | 2.05 |
| 4 | BOSS | 7.71 | 3 | 23.34 | 16.22 | 2.05 | 0.09 | 1.52 | 2.05 |

Run-level observations:

- Time to first decision: `1.323 s`; onboarding to first combat: `1.264 s`.
- Maximum dead time: `4.907 s`, below the `8 s` guardrail.
- Observed combat, result dwell, recovery, shop-decision, and action-density values are inside their timing ranges for the observed span; boss combat was `16.22 s`, below the `90 s` boss ceiling.
- Boss cadence is **FAIL / missing** because only one boss was reached; no inter-boss interval exists to evaluate against the `4–6 stage` range.
- Run length is **FAIL**: highest stage `4`, below the minimum `5` and target `9`.
- Result skip response is `N/A`: the observed Main flow exposes no player-facing result skip control.

## Loss/retry sample

The controlled sample reached a real defeat, showed the loss overlay, pressed New Game, and verified return to the unit-selection flow. Its first-stage timeline was: planning `4.46 s`, combat `4.55 s`, result dwell `2.09 s`, recovery `0.18 s`, and explicit retry recovery `0.28 s`. The scope-aware analyzer excludes shop/action-density and normal recovery assertions that are not part of this loss-only sample.

## Actionable findings and risks

1. The first boss is the current pacing stop in this natural sample. A separate balance/escalation workstream should investigate why the Bonko run cannot reach stage 5; this harness intentionally does not rebalance it.
2. Boss interval and fatigue/run-length claims remain unproven until a campaign reaches at least two bosses and the stage-9 target. Re-run after the gameplay/balance work lands.
3. The retry transition is responsive in the controlled path, but the fixture does not prove player retention or balance under a normal loss.
4. Runtime visual captures from the real Main framebuffer covered title/menu, unit selection, opening result, and shop/planning states. No blocking crop or overlap was visible; the dark red/black presentation is readable but remains a contrast watch item outside this pacing-only change.

## Validation

- `tests/pacing/PacingMetricsContractTest.tscn` via MCP: `normal=PASS`, `fast=FAIL`, `slow=FAIL`, `suite=FAIL`; debug `errors=[]` for the contract run.
- `tests/pacing/LongitudinalPacingHarness.tscn` via MCP: completed and wrote the two-run report without a script error or assertion failure.
- Real entrypoint exercised: `scenes/Main.tscn`.
- The report renderer includes per-stage timelines and the threshold table; the prior renderer type-conversion failure was fixed and covered by the successful rerun.
