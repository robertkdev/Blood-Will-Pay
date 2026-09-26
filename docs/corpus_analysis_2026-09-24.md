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

## 3. Headline: every tier is +EV, and that is deliberate

Every encounter tier pays out more than the true odds require, so a stake is +EV in **all four**
tiers and staking everything is correct play:

| tier | fights | pays | break-even | observed win rate | EV per stake |
| --- | ---: | ---: | ---: | ---: | ---: |
| CREEPS | 973 | 1.5x | 66.7% | 100.0% | +0.500 |
| NORMAL | 3,366 | 2.0x | 50.0% | 83.3% | +0.667 |
| BOSS | 2,157 | 3.0x | 33.3% | 52.4% | +0.572 |
| MIRROR | 1,803 | 2.0x | 50.0% | 54.1% | +0.082 |

Independently recomputed by the root from `calibration.csv`; it reproduces the earlier table
exactly. Only MIRROR is close to fairly priced.

**Designer ruling, 2026-09-24 - this is intended, and the recommendation to reprice it is
withdrawn.** In his words: *"to a computer who can calculate odds it should be 100% subsidy. from
the players perspective that changes because they only see the odds predicted at the beginning of
planning phase. they have to guess if they upgraded enough to win on their own and that's the
gamble."* So the +EV is the reward for reading your own board correctly, and the risk lives in the
player's uncertainty rather than in the price. Do **not** lower the multipliers toward break-even;
that would delete the intended payout.

Two consequences worth keeping straight:

- The bankroll reaching 2.3e11 is what an unconstrained +EV loop does. It is a symptom to design
  around (see the ledger work), not evidence of a pricing bug.
- The displayed-vs-realised gap is still worth a look, but as an **information** question rather
  than a pricing one. NORMAL displays 0.593 and delivers 0.833, so the number the player uses for
  their self-assessment systematically under-promises. If the gamble is meant to be the player's
  own read of their board, an honest display makes that read meaningful; a display that is 24
  points low makes the game feel harder than it is and makes the rig under-stake. Recalibrating the
  display toward outcomes is consistent with the design; repricing the payout is not.

## 4. Corrections to earlier notes (recorded 2026-09-24)

1. **"The odds model is optimistic on NORMAL" is retired, and so is the payout-table
   recommendation that briefly replaced it.** `strategy.md` section 2 measured the harness's
   internal `measured_edge` against the 0.50 *break-even* and called the result an over-confident
   model; measured against outcomes the display is *pessimistic* in 3 of 4 tiers. That gap is not
   a pricing error - the designer confirmed on 2026-09-24 that a computer able to recompute the
   odds is meant to find the wager a straight subsidy, and that the gamble is the player's own
   guess about their upgrades (section 3). What remains a defect is the rig's sizing: the
   out-of-sample check found the rig's own Jev choices beat the deterministic mechanical rule
   (125 better / 212 worse), so the model adds value and should keep choosing; only the rate it
   sizes against needs fixing.
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

## 14. Designer rulings of 2026-09-24, and the actions they triggered

Answers given to the six open questions, recorded verbatim where the wording carries the design
intent.

| # | ruling | action |
| --- | --- | --- |
| 1 | *"to a computer who can calculate odds it should be 100% subsidy. from the players perspective that changes because they only see the odds predicted at the beginning of planning phase. they have to guess if they upgraded enough to win on their own and that's the gamble."* | **Repricing withdrawn.** Section 3 rewritten; the displayed-vs-realised gap reclassified from a pricing defect to an information question. |
| 2 | Reach rate should scale with account-wide upgrades, modelled on the incremental game "The Tower": first run goes nowhere, a beefed-up account outscales the early game. "we need to improve our ledger upgrades. start by researching the tower." | Research in flight: `tower_ledger_brief.md`. |
| 3 | *"i meant the verticals ... i wanted several runs of different vertical traits so we could compare their viability. the low max traits are more for flex play rather than forcing vert."* | Comparative vertical-trait viability in flight: `trait_verticals.md`. |
| 4 | The player should be able to max their level, prioritised when they hold an econ lead and can ride the current board for a couple of rounds. | Quantified in flight: `level_economy.md`. See the known rig defect below. |
| 5 | *"the rig should be allowed to sell. selling is a big part of the game. selling is crucial to building a board with flex play."* | A `sell` decision kind is being added to the rig. |
| 6 | *"there should only be one game"* | Confirmed: there is only one. See below. |

