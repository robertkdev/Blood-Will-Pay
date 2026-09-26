extends Button
class_name ShopCard

const TextureUtils := preload("res://scripts/util/texture_utils.gd")
const TraitIconScene := preload("res://scenes/ui/traits/TraitIcon.tscn")
const AbilityCatalog := preload("res://scripts/game/abilities/ability_catalog.gd")
const UnitFactory := preload("res://scripts/unit_factory.gd")
const UnitTargetingText := preload("res://scripts/ui/unit_targeting_text.gd")
const UnitUpgradePaths := preload("res://scripts/game/units/unit_upgrade_paths.gd")
const GothicUIAssets: GDScript = preload("res://scripts/ui/gothic_ui_assets.gd")
const VisualTypeSystem: GDScript = preload("res://scripts/ui/visual_type_system.gd")
const UnitArtPresentation: GDScript = preload("res://scripts/ui/unit_art_presentation.gd")
const UserSettingsScript: GDScript = preload("res://scripts/game/settings/user_settings.gd")
const BloodBuckets: GDScript = preload("res://scripts/game/economy/blood_buckets.gd")

const COLOR_TEXT: Color = Color(0.91, 0.87, 0.78, 1.0)
const COLOR_MUTED: Color = Color(0.66, 0.60, 0.52, 1.0)
const COLOR_GOLD: Color = Color(0.92, 0.66, 0.32, 1.0)
const COLOR_BLOOD: Color = Color(0.52, 0.040, 0.072, 1.0)
const COLOR_PANEL: Color = Color(0.045, 0.037, 0.047, 0.97)
const COLOR_IRON: Color = Color(0.40, 0.34, 0.32, 0.94)
const TOOLTIP_WIDTH: float = 400.0
const TOOLTIP_CURSOR_OFFSET: Vector2 = Vector2(18.0, -14.0)
const TOOLTIP_EDGE_PADDING: float = 12.0
const COMPACT_TOOLTIP_MIN_HEIGHT: float = 76.0
const COMPACT_NAME_SHARE: float = 0.62
## The shared caption row splits at `COMPACT_NAME_SHARE`, so the compact price
## share is 0.38 of the cell. The tier's price copy ("0 bkt") measures 43.0
## logical at the dock's 17px font plus its own 4px right inset, so holding the
## name and the price on one row needs (43.0 + 4.0) / 0.38 = 124 logical of
## card. The composed dock's 150-percent cell is 97 logical wide and the dock
## band has no width left to widen it, so below this width the caption stacks:
## the name keeps a full-width row and the price takes the row beneath it.
const CAPTION_STACK_MAX_WIDTH: float = 124.0
## The compact tiers are budgeted cells, not a share of the raw frame:
## `CompactShopFooterSmoke` holds the compact card to 80-96 logical pixels and the
## tight card to 54-70, while the composed dock owns its own taller cell through
## `Composition.shop_card_height` and only asks this for the card's portrait tier.
const COMPACT_CELL_HEIGHT: float = 88.0
const TIGHT_CELL_HEIGHT: float = 62.0
## A composed dock cell has to be at least this tall before the card trades its
## compact summary for the full detail panel. This mirrors the portrait-layout
## threshold used by `set_compact_presentation`.
const COMPOSED_DOCK_DETAIL_MIN_CELL_HEIGHT: float = 100.0

@onready var _icon: TextureRect = $Icon
@onready var _name_label: Label = $Name
@onready var _price_label: Label = $Price
@onready var _border_gradient: TextureRect = get_node_or_null("boarder_gradient") as TextureRect
@onready var _bottom_gradient: TextureRect = get_node_or_null("bottom_gradient") as TextureRect
@onready var _legacy_role_label: Label = get_node_or_null("Role") as Label
@onready var _traits_box: VBoxContainer = $TraitIcons
@onready var _identity_panel: VBoxContainer = $IdentityPanel
@onready var _role_badge: Label = $"IdentityPanel/RoleBadge"
@onready var _goal_label: Label = $"IdentityPanel/GoalLabel"
@onready var _approach_tags: FlowContainer = $"IdentityPanel/ApproachTags"

var offer_id: String = ""
var _disabled_reason: String = ""
var slot_index: int = -1
var _hover_tween: Tween = null
var _hovered: bool = false
var _compact_presentation: bool = false
var _tight_presentation: bool = false
var _has_identity_content: bool = false
var _tooltip: PanelContainer = null
var _tooltip_layer: CanvasLayer = null
var _tooltip_scroll: ScrollContainer = null
## Resolved once per hover: whether this card may show the full-detail panel.
var _tooltip_full_detail: bool = false
var _tooltip_title: String = ""
var _tooltip_subtitle: String = ""
var _tooltip_lines: Array[String] = []
var _tooltip_detail_context: Dictionary = {}
var _tooltip_details_built: bool = false
var _status_tip: String = ""
var _package_level: int = 1
var _package_kind: String = "standard"
var _price_value: int = 0
var _unit_texture: Texture2D = null
var _uses_board_art: bool = false
## The source the live portrait atlas was built from, the window it selects, and
## the aspect that window was measured for. Together they let a re-layout tell an
## unchanged crop apart from a stale one, so only the second case rebuilds.
var _portrait_source: Texture2D = null
var _portrait_region: Rect2 = Rect2()
var _portrait_frame_aspect: float = 0.0
var _portrait_atlas: AtlasTexture = null
var _portrait_refresh_queued: bool = false
var _caption_band: Panel = null

func _resolve_child(paths: Array) -> Node:
	for p in paths:
		var node := get_node_or_null(String(p))
		if node:
			return node
	return null

func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	toggle_mode = false
	clip_text = false
	tooltip_text = ""
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	# Connected before the first style pass, because that pass moves the icon's
	# anchors: the window has to follow the first rect it produces too.
	_wire_portrait_refresh()
	_apply_static_style()
	_wire_hover()
	if not is_connected("pressed", Callable(self, "_on_pressed")):
		pressed.connect(_on_pressed)

