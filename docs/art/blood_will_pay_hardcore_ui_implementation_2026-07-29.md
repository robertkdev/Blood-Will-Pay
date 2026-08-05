# Blood Will Pay Hybrid UI Implementation

Date: 2026-07-29

## Direction

The implemented visual split is deliberate:

- Out-of-world decisions use distressed hardcore-poster graphics: title command surfaces, menus, buttons, hover/focus/pressed/disabled states, roster selection, shop actions, wagering, contracts, results, loss, and transient combat callouts.
- The world-facing game remains gothic: arena, battlefield, unit preview plates, storage, bench, statistics, scoreboard, and persistent combat architecture.
- Bone paper, black ink, oxidized gold, and blood red tie the two styles together. Poster red is reserved for interaction and pressure so the contrast does not flatten the dark arena.

The pre-generation replacement inventory is
`docs/art/blood_will_pay_hardcore_ui_asset_inventory_2026-07-29.md`.

## Asset kit

- 178 exact-size PNG assets in `assets/ui/hardcore/` and `assets/ui/gothic_v3/`.
- Nine complete interactive state families covering normal, hover, pressed, focus, disabled, selected, and selected-hover where applicable.
- Full-screen poster backdrop, menu rail/content plates, modal/result/loss panels, roster cards, shop cards, wager/action buttons, contract choices, pressure banners, stage frames, and gothic in-world plates.
- Source generations are retained under `tools/art/source/hardcore_ui_2026_07_29/`.
- `tools/art/recover_hardcore_ui.py` performs deterministic crop, exact resize, alpha/shape recovery, and dimension auditing. Its report is `tools/art/source/hardcore_ui_2026_07_29/recovery_report.json`.
- `scripts/ui/hardcore_ui_assets.gd` is the single typed runtime loader and `StyleBoxTexture` factory.

## Wired surfaces

- Title gateway and full poster command menu, including settings, inputs, checkboxes, sliders, popup menus, navigation, focus, hover, pressed, and disabled states.
- System/pause menu and all actions.
- Starter roster, card hover/selection/focus states, gothic unit preview, and start CTA.
- Black Ledger rows and frame hierarchy.
- Shop cards and live tooltip, reroll/lock/XP/start-battle actions, wager slider, all-in state, gold plate, and compact footer.
- Team-metric tabs, team tabs, scoreboard rows, and statistics panel.
- Contract market, ascension choices, reinforcement/hazard decisions, and post-combat planning beats.
- Victory, bounty, defeat, stalemate, and final-loss presentation.
- Arena pressure stages, escalation frames, hazard/reinforcement callouts, impact intensity, intermission track, and fill.

## State and size contract

- Generated controls are applied through exact native control sizes or nine-slice margins; they are not promoted as arbitrary stretched image output.
- Interactive families are validated for every declared state by `tests/visual/HardcoreUIAssetAudit.tscn`.
- The visual state matrix is rendered by `tests/visual/HardcoreUIStateGallery.tscn`.
- Runtime proof includes a real title-menu hover, selected roster state, system menu, live shop-card hover with tooltip, battle result, loss, ledger, contracts, and escalating arena pressure.

## Validation evidence

Passing:

- `HardcoreUIAssetAudit.tscn`: 178 assets, 9 state families, 7 state classes.
- `TitleMenuSmoke.tscn`
- `AccessibilitySettingsSmoke1920.tscn`
- `SystemMenuHoverStabilitySmoke.tscn`
- `UnitSelectSmoke.tscn`
- `BlackLedgerSmoke.tscn`
- `LossScreenSmoke.tscn`
- `ContractSystemVisualCapture.tscn`
- `EncounterEscalationVisualCapture.tscn`
- `PostCombatPlanningBeatSmoke.tscn`
- `StatsPanelClickSmoke.tscn`
- `CompactShopFooterSmoke.tscn`
- `PostShopLayoutCapture.tscn`
- `UIThemeSmoke.tscn`
- `RoleMatrixProbe.tscn`: failed 0, skipped 0, errors 0.
- Full `RGATesting.tscn`: 48 rows; `RolesMetrics` failed 0, skipped 0, errors 0.

Fresh real-game captures:

- `%APPDATA%\Godot\app_userdata\Blood Will Pay\hardcore_ui_real_menu_hover_2026_07_29.png`
- `%APPDATA%\Godot\app_userdata\Blood Will Pay\hardcore_ui_real_shop_hover_2026_07_29.png`
- `%APPDATA%\Godot\app_userdata\Blood Will Pay\hardcore_unit_select_runtime_2026_07_29.png`
- `%APPDATA%\Godot\app_userdata\Blood Will Pay\hardcore_system_menu_runtime_2026_07_29.png`
- `%APPDATA%\Godot\app_userdata\Blood Will Pay\hardcore_battle_result_runtime_2026_07_29.png`
- `%APPDATA%\Godot\app_userdata\Blood Will Pay\hardcore_ui_state_gallery_2026_07_29.png`

