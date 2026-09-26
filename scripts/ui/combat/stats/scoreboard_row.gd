extends Control
class_name ScoreboardRow

const TextureUtils := preload("res://scripts/util/texture_utils.gd")
const VisualTypeSystem: GDScript = preload("res://scripts/ui/visual_type_system.gd")
const UnitArtPresentation: GDScript = preload("res://scripts/ui/unit_art_presentation.gd")

# Support-rail material: a recessed row with a thin team accent, a small
# portrait, the authored mixed-case name and its value. The former solid box
# with a repeated bold team prefix is gone; the rail chrome and the row tooltip
# own the team identity now.
const COLOR_ROW_BG: Color = Color(0.020, 0.018, 0.022, 0.52)
const COLOR_ROW_BG_HOVER: Color = Color(0.048, 0.034, 0.026, 0.72)
const COLOR_ACCENT_PLAYER: Color = Color(0.62, 0.46, 0.24, 0.92)
const COLOR_ACCENT_ENEMY: Color = Color(0.55, 0.090, 0.115, 0.92)
const COLOR_NAME: Color = Color(0.92, 0.89, 0.83, 1.0)
const COLOR_NAME_HOVER: Color = Color(1.0, 0.95, 0.87, 1.0)
const COLOR_VALUE: Color = Color(0.86, 0.76, 0.60, 1.0)
const COLOR_VALUE_HOVER: Color = Color(1.0, 0.86, 0.63, 1.0)
const COLOR_BAR_PLAYER: Color = Color(0.60, 0.095, 0.105, 0.92)
const COLOR_BAR_ENEMY: Color = Color(0.44, 0.045, 0.065, 0.90)
const COLOR_BAR_TRACK: Color = Color(0.010, 0.009, 0.012, 0.70)
const COLOR_WELL_RULE: Color = Color(0.34, 0.29, 0.26, 0.52)
const COLOR_PORTRAIT_EDGE: Color = Color(0.30, 0.26, 0.23, 0.62)
## Below this compact row width the inline portrait costs more than it gives:
## the authored full name is the record, so the portrait yields to it.
const COMPACT_PORTRAIT_MIN_WIDTH: float = 160.0
## Below this width the rail is a dense ledger: shorter rows, smaller portrait,
## tighter separations. The rail's real width decides, not the UI tier or the
## moment the row happened to be created.
const DENSE_ROW_WIDTH: float = 190.0

var team: String = "player"
var index: int = -1
var unit_ref: Unit = null
var value: float = 0.0
var share: float = 0.0
var metric_key: String = "damage"
var display_name: String = ""

@onready var portrait: TextureRect = $"HBox/Portrait"
@onready var bar_bg: ColorRect = $"HBox/Content/BarBG"
@onready var bar_fill: ColorRect = $"HBox/Content/BarFill"
@onready var name_label: Label = $"HBox/Content/Name"
@onready var value_label: Label = $"HBox/Content/Value"
@onready var content_box: Control = $"HBox/Content"
@onready var hbox: HBoxContainer = $"HBox"

## Identity type ladder. The rail tries the complete authored identity - including
## a duplicate discriminator such as "Berebell #2" - at the roomiest size first
## and steps down only as far as the legibility floor before it abbreviates. The
## outer rail is never widened to make a name fit.
const IDENTITY_FONT_SIZE_FLOOR: int = 14
const IDENTITY_FONT_SIZE_DESKTOP: int = 17

var _frame: Panel = null
var _value_well: Panel = null
var _hovered: bool = false
var _record_emphasis: bool = false
var _compact_layout: bool = false
var _compact_identity_font_size: int = 14
var _exact_compact_values: bool = false
var _compact_identity_mode: String = "name_only_team_in_chrome"
var _row_pitch: float = 0.0
var _value_column: float = 0.0
var _portrait_source: Texture2D = null
var _portrait_aspect: float = 0.0
var _fallback_portrait: Texture2D = null
var _chrome_team: String = ""
var _frame_style_idle: StyleBoxFlat = null
var _frame_style_hover: StyleBoxFlat = null
var _well_style: StyleBoxFlat = null
var _portrait_bounds_style: StyleBoxFlat = null

