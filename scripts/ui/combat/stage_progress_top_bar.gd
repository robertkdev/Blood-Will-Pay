extends PanelContainer
class_name StageProgressTopBar

const ChapterCatalog := preload("res://scripts/game/progression/chapter_catalog.gd")
const RosterCatalog := preload("res://scripts/game/progression/roster_catalog.gd")
const StageTypes := preload("res://scripts/game/progression/stage_types.gd")
const GothicUIAssets: GDScript = preload("res://scripts/ui/gothic_ui_assets.gd")

const ICON_SIZE: Vector2 = Vector2(44.0, 44.0)
const BAR_MIN_SIZE: Vector2 = Vector2(560.0, 56.0)
const SELECTED_TEXTURE_PATHS: PackedStringArray = [
	"res://assets/ui/stage_icons/stage_1_creep_selected.png",
	"res://assets/ui/stage_icons/stage_2_challenge_selected.png",
	"res://assets/ui/stage_icons/stage_3_challenge_selected.png",
	"res://assets/ui/stage_icons/stage_4_boss_selected.png",
	"res://assets/ui/stage_icons/stage_5_mirror_selected.png",
]
const UNSELECTED_TEXTURE_PATHS: PackedStringArray = [
	"res://assets/ui/stage_icons/stage_1_creep_unselected.png",
	"res://assets/ui/stage_icons/stage_2_challenge_unselected.png",
	"res://assets/ui/stage_icons/stage_3_challenge_unselected.png",
	"res://assets/ui/stage_icons/stage_4_boss_unselected.png",
	"res://assets/ui/stage_icons/stage_5_mirror_unselected.png",
]
const STAGE_TOOLTIPS: PackedStringArray = [
	"Stage 1: Creeps",
	"Stage 2: Challenge",
	"Stage 3: Challenge",
	"Stage 4: Boss",
	"Stage 5: Mirror",
]
const TOOLTIP_GROUP: String = "gothic_hover_tooltip"
const TOOLTIP_WIDTH: float = 360.0
const TOOLTIP_CURSOR_OFFSET: Vector2 = Vector2(18.0, 18.0)
const TOOLTIP_EDGE_PADDING: float = 12.0

var _row: HBoxContainer
var _chapter_label: Label
var _icons: Array[TextureRect] = []
var _texture_cache: Dictionary[String, Texture2D] = {}
var _tooltip: PanelContainer = null
var _hover_target: Control = null

func _ready() -> void:
	_ensure_built()

func update_progress(chapter: int, stage_in_chapter: int, total_stages: int) -> void:
	_ensure_built()
	var safe_chapter: int = max(1, int(chapter))
	var safe_total: int = clampi(int(total_stages), 1, SELECTED_TEXTURE_PATHS.size())
	var safe_stage: int = clampi(int(stage_in_chapter), 1, safe_total)
	_chapter_label.text = ChapterCatalog.display_name_for(safe_chapter)
	_set_hover_text(_chapter_label, _chapter_tooltip_for(safe_chapter, safe_total))
	for index: int in range(_icons.size()):
		var icon: TextureRect = _icons[index]
		var stage_number: int = index + 1
		icon.visible = stage_number <= safe_total
		if not icon.visible:
			continue
		var selected: bool = stage_number == safe_stage
		var texture_path: String = SELECTED_TEXTURE_PATHS[index] if selected else UNSELECTED_TEXTURE_PATHS[index]
		icon.texture = _load_icon_texture(texture_path)
		_set_hover_text(icon, _stage_tooltip_for(safe_chapter, stage_number))
		icon.modulate = Color(1.0, 1.0, 1.0, 1.0) if selected else Color(0.78, 0.78, 0.78, 1.0)

func _ensure_built() -> void:
	if _row != null:
		return
	custom_minimum_size = BAR_MIN_SIZE
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel", _make_panel_style())

	var margin: MarginContainer = MarginContainer.new()
	margin.name = "Margin"
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 5)
	add_child(margin)

	_row = HBoxContainer.new()
	_row.name = "Row"
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.add_theme_constant_override("separation", 10)
	margin.add_child(_row)

	_chapter_label = Label.new()
	_chapter_label.name = "ChapterLabel"
	_chapter_label.custom_minimum_size = Vector2(150.0, 0.0)
	_chapter_label.text = "Chapter 1"
	_chapter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_chapter_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_chapter_label.mouse_filter = Control.MOUSE_FILTER_PASS
	_chapter_label.add_theme_font_size_override("font_size", 22)
	_chapter_label.add_theme_color_override("font_color", Color(0.96, 0.84, 0.60, 1.0))
	_chapter_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.72))
	_chapter_label.add_theme_constant_override("shadow_offset_x", 1)
	_chapter_label.add_theme_constant_override("shadow_offset_y", 2)
	_wire_hover_target(_chapter_label)
	_row.add_child(_chapter_label)

	for index: int in range(SELECTED_TEXTURE_PATHS.size()):
		var icon: TextureRect = _make_icon(index)
		_icons.append(icon)
		_row.add_child(icon)

