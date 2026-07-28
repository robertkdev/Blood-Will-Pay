# RGA Validation — Entry Points

Run these scenes via MCP for headless validation and reports.

- Role Matrix Probe (per-unit orchestrator)
  - Scene: `tests/rga_testing/validation/RoleMatrixProbe.tscn`
  - Args (examples):
    - `-- unit_id=bonko` (minimal)
    - `-- unit_id=bonko scenario_packs_to_run=neutral,burst opponents_per_pack=1 max_sims=12`
    - `-- unit_id=bonko dump_json=1` (raw metric JSON)
  - Live counterplay scenarios: quick/full RoleMatrix runs now treat `counterplay`, `cleanse`, and `high_tenacity_cleanse` labels as response-pressure scenarios. Quick probes add a synthetic `shared.counterplay_response` pack when the label is requested; full 6v6 probes force Totem and Veyra into the opposing response shell. Non-counterplay quick metrics evaluate against baseline rows only, while `approach_debuff` and `approach_lockdown` evaluate against the combined baseline-plus-counterplay rows so scenario-delta evidence does not dilute unrelated engage/goal gates.

- Full Probe 6v6 (subject-as-slot substitution)
  - Scene: `tests/rga_testing/validation/RoleMatrixProbe6v6.tscn`
  - Default profile is wired for 6v6 with subject substituted into each role slot, 3 seeds per scenario, and `max_sims=12` for quick runs.
  - To adjust quickly via MCP before running:
    - Set repeats/seeds or cap sims: edit `RoleMatrixProbe` node props (e.g., `max_sims=18`, `repeats=3`).
  - Produces rows in a single file: `user://rga_out.jsonl` (overwritten each run), and a report at `user://identity_reports/<unit>.json`.
  - Targeted 6v6 scenes:
    - `tests/rga_testing/validation/RoleMatrixProbe6v6Axiom.tscn` - support peel/sustain/amp.
    - `tests/rga_testing/validation/RoleMatrixProbe6v6Mara.tscn` - mage pick_burst/burst.
    - `tests/rga_testing/validation/RoleMatrixProbe6v6Bo.tscn` - brawler skirmish_dive/disrupt/reposition across counter and peel contexts.
    - `tests/rga_testing/validation/RoleMatrixProbe6v6Mortem.tscn` - brawler attrition_dps/reposition/burst/disrupt across burst and peel contexts.
    - `tests/rga_testing/validation/RoleMatrixProbe6v6Hexeon.tscn` - assassin access_backline/burst/execute across counter and burst contexts.
    - `tests/rga_testing/validation/RoleMatrixProbe6v6Nyxa.tscn` - marksman long_range/ramp/aoe.
    - `tests/rga_testing/validation/RoleMatrixProbe6v6Paisley.tscn` - mage wombo/aoe/peel.
    - `tests/rga_testing/validation/RoleMatrixProbe6v6Faeling.tscn` - mage area_denial_zone/aoe/zone.
    - `tests/rga_testing/validation/RoleMatrixProbe6v6Volt.tscn` - mage pick_burst/burst/lockdown across counterplay plus burst contexts.
    - `tests/rga_testing/validation/RoleMatrixProbe6v6Grint.tscn` - tank initiate_fight/engage/debuff/damage_reduction across counterplay, engage, and burst contexts.
    - `tests/rga_testing/validation/RoleMatrixProbe6v6Berebell.tscn` - brawler disrupt/reposition/sustain.
    - `tests/rga_testing/validation/RoleMatrixProbe6v6Repo.tscn` - tank lockdown/damage_reduction/burst.
    - `tests/rga_testing/validation/RoleMatrixProbe6v6Veyra.tscn` - tank damage_reduction/sustain/ramp.
    - `tests/rga_testing/validation/RoleMatrixProbe6v6Sari.tscn` - marksman long_range/ramp/on_hit_effect.
    - `tests/rga_testing/validation/RoleMatrixProbe6v6Kythera.tscn` - tank team_fortification/damage_reduction/debuff across counterplay, fortify, and burst contexts, with explicit goal-primary span checks for the now-passing buff-uptime contract.
    - `tests/rga_testing/validation/RoleMatrixProbe6v6Korath.tscn` - tank damage_reduction/redirect/engage.
    - `tests/rga_testing/validation/RoleMatrixProbe6v6Teller.tscn` - marksman sustained_dps/long_range/burst/aoe across sustained, clustered, kite, and burst contexts.
    - `tests/rga_testing/validation/RoleMatrixProbe6v6Totem.tscn` - support peel/amp/cc_immunity across `peel` plus carry-threat `threat` contexts, with explicit goal-primary span checks for the current save/interrupt residual shape.

- On-hit telemetry positive control
  - Scene: `tests/rga_testing/validation/OnHitProcProbe.tscn`
  - Fixed 6v6 team with two active Vindicator units; fails if the subject records no explicit `on_hit_proc` events.

- Completed item effect registry smoke
  - Scene: `tests/rga_testing/validation/CompletedItemEffectRegistrySmoke.tscn`
  - Loads completed item resources and fails if any declared runtime effect lacks a registered `EffectRegistry` handler, or if a completed item declares an unsupported `stat_mods` key.

- Disruption telemetry positive control
  - Scene: `tests/rga_testing/validation/DisruptionKernelProbe.tscn`
  - Directly drives `DerivedStatsAggregator` and fails if post-control forced reposition, target swap, formation break, or follow-up kill attribution is missing.

- DoT tick telemetry positive control
  - Scene: `tests/rga_testing/validation/DotTickKernelProbe.tscn`
  - Directly drives `CombatEngine.dot_tick_applied` plus a source-attributed DoT debuff and a synthetic neutral-vs-anti-DoT payload; fails if source-owned tick count, tick damage, touched targets, source duration, active uptime, target receipt, direct `approach_dot` evaluation, or anti-DoT scenario-delta spans are missing.

- Reset telemetry positive control
  - Scene: `tests/rga_testing/validation/ResetMechanicKernelProbe.tscn`
  - Directly drives `CombatEngine.reset_triggered`, paired post-reset hit events, and a synthetic neutral-vs-counter payload; fails if reset event count, chain length, reset timing, touched targets, post-first-reset impact, reset counter-scenario deltas, or direct `approach_reset_mechanic` evaluation is missing.

- Execute bonus telemetry positive control
  - Scene: `tests/rga_testing/validation/ExecuteBonusKernelProbe.tscn`
  - Directly drives `CombatEngine.execute_bonus_applied` and paired hit events; fails if execute bonus event count, bonus damage, bonus damage share, low-HP kill conversion, or direct `approach_execute` evaluation is missing.

