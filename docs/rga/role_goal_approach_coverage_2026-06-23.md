# RGA Role / Goal / Approach Coverage - 2026-06-23

Source checked: live Google Doc `gamble battle` in the signed-in Chrome session.

## Doc Standard

The design doc says each unit identity has:

- one primary role: fundamental archetype and stat profile
- one primary goal: the unit's specific round win condition
- a handful of approaches: concrete mechanics used to achieve that goal

The doc also lists metrics for each goal and approach. The important test implication is that role-fit passing is not enough. A unit can pass its broad role test while its specific goal or toolkit tag is still untested or failing.

## Current RGA State

Role coverage is real and smoke-green for the six core role archetypes, but targeted unit probes can still fail their role identity thresholds:

- `role_tank_identity`
- `role_brawler_identity`
- `role_assassin_identity`
- `role_marksman_identity`
- `role_mage_identity`
- `role_support_identity`

Goal coverage now has an executable `goal_primary` metric for every doc-listed primary goal ID. `ProbeReportCompiler` prefers that direct goal metric over older goal-proxy verdicts. Goal verdicts can now be direct `PASS`/`FAIL`, or fall back to `PROXY_PASS`, `PROXY_FAIL`, `MISSING_RUN`, or `UNTESTED` when the direct metric did not run.

`goal_primary` now consumes a direct `disruption` kernel for post-control enemy responses: forced reposition distance/events, target swaps, formation spread breaks, and follow-up kills. This replaces the older movement/CC-count proxies for goals such as `brawler.frontline_disruption`, `mage.area_denial_zone`, and `support.formation_breaking` when the derived kernel is present.

`goal_primary` and `approach_zone` now also consume direct `zone_exposure` telemetry for subject-owned lingering-zone/hazard evidence: exposure events, unique targets, duration, damage, and radius. Positioning occupancy remains a fallback and diagnostic, not the preferred proof for zone-tagged kits.

Approach coverage now has executable tests for:

- `approach_access_backline`: backline-entry kernel, including cast-relative contact windows.
- `approach_long_range`: range/over-2-tiles kernel.
- `approach_peel`: subject effective-health contribution, source-attributed ally protection utility, or team peel saves.
- `approach_zone`: direct source-owned zone/hazard exposure, with frontline/zone occupancy retained as fallback diagnostics.
- `approach_sustain`: subject healing plus absorbed shields over incoming pressure or fight time.
- `approach_damage_reduction`: subject pre-mitigation to post-mitigation prevention before shields.
- `approach_lockdown`: subject CC seconds/events on priority targets, plus forced-cleanse pressure, tenacity/CC-immunity tax, and neutral-vs-cleanse/high-tenacity scenario deltas when those scenario labels are present.
- `approach_burst`: subject peak 1-second damage, peak damage share, overkill rate, and cast-to-peak counterplay window.
- `approach_execute`: direct execute bonus event count, bonus damage share, low-health kill share/count, and overkill guardrail when direct telemetry is present.
- `approach_aoe`: subject multi-target hit groups, max targets hit, and AoE DPS.
- `approach_ramp`: direct stack/window ramp events, max stack, time-to-peak, and peak/window duration when current telemetry is present; older rows fall back to late-vs-early DPS ratio, time-to-peak, and post-peak falloff.
- `approach_disrupt`: subject CC seconds/events and unique controlled targets, not restricted to priority targets.
- `approach_engage`: subject early displacement plus early hit/cast/CC initiation evidence.
- `approach_reposition`: subject max movement step, post-cast movement, and total path distance.
- `approach_amp`: source-attributed ally-directed buffs or utility applied to other allies, plus direct buff-output delta/events/beneficiary spans when output telemetry is present.
- `approach_debuff`: source-attributed enemy debuff events, magnitude, forced-cleanse pressure, cleanse-bait rate, and neutral-vs-cleanse scenario delta when those scenario labels are present.
- `approach_cc_immunity`: CC-immunity application/receipt or prevented CC while immune.
- `approach_redirect`: direct absorb/redirect events, redirected damage-prevention telemetry, enemy focus starts, target swaps onto the subject, and enemy focus duration, with pressure-share retained as a fallback diagnostic.
- `approach_on_hit_effect`: explicit basic-attack on-hit proc evidence from source-attributed `on_hit_proc` telemetry.
- `approach_dot`: source-owned DoT tick events, tick damage, touched targets, active uptime, and applied duration when direct telemetry is present; older rows fall back to debuff/on-hit/sustained-damage proxy evidence.
- `approach_reset_mechanic`: direct reset/recast event count, chain length, reset timing, and touched targets when direct telemetry is present; older rows fall back to kill/low-health/post-peak proxy evidence.
- `approach_untargetable`: direct untargetable frame share, key-threat dodge rate, and cooldown-trade evidence when targetability telemetry is present; older rows fall back to low incoming share, survival, mobility, and CC-prevention proxy evidence.

