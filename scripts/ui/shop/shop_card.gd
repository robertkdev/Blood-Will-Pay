extends Button
class_name ShopCard

const TextureUtils := preload("res://scripts/util/texture_utils.gd")
const TraitIconScene := preload("res://scenes/ui/traits/TraitIcon.tscn")
const AbilityCatalog := preload("res://scripts/game/abilities/ability_catalog.gd")
const UnitFactory := preload("res://scripts/unit_factory.gd")
const UnitTargetingText := preload("res://scripts/ui/unit_targeting_text.gd")
const GothicUIAssets: GDScript = preload("res://scripts/ui/gothic_ui_assets.gd")

const COLOR_TEXT: Color = Color(0.91, 0.87, 0.78, 1.0)
const COLOR_MUTED: Color = Color(0.66, 0.60, 0.52, 1.0)
const COLOR_GOLD: Color = Color(0.92, 0.66, 0.32, 1.0)
const COLOR_BLOOD: Color = Color(0.52, 0.040, 0.072, 1.0)
const COLOR_PANEL: Color = Color(0.045, 0.037, 0.047, 0.97)
const COLOR_IRON: Color = Color(0.40, 0.34, 0.32, 0.94)
const TOOLTIP_WIDTH: float = 330.0
const TOOLTIP_CURSOR_OFFSET: Vector2 = Vector2(18.0, -14.0)
const TOOLTIP_EDGE_PADDING: float = 12.0

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
var _tooltip: PanelContainer = null
var _tooltip_title: String = ""
var _tooltip_subtitle: String = ""
var _tooltip_lines: Array[String] = []
var _status_tip: String = ""

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
	var price_i: int = int(props.get("price", props.get("cost", 0)))
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
		_name_label.text = title
	if _price_label:
		_price_label.text = "%d blood" % price_i
	if _icon:
		var tex: Texture2D = null
		if img_path != "":
			tex = TextureUtils.try_load_texture(img_path)
		if tex == null:
			tex = TextureUtils.make_circle_texture(Color(0.75, 0.75, 0.75), 96)
		_icon.texture = tex

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
	var identity_tip := "\n".join(tooltip_lines)
	set_meta("identity_tooltip", identity_tip)
	if _disabled_reason != "":
		tooltip_text = _disabled_reason
	elif identity_tip != "":
		tooltip_text = identity_tip
	else:
		tooltip_text = title
	_tooltip_title = title
	_tooltip_subtitle = "%d blood" % price_i
	_tooltip_lines = _build_tooltip_lines(display_role, display_goal, approaches, alt_goals, traits)
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
		_identity_panel.visible = has_identity

func set_affordable(affordable: bool) -> void:
	var ok: bool = bool(affordable)
	var shop_reason: String = String(get_meta("shop_disabled_reason", ""))
	if shop_reason != "":
		disabled = true
	else:
		disabled = not ok
	if _price_label:
		_price_label.modulate = Color(1, 1, 0.8, 0.95) if ok else Color(1, 0.5, 0.5, 0.85)
	set_status_tip("" if ok else "Not enough blood in reserve")
	_refresh_cursor()

func set_shop_disabled(reason) -> void:
	_disabled_reason = String(reason)
	set_meta("shop_disabled_reason", _disabled_reason)
	disabled = true
	set_status_tip(_disabled_reason)
	modulate = Color(1, 1, 1, 0.6)
	_refresh_cursor()

func set_status_tip(text: String) -> void:
	_status_tip = String(text).strip_edges()
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
	var preview_unit: Unit = UnitFactory.spawn(offer_id) if offer_id.strip_edges() != "" else null
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
	var compact: bool = viewport_size.y <= 760.0 or viewport_size.x <= 1400.0
	custom_minimum_size = Vector2(120.0, 94.0) if compact else Vector2(150.0, 138.0)
	add_theme_stylebox_override("normal", _make_card_style(false, false))
	add_theme_stylebox_override("hover", _make_card_style(false, true))
	add_theme_stylebox_override("pressed", _make_card_style(true, true))
	add_theme_stylebox_override("disabled", _make_card_style(false, false, true))
	add_theme_stylebox_override("focus", _make_card_style(false, true))
	add_theme_color_override("font_disabled_color", Color(0.74, 0.67, 0.56, 0.92))
	if _border_gradient != null:
		_border_gradient.visible = false
	if _bottom_gradient != null:
		_bottom_gradient.visible = false
	if _icon:
		_icon.z_index = 2
		_icon.modulate = Color(1.0, 0.93, 0.82, 1.0)
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
		_role_badge.add_theme_font_size_override("font_size", 11)
		_role_badge.add_theme_color_override("font_color", COLOR_GOLD)
		_role_badge.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.70))
		_role_badge.add_theme_constant_override("outline_size", 1)
	if _goal_label:
		_goal_label.add_theme_color_override("font_color", COLOR_MUTED)
	if _name_label:
		_name_label.z_index = 6
		_name_label.add_theme_font_size_override("font_size", 13)
		_name_label.add_theme_color_override("font_color", COLOR_TEXT)
		_name_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.82))
		_name_label.add_theme_constant_override("outline_size", 1)
	if _price_label:
		_price_label.z_index = 6
		_price_label.add_theme_font_size_override("font_size", 13)
		_price_label.add_theme_color_override("font_color", COLOR_GOLD)
		_price_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.82))
		_price_label.add_theme_constant_override("outline_size", 1)

