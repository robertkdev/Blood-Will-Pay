# Pacing policy comparison - 2026-08-02

## Decision

The current stage-4 failure is primarily an automation-policy failure, with an
economy interaction that makes the weak policy visible. It is not enough
evidence to rebalance the boss. The natural policy buys too conservatively and
can reserve gold while leaving the board under-cap; the competent comparator
spends on duplicate/role value and releases the level reserve when the board is
blocked. This changes first-boss reachability without changing combat, shop, or
results production logic.

## Falsifiable comparison

Both policies use the real `scenes/Main.tscn` flow, starter `bonko`, shop seed
4401, the same pacing delays, and the same production economy/progression.
The harness records `policy_round_start`, `policy_round_result`, purchases,
gold before/after shop, level/cap, board/bench, combat power, estimated odds,
combat duration, result dwell, recovery, and advancement for every stage.

| Policy | First-boss trace | Result | Interpretation |
| --- | --- | --- | --- |
| natural baseline | Stages 1-3 advance; stage 4 reaches the shop/boss gate with a four-unit board. The integrated baseline report ends at the stage-4 boss with four units and 0 gold. | FAIL: no stage-9 runway or second boss | Reproduces the pacing failure. The fresh MCP run also emitted repeated stage `1:4`, `advanced=false` shop results with `board=4`; no script error was reported. |
| competent-player-equivalent | The parent-side comparator reaches stage 4 with `bonko,grint,sari,mara`, player power `127.59`, enemy power `174.56`, estimated odds `38%`, and wins; it advances through stage 5 before a later stage-6 technical stop with board 4, bench `mara`, gold 4. | PASS through first boss; longitudinal closure still pending | The first-boss result changes when only purchase/deploy/XP policy changes. That falsifies a boss-only explanation, but the later cap/economy stop remains a real harness finding. |

The parent-side competent artifact is the read-only comparator at
`%APPDATA%\\Godot\\app_userdata\\Blood Will Pay\\pacing\\competent_policy_pacing_suite.json`.
The current branch extends that policy with a controlled low-cost XP release
when a non-empty bench is blocked by the current cap, and retains the full
comparison artifact rather than hiding the later failure.

## Root-cause split

* Automation: primary. The natural policy's one-buy/hold behavior and weak offer
  scoring are materially different from a reasonable player. The competent
  comparator wins the same first boss and continues to stage 5.
* Economy pacing: contributing constraint, not yet a production defect. The
  comparator's stage-6 trace has board 4, bench `mara`, and gold 4; the board
  cannot grow because the safe XP threshold is 6. The harness now records this
  as a policy decision and tests a reserve release, without changing Economy.
* Boss tuning: not proven responsible. The observed first-boss comparator win,
  together with calibration supplied for this investigation (boss
  low/mid/high preparation rates 25.0%/47.22%/77.78%; normal predicted/observed
  50.0%/52.08%; boss predicted/observed 58.25%/50.0%), does not justify a blind
  boss nerf. Revisit boss tuning only after a competent policy fails with a
  full, levelled board and adequate reserve.

## Targeted falsification gates

1. `PacingMetricsContractTest.tscn`: normal rhythm passes; known-fast and
   known-slow traces fail; the mixed suite fails. This proves the analyzer can
   reject bad pacing rather than merely count completed fights.
2. `PacingRecorderParseTest.tscn`: loads the recorder and its telemetry
   dependencies without a production scene.
3. Side-by-side Main flow: same seed and entrypoint, policy is the only
   intentional variable. A first-boss result that does not differ rejects the
   automation diagnosis; a competent run that fails with strong board/power
   and reserve rejects the "automation only" diagnosis and reopens economy or
   boss tuning.
4. Longitudinal target: the campaign sample must reach global stage 10, which
   means stage 9's boss has resolved, and must preserve two boss intervals in
   the per-stage timeline. A lower terminal stage remains FAIL, not a green
   aggregate.

## Current verdict and remaining risk

The harness and instrumentation are ready for this decision, but the current
legacy-MCP run was still executing when this report was written and the
Godot-AI editor session had dropped, so no fresh stage-9 artifact or runtime
framebuffer screenshot is claimed here. The honest current verdict remains
`FAIL/BLOCKED` for longitudinal closure until a fresh competent run reaches
stage 10 and a player-facing Main.tscn screenshot is captured. No production
combat, shop, results, economy, or boss code was changed.