`ApproachSemanticCatalogProbe.tscn` now gives the approach side the same catalog-level proof as `GoalPrimaryCatalogProbe.tscn`: all 22 Google-doc approach metrics pass on purpose-built evidence, fail an empty/control payload, and emit an expected approach span prefix. This proves testability of the approach vocabulary, not that every live unit currently satisfies its assigned tags.

## Current Roster Goals

| Goal | Units | Coverage |
| --- | --- | --- |
| `tank.frontline_absorb` | brute, drubble, korath, veyra | direct `goal_primary`; latest Korath run passes through real body-block redirect evidence even though damage-taken share and frontline-zone proxy remain below threshold |
| `tank.team_fortification` | kythera | proxy via `approach_damage_reduction`, `approach_debuff`, and `approach_sustain`; Kythera currently proxy-passes while sustain fails |
| `tank.initiate_fight` | grint | testable via `approach_engage`; Grint currently fails neutral 6v6 probe |
| `tank.single_target_lockdown` | repo | testable via `approach_lockdown`, including direct cleanse/tenacity counterplay spans; Repo currently fails neutral 6v6 probe |
| `brawler.attrition_dps` | bonko, morrak, mortem, vykos | proxy via `approach_sustain` and `approach_ramp` when tagged/run |
| `brawler.frontline_disruption` | berebell | direct `goal_primary` now checks subject CC plus enemy-response events; latest Berebell run fails with zero CC/disruption and zero enemy-response events |
| `brawler.skirmish_dive` | bo, drueling | proxy via `approach_access_backline`, `approach_reposition`, and `approach_disrupt` when run |
| `assassin.backline_elimination` | hexeon | proxy via `assassin_backline_elimination` and `approach_access_backline`; Hexeon still has a separate `approach_execute` failure |
| `assassin.cleanup_execution` | creep | proxy via `approach_execute` when run |
| `marksman.sustained_dps` | beegle, sari | proxy via `approach_ramp`, `approach_on_hit_effect`, and `approach_long_range`; Sari currently proxy-passes through long_range/ramp while on-hit and latest marksman identity fail |
| `marksman.backline_siege` | nyxa | proxy via `approach_long_range`, `approach_ramp`, and `approach_aoe` when run |
| `marksman.tank_shredding` | teller | proxy via `approach_debuff`, `approach_ramp`, and `approach_long_range`; Teller currently proxy-passes through long range while debuff/ramp fail |
| `mage.wombo_combo_burst` | luna, paisley | proxy/direct goal checks via `approach_burst` and `approach_aoe` when run; latest Paisley proves `aoe` and `peel` but still fails the wombo goal on burst share and CC-sync |
| `mage.area_denial_zone` | faeling | direct `goal_primary` and `ZoneExposureKernelProbe.tscn` cover the doc goal; latest Faeling 6v6 now passes live area denial through source-owned Eavesdropping spin-zone exposure |
| `mage.pick_burst` | mara, volt | proxy/direct goal checks via `approach_burst`; latest Volt is now tested as pick burst and fails honestly on burst/kill evidence |
| `mage.sustained_dps` | none currently assigned | direct `goal_primary` covers the catalog goal when assigned and now requires team damage share plus direct DoT, persistent-zone, ramp, or on-hit evidence; `MageSustainedDpsGoalProbe.tscn` rejects the old AoE-only false-positive path |
| `support.peel_carry` | totem | direct `goal_primary` now passes through Totem's live source-attributed ally protection utility: real debuff removal, shield/CC-immunity/amp application to the allied carry, plus direct `approach_peel`, `approach_cc_immunity`, and `approach_amp` passes |
| `support.team_amplification` | axiom | direct `goal_primary` now passes through source-attributed Pupil output lift from Axiom's live kit (`120.46` output delta, `17` output events, `1` beneficiary) |

