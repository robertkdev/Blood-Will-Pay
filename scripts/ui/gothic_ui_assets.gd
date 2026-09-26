extends Object
class_name GothicUIAssets

const TextureUtils: GDScript = preload("res://scripts/util/texture_utils.gd")

const PANEL_PLATE_WIDE: String = "res://assets/ui/gothic/panel_plate_wide_v2.png"
const PANEL_PLATE_GRID: String = "res://assets/ui/gothic/panel_plate_grid_v2.png"
const PANEL_PLATE_ITEM_STORAGE: String = "res://assets/ui/gothic/panel_plate_item_storage.png"
const PANEL_PLATE_TRAITS: String = "res://assets/ui/gothic/panel_plate_traits.png"
## Runtime trial frame recovered from Luna's blackened-iron / dim-old-gold pass.
## Same 150x138 size, alpha bbox and 22px nine-slice as the retained original,
## so it is a drop-in stylebox swap with no layout change.
const SHOP_CARD_FRAME: String = "res://assets/ui/gothic/generated/shop_card_frame_luna_v1.png"
## One-line rollback: point SHOP_CARD_FRAME back at this retained original.
const SHOP_CARD_FRAME_ROLLBACK: String = "res://assets/ui/gothic/shop_card_frame_v2.png"
const BUTTON_SMALL: String = "res://assets/ui/gothic/button_small_v2.png"
const BUTTON_PRIMARY: String = "res://assets/ui/gothic/button_primary_v2.png"
## Generated stone floor with blood, grates and debris at the edges, left even through the
## middle so the panels and the grid sit on it rather than in a black void.
const SCREEN_BACKDROP: String = "res://assets/ui/gothic/generated/arena_backdrop.png"
const BATTLEFIELD_SURFACE: String = "res://assets/ui/gothic/battlefield_surface_horror_v1.png"
const BATTLEFIELD_SURFACE_TOP: String = "res://assets/ui/gothic/battlefield_surface_horror_v1_top.png"
const BATTLEFIELD_SURFACE_BOTTOM: String = "res://assets/ui/gothic/battlefield_surface_horror_v1_bottom.png"
const BATTLEFIELD_SURFACE_ONSET: String = "res://assets/ui/gothic/generated/arena_firelit_luna_v6.png"
const BATTLEFIELD_SURFACE_MIDFIGHT: String = "res://assets/ui/gothic/battlefield_surface_horror_midfight_v2.png"
const BATTLEFIELD_SURFACE_REDUCED_MOTION: String = "res://assets/ui/gothic/battlefield_surface_horror_reduced_motion_v2.png"
const BOARD_TILE_PLAYER: String = "res://assets/ui/gothic/board_tile_player.png"
const BOARD_TILE_ENEMY: String = "res://assets/ui/gothic/board_tile_enemy.png"
const BENCH_SLOT_FRAME: String = "res://assets/ui/gothic/bench_slot_frame.png"
const ITEM_ICON_FRAME: String = "res://assets/ui/gothic/item_icon_frame.png"
const UNIT_BASE_PLAYER: String = "res://assets/ui/gothic/unit_base_player.png"
const UNIT_BASE_ENEMY: String = "res://assets/ui/gothic/unit_base_enemy.png"
const ARENA_FRAME: String = "res://assets/ui/gothic/arena_frame.png"
const STATUS_STRIP: String = "res://assets/ui/gothic/status_strip.png"

## Gameplay material family.
##
## Every gameplay panel is meant to read as one constructed object: a recessed
## near-black iron interior behind a thin, dull warm-gold edge. These colours are
## the code-drawn stand-in for that surface, used both as the shipping fallback
## and as the exact fallback under the root-approved generated panel. Title,
## menu and starter surfaces keep `wide_panel_style`/`grid_panel_style`; nothing
## here redefines those, so the opening flows are untouched.
const COLOR_GAMEPLAY_RECESS: Color = Color(0.028, 0.024, 0.030, 0.97)
const COLOR_GAMEPLAY_RECESS_DEEP: Color = Color(0.014, 0.012, 0.016, 0.98)
const COLOR_GAMEPLAY_EDGE: Color = Color(0.47, 0.39, 0.27, 0.72)
const COLOR_GAMEPLAY_EDGE_DIM: Color = Color(0.33, 0.28, 0.23, 0.62)
const COLOR_GAMEPLAY_CRIMSON: Color = Color(0.42, 0.048, 0.060, 0.98)
const COLOR_GAMEPLAY_CRIMSON_HOT: Color = Color(0.62, 0.075, 0.075, 0.99)

