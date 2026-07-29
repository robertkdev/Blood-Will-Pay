# Gothic UI Asset Workflow

This is the future-agent recipe for making Gamble Battle UI assets in the current generated gothic style. Use this before creating or replacing bottom bars, buttons, cards, panels, tooltips, and other exact-size GUI surfaces.

## Current Production Assets

Live generated UI assets are under `assets/ui/gothic/`:

| Asset | Current canvas | Runtime helper |
| --- | ---: | --- |
| `panel_plate_wide_v2.png` | `1120x238` | `GothicUIAssets.wide_panel_style()` |
| `panel_plate_grid_v2.png` | `1120x178` | `GothicUIAssets.grid_panel_style()` |
| `panel_plate_item_storage.png` | `320x180` | `GothicUIAssets.item_storage_panel_style()` |
| `panel_plate_traits.png` | `320x320` | `GothicUIAssets.traits_panel_style()` |
| `shop_card_frame_v2.png` | `150x138` | `GothicUIAssets.shop_card_style()` |
| `button_primary_v2.png` | `240x54` | `GothicUIAssets.primary_button_style()` |
| `button_small_v2.png` | `100x44` | `GothicUIAssets.small_button_style()` / `item_slot_style()` |
| `screen_backdrop.png` | `1920x1080` | `GothicUIAssets.screen_backdrop_texture()` |
| `battlefield_surface.png` | `1536x768` | `GothicUIAssets.battlefield_texture()` |
| `battlefield_surface_top.png` | `1536x384` | `GothicUIAssets.battlefield_top_texture()` |
| `battlefield_surface_bottom.png` | `1536x384` | `GothicUIAssets.battlefield_bottom_texture()` |
| `board_tile_player.png` | `96x96` | `GothicUIAssets.board_tile_style(true)` |
| `board_tile_enemy.png` | `96x96` | `GothicUIAssets.board_tile_style(false)` |
| `bench_slot_frame.png` | `96x96` | `GothicUIAssets.bench_slot_style()` |
| `item_icon_frame.png` | `96x96` | `GothicUIAssets.item_icon_frame_style()` |
| `unit_base_player.png` | `128x96` | `GothicUIAssets.unit_base_style(true)` |
| `unit_base_enemy.png` | `128x96` | `GothicUIAssets.unit_base_style(false)` |
| `arena_frame.png` | `640x360` | `GothicUIAssets.arena_frame_style()` |
| `status_strip.png` | `512x64` | `GothicUIAssets.status_strip_style()` |

The July 11 restrained v2 pass replaced the first-generation wide/grid plates,
shop card, and button family with versioned siblings. The v1 files remain for
non-destructive rollback and comparison, while runtime constants point to v2.
The local run source and deterministic audit are kept under
`outputs/art_pipeline/ui_gothic_v2_2026_07_11/` (ignored review evidence). The
committed `tools/art/recover_gothic_ui_v2.py` reruns exact sizing, v1 alpha-mask
recovery, and key-green checks when supplied a compatible generated sheet.

The implementation hook is `scripts/ui/gothic_ui_assets.gd`. Runtime callers should use `StyleBoxTexture` through that helper and keep a flat fallback with `GothicUIAssets.style_or_fallback(...)`.

## Working Rule

Image generation is a texture/style pass, not the sizing authority.

The tested result is consistent: even when ImageGen receives an exact calculated source outline, it may change canvas size, asset bbox, aspect ratio, or matte pixels. Do not put raw ImageGen output directly into `assets/ui/gothic/`.

Production candidates must be recovered deterministically:

1. Measure the in-game slot from current UI code, current Control rects, or a fresh full-game capture.
2. Generate an exact outline/mask at the target canvas size, including the intended corner radius and nine-slice-safe border region.
3. Send that outline to ImageGen only to paint the gothic texture language inside the intended shape.
4. Detect the generated non-matte/nontransparent asset bbox.
5. Crop and resize the generated texture back to the exact target canvas.
6. Reapply the original calculated alpha mask or shape mask.
7. Audit final dimensions, alpha edge, corner shape, and nine-slice margins before replacing any live asset.
8. Wire it through `GothicUIAssets` and validate in live UI states.

## Prompt Direction

Keep prompts restrained enough for dense game UI:

```text
Paint only inside the provided exact UI outline. Keep the silhouette, corners, bevel width, and empty matte/alpha outside unchanged. Dark gothic tactics-game UI, blackened iron, charcoal stone, blood-red enamel, dull ember-gold worn trim, dry vellum/stone grain, low-sheen hand-painted texture, crisp readable bevels. No text, symbols, logos, extra holes, extra tabs, glowing effects, background scene, or changed aspect ratio.
```