Telegram review trail: messages 3704-3716.

`ShopCardHoverSmoke` now captures its own framebuffer proof and routes hover
motion through Godot's input pipeline, so the same test covers the generated
tooltip asset, targeting copy, viewport containment, reroll cleanup, and
hover-exit cleanup. `CompactViewportVisualAuditSmoke` remains unsuitable as a
release gate because its direct synthetic 720p construction does not match the
authoritative responsive runtime; `CompactShopFooterSmoke` and the real 1080p
game remain the compact-layout gates.

## First independent audit and repair

The first clean-checkpoint audit correctly returned FAIL against `8dd2750`.
Its three player-facing defects were repaired before requesting another review:

- The victory/defeat/stalemate card is now hidden when the two-second intermission completes, before planning resumes. `PostCombatPlanningBeatSmoke` asserts that the card is gone while the restored planning timer is still at least 55 seconds.
- The 1920x1080 starter layout now reserves 940 vertical pixels, uses a 320-pixel portrait, clips the details scroller, and contains all Axiom targeting copy above Start Game. `UnitSelectSmoke` verifies the clipping and geometry.
- The gothic gateway now shows a restrained `CLICK OR PRESS ANY KEY` affordance while retaining its full-screen accessible interaction surface. `TitleMenuSmoke` verifies the prompt and input handoff.

Fresh repair proof:

- `%APPDATA%\Godot\app_userdata\Blood Will Pay\hardcore_ui_title_prompt_repair_2026_07_29.png` (Telegram 3725)
- `%APPDATA%\Godot\app_userdata\Blood Will Pay\hardcore_ui_roster_overflow_repair_2026_07_29.png` (Telegram 3726)

Post-repair targeted results: `TitleMenuSmoke`, `UnitSelectSmoke`,
`PostCombatPlanningBeatSmoke`, `HardcoreUIAssetAudit`, `BlackLedgerSmoke`, and
`LossScreenSmoke` pass with zero gameplay/script errors. Headless capture-only
errors from the contract visual fixture are not treated as visual acceptance;
contract and escalation rendering must be checked through the framebuffer by
the next independent reviewer.

## Independent audit context

The reviewer must use the exact file manifest in
`docs/art/blood_will_pay_hardcore_ui_changed_files_2026-07-29.md`, run the game through the player-facing entrypoint, take new screenshots, inspect every surface/state family above, and return PASS only if the complete hybrid direction is coherent, readable, correctly sized, and interaction states are visibly distinct.

## Final independent acceptance

Final acceptance was issued against `17bddaa` after four independent review
passes. Earlier reviews served as real defect discovery rather than waived
evidence:

- The first audit found the overlong result card, starter-copy overflow, and
  missing gateway affordance; all three were repaired and targeted by smokes.
- A later audit found white starter-screen holes and an electric-blue,
  block-corrupted victory arena. Six task-launched Godot editors had written
  the same transient `.godot/imported` cache concurrently. All task editors
  were closed, the corrupted cache was quarantined, and one editor rebuilt all
  828 imports before the failed states were replayed.
- Clean single-writer repair proof is
  `%APPDATA%\Godot\app_userdata\Blood Will Pay\hybrid_ui_clean_reimport_roster_2026_07_29.png`
  (Telegram 3751) and
  `%APPDATA%\Godot\app_userdata\Blood Will Pay\hybrid_ui_clean_reimport_victory_2026_07_29.png`
  (Telegram 3752).

The final fresh reviewer started from a clean worktree, launched one editor,
ran the real `Main.tscn` at 1920x1080, and returned **PASS** with no unresolved
P0-P2 UI/art issue. Its own evidence:

- Telegram 3753: gothic title gateway and visible input affordance.
- Telegram 3754: unselected starter roster without white holes.
- Telegram 3755: selected Axiom with contained targeting copy.
- Telegram 3756: clean opening gothic battle.
- Telegram 3757: restored planning/shop after victory without arena corruption.
- Telegram 3758: real shop hover and contained targeting tooltip.
- Telegram 3759: exercised All In state with updated wager/outcome summary.
- `clean_final_09_system_menu.png`: hardcore System modal over the dark world.

The final accepted validation set includes `HardcoreUIAssetAudit` (178 assets,
9 families, 7 state classes), `StatsPanelClickSmoke`,
`CompactShopFooterSmoke`, `PostCombatPlanningBeatSmoke`,
`ShopCardHoverSmoke`, and `ShopPurchaseFeedbackSmoke`, plus framebuffer review
of the Black Ledger, loss states, contracts/champion targeting, ascension,
Warded Lines, Cinder Clock, escalation, reinforcements, pressure callouts, and
the full state gallery.