func set_data(props: Dictionary) -> void:
	if not disabled:
		_disabled_reason = ""
		set_meta("shop_disabled_reason", "")
	offer_id = String(props.get("id", ""))
	var title := String(props.get("name", "?"))
	var price_i := int(props.get("price", props.get("cost", 0)))
	_price_value = price_i
	_package_level = max(1, int(props.get("package_level", 1)))
	_package_kind = String(props.get("package_kind", "standard"))
	var img_path := String(props.get("image_path", props.get("sprite_path", "")))
	var roles: Array = _coerce_array(props.get("roles", []))
	var traits: Array = _coerce_array(props.get("traits", []))
	var primary_role := String(props.get("primary_role", ""))
	var primary_goal := String(props.get("primary_goal", ""))
	var approaches: Array = _coerce_array(props.get("approaches", []))
	var alt_goals: Array = _coerce_array(props.get("alt_goals", []))
	var identity_path := String(props.get("identity_path", ""))

	var display_role := _format_role(primary_role)
	if display_role == "" and roles.size() > 0:
		display_role = _format_role(roles[0])
	var display_goal := _format_goal(primary_goal)

	if _name_label:
		_name_label.text = "%s • Lv%d" % [title, _package_level] if _package_kind != "standard" else title
	if _price_label:
		_price_label.text = _price_copy()
	if _name_label and _package_kind == "current_grade":
		_name_label.text = "CAPITAL %s • Lv%d" % [title, _package_level]
	if _icon:
		var tex: Texture2D = null
		if img_path != "":
			tex = TextureUtils.try_load_texture(img_path)
		if tex == null:
			tex = TextureUtils.make_circle_texture(Color(0.75, 0.75, 0.75), 96)
			_uses_board_art = false
		else:
			_uses_board_art = bool(props.get("uses_board_art", false))
		_unit_texture = tex
		_apply_portrait_crop()

	_update_identity_panel(display_role, display_goal, approaches)
	_set_traits(traits)
	_apply_static_style()
	_apply_hover_motion(_hovered)

	var tooltip_lines: Array[String] = []
	if display_role != "":
		tooltip_lines.append("Role: %s" % display_role)
	if display_goal != "":
		tooltip_lines.append("Goal: %s" % display_goal)
	var approach_text := _format_list(approaches, 4)
	if approach_text != "":
		tooltip_lines.append("Approaches: %s" % approach_text)
	var alt_text := _format_list(alt_goals, 3)
	if alt_text != "":
		tooltip_lines.append("Alt Goals: %s" % alt_text)
	if identity_path != "":
		tooltip_lines.append(identity_path)
	if _package_kind != "standard":
		tooltip_lines.append("%s package: arrives at level %d" % ["Current-grade" if _package_kind == "current_grade" else "Depth-grade", _package_level])
	if _package_kind == "current_grade":
		var charter: Dictionary = UnitUpgradePaths.charter_definition(UnitUpgradePaths.charter_for_role(primary_role))
		tooltip_lines.append("CAPITAL CHARTER — %s" % String(charter.get("name", "Unknown Charter")))
		tooltip_lines.append("BENEFIT — %s" % String(charter.get("benefit", "")))
		tooltip_lines.append("DRAWBACK — %s" % String(charter.get("drawback", "")))
		tooltip_lines.append("FIT — %s" % String(charter.get("fit", "")))
	var identity_tip := "\n".join(tooltip_lines)
	set_meta("identity_tooltip", identity_tip)
	if _disabled_reason != "":
		tooltip_text = _disabled_reason
	elif identity_tip != "":
		tooltip_text = identity_tip
	else:
		tooltip_text = title
	_tooltip_title = title
	_tooltip_subtitle = "%s • %s Lv%d" % [BloodBuckets.describe(price_i), "Current Grade" if _package_kind == "current_grade" else "Depth Grade", _package_level] if _package_kind != "standard" else BloodBuckets.describe(price_i)
	# Unit preview construction is tooltip-only work. Do not do it while a reroll
	# is binding every visible card; wait until the player asks for detail.
	_tooltip_lines.clear()
	_tooltip_details_built = false
	_tooltip_detail_context = {
		"display_role": display_role,
		"display_goal": display_goal,
		"approaches": approaches,
		"alt_goals": alt_goals,
		"traits": traits,
	}
	set_meta("tooltip_detail_state", "deferred")
	if _package_kind == "current_grade":
		var capital_charter: Dictionary = UnitUpgradePaths.charter_definition(UnitUpgradePaths.charter_for_role(primary_role))
		_tooltip_subtitle = "%s • CAPITAL Lv%d" % [BloodBuckets.describe(price_i), _package_level]
		_tooltip_lines.push_front("DRAWBACK — %s" % String(capital_charter.get("drawback", "")))
		_tooltip_lines.push_front("BENEFIT — %s" % String(capital_charter.get("benefit", "")))
		_tooltip_lines.push_front("CAPITAL CHARTER — %s" % String(capital_charter.get("name", "")))
	tooltip_text = ""
	if _hovered:
		_show_tooltip()

func _update_identity_panel(display_role: String, display_goal: String, approaches: Array) -> void:
	var has_identity := false
	if _role_badge:
		if display_role != "":
			_role_badge.text = display_role.to_upper()
			_role_badge.visible = true
			has_identity = true
		else:
			_role_badge.visible = false
	if _goal_label:
		_goal_label.text = display_goal
		_goal_label.visible = false
	_set_approach_tags(approaches)
	if _approach_tags:
		_approach_tags.visible = false
	if _identity_panel:
		_has_identity_content = has_identity
		_identity_panel.visible = _has_identity_content and not _compact_presentation

