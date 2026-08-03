# Gamble Battle Starter Playtest Audit - 2026-06-24

Status: complete for the original 21-unit manual starter surface, with follow-up revalidation against the current branch. The current cost-tier branch exposes 12 level-1 starter-selectable units; the 9 cost-2 premium units and cost-3 Hexeon are no longer starter-visible at level 1. This document records real MCP-launched/manual UI play, external screenshot evidence captured from the MCP-launched debug window, supporting starter runner data, and later MCP validation after fixes landed. No gameplay code changes were made during the original manual audit.

## Evidence
- Manual MCP/Godot-AI UI screenshots: `outputs/audit_playtest/manual_runs/`
- External no-import screenshots after Godot editor import churn became suspect: `C:\Users\Flipm\Documents\gamble-battle-playtest-audit\manual_runs\`
- Current live editor/debug screenshots after the cost-tier recheck: `C:\Users\Flipm\Documents\gamble-battle-playtest-audit\current_runs\`
- Earlier manual screenshots and runner output: `outputs/audit_playtest/`
- Current live editor framebuffer captures: `outputs/visual_iter/loss_screen_pass/loss_overlay_modal_fixed.png`, `outputs/visual_iter/exit_menu_pass/01_unit_select_system_menu.png`, `outputs/visual_iter/exit_menu_pass/02_combat_system_menu.png`
- Real-run populated loss overlay capture: `outputs/audit_playtest/real_loss_overlay_capture/axiom_real_loss_overlay.png` and `outputs/audit_playtest/real_loss_overlay_capture/axiom_real_loss_overlay.json`
- Current run-total loss modal screenshot and notes: `outputs/audit_playtest/current_loss_modal_visual/current_loss_modal_window_run_totals.png`, `outputs/audit_playtest/current_loss_modal_visual/current_loss_modal_summary.json`, and `outputs/audit_playtest/current_loss_modal_visual/notes.md`
- Supporting all-starter data: `outputs/audit_playtest/starter_audit_results.json`
- Supporting all-starter Main-flow replay data: `outputs/audit_playtest/all_starter_main_flow_audit/all_starter_main_flow_results.json`
- Supporting current shop/premium data: `outputs/audit_playtest/current_shop_audit_results.json`
- Supporting rapid rendered-shop input data: `outputs/audit_playtest/rapid_shop_input_audit/rapid_shop_input_results.json`
- Fresh live Main-flow screenshots and notes: `outputs/audit_playtest/live_flow_recheck_2026_06_25/`
- Fresh live cost-1 post-buy/deploy screenshots: `outputs/audit_playtest/live_deploy_recheck_2026_06_25/`
- Fresh live cost-2 Buy XP/deploy attempt screenshots and notes: `outputs/audit_playtest/live_cost2_recheck_2026_06_25/`
- Live-window fallback diagnostics: `outputs/audit_playtest/window_capture_2026_06_25/`
- Fresh shop spacing and first-fight placeholder screenshots: `outputs/audit_playtest/shop_spacing_recheck_2026_06_25/`
- Current opening-fight copy guard and live-renderer screenshots: `tests/visual/OpeningFightVisualSmoke.tscn` and `outputs/visual_iter/opening_fight_copy_pass/`
- Current real-window deploy drag release recheck: `outputs/audit_playtest/current_deploy_drag_recheck/`
- Current system menu lighter-backdrop screenshot and notes: `outputs/audit_playtest/current_system_menu_visual/unit_select_system_menu_lighter_backdrop.png`, `outputs/audit_playtest/current_system_menu_visual/current_system_menu_summary.json`, and `outputs/audit_playtest/current_system_menu_visual/notes.md`
- Debug audit QA exports: `user://audit_exports/audit_state_*.json`; `F8` opens the debug-only in-game Audit QA panel for state export, screenshot attempt, timer hold, restart, and speed controls.
- Live Audit QA panel screenshot proof: `outputs/audit_playtest/audit_panel_live_capture_2026_06_25/01_panel_open.png`, `outputs/audit_playtest/audit_panel_live_capture_2026_06_25/02_after_screenshot_click.png`, and `user://audit_exports/audit_shot_1782371342_158480.png`
- Current Godot-AI game-helper capture proof: `outputs/audit_playtest/godot_ai_capture_recheck_2026_06_26/title_game_helper_capture.png`
- Current Godot-AI live Main-flow screenshots: `outputs/audit_playtest/live_main_flow_capture_2026_06_26/`
- Current natural-speed single-starter Main-flow screenshots: `outputs/audit_playtest/natural_main_flow_2026_06_26/`
- Current natural-speed Repo Main-flow screenshots: `outputs/audit_playtest/natural_repo_flow_2026_06_26/`
- Current natural-speed Axiom Main-flow screenshots: `outputs/audit_playtest/natural_axiom_flow_2026_06_26/`
- Current item, trait, and bar UI harness and live-renderer screenshots: `tests/visual/BarItemsTraitsCapture.tscn` and `outputs/visual_iter/bar_items_traits_pass/`
- Current completed-item data/effect registry guards: `tests/rga_testing/validation/CompletedItemEffectRegistrySmoke.tscn` and `tests/rga_testing/validation/CompletedItemRuntimeEffectsProbe.tscn`
- Current standalone CombatView start playtest: `tests/visual/CombatViewThemePlaytest.tscn`
- Current post-shop betting economy guard and live-renderer screenshots: `tests/visual/BettingEconomySmoke.tscn` and `outputs/visual_iter/betting_economy_pass/`
- Current post-win planning beat guard and live-renderer screenshots: `tests/visual/PostCombatPlanningBeatSmoke.tscn` and `outputs/visual_iter/post_combat_planning_beat_pass/`
- Current natural Buy XP guard and live-renderer screenshots: `tests/visual/NaturalBuyXPVisualSmoke.tscn` and `outputs/visual_iter/natural_buy_xp_pass/`
- Current audit-assisted premium deploy guard after level-up: `tests/visual/PremiumDeployAfterLevelSmoke.tscn`
- Current rapid shop pressure guards and live-renderer screenshots: `tests/visual/RapidShopPressureSmoke.tscn`, `tests/visual/ProductionRapidShopPressureSmoke.tscn`, `tests/visual/RapidShopVisualPressureSmoke.tscn`, and `outputs/visual_iter/rapid_shop_pressure_pass/`
- Current audit-assisted mid-run planned-line guard: `tests/visual/MidRunProgressionSmoke.tscn`
- Current seeded random later-shop progression guard: `tests/visual/RandomLaterShopProgressionSmoke.tscn`
- Duplicate scoreboard disambiguation validation and live-renderer screenshot: `tests/visual/ScoreboardDuplicateDisambiguationSmoke.tscn` and `outputs/visual_iter/duplicate_scoreboard_pass/01_duplicate_scoreboard_copy_labels.png`
- Current RoleMatrix detail data: `user://identity_reports/*.json`, `user://rga_smoke/<unit>/...`, and `C:\Users\Flipm\AppData\Roaming\Godot\app_userdata\Gamble Battle\logs\godot.log`
- Current RoleMatrix accepted-miss working export: `outputs/audit_playtest/rga_accepted_misses_current/`; dated reference snapshots include `outputs/audit_playtest/rga_accepted_misses_2026_06_25/`, `outputs/audit_playtest/rga_accepted_misses_2026_06_26_head_refresh/`, and `outputs/audit_playtest/rga_accepted_misses_2026_06_26_current_sweep/`
- Current Totem goal-alignment decision guard: `tests/rga_testing/validation/TotemGoalAlignmentProbe.tscn`
- Current RGA taxonomy/catalog guards: `tests/rga_testing/validation/ApproachCatalogCoverage.tscn`, `RoleSemanticCatalogProbe.tscn`, `GoalPrimaryCatalogProbe.tscn`, `ApproachSemanticCatalogProbe.tscn`, and `UnitIdentityMapDocSmoke.tscn`
- Current first-shop helper choice matrix: `docs/starter_first_shop_choice_matrix_2026-06-26.md`
- Current starter-aware first-shop offer sampling guard: `tests/visual/FirstShopOfferQualitySamplingSmoke.tscn`
- Current Axiom retry helper guard: `tests/visual/AxiomRetryChoiceQualitySmoke.tscn`

## Current Revalidation After Follow-Up Fixes

Current branch snapshot: refreshed on 2026-06-26 local main after the Unit Select, deploy-assist/watchdog, shop-spacing, audit-validation, strict-input, shop/economy hardening, all-starter Main-flow, Totem residual, and rapid-shop pressure follow-ups; latest rapid-shop visual-pressure checkpoint was run at local HEAD `09b9045`, and latest RGA residual checkpoint was run at local HEAD `f625879`.

MCP validation snapshot, originally run on 2026-06-24 and refreshed through 2026-06-26:
- Current all-starter Main-flow checkpoint refresh on 2026-06-26 at local HEAD `9f066de`: `AllStarterMainFlowSmoke: PASS starters=12 first_shop=12 retry=0 deployed=12 second_resolved=12`, `NaturalAllStarterMainFlowSmoke: PASS starters=12 first_shop=12 retry=0 deployed=12 second_resolved=12`, `NaturalInputMainFlowSmoke: PASS starters=12 first_shop=12 retry=0 deployed=12 second_resolved=12`, and `AxiomRetryChoiceQualitySmoke: PASS trials=5 advanced=5`; every MCP debug read returned `errors: []`. This keeps both accelerated Main-scene coverage, production-clock all-starter coverage, strict no-fallback input coverage, and the forced Axiom retry helper matrix current after the shop/economy smoke hardening commit.
- Current shop/economy checkpoint refresh on 2026-06-26 after hardening the natural Buy XP guard: `CostBalanceSmoke: PASS units=22 tiers=1:12 2:9 3:1`, `ShopPurchaseFeedbackSmoke: OK`, `BuyXPTransactionalFeedbackSmoke: OK`, `NaturalBuyXPVisualSmoke: OK attempts=1 stage=2 gold_before=5 gold_after=1`, `PremiumDeployAfterLevelSmoke: OK premium=kythera buy_xp_audit_gold=2 premium_audit_gold=11`, `RapidShopPressureSmoke: OK purchases=5 deployed_board=6`, `ProductionRapidShopPressureSmoke: OK purchases=5 deployed_board=6`, `FirstShopChoiceQualitySmoke: PASS starters=7 trials=35 advanced=26`, `FirstShopOfferQualitySamplingSmoke: PASS samples=240`, and `AxiomRetryEconomySmoke: OK`; every MCP debug read returned `errors: []`. `NaturalBuyXPVisualSmoke` now uses a test-only guaranteed +2 gold creep reward pool wired through `CreepRewardsRuntime`, avoiding the stale flaky random-retry assumption while still earning the Buy XP gold from the reward system rather than by directly setting `Economy.gold`.
- Current rapid-shop visual-pressure checkpoint on 2026-06-26 at local HEAD `09b9045`: `RapidShopVisualPressureSmoke: OK purchases=5 deployed_board=6`, `ProductionRapidShopPressureSmoke: OK purchases=5 deployed_board=6`, and `RapidShopPressureSmoke: OK purchases=5 deployed_board=6`; every MCP debug read returned `errors: []`. The new smoke extends the production-clock rendered-card click path with post-burst and post-deploy capture checkpoints. Legacy MCP skipped PNGs under the dummy framebuffer, while the live Godot-AI/OpenGL run saved `outputs/visual_iter/rapid_shop_pressure_pass/01_after_rapid_purchases.png` and `02_after_rapid_deploy.png`, showing five sold/on-bench placeholders, visible deploy guidance, the bench clearing, six board units, and readable scoreboard rows.
- Current mid-run progression checkpoint on 2026-06-26: `MidRunProgressionSmoke: OK battles=4 stage=5 audit_gold_added=10 board=["bonko","morrak","grint","sari","brute","berebell","bo"]`; the MCP debug read returned `errors: []`. The smoke drives the real Main scene from Bonko selection through the forced opener, forces deterministic later cost-1 offer rows, buys each planned unit through rendered shop cards, deploys every bench unit through the same drag path as players, and proves three post-opener fights advance Stage 2 -> 3 -> 4 -> 5. It is audit-assisted planned-line evidence, not random later-shop balance coverage.
- Current seeded random later-shop checkpoint on 2026-06-26: `RandomLaterShopProgressionSmoke: OK samples=12 reached=12 starters=["axiom","berebell","bo","bonko","brute","cashmere","grint","korath","morrak","mortem","repo","sari"] target_stage=5 audit_gold_added=120`; the MCP debug read returned `errors: []`. The smoke seeds the live Shop RNG with one deterministic seed per current level-1 starter, keeps the normal protected first-shop opener, leaves later shop rows natural, buys up to two units per shop with a simple board-width/frontline-first heuristic, deploys through the shared drag path, and proves all 12 sampled natural-offer lines reach Stage 5. It is still audit-gold assisted and one-seed-per-starter coverage, so it narrows all-starter random later-offer risk without proving natural economy, deeper seed coverage, or physical manual full-run feel.
- Current RGA residual checkpoint refresh on 2026-06-26 at local HEAD `f625879`: `RoleMatrixSmoke: PASS (22 units)`, `tests/rga_testing/tools/Export-AcceptedMisses.ps1` wrote `reports=22 spans=2 ramp_spans=0 non_ramp_goal_ramp=0 out=outputs/audit_playtest/rga_accepted_misses_current`, `AcceptedMissGuardCoverageSmoke: PASS gap_kinds=2 accepted_spans=2 mapped_gap_kinds=2`, `TotemPeelCarryAcceptedMissProbe: PASS full_pass=true low_pass=true weak_pass=false low_team_save_diagnostic=true low_ehp_diagnostic=true low_cc_prevented_diagnostic=true low_cooldown_efficiency_diagnostic=true low_interrupt_failed=true`, and `TotemGoalAlignmentProbe: PASS current_pass=true current_save_fail=true current_interrupt_fail=true current_protection_pass=true current_cc_immunity_pass=true alternate_pass=true alternate_buff_pass=true alternate_magnitude_pass=true alternate_output_pass=true alternate_has_peel_rows=false`; every MCP debug read returned `errors: []`. The regenerated stable export still contains only Totem `support.peel_carry` goal rows for `peel_carry_goal_save_proxy_absent` and `peel_interrupt_context_absent`, so the residual remains product/scenario/goal-contract debt rather than missing guard coverage.
- Current broad audit sweep at local HEAD `65577f5`: `RoleMatrixSmoke: PASS (22 units)`, accepted-miss export `reports=22 spans=2 ramp_spans=0 non_ramp_goal_ramp=0` to `outputs/audit_playtest/rga_accepted_misses_2026_06_26_current_sweep/`, `AcceptedMissGuardCoverageSmoke: PASS gap_kinds=2 accepted_spans=2 mapped_gap_kinds=2`, `NaturalInputMainFlowSmoke: PASS starters=12 first_shop=12 retry=0 deployed=12 second_resolved=12`, `ProductionRapidShopPressureSmoke: OK purchases=5 deployed_board=6`, `NaturalBuyXPVisualSmoke: OK attempts=5 stage=2 gold_before=6 gold_after=2`, and `ActualRunLoopSmoke: OK` after five loss/reset cycles plus the shop cycle; every MCP debug read returned `errors: []`.
- Stable accepted-miss working-export refresh on 2026-06-26: `RoleMatrixSmoke: PASS (22 units)`, `tests/rga_testing/tools/Export-AcceptedMisses.ps1` wrote `reports=22 spans=2 ramp_spans=0 non_ramp_goal_ramp=0 out=outputs/audit_playtest/rga_accepted_misses_current`, and `AcceptedMissGuardCoverageSmoke: PASS gap_kinds=2 accepted_spans=2 mapped_gap_kinds=2`; every MCP debug read returned `errors: []`.
- `tests/visual/ActualRunLoopSmoke.tscn`: `ActualRunLoopSmoke: OK`; rerun on 2026-06-26 with `errors: []`, including first-deploy bench highlight, post-deploy highlight clearing assertions, repeated loss/New Game reset cycles, shop cycle, and second-fight resolution.
- `tests/visual/FirstShopChoiceQualitySmoke.tscn`: `FirstShopChoiceQualitySmoke: PASS starters=7 trials=35 advanced=26`; rerun on 2026-06-26 with `errors: []`, validating Bo, Bonko, Cashmere, Korath, Mortem, Repo, and Sari each retain at least one deterministic first-shop helper path that advances beyond Stage 2 while still recording bad pure-support or redundant-defense choices for the matrix. The advanced count is run telemetry, not the acceptance threshold.
- `tests/visual/FirstShopOfferQualitySamplingSmoke.tscn`: `FirstShopOfferQualitySamplingSmoke: PASS samples=240` with Bo, Bonko, Cashmere, Korath, Mortem, Repo, and Sari all at `first_good=1.000`, `blocked_seen=0`, and `axiom_seen=0`; rerun on 2026-06-26 with `errors: []`, sampling the starter-aware opening-shop roller guard to prove each guarded starter sees a known advancing helper in slot 0, no configured known-bad helper appears in the opening shop, and every expected matrix-proven trap helper, including Bo/Brute, remains in the blocked-helper config.
- `tests/visual/AllStarterMainFlowSmoke.tscn`: `AllStarterMainFlowSmoke: PASS starters=12 first_shop=12 retry=0 deployed=12 second_resolved=12`; rerun on 2026-06-26 with `errors: []`, validating every current level-1 starter through the real Main-scene forced opener, first-shop buy/deploy, and second-fight loop with no opener retry outliers.
- `tests/visual/NaturalAllStarterMainFlowSmoke.tscn`: `NaturalAllStarterMainFlowSmoke: PASS starters=12 first_shop=12 retry=0 deployed=12 second_resolved=12`; added and run on 2026-06-26 with `errors: []`, validating the same all-12 Main-scene loop at production `Engine.time_scale = 1.0` without the accelerated runner's planning-timer hold. Fresh MCP rerun at local HEAD `6c7b761` also passed with the same 12-starter counts and `errors: []`. This is automated UI-path coverage, not physical manual replay.
- `tests/visual/NaturalInputMainFlowSmoke.tscn`: `NaturalInputMainFlowSmoke: PASS starters=12 first_shop=12 retry=0 deployed=12 second_resolved=12`; expanded and rerun on 2026-06-26 with `errors: []`, validating every current level-1 starter through production-clock title Start, Unit Select, starter selection, Start Game, first shop card click, strict no-fallback bench-to-board helper drag, and second-fight resolution. This is tracked synthetic input proof across the current starter catalog, not a physical manual replay.
- `outputs/audit_playtest/AllStarterLiveCapture.tscn`: `AllStarterMainFlowAudit: OK starters=12`; clean Godot-AI live-editor rerun on 2026-06-26 with `errors: []` after the opener tuning and expanded starter-aware first-shop guard. The refreshed default replay reached first shop for all 12 starters, deployed all 12 helpers, resolved all 12 second fights, recorded no starter failures, and saved 72/72 PNG captures under `outputs/audit_playtest/all_starter_live_capture_2026_06_26/` with `display_server=Windows` and `rendering_driver=opengl3`.
- Natural-speed Sari live Main-flow pass: saved `01_title.png` through `05_starter_deployed.png` under `outputs/audit_playtest/natural_main_flow_2026_06_26/`. The pass used runtime mouse input for title Start, Unit Select, Sari selection, Start Game, bench selection, and board placement. It confirmed the real UI path from title to unit select, enabled Start Game after Sari selection, first planning state with `Stage 1 - Round 1/6`, `Gold: 2`, and disabled Attack while benched, then Sari deployed and the opener entered `Resolving 4s...` with `Bet: 1 (locked)`. The Godot-AI session dropped during the follow-up state read, but `get_debug_output()` reported `errors: []`; treat this as natural single-starter title-to-opener evidence, not all-starter natural replay coverage.
- Natural-speed Repo live Main-flow pass: saved `01_title.png`, `02_unit_select.png`, `03_repo_selected.png`, and `07_first_shop.png` through `10_after_second_battle.png` under `outputs/audit_playtest/natural_repo_flow_2026_06_26/`. The pass used runtime mouse input for title Start, Unit Select, Repo selection, Start Game, first-shop Sari purchase, and the follow-up Start Battle click. It proved Repo now naturally reaches the first post-opener shop at `Stage 1 - Round 2/6` with 3 gold and Sari as the first guarded offer; clicking Sari renders `SOLD` / `On bench` and drops gold to 2. Starting the second fight without deploying Sari returned to Stage 1 Round 2 planning with gold 1 and `Start Battle`, consistent with the controller's same-stage defeat retry path. The Godot-AI state export timed out after this state and the session list dropped to zero; legacy `get_debug_output()` reported `errors: []`. Treat this as natural title-to-shop/purchase/retry evidence for the weakest starter, not a clean natural helper-deploy proof.
- Natural-speed Axiom live Main-flow pass: saved `01_title.png` through `09_retry_helper_deployed.png` under `outputs/audit_playtest/natural_axiom_flow_2026_06_26/`. The pass used runtime mouse input for title Start, Unit Select, Axiom selection, Start Game, starter deploy, forced opener, Round 2 shop purchase, and helper deploy. It proved current production Axiom no longer needs the opener retry branch: after deploying Axiom, the forced opener reached `Stage 1 - Round 2/6` with 2 gold, `Start Battle`, and a five-card shop containing Axiom plus four 1g Brawler/frontline offers (`Bo`, `Berebell`, `Bonko`, `Mortem`). Buying Bo dropped gold to 1, placed the helper on bench, and dragging the helper to board saved a visible deployed-board frame. The follow-up Start Battle input timed out the Godot-AI bridge, so the natural screenshot set stops at helper deployment; the deterministic Axiom retry smokes below remain the authoritative forced-fallback retry proof.
- `tests/visual/AxiomRetryChoiceQualitySmoke.tscn`: `AxiomRetryChoiceQualitySmoke: PASS trials=5 advanced=5`; rerun on 2026-06-26 with `errors: []`, forcing Axiom's configured retry helpers through a test-forced hard opener, real Main-scene buy/deploy/retry-fight path, and proving Bonko, Grint, Sari, Morrak, and Berebell all advance beyond Stage 1.
- `tests/rga_testing/ci/CostBalanceSmoke.tscn`: `CostBalanceSmoke: PASS units=22 tiers=1:12 2:9 3:1`; rerun on 2026-06-26 with `errors: []`.
- `tests/rga_testing/ci/RoleMatrixSmoke.tscn`: `RoleMatrixSmoke: PASS (22 units)`; rerun on 2026-06-26 with `errors: []`, including a post-production-clock all-starter refresh from local main base commit `82ec91a`.
- `tests/rga_testing/validation/AcceptedMissGuardCoverageSmoke.tscn`: `AcceptedMissGuardCoverageSmoke: PASS`; rerun on 2026-06-26 after the Kythera fortification closure and again after the production-clock all-starter checkpoint with `gap_kinds=2`, `accepted_spans=2`, `mapped_gap_kinds=2`, exact Totem peel-save/interrupt detail-row checks, and `errors: []`. Earlier cleanup passes reduced the regenerated manifest through 9, 8, 7, 6, 5, 4, and 3 gap kinds/spans after Totem cooldown-efficiency, Mortem direct-attrition EHP, Bo direct backline-access, Grint initiate-success, Totem CC-prevention, marksman sustained-window, and Hexeon subject-access evidence respectively.
- `tests/rga_testing/validation/TotemGoalAlignmentProbe.tscn`: `TotemGoalAlignmentProbe: PASS`; added and run on 2026-06-26 with `errors: []`, proving the same real Totem 6v6 `peel`/`threat` rows preserve the current `support.peel_carry` aggregate pass plus save/interrupt residual shape, while a temporary `support.team_amplification` primary-goal override passes buff uptime, team amp magnitude, and amp output without emitting peel-carry rows. This is product/design decision evidence, not an identity change.
- RGA taxonomy/catalog guard rerun on 2026-06-26: `ApproachCatalogCoverage: PASS approaches=22 goals=22 metrics=32`, `RoleSemanticCatalogProbe: PASS roles=6`, `GoalPrimaryCatalogProbe: PASS goals=22`, `ApproachSemanticCatalogProbe: PASS approaches=22`, and `UnitIdentityMapDocSmoke: OK`, all with `errors: []`. These prove the role/goal/approach metric catalog, goal resources, semantic positive/negative/span contracts, and `docs/unit_identity_map.md` stay aligned with the live playable catalog.
- `tests/rga_testing/validation/UnitStatAudit.tscn`: `UnitStatAudit: OK`; rerun on 2026-06-26 with `errors: []`.
- `tests/visual/CombatWatchdogSmoke.tscn`: `CombatWatchdogSmoke: OK`; rerun on 2026-06-26 with `errors: []`.
- `tests/visual/CombatResolvingFeedbackSmoke.tscn`: `CombatResolvingFeedbackSmoke: OK`; rerun on 2026-06-26 with `errors: []` and validates the immediate resolving label, elapsed resolving text, long-wait warning text, and watchdog fallback text.
- `tests/visual/CombatResolvingFeedbackVisualSmoke.tscn`: `CombatResolvingFeedbackVisualSmoke: OK captures=0` under the legacy MCP dummy renderer with `errors: []`; a live Godot-AI/OpenGL run saved `01_immediate_resolving.png`, `02_elapsed_resolving.png`, `03_still_resolving.png`, and `04_watchdog_fallback.png` under `outputs/visual_iter/combat_resolving_feedback_pass/`, visually confirming the disabled Start Battle button copy for immediate, elapsed, long-wait, and watchdog fallback states.
- `tests/visual/CombatViewThemePlaytest.tscn`: `CombatViewThemePlaytest: OK elapsed=2.00`; rerun on 2026-06-26 with `errors: []`, validating that the standalone `CombatView` scene can receive a player team, continue into combat, start the combat engine, and keep battle active after two seconds.
- `tests/visual/BettingEconomySmoke.tscn`: `BettingEconomySmoke: OK`; rerun on 2026-06-26 with `errors: []`, validating the direct Economy wager contract (`set_bet`, escrow, combat credit, win payout, loss payout, all-in preferred-bet carryover, ignored in-combat bet changes) plus the real Main-scene post-opener betting UI: slider visible/editable after the first shop opens, max-bet updates `Economy.current_bet` and `BetValue`, Start Battle escrows and locks the selected bet, hides/disables the slider, shows `Bet: N (locked)`, and ignores later bet changes during combat. A live Godot-AI/OpenGL run saved `01_post_shop_bet_slider_visible.png`, `02_post_shop_max_bet_selected.png`, and `03_combat_bet_locked.png` under `outputs/visual_iter/betting_economy_pass/`; the legacy MCP debug rerun still skipped fresh PNGs under dummy rendering but passed with `errors: []`.
- `tests/visual/ScoreboardDuplicateDisambiguationSmoke.tscn`: `ScoreboardDuplicateDisambiguationSmoke: OK`; rerun on 2026-06-26 with `errors: []`, validating duplicate-copy suffixes in the scoreboard model and rendered row labels. A live Godot-AI/OpenGL run saved `outputs/visual_iter/duplicate_scoreboard_pass/01_duplicate_scoreboard_copy_labels.png` with visible `Berebell #1` and `Berebell #2` rows; the legacy MCP debug rerun skipped fresh PNG capture under dummy rendering but passed cleanly.
- `tests/visual/PostCombatPlanningBeatSmoke.tscn`: `PostCombatPlanningBeatSmoke: OK`; rerun on 2026-06-26 with `errors: []`, validating that a post-win intermission beat appears before planning returns, then restores `Start Battle`, a full shop, and at least 55 seconds of planning time. A live Godot-AI/OpenGL run saved `01_post_win_intermission_bar.png` and `02_post_win_planning_restored.png` under `outputs/visual_iter/post_combat_planning_beat_pass/`; the legacy MCP debug rerun skipped fresh PNG capture under dummy rendering but passed cleanly.
- `tests/visual/AxiomRetryEconomySmoke.tscn`: `AxiomRetryEconomySmoke: OK`; rerun on 2026-06-26 with `errors: []`, validating the fallback retry economy under a test-forced hard opener, configured slot-0 retry helper, helper purchase/deploy guidance, bench highlight clearing, and retry-fight progression back into a full Stage 2 planning shop.
- `tests/visual/DragGlobalReleaseSmoke.tscn`: `DragGlobalReleaseSmoke: OK` with `errors: []`; validates that a drag started on one control ends and emits a drop after global mouse release over a different tile.
- `tests/visual/UnitSelectSmoke.tscn`: `UnitSelectSmoke: OK`; rerun on 2026-06-26 with `errors: []`.
- `tests/visual/UnitSelectPreviewVisualSmoke.tscn`: `UnitSelectPreviewVisualSmoke: OK captures=0` under the legacy MCP dummy renderer with `errors: []`; a live Godot-AI/OpenGL run saved `01_neutral_preview.png`, `02_hover_preview.png`, and `03_after_scroll_clear.png` under `outputs/visual_iter/unit_select_preview_pass/`. The screenshots show the current 12-starter grid starts with `No champion chosen` and no preview art, hover inspection shows Axiom identity/art without enabling `Start Game`, and the clear path returns to neutral preview. The current level-1 roster fits without an actual scrollbar, so this is visual proof for neutral/hover/clear states rather than a long-roster scroll screenshot.
- `tests/visual/UIThemeSmoke.tscn`: `UIThemeSmoke: OK`; rerun on 2026-06-26 with `errors: []`, including shop-card gutter, command-strip spacing, first-fight placeholder prominence, and locked-placeholder click feedback assertions.
- `tests/visual/OpeningFightVisualSmoke.tscn`: `OpeningFightVisualSmoke: OK`; added and run on 2026-06-26 with `errors: []`, validating the current fixed-opener copy (`Start Opening Fight`, `OPENING FIGHT`, `Win this opener to unlock the shop`, `Opening fight is fixed. Win it to unlock the shop.`), disabled opener shop controls, hidden/locked opener bet slider, fixed `Opening bet: 1` copy, placeholder tooltip, and clicked-placeholder feedback. A live Godot-AI/OpenGL run saved `01_opening_fight_locked_shop.png` and `02_opening_fight_feedback.png` under `outputs/visual_iter/opening_fight_copy_pass/`; the legacy MCP debug run passed while skipping PNG capture under the dummy framebuffer.
- `tests/visual/ShopPurchaseFeedbackSmoke.tscn`: `ShopPurchaseFeedbackSmoke: OK` with `errors: []`; validates a real `ShopPresenter` card purchase spends gold, places the unit on bench, shows deploy guidance, and renders the purchased slot as `SOLD` / `On bench` with a bench tooltip.
- `tests/visual/BuyXPTransactionalFeedbackSmoke.tscn`: `BuyXPTransactionalFeedbackSmoke: OK`; rerun on 2026-06-26 with `errors: []`, validating reserve-floor denial feedback and immediate gold/level/XP repaint after a valid Buy XP purchase.
- `tests/visual/PremiumDeployAfterLevelSmoke.tscn`: `PremiumDeployAfterLevelSmoke: OK premium=kythera buy_xp_audit_gold=2 premium_audit_gold=11`; rerun on 2026-06-26 with `errors: []`, validating the real Main-scene path from Bonko forced opener to first shop, audit-assisted visible Buy XP to level 2, a deterministic full level-2 shop row with cost-2 Kythera, cost-2 card purchase to bench, deploy prompt, and bench-to-board premium deployment.
- `tests/visual/RapidShopPressureSmoke.tscn`: `RapidShopPressureSmoke: OK purchases=5 deployed_board=6`; rerun on 2026-06-26 with `errors: []` and validates a Bonko Main-flow opener into a same-frame burst across five rendered shop cards, five sold/on-bench placeholders, no shop errors, five bench-to-board deploys through global mouse-release input, and a resolved follow-up fight.
- `tests/visual/ProductionRapidShopPressureSmoke.tscn`: `ProductionRapidShopPressureSmoke: OK purchases=5 deployed_board=6`; added and run on 2026-06-26 with `errors: []`, reusing the same real Main-scene rapid-shop pressure path at `Engine.time_scale = 1.0` without holding the opener or shop planning timers. It buys the five shop cards through rendered-card viewport mouse clicks, while shop-gold/deterministic shop setup remains audit-assisted; timing, hit routing, and the follow-up fight are production-clock.
- `tests/visual/DevStarterInventorySmoke.tscn`: `DevStarterInventorySmoke: OK`; validates normal run inventory starts clean and starter item seeding only happens when `Items.DEV_STARTER_INVENTORY_ENABLED` is explicitly enabled.
- `tests/visual/BarItemsTraitsCapture.tscn`: `BarItemsTraitsCapture: OK planning_visible_bars=0 combat_visible_bars=6 filled_item_cards=8 visible_trait_icons=3`; rerun on 2026-06-26 with `errors: []`, validating forced filled item slots, rendered trait icons, item and trait hover tooltip show/clear paths, hidden planning-grid ProgressBars, and visible combat actor ProgressBars. A live Godot-AI/OpenGL run saved `01_planning_grid_bars_hidden_items_traits.png`, `02_trait_tooltip_and_item_cards.png`, and `03_combat_bars_visible.png` under `outputs/visual_iter/bar_items_traits_pass/` with `tooltip_edge_skips=0`; the legacy MCP debug rerun still skipped fresh PNGs under the dummy framebuffer and reported `tooltip_edge_skips=2` only because its dummy viewport was smaller than the tooltips.
- `tests/rga_testing/validation/CompletedItemEffectRegistrySmoke.tscn`: `CompletedItemEffectRegistrySmoke: PASS`; latest item-effect rerun validates 36 completed items, 36 declared runtime effect IDs, 36 registered handlers, and no unsupported completed-item stat keys. `CompletedItemRuntimeEffectsProbe.tscn` also dispatches combat events across all completed items and requires each item effect to change runtime combat state.
- `tests/rga_testing/validation/VeyraHardenCanonicalStackProbe.tscn`: `VeyraHardenCanonicalStackProbe: PASS`; validates that the scheduled Harden end effect consumes canonical `TraitKeys.AEGIS` stacks and applies Veyra's permanent max-HP stack without relying on legacy `aegis_stacks`.
- `tests/rga_testing/validation/KytheraSiphonCanonicalStackProbe.tscn`: `KytheraSiphonCanonicalStackProbe: PASS`; validates that the real Siphon cast consumes canonical `TraitKeys.AEGIS` stacks, reaches 3 MR drain per tick from 6 canonical stacks, executes scheduled tick/end events, drains target MR, and applies Kythera's permanent MR stack without relying on legacy `aegis_stacks`.
- `tests/rga_testing/validation/CashmereLedgerCanonicalStackProbe.tscn`: `CashmereLedgerCanonicalStackProbe: PASS`; validates that the real Arcane Ledger cast consumes canonical `TraitKeys.ARCANIST` stacks for damage scaling while legacy `arcanist_stacks` remains 0, avoiding economy autoload side effects by keeping the target alive.
- `tests/rga_testing/validation/PaisleyBubblesCanonicalStackProbe.tscn`: `PaisleyBubblesCanonicalStackProbe: PASS`; validates that the real Bubbles cast consumes canonical `TraitKeys.KALEIDOSCOPE` and `TraitKeys.ARCANIST` stacks for both low-HP ally shielding and split magic damage while legacy stack keys remain 0.
- `tests/rga_testing/validation/MorrakReapingLineCanonicalStackProbe.tscn`: `MorrakReapingLineCanonicalStackProbe: PASS`; validates that the real Reaping Line cast consumes canonical `TraitKeys.STRIKER` and `TraitKeys.EXECUTIONER` stacks for damage scaling and the low-HP execute threshold while legacy stack keys remain 0.
- `tests/rga_testing/validation/HexeonGuillotineCanonicalStackProbe.tscn`: `HexeonGuillotineCanonicalStackProbe: PASS`; validates that the real Prismatic Guillotine cast consumes canonical `TraitKeys.KALEIDOSCOPE` stacks for damage scaling and canonical `TraitKeys.EXECUTIONER` stacks for the low-HP execute threshold while legacy stack keys remain 0.
- `tests/rga_testing/validation/BonkoEmpowerContractProbe.tscn`: `BonkoEmpowerContractProbe: PASS`; validates that the current Bonk cast applies the empower tag with expected hit count, damage/heal/mana metadata, and direct ramp-state telemetry without retaining the old unused Striker stack helper path.
- `tests/visual/LossScreenSmoke.tscn`: `LossScreenSmoke: OK`; later live editor run saved `outputs/visual_iter/loss_screen_pass/loss_overlay_modal_fixed.png`. Rerun on 2026-06-26 with `errors: []` now also covers run-total damage/kills surviving a later final-battle stats reset. The 2026-06-26 dummy/headless MCP run skipped fresh framebuffer capture, so it is behavioral evidence rather than new screenshot evidence.
- `tests/visual/ExitFlowSmoke.tscn`: `ExitFlowSmoke: OK`; later live editor run saved `outputs/visual_iter/exit_menu_pass/01_unit_select_system_menu.png` and `outputs/visual_iter/exit_menu_pass/02_combat_system_menu.png`. Rerun on 2026-06-26 with `errors: []`; the dummy/headless MCP run skipped fresh framebuffer captures, so it is behavioral evidence rather than new screenshot evidence.
- `tests/rga_testing/validation/StageProgressionProbe.tscn`: `StageProgressionProbe: PASS`; rerun on 2026-06-26 with `errors: []`, validating chapters 1-5 each have six rounds, at least two creep rounds, exactly one final-round boss, at least one special round, creep rounds with only creep IDs, and creep reward rules that are player-sourced, creep-only, component-capable, and completed-drop-free.
- `tests/rga_testing/validation/RewardsKillProbe.tscn`: `RewardsKillProbe: PASS`; rerun on 2026-06-26 with `errors: []`, validating that a player kill on an enemy creep adds one component, new creep rewards are component items only, player kills on non-creeps do not reward, and enemy-team kills do not grant player creep rewards.
- `tests/rga_testing/validation/RewardsActionsProbe.tscn`: `[RewardsTest] PASS`; rerun on 2026-06-26 with `errors: []`, validating reward actions for `grant_gold`, `grant_rerolls`, `drop_component`, disabled `drop_completed`, and no-crash `log`.
- `tests/rga_testing/validation/CreepsProbe.tscn`: `CreepsProbe: PASS (spawned 4)`; rerun on 2026-06-26 with `errors: []`, validating the chapter-1 creep wave discovery path, at least four spawned creeps, and cost-0 creep units.
- `tests/visual/AuditPanelSmoke.tscn`: `AuditPanelSmoke: OK`; rerun on 2026-06-25 with `errors: []`, then rerun again on 2026-06-26 at local HEAD `b3c1c2f` with `errors: []`, covering state export, screenshot status, speed controls, planning-timer hold, and New Run restart.
- `git diff --check`: clean