- Execute bonus approach accepted-miss probe
  - Scene: `tests/rga_testing/validation/ExecuteBonusApproachProbe.tscn`
  - Proves real Hexeon/Morrak `execute` approach rows can consume direct execute-bonus events, bonus damage share, low-HP kill conversion, and overkill guardrails. Low-share positive-bonus rows stay diagnostic when direct execute evidence proves the aggregate, while zero-bonus aggregate controls still preserve the failed bonus-share span.

- Hexeon live execute threshold positive control
  - Scene: `tests/rga_testing/validation/HexeonExecuteLiveProbe.tscn`
  - Runs Hexeon's real `Prismatic Guillotine` implementation in low-HP and above-threshold cases; fails if the low-HP target is not executed, the above-threshold target is executed, threshold compliance telemetry is wrong, or direct `approach_execute` evaluation does not consume the live evidence.

- Assassin opening role positive control
  - Scene: `tests/rga_testing/validation/AssassinOpeningRoleProbe.tscn`
  - Drives `CombatEngine.position_updated` through `BacklineAccessKernel`; fails unless the real Hexeon assassin role emits passing subject-level `subject_first_backline_frac` evidence, keeps the side-level `a_first_frac` proxy diagnostic when the audited subject proves access, and rejects a late/access-losing control.

- Assassin opening scenario-pack smoke
  - Scene: `tests/rga_testing/validation/AssassinOpeningScenarioPackSmoke.tscn`
  - Fails unless Hexeon-style assassin identities keep `neutral`, `counter`, and `burst` contexts, non-assassin pick-burst identities do not request `counter`, and the assassin `counter` pack resolves to the front-lane `dive_window` map.

- Ramp state telemetry positive control
  - Scene: `tests/rga_testing/validation/RampStateKernelProbe.tscn`
  - Directly drives `CombatEngine.ramp_state_changed` and fails if ramp event count, max stacks, time-to-peak, peak/window duration, direct `approach_ramp`, or direct goal-level ramp consumption is missing.

- Ramp approach accepted-miss probe
  - Scene: `tests/rga_testing/validation/RampApproachProbe.tscn`
  - Proves real Sari/Veyra `ramp` approach rows can consume direct ramp-state events, max stacks, peak duration, and window duration. Also proves low stack-max rows stay diagnostic when ramp events plus peak/window duration already satisfy `approach_ramp`, while weak controls still fail.

- Veyra Harden canonical stack probe
  - Scene: `tests/rga_testing/validation/VeyraHardenCanonicalStackProbe.tscn`
  - Proves the scheduled Harden end effect consumes canonical `TraitKeys.AEGIS` stacks, not only the old `aegis_stacks` fallback, and applies the permanent max-HP stack.

- Kythera Siphon canonical stack probe
  - Scene: `tests/rga_testing/validation/KytheraSiphonCanonicalStackProbe.tscn`
  - Proves the real Siphon cast consumes canonical `TraitKeys.AEGIS` stacks for drain rate, executes scheduled tick/end events, drains target MR, and applies Kythera's permanent MR stack.

- Mara Ledger canonical stack probe
  - Scene: `tests/rga_testing/validation/MaraLedgerCanonicalStackProbe.tscn`
  - Proves the real Arcane Ledger cast consumes canonical `TraitKeys.ARCANIST` stacks for damage scaling without relying on the old `arcanist_stacks` fallback.

- Paisley Bubbles canonical stack probe
  - Scene: `tests/rga_testing/validation/PaisleyBubblesCanonicalStackProbe.tscn`
  - Proves the real Bubbles cast consumes canonical `TraitKeys.KALEIDOSCOPE` and `TraitKeys.ARCANIST` stacks for both low-HP ally shielding and split magic damage without relying on old stack-key fallbacks.

- Morrak Reaping Line canonical stack probe
  - Scene: `tests/rga_testing/validation/MorrakReapingLineCanonicalStackProbe.tscn`
  - Proves the real Reaping Line cast consumes canonical `TraitKeys.STRIKER` and `TraitKeys.EXECUTIONER` stacks for line damage scaling and the low-HP execute threshold without relying on old stack-key fallbacks.

- Hexeon Guillotine canonical stack probe
  - Scene: `tests/rga_testing/validation/HexeonGuillotineCanonicalStackProbe.tscn`
  - Proves the real Prismatic Guillotine cast consumes canonical `TraitKeys.KALEIDOSCOPE` stacks for damage scaling and canonical `TraitKeys.EXECUTIONER` stacks for the low-HP execute threshold without relying on old stack-key fallbacks.

- Bonko empower contract probe
  - Scene: `tests/rga_testing/validation/BonkoEmpowerContractProbe.tscn`
  - Proves the current Bonk cast applies the Bonko empower tag with the expected hit count, damage/heal/mana metadata, and direct ramp-state telemetry. Bonko no longer reads legacy Striker stack helpers in the cast path.

- Mage sustained-DPS goal positive/negative control
  - Scene: `tests/rga_testing/validation/MageSustainedDpsGoalProbe.tscn`
  - Feeds `goal_primary` a direct sustained-magic positive case with DoT, zone, and ramp evidence plus an AoE-DPS-only negative case; fails if `mage.sustained_dps` accepts AoE-only damage without a direct sustained mechanism.

- Amp output telemetry positive control
  - Scene: `tests/rga_testing/validation/AmpOutputKernelProbe.tscn`
  - Applies a source-attributed damage amp to an ally, runs a real buffed projectile hit, and fails if source-owned output events, output delta, beneficiaries, direct `approach_amp`, or direct `support.team_amplification` goal consumption is missing.

- Untargetable telemetry positive control
  - Scene: `tests/rga_testing/validation/UntargetableKernelProbe.tscn`
  - Directly drives `CombatEngine.targetability_window` and `CombatEngine.targetability_threat_interaction`, and fails if untargetable frame share, key-threat dodge rate, cooldown trade, or direct `approach_untargetable` evaluation is missing.

- Cooldown-pressure telemetry positive control
  - Scene: `tests/rga_testing/validation/CooldownPressureKernelProbe.tscn`
  - Directly drives `CombatEngine.ability_committed` plus CC-immunity evidence, and fails if cooldowns forced, cooldown seconds, key cooldown count, threat-draw caster/ability diversity, key-threat share, trade efficiency, direct cooldown-quality spans, or direct `approach_cc_immunity` counter-cooldown evaluation is missing.