func set_compact_presentation(enabled: bool, tight: bool = false, composed_dock: bool = false, cell_width: float = 0.0) -> void:
	_compact_presentation = enabled
	_tight_presentation = enabled and tight
	# The composed dock owns its cell width and passes it in, so the caption can
	# answer the cell it actually has: below the shared row's own requirement the
	# caption stacks instead of clipping the price (see CAPTION_STACK_MAX_WIDTH).
	var stack_caption: bool = enabled and composed_dock and cell_width > 1.0 and cell_width < CAPTION_STACK_MAX_WIDTH
	# Card layout and information access are separate decisions. A composed dock
	# keeps the compact portrait layout at full HD while still having room for
	# real detail, so only a genuinely small tier (no composed dock marker)
	# suppresses the detail panel.
	var full_detail: bool = not enabled or _full_detail_tooltip_allowed()
	set_meta("compact_tooltip_policy", "suppress_hover" if not full_detail else "full_detail_composed_dock" if enabled else "full_detail")
	set_meta("tooltip_suppressed_for_compact", not full_detail)
	if _tooltip != null and is_instance_valid(_tooltip):
		_clear_tooltip()
	if enabled:
		_clear_global_tooltip_layers()
	var card_height: float = presentation_height(get_viewport_rect().size, _tight_presentation, composed_dock)
	var portrait_layout: bool = card_height >= 100.0
	custom_minimum_size = Vector2(120.0 if _tight_presentation else 132.0, card_height)
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	set_meta("shop_safe_bottom_gutter", 2.0 if _tight_presentation else 6.0 if enabled else 16.0)
	if _icon != null:
		_icon.custom_minimum_size = Vector2.ZERO
		_icon.anchor_left = 0.10 if _tight_presentation else 0.08 if enabled else 0.12
		_icon.anchor_top = 0.04 if _tight_presentation else 0.05 if enabled else 0.21
		_icon.anchor_right = 0.90 if _tight_presentation else 0.92 if enabled else 0.88
		_icon.anchor_bottom = 0.61 if _tight_presentation else 0.66 if enabled else 0.78
		if portrait_layout:
			_icon.anchor_left = 0.06
			_icon.anchor_right = 0.94
			_icon.anchor_top = 0.04
			_icon.anchor_bottom = 1.0
		# A stacked caption rides one row lower than the shared row.
		_icon.offset_bottom = -52.0 if stack_caption else -34.0 if portrait_layout else 0.0
	if _traits_box != null:
		_traits_box.visible = false
		_traits_box.custom_minimum_size = Vector2.ZERO if enabled else Vector2(0.0, 48.0)
	if _identity_panel != null:
		_identity_panel.visible = false
		_identity_panel.custom_minimum_size = Vector2.ZERO
	if _name_label != null:
		_name_label.anchor_left = 0.0
		_name_label.anchor_top = 0.61 if _tight_presentation else 0.66 if enabled else 1.0
		_name_label.anchor_right = COMPACT_NAME_SHARE if enabled else 0.76
		_name_label.anchor_bottom = 1.0
		_name_label.offset_left = 4.0 if enabled else 8.0
		_name_label.offset_top = 0.0 if enabled else -23.0
		_name_label.offset_right = -2.0 if enabled else -4.0
		_name_label.offset_bottom = -2.0
		_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_name_label.clip_text = enabled
		_name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS if enabled else TextServer.OVERRUN_NO_TRIMMING
		_name_label.add_theme_font_size_override("font_size", 14 if _tight_presentation else 16 if enabled else 20)
		if portrait_layout:
			_name_label.anchor_top = 1.0
			if stack_caption:
				# Stacked: the name spans the cell instead of holding the 62
				# percent column, which a 97-logical cell cannot fit it into.
				_name_label.anchor_right = 1.0
				_name_label.offset_left = 4.0
				_name_label.offset_right = -4.0
				_name_label.offset_top = -50.0
				_name_label.offset_bottom = -26.0
			else:
				_name_label.offset_top = -32.0
				_name_label.offset_bottom = -6.0
	if _price_label != null:
		_price_label.text = _price_copy()
		_price_label.anchor_left = COMPACT_NAME_SHARE if enabled else 0.76
		_price_label.anchor_top = 0.61 if _tight_presentation else 0.66 if enabled else 1.0
		_price_label.anchor_right = 1.0
		_price_label.anchor_bottom = 1.0
		_price_label.offset_left = 0.0
		_price_label.offset_top = 0.0 if enabled else -23.0
		_price_label.offset_right = -4.0 if enabled else -8.0
		_price_label.offset_bottom = -2.0
		_price_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_price_label.clip_text = enabled
		_price_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS if enabled else TextServer.OVERRUN_NO_TRIMMING
		_price_label.add_theme_font_size_override("font_size", 16 if _tight_presentation else 17 if enabled else 20)
		if portrait_layout:
			_price_label.anchor_top = 1.0
			if stack_caption:
				# Stacked: the price takes the full row under the name. Its 38
				# percent share of a 97-logical cell is 33 logical, and the copy
				# needs 43.
				_price_label.anchor_left = 0.0
				_price_label.offset_left = 4.0
				_price_label.offset_right = -4.0
				_price_label.offset_top = -26.0
				_price_label.offset_bottom = -2.0
			else:
				_price_label.offset_top = -32.0
				_price_label.offset_bottom = -6.0
	set_meta("compact_presentation", enabled)
	set_meta("tight_presentation", _tight_presentation)
	set_meta("portrait_presentation", portrait_layout)
	# The framing follows the icon window, so it is rebuilt after the anchors are
	# settled rather than at texture-assignment time.
	_apply_portrait_crop()
	_apply_caption_band()

## A calm caption strip under the portrait.
##
## The card image used to run straight into a thin name/price row, which made the
## card read as image-heavy and abruptly terminated. This paints one quiet
## recessed band across the caption row, with a single warm hairline as the
## divider between portrait and caption. It is paint only: the band sits behind
## the labels (z 5 against their z 6), ignores the mouse, and carries no content
## margins, so no label's text rect or purchasing behaviour changes.
func _apply_caption_band() -> void:
	if _name_label == null or _price_label == null:
		return
	if _caption_band == null or not is_instance_valid(_caption_band):
		_caption_band = Panel.new()
		_caption_band.name = "ShopCaptionBand"
		_caption_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_caption_band.show_behind_parent = false
		_caption_band.z_index = 5
		add_child(_caption_band)
		_caption_band.add_theme_stylebox_override("panel", GothicUIAssets.quiet_iron_panel_style(
			Color(0.012, 0.010, 0.014, 0.78), Color(0.42, 0.35, 0.25, 0.45)
		))
		_caption_band.set_meta("caption_band", true)
	_caption_band.anchor_left = minf(_name_label.anchor_left, _price_label.anchor_left)
	_caption_band.anchor_right = maxf(_name_label.anchor_right, _price_label.anchor_right)
	_caption_band.anchor_top = _name_label.anchor_top
	_caption_band.anchor_bottom = 1.0
	# Paint-only band, and it stays inside the card it belongs to: the shared
	# caption row already spans the card, so a negative/positive overhang only
	# painted 3px past the card's own edges and overflowed its parent.
	_caption_band.offset_left = 0.0
	_caption_band.offset_right = 0.0
	_caption_band.offset_top = _name_label.offset_top - 3.0
	_caption_band.offset_bottom = -1.0

## Present the shop image as a portrait over the board sprite.
##
## Board art is a full figure, so a fixed top band turns wide poses, staffs and
## shields into clipped bodies and gives every card a different focal scale.
## `UnitArtPresentation.portrait_region` measures this sprite's own alpha profile
## and returns a head-and-shoulder window that never cuts the head, keeps a wide
## body or weapon readable, and is shaped like the card's own icon window so the
## source is not stretched. Dedicated shop art is authored for the card and is
## used uncropped, exactly as before.
##
## The window is read from the icon's laid-out rect, and a card is normally
## hydrated before its container has given it that rect, so the crop measured at
## assignment time belongs to whatever transient size the layout was in. Because
## the window is measured *for* that aspect, a stale one stays letterboxed inside
## the settled rect instead of filling it. The rect is therefore re-measured on
## every icon resize (see `_wire_portrait_refresh`) and rebuilt only when the
## measured window actually changed.
func _apply_portrait_crop() -> void:
	if _icon == null:
		return
	var texture: Texture2D = _unit_texture
	if texture == null:
		return
	if not _uses_board_art:
		# Dedicated shop art is authored for the card and is used uncropped.
		_forget_portrait_crop()
		_icon.texture = texture
		UnitArtPresentation.apply_to(_icon, UnitArtPresentation.SURFACE_PORTRAIT)
		return
	var frame_aspect: float = _icon_frame_aspect()
	var region: Rect2 = UnitArtPresentation.portrait_region(texture, frame_aspect)
	if region.size.x <= 0.0 or region.size.y <= 0.0:
		_forget_portrait_crop()
		_icon.texture = texture
		UnitArtPresentation.apply_to(_icon, UnitArtPresentation.SURFACE_PORTRAIT)
		return
	if _portrait_atlas != null and _portrait_source == texture and _icon.texture == _portrait_atlas and _portrait_atlas.region.is_equal_approx(region):
		# Same window, same source, and the node still shows this atlas: the
		# re-layout only needs the metadata to stay truthful.
		_publish_portrait_crop(region, frame_aspect)
		return
	var portrait: AtlasTexture = AtlasTexture.new()
	# Prepared sampling source under the same region: the crop and filter_clip are
	# unchanged, only the atlas carries a mip chain.
	portrait.atlas = UnitArtPresentation.prepared_texture(texture)
	portrait.region = region
	portrait.filter_clip = true
	_portrait_source = texture
	_portrait_atlas = portrait
	_icon.texture = portrait
	_publish_portrait_crop(region, frame_aspect)
	# Presentation follows the assignment, so it holds whenever the card is
	# styled: the material, the prepared sampling source and the mipmap filter all
	# apply to the texture that was just set.
	UnitArtPresentation.apply_to(_icon, UnitArtPresentation.SURFACE_PORTRAIT)