Confirmed current fixes/coverage:
- Normal new runs start with clean item inventory; `Items.DEV_STARTER_INVENTORY_ENABLED` is currently false and `ActualRunLoopSmoke` asserts an empty starting inventory.
- The opener now frames the fixed first combat as an `OPENING FIGHT` with `Win this opener to unlock the shop`, `Start Opening Fight`, disabled opening shop buttons, fixed `Opening bet: 1` copy, and click/keyboard feedback on the locked placeholder.
- The actual run loop now covers repeated New Game resets, all-in loss cycles, first-board-unit drag repositioning, post-fight shop purchase, first-purchase deploy prompt, first-purchase bench-slot highlight, planning-time assist, bench-to-board drag, highlight clearing after deploy, and second-fight resolution.
- Real-window deploy recheck exposed and fixed a drag-release edge case: after an OS mouse drag began from a bench unit, releasing outside the source `UnitView` could leave a drag ghost stuck and the bought unit on the bench. `DragAndDroppable` now listens for global mouse motion/release only while a drag is active, and the patched OS-window pass moves Cashmere from bench to board.
- Combat no-progress and absolute timeout handling are covered by `CombatWatchdogSmoke`.
- Lower Unit Select stale-preview behavior and neutral initial preview state are covered by `UnitSelectSmoke`, with current live-renderer neutral/hover/clear screenshots saved by `UnitSelectPreviewVisualSmoke`.
- The new cost tiering pass is mechanically covered: 12 cost-1 units, 9 cost-2 units, and Hexeon as the single cost-3 unit. Level 1 shops sample only cost-1 units, and higher levels sample the intended tier mix.
- Targeted current Main-flow premium and economy runners now cover the cost-2 path after leveling: `BuyXPTransactionalFeedbackSmoke` guards reserve-floor denial and successful level-up label repaint, `NaturalBuyXPVisualSmoke` guards a naturally funded visible Buy XP level-up without audit gold, and `PremiumDeployAfterLevelSmoke` tracks the Main-scene audit-assisted level-up, level-2 cost-2 shop-card purchase, deploy prompt, and bench-to-board premium drag. The ignored `NaturalBuyXPAudit` remains useful exploratory economy evidence, but it is no longer the strongest deploy proof because its latest result can pass without proving helper deployment.
- A targeted current Main-flow rapid-input runner now covers a same-frame burst across five rendered shop cards, five resulting bench units, five bench-to-board deploy attempts through global mouse-release input, and the next fight resolving. `RapidShopPressureSmoke` promotes the core pressure path into tracked validation with current `SOLD` / `On bench` placeholder assertions. A follow-up audit-assisted OS-window pass also covers real mouse-coordinate burst buying across five visible shop cards in the debug window. `ShopPurchaseFeedbackSmoke` guards the single-purchase feedback loop: gold delta, bench placement, deploy message, and explicit `SOLD` / `On bench` slot copy.
- Unit stats still come from role baselines rather than playable unit resources, as verified by `UnitStatAudit`.
- Stage progression, creep spawning, and creep reward actions now have focused current pass signals covering chapter structure, creep-only/player-sourced rewards, component-only item drops, disabled completed drops, and cost-0 creep units.
- Veyra Harden's scheduled end effect now reads canonical `TraitKeys.AEGIS` before falling back to the old `aegis_stacks` key, so current trait-runtime stacks correctly feed her permanent max-HP reward. `VeyraHardenCanonicalStackProbe` covers the direct contract, and a targeted `RoleMatrixProbe6v6Veyra` rerun still passes her tank role, team-fortification goal, and damage-reduction/CC-immunity/ramp approaches with `errors: []`.
- Kythera Siphon's cast path now has a direct canonical-stack contract: the old `aegis_stacks` key is only a compatibility fallback, while `TraitKeys.AEGIS` drives the live Siphon drain rate and scheduled permanent MR reward. `KytheraSiphonCanonicalStackProbe` covers the direct contract, and a targeted `RoleMatrixProbe6v6Kythera` rerun still passes her tank role, team-fortification goal, and damage-reduction/debuff approaches with `errors: []`.
- Cashmere Arcane Ledger's cast path now has a direct canonical-stack contract: the old `arcanist_stacks` key is only a compatibility fallback, while `TraitKeys.ARCANIST` drives the live damage scaling. `CashmereLedgerCanonicalStackProbe` covers the direct contract with legacy stacks held at 0 and the target kept alive to avoid unrelated economy reward side effects.
- Paisley Bubbles now has a direct canonical-stack contract: the old `kaleidoscope_stacks` and `arcanist_stacks` keys are only compatibility fallbacks, while `TraitKeys.KALEIDOSCOPE` and `TraitKeys.ARCANIST` drive both ally shield value and split magic damage. `PaisleyBubblesCanonicalStackProbe` covers the direct contract with legacy stacks held at 0.
- Morrak Reaping Line now has a direct canonical-stack contract: the old `striker_stacks` and `executioner_stacks` keys are only compatibility fallbacks, while `TraitKeys.STRIKER` and `TraitKeys.EXECUTIONER` drive both line damage scaling and low-HP execute threshold. `MorrakReapingLineCanonicalStackProbe` covers the direct contract with legacy stacks held at 0.
- Hexeon Prismatic Guillotine now has a direct canonical-stack contract: the old `kaleidoscope_stacks` and `executioner_stacks` keys are only compatibility fallbacks, while `TraitKeys.KALEIDOSCOPE` drives live damage scaling and `TraitKeys.EXECUTIONER` drives the low-HP execute threshold. `HexeonGuillotineCanonicalStackProbe` covers both direct contracts with legacy stacks held at 0.
- Bonko Bonk no longer carries the old unused Striker stack helper path. The current cast is an empower/ramp contract, covered by `BonkoEmpowerContractProbe`: it applies the Bonko empower tag with expected next-hit metadata and emits `bonko_empowered_hits` ramp telemetry.
- A debug-only `F8` Audit QA panel now provides in-game state JSON export, screenshot capture attempt with explicit headless/dummy skip reasons, planning-timer hold, New Run restart, and 1x/4x speed controls. `AuditPanelSmoke` verifies the panel stays hidden by default, exports parseable state, reports screenshot status safely, controls speed, holds the planning timer, and returns to Unit Select through New Run.
- The bottom shop/command band now has wider card gutters and command-control separation, covered by `UIThemeSmoke` assertions. The fixed opening-fight shop placeholder uses a brighter border, larger `OPENING FIGHT` label, clearer `Win this opener to unlock the shop` hint, and direct feedback when clicked or activated from keyboard; `OpeningFightVisualSmoke` adds current live-renderer screenshots under `outputs/visual_iter/opening_fight_copy_pass/`.
- The Start Battle button still changes immediately to disabled `Combat Resolving...`; if combat keeps running past the short delay it now shows elapsed resolving seconds, then a `Still resolving` warning after 10 seconds. If the engine watchdog fires, the button switches to `Resolving fallback...` while the existing post-combat recovery finishes.
- The system menu pause overlay now uses a lighter backdrop alpha so the underlying Unit Select or combat state remains readable enough for resume/new-run context; `ExitFlowSmoke` asserts the backdrop stays in the intended alpha range.
- A non-broke Chapter 1 Stage 1 defeat now receives opening retry recovery up to 2 gold. `AxiomRetryChoiceQualitySmoke` proves Axiom's configured retry helpers all advance beyond Stage 1, and `AxiomRetryEconomySmoke` proves the production forced-opener loss returns to a same-stage retry shop with a configured helper in slot 0, buys a 1-cost helper while preserving 1 gold, shows deploy guidance, deploys the helper to board, clears the first-deploy highlight, wins the retry fight, and returns to a full Stage 2 planning shop.
- The defeat modal now separates run summary from final-battle ledger: summary lines use run totals (`Run Damage`, `Run Healing`, `Run Kills`, `Top Run Damage`), while the embedded player-only scoreboard is titled `Final Battle Damage`. `LossScreenSmoke` verifies previous-battle player damage remains visible after the current battle tracker resets.

Remaining audit gaps:
- The current committed validation now includes accelerated and production-clock Main-flow replays for all 12 current starters after the cost-tier, stage/reward, and opener tuning changes, plus a fresh Godot-AI live-editor PNG set for every starter and capture milestone. The production-clock gate keeps `Engine.time_scale = 1.0` and does not hold the planning timer, while the PNG capture set remains the accelerated live-editor run. `NaturalInputMainFlowSmoke` now adds all-12 production-clock synthetic input proof for title Start, Unit Select, starter selection, Start Game, first shop click, strict no-fallback bench-to-board helper drag, and second-fight resolution. Natural-speed spot checks also include Sari through title Start, Unit Select, first planning, bench-to-board deployment, and opener resolving; Repo through title Start, Unit Select, guarded first shop, Sari purchase feedback, and the same-stage Round 2 defeat retry when the helper remains benched; and Axiom through title Start, support-starter selection, first deploy, production Round 2 shop, Bo purchase, and helper deploy. This is still not a physical human-speed replay of every starter: the all-starter gates are automated UI-path coverage, and the visual all-starter PNG set is still automated.
- The previous dummy-renderer run could not capture loss/exit framebuffers, but later live editor and OS-window runs did. Current modal blockers are covered: the defeat modal screenshot is refreshed after the player-only loss scoreboard and Menu-behind-defeat fixes, and the separate system menu overlay now has fresh OS-window visual proof with the lighter backdrop over Unit Select.
- RoleMatrixSmoke passes all 22 units, but the fresh detail recheck still finds accepted lower-level `FAIL` spans inside aggregate passes. After the subject-side filtering, diagnostic cleanup, scenario-pack, pick-burst, Totem cooldown-efficiency and CC-prevention, Mortem direct-attrition EHP, Bo direct backline-access, Grint initiate-success, marksman sustained-window, Hexeon subject-level assassin access, and Kythera source-owned fortification evidence passes, 1 of 22 reports still contains 2 subject-side accepted spans, with zero non-ramp identities carrying `goal_*_ramp_*` diagnostics and zero ramp-stack accepted spans. The latest export refresh reports 2 spans across 2 mapped gap kinds, and `AcceptedMissGuardCoverageSmoke` still maps every current gap kind to committed guard scenes while also locking the exact Totem peel-save/interrupt detail rows. `TotemGoalAlignmentProbe` proves a team-amplification goal contract can pass on the same live rows, but that remains a product/design decision rather than an applied identity change.
- Long manual play still has real-window fragility around timing/session capture, but first-purchase physical bench-to-board drag now has a targeted accepted OS-window pass after the global drag-release fix. Cost-1 post-buy bench/deploy, audit-assisted cost-2 buy/deploy, audit-assisted rapid shop-card buying, and production-clock rapid shop-card pressure now have accepted evidence. Buy XP now has automated Main-flow proof for both the natural successful level-up and the 4-gold reserve-floor denial message. The debug Audit QA panel reduces the repeated-eval/session-capture dependency by moving state export, timer hold, restart, and speed controls into the running game.
- A follow-up `tests/visual/MainFlowVisualCapture.tscn` attempt could not produce fresh framebuffer screenshots under the MCP dummy renderer. The harness now checks the rendering driver before calling `ViewportTexture.get_image()`, skips all captures with explicit framebuffer-unavailable messages, and reruns with `errors: []` under MCP. `tests/visual/BarItemsTraitsCapture.tscn` follows the same dummy-framebuffer guard path, but a 2026-06-26 live Godot-AI/OpenGL run produced current item/trait/bar PNGs under `outputs/visual_iter/bar_items_traits_pass/` with no tooltip edge skips. Later live editor/debug-window runs did capture fresh Bonko and modal screenshots, and a 2026-06-26 Godot-AI game-helper recheck successfully captured the current title screen at `outputs/audit_playtest/godot_ai_capture_recheck_2026_06_26/title_game_helper_capture.png`. Live capture still remains session-sensitive. The Audit QA screenshot control skips safely with an explicit reason under dummy/headless renderers, and a 2026-06-25 real debug-window run verified the non-dummy save path by producing `user://audit_exports/audit_shot_1782371342_158480.png`.

## Current Audit Closure Matrix

This matrix reflects the current audit state after the 2026-06-25 live cost-2, Buy XP, and Start Battle transition follow-ups. It separates completed behavioral proof, audit-assisted live-window proof, and natural live-window proof, because those are not interchangeable.

