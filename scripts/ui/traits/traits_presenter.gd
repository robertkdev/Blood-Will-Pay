extends RefCounted
class_name TraitsPresenter

const TraitCompiler := preload("res://scripts/game/traits/trait_compiler.gd")
const VisualTypeSystem: GDScript = preload("res://scripts/ui/visual_type_system.gd")
const UserSettingsScript: GDScript = preload("res://scripts/game/settings/user_settings.gd")
const TRAIT_ICON_SCENE_PATH: String = "res://scenes/ui/traits/TraitIcon.tscn"

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
const ICON_SIZE: int = 40

# Support-rail furniture: one quiet recessed row per trait. Activation keeps a
# single structural left edge plus a small checkpoint ladder; the trait's own
# symbol carries identity, and the count/checkpoint reads as its own field
# instead of a slash-joined uppercase string.
## Quiet recessed rows: the interior wash stays near-black in both states and a
## single muted edge carries activation, so the strip has one accent per row
## instead of a red box, a bright plate and a loud pip row competing.
const COLOR_ROW_ACTIVE_BG: Color = Color(0.055, 0.032, 0.030, 0.62)
const COLOR_ROW_INACTIVE_BG: Color = Color(0.022, 0.021, 0.026, 0.52)
const COLOR_ROW_ACTIVE_EDGE: Color = Color(0.42, 0.105, 0.115, 0.88)
const COLOR_ROW_INACTIVE_EDGE: Color = Color(0.15, 0.13, 0.14, 0.75)
const COLOR_NAME_ACTIVE: Color = Color(0.94, 0.89, 0.80, 1.0)
const COLOR_NAME_INACTIVE: Color = Color(0.68, 0.64, 0.59, 0.94)
const COLOR_VALUE_ACTIVE: Color = Color(0.88, 0.70, 0.42, 0.98)
const COLOR_VALUE_INACTIVE: Color = Color(0.55, 0.50, 0.46, 0.92)
const COLOR_PIP_REACHED: Color = Color(0.82, 0.52, 0.26, 0.96)
const COLOR_PIP_REACHED_INACTIVE: Color = Color(0.44, 0.30, 0.22, 0.90)
const COLOR_PIP_UNMET: Color = Color(0.28, 0.25, 0.24, 0.90)
const NAME_LINE_MIN_HEIGHT: float = 19.0
const MIN_NAME_FONT_SIZE: int = 10
const MIN_ICON_SIZE: float = 20.0
## Below this rail width the strip is dense: shorter rows, smaller symbols and
## tighter margins. The settled rail width decides, not the UI tier.
const DENSE_RAIL_WIDTH: float = 200.0
## Room the strip reserves for its own vertical scrollbar so the row interior
## can never end up wider than the scroll viewport.
const SCROLLBAR_ALLOWANCE: float = 16.0
## One physical row rhythm for every UI scale, so an enlarged UI gets denser
## logical rows instead of taller ones that push the strip past its region.
const ROW_PITCH_PHYSICAL: float = 46.0
const ROW_MIN_HEIGHT: float = 30.0
const ROW_MAX_HEIGHT: float = 48.0
## Traits the strip tries to keep visible before it starts scrolling.
const TARGET_VISIBLE_ROWS: float = 5.0

var _layout_width: float = float(WIDTH)
var _layout_row_height: float = float(ROW_HEIGHT)
var _layout_icon_size: float = float(ICON_SIZE)
var _compact_layout: bool = false

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

func set_compact_layout(width: float, row_height: float, icon_size: float, compact: bool) -> void:
	# Hints only: once the rail has settled its own width, _update_layout derives
	# the dense presentation from that width instead.
	_layout_width = maxf(96.0, width)
	_layout_row_height = maxf(32.0, row_height)
	_layout_icon_size = maxf(22.0, icon_size)
	_compact_layout = compact
	_update_layout()
	if _vbox == null:
		return
	for child: Node in _vbox.get_children():
		var row: PanelContainer = child as PanelContainer
		if row != null:
			_apply_trait_row_layout(row)

