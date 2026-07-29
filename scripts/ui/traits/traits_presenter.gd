extends RefCounted
class_name TraitsPresenter

const TraitCompiler := preload("res://scripts/game/traits/trait_compiler.gd")
const TRAIT_ICON_SCENE_PATH: String = "res://scenes/ui/traits/TraitIcon.tscn"
const GothicUIAssets: GDScript = preload("res://scripts/ui/gothic_ui_assets.gd")

var view: Control
var manager

var _overlay: Control = null
var _scroll: ScrollContainer = null
var _vbox: VBoxContainer = null
var _trait_signature: String = ""
var _trait_icon_scene: PackedScene = null

const WIDTH: int = 296
const PADDING_X: int = 10
const SPACING: int = 6
const ROW_HEIGHT: int = 48

static var diagnostics_enabled: bool = false
static var diagnostic_rebuild_calls: int = 0
static var diagnostic_rebuild_skips: int = 0

static func set_diagnostics_enabled(enabled: bool) -> void:
	diagnostics_enabled = bool(enabled)

static func reset_diagnostics() -> void:
	diagnostic_rebuild_calls = 0
	diagnostic_rebuild_skips = 0

static func diagnostic_snapshot() -> Dictionary:
	return {
		"rebuild_calls": diagnostic_rebuild_calls,
		"rebuild_skips": diagnostic_rebuild_skips
	}

func configure(_view: Control, _manager) -> void:
	view = _view
	manager = _manager

func initialize() -> void:
	_ensure_overlay()
	_connect_signals()
	rebuild()

func teardown() -> void:
	if view != null and is_instance_valid(view) and view.is_connected("resized", Callable(self, "_on_view_resized")):
		view.resized.disconnect(_on_view_resized)
	if manager != null and is_instance_valid(manager) and manager.is_connected("team_stats_updated", Callable(self, "_on_team_stats_updated")):
		manager.team_stats_updated.disconnect(_on_team_stats_updated)
	if _vbox != null and is_instance_valid(_vbox):
		for c in _vbox.get_children():
			if c is Node:
				c.queue_free()
	_overlay = null
	_scroll = null
	_vbox = null
	manager = null
	view = null

func _connect_signals() -> void:
	if view and not view.is_connected("resized", Callable(self, "_on_view_resized")):
		view.resized.connect(_on_view_resized)
	if manager and not manager.is_connected("team_stats_updated", Callable(self, "_on_team_stats_updated")):
		manager.team_stats_updated.connect(_on_team_stats_updated)

func _on_team_stats_updated(_pteam, _eteam) -> void:
	rebuild(false)

func _on_view_resized() -> void:
	_update_layout()

func _ensure_overlay() -> void:
	# Find prebuilt panel in scene instead of constructing via code
	if _overlay and is_instance_valid(_overlay):
		return
	if view == null:
		return
	# Prefer the left-side dock; keep the old root as a migration fallback.
	var panel: Control = view.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ContentRow/LeftItemArea/TraitsPanel")
	if panel == null:
		panel = view.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/TraitsPanel")
	if panel == null:
		return
	_overlay = panel
	# Locate ScrollContainer and VBox inside the panel by name
	_scroll = panel.get_node_or_null("TraitsScroll")
	if _scroll == null:
		# fallback: first ScrollContainer child
		for c in panel.get_children():
			if c is ScrollContainer:
				_scroll = c
				break
	if _scroll:
		_vbox = _scroll.get_node_or_null("TraitsVBox")
		if _vbox == null:
			# fallback: first VBoxContainer inside the scroll
			for c2 in _scroll.get_children():
				if c2 is VBoxContainer:
					_vbox = c2
					break
	# Ensure spacing default if found
	if _vbox:
		_vbox.add_theme_constant_override("spacing", SPACING)

