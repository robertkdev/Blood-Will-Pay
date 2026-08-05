extends DragAndDroppable
class_name ItemCard

const TextureUtils := preload("res://scripts/util/texture_utils.gd")
const ItemCatalog := preload("res://scripts/game/items/item_catalog.gd")
const ItemDef := preload("res://scripts/game/items/item_def.gd")
const CombineRules := preload("res://scripts/game/items/combine_rules.gd")
const ItemTooltipScene := preload("res://scenes/ui/items/ItemTooltip.tscn")
const GothicUIAssets: GDScript = preload("res://scripts/ui/gothic_ui_assets.gd")

const HOVER_DELAY: float = 0.10
const TOOLTIP_GROUP: String = "gothic_hover_tooltip"

var icon: TextureRect
var count_label: Label
var background: Panel
var frame: Panel
var patina: ColorRect
var empty_mark: Label
var pocket_cavity: Panel
var binding_rail: ColorRect
var docket_label: Label
var seal_stud: ColorRect
var combine_preview_label: Label

var slot_index: int = -1
var item_id: String = ""
var count: int = 0
var _hovered: bool = false
var _hover_token: int = 0
var _tooltip: Control = null
var _hover_tween: Tween = null
var _material_slot_size: Vector2 = Vector2(48.0, 48.0)
var _material_shell_enforcement_queued: bool = false

static var active_drag_item_id: String = ""

func _ready() -> void:
	super._ready()
	_ensure_children()
	_refresh()
	# Drag base config
	content_root_path = NodePath(".")
	drag_size = Vector2(maxf(36.0, _material_slot_size.x), maxf(36.0, _material_slot_size.y))
	# Ensure the card occupies space in containers (e.g., GridContainer)
	custom_minimum_size = _material_slot_size
	clip_contents = true
	mouse_default_cursor_shape = Control.CURSOR_ARROW
	pivot_offset = custom_minimum_size * 0.5
	allowed_phases = [GameState.GamePhase.PREVIEW, GameState.GamePhase.COMBAT, GameState.GamePhase.POST_COMBAT]
	tooltip_text = ""
	if not is_connected("mouse_entered", Callable(self, "_on_mouse_entered")):
		mouse_entered.connect(_on_mouse_entered)
	if not is_connected("mouse_exited", Callable(self, "_on_mouse_exited")):
		mouse_exited.connect(_on_mouse_exited)
	if not is_connected("focus_entered", Callable(self, "_on_focus_entered")):
		focus_entered.connect(_on_focus_entered)
	if not is_connected("focus_exited", Callable(self, "_on_focus_exited")):
		focus_exited.connect(_on_focus_exited)
	if not is_connected("gui_input", Callable(self, "_on_hover_gui_input")):
		gui_input.connect(_on_hover_gui_input)
	if not is_connected("began_drag", Callable(self, "_on_began_drag")):
		began_drag.connect(_on_began_drag)
	if not is_connected("ended_drag", Callable(self, "_on_ended_drag")):
		ended_drag.connect(_on_ended_drag)
	if not is_connected("resized", Callable(self, "_sync_pivot")):
		resized.connect(_sync_pivot)
	if not is_connected("resized", Callable(self, "_queue_material_shell_enforcement")):
		resized.connect(_queue_material_shell_enforcement)
	_sync_pivot()

func _can_drag_extra() -> bool:
	# Do not allow dragging when this is an empty placeholder slot
	return String(item_id) != ""

