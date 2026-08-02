# RGA Counter Actual Results - 2026-07-05

Status: runtime comparison of the intended counter web against current Godot simulation outputs after execute fixes, mana-feedback fixes, cadence/damage tuning, generated-lane counter relabeling, generated item-loadout tightening, counter-selector cleanup, source-kill selector tightening, solo protection-loop tuning, and beat/prey selector cleanup.

## Sources

- Target behavior: `docs/rga_counter_matrix_2026-06-28.md`
- Build/lane data: `data/identity/unit_build_affinities.json`
- Authored contract run: `user://rga_probe/counter_outcome_gauntlet/results.json`
- Focused mismatch diagnostic: `user://counter_focus_diagnostic.json`
- Broad lane run: `user://lane_matchup_gauntlet.json`
- Ranked candidate audit: `user://lane_matchup_candidate_audit.json`
- Exhaustive candidate survey: `user://lane_matchup_exhaustive_candidate_audit.json`

## Intended Behavior

- Hard counters should usually flip the matchup when present and positioned/timed correctly.
- Soft counters should show measurable pressure even when they do not win outright.
- Supports should make one plan strong while leaving visible pressure points.
- Peel, redirect, fortification, and damage reduction should buy time, not create permanent stalemates.
- Unit lanes should have readable prey and predators: each lane needs at least one thing it beats and one thing that beats it.

## Actual Runtime Result

The authored counter contract is healthy:

| Suite | Cases | Sims | Result |
| --- | ---: | ---: | --- |
| `CounterOutcomeGauntlet` | 9 | 36 | PASS |

Contract read:

| Case | Strength | Result |
| --- | --- | --- |
| Peel vs backline access | hard | pass |
| Redirect vs backline access | hard | pass |
| Zone vs engage | soft_pressure | pass |
| CC immunity vs lockdown | hard | pass |
| Long range vs zone | hard | pass |
| Control vs reset | hard | pass |
| Execute vs attrition | hard | pass |
| Attrition vs burst | soft_protection | pass |
| Formation breaking vs peel ball | hard | pass |

The broad lane gauntlet also passes:

| Suite | Lanes | Samples | Formal failures | Team A wins | Team B wins | Timeouts |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `LaneMatchupGauntlet` | 153 | 612 | 0 | 306 | 306 | 0 |

Counter/prey pair summaries from the same lane run:

| Pair read | Pairs | Clean pairs | Issue pairs | Wrong-winner pairs | Timeout-only or partial-timeout pairs |
| --- | ---: | ---: | ---: | ---: | ---: |
| Counter pairs | 153 | 153 | 0 | 0 | 0 |
| Beat/prey pairs | 153 | 153 | 0 | 0 | 0 |

Strict first-choice candidate read from the latest lane run:

| Read | Result |
| --- | ---: |
| Counter lanes passing on first sampled candidate | 153 / 153 |
| Beat lanes passing on first sampled candidate | 153 / 153 |
| Unique passing counter teams | 19 |
| Unique passing beat/prey targets | 12 |
| Strict first-choice timeouts | 0 |

Important selector finding: the earlier predicted-first ordering produced a clean run, but it was over-reliant on one dominant shell (`malachor+meridian` appeared as the passing counter in 146 / 153 lanes, with only 4 unique passing counter teams). A semantic-first stress run exposed hidden mismatches in timeout-prone or meme/off-lane candidates. The current selector keeps semantic fit first, but adds lane priority, lane-specific rating propagation, support/tank counter shells, fragile-damage counter shells, and source-kill finishing preference so the selected counter actually resolves the fight.

Top-four ranked candidate audit:

| Read | Result |
| --- | ---: |
| Total sims | 2,172 |
| Beat candidates sampled | 487 |
| Counter candidates sampled | 599 |
| Extra beat candidates after first pass | 334 |
| Extra counter candidates after first pass | 446 |
| Beat failed candidates | 0 |
| Counter failed candidates | 0 |
| Beat directional failed candidates | 0 |
| Counter directional failed candidates | 0 |
| Beat semantic-only failed candidates | 0 |
| Counter semantic-only failed candidates | 0 |
| Beat timeout candidates | 0 |
| Counter timeout candidates | 0 |

The normal strict gate remains clean in this audit because it only gates the first live counter/prey claim per lane. The extra ranked audit rows deliberately continue past the first pass. `LaneMatchupCandidateAudit.tscn` now runs with `fail_on_ranked_candidate_audit_issues = true`, so any top-four ranked directional counter or beat/prey contradiction fails the scene. The top-four ranked counter and beat/prey sides are both fully passing.

All-candidate survey:

| Read | Result |
| --- | ---: |
| Scene | `LaneMatchupExhaustiveCandidateSurvey.tscn` |
| Mode | report-only |
| Seed mode | stable per matchup |
| Total sims | 7,590 |
| Beat candidates sampled | 1,629 / 1,629 |
| Counter candidates sampled | 2,166 / 2,166 |
| Skipped lower-ranked candidates | 0 |
| Counter failed candidates | 0 |
| Counter directional failed candidates | 0 |
| Counter semantic-only failed candidates | 0 |
| Counter timeout candidates | 0 |
| Beat failed candidates | 0 |
| Beat directional failed candidates | 0 |
| Beat semantic-only failed candidates | 0 |
| Beat timeout candidates | 0 |

This wider pass proves the generated counter side and generated beat/prey side are both clean across the ranked candidate pool at the tested lane/loadout scope. The lower-ranked counter cleanup moved counter-direction failures from `67 -> 41 -> 21 -> 17 -> 16 -> 5 -> 4 -> 0`, and the beat/prey cleanup moved all-candidate beat/prey failures from `140 -> 0`.

## Fixed In This Pass