func _make_icon(index: int) -> TextureRect:
	var icon: TextureRect = TextureRect.new()
	icon.name = "StageIcon%d" % int(index + 1)
	icon.custom_minimum_size = ICON_SIZE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_PASS
	icon.texture = _load_icon_texture(UNSELECTED_TEXTURE_PATHS[index])
	_set_hover_text(icon, STAGE_TOOLTIPS[index])
	_wire_hover_target(icon)
	return icon

func _wire_hover_target(target: Control) -> void:
	if target == null:
		return
	target.tooltip_text = ""
	var entered: Callable = Callable(self, "_on_hover_target_entered").bind(target)
	var exited: Callable = Callable(self, "_on_hover_target_exited").bind(target)
	var input: Callable = Callable(self, "_on_hover_target_gui_input").bind(target)
	if not target.is_connected("mouse_entered", entered):
		target.mouse_entered.connect(entered)
	if not target.is_connected("mouse_exited", exited):
		target.mouse_exited.connect(exited)
	if not target.is_connected("gui_input", input):
		target.gui_input.connect(input)

func _set_hover_text(target: Control, text: String) -> void:
	if target == null:
		return
	target.set_meta("stage_hover_text", String(text))
	target.tooltip_text = ""
	if _hover_target == target:
		_show_tooltip_for(target)

func _on_hover_target_entered(target: Control) -> void:
	_hover_target = target
	_show_tooltip_for(target)

func _on_hover_target_exited(target: Control) -> void:
	if _hover_target == target:
		_hover_target = null
	_clear_tooltip()

func _on_hover_target_gui_input(event: InputEvent, target: Control) -> void:
	if _hover_target != target:
		return
	if event is InputEventMouseMotion and _tooltip != null and is_instance_valid(_tooltip):
		var viewport: Viewport = get_viewport()
		if viewport != null:
			_move_tooltip(viewport.get_mouse_position())

func _show_tooltip_for(target: Control) -> void:
	_clear_tooltip()
	if target == null or not is_inside_tree():
		return
	var raw_text: String = String(target.get_meta("stage_hover_text", "")).strip_edges()
	if raw_text == "":
		return
	var tree: SceneTree = get_tree()
	if tree == null or tree.root == null:
		return
	var tooltip: PanelContainer = PanelContainer.new()
	tooltip.name = "StageProgressTooltip"
	tooltip.top_level = true
	tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip.z_index = 960
	tooltip.custom_minimum_size.x = TOOLTIP_WIDTH
	tooltip.add_to_group(TOOLTIP_GROUP)
	tooltip.add_theme_stylebox_override("panel", _make_tooltip_style())
	var box: VBoxContainer = VBoxContainer.new()
	box.name = "Rows"
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 5)
	tooltip.add_child(box)
	var lines: PackedStringArray = raw_text.split("\n", false)
	for line_index: int in range(lines.size()):
		var line: String = String(lines[line_index]).strip_edges()
		if line == "":
			continue
		var font_size: int = 16 if line_index == 0 else 13
		var color: Color = Color(0.96, 0.70, 0.36, 1.0) if line_index == 0 else Color(0.91, 0.87, 0.78, 1.0)
		_add_tooltip_label(box, line, font_size, color)
	tree.root.add_child(tooltip)
	_tooltip = tooltip
	_sync_tooltip_size()
	var viewport: Viewport = get_viewport()
	if viewport != null:
		_move_tooltip(viewport.get_mouse_position())
	else:
		_move_tooltip(target.get_global_rect().position + Vector2(16.0, target.size.y))

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
	_tooltip.size.y = max(74.0, _tooltip.get_combined_minimum_size().y)

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
	_clear_tooltip()