## Re-measure the window whenever the icon's own rect moves. A container pass can
## resize a child more than once before it settles, so the re-measure is
## coalesced and deferred: one measurement per settled rect, read after the
## layout of the frame that moved it.
func _wire_portrait_refresh() -> void:
	if _icon == null:
		return
	if not _icon.resized.is_connected(Callable(self, "_queue_portrait_refresh")):
		_icon.resized.connect(_queue_portrait_refresh)

func _queue_portrait_refresh() -> void:
	if _portrait_refresh_queued:
		return
	_portrait_refresh_queued = true
	call_deferred("_refresh_portrait_crop")

func _refresh_portrait_crop() -> void:
	_portrait_refresh_queued = false
	if not is_inside_tree():
		return
	_apply_portrait_crop()

## The capture tooling reads these two, so they report the window the card is
## actually using rather than the one it happened to be built with. The cached
## values are the comparison, so an unchanged window is not rewritten.
func _publish_portrait_crop(region: Rect2, frame_aspect: float) -> void:
	if not is_equal_approx(_portrait_frame_aspect, frame_aspect):
		_portrait_frame_aspect = frame_aspect
		set_meta("shop_portrait_frame_aspect", frame_aspect)
	if not _portrait_region.is_equal_approx(region):
		_portrait_region = region
		set_meta("shop_portrait_region", region)

## Used when this card shows no crop at all: dedicated shop art or an empty
## region. The metadata is cleared rather than left describing a window the card
## no longer draws.
func _forget_portrait_crop() -> void:
	_portrait_source = null
	_portrait_region = Rect2()
	_portrait_frame_aspect = 0.0
	_portrait_atlas = null
	if has_meta("shop_portrait_region"):
		remove_meta("shop_portrait_region")
	if has_meta("shop_portrait_frame_aspect"):
		remove_meta("shop_portrait_frame_aspect")

## Aspect of the icon window the crop has to fill. The live rect is the authority;
## the card's authored minimum size and the icon anchors are only the provisional
## answer for the frame before the container has laid the card out, so the card
## still draws something sane before `_wire_portrait_refresh` re-measures.
func _icon_frame_aspect() -> float:
	if _icon != null and _icon.size.x > 1.0 and _icon.size.y > 1.0:
		return _icon.size.x / _icon.size.y
	if _icon == null:
		return 1.0
	var frame_width: float = maxf(1.0, custom_minimum_size.x) * maxf(0.05, _icon.anchor_right - _icon.anchor_left)
	var frame_height: float = maxf(1.0, custom_minimum_size.y) * maxf(0.05, _icon.anchor_bottom - _icon.anchor_top) + _icon.offset_bottom
	if frame_height <= 1.0:
		return 1.0
	return frame_width / frame_height

## The shop band's cell height. The composed dock sizes its own taller cell from
## `Composition.shop_card_height` and only reads this for the card's portrait
## tier, so `composed_dock` keeps that presentation intact. Every other tier is a
## budgeted compact cell: the frame-derived heights (108/144/188) were above the
## compact budget on every window the compact tier actually serves.
static func presentation_height(logical_size: Vector2, tight: bool, composed_dock: bool = false) -> float:
	if composed_dock:
		if logical_size.x >= 1500.0 and logical_size.y >= 1000.0:
			return 188.0
		if logical_size.x >= 1400.0 and logical_size.y >= 800.0:
			return 144.0
		if logical_size.x >= 1200.0 and logical_size.y >= 680.0:
			return 108.0
	return TIGHT_CELL_HEIGHT if tight else COMPACT_CELL_HEIGHT

func _price_copy() -> String:
	return BloodBuckets.format_amount(_price_value, _compact_presentation)

func set_affordable(affordable: bool) -> void:
	var ok: bool = bool(affordable)
	var shop_reason: String = String(get_meta("shop_disabled_reason", ""))
	if shop_reason != "":
		disabled = true
	else:
		disabled = not ok
	if _price_label:
		_price_label.modulate = Color(1, 1, 0.8, 0.95) if ok else Color(1, 0.5, 0.5, 0.85)
	set_status_tip("" if ok else "Not enough Blood Reserve for " + BloodBuckets.describe(_price_value))
	_refresh_cursor()

func set_shop_disabled(reason) -> void:
	_disabled_reason = String(reason)
	set_meta("shop_disabled_reason", _disabled_reason)
	disabled = true
	set_status_tip(_disabled_reason)
	modulate = Color(1, 1, 1, 0.6)
	_refresh_cursor()

func set_status_tip(tip_text: String) -> void:
	_status_tip = String(tip_text).strip_edges()
	tooltip_text = ""
	if _hovered:
		_show_tooltip()

func set_slot_index(i: int) -> void:
	slot_index = int(i)

func _set_traits(traits: Array) -> void:
	if _traits_box == null:
		return
	for c in _traits_box.get_children():
		c.queue_free()
	var shown := 0
	for t in traits:
		var trait_id := String(t).strip_edges()
		if trait_id == "":
			continue
		var trait_icon = (TraitIconScene.instantiate() if TraitIconScene else null)
		if trait_icon == null:
			continue
		if trait_icon.has_method("set_trait"):
			trait_icon.call("set_trait", trait_id)
		_traits_box.add_child(trait_icon)
		shown += 1
		if shown >= 3:
			break
	_traits_box.visible = shown > 0

func _set_approach_tags(approaches: Array) -> void:
	if _approach_tags == null:
		return
	for child in _approach_tags.get_children():
		child.queue_free()
	var seen: Dictionary = {}
	var shown := 0
	for approach in approaches:
		var pretty := _prettify_token(String(approach))
		if pretty == "" or seen.has(pretty):
			continue
		seen[pretty] = true
		var label := Label.new()
		label.text = pretty
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.modulate = Color(1, 1, 1, 0.92)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_stylebox_override("normal", _make_tag_style())
		_approach_tags.add_child(label)
		shown += 1
		if shown >= 4:
			break
	_approach_tags.visible = shown > 0