func teardown() -> void:
	if view != null and is_instance_valid(view) and view.is_connected("resized", Callable(self, "_on_view_resized")):
		view.resized.disconnect(_on_view_resized)
	if manager != null and is_instance_valid(manager) and manager.is_connected("team_stats_updated", Callable(self, "_on_team_stats_updated")):
		manager.team_stats_updated.disconnect(_on_team_stats_updated)
	if _vbox != null and is_instance_valid(_vbox):
		for c: Node in _vbox.get_children():
			# Detach before freeing: a queued node still counts toward the rail's
			# measured interior minimum until idle deletion.
			_vbox.remove_child(c)
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
		for c: Node in _vbox.get_children():
			# Detach first so the rebuilt rows never coexist with the outgoing
			# ones inside a measured minimum-size pass.
			_vbox.remove_child(c)
			c.queue_free()

	# Pull on-board team only
	var board_team: Array = (manager.player_team if manager else [])
	var compiled: Dictionary = {}
	if TraitCompiler and board_team is Array:
		compiled = _compile_board(board_team)
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
	var compiled: Dictionary = {}
	if TraitCompiler and board_team is Array:
		compiled = _compile_board(board_team)
	var counts: Dictionary = compiled.get("counts", {})
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

## The manager publishes the on-board team as an untyped Array while
## TraitCompiler.compile() takes a typed Array[Unit]; coerce at the boundary so
## the call itself never fails its typed-array contract.
func _compile_board(board_team: Array) -> Dictionary:
	var roster: Array[Unit] = []
	for entry: Variant in board_team:
		if entry is Unit:
			roster.append(entry)
	return TraitCompiler.compile(roster)

func _item_grid() -> Control:
	if view == null:
		return null
	return view.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ContentRow/LeftItemArea/ItemStorageGrid")