func rebuild(force: bool = true) -> void:
	if _overlay == null:
		_ensure_overlay()
	if _overlay == null:
		return
	var next_signature: String = _current_trait_signature()
	if not force and next_signature == _trait_signature:
		if diagnostics_enabled:
			diagnostic_rebuild_skips += 1
		return
	_trait_signature = next_signature
	if diagnostics_enabled:
		diagnostic_rebuild_calls += 1
	# Clear existing
	if _vbox:
		for c in _vbox.get_children():
			c.queue_free()

	# Pull on-board team only
	var board_team: Array = (manager.player_team if manager else [])
	var compiled: Dictionary = {}
	if TraitCompiler and board_team is Array:
		compiled = TraitCompiler.compile(board_team)
	var counts: Dictionary = compiled.get("counts", {})
	var tiers: Dictionary = compiled.get("tiers", {})

	# Build visible list: traits on board only (count > 0)
	var ids: Array[String] = []
	for k in counts.keys():
		var c: int = int(counts[k])
		if c > 0:
			ids.append(String(k))

	# Partition active vs inactive
	var active: Array[String] = []
	var inactive: Array[String] = []
	for id in ids:
		var tier: int = int(tiers.get(id, -1))
		if tier >= 0:
			active.append(id)
		else:
			inactive.append(id)

	var thresholds_by_id: Dictionary = compiled.get("thresholds", {})
	active.sort_custom(func(a: String, b: String) -> bool:
		return _compare_traits(a, b, counts, thresholds_by_id, true)
	)
	inactive.sort_custom(func(a: String, b: String) -> bool:
		return _compare_traits(a, b, counts, thresholds_by_id, false)
	)

	var ordered: Array[String] = []
	for x: String in active: ordered.append(x)
	for y: String in inactive: ordered.append(y)

	# Create compact rows so the sort key is legible, not just implied by icon order.
	for id: String in ordered:
		_add_trait_row(id, active.has(id), int(counts.get(id, 0)), int(tiers.get(id, -1)), thresholds_by_id)

	_update_layout()

func _current_trait_signature() -> String:
	var board_team: Array = (manager.player_team if manager else [])
	var counts: Dictionary = {}
	for unit_value in board_team:
		if not (unit_value is Unit):
			continue
		var current_unit: Unit = unit_value as Unit
		for trait_value in current_unit.traits:
			var trait_id: String = String(trait_value)
			counts[trait_id] = int(counts.get(trait_id, 0)) + 1
	var keys: Array = counts.keys()
	keys.sort()
	var parts: PackedStringArray = PackedStringArray()
	for key_value in keys:
		var key: String = String(key_value)
		parts.append("%s=%d" % [key, int(counts.get(key, 0))])
	var signature: String = ""
	for index in range(parts.size()):
		if index > 0:
			signature += "|"
		signature += String(parts[index])
	return signature

func _item_grid() -> Control:
	if view == null:
		return null
	return view.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ContentRow/LeftItemArea/ItemStorageGrid")

func _update_layout() -> void:
	if _overlay == null or _scroll == null:
		return
	# With prebuilt panel, respect authored position/size; just ensure visibility
	_overlay.custom_minimum_size.x = WIDTH
	_scroll.visible = true
	if _vbox:
		_vbox.custom_minimum_size.x = max(1.0, float(WIDTH - (PADDING_X * 2)))

func _compare_traits(a: String, b: String, counts: Dictionary, thresholds_by_id: Dictionary, use_checkpoint: bool) -> bool:
	var count_a: int = int(counts.get(a, 0))
	var count_b: int = int(counts.get(b, 0))
	if use_checkpoint:
		var checkpoint_a: int = _activation_checkpoint(a, count_a, thresholds_by_id)
		var checkpoint_b: int = _activation_checkpoint(b, count_b, thresholds_by_id)
		if checkpoint_a != checkpoint_b:
			return checkpoint_a > checkpoint_b
	if count_a != count_b:
		return count_a > count_b
	var next_a: int = _next_checkpoint(a, count_a, thresholds_by_id)
	var next_b: int = _next_checkpoint(b, count_b, thresholds_by_id)
	if next_a != next_b:
		return next_a < next_b
	return _trait_display_name(a) < _trait_display_name(b)

