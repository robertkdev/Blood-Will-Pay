extends Control
class_name ScoreboardRow

const TextureUtils := preload("res://scripts/util/texture_utils.gd")
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

var _frame: Panel = null
var _value_well: Panel = null
var _hovered: bool = false
var _record_emphasis: bool = false
var _compact_layout: bool = false
var _compact_identity_font_size: int = 14
var _exact_compact_values: bool = false
var _compact_identity_mode: String = "full_badge"

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
		tex = TextureUtils.make_circle_texture(Color(0.6, 0.65, 0.75), 32)
	portrait.texture = tex

func _update_bar() -> void:
	var w: float = max(0.0, float(content_box.size.x if content_box != null else bar_bg.size.x))
	var fill_w: float = w * share
	bar_fill.anchor_left = 0.0
	bar_fill.anchor_right = 0.0
	bar_fill.anchor_top = 0.72 if _record_emphasis else 0.78
	bar_fill.anchor_bottom = 0.92 if _record_emphasis else 0.90
	bar_fill.offset_left = 0.0
	bar_fill.offset_right = fill_w
	bar_fill.offset_top = 0.0
	bar_fill.offset_bottom = 0.0
	value_label.text = _format_value(value)
	_center_value_label()

func _update_identity() -> void:
	if name_label == null:
		return
	var unit_name: String = "Unit"
	if display_name.strip_edges() != "":
		unit_name = display_name.strip_edges()
	elif unit_ref != null and String(unit_ref.name).strip_edges() != "":
		unit_name = String(unit_ref.name)
	var team_prefix: String = "FOE" if team == "enemy" else "YOU"
	if _compact_layout:
		var compact_identity: String = _compact_identity_for_width(unit_name, team_prefix, _compact_identity_available_width())
		name_label.text = compact_identity
		name_label.set_meta("compact_identity_source", unit_name.to_upper())
		name_label.set_meta("compact_identity_lossless", compact_identity == "%s %s" % [team_prefix, unit_name.to_upper()])
		name_label.set_meta("compact_team_marker", team_prefix)
		name_label.set_meta("compact_identity_font_size", _compact_identity_font_size)
		name_label.set_meta("compact_identity_mode", _compact_identity_mode)
		name_label.set_meta("compact_identity_preserves_unit_name", compact_identity.contains(unit_name.to_upper()))
	else:
		name_label.text = unit_name
	name_label.set_meta("compact_identity_complete", _compact_layout)
	name_label.tooltip_text = "%s team — %s" % ["Enemy" if team == "enemy" else "Your", unit_name]

func _apply_visual_style() -> void:
	custom_minimum_size.y = 40.0 if _compact_layout else 94.0 if _record_emphasis else 54.0
	var player_side: bool = team != "enemy"
	var fill_color: Color = Color(0.66, 0.055, 0.070, 0.92) if player_side else Color(0.42, 0.030, 0.045, 0.90)
	var bg_color: Color = Color(0.016, 0.014, 0.018, 0.42)
	if _frame != null:
		_frame.add_theme_stylebox_override("panel", _make_row_style(player_side, _hovered))
	if bar_bg != null:
		bar_bg.color = bg_color
	if bar_fill != null:
		bar_fill.color = Color(fill_color.r + 0.06, fill_color.g + 0.05, fill_color.b + 0.04, 1.0) if _hovered else fill_color
	if name_label != null:
		name_label.add_theme_font_size_override("font_size", _compact_identity_font_size if _compact_layout else 22 if _record_emphasis else 17)
		name_label.add_theme_color_override("font_color", Color(0.96, 0.90, 0.78, 1.0) if _hovered else Color(0.88, 0.84, 0.76, 1.0))
		name_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.78))
		name_label.add_theme_constant_override("outline_size", 1)
	if value_label != null:
		value_label.add_theme_font_size_override("font_size", 15 if _compact_layout else 26 if _record_emphasis else 18)
		value_label.add_theme_color_override("font_color", Color(1.0, 0.72, 0.60, 1.0) if _hovered else Color(0.95, 0.56, 0.50, 1.0))
		value_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.82))
		value_label.add_theme_constant_override("outline_size", 1)
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value_label.clip_text = true
		value_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING

func _compact_identity_for_width(unit_name: String, team_prefix: String, available_width: float) -> String:
	var clean_name: String = unit_name.strip_edges().to_upper()
	if clean_name == "":
		clean_name = "UNIT"
	var font: Font = name_label.get_theme_font("font") if name_label != null else null
	var full_badge: String = "%s %s" % [team_prefix, clean_name]
	_compact_identity_font_size = 14
	while _compact_identity_font_size > 10 and _compact_text_width(full_badge, font, _compact_identity_font_size) > available_width:
		_compact_identity_font_size -= 1
	if _compact_text_width(full_badge, font, _compact_identity_font_size) <= available_width:
		_compact_identity_mode = "full_badge"
		return full_badge
	_compact_identity_font_size = 13
	while _compact_identity_font_size > 9 and _compact_text_width(clean_name, font, _compact_identity_font_size) > available_width:
		_compact_identity_font_size -= 1
	if _compact_text_width(clean_name, font, _compact_identity_font_size) <= available_width:
		_compact_identity_mode = "name_only_team_in_chrome"
		return clean_name
	_compact_identity_font_size = 10
	_compact_identity_mode = "coded_name_team_in_chrome"
	return _compact_identity_name(clean_name)

func _compact_identity_available_width() -> float:
	if name_label == null:
		return 72.0
	if name_label.size.x > 1.0:
		return name_label.size.x
	if content_box != null and content_box.size.x > 1.0:
		return maxf(32.0, content_box.size.x - 52.0)
	return maxf(32.0, size.x - 62.0)

func _compact_text_width(text: String, font: Font, font_size: int) -> float:
	if font != null:
		return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	return float(text.length() * 8)

func _compact_identity_name(unit_name: String) -> String:
	var clean_name: String = unit_name.strip_edges()
	if clean_name == "":
		return "UNIT"
	if clean_name.length() <= 6:
		return clean_name.to_upper()
	var duplicate_marker: int = clean_name.rfind("#")
	if duplicate_marker > 0:
		var suffix: String = clean_name.substr(duplicate_marker).strip_edges()
		var base_budget: int = maxi(2, 6 - suffix.length())
		return "%s%s" % [clean_name.left(base_budget).to_upper(), suffix]
	var words: PackedStringArray = clean_name.split(" ", false)
	if words.size() > 1:
		var first_code: String = words[0].left(3).to_upper()
		var final_code: String = words[words.size() - 1].left(2).to_upper()
		return "%s%s" % [first_code, final_code]
	return "%s%s" % [clean_name.left(4).to_upper(), clean_name.right(2).to_upper()]

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
		hbox.add_theme_constant_override("separation", 0 if _compact_layout else 12 if _record_emphasis else 8)
	if portrait != null:
		portrait.visible = not _compact_layout
		portrait.custom_minimum_size = Vector2.ZERO if _compact_layout else Vector2(78.0, 78.0) if _record_emphasis else Vector2(40.0, 40.0)
	if content_box != null:
		content_box.custom_minimum_size = Vector2(0.0, 34.0) if _compact_layout else Vector2(0.0, 78.0) if _record_emphasis else Vector2(0.0, 42.0)
		_ensure_value_well()
	if name_label != null:
		var compact_value_width: float = _compact_numeric_well_width()
		name_label.anchor_left = 0.0
		name_label.anchor_right = 1.0
		name_label.anchor_top = 0.0
		name_label.anchor_bottom = 1.0
		name_label.offset_left = 4.0 if _compact_layout else 16.0 if _record_emphasis else 10.0
		name_label.offset_right = -(compact_value_width + 6.0) if _compact_layout else -126.0 if _record_emphasis else -84.0
		name_label.clip_text = true
		name_label.set_meta("compact_numeric_safety_gap", 6.0 if _compact_layout else 0.0)
	if value_label != null:
		var compact_content_width: float = _compact_numeric_content_width()
		var compact_right_inset: float = _compact_numeric_right_inset()
		value_label.anchor_left = 1.0
		value_label.anchor_right = 1.0
		value_label.anchor_top = 0.0
		value_label.anchor_bottom = 1.0
		value_label.offset_left = -compact_content_width - compact_right_inset if _compact_layout else -116.0 if _record_emphasis else -76.0
		value_label.offset_right = -compact_right_inset if _compact_layout else -14.0 if _record_emphasis else -10.0
		value_label.set_meta("compact_numeric_content_width", compact_content_width if _compact_layout else 0.0)