func _ensure_children() -> void:
	if background == null:
		background = Panel.new()
		background.name = "Background"
		background.mouse_filter = Control.MOUSE_FILTER_IGNORE
		background.set_anchors_preset(Control.PRESET_FULL_RECT)
		background.offset_left = 0.0
		background.offset_top = 0.0
		background.offset_right = 0.0
		background.offset_bottom = 0.0
		background.z_index = -1
		add_child(background)
	if icon == null:
		icon = TextureRect.new()
		icon.name = "Icon"
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.z_index = 1
		add_child(icon)
		icon.anchor_left = 0.0
		icon.anchor_top = 0.0
		icon.anchor_right = 1.0
		icon.anchor_bottom = 1.0
		icon.offset_left = 4.0
		icon.offset_top = 4.0
		icon.offset_right = -4.0
		icon.offset_bottom = -4.0
	if pocket_cavity == null:
		pocket_cavity = Panel.new()
		pocket_cavity.name = "PocketCavity"
		pocket_cavity.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pocket_cavity.set_anchors_preset(Control.PRESET_FULL_RECT)
		pocket_cavity.z_index = 0
		add_child(pocket_cavity)
	if binding_rail == null:
		binding_rail = ColorRect.new()
		binding_rail.name = "BindingRail"
		binding_rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
		binding_rail.z_index = 1
		add_child(binding_rail)
	if seal_stud == null:
		seal_stud = ColorRect.new()
		seal_stud.name = "SealStud"
		seal_stud.mouse_filter = Control.MOUSE_FILTER_IGNORE
		seal_stud.z_index = 2
		add_child(seal_stud)
	if patina == null:
		patina = ColorRect.new()
		patina.name = "Patina"
		patina.mouse_filter = Control.MOUSE_FILTER_IGNORE
		patina.set_anchors_preset(Control.PRESET_FULL_RECT)
		patina.offset_left = 2.0
		patina.offset_top = 2.0
		patina.offset_right = -2.0
		patina.offset_bottom = -2.0
		patina.z_index = 2
		patina.visible = false
		patina.color = Color(0.060, 0.026, 0.018, 0.30)
		add_child(patina)
	if empty_mark == null:
		empty_mark = Label.new()
		empty_mark.name = "EmptyMark"
		empty_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		empty_mark.set_anchors_preset(Control.PRESET_FULL_RECT)
		empty_mark.offset_left = 0.0
		empty_mark.offset_top = 0.0
		empty_mark.offset_right = 0.0
		empty_mark.offset_bottom = 0.0
		empty_mark.text = "+"
		empty_mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty_mark.add_theme_font_size_override("font_size", 11)
		empty_mark.add_theme_color_override("font_color", Color(0.66, 0.59, 0.52, 0.54))
		empty_mark.z_index = 2
		add_child(empty_mark)
	if frame == null:
		frame = Panel.new()
		frame.name = "Frame"
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.set_anchors_preset(Control.PRESET_FULL_RECT)
		frame.offset_left = 0.0
		frame.offset_top = 0.0
		frame.offset_right = 0.0
		frame.offset_bottom = 0.0
		frame.z_index = 3
		add_child(frame)
	if docket_label == null:
		docket_label = Label.new()
		docket_label.name = "Docket"
		docket_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		docket_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		docket_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		docket_label.z_index = 4
		add_child(docket_label)
	if count_label == null:
		count_label = Label.new()
		count_label.name = "Count"
		add_child(count_label)
		count_label.z_index = 4
		count_label.anchor_left = 1.0
		count_label.anchor_top = 1.0
		count_label.anchor_right = 1.0
		count_label.anchor_bottom = 1.0
		count_label.offset_left = -18
		count_label.offset_top = -18
		count_label.offset_right = 0
		count_label.offset_bottom = 0
		count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		count_label.modulate = Color(0.96, 0.74, 0.38, 0.98)
		count_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.78))
		count_label.add_theme_constant_override("outline_size", 1)
	if combine_preview_label == null:
		combine_preview_label = Label.new()
		combine_preview_label.name = "CombinePreview"
		combine_preview_label.visible = false
		combine_preview_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		combine_preview_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		combine_preview_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		combine_preview_label.add_theme_font_size_override("font_size", 11)
		combine_preview_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.42, 1.0))
		combine_preview_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
		combine_preview_label.add_theme_constant_override("outline_size", 2)
		combine_preview_label.set_anchors_preset(Control.PRESET_FULL_RECT)
		combine_preview_label.offset_left = -34.0
		combine_preview_label.offset_right = 34.0
		combine_preview_label.offset_top = -24.0
		combine_preview_label.offset_bottom = -6.0
		combine_preview_label.z_index = 80
		add_child(combine_preview_label)
	_sync_pocket_geometry()