func set_compact_layout(enabled: bool) -> void:
	_compact_layout = enabled
	set_meta("compact_layout", enabled)
	_refresh()

func set_exact_compact_values(enabled: bool) -> void:
	_exact_compact_values = enabled
	set_meta("exact_compact_values", enabled)
	_refresh()

func set_record_emphasis(enabled: bool) -> void:
	_record_emphasis = enabled
	_refresh()

## The rail pushes the ledger's row pitch once it knows its own space and UI
## scale, so one rail is dense at 150 percent and roomier at 100 percent.
func set_row_pitch(pitch: float) -> void:
	var next_pitch: float = maxf(0.0, pitch)
	if is_equal_approx(_row_pitch, next_pitch):
		return
	_row_pitch = next_pitch
	set_meta("row_pitch", next_pitch)
	_refresh()

## The rail shares one numeric column width across its rows so the value rules
## line up down the ledger. 0 leaves the row sizing its own column.
func set_value_column_width(width: float) -> void:
	var next_width: float = maxf(0.0, width)
	if is_equal_approx(_value_column, next_width):
		return
	_value_column = next_width
	set_meta("value_column_width", next_width)
	_refresh()

## The column this row's own readout currently needs, before the rail settles on
## one shared width for the whole ledger.
func requested_value_column_width() -> float:
	return _compact_numeric_well_width()

func refresh_compact_identity() -> void:
	if _compact_layout:
		_update_identity()

func set_row_data(row: Dictionary) -> void:
	team = String(row.get("team", team))
	index = int(row.get("index", index))
	unit_ref = row.get("unit")
	display_name = String(row.get("display_name", ""))
	value = float(row.get("value", 0.0))
	share = clamp(float(row.get("share", 0.0)), 0.0, 1.0)
	metric_key = String(row.get("metric", metric_key))
	_refresh()

func _refresh() -> void:
	_ensure_layout()
	_update_portrait()
	_update_bar()
	_update_identity()
	_apply_visual_style()
	_center_value_label()

func _update_portrait() -> void:
	var tex: Texture2D = null
	if unit_ref != null and String(unit_ref.sprite_path) != "":
		tex = TextureUtils.try_load_texture(unit_ref.sprite_path)
	if tex == null:
		if _fallback_portrait == null:
			_fallback_portrait = TextureUtils.make_circle_texture(Color(0.6, 0.65, 0.75), 32)
		if portrait.texture != _fallback_portrait:
			portrait.texture = _fallback_portrait
		_portrait_source = null
		return
	_apply_portrait_crop(tex)
	_ensure_portrait_bounds()

## The board sprite is a full figure, so shrinking it into the rail produced a
## tiny full-body cutout that read as neither a person nor an icon. The small
## identity marker is instead a framed head-and-upper-body crop taken from the
## shared presentation helper, which measures the sprite's own alpha profile:
## the same source pixels, presented as a portrait. Nothing is redrawn or
## recoloured, and no new identity is introduced.
func _apply_portrait_crop(texture: Texture2D) -> void:
	var frame_aspect: float = _portrait_frame_aspect()
	if _portrait_source == texture and is_equal_approx(_portrait_aspect, frame_aspect) and portrait.texture != null:
		return
	var region: Rect2 = UnitArtPresentation.portrait_region(texture, frame_aspect)
	if region.size.x <= 0.0 or region.size.y <= 0.0:
		portrait.texture = texture
	else:
		var atlas: AtlasTexture = AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = region
		atlas.filter_clip = true
		portrait.texture = atlas
		set_meta("rail_portrait_region", region)
	_portrait_source = texture
	_portrait_aspect = frame_aspect
	UnitArtPresentation.apply_to(portrait, UnitArtPresentation.SURFACE_PORTRAIT)