func _make_card_style(pressed_state: bool, highlighted: bool, disabled_state: bool = false) -> StyleBox:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = COLOR_PANEL
	style.border_color = COLOR_IRON
	var modulate: Color = Color.WHITE
	if highlighted:
		style.bg_color = Color(0.092, 0.054, 0.062, 0.99)
		style.border_color = COLOR_GOLD
		modulate = Color(1.14, 1.05, 0.92, 1.0)
	if pressed_state:
		style.bg_color = Color(0.13, 0.026, 0.040, 0.98)
		style.border_color = COLOR_BLOOD
		modulate = Color(0.92, 0.82, 0.78, 1.0)
	if disabled_state:
		style.bg_color = Color(0.038, 0.032, 0.040, 0.96)
		style.border_color = Color(0.33, 0.29, 0.29, 0.88)
		modulate = Color(0.50, 0.48, 0.46, 0.82)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_right = 5
	style.corner_radius_bottom_left = 5
	style.shadow_size = 12 if highlighted else 8
	style.shadow_color = Color(0.58, 0.18, 0.060, 0.30) if highlighted else Color(0.0, 0.0, 0.0, 0.46)
	return GothicUIAssets.style_or_fallback(GothicUIAssets.shop_card_style(modulate), style)

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
	add_theme_stylebox_override("focus", _make_card_style(false, highlight))
	if highlight:
		if _icon != null:
			_icon.modulate = Color(1.0, 0.93, 0.78, 1.0)
	else:
		if _icon != null:
			_icon.modulate = Color(0.96, 0.91, 0.84, 1.0)

func _show_tooltip() -> void:
	_clear_tooltip()
	if not is_inside_tree():
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
	tooltip.z_index = 950
	tooltip.custom_minimum_size.x = TOOLTIP_WIDTH
	tooltip.add_theme_stylebox_override("panel", _make_tooltip_style())
	var box: VBoxContainer = VBoxContainer.new()
	box.name = "Rows"
	box.add_theme_constant_override("separation", 5)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip.add_child(box)
	if _tooltip_title.strip_edges() != "":
		_add_tooltip_label(box, _tooltip_title, 18, COLOR_GOLD)
	if _tooltip_subtitle.strip_edges() != "":
		_add_tooltip_label(box, _tooltip_subtitle, 12, COLOR_MUTED)
	for line: String in lines:
		var color: Color = Color(0.92, 0.76, 0.58, 1.0) if line == _status_tip and _status_tip != "" else COLOR_TEXT
		_add_tooltip_label(box, line, 13, color)
	tree.root.add_child(tooltip)
	_tooltip = tooltip
	_sync_tooltip_size()
	var viewport: Viewport = get_viewport()
	if viewport != null:
		_move_tooltip(viewport.get_mouse_position())

func _current_tooltip_lines() -> Array[String]:
	var lines: Array[String] = []
	if _status_tip != "":
		lines.append(_status_tip)
	for line: String in _tooltip_lines:
		if line.strip_edges() != "":
			lines.append(line)
	return lines

func _add_tooltip_label(parent: VBoxContainer, text: String, font_size: int, color: Color) -> void:
	var label: Label = Label.new()
	label.text = String(text)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = TOOLTIP_WIDTH - 24.0
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.75))
	label.add_theme_constant_override("outline_size", 1)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)

func _move_tooltip(viewport_pos: Vector2) -> void:
	if _tooltip == null or not is_instance_valid(_tooltip):
		return
	_sync_tooltip_size()
	_tooltip.global_position = _clamped_tooltip_position(viewport_pos + TOOLTIP_CURSOR_OFFSET)

func _sync_tooltip_size() -> void:
	if _tooltip == null or not is_instance_valid(_tooltip):
		return
	_tooltip.size.x = TOOLTIP_WIDTH
	_tooltip.size.y = max(84.0, _tooltip.get_combined_minimum_size().y)

func _clamped_tooltip_position(raw_position: Vector2) -> Vector2:
	if _tooltip == null or not is_instance_valid(_tooltip):
		return raw_position
	var viewport: Viewport = get_viewport()
	if viewport == null:
		return raw_position
	var viewport_size: Vector2 = viewport.get_visible_rect().size
	var next_position: Vector2 = raw_position
	if next_position.x + _tooltip.size.x + TOOLTIP_EDGE_PADDING > viewport_size.x:
		next_position.x = raw_position.x - _tooltip.size.x - TOOLTIP_CURSOR_OFFSET.x * 1.5
	if next_position.y + _tooltip.size.y + TOOLTIP_EDGE_PADDING > viewport_size.y:
		next_position.y = viewport_size.y - _tooltip.size.y - TOOLTIP_EDGE_PADDING
	if next_position.x < TOOLTIP_EDGE_PADDING:
		next_position.x = TOOLTIP_EDGE_PADDING
	if next_position.y < TOOLTIP_EDGE_PADDING:
		next_position.y = TOOLTIP_EDGE_PADDING
	return next_position

func _make_tooltip_style() -> StyleBox:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.024, 0.020, 0.028, 0.985)
	style.border_color = Color(0.72, 0.46, 0.22, 0.95)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_right = 5
	style.corner_radius_bottom_left = 5
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	style.shadow_size = 14
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.62)
	return GothicUIAssets.style_or_fallback(GothicUIAssets.grid_panel_style(), style)

func _clear_tooltip() -> void:
	if _tooltip != null and is_instance_valid(_tooltip):
		_tooltip.queue_free()
	_tooltip = null

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