Doc-defined goals not currently assigned to a unit but covered by `goal_primary` when assigned or directly probed:

- `assassin.disrupt_and_escape`
- `support.enemy_lockdown`
- `support.initiate_fight`
- `support.formation_breaking`

## Current Roster Approaches

| Approach | Units | Coverage |
| --- | --- | --- |
| `access_backline` | bo, creep, hexeon | covered by `approach_access_backline` |
| `damage_reduction` | brute, creep, drubble, grint, korath, kythera, repo, veyra | covered by `approach_damage_reduction` |
| `disrupt` | berebell, bo, drueling, grint, morrak, mortem | covered by `approach_disrupt`; Grint and Berebell currently fail neutral 6v6 |
| `engage` | brute, drubble, drueling, grint, korath | covered by `approach_engage`; latest Korath and Grint targeted runs fail neutral 6v6 |
| `lockdown` | brute, repo, volt | covered by `approach_lockdown`; Repo and latest Volt currently fail neutral 6v6 with zero priority-control, cleanse-pressure, or tenacity-tax evidence |
| `long_range` | beegle, luna, nyxa, sari, teller | covered by `approach_long_range` |
| `peel` | axiom, paisley, totem | covered by `approach_peel` |
| `reposition` | berebell, bo | covered by `approach_reposition`; Berebell passes neutral 6v6 |
| `sustain` | axiom, beegle, berebell, bonko, kythera, morrak, mortem, veyra, vykos | covered by `approach_sustain`; Veyra currently fails neutral 6v6 |
| `zone` | faeling | covered by `approach_zone`; current rows prefer direct zone exposure over occupancy proxies. Faeling now passes with live direct spin-zone exposure |
| `amp` | axiom, totem | covered by `approach_amp`, including direct output-delta telemetry when present; latest Axiom and Totem 6v6 runs both pass through source-attributed live ally amp evidence |
| `aoe` | mara, creep, faeling, luna, morrak, nyxa, paisley | covered by `approach_aoe`; current proxy uses hit groups and AoE DPS |
| `burst` | mara, hexeon, luna, mortem, repo, volt, vykos | covered by `approach_burst`; Repo currently fails neutral 6v6 |
| `cc_immunity` | totem | covered by `approach_cc_immunity`; latest Totem 6v6 passes through source-attributed CC-immunity grants |
| `debuff` | kythera, teller | covered by `approach_debuff`, including forced-cleanse pressure and cleanse-bait rate when present; Kythera passes and Teller fails |
| `execute` | mara, hexeon, vykos | covered by `approach_execute`; Hexeon's neutral 6v6 row can still fail when no execute opportunity appears, but `HexeonExecuteLiveProbe.tscn` now proves the real kit executes low-HP targets and does not execute above-threshold targets |
| `on_hit_effect` | sari | covered by `approach_on_hit_effect`; latest Sari run fails honestly because no subject on-hit proc events are observed |
| `ramp` | bonko, nyxa, sari, teller, veyra | covered by `approach_ramp`; current rows prefer direct stack/window state telemetry, while older rows fall back to late/early DPS, time-to-peak, and post-peak falloff |
| `redirect` | korath | covered by `approach_redirect`; Korath passes direct absorb/redirect evidence, enemy-focus and target-swap evidence, and live body-block/end-risk evidence from real diverted damage; taunt-command and explicit threat-swap submodes are not currently claimed by a live kit |

Doc-defined approaches not currently assigned to a unit:

- `dot` - covered by `approach_dot` with direct DoT tick ownership, active uptime, and applied-duration spans when current telemetry is present.
- `reset_mechanic` - covered by `approach_reset_mechanic` with direct reset/recast spans when current telemetry is present.
- `untargetable` - covered by `approach_untargetable` with direct targetability-window and threat-dodge spans when current telemetry is present.