func _build_tooltip_lines(display_role: String, display_goal: String, approaches: Array, alt_goals: Array, traits: Array) -> Array[String]:
	var lines: Array[String] = []
	var trait_text: String = _format_list(traits, 4)
	if trait_text != "":
		lines.append("Traits: %s" % trait_text)
	if display_role != "":
		lines.append("Role: %s" % display_role)
	if display_goal != "":
		lines.append("Goal: %s" % display_goal)
	var approach_text: String = _format_list(approaches, 4)
	if approach_text != "":
		lines.append("Approaches: %s" % approach_text)
	var alt_text: String = _format_list(alt_goals, 3)
	if alt_text != "":
		lines.append("Alt Goals: %s" % alt_text)
	var preview_unit: Unit = UnitFactory.spawn_at_level(offer_id, _package_level) if offer_id.strip_edges() != "" else null
	var attack_text: String = _format_attack_info(preview_unit)
	if attack_text != "":
		lines.append(attack_text)
	var attack_targeting_text: String = UnitTargetingText.attack_targeting_line(preview_unit)
	if attack_targeting_text != "":
		lines.append(attack_targeting_text)
	var ability_text: String = _format_ability_info(preview_unit)
	if ability_text != "":
		lines.append(ability_text)
	var ability_targeting_text: String = UnitTargetingText.ability_targeting_line(preview_unit)
	if ability_targeting_text != "":
		lines.append(ability_targeting_text)
	return lines

func _ensure_tooltip_details() -> void:
	if _tooltip_details_built:
		return
	_tooltip_details_built = true
	var capital_lines: Array[String] = _tooltip_lines.duplicate()
	_tooltip_lines = _build_tooltip_lines(
		String(_tooltip_detail_context.get("display_role", "")),
		String(_tooltip_detail_context.get("display_goal", "")),
		_coerce_array(_tooltip_detail_context.get("approaches", [])),
		_coerce_array(_tooltip_detail_context.get("alt_goals", [])),
		_coerce_array(_tooltip_detail_context.get("traits", []))
	)
	for index: int in range(capital_lines.size() - 1, -1, -1):
		_tooltip_lines.push_front(capital_lines[index])
	set_meta("tooltip_detail_state", "resolved")

func _format_attack_info(unit: Unit) -> String:
	if unit == null:
		return ""
	var attack_speed: float = max(0.01, float(unit.attack_speed))
	var attack_period: float = 1.0 / attack_speed
	var parts: PackedStringArray = PackedStringArray()
	parts.append("%d damage" % int(round(unit.attack_damage)))
	parts.append("every %.1fs" % attack_period)
	parts.append("range %d" % int(unit.attack_range))
	var crit_chance: int = int(round(float(unit.crit_chance) * 100.0))
	if crit_chance > 0:
		parts.append("%d%% crit for %d%%" % [crit_chance, int(round(float(unit.crit_damage) * 100.0))])
	return "Attack: %s" % " | ".join(parts)

func _format_ability_info(unit: Unit) -> String:
	if unit == null:
		return ""
	var ability_id: String = String(unit.ability_id).strip_edges()
	if ability_id == "":
		return ""
	var ability_def: AbilityDef = AbilityCatalog.get_def(ability_id)
	if ability_def == null:
		return "Ability: %s" % _prettify_token(ability_id)
	var ability_name: String = String(ability_def.name).strip_edges()
	if ability_name == "":
		ability_name = _prettify_token(ability_id)
	var prefix: String = "Ability: %s" % ability_name
	if int(ability_def.base_cost) > 0:
		prefix += " (%d mana)" % int(ability_def.base_cost)
	var description: String = String(ability_def.description).strip_edges()
	if description != "":
		return "%s - %s" % [prefix, description]
	return prefix

func _make_tag_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.046, 0.043, 0.050, 0.96)
	sb.border_color = Color(0.36, 0.28, 0.22, 0.86)
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_right = 6
	sb.corner_radius_bottom_left = 6
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2
	return sb

func _apply_static_style() -> void:
	pivot_offset = size * 0.5
	tooltip_text = ""
	var viewport_size: Vector2 = get_viewport_rect().size
	var ui_scale: float = clampf(UserSettingsScript.get_ui_scale(), UserSettingsScript.MIN_UI_SCALE, UserSettingsScript.MAX_UI_SCALE)
	var effective_size: Vector2 = _effective_ui_viewport_size(viewport_size)
	var compact: bool = effective_size.y <= 1080.0 or effective_size.x <= 1400.0
	var tight_compact: bool = effective_size.y <= 520.0 or effective_size.x <= 1100.0 or (ui_scale >= 1.25 and effective_size.y <= 720.0)
	custom_minimum_size = Vector2(120.0, 54.0) if tight_compact else Vector2(132.0, 80.0) if compact else Vector2(150.0, 122.0)
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	set_meta("shop_safe_bottom_gutter", 2.0 if tight_compact else 6.0 if compact else 16.0)
	add_theme_stylebox_override("normal", _make_card_style(false, false))
	add_theme_stylebox_override("hover", _make_card_style(false, true))
	add_theme_stylebox_override("pressed", _make_card_style(true, true))
	add_theme_stylebox_override("hover_pressed", _make_card_style(true, true))
	add_theme_stylebox_override("disabled", _make_card_style(false, false, true))
	add_theme_stylebox_override("focus", _make_card_focus_style())
	add_theme_color_override("font_disabled_color", Color(0.74, 0.67, 0.56, 0.92))
	if _border_gradient != null:
		_border_gradient.visible = false
	if _bottom_gradient != null:
		_bottom_gradient.visible = false
	if _icon:
		_icon.z_index = 2
		# Portrait presence now comes from the shared character exposure pass, so
		# the resting tint stays neutral instead of warming the shipped art.
		_icon.modulate = Color.WHITE
		UnitArtPresentation.apply_to(_icon, UnitArtPresentation.SURFACE_PORTRAIT)
		_icon.anchor_left = 0.12
		_icon.anchor_top = 0.21
		_icon.anchor_right = 0.88
		_icon.anchor_bottom = 0.78
		_icon.offset_left = 0.0
		_icon.offset_top = 0.0
		_icon.offset_right = 0.0
		_icon.offset_bottom = 0.0
	if _traits_box:
		_traits_box.z_index = 4
		_traits_box.visible = false
	if _identity_panel:
		_identity_panel.z_index = 5
		_identity_panel.anchor_left = 0.06
		_identity_panel.anchor_top = 0.040
		_identity_panel.anchor_right = 0.94
		_identity_panel.anchor_bottom = 0.18
		_identity_panel.offset_left = 0.0
		_identity_panel.offset_top = 0.0
		_identity_panel.offset_right = 0.0
		_identity_panel.offset_bottom = 0.0
	if _legacy_role_label:
		_legacy_role_label.visible = false
	if _role_badge:
		_role_badge.add_theme_font_size_override("font_size", 16)
		VisualTypeSystem.set_gameplay_name(_role_badge)
		_role_badge.add_theme_color_override("font_color", COLOR_GOLD)
		_role_badge.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.70))
		_role_badge.add_theme_constant_override("outline_size", 1)
	if _goal_label:
		_goal_label.add_theme_color_override("font_color", COLOR_MUTED)
	if _name_label:
		_name_label.z_index = 6
		_name_label.add_theme_font_size_override("font_size", 18)
		# The card presents a character, so the name is a name: regular utility
		# weight rather than the display face, which was outweighing the art.
		VisualTypeSystem.set_gameplay_name(_name_label)
		_name_label.add_theme_color_override("font_color", COLOR_TEXT)
		_name_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.82))
		_name_label.add_theme_constant_override("outline_size", 1)
	if _price_label:
		_price_label.z_index = 6
		# Price stays a value, but in a duller gold at the caption's own size so it
		# reads second to the name instead of competing with it.
		_price_label.add_theme_font_size_override("font_size", 18)
		# Restrained numeric: the utility face at bold weight, not condensed
		# impact lettering competing with the price of five cards in a row.
		VisualTypeSystem.set_gameplay_numeric(_price_label)
		_price_label.add_theme_color_override("font_color", Color(0.86, 0.70, 0.44, 1.0))
		_price_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.82))
		_price_label.add_theme_constant_override("outline_size", 1)
	set_compact_presentation(compact, tight_compact)