func _portrait_frame_aspect() -> float:
	var width: float = portrait.size.x if portrait.size.x > 1.0 else portrait.custom_minimum_size.x
	var height: float = portrait.size.y if portrait.size.y > 1.0 else portrait.custom_minimum_size.y
	return maxf(0.75, width) / maxf(0.75, height)

## One quiet recess and a hairline edge so the crop sits in a deliberate small
## portrait bound instead of floating as a cutout. Created once; a stylebox that
## already carries the marker is left alone.
func _ensure_portrait_bounds() -> void:
	if portrait == null:
		return
	var frame: Panel = portrait.get_node_or_null("PortraitBounds") as Panel
	if frame == null:
		frame = Panel.new()
		frame.name = "PortraitBounds"
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.show_behind_parent = true
		portrait.add_child(frame)
		frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if _portrait_bounds_style == null:
		_portrait_bounds_style = _make_portrait_bounds_style()
		_portrait_bounds_style.set_meta("rail_portrait_bounds", true)
	frame.add_theme_stylebox_override("panel", _portrait_bounds_style)

func _make_portrait_bounds_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.012, 0.011, 0.014, 0.62)
	style.border_color = COLOR_PORTRAIT_EDGE
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_right = 2
	style.corner_radius_bottom_left = 2
	return style

func _update_bar() -> void:
	var w: float = max(0.0, float(content_box.size.x if content_box != null else bar_bg.size.x))
	var fill_w: float = w * share
	var band_top: float = 0.72 if _record_emphasis else 0.78
	var band_bottom: float = 0.94 if _record_emphasis else 0.92
	# The share bar is a thin rule under the name, not a full-cell fill. Anchoring
	# the track to the same band as the fill keeps the row quiet.
	if bar_bg != null:
		bar_bg.anchor_left = 0.0
		bar_bg.anchor_right = 1.0
		bar_bg.anchor_top = band_top
		bar_bg.anchor_bottom = band_bottom
		bar_bg.offset_left = 0.0
		bar_bg.offset_right = 0.0
		bar_bg.offset_top = 0.0
		bar_bg.offset_bottom = 0.0
	bar_fill.anchor_left = 0.0
	bar_fill.anchor_right = 0.0
	bar_fill.anchor_top = band_top
	bar_fill.anchor_bottom = band_bottom
	bar_fill.offset_left = 0.0
	bar_fill.offset_right = fill_w
	bar_fill.offset_top = 0.0
	bar_fill.offset_bottom = 0.0
	value_label.text = _format_value(value)
	_center_value_label()

func _update_identity() -> void:
	_apply_compact_portrait_state()
	if name_label == null:
		return
	var unit_name: String = "Unit"
	if display_name.strip_edges() != "":
		unit_name = display_name.strip_edges()
	elif unit_ref != null and String(unit_ref.name).strip_edges() != "":
		unit_name = String(unit_ref.name)
	var team_prefix: String = "FOE" if team == "enemy" else "YOU"
	var rendered_name: String = unit_name
	if not _record_emphasis:
		rendered_name = _fit_identity_name(unit_name, _compact_identity_available_width())
	name_label.text = rendered_name
	# The rail chrome owns the team identity: the "Team Metrics" surface heads
	# your ledger and the enemy ledger has its own control. A row therefore
	# shows the authored name instead of repeating a bold team prefix, while
	# the mapping stays in metadata and in the tooltip.
	name_label.set_meta("compact_identity_source", unit_name)
	name_label.set_meta("compact_identity_lossless", rendered_name == unit_name)
	name_label.set_meta("compact_team_marker", team_prefix)
	name_label.set_meta("compact_identity_font_size", _compact_identity_font_size)
	name_label.set_meta("compact_identity_mode", _compact_identity_mode if _compact_layout else "rail_identity")
	name_label.set_meta("compact_identity_preserves_unit_name", rendered_name == unit_name)
	name_label.set_meta("compact_identity_complete", _compact_layout)
	name_label.tooltip_text = "%s team — %s" % ["Enemy" if team == "enemy" else "Your", unit_name]