## Bottom Line

Role + goal + approach are now mechanically testable across the current identity catalog and the full Google-doc role/goal/approach vocabulary. Role, goal, and approach catalog gates now all have positive/negative semantic probes, and the support path has live semantic proof for both Axiom's team amplification and Totem's peel-carry kit, including real debuff removal on a carry. They are still not all passing to the full semantic depth the Google Doc asks for because several roster content/identity tags fail honestly in live probes.

What is solid now:

- broad role identity tests for all six roles
- direct semantic positive/negative coverage for all 6 role identity metrics through `RoleSemanticCatalogProbe.tscn`
- direct `goal_primary` coverage for all 22 doc-listed primary goal IDs
- direct semantic positive/negative coverage for all 22 doc-listed primary goal branches through `GoalPrimaryCatalogProbe.tscn`
- direct semantic positive/negative coverage for all 22 doc-listed approach branches through `ApproachSemanticCatalogProbe.tscn`
- direct post-control enemy-response telemetry for target swaps, forced reposition, formation spread, and follow-up kills, plus a positive-control scene for that kernel
- direct DoT telemetry for source tick count, tick damage, touched targets, target receipt, active uptime, applied duration, and neutral-vs-anti-DoT scenario deltas, plus a positive-control scene for that metric path
- direct execute telemetry for bonus event count, bonus damage/share, threshold compliance, and low-HP conversion, plus both a signal positive-control scene and a live Hexeon low-HP-vs-above-threshold probe for that metric path
- direct ramp telemetry for stack/window event count, max stack, time-to-peak, and peak/window duration, plus a positive-control scene for that metric path
- direct reset/recast telemetry for event count, chain length, reset timing, touched targets, post-first-reset damage/kills/follow-up, win rate after reset, and neutral-vs-counter scenario deltas, plus a positive-control scene for that metric path
- direct targetability telemetry for untargetable frame share, key-threat dodge rate, and cooldown trade, plus a positive-control scene for that metric path
- direct cooldown-pressure telemetry for committed enemy ability responses targeted at a subject, including threat-draw caster/ability diversity, key-threat share, and cooldown-trade efficiency, plus a positive-control scene for cooldowns forced and CC-immunity counter-cooldown trade
- direct counterplay-pressure telemetry for forced cleanses, cleanse-bait rate, tenacity tax, CC-immunity tax, and cleanse/high-tenacity scenario deltas, plus a positive-control scene for lockdown/debuff counterplay spans
- direct redirect telemetry for enemy focus starts, target swaps onto the subject, enemy focus duration, explicit taunts, body blocks, body-block prevention, and redirect end-risk, plus a positive-control scene for that metric path
- direct zone-exposure telemetry for source-owned lingering-zone/hazard events, unique targets, duration, damage, and radius, plus a positive-control scene for `approach_zone` and `mage.area_denial_zone` goal consumption
- direct mage sustained-DPS goal validation requiring damage share plus a direct sustained mechanism from DoT, persistent zone, ramp, or on-hit evidence, with a positive/negative control rejecting AoE-only false positives
- direct amp-output telemetry for source-attributed output lift, output events, and beneficiaries, plus positive-control scene coverage and live Axiom/Totem kit proof for amp-bearing support paths
- direct live support-cleanse proof for Totem's real `Cleanse` kit against a debuffed carry, including source-owned cleanse/CC-immunity telemetry and direct support goal/approach consumption
- source-attributed ally-protection spans for `approach_peel`, `support.peel_carry`, and `role_support_identity`, so ally shields, real cleanse removals, CC-immunity grants, and support buffs from the subject count as support evidence instead of only self-EHP or coarse team peel saves
- explicit doc-name tests for every catalog approach: `access_backline`, `damage_reduction`, `disrupt`, `engage`, `lockdown`, `long_range`, `peel`, `reposition`, `sustain`, `zone`, `amp`, `aoe`, `burst`, `cc_immunity`, `debuff`, `execute`, `on_hit_effect`, `ramp`, `redirect`, `dot`, `reset_mechanic`, and `untargetable`
- report output that no longer hides untested goals/approaches
- failures now surface real tag-vs-behavior mismatches instead of being silently absent