func _effective_ui_viewport_size(viewport_size: Vector2) -> Vector2:
	return viewport_size

func _make_card_style(pressed_state: bool, highlighted: bool, disabled_state: bool = false) -> StyleBox:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = COLOR_PANEL
	style.border_color = COLOR_IRON
	if highlighted:
		style.bg_color = Color(0.092, 0.054, 0.062, 0.99)
		style.border_color = COLOR_GOLD
	if pressed_state:
		style.bg_color = Color(0.13, 0.026, 0.040, 0.98)
		style.border_color = COLOR_BLOOD
	if disabled_state:
		style.bg_color = Color(0.038, 0.032, 0.040, 0.96)
		style.border_color = Color(0.33, 0.29, 0.29, 0.88)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 0
	style.corner_radius_top_right = 0
	style.corner_radius_bottom_right = 0
	style.corner_radius_bottom_left = 0
	style.shadow_size = 8 if highlighted else 3
	style.shadow_color = Color(0.58, 0.18, 0.060, 0.30) if highlighted else Color(0.0, 0.0, 0.0, 0.46)
	var tint: Color = Color(0.53, 0.53, 0.53) if disabled_state else Color(0.78, 0.73, 0.68) if pressed_state else Color(1.18, 1.12, 1.04) if highlighted else Color.WHITE
	return GothicUIAssets.style_or_fallback(GothicUIAssets.shop_card_style(tint), style)

func _make_card_focus_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	style.border_color = COLOR_GOLD
	style.set_border_width_all(2)
	style.expand_margin_left = 2.0
	style.expand_margin_top = 2.0
	style.expand_margin_right = 2.0
	style.expand_margin_bottom = 2.0
	return style

func _wire_hover() -> void:
	if not is_connected("mouse_entered", Callable(self, "_on_hover_entered")):
		mouse_entered.connect(_on_hover_entered)
	if not is_connected("mouse_exited", Callable(self, "_on_hover_exited")):
		mouse_exited.connect(_on_hover_exited)
	if not is_connected("gui_input", Callable(self, "_on_hover_gui_input")):
		gui_input.connect(_on_hover_gui_input)
	if not is_connected("resized", Callable(self, "_sync_pivot")):
		resized.connect(_sync_pivot)
	_sync_pivot()

func _sync_pivot() -> void:
	pivot_offset = size * 0.5
	# The icon is anchored to this card, so a card resize is also a portrait-window
	# resize; queueing here covers the pass where the icon's own signal is still
	# one layout step behind.
	_queue_portrait_refresh()

func _on_hover_entered() -> void:
	_hovered = true
	_apply_hover_motion(true)
	_show_tooltip()

func _on_hover_exited() -> void:
	_hovered = false
	_apply_hover_motion(false)
	_clear_tooltip()

func _on_hover_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and _tooltip != null and is_instance_valid(_tooltip):
		var viewport: Viewport = get_viewport()
		if viewport != null:
			_move_tooltip(viewport.get_mouse_position())

func _apply_hover_motion(active: bool) -> void:
	if _hover_tween != null and is_instance_valid(_hover_tween):
		_hover_tween.kill()
	_hover_tween = null
	scale = Vector2.ONE
	var highlight: bool = active and not disabled
	z_index = 20 if highlight else 0
	add_theme_stylebox_override("normal", _make_card_style(false, highlight))
	add_theme_stylebox_override("hover", _make_card_style(false, highlight))
	add_theme_stylebox_override("focus", _make_card_focus_style())
	if highlight:
		if _icon != null:
			_icon.modulate = Color(1.12, 1.10, 1.07, 1.0)
	else:
		if _icon != null:
			_icon.modulate = Color.WHITE

## Full-detail access for the composed dock.
##
## `combat_view._apply_dock_shop_cells` drives this card's compact portrait
## layout at full HD, but that layout is a visual choice, not a space
## constraint: the dock has room for the real detail panel. The dock already
## publishes `composed_dock_cell_size` on its ShopGrid, so the card uses that
## existing marker to tell "composed layout" apart from a genuinely small
## compact tier. The dock runs at small tiers too, so the marker alone is not
## enough: the cell the composition chose must be portrait-tall (the same
## threshold this card uses for its portrait layout) and the viewport must be
## wide enough to host the panel beside the purchase targets. Keep this marker
## coordinated with the composition worker.
func _full_detail_tooltip_allowed() -> bool:
	if not _compact_presentation:
		return true
	var dock: Control = _composed_dock_host()
	if dock == null:
		return false
	var cell_size: Vector2 = dock.get_meta("composed_dock_cell_size", Vector2.ZERO) as Vector2
	if cell_size.y < COMPOSED_DOCK_DETAIL_MIN_CELL_HEIGHT:
		return false
	var viewport: Viewport = get_viewport()
	if viewport == null:
		return false
	return viewport.get_visible_rect().size.x >= TOOLTIP_WIDTH + TOOLTIP_EDGE_PADDING * 2.0

func _composed_dock_host() -> Control:
	var context: Node = get_parent()
	while context != null:
		var control: Control = context as Control
		if control != null and String(control.name) == "ShopGrid" and control.has_meta("composed_dock_cell_size"):
			return control
		context = context.get_parent()
	return null

