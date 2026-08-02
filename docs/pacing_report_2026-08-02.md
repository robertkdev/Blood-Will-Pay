# Gamble Battle pacing verdict - 2026-08-02

## Verdict

The longitudinal `scenes/Main.tscn` pacing harness is operational and remains
**FAIL/BLOCKED for closure**: the natural Bonko campaign loses at the first
boss (stage 4), while the competent comparator wins that boss and reaches stage
5 before a later cap/economy automation stop. A fresh stage-9/two-boss artifact
and runtime framebuffer capture are still required before declaring green. The
scoped loss/retry sample is **PASS**. Timing guardrails pass over the observed
campaign stages.

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

## Policy diagnosis

The same-seed competent comparator reaches the stage-4 boss with
`bonko,grint,sari,mara`, player power `127.59`, enemy power `174.56`, and
estimated odds `38%`, then wins and advances to stage 5. Its later stage-6 stop
has board 4, bench `mara`, and gold 4, exposing the cap/XP reserve constraint.
The current test-only policy adds a controlled XP reserve release when a bench
is blocked at cap and preserves both policy reports in
`user://pacing/policy_comparison.json`. This is an automation diagnosis, not a
production rebalance; see `docs/pacing_policy_comparison_2026-08-02.md`.

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