func _update_layout() -> void:
	if _overlay == null or _scroll == null:
		return
	# The rail's real allotted width is the authority; the pushed width is only an
	# early hint. Row height, symbol size and density all follow that width, so
	# the strip adapts wherever the composition puts it.
	if _overlay.size.x > 1.0:
		_layout_width = maxf(96.0, _overlay.size.x)
		_layout_row_height = _row_height_for(_layout_width)
		_layout_icon_size = clampf(minf(_icon_size_for_width(_layout_width), _layout_row_height - 4.0), MIN_ICON_SIZE, 40.0)
		_compact_layout = _layout_width < DENSE_RAIL_WIDTH
	# The composition and the combat view own the rail's outer width. This only
	# measures the rect it was given; it never claims one, so the rail is never
	# widened by its own interior minimum.
	_scroll.visible = true
	_scroll.clip_contents = true
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	if _vbox:
		_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_vbox.add_theme_constant_override("separation", 2 if _compact_layout else SPACING)
		# Re-fit every row for the current rail width so a resize can never leave
		# a stale name or icon size behind.
		for child: Node in _vbox.get_children():
			var row: PanelContainer = child as PanelContainer
			if row != null:
				_apply_trait_row_layout(row)

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
	row.custom_minimum_size = Vector2(0.0, _layout_row_height)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	row.clip_contents = false
	row.set_meta("trait_id", id)
	row.set_meta("trait_count", count)
	row.set_meta("trait_active", active_trait)
	row.set_meta("trait_thresholds", thresholds_by_id)
	row.add_theme_stylebox_override("panel", _make_trait_row_style(active_trait))

	var margin: MarginContainer = MarginContainer.new()
	margin.name = "Margin"
	margin.mouse_filter = Control.MOUSE_FILTER_PASS
	margin.add_theme_constant_override("margin_left", _row_margin_x())
	margin.add_theme_constant_override("margin_top", _row_margin_y())
	margin.add_theme_constant_override("margin_right", _row_margin_x())
	margin.add_theme_constant_override("margin_bottom", _row_margin_y())
	row.add_child(margin)

	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.name = "Row"
	hbox.mouse_filter = Control.MOUSE_FILTER_PASS
	hbox.add_theme_constant_override("separation", _row_separation())
	margin.add_child(hbox)

	# The authored trait symbol is the fastest way to read this rail, and it is
	# also the hover and focus surface for the trait tooltip. It stays visible at
	# every rail width instead of collapsing into text-only telemetry.
	var trait_icon_scene: PackedScene = _get_trait_icon_scene()
	var icon: Control = trait_icon_scene.instantiate() as Control if trait_icon_scene != null else null
	if icon != null:
		icon.custom_minimum_size = Vector2(_icon_size(), _icon_size())
		icon.clip_contents = false
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

	var display_name: String = _trait_display_name(id)
	var name_label: Label = Label.new()
	name_label.name = "TraitName"
	name_label.text = display_name
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.custom_minimum_size.y = NAME_LINE_MIN_HEIGHT
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.tooltip_text = display_name
	VisualTypeSystem.set_gameplay_name(name_label)
	name_label.add_theme_color_override("font_color", COLOR_NAME_ACTIVE if active_trait else COLOR_NAME_INACTIVE)
	text_box.add_child(name_label)

	# The count and its checkpoint are their own quiet field, followed by a
	# small ladder of activation marks. Nothing here needs an uppercase slash
	# string to stay readable.
	var meta_box: HBoxContainer = HBoxContainer.new()
	meta_box.name = "Meta"
	meta_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meta_box.add_theme_constant_override("separation", 6)
	text_box.add_child(meta_box)

	var progress_label: Label = Label.new()
	progress_label.name = "TraitCheckpoint"
	progress_label.text = _progress_text(id, count, active_trait, thresholds_by_id)
	progress_label.clip_text = true
	progress_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	progress_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	progress_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	progress_label.tooltip_text = _checkpoint_text(id, count, active_trait, thresholds_by_id)
	VisualTypeSystem.set_gameplay_numeric(progress_label)
	progress_label.add_theme_color_override("font_color", COLOR_VALUE_ACTIVE if active_trait else COLOR_VALUE_INACTIVE)
	meta_box.add_child(progress_label)

	var pips: HBoxContainer = HBoxContainer.new()
	pips.name = "TraitPips"
	pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pips.add_theme_constant_override("separation", 2)
	meta_box.add_child(pips)
	# The marks are populated by _apply_trait_row_layout below, which knows the
	# rail width and can size them so the count/checkpoint keeps its room.

	_vbox.add_child(row)
	_apply_trait_row_layout(row)

