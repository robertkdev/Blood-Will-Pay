extends Button
class_name ShopCard

const TextureUtils := preload("res://scripts/util/texture_utils.gd")
const TraitIconScene := preload("res://scenes/ui/traits/TraitIcon.tscn")
const AbilityCatalog := preload("res://scripts/game/abilities/ability_catalog.gd")
const UnitFactory := preload("res://scripts/unit_factory.gd")
const UnitTargetingText := preload("res://scripts/ui/unit_targeting_text.gd")
const UnitUpgradePaths := preload("res://scripts/game/units/unit_upgrade_paths.gd")
const GothicUIAssets: GDScript = preload("res://scripts/ui/gothic_ui_assets.gd")
const HardcoreUIAssets: GDScript = preload("res://scripts/ui/hardcore_ui_assets.gd")
const VisualTypeSystem: GDScript = preload("res://scripts/ui/visual_type_system.gd")
const UserSettingsScript: GDScript = preload("res://scripts/game/settings/user_settings.gd")

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
var _tooltip_title: String = ""
var _tooltip_subtitle: String = ""
var _tooltip_lines: Array[String] = []
var _status_tip: String = ""
var _package_level: int = 1
var _package_kind: String = "standard"
var _price_value: int = 0

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
	_tooltip_subtitle = "%d blood • %s Lv%d" % [price_i, "Current Grade" if _package_kind == "current_grade" else "Depth Grade", _package_level] if _package_kind != "standard" else "%d blood" % price_i
	_tooltip_lines = _build_tooltip_lines(display_role, display_goal, approaches, alt_goals, traits)
	if _package_kind == "current_grade":
		var capital_charter: Dictionary = UnitUpgradePaths.charter_definition(UnitUpgradePaths.charter_for_role(primary_role))
		_tooltip_subtitle = "%d blood • CAPITAL Lv%d" % [price_i, _package_level]
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

func set_compact_presentation(enabled: bool, tight: bool = false) -> void:
	_compact_presentation = enabled
	_tight_presentation = enabled and tight
	set_meta("compact_tooltip_policy", "suppress_hover" if enabled else "full_detail")
	set_meta("tooltip_suppressed_for_compact", enabled)
	if _tooltip != null and is_instance_valid(_tooltip):
		_clear_tooltip()
	if enabled:
		_clear_global_tooltip_layers()
	custom_minimum_size = Vector2(120.0, 54.0) if _tight_presentation else Vector2(132.0, 80.0) if enabled else Vector2(150.0, 122.0)
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	set_meta("shop_safe_bottom_gutter", 2.0 if _tight_presentation else 6.0 if enabled else 16.0)
	if _icon != null:
		_icon.custom_minimum_size = Vector2.ZERO if enabled else Vector2(112.0, 112.0)
		_icon.anchor_left = 0.10 if _tight_presentation else 0.08 if enabled else 0.12
		_icon.anchor_top = 0.04 if _tight_presentation else 0.05 if enabled else 0.21
		_icon.anchor_right = 0.90 if _tight_presentation else 0.92 if enabled else 0.88
		_icon.anchor_bottom = 0.61 if _tight_presentation else 0.66 if enabled else 0.78
	if _traits_box != null:
		_traits_box.visible = false
		_traits_box.custom_minimum_size = Vector2.ZERO if enabled else Vector2(0.0, 48.0)
	if _identity_panel != null:
		_identity_panel.visible = false if enabled else _has_identity_content
		_identity_panel.custom_minimum_size = Vector2.ZERO
	if _name_label != null:
		_name_label.anchor_left = 0.0
		_name_label.anchor_top = 0.61 if _tight_presentation else 0.66 if enabled else 1.0
		_name_label.anchor_right = 0.72 if enabled else 0.76
		_name_label.anchor_bottom = 1.0
		_name_label.offset_left = 4.0 if enabled else 8.0
		_name_label.offset_top = 0.0 if enabled else -23.0
		_name_label.offset_right = -2.0 if enabled else -4.0
		_name_label.offset_bottom = -2.0
		_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_name_label.clip_text = enabled
		_name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS if enabled else TextServer.OVERRUN_NO_TRIMMING
		_name_label.add_theme_font_size_override("font_size", 14 if _tight_presentation else 16 if enabled else 20)
	if _price_label != null:
		_price_label.text = _price_copy()
		_price_label.anchor_left = 0.72 if enabled else 0.76
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
	set_meta("compact_presentation", enabled)
	set_meta("tight_presentation", _tight_presentation)