func set_item_id(id: String) -> void:
	item_id = String(id)
	_refresh()

func set_slot_index(idx: int) -> void:
	slot_index = int(idx)
	_sync_empty_slot_label()

func set_material_slot_presentation(slot_size: Vector2) -> void:
	_material_slot_size = slot_size
	custom_minimum_size = slot_size
	drag_size = Vector2(maxf(36.0, slot_size.x), maxf(36.0, slot_size.y))
	pivot_offset = slot_size * 0.5
	_sync_pocket_geometry()
	_sync_empty_slot_label()
	_apply_card_style(item_id.strip_edges() != "")

func get_slot_index() -> int:
	return slot_index

func set_count(n: int) -> void:
	count = int(n)
	_refresh()

func _refresh() -> void:
	_ensure_children()
	count_label.text = (str(count) if count > 1 else "")
	var def: ItemDef = ItemCatalog.get_def(item_id)
	if String(item_id) == "":
		# Empty cache pocket: no icon, but an authored receive state remains visible.
		icon.texture = null
		icon.visible = false
		empty_mark.visible = true
		tooltip_text = ""
		mouse_default_cursor_shape = Control.CURSOR_ARROW
		focus_mode = Control.FOCUS_NONE
		_apply_card_style(false)
		_sync_pocket_state(false)
		return
	empty_mark.visible = false
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	focus_mode = Control.FOCUS_ALL
	if def != null:
		var tex: Texture2D = null
		if String(def.icon_path) != "":
			tex = load(def.icon_path)
		if tex == null:
			tex = TextureUtils.make_circle_texture(Color(0.6, 0.7, 0.9), 48)
		icon.texture = tex
		icon.visible = true
	else:
		icon.texture = TextureUtils.make_circle_texture(Color(0.5, 0.5, 0.5), 48)
		icon.visible = true
	_apply_card_style(true)
	_sync_pocket_state(true)
	tooltip_text = ""

func _apply_card_style(filled: bool) -> void:
	var hover_filled: bool = _hovered and filled
	var hover_empty: bool = _hovered and not filled
	if background != null:
		background.add_theme_stylebox_override("panel", _reliquary_outer_style(filled, _hovered))
	if pocket_cavity != null:
		pocket_cavity.add_theme_stylebox_override("panel", _reliquary_cavity_style(filled, _hovered))
	if icon != null:
		var icon_inset: float = 13.0 if _material_slot_size.x >= 70.0 else 10.0 if _material_slot_size.x >= 48.0 else 8.0
		icon.offset_left = icon_inset
		icon.offset_top = icon_inset + 3.0
		icon.offset_right = -icon_inset
		icon.offset_bottom = -(icon_inset - 2.0)
		icon.modulate = Color(0.96, 0.84, 0.66, 1.0) if hover_filled else Color(0.76, 0.68, 0.56, 0.90) if filled else Color(1.0, 1.0, 1.0, 0.0)
	if patina != null:
		patina.visible = filled
		patina.offset_left = 9.0
		patina.offset_top = 18.0
		patina.offset_right = -9.0
		patina.offset_bottom = -8.0
		patina.color = Color(0.10, 0.040, 0.026, 0.36) if hover_filled else Color(0.026, 0.020, 0.018, 0.56)
	if frame != null:
		frame.visible = true
		frame.offset_left = 5.0
		frame.offset_top = 5.0
		frame.offset_right = -5.0
		frame.offset_bottom = -6.0
		frame.add_theme_stylebox_override("panel", _reliquary_inner_style(filled, _hovered))
	if binding_rail != null:
		var rail_color: Color = Color(0.58, 0.06, 0.075, 0.62) if filled else Color(0.34, 0.05, 0.06, 0.46)
		binding_rail.color = rail_color.lightened(0.16) if _hovered else rail_color
	if seal_stud != null:
		seal_stud.color = Color(0.92, 0.72, 0.43, 0.92) if filled else Color(0.66, 0.58, 0.48, 0.72)
	if empty_mark != null:
		empty_mark.visible = not filled
		empty_mark.modulate = Color(1.0, 0.78, 0.68, 0.92) if hover_empty else Color.WHITE
	if docket_label != null:
		docket_label.add_theme_color_override("font_color", Color(0.98, 0.78, 0.48, 0.98) if filled else Color(0.86, 0.76, 0.62, 0.90))
		docket_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.94))
		docket_label.add_theme_constant_override("outline_size", 1)
	if count_label != null:
		count_label.modulate = Color(1.0, 0.84, 0.42, 1.0) if _hovered else Color(0.96, 0.74, 0.38, 0.98)

