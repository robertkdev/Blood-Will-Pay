extends Control
class_name UnitSelect

signal unit_selected(unit_id: String)

const UnitCatalog := preload("res://scripts/game/shop/unit_catalog.gd")
const ShopConfig := preload("res://scripts/game/shop/shop_config.gd")
const AbilityCatalog := preload("res://scripts/game/abilities/ability_catalog.gd")
const UnitTargetingText := preload("res://scripts/ui/unit_targeting_text.gd")
const UnitFactory := preload("res://scripts/unit_factory.gd")
const TextureUtils := preload("res://scripts/util/texture_utils.gd")
const GothicUIAssets: GDScript = preload("res://scripts/ui/gothic_ui_assets.gd")

const COLOR_VOID: Color = Color(0.012, 0.010, 0.014, 1.0)
const COLOR_PANEL: Color = Color(0.034, 0.029, 0.039, 0.94)
const COLOR_PANEL_DEEP: Color = Color(0.018, 0.015, 0.023, 0.98)
const COLOR_TEXT: Color = Color(0.91, 0.87, 0.78, 1.0)
const COLOR_MUTED: Color = Color(0.65, 0.60, 0.53, 1.0)
const COLOR_GOLD: Color = Color(0.92, 0.66, 0.32, 1.0)
const COLOR_BLOOD: Color = Color(0.52, 0.040, 0.080, 1.0)
const COLOR_BLOOD_HOT: Color = Color(0.82, 0.070, 0.120, 1.0)
const FULL_LAYOUT_SIZE: Vector2 = Vector2(1320.0, 900.0)
const COMPACT_VIEWPORT_HEIGHT: float = 780.0
const IDENTITY_PANEL_MIN_HEIGHT: float = 96.0
const START_BUTTON_READY_TEXT: String = "Start Game"
const START_BUTTON_PENDING_TEXT: String = "Preparing Battle..."

@onready var background: ColorRect = $Background
@onready var hbox: HBoxContainer = $Center/HBox
@onready var left_column: VBoxContainer = $Center/HBox/Left
@onready var right_column: VBoxContainer = $Center/HBox/Right
@onready var heading_label: Label = $Center/HBox/Left/Label
@onready var scroll: ScrollContainer = $Center/HBox/Left/Scroll
@onready var grid: GridContainer = $Center/HBox/Left/Scroll/Grid
@onready var start_button: Button = $Center/HBox/Right/StartButton

var selected_label: Label = null
var preview_art: TextureRect = null
var details_scroll: ScrollContainer = null
var details_label: Label = null
var help_label: Label = null
var identity_panel: VBoxContainer = null
var identity_role_label: Label = null
var identity_goal_label: Label = null
var identity_approach_tags: FlowContainer = null

var items: Array[Dictionary] = []
var items_by_id: Dictionary[String, Dictionary] = {}
var buttons_by_id: Dictionary[String, Button] = {}
var _preview_units_by_id: Dictionary[String, Unit] = {}
var selected_id: String = ""
var button_group: ButtonGroup = ButtonGroup.new()
var grid_wrap: CenterContainer = null
var _hovered_id: String = ""
var _start_button_hover_tween: Tween = null
var _left_plate: Panel = null
var _right_plate: Panel = null
var _preview_art_plate: Panel = null
var _plate_reposition_queued: bool = false
var _last_scroll_bar_value: float = 0.0

func _ready() -> void:
	_ensure_grid_wrapper()
	_ensure_preview_panel()
	_apply_gothic_layout()
	_wire_start_button_hover()
	start_button.disabled = true
	start_button.text = START_BUTTON_READY_TEXT
	if help_label:
		help_label.visible = true
	if not start_button.is_connected("pressed", Callable(self, "_on_StartButton_pressed")):
		start_button.pressed.connect(_on_StartButton_pressed)
	_wire_scroll_observers()
	set_process(true)
	resized.connect(_on_resized)
	_populate_units()
	_on_resized()

func _process(_delta: float) -> void:
	if scroll == null:
		return
	var scroll_bar: VScrollBar = scroll.get_v_scroll_bar()
	if scroll_bar == null:
		return
	var current_value: float = float(scroll_bar.value)
	if absf(current_value - _last_scroll_bar_value) < 0.5:
		return
	_last_scroll_bar_value = current_value
	_clear_hover_for_scroll()

func _wire_scroll_observers() -> void:
	if scroll == null:
		return
	var scroll_bar: VScrollBar = scroll.get_v_scroll_bar()
	if scroll_bar == null:
		return
	_last_scroll_bar_value = float(scroll_bar.value)
	if not scroll_bar.is_connected("value_changed", Callable(self, "_on_scroll_changed")):
		scroll_bar.value_changed.connect(_on_scroll_changed)