func _fit_identity_name(unit_name: String, available_width: float) -> String:
	var font: Font = name_label.get_theme_font("font") if name_label != null else null
	# The rail tries the complete authored identity - including a duplicate
	# discriminator such as "Berebell #2" - at the roomiest size first and steps
	# down to the legibility floor before it abbreviates anything. Everything is
	# measured in the face that is actually drawn, against the rail's own measured
	# column, so the outer rail is never widened to make a name fit.
	var roomiest: int = IDENTITY_FONT_SIZE_FLOOR if _compact_layout else IDENTITY_FONT_SIZE_DESKTOP
	# An unmeasured row has no column yet, so there is nothing to fit against:
	# keep the complete authored identity (with its duplicate discriminator) and
	# let the resize pass step it down once the settled column is known. Only a
	# real measured column may abbreviate a name.
	if available_width <= 0.0:
		_compact_identity_font_size = roomiest
		_compact_identity_mode = "name_only_team_in_chrome" if _compact_layout else "rail_complete_identity"
		return unit_name
	var candidate: int = roomiest
	while candidate >= IDENTITY_FONT_SIZE_FLOOR:
		if available_width > 0.0 and _compact_text_width(unit_name, font, candidate) + 1.0 <= available_width:
			_compact_identity_font_size = candidate
			_compact_identity_mode = "name_only_team_in_chrome" if _compact_layout else "rail_complete_identity"
			return unit_name
		candidate -= 1
	_compact_identity_font_size = IDENTITY_FONT_SIZE_FLOOR
	# The tight rail keeps the identity unambiguous instead of clipping it: the
	# shortened form still starts with the authored name's distinctive prefix.
	_compact_identity_mode = "coded_name_team_in_chrome"
	return _compact_identity_name_for_width(unit_name, available_width, font, _compact_identity_font_size)

func _apply_visual_style() -> void:
	# A compact metric is a record, not decorative microcopy. Keep the row and
	# its identity at an accessibility-safe baseline when the parent rail is
	# widened for maximum-scale planning.
	custom_minimum_size = Vector2(0.0, _row_min_height())
	# A row never stretches and never forces the rail wider than its region; the
	# rail's own width and its scroll viewport own the geometry.
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var player_side: bool = team != "enemy"
	if _frame != null:
		_apply_row_frame_style()
	if bar_bg != null:
		bar_bg.color = COLOR_BAR_TRACK
	if bar_fill != null:
		var fill_color: Color = COLOR_BAR_PLAYER if player_side else COLOR_BAR_ENEMY
		if _hovered:
			fill_color = Color(minf(1.0, fill_color.r + 0.10), minf(1.0, fill_color.g + 0.06), minf(1.0, fill_color.b + 0.05), 1.0)
		bar_fill.color = fill_color
	if name_label != null:
		_apply_identity_font()
		VisualTypeSystem.set_gameplay_name(name_label)
		name_label.add_theme_color_override("font_color", COLOR_NAME_HOVER if _hovered else COLOR_NAME)
	if value_label != null:
		value_label.add_theme_font_size_override("font_size", 15 if _compact_layout else 26 if _record_emphasis else 18)
		VisualTypeSystem.set_gameplay_numeric(value_label)
		value_label.add_theme_color_override("font_color", COLOR_VALUE_HOVER if _hovered else COLOR_VALUE)
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value_label.clip_text = true
		value_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING

## The identity is fitted against the column this row actually settled at, and
## that column is only known once the anchored label has been laid out. A
## resize therefore re-runs the fit and re-applies the chosen size, so a size
## picked against a provisional column can never be left clipping the settled
## one.
func _refit_identity() -> void:
	_update_identity()
	_apply_identity_font()

func _apply_identity_font() -> void:
	if name_label == null:
		return
	name_label.add_theme_font_size_override("font_size", 22 if _record_emphasis else _compact_identity_font_size)