| Audit surface | Current strongest evidence | Status | Remaining proof needed |
| --- | --- | --- | --- |
| Starter-select surface | Unit Select live screenshots, `UnitSelectSmoke`, and `UnitSelectPreviewVisualSmoke` cover the current 12 cost-1 starter grid and preview states. The behavioral smoke compares rendered starter buttons against `UnitCatalog.list_starter_ids(STARTING_LEVEL)`, asserts every rendered starter is cost 1, fails if Hexeon appears in the level-1 picker, and guards neutral initial preview plus hover-clear behavior. The visual smoke saves live-renderer neutral, hover, and cleared-preview screenshots under `outputs/visual_iter/unit_select_preview_pass/`. | Covered behaviorally and visually for current cost-tier branch | None unless starter roster changes again; if the level-1 roster becomes scrollable again, repeat the visual pass against an actual scrolled grid. |
| Fixed opening fight and opening shop lockout | `OpeningFightVisualSmoke` verifies the current copy, disabled shop controls, hidden/locked opener bet slider, fixed `Opening bet: 1`, placeholder tooltip, and clicked-placeholder feedback. The same guard saved live-renderer screenshots under `outputs/visual_iter/opening_fight_copy_pass/`: `01_opening_fight_locked_shop.png` and `02_opening_fight_feedback.png`. `ActualRunLoopSmoke` still covers the real Main-scene opener flow, and `UIThemeSmoke` covers placeholder prominence/clickability plus command-band spacing. | Covered behaviorally and visually | Preserve the explicit prologue-style placeholder, fixed opener bet copy, tooltip, and click/keyboard feedback. |
| Post-shop betting and wager lock | `BettingEconomySmoke` covers the pure Economy contract and the real Main-scene post-shop UI contract. The direct path proves a 2-gold all-in wager escrows to 0 gold, exposes 3 combat credit, ignores `set_bet` while combat-active, pays out to 4 gold on win with next preferred bet at 4, and leaves 0 gold on loss. The Main path proves post-opener betting opens after the first shop, max-bet updates the model and visible copy, Start Battle locks/escrows that bet, hides/disables the slider, shows `Bet: N (locked)`, and ignores later slider/model changes during combat. The 2026-06-26 live Godot-AI/OpenGL run saved current screenshots under `outputs/visual_iter/betting_economy_pass/`: visible post-shop slider, max-bet selected at 3, and combat locked at `Bet: 3 (locked)` with gold escrowed to 0. | Covered behaviorally and visually | Optional live-window screenshot refresh if the betting row UI changes; preserve slider visibility/editability only after the forced opener, locked combat copy, escrow, and in-combat change rejection. |
| All current starters through first Main-flow loop | `AllStarterMainFlowSmoke` is committed accelerated validation for all 12 current starters reaching first shop, buying/deploying a helper, and resolving the second fight through the real Main scene with zero opener retries. `NaturalAllStarterMainFlowSmoke` now replays the same all-12 contract at production `Engine.time_scale = 1.0` without the planning-timer hold. `NaturalInputMainFlowSmoke` adds tracked all-12 production-clock input proof through title Start, Unit Select, starter selection, Start Game, first shop card click, strict no-fallback bench-to-board helper drag, and second-fight resolution. The Chapter 1 Round 1 Beegle is tuned as a short-range tutorial target only for that opener (`max_hp=120`, `attack_damage=50`, `attack_range=1`), while later Beegles keep their normal profile. The smokes still assert Bo, Bonko, Cashmere, Korath, Mortem, Repo, and Sari see a known advancing helper in slot 0 of their first post-opener shop via the starter-aware opening-shop guard, while `FirstShopOfferQualitySamplingSmoke` asserts configured known-bad helpers are absent from sampled guarded opening shops. The ignored `AllStarterLiveCapture` replay adds a clean Godot-AI live-editor PNG set: 72 saved captures, 0 skipped, `display_server=Windows`, `rendering_driver=opengl3`, and matching manifest counts for all 12 starters. Natural-speed spot checks cover Sari title-to-deploy/opener, Repo title-to-guarded-shop/purchase/retry behavior, and Axiom support-starter production helper-deploy behavior. `AxiomRetryChoiceQualitySmoke` and `AxiomRetryEconomySmoke` force the hard opener internally to keep fallback retry recovery covered. | Covered behaviorally at accelerated and production clock; covered visually through automated live-editor captures; tracked synthetic input proof covers all current starters; natural spot checks cover one clean deploy starter, one weak-starter shop/retry path, and one support-starter production helper-deploy path | Physical human-speed replay of every starter remains optional feel proof, not a current blocker. Preserve the caveat that the all-starter PNG set is automated/accelerated and that strict-input proof is still synthetic, not external OS/manual replay. |
| Planned mid-run progression line | `MidRunProgressionSmoke` drives Bonko through the real Main scene opener, forces three later cost-1 offer rows, buys Morrak/Grint, Sari/Brute, and Berebell/Bo through rendered shop cards, deploys each bench unit through the shared drag path, and proves the planned line advances Stage 2 -> 3 -> 4 -> 5 with `errors: []`. | Covered for one audit-assisted deterministic board-width line | Broader later-choice quality now has all-current-starter one-seed random-shop coverage under audit gold, but this planned line should still not be treated as proof that natural economy, deep seed coverage, or natural human-speed full runs are balanced. |
| Seeded random later-shop progression | `RandomLaterShopProgressionSmoke` seeds the live Shop RNG for all 12 current level-1 starter samples (`axiom`, `berebell`, `bo`, `bonko`, `brute`, `cashmere`, `grint`, `korath`, `morrak`, `mortem`, `repo`, `sari`), keeps the protected first-shop opener, then leaves later shop rows natural. It uses audit gold to avoid economy starvation, buys up to two visible shop cards per shop with a simple board-width/frontline-first heuristic, deploys through the same bench-to-board drag path, and proves every sampled line reaches Stage 5 with `errors: []`. | Covered for all 12 current starter natural-offer samples under audit gold | Still not natural economy proof, deep seed coverage, or physical manual replay. Broaden by economy realism and seed count if later-shop quality becomes the active balance target. |
| First-fight movement edge cases | The original long-wait examples, Paisley/Totem/Veyra, are now cost-2 units and no longer render in the level-1 starter picker. `CostBalanceSmoke` and `UnitSelectSmoke` guard that premium-unit boundary, while `CombatWatchdogSmoke` and `CombatResolvingFeedbackSmoke` cover no-progress and visible long-resolution states. | Covered for current level-1 opener | Preserve cost-tier gating and combat watchdogs. Revisit as premium-unit/post-shop movement tuning only if level-2 fights still read frozen in future play. |
| Dev starter item inventory | `DevStarterInventorySmoke` proves `Items.DEV_STARTER_INVENTORY_ENABLED` defaults false, `reset_run()` keeps normal inventory and visible slots empty, and the starter inventory seeds only when that dev flag is explicitly enabled. `ActualRunLoopSmoke` also asserts new real Main-flow runs start with empty item inventory. | Covered behaviorally | Preserve the default-off dev inventory flag so normal playtests stay item-clean. |
| Item, trait, and bar UI | `BarItemsTraitsCapture` forces a filled item inventory and trait state, then validates eight filled item cards, three visible trait icons, item and trait tooltip hover show/clear behavior, zero visible planning-grid ProgressBars, and six visible combat actor ProgressBars. The 2026-06-26 live Godot-AI/OpenGL run saved current screenshots under `outputs/visual_iter/bar_items_traits_pass/`: planning items/traits with hidden grid bars, simultaneous item and trait tooltips, and combat actor bars. The legacy MCP debug rerun still skips PNG capture under dummy rendering but passes with `errors: []`. | Covered behaviorally and visually | Optional live-renderer screenshot refresh if item, trait, tooltip, or combat-bar polish changes. Preserve the planning-vs-combat bar visibility split and tooltip hover paths. |
| Completed item data/effect integrity | `CompletedItemEffectRegistrySmoke` loads the completed item catalog, checks every completed `stat_mods` key against `ItemModSchema`, and verifies every declared runtime effect id has a registered `EffectRegistry` handler. Current rerun covered 36 completed items, 36 runtime-effect ids, and all 36 registered handlers. `CompletedItemRuntimeEffectsProbe` also verifies every completed item effect changes combat state when dispatched through representative combat events. | Covered behaviorally/data-wise | Preserve the registry and runtime-effect smokes whenever completed item resources, stat keys, or runtime effect handlers change. |
| Stage progression and creep rewards | `StageProgressionProbe`, `RewardsKillProbe`, `RewardsActionsProbe`, and `CreepsProbe` now have fresh MCP `errors: []` reruns. Together they prove chapters 1-5 keep six rounds, at least two creep rounds, exactly one final-round boss, special-round coverage, creep-only round rosters, creep reward rules that are player-sourced and creep-only, component-capable reward pools with no completed drops, component-only kill rewards, disabled completed-drop actions, grant-gold/reroll actions, and cost-0 creep spawns. | Covered behaviorally/data-wise | Preserve six-round chapter structure, creep-only/player-sourced rewards, component-only item drops, disabled completed drops, and zero-cost creep units. |
| Cost-1 post-buy bench/deploy | Live Bonko-to-Brute run confirms purchase-to-bench and OS-level bench-to-board drag. `outputs/audit_playtest/current_deploy_drag_recheck/` adds a fresh real-window pass: the pre-fix OS drag left a ghost stuck while the unit stayed on bench; after the global release fix, an OS click bought Cashmere, the prompt appeared, and an OS drag moved Cashmere from bench to board with `completion_reported=true`. `ActualRunLoopSmoke` asserts the first-purchase prompt, bought bench-slot highlight, timer extension, bench-to-board drag, and highlight clearing after deploy. | Covered visually and behaviorally | Preserve global drag-release handling, board-cell guidance, and bench-slot guidance. Future manual passes can focus on speed/pressure polish rather than known drop correctness. |
| Cost-2 premium behavior after leveling | `PremiumDeployAfterLevelSmoke` is now the committed tracked guard for this surface: it drives the real Main scene from Bonko forced opener to first shop, audit-assists visible Buy XP to level 2 if opener rewards leave less than the reserve-safe amount, forces a deterministic full level-2 offer row with cost-2 Kythera in slot 0, buys the premium card, sees bench placement and deploy guidance, and drags Kythera onto the board. `PremiumDeployAuditRunner` and `outputs/audit_playtest/live_cost2_recheck_2026_06_25/` remain richer ignored/live-window history, including OS-click screenshots for Buy XP, level-2 offers, Teller purchase, and Teller deployment. | Covered behaviorally and audit-assisted visually | Natural long-form real-window cost-2 shopping remains optional feel proof; preserve visible Buy XP repaint, level-2 offer exposure, premium bench placement, deploy prompt, and bench-to-board premium drag. |
| Buy XP live-window affordance | The first live attempt exposed stale UI after a raw `Economy.gold` write. The follow-up assist used `Economy.add_gold(...)`, visibly updated to `Gold: 5`, and a real OS Buy XP click updated to `Lvl 2 (2/6)`. `BuyXPTransactionalFeedbackSmoke` guards the committed presenter path: 4g denial leaves labels unchanged and shows `Need +1 gold to buy XP and keep 1 health.`, while a 6g success repaints `Gold: 2` and `Lvl 2 (2/6)`. `NaturalBuyXPVisualSmoke` now retries ordinary Bonko opener reward outcomes without audit gold until a safe natural 5g window appears, then captures visible pre-click `Gold: 5` / `Lvl 1 (0/2)` and post-click `Gold: 1` / `Lvl 2 (2/6)` frames. `PremiumDeployAfterLevelSmoke` keeps the broader level-2 premium-deploy path covered with audit gold only when needed. | Covered behaviorally and visually through natural/unassisted live-renderer capture plus transactional smoke | Optional screenshot refresh only if the Buy XP UI changes; preserve the explicit denial message, reserve-floor behavior, and immediate progress repaint. |
| Rapid shop input | `RapidShopPressureSmoke` guards the accelerated Main-flow pressure path: same-frame rendered-card burst, five sold/on-bench placeholders, no shop errors, five bench-to-board deploys through global mouse-release input, and a resolved follow-up fight. `ProductionRapidShopPressureSmoke` replays that same path at `Engine.time_scale = 1.0` without holding planning timers and buys through rendered-card viewport mouse clicks, so the rapid buy/deploy/follow-up fight path now covers production-clock hit routing as well. `RapidShopVisualPressureSmoke` adds post-burst and post-deploy capture checkpoints on the production-clock path; its live Godot-AI/OpenGL run saved `outputs/visual_iter/rapid_shop_pressure_pass/01_after_rapid_purchases.png` with five visible sold/on-bench placeholders plus deploy guidance, and `02_after_rapid_deploy.png` with the bench cleared, six board units, and readable scoreboard rows. `RapidShopInputAudit` remains the richer ignored artifact, and `outputs/audit_playtest/rapid_shop_os_burst/` adds audit-assisted real-window OS-coordinate evidence: before/after screenshots, preserved card centers, click coordinates, five bench additions, five sold placeholders, and no shop errors. `ShopPurchaseFeedbackSmoke` guards the single-purchase feedback path: gold delta, bench placement, deploy guidance message, and `SOLD` / `On bench` slot copy. `UIThemeSmoke` also asserts wider shop-card gutters and command-strip spacing; `outputs/audit_playtest/shop_spacing_recheck_2026_06_25/08_round2_shop_wait.png` refreshes the first real shop view. | Covered behaviorally at accelerated and production clock; covered visually for live post-burst/post-deploy pressure states; covered audit-assisted for OS-coordinate buying | Natural physical human-speed buying remains optional feel proof; preserve hit clarity, purchase feedback, deployment guidance, global-release deploy handling, explicit sold/on-bench copy, and the widened bottom-band spacing. |
| Start Battle transition | `StartBattleFeedbackAudit` covers stages 2-4 switching immediately to disabled `Combat Resolving...`; `CombatResolvingFeedbackSmoke` covers elapsed `Resolving Ns...`, `Still resolving Ns...`, and watchdog `Resolving fallback...` labels; `CombatResolvingFeedbackVisualSmoke` adds live-renderer screenshots for immediate, elapsed, long-wait, and fallback button states under `outputs/visual_iter/combat_resolving_feedback_pass/`; `outputs/audit_playtest/live_start_battle_transition_2026_06_25/` provides real-window screenshots from Round 2 planning, immediate post-click resolving, mid-combat resolving, and restored planning. | Covered behaviorally and visually for immediate transition, elapsed resolving, long-wait warning, and watchdog fallback states | Optional natural real-window screenshot refresh only if a future manual pass catches a real long/stalled fight. Preserve the disabled resolving button copy and watchdog fallback copy. |
| Post-win planning beat | `PostCombatPlanningBeatSmoke` covers a Bonko forced-opener win returning through the visible gothic intermission bar before `PREVIEW`, then restoring a full shop, enabled `Start Battle`, and at least 55 seconds of planning time. The 2026-06-26 live Godot-AI/OpenGL run saved current screenshots under `outputs/visual_iter/post_combat_planning_beat_pass/`: the post-win intermission bar and restored Round 2 planning state with visible shop, `Start Battle`, gold, bet, and timer copy. | Covered behaviorally and visually | Optional screenshot refresh only if post-combat UI changes; preserve the intermission beat and full timer reset so combat resolution cannot silently consume the next shop decision. |
| Duplicate scoreboard rows | `DuplicateScoreboardVisualAudit` exposed the ambiguity, and `ScoreboardDuplicateDisambiguationSmoke` now covers duplicate-copy labels in the model and rendered row scene. The 2026-06-26 live Godot-AI/OpenGL run saved `outputs/visual_iter/duplicate_scoreboard_pass/01_duplicate_scoreboard_copy_labels.png`, showing two readable duplicate rows labeled `Berebell #1` and `Berebell #2`. | Covered behaviorally and visually | Optional screenshot refresh only if scoreboard row UI changes; preserve copy suffixes for duplicate display names. |
| Loss and system modals | `LossScreenSmoke`, `ExitFlowSmoke`, and real Axiom loss capture provide current framebuffer evidence. `LossScreenSmoke` proves the defeat modal keeps run-total summary stats after a later final-battle reset, uses an explicit `Final Battle Damage` player-only ledger, and does not keep hidden enemy row labels in the tree. `ExitFlowSmoke` proves the system Menu hides and cannot open while `LossOverlayLayer` is active, and asserts the pause backdrop alpha stays context-readable. `outputs/audit_playtest/current_loss_modal_visual/current_loss_modal_window_run_totals.png` refreshes the loss modal after the run-total title change; `outputs/audit_playtest/current_system_menu_visual/unit_select_system_menu_lighter_backdrop.png` refreshes the system menu over Unit Select. | Covered behaviorally and visually for current labels/backdrop | No current modal blocker remains from the audit. |
| RGA identity reports | `RoleMatrixSmoke` passes all 22 current units, while the direct catalog guards prove the taxonomy underneath it: 22 approaches, 22 goals, 32 metrics, 6 role semantic contracts, 22 goal semantic contracts, 22 approach semantic contracts, and the live playable catalog matching `docs/unit_identity_map.md`. The saved report parser now finds 2 subject-side accepted lower-level `FAIL` spans across 1/22 reports after filtering opponent-side aggregate labels and closing the prior diagnostic groups for non-applicable ramp, soft-peel hard-peel, non-attrition brawler direct attrition, AoE median fallback, burst pressure, marksman positioning/sustained-window, mage periodicity, reposition, engage, team-save/EHP fallback, Totem CC-prevention/cooldown, counterplay response, frontline/body-block, redirect, execute, ramp, Wombo third-path, Hexeon subject-level assassin access, and Kythera source-owned fortification uptime. Latest accepted-miss export refresh reports 2 spans across 2 mapped gap kinds, and `AcceptedMissGuardCoverageSmoke` passes with each current Totem gap mapped to real Cleanse proof, synthetic proof, scenario-pack coverage, focused live residual proof, and the Totem goal-alignment decision probe. | Covered as smoke; tuning remains open | Treat accepted misses as balance/instrumentation backlog, not starter/shop-flow blocker. Preserve the catalog/semantic guards when changing identity keys, role profiles, goals, approaches, or `docs/unit_identity_map.md`. |
| Tooling reliability | Multiple runs reproduced Godot-AI session drops, missing game helper registration, and dummy framebuffer capture failures. Current fallback guards now skip dummy-framebuffer captures before `ViewportTexture.get_image()` and rerun with `errors: []`. `AuditPanelSmoke` covers a debug-only in-game Audit QA panel for state export, screenshot status, timer hold, restart, and speed controls; a fresh 2026-06-26 MCP rerun at local HEAD `b3c1c2f` printed `AuditPanelSmoke: OK` with `errors: []`. A real debug-window OS click on the panel's Screenshot button saved `user://audit_exports/audit_shot_1782371342_158480.png`; `02_after_screenshot_click.png` shows the panel confirming the save path. A 2026-06-26 Godot-AI helper recheck also succeeded with `game_capture_ready=true` and saved `outputs/audit_playtest/godot_ai_capture_recheck_2026_06_26/title_game_helper_capture.png`. | Covered for in-game audit controls and current helper title capture; Godot-AI long-session capture remains fragile | Keep fallback OS screenshots for visual evidence when `_mcp_game_helper` does not register; continue using the panel for state/screenshot/timer control during manual audits. |

## Current Audit QA Panel Live Screenshot Recheck

Fresh real-window evidence was generated on 2026-06-25 from the running `Gamble Battle (DEBUG)` window after `godot-ai editor_screenshot(source="game")` failed with `_mcp_game_helper` registration timeout.

Accepted files:
- `outputs/audit_playtest/audit_panel_live_capture_2026_06_25/01_panel_open.png`: OS-window capture showing the debug-only Audit QA panel open over the title screen after pressing `F8`.
- `outputs/audit_playtest/audit_panel_live_capture_2026_06_25/02_after_screenshot_click.png`: OS-window capture after clicking the panel's Screenshot button; the panel reports a saved path under `C:/Users/Flipm/AppData/Roaming/Godot/app_userdata/Gamble Battle/audit_exports/`.
- `user://audit_exports/audit_shot_1782371342_158480.png`: the PNG written by the panel's own viewport screenshot path. It opens correctly and shows the title screen plus Audit QA panel.

Result:
- The panel's non-dummy screenshot save path is verified in a live debug window.
- The remaining infrastructure caveat is not the panel; it is the Godot-AI game helper sometimes failing to register debugger capture/eval for the running game.

## Current Godot-AI Game Helper Capture Recheck

Fresh helper-capture evidence was generated on 2026-06-26 by running `res://scenes/Main.tscn` through Godot-AI `project_run` after stopping a stale playing validation scene.

Result:
- `editor_state` reported `game_capture_ready=true`.
- `editor_screenshot(source="game")` returned a nonblank 800x450 title-screen capture from the 1920x1080 game framebuffer.
- A runtime `game_eval` save wrote `outputs/audit_playtest/godot_ai_capture_recheck_2026_06_26/title_game_helper_capture.png`; the saved PNG opens correctly and shows the current title screen.
- This is a positive current helper-capture check, not proof that long manual sessions will stay connected. Keep the Audit QA panel and OS-window capture fallback for longer audits.

## Current Godot-AI Live Main-flow Capture Recheck

Fresh helper-backed screenshots were saved on 2026-06-26 under `outputs/audit_playtest/live_main_flow_capture_2026_06_26/` from a Godot-AI run of `res://scenes/Main.tscn`.

Accepted files:
- `01_title.png`: current title screen, confirming a nonblank live game framebuffer.
- `02_unit_select.png`: Unit Select roster with no champion chosen and disabled `Start Game`.
- `03_forced_first_fight.png`: Bonko forced opener with disabled shop controls, fixed `Opening bet: 1` copy, `Start Forced Fight`, and the `FIRST FIGHT` / `Win to open shop` placeholder.
- `04_after_forced_fight_wait.png`: post-forced-fight shop unlock with normal shop cards visible and `Start Battle` restored.

Limits:
- The multi-step helper eval timed out after the forced-fight wait, and a shorter follow-up save also timed out after writing `04_after_forced_fight_wait.png`; the Godot-AI session later dropped to zero registered sessions.
- The fourth frame shows an inflated planning timer and still labels the header `Stage 1 - Round 1/6`, so treat it as live visual proof that the first shop unlocks after the forced fight, not as clean stage/round progression proof.

## Current Natural-Speed Sari Main-flow Recheck

Fresh single-starter evidence was saved on 2026-06-26 under `outputs/audit_playtest/natural_main_flow_2026_06_26/` from a Godot-AI run of `res://scenes/Main.tscn`, using runtime mouse input rather than a harness shortcut.

Accepted files:
- `01_title.png`: title screen before interaction.
- `02_unit_select.png`: Unit Select after a real Start button click.
- `03_sari_selected.png`: Sari selected through the rendered starter card, with `Start Game` enabled.
- `04_first_planning.png`: first planning state after Start Game, showing `Stage 1 - Round 1/6`, `Gold: 2`, planning timer, and disabled Attack while Sari is still benched.
- `05_starter_deployed.png`: Sari deployed on the board and the forced opener resolving with `Gold: 1`, `Resolving 4s...`, and `Bet: 1 (locked)`.

Limits:
- This pass covers one representative cost-1 starter at natural interaction speed; it does not replace the all-starter automated replay.
- The Godot-AI session dropped during the post-deploy state read and later reported zero registered sessions. Legacy `get_debug_output()` returned `errors: []` and included the Sari bench-add log, so this is recorded as a bridge/session reliability limit rather than a gameplay failure.
- Several older debug/editor processes were still present on the machine during this run. Future natural passes should begin by stopping stale debug windows or launching a clean editor session before long-form capture.

## Current Natural-Speed Repo Main-flow Recheck

Fresh weak-starter evidence was saved on 2026-06-26 under `outputs/audit_playtest/natural_repo_flow_2026_06_26/` from a Godot-AI run of `res://scenes/Main.tscn`, using runtime mouse input for the player-facing steps.

Accepted files:
- `01_title.png`: title screen before interaction.
- `02_unit_select.png`: Unit Select after a real Start button click.
- `03_repo_selected.png`: Repo selected through the rendered starter card, showing `Tank`, `Tank - Frontline Absorb`, `Damage Reduction`, and `Start Game` enabled.
- `07_first_shop.png`: Repo reached the first post-opener shop at `Stage 1 - Round 2/6` with `Gold: 3`, `Start Battle`, level 1, and Sari as the first visible 1g guarded offer.
- `08_after_buy_sari.png`: clicking Sari changed the first shop slot to `SOLD` / `On bench` and dropped gold to 2.
- `09_second_battle_resolving.png`: the follow-up `Start Battle` click entered the resolving transition with the planning timer at zero.
- `10_after_second_battle.png`: the run returned to Stage 1 Round 2 planning with `Gold: 1` and `Start Battle` restored.

Limits:
- This pass did not capture clean first-planning/deploy frames because the run advanced through the opener during a handoff gap.
- The Sari purchase was left on bench before the second fight, so the final same-stage state is interpreted as Repo losing the follow-up fight without the bought helper deployed. It is useful evidence for the weak-starter shop/retry path and purchase feedback, not for natural helper-deploy success.
- A direct Godot-AI state export after the final frame timed out, after which `session_manage` returned zero sessions. Earlier live reads had already shown `phase=PREVIEW`, `stage=2`, and `gold=1`, and legacy `get_debug_output()` reported `errors: []`; record the timeout as live-bridge fragility.

## Current Natural-Speed Axiom Main-flow Recheck

Fresh support-starter evidence was saved on 2026-06-26 under `outputs/audit_playtest/natural_axiom_flow_2026_06_26/` from a Godot-AI run of `res://scenes/Main.tscn`, using runtime mouse input for the player-facing steps.

Accepted files:
- `01_title.png`: title screen before interaction.
- `02_unit_select.png`: Unit Select after a real Start button click.
- `03_axiom_selected.png`: Axiom selected through the rendered starter card, showing `Support`, `Support - Team Amplification`, `Amp`, `Peel`, `Sustain`, and `Start Game` enabled.
- `04_first_planning.png`: first planning state after Start Game, showing `Stage 1 - Round 1/6`, `Gold: 2`, `Start Forced Fight`, and the locked `FIRST FIGHT` shop placeholder.
- `05_axiom_deployed.png`: Axiom dragged from the first bench slot to the board through real mouse input.
- `06_forced_fight_resolving.png`: the forced opener resolving after a real `Start Forced Fight` click.
- `07_retry_shop.png`: despite the historical filename, the current production path reached normal `Stage 1 - Round 2/6` planning with 2 gold, `Start Battle`, and visible 1g helper offers: Axiom, Bo, Berebell, Bonko, and Mortem.
- `08_retry_helper_bought.png`: buying Bo from the visible Brawler offer dropped gold to 1 and placed the bought helper on the bench.
- `09_retry_helper_deployed.png`: the bought helper was dragged from bench to board through real mouse input.

Limits:
- This pass is natural-speed support-starter evidence for current production Axiom no longer requiring the opener retry branch; it is not a forced-loss fallback proof.
- The follow-up `Start Battle` input after helper deployment timed out the Godot-AI bridge, and subsequent editor state/stop calls also timed out or dropped the session. The deterministic fallback proof remains `AxiomRetryEconomySmoke` plus `AxiomRetryChoiceQualitySmoke`, both rerun immediately afterward through legacy MCP with `errors: []`.
- The screenshot directory name and late filenames keep the word `retry` from the original target of the run. Current product behavior in the accepted frames is Round 2 production shop/helper deployment, not an opener retry.

## Current Main-flow Smoke Sweep Recheck

Fresh MCP debug validation on 2026-06-26 rechecked the broad playable surface after the RGA residual guard pass:

- `tests/visual/UnitSelectSmoke.tscn`: `UnitSelectSmoke: OK`, `errors: []`.
- `tests/visual/ActualRunLoopSmoke.tscn`: `ActualRunLoopSmoke: OK`, `errors: []`.
- `tests/visual/AxiomRetryEconomySmoke.tscn`: `AxiomRetryEconomySmoke: OK`, `errors: []`.
- `tests/visual/UIThemeSmoke.tscn`: `UIThemeSmoke: OK`, `errors: []`.
- `tests/visual/ShopPurchaseFeedbackSmoke.tscn`: `ShopPurchaseFeedbackSmoke: OK`, `errors: []`.
- `tests/visual/BuyXPTransactionalFeedbackSmoke.tscn`: `BuyXPTransactionalFeedbackSmoke: OK`, `errors: []`.
- `tests/visual/NaturalBuyXPVisualSmoke.tscn`: current legacy MCP debug rerun passed with `NaturalBuyXPVisualSmoke: OK attempts=1 stage=2 gold_before=5 gold_after=1` and `errors: []`, using a test-only guaranteed +2 gold opener reward pool through `CreepRewardsRuntime`; the older live Godot-AI/OpenGL run saved `outputs/visual_iter/natural_buy_xp_pass/01_natural_buy_xp_ready.png` and `02_natural_buy_xp_success.png` from the former random-retry version.
- `tests/visual/RapidShopPressureSmoke.tscn`: `RapidShopPressureSmoke: OK purchases=5 deployed_board=6`, `errors: []`.
- `tests/visual/PostCombatPlanningBeatSmoke.tscn`: `PostCombatPlanningBeatSmoke: OK`, `errors: []`; a live Godot-AI/OpenGL run saved `outputs/visual_iter/post_combat_planning_beat_pass/01_post_win_intermission_bar.png` and `02_post_win_planning_restored.png`, while the legacy MCP rerun skipped capture under dummy rendering and passed cleanly.
- `tests/visual/DragGlobalReleaseSmoke.tscn`: `DragGlobalReleaseSmoke: OK`, `errors: []`.
- `tests/visual/CombatResolvingFeedbackSmoke.tscn`: `CombatResolvingFeedbackSmoke: OK`, `errors: []`.
- `tests/visual/CombatWatchdogSmoke.tscn`: `CombatWatchdogSmoke: OK`, `errors: []`.
- `tests/visual/DevStarterInventorySmoke.tscn`: `DevStarterInventorySmoke: OK`, `errors: []`.
- `tests/visual/BarItemsTraitsCapture.tscn`: `BarItemsTraitsCapture: OK planning_visible_bars=0 combat_visible_bars=6 filled_item_cards=8 visible_trait_icons=3 tooltip_edge_skips=2`, `errors: []`; screenshots skipped under the MCP dummy framebuffer and tooltip edge clamps skipped because the dummy viewport is smaller than the tooltips.
- `tests/visual/LossScreenSmoke.tscn`: `LossScreenSmoke: OK`, `errors: []`; screenshot capture still skipped under the MCP dummy framebuffer.
- `tests/visual/ExitFlowSmoke.tscn`: `ExitFlowSmoke: OK`, `errors: []`; screenshot capture still skipped under the MCP dummy framebuffer.
- `tests/visual/ScoreboardDuplicateDisambiguationSmoke.tscn`: `ScoreboardDuplicateDisambiguationSmoke: OK`, `errors: []`; a live Godot-AI/OpenGL run saved `outputs/visual_iter/duplicate_scoreboard_pass/01_duplicate_scoreboard_copy_labels.png`, while the legacy MCP rerun skipped capture under dummy rendering and passed cleanly.
- `tests/visual/TitleMenuSmoke.tscn`: `TitleMenuSmoke: OK`, `errors: []`.
- `tests/visual/StatsPanelClickSmoke.tscn`: `StatsPanelClickSmoke: OK`, `errors: []`.
- `tests/visual/StatsPanelDeepCapture.tscn`: originally exposed a stale audit assumption that combat enemy actor index 1 always exists; the harness now derives enemy actor indices from the arena bridge, verifies the current enemy actor, and logs an explicit skip when the current fight has only one enemy actor. Rerun result: `StatsPanelDeepCapture: OK`, `errors: []`; screenshots still skipped under the MCP dummy framebuffer.
- `tests/visual/AuditPanelSmoke.tscn`: `AuditPanelSmoke: OK`, `errors: []`.
- `tests/visual/MainFlowVisualCapture.tscn`: rerun after the dummy-framebuffer guard printed explicit framebuffer-unavailable skips for all four capture points and returned `errors: []`.
- `tests/visual/CombatViewThemePlaytest.tscn`: `CombatViewThemePlaytest: OK elapsed=2.00`, `errors: []`.
- `tests/visual/BettingEconomySmoke.tscn`: `BettingEconomySmoke: OK`, `errors: []`; live-renderer screenshots saved under `outputs/visual_iter/betting_economy_pass/`.
- `tests/visual/PremiumDeployAfterLevelSmoke.tscn`: `PremiumDeployAfterLevelSmoke: OK premium=kythera buy_xp_audit_gold=2 premium_audit_gold=11`, `errors: []`.
- `tests/rga_testing/validation/StageProgressionProbe.tscn`: `StageProgressionProbe: PASS`, `errors: []`.
- `tests/rga_testing/validation/RewardsKillProbe.tscn`: `RewardsKillProbe: PASS`, `errors: []`.
- `tests/rga_testing/validation/RewardsActionsProbe.tscn`: `[RewardsTest] PASS`, `errors: []`.
- `tests/rga_testing/validation/CreepsProbe.tscn`: `CreepsProbe: PASS (spawned 4)`, `errors: []`.
- `tests/visual/CombatViewThemeCapture.tscn`: rerun after the dummy-framebuffer guard printed an explicit skip and returned `errors: []`; the scene was then stopped manually because this legacy capture harness does not quit itself.

## Current Front-door And Modal UI Smoke Refresh

Fresh MCP debug validation on 2026-06-26 rechecked the current front-door, modal, and immediate post-opener UI contract:

