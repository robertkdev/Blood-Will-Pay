extends Control
class_name Scoreboard

const ScoreboardModelLib := preload("res://scripts/ui/combat/stats/scoreboard_model.gd")
const ScoreboardRow := preload("res://scripts/ui/combat/stats/scoreboard_row.gd")
const TooltipSvc := preload("res://scripts/ui/combat/stats/tooltip_service.gd")
const GothicUIAssets: GDScript = preload("res://scripts/ui/gothic_ui_assets.gd")
const HardcoreUIAssets: GDScript = preload("res://scripts/ui/hardcore_ui_assets.gd")

@onready var expand_button: Button = $"Header/ExpandButton"
@onready var body_box: HBoxContainer = $"Body"
@onready var player_col: VBoxContainer = $"Body/PlayerColumn"
@onready var enemy_col: VBoxContainer = $"Body/EnemyColumn" # kept for non-overlay mode (currently unused)
@onready var title_label: Label = $"Header/Title"

# Floating overlay to show enemy column without reflowing the main layout
var overlay: Control
var overlay_enemy_col: VBoxContainer
var overlay_width: int = 320

var tracker: StatsTracker
var model: ScoreboardModel

var metric: String = "damage"
var window: String = "ALL"
var norm_mode: int = ScoreboardModel.NormMode.TEAM_SHARE
var expanded: bool = false
var expand_enabled: bool = true
var enemy_rows_enabled: bool = true

var refresh_interval: float = 0.3
var _accum: float = 0.0
var _authored_title: String = "Scoreboard"

func _ready() -> void:
	set_process(true)
	if expand_button and not expand_button.is_connected("pressed", Callable(self, "_on_toggle_expand")):
		expand_button.pressed.connect(_on_toggle_expand)
	_build_overlay()
	set_expanded(false)
	# Ensure in-panel enemy column never forces layout
	if enemy_col:
		enemy_col.visible = false
	_sync_responsive_header()

func _exit_tree() -> void:
	teardown()

func teardown() -> void:
	set_process(false)
	if expand_button != null and is_instance_valid(expand_button) and expand_button.is_connected("pressed", Callable(self, "_on_toggle_expand")):
		expand_button.pressed.disconnect(_on_toggle_expand)
	_clear_rows(player_col)
	_clear_rows(enemy_col)
	_clear_rows(overlay_enemy_col)
	if overlay != null and is_instance_valid(overlay):
		overlay.queue_free()
	overlay = null
	overlay_enemy_col = null
	model = null
	tracker = null

func configure(_tracker: StatsTracker) -> void:
	tracker = _tracker
	model = ScoreboardModelLib.new()
	model.configure(tracker)
	_rebuild_now()

func set_metric(m: String) -> void: metric = m
func set_window(w: String) -> void: window = w
func set_norm_mode(n: int) -> void: norm_mode = n
func set_title(text: String) -> void:
	_authored_title = text
	if title_label != null:
		title_label.text = text
	_sync_responsive_header()

func set_expand_enabled(flag: bool) -> void:
	expand_enabled = flag
	if not expand_enabled:
		set_expanded(false)
	_sync_expand_button()
	_sync_responsive_header()

func set_enemy_rows_enabled(flag: bool) -> void:
	enemy_rows_enabled = flag
	if not enemy_rows_enabled:
		set_expanded(false)
		_clear_rows(enemy_col)
		_clear_rows(overlay_enemy_col)
	_sync_expand_button()
	_rebuild_now()

func set_expanded(flag: bool) -> void:
	if flag and (not expand_enabled or not enemy_rows_enabled):
		flag = false
	expanded = flag
	if overlay:
		overlay.visible = expanded
		_layout_overlay()
	# Keep embedded enemy column hidden to avoid container expansion
	if enemy_col:
		enemy_col.visible = false
	_sync_expand_button()

func _on_toggle_expand() -> void:
	if not expand_enabled:
		set_expanded(false)
		return
	set_expanded(not expanded)

func _process(delta: float) -> void:
	_accum += max(0.0, float(delta))
	_sync_responsive_header()
	_restore_compact_row_identities()
	if _accum >= refresh_interval:
		_accum = 0.0
		_rebuild_now()
		if overlay and overlay.visible:
			_layout_overlay()