func _compact_identity_available_width() -> float:
	if name_label == null:
		return 72.0
	if name_label.size.x > 1.0:
		# The fit re-runs against this settled column (see `_refit_identity`), so
		# only a hairline guard is needed; a wider reservation would push a
		# complete authored name out of the rail it already fits.
		return maxf(32.0, name_label.size.x - 2.0)
	if content_box != null and content_box.size.x > 1.0:
		return maxf(32.0, content_box.size.x - 60.0)
	if size.x > 1.0:
		return maxf(32.0, size.x - 70.0)
	# The row has not been laid out at all, so no column is known: report an
	# unmeasured width instead of a provisional floor the identity would clip to.
	return 0.0

func _compact_text_width(text: String, font: Font, font_size: int) -> float:
	if font != null:
		return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	return float(text.length() * 8)

func _compact_identity_name(unit_name: String) -> String:
	var clean_name: String = unit_name.strip_edges()
	if clean_name == "":
		return "UNIT"
	if clean_name.length() <= 6:
		return clean_name
	var duplicate_marker: int = clean_name.rfind("#")
	if duplicate_marker > 0:
		var suffix: String = clean_name.substr(duplicate_marker).strip_edges()
		var base_budget: int = maxi(2, 6 - suffix.length())
		return "%s%s" % [clean_name.left(base_budget), suffix]
	var words: PackedStringArray = clean_name.split(" ", false)
	if words.size() > 1:
		var first_code: String = words[0].left(3)
		var final_code: String = words[words.size() - 1].left(2)
		return "%s%s" % [first_code, final_code]
	return "%s%s" % [clean_name.left(4), clean_name.right(2)]

func _compact_identity_name_for_width(unit_name: String, available_width: float, font: Font, font_size: int) -> String:
	var coded_name: String = _compact_identity_name(unit_name)
	if _compact_text_width(coded_name, font, font_size) <= available_width:
		return coded_name
	var duplicate_marker: int = coded_name.rfind("#")
	var suffix: String = coded_name.substr(duplicate_marker) if duplicate_marker > 0 else ""
	var base: String = coded_name.left(duplicate_marker) if duplicate_marker > 0 else coded_name
	while base.length() > 1 and _compact_text_width(base + suffix, font, font_size) > available_width:
		base = base.left(base.length() - 1)
	return base + suffix

func _ensure_layout() -> void:
	if _frame == null:
		_frame = Panel.new()
		_frame.name = "RowFrame"
		_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_frame.show_behind_parent = true
		_frame.z_index = -1
		add_child(_frame)
		_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
		_frame.offset_left = 0.0
		_frame.offset_top = 0.0
		_frame.offset_right = 0.0
		_frame.offset_bottom = 0.0
	if hbox != null:
		hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
		hbox.offset_left = 5.0 if _compact_layout else 12.0 if _record_emphasis else 8.0
		hbox.offset_top = 3.0 if _compact_layout else 8.0 if _record_emphasis else 6.0
		hbox.offset_right = -5.0 if _compact_layout else -12.0 if _record_emphasis else -8.0
		hbox.offset_bottom = -3.0 if _compact_layout else -8.0 if _record_emphasis else -6.0
		hbox.add_theme_constant_override("separation", 4 if _row_dense() else 6 if _compact_layout else 12 if _record_emphasis else 8)
	_apply_compact_portrait_state()
	if content_box != null:
		content_box.custom_minimum_size = Vector2(0.0, _content_min_height())
		_ensure_value_well()
	if name_label != null:
		# Rail rows size their value column from the shared measured column, so a
		# narrower rail (150 percent) hands the identity its real width instead of
		# the desktop rail's fixed insets. Only the loss record keeps its authored
		# record geometry.
		var compact_value_width: float = _compact_numeric_well_width()
		name_label.anchor_left = 0.0
		name_label.anchor_right = 1.0
		name_label.anchor_top = 0.0
		name_label.anchor_bottom = 1.0
		name_label.offset_left = 4.0 if _compact_layout else 16.0 if _record_emphasis else 10.0
		name_label.offset_right = -126.0 if _record_emphasis else -(compact_value_width + 6.0)
		name_label.clip_text = true
		name_label.set_meta("compact_numeric_safety_gap", 6.0)
	if value_label != null:
		var compact_content_width: float = _compact_numeric_content_width()
		var compact_right_inset: float = _compact_numeric_right_inset()
		value_label.anchor_left = 1.0
		value_label.anchor_right = 1.0
		value_label.anchor_top = 0.0
		value_label.anchor_bottom = 1.0
		value_label.offset_left = -116.0 if _record_emphasis else -compact_content_width - compact_right_inset
		value_label.offset_right = -14.0 if _record_emphasis else -compact_right_inset
		value_label.set_meta("compact_numeric_content_width", 0.0 if _record_emphasis else compact_content_width)