func _ensure_preview_panel() -> void:
	var right: VBoxContainer = $"Center/HBox/Right"
	if right == null:
		return
	var legacy: Label = right.get_node_or_null("SelectedLabel") as Label
	if legacy:
		legacy.visible = false
	var preview: VBoxContainer = right.get_node_or_null("Preview") as VBoxContainer
	if preview == null:
		preview = VBoxContainer.new()
		preview.name = "Preview"
		preview.add_theme_constant_override("separation", 10)
		preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
		right.add_child(preview)
	selected_label = preview.get_node_or_null("SelectedLabel") as Label
	if selected_label == null:
		selected_label = Label.new()
		selected_label.name = "SelectedLabel"
		selected_label.text = "No champion chosen"
		preview.add_child(selected_label)
	_ensure_identity_panel(preview)
	var art_wrap: CenterContainer = preview.get_node_or_null("ArtWrap") as CenterContainer
	if art_wrap == null:
		var old_art: Node = preview.get_node_or_null("Art")
		if old_art:
			preview.remove_child(old_art)
			old_art.queue_free()
		art_wrap = CenterContainer.new()
		art_wrap.name = "ArtWrap"
		art_wrap.custom_minimum_size = Vector2(380, 300)
		preview.add_child(art_wrap)
	preview_art = art_wrap.get_node_or_null("Art") as TextureRect
	if preview_art == null:
		preview_art = TextureRect.new()
		preview_art.name = "Art"
		preview_art.custom_minimum_size = Vector2(360, 360)
		preview_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		preview_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		preview_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art_wrap.add_child(preview_art)
	details_scroll = preview.get_node_or_null("DetailsScroll") as ScrollContainer
	if details_scroll == null:
		details_scroll = ScrollContainer.new()
		details_scroll.name = "DetailsScroll"
		details_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		preview.add_child(details_scroll)
	details_label = details_scroll.get_node_or_null("Details") as Label
	var legacy_details: Label = preview.get_node_or_null("Details") as Label
	if details_label == null and legacy_details != null:
		preview.remove_child(legacy_details)
		details_scroll.add_child(legacy_details)
		details_label = legacy_details
	if details_label == null:
		details_label = Label.new()
		details_label.name = "Details"
		details_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		details_label.text = "Hover a unit to preview"
		details_scroll.add_child(details_label)
	help_label = right.get_node_or_null("HelpLabel") as Label
	if help_label == null:
		help_label = Label.new()
		help_label.name = "HelpLabel"
		help_label.text = "Select a unit to continue"
		right.add_child(help_label)
	right.custom_minimum_size = Vector2(500, 0)
	right.size_flags_horizontal = 0
	start_button.size_flags_vertical = 0
	right.move_child(preview, 0)
	right.move_child(start_button, right.get_child_count() - 1)

func _apply_gothic_layout() -> void:
	if background:
		background.color = COLOR_VOID
		if background.material is ShaderMaterial:
			var mat: ShaderMaterial = background.material as ShaderMaterial
			mat.set_shader_parameter("top_color", Color(0.034, 0.026, 0.036, 1.0))
			mat.set_shader_parameter("bottom_color", Color(0.006, 0.005, 0.008, 1.0))
			mat.set_shader_parameter("vignette", 0.48)
			mat.set_shader_parameter("vignette_softness", 0.62)
	if hbox:
		hbox.custom_minimum_size = Vector2(1320.0, 900.0)
		hbox.add_theme_constant_override("separation", 34)
	if left_column:
		left_column.custom_minimum_size = Vector2(760.0, 880.0)
		left_column.add_theme_constant_override("separation", 14)
		_left_plate = _ensure_float_plate(left_column, "GothicRosterPlate", GothicUIAssets.style_or_fallback(GothicUIAssets.wide_panel_style(), _make_panel_style(COLOR_PANEL, Color(0.36, 0.29, 0.27, 0.86), 1, 7)), -2, 10.0)
	if right_column:
		right_column.custom_minimum_size = Vector2(500.0, 880.0)
		right_column.add_theme_constant_override("separation", 16)
		_right_plate = _ensure_float_plate(right_column, "GothicPreviewPlate", GothicUIAssets.style_or_fallback(GothicUIAssets.wide_panel_style(), _make_panel_style(Color(0.030, 0.025, 0.034, 0.96), Color(0.48, 0.34, 0.25, 0.88), 1, 7)), -2, 10.0)
	if heading_label:
		heading_label.text = "Choose Your Starting Unit"
		heading_label.add_theme_font_size_override("font_size", 38)
		heading_label.add_theme_color_override("font_color", COLOR_TEXT)
		heading_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.76))
		heading_label.add_theme_constant_override("outline_size", 3)
		heading_label.custom_minimum_size = Vector2(0.0, 70.0)
		heading_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if scroll:
		scroll.custom_minimum_size = Vector2(720.0, 800.0)
		scroll.clip_contents = true
		scroll.add_theme_stylebox_override("focus", _make_panel_style(Color(0.0, 0.0, 0.0, 0.0), COLOR_GOLD, 1, 4))
	if grid_wrap:
		grid_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid_wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
		grid_wrap.custom_minimum_size = Vector2(max(720.0, float(scroll.size.x)), 0.0)
	if grid:
		grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		grid.add_theme_constant_override("h_separation", 12)
		grid.add_theme_constant_override("v_separation", 14)
	if selected_label:
		selected_label.custom_minimum_size = Vector2(500.0, 64.0)
		selected_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		selected_label.add_theme_font_size_override("font_size", 32)
		selected_label.add_theme_color_override("font_color", COLOR_TEXT)
		selected_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.70))
		selected_label.add_theme_constant_override("outline_size", 2)
	if identity_goal_label:
		identity_goal_label.add_theme_color_override("font_color", COLOR_MUTED)
	if details_label:
		details_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		details_label.add_theme_font_size_override("font_size", 16)
		details_label.add_theme_color_override("font_color", COLOR_MUTED)
	if details_scroll:
		details_scroll.custom_minimum_size = Vector2(500.0, 126.0)
		details_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if help_label:
		help_label.add_theme_font_size_override("font_size", 16)
		help_label.add_theme_color_override("font_color", COLOR_MUTED)
	if preview_art:
		preview_art.custom_minimum_size = Vector2(360.0, 360.0)
		preview_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		preview_art.modulate = Color(0.92, 0.88, 0.82, 1.0)
	var art_wrap: Control = right_column.get_node_or_null("Preview/ArtWrap") as Control
	if art_wrap:
		art_wrap.custom_minimum_size = Vector2(430.0, 360.0)
		_preview_art_plate = _ensure_float_plate(art_wrap, "GothicArtPlate", GothicUIAssets.style_or_fallback(GothicUIAssets.grid_panel_style(), _make_panel_style(Color(0.014, 0.012, 0.018, 0.86), Color(0.32, 0.24, 0.23, 0.84), 1, 6)), -1, 8.0)
		if not art_wrap.resized.is_connected(Callable(self, "_queue_gothic_plate_reposition")):
			art_wrap.resized.connect(_queue_gothic_plate_reposition)
	if right_column != null and not right_column.sort_children.is_connected(Callable(self, "_queue_gothic_plate_reposition")):
		right_column.sort_children.connect(_queue_gothic_plate_reposition)
	_queue_gothic_plate_reposition()
	_style_start_button()

