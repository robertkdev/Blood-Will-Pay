# Full playtest repair — 2026-07-17

## Outcome

The reported source-build blockers were repaired on `codex/019f7308-526-full-playtest-repair`. CombatView and its shop/item/trait scene dependencies load, the Bonko betting and deterministic mid-run paths reach live combat, automatic capacity floors are asserted at stages 7/12/17/22, and the 144-sample odds calibration probe has zero timeouts.

The stale visual and interaction harnesses now follow `TitlePage`, control the forced opener before auto-start, match price-bearing progression button labels, respect live board capacity, and use an authoritative 1920x1080 SubViewport for arena geometry. Exit/loss tests now return truthful failure codes and explicitly tear down runtime state.

Combat Terms renders a recoverable `Nothing Found` card with `Clear Search`. Settings now persist 100%, 125%, and 150% UI scale choices and expose conflict-aware keyboard remapping for Confirm and Menu / Back, with cancel and reset behavior.

## Fresh validation

- `TitleMenuSmoke`: OK, empty Godot error array.
- `AccessibilitySettingsSmoke`: OK; scale persistence, key persistence, conflict rejection, Escape cancel, reset, and non-key event preservation.
- `TitleMenuStateCapture`: OK, seven diagnostic state captures including the unmatched Combat Terms result and accessibility settings.
- `BettingEconomySmoke`: OK; CombatView opens and betting state locks/resolves correctly.
- `MidRunProgressionSmoke`: OK; five real post-opener battles reach Chapter 2 Stage 1.
- `NaturalRepresentativeMultiStageMainFlowSmoke`: OK; all six representative starters and seeds load CombatView and advance through the Chapter 1 multi-stage runway.
- `FirstShopChoiceQualitySmoke`: PASS, 39/45 choices advanced across nine starters; all five Axiom trials advanced.
- `ProductionRapidShopPressureSmoke`: OK; five purchases and capacity-correct deployment.
- `EndlessRuntimeIntegrationProbe`: PASS; exact capacity floors 6/7/8/9 at stages 7/12/17/22.
- `TeamOddsCalibrationProbe`: PASS, 144 samples, predicted 50.0%, observed 50.7%, aggregate gap 0.7%, Brier 0.136, zero timeouts; largest reported bucket gap 17.7 points.
- `CombatArenaBoundsSmoke`: OK at an authoritative 1920x1080 viewport.
- `CompactViewportVisualAuditSmoke`: OK, five diagnostic captures, no ObjectDB leak warning.
- `ExitFlowSmoke` and `LossScreenSmoke`: OK behaviorally with empty Godot error arrays.
- `RoleMatrixProbe6v6`: PASS for Bonko's role, goal, sustain, and ramp contracts; empty Godot error array.
- `RGATesting`: PASS, 48 rows, no failed/skipped/error metrics and an empty Godot error array.
- Godot-AI game framebuffer capture: available at 1920x1080. Fresh title and Settings frames were visually inspected; the settings page fits and shows UI Scale plus both keyboard bindings without visible overlap.

## Evidence limits

The software `VisionSnapshot` PNGs are diagnostic control maps, not authoritative pixel renders. They remain useful for state, text, control-presence, and gross-bound checks only. Godot-AI supplied authoritative 1920x1080 game frames, but Windows physical-window capture still fails before input with `0x80004002`, so physical keyboard/mouse feel and OS compositor fidelity remain externally unaccepted.

Framebuffer capture remains unavailable inside the legacy `ExitFlowSmoke` and `LossScreenSmoke` runners; their behavior is accepted, their screenshots are not. Raw `outputs/` captures remain intentionally ignored, while this reviewed report and the test contracts are normal Git evidence.

A checked-in Windows Desktop export preset now targets `build/windows/GambleBattle.exe`, and `/build/` is ignored. No packaged executable was produced because export templates are not installed and the approved Godot MCP surfaces do not expose an export operation. Packaged startup, performance, distribution, and OS scaling therefore remain an environment/tooling gate rather than source-build acceptance.

The canonical vault validator is currently green; the three previously reported vault failures were stale, unrelated evidence and were not converted into project changes.