## Gameplay surfaces. Each helper returns its documented fallback while a file is
## absent or does not match the audited source size, so an unapproved or resized
## asset can never reach the runtime. The v5 panel below is wired as a trial.
const GAMEPLAY_PANEL_SURFACE: String = "res://assets/ui/gothic/generated/gameplay_panel_luna_v5.png"
## The shipping name, so a caller can refer to the trial explicitly.
const GAMEPLAY_PANEL_SURFACE_TRIAL_V5: String = GAMEPLAY_PANEL_SURFACE
## Rejected earlier candidate: kept for provenance and one-line rollback only.
const GAMEPLAY_PANEL_SURFACE_REJECTED_V2: String = "res://assets/ui/gothic/generated/gameplay_panel_luna_v2.png"
const GAMEPLAY_COMMIT_SURFACE: String = "res://assets/ui/gothic/generated/gameplay_commit_luna_v2.png"
const GAMEPLAY_PANEL_SURFACE_SIZE: Vector2 = Vector2(320.0, 320.0)
const GAMEPLAY_COMMIT_SURFACE_SIZE: Vector2 = Vector2(256.0, 144.0)
## v5 is a root-approved FULL-SCENE TRIAL, not final approval: its narrower
## aged-brass rim and quiet iron centre replace the flat fallback only on the UI
## panels the theme allowlists (rails, reliquary/shop content panels, wager and
## action bays). Arena, board, environment and label surfaces keep the paint they
## were authored with. The rejected v2 surface is never used, and the 40px bands
## below stay separate from the panels' own content insets.
const GAMEPLAY_PANEL_SURFACE_ENABLED: bool = true
## The crimson action plaque is declined for the commit action: that control's
## acceptance contract is restrained flat field furniture, and the plaque's own
## relief reads as a second frame inside its bay. The file is kept for provenance
## and one-line rollback, exactly like the rejected v2 panel.
const GAMEPLAY_COMMIT_SURFACE_ENABLED: bool = false
## A surface at least this wide and tall can carry the 40px nine-slice bands
## without the rim becoming the whole surface. Small controls keep the flat iron.
const GAMEPLAY_PANEL_MIN_SPAN: float = 80.0
## Nine-slice bands, in source pixels: 40px for the panel, 24px for the commit
## plaque. The source size is checked against these before the slice is used.
const GAMEPLAY_PANEL_SLICE_PX: float = 40.0
const GAMEPLAY_COMMIT_SLICE_PX: float = 24.0
## Content insets are set explicitly, never inherited from the slice bands.
## `StyleBox::get_margin()` falls back to the texture margin when a content
## margin is unset, so a 40px band would otherwise become an 80px inset per axis
## and push every panel and button off its authored layout. Panels stay tight;
## the commit action gets a comfortable inset while its target stays inside the
## authored 90-140px action band.
const GAMEPLAY_PANEL_CONTENT_INSETS: Vector4 = Vector4(8.0, 6.0, 8.0, 6.0)
const GAMEPLAY_COMMIT_CONTENT_INSETS: Vector4 = Vector4(12.0, 4.0, 12.0, 4.0)