func _sync_empty_slot_label() -> void:
	if empty_mark == null:
		return
	var slot_number: int = maxi(1, slot_index + 1)
	empty_mark.text = "RECEIVE" if _material_slot_size.x < 48.0 else "RECEIVE\nRELIC"
	empty_mark.add_theme_font_size_override("font_size", 7 if _material_slot_size.x < 48.0 else 9 if _material_slot_size.x < 70.0 else 11)
	empty_mark.add_theme_color_override("font_color", Color(0.76, 0.67, 0.55, 0.72))
	empty_mark.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.88))
	empty_mark.add_theme_constant_override("outline_size", 1)
	empty_mark.set_meta("purposeful_empty_slot", true)
	empty_mark.set_meta("ready_pocket_number", slot_number)
	_sync_pocket_state(item_id.strip_edges() != "")

func _sync_pocket_state(filled: bool) -> void:
	var slot_number: int = maxi(1, slot_index + 1)
	if docket_label != null:
		docket_label.text = ("HELD // %02d" if filled else "READY // %02d") % slot_number
		docket_label.add_theme_font_size_override("font_size", 7 if _material_slot_size.x < 48.0 else 8 if _material_slot_size.x < 70.0 else 10)
		docket_label.set_meta("pocket_status", "held" if filled else "ready")
	set_meta("reliquary_pocket", true)
	set_meta("evidence_compartment", true)
	set_meta("cache_slot_state", "held" if filled else "ready")
	set_meta("pocket_serial", slot_number)

func _sync_pocket_geometry() -> void:
	var tight: bool = _material_slot_size.x < 48.0
	var cavity_inset: float = 6.0 if tight else 8.0 if _material_slot_size.x < 70.0 else 10.0
	if pocket_cavity != null:
		pocket_cavity.offset_left = cavity_inset
		pocket_cavity.offset_top = 16.0 if tight else 18.0
		pocket_cavity.offset_right = -cavity_inset
		pocket_cavity.offset_bottom = -7.0 if tight else -9.0
	var rail_anchor: float = 0.24 if posmod(slot_index, 3) == 0 else 0.50 if posmod(slot_index, 3) == 1 else 0.76
	if binding_rail != null:
		binding_rail.anchor_left = rail_anchor
		binding_rail.anchor_right = rail_anchor
		binding_rail.anchor_top = 0.0
		binding_rail.anchor_bottom = 1.0
		binding_rail.offset_left = -1.0
		binding_rail.offset_top = 18.0 if tight else 20.0
		binding_rail.offset_right = 1.0
		binding_rail.offset_bottom = -9.0
	if seal_stud != null:
		seal_stud.anchor_left = rail_anchor
		seal_stud.anchor_right = rail_anchor
		seal_stud.anchor_top = 1.0
		seal_stud.anchor_bottom = 1.0
		seal_stud.offset_left = -2.0
		seal_stud.offset_top = -14.0
		seal_stud.offset_right = 2.0
		seal_stud.offset_bottom = -10.0
	if docket_label != null:
		docket_label.anchor_left = 0.0
		docket_label.anchor_right = 1.0
		docket_label.anchor_top = 0.0
		docket_label.anchor_bottom = 0.0
		docket_label.offset_left = 5.0
		docket_label.offset_top = 3.0
		docket_label.offset_right = -5.0
		docket_label.offset_bottom = 17.0 if tight else 19.0
	if empty_mark != null:
		empty_mark.offset_left = cavity_inset + 2.0
		empty_mark.offset_top = 18.0 if tight else 21.0
		empty_mark.offset_right = -(cavity_inset + 2.0)
		empty_mark.offset_bottom = -9.0