- Nullora and Vesper no longer force a target down to execute threshold with setup true damage. They now execute only if the real post-hit HP is already at or below the execute threshold.
- Ability and scheduled damage no longer grants basic-attack mana. This removed recursive caster refueling that let Malachor cast far too often and overfed Vesper/Nullora casts.
- Draxelle `Colossus Hook` mana cost moved from `30` to `55`.
- Marble `Sanctuary Bolt` was tuned down from a cheap nuke/self-AD/shred package into a defensive marksman bolt: lower damage, no self-AD bonus, no armor shred, and `55` mana.
- Ivara `Open Bid` was tuned down from a cheap self-scaling nuke into a tank-shred opener: lower damage, no self-AD bonus, armor shred only, and `55` mana.
- Malachor `Debt of Flesh` mana cost moved from `35` to `65`, matching its cost-5 hard-CC plus sustain impact better.
- `LaneMatchupGauntlet` now treats `wall_timeout` as a timeout in pair summaries instead of counting it as an unexpected subject win.
- `LaneMatchupGauntlet` has a wall-clock guard and progress logging so pathological generated rows record as timeouts instead of hanging the full run.
- Meme-lane generated counter text now keeps the unit-authored predator shape instead of using generic off-role goal counters. This removed the Creep/Kett meme-lane false counter expectations.
- Generated completed-item loadouts now weight role fit strongly enough that off-role defensive items do not beat actual lane-role items just because they share a couple of axes.
- Counter candidate ordering now prioritizes live predicted disadvantage after semantic matching, so weak semantic-overlap lanes are not sampled ahead of stronger real counter builds.
- Beat/prey candidate ordering now also prioritizes live predicted advantage after semantic matching, which removed high-semantic stall rows that were being tried before clean prey targets.
- Counter candidate ordering now carries lane-specific ratings through strengthened counter shells. The predictor no longer prices a tested lane as if it were always the unit's strongest lane.
- Source-kill counter selection now penalizes pure tank/control shells when they only stall a support engine. Quillith primary/meme no longer labels Bastionne+Meridian as the first clean counter; it selects Malachor+Meridian, which kills the support engine cleanly.
- Derived target tokens now come only from the active lane's capabilities instead of the full relationship text. This prevents `beats`, `loses_to`, and `counter_board` prose from polluting the opposite direction.
- Fragile marksman/mage counter candidates now get small-board support when they are being tested into dive, brawler, tank, or support contexts that require peel or finishing help.
- Pure tank/support counter candidates into reset/source-kill engine lanes now bring a finisher shell. The old extra Quillith meme vs Bastionne+Meridian stall now resolves as Bastionne+Malachor+Meridian winning the counter case.
- Assassin counter candidates only satisfy access-counter claims when their active lane actually has access, backline-elimination, or engage terms. Vesper primary cleanup execution is no longer sampled as a false access counter into Marble meme.
- Beat/prey target selection now rejects several wrong lane-shape matches: cleanup assassins are not generic dive prey, peel supports are not backline engines, defensive tank fortification is not prey for low-damage amplification lanes, capstone support engines are not generic stat-race prey, and zone/control mages are not treated as exposed carries.
- Added `LaneMatchupCandidateAudit.tscn`, a heavier audit scene that samples the top four ranked beat/counter candidates per lane while preserving the normal strict gate for the first passing candidate.
- Added `LaneMatchupExhaustiveCandidateSurvey.tscn`, a report-only all-16 ranked candidate survey that samples every generated beat/counter candidate currently emitted per lane.
- `LaneMatchupGauntlet` now fails the scene if either strict pair summary has issue pairs. `LaneMatchupCandidateAudit.tscn` additionally fails on top-four ranked directional candidate failures. The JSON pair summary is no longer advisory-only.
- Lower-ranked selector guards now reject several false counter/prey matches that looked plausible in text but did not map to live outcomes, including generic attrition-as-counter, fortification into other tanks, support lockdown into frontline shells, cleanup/access assassins into the wrong subject shape, and zone/wombo/pick-burst claims without matching source-kill, zone, clump, or burst context.
- Bastionne's `No-Pass Writ` now gives Bastionne a reduced self-gate while preserving the full gate package for allies. This keeps fortification valuable on a board without letting solo Bastionne create permanent counter stalls.
- Quillith's `Final Exam` no longer names Quillith as the full Pupil when no allied pupil exists. This prevents solo Quillith from looping the full team-amplification shield package into a permanent stall.
- Added `CounterFocusDiagnostic.tscn` to keep regression coverage on rows that previously contradicted or stalled the intended counter web.
- `LaneMatchupGauntlet` now uses stable per-matchup seeds instead of deriving seeds from global sample order. Counter-selector changes no longer perturb unrelated beat/prey seeds.
- Counter candidate filtering now drops candidates that fall to nonpositive score after finishing-pressure adjustments, so demoted stall shells are not kept as reportable counters.
- Pure tank/support finishing counter shells now prefer actual damage-role partners. This removed Quillith support-engine timeout counters that had enough control to stall but not enough pressure to finish.
- Additional counter guards reject low-conversion paper counters that failed live: passive support-amplification into tank initiate, frontline-disruption into tank initiate without redirect/zone/kill pressure, tank-shaped wombo into tank initiate without burst/range/kill pressure, and sustained-DPS range-only counters into pick burst.
- Counter-board strengthening now prefers damage partners and rejects stall-prone support-peel counter shells, including non-primary brawler dive/support-control/defensive shells that did not kill Saffron-style peel lanes in live rows.
- Beat/prey candidates now require live predicted subject advantage before being sampled. This prevents low-probability semantic matches from masquerading as intended prey.
- Beat/prey fallback choices are limited to one emergency proof target instead of turning the fallback list into a broad prey claim.
- Lower-ranked beat/prey guards now reject false solo-stall prey claims: fortification/frontline into attrition sustain, support amplification, other tanks, engage tanks, and zone/source-kill pick-burst lanes without a real finisher or backline access.