func _ensure_grid_wrapper() -> void:
	if scroll == null or grid == null:
		return
	grid_wrap = scroll.get_node_or_null("GridWrap") as CenterContainer
	if grid_wrap == null:
		grid_wrap = CenterContainer.new()
		grid_wrap.name = "GridWrap"
		scroll.remove_child(grid)
		scroll.add_child(grid_wrap)
		grid_wrap.add_child(grid)
	grid_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid_wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

func _ensure_identity_panel(preview: VBoxContainer) -> void:
	identity_panel = preview.get_node_or_null("IdentityPanel") as VBoxContainer
	if identity_panel == null:
		identity_panel = VBoxContainer.new()
		identity_panel.name = "IdentityPanel"
		identity_panel.add_theme_constant_override("separation", 4)
		preview.add_child(identity_panel)
	# Keep this slot in the VBox layout even when its labels are empty. Hiding the
	# container made ArtWrap jump vertically whenever a card gained/lost hover.
	identity_panel.visible = true
	identity_panel.custom_minimum_size = Vector2(0.0, IDENTITY_PANEL_MIN_HEIGHT)
	identity_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if selected_label:
		var index: int = selected_label.get_index() + 1
		preview.move_child(identity_panel, min(index, preview.get_child_count() - 1))
	identity_role_label = identity_panel.get_node_or_null("RoleBadge") as Label
	if identity_role_label == null:
		identity_role_label = Label.new()
		identity_role_label.name = "RoleBadge"
		identity_role_label.uppercase = true
		identity_role_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		identity_role_label.modulate = Color(1, 1, 1, 0.95)
		identity_panel.add_child(identity_role_label)
	identity_role_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	identity_role_label.custom_minimum_size = Vector2(132.0, 0.0)
	identity_role_label.add_theme_stylebox_override("normal", _make_badge_style())
	identity_role_label.add_theme_font_size_override("font_size", 13)
	identity_role_label.add_theme_color_override("font_color", COLOR_TEXT)
	identity_goal_label = identity_panel.get_node_or_null("GoalLabel") as Label
	if identity_goal_label == null:
		identity_goal_label = Label.new()
		identity_goal_label.name = "GoalLabel"
		identity_goal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		identity_goal_label.add_theme_font_size_override("font_size", 18)
		identity_goal_label.modulate = Color(1, 1, 1, 0.9)
		identity_panel.add_child(identity_goal_label)
	identity_approach_tags = identity_panel.get_node_or_null("ApproachTags") as FlowContainer
	if identity_approach_tags == null:
		identity_approach_tags = FlowContainer.new()
		identity_approach_tags.name = "ApproachTags"
		identity_approach_tags.vertical = false
		identity_approach_tags.add_theme_constant_override("h_separation", 6)
		identity_approach_tags.add_theme_constant_override("v_separation", 4)
		identity_panel.add_child(identity_approach_tags)

func show_screen() -> void:
	visible = true
	_apply_gothic_layout()
	_style_unit_cards()
	start_button.disabled = selected_id == ""
	if help_label:
		help_label.visible = start_button.disabled
	_on_resized()

func hide_screen() -> void:
	visible = false

func reset_selection() -> void:
	selected_id = ""
	_hovered_id = ""
	for unit_id: String in buttons_by_id.keys():
		var button: Button = buttons_by_id.get(unit_id, null) as Button
		if button == null:
			continue
		button.button_pressed = false
		button.scale = Vector2.ONE
		button.z_index = 0
		if button.has_meta("hover_tween"):
			var hover_tween: Tween = button.get_meta("hover_tween") as Tween
			if hover_tween != null and is_instance_valid(hover_tween):
				hover_tween.kill()
	if start_button != null:
		start_button.disabled = true
		start_button.scale = Vector2.ONE
		_style_start_button()
	if help_label != null:
		help_label.visible = true
	_clear_preview()
	_style_unit_cards()

