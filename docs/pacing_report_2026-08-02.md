# Gamble Battle pacing verdict - 2026-08-02

## Verdict

The longitudinal `scenes/Main.tscn` pacing harness is operational and remains
**FAIL** for one honest reason: the natural Bonko campaign loses at the first
boss (stage 4), so it cannot prove a stage-9 runway or an interval between two
bosses. The scoped loss/retry sample is **PASS**. Timing guardrails pass over
the four observed campaign stages.

This verdict must not be converted to green by forcing a boss win. The harness
is now useful precisely because it separates transition rhythm from balance
and competent-player-policy reachability.

## Fresh combined-build evidence

Artifacts:

- `user://pacing/longitudinal_pacing_suite.json`
- `user://pacing/longitudinal_pacing_report.md`
- `%APPDATA%\Godot\app_userdata\Blood Will Pay\pacing\longitudinal_pacing_report.md`

| Stage | Kind | Planning s | Actions/min | Combat s | Result dwell s | Recovery s | Shop decision s | Dead gap s |
| ---: | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | CREEPS | 3.20 | 18.74 | 4.65 | 6.00 | 0.17 | N/A | 2.08 |
| 2 | NORMAL | 7.15 | 16.79 | 16.00 | 6.03 | 0.17 | 2.75 | 2.09 |
| 3 | NORMAL | 7.13 | 16.83 | 22.81 | 6.01 | 0.35 | 2.73 | 2.07 |
| 4 | BOSS | 8.84 | 13.57 | 15.90 | 5.95 | 0.10 | 4.19 | 5.95 |

The terminal campaign state was a stage-4 boss loss with a four-unit board and
zero gold. The separate forced-loss fixture reached the production loss screen
and returned to unit selection in 0.08 seconds. It is scope-aware: planning,
shop, action-density, boss cadence, and run length are explicitly N/A rather
than false failures.

Result-screen skipping is player-facing and was validated separately by
`InteractionLatencySmoke.tscn`: immediate hide 5.1 ms, first observed frame
18.4 ms, and full settlement 189.1 ms. The pacing harness does not duplicate
that latency measurement.

## Contract validation

- Controlled normal rhythm: PASS.
- Deliberately too-fast rhythm: FAIL as intended.
- Deliberately too-slow rhythm: FAIL as intended.
- Scoped loss/retry rhythm without a planning beat: PASS, planning N/A.
- Mixed suite containing the falsification cases: FAIL as intended.

## Remaining decision

Do not declare longitudinal pacing green until a competent natural campaign
reaches at least stage 9 and two bosses. The next investigation should compare
the harness's purchase/deployment policy against a competent-player policy and
then decide whether the failure belongs to boss tuning, economy preparation,
or the automated player's decisions.
