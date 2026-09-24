# Full-corpus analysis of the 29-hour playtest loop, 2026-09-24

A read-only pass over everything the loop recorded (2026-09-21 16:48 -> 2026-09-24 13:40
America/Denver): **571 run directories, 8,299 joined fights, 106,542 events, 40,107 controller
decisions, 121 seeds, 80+ repo revisions**. Eight agents produced it; the artifacts and raw tables
live outside the repo under `E:\CodexStorage\task-artifacts\gamble-battle-analysis-20260924\`.
Start at that directory's `README.md`; this note records only what is durable and actionable.

## Headline

Every encounter tier pays out more than the true odds require, so a stake is +EV in **all four**
tiers and staking everything is correct play:

| tier | fights | pays | break-even | observed win rate | EV per stake |
| --- | ---: | ---: | ---: | ---: | ---: |
| CREEPS | 973 | 1.5x | 66.7% | 100.0% | +0.500 |
| NORMAL | 3,366 | 2.0x | 50.0% | 83.3% | +0.667 |
| BOSS | 2,157 | 3.0x | 33.3% | 52.4% | +0.572 |
| MIRROR | 1,803 | 2.0x | 50.0% | 54.1% | +0.082 |

Only MIRROR is priced honestly. **The predictor is not the problem; the payout table is.** The
displayed odds are pessimistic in three tiers of four (NORMAL quotes 0.593 and delivers 0.833), so
the earlier "the odds model is optimistic on NORMAL" note was measuring the harness's internal edge
against break-even rather than against outcomes. That framing is retired.

## Corrigenda to earlier notes

1. **"Max out at least one trait" is nearly meaningless as recorded.** `maxed` and `maxed_ladder`
   are separate readings (`tests/agent/jev_run_harness.gd:2234-2235`). Five traits are one-rung,
   and Chronomancer `[1]` / Catalyst `[1]` are maxed by a single unit. 428 of 554 runs (77.3%) earn
   the loose flag; **exactly 1 run** maxed a genuine multi-tier ladder. `maxed_ladders` is computed
   by the analyzer but never exported to `runs.csv`.
2. **The trait ladder is effectively binary.** Of 33,981 trait-rows on multi-rung traits, 1.33%
   ever reached tier 1 and tier 2 happened 12 times in the whole corpus. A `[2,4,6,8]` trait needs
   8 same-trait bodies on a <=9-unit board.
3. **The item "slam it on then bench it" complaint does not reproduce** at id level (all 322 cases
   had a same-id copy on the board; 7 maybe left the board; 0 ids vanished).
4. **Backline-in-the-front is fixed**, not a live defect. The pooled 15% is era-conflated: 59.6%
   before `reposition_role_fix`, 0.2% after.
5. **The idle-bankroll complaint is a heuristic-lane artifact** (94.0% of heuristic fights vs 0.0%
   of jev fights). The real jev-side defect is under-sizing, not idling.
6. **The campaign-growth effect is not established.** +0.50 chapters over 30 matched seed-pairs
   against a same-arm repeat spread of +2.00. Needs ~160 runs or a deterministic arm.

## Confirmed, worth acting on

* **Under-betting is systemic.** 42% of rounds (2,907 of 6,890) staked exactly 1 bucket with more
  in hand; 1,890 of those on bands better than +10% per unit. 46% of rounds holding 60+ buckets had
  a small stake *and* a small shop spend (median: carried 1,050, staked 1, spent 6). Cause is in
  `_wager_candidates()`: Kelly against a band table shrunk toward a pessimistic display, with no
  NORMAL row below 0.3, collapses the menu to "1 bucket or all-in".
* **Cost is a cliff the player cannot climb.** Matched on kind and power band, cost-3+ boards win
  +10.5 to +16.7 pp. The player fields a cost-4+ body in 0.1-0.2% of bodies; the enemy fields one in
  13.1% (NORMAL) / 18.7% (BOSS) and has one in 41.3% of BOSS fights. Enemy units reach level 5; no
  player body ever has, and `_level_cap_for` has no tie to the player's cap.
* **The shelf is level-gated, not chapter-gated.** At level 1, 0.0% of 13,985 offers are cost 3+;
  only 33 of 554 runs ever reached level 4. Rich runs never converted: of 74 runs peaking above
  1,000 buckets, 54 never exceeded max unit level 3.
* **The bench saturates because nothing can leave it.** Mean bench 0.30 (ch1) -> 5.41 (ch5) -> 10.0
  (ch10) while the board caps at 9. There is no sell, star, field or formation decision anywhere in
  the rig.
* **CREEPS cannot lose** - 973 fights, 100% won at 1.5x, and in 418 of them the player dealt less
  damage than the creeps.

## Open leads

1. **`heuristic-deep-seed21314-20260924-054939`, chapter 9 stage 4** (rev `6ac5060c75`): four
   attempts, all losses, **quoted odds 0.99**, player power 1.19M -> 2.91M against enemy power
   1,858, player damage 18-50M, `player_alive` 0. The mirror copied the same board, so the stats are
   real and the damage is not applied. Would explain the 0.99 quote on a loss and the mirror power
   blow-ups at chapters 7-8.
2. **A 20% unmodelled income stream**: the chain `gold_before - shop - stake + payout` closes on
   only 78% of 6,431 steps.
3. **`Parse JSON failed`, 679 occurrences** - the single most common failure on disk, ahead of
   every gameplay failure. Then `contract_market_missing` (503 of 540 contract decisions).

## Data to start recording (ranked)

1. `resolution_units: [{id, level, side, damage_dealt, damage_taken, survived}]` in
   `combat_diagnostic` - one gap blocks trait, item and cost attribution at once.
2. `cost` + `primary_role` on `fight_start.player_units[] / enemy_units[] / owned_units[]`.
3. `wager_settled {...}` at settlement, and a `wager_set` for the heuristic lane (it currently
   emits none).
4. `trait_tier_change {trait_id, from_tier, to_tier}`.
5. Export `maxed_ladders` in `runs.csv`.
6. Structured failure causes instead of collapsing everything to `harness_fault`.
7. `ledger_omens`/rank in `run_summary.json` so a run can state its profile.

Full detail, per-question reports and the raw CSV tables are in
`E:\CodexStorage\task-artifacts\gamble-battle-analysis-20260924\`.