- Counterplay-pressure telemetry positive control
  - Scene: `tests/rga_testing/validation/CounterplayPressureKernelProbe.tscn`
  - Directly drives `CombatEngine.debuff_applied`, `CombatEngine.cc_taxed`, and `CombatEngine.cleanse_applied`; fails if forced-cleanse attribution, cleanse-bait rate, tenacity tax, direct `approach_lockdown`/`approach_debuff` counterplay spans, or synthetic cleanse/high-tenacity scenario-delta spans are missing.

- Counterplay context triage smoke
  - Scene: `tests/rga_testing/validation/CounterplayContextTriageSmoke.tscn`
  - Synthetic counterplay guard for Brute, Volt, Grint, Kythera, and Sari; fails if the current debuff/lockdown counterplay spans stop passing when cleanse/high-tenacity response pressure is present.
  - The live RoleMatrix smoke now exercises this pressure for debuff/lockdown identities. The 2026-06-25 run confirmed Grint's `counterplay` scenario passes debuff scenario-delta spans without breaking `tank.initiate_fight`; low response-pressure rows on Kythera, Sari, Brute, and Volt are now diagnostic when direct debuff/lockdown evidence already satisfies the aggregate.

- Counterplay accepted-miss probe
  - Scene: `tests/rga_testing/validation/CounterplayAcceptedMissProbe.tscn`
  - Feeds Kythera/Sari debuff rows and Brute/Volt lockdown rows through their real approach metrics; fails unless response-pressure rows pass cleanse/high-tenacity spans, direct debuff/lockdown aggregate controls keep low response spans diagnostic while the approaches pass, and weak controls fail.

- Totem live cleanse positive control
  - Scene: `tests/rga_testing/validation/TotemCleanseLiveProbe.tscn`
  - Runs Totem's real `Cleanse` implementation against a genuinely debuffed allied carry; fails if the debuff is not removed, source-owned cleanse/CC-immunity telemetry is missing, enemy cleanse-pressure attribution is missing, direct `approach_peel`, `approach_cc_immunity`, `role_support_identity`, and `support.peel_carry` goal consumption do not pass, or the current no-save/no-interrupt residual shape changes without updating the accepted-miss contract.

- Totem peel-carry accepted-miss probe
  - Scene: `tests/rga_testing/validation/TotemPeelCarryAcceptedMissProbe.tscn`
  - Feeds the real Totem identity through `approach_peel`, `approach_cc_immunity`, `role_support_identity`, and `support.peel_carry`; fails unless full team-save/EHP/CC-prevention/interrupt/cooldown evidence passes, direct-protection aggregate controls keep current goal save/interrupt lower-level miss spans failing while CC-prevention and cooldown-efficiency rows are diagnostic, and a weak payload fails all consumers.

- Support carry-threat scenario-pack smoke
  - Scene: `tests/rga_testing/validation/SupportCarryThreatScenarioPackSmoke.tscn`
  - Fails unless `support.peel_carry` identities keep a `threat` context alongside `peel`, non-peel-carry supports and non-support CC-immunity identities do not, and the support `threat` pack resolves to back-lane `carry_threat_window`.

- Totem focused 6v6 peel/threat probe
  - Scene: `tests/rga_testing/validation/RoleMatrixProbe6v6Totem.tscn`
  - Runs Totem in full 6v6 support-slot `peel` and carry-threat `threat` contexts; fails if the role, `support.peel_carry` goal, `approach_peel`, `approach_cc_immunity`, or `approach_amp` aggregate consumers stop passing. The scene also opts into `RoleMatrixProbe.expected_span_checks` so the current live audit contract is explicit: goal-level save and interrupt spans fail, while direct ally-protection events, magnitude, and CC-immunity application spans pass.

- Totem goal-alignment probe
  - Scene: `tests/rga_testing/validation/TotemGoalAlignmentProbe.tscn`
  - Reruns the same real Totem 6v6 `peel` and carry-threat `threat` rows, verifies the current `support.peel_carry` aggregate pass plus save/interrupt residual shape, then evaluates those rows under a temporary `support.team_amplification` identity override. This is a design-decision guard: it proves the team-amplification contract is mechanically viable without changing Totem's actual identity resource.

- Redirect threat-swap telemetry positive control
  - Scene: `tests/rga_testing/validation/RedirectThreatKernelProbe.tscn`
  - Directly drives `CombatEngine.target_start`, `CombatEngine.target_end`, and `CombatEngine.redirect_semantic_applied`; fails if enemy focus starts, target swaps onto the subject, focus duration, explicit taunt/body-block/end-risk evidence, or direct `approach_redirect` evaluation is missing.

- Korath redirect accepted-miss probe
  - Scene: `tests/rga_testing/validation/KorathRedirectAcceptedMissProbe.tscn`
  - Feeds the real Korath `redirect` approach direct target-swap, explicit threat-swap, and taunt evidence; fails unless those submode spans can pass, a direct body-block aggregate control keeps those missing submode spans diagnostic while `approach_redirect` passes, and a direct-supported weak payload fails even when proxy incoming-share evidence is present.

- Frontline body-block goal positive control
  - Scene: `tests/rga_testing/validation/FrontlineBodyBlockGoalProbe.tscn`
  - Directly drives `CombatEngine.damage_redirected` and `redirect_semantic_applied`; fails unless the real Brute `tank.frontline_absorb` goal consumes both direct body-block events and enough prevented damage, while event-only, damage-only, and weak-prevention controls fail.

- Brute frontline fallback diagnostic probe
  - Scene: `tests/rga_testing/validation/BruteFrontlineShareGoalProbe.tscn`
  - Feeds the real Brute `tank.frontline_absorb` goal direct incoming-share evidence; fails unless the damage-taken-share span can pass, an aggregate prevention-plus-frontline-position control keeps low damage-share and absent body-block spans diagnostic while the goal passes, and a weak frontline control fails.

- Grint engage-success goal diagnostic probe
  - Scene: `tests/rga_testing/validation/GrintEngageSuccessGoalProbe.tscn`
  - Feeds the real Grint `tank.initiate_fight` goal direct engage-success evidence; fails unless the success-target span can pass, an aggregate distance-plus-first-action control keeps the success-target span diagnostic while the goal passes, and a weak initiate control fails.

- Tank engage scenario-pack smoke
  - Scene: `tests/rga_testing/validation/TankEngageScenarioPackSmoke.tscn`
  - Fails unless Grint-style initiate identities keep `engage`, `counterplay`, and `burst` under label-cap pressure, non-engage fortification tanks do not request `engage`, and the tank `engage` pack resolves to front-lane `engage_window`.