func _apply_trait_row_layout(row: PanelContainer) -> void:
	# No horizontal minimum: the rail's width is the composition's to set, and the
	# row fills whatever it is given. Name fitting measures that rect instead.
	row.custom_minimum_size = Vector2(0.0, _layout_row_height)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.clip_contents = false
	var margin: MarginContainer = row.get_node_or_null("Margin") as MarginContainer
	if margin != null:
		margin.add_theme_constant_override("margin_left", _row_margin_x())
		margin.add_theme_constant_override("margin_top", _row_margin_y())
		margin.add_theme_constant_override("margin_right", _row_margin_x())
		margin.add_theme_constant_override("margin_bottom", _row_margin_y())
	var row_box: HBoxContainer = row.get_node_or_null("Margin/Row") as HBoxContainer
	if row_box == null:
		return
	row_box.add_theme_constant_override("separation", _row_separation())
	var icon: Control = row_box.get_node_or_null("TraitIcon") as Control
	if icon != null:
		icon.visible = true
		icon.custom_minimum_size = Vector2(_icon_size(), _icon_size())
		icon.clip_contents = false
		for descendant: Node in icon.find_children("*", "Control", true, false):
			var icon_child: Control = descendant as Control
			if icon_child != null:
				icon_child.custom_minimum_size = Vector2.ZERO
	var name_label: Label = row.get_node_or_null("Margin/Row/Text/TraitName") as Label
	var progress_label: Label = row.get_node_or_null("Margin/Row/Text/Meta/TraitCheckpoint") as Label
	var pips: HBoxContainer = row.get_node_or_null("Margin/Row/Text/Meta/TraitPips") as HBoxContainer
	var trait_id: String = String(row.get_meta("trait_id", ""))
	var trait_count: int = int(row.get_meta("trait_count", 0))
	var trait_active: bool = bool(row.get_meta("trait_active", false))
	var trait_thresholds: Dictionary = row.get_meta("trait_thresholds", {}) as Dictionary
	var display_name: String = _trait_display_name(trait_id)
	var available_width: float = _name_available_width(row)
	if name_label != null:
		# Re-assert the role before measuring: the fit has to use the face that
		# will actually be drawn, not a sibling face with different metrics.
		VisualTypeSystem.set_gameplay_name(name_label)
	var name_font: Font = name_label.get_theme_font("font") if name_label != null else VisualTypeSystem.FONT_UTILITY
	var fit: Dictionary = _fit_trait_name(display_name, available_width, name_font)
	var chosen_size: int = int(fit.get("font_size", MIN_NAME_FONT_SIZE))
	var progress_size: int = maxi(MIN_NAME_FONT_SIZE, chosen_size - 2)
	var value_width: float = 0.0
	if name_label != null:
		var fitted_name: String = String(fit.get("text", display_name))
		name_label.text = fitted_name
		name_label.set_meta("trait_name_source", display_name)
		name_label.set_meta("trait_name_complete", fitted_name == display_name)
		name_label.tooltip_text = display_name
		name_label.clip_text = true
		name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		name_label.custom_minimum_size = Vector2(0.0, NAME_LINE_MIN_HEIGHT)
		name_label.add_theme_font_size_override("font_size", chosen_size)
		name_label.add_theme_color_override("font_color", COLOR_NAME_ACTIVE if trait_active else COLOR_NAME_INACTIVE)
	if progress_label != null:
		VisualTypeSystem.set_gameplay_numeric(progress_label)
		var progress_text: String = _progress_text(trait_id, trait_count, trait_active, trait_thresholds)
		progress_label.text = progress_text
		progress_label.tooltip_text = _checkpoint_text(trait_id, trait_count, trait_active, trait_thresholds)
		progress_label.add_theme_font_size_override("font_size", progress_size)
		progress_label.add_theme_color_override("font_color", COLOR_VALUE_ACTIVE if trait_active else COLOR_VALUE_INACTIVE)
		# The label lives in an HBox beside the pip row, and a clipped label is
		# measured at zero, so an underestimated reservation silently eats the
		# last glyph (it clipped the checkpoint's denominator). Reserve the width
		# the drawn string actually needs in the face that is actually rendered,
		# plus a hair of slack for hinting.
		var value_font: Font = progress_label.get_theme_font("font")
		value_width = _text_width(progress_text, value_font, progress_size) + 2.0
		progress_label.custom_minimum_size = Vector2(value_width, 0.0)
		progress_label.clip_text = true
		progress_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if pips != null:
		_update_trait_pips(pips, _thresholds_for(trait_id, trait_thresholds), trait_count, trait_active, available_width, value_width)

# --- Support-rail geometry and quiet marks ---

func _row_content_width() -> float:
	return maxf(64.0, _layout_width - float(PADDING_X * 2) - SCROLLBAR_ALLOWANCE)

func _row_margin_x() -> int:
	if _layout_width < 150.0:
		return 2
	if _layout_width < DENSE_RAIL_WIDTH:
		return 3
	if _layout_width < 260.0:
		return 4
	return 6

func _row_margin_y() -> int:
	return 1 if _compact_layout else 4

func _row_separation() -> int:
	return 5 if _layout_width < 150.0 else 6 if _compact_layout else 8

## Traits want the largest readable name the rail can hold; the rail width, not
## the UI tier, decides how far down the candidate list we walk.
func _preferred_name_font_size() -> int:
	return 14