## Generated icon sheets. Five action cells (reroll, lock, level up, all in, wager) and three
## reliquary cells (reliquary, ledger, bone chit), laid out left to right.
const ACTION_ICONS: String = "res://assets/ui/gothic/generated/action_icons.png"
const RELIC_ICONS: String = "res://assets/ui/gothic/generated/relic_icons.png"
const ACTION_ICON_REROLL: int = 0
const ACTION_ICON_LOCK: int = 1
const ACTION_ICON_LEVEL_UP: int = 2
const ACTION_ICON_ALL_IN: int = 3
const ACTION_ICON_WAGER: int = 4
const RELIC_ICON_RELIQUARY: int = 0
const RELIC_ICON_LEDGER: int = 1
const RELIC_ICON_CHIT: int = 2
## Drawn size of one icon, in the game's own pixels. The sheets are resized down to this once
## rather than left at their 512px cell size for the layout to squeeze.
## The shelf bar lives in a vertical budget the compact tiers shrink hard, so an icon that is
## comfortable at 1080p overflows the maximum-scale layout and pushes the shop cards past the
## bottom edge. 22 keeps the action button's height at what the text-only button used to be.
const ACTION_ICON_PIXELS: int = 22
const RELIC_ICON_PIXELS: int = 48
## Crossed-swords primary-action emblem: an IN-GAME TRIAL candidate only. Root
## approved a trial of this file, not final shipping acceptance, and nothing is
## attached to a Button yet - the action bay takes it once its geometry is stable.
## Source, recovery and display-size decisions are recorded in
## docs/art/gameplay_composition_v2_assets.md.
const PRIMARY_ACTION_EMBLEM: String = "res://assets/ui/gothic/generated/crossed_swords_emblem_luna_v1.png"
## The trial name, so a caller can refer to the candidate explicitly.
const PRIMARY_ACTION_EMBLEM_TRIAL_V1: String = PRIMARY_ACTION_EMBLEM
## Drawn size of the emblem, in the game's own pixels. The source is a 128px canvas
## with the mark inset inside it (98x97 of the 128 here), so 56 logical draws a
## ~43px visible crest at 100% UI. Resized once rather than handed over at 128px,
## which a Button turns into its own minimum size.
const PRIMARY_ACTION_EMBLEM_PIXELS: int = 56
## Built once per session; the candidate is a fixed size and never re-resized.
static var _primary_action_emblem: Texture2D = null

