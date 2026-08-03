# Gamble Battle pacing verdict - 2026-08-02

## Verdict

The real `scenes/Main.tscn` pacing harness is now green for the controlled
competent-policy campaign and the scoped loss/retry fixture. The campaign
reached stage 10, observed two bosses (stages 4 and 9), and resolved the stage-9
boss. The natural Bonko route remains a deliberately retained comparison: it
can lose at stage 4 when it spends its runway, so it is not used as a universal
player-policy claim. Reaching stage 10 is a longitudinal stress check, not a
requirement for declaring combat balance; the balance acceptance gate is the
calibrated skill-plus-luck evidence in the boss odds report.

## Fresh competent-policy evidence

Artifacts:

- `user://pacing/competent_policy_pacing_suite.json` (fresh Main.tscn event capture)
- `user://pacing/competent_policy_pacing_report.md` (original capture report)
- `user://pacing/competent_policy_pacing_reanalysis_suite.json`
- `user://pacing/competent_policy_pacing_reanalysis_report.md` (contract re-analysis)
- `%APPDATA%\\Godot\\app_userdata\\Blood Will Pay\\pacing\\`

The first capture report flagged only `max_dead_time_seconds:too_slow`: the
chapter-contract pass was followed by an intentional planning wait and had not
yet been classified as a planning boundary. `PacingReportReanalysisTest.tscn`
recomputed that metric with the corrected recorder helper over the unchanged
raw events; the resulting report is **PASS**.

| Stage | Kind | Plan s | Actions | Actions/min | Combat s | Result dwell s | Recovery s | Shop decision s | Dead gap s |
| ---: | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | CREEPS | 5.25 | 1 | 11.42 | 4.67 | 6.09 | 0.14 | N/A | 4.09 |
| 2 | NORMAL | 16.50 | 4 | 14.54 | 8.23 | 6.04 | 0.20 | 2.76 | 6.98 |
| 3 | NORMAL | 7.23 | 0 | 0.00 | 15.78 | 6.02 | 0.16 | N/A | 0.00 |
| 4 | BOSS | 10.86 | 2 | 11.05 | 44.95 | 6.03 | 0.14 | 4.21 | 4.17 |
| 5 | MIRROR | 7.77 | 2 | 15.44 | 38.98 | 6.01 | 0.10 | 5.66 | 6.06 |
| 6 | CREEPS | 10.90 | 0 | 0.00 | 5.93 | 6.03 | 0.22 | N/A | 0.00 |
| 7 | NORMAL | 18.93 | 13 | 41.21 | 44.94 | 6.04 | 0.15 | 4.60 | 7.93 |
| 8 | NORMAL | 12.29 | 0 | 0.00 | 19.02 | 6.02 | 0.28 | N/A | 0.00 |
| 9 | BOSS | 12.62 | 2 | 9.51 | 37.36 | 6.03 | 0.15 | 9.14 | 7.99 |

Guardrails are planning 1-60 s, action-density p50 1-30 actions/min, combat
0.75-50 s (boss max 90 s), result dwell 1-8 s, recovery 0-5 s, shop decision
1-45 s, unexplained dead time max 8 s, boss interval p50 4-6 stages, and target
stage 10 for this competent fixture. Preview-to-combat and contract-pass-to-
combat waits are counted as planning, not unexplained stalls.

## Other gates

- Controlled pacing contract: normal PASS; known-fast FAIL; known-slow FAIL;
  loss/retry PASS; mixed suite FAIL as intended.
- Result/shop interaction latency: fresh manifest has no failures; result hide
  3.66 ms, first observed frame 32.58 ms, settled 175.04 ms, and exactly one
  cleanup after eight repeated accepts. Reroll 24.01 ms, lock 0.15 ms, Buy XP
  3.84 ms, purchase 35.25 ms, drag/deploy 1.49 ms, and menu 1.53 ms.
- Shop correctness, transactional Buy XP, affordability reserve, board
  purchase/combine, and purchase feedback smoke gates pass; normal duplicates
  remain allowed and opening-helper diversity is enforced.
- Hard stability audit: PASS; failures `[]`, teardown calls 6, rapid reset 6,
  system-menu 8, deferred-reset 2, loss recovery 2, rapid shop rerolls 12,
  same-frame shop presses 5, and 12v12 watchdog pass.

The dedicated result-dismissal interaction gate owns skip latency; the pacing
harness reports that metric as N/A rather than duplicating it.