func _row_height_for_width(width: float) -> float:
	if width < 150.0:
		return 32.0
	if width < DENSE_RAIL_WIDTH:
		return 36.0
	if width < 260.0:
		return 42.0
	return 48.0

## Row height is the smaller of what the width can carry and the physical row
## rhythm the current UI scale budgets, capped by the strip's own viewport so a
## long trait list scrolls instead of growing the rail.
func _row_height_for(width: float) -> float:
	var ui_scale: float = maxf(1.0, UserSettingsScript.get_ui_scale())
	var physical_height: float = clampf(ROW_PITCH_PHYSICAL / ui_scale, ROW_MIN_HEIGHT, ROW_MAX_HEIGHT)
	var wanted: float = minf(_row_height_for_width(width), physical_height)
	if _scroll != null and _scroll.size.y > 1.0:
		wanted = minf(wanted, _scroll.size.y / TARGET_VISIBLE_ROWS)
	return clampf(wanted, ROW_MIN_HEIGHT, ROW_MAX_HEIGHT)

func _icon_size_for_width(width: float) -> float:
	if width < 150.0:
		return 22.0
	if width < DENSE_RAIL_WIDTH:
		return 24.0
	if width < 260.0:
		return 28.0
	return 30.0

func _icon_size() -> float:
	return clampf(_layout_icon_size, MIN_ICON_SIZE, 40.0)

func _name_available_width(row: Control) -> float:
	var icon_width: float = 0.0
	var separation: float = 0.0
	var row_box: HBoxContainer = row.get_node_or_null("Margin/Row") as HBoxContainer
	if row_box != null:
		separation = float(row_box.get_theme_constant("separation"))
		var icon: Control = row_box.get_node_or_null("TraitIcon") as Control
		if icon != null:
			icon_width = icon.custom_minimum_size.x
			if icon_width <= 0.0:
				icon_width = icon.size.x
	return maxf(32.0, _row_content_width() - float(_row_margin_x() * 2) - icon_width - separation)

func _fit_trait_name(display_name: String, available_width: float, font: Font = null) -> Dictionary:
	if font == null:
		font = VisualTypeSystem.FONT_UTILITY
	var preferred: int = _preferred_name_font_size()
	var chosen_size: int = MIN_NAME_FONT_SIZE
	for step: int in range(preferred - MIN_NAME_FONT_SIZE + 1):
		var candidate: int = preferred - step
		chosen_size = candidate
		if _text_width(display_name, font, candidate) + 1.0 <= available_width:
			return {"text": display_name, "font_size": candidate}
	# Only a genuinely narrow rail abbreviates, and the authored name stays
	# complete in the row tooltip.
	return {"text": _trim_text_to_width(display_name, font, chosen_size, available_width), "font_size": chosen_size}

func _text_width(text: String, font: Font, font_size: int) -> float:
	if font != null:
		return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	return float(text.length() * 7)

func _trim_text_to_width(text: String, font: Font, font_size: int, max_width: float) -> String:
	if text.length() <= 1:
		return text
	var suffix: String = "..."
	var trimmed: String = text
	while trimmed.length() > 1 and _text_width(trimmed + suffix, font, font_size) > max_width:
		trimmed = trimmed.left(trimmed.length() - 1)
	return trimmed + suffix

func _progress_text(id: String, count: int, active_trait: bool, thresholds_by_id: Dictionary) -> String:
	var bound: int = _activation_checkpoint(id, count, thresholds_by_id) if active_trait else _next_checkpoint(id, count, thresholds_by_id)
	if bound <= 0:
		return str(count)
	return "%d / %d" % [count, bound]