## One cell of a horizontally laid out icon sheet, resized to `target` pixels wide.
##
## The sheets are 512px cells. Handing one straight to a Button makes the button's minimum
## size 520px tall, and the drawing code then squeezes the icon into whatever the row allows -
## so the glyph ends up a smudge whose size nothing controls, and `icon_max_width` does not
## change it. Resizing the cell once gives a texture whose size is the size that gets drawn.
static func sheet_icon(path: String, cells: int, slot: int, target: int = 40) -> Texture2D:
	var sheet: Texture2D = TextureUtils.try_load_texture(path)
	if sheet == null or cells <= 0:
		return null
	var width: int = sheet.get_width()
	var height: int = sheet.get_height()
	if width < cells or height <= 0:
		return null
	var cell: int = int(float(width) / float(cells))
	if cell <= 0:
		return null
	var image: Image = sheet.get_image()
	if image == null:
		return null
	var patch: Image = image.get_region(Rect2i(clampi(slot, 0, cells - 1) * cell, 0, cell, height))
	if target > 0 and target != cell:
		var target_height: int = maxi(1, int(round(float(height) * float(target) / float(cell))))
		patch.resize(target, target_height, Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(patch)

static func action_icon(slot: int) -> Texture2D:
	return sheet_icon(ACTION_ICONS, 5, slot, ACTION_ICON_PIXELS)

static func relic_icon(slot: int) -> Texture2D:
	return sheet_icon(RELIC_ICONS, 3, slot, RELIC_ICON_PIXELS)

## The crossed-swords primary-action emblem at its bounded display size.
##
## The candidate is one image, so it is the existing `sheet_icon` route with a
## single cell: loaded and resized to `PRIMARY_ACTION_EMBLEM_PIXELS` once, and the
## texture's own size is then the size that gets drawn. Cached for the session, and
## null while the candidate is absent, so a caller keeps whatever presentation it
## already had.
static func primary_action_emblem() -> Texture2D:
	if _primary_action_emblem == null:
		_primary_action_emblem = sheet_icon(PRIMARY_ACTION_EMBLEM, 1, 0, PRIMARY_ACTION_EMBLEM_PIXELS)
	return _primary_action_emblem

static func wide_panel_style(modulate: Color = Color.WHITE) -> StyleBoxTexture:
	return texture_style(PANEL_PLATE_WIDE, Vector4(42.0, 42.0, 42.0, 42.0), Vector4(22.0, 18.0, 22.0, 18.0), modulate)

static func grid_panel_style(modulate: Color = Color.WHITE) -> StyleBoxTexture:
	return texture_style(PANEL_PLATE_GRID, Vector4(40.0, 36.0, 40.0, 36.0), Vector4(18.0, 14.0, 18.0, 14.0), modulate)

static func item_storage_panel_style(modulate: Color = Color.WHITE) -> StyleBoxTexture:
	return texture_style(PANEL_PLATE_ITEM_STORAGE, Vector4(40.0, 36.0, 40.0, 36.0), Vector4(18.0, 14.0, 18.0, 14.0), modulate)

static func traits_panel_style(modulate: Color = Color.WHITE) -> StyleBoxTexture:
	return texture_style(PANEL_PLATE_TRAITS, Vector4(40.0, 40.0, 40.0, 40.0), Vector4(18.0, 18.0, 18.0, 18.0), modulate)

static func shop_card_style(modulate: Color = Color.WHITE) -> StyleBoxTexture:
	return texture_style(SHOP_CARD_FRAME, Vector4(22.0, 22.0, 22.0, 22.0), Vector4(8.0, 8.0, 8.0, 8.0), modulate)

static func small_button_style(modulate: Color = Color.WHITE) -> StyleBoxTexture:
	return texture_style(BUTTON_SMALL, Vector4(18.0, 14.0, 18.0, 14.0), Vector4(16.0, 7.0, 16.0, 7.0), modulate)

static func primary_button_style(modulate: Color = Color.WHITE) -> StyleBoxTexture:
	return texture_style(BUTTON_PRIMARY, Vector4(26.0, 16.0, 26.0, 16.0), Vector4(22.0, 8.0, 22.0, 8.0), modulate)

static func apply_button_material(button: Button, primary: bool) -> void:
	var states: Dictionary[String, Color] = {
		"normal": Color.WHITE,
		"hover": Color(1.18, 1.12, 1.04),
		"pressed": Color(0.78, 0.74, 0.68),
		"hover_pressed": Color(0.90, 0.82, 0.72),
		"disabled": Color(0.45, 0.45, 0.45, 0.86),
	}
	for state: String in states:
		# The commit action keeps a material texture of its own (the root-approved
		# crimson plaque once it ships, the existing primary plate until then) so
		# it keeps independent weight. Every other gameplay button is the same
		# quiet recessed iron as the panels; the legacy silver button plate is no
		# longer a gameplay surface.
		var style: StyleBox = gameplay_commit_style(states[state]) if primary else quiet_iron_button_style(state)
		if style == null:
			continue
		# Text and hit areas keep their responsive budget; ornament is only paint.
		# The insets are explicit, so a 24px commit band can never become a 48px
		# inset, and the action target stays inside its authored width band.
		if primary:
			style.content_margin_left = GAMEPLAY_COMMIT_CONTENT_INSETS.x
			style.content_margin_top = GAMEPLAY_COMMIT_CONTENT_INSETS.y
			style.content_margin_right = GAMEPLAY_COMMIT_CONTENT_INSETS.z
			style.content_margin_bottom = GAMEPLAY_COMMIT_CONTENT_INSETS.w
		else:
			style.content_margin_left = 6.0
			style.content_margin_right = 6.0
			style.content_margin_top = 2.0
			style.content_margin_bottom = 2.0
		button.add_theme_stylebox_override(state, style)

static func item_slot_style(modulate: Color = Color.WHITE) -> StyleBoxTexture:
	return texture_style(BUTTON_SMALL, Vector4(10.0, 10.0, 10.0, 10.0), Vector4(3.0, 3.0, 3.0, 3.0), modulate)

static func bench_slot_style(modulate: Color = Color.WHITE) -> StyleBoxTexture:
	return texture_style(BENCH_SLOT_FRAME, Vector4(22.0, 22.0, 22.0, 22.0), Vector4(0.0, 0.0, 0.0, 0.0), modulate)

static func item_icon_frame_style(modulate: Color = Color.WHITE) -> StyleBoxTexture:
	# Same material family as the rest of the gameplay chrome: the pale default
	# tint read as a bright nested frame inside the recessed iron. The caller's
	# own tint still applies, through the family's dull warm edge.
	var family_tint: Color = Color(modulate.r * 0.62, modulate.g * 0.58, modulate.b * 0.50, modulate.a)
	return texture_style(ITEM_ICON_FRAME, Vector4(22.0, 22.0, 22.0, 22.0), Vector4(4.0, 4.0, 4.0, 4.0), family_tint)

static func complete_item_slot_style(filled: bool, hovered: bool) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.074, 0.047, 0.050, 0.98) if filled else Color(0.018, 0.016, 0.021, 0.96)
	style.border_color = (
		Color(0.66, 0.50, 0.28, 0.68)
		if hovered
		else Color(0.46, 0.37, 0.26, 0.52)
		if filled
		else Color(0.34, 0.30, 0.25, 0.38)
	)
	# One hairline per pocket. The nested two-weight frame is what made empty
	# relic pockets louder than the relics they hold.
	var border_width: int = 1
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_right = 2
	style.corner_radius_bottom_left = 2
	style.content_margin_left = 3.0
	style.content_margin_top = 3.0
	style.content_margin_right = 3.0
	style.content_margin_bottom = 3.0
	# A shallow recess: nested frames were carrying more visual weight than the
	# relics they hold, so the pocket casts no resting shadow and only a slight
	# warm lift on hover.
	style.shadow_size = 2 if hovered else 0
	style.shadow_color = Color(0.30, 0.10, 0.06, 0.18) if hovered else Color(0.0, 0.0, 0.0, 0.0)
	return style