func _price_copy() -> String:
	return "B%d" % _price_value if _compact_presentation else "%d blood" % _price_value

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
		_role_badge.add_theme_font_size_override("font_size", 16)
		VisualTypeSystem.set_action(_role_badge)
		_role_badge.add_theme_color_override("font_color", COLOR_GOLD)
		_role_badge.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.70))
		_role_badge.add_theme_constant_override("outline_size", 1)
	if _goal_label:
		_goal_label.add_theme_color_override("font_color", COLOR_MUTED)
	if _name_label:
		_name_label.z_index = 6
		_name_label.add_theme_font_size_override("font_size", 20)
		VisualTypeSystem.set_utility_bold(_name_label)
		_name_label.add_theme_color_override("font_color", COLOR_TEXT)
		_name_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.82))
		_name_label.add_theme_constant_override("outline_size", 1)
	if _price_label:
		_price_label.z_index = 6
		_price_label.add_theme_font_size_override("font_size", 20)
		VisualTypeSystem.set_action(_price_label)
		_price_label.add_theme_color_override("font_color", COLOR_GOLD)
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
	return style

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
			_icon.modulate = Color(1.0, 0.93, 0.78, 1.0)
	else:
		if _icon != null:
			_icon.modulate = Color(0.96, 0.91, 0.84, 1.0)

func _show_tooltip() -> void:
	_clear_tooltip()
	set_meta("tooltip_suppressed_for_compact", false)
	if not is_inside_tree():
		return
	_clear_global_tooltip_layers()
	if _compact_presentation:
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
	tooltip.clip_contents = _compact_presentation
	tooltip.z_index = 950
	tooltip.set_meta("source_card_instance_id", get_instance_id())
	tooltip.set_meta("source_offer_id", offer_id)
	tooltip.set_meta("presentation_mode", "pinned_shop_band" if _compact_presentation else "cursor_detail")
	tooltip.set_meta("non_obstructive_region", "shop_grid_band" if _compact_presentation else "viewport_edge")
	tooltip.set_meta("information_access", "vertical_scroll_complete" if _compact_presentation else "fully_expanded")
	tooltip.set_meta("detail_line_count", lines.size() + 2)
	if _compact_presentation:
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
	box.add_theme_constant_override("separation", 2 if _compact_presentation else 5)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _compact_presentation:
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
	label.custom_minimum_size.x = 0.0 if _compact_presentation else TOOLTIP_WIDTH - 24.0
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var presentation_font_size: int = mini(font_size, 15) if _compact_presentation else font_size
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
	if _compact_presentation:
		_tooltip.global_position = _shop_band_rect().position
		return
	_tooltip.global_position = _clamped_tooltip_position(viewport_pos + TOOLTIP_CURSOR_OFFSET)

func _sync_tooltip_size() -> void:
	if _tooltip == null or not is_instance_valid(_tooltip):
		return
	if _compact_presentation:
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
	if not _compact_presentation:
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
	return GothicUIAssets.style_or_fallback(HardcoreUIAssets.texture_style(HardcoreUIAssets.GOTHIC_V3_ROOT + "utility_tooltip.png", Vector4(28.0, 24.0, 28.0, 24.0), Vector4(12.0, 10.0, 12.0, 10.0)), style)

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
