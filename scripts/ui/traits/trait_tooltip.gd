extends Panel
class_name TraitTooltip

const GothicUIAssets: GDScript = preload("res://scripts/ui/gothic_ui_assets.gd")

@onready var _name_label: Label = $VBox/Name
@onready var _state_label: Label = $VBox/State
@onready var _threshold_label: Label = $VBox/Thresholds
@onready var _description_label: Label = $VBox/Description
@onready var _footer_label: Label = $VBox/Footer
@onready var _vbox: VBoxContainer = $VBox
var _threshold_row: HBoxContainer = null

const TOOLTIP_WIDTH: float = 320.0
const PADDING: float = 18.0
const EDGE_PADDING: float = 12.0
const BOTTOM_UI_RESERVE: float = 236.0
const LEFT_PANEL_RESERVE: float = 340.0
const LEFT_PANEL_TOOLTIP_TOP: float = 268.0
const TOOLTIP_GROUP: String = "gothic_hover_tooltip"
const CURSOR_OFFSET: Vector2 = Vector2(18.0, -14.0)
const COLOR_PANEL: Color = Color(0.024, 0.020, 0.030, 0.985)
const COLOR_BORDER: Color = Color(0.64, 0.42, 0.22, 0.94)
const COLOR_BORDER_ACTIVE: Color = Color(0.95, 0.69, 0.31, 1.0)
const COLOR_TEXT: Color = Color(0.91, 0.87, 0.78, 1.0)
const COLOR_MUTED: Color = Color(0.68, 0.61, 0.53, 1.0)
const COLOR_GOLD: Color = Color(0.94, 0.70, 0.36, 1.0)
const COLOR_BLOOD: Color = Color(0.82, 0.36, 0.24, 1.0)
const COLOR_GREEN: Color = Color(0.50, 0.72, 0.58, 1.0)

var trait_id: String = ""
var trait_count: int = 0
var trait_tier: int = -1
var is_active: bool = false

func _ready() -> void:
	top_level = true
	focus_mode = Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 900
	add_to_group(TOOLTIP_GROUP)
	custom_minimum_size.x = TOOLTIP_WIDTH
	_ensure_threshold_row()
	_apply_style()
	_update_labels()

func _apply_style() -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = COLOR_PANEL
	style.border_color = COLOR_BORDER_ACTIVE if is_active else COLOR_BORDER
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_right = 5
	style.corner_radius_bottom_left = 5
	style.shadow_size = 14
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.62)
	var style_modulate: Color = Color(1.10, 1.02, 0.88, 1.0) if is_active else Color.WHITE
	add_theme_stylebox_override("panel", GothicUIAssets.style_or_fallback(GothicUIAssets.grid_panel_style(style_modulate), style))
	var background: ColorRect = get_node_or_null("ColorRect") as ColorRect
	if background != null:
		background.color = Color(0.050, 0.033, 0.040, 0.0)
	if _vbox != null:
		_vbox.add_theme_constant_override("separation", 9)
	if _name_label != null:
		_name_label.add_theme_font_size_override("font_size", 20)
		_name_label.add_theme_color_override("font_color", COLOR_GOLD)
		_name_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.74))
		_name_label.add_theme_constant_override("outline_size", 1)
	if _state_label != null:
		_state_label.add_theme_font_size_override("font_size", 12)
		_state_label.add_theme_color_override("font_color", COLOR_GREEN if is_active else COLOR_MUTED)
	if _threshold_label != null:
		_threshold_label.visible = false
		_threshold_label.add_theme_color_override("font_color", COLOR_MUTED)
	if _description_label != null:
		_description_label.add_theme_font_size_override("font_size", 15)
		_description_label.add_theme_color_override("font_color", COLOR_TEXT)
		_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if _footer_label != null:
		_footer_label.add_theme_font_size_override("font_size", 14)
		_footer_label.add_theme_color_override("font_color", COLOR_MUTED)
		_footer_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func set_trait(id: String) -> void:
	trait_id = String(id)
	_update_labels()

func set_context(active: bool, count: int, tier: int) -> void:
	is_active = bool(active)
	trait_count = int(count)
	trait_tier = int(tier)
	_apply_style()
	_update_labels()