What remains:

- direct telemetry for several deeper goal/approach KPIs: live-kit proof for every non-support semantic mode attached to a tag
- support live-kit proof is now covered for Axiom and Totem, including an explicit debuffed-carry Totem cleanse scenario that proves actual debuff removal separately from shield/CC-immunity/amp support identity
- live kit integration for deeper `redirect` modes beyond Korath's body-block absorb if a kit actually claims taunt-command or explicit threat-swap semantics. Current Korath coverage is valid for the doc's body-blocking redirect path.
- live primary-owner coverage for `mage.sustained_dps` if the roster keeps that doc goal; the catalog metric is now stricter and probe-guarded, but no current mage primary identity owns it.
- semantic depth for `on_hit_effect` beyond trait/buff-system procs if future kits implement item-side or native attack-side on-hit mechanics outside `BuffSystem`
- sharper ability semantics for explicit redirect threat-swap/taunt commands if those submodes are assigned to a kit

## Validation From This Pass

- Latest `RoleMatrixProbe6v6Korath.tscn` after live body-block semantic wiring: tank role PASS; `approach_damage_reduction: PASS`; `approach_redirect: PASS` with direct redirect evidence (`19` events, `280` damage prevented, `5` focus starts, `1` target swap, `63.0s` enemy focus), body-block events `19`, body-block prevented damage `280`, redirect end-risk events `19`, and end-risk seconds `31.40`; `goal tank.frontline_absorb: PASS` through direct body-block protection; `approach_engage: FAIL`.
- Latest `RoleMatrixProbe6v6Berebell.tscn`: brawler role PASS; `approach_reposition: PASS`; `approach_disrupt: FAIL`; `approach_sustain: FAIL`; direct `goal brawler.frontline_disruption: FAIL` with `goal_frontline_disruption_enemy_response_events: 0.00 < 1.00`.
- `ZoneExposureKernelProbe.tscn`: PASS; direct zone-exposure signal supported, events `2`, targets `2`, exposure time `2.5`, damage `20.0`, radius `2.0`, and direct `approach_zone` plus `goal_primary` area-denial consumption both pass.
- `RoleSemanticCatalogProbe.tscn`: PASS; all 6 role identity metrics passed a purpose-built positive payload, failed an empty/control negative payload, and emitted the expected role span prefix.
- `GoalPrimaryCatalogProbe.tscn`: PASS; all 22 doc primary goals passed a purpose-built positive payload, failed an empty/control negative payload, and emitted the expected goal span prefix.
- `ApproachSemanticCatalogProbe.tscn`: PASS; all 22 doc approaches passed a purpose-built positive payload, failed an empty/control negative payload, and emitted the expected approach span prefix.
- `MageSustainedDpsGoalProbe.tscn`: PASS; positive case passed with direct DoT/zone/ramp spans, AoE-only negative case failed, and AoE DPS emitted only as a diagnostic span.
- Latest `RoleMatrixProbe6v6Faeling.tscn` after retagging Faeling to `mage.area_denial_zone`: PASS; mage role PASS; direct `goal mage.area_denial_zone: PASS`; `approach_aoe: PASS`; `approach_zone: PASS` through direct Eavesdropping spin-zone exposure (`18` events, `3` targets, `3.60s` exposure, `327` damage, max radius `2.30`, `12.73` AoE DPS).
- Latest `RoleMatrixProbe6v6Paisley.tscn` after Google Doc retag: identity is `mage.wombo_combo_burst` with `aoe`/`peel`; `approach_aoe: PASS`; `approach_peel: PASS` through source-attributed ally shield evidence (`3` protection events, `321` magnitude); mage identity is LEAN/FAIL and direct `goal mage.wombo_combo_burst: FAIL` because burst share is `0.16 < 0.25` and CC-sync is `0`.
- Latest `RoleMatrixProbe6v6Volt.tscn` after Google Doc retag: identity is `mage.pick_burst` with `burst`/`lockdown`; mage role PASS; direct `goal mage.pick_burst: FAIL`; `approach_burst: FAIL`; `approach_lockdown: FAIL` with peak DPS `20.00 < 25.00`, no kills, and zero priority-lockdown evidence.
- `DisruptionKernelProbe.tscn`: PASS; direct forced reposition, target swap, formation break, and follow-up kill attribution all recorded.
- `DotTickKernelProbe.tscn`: PASS; direct source-owned DoT ticks, damage, touched targets, applied duration `3.0`, active uptime `1.25`, target receipt, target uptime `1.25`, direct `approach_dot` evaluation without proxy fallback, and synthetic neutral-vs-anti-DoT scenario-delta spans are recorded.
- `ExecuteBonusKernelProbe.tscn`: PASS; direct execute bonus signal support, bonus event count `1`, bonus damage `50`, bonus share `0.25`, low-HP kill count `1`, and direct `approach_execute` evaluation are recorded.
- `HexeonExecuteLiveProbe.tscn`: PASS; Hexeon's real `Prismatic Guillotine` executed the low-HP target with one execute event, `110` bonus damage, target HP pct `0.11 <= 0.12`, one low-HP kill, and zero outside-threshold events, while the above-threshold target survived with zero execute events and zero kills; direct `approach_execute` passed on the combined evidence.
- `RampStateKernelProbe.tscn`: PASS; direct ramp-state signal support, event count `2`, max stack `4`, time-to-peak `3.0`, peak/window duration `3.0`, direct `approach_ramp`, and goal-level direct ramp consumption are recorded.
- `ResetMechanicKernelProbe.tscn`: PASS; direct reset events, chain length, reset timing, touched targets, post-first-reset damage `150`, post-first-reset kills `2`, first follow-up `0.1s`, reset win-rate spans, neutral-vs-counter scenario-delta spans, and `approach_reset_mechanic` evaluation are recorded without proxy fallback.
- `UntargetableKernelProbe.tscn`: PASS; direct untargetable window duration, frame share, key-threat dodge rate, cooldown trade, and `approach_untargetable` evaluation are recorded without proxy fallback.
- `CooldownPressureKernelProbe.tscn`: PASS; direct cooldown-pressure signal support, cooldowns forced `2`, forced cooldown seconds `3.5`, key cooldown count `2`, threat-draw casters `2`, threat-draw abilities `2`, key-threat share `1.0`, trade efficiency `7.0`, and `approach_cc_immunity` counter-cooldown/quality spans are recorded.
- `CounterplayPressureKernelProbe.tscn`: PASS; direct forced-cleanse attribution, cleanse-bait rate, tenacity tax, direct `approach_lockdown`/`approach_debuff` counterplay spans, and synthetic neutral-vs-high-tenacity-cleanse scenario delta spans are recorded.
- `TotemCleanseLiveProbe.tscn`: PASS; Totem's real `Cleanse` implementation removes an enemy stat debuff from the allied carry, restores armor, emits source-owned cleanse and CC-immunity telemetry, attributes cleanse pressure back to the enemy debuff source, and passes direct `approach_peel`, `approach_cc_immunity`, support role, and `support.peel_carry` goal metrics.
- `RedirectThreatKernelProbe.tscn`: PASS; direct target and redirect-semantic signals supported, focus starts `1`, target swaps onto subject `1`, enemy focus duration `1.25`, taunt events `1`, body-block events `1`, body-block prevented damage `18.0`, end-risk events `1`, end-risk duration `0.75`, and direct `approach_redirect` evaluation are recorded.
- Latest `RoleMatrixProbe6v6Totem.tscn`: PASS overall; support role PASS, direct `goal support.peel_carry` PASS, `approach_peel` PASS, `approach_cc_immunity` PASS, and `approach_amp` PASS. Live evidence includes `subject_peel_ally_protection_events=76`, `subject_peel_ally_protection_magnitude=2356`, `subject_peel_cc_immunity_grants=19`, `subject_amp_output_delta=149.19`, `subject_amp_output_events=22`, `subject_amp_output_beneficiaries=1`, and `goal_peel_carry_cc_immunity_applied=19`.
- Latest `RoleMatrixProbe6v6Repo.tscn`: full row includes `counterplay_pressure` in capabilities; Repo still fails tank identity, `goal_primary` single-target lockdown, and `approach_lockdown` because the live run produced zero priority-control, forced-cleanse, or tenacity-tax subject evidence.
- Latest `RoleMatrixProbe6v6Hexeon.tscn`: reran after direct execute bonus telemetry with no parse/runtime errors; role and `goal_primary` pass, `access_backline` and `burst` pass, and `execute` remains the exposed content failure because direct execute bonus events and low-HP kills are both zero in the live counter scenario.
- Latest `RoleMatrixProbe6v6Nyxa.tscn`: `ramp_state` capability present; role, `goal_primary`, `long_range`, `ramp`, and `aoe` pass, with direct ramp spans at both approach and goal levels (`goal_backline_siege_ramp_state_events=2`, `stack_max=3`, `peak_duration=5.0`, `window_duration=5.0`).
- Latest `RoleMatrixProbe6v6Sari.tscn`: `ramp_state` capability present; direct `marksman.sustained_dps` goal, `long_range`, and direct `ramp` pass, while marksman identity remains LEAN/FAIL and `on_hit_effect` fails with zero subject proc events. This is now an explicit role-vs-goal-vs-approach separation rather than an untested goal path.
- Latest `RoleMatrixProbe6v6Veyra.tscn`: `ramp_state` capability present; `damage_reduction` passes, while tank identity, direct `tank.frontline_absorb`, `sustain`, and direct `ramp` fail with zero subject ramp-state events.
- Latest `RoleMatrixProbe6v6.tscn` for Bonko: `ramp_state` capability present; brawler role, direct attrition goal, `sustain`, and `ramp` pass, with goal-level direct ramp spans aggregated across three scenarios (`events=6`, `stack_max=3`, `peak_duration=3.0`, `window_duration=3.0`).
- `ApproachCatalogCoverage.tscn`: PASS; `approaches=22`, `goals=22`, `metrics=32`.
- `AmpOutputKernelProbe.tscn`: PASS; a source-attributed support buff plus a real buffed projectile hit emitted direct `amp_output_applied` telemetry, Axiom source record captured `1` ally buff, `1` output event, `25.0` output delta, `1` beneficiary, `hit_processed=true`, and both direct `approach_amp` plus `support.team_amplification` goal spans passed.
- Latest `RoleMatrixProbe6v6Axiom.tscn`: PASS overall; `approach_amp`, `approach_peel`, `approach_sustain`, `goal_primary`, and support identity pass. Direct live amp-output spans now pass with `subject_amp_output_delta: 120.46 >= 1.00`, `subject_amp_output_events: 17.00 >= 1.00`, `subject_amp_output_beneficiaries: 1.00 >= 1.00`, and `goal_team_amplification_amp_output_delta: 120.46 >= 1.00`.
- Earlier targeted runs before direct `goal_primary` remain useful as approach evidence, but their `PROXY_*` goal statuses should be rerun before treating them as current direct goal verdicts. Those earlier runs showed real content mismatches in Sari on-hit, Teller debuff/ramp, Repo lockdown/burst, Hexeon execute, Grint engage/disrupt, and Berebell disrupt; the older Paisley peel/zone finding is superseded by the Google Doc retag.
- Earlier targeted coverage still shows real mismatches: Repo fails lockdown/burst, Hexeon fails execute, Grint fails engage/disrupt, and Berebell fails disrupt. Paisley's current retagged probe instead passes `aoe`/`peel` but fails the `mage.wombo_combo_burst` goal and mage identity.
- Latest `RoleMatrixSmoke.tscn`: FAIL as a roster/content smoke. Representative role/goal/approach reports passed for Korath, Nyxa, Hexeon, and Axiom; Bonko passed brawler role, attrition goal, and ramp but failed live `sustain`; Paisley passed `aoe` and `peel` but mage identity was LEAN and `mage.wombo_combo_burst` failed. This is the intended current behavior: the framework can test role/goal/approach, and live roster mismatches surface instead of being hidden.

All targeted runs still show the known Godot shutdown tail:

- `ObjectDB instances leaked at exit`
- `8 resources still in use at exit`

Those warnings were already observed outside the new metrics and should be tracked separately from role/approach correctness.
