extends Panel
class_name ItemTooltip

const ItemCatalog := preload("res://scripts/game/items/item_catalog.gd")
const ItemDef := preload("res://scripts/game/items/item_def.gd")
const PhaseRules := preload("res://scripts/game/items/phase_rules.gd")
const GothicUIAssets: GDScript = preload("res://scripts/ui/gothic_ui_assets.gd")

const TOOLTIP_WIDTH: float = 320.0
const PADDING: float = 18.0
const EDGE_PADDING: float = 12.0
const BOTTOM_UI_RESERVE: float = 236.0
const LEFT_PANEL_RESERVE: float = 340.0
const LEFT_PANEL_TOOLTIP_TOP: float = 164.0
const TOOLTIP_GROUP: String = "gothic_hover_tooltip"
const CURSOR_OFFSET: Vector2 = Vector2(18.0, -16.0)
const COLOR_PANEL: Color = Color(0.023, 0.019, 0.027, 0.985)
const COLOR_PANEL_INNER: Color = Color(0.047, 0.032, 0.040, 0.92)
const COLOR_BORDER: Color = Color(0.72, 0.46, 0.22, 0.95)
const COLOR_TEXT: Color = Color(0.91, 0.87, 0.78, 1.0)
const COLOR_MUTED: Color = Color(0.74, 0.68, 0.58, 1.0)
const COLOR_GOLD: Color = Color(0.96, 0.72, 0.34, 1.0)
const COLOR_BLOOD: Color = Color(0.90, 0.42, 0.24, 1.0)
const COLOR_STEEL: Color = Color(0.58, 0.68, 0.66, 1.0)

@onready var _background: ColorRect = $Background
@onready var _vbox: VBoxContainer = $VBox
@onready var _name_label: Label = $VBox/Name
@onready var _type_label: Label = $VBox/Type
@onready var _stats_label: Label = $VBox/Stats
@onready var _effects_label: Label = $VBox/Effects
@onready var _components_label: Label = $VBox/Components
@onready var _tags_label: Label = $VBox/Tags
@onready var _footer_label: Label = $VBox/Footer

var item_id: String = ""

func _ready() -> void:
	top_level = true
	focus_mode = Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 900
	add_to_group(TOOLTIP_GROUP)
	custom_minimum_size.x = TOOLTIP_WIDTH
	_apply_style()
	_update_labels()

func set_item_id(id: String) -> void:
	item_id = String(id)
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

func move_to(viewport_pos: Vector2) -> void:
	_sync_size()
	global_position = _clamped_position(viewport_pos + CURSOR_OFFSET)

func _apply_style() -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = COLOR_PANEL
	style.border_color = COLOR_BORDER
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
	add_theme_stylebox_override("panel", GothicUIAssets.style_or_fallback(GothicUIAssets.grid_panel_style(), style))
	if _background != null:
		_background.color = Color(COLOR_PANEL_INNER.r, COLOR_PANEL_INNER.g, COLOR_PANEL_INNER.b, 0.0)
	if _vbox != null:
		_vbox.add_theme_constant_override("separation", 7)
	var labels: Array[Variant] = [_name_label, _type_label, _stats_label, _effects_label, _components_label, _tags_label, _footer_label]
	for label_variant: Variant in labels:
		var label: Label = label_variant as Label
		if label == null:
			continue
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size.x = TOOLTIP_WIDTH - PADDING * 2.0
		label.add_theme_color_override("font_color", COLOR_TEXT)
	if _name_label != null:
		_name_label.add_theme_font_size_override("font_size", 18)
		_name_label.add_theme_color_override("font_color", COLOR_GOLD)
		_name_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.78))
		_name_label.add_theme_constant_override("outline_size", 1)
	if _type_label != null:
		_type_label.add_theme_font_size_override("font_size", 12)
		_type_label.add_theme_color_override("font_color", COLOR_MUTED)
	if _stats_label != null:
		_stats_label.add_theme_color_override("font_color", COLOR_TEXT)
	if _effects_label != null:
		_effects_label.add_theme_color_override("font_color", Color(0.88, 0.78, 0.65, 1.0))
	if _components_label != null:
		_components_label.add_theme_color_override("font_color", COLOR_STEEL)
	if _tags_label != null:
		_tags_label.add_theme_color_override("font_color", COLOR_MUTED)
	if _footer_label != null:
		_footer_label.add_theme_color_override("font_color", COLOR_BLOOD)

func _update_labels() -> void:
	var def: ItemDef = ItemCatalog.get_def(item_id)
	var clean_id: String = item_id.strip_edges()
	if clean_id == "":
		_set_empty_slot()
		return
	if def == null:
		_set_unknown_item(clean_id)
		return
	var stats_text: String = _format_stats(def)
	var effects_text: String = _format_effects(def)
	var components_text: String = _format_components(def)
	var tags_text: String = _format_tags(def)
	_set_label(_name_label, _display_name(def), true)
	_set_label(_type_label, _type_label_text(def), true)
	_set_label(_stats_label, stats_text, not stats_text.is_empty())
	_set_label(_effects_label, effects_text, not effects_text.is_empty())
	_set_label(_components_label, components_text, not components_text.is_empty())
	_set_label(_tags_label, tags_text, not tags_text.is_empty())
	_set_label(_footer_label, _footer_text(def), true)
	_sync_size()