func show_at(viewport_pos: Vector2) -> void:
	visible = true
	modulate.a = 0.0
	scale = Vector2(0.985, 0.985)
	await get_tree().process_frame
	_sync_size()
	move_to(viewport_pos)
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 1.0, 0.08)
	tween.parallel().tween_property(self, "scale", Vector2.ONE, 0.08)

func show_near(icon_position: Vector2, icon_size: Vector2) -> void:
	visible = true
	modulate.a = 0.0
	scale = Vector2(0.985, 0.985)
	await get_tree().process_frame
	_sync_size()
	move_to_raw(icon_position + Vector2(icon_size.x + 14.0, -8.0))
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 1.0, 0.08)
	tween.parallel().tween_property(self, "scale", Vector2.ONE, 0.08)

func move_to(viewport_pos: Vector2) -> void:
	_sync_size()
	global_position = _clamped_position(viewport_pos + CURSOR_OFFSET)

func move_to_raw(raw_position: Vector2) -> void:
	_sync_size()
	global_position = _clamped_position(raw_position)

func _update_labels() -> void:
	var def: TraitDef = _load_trait_def(trait_id)
	var title: String = trait_id
	if def != null and String(def.name).strip_edges() != "":
		title = String(def.name)
	if _name_label:
		_name_label.text = title
	var state_text: String = _format_state(def)
	if _state_label:
		_state_label.text = state_text
		_state_label.visible = state_text != ""
	var thresholds_text: String = _format_thresholds(def)
	if _threshold_label:
		_threshold_label.text = thresholds_text
		_threshold_label.visible = false
	_update_threshold_row(def)
	var description: String = ""
	if def != null and def.description != null:
		description = String(def.description)
	if _description_label:
		_description_label.text = description
		_description_label.visible = description.strip_edges() != ""
	if _footer_label:
		_footer_label.text = _format_footer(def)
		_footer_label.visible = _footer_label.text.strip_edges() != ""
	_sync_size()
	queue_redraw()

func _format_state(def: TraitDef) -> String:
	var count_text: String = "Members: %d" % trait_count if trait_count > 0 else "Members: hidden"
	if is_active:
		return "ACTIVE  |  %s  |  Tier %d" % [count_text, trait_tier + 1]
	var next_threshold: int = _next_threshold(def)
	if next_threshold > 0:
		return "DORMANT  |  %s  |  Next at %d" % [count_text, next_threshold]
	return "DORMANT  |  %s" % count_text

func _format_thresholds(def: TraitDef) -> String:
	# Godot 4 does not have Object.has_property(); TraitDef always defines
	# an exported Array[int] `thresholds`, so access it directly and guard nulls.
	var values: Array[int] = []
	if def != null:
		var arr: Array = def.thresholds
		if arr != null and arr.size() > 0:
			for v in arr:
				values.append(int(v))
	var parts: PackedStringArray = PackedStringArray()
	for v in values:
		parts.append(str(v))
	if parts.size() == 0:
		return ""
	return "Thresholds: %s" % " / ".join(parts)

func _ensure_threshold_row() -> void:
	if _vbox == null:
		return
	_threshold_row = _vbox.get_node_or_null("ThresholdRow") as HBoxContainer
	if _threshold_row != null:
		return
	_threshold_row = HBoxContainer.new()
	_threshold_row.name = "ThresholdRow"
	_threshold_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_threshold_row.add_theme_constant_override("separation", 8)
	var insert_index: int = _vbox.get_child_count()
	if _threshold_label != null:
		insert_index = _threshold_label.get_index() + 1
	_vbox.add_child(_threshold_row)
	_vbox.move_child(_threshold_row, min(insert_index, _vbox.get_child_count() - 1))