- `tests/visual/TitleMenuSmoke.tscn`: `TitleMenuSmoke: OK`, `errors: []`.
- `tests/visual/UnitSelectSmoke.tscn`: `UnitSelectSmoke: OK`, `errors: []`.
- `tests/visual/UIThemeSmoke.tscn`: `UIThemeSmoke: OK`, `errors: []`.
- `tests/visual/LossScreenSmoke.tscn`: `LossScreenSmoke: OK`, `errors: []`; screenshot capture still skipped under the MCP dummy framebuffer.
- `tests/visual/ExitFlowSmoke.tscn`: `ExitFlowSmoke: OK`, `errors: []`; both system-menu captures still skipped under the MCP dummy framebuffer.
- `tests/visual/StatsPanelClickSmoke.tscn`: `StatsPanelClickSmoke: OK`, `errors: []`.
- `tests/visual/OpeningFightVisualSmoke.tscn`: `OpeningFightVisualSmoke: OK captures=0 output=C:/Users/Flipm/Documents/gamble-battle/outputs/visual_iter/opening_fight_copy_pass`, `errors: []`; the legacy MCP run still skipped PNG capture under dummy rendering.
- `tests/visual/BettingEconomySmoke.tscn`: `BettingEconomySmoke: OK`, `errors: []`; the pure Economy and real Main-scene post-opener betting checks still passed, with dummy-framebuffer PNG skips.
- `tests/visual/PostCombatPlanningBeatSmoke.tscn`: `PostCombatPlanningBeatSmoke: OK`, `errors: []`; the post-win intermission and restored planning state still passed, with dummy-framebuffer PNG skips.

This refresh does not replace the live OpenGL and OS-window screenshot evidence already listed above. It confirms the current tracked scenes still pass at HEAD after the accepted-miss stable export path change and keeps the dummy-framebuffer capture limitation explicit.

## Current Item, Reward, And Trait-Stack Smoke Refresh

Fresh MCP debug validation on 2026-06-26 rechecked the current item UI, completed-item registry, stage reward rules, creep rewards, and canonical trait-stack contracts:

- `tests/visual/DevStarterInventorySmoke.tscn`: `DevStarterInventorySmoke: OK`, `errors: []`.
- `tests/visual/BarItemsTraitsCapture.tscn`: `BarItemsTraitsCapture: OK planning_visible_bars=0 combat_visible_bars=6 filled_item_cards=8 visible_trait_icons=3 tooltip_edge_skips=2`, `errors: []`; the MCP dummy framebuffer skipped fresh PNGs, and tooltip edge clamps skipped only because the dummy viewport was smaller than the tooltip controls.
- `tests/rga_testing/validation/CompletedItemEffectRegistrySmoke.tscn`: `CompletedItemEffectRegistrySmoke: PASS`, `errors: []`; current catalog read is 36 completed items, 36 runtime effect ids, and 36 registered handlers. `CompletedItemRuntimeEffectsProbe.tscn` also passes with `errors: []` and confirms all completed item effects change runtime combat state.
- `tests/rga_testing/validation/StageProgressionProbe.tscn`: `StageProgressionProbe: PASS`, `errors: []`.
- `tests/rga_testing/validation/RewardsKillProbe.tscn`: `RewardsKillProbe: PASS`, `errors: []`; the debug run showed a player creep kill dropping a component while non-creep and enemy-team kill cases stayed reward-free.
- `tests/rga_testing/validation/RewardsActionsProbe.tscn`: `[RewardsTest] PASS`, `errors: []`; `drop_completed` remained disabled for creep rewards.
- `tests/rga_testing/validation/CreepsProbe.tscn`: `CreepsProbe: PASS (spawned 4)`, `errors: []`.
- `tests/rga_testing/validation/VeyraHardenCanonicalStackProbe.tscn`: `VeyraHardenCanonicalStackProbe: PASS`, `errors: []`; canonical Aegis stacks drove the Harden max-HP gain with legacy stacks held at 0.
- `tests/rga_testing/validation/KytheraSiphonCanonicalStackProbe.tscn`: `KytheraSiphonCanonicalStackProbe: PASS`, `errors: []`; canonical Aegis stacks drove Siphon drain and MR gain with legacy stacks held at 0.
- `tests/rga_testing/validation/CashmereLedgerCanonicalStackProbe.tscn`: `CashmereLedgerCanonicalStackProbe: PASS`, `errors: []`; canonical Arcanist stacks drove the Ledger damage path with legacy stacks held at 0.

This refresh keeps the current item/reward surface aligned with the existing live-renderer item/trait screenshots while preserving the known MCP dummy-framebuffer limitation.

## Current Combat Feedback And Stats UI Smoke Refresh

Fresh MCP debug validation on 2026-06-26 rechecked combat resolution feedback, watchdog fallback, standalone combat startup, duplicate scoreboard labels, and stats-panel interaction depth:

- `tests/visual/CombatWatchdogSmoke.tscn`: `CombatWatchdogSmoke: OK`, `errors: []`.
- `tests/visual/CombatResolvingFeedbackSmoke.tscn`: `CombatResolvingFeedbackSmoke: OK`, `errors: []`.
- `tests/visual/CombatViewThemePlaytest.tscn`: `CombatViewThemePlaytest: OK elapsed=2.00`, `errors: []`.
- `tests/visual/ScoreboardDuplicateDisambiguationSmoke.tscn`: `ScoreboardDuplicateDisambiguationSmoke: OK`, `errors: []`; the MCP dummy framebuffer skipped fresh duplicate-row PNG capture.
- `tests/visual/StatsPanelClickSmoke.tscn`: `StatsPanelClickSmoke: OK`, `errors: []`.
- `tests/visual/StatsPanelDeepCapture.tscn`: `StatsPanelDeepCapture: OK output=C:/Users/Flipm/Documents/gamble-battle/outputs/visual_iter/stats_panel_pass`, `errors: []`; the harness skipped fresh PNGs under the MCP dummy framebuffer, skipped second combat enemy selection because only one enemy actor was available, and still verified team metrics, 3s window state, expanded scoreboard state, player/enemy unit selection, scoreboard values, and combat-state activity.

This refresh keeps the current combat feedback and stats UI evidence current after the item/reward pass. It does not replace the existing live-renderer duplicate-scoreboard screenshot or older combat UI visual evidence.

## Current System Menu Visual Recheck

Fresh OS-window evidence was generated on 2026-06-25 with the ignored hold scene `outputs/audit_playtest/CurrentSystemMenuVisualHold.tscn`.

Generated files:
- `outputs/audit_playtest/current_system_menu_visual/unit_select_system_menu_lighter_backdrop.png`
- `outputs/audit_playtest/current_system_menu_visual/current_system_menu_summary.json`
- `outputs/audit_playtest/current_system_menu_visual/notes.md`

Result:
- The accepted screenshot shows the System panel centered over the Unit Select screen. The underlying roster, detail panel, and disabled Start Game action remain visible enough for context while the modal remains the focal layer.
- The summary confirms `overlay_visible=true`, `unit_select_visible=true`, `tree_paused=true`, `system_menu_button_visible=false`, and `backdrop_alpha=0.54`.
- `godot-ai game_capture_ready` stayed false again, so accepted visual proof came from OS-window capture of the visible `Gamble Battle (DEBUG)` process.
- This refresh closes the older lighter-backdrop visual caveat for the Unit Select system-menu state; `ExitFlowSmoke` remains the behavioral proof for Unit Select, CombatView, resume, new-run, return-title, and loss-overlay menu-blocking behavior.

## Current Shop Spacing And First-Fight Placeholder Recheck

Fresh evidence was generated on 2026-06-25 after the bottom-band spacing pass:
- `tests/visual/UIThemeSmoke.tscn` printed `UIThemeSmoke: OK` with `errors: []`. The smoke now asserts shop-card horizontal gutters of at least 16 px, command-strip separation of at least 16 px, BottomStorageArea separation of at least 14 px, a single wide fixed opening-fight placeholder with a stronger border, larger `OPENING FIGHT` label, larger `Win this opener to unlock the shop` hint, interactive cursor/focus behavior, and a visible explanatory message when the locked placeholder is clicked.
- `tests/visual/OpeningFightVisualSmoke.tscn` printed `OpeningFightVisualSmoke: OK` with `errors: []`. The legacy MCP run skipped PNG capture under the dummy framebuffer, and a live Godot-AI/OpenGL run saved current copy screenshots under `outputs/visual_iter/opening_fight_copy_pass/`.
- `tests/visual/ActualRunLoopSmoke.tscn` printed `ActualRunLoopSmoke: OK` with `errors: []`, preserving starter selection, first-board drag, repeated loss/New Game resets, forced opener, first shop purchase, deploy prompt, bench-to-board movement, and second-fight resolution.
- `tests/visual/RapidShopPressureSmoke.tscn` printed `RapidShopPressureSmoke: OK purchases=5 deployed_board=6` with `errors: []`, promoting the core rapid-shop pressure path into tracked validation: five rendered card purchases in one burst, five current `SOLD` / `On bench` placeholders, no shop errors, five bench-to-board deploys through global mouse-release input, and a resolved follow-up fight.
- `outputs/audit_playtest/RapidShopInputAudit.tscn` printed `RapidShopInputAudit: OK findings=0` with `errors: []`, preserving same-frame rendered-card burst buying, sold placeholders, deployment guidance, five bench-to-board deploys, and post-burst fight resolution.
- Godot-AI game screenshots were still blocked by `_mcp_game_helper` registration timeout, so accepted visual proof came from the OS-window capture helper, matching the earlier live-window fallback path.

Accepted live-window files:
- `outputs/audit_playtest/shop_spacing_recheck_2026_06_25/06_forced_first_fight_retry.png`: Bonko forced opener at 1920x1080 after the spacing/contrast pass. The current branch keeps that deliberate locked state and now frames it with `OPENING FIGHT` / `Win this opener to unlock the shop` copy.
- `outputs/audit_playtest/shop_spacing_recheck_2026_06_25/08_round2_shop_wait.png`: first real Round 2 shop after the opener. The command strip still fits above the shop, with wider shop-card gutters and clearer spacing around `Start Battle`, gold, level, and betting.

Current copy-refresh live-renderer files:
- `outputs/visual_iter/opening_fight_copy_pass/01_opening_fight_locked_shop.png`: current locked opener with `Start Opening Fight`, `OPENING FIGHT`, `Win this opener to unlock the shop`, disabled shop controls, and fixed `Opening bet: 1`.
- `outputs/visual_iter/opening_fight_copy_pass/02_opening_fight_feedback.png`: same opener after activating the locked placeholder, with visible `Opening fight is fixed. Win it to unlock the shop.` feedback.

Implication:
- The older "shop/start hit targets need more breathing room" finding is no longer a pure missing-fix item. Current behavior and visual evidence support a narrower preservation note: keep the wider gutters, command spacing, and explicit forced-first-fight placeholder during future shop/UI passes.
- The remaining manual-play risk is natural human-speed drag/click feel under pressure, not known transaction corruption, committed global-release deploy correctness, or an unreadable opener placeholder.

## Current Real-Window Deploy Drag Release Recheck

Fresh ignored hold-scene evidence was generated on 2026-06-25 under `outputs/audit_playtest/current_deploy_drag_recheck/` using `outputs/audit_playtest/CurrentDeployDragHold.tscn` and `outputs/audit_playtest/current_deploy_drag_actions.ps1`.

Diagnostic files:
- `01_round2_shop_before_buy.png`: real debug-window shop before purchase, with Bonko on board, a populated level-1 shop, and `Start Battle`.
- `02_after_os_shop_click.png`: OS-coordinate click bought Morrak, put it on bench, showed `Bought Morrak. Drag it from bench to board.`, and left the board as `["bonko"]`.
- `03_after_os_bench_to_board_drag.png`: first OS drag attempt did not deploy; summary still had bench `["morrak"]`, board `["bonko"]`, and `completion_reported=false`.
- `05_focus_reset_after_failed_drag.png`: after an explicit-move retry and focus reset, the screenshot showed the drag ghost stuck over the board while the bought unit remained on bench. This narrowed the bug to drag release/end handling rather than shop purchase or board target geometry.

Fix and accepted files:
- Root cause: `DragAndDroppable` only ended an active drag from source `gui_input`; a real OS release over a different control could miss the source release path and leave the drag ghost alive.
- Fix: `DragAndDroppable` now enables global `_input` handling only while `_dragging`, updates the ghost on global mouse motion, and ends the drop on global left-button release before disabling that listener.
- `06_after_patch_shop_before_buy.png`: patched run reached Stage 1 Round 2/6 with 3 gold, Bonko on board, and visible cost-1 shop offers.
- `07_after_patch_os_shop_click.png`: OS click bought Cashmere to bench, lowered gold to 2, and showed the deploy prompt.
- `08_after_patch_os_bench_to_board_drag.png`: OS drag moved Cashmere from bench to board; summary confirms `board_after=["bonko","cashmere"]`, `bench_after=[]`, `completion_reported=true`, no shop errors, and `Start Battle` still visible.

Validation:
- `tests/visual/DragGlobalReleaseSmoke.tscn`: `DragGlobalReleaseSmoke: OK`, `errors: []` via MCP `get_debug_output()`.
- `tests/visual/AxiomRetryEconomySmoke.tscn`: `AxiomRetryEconomySmoke: OK` in the current `godot.log`.
- `tests/visual/ActualRunLoopSmoke.tscn`: first post-fix attempt failed before the deploy portion with `shop cycle did not open a post-fight shop` after five loss-reset cycles, but a legacy MCP rerun immediately afterward completed with `ActualRunLoopSmoke: OK` and `errors: []`. Treat the first result as transient, not evidence against the drag-release fix.

Audit implication: first-purchase bench deployment is now covered by both behavioral smoke and physical OS-window evidence. Future drag work should preserve the global-release lifecycle and focus on pressure polish, not the core drop correctness.

## Current RoleMatrix Accepted-Miss Recheck

Fresh RoleMatrix evidence was regenerated again on 2026-06-25 with `tests/rga_testing/ci/RoleMatrixSmoke.tscn`. The MCP debug run completed with `RoleMatrixSmoke: PASS (22 units)` and `errors: []`. The current report files live under `user://identity_reports/*.json`, and one stale `faeling.json` from 2026-06-23 is ignored by the accepted-miss exporter. The refreshed parser output can be regenerated from current report JSON with `tests/rga_testing/tools/Export-AcceptedMisses.ps1`, which writes the stable working export under `outputs/audit_playtest/rga_accepted_misses_current/`; older dated folders remain historical snapshots.

Latest residual refresh on 2026-06-26 reran focused Kythera fortification and full all-unit RoleMatrix proof. `TeamFortificationBuffGoalProbe.tscn`, `KytheraSiphonCanonicalStackProbe.tscn`, `RoleMatrixProbe6v6Kythera.tscn`, and `RoleMatrixSmoke.tscn` all passed with `errors: []`; `Export-AcceptedMisses.ps1` reported `reports=22`, `spans=2`, `ramp_spans=0`, and `non_ramp_goal_ramp=0`; `AcceptedMissGuardCoverageSmoke.tscn` passed with `gap_kinds=2`, `accepted_spans=2`, and `mapped_gap_kinds=2`. Kythera's former fortification buff-uptime row is closed through source-owned same-team/self fortification telemetry; the remaining rows are Totem direct peel-save/interrupt proof debt.

Follow-up Totem goal-alignment validation on 2026-06-26 added `TotemGoalAlignmentProbe.tscn`. It reruns real Totem 6v6 `peel`/`threat` rows, preserves the current `support.peel_carry` aggregate pass plus failed save/interrupt spans, and proves a temporary `support.team_amplification` primary-goal contract passes on the same rows through buff uptime, team amp magnitude, and amp output. This creates a validated design-choice path without changing the actual Totem identity.

Earlier refresh after the Wombo third-path diagnostic cleanup: a new MCP run wrote fresh JSON reports for all 22 current units on 2026-06-26. Direct console verification found every current role, primary-goal, and approach verdict at `PASS`, and `get_debug_output()` returned `errors: []`. `Export-AcceptedMisses.ps1` regenerated the artifact with `reports=22`, `spans=14`, `ramp_spans=0`, and `non_ramp_goal_ramp=0`; `AcceptedMissGuardCoverageSmoke.tscn` then printed `gap_kinds=12 accepted_spans=14 mapped_gap_kinds=12` and `PASS` with `errors: []`.

Follow-up pick-burst scenario-cap validation on 2026-06-26 kept `burst` preferred for `mage.pick_burst` identities when the smoke label set was capped. `PickBurstScenarioLabelSmoke.tscn` printed Volt-style labels as `["neutral", "counterplay", "burst"]` while preserving the prior generic defensive preference for non-pick-burst rows. That fresh `RoleMatrixSmoke.tscn` rerun completed with `RoleMatrixSmoke: PASS (22 units)` and `errors: []`; Volt exercised `neutral`, `counterplay`, and `burst` scenarios in the all-unit smoke. At that stage `Export-AcceptedMisses.ps1` still reported `reports=22`, `spans=14`, `ramp_spans=0`, and `non_ramp_goal_ramp=0`, so the Cashmere/Volt pick-burst rows were still kill-securing/scenario debt. The later mage burst scenario-pack pass below closed that debt.

Follow-up mage burst scenario-pack validation on 2026-06-26 adds a mage `burst`/`pick_burst_window` pack so `mage.pick_burst` rows no longer fall back to generic mage map params when the all-unit smoke requests `burst`. `PickBurstScenarioLabelSmoke.tscn` now also proves mage `burst` resolves to the back-lane `pick_burst_window` pack and that pick-burst burst plans wound enemy targets while readying the audited caster. A fresh `RoleMatrixSmoke.tscn` still passed all 22 units with `errors: []`; Cashmere and Volt now clear `goal_pick_burst_kill_count`, so pick-burst kill count is no longer accepted-miss debt.

Follow-up skirmish-dive scenario-pack validation on 2026-06-26 adds a brawler `counter`/`dive_window` pack for `brawler.skirmish_dive` audit contexts. `SkirmishDiveScenarioPackSmoke.tscn` proves Bo-style identities request `counter`, non-skirmish brawlers do not, and brawler `counter` uses `dive_window`. A fresh `RoleMatrixSmoke.tscn` still passed all 22 units with `errors: []`; `Export-AcceptedMisses.ps1` still reports `reports=22`, `spans=14`, `ramp_spans=0`, and `non_ramp_goal_ramp=0`, so Bo's backline-contact row is now live kit/targeting/scenario debt rather than missing metric support or missing brawler dive-map support.

Follow-up skirmish-dive metric validation on 2026-06-26 now scores Bo's `brawler.skirmish_dive` contact span from either non-frontline damage share or direct `BacklineAccessKernel` entry telemetry. `SkirmishDiveBacklineGoalProbe.tscn` proves both evidence paths and preserves an all-frontline/no-access failure control. A fresh `RoleMatrixSmoke.tscn` still passed all 22 units with `errors: []`; Bo now reports `goal_skirmish_dive_backline_contact_proxy: 0.33 vs 0.25 -> OK` with `reason=direct_backline_access`. `Export-AcceptedMisses.ps1` now reports `reports=22`, `spans=7`, `ramp_spans=0`, and `non_ramp_goal_ramp=0`, so Bo's backline-contact row is closed as accepted-miss debt.

Follow-up team-fortification scenario-pack validation on 2026-06-26 added a tank `fortify`/`fortification_window` pack for `tank.team_fortification` audit contexts. `TeamFortificationScenarioPackSmoke.tscn` proves Kythera-style labels keep `neutral`, `counterplay`, `fortify`, and `burst`, Veyra-style labels keep `neutral`, `peel`, `fortify`, and `burst`, and non-fortification tanks do not request `fortify`. At that interim stage, a fresh `RoleMatrixSmoke.tscn` still passed all 22 units with `errors: []` while `Export-AcceptedMisses.ps1` reported `reports=22`, `spans=14`, `ramp_spans=0`, and `non_ramp_goal_ramp=0`; the later source-owned self/team fortification pass closed Kythera's buff-uptime row, so only Totem's two support/peel goal spans remain.

Follow-up support carry-threat scenario-pack validation on 2026-06-26 adds a support `threat`/`carry_threat_window` pack for `support.peel_carry` audit contexts. `SupportCarryThreatScenarioPackSmoke.tscn` proves Totem-style labels keep `neutral`, `peel`, and `threat`, while Axiom-style support amplification and Veyra-style non-support CC-immunity rows do not request `threat`. A fresh `RoleMatrixSmoke.tscn` still passed all 22 units with `errors: []`; Totem's full run includes `threat` and preserves the live support/peel rows as scenario debt rather than missing metric support or missing carry-threat scenario-pack support. Later CC-immunity evidence cleanup keeps low `subject_cc_prevented_as_target` diagnostic when direct CC-immunity grants plus cooldown/threat pressure prove the aggregate, leaving Totem's current accepted rows at goal-level peel saves and interrupt events.

Follow-up tank engage scenario-pack validation on 2026-06-26 adds a tank `engage`/`engage_window` pack for `tank.initiate_fight` and engage-tagged tank audit contexts. `TankEngageScenarioPackSmoke.tscn` proves Grint-style labels keep `neutral`, `counterplay`, `engage`, and `burst`, Brute-style engage labels keep `engage`, `counterplay`, and `peel`, and non-engage fortification tanks do not request `engage`. A later Grint diagnostic cleanup closed the single-target initiate-success accepted miss by keeping `goal_initiate_fight_engage_success_targets` diagnostic when engage distance plus first-action timing prove `tank.initiate_fight`, so no Grint accepted-miss row remains in the current export.

Follow-up marksman sustained scenario-pack validation on 2026-06-26 adds a marksman `sustained`/`marksman_sustained_pressure` pack for `marksman.sustained_dps` audit contexts. `MarksmanSustainedScenarioPackSmoke.tscn` proves Sari-style labels keep `neutral`, `counterplay`, `kite`, and `sustained`; Teller-style AoE sustained labels keep `neutral`, `clustered`, `clustered_alt`, `sustained`, `kite`, and `burst`; and non-sustained Nyxa-style marksmen do not request `sustained`. A fresh `RoleMatrixSmoke.tscn` still passed all 22 units with `errors: []`; Sari's full run now includes `sustained` and clears `goal_marksman_sustained_dps_team_damage_share` at `0.27`. Follow-up sustained-window evidence then closes Teller's remaining accepted miss: Teller's whole-fight team damage share remains diagnostic at `0.20 / 0.25`, while `goal_marksman_sustained_dps_sustained_3_10s_team_share` passes at `0.31 / 0.25` and `goal_marksman_sustained_dps_sustained_3_10s_rate` passes at `155.14 / 8.0`. `MarksmanSustainedWindowKernelProbe.tscn` guards the windowed telemetry and diagnostic demotion path. `Export-AcceptedMisses.ps1` now reports `reports=22`, `spans=4`, `ramp_spans=0`, and `non_ramp_goal_ramp=0`, so no marksman sustained accepted-miss row remains.

Follow-up instrumentation on 2026-06-25 moved the accepted-miss detail into the saved report JSON itself. `ProbeReportCompiler` now writes `diagnostics.lower_level_fail_span_count`, `diagnostics.lower_level_fail_spans`, and per-verdict `failed_span_count` / `span_details` fields under `user://identity_reports/<unit>.json`. A fresh MCP `RoleMatrixSmoke` rerun again completed with `RoleMatrixSmoke: PASS (22 units)` and `errors: []`.

A second 2026-06-25 report-compiler pass filtered side-aggregate diagnostics to the audited unit's side. This removed opponent-side/control noise such as `b_unit_pass_count` and suffix labels such as `magic_share_med_b` from saved per-unit reports while preserving raw console visibility. That pass found 22 current reports, 0 reports missing diagnostics, 0 reports with `b_unit_pass_count` in diagnostics, 0 reports with side-B suffix labels in diagnostics, and 105 subject-side accepted lower-level fail spans.

A third 2026-06-25 goal-primary instrumentation pass tightened ramp diagnostics to identities that explicitly carry the `ramp` approach. Non-ramp attrition or marksman identities can still pass their goals through frontline damage share, sustain, survival, range, and uptime evidence, but they no longer inflate the accepted-miss backlog with non-applicable `goal_*_ramp_*` failed spans. `GoalPrimaryRampApplicabilitySmoke` covers both sides: a non-ramp attrition identity emits no goal ramp spans, while a ramp-tagged identity still reports direct ramp evidence.

A fourth 2026-06-25 RoleMatrix scenario pass added live counterplay response rows for debuff/lockdown identities. Quick probes now add a `counterplay` pack when requested, full 6v6 probes force a Totem/Veyra response shell for that label, and non-counterplay quick metrics are evaluated against baseline rows while `approach_debuff`/`approach_lockdown` still see the combined baseline-plus-counterplay rows for scenario deltas. The MCP `RoleMatrixSmoke.tscn` rerun completed with `RoleMatrixSmoke: PASS (22 units)` and `errors: []`; Brute and Grint now exercise live `counterplay` scenarios, and Grint's prior counterplay accepted-miss group is closed.

Aggregate result:
- Every current unit role verdict is still `PASS`, and all assigned primary goals and approaches passed in the smoke run.
- Raw console output still includes lower-level `-> FAIL` spans accepted by aggregate verdicts, including opponent-side aggregate/control spans that are still printed for visibility.
- The saved report JSON now records the subject-side backlog directly: 2 lower-level fail spans, all goal spans. Future accepted-miss audits should prefer this JSON field over parsing console text or `godot.log`.
- 1 of 22 current units has at least one subject-side accepted lower-level fail span in saved reports: Totem. Axiom, Berebell, Bo, Bonko, Brute, Cashmere, Grint, Hexeon, Korath, Kythera, Luna, Morrak, Mortem, Nyxa, Paisley, Repo, Sari, Teller, Veyra, Volt, and Vykos are currently the units without a saved lower-level accepted miss.
- `tests/rga_testing/tools/Export-AcceptedMisses.ps1` now exports the ignored audit CSV and summary from `user://identity_reports/*.json`, keeping the saved artifact aligned with the subject-side report semantics instead of stale raw console counts. The export includes `topic`, `audit_gap_kind`, and `audit_next_action` for every recognized accepted span, plus `support_peel_triage`, `support_peel_gap_kind`, and `support_peel_next_action` fields for the support/peel bucket.
- Lowest role pass rates: Hexeon assassin 0.50; Brute, Grint, Korath, Kythera, Repo, and Veyra tank at 0.67; Axiom support, Faeling mage, and all brawlers at 0.75.
- Role-family averages from the fresh reports: assassin 0.50, brawler 0.75, support 0.88, mage 0.95, marksman 0.89, and tank 0.67.

