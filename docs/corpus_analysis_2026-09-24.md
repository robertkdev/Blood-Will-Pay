# Full-corpus analysis of the 29-hour playtest loop

| | |
| --- | --- |
| **Analysis date** | 2026-09-24, 13:45-14:35 America/Denver |
| **Corpus window** | 2026-09-21 16:48 -> 2026-09-24 13:40 America/Denver |
| **Status** | complete |
| **Repo impact** | this document only; nothing else under the repo was modified |
| **Artifacts** | `E:\CodexStorage\task-artifacts\gamble-battle-analysis-20260924\` |

A read-only pass over everything the 29-hour loop recorded. Eight agents produced it (four in the
earlier pass: calibration, instrumentation gaps, outcomes, strategy; three in this one: power,
betting, enemy generation; plus the root reconciliation). The raw tables and per-question reports
live in the artifact directory; this note is the durable, in-repo record.

## 1. Scope and corpus map

571 run directories across six roots. The counts quoted by the individual reports differ because
they count different things; all are correct:

| scope | count | table |
| --- | ---: | --- |
| run directories on disk | **571** | `runs.csv` |
| runs with a `run_events.jsonl` | **562** | `events_summary.csv` |
| runs with a `findings.json` | **564** (was 355 when this pass began) | `runs.csv` |
| runs with a judgeable `progression` block | **554** (was 345) | `runs.csv` |
| runs with a `run_result.json` | 482 | `runs.csv` |
| runs contributing a joined fight | 533 | `calibration.csv` |
| **joined fights** | **8,299** (from 8,859 `fight_start`, 8,409 diagnostics) | `calibration.csv` |
| recorded events | 106,542 | `events_summary.csv` |
| controller decisions | 40,107 | `decisions.jsonl` |
| `wager_set` events | 6,980 | `wagers.csv` |
| distinct seeds / repo revisions / rules hashes | 121 / 80-82 / 33 | `calibration.md` |

| root | runs | first run | last run |
| --- | ---: | --- | --- |
| `gamble-battle-jev-run-20260921` | 69 | 09-21 07:33 | 09-24 14:05 |
| `gamble-battle-jev-run-20260922` | 277 | 09-22 15:13 | 09-24 14:06 |
| `gamble-battle-jev-run-20260923` | 204 | 09-23 09:35 | 09-24 14:07 |
| `gamble-battle-jev-run-20260924` | 5 | 09-24 10:15 | 09-24 14:08 |
| `gamble-battle-jev-run-20260924b` | 5 | 09-24 10:59 | 09-24 11:22 |
| `gamble-battle-growth` | 11 | 09-24 13:02 | 09-24 14:08 |

## 2. The data gap this pass closed

209 runs had events on disk but had never been through the analyzer. Running the loop's own
deterministic `tools/jev/analyze_jev_run.py` over them (206 ok, 0 failed, no model) and
regenerating via `extract.ps1` recovered them. **Every success-criterion denominator roughly
doubled because of that**, so the refreshed numbers in section 5 supersede the earlier ones.
7 runs still have no `findings.json`; they have no `run_events.jsonl` either.

## 3. Headline: the payout table, not the predictor

Every encounter tier pays out more than the true odds require, so a stake is +EV in **all four**
tiers and staking everything is correct play:

| tier | fights | pays | break-even | observed win rate | EV per stake |
| --- | ---: | ---: | ---: | ---: | ---: |
| CREEPS | 973 | 1.5x | 66.7% | 100.0% | +0.500 |
| NORMAL | 3,366 | 2.0x | 50.0% | 83.3% | +0.667 |
| BOSS | 2,157 | 3.0x | 33.3% | 52.4% | +0.572 |
| MIRROR | 1,803 | 2.0x | 50.0% | 54.1% | +0.082 |

Only MIRROR is priced honestly. Independently recomputed by the root from `calibration.csv`; it
reproduces the earlier table exactly. The displayed odds are *pessimistic* in three tiers of four
(NORMAL quotes 0.593 and delivers 0.833), so **the predictor is not the problem**. That is why the
bankroll compounds to 2.3e11 in the tail and why "stake everything" is correct.

## 4. Corrections to earlier notes (recorded 2026-09-24)

1. **"The odds model is optimistic on NORMAL" is retired.** `strategy.md` section 2 measured the
   harness's internal `measured_edge` against the 0.50 *break-even* and called the result an
   over-confident model. Against outcomes the display is pessimistic in 3 of 4 tiers. The failure
   is the payout table. The out-of-sample check also found the rig's own Jev choices beat the
   deterministic mechanical rule (125 better / 212 worse), so the model adds value and should keep
   choosing; only the rate it sizes against needs fixing.
2. **"Max out at least one trait" is nearly meaningless as recorded.** `maxed` and `maxed_ladder`
   are separate readings defined side by side at `tests/agent/jev_run_harness.gd:2234-2235`. Five
   traits are one-rung (Cartel `[2]`, Harmony `[2]`, Kaleidoscope `[2]`, and Chronomancer `[1]` /
   Catalyst `[1]`, which a *single unit* maxes). 428 of 554 runs earn the loose flag; **exactly 1
   run** maxed a genuine multi-tier ladder. Two independent methods agree. `maxed_ladders` is
   computed by the analyzer but never exported to `runs.csv`.
3. **The trait ladder is effectively binary.** Of 33,981 trait-rows on multi-rung traits, 1.33%
   ever reached tier 1 and tier 2 happened 12 times in the whole corpus. A `[2,4,6,8]` trait needs
   8 same-trait bodies on a board of at most 9 units.
4. **The "slam items on a unit then bench it" complaint does not reproduce** at id level. All 322
   cases had a same-id copy on the board; 7 may have left the board; 0 ids vanished. Settling it
   needs a per-instance `unit_key` in `fight_start`.
5. **Backline-in-the-front is fixed, not live.** The pooled 15% is era-conflated: 59.6% before
   `reposition_role_fix`, 0.2% after (17 of 8,236).
6. **The idle-bankroll complaint is a heuristic-lane artifact** (94.0% of heuristic fights vs 0.0%
   of jev fights). The real jev-side defect is under-sizing, not idling.
7. **Campaign growth is not established.** +0.50 chapters over 30 matched seed-pairs against a
   same-arm repeat spread of +2.00. Needs roughly 160 runs per arm, or a deterministic arm.
8. **The enemy-generation audit of 2026-09-23 stays valid**, and this pass re-tested its invariants
   against the full corpus: no composition bugs.

## 5. Success criteria against actual results

Judgeable runs only (denominator present), refreshed after the backfill:

| criterion | hits | judged | rate |
| --- | ---: | ---: | ---: |
| 3-star at least one unit | 127 | 554 | 22.9% |
| max out at least one trait (loose reading) | 428 | 554 | 77.3% |
| max out at least one trait (real multi-tier ladder) | **1** | 554 | **0.2%** |
| fully build out a board | 494 | 554 | 89.2% |
| 8+ completed items | 20 | 546 | 3.7% |
| reach chapter 5 / 8 / 10 | 91 / 15 / 3 | 555 | 16.4% / 2.7% / 0.5% |

Terminals: loss 277, stage_stall 211, target_reached 26, in_progress 20, aborted 12,
controller_lost 5, technical_failure 4, unrecorded 16. Deepest chapter anywhere: 10.

Best run on record: `jev-deep-seed21356-20260924-104644` - chapter-10 `target_reached`,
56 battles, peak **230,683,256,528** buckets, 7 three-stars, 3 maxed traits, 9/9 board, 15 items,
zero technical failures. Peak bankroll overall: median 12, p90 2,486. 68 runs peaked above 1,000
buckets, 115 above 100. The "gambling" goal is met in the tail and absent in the body.

## 6. The design questions, answered

**Are traits useless? Cannot tell - and the ladder is effectively binary.** Raw "more traits wins
more" is a depth proxy (mean active traits 2.84 in ch1 -> 5.82 in ch10). Centred within run *and*
chapter the correlation is **+0.028** (7,481 fights / 407 runs). At matched encounter kind and
matched power-ratio band the player wins **more** against enemies carrying 2+ active traits
(+10.7 pp pooled, 8 cells / 4,020 fights), i.e. enemy trait slots behave like rating padding.

**Do higher-cost units matter? Yes - and the sharper finding is the supply gap.** Matched on kind
and power band, boards whose priciest unit is cost 3+ win **+10.5 to +16.7 pp** (NORMAL 84.2% ->
94.7%, n=734/171; BOSS 42.3% -> 58.9%, n=430/107). But the player fields a cost-4+ body in
**0.1-0.2%** of bodies while the enemy fields one in **13.1% (NORMAL) / 18.7% (BOSS)**, and has
one in **41.3% of BOSS fights**. A player whose best unit is cost 1 meets a cost-4/5 boss in
**262 fights (20.3%)**. MIRROR is the one tier where cost cancels, by construction: enemy top cost
correlates 0.919 with the player's and is never above it.

**Does levelling help? The gate is established, the payoff is suggestive.** The shelf is gated on
*level*, not chapter: at level 1, **0.0%** of 13,985 offers are cost 3+; level 4 -> 14.0%; level 7
-> 44.2% - and at chapter 7+, level 1 is still 0.0% (n=165). Only **33 of 554 runs (6.0%)** ever
reached level 4. Within the jev lane, best unit level 1->4 walks mean final chapter **1.17 ->
2.26 -> 4.14 -> 6.70** (n=76/258/107/20) against a 1.75-chapter noise floor. The money was never
converted: of 74 runs peaking above 1,000 buckets, **54 never exceeded max unit level 3**, and the
2.3e11-bucket chapter-10 run bought XP twice.

**Is the difficulty curve backwards? No for bosses.** Mean BOSS `enemy_power / player_power`
escalates **0.81 -> 1.80** across chapters 1->7, so late bosses are harder than early ones, as
designed. Observed win rate is not monotone (ch1 82.2%, ch2 63.1%, ch3 72.3%, ch4 79.0%,
ch7 65.2%, ch9 54.4%) - mostly survivorship, since only strong boards reach later chapters. Use
the power ratio as the difficulty measure.

## 7. The betting layer

"Jev is not betting all-in when it should" is **correct and systemic, not anecdotal**:

* **2,907 of 6,890 rounds (42%) staked exactly 1 bucket with more in hand** - and 1,890 of those
  were on bands worth better than +10% per unit.
* **959 of 2,078 rounds holding 60+ buckets (46%)** had a small stake *and* a low shop spend. The
  median of those carried 1,050 buckets, staked **1**, and spent 6. A rich round's median shape is
  the reported "60 buckets, spent 4, bet 2".
* The opposite failure is real but 15x smaller: 114 of 2,326 all-ins (5%) went in below the
  displayed break-even and lost 84%.

Mechanism, from the code: `_wager_candidates()` sizes Kelly off a hand-written band table shrunk
toward the display by `prior_strength: 20`. Below a 0.5 quote on a 2x tier Kelly lands at or below
zero, so the four-candidate menu collapses to "1 bucket or the whole bankroll", and the band table
has **no NORMAL row below 0.3** - where it falls back to the display it has already documented as
pessimistic. That is why the median stake fraction *falls* from 0.600 at 5-10 buckets to 0.112
above a million while the all-in share rises 29% -> 42%: the rig goes bimodal as it gets rich.

Highest-leverage fix: swap only the rate the menu is built from (Kelly at the realised kind x
displayed-band rate, band table extended down to 0.1), leaving the formula, the all-in bar, the 25%
retry cap and the 2-bucket floor alone. Out of sample that improves **305 of 429 runs**, worsens
111, p90 +112 buckets.

Side findings: a **20% unmodelled income stream** (the chain
`gold_before - shop - stake + payout` closes on only 78% of 6,431 steps; the rest gain a median
+25% of the next round's bankroll), and **CREEPS cannot lose** - 973 fights, 100% won at 1.5x, and
in 418 of them the player dealt less damage than the creeps and still won.

## 8. Rig behaviour: what was real and what was not

| complaint | verdict |
| --- | --- |
| "goes in with gold neither bet nor spent every round" | **heuristic-lane artifact.** 94.0% of heuristic fights (1,420/1,511) vs **0.0%** of jev fights (1/7,348). The jev lane always stakes; it stakes small. |
| "positions backliners in the front" | **real historically, fixed now.** Pooled 15.0% is era-conflated: 59.6% before `reposition_role_fix` vs 0.2% after. |
| "slams items on a unit then benches it" | **not reproduced.** 322 equips had the carrier's id benched next fight, but all had a same-id copy on the board; 7 maybe left the board, 0 ids vanished. |
| "hoards units on the bench" | **real, and it is a harness capability gap, not a choice.** Mean bench 0.30 (ch1) -> 1.66 (ch2) -> 3.64 (ch3) -> 5.41 (ch5) -> saturates at **10.0 by ch10** while the board caps at 9. There is **no sell, star, field or formation decision anywhere** in the rig, so nothing can leave the bench. |
| "buys a second copy instead of fielding the loaded one" | **52.5% of boards (4,326/8,247) carry a duplicate unit id** - the star-up mechanic working, not a misplay. |

Failure volume is dominated by the rig: 207 distinct failure messages, 998 ERROR/SCRIPT ERROR
lines. Top: `Parse JSON failed` (**679 occurrences**), `contract_market_missing` (503 of 540
contract decisions), `stage_stall_after_4_attempts` (167), `wiped` (125), `clock_outnumbered`
(72). `click_fallback` fired 1,581 times, concentrated on shop slots and reroll.

## 9. Enemy generation

Composition logic is **clean**: zero empty teams, zero zero-power teams, `enemy_body_count` always
equals the id count, no duplicate ids outside MIRROR, no over-cap boards, no duplicate or negative
tiles in 8,800 `fight_start`s. Seed determinism is fixed and holding (0 differing non-mirror
same-seed groups across the 26 revisions after `5746feb81c`; the 19.9% pooled figure is pre-fix
history). The "identical boards across different seeds" cases are the authored four-template
chapter-1 runway plus the four-id creep pool.

Two real mismatches, both undefended in the code:

* **Levels.** The enemy reaches level 5; no player body has ever been level 5 (49,944 bodies, max
  4). Chapter-2 NORMAL already fields 10 bodies at level 4+ including a level-5 body while a
  player's chapter-2 ceiling is 3. `_level_cap_for` (`endless_chapter_generator.gd:773-780`) has
  no tie to the player's cap.
* **Cost.** Recent-era boss enemy bodies are **29.6% cost-4/5** (177 of 597) against **0 of 855**
  player bodies. The earlier 22% figure reproduces and is worse now.

## 10. Open leads

1. **`heuristic-deep-seed21314-20260924-054939`, chapter 9 stage 4** (rev `6ac5060c75`): four
   attempts, all losses, **quoted odds 0.99**, player power 1.19M -> 2.91M against enemy power
   1,858, player damage 18-50M, `player_alive` 0. The mirror copied the same board at 270,543
   power, so the inflated stats are real and the damage is not applied. Enemy-side scaling is ruled
   out (`EnemyScaling.ENABLED == false`, `stat_scale` clamped to 4.0, spawned power matches
   target). One defect would explain the 0.99 quote on a loss, the mirror power blow-ups at
   chapters 7-8, and every power ratio in those 30 fights.
2. **A 20% unmodelled income stream** (section 7).
3. **`Parse JSON failed`, 679 occurrences** - the most common failure on disk, ahead of every
   gameplay failure. Then the contract-market path (503 missing + 96/94 "no actionable PASS
   choice").

## 11. Data to start recording, ranked by what it blocks

1. `resolution_units: [{id, level, side, damage_dealt, damage_taken, survived}]` in
   `combat_diagnostic` - this single gap blocks trait usefulness, item placement and cost value at
   once.
2. `cost` + `primary_role` on `fight_start.player_units[] / enemy_units[] / owned_units[]`; cost
   currently has to be re-joined to today's catalogue across 80 revisions.
3. `wager_settled {applied, stake_odds, shown_win_odds, result, payout_buckets, buckets_delta}`
   at settlement, and a `wager_set` for the heuristic lane, which emits none - the deepest run in
   the corpus stakes every fight and records reasoning for none of them.
4. `trait_tier_change {trait_id, from_tier, to_tier}` - the fight where a ladder flipped is
   currently unrecoverable.
5. Export `maxed_ladders` in `runs.csv`; the analyzer computes it but `extract.ps1` drops it.
6. Structured failure causes instead of collapsing everything to `harness_fault` - the deepest run
   *won* its last fight and is still filed `failed: true`.
7. `ledger_omens` / rank in `run_summary.json` and `run_result.json`, so a run can state which
   profile it played.
8. A recorded intent for star / sell / field / formation; none exists, and the missing sell action
   is why the bench saturates.

## 12. Artifact inventory

All under `E:\CodexStorage\task-artifacts\gamble-battle-analysis-20260924\`, all written
2026-09-24 between 13:48 and 14:19 America/Denver.

**Synthesis and question answers**

| file | written | question |
| --- | --- | --- |
| `README.md` | 14:19 | index, corpus reconciliation, corrigenda |
| `arms_and_growth.md` | 13:51 | campaign-growth arms and the noise floor |
| `outcomes.md` | 14:08 | terminals, chapters, criterion hit rates |
| `strategy.md` | 13:58 | decision mix, wagers, items, positioning, failures |
| `calibration.md` | 13:55 | odds calibration, enemy generation, field audit |
| `field_notes.md` | 13:55 | absent/empty fields |
| `instrumentation_gaps.md` | 13:51 | what to instrument next |
| `power_audit.md` | 14:12 | traits, cost tiers, levelling |
| `gamble_audit.md` | 14:17 | wager-vs-predictor, EV, payout table |
| `enemy_gen_bugs.md` | 14:13 | generator invariants and bugs |

**Detailed sub-reports**: `trait_power_report.md` (14:09), `maxed_trait_power_report.md` (14:11),
`cost_power_report.md` (14:06), `enemy_cost_power_report.md` (14:09), `xp_power_report.md`
(14:12).

**Tables**: `runs.csv` 571x25 (14:08), `events_summary.csv` 562x77 (13:58), `calibration.csv`
8,299 fights (13:51), `wagers.csv` 6,980 (13:58), `failures.csv` (13:58), `batches.csv` (13:48),
`positioning_by_role.csv` and `wager_by_quote_kind.csv` (13:58), `fights_power.csv` /
`offers_power.csv` / `buys_power.csv` (14:05), `fights_gamble.csv` / `wagers_gamble.csv` (14:08).

**Method**: read-only scripts in the same directory, each named for its question
(`extract.py`, `stats.py`, `verify.py`, `paired2.py`, `extract.ps1`, `extract_power.py`,
`trait_power.py`, `maxed_trait_power.py`, `trait_ladder_power.py`, `cost_power.py`,
`enemy_cost_power.py`, `xp_power.py`, `extract_gamble.py`, `analyze_gamble.py`,
`chain_gamble.py`, `helpers_gamble.py`, `enemy_invariants_enemy.py`, `enemy_drilldown_enemy.py`,
`enemy_seedprobe_enemy.py`, `enemy_tiles_enemy.py`, `enemy_roles_enemy.py`,
`enemy_escalation_enemy.py`).

## 13. Provenance

Agents, all read-only on the repo:

| agent | scope | finished |
| --- | --- | --- |
| calibration | 8,299-fight join, odds calibration, enemy generation stats | 2026-09-24 ~13:55 |
| gaps | instrumentation audit | 2026-09-24 ~13:51 |
| outcomes | per-run outcomes and progression | 2026-09-24 ~14:08 |
| strategy | event-level behaviour | 2026-09-24 ~13:58 |
| power_audit | traits, cost, levelling | 2026-09-24 ~14:12 |
| gamble_audit | betting layer | 2026-09-24 ~14:17 |
| enemy_gen_bugs | generator invariants and bugs | 2026-09-24 ~14:13 |

Root reconciliation, the `findings.json` backfill of 209 runs, and this document: 2026-09-24
14:05-14:35. The two untracked files `tools/jev/_tmp_cost_tier_audit.py` and
`tools/jev/_tmp_position_audit.py` pre-date this pass and were left as found.

Related in-repo notes from the earlier loop, still valid unless contradicted above:
`docs/enemy_generation_audit_2026-09-23.md`, `docs/odds_calibration_by_encounter_2026-09-24.md`,
`docs/campaign_growth_ab_2026-09-24.md`, `docs/item_rate_against_chapter_10_2026-09-24.md`.