func _show_tooltip() -> void:
	_clear_tooltip()
	set_meta("tooltip_suppressed_for_compact", false)
	if not is_inside_tree():
		return
	_clear_global_tooltip_layers()
	_tooltip_full_detail = _full_detail_tooltip_allowed()
	if not _tooltip_full_detail:
		set_meta("tooltip_suppressed_for_compact", true)
		set_meta("compact_information_access", "card_summary_and_deliberate_purchase")
		return
	var lines: Array[String] = _current_tooltip_lines()
	if _tooltip_title.strip_edges() == "" and lines.is_empty():
		return
	var tree: SceneTree = get_tree()
	if tree == null or tree.root == null:
		return
	var tooltip: PanelContainer = PanelContainer.new()
	tooltip.name = "ShopCardTooltip"
	tooltip.top_level = true
	tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip.clip_contents = not _tooltip_full_detail
	tooltip.z_index = 950
	tooltip.set_meta("source_card_instance_id", get_instance_id())
	tooltip.set_meta("source_offer_id", offer_id)
	tooltip.set_meta("presentation_mode", "cursor_detail" if _tooltip_full_detail else "pinned_shop_band")
	tooltip.set_meta("non_obstructive_region", "viewport_edge" if _tooltip_full_detail else "shop_grid_band")
	tooltip.set_meta("information_access", "fully_expanded" if _tooltip_full_detail else "vertical_scroll_complete")
	tooltip.set_meta("detail_line_count", lines.size() + 2)
	if not _tooltip_full_detail:
		var detail_rect: Rect2 = _shop_band_rect()
		var source_rect: Rect2 = get_global_rect()
		var source_remains_visible: bool = not detail_rect.intersects(source_rect)
		var opposite_side_anchor: String = "right_of_source" if detail_rect.position.x >= source_rect.end.x else "left_of_source"
		tooltip.set_meta("source_card_remains_visible", source_remains_visible)
		tooltip.set_meta("opposite_side_anchor", opposite_side_anchor)
		tooltip.set_meta("shop_band_width_ratio", detail_rect.size.x / maxf(1.0, _shop_grid_rect().size.x))
		set_meta("tooltip_source_remains_visible", source_remains_visible)
		set_meta("tooltip_opposite_side_anchor", opposite_side_anchor)
	tooltip.custom_minimum_size.x = _tooltip_panel_width()
	tooltip.add_theme_stylebox_override("panel", _make_tooltip_style())
	var box: VBoxContainer = VBoxContainer.new()
	box.name = "Rows"
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 5 if _tooltip_full_detail else 2)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not _tooltip_full_detail:
		var scroll: ScrollContainer = ScrollContainer.new()
		scroll.name = "DetailScroll"
		scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tooltip.add_child(scroll)
		scroll.add_child(box)
		_tooltip_scroll = scroll
		_add_tooltip_label(box, "SHOP DETAIL // WHEEL FOR FULL RECORD", 14, Color(0.96, 0.54, 0.28, 1.0))
	else:
		tooltip.add_child(box)
	if _tooltip_title.strip_edges() != "":
		_add_tooltip_label(box, _tooltip_title, 22, COLOR_GOLD)
	if _tooltip_subtitle.strip_edges() != "":
		_add_tooltip_label(box, _tooltip_subtitle, 17, Color(0.80, 0.75, 0.68, 1.0))
	for line: String in lines:
		var color: Color = Color(0.92, 0.76, 0.58, 1.0) if line == _status_tip and _status_tip != "" else COLOR_TEXT
		_add_tooltip_label(box, line, 18, color)
	var tooltip_layer: CanvasLayer = CanvasLayer.new()
	tooltip_layer.name = "ShopCardTooltipLayer"
	tooltip_layer.layer = 400
	tree.root.add_child(tooltip_layer)
	tooltip_layer.add_child(tooltip)
	_tooltip_layer = tooltip_layer
	_tooltip = tooltip
	_sync_tooltip_size()
	var viewport: Viewport = get_viewport()
	if viewport != null:
		_move_tooltip(viewport.get_mouse_position())

func _clear_global_tooltip_layers() -> void:
	if not is_inside_tree():
		return
	var tree: SceneTree = get_tree()
	if tree == null or tree.root == null:
		return
	for raw_child: Node in tree.root.get_children():
		if String(raw_child.name) != "ShopCardTooltipLayer":
			continue
		tree.root.remove_child(raw_child)
		raw_child.free()

func _current_tooltip_lines() -> Array[String]:
	_ensure_tooltip_details()
	var lines: Array[String] = []
	if _status_tip != "":
		lines.append(_status_tip)
	for line: String in _tooltip_lines:
		if line.strip_edges() != "":
			lines.append(line)
	return lines

func _add_tooltip_label(parent: VBoxContainer, label_text: String, font_size: int, color: Color) -> void:
	var label: Label = Label.new()
	label.text = String(label_text)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = TOOLTIP_WIDTH - 24.0 if _tooltip_full_detail else 0.0
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var presentation_font_size: int = font_size if _tooltip_full_detail else mini(font_size, 15)
	label.add_theme_font_size_override("font_size", presentation_font_size)
	if presentation_font_size >= 22:
		VisualTypeSystem.set_action(label)
	else:
		VisualTypeSystem.set_utility(label)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.75))
	label.add_theme_constant_override("outline_size", 1)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)

func _move_tooltip(viewport_pos: Vector2) -> void:
	if _tooltip == null or not is_instance_valid(_tooltip):
		return
	_sync_tooltip_size()
	if not _tooltip_full_detail:
		_tooltip.global_position = _shop_band_rect().position
		return
	_tooltip.global_position = _clamped_tooltip_position(viewport_pos + TOOLTIP_CURSOR_OFFSET)

func _sync_tooltip_size() -> void:
	if _tooltip == null or not is_instance_valid(_tooltip):
		return
	if not _tooltip_full_detail:
		var band_rect: Rect2 = _shop_band_rect()
		var pinned_height: float = band_rect.size.y
		_tooltip.custom_minimum_size = Vector2(band_rect.size.x, pinned_height)
		_tooltip.size = Vector2(band_rect.size.x, pinned_height)
		if _tooltip_scroll != null and is_instance_valid(_tooltip_scroll):
			var scroll_height: float = maxf(24.0, pinned_height - 34.0)
			_tooltip_scroll.custom_minimum_size = Vector2(0.0, scroll_height)
			_tooltip_scroll.size = Vector2(band_rect.size.x, scroll_height)
		return
	_tooltip.size.x = TOOLTIP_WIDTH
	_tooltip.size.y = max(84.0, _tooltip.get_combined_minimum_size().y)

func _tooltip_panel_width() -> float:
	if _tooltip_full_detail:
		return TOOLTIP_WIDTH
	return _shop_band_rect().size.x

func _shop_band_rect() -> Rect2:
	var shop_rect: Rect2 = _shop_grid_rect()
	var source_rect: Rect2 = get_global_rect()
	var gap: float = 8.0
	var source_on_left: bool = source_rect.get_center().x <= shop_rect.get_center().x
	var target_width: float = shop_rect.size.x * 0.58
	var available_width: float = shop_rect.end.x - source_rect.end.x - gap if source_on_left else source_rect.position.x - shop_rect.position.x - gap
	var drawer_width: float = minf(target_width, maxf(shop_rect.size.x * 0.42, available_width))
	var drawer_x: float = shop_rect.end.x - drawer_width if source_on_left else shop_rect.position.x
	var drawer_rect: Rect2 = Rect2(Vector2(drawer_x, shop_rect.position.y), Vector2(drawer_width, shop_rect.size.y))
	if drawer_rect.intersects(source_rect):
		if source_on_left:
			drawer_rect.position.x = source_rect.end.x + gap
			drawer_rect.size.x = maxf(1.0, shop_rect.end.x - drawer_rect.position.x)
		else:
			drawer_rect.size.x = maxf(1.0, source_rect.position.x - gap - shop_rect.position.x)
	return drawer_rect

