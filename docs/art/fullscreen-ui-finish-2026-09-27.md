# Fullscreen UI finish - 2026-09-27

The authored 1920x1080 gameplay UI now uses complete recessed deployment cells,
larger board figures, 18 px trait names, and explicit Bench/Shop headings. The
phase label stays plain during timer refresh. The metrics subheader has an inner
gutter, and shop tooltips format alternate role/goal identifiers as readable text.
The existing reserve, wager, win/loss outcomes, keyboard focus and countdown lock
remain native controls. Unit art and gameplay calculations are unchanged.

This delivery includes the earlier local commit `da818475`, which removes the
interface-scale setting and scale-driven composition. Fullscreen is the sole
acceptance target; no scaling or resize matrix is supported.

## Asset and editor workflow

The research chat "Research Pro Animated Game UI" verified Inkscape 1.4.4 headless
SVG/object export. This pass used it to export the editable master
`tools/art/source/deployment_cells.svg` into two 128x80 transparent PNGs. The
native `StyleBoxTexture` uses 12 px margins; hover, pressed and focus are native
Godot states. Re-export with the installed Inkscape CLI:

```powershell
& $inkscape tools/art/source/deployment_cells.svg --export-id=player --export-id-only --export-area=0:0:128:80 --export-filename=assets/ui/gothic/deployment_cell_player.png
& $inkscape tools/art/source/deployment_cells.svg --export-id=enemy --export-id-only --export-area=144:0:272:80 --export-filename=assets/ui/gothic/deployment_cell_enemy.png
```

The shared Visual Debug Harness art runtime was updated through its installer to
0.16.19 (all 26 managed hashes match). Its native preview produced the initial reference/actual pair. Godot-AI
then ran the real Main scene fixture through the restricted MCP launcher after
the editor hydration gate passed (327 classes, no missing resources). No
project-local preview controller or replacement whole-screen image was added.

## Verification and evidence

Local MCP debug checks: GameplayArtDirectionReview (nine states), UIThemeSmoke,
CompositionLayoutSmoke, BettingEconomySmoke, AccessibilitySettingsSmoke and
TitleMenuSmoke and LossScreenSmoke. Inspect current-run game/editor logs for each. The gameplay
fixture exercises repeated pointer wager reversals, keyboard input, All In,
pressed state, hover, countdown, and advancing combat positions. This is focused
UI validation, not a broad playtest.

The theme check now catches missing deployment-cell edges. Composition checks
measure the actual visible reserve/outcome rows instead of the retired hidden
summary. Title-menu checks no longer demand obsolete decorative dockets. The
accessibility scene checks bindings and motion at fullscreen; its old resizing
stress pass was removed. CI now runs fullscreen title, composition and theme gates
in place of the retired compact/resize gates; loss verification keeps recovery,
value fitting, hover and focus at fullscreen.

Evidence root: `E:/CodexArtifacts/Blood-Will-Pay/fullscreen-ui-finish-20260927/`.
`before/`, `pass1/`, `final/` preserve earlier captures; `accepted/` holds the last
nine gameplay captures and manifest. `check-*.json` contains MCP debug results.
`review-packet/` holds the visual comparison packet, and `independent-review.md`
records the clean-context DeepSeek review and final follow-up. One earlier
pointer-input miss did not reproduce in subsequent repeated-reversal passes.

The independent reviewer accepted the fullscreen hierarchy and deployment-cell
readability. Root inspection of original PNGs resolved JPEG HP ambiguity
(1190/1190), confirmed the gold/red outcome distinction, and verified uncropped
bench figures. The metrics subheader is also a single line in the original PNG; the reviewer's wrap observation was a JPEG reading error. The partially visible bottom trait row belongs to a scroll
viewport. The temporary shop tooltip covers part of the board/bench; its full
copy remains readable and clears on pointer exit. The concept remains visual
direction, not an exact composition or content contract. Unit source-art
approval, broader combat pacing, audio, and the paused 20-reference capability
goal are separate work.
