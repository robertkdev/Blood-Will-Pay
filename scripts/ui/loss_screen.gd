extends Control
class_name LossScreen

const Scoreboard := preload("res://scenes/ui/stats/Scoreboard.tscn")
const HighScore := preload("res://scripts/util/high_score.gd")
const GothicUIAssets: GDScript = preload("res://scripts/ui/gothic_ui_assets.gd")
const RunStateStore := preload("res://scripts/game/run/run_state_store.gd")

const BACKDROP_COLOR: Color = Color(0.006, 0.005, 0.008, 1.0)
const FRAME_COLOR: Color = Color(0.075, 0.057, 0.061, 1.0)
const FRAME_BORDER: Color = Color(0.48, 0.35, 0.18, 0.92)
const BLOOD_COLOR: Color = Color(0.74, 0.10, 0.08, 1.0)
const BONE_COLOR: Color = Color(0.86, 0.80, 0.68, 1.0)
const DULL_GOLD: Color = Color(0.79, 0.61, 0.32, 1.0)
const MUTED_TEXT: Color = Color(0.62, 0.57, 0.49, 1.0)

@onready var panel: PanelContainer = $Panel
@onready var backdrop: ColorRect = $Backdrop
@onready var frame_panel: PanelContainer = $Panel/Center/Frame
@onready var content_box: VBoxContainer = $Panel/Center/Frame/VBox
@onready var title_label: Label = $Panel/Center/Frame/VBox/Title
@onready var stage_label: Label = $Panel/Center/Frame/VBox/StageLabel
@onready var high_label: Label = $Panel/Center/Frame/VBox/HighLabel
@onready var stats_label: Label = $Panel/Center/Frame/VBox/Stats
@onready var scoreboard_holder: Control = $Panel/Center/Frame/VBox/ScoreboardHolder
@onready var new_game_button: Button = $Panel/Center/Frame/VBox/NewGameButton

var _tracker: StatsTracker = null
var _ready_done: bool = false
var _pending_populate: bool = false
var _new_game_hover_tween: Tween = null

func _ready() -> void:
	RunStateStore.clear()
	_ready_done = true
	_fit_full_rect()
	mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_styles()
	_wire_new_game_hover()
	if new_game_button and not new_game_button.is_connected("pressed", Callable(self, "_on_new_game")):
		new_game_button.pressed.connect(_on_new_game)
	if _pending_populate or _tracker != null:
		_pending_populate = false
		_populate()

func _exit_tree() -> void:
	teardown()

func teardown() -> void:
	if _new_game_hover_tween != null and is_instance_valid(_new_game_hover_tween):
		_new_game_hover_tween.kill()
	_new_game_hover_tween = null
	if new_game_button != null and is_instance_valid(new_game_button):
		if new_game_button.is_connected("pressed", Callable(self, "_on_new_game")):
			new_game_button.pressed.disconnect(_on_new_game)
		if new_game_button.is_connected("mouse_entered", Callable(self, "_on_new_game_hover_entered")):
			new_game_button.mouse_entered.disconnect(_on_new_game_hover_entered)
		if new_game_button.is_connected("mouse_exited", Callable(self, "_on_new_game_hover_exited")):
			new_game_button.mouse_exited.disconnect(_on_new_game_hover_exited)
		if new_game_button.is_connected("focus_entered", Callable(self, "_on_new_game_hover_entered")):
			new_game_button.focus_entered.disconnect(_on_new_game_hover_entered)
		if new_game_button.is_connected("focus_exited", Callable(self, "_on_new_game_hover_exited")):
			new_game_button.focus_exited.disconnect(_on_new_game_hover_exited)
		if new_game_button.is_connected("resized", Callable(self, "_sync_new_game_pivot")):
			new_game_button.resized.disconnect(_sync_new_game_pivot)
	if scoreboard_holder != null and is_instance_valid(scoreboard_holder):
		for child: Node in scoreboard_holder.get_children():
			if child.has_method("teardown"):
				child.call("teardown")
	_tracker = null

func configure(tracker: StatsTracker) -> void:
	_tracker = tracker
	if _ready_done:
		_populate()
	else:
		_pending_populate = true