- Zone exposure telemetry positive control
  - Scene: `tests/rga_testing/validation/ZoneExposureKernelProbe.tscn`
  - Directly drives `CombatEngine.zone_exposure_applied`; fails if source-owned zone/hazard exposure events, unique targets, duration, damage, radius, direct `approach_zone`, or direct `mage.area_denial_zone` goal consumption is missing.

- Identity catalog coverage
  - Scene: `tests/rga_testing/validation/ApproachCatalogCoverage.tscn`
  - Loads every metric descriptor and fails if an `IdentityKeys.APPROACHES` entry lacks an `approach_*` metric or if a doc goal resource is missing.

- Role semantic catalog coverage
  - Scene: `tests/rga_testing/validation/RoleSemanticCatalogProbe.tscn`
  - Directly feeds all six role identity metrics synthetic positive and negative payloads; fails if any role cannot pass on purpose-built evidence, if an empty/control payload passes, or if the expected role span prefix is missing.

- Goal-primary semantic catalog coverage
  - Scene: `tests/rga_testing/validation/GoalPrimaryCatalogProbe.tscn`
  - Directly feeds `goal_primary` synthetic positive and negative payloads for all 22 Google-doc primary goals; fails if any mapped goal cannot pass on purpose-built evidence, if an empty/control payload passes, or if the expected goal span prefix is missing.

- Team-fortification buff goal positive control
  - Scene: `tests/rga_testing/validation/TeamFortificationBuffGoalProbe.tscn`
  - Directly drives `CombatEngine.buff_applied`; fails unless the real Kythera `tank.team_fortification` goal emits a passing fortification span when same-team source-owned self or ally telemetry is present, preserves an aggregate no-buff pass through EHP/prevention with a failed buff span, and rejects buff-only or weak controls.

- Team-fortification scenario-pack smoke
  - Scene: `tests/rga_testing/validation/TeamFortificationScenarioPackSmoke.tscn`
  - Fails unless `tank.team_fortification` identities keep a `fortify` context under label-cap pressure, non-fortification tanks do not, and the tank `fortify` pack resolves to front-lane `fortification_window`.

- Skirmish-dive backline goal positive control
  - Scene: `tests/rga_testing/validation/SkirmishDiveBacklineGoalProbe.tscn`
  - Directly drives `CombatEngine.hit_applied` through `PerUnitKpisKernel` and direct `BacklineAccessKernel` entries; fails unless the real Bo `brawler.skirmish_dive` goal emits a passing backline-contact span from either non-frontline damage share or direct backline access, and rejects an all-frontline/no-access control.

- Skirmish-dive scenario-pack smoke
  - Scene: `tests/rga_testing/validation/SkirmishDiveScenarioPackSmoke.tscn`
  - Fails unless Bo-style `brawler.skirmish_dive` identities request the `counter` context, non-skirmish brawlers do not, and the brawler `counter` pack resolves to front-lane `dive_window`.

- Approach semantic catalog coverage
  - Scene: `tests/rga_testing/validation/ApproachSemanticCatalogProbe.tscn`
  - Directly feeds every Google-doc approach metric synthetic positive and negative payloads; fails if any approach cannot pass on purpose-built evidence, if an empty/control payload passes, or if the expected approach span prefix is missing.

- Quick sanity (wrapper)
  - Scene: `tests/rga_testing/validation/QuickProbe.tscn`
  - One unit (default: bonko), neutral scenarios, small run; prints PASS/FAIL and exits.

- RGA Testing main (pipeline + optional metrics)
  - Scene: `tests/rga_testing/RGATesting.tscn`
  - Pick a profile in the inspector (e.g., `rga_roles_derived`).

- CI smoke (optional)
  - Scene: `tests/rga_testing/ci/RoleMatrixSmoke.tscn` (attach `RoleMatrixSmoke.gd`)
  - Runs RoleMatrixProbe programmatically for 1 unit per role with minimal seeds; asserts report files exist.

- Probe report compiler smoke
  - Scene: `tests/rga_testing/validation/ProbeReportCompilerSubjectSideSmoke.tscn`
  - Synthetic fast check that report diagnostics keep audited-side spans and exclude opponent-side aggregates such as `b_unit_pass_count`, suffix labels such as `magic_share_med_b`, and direct-attrition diagnostics for non-attrition brawler identities.

- Unit identity map doc smoke
  - Scene: `tests/rga_testing/validation/UnitIdentityMapDocSmoke.tscn`
  - Compares `docs/unit_identity_map.md` against current playable `UnitCatalog` identity metadata so stale role/goal/approach retags do not mislead audits.

- Goal primary ramp applicability smoke
  - Scene: `tests/rga_testing/validation/GoalPrimaryRampApplicabilitySmoke.tscn`
  - Ensures goal-level ramp diagnostics are emitted for ramp-tagged identities and skipped for non-ramp identities that pass the same primary goal through other assigned evidence.

- Probe report hard-peel applicability smoke
  - Scene: `tests/rga_testing/validation/ProbeReportCompilerHardPeelApplicabilitySmoke.tscn`
  - Ensures saved accepted-miss diagnostics keep cleanse/CC-immunity hard-peel subspans only for identities that claim `support.peel_carry` or `cc_immunity`, while preserving team peel-save scenario diagnostics for soft peel identities.

- Accepted-miss guard coverage smoke
  - Scene: `tests/rga_testing/validation/AcceptedMissGuardCoverageSmoke.tscn`
  - Reads the regenerated `outputs/audit_playtest/rga_accepted_misses_current/accepted_gap_kind_summary.csv` and `accepted_lower_level_fail_spans.csv`; fails if the current 2 accepted-miss gap kinds are not each mapped to validation scenes covering synthetic proof, scenario-pack coverage, and the focused live residual probe, if the accepted span count is not 2, or if the detailed residual rows differ from the current Totem peel-save/interrupt contract. Regenerate the export with `tests/rga_testing/tools/Export-AcceptedMisses.ps1` before running this smoke.

- Peel team-save proxy probe
  - Scene: `tests/rga_testing/validation/PeelTeamSaveProxyProbe.tscn`
  - Proves one derived team peel-save passes the shared proxy path for `approach_peel`, `role_support_identity`, and `support.peel_carry`, and rejects a zero-save control payload.

- Soft-peel team-save accepted-miss probe
  - Scene: `tests/rga_testing/validation/SoftPeelTeamSaveAcceptedMissProbe.tscn`
  - Proves real Axiom/Paisley soft-peel rows can pass from direct team-save evidence, and keeps low team-save fallback spans diagnostic when ally-protection evidence already keeps the consumers passing.