func _populate_units() -> void:
	items.clear()
	items_by_id.clear()
	buttons_by_id.clear()
	_preview_units_by_id.clear()
	for child in grid.get_children():
		child.queue_free()
	# Use catalog to obtain starter-eligible units at starting level
	var catalog: UnitCatalog = UnitCatalog.new()
	catalog.refresh()
	var level: int = int(ShopConfig.STARTING_LEVEL)
	var ids: Array[String] = catalog.list_starter_ids(level)
	var meta_items: Array[Dictionary] = []
	for uid: String in ids:
		var meta: Dictionary = catalog.get_unit_meta(String(uid))
		if meta.is_empty():
			continue
		var entry: Dictionary = meta.duplicate(true)
		entry["id"] = String(uid)
		meta_items.append(entry)
	# Sort by name for display
	meta_items.sort_custom(func(a, b): return String(a.get("name", "")).nocasecmp_to(String(b.get("name", ""))) < 0)
	items = meta_items
	for it: Dictionary in items:
		var uid2: String = String(it.get("id", ""))
		if uid2 == "":
			continue
		items_by_id[uid2] = it
		var tile: VBoxContainer = VBoxContainer.new()
		tile.name = "UnitCard_%s" % _node_safe_id(uid2)
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tile.custom_minimum_size = Vector2(150, 184)
		tile.add_theme_constant_override("separation", 4)
		var btn: Button = Button.new()
		btn.name = "UnitButton_%s" % _node_safe_id(uid2)
		btn.toggle_mode = true
		btn.button_group = button_group
		btn.focus_mode = Control.FOCUS_ALL
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn.expand_icon = true
		btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		btn.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
		btn.custom_minimum_size = Vector2(150, 138)
		btn.set_meta("unit_id", uid2)
		var sp: String = String(it.get("sprite_path", ""))
		if sp != "":
			var icon: Texture2D = TextureUtils.try_load_texture(sp)
			if icon:
				btn.icon = icon
		var name_label: Label = Label.new()
		name_label.name = "UnitName"
		name_label.text = String(it.get("name", ""))
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var role_label: Label = Label.new()
		role_label.name = "UnitRole"
		role_label.text = _format_role(String(it.get("primary_role", ""))).to_upper()
		role_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tile.add_child(btn)
		tile.add_child(name_label)
		tile.add_child(role_label)
		btn.pressed.connect(_on_unit_button_pressed.bind(btn, uid2, String(it.get("name", ""))))
		btn.mouse_entered.connect(_on_unit_hovered.bind(uid2))
		btn.mouse_exited.connect(_on_unit_unhovered)
		btn.focus_entered.connect(_on_unit_hovered.bind(uid2))
		btn.focus_exited.connect(_on_unit_unhovered)
		grid.add_child(tile)
		buttons_by_id[uid2] = btn
		_style_unit_card(tile, btn, name_label, role_label, false)
	_style_unit_cards()
	if selected_id == "":
		_clear_preview()

func _unit_entry_from_resource(res: Resource) -> Dictionary:
	var id: String = ""
	var display_name: String = ""
	var sprite_path: String = ""
	var roles: PackedStringArray = PackedStringArray()
	var traits: PackedStringArray = PackedStringArray()
	var primary_role: String = ""
	var primary_goal: String = ""
	var approaches: PackedStringArray = PackedStringArray()
	var alt_goals: PackedStringArray = PackedStringArray()
	if res is UnitProfile:
		var p: UnitProfile = res
		id = String(p.id)
		display_name = String(p.name)
		sprite_path = String(p.sprite_path)
		roles = p.role_names()
		traits = PackedStringArray(p.traits)
		primary_role = _normalize_role(p.primary_role)
		primary_goal = _normalize_key(p.primary_goal)
		approaches = PackedStringArray(p.approaches)
		alt_goals = PackedStringArray(p.alt_goals)
		if p.identity != null:
			primary_role = _normalize_role(p.identity.primary_role)
			primary_goal = _normalize_key(p.identity.primary_goal)
			approaches = PackedStringArray(p.identity.approaches)
			alt_goals = PackedStringArray(p.identity.alt_goals)
	else:
		return {}
	if id == "":
		return {}
	if primary_role == "" and roles.size() > 0:
		primary_role = _normalize_role(roles[0])
	return {
		"id": id,
		"name": display_name,
		"sprite_path": sprite_path,
		"roles": roles,
		"traits": traits,
		"primary_role": primary_role,
		"primary_goal": primary_goal,
		"approaches": approaches,
		"alt_goals": alt_goals,
	}

func _on_unit_button_pressed(_btn: Button, id: String, _name: String) -> void:
	selected_id = id
	_update_preview(id, true)
	start_button.disabled = false
	_style_start_button()
	_style_unit_cards()
	if help_label:
		help_label.visible = false

func _on_StartButton_pressed() -> void:
	if selected_id == "":
		return
	emit_signal("unit_selected", selected_id)

func set_transition_pending(pending: bool) -> void:
	if start_button == null:
		return
	start_button.text = START_BUTTON_PENDING_TEXT if pending else START_BUTTON_READY_TEXT
	start_button.disabled = pending or selected_id == ""
	if pending:
		start_button.release_focus()
	if is_inside_tree():
		_style_start_button()

func _on_unit_hovered(id: String) -> void:
	if id != "":
		if _hovered_id != id and _hovered_id != "":
			_apply_unit_button_motion(_hovered_id, false)
		_hovered_id = id
		_apply_unit_button_motion(id, true)
		_update_preview(id, false)
		_style_unit_cards()