func _populate() -> void:
	# Title
	if title_label:
		title_label.text = "Defeat"
	# Total-earned score and supporting run records.
	var stage_reached: int = 1
	var chapter_reached: int = 1
	var gs: Node = _get_autoload("GameState")
	if gs != null:
		stage_reached = int(gs.get("stage"))
		chapter_reached = int(gs.get("chapter"))
	var economy_record: Dictionary = {}
	var economy: Node = _get_autoload("Economy")
	if economy != null and economy.has_method("snapshot_run_record"):
		economy_record = economy.call("snapshot_run_record")
	economy_record["stage"] = stage_reached
	economy_record["chapter"] = chapter_reached
	economy_record["identities"] = _run_identity_ids()
	economy_record["contract_discoveries"] = _contract_discovery_ids()
	if stage_label:
		stage_label.text = "Total Earned: %dg  •  Chapter %d  •  Stage %d" % [
			int(economy_record.get("total_money_earned", 0)),
			chapter_reached,
			stage_reached,
		]
	var records: Dictionary = HighScore.submit_run(economy_record)
	if high_label:
		high_label.text = "Best Total Earned: %dg  •  Peak Bank: %dg" % [
			int(records.get("best_total_earned", 0)),
			int(records.get("peak_bankroll", 0)),
		]

	# Interesting run stats (from last battle tracker)
	var lines: Array[String] = []
	lines.append("Biggest Wager Won: %dg" % int(economy_record.get("biggest_wager_won", 0)))
	lines.append("Richest Fight: %dg" % int(economy_record.get("richest_fight", 0)))
	if _tracker != null:
		var use_run_totals: bool = _tracker.has_run_values("player")
		var dmg_total: float = _tracker.get_run_team_total("player", "damage") if use_run_totals else _tracker.get_team_total("player", "damage", "ALL")
		var heal_total: float = _tracker.get_run_team_total("player", "healing") if use_run_totals else _tracker.get_team_total("player", "healing", "ALL")
		var kills_total: float = _tracker.get_run_team_total("player", "kills") if use_run_totals else _tracker.get_team_total("player", "kills", "ALL")
		var rows: Array = _tracker.get_run_rows("player", "damage") if use_run_totals else _tracker.get_rows("player", "damage", "ALL")
		var top_name: String = ""
		var top_val: float = -1.0
		for raw_row in rows:
			if typeof(raw_row) != TYPE_DICTIONARY:
				continue
			var r: Dictionary = raw_row
			var v: float = float(r.get("value", 0.0))
			if v > top_val:
				top_val = v
				var u: Unit = r.get("unit") as Unit
				top_name = String(r.get("display_name", ""))
				if top_name == "":
					top_name = (u.name if u != null else "?")
		var prefix: String = "Run" if use_run_totals else "Team"
		lines.append("%s Damage: %d" % [prefix, int(dmg_total)])
		lines.append("%s Healing: %d" % [prefix, int(heal_total)])
		lines.append("%s Kills: %d" % [prefix, int(kills_total)])
		if top_val >= 0.0:
			lines.append("Top %s Damage: %s (%d)" % [prefix, top_name, int(top_val)])
	if stats_label:
		stats_label.text = "\n".join(lines)

	# Scoreboard (player damage, expanded shows enemy in overlay sidebar)
	if scoreboard_holder and scoreboard_holder.get_child_count() == 0:
		var sb: Node = Scoreboard.instantiate()
		scoreboard_holder.add_child(sb)
		if _tracker != null and sb.has_method("configure"):
			sb.configure(_tracker)
		var scoreboard_window: String = "RUN" if _tracker != null and _tracker.has_run_values("player") else "ALL"
		if sb.has_method("set_title"):
			sb.set_title("Run Damage Leaders" if scoreboard_window == "RUN" else "Final Battle Damage")
		if sb.has_method("set_metric"):
			sb.set_metric("damage")
		if sb.has_method("set_window"):
			sb.set_window(scoreboard_window)
		if sb.has_method("set_enemy_rows_enabled"):
			sb.set_enemy_rows_enabled(false)
		if sb.has_method("set_expand_enabled"):
			sb.set_expand_enabled(false)
		if sb.has_method("set_expanded"):
			sb.set_expanded(false)