func _chapter_tooltip_for(chapter: int, total_stages: int) -> String:
	var lines: Array[String] = [ChapterCatalog.display_name_for(chapter)]
	for stage_number: int in range(1, int(total_stages) + 1):
		lines.append(_stage_tooltip_for(chapter, stage_number).replace("\n", " | "))
	return "\n".join(lines)

func _stage_tooltip_for(chapter: int, stage_number: int) -> String:
	var fallback: String = STAGE_TOOLTIPS[clampi(stage_number - 1, 0, STAGE_TOOLTIPS.size() - 1)]
	var spec: Dictionary = RosterCatalog.get_spec(chapter, stage_number)
	if not StageTypes.validate_spec(spec):
		return fallback
	var kind: String = String(spec.get(StageTypes.KEY_KIND, ""))
	var rules: Dictionary = spec.get(StageTypes.KEY_RULES, {}) if typeof(spec.get(StageTypes.KEY_RULES, {})) == TYPE_DICTIONARY else {}
	var ids: Array[String] = _spec_ids(spec)
	var title: String = "%s: %s" % [fallback, _kind_label(kind)]
	var lines: Array[String] = [title]
	if kind == StageTypes.KIND_MIRROR:
		lines.append("Enemy: your boss-entry board")
	else:
		lines.append("Enemy: %s" % _ids_label(ids))
	var challenge: Dictionary = rules.get("rga_challenge", {}) if typeof(rules.get("rga_challenge", {})) == TYPE_DICTIONARY else {}
	if not challenge.is_empty():
		var challenge_label: String = String(challenge.get("label", "")).strip_edges()
		if challenge_label != "":
			lines.append("RGA: %s" % challenge_label)
		var puzzle: String = String(challenge.get("puzzle", "")).strip_edges()
		if puzzle != "":
			lines.append("Plan: %s" % puzzle)
	var theme: String = String(rules.get("theme", "")).strip_edges()
	if theme != "" and challenge.is_empty():
		lines.append("Theme: %s" % theme.replace("_", " ").capitalize())
	if rules.has("difficulty_rating") or rules.has("target_rating"):
		lines.append("Rating: %d/%d" % [int(rules.get("difficulty_rating", 0)), int(rules.get("target_rating", 0))])
	return "\n".join(lines)

func _spec_ids(spec: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var value: Variant = spec.get(StageTypes.KEY_IDS, [])
	if value is Array:
		for id_value: Variant in value:
			var unit_id: String = String(id_value).strip_edges()
			if unit_id != "":
				out.append(unit_id)
	return out

func _ids_label(ids: Array[String]) -> String:
	if ids.is_empty():
		return "unknown"
	var names: Array[String] = []
	for unit_id: String in ids:
		names.append(unit_id.replace("_", " ").capitalize())
	return ", ".join(names)

func _kind_label(kind: String) -> String:
	match String(kind):
		StageTypes.KIND_CREEPS:
			return "Creep reward"
		StageTypes.KIND_NORMAL:
			return "RGA challenge"
		StageTypes.KIND_BOSS:
			return "Boss"
		StageTypes.KIND_MIRROR:
			return "Mirror"
		_:
			return String(kind).capitalize()

func _load_icon_texture(path: String) -> Texture2D:
	if _texture_cache.has(path):
		return _texture_cache[path]
	if ResourceLoader.exists(path, "Texture2D"):
		var resource: Resource = ResourceLoader.load(path, "Texture2D")
		var imported_texture: Texture2D = resource as Texture2D
		if imported_texture != null:
			_texture_cache[path] = imported_texture
			return imported_texture
	var image: Image = Image.new()
	var err: Error = image.load(path)
	if err != OK:
		var absolute_path: String = ProjectSettings.globalize_path(path)
		err = image.load(absolute_path)
	if err != OK:
		push_error("StageProgressTopBar: failed to load icon texture %s error=%d" % [path, int(err)])
		return null
	var texture: ImageTexture = ImageTexture.create_from_image(image)
	texture.take_over_path(path)
	_texture_cache[path] = texture
	return texture

func _make_panel_style() -> StyleBox:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.030, 0.024, 0.030, 0.78)
	style.border_color = Color(0.46, 0.34, 0.20, 0.62)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_right = 5
	style.corner_radius_bottom_left = 5
	return GothicUIAssets.style_or_fallback(GothicUIAssets.status_strip_style(Color(0.74, 0.68, 0.58, 0.76)), style)