func _update_preview(id: String, is_selected: bool = false) -> void:
	if selected_label == null:
		return
	var it: Dictionary = items_by_id.get(id, {})
	if it.is_empty():
		_clear_preview()
		return
	var display_name: String = String(it.get("name", ""))
	selected_label.text = ("%s" if is_selected else "Inspecting %s") % [display_name]
	var role_text: String = _format_role(String(it.get("primary_role", "")))
	var goal_text: String = _format_goal(String(it.get("primary_goal", "")))
	var approach_arr: Array = _duplicate_strings(it.get("approaches", PackedStringArray()))
	_set_identity_summary(role_text, goal_text, approach_arr)
	var sp: String = String(it.get("sprite_path", ""))
	if preview_art:
		preview_art.texture = TextureUtils.try_load_texture(sp) if sp != "" else null
	if details_label:
		var lines: Array[String] = _build_detail_lines(id, it)
		details_label.text = "\n".join(lines)
	_queue_gothic_plate_reposition()

func _build_detail_lines(id: String, it: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	var traits: Array = _duplicate_strings(it.get("traits", PackedStringArray()))
	var trait_text: String = _format_list(traits, 5)
	if trait_text == "":
		trait_text = _format_list(_duplicate_strings(it.get("approaches", PackedStringArray())), 5)
	if trait_text != "":
		lines.append("Traits: %s" % trait_text)
	lines.append("Cost: %dg" % int(it.get("cost", 0)))
	var alt_goals: String = _format_list(_duplicate_strings(it.get("alt_goals", PackedStringArray())), 3)
	if alt_goals != "":
		lines.append("Alt Goals: %s" % alt_goals)
	var preview_unit: Unit = _preview_unit(id)
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
	if lines.is_empty():
		lines.append("No preview details available.")
	return lines

func _preview_unit(id: String) -> Unit:
	var clean_id: String = String(id).strip_edges()
	if clean_id == "":
		return null
	if _preview_units_by_id.has(clean_id):
		return _preview_units_by_id[clean_id]
	var unit: Unit = UnitFactory.spawn(clean_id)
	if unit != null:
		_preview_units_by_id[clean_id] = unit
	return unit

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
		return "Ability: %s" % _format_token(ability_id)
	var ability_name: String = String(ability_def.name).strip_edges()
	if ability_name == "":
		ability_name = _format_token(ability_id)
	var prefix: String = "Ability: %s" % ability_name
	if int(ability_def.base_cost) > 0:
		prefix += " (%d mana)" % int(ability_def.base_cost)
	var description: String = String(ability_def.description).strip_edges()
	if description != "":
		return "%s - %s" % [prefix, description]
	return prefix

func _on_unit_unhovered() -> void:
	if _hovered_id != "":
		_apply_unit_button_motion(_hovered_id, false)
		_hovered_id = ""
		_style_unit_cards()
	if selected_id != "":
		_update_preview(selected_id, true)
		return
	_clear_preview()

func _on_scroll_changed(_value: float) -> void:
	_last_scroll_bar_value = float(_value)
	_clear_hover_for_scroll()

func _clear_hover_for_scroll() -> void:
	if _hovered_id != "":
		_apply_unit_button_motion(_hovered_id, false)
		_hovered_id = ""
		_style_unit_cards()
	if selected_id != "":
		_update_preview(selected_id, true)
	else:
		_clear_preview()

func _clear_preview() -> void:
	if selected_label:
		selected_label.text = "No champion chosen"
	if preview_art:
		preview_art.texture = null
	_clear_identity_panel()
	if details_label:
		details_label.text = "Hover a unit to preview"
	_queue_gothic_plate_reposition()

func _set_identity_summary(role_text: String, goal_text: String, approaches: Array) -> void:
	var show_role: bool = role_text.strip_edges() != ""
	if identity_role_label:
		identity_role_label.text = role_text
		identity_role_label.visible = show_role
	var show_goal: bool = goal_text.strip_edges() != ""
	if identity_goal_label:
		identity_goal_label.text = goal_text
		identity_goal_label.visible = show_goal
	_set_identity_approach_tags(approaches)
	if identity_panel:
		identity_panel.visible = true

func _set_identity_approach_tags(approaches: Array) -> bool:
	if identity_approach_tags == null:
		return false
	for child in identity_approach_tags.get_children():
		child.queue_free()
	var seen: Dictionary[String, bool] = {}
	var shown: int = 0
	for approach: Variant in approaches:
		var pretty: String = _format_token(String(approach))
		if pretty == "" or seen.has(pretty):
			continue
		seen[pretty] = true
		var label: Label = Label.new()
		label.text = pretty
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.modulate = Color(1, 1, 1, 0.9)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.custom_minimum_size = Vector2(62.0, 22.0)
		label.add_theme_font_size_override("font_size", 12)
		label.add_theme_color_override("font_color", Color(0.88, 0.82, 0.70, 1.0))
		label.add_theme_stylebox_override("normal", _make_tag_style())
		identity_approach_tags.add_child(label)
		shown += 1
		if shown >= 5:
			break
	identity_approach_tags.visible = shown > 0
	return identity_approach_tags.visible

func _clear_identity_panel() -> void:
	if identity_role_label:
		identity_role_label.visible = false
	if identity_goal_label:
		identity_goal_label.visible = false
	if identity_approach_tags:
		for child in identity_approach_tags.get_children():
			child.queue_free()
		identity_approach_tags.visible = false
	if identity_panel:
		identity_panel.visible = true

func _on_resized() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	var compact: bool = viewport_size.y <= COMPACT_VIEWPORT_HEIGHT or viewport_size.x < 1400.0
	var available_width: float = max(960.0, viewport_size.x - 48.0)
	var available_height: float = max(640.0, viewport_size.y - 48.0)
	var layout_width: float = min(FULL_LAYOUT_SIZE.x, available_width)
	var layout_height: float = min(FULL_LAYOUT_SIZE.y, available_height)
	var gap: float = 20.0 if compact else 34.0
	var right_width: float = min(500.0, max(420.0, layout_width * 0.38))
	var left_width: float = max(520.0, layout_width - right_width - gap)
	var heading_height: float = 52.0 if compact else 70.0
	var scroll_height: float = max(470.0, layout_height - heading_height - 26.0)
	var tile_width: float = 138.0 if compact else 150.0
	var tile_height: float = 166.0 if compact else 184.0
	var button_size: Vector2 = Vector2(138.0, 116.0) if compact else Vector2(150.0, 138.0)
	var preview_art_size: float = 270.0 if compact else 360.0
	if hbox != null:
		hbox.custom_minimum_size = Vector2(layout_width, layout_height)
		hbox.add_theme_constant_override("separation", int(gap))
	if left_column != null:
		left_column.custom_minimum_size = Vector2(left_width, layout_height)
		left_column.add_theme_constant_override("separation", 10 if compact else 14)
	if right_column != null:
		right_column.custom_minimum_size = Vector2(right_width, layout_height)
		right_column.add_theme_constant_override("separation", 10 if compact else 16)
	if heading_label != null:
		heading_label.custom_minimum_size = Vector2(0.0, heading_height)
		heading_label.add_theme_font_size_override("font_size", 30 if compact else 38)
	if scroll != null:
		scroll.custom_minimum_size = Vector2(left_width, scroll_height)
	if selected_label != null:
		selected_label.custom_minimum_size = Vector2(right_width, 50.0 if compact else 64.0)
		selected_label.add_theme_font_size_override("font_size", 24 if compact else 32)
	if details_scroll != null:
		details_scroll.custom_minimum_size = Vector2(right_width, 92.0 if compact else 126.0)
	if details_label != null:
		details_label.add_theme_font_size_override("font_size", 15 if compact else 16)
	if preview_art != null:
		preview_art.custom_minimum_size = Vector2(preview_art_size, preview_art_size)
	var art_wrap: Control = null
	if right_column != null:
		art_wrap = right_column.get_node_or_null("Preview/ArtWrap") as Control
	if art_wrap != null:
		art_wrap.custom_minimum_size = Vector2(right_width, preview_art_size)
	if start_button != null:
		start_button.custom_minimum_size = Vector2(right_width, 54.0 if compact else 68.0)
		start_button.add_theme_font_size_override("font_size", 22 if compact else 27)
	for tile_node: Node in grid.get_children():
		var tile: VBoxContainer = tile_node as VBoxContainer
		if tile == null:
			continue
		tile.custom_minimum_size = Vector2(tile_width, tile_height)
		for child: Node in tile.get_children():
			var button: Button = child as Button
			if button != null:
				button.custom_minimum_size = button_size
				continue
			var label: Label = child as Label
			if label != null:
				label.add_theme_font_size_override("font_size", 13 if compact and label.name == "UnitName" else (10 if compact else (15 if label.name == "UnitName" else 11)))
	var tile_w: float = tile_width + 14.0
	var available: float = max(1.0, float(scroll.size.x))
	var cols: int = int(floor(available / tile_w))
	grid.columns = max(3, min(cols, 5))
	if grid_wrap:
		grid_wrap.custom_minimum_size = Vector2(available, max(float(grid.size.y), float(scroll.size.y)))
	_position_gothic_plates()

func _format_role(value: String) -> String:
	var text := String(value).strip_edges().to_lower()
	if text == "":
		return ""
	var parts := text.split("_", false)
	var pretty := PackedStringArray()
	for part in parts:
		if part == "":
			continue
		pretty.append(part.capitalize())
	return " ".join(pretty)

func _format_goal(goal_value: String) -> String:
	var goal := String(goal_value).strip_edges()
	if goal == "":
		return ""
	var parts := goal.split(".", false, 2)
	if parts.size() >= 2:
		var role_part := _format_role(parts[0])
		var goal_part := _format_token(parts[1])
		if role_part != "":
			if goal_part != "":
				return "%s - %s" % [role_part, goal_part]
			return role_part
	return _format_token(goal)

func _format_list(values: Array, limit: int) -> String:
	if values == null or values.is_empty():
		return ""
	var formatted := PackedStringArray()
	var seen: Dictionary = {}
	for i in range(values.size()):
		if formatted.size() >= limit:
			break
		var token := _format_token(String(values[i]))
		if token == "" or seen.has(token):
			continue
		seen[token] = true
		formatted.append(token)
	if values.size() > limit and formatted.size() == limit:
		formatted.append("+")
	return ", ".join(formatted)

func _format_token(value: String) -> String:
	var text := String(value).strip_edges().to_lower()
	if text == "":
		return ""
	var parts := text.split("_", false)
	var pretty := PackedStringArray()
	for part in parts:
		if part == "":
			continue
		pretty.append(part.capitalize())
	return " ".join(pretty)

func _normalize_role(value: String) -> String:
	var s := String(value).strip_edges().to_lower()
	s = s.replace(" ", "_")
	s = s.replace("-", "_")
	while s.find("__") != -1:
		s = s.replace("__", "_")
	return s

func _normalize_key(value: String) -> String:
	return String(value).strip_edges().to_lower()

func _duplicate_strings(values) -> Array:
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

func _make_badge_style() -> StyleBox:
	var sb: StyleBoxFlat = _make_panel_style(Color(0.16, 0.075, 0.090, 0.94), Color(0.72, 0.42, 0.25, 0.88), 1, 5)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	return GothicUIAssets.style_or_fallback(GothicUIAssets.small_button_style(Color(1.02, 0.86, 0.72, 1.0)), sb)

func _make_tag_style() -> StyleBox:
	var sb: StyleBoxFlat = _make_panel_style(Color(0.046, 0.042, 0.050, 0.95), Color(0.36, 0.28, 0.22, 0.90), 1, 4)
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2
	return GothicUIAssets.style_or_fallback(GothicUIAssets.item_slot_style(Color(0.86, 0.76, 0.66, 1.0)), sb)

func _style_unit_cards() -> void:
	for tile_node in grid.get_children():
		var tile: VBoxContainer = tile_node as VBoxContainer
		if tile == null:
			continue
		var button: Button = null
		var name_label: Label = null
		var role_label: Label = null
		for child in tile.get_children():
			if child is Button:
				button = child as Button
			elif child is Label and child.name == "UnitName":
				name_label = child as Label
			elif child is Label and child.name == "UnitRole":
				role_label = child as Label
		if button == null:
			continue
		var unit_id: String = String(button.get_meta("unit_id")) if button.has_meta("unit_id") else ""
		var hovered: bool = unit_id != "" and unit_id == _hovered_id
		_style_unit_card(tile, button, name_label, role_label, button.button_pressed, hovered)

func _style_unit_card(tile: VBoxContainer, button: Button, name_label: Label, role_label: Label, selected: bool, hovered: bool = false) -> void:
	var compact: bool = _is_compact_layout()
	tile.add_theme_constant_override("separation", 4)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pivot_offset = button.size * 0.5 if button.size != Vector2.ZERO else button.custom_minimum_size * 0.5
	button.add_theme_stylebox_override("normal", _make_unit_button_style(selected, hovered))
	button.add_theme_stylebox_override("hover", _make_unit_button_style(false, true))
	button.add_theme_stylebox_override("pressed", _make_unit_button_style(true, true))
	button.add_theme_stylebox_override("focus", GothicUIAssets.focus_outline_style(5, COLOR_GOLD))
	button.add_theme_stylebox_override("disabled", _make_unit_button_style(false, false))
	if name_label:
		name_label.add_theme_font_size_override("font_size", 13 if compact else 15)
		name_label.add_theme_color_override("font_color", COLOR_TEXT if selected or hovered else Color(0.82, 0.78, 0.70, 1.0))
		name_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.72))
		name_label.add_theme_constant_override("outline_size", 1)
	if role_label:
		role_label.add_theme_font_size_override("font_size", 10 if compact else 11)
		role_label.add_theme_color_override("font_color", COLOR_GOLD if selected or hovered else COLOR_MUTED)