func _on_new_game() -> void:
	# Reset run-related singletons and return to unit select flow
	var overlay_parent: Node = get_parent()
	var main: Node = _find_main()
	if main != null and main.has_method("request_new_run"):
		main.call("request_new_run")
		queue_free()
		if overlay_parent is CanvasLayer and not overlay_parent.is_queued_for_deletion():
			overlay_parent.queue_free()
		return
	var economy: Node = _get_autoload("Economy")
	if economy != null and economy.has_method("reset_run"):
		economy.call("reset_run")
	var shop: Node = _get_autoload("Shop")
	if shop != null and shop.has_method("reset_run"):
		shop.call("reset_run")
	var roster: Node = _get_autoload("Roster")
	if roster != null and roster.has_method("reset"):
		roster.call("reset")
	var gs: Node = _get_autoload("GameState")
	if gs != null:
		if gs.has_method("set_chapter_and_stage"):
			gs.call("set_chapter_and_stage", 1, 1)
		elif gs.has_method("set_stage"):
			gs.call("set_stage", 1)
	if main and main.has_method("_on_start"):
		main.call("_on_start")
	# Close this screen
	queue_free()
	if overlay_parent is CanvasLayer and not overlay_parent.is_queued_for_deletion():
		overlay_parent.queue_free()

func _get_autoload(autoload_name: String) -> Node:
	if not is_inside_tree():
		return null
	var root: Window = get_tree().root
	if root == null:
		return null
	var node: Node = root.get_node_or_null(autoload_name)
	if node == null:
		node = root.get_node_or_null("/root/%s" % String(autoload_name))
	return node

func _find_main() -> Node:
	if not is_inside_tree():
		return null
	var root: Window = get_tree().root
	if root == null:
		return null
	var main: Node = root.get_node_or_null("Main")
	if main == null:
		main = root.get_node_or_null("/root/Main")
	if main == null:
		main = root.find_child("Main", true, false)
	return main

func _run_identity_ids() -> Array[String]:
	var roster: Node = _get_autoload("Roster")
	var current_team: Array = []
	var main: Node = _find_main()
	if main != null:
		var combat_view: Node = main.get_node_or_null("CombatView")
		if combat_view != null:
			var manager: Variant = combat_view.get("manager")
			if manager != null:
				var team_value: Variant = manager.get("player_team")
				if team_value is Array:
					current_team = team_value
	var identities: Array[String] = []
	if roster != null and roster.has_method("owned_units"):
		var owned_value: Variant = roster.call("owned_units", current_team)
		if owned_value is Array:
			for raw_unit: Variant in owned_value:
				var unit: Unit = raw_unit as Unit
				if unit == null:
					continue
				var unit_id: String = String(unit.id).strip_edges()
				if unit_id != "" and not identities.has(unit_id):
					identities.append(unit_id)
	return identities

func _contract_discovery_ids() -> Array[String]:
	var shop: Node = _get_autoload("Shop")
	if shop == null or not shop.has_method("get_contract_snapshot"):
		return []
	var snapshot: Dictionary = shop.call("get_contract_snapshot")
	var history: Variant = snapshot.get("chosen_history", [])
	var discoveries: Array[String] = []
	if history is Array:
		for entry: Variant in history:
			if not entry is Dictionary:
				continue
			var contract_id: String = String((entry as Dictionary).get("id", "")).strip_edges()
			if contract_id != "" and not discoveries.has(contract_id):
				discoveries.append(contract_id)
	return discoveries