func _update_threshold_row(def: TraitDef) -> void:
	_ensure_threshold_row()
	if _threshold_row == null:
		return
	for child: Node in _threshold_row.get_children():
		child.queue_free()
	var values: Array[int] = _threshold_values(def)
	if values.is_empty():
		_threshold_row.visible = false
		return
	_threshold_row.visible = true
	var active_value: int = values[clampi(trait_tier, 0, values.size() - 1)] if is_active and trait_tier >= 0 else -1
	for value: int in values:
		var reached: bool = trait_count >= value
		var active_chip: bool = value == active_value
		var chip: Label = Label.new()
		chip.text = str(value)
		chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		chip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		chip.custom_minimum_size = Vector2(52.0, 28.0)
		chip.add_theme_font_size_override("font_size", 14)
		chip.add_theme_color_override("font_color", Color(1.0, 0.98, 0.82, 1.0) if active_chip else (COLOR_TEXT if reached else COLOR_MUTED))
		chip.add_theme_stylebox_override("normal", _make_threshold_chip_style(active_chip, reached))
		_threshold_row.add_child(chip)

func _threshold_values(def: TraitDef) -> Array[int]:
	var values: Array[int] = []
	if def != null:
		var arr: Array = def.thresholds
		if arr != null and arr.size() > 0:
			for v in arr:
				values.append(int(v))
	return values

func _make_threshold_chip_style(active_chip: bool, reached: bool) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	if active_chip:
		style.bg_color = Color(0.38, 0.27, 0.12, 1.0)
		style.border_color = Color(0.94, 0.72, 0.38, 1.0)
	elif reached:
		style.bg_color = Color(0.18, 0.12, 0.070, 0.96)
		style.border_color = Color(0.74, 0.50, 0.26, 0.92)
	else:
		style.bg_color = Color(0.035, 0.030, 0.038, 0.88)
		style.border_color = Color(0.28, 0.24, 0.24, 0.78)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_right = 4
	style.corner_radius_bottom_left = 4
	return style

func _format_footer(def: TraitDef) -> String:
	if def == null:
		return "Trait definition was not found."
	if is_active:
		return "The bonus is live for the current board."
	var next_threshold: int = _next_threshold(def)
	if next_threshold > 0:
		var needed: int = max(0, next_threshold - trait_count)
		return "%d more matching member%s to awaken." % [needed, "" if needed == 1 else "s"]
	return ""

func _next_threshold(def: TraitDef) -> int:
	if def == null:
		return 0
	for threshold: int in def.thresholds:
		if trait_count < threshold:
			return threshold
	return 0

func _load_trait_def(id: String) -> TraitDef:
	var key: String = String(id).strip_edges()
	if key == "":
		return null
	var path: String = "res://data/traits/%s.tres" % key
	if ResourceLoader.exists(path):
		return load(path) as TraitDef
	return null

func _sync_size() -> void:
	if _vbox == null:
		return
	var content_width: float = TOOLTIP_WIDTH - PADDING * 2.0
	for child: Node in _vbox.get_children():
		var child_control: Control = child as Control
		if child_control != null:
			child_control.custom_minimum_size.x = content_width
			child_control.size.x = content_width
	size.x = TOOLTIP_WIDTH
	var desired_height: float = _vbox.get_combined_minimum_size().y + PADDING * 2.0
	size.y = max(desired_height, 112.0)

func _clamped_position(raw_position: Vector2) -> Vector2:
	var viewport: Viewport = get_viewport()
	if viewport == null:
		return raw_position
	var viewport_size: Vector2 = viewport.get_visible_rect().size
	var new_position: Vector2 = raw_position
	if viewport_size.x >= 1200.0 and new_position.x < LEFT_PANEL_RESERVE:
		new_position.x = EDGE_PADDING
		new_position.y = max(new_position.y, LEFT_PANEL_TOOLTIP_TOP)
	if new_position.x + size.x + EDGE_PADDING > viewport_size.x:
		new_position.x = raw_position.x - size.x - CURSOR_OFFSET.x * 1.5
	var bottom_reserve: float = min(BOTTOM_UI_RESERVE, viewport_size.y * 0.30)
	var bottom_limit: float = viewport_size.y - EDGE_PADDING - bottom_reserve
	if new_position.y + size.y > bottom_limit:
		new_position.y = bottom_limit - size.y
	if new_position.x < EDGE_PADDING:
		new_position.x = EDGE_PADDING
	if new_position.y < EDGE_PADDING:
		new_position.y = EDGE_PADDING
	return new_position
