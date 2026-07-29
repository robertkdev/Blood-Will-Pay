# UI Asset Outline ImageGen Experiment - 2026-07-03

## Goal

Test whether calculated UI asset outlines can be used as ImageGen start sources to produce perfectly sized and shaped Blood Will Pay GUI assets in the current gothic art approach.

## Inputs

- Current gothic assets:
  - `assets/ui/gothic/panel_plate_wide.png` - `1120x238`
  - `assets/ui/gothic/button_primary.png` - `240x54`
  - `assets/ui/gothic/button_small.png` - `100x44`
  - `assets/ui/gothic/shop_card_frame.png` - `150x138`
- Generated outline sources:
  - `outputs/ui_asset_outline_experiment/ui_asset_outline_contact_sheet.png`
  - `outputs/ui_asset_outline_experiment/bottom_bar_wide_plate_outline.png`
  - `outputs/ui_asset_outline_experiment/primary_button_outline.png`
  - `outputs/ui_asset_outline_experiment/small_button_outline.png`
  - `outputs/ui_asset_outline_experiment/shop_card_frame_outline.png`
- Current full-game comparison capture:
  - `outputs/vision_snapshots/smoke/05_post_fight_shop_1783096910_6543_software.png`
  - `outputs/vision_snapshots/smoke/05_post_fight_shop_1783096910_6543.json`

## Results

| Test | Target | Native ImageGen output | Result |
| --- | ---: | ---: | --- |
| Contact-sheet edit | `1280x720` | `1672x941` | Failed exact canvas preservation |
| Primary button edit | `240x54` | raw `1874x839`, detected button `1738x442` | Failed native exact sizing; exact-mask postprocess made a `240x54` asset but with visible aspect distortion risk |
| Bottom bar edit | `1120x238` | raw `1717x916`, detected plate `1644x362` | Failed native exact sizing; exact-mask postprocess made a visually plausible `1120x238` asset |

The current post-fight shop full-flow capture reported:

- `GothicShopPlate`: `1140x274`
- `BottomStorageArea`: `1120x254`
- `ShopGrid`: `1120x178`
- shop cards: `150x138`
- primary continue button: `240x62` in layout, using the `240x54` asset through button styling

## Recommendation

The built-in ImageGen path is not reliable as a pixel-exact asset generator, even when the source image is an exact calculated outline. It is good at matching the gothic art language and preserving broad shape intent, but it changes output canvas size and sometimes changes aspect ratio.

Use this workflow for production candidates:

1. Generate a calculated outline/mask from the exact in-game slot and nine-slice margins.
2. Use ImageGen as a style-render pass, not as the final sizing authority.
3. Detect the generated asset bounding box.
4. Crop, resize, and apply the original exact silhouette mask.
5. Validate the recovered dimensions and nine-slice margins against a current full-game capture.
6. Prefer this for wide panels and large frames. For tiny buttons, generate larger master assets or manually clean the postprocessed result before replacing production art.

## Artifacts

- Raw contact sheet: `outputs/ui_asset_outline_experiment/imagegen_contact_sheet_pass1.png`
- Raw primary button: `outputs/ui_asset_outline_experiment/imagegen_primary_button_raw.png`
- Recovered primary button: `outputs/ui_asset_outline_experiment/imagegen_primary_button_postprocessed_240x54.png`
- Raw bottom bar: `outputs/ui_asset_outline_experiment/imagegen_bottom_bar_raw.png`
- Recovered bottom bar: `outputs/ui_asset_outline_experiment/imagegen_bottom_bar_postprocessed_1120x238.png`
- Final comparison: `outputs/ui_asset_outline_experiment/full_game_slot_comparison_latest.png`

## Validation

Ran `tests/visual/VisionCaptureSmoke.tscn` through the Godot MCP runner. It completed with:

`VisionCaptureSmoke: OK captures=6 output=C:/Users/Flipm/Documents/gamble-battle/outputs/vision_snapshots/smoke`

The debug output still included known dummy-renderer cleanup diagnostics at process exit. No gameplay or assertion failure was reported by the smoke.