func _update_trait_pips(pips: HBoxContainer, thresholds: Array[int], count: int, active_trait: bool, available_width: float = 0.0, value_width: float = 0.0) -> void:
	if pips == null:
		return
	var reached: int = 0
	for threshold: int in thresholds:
		if count >= threshold:
			reached += 1
	var pip_size: float = 5.0 if _compact_layout else 6.0
	var pip_separation: int = 2
	var show_marks: bool = not thresholds.is_empty()
	if show_marks and available_width > 0.0:
		# The value keeps its own room; the marks shrink before anything is
		# clipped. A truly narrow rail drops the marks rather than overflowing.
		var available_for_pips: float = available_width - value_width - 6.0
		var count_pips: int = thresholds.size()
		var nominal_total: float = float(count_pips) * pip_size + float(maxi(0, count_pips - 1) * pip_separation)
		if nominal_total > available_for_pips:
			pip_separation = 1
			var floor_total: float = float(count_pips) * 3.0 + float(maxi(0, count_pips - 1))
			if floor_total > available_for_pips:
				show_marks = false
			else:
				pip_size = clampf((available_for_pips - float(maxi(0, count_pips - 1))) / float(count_pips), 3.0, pip_size)
	# This runs from layout/resize paths, so it must be idempotent: the marks are
	# reconciled in place, and a pass whose marks already match returns without
	# touching the container or its children.
	var wanted_count: int = thresholds.size() if show_marks else 0
	var signature: String = "%d/%d/%s/%.1f/%d" % [wanted_count, reached, str(active_trait), pip_size, pip_separation]
	if String(pips.get_meta("pip_signature", "")) == signature:
		pips.visible = show_marks
		return
	pips.set_meta("pip_signature", signature)
	pips.visible = show_marks
	_reconcile_trait_pips(pips, wanted_count)
	if not show_marks:
		return
	pips.add_theme_constant_override("separation", pip_separation)
	for index in range(wanted_count):
		var pip: Panel = pips.get_child(index) as Panel
		if pip == null:
			continue
		pip.custom_minimum_size = Vector2(pip_size, pip_size)
		pip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pip.add_theme_stylebox_override("panel", _make_pip_style(index < reached, active_trait))

## Grows or shrinks the mark row in place. Extra marks are detached before they
## are freed, so an oversized minimum can never survive into the next layout
## pass while the node waits for idle deletion.
func _reconcile_trait_pips(pips: HBoxContainer, wanted_count: int) -> void:
	while pips.get_child_count() > wanted_count:
		var extra: Node = pips.get_child(pips.get_child_count() - 1)
		pips.remove_child(extra)
		extra.queue_free()
	var index: int = pips.get_child_count()
	while index < wanted_count:
		var pip: Panel = Panel.new()
		pip.name = "Pip_%d" % index
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pips.add_child(pip)
		index += 1

func _make_pip_style(reached: bool, active_trait: bool) -> StyleBox:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.corner_radius_top_left = 1
	style.corner_radius_top_right = 1
	style.corner_radius_bottom_right = 1
	style.corner_radius_bottom_left = 1
	if reached:
		style.bg_color = COLOR_PIP_REACHED if active_trait else COLOR_PIP_REACHED_INACTIVE
	else:
		style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
		style.border_color = COLOR_PIP_UNMET
		style.border_width_left = 1
		style.border_width_top = 1
		style.border_width_right = 1
		style.border_width_bottom = 1
	return style

func _get_trait_icon_scene() -> PackedScene:
	if _trait_icon_scene == null:
		_trait_icon_scene = ResourceLoader.load(TRAIT_ICON_SCENE_PATH, "PackedScene") as PackedScene
	return _trait_icon_scene

func _make_trait_row_style(active_trait: bool) -> StyleBox:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = COLOR_ROW_ACTIVE_BG if active_trait else COLOR_ROW_INACTIVE_BG
	style.border_color = COLOR_ROW_ACTIVE_EDGE if active_trait else COLOR_ROW_INACTIVE_EDGE
	# One structural left edge marks an active trait. The former bright red
	# rectangle on all four sides made every active row shout at once.
	style.border_width_left = 5 if active_trait else 2
	style.border_width_top = 0
	style.border_width_right = 0
	style.border_width_bottom = 0
	style.content_margin_left = 2.0
	style.content_margin_top = 0.0
	style.content_margin_right = 2.0
	style.content_margin_bottom = 0.0
	return style

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
