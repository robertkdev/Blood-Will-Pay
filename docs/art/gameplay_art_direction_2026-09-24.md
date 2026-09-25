# Gameplay Art Direction

This pass uses the supplied concept as a visual reference only. It does not copy
its game rules, terminology, roster, board topology, or economy.
Full-screen composition is the design target. Existing smaller-viewport checks
are regression coverage, not a separate resizable-window design goal.

## Presentation

- Larger responsive shop portraits use existing runtime unit textures. Board-art
  fallbacks show the upper 72 percent; dedicated shop art is not cropped. This is
  presentation, not approval of any placeholder or selected artwork.
- Existing worn-metal frame assets now carry panels, chapter progress, cards,
  and button states. Red is concentrated on hostility and the commit action.
- Complete, restrained tile outlines replace the interrupted bright grid.
- Team metrics scroll within their panel. Planning labels use settled grid
  bounds and leave deployment tiles unobstructed. Panel titles are inset clear
  of their frame ornaments in team and individual-unit views.
- Cinzel is used selectively for gameplay headings and the commit action;
  functional numbers and compact labels retain the existing readable fonts.

## Asset Provenance

`assets/ui/gothic/generated/arena_firelit_v1.png` was generated with the built-in
ImageGen tool on 2026-09-24 using the existing onset floor and the supplied
concept as references. The instruction retained an uninterrupted stone fighting
surface and placed firelight, ironwork, candles, and burgundy cloth at the edges.
It contains no UI or characters. The opaque 1672x941 output is used unscaled as
the source texture; the existing runtime camera performs display scaling.

SHA-256: `89936ee87aaf49e28a742a47457e60860ca02e80ff4e68b435dd2de5a536e7d2`

The original floor assets remain available. Existing combat camera, actor
movement, phase-transition behavior, and reduced-motion handling are unchanged.
The floor raster still carries the painted fires; the live motion over them is a
separate layer described below. Nothing in this change alters gameplay, the
camera, or game content.

### Practical Fire Layer

`assets/ui/gothic/generated/crypt_flame_luna_v1.png` is the reviewed static
flame cluster used by the animated overlay. It is a byte-identical copy of the source under
`outputs/art_pipeline/luna_fire_2026_09_24/`.

SHA-256: `35cf274607f490c793454aed2b5e7dcf707ff2067294946e96007973ed243a19`

`scripts/ui/combat/arena_practical_fire.gd` installs it as a child of the floor
surface `GothicArenaSurface` and places every anchor in floor raster pixels, so
the existing shared-field camera carries the fires through planning, the entry
push, live combat and the reverse return. No screen-space anchoring is involved.

- The four corner brazier bases carry a restrained additive flame overlay sized
  to the flames already painted there, plus one small local light pool each.
- The three candle clusters carry a local light pool only, because the approved
  cluster is brazier-scale art.
- The arena centre stays quiet: no fire there, and no new haze, spark, screen
  pulse or oversized glow anywhere.
- Reduced motion uses the existing setting and freezes the flames with constant
  light and no particles.
- The layer is dormant, not placeholder-filled, when the approved texture is
  missing or is not the expected size, so the arena falls back to the authored
  raster. Anchors are fixed constants tied to the current floor raster; a
  different floor texture would need them re-measured.

### Unit Presentation

`shaders/unit_art_presentation.gdshader` with
`scripts/ui/unit_art_presentation.gd` lifts the shipped unit art over dark stone.
It draws the same existing unit textures and preserves the incoming CanvasItem
tint and alpha, which it captures in `vertex()` instead of reading the fragment
`COLOR`. Source textures are not replaced; rendered exposure changes while
transparency and inherited tint remain intact. Materials are cached per surface.

### Shop Card Frame

`assets/ui/gothic/generated/shop_card_frame_luna_v1.png` (150x138) is the
recovered shop card frame from Luna's blackened-iron and dim-old-gold pass. It
was recovered to the original 150x138 frame size with an exact alpha-mask match
and the existing 22 px nine-slice margins; the audit is
`outputs/art_pipeline/luna_frame_2026_09_24/recovery_audit.json`.

SHA-256: `aa3b1ee6aeed28163888417f4c71a7a8e4120288539fd03beba4176cdb4d23eb`

`assets/ui/gothic/shop_card_frame_v2.png` is retained as a one-line rollback.

`assets/fonts/Cinzel.ttf` comes from the official Google Fonts repository:
https://github.com/google/fonts/tree/main/ofl/cinzel

The bundled `assets/fonts/Cinzel-OFL.txt` is the SIL Open Font License supplied
with that font. Icon art and the remaining existing frame art are reused
unchanged.