static func complete_item_slot_inner_style(filled: bool, hovered: bool) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	# No resting ring. This inner outline was the redundant nested frame that
	# made the cache read as stacked pale boxes; the outer pocket already marks
	# empty versus filled, so hover keeps a single faint hairline of feedback.
	style.border_color = Color(0.80, 0.63, 0.38, 0.44) if hovered else Color(0.44, 0.36, 0.26, 0.0)
	var inner_width: int = 1 if hovered else 0
	style.border_width_left = inner_width
	style.border_width_top = inner_width
	style.border_width_right = inner_width
	style.border_width_bottom = inner_width
	style.corner_radius_top_left = 1
	style.corner_radius_top_right = 1
	style.corner_radius_bottom_right = 1
	style.corner_radius_bottom_left = 1
	style.draw_center = false
	return style

static func unit_base_style(is_player: bool, modulate: Color = Color.WHITE) -> StyleBoxTexture:
	var path: String = UNIT_BASE_PLAYER if is_player else UNIT_BASE_ENEMY
	return texture_style(path, Vector4(36.0, 24.0, 36.0, 24.0), Vector4(0.0, 0.0, 0.0, 0.0), modulate)

static func arena_frame_style(modulate: Color = Color.WHITE) -> StyleBoxTexture:
	return texture_style(ARENA_FRAME, Vector4(58.0, 58.0, 58.0, 58.0), Vector4(0.0, 0.0, 0.0, 0.0), modulate, false)

static func status_strip_style(modulate: Color = Color.WHITE) -> StyleBoxTexture:
	return texture_style(STATUS_STRIP, Vector4(54.0, 24.0, 54.0, 24.0), Vector4(16.0, 6.0, 16.0, 6.0), modulate)

static func focus_outline_style(radius: int = 5, border_color: Color = Color(1.0, 0.80, 0.43, 1.0), border_width: int = 2) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	style.border_color = border_color
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_right = radius
	style.corner_radius_bottom_left = radius
	style.draw_center = false
	return style

static func screen_backdrop_texture() -> Texture2D:
	return TextureUtils.try_load_texture(SCREEN_BACKDROP)

static func battlefield_texture() -> Texture2D:
	return TextureUtils.try_load_texture(BATTLEFIELD_SURFACE)

static func battlefield_top_texture() -> Texture2D:
	return TextureUtils.try_load_texture(BATTLEFIELD_SURFACE_TOP)

static func battlefield_bottom_texture() -> Texture2D:
	return TextureUtils.try_load_texture(BATTLEFIELD_SURFACE_BOTTOM)

static func battlefield_onset_texture() -> Texture2D:
	return TextureUtils.try_load_texture(BATTLEFIELD_SURFACE_ONSET)

static func battlefield_midfight_texture() -> Texture2D:
	return TextureUtils.try_load_texture(BATTLEFIELD_SURFACE_MIDFIGHT)

static func battlefield_reduced_motion_texture() -> Texture2D:
	return TextureUtils.try_load_texture(BATTLEFIELD_SURFACE_REDUCED_MOTION)

static func board_tile_style(is_player: bool, modulate: Color = Color.WHITE) -> StyleBoxTexture:
	var path: String = BOARD_TILE_PLAYER if is_player else BOARD_TILE_ENEMY
	return texture_style(path, Vector4(22.0, 22.0, 22.0, 22.0), Vector4(0.0, 0.0, 0.0, 0.0), modulate)