## The rail's settled width decides how dense this row is. An unmeasured row
## (width 0) keeps the standard compact density so the first frame is stable.
func _row_dense() -> bool:
	if _row_pitch > 0.0:
		return _row_pitch <= 36.0
	return _compact_layout and size.x > 0.0 and size.x < DENSE_ROW_WIDTH

func _row_min_height() -> float:
	if _record_emphasis:
		return 96.0
	if _row_pitch > 0.0:
		return _row_pitch
	if not _compact_layout:
		return 54.0
	return 36.0 if _row_dense() else 42.0

## The value/name band always leaves the row's own inset free, so a dense row
## cannot push its contents past the rail's clipping edge.
func _content_min_height() -> float:
	if _record_emphasis:
		return 78.0
	return clampf(_row_min_height() - 6.0, 22.0, 42.0)

## The compact rail keeps the portrait while the row is wide enough for the
## authored name beside it, and yields the portrait when the name is the only
## thing that must stay complete.
func _apply_compact_portrait_state() -> void:
	if portrait == null:
		return
	if not _compact_layout:
		portrait.visible = true
		if _record_emphasis:
			portrait.custom_minimum_size = Vector2(78.0, 78.0)
			portrait.set_meta("portrait_mode", "record")
			return
		# Rail tier: the bound tracks the row's own height, so a roomier ledger
		# shows a readable face and a tight one keeps a small marker.
		var rail_size: float = clampf(_row_min_height() - 10.0, 24.0, 40.0)
		portrait.custom_minimum_size = Vector2(rail_size, rail_size)
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		portrait.set_meta("portrait_mode", "rail")
		return
	var show_inline: bool = size.x >= COMPACT_PORTRAIT_MIN_WIDTH
	portrait.visible = show_inline
	# Deliberate small bounds: the portrait tracks the row's own height, so a
	# roomier rail shows a readable face and a dense rail keeps a small marker.
	var inline_size: float = clampf(_row_min_height() - 10.0, 20.0, 40.0)
	portrait.custom_minimum_size = Vector2(inline_size, inline_size) if show_inline else Vector2.ZERO
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	# Keep the bound square and centred: the crop is composed for this aspect, and
	# a stretched box would re-frame the portrait behind the crop's back.
	portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	portrait.set_meta("portrait_mode", "compact_inline" if show_inline else "compact_omitted_for_name_legibility")

func _make_row_style(player_side: bool, hovered: bool = false) -> StyleBox:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = COLOR_ROW_BG_HOVER if hovered else COLOR_ROW_BG
	style.border_color = COLOR_ACCENT_PLAYER if player_side else COLOR_ACCENT_ENEMY
	# A thin accent edge carries the team without a text prefix, and a single
	# bottom hairline separates rows instead of boxing each one.
	style.border_width_left = 3
	style.border_width_top = 0
	style.border_width_right = 0
	style.border_width_bottom = 1
	style.shadow_size = 0
	return style