## Runtime Verification

Launch through the project's Godot MCP workflow, after editor hydration:

- `tests/visual/GameplayArtDirectionReview.tscn`: sparse and populated planning,
  100/150 percent UI scale, shop hover, and moving combat on the same floor.
- `tests/visual/CompactViewportVisualAuditSmoke.tscn`: 720p/1080p at
  100/125/150 percent, including deployment-label overlap checks.
- `tests/visual/PhaseTransitionSmoke.tscn`: entry, return, camera continuity,
  and reduced-motion behavior.
- `tests/visual/PracticalFireSmoke.tscn`: practical fire parented to the floor
  raster, anchors held in planning and combat, quiet arena centre, no mouse
  capture, reduced-motion freeze and resume, missing-art texture resolution,
  and allocation-safe repeated installation. Caller-supplied rejected nodes
  remain caller-owned; absent-floor and existing-layer paths allocate no node.
- `tests/visual/UnitArtPresentationSmoke.tscn`: the presentation shader keeps the
  node tint, alpha, and the existing unit textures.
- `tests/visual/LossScreenSmoke.tscn`: result flow and scoreboard integration.
- `tests/visual/ShopCardHoverSmoke.tscn`: stable card geometry and custom-tooltip
  lifecycle in the bottom-screen shop fixture.
- `tests/visual/StageProgressTopBarHoverSmoke.tscn`: native tooltip ownership,
  text, material frame, and stable token geometry. This does not visually
  qualify the native tooltip popup.

The focused review emits raw framebuffer PNGs and `captures.json` with state,
scale, viewport, runtime identity, and timestamps. Review screenshots as well as
test results; assertions alone are not aesthetic acceptance.

All eight scenes passed in Godot 4.5 on this change. `PracticalFireSmoke` and
`UnitArtPresentationSmoke` passed after the shader repair, in which both shaders
carry the incoming CanvasItem tint and alpha through a varying instead of reading
or overwriting the fragment `COLOR`. The focused review produced seven gameplay
captures and the viewport audit produced twelve menu/planning/detail captures;
both sets are retained, and the practical-fire smoke emitted its own planning and
combat captures. Phase-transition coverage also passed the actual run-loop
checks, and the loss-screen and stage-progress checks are unchanged from the
prior pass.

Verification records confirmed by the root agent: `r1903343-4` (unit art),
`r456440-1` (final practical fire and lifecycle), `r2018029-6` (main review), `r2075014-7`
(viewport audit), `r2168666-8` (phase transition), `r2239802-9` (shop).

The final lifecycle check supersedes `r1945444-5`. The repair delays layer-node
allocation until the floor and approved texture validate. It does not alter
the flame shader, placement or lighting, so the captured motion remains
representative of the rendered effect. Two fresh final-smoke captures were
also inspected. The shader's only subsequent edit corrects a comment.

A normal-speed 8 s silent game-window clip (`motion-live-fire-05`) passed root
and independent review for ambient practical-fire presentation in settled
planning: fixed brazier attachment, restrained tip/brightness changes, and no
visible global pulse or unit/UI obstruction. It contains no input or phase
transition, so it does not qualify those behaviours or combat motion.

The clip has 445 decoded frames (55.625 fps average, requested 60), recorder DTS
corrections and one equal-PTS pair. A unique three-frame visual cue binds the
video to Godot telemetry. The cue-aligned Godot intervals peak at 18.056 ms;
PresentMon peaks at 25.873 ms, with first-sample alignment only. Neither stream
has an interval over 33.3 ms in this capture. This is bounded evidence, not a
general frame-rate guarantee. Lossy encoding limits sub-pixel and percent-level
motion claims; the accepted fire motion is subtle, not a dramatic animation.

Clip SHA-256: `3693b7d586c9a7e339d543dcd0ea6296f79f50ca338b11a13fa2039b3e427b5b`

The local task evidence contains the original before frame, immutable gameplay
and viewport captures, still and motion reviews, the detailed artistic and
psychological comparison, and `verification.json`. The independent still review
accepted the delegated increment; the root also compared the full result against
the original runtime, not only the intermediate checkpoint.

These are focused visual and integration checks, not a broad gameplay playtest.

## Design Outcome and Remaining Gaps

The floor, frames, type, and unit exposure now read as one dark iron-and-blood
crypt instead of a flat board, and the braziers and candles carry live light
without moving the camera or changing play. This is still a step short of the
supplied reference, which is more hand-authored than the current pass: its trait
rows carry their own iconography where ours are still text, and the roster's unit
art is not yet one coherent visual family. Nothing here is a claim that a
placeholder, a frame still in trial, or any unselected asset is finished work.