## Objective-exact audit repair iteration

A later zero-history reviewer audited the complete 394-path manifest against
the literal objective at `64dd5df8` and returned **FAIL**. That supersedes the
earlier acceptance claim for objective-level completion. The repair iteration
addressed all eight concrete P2 findings:

- Shop tooltips now use a dedicated CanvasLayer at layer 400, clear
  synchronously on shop rebuild, and identify their owning card so stale and
  replacement tooltips can be distinguished.
- Every disabled/exhausted asset now carries a high-contrast crossed-out
  non-color cue. `HardcoreUIAssetAudit` samples both diagonals in all nine
  state families.
- The wager uses authored track/fill/grabber assets plus an explicit rendered
  rail behind the HSlider; the live planning capture shows the complete rail.
- Loss-summary text uses bone/red ink with a dark keyline over the grunge
  poster.
- Frozen contracts are enforced at runtime: System Menu 430x430 with 320x52
  actions, Unit Select 1320x900, result card 560x176, and Arena Pressure
  572x40 at the 82px arena offset.
- Black Ledger compact widths now fit 1280x720 at 150% UI scale.
- controller A/B defaults are restored and preserved across keyboard remaps;
  controller A activates a focused title-menu action in the smoke test.
- Arena Pressure has direct low/high/critical/reduced-motion captures,
  replacement/no-stacking checks, and modal/result z-order checks.

The new `UIResolutionMatrixSmoke` passes all 12 combinations of 1280x720,
1920x1080, 2560x1080, and 3840x2160 at 100%, 125%, and 150%. The contract
visual fixture now captures market, error, accepted champion targeting,
ascension, Warded Lines, and Cinder Clock states directly.

Fresh targeted runtime results in this iteration:

- `HardcoreUIAssetAudit`: PASS (178 assets, 9 families, 7 states)
- `AccessibilitySettingsSmoke`: PASS
- `SystemMenuHoverStabilitySmoke`: PASS
- `UnitSelectSmoke`: PASS
- `ShopCardHoverSmoke`: PASS
- `LossScreenSmoke`: PASS
- `BettingEconomySmoke`: PASS
- `PostCombatPlanningBeatSmoke`: PASS
- `ArenaPressureVisualSmoke`: PASS
- `UIResolutionMatrixSmoke`: PASS (4x3)
- `ContractSystemVisualCapture`: 8 framebuffer captures, no errors

Telegram repair evidence: 3766-3773. The user requested that the goal stop
after this iteration, so a new zero-history final reviewer has deliberately
not been spawned yet. Objective-level PASS remains pending that future review.

## Resumed Board repair iteration

The user resumed the same goal and explicitly removed unit artwork and actor
presentation from this pass because those assets will be rebuilt separately.
The starter-selection shell, shop framing, and interaction states remain in
scope; blank or temporary unit art is not an acceptance defect for this cut.

The resumed repair addressed the remaining non-unit evidence and interaction
gaps:

- The title command menu now recomputes its compact layout on live resize.
  `UIResolutionMatrixSmoke` proves visible actions and content at 1280x720,
  1920x1080, 2560x1080, and 3840x2160 across 100%, 125%, and 150% UI scale.
- The compact starter shell centers its headings, top-aligns the available
  choices, limits compact rows to four columns, and keeps Start Game visible.
- Shop tooltips prefer space outside the complete shop strip, not merely
  outside the hovered card.
- Loading, error, and success assets are wired through the runtime loader and
  state gallery. The contract market now uses the authored error/success
  artwork in the actual purchase flow and keeps Champion targeting open after
  purchase.
- `ALL IN` now becomes an unmistakable selected `ALL IN!` state and prefixes
  the outcome quote with `ALL IN ARMED`.
- The battle-result interruption is a 760x260 responsive nine-slice card with
  a stronger scrim, larger type, and reduced-motion-safe reveal.
- Arena Pressure evidence now renders against the shipping gothic battlefield
  and arena frame rather than an empty black fixture.

Fresh MCP-only results: `HardcoreUIAssetAudit` PASS (178/9/7),
`TitleMenuSmoke` PASS, `UnitSelectSmoke` PASS,
`UnitSelectPreviewVisualSmoke` PASS, `ShopCardHoverSmoke` PASS,
`SystemMenuHoverStabilitySmoke` PASS, `LossScreenSmoke` PASS,
`BettingEconomySmoke` PASS, `PostCombatPlanningBeatSmoke` PASS,
`ArenaPressureVisualSmoke` PASS, `ContractSystemVisualCapture` 8/8,
`UIResolutionMatrixSmoke` PASS (4x3), and full `RGATesting` 48 rows with
`RolesMetrics` failed 0, skipped 0, errors 0.

Telegram progress evidence: 3776-3783.