func _apply_styles() -> void:
	if panel != null:
		panel.add_theme_stylebox_override("panel", _make_style(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 0))
	if backdrop != null:
		backdrop.color = BACKDROP_COLOR
	if frame_panel != null:
		frame_panel.add_theme_stylebox_override("panel", GothicUIAssets.style_or_fallback(GothicUIAssets.wide_panel_style(), _make_style(FRAME_COLOR, FRAME_BORDER, 2, 8)))
	if content_box != null:
		content_box.add_theme_constant_override("separation", 16)
	if title_label != null:
		title_label.add_theme_color_override("font_color", BLOOD_COLOR)
		title_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.82))
		title_label.add_theme_constant_override("shadow_offset_x", 2)
		title_label.add_theme_constant_override("shadow_offset_y", 3)
	if stage_label != null:
		stage_label.add_theme_color_override("font_color", DULL_GOLD)
	if high_label != null:
		high_label.add_theme_color_override("font_color", BONE_COLOR)
	if stats_label != null:
		stats_label.add_theme_color_override("font_color", MUTED_TEXT)
		stats_label.add_theme_constant_override("line_spacing", 5)
	if scoreboard_holder != null:
		scoreboard_holder.custom_minimum_size = Vector2(720.0, 220.0)
	if new_game_button != null:
		new_game_button.focus_mode = Control.FOCUS_ALL
		new_game_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		new_game_button.add_theme_color_override("font_color", BONE_COLOR)
		new_game_button.add_theme_color_override("font_hover_color", Color(1.0, 0.92, 0.76, 1.0))
		new_game_button.add_theme_color_override("font_focus_color", Color(1.0, 0.92, 0.76, 1.0))
		new_game_button.add_theme_stylebox_override("normal", GothicUIAssets.style_or_fallback(GothicUIAssets.primary_button_style(), _make_style(Color(0.14, 0.053, 0.045, 1.0), FRAME_BORDER, 2, 5)))
		new_game_button.add_theme_stylebox_override("hover", GothicUIAssets.style_or_fallback(GothicUIAssets.primary_button_style(Color(1.16, 1.06, 0.92, 1.0)), _make_style(Color(0.20, 0.07, 0.055, 1.0), DULL_GOLD, 2, 5)))
		new_game_button.add_theme_stylebox_override("pressed", GothicUIAssets.style_or_fallback(GothicUIAssets.primary_button_style(Color(0.84, 0.70, 0.66, 1.0)), _make_style(Color(0.09, 0.035, 0.035, 1.0), BLOOD_COLOR, 2, 5)))
		new_game_button.add_theme_stylebox_override("focus", GothicUIAssets.focus_outline_style(5, DULL_GOLD))

func _wire_new_game_hover() -> void:
	if new_game_button == null:
		return
	new_game_button.pivot_offset = new_game_button.size * 0.5 if new_game_button.size != Vector2.ZERO else new_game_button.custom_minimum_size * 0.5
	if not new_game_button.is_connected("mouse_entered", Callable(self, "_on_new_game_hover_entered")):
		new_game_button.mouse_entered.connect(_on_new_game_hover_entered)
	if not new_game_button.is_connected("mouse_exited", Callable(self, "_on_new_game_hover_exited")):
		new_game_button.mouse_exited.connect(_on_new_game_hover_exited)
	if not new_game_button.is_connected("focus_entered", Callable(self, "_on_new_game_hover_entered")):
		new_game_button.focus_entered.connect(_on_new_game_hover_entered)
	if not new_game_button.is_connected("focus_exited", Callable(self, "_on_new_game_hover_exited")):
		new_game_button.focus_exited.connect(_on_new_game_hover_exited)
	if not new_game_button.is_connected("resized", Callable(self, "_sync_new_game_pivot")):
		new_game_button.resized.connect(_sync_new_game_pivot)

func _on_new_game_hover_entered() -> void:
	_apply_new_game_hover_motion(true)

func _on_new_game_hover_exited() -> void:
	_apply_new_game_hover_motion(false)

func _apply_new_game_hover_motion(active: bool) -> void:
	if new_game_button == null:
		return
	if _new_game_hover_tween != null and is_instance_valid(_new_game_hover_tween):
		_new_game_hover_tween.kill()
	new_game_button.modulate = Color(1.22, 1.12, 0.92, 1.0) if active else Color.WHITE
	_new_game_hover_tween = create_tween()
	_new_game_hover_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_new_game_hover_tween.tween_property(new_game_button, "scale", Vector2(1.04, 1.04) if active else Vector2.ONE, 0.10)

func _sync_new_game_pivot() -> void:
	if new_game_button != null:
		new_game_button.pivot_offset = new_game_button.size * 0.5 if new_game_button.size != Vector2.ZERO else new_game_button.custom_minimum_size * 0.5

func _fit_full_rect() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0
	if panel != null:
		panel.set_anchors_preset(Control.PRESET_FULL_RECT)
		panel.offset_left = 0.0
		panel.offset_top = 0.0
		panel.offset_right = 0.0
		panel.offset_bottom = 0.0
	if backdrop != null:
		backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
		backdrop.offset_left = 0.0
		backdrop.offset_top = 0.0
		backdrop.offset_right = 0.0
		backdrop.offset_bottom = 0.0

func _make_style(bg: Color, border: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 22
	style.content_margin_bottom = 22
	return style