## Focused Mismatch Rows

These previously looked wrong and now map to the intended behavior:

| Scenario | Actual result | Important read |
| --- | --- | --- |
| Nullora vs Bastionne+Meridian | counter team wins | Nullora no longer manufactures execute setup |
| Nullora vs Quillith+Meridian | counter team wins | Shield/CC pressure beats the assassin line |
| Malachor vs Quillith+Meridian+Bastionne+Draxelle | counter team wins | Malachor no longer refuels into runaway casts |
| Vesper vs Omenry | counter team wins | Vesper no longer forces threshold execute |
| Vesper vs Gable | counter team wins | Long-range counter-siege works |
| Bastionne off vs Malachor+Meridian | counter team wins | Bastionne self-gate no longer creates a permanent solo fortress |
| Quillith primary vs Malachor+Meridian | counter team wins | Quillith no longer self-pupils into repeated full shields |
| Quillith primary/meme vs Bastionne+Meridian | timeout before selector fix | Lockdown-only control can stall Quillith, but the real counter claim needs finishing pressure; Malachor+Meridian is now selected instead |

## What Is Working

The authored counter mechanics exist in live combat and produce the planned outcomes at the strict first-choice gate. There are no remaining wrong-winner or timeout counter pairs in the latest strict broad lane run: every sampled first-choice counter outcome wins for the counter side.

The authored counter web also distinguishes hard counters from soft pressure correctly. Zone into engage is not an auto-win in the sampled board, but it materially improves damage and protected time versus the non-zone baseline, which is the right shape for a soft counter.

The generated lane matrix now maps cleanly onto the real game at this tested scope. Creep/Kett meme rows no longer claim solo duelists are reliable counters to tanky disruption builds, Omenry's real marksman lane is selected ahead of its weaker meme cleanup lane when testing Vesper off-lane counterplay, support-engine counters require finishing pressure, and high-semantic prey rows are not sampled ahead of cleaner runtime prey targets.

The top-four ranked counter audit is also clean now: all `599` sampled counter candidates pass, with no counter timeout candidates.

The exhaustive ranked counter survey is clean now: all `2,166` generated counter candidates pass under stable per-matchup seeds, with no counter-direction failures, no counter semantic-only failures, and no counter timeout candidates.

The ranked beat/prey side is also clean now. The top-four audit has `0 / 487` beat/prey failures, and the exhaustive survey has `0 / 1,629` beat/prey failures. The old Caldera/Egress rows, Kythera/Juno timeout row, fortification-vs-support-engine stalls, and other predicted-favorable wrong-winner or timeout rows are no longer emitted as valid prey claims.

## What Is Not Working Right

### 1. This is not a proof of all possible item/board variants

The clean result covers the generated lane loadouts and selected semantic prey/counter candidates. It does not prove every possible hand-built item set, every trait stack, or every full-board composition.

### 2. The enforced and exhaustive generated-lane gates are clean, but broader balance work remains

`LaneMatchupGauntlet` now fails when any strict beat/prey or counter pair has a wrong winner or timeout. `LaneMatchupCandidateAudit` samples top-four ranked candidates and fails on directional contradictions. `LaneMatchupExhaustiveCandidateSurvey` now samples all lower-ranked generated candidates. It remains report-only because it is intentionally heavy and diagnostic, not because current generated counter or beat/prey candidates are failing.

### 3. Fresh broad analytics found balance problems outside generated counter semantics

`CombatAnalyticsGauntlet.tscn` was rerun after the Brute/Korath primary bundle fix. It ran `10,888` live-engine rows with `0` wall-time capped rows and wrote the current report to `outputs/balance/combat_analytics_20260707_after_brute_korath/combat_analytics_report.md`.

That pass does not contradict the generated counter result: it does not show wrong-winner generated counter claims. It does show broader balance issues that matter before calling combat balanced:

- Primary generated item loadouts previously made several non-tank units worse instead of better. The worst full-run deltas before the targeted non-tank pass were Creep `-31pp`, Noxley `-28pp`, Saffron `-26pp`, Quorra `-23pp`, Teller `-23pp`, Hexeon `-22pp`, Ivara `-14pp`, and Juno Vale/Paisley/Vesper `-12pp`.
- The tank primary item pass held up in the full matrix: Brute is now `+36pp`, Korath `+30pp`, Grint `+18pp`, Veyra `+33pp`, Repo `+28pp`, Kythera `+24pp`, Caldera `+21pp`, Bastionne `+6pp`, and Malachor `+4pp`.
- Fully stacked trait teams are too polarized. Executioner is `95.24%`, Titan `90.48%`, and Overload `85.71%`, while Chronomancer is `0%`, Mogul `4.76%`, Cartel `9.52%`, and Bulwark `19.05%`.
- Long-resolution fights remain common, but the current primary-item pass is much better than the pre-fix run: no-item rows have `34.22%` long resolution, primary-item rows have `23.72%`, and fully stacked trait rows have `29.34%`.

So the current answer is: counter claims are working at the generated lane/loadout scope, but item recommendation balance and fully stacked trait balance are not healthy yet.

### 4. Targeted tank item pass improved the worst defensive-stack failures

After the broad analytics found itemized tank loadouts making several tanks worse, `build_unit_build_lane_matrix.py` was updated so tank primary bundles are scored as bundles and require tank/brawler-compatible conversion pressure instead of three passive durability items. This changed only nine tank primary bundles in `data/identity/unit_build_affinities.json`.

The generated counter/prey web stayed clean after the item pass:

- `LaneMatchupCandidateAudit.tscn`: `153` lanes, `2,178` samples, `0` failures, `0 / 602` counter failures, `0 / 487` beat/prey failures.
- `LaneMatchupExhaustiveCandidateSurvey.tscn`: `153` lanes, `7,656` samples, `2,199 / 2,199` generated counter candidates clean, `1,629 / 1,629` generated beat/prey candidates clean.

`CombatAnalyticsTankItemFocus.tscn` then ran `1,836` live-engine rows for the nine changed tank primaries versus the full unit list, with `0` wall-time capped rows. Directional result versus the previous full-run item deltas:

- Fixed from negative or flat to positive: Bastionne `-20.0pp -> +5.17pp`, Caldera `-31.0pp -> +18.97pp`, Kythera `-18.0pp -> +20.69pp`, Malachor `-4.0pp -> +5.18pp`, Repo `0.0pp -> +25.87pp`, Veyra `-13.0pp -> +32.76pp`.
- Still not fixed: Brute stayed negative at about `-15.52pp`, Korath stayed negative at about `-15.52pp`, and Grint stayed positive but dropped from the previous broad-run `+32.0pp` read to `+10.34pp` in the focused run.

Follow-up Brute/Korath work found the issue: the tank bundle tie-break treated a crit/formation item as equivalent to repeatable reactive pressure for primary `tank.frontline_absorb` lanes. `build_unit_build_lane_matrix.py` now only uses the reactive tie-break for primary frontline-absorb tank lanes, so Brute and Korath move from `anchor, wardheart, armageddon` to `anchor, wardheart, thunderplate` without changing Bastionne's off-lane back into the timeout-prone Thunderplate variant.

Validation after that narrower tie-break:

- `CombatAnalyticsTankProblemFocus.tscn`: `408` live-engine rows, Brute `-15.52pp -> +33.33pp`, Korath `-15.52pp -> +29.41pp`, `0` wall-time capped rows.
- `BuildLaneAudit.tscn`: pass.
- `LaneMatchupCandidateAudit.tscn`: `153` lanes, `2,178` samples, `0` failures, `0 / 602` sampled counter failures, `0 / 487` sampled beat/prey failures.
- `LaneMatchupExhaustiveCandidateSurvey.tscn`: `153` lanes, `7,656` samples, `2,199 / 2,199` generated counter candidates clean, `1,629 / 1,629` generated beat/prey candidates clean.