func _add_trait_row(id: String, active_trait: bool, count: int, tier: int, thresholds_by_id: Dictionary) -> void:
	if _vbox == null:
		return
	var row: PanelContainer = PanelContainer.new()
	row.name = "TraitRow_%s" % id.to_lower().replace(" ", "_").replace("-", "_")
	row.custom_minimum_size = Vector2(float(WIDTH - (PADDING_X * 2)), float(ROW_HEIGHT))
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_theme_stylebox_override("panel", _make_trait_row_style(active_trait))

	var margin: MarginContainer = MarginContainer.new()
	margin.name = "Margin"
	margin.mouse_filter = Control.MOUSE_FILTER_PASS
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_bottom", 4)
	row.add_child(margin)

	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.name = "Row"
	hbox.mouse_filter = Control.MOUSE_FILTER_PASS
	hbox.add_theme_constant_override("separation", 8)
	margin.add_child(hbox)

	var trait_icon_scene: PackedScene = _get_trait_icon_scene()
	var icon: Control = trait_icon_scene.instantiate() as Control if trait_icon_scene != null else null
	if icon != null:
		icon.custom_minimum_size = Vector2(40.0, 40.0)
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if icon.has_method("set_trait"):
			icon.call("set_trait", id)
		if icon.has_method("set_active"):
			icon.call("set_active", active_trait)
		if icon.has_method("set_trait_state"):
			icon.call("set_trait_state", count, tier)
		hbox.add_child(icon)

	var text_box: VBoxContainer = VBoxContainer.new()
	text_box.name = "Text"
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text_box.add_theme_constant_override("separation", 0)
	hbox.add_child(text_box)

	var name_label: Label = Label.new()
	name_label.name = "TraitName"
	name_label.text = _trait_display_name(id)
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", Color(0.94, 0.87, 0.72, 1.0) if active_trait else Color(0.70, 0.66, 0.60, 0.92))
	text_box.add_child(name_label)

	var checkpoint_label: Label = Label.new()
	checkpoint_label.name = "TraitCheckpoint"
	checkpoint_label.text = _checkpoint_text(id, count, active_trait, thresholds_by_id)
	checkpoint_label.clip_text = true
	checkpoint_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	checkpoint_label.add_theme_font_size_override("font_size", 11)
	checkpoint_label.add_theme_color_override("font_color", Color(0.78, 0.62, 0.40, 0.96) if active_trait else Color(0.52, 0.48, 0.44, 0.90))
	text_box.add_child(checkpoint_label)

	var count_label: Label = Label.new()
	count_label.name = "TraitCount"
	count_label.custom_minimum_size = Vector2(30.0, 38.0)
	count_label.text = str(count)
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	count_label.add_theme_font_size_override("font_size", 18)
	count_label.add_theme_color_override("font_color", Color(1.0, 0.78, 0.36, 1.0) if active_trait else Color(0.72, 0.66, 0.58, 0.92))
	count_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.68))
	count_label.add_theme_constant_override("outline_size", 1)
	hbox.add_child(count_label)

	_vbox.add_child(row)

func _get_trait_icon_scene() -> PackedScene:
	if _trait_icon_scene == null:
		_trait_icon_scene = ResourceLoader.load(TRAIT_ICON_SCENE_PATH, "PackedScene") as PackedScene
	return _trait_icon_scene

func _make_trait_row_style(active_trait: bool) -> StyleBox:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.090, 0.052, 0.040, 0.88) if active_trait else Color(0.028, 0.024, 0.032, 0.80)
	style.border_color = Color(0.80, 0.50, 0.22, 0.86) if active_trait else Color(0.24, 0.22, 0.24, 0.82)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_right = 5
	style.corner_radius_bottom_left = 5
	style.shadow_size = 5
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.34)
	var modulate: Color = Color(1.08, 0.92, 0.72, 0.98) if active_trait else Color(0.58, 0.56, 0.54, 0.82)
	return GothicUIAssets.style_or_fallback(GothicUIAssets.small_button_style(modulate), style)

func _checkpoint_text(id: String, count: int, active_trait: bool, thresholds_by_id: Dictionary) -> String:
	if active_trait:
		var checkpoint: int = _activation_checkpoint(id, count, thresholds_by_id)
		return "checkpoint %d" % checkpoint
	var next_checkpoint: int = _next_checkpoint(id, count, thresholds_by_id)
	if next_checkpoint > 0:
		return "next %d" % next_checkpoint
	return "inactive"

func _activation_checkpoint(id: String, count: int, thresholds_by_id: Dictionary) -> int:
	var checkpoint: int = 0
	for threshold: int in _thresholds_for(id, thresholds_by_id):
		if count >= threshold:
			checkpoint = threshold
	return checkpoint

func _next_checkpoint(id: String, count: int, thresholds_by_id: Dictionary) -> int:
	for threshold: int in _thresholds_for(id, thresholds_by_id):
		if count < threshold:
			return threshold
	return 0

func _thresholds_for(id: String, thresholds_by_id: Dictionary) -> Array[int]:
	var out: Array[int] = []
	var raw: Variant = thresholds_by_id.get(id, [])
	if raw is Array:
		for value: Variant in raw:
			out.append(int(value))
	return out

func _trait_display_name(id: String) -> String:
	var path: String = "res://data/traits/%s.tres" % id
	if ResourceLoader.exists(path):
		var resource: Resource = load(path)
		var trait_def: TraitDef = resource as TraitDef
		if trait_def != null and String(trait_def.name).strip_edges() != "":
			return String(trait_def.name)
	return id.capitalize()