## Quiet recessed iron: the gameplay panel fallback, and the shape the approved
## generated panel replaces. Deliberately flat, with one thin edge rather than a
## bevel, so panels read as construction instead of a stack of bright outlines.
static func quiet_iron_panel_style(bg_color: Color = COLOR_GAMEPLAY_RECESS, edge_color: Color = COLOR_GAMEPLAY_EDGE, side_accent: bool = false) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = edge_color
	style.border_width_left = 3 if side_accent else 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 2
	style.shadow_size = 4
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.46)
	# Tight content margins: the recess is the point, so panel inners must not be
	# padded away into a bright cover. These match the surfaces they fall back for.
	style.content_margin_left = 4.0
	style.content_margin_right = 4.0
	style.content_margin_top = 2.0
	style.content_margin_bottom = 2.0
	return style

## Quiet recessed iron at full panel scale, for surfaces that are not buttons.
static func quiet_iron_recess_style(side_accent: bool = false) -> StyleBoxFlat:
	return quiet_iron_panel_style(COLOR_GAMEPLAY_RECESS_DEEP, COLOR_GAMEPLAY_EDGE_DIM, side_accent)

## Per-state quiet iron for gameplay buttons. One material family: the state is
## carried by the interior tint and the edge, not by a second kind of border.
static func quiet_iron_button_style(state: String) -> StyleBoxFlat:
	match state:
		"hover":
			return quiet_iron_panel_style(Color(0.055, 0.045, 0.046, 0.97), Color(0.62, 0.50, 0.32, 0.90))
		"pressed", "hover_pressed":
			return quiet_iron_panel_style(Color(0.150, 0.030, 0.040, 0.98), Color(0.64, 0.14, 0.12, 0.88), true)
		"disabled":
			return quiet_iron_panel_style(Color(0.028, 0.026, 0.030, 0.90), Color(0.26, 0.24, 0.24, 0.66))
	return quiet_iron_panel_style()

## Transient interaction surfaces share the permanent panel vocabulary: one quiet
## recessed iron field behind a single thin aged-brass rim. The relic pockets used
## to stack three pale rounded frames here, so the frame read louder than the
## relic; these helpers keep the node layout and the slot states and give the
## pocket exactly one rim.
static func relic_pocket_style(filled: bool, hovered: bool) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.040, 0.022, 0.024, 0.94) if filled else Color(0.016, 0.014, 0.018, 0.94)
	style.border_color = Color(0.78, 0.60, 0.36, 0.92) if hovered else Color(0.52, 0.42, 0.32, 0.86) if filled else Color(0.34, 0.30, 0.27, 0.78)
	style.set_border_width_all(1)
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_right = 2
	style.corner_radius_bottom_left = 2
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.72)
	style.shadow_size = 4 if hovered else 2
	style.content_margin_left = 4.0
	style.content_margin_top = 3.0
	style.content_margin_right = 4.0
	style.content_margin_bottom = 4.0
	return style

## The recess inside that single rim, with no second frame of its own: the dark
## interior and one inner shadow line carry the depth.
static func relic_cavity_style(filled: bool, hovered: bool) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.058, 0.022, 0.026, 0.96) if filled else Color(0.006, 0.005, 0.007, 0.98)
	style.border_color = Color(0.30, 0.26, 0.23, 0.55) if hovered else Color(0.20, 0.17, 0.16, 0.45)
	style.border_width_left = 0
	style.border_width_top = 1
	style.border_width_right = 0
	style.border_width_bottom = 0
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_right = 2
	style.corner_radius_bottom_left = 2
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.90)
	style.shadow_size = 3
	return style

## The pocket's inner frame is retired: a slot keeps exactly one rim. The node
## stays where the author put it and simply draws nothing.
static func relic_inner_style(_filled: bool, _hovered: bool) -> StyleBox:
	return StyleBoxEmpty.new()

## Hover tooltip material: the same quiet iron and single thin brass rim as the
## relic pockets, with the content insets the tooltip layout already assumes.
static func tooltip_panel_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = quiet_iron_panel_style(COLOR_GAMEPLAY_RECESS, COLOR_GAMEPLAY_EDGE, false)
	style.set_border_width_all(1)
	style.border_width_bottom = 2
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_right = 2
	style.corner_radius_bottom_left = 2
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	style.shadow_size = 10
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.62)
	return style