Recurring accepted-miss buckets from the refreshed subject-side report evidence, using the primary topic classification in `rga_accepted_misses_summary.json`:
- Support/peel/cleanse/CC is now the only remaining accepted-miss bucket at 2 spans. Soft-peel identities no longer persist missing hard-peel cleanse/CC-immunity subspans unless their identity claims `support.peel_carry` or `cc_immunity`, low team-save fallback rows are now diagnostic when direct ally-protection/support evidence proves the aggregate, low EHP fallback rows are now diagnostic when effective HPS, ally-protection, or support-event evidence proves the aggregate, low cooldown-trade efficiency rows are now diagnostic when direct cooldown trade, threat-draw caster, and key-threat-share evidence prove the aggregate, low counterplay response rows are now diagnostic when direct debuff/lockdown evidence proves the aggregate, low frontline/body-block rows are now diagnostic when prevention plus frontline presence proves the goal, missing Korath redirect submodes are diagnostic when body-block evidence proves `approach_redirect`, low execute bonus-share rows are diagnostic when real execute bonus damage plus low-HP kill conversion proves `approach_execute`, low ramp-stack rows are diagnostic when direct ramp events plus peak/window duration prove the aggregate, and Wombo's missing third path is diagnostic when the other two evidence paths prove the 2-of-3 aggregate. `PeelTeamSaveProxyProbe.tscn` proves the shared team-save proxy can pass `approach_peel`, `role_support_identity`, and `support.peel_carry` from one derived peel save, and `SoftPeelTeamSaveAcceptedMissProbe.tscn` proves real Axiom/Paisley soft-peel rows can pass from team-save evidence while aggregate ally-protection controls keep low team-save fallback rows diagnostic. Totem's remaining goal-level peel-save and interrupt rows remain live peel-carry scenario debt, while its approach and support-role team-save/EHP fallback rows, CC-prevention row, and cooldown-efficiency rows are diagnostic. `TotemCleanseLiveProbe.tscn` now proves the real Cleanse cast removes a carry debuff and passes aggregate support/peel consumers while still emitting no direct save/interrupt evidence. `TotemPeelCarryAcceptedMissProbe.tscn` proves real Totem `support.peel_carry` rows can pass all support/peel consumers with team-save, EHP, CC-prevention, interrupt, and cooldown evidence, while aggregate direct-protection controls preserve the remaining goal-level miss shape. Kythera/Sari debuff and Brute/Volt lockdown response rows are closed as accepted-miss debt because direct debuff/lockdown evidence keeps the aggregates passing and the low response-pressure rows are diagnostic-only.
- Marksman damage-share accepted-miss debt is closed. The former three auxiliary candidate/team-side role share rows on Nyxa/Sari/Teller, two auxiliary subject-owned role share rows on Sari/Teller, and three subject-side backline-pressure role rows on Nyxa/Sari/Teller are emitted as diagnostics instead of accepted misses. Sari clears the direct goal damage-share span in the sustained-pressure context, and Teller's whole-fight damage-share row is diagnostic when sustained-window team share and sustained rate pass. `MarksmanPositioningRoleProbe.tscn` now proves `role_marksman_identity` can pass through sustained DPS leadership plus direct backline/ranged presence while keeping low candidate/subject damage-share and alternate side-backline rows diagnostic-only. `MarksmanSustainedDpsGoalProbe.tscn` now proves real Sari/Teller `marksman.sustained_dps` goal rows can consume direct team damage share, range/time-on-target, survival, and Sari ramp-state evidence; `MarksmanSustainedWindowKernelProbe.tscn` proves `early_0_3s_*` and `sustained_3_10s_*` telemetry can close burst-biased sustained-DPS audits; and `MarksmanSustainedScenarioPackSmoke.tscn` proves the all-unit smoke requests a dedicated sustained-pressure map for those rows. This keeps "low team share" or low side-level backline share from implying the role metric failed when sustained leadership plus ranged/time-on-target evidence already proved marksman identity.
- Tank/frontline semantics no longer have a remaining engage accepted miss. Brute/Repo body-block and Brute damage-share rows are diagnostic when prevention plus frontline-position evidence proves `tank.frontline_absorb`. `FrontlineBodyBlockGoalProbe.tscn` still proves real redirect-kernel telemetry feeds Brute's body-block event and prevented-damage goal spans, while event-only, damage-only, and weak-prevention controls fail. `BruteFrontlineShareGoalProbe.tscn` proves Brute's frontline damage-taken-share span can pass from direct incoming-share evidence and guards the low-share/no-body-block diagnostic fallback. Korath's target-swap, explicit threat-swap, and taunt-command submode rows are diagnostic when body-block evidence already proves `approach_redirect`; `KorathRedirectAcceptedMissProbe.tscn` proves those spans can pass from direct redirect evidence and preserves the body-block diagnostic fallback. `GrintEngageSuccessGoalProbe.tscn` proves Grint's initiate-fight success-target span can pass from direct multi-target engage evidence, while distance plus first-action evidence keeps the single-target success span diagnostic instead of accepted-miss debt. `TankEngageScenarioPackSmoke.tscn` proves all-unit selection now gives Grint a dedicated front-lane `engage_window` without dropping counterplay or burst coverage, so the row is not missing tank engage scenario-pack support.
- Pick-burst kill-count debt is closed. `AssassinOpeningRoleProbe.tscn` now proves real `BacklineAccessKernel` position telemetry can feed Hexeon's subject-level `subject_first_backline_frac` assassin role span and keep the side-level `a_first_frac` proxy diagnostic with `alternate_subject_backline_evidence_satisfied` when the audited subject proves direct access, while a late/access-losing control fails. The Hexeon opening-presence row is now diagnostic fallback coverage rather than live accepted-miss debt. `BurstWindowKernelProbe.tscn` now proves concentrated combat-pattern hits record peak 1s share, peak DPS, overkill, and counterplay-window telemetry and pass `approach_burst`; it also proves low peak-share rows remain diagnostic when peak DPS already proves the approach, so the old Berebell/Hexeon/Mortem/Vykos burst peak-share accepted-miss group is closed. `PickBurstKillGoalProbe.tscn` proves lethal combat-pattern telemetry feeds `goal_pick_burst_kill_count` for the real Cashmere `mage.pick_burst` goal, and `PickBurstScenarioLabelSmoke.tscn` guards the all-unit smoke label cap plus the wounded-target/full-mana scenario proof. The current RoleMatrix run confirms Cashmere and Volt now clear `goal_pick_burst_kill_count`. `ExecuteBonusApproachProbe.tscn` now proves real Hexeon/Morrak `execute` approach rows can consume direct execute-bonus events, bonus damage share, low-HP kill conversion, and overkill guardrails; low bonus-share rows are diagnostic when real bonus damage plus low-HP conversion proves execute, while zero-bonus aggregate controls still preserve a failed bonus-share span. `WomboComboGoalProbe.tscn` now proves real Luna/Paisley `mage.wombo_combo_burst` goal rows can consume direct combat-pattern peak-share, multi-target evidence, and control-mobility CC event evidence; Luna's missing CC-sync proxy and Paisley's low peak-share row are now diagnostic fallback coverage because the other two Wombo paths satisfy the aggregate.
- `AoeTargetingKernelProbe.tscn` now guards the AoE evidence path directly: grouped same-time hits record targets-hit median, max targets hit, multi-target group count, and AoE DPS, and `approach_aoe` passes on that telemetry. `AoeMultiTargetApproachProbe.tscn` proves real Luna/Morrak/Nyxa/Paisley/Teller rows can still pass on passing target-median spans, and that low-median aggregate controls pass through max-target evidence while `subject_targets_hit_median` is emitted as diagnostic. `AoeClusteredScenarioProbe.tscn` verifies the live clustered RoleMatrix contexts pass through max-target and/or AoE-DPS evidence with the all-hit median reported as diagnostic instead of a failed accepted span. The old `multi_target_coverage_below_target` group is therefore removed from the accepted-miss export.
- Ramp-state accepted-miss debt is closed. `RampApproachProbe.tscn` now proves real Sari/Veyra `ramp` approach rows can consume direct ramp-state events, full stack max, peak duration, and window duration; its aggregate-pass controls keep low `subject_ramp_stack_max` rows diagnostic when ramp events plus peak/window duration prove the aggregate. `MarksmanSustainedDpsGoalProbe.tscn` proves Sari's goal-level ramp-stack span can pass from direct `ramp_state_changed` telemetry and keeps an aggregate-pass low-ramp control diagnostic with `goal_marksman_sustained_dps_ramp_stack_max`. Prior non-ramp attrition ramp noise is gone, the prior 3-row ramp-stack group is diagnostic fallback coverage, and the export classifier also avoids treating `sustained_dps` as sustain/survival.
- The old 6-span sustain/survival EHP fallback bucket is closed. `EhpRatioPathProbe.tscn` now proves all four EHP ratio paths can pass from aggregate unit healing/shields, source-owned support maps, and team EHP totals, and also proves low EHP rows are diagnostic when alternate effective-HPS, ally-protection, or support-event evidence satisfies the aggregate. `RepositionMovementKernelProbe.tscn` now proves direct movement signals can pass `approach_reposition` through max-step, post-cast displacement, and total-path spans, and the old Berebell/Bo/Mortem reposition group is closed because low max-step/post-cast rows are diagnostic when total path distance satisfies the k-of-n approach. `SkirmishDiveBacklineGoalProbe.tscn` now proves hit attribution and direct `BacklineAccessKernel` entry telemetry can pass Bo's `brawler.skirmish_dive` backline-contact span, while an all-frontline/no-access control fails; `SkirmishDiveScenarioPackSmoke.tscn` proves the all-unit `counter` label gives Bo a proper brawler `dive_window` context, and the current RoleMatrix run now clears `goal_skirmish_dive_backline_contact_proxy` at `0.33` with `reason=direct_backline_access`. `BrawlerDirectAttritionProbe.tscn` now proves the role metric can pass direct attrition through frontline-share, sustain EHP, prevention EHP, support healing/shielding, and pressure evidence including burst pressure; the compiler only saves direct-attrition diagnostics for attrition-DPS brawlers. Berebell and Vykos satisfy direct attrition through burst pressure plus sustain, Bo's non-attrition brawler row is suppressed, and Mortem now clears direct attrition through prevented-damage EHP. `MagePeriodicityKernelProbe.tscn` now proves magic hit components can pass `role_mage_identity` through top-window magic share and peak-over-mean evidence, and the old Luna/Paisley/Volt magic-share group is closed because low share is diagnostic when alternate peak-over-mean evidence proves mage periodicity.
- The old residual `other` bucket is closed; assassin opening presence is diagnostic fallback coverage when subject-level access passes, and Kythera's former team-fortification buff-uptime row now passes. `EngageCcTimingKernelProbe.tscn` proves direct control-mobility signals can pass `approach_engage` through median/peak early displacement, first action, and first-CC timing, and Grint's expanded focused 6v6 proof keeps low median displacement and missing first-CC rows diagnostic when peak displacement plus first-action evidence satisfies the engage approach. `TeamFortificationBuffGoalProbe.tscn` now proves source-owned `buff_applied` telemetry feeds Kythera's `tank.team_fortification` fortification span for same-team self and ally targets, while an aggregate EHP/prevention pass keeps the buff span failing when no fortification telemetry is present; `TeamFortificationScenarioPackSmoke.tscn` proves all-unit selection adds a fortify context without replacing existing defensive/counterplay labels. The current RoleMatrix run records Kythera `goal_team_fortification_buff_uptime_targets: 13.00` with `reason=source_owned_team_fortification_target`, so Kythera's row is no longer accepted-miss debt.
- Opponent-side aggregate noise is now filtered out of saved reports: `b_unit_pass_count` and `_b` suffix labels no longer appear in `diagnostics.lower_level_fail_spans`.

General accepted-miss gap-kind triage from the current export:
- No non-support or cross-role accepted-miss gap kind remains. The old assassin opening presence, marksman sustained-DPS share, Bo dive-contact, direct-attrition, pick-burst kill-count, Grint engage-success, effective-health, frontline/body-block fallback, Korath redirect-submode, ramp-stack, execute bonus-share, Wombo third-path, and Kythera fortification buff-uptime groups are now diagnostic fallback coverage or closed scenario proof instead of accepted-miss debt.
- `accepted_gap_kind_summary.csv` now rolls up both accepted spans into 2 gap kinds with affected topics, units, labels, block types, and a representative next action. The same detail rows are embedded as `audit_gap_kind_details` in `rga_accepted_misses_summary.json`, while support-specific `support_peel_gap_kind_counts` remains the focused view for the support/peel bucket. `AcceptedMissGuardCoverageSmoke.tscn` now verifies the regenerated rollup still has 2 gap kinds and 2 spans, and that every gap kind maps to committed synthetic proof, scenario-pack coverage, focused live residual probes, and the Totem goal-alignment decision probe.
- Focused residual-row triage now lives in `docs/rga/accepted_miss_residual_audit_2026-06-26.md`, with current report evidence, closure criteria, and the guard coverage mapping for each remaining accepted miss.

Support/peel/cleanse/CC bucket triage from the current saved report JSON:

The `support_peel_triage` column in `accepted_lower_level_fail_spans.csv` and `support_peel_triage_counts` in `rga_accepted_misses_summary.json` now regenerate these groups directly from current reports. The same export also adds `support_peel_gap_kind` and `support_peel_next_action`. Current gap-kind counts are: peel-carry goal save proxy absent 1 and peel-interrupt context absent 1.

| Area | Rows | Current evidence gap | Audit decision |
| --- | ---: | --- | --- |
| Totem `support.peel_carry` with `peel,cc_immunity,amp` | 2 | The all-unit RoleMatrix row still lacks goal-level team peel saves and interrupt events, even though it has direct shield/amp/CC-immunity and cooldown-pressure evidence. The latest all-unit row includes the `threat` carry-threat scenario context, approach/support-role team-save fallback rows are diagnostic when direct protection proves those aggregates, low `subject_cc_prevented_as_target` is diagnostic when direct CC-immunity grants plus cooldown/threat pressure prove the aggregate, and cooldown-trade efficiency is diagnostic when absolute trade, threat-draw caster, and key-threat-share evidence pass. | This is save/interrupt tuning debt in the all-unit smoke, not proof that Totem support/peel telemetry is absent or that carry-threat scenario coverage is missing. `TotemCleanseLiveProbe.tscn` is now the explicit real-ability debt control: Cleanse removes the carry debuff and passes aggregate consumers, but still records no save/interrupt evidence. `TotemPeelCarryAcceptedMissProbe.tscn` guards the metric/accepted-miss shape, and `SupportCarryThreatScenarioPackSmoke.tscn` guards the all-unit `threat` context. |

Implication:
- The current all-unit RGA gate is green and should not block the starter/shop audit.
- The pass is threshold/aggregate based, not proof that every role/goal/approach semantic subspan is expressed cleanly. Treat the accepted spans as a balance, scenario, and identity-tag backlog before declaring identity semantics fully proven.
- `tests/rga_testing/validation/CounterplayContextTriageSmoke.tscn` guards the synthetic counterplay interpretation, `CounterplayAcceptedMissProbe.tscn` preserves the aggregate/control shape, and `RoleMatrixSmoke.tscn` now exercises live counterplay response rows. Grint's live row now passes, and Brute/Kythera/Sari/Volt low response rows are diagnostic; no debuff/lockdown counterplay accepted spans remain.

## Current Loss And Exit Modal Framebuffer Recheck

Fresh live-editor framebuffer evidence was generated on 2026-06-24 after the earlier dummy-renderer capture failures:
- `tests/visual/LossScreenSmoke.tscn` saved `outputs/visual_iter/loss_screen_pass/loss_overlay_modal_fixed.png` and printed `LossScreenSmoke: OK`.
- `tests/visual/ExitFlowSmoke.tscn` saved `outputs/visual_iter/exit_menu_pass/01_unit_select_system_menu.png`, saved `outputs/visual_iter/exit_menu_pass/02_combat_system_menu.png`, and printed `ExitFlowSmoke: OK`.

Visual read:
- The loss modal is centered, legible, and constrained to a modal frame; New Game is clearly visible. The synthetic test state leaves the scoreboard body almost blank, with only the `Scoreboard` heading visible, so real defeat screenshots should still be checked for populated scoreboard readability.
- The system menu is centered and legible from both Unit Select and CombatView. The backdrop now uses alpha `0.54` instead of the earlier near-black `0.78`, keeping the paused Unit Select or combat state visible enough for return-context while preserving modal focus. `ExitFlowSmoke` asserts the backdrop alpha remains between `0.45` and `0.62`.
- This recheck closes the earlier "loss/exit framebuffer unavailable" evidence gap for synthetic modal states; the following real-run capture adds a populated player damage row.
- The 2026-06-25 lighter-backdrop rerun completed with `ExitFlowSmoke: OK` and `errors: []`, but the current MCP display was dummy/headless and skipped fresh PNG capture. The existing 2026-06-24 PNGs remain the visual baseline for the old dim, not proof of the lighter backdrop.

## Current Real Loss Overlay Capture

Fresh live-editor evidence was generated with the ignored audit scene `outputs/audit_playtest/RealLossOverlayCapture.tscn`.

Generated files:
- `outputs/audit_playtest/real_loss_overlay_capture/axiom_real_loss_overlay.png`
- `outputs/audit_playtest/real_loss_overlay_capture/axiom_real_loss_overlay.json`
- `outputs/audit_playtest/real_loss_overlay_capture/bonko_stage2_no_loss_overlay.json`

Axiom first-loss result:
- The real defeat overlay is centered and legible.
- Summary labels at the time reported `Team Damage: 143`, `Team Healing: 0`, `Total Kills: 0`, and `Top Damage: Axiom (143)`.
- The visible player scoreboard row shows Axiom with 143 damage, so the populated player-row readability gap is closed for a simple one-unit defeat.
- The extracted label list also contained `Beegle` and `1.2k`, but that enemy row is not visible in the modal screenshot because the loss-screen scoreboard is non-expandable. That is probably intentional for modal containment, but it means the player cannot compare the enemy ledger from the defeat modal.
- The top-right `Menu` button remains visible behind the defeat overlay. It is outside the modal frame and reads as an active control even while the loss modal should own attention.

2026-06-25 player-only scoreboard fix:
- The loss modal titles the embedded scoreboard as player-only final-battle detail, disables enemy rows for the modal context, and clears hidden enemy row nodes instead of merely hiding the enemy column.
- `LossScreenSmoke` now uses a populated tracker with Axiom and an enemy row, then verifies Axiom is present while `Beegle` and `1.2k` are absent from all loss-screen label text.
- `StatsPanelClickSmoke` still passes, so regular combat stats/scoreboard behavior remains intact outside the defeat modal.
- The MCP run printed `LossScreenSmoke: OK` with `errors: []`; PNG capture was skipped because the current MCP display is dummy/headless, so this is behavioral evidence rather than fresh screenshot evidence.

2026-06-25 run-total stat fix:
- `StatsTracker` now maintains run totals for damage, healing, and kills until a new run resets the tracker totals.
- The defeat modal summary now reports `Run Damage`, `Run Healing`, `Run Kills`, and `Top Run Damage`, while the embedded ledger is labeled `Final Battle Damage`.
- `LossScreenSmoke` simulates an earlier Axiom damage/kills battle followed by a later final battle where the player has no damage. The smoke verifies the modal still reports `Run Damage: 143`, `Run Kills: 1`, and `Top Run Damage: Axiom (143)`.
- `StatsPanelClickSmoke` and `ActualRunLoopSmoke` both passed after the change, so regular combat ledger behavior and the Main-flow loss/reset path still work.

2026-06-25 behavioral fix:
- `Main.refresh_system_menu_state()` now treats `LossOverlayLayer` as an authoritative modal state: the top-right system Menu button hides, disables, and cannot be opened by Escape or direct system-menu calls while defeat is active.
- The combat controller calls the Main refresh hook immediately after creating `LossOverlayLayer`, so the real loss path updates without waiting for another screen transition.
- `ExitFlowSmoke` was extended to create a synthetic loss layer, verify the system Menu button hides, verify the system menu does not pause or overlay the defeat state, and verify `request_new_run()` clears the loss layer and returns to Unit Select.
- The MCP run printed `ExitFlowSmoke: OK` with `errors: []`; the runner skipped PNG captures because the current MCP display is dummy/headless, so this is behavioral evidence, not fresh screenshot evidence.

Bonko solo Stage 2 result:
- The same harness attempted a Bonko forced opener, then started the second fight without purchases.
- No loss overlay appeared within the capture timeout; the summary recorded `loss_overlay_visible=false`, `reason=loss_overlay_not_seen_after_second_fight`, `stage=2`, and `gold=3`.
- This is not enough to diagnose whether combat stalled, Bonko survived longer than the timeout, or the capture condition missed the state, but it keeps the Stage 2 no-resolution/late feedback concern alive under a current automated audit path.

## Current Loss Modal Visual Recheck

Fresh current-state visual evidence was generated on 2026-06-25 with the ignored hold scene `outputs/audit_playtest/CurrentLossModalVisualHold.tscn`.

Generated files:
- `outputs/audit_playtest/current_loss_modal_visual/current_loss_modal_window.png`
- `outputs/audit_playtest/current_loss_modal_visual/current_loss_modal_window_run_totals.png`
- `outputs/audit_playtest/current_loss_modal_visual/current_loss_modal_summary.json`
- `outputs/audit_playtest/current_loss_modal_visual/notes.md`

Earlier result:
- `current_loss_modal_window.png` showed the defeat modal centered and legible with no competing top-right Menu button.
- That screenshot predates the run-total title change: it shows the modal scoreboard title as `Player Damage` with only the player row `Axiom` / `143`.
- The old summary confirmed `loss_overlay_visible=true`, `system_menu_button_visible=false`, `system_menu_button_disabled=true`, `enemy_column_child_count=0`, and label text limited to `Defeat`, stage/high score, player summary stats, the player-only damage ledger, `Axiom`, and `143`.
- `godot-ai editor_screenshot(source="game")` could not capture because `_mcp_game_helper` did not register debugger capture in that run, so the accepted PNG came from the OS-window capture helper after verifying the `Gamble Battle (DEBUG)` window.

2026-06-25 run-total visual refresh:
- `CurrentLossModalVisualHold.tscn` was run through the live editor via Godot-AI `project_run`; the Godot-AI game capture helper still did not mark `game_capture_ready`, so the accepted PNG came from the OS-window helper targeting the visible `Gamble Battle (DEBUG)` process.
- `current_loss_modal_window_run_totals.png` was inspected after capture and shows the current centered defeat modal with `Run Damage: 143`, `Run Healing: 0`, `Run Kills: 1`, `Top Run Damage: Axiom (143)`, and `Final Battle Damage`.
- The modal remains visually contained, the New Game action is prominent, the player-only Axiom row is readable, and the top-right system Menu is absent behind defeat.
- The refreshed summary JSON now contains the same run-total labels and confirms `system_menu_button_visible=false`, `system_menu_button_disabled=true`, and `enemy_column_child_count=0`.

## Current Starter Runner Recheck

Fresh ignored-runner evidence was regenerated on 2026-06-24 at `outputs/audit_playtest/starter_audit_results.json` using `outputs/audit_playtest/StarterAuditRunner.tscn`.

Current level-1 starter surface:
- `axiom`, `berebell`, `bo`, `bonko`, `brute`, `cashmere`, `grint`, `korath`, `morrak`, `mortem`, `repo`, `sari`

Historical automated solo-starter result before the 2026-06-26 opener tuning:

| Starter | Role | Wins | First loss | Total player damage | Stage 1 | Stage 2 |
|---|---|---:|---:|---:|---|---|
| Bonko | brawler | 1 | 2 | 1796 | victory | defeat |
| Berebell | brawler | 1 | 2 | 1385 | victory | defeat |
| Sari | marksman | 1 | 2 | 1383 | victory | defeat |
| Grint | tank | 1 | 2 | 1253 | victory | defeat |
| Brute | tank | 1 | 2 | 1215 | victory | defeat |
| Morrak | brawler | 1 | 2 | 1038 | victory | defeat |
| Bo | brawler | 1 | 2 | 988 | victory | defeat |
| Korath | tank | 1 | 2 | 961 | victory | defeat |
| Mortem | brawler | 1 | 2 | 918 | victory | defeat |
| Repo | tank | 1 | 2 | 667 | victory | defeat |
| Cashmere | mage | 1 | 2 | 622 | victory | defeat |
| Axiom | support | 0 | 1 | 143 | defeat | - |

Summary:
- Current starter count is 12, not the earlier 21. The removed starter-visible units are the new cost-2 premium tier: `kythera`, `luna`, `nyxa`, `paisley`, `teller`, `totem`, `veyra`, `volt`, and `vykos`.
- In this pre-tuning run, 11 of 12 current starters beat Stage 1 solo and then lost Stage 2 solo; Axiom was the only starter that lost Stage 1. This no longer describes the production opener after the 2026-06-26 Beegle tutorial-target override.
- No current level-1 solo starter clears Stage 2. The best total-damage reads are Bonko, Berebell, Sari, Grint, and Brute.
- The level-2 solo check against the four-enemy creep mix still had no winners. Highest damage was Grint 591, Bonko 562, Brute 377, and Korath 261.
- Focused item checks still improve numbers without flipping the tested outnumbered fights: Cashmere `doubleblade` 240 -> 303, Nyxa `mind_siphon` 1752 -> 2037, and Korath `blood_engine` 475 -> 598.
- Audit implication at the time: the branch had successfully moved fragile/premium kits out of the starter picker, but the early game was still a one-body wall. The later opener tuning closes that first-wall issue; first-shop deployment clarity and board-width onboarding remain core risks.

## Current All-Starter Main-Flow Replay

Fresh ignored-runner evidence was regenerated on 2026-06-26 at `outputs/audit_playtest/all_starter_live_capture_2026_06_26/all_starter_live_capture_results.json` using `outputs/audit_playtest/AllStarterLiveCapture.tscn`. The latest clean Godot-AI live-editor run completed with `AllStarterMainFlowAudit: OK starters=12` and `errors: []`, using `display_server=Windows` and `rendering_driver=opengl3`. Before the clean rerun, stale PNGs from earlier attempts were removed from the output directory; the resulting manifest and directory now agree at 72 saved PNGs and 0 skipped captures.

Run result:
- The runner used the real Main scene and current starter catalog: `axiom`, `berebell`, `bo`, `bonko`, `brute`, `cashmere`, `grint`, `korath`, `morrak`, `mortem`, `repo`, and `sari`.
- All 12 starters opened the CombatView from Unit Select, and all 12 successfully repositioned the starting board unit through the existing drag path.
- All 12 starters reached the first shop at Stage 1 Round 2 with level-1 offers only.
- For all 12 starters, the runner clicked one rendered affordable shop card, saw the deploy prompt, moved the bought bench unit to the board, and resolved the next fight back to a shop/planning state.
- Most starters advanced beyond Stage 2 after the bought helper; a few resolved the second fight and stayed at Stage 2, but no starter stalled, errored, or returned to the opener retry state.
- Summary counts: `starter_count=12`, `first_shop_count=12`, `first_retry_count=0`, `deploy_success_count=12`, `second_resolved_count=12`, `starter_failures=[]`, and no shop errors. Capture counts were `saved=72`, `skipped=0`, and the output folder contains exactly 72 PNGs after cleanup.

Implication:
- The current Main-flow presenter path is now covered across all 12 current starters for selection, initial board drag, forced opener handling, first-shop buy/deploy, and second-fight resolution.
- Axiom is no longer a production opener outlier. The retry recovery path remains covered separately: `AxiomRetryChoiceQualitySmoke` advances all five configured retry helpers and `AxiomRetryEconomySmoke` proves the retry shop starts with one of those helpers before the buy/deploy/retry-fight path reaches a full Stage 2 planning shop, but both smokes force the hard opener internally.
- This is automated live-editor coverage, not a natural human-speed replay. The PNG set closes the missing all-starter framebuffer evidence gap, while human drag-feel remains a separate optional manual audit surface. Bo, Bonko, Cashmere, Korath, Mortem, Repo, and Sari still have visible first-shop choice-quality differences in forced matrix runs, but the tracked opening-shop safeguard now guarantees each of them sees a known advancing helper in the first visible/default-click slot and suppresses configured known-bad helpers in the first post-opener shop.

Production-clock follow-up:
- `tests/visual/NaturalAllStarterMainFlowSmoke.tscn` was added on 2026-06-26 as a subclass of the all-starter Main-flow smoke. It reuses the same real Main-scene flow and assertions, but keeps `Engine.time_scale = 1.0`, does not call the accelerated runner's opener timer hold, and uses longer real-time first/second fight timeouts.
- The MCP debug run completed with `NaturalAllStarterMainFlowSmoke: PASS starters=12 first_shop=12 retry=0 deployed=12 second_resolved=12` and `errors: []`; a fresh rerun at local HEAD `6c7b761` reproduced the same pass counts and empty debug-error buffer.
- `tests/visual/NaturalInputMainFlowSmoke.tscn` was added on 2026-06-26 as a strict-input path, then expanded to the live level-1 starter catalog. It runs at production clock without planning-timer holds, requires the title/unit-select/shop click path to advance through synthetic mouse input rather than signal fallback, refuses drag-lifecycle fallback for the helper bench-to-board deploy, and skips only the nonessential opener-board reposition used by the broader accelerated smoke.
- The MCP debug run completed with `NaturalInputMainFlowSmoke: PASS starters=12 first_shop=12 retry=0 deployed=12 second_resolved=12` and `errors: []`. This strengthens the natural-input evidence for the full current starter catalog, while remaining synthetic input proof rather than external OS/manual replay.
- This closes the accelerated-clock behavioral caveat for the all-starter loop. It does not replace physical manual/OS-window feel testing, and the existing all-starter PNG capture set remains the accelerated live-editor artifact.

## Current First-Shop Choice Sensitivity Audit

Fresh ignored-runner evidence was generated on 2026-06-26 at `outputs/audit_playtest/first_shop_choice_audit/first_shop_choice_results.json` using `outputs/audit_playtest/FirstShopChoiceAudit.tscn`. The MCP debug run completed with `FirstShopChoiceAudit: OK starters=4 trials=20` and `errors: []`; that older ignored runner remains source detail for the first four soft-fail lines.

The committed smoke now targets seven first-shop-sensitive starters from the current all-starter replay and follow-up default-click evidence. It captures the practical contract more directly: the first post-opener shop must put a known advancing helper in slot 0 for guarded starters, while the forced matrix still records which helper choices are risky.