func _reliquary_outer_style(filled: bool, hovered: bool) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.058, 0.026, 0.030, 0.99) if filled else Color(0.017, 0.013, 0.017, 0.99)
	style.border_color = Color(0.94, 0.70, 0.38, 1.0) if hovered else Color(0.64, 0.49, 0.33, 0.98) if filled else Color(0.48, 0.42, 0.36, 0.94)
	style.border_width_left = 4 if filled or hovered else 3
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 5 if filled or hovered else 4
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 1
	style.corner_radius_bottom_right = 3
	style.corner_radius_bottom_left = 1
	style.shadow_color = Color(0.16, 0.0, 0.012, 0.72) if filled else Color(0.0, 0.0, 0.0, 0.78)
	style.shadow_size = 6 if hovered else 4
	return style

func _reliquary_cavity_style(filled: bool, hovered: bool) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.070, 0.022, 0.026, 0.96) if filled else Color(0.006, 0.005, 0.007, 0.98)
	style.border_color = Color(0.78, 0.20, 0.16, 0.76) if hovered else Color(0.45, 0.11, 0.10, 0.62) if filled else Color(0.32, 0.26, 0.23, 0.70)
	style.border_width_left = 2
	style.border_width_top = 3
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_right = 5
	style.corner_radius_bottom_left = 5
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.94)
	style.shadow_size = 5
	return style

func _reliquary_inner_style(filled: bool, hovered: bool) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	style.border_color = Color(0.92, 0.72, 0.44, 0.88) if hovered else Color(0.66, 0.20, 0.16, 0.72) if filled else Color(0.58, 0.51, 0.43, 0.48)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 2
	style.corner_radius_top_left = 1
	style.corner_radius_top_right = 1
	style.corner_radius_bottom_right = 2
	style.corner_radius_bottom_left = 2
	style.draw_center = false
	return style

func _on_mouse_entered() -> void:
	_hovered = true
	_hover_token += 1
	_apply_card_style(item_id.strip_edges() != "")
	_apply_hover_motion(true, item_id.strip_edges() != "")
	_update_combine_preview()
	var token: int = _hover_token
	await get_tree().create_timer(HOVER_DELAY).timeout
	if not _hovered or token != _hover_token:
		return
	_show_tooltip()

func _on_mouse_exited() -> void:
	_hovered = false
	_hover_token += 1
	_clear_tooltip()
	_apply_card_style(item_id.strip_edges() != "")
	_apply_hover_motion(false, item_id.strip_edges() != "")
	_clear_combine_preview()

func _on_focus_entered() -> void:
	if item_id.strip_edges() == "":
		return
	_hovered = true
	_hover_token += 1
	_apply_card_style(true)
	_apply_hover_motion(true, true)
	_show_tooltip_at(get_global_rect().end + Vector2(10.0, -size.y * 0.5))

func _on_focus_exited() -> void:
	_hovered = false
	_hover_token += 1
	_clear_tooltip()
	_apply_card_style(item_id.strip_edges() != "")
	_apply_hover_motion(false, item_id.strip_edges() != "")

func _on_hover_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and _tooltip != null and is_instance_valid(_tooltip):
		var viewport: Viewport = get_viewport()
		if viewport != null and _tooltip.has_method("move_to"):
			_tooltip.call("move_to", viewport.get_mouse_position())

func _on_began_drag() -> void:
	active_drag_item_id = item_id
	_hovered = false
	_hover_token += 1
	_clear_tooltip()
	_apply_card_style(item_id.strip_edges() != "")
	_apply_hover_motion(false, item_id.strip_edges() != "")