func _rebuild_now() -> void:
	if tracker == null:
		return
	var data: Dictionary = model.build(metric, window, norm_mode)
	_apply_rows(player_col, data.get("player_rows", []), float(data.get("player_total", 0.0)))
	if not enemy_rows_enabled:
		_clear_rows(enemy_col)
		_clear_rows(overlay_enemy_col)
		return
	var enemy_target: VBoxContainer = (overlay_enemy_col if expanded and overlay_enemy_col != null else enemy_col)
	_apply_rows(enemy_target, data.get("enemy_rows", []), float(data.get("enemy_total", 0.0)))

func _apply_rows(col: VBoxContainer, rows: Array, team_total: float) -> void:
	if col == null:
		return
	# Map existing by key
	var existing: Dictionary = {}
	for child in col.get_children():
		if child is ScoreboardRow:
			var key: String = _key(child.team, child.index)
			existing[key] = child
	# Build desired order; create missing
	var desired: Array[ScoreboardRow] = []
	for r in rows:
		var key2: String = _key(String(r.get("team")), int(r.get("index", -1)))
		var row_node: ScoreboardRow = existing.get(key2)
		if row_node == null:
			row_node = load("res://scenes/ui/stats/ScoreboardRow.tscn").instantiate()
			col.add_child(row_node)
		r["metric"] = metric
		row_node.set_row_data(r)
		# Tooltip using window + team_total context
		var uname: String = String(r.get("display_name", "")).strip_edges()
		var u: Unit = r.get("unit")
		if uname == "" and u != null:
			uname = String(u.name)
		var tip: String = TooltipSvc.row_tooltip(metric, window, float(r.get("value", 0.0)), float(r.get("share", 0.0)), uname, team_total)
		if metric == "damage" and tracker != null:
			var br: Dictionary = tracker.damage_breakdown(String(r.get("team")), int(r.get("index", -1)))
			if br != null and not br.is_empty():
				tip = TooltipSvc.row_tooltip(metric, window, float(r.get("value", 0.0)), float(r.get("share", 0.0)), uname, team_total, br)
		row_node.tooltip_text = tip
		desired.append(row_node)
	# Remove extras
	for child in col.get_children():
		if child is ScoreboardRow and not desired.has(child):
			child.queue_free()
	# Enforce order with a small tween hint
	for i in range(desired.size()):
		var node: Node = desired[i]
		if node.get_index() != i:
			node.owner = get_tree().edited_scene_root
			col.move_child(node, i)
			if node is ScoreboardRow:
				node.tween_reorder_hint()

func _clear_rows(col: VBoxContainer) -> void:
	if col == null or not is_instance_valid(col):
		return
	for child: Node in col.get_children():
		child.queue_free()

func _key(team: String, index: int) -> String:
	return "%s#%d" % [String(team), int(index)]

# --- Overlay helpers ---

func _build_overlay() -> void:
	if overlay != null:
		return
	overlay = Control.new()
	overlay.name = "Overlay"
	overlay.top_level = true
	overlay.visible = false
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 1000
	add_child(overlay)
	# Container inside overlay
	var panel: PanelContainer = PanelContainer.new()
	panel.name = "EnemyLedgerPanel"
	overlay.add_child(panel)
	panel.anchor_left = 0.0
	panel.anchor_right = 1.0
	panel.anchor_top = 0.0
	panel.anchor_bottom = 1.0
	panel.offset_left = 0.0
	panel.offset_right = 0.0
	panel.offset_top = 0.0
	panel.offset_bottom = 0.0
	panel.clip_contents = true
	panel.add_theme_stylebox_override("panel", _make_overlay_style())
	overlay_enemy_col = VBoxContainer.new()
	overlay_enemy_col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	overlay_enemy_col.add_theme_constant_override("separation", 8)
	panel.add_child(overlay_enemy_col)