func _make_row_style(player_side: bool, hovered: bool = false) -> StyleBox:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.050, 0.030, 0.034, 0.98) if hovered else Color(0.027, 0.023, 0.028, 0.96)
	style.border_color = Color(0.96, 0.55, 0.23, 0.98) if hovered else Color(0.46, 0.34, 0.22, 0.88) if player_side else Color(0.58, 0.035, 0.060, 0.92)
	style.border_width_left = 5
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.shadow_size = 4 if hovered else 2
	style.shadow_color = Color(0.60, 0.025, 0.035, 0.24) if hovered else Color(0.0, 0.0, 0.0, 0.42)
	return style

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
	_value_well.offset_left = -compact_well_width if _compact_layout else -122.0 if _record_emphasis else -82.0
	_value_well.offset_right = 0.0
	_value_well.offset_top = 3.0
	_value_well.offset_bottom = -3.0
	_value_well.add_theme_stylebox_override("panel", _make_value_well_style())
	_value_well.set_meta("compact_numeric_well_width", compact_well_width if _compact_layout else 0.0)
	if name_label != null:
		content_box.move_child(name_label, content_box.get_child_count() - 1)
	if value_label != null:
		content_box.move_child(value_label, content_box.get_child_count() - 1)

func _make_value_well_style() -> StyleBox:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.010, 0.009, 0.012, 0.94)
	style.border_color = Color(0.48, 0.30, 0.18, 0.82)
	style.border_width_left = 3
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.content_margin_left = 6
	style.content_margin_right = 8
	return style

func _compact_numeric_well_width() -> float:
	if not _exact_compact_values:
		return 22.0
	return 62.0 if size.x < 180.0 else 78.0

func _compact_numeric_content_width() -> float:
	if not _exact_compact_values:
		return 16.0
	return 50.0 if size.x < 180.0 else 64.0

func _compact_numeric_right_inset() -> float:
	return 8.0 if _exact_compact_values else 4.0

func _format_value(v: float) -> String:
	if metric_key == "dps":
		if v >= 1000.0:
			return String.num(v/1000.0, 1) + "k"
		return String.num(v, 1)
	if metric_key == "casts":
		return str(int(round(v)))
	if _compact_layout and _exact_compact_values and absi(int(round(v))) < 10000:
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
	var viewport_size: Vector2 = get_viewport_rect().size
	_compact_layout = viewport_size.y <= 520.0 or viewport_size.x <= 1100.0
	set_meta("compact_layout", _compact_layout)
	_ensure_layout()
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if not is_connected("mouse_entered", Callable(self, "_on_mouse_entered")):
		mouse_entered.connect(_on_mouse_entered)
	if not is_connected("mouse_exited", Callable(self, "_on_mouse_exited")):
		mouse_exited.connect(_on_mouse_exited)
	# Ensure centering reacts to resizes and enforce vertical alignment
	if not is_connected("resized", Callable(self, "_center_value_label")):
		resized.connect(_center_value_label)
	if content_box and not content_box.is_connected("resized", Callable(self, "_center_value_label")):
		content_box.resized.connect(_center_value_label)
	if not is_connected("resized", Callable(self, "_update_bar")):
		resized.connect(_update_bar)
	if content_box and not content_box.is_connected("resized", Callable(self, "_update_bar")):
		content_box.resized.connect(_update_bar)
	if not is_connected("resized", Callable(self, "_update_identity")):
		resized.connect(_update_identity)
	if content_box and not content_box.is_connected("resized", Callable(self, "_update_identity")):
		content_box.resized.connect(_update_identity)
	if value_label:
		value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_center_value_label()

func _on_mouse_entered() -> void:
	_hovered = true
	_apply_visual_style()

func _on_mouse_exited() -> void:
	_hovered = false
	_apply_visual_style()