func _shop_grid_rect() -> Rect2:
	var context_control: Control = self
	while context_control != null:
		if String(context_control.name) == "ShopGrid":
			var shop_rect: Rect2 = context_control.get_global_rect()
			if shop_rect.size.x > 1.0 and shop_rect.size.y > 1.0:
				return shop_rect
		context_control = context_control.get_parent() as Control
	var viewport: Viewport = get_viewport()
	var viewport_rect: Rect2 = viewport.get_visible_rect() if viewport != null else Rect2(Vector2.ZERO, Vector2(1280.0, 720.0))
	var card_rect: Rect2 = get_global_rect()
	return Rect2(
		Vector2(TOOLTIP_EDGE_PADDING, card_rect.position.y),
		Vector2(maxf(320.0, viewport_rect.size.x - TOOLTIP_EDGE_PADDING * 2.0), maxf(COMPACT_TOOLTIP_MIN_HEIGHT, card_rect.size.y))
	)

func _clamped_tooltip_position(raw_position: Vector2) -> Vector2:
	if _tooltip == null or not is_instance_valid(_tooltip):
		return raw_position
	var viewport: Viewport = get_viewport()
	if viewport == null:
		return raw_position
	var viewport_size: Vector2 = viewport.get_visible_rect().size
	var card_rect: Rect2 = get_global_rect()
	var context_rect: Rect2 = card_rect
	var context_control: Control = get_parent() as Control
	if context_control != null:
		context_rect = context_control.get_global_rect()
	var above_position: Vector2 = Vector2(
		card_rect.get_center().x - _tooltip.size.x * 0.5,
		context_rect.position.y - _tooltip.size.y - TOOLTIP_EDGE_PADDING
	)
	var next_position: Vector2 = above_position if above_position.y >= TOOLTIP_EDGE_PADDING else raw_position
	if above_position.y < TOOLTIP_EDGE_PADDING:
		var below_position: Vector2 = Vector2(
			card_rect.get_center().x - _tooltip.size.x * 0.5,
			context_rect.end.y + TOOLTIP_EDGE_PADDING
		)
		var right_position: Vector2 = Vector2(context_rect.end.x + TOOLTIP_EDGE_PADDING, card_rect.position.y)
		var left_position: Vector2 = Vector2(context_rect.position.x - _tooltip.size.x - TOOLTIP_EDGE_PADDING, card_rect.position.y)
		if below_position.y + _tooltip.size.y + TOOLTIP_EDGE_PADDING <= viewport_size.y:
			next_position = below_position
		elif right_position.x + _tooltip.size.x + TOOLTIP_EDGE_PADDING <= viewport_size.x:
			next_position = right_position
		elif left_position.x >= TOOLTIP_EDGE_PADDING:
			next_position = left_position
		else:
			next_position = raw_position
	if next_position.x + _tooltip.size.x + TOOLTIP_EDGE_PADDING > viewport_size.x:
		next_position.x = viewport_size.x - _tooltip.size.x - TOOLTIP_EDGE_PADDING
	if next_position.y + _tooltip.size.y + TOOLTIP_EDGE_PADDING > viewport_size.y:
		next_position.y = viewport_size.y - _tooltip.size.y - TOOLTIP_EDGE_PADDING
	if next_position.x < TOOLTIP_EDGE_PADDING:
		next_position.x = TOOLTIP_EDGE_PADDING
	if next_position.y < TOOLTIP_EDGE_PADDING:
		next_position.y = TOOLTIP_EDGE_PADDING
	return next_position

func _make_tooltip_style() -> StyleBox:
	# The hover panel is a transient interaction surface, so it shares the
	# permanent panel vocabulary: quiet recessed iron behind one thin aged-brass
	# rim, with the content insets this layout already assumes. The previous
	# hardcore utility_tooltip texture framed it with a thick pale rounded border
	# that read as a different interface from the rails it opened over.
	return GothicUIAssets.tooltip_panel_style()

func _clear_tooltip() -> void:
	if _tooltip != null and is_instance_valid(_tooltip):
		var tooltip_parent: Node = _tooltip.get_parent()
		if tooltip_parent != null:
			tooltip_parent.remove_child(_tooltip)
		_tooltip.free()
	_tooltip = null
	_tooltip_scroll = null
	if _tooltip_layer != null and is_instance_valid(_tooltip_layer):
		var layer_parent: Node = _tooltip_layer.get_parent()
		if layer_parent != null:
			layer_parent.remove_child(_tooltip_layer)
		_tooltip_layer.free()
	_tooltip_layer = null

func clear_transient_state() -> void:
	_hovered = false
	_apply_hover_motion(false)
	_clear_tooltip()

func _exit_tree() -> void:
	if _hover_tween != null and is_instance_valid(_hover_tween):
		_hover_tween.kill()
	_hover_tween = null
	_clear_tooltip()

func _refresh_cursor() -> void:
	mouse_default_cursor_shape = Control.CURSOR_ARROW if disabled else Control.CURSOR_POINTING_HAND

func _coerce_array(values) -> Array:
	var out: Array = []
	if values is Array:
		for v in values:
			out.append(String(v))
	elif values is PackedStringArray:
		for v in values:
			out.append(String(v))
	elif typeof(values) == TYPE_STRING:
		out.append(String(values))
	return out

func _format_role(role_value) -> String:
	var role_text := String(role_value).replace("_", " ").strip_edges()
	if role_text == "":
		return ""
	var parts := role_text.split(" ", false)
	var pretty := PackedStringArray()
	for part in parts:
		if part == "":
			continue
		pretty.append(part.capitalize())
	if pretty.size() == 0:
		return role_text.capitalize()
	return " ".join(pretty)

func _format_goal(goal_value) -> String:
	var goal_text := String(goal_value).strip_edges()
	if goal_text == "":
		return ""
	var parts := goal_text.split(".", false, 2)
	if parts.size() >= 2:
		var role_part := _format_role(parts[0])
		var goal_part := _prettify_token(parts[1])
		if role_part != "":
			if goal_part != "":
				return "%s - %s" % [role_part, goal_part]
			return role_part
	return _prettify_token(goal_text)

func _format_list(values: Array, limit: int) -> String:
	if values == null or values.is_empty():
		return ""
	var formatted := PackedStringArray()
	for i in range(min(limit, values.size())):
		var token := _prettify_token(String(values[i]))
		if token != "":
			formatted.append(token)
	if values.size() > limit:
		formatted.append("+")
	return ", ".join(formatted)

func _prettify_token(value: String) -> String:
	var token_text := String(value).strip_edges().to_lower()
	if token_text == "":
		return ""
	var parts := token_text.split("_", false)
	var pretty := PackedStringArray()
	for part in parts:
		if part == "":
			continue
		pretty.append(part.capitalize())
	return " ".join(pretty)

signal clicked(slot_index: int)

func _on_pressed() -> void:
	emit_signal("clicked", int(slot_index))