func _is_compact_layout() -> bool:
	var viewport_size: Vector2 = get_viewport_rect().size
	return viewport_size.y <= COMPACT_VIEWPORT_HEIGHT or viewport_size.x < 1400.0

func _make_unit_button_style(selected: bool, highlighted: bool) -> StyleBox:
	var bg: Color = Color(0.040, 0.035, 0.045, 0.96)
	var border: Color = Color(0.24, 0.21, 0.22, 0.92)
	var style_modulate: Color = Color.WHITE
	if selected:
		bg = Color(0.105, 0.044, 0.056, 0.98)
		border = COLOR_GOLD
		style_modulate = Color(1.14, 1.04, 0.84, 1.0)
	elif highlighted:
		bg = Color(0.070, 0.047, 0.057, 0.98)
		border = Color(0.62, 0.38, 0.25, 0.96)
		style_modulate = Color(1.10, 1.02, 0.90, 1.0)
	var sb: StyleBoxFlat = _make_panel_style(bg, border, 2 if selected or highlighted else 1, 5)
	sb.shadow_size = 10 if selected or highlighted else 5
	sb.shadow_color = Color(0.56, 0.15, 0.040, 0.30) if selected or highlighted else Color(0.0, 0.0, 0.0, 0.38)
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	return GothicUIAssets.style_or_fallback(GothicUIAssets.shop_card_style(style_modulate), sb)

