# Gamble Battle Broad Playtest - 2026-07-17

## Verdict

**PARTIAL PASS.** No unresolved P0-P2 game defect remains in the exercised source build. The player-facing title, tutorial, settings, starter selection, forced opener, shop, bench/board drag, wagering, contracts, boss escalation, loss, reset, and exit paths all completed without engine errors. The result remains partial because the Windows physical-input capture bridge failed after entering the run, a packaged build was not available for platform validation, and the settings surface does not yet offer remapping or UI scaling.

Build under test: `d9e096f89c0f8be615b121d464954aa09234d4a0`, plus the tutorial and test-harness repairs described below.

Player assumptions: first-time but genre-familiar player for onboarding; returning optimizer for economy and later-shop routes. Platform: Windows, 1920x1080, mouse and keyboard. Player-facing entrypoint: `scenes/Main.tscn`.

## Fixed During The Playtest

- **P2 - stale onboarding:** How to Play still taught a level-3 combine cap and omitted the current Stakes and chapter-contract decisions. It now teaches selective shopping, CAPITAL recruits, level 4 plus permanent legacy choice, shop-then-wager sequencing, and contract PRICE/REWARD/RISK/NEXT FIGHT fields.
- **Test debt - outdated opener assumptions:** the seeded later-shop route tried to reposition during the now-auto-started opener and required an exact old Buy XP label. The route now follows the production clock and current label.
- **Test debt - incomplete roster and indiscriminate buying:** Knoll and Pilfer are now sampled, and the seeded buyer passes offers below a 70-point fit threshold instead of buying low-quality duplicates.
- **Input verification debt:** synthetic drag now verifies the live UnitView after a board refresh, avoiding a stale-node false negative.

## Perspective Matrix

| Perspective | Result | Evidence and finding |
| --- | --- | --- |
| Onboarding | PASS | Direct title, How to Play, and Settings inspection; `TitleMenuSmoke` passed after the P2 copy repair. |
| UI and readability | PASS | Fresh real-render How to Play capture showed the corrected level-4 guidance with no overlap or clipping. CAPITAL review packet passed; remaining density concerns are P3. |
| Core loop | PASS | `NaturalInputMainFlowSmoke` passed all 14 starters; `ActualRunLoopSmoke` passed five reset/loss cycles plus a complete shop cycle. |
| Controls | PARTIAL | Strict mouse/click/drag event routes passed, including reposition and bench deployment. Physical OS automation became unavailable with `0x80004002`, so the full run was not re-driven through that fallback. |
| Economy and decision quality | PASS | 14 seeded selective-shop routes reached first-boss planning; `EconomyDecisionQualityProbe`, `StakesMarketContractProbe`, and `TeamOddsCalibrationProbe` passed. |
| Difficulty and balance | PARTIAL | All 14 routes reached the first boss. The generic no-item autobuyer is intentionally not expected to beat the escalated boss; item/combine/encounter adaptation is required. Human telemetry is still needed. |
| Encounter flow and spectacle | PASS | `EncounterEscalationProbe` passed two phases, five reinforcements, and a 220-damage hazard pulse; contract battle probes passed. |
| Progression and replayability | PASS | Level-4 legacy paths, CAPITAL packages, contracts, encounter mutations, and persistent career/run state all have dedicated passing probes and visual evidence. |
| Loss, reset, and exit | PASS | `LossScreenSmoke`, `ExitFlowSmoke`, and the five-cycle actual-run route completed with `errors=[]`. |
| Save and resume | PASS | Schema-2 checksum, backup recovery, legacy compatibility, and separate-process writer/reader probes passed. |
| Accessibility and settings | PARTIAL | Text was readable at the tested resolution and master volume/fullscreen controls work. No remapping or UI-scale controls are exposed yet. |
| Stability | PASS | Full `RGATesting` completed 48 rows with `failed=0`, `skipped=0`, `errors=0`; all targeted runs reported empty engine error arrays. |
| Platform fit | PARTIAL | Source/editor runtime was stable on Windows. Packaged-build export and distribution behavior were not tested. |

## Quantitative Evidence

- Natural production-clock route: `starters=14`, `first_shop=14`, `retry=0`, `deployed=14`, `second_resolved=14`.
- Seeded later-shop route: `samples=14`, `reached=14`, `target_stage=4` (first-boss planning), `audit_gold_added=119`.
- Team-odds calibration: `samples=144`, predicted `50.0%`, observed `50.7%`, aggregate gap `0.7%`, Brier score `0.136`, timeouts `0`.
- Encounter escalation: `phases=2`, `revived=5`, `pulse_damage=220`.
- Full deterministic regression: `rows=48`, `failed=0`, `skipped=0`, `errors=0`.

## Visual Evidence

- Current tutorial capture: `outputs/vision_snapshots/title_menu_states/02_how_to_play_search_combine_1784324914_9372_viewport.png`
- Unit-upgrade packet: `outputs/visual_debug/vdh_runs/unit-upgrades-final-20260717/`

The legacy runner could not save framebuffer images for the loss and exit smoke scenes, although both routes completed cleanly. A separate live editor capture already proved the corrected tutorial. The physical Windows capture fallback then failed with `SetIsBorderRequired failed: No such interface supported (0x80004002)`; no blind UI driving followed.

## Remaining P3 Risks

- CAPITAL ascension cards and some tooltips are information-dense and visually flat.
- Settings need input remapping and UI scaling before a platform-readiness claim.
- The Windows physical-input/capture bridge needs a tooling repair for uninterrupted Tier-0 evidence.
- Human sessions should calibrate whether the first boss asks for adaptation without feeling like a surprise wall.