**Ruling 4 already has a known rig-side cause and an unused fix.** The harness docblock
(`tests/agent/jev_run_harness.gd:23-40`) records that the model's levelling rule "turns out to have
no reachable off-switch" - it holds off while cheap pairs remain the best value, which on a
level-3 shelf is permanently true - and that one run "sat at shop level 2 holding 58,490
buckets". An opt-in policy already implements exactly the rule the designer describes:
`JEV_LEVEL_POLICY=eager` buys the level deterministically when the bankroll is at least 20x the XP
price and the level is still below 7 (`EAGER_LEVEL_TARGET`, `EAGER_LEVEL_PRICE_BANKROLL_RATIO`),
bypassing the model only for that one decision class so an A/B differs in nothing else. It is off
by default. So part of the answer to "can the player ever max out their level" is that the rig
chooses not to, and that choice is already fixable without touching the game.

**Ruling 6: there is only one game, and the confusion was a reporting artifact.** `JEV_MODE=heuristic`
replays the *same* scene, seed, starter and click path through the harness's inherited rule-based
policy instead of asking Jev; the harness docblock calls it "a comparable baseline on identical
seed and starter" (`jev_run_harness.gd:17-18`). It is a control arm, not a second game. The defect
was that analyses pooled it: it emits no `wager_set` and no `buy_xp` at all and never combines a
unit past level 1, which is what manufactured the "enters every round with money neither bet nor
spent" finding and flattened the levelling gradient. Reporting rule from here on: **never pool the
two arms.** Balance statistics use the Jev arm only; the control arm is the low-variance
deterministic baseline that `arms_and_growth.md` recommends for growth A/B work.

## 15. Follow-up work on the rulings