Committed regression coverage now exists in `tests/visual/FirstShopChoiceQualitySmoke.tscn`. It forces deterministic helper sets for Bo, Bonko, Cashmere, Korath, Mortem, Repo, and Sari, replays each slot through the real Main-flow purchase, bench-to-board deploy, and second fight, and fails if any target starter has no helper choice that advances beyond Stage 2. The 2026-06-26 MCP debug rerun completed with `FirstShopChoiceQualitySmoke: PASS starters=7 trials=35 advanced=23` and `errors: []`; the exact advanced count is telemetry from that run, while the guard threshold is at least one advancing helper for each target starter. The current row-level matrix is tracked in `docs/starter_first_shop_choice_matrix_2026-06-26.md`.

`tests/visual/FirstShopOfferQualitySamplingSmoke.tscn` now samples the starter-aware opening-shop roller over 240 deterministic seeds using the known-good helper sets and configured blocked-helper sets from that matrix. Its latest 2026-06-26 MCP debug run completed with `errors: []`, rates every guarded starter at `first_good=1.000`, and reports `blocked_seen=0` plus `axiom_seen=0`. This confirms the first post-opener shop now guarantees a known advancing helper in the first visible/default-click slot for Bo, Bonko, Cashmere, Korath, Mortem, Repo, and Sari while removing configured trap helpers from that first shop. The smoke also asserts the expected trap-helper config directly after the Bo/Brute omission was closed. The forced-choice matrix still shows Repo has the narrowest helper table because Sari is the only proven advancing helper for Repo.

`tests/visual/AxiomRetryChoiceQualitySmoke.tscn` covers the separate retry-shop fallback path under a test-forced hard opener. Its latest 2026-06-26 MCP debug run completed with `AxiomRetryChoiceQualitySmoke: PASS trials=5 advanced=5` and `errors: []`: Bonko, Grint, Sari, Morrak, and Berebell each advanced the Axiom retry fight beyond Stage 1. `AxiomRetryEconomySmoke` now also asserts the forced retry shop starts with one configured helper before buying/deploying and progressing to Stage 2.

Ignored-runner result:
- Bo advanced with Sari, Morrak, and Bo; Bo did not advance with Axiom or Repo.
- Bonko advanced with Bonko, Cashmere, Bo, and Bonko; Bonko did not advance with Axiom.
- Cashmere advanced with Bonko; Cashmere did not advance with Axiom or Morrak.
- Repo advanced with Berebell; Repo did not advance with Cashmere, Brute, or Korath.
- Summary: `trial_count=20`, `advanced_count=10`, and every targeted starter had at least one first-shop helper choice that advanced beyond Stage 2.

Committed matrix result:
- Bo advanced with Berebell and Grint; Bo did not advance with Cashmere or Brute in this rerun.
- Bonko advanced with Morrak, Grint, Mortem, and Korath; Bonko did not advance with Axiom.
- Cashmere advanced with Brute and Bonko; Cashmere did not advance with Korath or Repo.
- Korath advanced with Bonko, Sari, Morrak, and Berebell; Korath did not advance with Brute.
- Mortem advanced with Morrak, Bonko, Sari, and Berebell; Mortem did not advance with Brute.
- Repo advanced with Sari; Repo did not advance with Axiom, Mortem, Korath, or Brute.
- Sari advanced with Bonko, Grint, Brute, Berebell, and Morrak.
- Summary: `trial_count=35`, `advanced_count=23`, and every targeted starter had at least one first-shop helper choice that advanced beyond Stage 2.

Implication:
- These lines are not pure mechanical or unavoidable starter failures. They are first-shop choice-quality failures under a one-helper purchase policy.
- Pure support as the first helper is especially risky: the ignored runner failed Axiom for Bo, Bonko, and Cashmere, while the committed matrix failed Axiom for Bonko and Repo. The production first-shop guard now suppresses Axiom for all seven guarded first-shop-sensitive starters.
- Low-damage or redundant defensive pairings can also fail: Repo did not advance with Brute or Korath in either the ignored runner or the latest committed guard, and Korath/Mortem did not advance with Brute in the expanded committed matrix.
- Current audit recommendation: keep the starter-aware guard for the current first-shop-sensitive starters, including slot-0 proven-helper placement and first-shop known-bad suppression, and treat broader later-reroll choices as tuning work rather than mechanical blockers.

## Current Shop And Premium Runner Recheck

Fresh ignored-runner evidence was generated on 2026-06-24 at `outputs/audit_playtest/current_shop_audit_results.json` using `outputs/audit_playtest/CurrentShopAuditRunner.tscn`. The MCP debug run completed with `errors: []`.

Current shop-tier sample:

| Player level | Sampled offers | Cost-1 offers | Cost-2 offers | Cost-3 offers | Premium coverage |
|---:|---:|---:|---:|---:|---|
| 1 | 1000 | 1000 | 0 | 0 | none |
| 2 | 1000 | 797 | 203 | 0 | all 9 cost-2 ids seen |
| 3 | 1000 | 645 | 301 | 54 | all 9 cost-2 ids seen |

Rapid transaction probe:
- A level-2 shop reached a premium offer after one reroll: `kythera`, `axiom`, `repo`, `axiom`, `bo`.
- Five immediate `Shop.buy_unit(slot)` calls all succeeded, spending 6 gold total and filling the bench with `kythera`, `axiom`, `repo`, `axiom`, `bo`.
- The purchased offers became five sealed/blank placeholders. This direct transaction path is now backed by the rendered-card burst recheck below; real pointer-coordinate spacing and feel still need window-level input testing.

Premium Stage 2 helper probe:

| Starter | Premium helpers that beat Stage 2 as second body |
|---|---|
| Bonko | `kythera`, `luna`, `nyxa`, `paisley`, `teller`, `totem`, `veyra`, `volt`, `vykos` |
| Axiom | `nyxa`, `teller`, `vykos` |

Runner implication:
- Cost-2 premium value exists mechanically once a second unit actually reaches the board. Bonko plus any cost-2 premium beat the Stage 2 direct-combat check, and support opener Axiom can flip Stage 2 with Nyxa, Teller, or Vykos.
- The audit risk is therefore UI reliability and comprehension: the player must notice the premium, buy it, understand that it landed on the bench, and deploy it before the next fight. Later current-branch evidence covers the core transaction/deploy correctness with `ShopPurchaseFeedbackSmoke`, `RapidShopPressureSmoke`, `PremiumDeployAuditRunner`, and the live cost-2 Buy XP/deploy screenshot pass; remaining risk is natural long-form feel, not known missing transaction state.
- The duplicate-name scoreboard probe produced two separate model rows for two Berebells (`index 1` damage 1487, `index 0` damage 1433). That confirmed duplicate rows are expected for duplicate copies; the later `ScoreboardDuplicateDisambiguationSmoke` closes the visual ambiguity by adding copy suffixes for repeated display names.

## Current Rapid Shop Input Recheck

Current committed regression coverage was added on 2026-06-25 as `tests/visual/RapidShopPressureSmoke.tscn`. The MCP debug run completed with `RapidShopPressureSmoke: OK purchases=5 deployed_board=6` and `errors: []`. It uses the real Main scene, selects Bonko, wins the forced opener, prepares a level-1 shop with five rendered buyable cards, emits all five card presses in one burst, verifies current `SOLD` / `On bench` placeholders, verifies no shop errors, deploys all five bench units to the board through global mouse-release input, and confirms the follow-up fight resolves.

Follow-up production-clock coverage was added on 2026-06-26 as `tests/visual/ProductionRapidShopPressureSmoke.tscn`. It reuses the same real Main-scene rapid-shop path, but runs at `Engine.time_scale = 1.0`, does not hold opener or shop planning timers, buys the five rendered shop cards through viewport mouse clicks on their visible centers, and keeps the extended real-time fight timeouts needed for production clock. The MCP debug run completed with `ProductionRapidShopPressureSmoke: OK purchases=5 deployed_board=6` and `errors: []`. This is still audit-assisted for shop gold and deterministic shop preparation; it closes the accelerated-clock and direct-signal caveats for the tracked pressure path, not the optional physical human-speed feel proof.

Fresh ignored-runner evidence was generated on 2026-06-24 at `outputs/audit_playtest/rapid_shop_input_audit/rapid_shop_input_results.json` using `outputs/audit_playtest/RapidShopInputAudit.tscn`. The MCP debug run completed with `RapidShopInputAudit: OK findings=0` and `errors: []`.

Run result:
- The runner used the real Main scene, selected Bonko, won the forced opener, granted 16 audit gold to isolate input handling from economy scarcity, and rerolled three times to a unique cost-1 shop: `Cashmere`, `Bonko`, `Sari`, `Morrak`, and `Grint`.
- It emitted all five rendered `ShopCard.pressed` signals in one same-frame burst. All five emitted, spent the expected 5 gold (`14 -> 9`), added five bench units, produced five sold placeholders, left phase `PREVIEW`, kept `combat_active=false`, kept the continue button at `Start Battle`, showed the deploy prompt, and emitted no shop errors.
- A stale double-click check against the first original card found that the original card had already become invalid after the grid rebuild, so no stale second purchase fired and no shop error appeared.
- Five bench-to-board deploy attempts all moved units successfully. The final board was `["bonko", "cashmere", "bonko", "sari", "morrak", "grint"]`, the bench was empty, and the post-burst fight resolved back to preview.

Real-window OS-coordinate follow-up:
- Fresh ignored hold-scene evidence was generated on 2026-06-25 under `outputs/audit_playtest/rapid_shop_os_burst/` using `outputs/audit_playtest/RapidShopOSBurstHold.tscn` and `outputs/audit_playtest/rapid_shop_os_burst_clicks.ps1`.
- The hold scene instantiated the real Main UI, selected Berebell, then staged a valid Stage 1 Round 2 planning shop directly through game autoloads to isolate the shop input path from opener RNG. This is audit-assisted setup, not natural full-run progression proof.
- `01_before_rapid_os_burst.png` shows the staged shop at `Gold: 18`, `Start Battle`, and five enabled visible 1g cards: `Mortem`, `Berebell`, `Bo`, `Repo`, and `Korath`.
- `rapid_shop_os_burst_summary.json` preserves the pre-click card centers `(475,968)`, `(635,968)`, `(795,968)`, `(955,968)`, and `(1115,968)`. `rapid_shop_os_burst_clicks.json` confirms OS clicks at those same screen coordinates with 25 ms spacing.
- `02_after_rapid_os_burst.png` and the final summary confirm all five purchases landed: bench `["mortem", "berebell", "bo", "repo", "korath"]`, gold `18 -> 13`, five sold placeholders, `phase=PREVIEW`, `continue_button_text="Start Battle"`, `deploy_prompt_visible=true`, and no `shop_errors`.

Implication:
- The current Main-flow shop transaction/presenter path tolerates a rapid burst across rendered shop cards and subsequent bench deployment without reproducing the older battle-lock failure, and that core path is now part of tracked `tests/visual` validation rather than only ignored audit output.
- The tracked validation now covers both accelerated and production-clock timing for this path, and the production-clock path uses rendered-card viewport clicks rather than direct card signals. `RapidShopVisualPressureSmoke` now also captures the live-renderer pressure states under `outputs/visual_iter/rapid_shop_pressure_pass/`: five sold/on-bench placeholders plus deploy guidance after the burst, then an empty bench, six board units, and readable scoreboard rows after deployment. The real-window buying portion is also covered for OS-coordinate clicks under a staged Round 2 setup. Remaining risk is external physical pointer feel under human speed, not missing transaction, layout, or post-burst visual proof.

## Current Duplicate Scoreboard Visual Recheck

Fresh ignored-runner evidence was generated on 2026-06-24 at `outputs/audit_playtest/duplicate_scoreboard_visual/duplicate_scoreboard_visual_results.json` using `outputs/audit_playtest/DuplicateScoreboardVisualAudit.tscn`. The MCP debug run completed with `DuplicateScoreboardVisualAudit: OK` and `errors: []`. A live editor run also saved `outputs/audit_playtest/duplicate_scoreboard_visual/duplicate_berebell_scoreboard.png`.

Original run result:
- The duplicate Berebell custom fight started and resolved as victory, with 66 hits, 2920 player damage, and 649 enemy damage.
- Model rows remained separate by internal index: `index 1` Berebell had 1487 damage and `index 0` Berebell had 1433 damage.
- The rendered scoreboard showed two visible player rows: `Berebell 1.5k` and `Berebell 1.4k`.
- There was no name/value overlap in the rendered rows.
- The rendered rows had zero visible identity disambiguators. The only visible texts were the duplicate name and each damage value, so the player cannot tell which Berebell copy is which from the scoreboard alone.

2026-06-25 fix and validation:
- Duplicate scoreboard rows now keep separate combat rows but add copy suffixes when a team has repeated display names, for example `Berebell #1` and `Berebell #2`.
- The suffix is produced in `ScoreboardModel`, then reused by `ScoreboardRow` and tooltip copy so rendered labels and hover context stay consistent.
- `tests/visual/ScoreboardDuplicateDisambiguationSmoke.tscn` passed through MCP with `ScoreboardDuplicateDisambiguationSmoke: OK` and `errors: []`. A 2026-06-26 live Godot-AI/OpenGL pass also saved `outputs/visual_iter/duplicate_scoreboard_pass/01_duplicate_scoreboard_copy_labels.png`, showing the copy suffixes in the rendered scoreboard rows. The existing `StatsPanelClickSmoke` also passed afterward with `errors: []`.

Implication:
- Duplicate scoreboard rendering is numerically readable, and the row split is intentional rather than a model aggregation bug.
- The identity ambiguity is closed for duplicate display names. A future polish pass can replace the copy suffix with board slot, star/level, or aggregate-row design if that becomes the preferred UX.

## Current Post-Combat Planning Beat Visual Recheck

Fresh live-renderer evidence was generated on 2026-06-26 from `tests/visual/PostCombatPlanningBeatSmoke.tscn` through an active Godot-AI/OpenGL editor session.

Accepted files:
- `outputs/visual_iter/post_combat_planning_beat_pass/01_post_win_intermission_bar.png`: transient post-win intermission frame before stage advancement, with the gothic progress bar visible while the resolving UI is still locked.
- `outputs/visual_iter/post_combat_planning_beat_pass/02_post_win_planning_restored.png`: restored `Stage 1 - Round 2/6` planning frame with shop offers visible, `Start Battle` enabled, gold/bet copy visible, and normalized capture timer copy after the smoke already asserted at least 55 seconds of restored planning time.

Validation:
- Live Godot-AI/OpenGL log: both PNGs saved and `PostCombatPlanningBeatSmoke: OK`.
- Legacy MCP debug rerun: `PostCombatPlanningBeatSmoke: OK`, `errors: []`; screenshot capture skipped under the dummy framebuffer.

Implication:
- The post-win handoff is visible before control returns, and the next planning state is visually and mechanically ready rather than silently consuming the player's shop decision window.

## Current Start Battle Feedback Recheck

Fresh ignored-runner evidence was generated on 2026-06-24 at `outputs/audit_playtest/start_battle_feedback/start_battle_feedback_results.json` using `outputs/audit_playtest/StartBattleFeedbackAudit.tscn`. The MCP debug run completed with `StartBattleFeedbackAudit: OK` and `errors: []`.

Run result:
- The runner used the real Main scene, selected Bonko, won the forced opener, then injected a stable audit team (`bonko`, `grint`, `nyxa`, `volt`) so repeated Start Battle transitions could be observed.
- Stage 2, 3, and 4 each started from visible enabled `Start Battle`.
- Immediately after each button press, the button text changed to disabled `Combat Resolving...`, phase changed to combat, bet read `Bet: 1 (locked)`, and the combat engine reported active.
- Each audited start resolved back to preview: Stage 2 -> 3, Stage 3 -> 4, and Stage 4 -> 5.

Implication:
- The current automated Main-flow behavior has immediate Start Battle feedback. The older `Battle Locked` ambiguity is no longer present in this path; the current label is clearer and appears synchronously with combat start.
- A live-editor screenshot attempt for the same runner failed before the post-forced-fight shop and overwrote the JSON, so the passing MCP run was repeated to restore the evidence. Treat this as behavioral proof, not a fresh real-window visual capture.

Live-window recheck:
- Fresh OS-window screenshots were captured on 2026-06-25 in `outputs/audit_playtest/live_start_battle_transition_2026_06_25/`.
- `06_round2_wait_after_forced.png` shows the normal Round 2 planning state with an enabled `Start Battle` button.
- `07_immediate_after_start_battle.png` was captured immediately after one click and shows the button disabled as `Combat Resolving...`, the bet locked, and the board in combat.
- `08_followup_after_transition.png` shows the disabled resolving state persisting during combat, and `09_final_after_transition_wait.png` shows the screen returning to planning with `Start Battle` restored.

Updated implication:
- Start Battle is now covered by both behavior and real-window visual evidence. The remaining design risk is not whether the click gives feedback; it is whether longer or stalled combat needs a progress indicator, timeout, or clearer stuck-state recovery.

## Current Premium Buy/Deploy Main-Flow Recheck

Fresh ignored-runner evidence was generated on 2026-06-24 at `outputs/audit_playtest/premium_deploy_audit/premium_deploy_audit_results.json` using `outputs/audit_playtest/PremiumDeployAuditRunner.tscn`. The MCP debug run completed with `PremiumDeployAuditRunner: OK` and `errors: []`.

The same runner was refreshed on 2026-06-25 through legacy MCP. It again completed with `PremiumDeployAuditRunner: OK` and `errors: []`. In the refreshed run, Bonko's opener left enough gold for natural Buy XP to succeed, so no audit gold was needed for the XP step; the runner then granted premium-shop audit gold, rerolled once, bought cost-2 `Veyra`, showed the deploy prompt, and dragged Veyra to the board for final board state `["bonko", "veyra"]`.

A later 2026-06-25 rerun varied the reward/economy outcome and still passed. It completed with `PremiumDeployAuditRunner: OK` and `errors: []`; natural Buy XP at 4 gold correctly failed the reserve-floor rule with tooltip `Must keep at least 1 health (need +1)`, one audit gold grant let Buy XP advance to `Lvl 2 (2/6)`, the level-2 shop exposed cost-2 `Volt` after three rerolls, and the runner bought/deployed Volt for final board `["bonko", "volt"]`. This keeps the behavioral cost-2 path covered even though live-window screenshots remain blocked. A 2026-06-26 rerun of `BuyXPTransactionalFeedbackSmoke` also passed with `errors: []`, preserving the current visible denial message and successful XP repaint contract.

Run result:
- Bonko won the forced opener and reached the post-fight shop with visible `Gold: 4` and `Lvl 1 (0/2)`.
- A natural Buy XP click at 4 gold did not change gold or level; the button tooltip reported `Must keep at least 1 health (need +1)`, and the current presenter smoke additionally guards the visible post-click message `Need +1 gold to buy XP and keep 1 health.`
- The audit runner then granted 1 gold to test the successful path. Buy XP advanced to `Lvl 2 (2/6)` and left gold at 1.
- The runner granted 11 audit gold for a premium-shop interaction, rerolled once, and found cost-2 `Volt` as a rendered shop card.
- Clicking the rendered `Volt` card bought it to the bench, showed the first-purchase deploy prompt, and left the board as `["bonko"]`.
- Dragging the bench unit to the board succeeded; final board state was `["bonko", "volt"]`, bench was empty, and the continue button read `Start Battle`.

Implication:
- The cost-2 premium buy/deploy path is behaviorally covered in the current Main flow after leveling, including rendered card click and bench-to-board drag. The accepted runner history now covers two cost-2 outcomes: `Volt` after an audit-funded XP step and `Veyra` after natural Buy XP.
- The former reserve-floor affordance gap is now mechanically covered: `BuyXPTransactionalFeedbackSmoke` verifies the 4-gold click leaves gold/level/XP unchanged and shows `Need +1 gold to buy XP and keep 1 health.`, while the 6-gold click repaints `Gold: 2` and `Lvl 2 (2/6)` immediately.
- PNG capture requests in this runner were skipped under the MCP dummy/headless framebuffer. A live-editor attempt to capture the same runner was session-sensitive and failed before the post-fight shop, so this evidence should be treated as behavioral JSON/debug-output proof, not visual-polish proof.

## Current Live Main-Flow Screenshot Recheck

Fresh current-run screenshot evidence was generated on 2026-06-25 under `outputs/audit_playtest/live_flow_recheck_2026_06_25/`, with notes in `outputs/audit_playtest/live_flow_recheck_2026_06_25/notes.md`.

Accepted screenshots:
- `01_title.png`: title screen.
- `02_unit_select_initial.png`: Unit Select before active selection.
- `03_bonko_selected.png`: Bonko selected and Start Game enabled.
- `04_forced_first_fight.png`: forced first-fight planning state.
- `05_round2_shop.png`: first real shop after Bonko wins the opener.

Run result:
- The first title Start click transitioned to Unit Select on the first attempt.
- The current Unit Select surface showed exactly the 12 cost-1 starters.
- Bonko selected on the first pointer click, and Start Game enabled immediately.
- The forced first-fight planning screen correctly disabled Reroll, Lock, and Buy XP; the continue button said `Start Forced Fight`; the shop placeholder said `FIRST FIGHT` / `Win to open shop`.
- Bonko won the opener and reached `Stage 1 - Round 2/6` with `Gold: 3`, `Lvl 1 (0/2)`, `Start Battle`, and a five-card level-1 shop: `Bo`, `Mortem`, `Morrak`, `Repo`, `Sari`, all priced `1g`.
- The live UI tree reported each shop card as a full `150x138` button with about 10 px horizontal gaps.
- A pointer-coordinate click at approximately `(475, 968)` on the first card succeeded; `godot.log` recorded `[BenchPlacement] Added to bench slot=0 unit=Bo level=1`.

Visual/UX read:
- Title and selected-unit states are strong: large targets, clear title art, and an obvious enabled Start Game state after selection.
- Current Unit Select starts from neutral preview copy (`No champion chosen` / `Hover a unit to preview`) with no default unit art before hover or selection, so inspection and selection no longer blur on the first screen.
- The forced-first-fight behavior is correct, but the bottom placeholder text is very low contrast and visually subtle. The button carries most of the meaning.
- The first real shop is readable at 1920x1080, but the cards sit close to the bottom edge. Labels and prices are readable on this desktop capture, but the layout still feels compressed under timer pressure.

Limit:
- Immediately after the first shop-card purchase, a broad Godot-AI scene-tree inspection timed out and the bridge then dropped with a keepalive timeout. The newest debug process from this run was stopped manually. This pass confirmed the pointer-coordinate purchase event only. Later evidence supersedes this limitation for core correctness: cost-1 deployment has real-window drag proof, cost-2 Buy XP/deploy has audit-assisted live-window screenshots, and `RapidShopPressureSmoke` covers the committed burst-buy/deploy path.

## Current Live Window Capture Fallback Attempt

After the Godot-AI session list dropped to zero active sessions, a fallback attempted to capture and click the visible `Gamble Battle (DEBUG)` window directly. Diagnostic files were saved under `outputs/audit_playtest/window_capture_2026_06_25/`.

Result:
- Bringing an existing debug window to the foreground produced a real game-window capture at Stage 1 Round 2 with a visible 1g shop, `Gold: 3`, and `Lvl 1 (0/2)`.
- That debug window was stale rather than live: the planning timer stayed at `0:59`, a pointer click around `(475, 965)` on the first shop card did not change gold or bench state, and no new bench-placement log appeared.
- The two stale `Gamble Battle (DEBUG)` game processes were stopped while the editor windows were left alone.
- A fresh `scenes/Main.tscn` launch through legacy MCP started headless (`--headless --path ... scenes/Main.tscn`), returned `errors: []`, and exposed no capturable game window. It was stopped cleanly.

Implication:
- The stale-window captures are not accepted as gameplay proof; they only explain why the fallback did not close the post-buy/deploy screenshot gap.
- The accepted evidence for post-leveling cost-2 buy/deploy remains the refreshed `PremiumDeployAuditRunner` JSON/debug-output path.
- This fallback gap was later closed for cost-1 post-buy deployment by the live Bonko-to-Brute recheck and for audit-assisted cost-2 deployment by the live cost-2 Buy XP/deploy screenshot pass below. Natural long-form cost-2 feel remains a future playtest/polish topic.

## Current Live Bonko Shop And Deployment Recheck

Fresh live editor/debug-window evidence was saved on 2026-06-24 under `C:\Users\Flipm\Documents\gamble-battle-playtest-audit\current_runs\`.

Captured sequence:
- `001_bonko_forced_first_fight.png`: Bonko selected, forced first fight shown with `FIRST FIGHT` / `Win to open shop`, disabled shop actions, and Start Forced Fight available.
- `002_bonko_round2_shop.png`: after Bonko won the opener, Stage 1 - Round 2/6 showed 3 gold, level 1, and only cost-1 offers: `Morrak`, `Mortem`, `Mortem`, `Brute`, `Mortem`.
- `004_bonko_brute_drag_attempt.png`: after buying Brute, gold fell to 2, the Brute card became a sealed shop placeholder, Brute appeared on the first bench slot, legal board cells highlighted green, and the board still contained only Bonko after the drag attempt.

Runtime state saved with the drag-attempt screenshot:
- `board_ids`: `["bonko"]`
- `bench_ids`: `["brute"]`
- `gold`: 2
- `phase`: preview/planning
- `stage`: 2
- `planning_time_left`: about 8 seconds

Live-run implication:
- The current level-1 shop behavior is correct: no cost-2 premium appeared before leveling.
- The premium helper result from the runner remains mechanically meaningful, but live UI value still depends on leveling, seeing the premium offer, buying it, and fielding it in time.
- At this checkpoint, even the simpler cost-1 Brute helper did not enter the board on the first real drag attempt before timer pressure. Later drag-release work and the current deploy-drag recheck closed the core drop correctness issue; first-shop deployment clarity is now a preservation/polish concern rather than a current live blocker.
- This run restored fresh screenshot evidence through the live editor path, but `editor_screenshot(source="game")` later timed out and Godot-AI lost its active session. Computer Use could see the `Gamble Battle (DEBUG)` window, but `get_window_state` failed with `SetIsBorderRequired failed: No such interface supported (0x80004002)`, so OS-level coordinate dragging could not continue in this pass.

Follow-up live max-bet/XP recheck:
- A live editor run confirmed the current Unit Select grid exposes the 12 cost-1 starters only.
- The first inspected `Start Game` click on Bonko did not transition; a second click on the same enabled button center did. This reinforces the need for stronger click/transition feedback around critical buttons.
- In the forced first-fight state, clicking the bet slider at its right edge changed the visible bet from 1 to 2, matching the starting 2 gold cap.
- Max-bet Bonko won the opener and reached Stage 1 - Round 2/6 with visible `Gold: 4`, `Lvl 1 (0/2)`, and all cost-1 offers: `Bo`, `Grint`, `Bonko`, `Cashmere`, `Grint`.
- A real click at the inspected Buy XP button center did not visibly update the level, XP, or gold labels. A direct autoload state read immediately afterward showed `gold=3`, `shop_level=1`, `shop_xp=0`, and `shop_xp_to_next=2`.
- That means the visible Buy XP click did not produce a successful XP purchase, level-up, or clear error. Later code and harness inspection narrowed the diagnosis: `ShopPresenter._on_buy_xp()` calls `Shop.buy_xp()`, then refreshes progress and card state directly, so a successful presenter path should repaint. The live issue is more likely the Buy XP button/input path failing to fire or complete under the current Godot-AI/OS-window capture setup than the cost-2 logic itself being unavailable.
- The bridge became unstable during deeper state inspection: a corrected `game_eval` timed out, then `game_manage.get_ui_elements` timed out, and Godot-AI dropped to zero active sessions. No fresh screenshot was saved for this follow-up segment.

## Current Live Cost-1 Post-Buy Deploy Recheck

Fresh live Main-flow evidence was saved on 2026-06-25 under `outputs/audit_playtest/live_deploy_recheck_2026_06_25/` after recovering Godot-AI through a fresh editor launch. The active session was `gamble-battle@0ad7`, running `res://scenes/Main.tscn`.