func _layout_overlay() -> void:
	if overlay == null:
		return
	# Desired rect: match Body rows area and extend left
	var area_rect: Rect2 = (body_box.get_global_rect() if body_box != null else get_global_rect())
	var pc_rect: Rect2 = (player_col.get_global_rect() if player_col != null else Rect2())
	var w: float = pc_rect.size.x
	if w <= 0.0:
		w = float(overlay_width)
	var row_count: int = 0
	if overlay_enemy_col != null:
		row_count = overlay_enemy_col.get_child_count()
	var target_height: float = clampf(18.0 + float(row_count) * 62.0, 96.0, area_rect.size.y)
	overlay.position = Vector2(area_rect.position.x - w, area_rect.position.y)
	overlay.size = Vector2(w, target_height)

func _make_overlay_style() -> StyleBox:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.018, 0.015, 0.022, 0.96)
	style.border_color = Color(0.42, 0.050, 0.070, 0.88)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_right = 5
	style.corner_radius_bottom_left = 5
	style.shadow_size = 10
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.48)
	style.content_margin_left = 8
	style.content_margin_top = 8
	style.content_margin_right = 8
	style.content_margin_bottom = 8
	return GothicUIAssets.style_or_fallback(HardcoreUIAssets.stats_panel_style(), style)

func _sync_expand_button() -> void:
	if expand_button == null:
		return
	expand_button.visible = expand_enabled and enemy_rows_enabled
	expand_button.disabled = not expand_enabled or not enemy_rows_enabled
	var compact_header: bool = _uses_compact_header()
	expand_button.text = ("< YOU" if expanded else "FOE >") if compact_header else (">>" if expanded else "<<")
	expand_button.tooltip_text = "Hide enemy ledger" if expanded else "Show enemy ledger"

func _sync_responsive_header() -> void:
	var header: HBoxContainer = get_node_or_null("Header") as HBoxContainer
	if header == null or title_label == null:
		return
	var compact_header: bool = _uses_compact_header()
	header.visible = true
	title_label.clip_text = false
	if not compact_header:
		title_label.text = _authored_title
		title_label.size_flags_horizontal = Control.SIZE_SHRINK_END
		title_label.add_theme_font_size_override("font_size", 16)
		var desktop_spacer: Control = header.get_node_or_null("Spacer") as Control
		if desktop_spacer != null:
			desktop_spacer.visible = true
			desktop_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_sync_expand_button()
		return
	var tight_header: bool = size.x <= 150.0 or custom_minimum_size.x <= 150.0
	header.custom_minimum_size.y = 26.0 if tight_header else 30.0
	header.add_theme_constant_override("separation", 4)
	var spacer: Control = header.get_node_or_null("Spacer") as Control
	if spacer != null:
		spacer.visible = false
		spacer.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	if expand_button != null:
		expand_button.custom_minimum_size = Vector2(46.0 if tight_header else 54.0, 24.0)
		expand_button.add_theme_font_size_override("font_size", 10 if tight_header else 12)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 10 if tight_header else 12)
	title_label.text = "%s // %s" % [_metric_header_label(), _window_header_label()]
	title_label.tooltip_text = "Current metric: %s, window: %s" % [metric.capitalize(), window]
	title_label.set_meta("compact_metric_identity", true)
	header.set_meta("compact_navigation_visible", true)
	_sync_expand_button()

func _uses_compact_header() -> bool:
	var resolved_width: float = size.x
	if resolved_width <= 0.0:
		resolved_width = custom_minimum_size.x
	return resolved_width > 0.0 and resolved_width <= 310.0

func _metric_header_label() -> String:
	match metric.to_lower():
		"damage":
			return "DMG"
		"dps":
			return "DPS"
		"casts":
			return "CAST"
		"healing":
			return "HEAL"
		_:
			return metric.left(4).to_upper()

func _window_header_label() -> String:
	var normalized_window: String = window.strip_edges().to_upper()
	return "ALL" if normalized_window == "" else normalized_window.left(4)

func _restore_compact_row_identities() -> void:
	if not _uses_compact_header():
		return
	for row_node: Node in find_children("*", "ScoreboardRow", true, false):
		var row: ScoreboardRow = row_node as ScoreboardRow
		if row != null and bool(row.get_meta("compact_layout", false)):
			row.refresh_compact_identity()
