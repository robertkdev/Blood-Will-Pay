# UI Shape Outline Imagegen Test - 2026-07-03

## Purpose

Test whether calculated, exact-size UI outlines can be used as image-generation start sources for Blood Will Pay UI assets such as the bottom bar, shop cards, action buttons, and the primary battle button.

## Source Geometry

Target dimensions were taken from the current Godot UI theme/code:

- Bottom storage plate: `1120x238`
- Shop grid plate: `1120x178`
- Shop card frame: `150x138`, radius `5`, border `2`
- Shop action button: `100x44`, radius `5`
- Continue/start battle button: `240x54`, radius `5`

Generated source controls:

- `outputs/art_pipeline/ui_shape_outline_test_2026_07_03/outline_source_ui_assets_clean.png`
- `outputs/art_pipeline/ui_shape_outline_test_2026_07_03/outline_source_ui_assets_contact_sheet.png`
- `outputs/art_pipeline/ui_shape_outline_test_2026_07_03/game_screenshot_target_overlay.png`

Comparator screenshot:

- `outputs/visual_iter/state_loop_8/07_combat_populated_shop.png`

## Image Generation Pass

Mode: built-in `image_gen` tool using the clean outline sheet as the visible edit/source image.

Prompt intent: preserve exact geometry and green matte while painting only inside the existing shapes in the current severe gothic Blood Will Pay UI direction: blackened iron, deep charcoal stone, blood-red enamel, ember-gold trim, subtle vellum/stone grain, crisp bevels.

Raw output:

- `outputs/art_pipeline/ui_shape_outline_test_2026_07_03/imagegen_outline_asset_sheet_raw.png`

## Raw Geometry Result

The generated canvas preserved the exact source canvas size: `1536x1024`.

The generated assets were close but not perfectly pixel-preserved:

- Bottom storage: expected `1120x238`, measured `1119x240`
- Shop grid: expected `1120x178`, measured `1119x181`
- Shop card: expected `150x138`, measured `147x138`
- Shop action button: expected `100x44`, measured `99x45`
- Continue button: expected `240x54`, measured `239x55`

The outside matte also drifted from exact `#00ff00`; sampled generated background pixels included values like `(19, 242, 12)` and `(4, 248, 2)`.

Full measurement file:

- `outputs/art_pipeline/ui_shape_outline_test_2026_07_03/geometry_report.json`

Review images:

- `outputs/art_pipeline/ui_shape_outline_test_2026_07_03/ui_shape_outline_test_contact_sheet.png`
- `outputs/art_pipeline/ui_shape_outline_test_2026_07_03/imagegen_geometry_review_overlay.png`
- `outputs/art_pipeline/ui_shape_outline_test_2026_07_03/imagegen_outline_asset_sheet_keyed_threshold.png`

## Deterministic Extraction Result

Using the original calculated outline masks for crop and alpha enforcement produced exact-size PNG assets:

- `final_bottom_storage_plate_1120x238.png`
- `final_shop_grid_plate_1120x178.png`
- `final_shop_card_frame_150x138.png`
- `final_shop_action_button_100x44.png`
- `final_continue_button_240x54.png`

All final extracted canvases matched their expected dimensions exactly. Report:

- `outputs/art_pipeline/ui_shape_outline_test_2026_07_03/final_asset_report.json`

Visual proof:

- `outputs/art_pipeline/ui_shape_outline_test_2026_07_03/final_exact_assets_contact_sheet.png`
- `outputs/art_pipeline/ui_shape_outline_test_2026_07_03/game_screenshot_exact_asset_mockup.png`

## Verdict

Image generation alone is not reliable enough for perfect pixel-sized UI assets, even when given a calculated source outline. It preserved the canvas and overall layout well, but introduced 1-4 px shape drift and matte color variation.

The practical workflow is viable if image generation is treated as a texture/detail pass only:

1. Generate or edit from a calculated source outline.
2. Deterministically crop to the expected rectangle.
3. Apply the original calculated alpha mask.
4. Audit final canvas sizes and alpha shape before using in Godot.

The draft art should not be promoted directly into live UI. It is too ornate for the current in-game information density, and there is a small green-edge artifact on some extracted corners. A production pass should generate per-asset variants with simpler borders, then enforce the same crop/mask audit before any `assets/ui` replacement.

## Runtime Note

`tests/visual/MainFlowVisualCapture.tscn` was run through MCP to try to capture fresh full-game screenshots. The run started cleanly, but the current MCP runner used the dummy renderer, so framebuffer screenshots were skipped. Existing full-game screenshots under `outputs/visual_iter` were used for the visual comparison.
