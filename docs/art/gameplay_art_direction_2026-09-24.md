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
Fire in the new raster is static; no new fire animation is claimed.

`assets/fonts/Cinzel.ttf` comes from the official Google Fonts repository:
https://github.com/google/fonts/tree/main/ofl/cinzel

The bundled `assets/fonts/Cinzel-OFL.txt` is the SIL Open Font License supplied
with that font. Existing unit art, icon art, and frame art are reused unchanged.

## Runtime Verification

Launch through the project's Godot MCP workflow, after editor hydration:

- `tests/visual/GameplayArtDirectionReview.tscn`: sparse and populated planning,
  100/150 percent UI scale, shop hover, and moving combat on the same floor.
- `tests/visual/CompactViewportVisualAuditSmoke.tscn`: 720p/1080p at
  100/125/150 percent, including deployment-label overlap checks.
- `tests/visual/PhaseTransitionSmoke.tscn`: entry, return, camera continuity,
  and reduced-motion behavior.
- `tests/visual/LossScreenSmoke.tscn`: result flow and scoreboard integration.
- `tests/visual/ShopCardHoverSmoke.tscn`: stable card geometry and custom-tooltip
  lifecycle in the bottom-screen shop fixture.
- `tests/visual/StageProgressTopBarHoverSmoke.tscn`: native tooltip ownership,
  text, material frame, and stable token geometry. This does not visually
  qualify the native tooltip popup.

The focused review emits raw framebuffer PNGs and `captures.json` with state,
scale, viewport, runtime identity, and timestamps. Review screenshots as well as
test results; assertions alone are not aesthetic acceptance.

All six scenes passed in Godot 4.5 on this change. The focused review produced
seven gameplay captures; the viewport audit produced twelve menu/planning/detail
captures. Phase-transition coverage also passed the actual run-loop checks.
These are focused visual and integration checks, not a broad gameplay playtest.