- EHP ratio path probe
  - Scene: `tests/rga_testing/validation/EhpRatioPathProbe.tscn`
  - Proves EHP ratio pass paths for `approach_sustain`, `approach_peel`, support-role team EHP proxy, and support-role subject EHP diagnostic, and rejects weak controls.

- AoE targeting kernel probe
  - Scene: `tests/rga_testing/validation/AoeTargetingKernelProbe.tscn`
  - Proves grouped same-time hits record direct multi-target evidence for `targets_hit_median`, `max_targets_hit`, `multi_target_groups`, and `aoe_dps`, and that `approach_aoe` passes on that telemetry.

- AoE multi-target accepted-miss probe
  - Scene: `tests/rga_testing/validation/AoeMultiTargetApproachProbe.tscn`
  - Proves real Luna/Morrak/Nyxa/Paisley/Teller `aoe` approach rows can consume clustered same-time hit groups for a passing target-median span. Also preserves aggregate-pass controls where the same identities pass `approach_aoe` through max-target evidence while the median target span remains diagnostic.

- AoE clustered scenario probe
  - Scene: `tests/rga_testing/validation/AoeClusteredScenarioProbe.tscn`
  - Proves live clustered RoleMatrix contexts for Luna/Morrak/Nyxa/Paisley/Teller pass `approach_aoe` through direct max-target and/or AoE-DPS evidence while low all-hit median rows remain diagnostic.

- Brawler direct attrition probe
  - Scene: `tests/rga_testing/validation/BrawlerDirectAttritionProbe.tscn`
  - Proves `role_brawler_identity` can pass through direct attrition evidence when frontline damage share, sustain EHP, prevention EHP, support healing/shielding, and pressure evidence are present, including burst peak-DPS/share pressure, and rejects a weak negative payload.

- Brawler attrition scenario-pack smoke
  - Scene: `tests/rga_testing/validation/BrawlerAttritionScenarioPackSmoke.tscn`
  - Fails unless Mortem-style attrition brawler identities keep `neutral`, `burst`, and `peel` contexts without requesting skirmish `counter`, and the brawler `burst`/`peel` packs resolve to front-lane `burst_lane` and `peel_context` maps.

- Burst window kernel probe
  - Scene: `tests/rga_testing/validation/BurstWindowKernelProbe.tscn`
  - Proves concentrated combat-pattern hits record direct `peak_1s_damage_share`, `peak_1s_dps`, overkill, and counterplay-window telemetry for `approach_burst`, rejects diffuse damage, and keeps low peak-share rows diagnostic when peak DPS already proves the burst approach.

- Pick-burst kill goal probe
  - Scene: `tests/rga_testing/validation/PickBurstKillGoalProbe.tscn`
  - Proves lethal combat-pattern hits feed `kill_count` into the real Mara `mage.pick_burst` goal span, while a nonlethal aggregate pass keeps the kill-count span failing and a diffuse control fails the goal.

- Pick-burst scenario-label smoke
  - Scene: `tests/rga_testing/validation/PickBurstScenarioLabelSmoke.tscn`
  - Guards all-unit smoke scenario selection for `mage.pick_burst` identities: pick-burst rows keep `burst` before generic `peel` under label-cap pressure, non-pick-burst defensive rows preserve the existing `engage` and `peel` preference, and mage `burst` resolves to the back-lane `pick_burst_window` pack.

- Wombo combo goal probe
  - Scene: `tests/rga_testing/validation/WomboComboGoalProbe.tscn`
  - Proves real Luna/Paisley `mage.wombo_combo_burst` goal rows consume direct combat-pattern peak-share and multi-target evidence plus control-mobility CC event evidence. Also preserves aggregate-pass controls where Luna's missing CC-sync proxy and Paisley's low peak-share span stay diagnostic when alternate Wombo evidence satisfies the 2-of-3 goal aggregate.

- Reposition movement kernel probe
  - Scene: `tests/rga_testing/validation/RepositionMovementKernelProbe.tscn`
  - Proves direct movement signals record `max_step_tiles`, `post_cast_displacement_tiles`, total path distance, and reposition steps for `approach_reposition`, keeps low max-step/post-cast rows diagnostic when alternate path-distance evidence satisfies the k-of-n approach, and rejects weak movement.

- Engage CC timing kernel probe
  - Scene: `tests/rga_testing/validation/EngageCcTimingKernelProbe.tscn`
  - Proves direct control-mobility signals record median/peak early displacement, first action, and first CC timing for `approach_engage`, keeps low median displacement or missing first-CC rows diagnostic when standard or peak displacement plus first-action evidence satisfies the engage approach, and rejects a weak no-engage control payload.

- Mage periodicity kernel probe
  - Scene: `tests/rga_testing/validation/MagePeriodicityKernelProbe.tscn`
  - Proves magic hit components record top-2s magic damage share and magic peak-over-mean for `role_mage_identity`, keeps low magic-share rows diagnostic when peak-over-mean already proves mage periodicity, and rejects diffuse magic damage.

- Marksman positioning role probe
  - Scene: `tests/rga_testing/validation/MarksmanPositioningRoleProbe.tscn`
  - Proves `role_marksman_identity` can pass through sustained DPS leadership plus direct backline/ranged positioning, emits low auxiliary candidate/subject damage-share rows and low side-backline rows as diagnostics when subject ranged/time-on-target evidence proves marksman positioning, and rejects weak marksman evidence.

- Marksman sustained-DPS goal probe
  - Scene: `tests/rga_testing/validation/MarksmanSustainedDpsGoalProbe.tscn`
  - Proves real Sari/Teller `marksman.sustained_dps` goal rows can consume direct team damage share, range/time-on-target, survival, and Sari ramp-state evidence. Also preserves aggregate-pass controls where Sari/Teller pass while team damage share is below target, and proves Sari's low ramp-stack span stays diagnostic when alternate ramp-state proof is enough.

- Marksman sustained-window kernel probe
  - Scene: `tests/rga_testing/validation/MarksmanSustainedWindowKernelProbe.tscn`
  - Proves combat-pattern telemetry emits `early_0_3s_*` and `sustained_3_10s_*` fields, and that direct sustained-window team share plus sustained rate can make whole-fight damage share diagnostic for burst-biased sustained-DPS audits.