## The row's own material is cached per state and re-used, so a refresh or a
## hover swaps between two marked styleboxes instead of minting new instances.
func _apply_row_frame_style() -> void:
	if _frame == null:
		return
	var player_side: bool = team != "enemy"
	if _chrome_team != team or _frame_style_idle == null or _frame_style_hover == null:
		_chrome_team = team
		_frame_style_idle = _make_row_style(player_side, false)
		_frame_style_hover = _make_row_style(player_side, true)
		_frame_style_idle.set_meta("rail_row_chrome", true)
		_frame_style_hover.set_meta("rail_row_chrome", true)
	var wanted: StyleBoxFlat = _frame_style_hover if _hovered else _frame_style_idle
	if _frame.get_theme_stylebox("panel") != wanted:
		_frame.add_theme_stylebox_override("panel", wanted)

func _apply_value_well_style() -> void:
	if _value_well == null:
		return
	if _well_style == null:
		_well_style = _make_value_well_style()
		_well_style.set_meta("rail_value_rule", true)
	if _value_well.get_theme_stylebox("panel") != _well_style:
		_value_well.add_theme_stylebox_override("panel", _well_style)

## Re-assert the rail's own material when something else has replaced it, so a
## competing theme pass cannot leave an ornate value medallion or a boxed row
## behind. A pass that finds the rail's own styles installed does no work.
func ensure_quiet_chrome() -> void:
	if _frame != null:
		var frame_style: StyleBox = _frame.get_theme_stylebox("panel")
		if frame_style == null or not frame_style.has_meta("rail_row_chrome"):
			_apply_row_frame_style()
	if _value_well != null:
		var well_style: StyleBox = _value_well.get_theme_stylebox("panel")
		if well_style == null or not well_style.has_meta("rail_value_rule"):
			_apply_value_well_style()
	_ensure_portrait_bounds()

func _ensure_value_well() -> void:
	if content_box == null:
		return
	if _value_well == null:
		_value_well = Panel.new()
		_value_well.name = "ValueWell"
		_value_well.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content_box.add_child(_value_well)
	_value_well.anchor_left = 1.0
	_value_well.anchor_right = 1.0
	_value_well.anchor_top = 0.0
	_value_well.anchor_bottom = 1.0
	var compact_well_width: float = _compact_numeric_well_width()
	_value_well.offset_left = -122.0 if _record_emphasis else -compact_well_width
	_value_well.offset_right = 0.0
	_value_well.offset_top = 3.0
	_value_well.offset_bottom = -3.0
	_apply_value_well_style()
	_value_well.set_meta("compact_numeric_well_width", 0.0 if _record_emphasis else compact_well_width)
	if name_label != null:
		content_box.move_child(name_label, content_box.get_child_count() - 1)
	if value_label != null:
		content_box.move_child(value_label, content_box.get_child_count() - 1)

func _make_value_well_style() -> StyleBox:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	# The value keeps its own room and one quiet separating rule, not a second
	# nested box inside the row.
	style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	style.border_color = COLOR_WELL_RULE
	style.border_width_left = 1
	style.border_width_top = 0
	style.border_width_right = 0
	style.border_width_bottom = 0
	style.content_margin_left = 4
	style.content_margin_right = 6
	return style

func _compact_numeric_well_width() -> float:
	if _value_column > 0.0:
		return _value_column
	# Wide record rows (the loss ledger) keep a generous numeric column; a rail
	# row takes only the width its own readout needs, so the name keeps the rest.
	if size.x >= 320.0:
		return 78.0
	return clampf(_compact_value_text_width() + 16.0, 34.0, 60.0)

func _compact_value_text_width() -> float:
	var font: Font = VisualTypeSystem.FONT_UTILITY_BOLD
	return font.get_string_size(_format_value(value), HORIZONTAL_ALIGNMENT_RIGHT, -1.0, 15).x

func _compact_numeric_content_width() -> float:
	return maxf(20.0, _compact_numeric_well_width() - 10.0)

func _compact_numeric_right_inset() -> float:
	return 6.0