func _style_start_button() -> void:
	if start_button == null:
		return
	start_button.custom_minimum_size = Vector2(500.0, 68.0)
	start_button.mouse_default_cursor_shape = Control.CURSOR_ARROW if start_button.disabled else Control.CURSOR_POINTING_HAND
	start_button.add_theme_font_size_override("font_size", 27)
	start_button.add_theme_color_override("font_color", COLOR_TEXT)
	start_button.add_theme_color_override("font_hover_color", Color(1.0, 0.91, 0.76, 1.0))
	start_button.add_theme_color_override("font_pressed_color", Color(1.0, 0.80, 0.58, 1.0))
	start_button.add_theme_color_override("font_disabled_color", Color(0.43, 0.40, 0.38, 1.0))
	start_button.add_theme_stylebox_override("normal", GothicUIAssets.style_or_fallback(GothicUIAssets.primary_button_style(), _make_panel_style(COLOR_BLOOD, Color(0.92, 0.47, 0.30, 0.86), 2, 5)))
	start_button.add_theme_stylebox_override("hover", GothicUIAssets.style_or_fallback(GothicUIAssets.primary_button_style(Color(1.18, 1.06, 0.92, 1.0)), _make_panel_style(COLOR_BLOOD_HOT, COLOR_GOLD, 2, 5)))
	start_button.add_theme_stylebox_override("pressed", GothicUIAssets.style_or_fallback(GothicUIAssets.primary_button_style(Color(0.84, 0.70, 0.66, 1.0)), _make_panel_style(Color(0.22, 0.020, 0.040, 1.0), COLOR_GOLD, 2, 5)))
	start_button.add_theme_stylebox_override("focus", GothicUIAssets.focus_outline_style(5, COLOR_GOLD))
	start_button.add_theme_stylebox_override("disabled", GothicUIAssets.style_or_fallback(GothicUIAssets.primary_button_style(Color(0.46, 0.44, 0.42, 0.80)), _make_panel_style(Color(0.030, 0.027, 0.034, 0.84), Color(0.16, 0.15, 0.17, 0.88), 1, 5)))

