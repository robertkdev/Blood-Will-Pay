extends Control
class_name ScoreboardRow

const TextureUtils := preload("res://scripts/util/texture_utils.gd")
const GothicUIAssets: GDScript = preload("res://scripts/ui/gothic_ui_assets.gd")
const HardcoreUIAssets: GDScript = preload("res://scripts/ui/hardcore_ui_assets.gd")

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
	name_label.text = unit_name

func _apply_visual_style() -> void:
	custom_minimum_size.y = max(custom_minimum_size.y, 54.0)
	var player_side: bool = team != "enemy"
	var fill_color: Color = Color(0.20, 0.38, 0.40, 0.96) if player_side else Color(0.62, 0.07, 0.10, 0.96)
	var bg_color: Color = Color(0.020, 0.018, 0.024, 0.96)
	if _frame != null:
		_frame.add_theme_stylebox_override("panel", _make_row_style(player_side, _hovered))
	if bar_bg != null:
		bar_bg.color = bg_color
	if bar_fill != null:
		bar_fill.color = Color(fill_color.r + 0.06, fill_color.g + 0.05, fill_color.b + 0.04, 1.0) if _hovered else fill_color
	if name_label != null:
		name_label.add_theme_font_size_override("font_size", 14)
		name_label.add_theme_color_override("font_color", Color(0.96, 0.90, 0.78, 1.0) if _hovered else Color(0.88, 0.84, 0.76, 1.0))
		name_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.78))
		name_label.add_theme_constant_override("outline_size", 1)
	if value_label != null:
		value_label.add_theme_font_size_override("font_size", 15)
		value_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.50, 1.0) if _hovered else Color(0.95, 0.75, 0.42, 1.0))
		value_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.82))
		value_label.add_theme_constant_override("outline_size", 1)
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value_label.clip_text = true
	if portrait != null:
		portrait.custom_minimum_size = Vector2(42.0, 42.0)
		portrait.modulate = Color(1.0, 0.94, 0.80, 1.0) if _hovered else Color(0.95, 0.90, 0.82, 1.0)

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
		hbox.offset_left = 8.0
		hbox.offset_top = 6.0
		hbox.offset_right = -8.0
		hbox.offset_bottom = -6.0
		hbox.add_theme_constant_override("separation", 8)
	if content_box != null:
		content_box.custom_minimum_size = Vector2(0.0, 42.0)
		_ensure_value_well()
	if name_label != null:
		name_label.anchor_left = 0.0
		name_label.anchor_right = 1.0
		name_label.anchor_top = 0.0
		name_label.anchor_bottom = 1.0
		name_label.offset_left = 10.0
		name_label.offset_right = -84.0
		name_label.clip_text = true
	if value_label != null:
		value_label.anchor_left = 1.0
		value_label.anchor_right = 1.0
		value_label.anchor_top = 0.0
		value_label.anchor_bottom = 1.0
		value_label.offset_left = -76.0
		value_label.offset_right = -10.0

func _make_row_style(player_side: bool, hovered: bool = false) -> StyleBox:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.050, 0.038, 0.044, 0.94) if hovered else Color(0.032, 0.028, 0.036, 0.88)
	style.border_color = Color(0.96, 0.70, 0.34, 0.96) if hovered else Color(0.24, 0.34, 0.34, 0.74) if player_side else Color(0.48, 0.045, 0.070, 0.80)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_right = 5
	style.corner_radius_bottom_left = 5
	style.shadow_size = 8 if hovered else 4
	style.shadow_color = Color(0.60, 0.16, 0.040, 0.26) if hovered else Color(0.0, 0.0, 0.0, 0.38)
	var modulate: Color = Color(1.14, 1.05, 0.92, 1.0) if hovered else Color(0.86, 0.82, 0.78, 0.94)
	return GothicUIAssets.style_or_fallback(HardcoreUIAssets.scoreboard_row_style(hovered), style)

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
	_value_well.offset_left = -82.0
	_value_well.offset_right = 0.0
	_value_well.offset_top = 3.0
	_value_well.offset_bottom = -3.0
	_value_well.add_theme_stylebox_override("panel", _make_value_well_style())
	if name_label != null:
		content_box.move_child(name_label, content_box.get_child_count() - 1)
	if value_label != null:
		content_box.move_child(value_label, content_box.get_child_count() - 1)

func _make_value_well_style() -> StyleBox:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.018, 0.015, 0.020, 0.82)
	style.border_color = Color(0.30, 0.22, 0.18, 0.54)
	style.border_width_left = 1
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_right = 4
	style.corner_radius_bottom_left = 4
	style.content_margin_left = 6
	style.content_margin_right = 8
	return GothicUIAssets.style_or_fallback(GothicUIAssets.small_button_style(Color(0.68, 0.64, 0.60, 0.70)), style)

func _format_value(v: float) -> String:
	if metric_key == "dps":
		if v >= 1000.0:
			return String.num(v/1000.0, 1) + "k"
		return String.num(v, 1)
	if metric_key == "casts":
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
	if value_label:
		value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_center_value_label()

func _on_mouse_entered() -> void:
	_hovered = true
	_apply_visual_style()

func _on_mouse_exited() -> void:
	_hovered = false
	_apply_visual_style()
