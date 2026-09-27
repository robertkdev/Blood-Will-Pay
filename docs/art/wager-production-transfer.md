# Wager and action production transfer — 2026-09-27

The reference-inspired planning screen had a dense repeated wager quote, an unlabeled all-in control, and a flat red primary action. The composed dock now has a header/reserve, one selected amount, native minus/plus buttons, the existing slider and All In callback, and separate outcome rows at all supported UI scales. Outcome numbers remain projected reserves from EconomyUI, not new payout calculations. The primary Button uses the existing isolated crimson texture and emblem; no image contains the complete UI.

The design target is fullscreen 1920×1080. The existing 100%, 125%, and 150% UI settings remain supported. Start Battle retains its existing mouse-only activation contract. Keyboard arrows adjust the focused wager slider, with a native transparent focus panel; the slider does not expose a focus StyleBox slot. Countdown locks both the slider and All In. The opening wager and combat escrow rules are unchanged.

## Verification

- `tests/visual/GameplayArtDirectionReview.tscn`: complete real Main scene, sparse/populated states, three UI scales, repeated layout stability, real pointer increment/decrement/all-in, keyboard adjustment, focus/armed/pressed/countdown captures, and live combat advancement.
- `tests/visual/BettingEconomySmoke.tscn`: real opener → victory → shop → maximum wager → locked combat; exact stake/payout invariants and post-victory layout stability.
- `tests/visual/CompactViewportVisualAuditSmoke.tscn`: preserved compact/fullscreen settings, visible native reserve and outcome information, physical text size, and unit-detail rail containment.
- `tests/visual/UIThemeSmoke.tscn`: affected presentation and opening-state explanations. Assertions no longer require the old flat action material or duplicated visible prose. Images determine aesthetic acceptance.

## What transferred from the capability work

The shared managed runtime is updated from 0.2.0 to 0.16.15. A typed live edit applied the isolated plaque texture to the actual production button and returned a fresh capture plus native property readback in approximately four seconds. That made a material candidate reviewable before integrating it into production. The project retains only its adapter; shared tool implementation remains managed.

Production exposed four gaps that a small laboratory fixture did not:

1. The old adapter disabled CombatView processing while leaving the opening state incomplete, then treated two elapsed frames as readiness. It now establishes the actual post-shop phase and checks visible controls before freezing.
2. Changing the wager amount could move neighboring shop targets. The selected amount reserves space for the selectable range rather than its current singular/plural text.
3. New container reflows could repeatedly schedule deferred dock layouts after victory, preventing another rendered frame. The unchanged baseline passed the same economy scene. Coalescing reflows to one transaction per frame restored progress; the economy scene now also checks that post-victory targets settle.

4. The broader CI audit still asserted the hidden legacy summary and logical font sizes. It now checks visible native outcomes and physical legibility. It also exposed the detail panel competing with its composed rail width; the detail owner now respects that width directly, so correctness no longer depends on which deferred reflow runs last.

The installed CLI was needed because the existing MCP process reported stale package metadata. Initial preparation also scanned thousands of historical output files; that startup cost is still an open shared-tool efficiency issue. Neither successful captures nor improved small regions establish full-screen reference fidelity. Board legibility, the larger visual hierarchy, and broader tool adoption remain separate work.