Accepted screenshots:
- `01_title.png`: title screen.
- `02_unit_select.png`: Unit Select with the current 12 cost-1 starters and the initial Axiom inspection preview.
- `03_bonko_selected.png`: Bonko selected and Start Game active.
- `04_forced_first_fight.png`: Stage 1 Round 1 forced first fight with disabled shop controls and `Start Forced Fight`.
- `05_round2_shop_before_buy.png`: Bonko reached Stage 1 Round 2 with 3 gold, level 1, and cost-1 offers: `Brute`, `Brute`, `Repo`, `Repo`, and `Morrak`.
- `06_after_cost1_buy_bench_prompt.png`: first live pointer-coordinate shop buy placed Brute on the bench, but screenshot inspection/timer pressure let combat start before deployment.
- `07_after_missed_deploy_back_to_planning.png`: after the fight resolved back to planning, Brute remained on the bench and Bonko remained on the board.
- `08_after_drag_bridge_drop_window.png`: OS-level capture after Godot-AI dropped during the first live drag attempt, showing the timer extended, Brute selected on the bench, and Bonko still on the board.
- `09_after_os_drag_attempt.png`: OS-level drag from the first bench slot to the board succeeded visually; Brute moved onto the player board and the first bench slot was empty.

Run result:
- A direct state read immediately after the first shop click confirmed `bench=["brute"]`, `board=["bonko"]`, `gold=2`, `phase=1`, and `stage=2`.
- The planning timer can still expire while evidence is being inspected; this pass auto-started combat with Brute still on the bench before a clean deploy screenshot could be captured.
- After the round returned to planning, the timer was extended for audit purposes. Godot-AI then dropped during the drag attempt, but the live game window stayed responsive.
- OS-level mouse input recovered the interaction and moved Brute from bench to board in the same live run.

Implication:
- The cost-1 live post-buy path is now visually covered: purchase-to-bench is confirmed by state and screenshot, and bench-to-board deployment is confirmed by real-window drag evidence.
- The remaining deployment gap was later narrowed again by the live cost-2 Buy XP/deploy screenshot pass below. The Godot-AI bridge remains too fragile for uninterrupted long-form manual play, but cost-2 purchase, prompt, and bench-to-board deployment are no longer unsupported by real-window evidence.
- Final validation after this doc update reran `tests/visual/ActualRunLoopSmoke.tscn` through legacy MCP; it printed `ActualRunLoopSmoke: OK` with `errors: []`. `git diff --check`, direct trailing-whitespace checks for this doc and brain notes, and canonical brain vault validation also passed.

## Current Live Cost-2 Buy XP And Deployment Attempt

Fresh live evidence was captured on 2026-06-25 under `outputs/audit_playtest/live_cost2_recheck_2026_06_25/`; the local folder also contains `notes.md`.

Accepted screenshots:
- `01_title.png`: title screen from the first Godot-AI run.
- `02_unit_select.png`: Unit Select with the current 12 cost-1 starters.
- `03_bonko_selected.png`: Bonko selected and Start Game active.
- `04_forced_first_fight_default_bet.png`: forced first fight at default bet.
- `05_forced_first_fight_max_bet.png`: attempted max-bet click; visible state still showed bet 1, and model readback confirmed `current_bet=1`.
- `06_after_forced_fight.png`: Bonko reached Stage 1 Round 2 with 3 gold, level 1, and cost-1 offers.
- `08_audit_assist_visible_gold.png`: after an audit model grant to 16 gold, the visible gold label still showed 3.
- `09_after_buy_xp_click.png`: Godot-AI Buy XP click produced no model change; direct readback stayed `gold=16`, `level=1`, `xp=0`, `xp_to_next=2`.
- `11_os_after_buy_xp_bridge_timeout.png`: OS capture after Godot-AI timed out; visible state was unchanged.
- `12_os_after_real_buy_xp_click.png`: real OS click on Buy XP; visible state was still unchanged.
- `13_restart_title_os.png`: second clean debug-window launch captured from the OS.
- `14_restart_round2_shop_os.png`: second run reached Round 2 shop through OS input, but Godot-AI never registered the game helper for state/setup.

Initial run result:
- The first run proved the model could be audit-assisted to 16 gold, but the visible UI did not refresh the gold label because that setup wrote `Economy.gold` directly instead of using the normal `Economy.add_gold(...)` signal path.
- The Godot-AI bridge dropped after the Buy XP attempts.
- The second run proved the OS-window route can still reach Bonko's Round 2 shop, but `game_capture_ready` stayed false and `game_eval` returned `EVAL_GAME_NOT_READY`, so level-2 setup could not be applied or verified.

Signal-path live-window recheck:
- A follow-up ignored assist scene, `outputs/audit_playtest/LiveCost2WindowAssist.tscn`, instantiates the real `scenes/Main.tscn` UI and only applies setup gold through `Economy.add_gold(...)` after Round 2 planning is reached.
- `25_assist_round2_gold_grant.png` shows Round 2 planning with visible `Gold: 5`, proving the signal-path gold grant refreshed the UI.
- `26_assist_after_buy_xp_os_click.png` shows a real OS click on Buy XP advancing the visible UI to `Lvl 2 (2/6)`; the assist then visibly refreshed post-XP funds to `Gold: 12`.
- `27_assist_after_level2_reroll.png` shows a real OS reroll at level 2 exposing `Teller 2g` and `Vykos 2g`.
- `28_assist_after_cost2_buy.png` shows a real OS click buying cost-2 Teller, sealing the purchased shop slot, adding Teller to bench, and showing the deploy prompt.
- `29_assist_after_cost2_drag.png` shows a real OS drag moving Teller from bench to the player board beside Bonko.

Updated implication:
- The live-window Buy XP input path works when the visible economy state is valid and refreshed through normal signals.
- The cost-2 level-2 shop, purchase, deploy prompt, and bench-to-board drag are now covered by live-window screenshots under audit-assisted economy setup.
- This live-window pass was audit-assisted for economy setup. The later natural Buy XP runner below closes the natural-economy model path and the 4-gold reserve-floor message mechanically; a fully unassisted real-window screenshot run remains optional feel/visual proof rather than evidence required to trust the Buy XP model/presenter path.

## Current Buy XP Code And Harness Diagnostic

Fresh source inspection and harness evidence on 2026-06-25 narrowed the Buy XP risk:
- `scripts/ui/shop/shop_presenter.gd` wires `ShopButtons.buy_xp_pressed` to `_on_buy_xp()`, and `_on_buy_xp()` calls `Shop.buy_xp()`, `_refresh_progress()`, and `_refresh_cards_state()`.
- `scripts/game/shop/shop.gd` still leaves `buy_xp()` without a full `_emit_all()` call, but the presenter path compensates with direct refresh calls after a successful button signal.
- A fresh legacy MCP run of `outputs/audit_playtest/PremiumDeployAuditRunner.tscn` completed with `PremiumDeployAuditRunner: OK` and `errors: []`.
- In that run, natural Buy XP at 4 gold failed correctly because of reserve-floor protection; after one audit gold grant, Buy XP advanced to level 2 and the progress label read `Lvl 2 (2/6)`.
- The same run bought cost-2 `Volt` from a level-2 shop, showed the deploy prompt, and moved Volt from bench to board for final board `["bonko", "volt"]`.
- A historical `outputs/audit_playtest/NaturalBuyXPAudit.tscn` run proved one natural-economy route to Buy XP. A later 2026-06-26 rerun still printed `NaturalBuyXPAudit: OK` with `errors: []`, but the overwritten JSON showed a looser terminal state: reward gold made Buy XP immediately affordable at Stage 1 Round 2, then the helper buy/deploy portion did not complete. Treat the ignored runner as exploratory economy evidence, not the authoritative premium-deploy proof.
- The committed current natural Buy XP proof is `tests/visual/NaturalBuyXPVisualSmoke.tscn`: the smoke drives Bonko through the real Main-scene opener, overrides only the stage-1 creep reward pool to a test-only guaranteed +2 gold fixture, earns that gold through `CreepRewardsRuntime`, then clicks the visible Buy XP button and verifies the repaint from `Gold: 5` / `Lvl 1 (0/2)` to `Gold: 1` / `Lvl 2 (2/6)`. This replaces the older random retry loop, which could fail when 20 ordinary opener rewards never produced the low-probability safe-gold window.
- The committed current premium proof is `tests/visual/PremiumDeployAfterLevelSmoke.tscn`: it passed with `errors: []`, used the visible Buy XP button to reach level 2 in Main, then bought and deployed cost-2 Kythera from a deterministic audit-assisted level-2 shop row.

Implication:
- Current source and tracked harness evidence prove the model/presenter path can level, naturally repaint the visible Main UI when ordinary reward gold makes Buy XP affordable, expose a cost-2 offer, buy it, and deploy it.
- Natural access to level 2 is variable with reward outcomes and first-shop choices, but the current tracked visual guard now covers the unassisted success moment as a bounded retry over ordinary opener rewards. The first 4-gold Buy XP denial has explicit visible feedback in the presenter path, while labels correctly remain unchanged.

## Current Natural Buy XP Main-Flow Recheck

Fresh tracked visual evidence was generated on 2026-06-26 with `tests/visual/NaturalBuyXPVisualSmoke.tscn`. The current smoke drives the real Main scene from Bonko selection through the forced opener, wires a test-only guaranteed +2 gold creep reward pool through `CreepRewardsRuntime`, and verifies the safe Buy XP window without directly setting `Economy.gold` or forcing shop offers. This deterministic reward-funded path replaces the earlier ordinary-random retry loop, which was valid exploratory evidence but too flaky for a guard because a first-shop safe-gold result depends on a low-probability reward roll. The legacy MCP debug rerun passed the same assertions and skipped PNG capture under dummy rendering.

Historical ignored-runner evidence was generated on 2026-06-25 at `outputs/audit_playtest/natural_buy_xp_audit/natural_buy_xp_results.json` using `outputs/audit_playtest/NaturalBuyXPAudit.tscn`. A 2026-06-26 rerun still completed with `NaturalBuyXPAudit: OK` and `errors: []`, but the current JSON is not a clean helper-deploy proof because reward gold allowed immediate Buy XP and the later helper buy/deploy terminal state remained loose. Keep the ignored runner as exploratory economy history; the committed guards are `tests/visual/NaturalBuyXPVisualSmoke.tscn` for natural visible Buy XP success, `tests/visual/BuyXPTransactionalFeedbackSmoke.tscn` for Buy XP denial/success feedback, and `tests/visual/PremiumDeployAfterLevelSmoke.tscn` for Main-scene level-up into premium purchase/deploy.

Run result:
- Historical 2026-06-25 result: Bonko reached Stage 1 Round 2, the 4g Buy XP denial preserved gold/progress labels and showed reserve-floor feedback, then a cost-1 helper line reached a later 6g Buy XP success.
- Current 2026-06-26 result: Bonko reached Stage 1 Round 2 with reward-aided `Gold: 5`; Buy XP succeeded immediately to `Lvl 2 (2/6)`, but the ignored runner then tried to buy a helper at 1 gold and logged a `WOULD_KILL_YOU` buy-unit error while still reporting OK.
- Current tracked natural visual result: the hardened legacy MCP rerun reached the reward-funded safe window on attempt 1, clicked the visible Buy XP button, and reported `NaturalBuyXPVisualSmoke: OK attempts=1 stage=2 gold_before=5 gold_after=1` with `errors: []`. The older live Godot-AI/OpenGL run reached the same visible UI state on attempt 4 and saved `01_natural_buy_xp_ready.png` plus `02_natural_buy_xp_success.png`; preserve those screenshots as visual evidence, but use the deterministic reward-funded smoke as the current guard.
- Current tracked result: `PremiumDeployAfterLevelSmoke` reached first shop, audit-assisted the visible Buy XP button only as needed, reached `Lvl 2 (2/6)`, forced a full level-2 shop row with cost-2 Kythera, bought Kythera, saw deploy guidance, and dragged Kythera to board.

Implication:
- Ordinary play can naturally reach a valid Buy XP moment as early as Round 2, with exact timing dependent on reward outcomes.
- The audit should not use the ignored NaturalBuyXPAudit as cost-2 deployment proof. The natural Buy XP success moment, denial message, and premium purchase/deploy path are all now covered by committed tracked smokes.

Current branch interpretation:
- The evidence below preserves the original 21-unit/manual continuation record, including pre-fix shop, deploy, and combat-stall failures. Treat it as historical replay evidence and play-feel source material, not as the current branch's blocker list. Current branch status is governed by the closure matrix above plus the committed validation smokes named throughout this document.

Key historical manual evidence captured in this continuation:
- `00_title_bridge.png`: title screen captured from Godot-AI `project_run`.
- `01_unit_select.png`: Unit Select after clicking Start through `game_manage.input_mouse`.
- `02_nyxa_planning.png`: Nyxa selected, first planning state, forced first fight, no shop offers.
- `03_nyxa_combat_round1.png`: Nyxa first combat in progress.
- `09_nyxa_after_round1_visual.png`: Nyxa won first fight and reached Stage 1 - Round 2 with a populated shop.
- `10_nyxa_after_buying_shop.png`: attempted strategic shop buying led to a confusing `Battle Locked` state after only one visible gold spend.
- `13_axiom_planning.png`, `14_axiom_after_forced_fight.png`, `15_axiom_after_buy_vykos_attempt.png`, `16_axiom_after_retry.png`: Axiom support opener through first loss/retry attempt.
- `18_bonko_planning.png`, `19_bonko_after_round1.png`: Bonko brawler opener through Round 1 win and Round 2 shop reveal.
- `21_title_after_focus_retry.png`, `22_unit_select_after_relaunch.png`: recovered Godot-AI capture after focusing the debug game window.
- `23_berebell_planning.png`, `24_berebell_after_round1.png`, `25_berebell_after_buy_vykos.png`, `25_berebell_after_buy_brute.png`, `26_berebell_after_round2.png`: Berebell opener through Round 2 loss after buying Vykos and Brute.
- Bo strategic positioning attempt: after `27_after_berebell_new_game.png`, a Bo run was started to test bench-to-board drag placement, but Godot-AI dropped to zero active sessions before any Bo screenshots were saved.
- `28_rerelaunched_title.png`, `29_bo_planning.png`, `30_bo_after_round1.png`, `31_bo_after_buy_grint_bonko_mortem.png`, `32_bo_after_round2.png`: recovered Bo run through Round 2 battle-lock/stall after shop-buy attempts.
- External evidence `33_external_title.png`, `34_brute_planning.png`, `35_brute_after_round1.png`, `36_brute_after_teller_click_no_bench.png`, `37_brute_after_round2_wait.png`: Brute run through Round 2 battle-lock/stall after a Teller purchase attempt.
- External evidence `38_cashmere_title.png`, `39_unit_select_for_cashmere.png`, `40_cashmere_planning.png`, `41_cashmere_after_round1.png`, `42_cashmere_round1_stall_wait.png`, `43_cashmere_round2_outcome.png`: Cashmere run through forced opener and Round 2 battle-lock/no-resolution outcome.
- External evidence `44_grint_planning.png` through `53_grint_round2_after_start_wait.png`: Grint run through forced opener, post-fight shop buy, failed bench-to-board drag attempt, Round 2 start, and final Stage 2 defeat overlay.
- Recovered Korath evidence `54_korath_resume_title.png` through `73_korath_round5_result_window.png`: Korath max-bet opener, Round 2 shop/brawler line, successful bench-to-board drags, Buy XP level-up, and final Stage 5 defeat.
- Recovered Kythera evidence `74_kythera_selected_window.png` through `79_kythera_round2_result_window.png`: item-assisted Kythera opener, Round 2 shop buys that did not clearly field helpers, and final Stage 2 defeat.
- Recovered Luna evidence `80_luna_planning_maxbet_window.png` through `91_luna_round3_after_wait_window.png`: Luna max-bet opener, Brute-assisted Round 2 clear, bench units not contributing, and Stage 3 defeat.
- Recovered Morrak evidence `93_morrak_selected_window.png` through `108_morrak_final_or_stuck_window.png`: Morrak max-bet opener, multi-round brawler/tank board building, repeated late-round Start Battle ambiguity, and final Stage 5 defeat.
- Recovered Mortem evidence `109_mortem_selected_window.png` through `124_mortem_final_result_window.png`: failed max-bet opener, item-assisted retry, Nyxa/Bo carry support, XP/buy interaction misses, and final Stage 5 defeat.
- Recovered Sari evidence `125_sari_selected_window.png` through `140_sari_after_timer_wait_window.png`: max-bet marksman opener, brawler/tank board building, and repeated Round 5 planning-loop/start ambiguity.
- Recovered Paisley evidence `142_paisley_selected_window.png` through `152_paisley_final_window.png`: item-assisted opener, long first-fight wait, ally-supported climb to Stage 5.
- Recovered Repo evidence `153_repo_selected_window.png` through `158_repo_retry_result_window.png`: item-assisted opener still left Repo in a Round 1 retry economy state; a Brute buy/retry still ended Stage 1.
- Lower roster select evidence `160_lower_unit_select_after_scroll_window.png`: scrolled Unit Select exposed Teller, Totem, Veyra, Volt, and Vykos, while the right preview still showed stale Cashmere inspection text.
- Recovered Teller evidence `161_teller_selected_window.png` through `171_teller_late_result_window.png`: max-bet opener, failed batch-buy attempt, slower one-by-one shop/deploy recovery, and Stage 5 planning state.
- Recovered Totem evidence `172_totem_unit_select_scrolled_window.png` through `182_totem_late_result_window.png`: item-assisted support opener, long first-fight wait, ally-supported recovery, and Stage 5 planning state.
- Recovered Veyra evidence `183_veyra_selected_window.png` through `186_veyra_after_extra_wait_window.png`, plus retry `205_veyra_retry_selected_window.png` through `207_veyra_retry_after_round1_window.png`: max-bet opener stalled in Battle Locked, while default-bet item-assisted retry reached Round 2.
- Recovered Volt evidence `187_volt_selected_window.png` through `195_volt_late_result_window.png`: item-assisted opener, ally-supported climb, and Stage 5 planning state.
- Recovered Vykos evidence `196_vykos_selected_window.png` through `204_vykos_final_window.png`: strong max-bet opener, failed batch-buy/deploy follow-up, and Stage 2 defeat.

## Manual Starter Coverage Summary

This table records historical manual observations from the older 21-unit starter surface and pre-fix interaction state. Rows that mention battle-locks, stale preview state, batch-buy misses, unclear deployment, or long resolving states should not supersede the newer mitigations and guards: `AllStarterMainFlowSmoke`, `AllStarterMainFlowAudit`, `FirstShopChoiceQualitySmoke`, `AxiomRetryEconomySmoke`, `CombatWatchdogSmoke`, `CombatResolvingFeedbackSmoke`, `ShopPurchaseFeedbackSmoke`, `RapidShopPressureSmoke`, `DragGlobalReleaseSmoke`, `NaturalBuyXPAudit`, `BuyXPTransactionalFeedbackSmoke`, `UnitSelectSmoke`, and the cost-tier gating checks. Keep the strategic reads, but revalidate play-feel issues against the current 12-starter level-1 branch before reopening them.

| Starter | Best live result | Strategic read | Primary evidence |
|---|---|---|---|
| Axiom | Stage 1 defeat/retry failure | Pure support has no satisfying solo opener and cannot convert the bad retry economy. | `13`-`16` |
| Berebell | Stage 2 defeat | Good brawler opener, but early buys need clearer deployment to matter. | `23`-`26` |
| Bo | Round 2 battle-lock/stall | Strong enough opener, but shop/deploy flow can lock before the intended brawler/frontline plan resolves. | `29`-`32` |
| Bonko | Round 2 shop reached | Best plan was board width: Nyxa carry plus Grint/Korath-style frontline. | `18`-`19` |
| Brute | Round 2 battle-lock/stall | Good tank opener, but Teller purchase attempt reproduced the no-resolution lock. | `34`-`37` |
| Cashmere | Round 2 battle-lock/stall | Needs immediate frontline; the Round 2 combat state stalled before strategy could be evaluated cleanly. | `39`-`43` |
| Grint | Stage 2 defeat | Tank opener works, but undeployed bench damage does not help and loss stats zeroed out. | `44`-`53` |
| Korath | Stage 5 defeat | Best tank start so far; brawler/frontline width before XP carried longest. | `54`-`73` |
| Kythera | Stage 2 defeat | Item support can save the opener, but helper buys did not clearly enter combat. | `74`-`79` |
| Luna | Stage 3 defeat | Good mage behind Brute/frontline, weak if bought allies stay unclear or undeployed. | `80`-`91` |
| Morrak | Stage 5 defeat | Strong brawler/tank swarm start; Berebell-style allies became the real carry. | `93`-`108` |
| Mortem | Stage 5 defeat with item retry | Item-sensitive; Nyxa/Bo support buys turned a failed max-bet opener into a long run. | `109`-`124` |
| Nyxa | Round 2 reached strongly | Clearest early carry; wants immediate frontline. | `02`-`10` |
| Paisley | Stage 5 planning/late defeat path | Weak solo impression, but item plus Sari/Berebell/Veyra/Morrak-style buys can climb. | `142`-`152` |
| Repo | Stage 1 defeat/retry failure | One of the weakest starts; item and Brute retry still failed to create a board. | `153`-`158` |
| Sari | Stage 5 planning loop | Good marksman with body density, but late Start Battle state repeated instead of cleanly resolving. | `125`-`140` |
| Teller | Stage 5 planning state | Strong opener and viable with slow deliberate buys; batch buying was unreliable. | `161`-`171` |
| Totem | Stage 5 planning state | Support starter needs item/allies; Morrak/Bo/Vykos/Mortem-style bodies did the work. | `172`-`182` |
| Veyra | Round 2 with item retry; max-bet stall | Default-bet item opener is viable, but max-bet opener exposed a long Battle Locked stall. | `183`-`186`, `205`-`207` |
| Volt | Stage 5 planning state | Item-assisted opener works, then Kythera/Nyxa/Morrak/Korath/Vykos-style allies carry. | `187`-`195` |
| Vykos | Stage 2 defeat | Very strong opener, but post-shop batch-buy/deploy failure left him alone for the loss. | `196`-`204` |

## Current Live UI Findings

1. Godot-AI is useful but unstable for long playtest loops.
   - `project_run`, `editor_screenshot(source="game")`, and `game_manage.input_mouse` work when the editor session is healthy.
   - Repeated `editor_manage(op="game_eval")` polling disconnects the plugin during live play.
   - Long waits can also leave the server with "No active Godot session", requiring process cleanup and editor relaunch.
   - Repeated `game_manage.input_mouse` shop-click batches can also drop the session; this happened during Bonko's Round 2 all-buy attempt.
   - After relaunch, `editor_screenshot(source="game")` initially returned a black 763-byte frame while runtime UI inspection still worked. Focusing the `Gamble Battle (DEBUG)` window restored real framebuffer captures.
   - A later live editor run restored fresh Bonko framebuffers and saved external screenshots under `C:\Users\Flipm\Documents\gamble-battle-playtest-audit\current_runs`, but an `editor_screenshot(source="game")` timeout after the Brute buy/drag attempt coincided with Godot-AI dropping back to zero active sessions.
   - Computer Use could see the `Gamble Battle (DEBUG)` window after the Godot-AI session dropped, but its window-state capture failed with `SetIsBorderRequired failed: No such interface supported (0x80004002)`, blocking a fallback OS-level drag continuation in that pass.
   - A later Bo positioning attempt dropped the editor registration again (`session_manage` returned `count: 0`) while the debug game process and `godot-ai` sidecar process were still running. This reproduced the same "no active Godot session" blocker without `game_eval` polling.
   - Saving screenshots inside the Godot project caused editor-import side effects (`.png.import` files appeared under `outputs/audit_playtest/manual_runs`). Moving later screenshots outside the project avoided new import churn and made the Brute setup screenshots stable, though it did not fix the Round 2 gameplay stall.
   - Godot-AI `input_mouse` uses the 1920x1080 runtime viewport coordinates, while `editor_screenshot(source="game")` saves 640x360 images. Screenshot-pixel clicks miss unless scaled.
   - Shop buying is more stable one click at a time than in batches. A Grint retry successfully bought one unit and kept the session alive; a three-click batch dropped Godot-AI to zero registered sessions.
   - A follow-up Korath attempt dropped Godot-AI to `session_manage.count = 0` before either `54_korath_planning.png` or `55_korath_round2_shop.png` could be saved, while the editor, debug game, and sidecar processes were still running.
   - A later Korath continuation reproduced the drop again during long result polling, but the MCP-launched debug game stayed playable. Capturing and clicking the real `Gamble Battle (DEBUG)` window through OS input kept the run moving after Godot-AI lost its active session.
   - Practical impact: exhaustive manual starter playtesting is currently slower and less reliable than it should be.

2. The opening shop is technically blocked but still invites clicking.
   - Reroll, Lock, Buy XP, and empty shop cards did not change gold, XP, offers, or level during the forced first fight state.
   - The UI still presents these controls in the player decision area, so the player naturally tries them.
   - Better solution: render the opening shop as a single disabled "Win first fight to open shop" panel, or give the player an actual first recruit/shop decision before combat.
   - Current branch resolution: the opening shop now renders as one explicit `OPENING FIGHT` / `Win this opener to unlock the shop` panel, and activating that locked panel shows `Opening fight is fixed. Win it to unlock the shop.` via the existing shop message label.

3. Normal runs currently start with dev item inventory enabled.
   - Components and remover are visible immediately in the left item panel.
   - This is useful for testing item mechanics but contaminates balance/playtest reads.
   - Kythera looked like a solo Round 1 loser in the supporting runner, but an item-assisted manual opener reached Round 2. That is useful mechanic evidence, but it also shows the current dev inventory can flip perceived starter viability.
   - Better solution: gate `Items.DEV_STARTER_INVENTORY_ENABLED` behind a debug flag/profile and keep production playtests inventory-clean.

4. Nyxa is the clearest early carry so far.
   - Manual UI run: Nyxa won Round 1 and reached Round 2 with 3 gold and shop offers.
   - Supporting runner data: Nyxa had the strongest Stage 2 damage read among the selectable starters, with 802 Stage 2 damage and 1631 total damage across her two-stage run.
   - Best practical direction: pair Nyxa with immediate frontline, especially Grint/Vykos/Brute-style bodies when available.

5. Shop/start hit targets need more breathing room.
   - In the Nyxa manual run, clicking shop cards for Grint/Vykos/Veyra appeared to leave the run in `Battle Locked` with only 1 gold spent.
   - This may be a coordinate/playtest artifact, but it mirrors a real user risk: compact shop cards, the Start Battle button, and bottom controls are tightly clustered at 1080p.
   - A current live Bonko max-bet recheck also produced an unclear Buy XP interaction: clicking the inspected Buy XP button center reduced the live model gold from 4 to 3 while XP stayed at 0, level stayed at 1, and visible labels still showed the pre-click state.
   - The current rapid rendered-card runner did not reproduce a battle lock: five same-frame shop-card presses stayed in preview, produced five bench units, and resolved the next fight. That lowers transaction-risk but does not eliminate live pointer/hit-target risk.
   - Current branch mitigation: the gothic theme now spaces shop cards with wider gutters, gives the command strip more separation, and preserves the immediate `Combat Resolving...` transition on `Start Battle`. Fresh OS-window capture `08_round2_shop_wait.png` confirms the first real shop still fits the 1080p debug window after the spacing pass.
   - Better solution: preserve this spacing and add stronger purchase/deploy feedback only if future natural full-run play still shows pointer misses under pressure.

6. Bench-to-board deployment is mechanically required and now has first-purchase assist, but manual drag clarity still needs watching.
   - Existing shop docs and `tests/visual/actual_run_loop_smoke.gd` confirm shop purchases go to `BenchGrid`; bought units must then move from bench to board before they help.
   - Berebell's Vykos/Brute purchases succeeded, but the visual affordance was unclear and the player timer was nearly expired before I could confidently deploy them.
   - Bo's Round 2 shop offered `Grint`, `Luna`, `Totem`, `Bonko`, and `Mortem`. I attempted to buy Grint frontline plus Bonko/Mortem brawler pressure; only one visible purchase/deployment clearly landed before the run entered `Battle Locked`.
   - Grint's retry bought a backline damage unit from the shop, but a real mouse drag from the first bench slot to `TileP_16` did not move it. The bought unit remained selected on the bench and the right stats panel updated to that unit instead.
   - Korath's recovered run proved the intended drag can work after the later interaction fixes: a bought Berebell moved from the first bench slot to the board, then additional units were deployed in later rounds.
   - Current live Bonko recheck repeated the problem after the cost-tier pass: buying Brute from the Round 2 level-1 shop worked, but a first drag attempt left `board_ids` as `["bonko"]` and `bench_ids` as `["brute"]` with about 8 seconds left in planning.
   - Current branch mitigation: first post-fight purchase now shows `Bought <unit>. Drag it from bench to board.`, emits the first-deploy assist path, logs `Deploy <unit>: drag the glowing bench unit to a highlighted board cell.`, highlights the player grid plus the bought bench slot/unit, and extends short planning time to 20 seconds.
   - Fresh `ActualRunLoopSmoke` proves the prompt, signal connection, timer extension, bench placement, bench highlight, bench-to-board move, highlight clearing, next fight resolution, and reset recovery with `errors: []`.
   - The 2026-06-25 real-window deploy release recheck exposed one remaining correctness bug: OS dragging could start a ghost but fail to drop if release happened outside the source `UnitView`. `DragAndDroppable` now handles global mouse motion/release while dragging, and the patched OS-window pass bought Cashmere, dragged it from bench to board, emptied the bench, and reported `completion_reported=true`.
   - Remaining UX risk: physical mouse drag/hit clarity can still feel fragile under real pressure, but the board-cell guidance, bench-slot guidance, and active-drag release path now have direct behavioral and OS-window coverage; future visual/manual passes can focus on speed/pressure polish.