func _format_value(v: float) -> String:
	if metric_key == "dps":
		if v >= 1000.0:
			return String.num(v/1000.0, 1) + "k"
		return String.num(v, 1)
	if metric_key == "casts":
		return str(int(round(v)))
	# The exact-value contract is the caller's, not the tier's: a rail that asks
	# for exact compact values keeps them whether or not it also flags a compact
	# layout, so a support rail never rounds an authored figure into "9.1k".
	if _exact_compact_values and absi(int(round(v))) < 10000:
		return str(int(round(v)))
	if v >= 1000000.0:
		return String.num(v/1000000.0, 1) + "m"
	if v >= 1000.0:
		return String.num(v/1000.0, 1) + "k"
	return str(int(round(v)))

func tween_reorder_hint() -> void:
	var t: Tween = create_tween()
	t.tween_property(self, "modulate:a", 0.6, 0.1)
	t.tween_property(self, "modulate:a", 1.0, 0.1)

func _center_value_label() -> void:
	if value_label == null:
		return
	# Center the label using explicit top/bottom offsets, independent of container sizing
	var row_h: float = (content_box.size.y if content_box else size.y)
	var font: Font = value_label.get_theme_font("font")
	var fsize: int = value_label.get_theme_font_size("font_size")
	var text_h: float = (font.get_height(fsize) if font else value_label.get_combined_minimum_size().y)
	var top: float = max(0.0, (row_h - text_h) * 0.5)
	value_label.anchor_top = 0.0
	value_label.anchor_bottom = 0.0
	value_label.offset_top = top
	value_label.offset_bottom = top + text_h

func _ready() -> void:
	_compact_layout = _resolve_compact_layout()
	set_meta("compact_layout", _compact_layout)
	_ensure_layout()
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if not is_connected("mouse_entered", Callable(self, "_on_mouse_entered")):
		mouse_entered.connect(_on_mouse_entered)
	if not is_connected("mouse_exited", Callable(self, "_on_mouse_exited")):
		mouse_exited.connect(_on_mouse_exited)
	# The compact portrait and the value well both depend on the settled row
	# width, so re-run the geometry whenever the rail resizes.
	if not is_connected("resized", Callable(self, "_ensure_layout")):
		resized.connect(_ensure_layout)
	if not is_connected("resized", Callable(self, "_update_portrait")):
		resized.connect(_update_portrait)
	# Ensure centering reacts to resizes and enforce vertical alignment
	if not is_connected("resized", Callable(self, "_center_value_label")):
		resized.connect(_center_value_label)
	if content_box and not content_box.is_connected("resized", Callable(self, "_center_value_label")):
		content_box.resized.connect(_center_value_label)
	if not is_connected("resized", Callable(self, "_update_bar")):
		resized.connect(_update_bar)
	if content_box and not content_box.is_connected("resized", Callable(self, "_update_bar")):
		content_box.resized.connect(_update_bar)
	# The identity fit reads the settled name column, so it is re-run (and the
	# chosen size re-applied) whenever the row, its content or the label itself
	# resizes. `_refit_identity` covers `_update_identity` plus the font.
	if not is_connected("resized", Callable(self, "_refit_identity")):
		resized.connect(_refit_identity)
	if content_box and not content_box.is_connected("resized", Callable(self, "_refit_identity")):
		content_box.resized.connect(_refit_identity)
	if name_label and not name_label.is_connected("resized", Callable(self, "_refit_identity")):
		name_label.resized.connect(_refit_identity)
	if value_label:
		value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_center_value_label()

## Rows are created and destroyed while the rail is already laid out, so the
## viewport heuristic alone would mis-tier a row that appears between responsive
## passes. When an ancestor has published the planning tier (the combat view
## does), that value wins; otherwise fall back to the viewport size.
func _resolve_compact_layout() -> bool:
	var node: Node = get_parent()
	while node != null:
		if node.has_meta("compact_layout"):
			return bool(node.get_meta("compact_layout"))
		node = node.get_parent()
	var viewport_size: Vector2 = get_viewport_rect().size
	return viewport_size.y <= 520.0 or viewport_size.x <= 1100.0

func _on_mouse_entered() -> void:
	_hovered = true
	_apply_visual_style()

func _on_mouse_exited() -> void:
	_hovered = false
	_apply_visual_style()