## Crimson primary-action fallback: the commit action's own material, so it keeps
## independent weight next to the quiet panels instead of reading as one more
## support button. Replaced by the approved commit plaque when that ships.
static func quiet_iron_commit_style(modulate: Color = Color.WHITE) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(
		COLOR_GAMEPLAY_CRIMSON.r * modulate.r,
		COLOR_GAMEPLAY_CRIMSON.g * modulate.g,
		COLOR_GAMEPLAY_CRIMSON.b * modulate.b,
		COLOR_GAMEPLAY_CRIMSON.a * modulate.a,
	)
	style.border_color = Color(
		minf(1.0, COLOR_GAMEPLAY_EDGE.r + 0.14),
		minf(1.0, COLOR_GAMEPLAY_EDGE.g + 0.12),
		minf(1.0, COLOR_GAMEPLAY_EDGE.b + 0.10),
		COLOR_GAMEPLAY_EDGE.a,
	)
	style.border_width_left = 2
	style.border_width_top = 1
	style.border_width_right = 2
	style.border_width_bottom = 3
	style.shadow_size = 8
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.54)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 4.0
	style.content_margin_bottom = 4.0
	return style

## The gameplay panel surface: the trial nine-slice when it is present at the
## audited size, otherwise `fallback`. The accessor does not decide which surface
## may use it - the theme's allowlist and `gameplay_panel_style_for()` do, since a
## 40px band on a thin strip or over the arena would be all band.
static func gameplay_panel_style(fallback: StyleBox = null, content_insets: Vector4 = GAMEPLAY_PANEL_CONTENT_INSETS) -> StyleBox:
	if not GAMEPLAY_PANEL_SURFACE_ENABLED:
		# Surface declined: callers already pass their own fallback.
		return fallback if fallback != null else quiet_iron_recess_style()
	var harvested: StyleBoxTexture = approved_surface_style(
		GAMEPLAY_PANEL_SURFACE, GAMEPLAY_PANEL_SURFACE_SIZE, GAMEPLAY_PANEL_SLICE_PX, content_insets
	)
	if harvested != null:
		return harvested
	return fallback if fallback != null else quiet_iron_recess_style()

## True when a surface of this size can carry the panel's 40px nine-slice bands
## without the rim becoming the whole surface.
static func gameplay_panel_fits(surface_size: Vector2) -> bool:
	return surface_size.x >= GAMEPLAY_PANEL_MIN_SPAN and surface_size.y >= GAMEPLAY_PANEL_MIN_SPAN

## Size-aware panel material for a caller that has already decided the surface is
## an allowed UI panel: the trial surface when it fits, otherwise the fallback.
## A small or still-collapsed surface keeps the fallback, so a 40px band is never
## squeezed onto a button, a header or a thin strip.
static func gameplay_panel_style_for(surface_size: Vector2, fallback: StyleBox = null, content_insets: Vector4 = GAMEPLAY_PANEL_CONTENT_INSETS) -> StyleBox:
	if not gameplay_panel_fits(surface_size):
		return fallback if fallback != null else quiet_iron_recess_style()
	return gameplay_panel_style(fallback, content_insets)

## The commit action's material: the flat crimson family while the plaque surface
## is declined (`GAMEPLAY_COMMIT_SURFACE_ENABLED`), otherwise the root-approved
## plaque when present at the audited size, then the existing primary button
## material, then the crimson flat.
static func gameplay_commit_style(modulate: Color = Color.WHITE, content_insets: Vector4 = GAMEPLAY_COMMIT_CONTENT_INSETS) -> StyleBox:
	if not GAMEPLAY_COMMIT_SURFACE_ENABLED:
		# Surface declined: the commit action keeps the flat crimson family, which
		# is the same material the plaque falls back to.
		var declined: StyleBoxFlat = quiet_iron_commit_style(modulate)
		declined.content_margin_left = content_insets.x
		declined.content_margin_top = content_insets.y
		declined.content_margin_right = content_insets.z
		declined.content_margin_bottom = content_insets.w
		return declined
	var harvested: StyleBoxTexture = approved_surface_style(
		GAMEPLAY_COMMIT_SURFACE, GAMEPLAY_COMMIT_SURFACE_SIZE, GAMEPLAY_COMMIT_SLICE_PX, content_insets
	)
	if harvested != null:
		harvested.modulate_color = modulate
		return harvested
	var existing: StyleBoxTexture = primary_button_style(modulate)
	if existing != null:
		# The legacy plate's own 26/16 bands are texture margins; without explicit
		# content insets they would become the action's inset too.
		existing.content_margin_left = content_insets.x
		existing.content_margin_top = content_insets.y
		existing.content_margin_right = content_insets.z
		existing.content_margin_bottom = content_insets.w
		return existing
	return quiet_iron_commit_style(modulate)