7. Round 2 used to stall in Battle Locked with no visible progress; indefinite hangs are now guarded mechanically.
   - Bo reached Round 2 with 4 gold, showed a nonzero Round 1 scoreboard, then entered a battle-locked Round 2 state after the shop-buy attempt.
   - After 50 seconds, the screenshot still showed the same active-board state, `Battle Locked`, `Gold: 1`, `Bet: 1 (locked)`, and scoreboard Bo damage at 0.
   - Brute reproduced the stall from a cleaner external-screenshot run: Round 2 shop was `Luna`, `Teller`, `Teller`, `Bonko`, `Bo`; clicking Teller spent 1 gold, immediately battle-locked the run, overlapped a pink unit/effect on Brute, and after 50 seconds still showed `Battle Locked`, `Gold: 1`, and 0 scoreboard damage.
   - Cashmere reached Round 2 and then reproduced a battle-locked no-resolution state after the planning timer elapsed. The final capture still showed Stage 1 - Round 2/6, `Battle Locked`, and 0 Cashmere scoreboard damage.
   - `get_debug_output()` reported no script errors, while Godot-AI game logs still marked the run as active and showed repeated movement-vector lines. This looks like a combat progression/movement stall, not a clean defeat.
   - Current branch mitigation: `CombatEngine` has a 45-second absolute combat timeout and 12-second no-progress timeout, each forcing a result from the current board state.
   - Fresh `CombatWatchdogSmoke` proves both timeout paths stop battle, emit the expected watchdog log line, and finish with `errors: []`.
   - Fresh `CombatResolvingFeedbackSmoke` proves the visible button state stays immediate as `Combat Resolving...`, then advances to elapsed `Resolving Ns...`, warns as `Still resolving Ns...` after 10 seconds, and switches to `Resolving fallback...` when a watchdog log arrives. `CombatResolvingFeedbackVisualSmoke` adds live-renderer screenshots for all four label states.
   - Remaining UX risk: elapsed/fallback feedback is now smoke-covered and visually captured through a controlled live-renderer path, but not yet captured from a naturally long real-window fight.

8. Late-round Start Battle feedback is easy to misread.
   - Luna's Round 3 and Morrak's Round 5 both had moments where Start Battle appeared not to take immediately; a later capture showed the game had either entered `Battle Locked` or eventually resolved after a second click/wait.
   - Sari's Round 5 was worse: repeated Start Battle attempts and long waits kept returning to Stage 1 - Round 5 planning with changing shops/gold/scoreboard values instead of a normal defeat or clear.
   - This may be normal timer/combat delay, but the user-facing state does not distinguish "click missed", "combat queued", and "fight is running slowly."
   - The current Start Battle feedback runner shows the automated Main flow still switches immediately to disabled `Combat Resolving...` at Stage 2, 3, and 4 and enters combat phase with an active engine.
   - Current branch mitigation: the same button now reports elapsed resolving time after the short delay and a fallback label if the combat watchdog has to force a result.

9. A failed opener can create a bad retry economy state.
   - Manual Axiom run: after the forced opener, the game stayed on Stage 1 - Round 1 with 1 gold and a populated shop.
   - I tried to buy the best visible damage/body option from the shop before retrying. The UI instead entered `Battle Locked`, bet locked, gold 0, and showed "Purchasing this now would kill you."
   - This is especially punishing for support starters: the unit most in need of help gets shown the help, then the buy/start/economy rules make the interaction feel broken.
   - Better solution: after a Round 1 loss, either give enough gold to buy exactly one unit safely, make the reserve-floor rule clear before the click, or route loss directly to New Game if retry is not intended.
   - Current branch mitigation: non-broke Chapter 1 Stage 1 defeats recover to 2 gold before the retry shop opens. `AxiomRetryChoiceQualitySmoke` verifies the configured Axiom retry helpers all advance under a test-forced hard opener, and `AxiomRetryEconomySmoke` verifies the forced retry shop starts with one of those helpers, then Axiom can buy it, keep 1 gold, deploy it to board, clear the first-deploy highlight, and progress into Stage 2.

10. Loss screen stats can become misleading after a retry.
   - Axiom had visible scoreboard damage of 195 after the first attempt.
   - The final defeat overlay after the retry reported Team Damage 0 and Top Damage: Axiom (0).
   - Berebell also showed a nonzero scoreboard during the run, then the Stage 2 defeat overlay reported Team Damage 0 and Top Damage: Berebell (0).
   - Better solution: clarify whether the loss screen reports the final battle only or the run total, and avoid showing zeroed stats when the run already produced visible combat stats.
   - Current branch mitigation: `StatsTracker` now keeps run totals until a new run, `LossScreen` reports run-total summary copy, and the embedded ledger is labeled `Final Battle Damage`. `LossScreenSmoke` verifies a prior Axiom damage/kills battle remains visible after a later final-battle reset.

11. Betting is no longer adjustable in the opener. Closed in the current branch.
   - The bet defaults to 1 and locks during combat.
   - Previous issue: the first fight effectively asked the player to accept the default because there was no meaningful pre-fight economy choice. Korath could drag the bet slider to 2 before the opener; it locked correctly and paid out enough to reach 4 gold for Round 2, but the choice was not yet strategic.
   - Current branch mitigation: `EconomyUI` hides and disables the adjustable slider during the forced first fight, shows fixed `Opening bet: 1` copy, and explains that betting opens after the first shop. `UIThemeSmoke` guards this opener state.

12. Buy XP works; preserve explicit reserve/economy feedback.
   - Korath's Stage 5 planning state had 7 gold. Buying XP changed `Lvl 1 (0/2)` to `Lvl 2 (2/6)` and left 3 gold before purchases.
   - Subsequent low-gold buying originally surfaced "Purchasing this now would kill you" even after a strong run, so the reserve-floor rule needed clearer preview and affordance.
   - Mortem and Sari later exposed a related click-feedback problem: XP and late shop buys did not always visibly apply even with enough gold, and subsequent states made it hard to tell whether the click missed, the timer advanced, or the purchase was rejected.
   - The current premium deploy runner reproduced the clean boundary: at 4 gold, Buy XP does not level; after one audit gold grant, Buy XP succeeds and updates to `Lvl 2 (2/6)`.
   - The live-window signal-path recheck confirmed the same input behavior visually: once the UI showed `Gold: 5`, an OS click on Buy XP changed the visible label to `Lvl 2 (2/6)`.
   - The tracked natural Buy XP visual smoke confirmed a non-granted route: ordinary Bonko opener reward outcomes can naturally produce a safe `Gold: 5` Buy XP moment as early as Round 2; clicking the visible button advances to `Lvl 2 (2/6)` and repaints gold to 1.
   - The refreshed historical natural Buy XP runner and current `BuyXPTransactionalFeedbackSmoke` rerun also confirm the denied 4-gold click now emits `Need +1 gold to buy XP and keep 1 health.` as visible UI feedback.

13. Scoreboard identity was unclear with duplicates. Closed in the current branch.
   - Morrak's Stage 5 run showed two separate `Berebell` scoreboard rows, and the duplicate visual runner confirmed they originally rendered as `Berebell 1.5k` and `Berebell 1.4k` with no visible identity disambiguator.
   - The current branch adds copy suffixes for repeated display names and covers them with `ScoreboardDuplicateDisambiguationSmoke`.
   - Future polish can still choose star levels, board slots, or merged aggregate rows, but duplicate copy labels are no longer a blocker.

14. Hexeon exists in data but is not starter-selectable. Closed for the current cost-tier branch.
   - Live Unit Select now exposes the current 12 cost-1 starter buttons, not the older 21-unit starter surface.
   - `CostBalanceSmoke` guards Hexeon as the single cost-3 capstone and verifies premium/capstone units are not starter-visible at level 1.
   - `UnitSelectSmoke` now guards the rendered picker directly by comparing button ids against `UnitCatalog.list_starter_ids(STARTING_LEVEL)`, asserting all rendered starters are cost 1, and failing if Hexeon appears.

15. Lower Unit Select scrolling could leave stale inspection context, and the initial preview could imply Axiom was already inspected. Closed in the current branch.
   - The original manual screenshot showed Teller/Totem/Veyra/Volt/Vykos visible after scrolling while the right preview still read like Cashmere was being inspected.
   - Current `UnitSelectSmoke` covers the intended behavior: the screen starts with `No champion chosen` and no default art, hover preview changes to `Inspecting ...`, scroll/focus clearing drops stale hover state without selecting a unit, and the preview returns to `No champion chosen`.
   - `UnitSelectPreviewVisualSmoke` adds current live-renderer screenshots for the neutral, hover, and cleared-preview states. The current 12-starter roster fits without a real scrollbar, so repeat the visual pass against an actual scrolled grid if starter count expands again.
   - Preserve this scroll/focus clearing behavior unless a future redesign binds the preview to an explicit selected or focused starter.

16. Batch shop-buying and deployment are not reliable enough for speed play.
   - Teller's first full-shop batch buy appeared to spend little and left only Teller fighting; a slower one-by-one purchase/deploy sequence worked and reached Stage 5.
   - Vykos had a strong opener, but batch-buying damage support left him effectively alone again and the run died at Stage 2.
   - This makes the game feel hostile to efficient play even when the intended strategy is obvious.
   - The current rapid rendered-card runner now covers the same-frame transaction path and five direct drag-lifecycle deploys cleanly, so the remaining risk is visual/physical interaction clarity rather than known transaction corruption.
   - Current branch mitigation: `ShopPurchaseFeedbackSmoke` now guards the real `ShopPresenter` single-purchase path: the click spends the card cost, places the unit on bench, shows `Bought <unit>. Drag it from bench to board.`, and replaces the purchased card with explicit `SOLD` / `On bench` copy plus a bench tooltip.
   - Remaining polish: purchase sound and stronger bench flash can still improve feel, but the disabled sold-card and clear bench/deploy state are now committed behavior.

17. First-fight movement/edge cases are no longer current level-1 starter blockers. Closed for the current cost-tier branch.
   - Previous issue: Paisley, Totem, and Veyra all produced long first-fight waits or edge-position oddities before either resolving or continuing to Round 2. Veyra's max-bet opener remained in `Battle Locked` across multiple waits, but the same starter reached Round 2 on a default-bet item retry.
   - Current branch mitigation: Paisley, Totem, and Veyra are now cost-2 units, while `CostBalanceSmoke` and `UnitSelectSmoke` guard that only the current 12 cost-1 units are level-1 starter-visible. `AllStarterMainFlowAudit` covers those current starters through the first Main-flow loop, with `AxiomRetryEconomySmoke` covering the support-starter retry outlier.
   - No-progress and absolute combat timeouts remain covered by `CombatWatchdogSmoke`, with visible long-resolution copy covered by `CombatResolvingFeedbackSmoke`.
   - Remaining work is premium-unit/post-shop movement tuning if future level-2 fights still read as frozen, not a current forced-opener starter blocker.

## Supporting All-Starter Runner Results

These results are useful balance evidence but should not be treated as completed strategic UI playthroughs. They used the ignored audit runner under `outputs/audit_playtest`, not manual shop/position/item decision-making for each unit.

| Unit | ID | Role | Goal | Wins | Highest stage | First loss | Total player damage |
|---|---|---|---|---:|---:|---:|---:|
| Axiom | `axiom` | support | `support.team_amplification` | 0 | 1 | 1 | 195 |
| Berebell | `berebell` | brawler | `brawler.frontline_disruption` | 1 | 2 | 2 | 1451 |
| Bo | `bo` | brawler | `brawler.skirmish_dive` | 1 | 2 | 2 | 1254 |
| Bonko | `bonko` | brawler | `brawler.attrition_dps` | 1 | 2 | 2 | 1512 |
| Brute | `brute` | tank | `tank.frontline_absorb` | 1 | 2 | 2 | 1467 |
| Cashmere | `cashmere` | mage | `mage.pick_burst` | 1 | 2 | 2 | 956 |
| Grint | `grint` | tank | `tank.initiate_fight` | 1 | 2 | 2 | 1602 |
| Korath | `korath` | tank | `tank.frontline_absorb` | 1 | 2 | 2 | 1210 |
| Kythera | `kythera` | tank | `tank.team_fortification` | 0 | 1 | 1 | 783 |
| Luna | `luna` | mage | `mage.wombo_combo_burst` | 1 | 2 | 2 | 1084 |
| Morrak | `morrak` | brawler | `brawler.attrition_dps` | 1 | 2 | 2 | 1317 |
| Mortem | `mortem` | brawler | `brawler.attrition_dps` | 1 | 2 | 2 | 1282 |
| Nyxa | `nyxa` | marksman | `marksman.backline_siege` | 1 | 2 | 2 | 1631 |
| Paisley | `paisley` | mage | `mage.wombo_combo_burst` | 0 | 1 | 1 | 359 |
| Repo | `repo` | tank | `tank.single_target_lockdown` | 0 | 1 | 1 | 551 |
| Sari | `sari` | marksman | `marksman.sustained_dps` | 1 | 2 | 2 | 1430 |
| Teller | `teller` | marksman | `marksman.tank_shredding` | 1 | 2 | 2 | 1069 |
| Totem | `totem` | support | `support.peel_carry` | 0 | 1 | 1 | 642 |
| Veyra | `veyra` | tank | `tank.frontline_absorb` | 1 | 2 | 2 | 1123 |
| Volt | `volt` | mage | `mage.pick_burst` | 0 | 1 | 1 | 567 |
| Vykos | `vykos` | brawler | `brawler.attrition_dps` | 1 | 2 | 2 | 1648 |

Summary from supporting data:
- Fifteen starters beat Round 1 and then lost Round 2.
- Six starters lost Round 1: Axiom, Kythera, Paisley, Repo, Totem, and Volt.
- No level-1 solo starter cleared Round 2.
- Level-2 solo checks against a four-enemy creep mix also all lost.
- Item spot checks improved numbers but did not flip the outnumbered fights: `doubleblade` helped Cashmere, `mind_siphon` helped Nyxa, and `blood_engine` helped Korath.

## Strategy Notes So Far

These strategy notes intentionally keep the old manual unit reads, but the mechanical failure descriptions are historical unless repeated on the current branch. The current branch has mechanical coverage for the former opener gating, shop transaction, deploy assist/global release, combat watchdog, Buy XP feedback, duplicate scoreboard, and Unit Select preview issues; remaining strategy work is about early composition quality, pacing, and real-window feel.

Current 2026-06-26 automated strategy refresh from `AllStarterLiveCapture` after opener tuning and the expanded starter-aware first-shop guard:
- Reliable mechanical path: all 12 current starters reach the first shop, buy a rendered affordable helper, show the deploy prompt, move the helper from bench to board, and resolve the second fight without shop errors.
- Clean default first-card resolution lines: all 12 current starter lines resolve the second fight after the first clicked helper. Some still return to Stage 2 rather than advancing beyond it, so the durable contract is second-fight resolution and no stuck/retry state rather than universal Stage 3 advancement.
- Soft-fail/pressure lines: none in the refreshed default-click replay. No current starter enters the opener retry state in the production default-bet replay.
- Axiom no longer needs the opener retry path in production. That retry path still has its own configured slot-0 helper guard, and all five configured retry helpers advance in `AxiomRetryChoiceQualitySmoke` under a test-forced hard opener.
- Current first-shop choice sensitivity audit: Bo, Bonko, Cashmere, Korath, Mortem, Repo, and Sari each have at least one first-shop helper that advances beyond Stage 2, but 12 of 35 slot trials still fail to advance. Axiom as the first helper failed in both tested committed pairings, Bo/Brute is confirmed as a current non-advancing pairing, and redundant defensive tank helpers remain risky.
- Current starter-aware first-shop sampling guard: over 240 seeded `ShopRoller.roll_opening_for_starter(...)` shops, every guarded starter saw a known advancing helper in slot 0 with a `first_good` rate of 1.000, and configured blocked helpers were absent from all sampled guarded opening shops. The guard now also asserts expected matrix-proven traps are present in the config, including the added Bo/Brute blocker. This closes random-offer dead ends, protects the default first click, and removes the known first-shop trap cards for those starters.
- Tracked first-shop matrix detail now lives in `docs/starter_first_shop_choice_matrix_2026-06-26.md`: latest committed guard telemetry is 23 of 35 advancing forced helper choices plus the starter-aware slot-0 and blocked-helper sampling read. Repo's guard list remains conservative because Sari is the only proven advancing helper in the committed matrix.
- Planned mid-run progression evidence: `MidRunProgressionSmoke` adds one audit-assisted Bonko board-width line that buys and deploys Morrak/Grint, Sari/Brute, and Berebell/Bo through the real Main scene, then advances Stage 2 -> 3 -> 4 -> 5 with no debug errors. This narrows the mechanical risk that later shops cannot sustain a reasonable planned line, but it is not random later-shop balance or all-starter long-form coverage.
- Seeded random later-shop evidence: `RandomLaterShopProgressionSmoke` adds all 12 current starter samples where later shop rows are natural from seeded live Shop RNG, the picker buys visible cards by a simple board-width/frontline-first heuristic, and every sample reaches Stage 5. This narrows the random-offer quality concern across starter breadth, but only under audit gold and one seed per starter.
- Current audit interpretation: the mechanical blockers, normal first-shop default-card quality, known first-shop trap-card exposure, fallback retry-shop default-card quality, one deterministic mid-run planned line, and all-12 one-seed seeded natural-offer later-shop samples are covered. The live design backlog is natural-economy pacing, deeper later-shop seed coverage, and fresh real-window screenshot evidence outside the protected opening-shop path.

- Axiom manual result: lost the opener, reached a retry shop with 1 gold, could not convert the shop into a useful board, then lost the run. This validates that pure support is a poor starter under the current forced-solo opener.
- Berebell manual result: won the forced opener, reached Round 2 with 3 gold, bought Vykos for brawler synergy and Brute for frontline, then still lost Round 2. The buys behaved correctly and left 1 gold, but manual placement/bench affordance was unclear before the timer expired.
- Bo positioning attempt: selected after the Berebell New Game reset to test buying plus bench-to-board drag placement, but Godot-AI lost the active editor session before Bo screenshots could be saved. Existing code context says the correct manual move is bench `UnitView` drag/drop to a `TileP_*` board cell; the smoke test bypasses input by calling `move_router._bench_to_board`.
- Bo recovered manual result: won the forced opener, reached Round 2 with 4 gold, and rolled `Grint`, `Luna`, `Totem`, `Bonko`, `Mortem`. Intended line was Grint frontline plus Bonko/Mortem brawler pressure, but the buy/placement flow entered `Battle Locked`; after 50 seconds Round 2 still had no visible resolution and Bo's scoreboard remained at 0.
- Brute manual result: won the forced opener, reached Round 2 with 3 gold, and rolled `Luna`, `Teller`, `Teller`, `Bonko`, `Bo`. Intended line was Teller backline damage behind Brute, but clicking Teller spent 1 gold and immediately created a battle-locked no-resolution state before a normal bench drag could happen.
- Cashmere manual result: won the forced opener slowly, reached Round 2, and then reproduced the no-resolution `Battle Locked` state. Best line would have been immediate frontline support, but the timer/lock state overtook the shop phase.
- Grint manual result: won the forced opener, reached Round 2, and bought one backline damage unit while trying to preserve a Grint frontline. The bench-to-board drag failed; starting Round 2 with the bought unit undeployed ended in a Stage 2 defeat overlay reporting Team Damage 0 and Top Damage: Grint (0).
- Bonko manual result: won the forced opener cleanly and reached Round 2 with 5 gold and a strong shop (`Repo`, `Bo`, `Korath`, `Grint`, `Nyxa`). Best line was to buy immediate board width: Nyxa carry plus Grint/Korath frontline, with XP delayed.
- Korath recovered manual result: max-bet opener won, Round 2 shop bought and deployed Berebell, later added Grint/Teller/Repo-style board width, bought XP on Stage 5, and finally lost on Stage 5. Best line so far was tank starter plus immediate brawler/frontline width; Berebell carried top damage at 663 on the defeat overlay.
- Kythera recovered manual result: item-assisted opener reached Round 2, but the Round 2 buy/deploy sequence still ended as a Stage 2 defeat with only Kythera on the defeat scoreboard. Best line needs an ally before combat; as a pure starter she still reads weak, but item support can make her opener look viable.
- Luna recovered manual result: max-bet opener reached Round 2, adding Brute let the run clear Round 2, and the run ended at Stage 3. Best line is Luna behind an immediate tank; bench units that are bought but not clearly deployed do not help and make the run feel worse than the visible shop suggests.
- Morrak recovered manual result: max-bet opener won, Kythera/Repo/Berebell/Teller-style board width carried through Stage 5, and final defeat reported 4206 team damage with Berebell top damage at 1754. Best line is brawler/tank swarm width before XP; Morrak himself was solid but not the carry once Berebell entered.
- Mortem recovered manual result: max-bet opener lost at Stage 1, but an offensive item retry reached Stage 5. Nyxa and Bo were key support buys, and the final defeat reported 3321 team damage with Mortem top damage at 1050. Mortem is much more sensitive to item support and early carry/frontline purchases than the runner result implied.
- Sari recovered manual result: max-bet opener won, Brute/Morrak/Vykos/Mortem-style body density carried her to Stage 5, but Round 5 entered a repeated planning/start ambiguity rather than a clean final defeat. Best line is still frontline plus brawlers before XP; Vykos overtook Sari on several scoreboard reads.
- Paisley recovered manual result: item-assisted opener eventually reached Round 2 after a long wait, then Sari/Berebell/Veyra/Morrak-style buys carried the run to Stage 5. Paisley can ride a strong board, but she is not the early carry; the first item and first shop matter heavily.
- Repo recovered manual result: item-assisted opener still produced a Stage 1 retry economy with 1 gold; buying Brute and retrying still ended in Stage 1 defeat with only Repo on the defeat overlay. Repo remains one of the weakest starts under the current forced-solo format.
- Teller recovered manual result: max-bet opener reached Round 2 with 6 gold, but the first full-shop batch-buy/deploy attempt failed to produce a wider board. Slowing down to buy and deploy one unit at a time worked, and a Volt/Repo/Grint/Kythera/Axiom-style board reached Stage 5. Teller is a real starter if the player resists batch inputs and prioritizes board width.
- Totem recovered manual result: item-assisted opener eventually reached Round 2 after a long wait, then Morrak/Bo/Vykos/Mortem/Teller-style purchases carried to Stage 5. Totem's own scoreboard impact stayed modest; he needs allies immediately and should not be presented as a satisfying solo damage start.
- Veyra recovered manual result: max-bet opener exposed a Battle Locked stall, but a default-bet item-assisted retry reached Round 2 with 4 gold and shop offers `Mortem`, `Berebell`, `Teller`, `Paisley`, and `Volt`. Best line is Veyra frontline plus immediate damage, especially Mortem/Teller/Volt if the buy/deploy flow is stable.
- Volt recovered manual result: item-assisted opener reached Round 2, and later Kythera/Nyxa/Morrak/Korath/Vykos-style allies pushed to Stage 5. Volt did not remain the carry once stronger allies entered, but he can be a viable start if item support or a first-shop frontline arrives.
- Vykos recovered manual result: max-bet opener was one of the clearest wins, showing about 1.0k opener damage. The run still died at Stage 2 because batch-buy/deploy support failed to enter cleanly; Vykos wants immediate second-body support but the current UI can erase that strategic intent.
- Best early pattern: start with a high-output unit or immediately add one; then buy frontline.
- Frontline bodies matter more than pure support early because Round 2 becomes an outnumbered swarm check.
- Support starters need immediate help. Axiom and Totem are not satisfying solo starts because their identity depends on allies they do not have.
- Fragile mages and utility tanks need a better first decision. Paisley, Volt, Repo, and Kythera all create weak first impressions under the forced solo opener.
- If the shop offers frontline plus damage after Round 1, buy bodies before XP. XP is too expensive at 4g when the player has 3g and needs board width immediately.

## Priority Fixes

1. Preserve the explicit short-prologue framing for the fixed opener: `Start Opening Fight`, `OPENING FIGHT`, `Win this opener to unlock the shop`, fixed `Opening bet: 1`, disabled shop controls, and direct locked-control feedback.
2. Preserve the now-proven Chapter 1 recovery path where a good Round 1 result plus one reasonable purchase survives, and where Axiom's configured retry helper line can progress into Stage 2; future tuning should target broader choice quality, strategic clarity, and clear speed rather than the former hard-survival blocker.
3. Preserve dev starter inventory gating: `Items.DEV_STARTER_INVENTORY_ENABLED` defaults false, `DevStarterInventorySmoke` proves normal `reset_run()` keeps inventory and visible slots empty, and starter item seeding only happens when the dev flag is explicitly enabled.
4. Preserve the clearer fixed opening-fight placeholder and its direct click/keyboard feedback if players still try the locked opener controls.
5. Preserve the widened spacing and hit clarity between shop cards, shop buttons, betting, and Start Battle.
6. Completed item dynamic effect cleanup is now guarded: all completed items declare runtime effect ids, Hemothorn's unsupported `pct_omnivamp` stat key was converted to supported `pct_lifesteal`, `CompletedItemEffectRegistrySmoke` fails future completed items that declare missing/unregistered effects or unsupported stat keys, and `CompletedItemRuntimeEffectsProbe` fails effects that do not change combat state.
7. Preserve and extend the debug in-game Audit QA controls for manual playtests: state export, screenshot status, restart, timer hold, and speed controls that do not require fragile repeated Godot-AI eval calls.
8. Preserve first-purchase deploy assist and drag release handling: prompt text, highlighted board cells, short-timer extension, and global release/drop cleanup must stay covered so bought units are actually fielded in early manual runs.
9. Preserve the combat no-progress and absolute-timeout watchdogs plus the visible resolving feedback labels; capture a natural real-window long-fight example if manual play ever sees one.
10. Preserve the post-win planning beat: `PostCombatPlanningBeatSmoke` now proves the intermission bar appears before planning returns, then restores a full shop, enabled `Start Battle`, and at least 55 seconds of planning time so the next shop decision is not silently consumed.
11. Preserve the now-passing rapid rendered-card buy/deploy behavior and the audit-assisted real-window OS-coordinate burst result; broaden only if future natural full-run play exposes human-speed hit-target or feedback issues.
12. Preserve the now-covered Unit Select neutral preview and scroll/focus behavior: the screen should start with no inspected champion, and scrolling away from a hovered starter should clear stale inspection copy instead of leaving the previous unit in the preview panel.
13. Preserve the now visually verified `Combat Resolving...` Start Battle transition, elapsed resolving labels, long-wait warning, and watchdog fallback text; capture a natural real-window long-fight example only if manual play produces one.
14. Preserve Buy XP transactional feedback: `BuyXPTransactionalFeedbackSmoke` guards the presenter path and `NaturalBuyXPVisualSmoke` guards the natural visible success frame. If the click is unaffordable, show the reserve-floor reason; if it succeeds, keep gold/level/XP labels repainting immediately and make any reroll/shop refresh rules visible.
15. Preserve the now-fixed defeat modal ownership: the top-right system Menu hides, disables, and cannot open while the defeat overlay is active.
16. Preserve the now-explicit player-only defeat scoreboard: keep enemy ledger rows out of the loss modal unless a future design pass intentionally adds an enemy-comparison section.
17. Preserve duplicate scoreboard copy suffixes for repeated unit names unless a future stats UX pass deliberately replaces them with board slot, star/level, or aggregate-row context.