The full `CombatAnalyticsGauntlet.tscn` rerun after this fix confirmed the tank item result in the full matrix: Brute `+36pp`, Korath `+30pp`, and Grint `+18pp`. This is real progress on item balance, not completion. The next item-balance work should move to the worst remaining non-tank item regressions, especially Creep, Noxley, Saffron, Quorra, Teller, and Hexeon, while fully stacked trait polarization remains a separate open balance problem.

### 5. Targeted non-tank item pass improved the worst remaining item regressions

`CombatAnalyticsWorstItemCandidateFocus.tscn` screened candidate item bundles for Creep, Noxley, Saffron, Quorra, Teller, and Hexeon against the full live unit list. It ran `1,836` live-engine rows with no Godot errors. The best tested primary overrides were then generated through `build_unit_build_lane_matrix.py` rather than patched directly into JSON:

- Creep: `dagger, shiv, lifetaker`
- Noxley: `mageheart, orb_on_a_stick, clockwork`
- Saffron: `anchor, orb_on_a_stick, conductor`
- Quorra: `lifetaker, shiv, vengeance`
- Teller: `bandana, clockwork, dagger`
- Hexeon: `mind_siphon, shiv, lifetaker`

`CombatAnalyticsWorstItemPrimaryFocus.tscn` then reran the six affected units at two seeds per matchup, writing `1,224` live-engine rows to `user://combat_analytics/worst_item_primary_focus_after_overrides` with no Godot errors. Directional item deltas after the overrides:

| Unit | Previous full-run item delta | Focused post-override item delta | Read |
| --- | ---: | ---: | --- |
| Creep | `-31pp` | `+1.96pp` | Fixed in focused read |
| Quorra | `-23pp` | `-3.92pp` | Nearly neutral |
| Noxley | `-28pp` | `-9.80pp` | Improved, still negative |
| Saffron | `-26pp` | `-11.76pp` | Improved, still negative and timeout-heavy |
| Teller | `-23pp` | `-17.65pp` | Improved only slightly, still unhealthy |
| Hexeon | `-22pp` | `-11.76pp` | Improved, still negative |

The item pass exposed another selector issue: lower-ranked defensive or low-pressure counter shells could still be emitted against Saffron-style support-peel lanes even though live rows timed out. `lane_matchup_gauntlet.gd` now rejects those paper counters, makes counter-board strengthening prefer damage partners, and blocks non-primary brawler skirmish partners from support-peel counter shells.

Validation after the non-tank pass:

- `BuildLaneAudit.tscn`: pass.
- `LaneMatchupCandidateAudit.tscn`: `153` lanes, `2,172` samples, `0` failures, `599 / 599` sampled counter candidates clean, `487 / 487` sampled beat/prey candidates clean, `0` ranked candidate timeouts.
- `LaneMatchupExhaustiveCandidateSurvey.tscn`: `153` lanes, `7,590` samples, `0` failures, `2,166 / 2,166` generated counter candidates clean, `1,629 / 1,629` generated beat/prey candidates clean, `0` ranked candidate timeouts.

Current remaining balance problems are not generated counter/prey contradictions. They are broader item scaling and content balance issues: Noxley, Saffron, Teller, and Hexeon still underperform their no-item baselines in the focused post-override read, and fully stacked trait teams remain too polarized.

### 6. Round-two non-tank item pass improved some units, but the latest exhaustive proof is still open

The first non-tank pass still left Noxley, Saffron, Teller, and Hexeon meaningfully below their no-item baselines, so a second focused candidate screen was added as `CombatAnalyticsWorstItemCandidateFocusRound2.tscn`. It ran `2,856` live-engine rows in `992.12s` with no Godot errors and wrote `user://combat_analytics/worst_item_candidate_focus_round2`.