## Evidence for the runtime validation pass: which gameplay surfaces are
## actually shipping, at which source size, with which slice bands.
static func gameplay_material_status() -> Dictionary:
	return {
		"panel_surface": GAMEPLAY_PANEL_SURFACE,
		"panel_surface_trial": true,
		"panel_surface_rejected": GAMEPLAY_PANEL_SURFACE_REJECTED_V2,
		"panel_source_size": GAMEPLAY_PANEL_SURFACE_SIZE,
		"panel_slice_px": GAMEPLAY_PANEL_SLICE_PX,
		"panel_content_insets": GAMEPLAY_PANEL_CONTENT_INSETS,
		"panel_min_span": GAMEPLAY_PANEL_MIN_SPAN,
		"panel_shipping": approved_surface_present(GAMEPLAY_PANEL_SURFACE, GAMEPLAY_PANEL_SURFACE_SIZE),
		"panel_surface_enabled": GAMEPLAY_PANEL_SURFACE_ENABLED,
		"commit_surface": GAMEPLAY_COMMIT_SURFACE,
		"commit_source_size": GAMEPLAY_COMMIT_SURFACE_SIZE,
		"commit_slice_px": GAMEPLAY_COMMIT_SLICE_PX,
		"commit_content_insets": GAMEPLAY_COMMIT_CONTENT_INSETS,
		"commit_shipping": approved_surface_present(GAMEPLAY_COMMIT_SURFACE, GAMEPLAY_COMMIT_SURFACE_SIZE),
		"commit_surface_enabled": GAMEPLAY_COMMIT_SURFACE_ENABLED,
	}

## True when the shipping file exists and matches the audited source size.
static func approved_surface_present(path: String, expected_size: Vector2) -> bool:
	if path.is_empty():
		return false
	var texture: Texture2D = TextureUtils.try_load_texture(path)
	return texture != null and texture.get_size() == expected_size

## Nine-slice builder for the approved gameplay surfaces. Silent while the file
## is simply not shipped yet; a present file at the wrong size is a shipping
## error and warns once per call site.
static func approved_surface_style(path: String, expected_size: Vector2, slice_px: float, content_insets: Vector4 = GAMEPLAY_PANEL_CONTENT_INSETS) -> StyleBoxTexture:
	if path.is_empty():
		return null
	var texture: Texture2D = TextureUtils.try_load_texture(path)
	if texture == null:
		return null
	if texture.get_size() != expected_size:
		push_warning("Gameplay surface %s is %s, expected %s; using the fallback material." % [
			path, str(texture.get_size()), str(expected_size),
		])
		return null
	var style: StyleBoxTexture = StyleBoxTexture.new()
	style.texture = texture
	style.texture_margin_left = slice_px
	style.texture_margin_top = slice_px
	style.texture_margin_right = slice_px
	style.texture_margin_bottom = slice_px
	style.content_margin_left = content_insets.x
	style.content_margin_top = content_insets.y
	style.content_margin_right = content_insets.z
	style.content_margin_bottom = content_insets.w
	return style

static func texture_style(path: String, texture_margins: Vector4, content_margins: Vector4, modulate: Color = Color.WHITE, draw_center: bool = true) -> StyleBoxTexture:
	var texture: Texture2D = TextureUtils.try_load_texture(path)
	if texture == null:
		push_warning("Gothic UI asset missing: %s" % path)
		return null
	var style: StyleBoxTexture = StyleBoxTexture.new()
	style.texture = texture
	style.texture_margin_left = texture_margins.x
	style.texture_margin_top = texture_margins.y
	style.texture_margin_right = texture_margins.z
	style.texture_margin_bottom = texture_margins.w
	style.content_margin_left = content_margins.x
	style.content_margin_top = content_margins.y
	style.content_margin_right = content_margins.z
	style.content_margin_bottom = content_margins.w
	style.draw_center = draw_center
	style.modulate_color = modulate
	return style

static func style_or_fallback(asset_style: StyleBoxTexture, fallback_style: StyleBox) -> StyleBox:
	if asset_style != null:
		return asset_style
	return fallback_style