Expect the model to ignore some geometry instructions. The deterministic mask/crop audit is what makes the asset usable.

## Implementation Pattern

Use generated frames as nine-slice style boxes and generated surfaces as texture backdrops:

- `wide_panel_style()` for large plates, title panels, preview panels, loss panels, and broad bottom-bar backplates.
- `grid_panel_style()` for medium panel interiors, command-strip plates, tooltips, and stat panels.
- `shop_card_style()` for shop cards and large card-like buttons.
- `primary_button_style()` for Start Battle, Start Game, New Game, and other primary calls to action.
- `small_button_style()` for compact command buttons, tabs, menu buttons, and search fields.
- `item_slot_style()` for tiny slots/chips/checkbox-like controls where the small button margins are too heavy.
- `screen_backdrop_texture()` for the root combat backdrop; do not re-enable the procedural battlefield shader behind the board.
- `battlefield_texture()` for combat arena mode, and the top/bottom battlefield split textures for planning board halves.
- `board_tile_style(true/false)` for player/enemy grid tiles; the generated tile center is translucent so the board surface still reads through.

For button states, prefer one recovered asset plus `modulate_color` variants for `normal`, `hover`, `pressed`, `focus`, `selected`, and `disabled`. Generate separate files only when tinting cannot produce a readable state.

## Validation Gates

At minimum, run a scoped MCP visual/style gate after UI asset or styling changes:

- `tests/visual/GothicUIAssetAudit.tscn` for exact dimensions and visible/transparent key-green contamination.
- `tests/visual/UIThemeSmoke.tscn` for combat/shop/bottom-bar styling.
- `tests/visual/TitleMenuSmoke.tscn` and `tests/visual/TitleMenuStateCapture.tscn` for title/menu/search/settings states.
- `tests/visual/UnitSelectSmoke.tscn` and `tests/visual/UnitSelectPreviewVisualSmoke.tscn` for starter selection states.
- `tests/visual/LossScreenSmoke.tscn` for loss overlay and New Game states.
- `tests/visual/VisionCaptureSmoke.tscn` for broad title, unit-select, combat, system-menu, shop, and unit-detail coverage.

Prefer `godot-ai project_run` from an open editor for real viewport/framebuffer captures. Use the legacy Godot MCP runner as fallback when the editor is unavailable. After each run, inspect game/debug output and do not count project launch as proof.

Expected screenshot artifacts from the latest accepted pass:

- `outputs/vision_snapshots/title_menu_states/title_menu_states_viewport_contact_sheet_latest.png`
- `outputs/vision_snapshots/smoke/vision_capture_viewport_contact_sheet_latest.png`
- `outputs/visual_iter/unit_select_preview_pass/unit_select_states_contact_sheet_latest.png`
- `outputs/visual_iter/loss_screen_pass/loss_screen_states_contact_sheet_latest.png`

## Visual Review Checklist

Before accepting a UI asset pass, compare against a current full-game screenshot and check:

- Bottom shop bar uses an external backplate and is not collapsed inside a container child.
- The combat root background is the generated `screen_backdrop.png`, not the old procedural ring/sigil shader.
- Planning grid halves show generated battlefield surfaces and generated tile frames, not flat red/teal Godot boxes.
- Combat arena mode shows `battlefield_surface.png` behind actors, and the old `ArenaBackground` shader/ColorRect is transparent.
- No stale overlay appears in the top-left or above the board.
- Shop cards remain `150x138` and text/icons fit at normal, hover, and pressed states.
- Primary buttons keep their target aspect and do not visibly stretch.
- Small buttons and slots keep readable borders at tiny sizes.
- Text is not occluded by ornate borders or bevels.
- Focus/hover/pressed/disabled states are visually distinct without changing layout.
- Tooltips and stat/detail panels still read as UI, not decorative art cards.
- The alpha edge is clean: no green matte, orange fringe, or dark halo from the generation source.

## Evidence Notes

The proof reports behind this workflow are:

- `docs/art/ui_shape_outline_imagegen_test_2026-07-03.md`
- `docs/art/ui_asset_outline_imagegen_experiment_2026-07-03.md`

Those reports show why raw ImageGen is not pixel-perfect and why exact-mask postprocessing is required. The accepted implementation commits after that proof are the generated gothic UI checkpoints, including the title menu, unit select, broad combat/shop surfaces, and loss screen states.