func _wire_start_button_hover() -> void:
	if start_button == null:
		return
	start_button.pivot_offset = start_button.size * 0.5 if start_button.size != Vector2.ZERO else start_button.custom_minimum_size * 0.5
	if not start_button.is_connected("mouse_entered", Callable(self, "_on_start_button_entered")):
		start_button.mouse_entered.connect(_on_start_button_entered)
	if not start_button.is_connected("mouse_exited", Callable(self, "_on_start_button_exited")):
		start_button.mouse_exited.connect(_on_start_button_exited)
	if not start_button.is_connected("focus_entered", Callable(self, "_on_start_button_entered")):
		start_button.focus_entered.connect(_on_start_button_entered)
	if not start_button.is_connected("focus_exited", Callable(self, "_on_start_button_exited")):
		start_button.focus_exited.connect(_on_start_button_exited)
	if not start_button.is_connected("resized", Callable(self, "_sync_start_button_pivot")):
		start_button.resized.connect(_sync_start_button_pivot)

func _on_start_button_entered() -> void:
	_apply_start_button_motion(true)

func _on_start_button_exited() -> void:
	_apply_start_button_motion(false)

func _apply_start_button_motion(active: bool) -> void:
	if start_button == null:
		return
	if _start_button_hover_tween != null and is_instance_valid(_start_button_hover_tween):
		_start_button_hover_tween.kill()
	var target_scale: Vector2 = Vector2(1.025, 1.025) if active and not start_button.disabled else Vector2.ONE
	_start_button_hover_tween = create_tween()
	_start_button_hover_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_start_button_hover_tween.tween_property(start_button, "scale", target_scale, 0.10)

func _sync_start_button_pivot() -> void:
	if start_button != null:
		start_button.pivot_offset = start_button.size * 0.5 if start_button.size != Vector2.ZERO else start_button.custom_minimum_size * 0.5

func _apply_unit_button_motion(id: String, active: bool) -> void:
	var button: Button = buttons_by_id.get(id, null) as Button
	if button == null:
		return
	var existing: Tween = button.get_meta("hover_tween") as Tween if button.has_meta("hover_tween") else null
	if existing != null and is_instance_valid(existing):
		existing.kill()
	button.pivot_offset = button.size * 0.5 if button.size != Vector2.ZERO else button.custom_minimum_size * 0.5
	button.scale = Vector2.ONE
	button.z_index = 12 if active else 0
	button.set_meta("hover_tween", null)

func _ensure_float_plate(control: Control, plate_name: String, style: StyleBox, z_value: int, pad: float) -> Panel:
	var plate: Panel = get_node_or_null(plate_name) as Panel
	if plate == null:
		plate = Panel.new()
		plate.name = plate_name
		plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
		plate.z_index = z_value
		plate.z_as_relative = false
		add_child(plate)
		move_child(plate, 1)
	plate.set_meta("target_path", get_path_to(control))
	plate.set_meta("pad", pad)
	plate.add_theme_stylebox_override("panel", style)
	_position_float_plate(plate)
	return plate

func _position_gothic_plates() -> void:
	_position_float_plate(_left_plate)
	_position_float_plate(_right_plate)
	_position_float_plate(_preview_art_plate)

func _queue_gothic_plate_reposition() -> void:
	if _plate_reposition_queued or not is_inside_tree():
		return
	_plate_reposition_queued = true
	get_tree().process_frame.connect(_position_gothic_plates_after_layout, CONNECT_ONE_SHOT)

func _position_gothic_plates_after_layout() -> void:
	_plate_reposition_queued = false
	if is_inside_tree():
		_position_gothic_plates()

func _position_float_plate(plate: Panel) -> void:
	if plate == null or not plate.has_meta("target_path"):
		return
	var target: Control = get_node_or_null(plate.get_meta("target_path")) as Control
	if target == null:
		return
	var pad: float = float(plate.get_meta("pad", 0.0))
	var root_origin: Vector2 = global_position
	plate.position = target.global_position - root_origin - Vector2(pad, pad)
	plate.size = target.size + Vector2(pad * 2.0, pad * 2.0)

func _make_panel_style(bg_color: Color, border_color: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = bg_color
	sb.border_color = border_color
	sb.border_width_left = border_width
	sb.border_width_top = border_width
	sb.border_width_right = border_width
	sb.border_width_bottom = border_width
	sb.corner_radius_top_left = radius
	sb.corner_radius_top_right = radius
	sb.corner_radius_bottom_right = radius
	sb.corner_radius_bottom_left = radius
	sb.shadow_size = 6
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.38)
	return sb

func _node_safe_id(value: String) -> String:
	var out: String = value.strip_edges().to_lower()
	out = out.replace(" ", "_")
	out = out.replace("-", "_")
	out = out.replace(".", "_")
	out = out.replace("/", "_")
	return out
