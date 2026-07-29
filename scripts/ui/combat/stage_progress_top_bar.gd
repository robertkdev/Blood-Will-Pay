extends PanelContainer
class_name StageProgressTopBar

const ChapterCatalog := preload("res://scripts/game/progression/chapter_catalog.gd")
const RosterCatalog := preload("res://scripts/game/progression/roster_catalog.gd")
const StageTypes := preload("res://scripts/game/progression/stage_types.gd")
const GothicUIAssets: GDScript = preload("res://scripts/ui/gothic_ui_assets.gd")

const ICON_SIZE: Vector2 = Vector2(44.0, 44.0)
const BAR_MIN_SIZE: Vector2 = Vector2(560.0, 56.0)
const COMPACT_ICON_SIZE: Vector2 = Vector2(32.0, 32.0)
const COMPACT_BAR_MIN_SIZE: Vector2 = Vector2(500.0, 48.0)
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
	"Round 1: Creeps",
	"Round 2: Challenge",
	"Round 3: Challenge",
	"Round 4: Boss",
	"Round 5: Mirror",
]

var _row: HBoxContainer
var _chapter_label: Label
var _icons: Array[TextureRect] = []
var _texture_cache: Dictionary[String, Texture2D] = {}

func _ready() -> void:
	_ensure_built()

func update_progress(chapter: int, stage_in_chapter: int, total_stages: int) -> void:
	_ensure_built()
	var safe_chapter: int = max(1, int(chapter))
	var safe_total: int = clampi(int(total_stages), 1, SELECTED_TEXTURE_PATHS.size())
	var safe_stage: int = clampi(int(stage_in_chapter), 1, safe_total)
	_chapter_label.text = ChapterCatalog.display_name_for(safe_chapter)
	_chapter_label.tooltip_text = _chapter_tooltip_for(safe_chapter, safe_total)
	for index: int in range(_icons.size()):
		var icon: TextureRect = _icons[index]
		var stage_number: int = index + 1
		icon.visible = stage_number <= safe_total
		if not icon.visible:
			continue
		var selected: bool = stage_number == safe_stage
		var texture_path: String = SELECTED_TEXTURE_PATHS[index] if selected else UNSELECTED_TEXTURE_PATHS[index]
		icon.texture = _load_icon_texture(texture_path)
		icon.tooltip_text = _stage_tooltip_for(safe_chapter, stage_number)
		icon.modulate = Color(1.0, 1.0, 1.0, 1.0) if selected else Color(0.78, 0.78, 0.78, 1.0)

func set_compact_layout(compact: bool) -> void:
	_ensure_built()
	custom_minimum_size = COMPACT_BAR_MIN_SIZE if compact else BAR_MIN_SIZE
	var margin: MarginContainer = get_node_or_null("Margin") as MarginContainer
	if margin != null:
		margin.add_theme_constant_override("margin_left", 10 if compact else 14)
		margin.add_theme_constant_override("margin_top", 2 if compact else 6)
		margin.add_theme_constant_override("margin_right", 10 if compact else 14)
		margin.add_theme_constant_override("margin_bottom", 2 if compact else 5)
	if _row != null:
		_row.add_theme_constant_override("separation", 7 if compact else 10)
	if _chapter_label != null:
		_chapter_label.custom_minimum_size = Vector2(130.0 if compact else 150.0, 0.0)
		_chapter_label.add_theme_font_size_override("font_size", 18 if compact else 22)
	var icon_size: Vector2 = COMPACT_ICON_SIZE if compact else ICON_SIZE
	for icon: TextureRect in _icons:
		icon.custom_minimum_size = icon_size
	queue_sort()

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
	icon.tooltip_text = STAGE_TOOLTIPS[index]
	return icon

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
			lines.append("Challenge: %s" % challenge_label)
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
			return "Challenge fight"
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