- Marksman sustained-DPS scenario-pack smoke
  - Scene: `tests/rga_testing/validation/MarksmanSustainedScenarioPackSmoke.tscn`
  - Guards all-unit smoke scenario selection so Sari-style sustained marksmen keep `sustained`, `kite`, and `counterplay`; Teller-style sustained AoE marksmen keep `sustained`, `kite`, `burst`, and clustered contexts; and non-sustained marksmen do not request `sustained`. It also proves the marksman `sustained` label resolves to the back-lane `marksman_sustained_pressure` map.

Artifacts
- Telemetry rows: `user://rga_out.jsonl` (or configured `out_path` ending with .jsonl/.ndjson; file is cleared each run)
- Probe reports: `user://identity_reports/<unit>.json`
  - `diagnostics.lower_level_fail_spans` lists applicable subject-side role/goal/approach span misses that were accepted by aggregate verdicts, with `lower_level_fail_span_count` for backlog triage. Non-applicable goal ramp spans, soft-peel hard-peel subspans, auxiliary marksman role share spans, alternate marksman side-backline spans, and direct-attrition spans for non-attrition brawlers are suppressed from saved diagnostics.
  - Role, goal, and approach verdict objects also include `span_details` and `failed_span_count` for local inspection without parsing console logs.
- Accepted-miss export: run `tests/rga_testing/tools/Export-AcceptedMisses.ps1` from the repo root to regenerate the ignored `outputs/audit_playtest/rga_accepted_misses_current/` CSV and JSON summary from current `user://identity_reports/*.json`. The row CSV includes `topic`, `audit_gap_kind`, and `audit_next_action` for every recognized accepted span, plus `support_peel_triage`, `support_peel_gap_kind`, and `support_peel_next_action` for the support/peel bucket. The generated `accepted_gap_kind_summary.csv` rolls those rows up by gap kind with counts, affected topics, units, labels, block types, and representative next action, and the generated README renders that rollup as a Markdown table. The JSON summary includes the same `audit_gap_kind_details` plus `primary_topic_counts`, `audit_gap_kind_counts`, `support_peel_triage_counts`, and `support_peel_gap_kind_counts`, so the backlog can be reviewed by scenario/content group and next tuning action instead of only by keyword.
- `AcceptedMissGuardCoverageSmoke.tscn` is the executable coverage manifest for the current accepted-miss audit state. It expects the regenerated summary to contain 2 gap kinds and 2 accepted spans, verifies every exported gap kind maps to committed validation-scene coverage, verifies the detailed CSV still contains only the exact Totem peel-save/interrupt rows, and verifies `docs/rga/accepted_miss_residual_audit_2026-06-26.md` names every current gap kind, affected unit, and metric label.