func _set_empty_slot() -> void:
	_set_label(_name_label, "Empty Item Slot", true)
	_set_label(_type_label, "INVENTORY SOCKET", true)
	_set_label(_stats_label, "", false)
	_set_label(_effects_label, "No relic is stored here.", true)
	_set_label(_components_label, "", false)
	_set_label(_tags_label, "", false)
	_set_label(_footer_label, "Drop items here or combine matching components.", true)
	_sync_size()

func _set_unknown_item(clean_id: String) -> void:
	_set_label(_name_label, clean_id, true)
	_set_label(_type_label, "UNKNOWN RELIC", true)
	_set_label(_stats_label, "", false)
	_set_label(_effects_label, "Item definition was not found.", true)
	_set_label(_components_label, "", false)
	_set_label(_tags_label, "", false)
	_set_label(_footer_label, "Check item catalog data for this id.", true)
	_sync_size()

func _display_name(def: ItemDef) -> String:
	if String(def.name).strip_edges() != "":
		return String(def.name)
	return String(def.id)

func _type_label_text(def: ItemDef) -> String:
	var item_type: String = String(def.type).strip_edges().to_lower()
	match item_type:
		"completed":
			return "COMPLETED RELIC"
		"component":
			return "COMPONENT"
		"special":
			return "SPECIAL TOOL"
		_:
			return item_type.to_upper()

func _format_stats(def: ItemDef) -> String:
	var mods: Dictionary[String, Variant] = {}
	if def.stat_mods != null:
		for key_variant: Variant in def.stat_mods.keys():
			mods[String(key_variant)] = def.stat_mods[key_variant]
	if mods.is_empty():
		return ""
	var keys: Array[String] = []
	for key_variant: Variant in mods.keys():
		keys.append(String(key_variant))
	keys.sort()
	var lines: PackedStringArray = PackedStringArray()
	lines.append("Stats")
	for key: String in keys:
		lines.append("%s %s" % [_format_stat_value(key, mods[key]), _stat_name(key)])
	return "\n".join(lines)

func _format_stat_value(key: String, value: Variant) -> String:
	var amount: float = float(value)
	if key.begins_with("pct_"):
		return "%+d%%" % int(round(amount * 100.0))
	return "%+d" % int(round(amount))

func _stat_name(key: String) -> String:
	var names: Dictionary[String, String] = {
		"pct_ad": "Attack Damage",
		"pct_as": "Attack Speed",
		"pct_crit_chance": "Critical Chance",
		"pct_omnivamp": "Omnivamp",
		"flat_sp": "Spell Power",
		"flat_armor": "Armor",
		"flat_mr": "Magic Resist",
		"flat_hp": "Health",
		"flat_mana_regen": "Mana Regen",
		"flat_start_mana": "Starting Mana"
	}
	if names.has(key):
		return names[key]
	return _humanize_id(key)

func _format_effects(def: ItemDef) -> String:
	if def.effects.is_empty():
		return ""
	var effects: PackedStringArray = PackedStringArray()
	for effect_id: String in def.effects:
		effects.append(_humanize_id(effect_id))
	return "Effect: %s" % ", ".join(effects)

func _format_components(def: ItemDef) -> String:
	if def.components.is_empty():
		return ""
	var names: PackedStringArray = PackedStringArray()
	for component_id: String in def.components:
		var component_def: ItemDef = ItemCatalog.get_def(component_id)
		if component_def != null:
			names.append(_display_name(component_def))
		else:
			names.append(_humanize_id(component_id))
	return "Recipe: %s" % " + ".join(names)

func _format_tags(def: ItemDef) -> String:
	if def.tags.is_empty():
		return ""
	var tags: PackedStringArray = PackedStringArray()
	for tag: String in def.tags:
		tags.append(_humanize_id(tag))
	return "Best for: %s" % ", ".join(tags)

func _footer_text(def: ItemDef) -> String:
	if String(def.id) == "remover" and not PhaseRules.can_remove():
		return "Locked during combat."
	if String(def.type) == "component":
		return "Combines into completed relics."
	if String(def.type) == "completed":
		return "Drag onto a unit to equip."
	return "Single-use inventory tool."

func _humanize_id(value: String) -> String:
	var text: String = String(value).strip_edges().replace("_", " ").replace("-", " ")
	var words: PackedStringArray = text.split(" ", false)
	var out: PackedStringArray = PackedStringArray()
	for word: String in words:
		if word.length() == 0:
			continue
		out.append(word.substr(0, 1).to_upper() + word.substr(1).to_lower())
	return " ".join(out)

func _set_label(label: Label, text: String, should_show: bool) -> void:
	if label == null:
		return
	label.text = text
	label.visible = should_show and text.strip_edges() != ""

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
	size.y = max(desired_height, 96.0)

func _clamped_position(raw_position: Vector2) -> Vector2:
	var viewport: Viewport = get_viewport()
	if viewport == null:
		return raw_position
	var viewport_size: Vector2 = viewport.get_visible_rect().size
	var new_position: Vector2 = raw_position
	if viewport_size.x >= 1200.0 and new_position.x < LEFT_PANEL_RESERVE:
		new_position.x = EDGE_PADDING
		new_position.y = min(new_position.y, LEFT_PANEL_TOOLTIP_TOP)
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