The generated primary item overrides after that pass are:

- Creep: `dagger, shiv, lifetaker` (unchanged from the first non-tank pass)
- Noxley: `codex, orb_on_a_stick, clockwork`
- Saffron: `largewand, orb_on_a_stick, conductor`
- Quorra: `lifetaker, shiv, vengeance` (unchanged from the first non-tank pass)
- Teller: `rendsaw, dagger, clockwork`
- Hexeon: `dagger, shiv, lifetaker`

`CombatAnalyticsWorstItemPrimaryFocus.tscn` then reran the six focused units at two seeds per matchup. It wrote `1,224` live-engine rows in `350.90s` to `user://combat_analytics/worst_item_primary_focus_after_overrides` with no Godot errors. Directional item deltas after the round-two overrides:

| Unit | Focused round-two item delta | Read |
| --- | ---: | --- |
| Teller | `+9.09pp` | Fixed in focused read |
| Creep | `0.0pp` | Neutral in focused read |
| Noxley | `0.0pp` | Neutral in focused read |
| Saffron | `0.0pp` | Neutral, but still has a high stall/other-result pattern |
| Quorra | `-5.45pp` | Slipped negative again |
| Hexeon | `-9.09pp` | Still negative |

The regular lane validations stayed clean after the generated item changes:

- `BuildLaneAudit.tscn`: pass.
- `LaneMatchupCandidateAudit.tscn`: `153` lanes, `2,172` samples, `0` failures.

However, the report-only all-candidate exhaustive survey after the round-two item override found six lower-ranked Noxley primary counter failures before the latest selector patch. All six were paper counters where Noxley won both seeds: Vesper meme, Sable primary, Ivara primary, Marble off, Sable meme, and Ivara meme.

`lane_matchup_gauntlet.gd` was then tightened again so low-pressure solo counters are not emitted into sustain/ramp mage lanes unless they bring real source kill, burst, anti-sustain, execute, lockdown, or ramp pressure. The top-four `LaneMatchupCandidateAudit.tscn` re-passed after that selector patch with `153` lanes, `2,172` samples, `0` failures, and no Godot errors.

The final all-candidate exhaustive rerun after that latest selector patch was interrupted before it produced a summary. Last observed progress was `2,880` samples and `0` progress-log failures. That is encouraging, but it is not a final exhaustive clean result until `user://lane_matchup_exhaustive_candidate_audit.json` is regenerated with `counter_directional_failed_candidates = 0` and `beat_directional_failed_candidates = 0`.

## Current Verdict

Yes, there were real counter bugs. The major runtime bugs were execute abilities manufacturing threshold kills, ability damage recursively granting mana, cheap high-impact casts, protection-loop stalls, unstable audit seeds, and false lower-ranked counter selectors. Those are fixed and regression-checked.

The generated counter web is healthy at the enforced lane/loadout scope: the latest strict broad run has zero false counter wins and zero counter timeouts across 153 strict counter pairs, and the latest top-four ranked counter audit after the round-two selector patch has `0` failures across `153` lanes and `2,172` samples.

The latest all-candidate exhaustive survey is not yet a final clean result after the round-two item changes. The pre-round-two stable-seed exhaustive survey was clean, and the post-round-two top-four audit is clean, but the post-round-two exhaustive survey first exposed six lower-ranked Noxley paper-counter failures and the rerun after the selector fix stopped before producing a final summary. The last observed partial rerun had `2,880` samples and `0` progress-log failures.

The still-not-balanced areas are broader than generated counter semantics: finish the post-selector exhaustive rerun, rerun full `CombatAnalyticsGauntlet.tscn` after the round-two item overrides, fix Hexeon and Quorra item deltas, inspect Saffron's stall-heavy neutral result, tune fully stacked trait polarization, and cover hand-built item/full-board variants outside the generated lane audit.