Deliverables in `E:\CodexStorage\task-artifacts\gamble-battle-followup-20260924\`.

### 15.1 The shape of the failure is a wall, not a bell

**351 of 555 runs (63%) die at chapter 1 or 2** (112 at ch1, 239 at ch2). There is no smooth
difficulty ramp to tune: there is a wall at chapter 2 with a thin tail behind it. Two related
readings: a chapter-10 run's best unit averaged **level 2**, *below* the chapter-6 average, so
depth is not coming from levelling; and board size saturates at 9 against a `MAX_BOARD_CAPACITY`
of 16, leaving seven slots no upgrade currently reaches.

### 15.2 Ledger: the "The Tower" research and the first build

Game identified: **The Tower - Idle Tower Defense** (Tech Tree Games), picked on the loop rather
than the name. Its second run is faster than the first through, in particular, **Enemy Level
Skip** (a deterministic difficulty-floor reduction, not a stat buff) and **Intro Sprint** (skip
up to your best wave in the tier, paying no coins for the skipped section). Its permanent layer is
six stacked systems, and the large multipliers are deliberately kept separate from the
speed-of-restart systems.

Ranked first of six proposals: a **chapter floor** bought with Omens - rank 15 starts you at
chapter 2, 30 -> ch3, 45 -> ch4, 60 -> ch5 (25 / 134 / 616 / 2,738 lifetime Omens, so the first
gate lands after one or two runs). Skipped chapters pay **no buckets and no first-clear items**,
but still bank their Omens, so no run is wasted.

Why that one: it is the ruling verbatim, and it is **the only proposal the current rig can
prove**. Floor 3 measures +0.72 mean chapters at paired sd 0.72 (sem 0.03) and floor 4 measures
+1.45, against the +0.50 growth effect that needed ~160 paired runs to separate from a 2.00
same-arm noise floor. Honest limit: **a floor does not raise the ceiling** - chapter 5/8/10 reach
is 19.4% / 3.2% / 0.6% before and after, identically, because those runs were already past the
floor. Ceiling work needs the starting shop level and the income multiplier.

Stated risk: a fully-grown profile has *already* produced a chapter-10 `target_reached` run at
2.3e11 buckets, so the top end is not defended by difficulty - it is defended by nobody getting
there. The brief ties every power proposal to converting Red Ink into a Tier ladder, which is
largely already built in `RED_INK_UNLOCK_CHAPTERS`.

### 15.3 Level economy: the game and the rig are both wrong

- **Price is exactly `4 x stake_unit`**, verified against the data (763 of 764 resolvable charges).
- **The rebasing erases the player's growth.** `stake_unit` is re-chosen at every chapter boundary
  so the bankroll stays worth ~75-187 units. So a run that gets richer does **not** buy more of the
  XP ladder - the ladder's cost is fixed in units and the bankroll is pinned beneath it. This is
  the structural reason rich runs never level, and it is where Tower-style account growth
  naturally belongs.
- Reachable and should be routine: **level 4 by chapter 3-4** (5 buys, 20 units), **level 5 by
  chapter 4** (9 buys, 36 units), level 7 by chapter 5 (25 buys). Nobody has ever passed level 7.
  Level 14 needs 556 buys (2,224 units) and is never reachable by saving.
- The top of the ladder is reachable only through the **within-chapter windfall** the designer
  described: win big while `stake_unit` is still frozen at the old price. That window is real and
  large - 267 of 1,506 run-chapters exceeded the normalisation band, and the best single beat
  could afford 524 purchases (2,096 XP, level 13 from level 1).
- **The rig wasted it.** By the designer's own definition (econ lead + two straight wins on a
  board at capacity) the window was open in **864 rounds across 146 runs**, and in **763 of them
  the run bought zero XP that chapter**. Worst case: `jev-deep-seed21022-20260923-161127` entered
  a chapter-6 round holding 397,200 buckets - 496 purchases, level 13 - *while sitting at level 1*.
- **Rig cause:** `_buy_xp_if_needed` buys at most **one** purchase per call, called once plus once
  per shop purchase (capped at 5), so the ceiling is ~6 per round and the best-ever run total is
  **25 purchases against a 556-purchase ladder**. The model is asked "one, or none", never "how
  much of this bankroll should become levels".
- The loop ran a **rank 67-68 of 99** account, and nothing in the edicts, writs or Red Ink tiers
  touches `stake_unit`, shop prices or the XP ladder - it is all starting bankroll and slot
  quantity, which a run outgrows by chapter 4.
- Levers, with the arithmetic: `HEALTHY_RESERVE_UNITS 75 -> 900` (the whole ladder then fits the
  normalisation band and spending power finally grows with gold), or `XP_PER_BUY 4 -> 48` (47
  purchases instead of 556, at the cost of collapsing levels 2-4 into one click). Rig side: a
  bounded loop that dumps purchases in one beat, with the reserve defined as the next wager rather
  than the current 2-bucket floor.

### 15.4 Traits: the verticals cannot be ranked yet, but the reason is structural

22 traits: 17 vertical (multi-rung), 5 flex. No ladder is arithmetically unreachable - duplicates
are allowed, and 52% of fights field two or more copies of one id - but the `[2,4,6,8]` top rung
needs 8 of 9 slots, and capacity only reaches 9 at chapters 4-5, so the steep ladders cannot even
be started early.

The blocker: **only 36 of 533 runs (6.8%) ever assembled a vertical at all**, and 11 of the 17
verticals were never assembled once. So there is almost nothing to rank, and "trap" is the wrong
label for the eleven - the rig has simply never tried them.

The finding worth acting on is structural. Across all 17 verticals, only **2 units** bridge
Cartel to a vertical (`kett`, `gable`); 3 bridge Harmony (`nullora`, `knoll`); 5 bridge
Kaleidoscope. Yet Harmony's own description rewards vertical size, and 14 of 17 verticals have no
unit that can carry it. The measured cost: Cartel active falls from 88.6% to 44.0% and Harmony
from 35.9% to 7.9% while the mean active-trait count is identical (4.04 vs 3.96). Matched
head-to-head, a vertical-largest board wins **-8.8 pp** against a flex-largest board (78 strata).
Vertical boards are not short of traits; they trade away the auras that pay for bodies that do
not. Two more: Exile-3 boards have 0.91x matched median power and Mentor-2 0.95x - those traits
produce no stats.

To settle it properly needs a forced-build mode (`--vertical`): screen all 17 verticals at 30
runs/arm (570 runs), then confirm five at 10 pp (600 runs), ~1,200 total with final chapter as the
paired primary endpoint.

### 15.5 Rig selling, implemented and verified

The rig can now sell. A `sell` decision kind was added to `tests/agent/jev_run_harness.gd`
(311 lines), with a preamble and a safe default in `tools/jev/jev_run_controller.py` (15 lines),
plus a new `tests/agent/sell_decision_probe.gd` and its `.tscn`.

Design: only **bench** bodies are offered - removing a deployed fighter is composition and belongs
to the fielding path - candidates are keyed on the unit instance so two copies of one id cannot
confuse the target, a body one copy from a star-up is never offered, and an empty or timed-out
decision holds. `basis` records who chose and `reason_kind` records why (`surplus_copy`,
`off_plan`, `low_cost_body`, `flex_value`).

Verified by the root, not only by the implementing agent: the probe passes
(`SELL_DECISION_PROBE PASS`), the 27 Python policy and analyzer tests pass, and a heuristic deep
run on seed 21353 sold four units - each exactly when the bench hit its 10 cap, leaving the board
untouched, with zero technical failures.

Known limits, stated so they are not mistaken for done: every observed sale so far is
heuristic-lane (no Jev-chosen sale has been exercised), the freed slot is available to the *next*
beat's shop rather than the same one, and `analyze_jev_run.py` counts `unit_sell` only generically
and has no `unit_sold` accounting yet.

### 15.6 Two open questions this work surfaced

1. Exile and Liaison are described as "exactly 1, 3, or 5", but the engine computes a monotone tier
   (a count of 2 reads no worse than 1, and 4 no better than 3). Should counts 2 and 4 be dead
   zones that pay nothing, or is monotone the intent?
2. 20.2% of corpus fights are missing `top_threshold`, all from the two earliest run roots. Schema
   change or bug?

### 15.7 Trait dead zones, implemented

**Ruling on 15.6(1), 2026-09-24: counts 2 and 4 on Exile and Liaison are dead zones that pay
nothing.** The engine was computing a monotone tier, so a count of 2 read the same as a count of 1
and a count of 4 the same as 3.

What was actually wrong was only the *reading*. `scripts/game/traits/effects/exile.gd` already
implemented the dead zones (`_upgrade_tier_for_count` returns 0 at 2 and 4), but the compiler, the
enemy generator, and therefore the UI and the rig's `deployed_traits` all reported a monotone tier.
Liaison's effect reads the compiled tier, so it *did* pay at 2 and 4 - that changes now.

Implementation, one rule in one place:

- `TraitDef.tier_for(count, thresholds, exact)` holds the rule and `TraitDef.exact_thresholds` is
  the per-trait flag, set true on `Exile.tres` and `Liaison.tres`. A count between two rungs
  activates nothing, and a count past the top rung keeps the top tier - so 9 Exiles is not worse
  than 5.
- `trait_compiler.gd` and `endless_chapter_generator.gd` both call it, and the generator caches the
  flag beside the thresholds. The harness and the UI read the compiler, so they follow.
- `tests/rga_testing/validation/composition_trait_balance_evidence.gd` models the same rule so it
  cannot disagree with the engine.

New probe: `tests/rga_testing/validation/trait_ladder_dead_zone_probe.gd` (with its `.tscn`). It
asserts the rule table for both ladder shapes, that the authored `.tres` carry the flag, that real
Exile boards of 1 to 5 bodies compile to tiers `[0, -1, 1, -1, 2]`, that Fortified's ramp is
unchanged (3 bodies -> tier 0, 5 -> tier 1), and that the generator agrees with the compiler.

Verification: the new probe passes; `MentorLinkNoSharedTraitProbe` and `ItemTraitSystemsProbe`
pass; `CompositionTraitBalanceEvidence` runs clean end to end; and a heuristic deep harness run on
seed 21353 finished with zero technical failures and no engine errors. That short run happened not
to field Exile or Liaison at all, so the probe is the evidence for the rule rather than the run.

Balance consequence worth flagging: enemy teams built around Exile or Liaison at 2 or 4 bodies now
register a lower trait pressure, so enemy level tuning at those counts shifts.