func _on_ended_drag() -> void:
	active_drag_item_id = ""
	_clear_combine_preview()
	_apply_card_style(item_id.strip_edges() != "")
	_apply_hover_motion(_hovered, item_id.strip_edges() != "")

func _update_combine_preview() -> void:
	if combine_preview_label == null:
		return
	var result_id: String = CombineRules.completed_for(active_drag_item_id, item_id)
	if result_id == "":
		combine_preview_label.visible = false
		return
	var result_def: ItemDef = ItemCatalog.get_def(result_id)
	var result_name: String = String(result_def.name) if result_def != null else result_id.replace("_", " ").capitalize()
	combine_preview_label.text = "Craft → %s" % result_name
	combine_preview_label.visible = true

func _clear_combine_preview() -> void:
	if combine_preview_label != null:
		combine_preview_label.visible = false

func _show_tooltip() -> void:
	var viewport: Viewport = get_viewport()
	var viewport_position: Vector2 = viewport.get_mouse_position() if viewport != null else get_global_rect().end
	_show_tooltip_at(viewport_position)

func _show_tooltip_at(viewport_position: Vector2) -> void:
	_clear_tooltip()
	_clear_global_tooltips()
	var tooltip: Control = ItemTooltipScene.instantiate() as Control
	if tooltip == null:
		return
	tooltip.top_level = true
	tooltip.add_to_group(TOOLTIP_GROUP)
	get_tree().root.add_child(tooltip)
	if tooltip.has_method("set_item_id"):
		tooltip.call("set_item_id", item_id)
	if tooltip.has_method("show_at"):
		tooltip.call("show_at", viewport_position)
	_tooltip = tooltip

func _clear_tooltip() -> void:
	if _tooltip != null and is_instance_valid(_tooltip):
		_tooltip.queue_free()
	_tooltip = null

func _clear_global_tooltips() -> void:
	if get_tree() == null:
		return
	var nodes: Array[Node] = get_tree().get_nodes_in_group(TOOLTIP_GROUP)
	for node: Node in nodes:
		if node != null and node != _tooltip and is_instance_valid(node):
			node.queue_free()

func _apply_hover_motion(active: bool, _filled: bool) -> void:
	if _hover_tween != null and is_instance_valid(_hover_tween):
		_hover_tween.kill()
	var target_scale: Vector2 = Vector2.ONE
	if active:
		z_index = 60
	else:
		z_index = 0
	_hover_tween = create_tween()
	_hover_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_hover_tween.tween_property(self, "scale", target_scale, 0.09)

func _sync_pivot() -> void:
	pivot_offset = size * 0.5 if size != Vector2.ZERO else custom_minimum_size * 0.5

func _queue_material_shell_enforcement() -> void:
	if slot_index != 0 or _material_shell_enforcement_queued:
		return
	_material_shell_enforcement_queued = true
	call_deferred("_enforce_material_cache_shell")

func _enforce_material_cache_shell() -> void:
	_material_shell_enforcement_queued = false
	var parent_grid: GridContainer = get_parent() as GridContainer
	if parent_grid == null or not bool(parent_grid.get_meta("material_cache_layout", false)):
		return
	var visible_ready_slots: int = int(parent_grid.get_meta("visible_ready_slots", 3))
	parent_grid.columns = 3 if visible_ready_slots <= 6 else 6
	var slot_size: Vector2 = parent_grid.get_meta("material_slot_size", _material_slot_size) as Vector2
	for card_node: Node in parent_grid.get_children():
		var cache_card: Control = card_node as Control
		if cache_card != null and cache_card.has_method("set_material_slot_presentation"):
			cache_card.call("set_material_slot_presentation", slot_size)
	var cache_header: Label = parent_grid.get_parent().get_node_or_null("ItemStorageHeader") as Label if parent_grid.get_parent() != null else null
	if cache_header != null:
		cache_header.text = String(parent_grid.get_meta("material_header_text", cache_header.text))
	parent_grid.queue_sort()