Notes
- Latest doc-vs-test comparison: `docs/rga/test_notes_2026-06-23.md`
- Role/goal/approach coverage matrix: `docs/rga/role_goal_approach_coverage_2026-06-23.md`
- Current doc-name approach metrics include `access_backline`, `long_range`, `peel`, `zone`, `sustain`, `damage_reduction`, `lockdown`, `burst`, `execute`, `aoe`, `ramp`, `disrupt`, `engage`, `reposition`, `amp`, `cc_immunity`, `debuff`, `on_hit_effect`, `redirect`, `dot`, `reset_mechanic`, and `untargetable`.
- All catalog approach tags have executable verdict paths and now have an all-approach semantic catalog gate. `RoleSemanticCatalogProbe.tscn` proves all six role identity metrics can pass on purpose-built evidence, reject an empty/control payload, and emit an expected role span. `AssassinOpeningRoleProbe.tscn` specifically proves Hexeon's assassin role can pass subject-level `subject_first_backline_frac` from real `BacklineAccessKernel` position telemetry while keeping a losing side-level `a_first_frac` proxy diagnostic when the audited subject proves access, so the old Hexeon opening-presence row is diagnostic fallback coverage rather than accepted-miss debt. `BrawlerDirectAttritionProbe.tscn` specifically proves the brawler role can pass through direct attrition evidence when frontline damage share, sustain EHP, prevention EHP, support healing/shielding, and pressure evidence are present, including burst peak-DPS/share pressure; direct-attrition diagnostics are now only saved for attrition-DPS brawlers, and Mortem now clears the live row through prevented-damage EHP. `MagePeriodicityKernelProbe.tscn` proves the mage role can pass through direct magic hit-component periodicity when top-window magic share and peak-over-mean evidence are present, and keeps low magic-share rows diagnostic when alternate peak-over-mean evidence proves mage identity. `MarksmanPositioningRoleProbe.tscn` proves the marksman role can pass through sustained DPS leadership plus backline/ranged presence while keeping team damage share and alternate side-backline rows diagnostic-only when subject ranged/time-on-target evidence proves positioning; Sari clears the direct sustained-DPS goal damage-share span in sustained-pressure context, and Teller's whole-fight share is diagnostic when direct sustained-window team share and sustained rate pass. `ApproachSemanticCatalogProbe.tscn` proves each Google-doc approach metric can pass on purpose-built evidence, rejects an empty/control payload, and emits an expected approach span. Some live roster tags still fail for content reasons. `GoalPrimaryCatalogProbe.tscn` proves every Google-doc primary goal branch can pass on purpose-built evidence and rejects an empty/control payload. `PeelTeamSaveProxyProbe.tscn` proves one derived team peel-save passes the shared proxy path for `approach_peel`, `role_support_identity`, and `support.peel_carry`, while `SoftPeelTeamSaveAcceptedMissProbe.tscn` proves real Axiom/Paisley soft-peel rows can pass from team-save evidence and keeps low team-save fallback rows diagnostic when direct ally-protection/support evidence already proves the aggregate. Totem's goal-level peel-save row remains live peel-carry scenario debt. `EhpRatioPathProbe.tscn` proves EHP ratio paths for `approach_sustain`, `approach_peel`, support-role team EHP proxy, and support-role subject EHP diagnostic; low EHP fallback rows are now diagnostic when effective HPS, direct ally-protection, or support-event evidence already proves the aggregate, so the old Berebell/Vykos/Paisley/Totem/Axiom EHP accepted-miss group is closed. `burst` has direct combat-pattern peak-window telemetry for peak 1s share, peak 1s DPS, overkill, and counterplay timing, with `BurstWindowKernelProbe.tscn` as the positive control; low peak-share rows now remain diagnostic when peak DPS already proves the approach, so the old Berebell/Hexeon/Mortem/Vykos burst peak-share accepted-miss group is closed. `reposition` has direct control-mobility telemetry for max step, post-cast displacement, total path distance, and reposition steps, with `RepositionMovementKernelProbe.tscn` as the positive control; low max-step/post-cast rows now remain diagnostic when total path distance satisfies the k-of-n approach, so the old Berebell/Bo/Mortem reposition accepted-miss groups are closed. `engage` has direct control-mobility telemetry for median/peak early displacement, first action, and first CC timing, with `EngageCcTimingKernelProbe.tscn` as the positive control; low median displacement or missing first-CC rows now remain diagnostic when standard or peak displacement plus first-action evidence satisfies the engage approach, and Grint's initiate-fight success-target span is diagnostic when distance plus first-action evidence proves the goal. `GrintEngageSuccessGoalProbe.tscn` proves Grint's initiate-fight goal can pass direct engage-success evidence and that the single-target aggregate pass shape does not remain accepted-miss debt, while `TankEngageScenarioPackSmoke.tscn` proves the all-unit smoke can request a dedicated front-lane engage context for those rows. `aoe` has direct grouped-hit telemetry for targets-hit median, max targets hit, multi-target groups, and AoE DPS, with `AoeTargetingKernelProbe.tscn` as the signal positive control, `AoeMultiTargetApproachProbe.tscn` proving low median becomes diagnostic when alternate max-target evidence satisfies the approach, and `AoeClusteredScenarioProbe.tscn` proving live Luna/Morrak/Nyxa/Paisley/Teller clustered contexts pass by direct max-target and/or AoE-DPS evidence. `zone` now prefers direct source-owned lingering-zone/hazard exposure, with `ZoneExposureKernelProbe.tscn` as the positive control; positioning occupancy remains only a fallback/diagnostic. Faeling is now tagged to `mage.area_denial_zone` and passes live `zone` plus direct area-denial goal checks through Eavesdropping spin exposure. `mage.sustained_dps` now requires damage share plus direct DoT, zone, ramp, or on-hit evidence, with `MageSustainedDpsGoalProbe.tscn` guarding against AoE-only false positives; no current mage primary identity owns that goal. Paisley and Volt were retagged away from `zone` after checking the Google Doc: Paisley's Bubbles is ally shielding plus split bubble damage, and Volt's Arc Lock is single-target damage plus stun, not persistent area denial. `redirect` now has direct absorb/redirect telemetry, enemy-focus/target-swap evidence, and explicit taunt/body-block/end-risk spans, with `RedirectThreatKernelProbe.tscn` as the positive control; current live Korath evidence proves the body-blocking redirect path from real diverted damage, and missing target-swap, taunt-command, and threat-swap submodes are diagnostic when body-block evidence already proves the aggregate. Goal-level disruption now has direct post-control enemy response telemetry for target swaps, forced reposition, formation spread, and follow-up kills, with `DisruptionKernelProbe.tscn` as the positive control. `execute` now prefers direct execute bonus damage/share telemetry when current rows provide it, with `ExecuteBonusKernelProbe.tscn` as the signal positive control, `HexeonExecuteLiveProbe.tscn` as the live low-HP-vs-above-threshold guard, and `ExecuteBonusApproachProbe.tscn` as the Hexeon/Morrak guard that keeps low bonus-share rows diagnostic when real bonus damage plus low-HP conversion proves execute while preserving zero-bonus failures. `ramp` now prefers direct stack/window state telemetry for both approach-level checks and ramp-bearing goals, with `RampStateKernelProbe.tscn` as the signal positive control, `RampApproachProbe.tscn` proving low approach stack rows stay diagnostic when ramp events plus peak/window duration prove the aggregate, and `MarksmanSustainedDpsGoalProbe.tscn` proving Sari's low goal ramp-stack row stays diagnostic under the same alternate ramp-state evidence. `dot` now prefers direct tick ownership and uptime/duration telemetry and exposes neutral-vs-anti-DoT scenario deltas when matching scenario labels are present, with `DotTickKernelProbe.tscn` as the positive control. `reset_mechanic` now prefers direct reset/recast telemetry plus post-first-reset impact and neutral-vs-counter scenario deltas when current rows provide them, with `ResetMechanicKernelProbe.tscn` as the positive control. `untargetable` now prefers direct targetability-window and threat-dodge telemetry when current rows provide it, with `UntargetableKernelProbe.tscn` as the positive control. `cooldown_pressure` now records committed ability responses targeted at a subject plus threat-draw diversity, key-threat share, and cooldown-trade efficiency, with `CooldownPressureKernelProbe.tscn` as the positive control. `counterplay_pressure` now records forced cleanses, cleanse-bait rate, tenacity tax, CC-immunity tax, and neutral-vs-cleanse/high-tenacity scenario deltas, with `CounterplayPressureKernelProbe.tscn` as the positive control.
- `PickBurstKillGoalProbe.tscn` proves lethal combat-pattern telemetry can feed the real Mara `mage.pick_burst` kill-count span, while the nonlethal aggregate pass keeps that span failing; the current all-unit smoke clears Mara/Volt pick-burst kill count through the wounded-target/full-mana burst proof.
- `PickBurstScenarioLabelSmoke.tscn` guards all-unit smoke scenario selection for `mage.pick_burst` identities. When label-cap pressure includes both counterplay and peel-style evidence, pick-burst rows keep `burst` before generic `peel`, non-pick-burst defensive rows preserve the existing `engage` and `peel` preference, and mage `burst` now resolves to the back-lane `pick_burst_window` pack. The current all-unit smoke clears Mara/Volt pick-burst kill count through the wounded-target/full-mana burst proof, so those rows are no longer accepted-miss debt.
- `TotemCleanseLiveProbe.tscn` now proves the real Cleanse cast removes a carry debuff, emits source-owned cleanse/CC-immunity telemetry, passes aggregate support/peel consumers through direct protection, and still emits no direct save/interrupt evidence. `TotemPeelCarryAcceptedMissProbe.tscn` proves real Totem `support.peel_carry` rows can pass all support/peel consumers with team-save, EHP, CC-prevention, interrupt, and cooldown evidence; it also preserves aggregate-pass controls where direct protection keeps the approach, role, and goal passing while goal team-save and interrupt spans remain below target, CC-prevention and cooldown-efficiency rows are diagnostic under direct CC-immunity/cooldown evidence, and approach/role team-save plus low-EHP fallback rows stay diagnostic. `SupportCarryThreatScenarioPackSmoke.tscn` guards all-unit scenario selection so Totem adds a `threat` context without changing Axiom or non-support CC-immunity rows; the full smoke still preserves Totem's two accepted lower-level misses, so the row is live save/interrupt debt rather than missing live ability proof, metric support, or carry-threat scenario-pack support.
- `SoftPeelTeamSaveAcceptedMissProbe.tscn` proves real Axiom/Paisley soft-peel rows can pass from team-save evidence; it also preserves aggregate-pass controls where Axiom's support role and Axiom/Paisley `approach_peel` keep passing through direct ally-protection evidence while low team-save fallback rows are diagnostic.
- `CounterplayAcceptedMissProbe.tscn` proves Kythera/Sari `debuff` and Brute/Volt `lockdown` rows can pass their response-pressure spans when cleanse/high-tenacity evidence is present; it also preserves aggregate-pass controls where direct debuff or lockdown evidence passes the approach while low cleanse-pressure, bait-rate, scenario-delta, and high-tenacity response rows remain diagnostic instead of accepted misses.
- `ExecuteBonusApproachProbe.tscn` proves real Hexeon/Morrak `execute` approach rows can pass on direct execute-bonus events, bonus share, low-HP kill conversion, and overkill guardrails; it also proves low bonus-share rows stay diagnostic when real bonus damage plus low-HP conversion proves execute, while zero-bonus aggregate controls still preserve a failed `subject_execute_bonus_damage_share` span.
- `RampApproachProbe.tscn` proves real Sari/Veyra `ramp` approach rows can pass on direct ramp-state events, full stack max, peak duration, and window duration; it also proves low `subject_ramp_stack_max` rows stay diagnostic when alternate ramp-state events plus peak/window duration prove the aggregate.
- `AoeMultiTargetApproachProbe.tscn` proves real Luna/Morrak/Nyxa/Paisley/Teller `aoe` approach rows can pass on clustered same-time hits with a passing target-median span; it also preserves aggregate-pass controls where the same identities pass while `subject_targets_hit_median` remains diagnostic. `AoeClusteredScenarioProbe.tscn` verifies the live clustered RoleMatrix contexts pass through direct max-target and/or AoE-DPS evidence with the all-hit median reported as diagnostic instead of a failed accepted span.
- `WomboComboGoalProbe.tscn` proves real Luna/Paisley `mage.wombo_combo_burst` goal rows can consume direct peak-share, multi-target, and CC-event evidence; it also preserves aggregate-pass controls where Luna passes without CC-sync and Paisley passes with a low peak-share span while the missing third evidence path is diagnostic rather than an accepted miss.
- `MarksmanSustainedDpsGoalProbe.tscn` proves real Sari/Teller `marksman.sustained_dps` goal rows can consume direct team damage share, range/time-on-target, survival, and Sari ramp-state evidence; it preserves aggregate-pass controls where Sari/Teller pass with low team damage share, and proves Sari's low ramp-stack span stays diagnostic when alternate ramp-state evidence proves the aggregate. `MarksmanSustainedWindowKernelProbe.tscn` proves combat-pattern telemetry emits `early_0_3s_*` and `sustained_3_10s_*` fields, and that direct sustained-window team share plus sustained rate can make whole-fight damage share diagnostic for burst-biased sustained-DPS audits. `MarksmanSustainedScenarioPackSmoke.tscn` guards all-unit scenario selection so Sari and Teller request a dedicated back-lane sustained-pressure context; the current all-unit smoke closes Sari's direct goal damage-share span and makes Teller's whole-fight damage-share row diagnostic through passing sustained-window evidence.
- `FrontlineBodyBlockGoalProbe.tscn` proves real redirect-kernel telemetry can feed Brute's `tank.frontline_absorb` body-block event and prevented-damage spans, while event-only, damage-only, and weak-prevention controls fail; low body-block rows are now diagnostic when alternate prevention plus frontline presence already proves the goal.
- `BruteFrontlineShareGoalProbe.tscn` proves Brute's `tank.frontline_absorb` damage-taken-share span can pass from direct incoming-share evidence; it also preserves an aggregate-pass control where prevention plus frontline presence pass the goal while low damage-share and absent body-block spans remain diagnostic.
- `KorathRedirectAcceptedMissProbe.tscn` proves Korath's `redirect` target-swap, explicit threat-swap, and taunt spans can pass from direct redirect evidence; it also preserves an aggregate-pass control where body-block evidence passes `approach_redirect` while those three missing submode spans remain diagnostic.
- `GrintEngageSuccessGoalProbe.tscn` proves Grint's `tank.initiate_fight` engage-success span can pass from direct success-target evidence; it also preserves an aggregate-pass control where engage distance plus first-action timing keep the goal passing while below-target `goal_initiate_fight_engage_success_targets` is emitted as diagnostic rather than an accepted miss. `TankEngageScenarioPackSmoke.tscn` guards all-unit scenario selection so Grint-style initiate rows add a front-lane `engage_window` context without dropping counterplay or burst coverage.
- `TeamFortificationBuffGoalProbe.tscn` proves source-owned `buff_applied` telemetry can feed Kythera's `tank.team_fortification` fortification span for both same-team self and ally targets, while an aggregate EHP/prevention pass still preserves the failed buff span when no fortification telemetry is present. `TeamFortificationScenarioPackSmoke.tscn` guards all-unit scenario selection so Kythera/Veyra keep a `fortify` context without dropping their existing defensive/counterplay labels; the current full smoke records Kythera `goal_team_fortification_buff_uptime_targets: 13.00` with `reason=source_owned_team_fortification_target`, so Kythera's former buff-uptime row is closed. `RoleMatrixProbe6v6Kythera.tscn` now opts into expected span checks so the focused live probe fails if the buff-uptime span stops passing, or if the aggregate EHP and damage-prevention spans stop passing.
- `SkirmishDiveBacklineGoalProbe.tscn` proves per-unit hit attribution and direct `BacklineAccessKernel` entries can feed Bo's `brawler.skirmish_dive` backline-contact span while an all-frontline/no-access control fails. `SkirmishDiveScenarioPackSmoke.tscn` guards RoleMatrix scenario selection so Bo's `counter` label uses a brawler `dive_window` pack; the current all-unit smoke now clears Bo's backline-contact row through `direct_backline_access`, so that gap is no longer accepted-miss debt.
- `amp` now exposes direct output-delta/events/beneficiary spans when `amp_output_applied` telemetry is present, with `AmpOutputKernelProbe.tscn` as the positive control. Latest live Axiom proves team amplification through source-attributed Pupil output lift, and latest live Totem proves the support peel-carry path through source-attributed ally shield, real debuff removal, CC-immunity, amp, and downstream output evidence; `TotemCleanseLiveProbe.tscn` guards the explicit debuffed-carry cleanse path.

Legacy
- See `../legacy/` for deprecated probes kept until parity is confirmed.
