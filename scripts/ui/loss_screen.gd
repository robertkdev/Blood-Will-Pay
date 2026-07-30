extends Control
class_name LossScreen

const Scoreboard := preload("res://scenes/ui/stats/Scoreboard.tscn")
const HighScore := preload("res://scripts/util/high_score.gd")
const HardcoreUIAssets: GDScript = preload("res://scripts/ui/hardcore_ui_assets.gd")
const RunStateStore := preload("res://scripts/game/run/run_state_store.gd")
const VisualTypeSystem: GDScript = preload("res://scripts/ui/visual_type_system.gd")

const BACKDROP_COLOR: Color = Color(0.006, 0.005, 0.008, 1.0)
const FRAME_COLOR: Color = Color(0.024, 0.006, 0.010, 0.90)
const FRAME_BORDER: Color = Color(0.84, 0.79, 0.68, 0.96)
const BLOOD_COLOR: Color = Color(0.74, 0.10, 0.08, 1.0)
const BONE_COLOR: Color = Color(0.86, 0.80, 0.68, 1.0)
const DULL_GOLD: Color = Color(0.79, 0.61, 0.32, 1.0)
const MUTED_TEXT: Color = Color(0.62, 0.57, 0.49, 1.0)
const SUMMARY_INK: Color = Color(0.94, 0.89, 0.79, 1.0)
const SUMMARY_BLOOD_INK: Color = Color(1.0, 0.48, 0.38, 1.0)
const SUMMARY_KEYLINE: Color = Color(0.015, 0.010, 0.012, 0.96)

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
var _loss_art: TextureRect = null
var _record_header_label: Label = null
var _record_chronology_label: Label = null
var _record_stamp_label: Label = null
var _record_footer_label: Label = null
var _pressure_layer: Control = null
var _casualty_ghost_label: Label = null
var _frame_damage_layer: Control = null

func _ready() -> void:
	RunStateStore.clear()
	_ready_done = true
	_fit_full_rect()
	mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_styles()
	_wire_new_game_hover()
	if not get_viewport().size_changed.is_connected(_sync_layout):
		get_viewport().size_changed.connect(_sync_layout)
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
	if get_viewport() != null and get_viewport().size_changed.is_connected(_sync_layout):
		get_viewport().size_changed.disconnect(_sync_layout)

func configure(tracker: StatsTracker) -> void:
	_tracker = tracker
	if _ready_done:
		_populate()
	else:
		_pending_populate = true

func _populate() -> void:
	# Title
	if title_label:
		title_label.text = "THE RUN IS DEAD"
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
		stage_label.text = "TOTAL EARNED %dg  //  CHAPTER %d  //  STAGE %d" % [
			int(economy_record.get("total_money_earned", 0)),
			chapter_reached,
			stage_reached,
		]
	var records: Dictionary = HighScore.submit_run(economy_record)
	if high_label:
		high_label.text = "BEST HAUL %dg  //  PEAK BANK %dg" % [
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
			sb.set_title("DAMAGE RECORD // RUN LEADERS" if scoreboard_window == "RUN" else "DAMAGE RECORD // FINAL BATTLE")
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
		_style_loss_scoreboard(sb)

func _style_loss_scoreboard(scoreboard: Node) -> void:
	if scoreboard == null:
		return
	var scoreboard_title: Label = scoreboard.get_node_or_null("Header/Title") as Label
	if scoreboard_title != null:
		scoreboard_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		scoreboard_title.add_theme_font_size_override("font_size", 21)
		scoreboard_title.add_theme_color_override("font_color", Color(0.94, 0.84, 0.69, 1.0))
		VisualTypeSystem.set_utility_bold(scoreboard_title)
	for raw_row: Node in scoreboard.find_children("*", "ScoreboardRow", true, false):
		if raw_row.has_method("set_record_emphasis"):
			raw_row.call("set_record_emphasis", true)

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
	_ensure_loss_art()
	_ensure_pressure_layer()
	_ensure_record_labels()
	_ensure_frame_damage()
	if frame_panel != null:
		frame_panel.add_theme_stylebox_override("panel", _make_loss_frame_style())
	if content_box != null:
		content_box.add_theme_constant_override("separation", 8)
	if title_label != null:
		title_label.text = "THE RUN IS DEAD"
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		VisualTypeSystem.set_impact(title_label)
		title_label.add_theme_color_override("font_color", BLOOD_COLOR)
		title_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.82))
		title_label.add_theme_constant_override("shadow_offset_x", 2)
		title_label.add_theme_constant_override("shadow_offset_y", 3)
	if stage_label != null:
		stage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		VisualTypeSystem.set_action(stage_label)
		_apply_summary_ink(stage_label, SUMMARY_BLOOD_INK)
	if high_label != null:
		high_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		VisualTypeSystem.set_utility_bold(high_label)
		_apply_summary_ink(high_label, SUMMARY_INK)
	if stats_label != null:
		stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		stats_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		stats_label.custom_minimum_size.y = 148.0
		VisualTypeSystem.set_utility(stats_label)
		_apply_summary_ink(stats_label, SUMMARY_INK)
		stats_label.add_theme_constant_override("line_spacing", 3)
		stats_label.add_theme_stylebox_override("normal", _make_damage_record_style())
	if scoreboard_holder != null:
		scoreboard_holder.custom_minimum_size = Vector2(840.0, 176.0)
	if new_game_button != null:
		new_game_button.text = "START NEW RUN"
		new_game_button.custom_minimum_size = Vector2(360.0, 64.0)
		VisualTypeSystem.set_impact(new_game_button)
		new_game_button.focus_mode = Control.FOCUS_ALL
		new_game_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		new_game_button.add_theme_color_override("font_color", BONE_COLOR)
		new_game_button.add_theme_color_override("font_hover_color", Color(1.0, 0.92, 0.76, 1.0))
		new_game_button.add_theme_color_override("font_focus_color", Color(1.0, 0.92, 0.76, 1.0))
		new_game_button.add_theme_color_override("font_pressed_color", Color(1.0, 0.74, 0.52, 1.0))
		new_game_button.add_theme_stylebox_override("normal", _make_restart_style("normal"))
		new_game_button.add_theme_stylebox_override("hover", _make_restart_style("hover"))
		new_game_button.add_theme_stylebox_override("pressed", _make_restart_style("pressed"))
		new_game_button.add_theme_stylebox_override("focus", _make_restart_style("focus"))
		new_game_button.add_theme_stylebox_override("disabled", _make_restart_style("disabled"))
		new_game_button.grab_focus()
	_sync_layout()

func _make_loss_frame_style() -> StyleBox:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.024, 0.006, 0.010, 0.94)
	style.border_color = Color(0.63, 0.10, 0.11, 0.98)
	style.border_width_left = 13
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 9
	style.set_corner_radius_all(0)
	style.content_margin_left = 52
	style.content_margin_right = 52
	style.content_margin_top = 38
	style.content_margin_bottom = 54
	style.shadow_color = Color(0.46, 0.0, 0.02, 0.42)
	style.shadow_size = 18
	style.shadow_offset = Vector2(12.0, 10.0)
	return style

func _ensure_frame_damage() -> void:
	if frame_panel == null:
		return
	_frame_damage_layer = frame_panel.get_node_or_null("FrameDamageLayer") as Control
	if _frame_damage_layer == null:
		_frame_damage_layer = Control.new()
		_frame_damage_layer.name = "FrameDamageLayer"
		_frame_damage_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame_panel.add_child(_frame_damage_layer)
		frame_panel.move_child(_frame_damage_layer, 0)
	_frame_damage_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	if _frame_damage_layer.get_child_count() > 0:
		return
	var reading_matte: ColorRect = ColorRect.new()
	reading_matte.name = "ReadingMatte"
	reading_matte.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reading_matte.color = Color(0.022, 0.006, 0.010, 0.82)
	reading_matte.set_anchors_preset(Control.PRESET_FULL_RECT)
	reading_matte.offset_left = 17.0
	reading_matte.offset_top = 16.0
	reading_matte.offset_right = -17.0
	reading_matte.offset_bottom = -16.0
	_frame_damage_layer.add_child(reading_matte)
	var wound_slash: ColorRect = ColorRect.new()
	wound_slash.name = "WoundSlash"
	wound_slash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wound_slash.color = Color(0.72, 0.012, 0.026, 0.38)
	wound_slash.anchor_left = 0.66
	wound_slash.anchor_top = 0.0
	wound_slash.anchor_right = 0.93
	wound_slash.anchor_bottom = 0.0
	wound_slash.offset_left = 0.0
	wound_slash.offset_top = 24.0
	wound_slash.offset_right = 0.0
	wound_slash.offset_bottom = 34.0
	wound_slash.rotation_degrees = -3.0
	_frame_damage_layer.add_child(wound_slash)
	var forfeit_stamp: Label = Label.new()
	forfeit_stamp.name = "ForfeitStamp"
	forfeit_stamp.text = "FOREST CLAIM // BODY COUNT FINAL"
	forfeit_stamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	forfeit_stamp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	forfeit_stamp.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	forfeit_stamp.anchor_left = 0.0
	forfeit_stamp.anchor_top = 1.0
	forfeit_stamp.anchor_right = 0.0
	forfeit_stamp.anchor_bottom = 1.0
	forfeit_stamp.offset_left = 52.0
	forfeit_stamp.offset_top = -47.0
	forfeit_stamp.offset_right = 390.0
	forfeit_stamp.offset_bottom = -16.0
	forfeit_stamp.rotation_degrees = -1.5
	forfeit_stamp.add_theme_font_size_override("font_size", 15)
	forfeit_stamp.add_theme_color_override("font_color", Color(0.92, 0.18, 0.16, 0.66))
	forfeit_stamp.add_theme_stylebox_override("normal", _make_record_stamp_style())
	VisualTypeSystem.set_action(forfeit_stamp)
	_frame_damage_layer.add_child(forfeit_stamp)

func _ensure_record_labels() -> void:
	if content_box == null:
		return
	_record_header_label = content_box.get_node_or_null("RecordHeader") as Label
	if _record_header_label == null:
		_record_header_label = Label.new()
		_record_header_label.name = "RecordHeader"
		content_box.add_child(_record_header_label)
	_record_header_label.text = "CASUALTY / DEBT RECORD  //  NO SURVIVORS  //  FILE 0X-13"
	_record_header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_record_header_label.add_theme_font_size_override("font_size", 17)
	VisualTypeSystem.set_utility_bold(_record_header_label)
	_record_header_label.add_theme_color_override("font_color", Color(0.71, 0.64, 0.54, 1.0))
	content_box.move_child(_record_header_label, 0)

	_record_chronology_label = content_box.get_node_or_null("RecordChronology") as Label
	if _record_chronology_label == null:
		_record_chronology_label = Label.new()
		_record_chronology_label.name = "RecordChronology"
		content_box.add_child(_record_chronology_label)
	_record_chronology_label.text = "01 WAGER CLAIMED  /  02 COMPANY ERASED  /  03 ACCOUNT CLOSED"
	_record_chronology_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_record_chronology_label.add_theme_font_size_override("font_size", 17)
	VisualTypeSystem.set_utility_bold(_record_chronology_label)
	_record_chronology_label.add_theme_color_override("font_color", Color(0.92, 0.43, 0.36, 0.96))
	var chronology_index: int = title_label.get_index() + 1 if title_label != null else 2
	content_box.move_child(_record_chronology_label, chronology_index)

	_record_stamp_label = content_box.get_node_or_null("RecordStamp") as Label
	if _record_stamp_label == null:
		_record_stamp_label = Label.new()
		_record_stamp_label.name = "RecordStamp"
		content_box.add_child(_record_stamp_label)
	_record_stamp_label.text = "ACCOUNT CLOSED // NAMES CROSSED OUT"
	_record_stamp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_record_stamp_label.custom_minimum_size.y = 44.0
	_record_stamp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_record_stamp_label.add_theme_font_size_override("font_size", 18)
	VisualTypeSystem.set_action(_record_stamp_label)
	_record_stamp_label.add_theme_color_override("font_color", Color(1.0, 0.46, 0.36, 1.0))
	_record_stamp_label.add_theme_stylebox_override("normal", _make_record_stamp_style())
	var stamp_index: int = high_label.get_index() + 1 if high_label != null else min(4, content_box.get_child_count() - 1)
	content_box.move_child(_record_stamp_label, stamp_index)

	_record_footer_label = content_box.get_node_or_null("RecordFooter") as Label
	if _record_footer_label == null:
		_record_footer_label = Label.new()
		_record_footer_label.name = "RecordFooter"
		content_box.add_child(_record_footer_label)
	_record_footer_label.text = "NO APPEAL // THE WOODS KEEP THE BALANCE // WALK BACK IN"
	_record_footer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_record_footer_label.add_theme_font_size_override("font_size", 16)
	VisualTypeSystem.set_utility_bold(_record_footer_label)
	_record_footer_label.add_theme_color_override("font_color", Color(0.68, 0.59, 0.49, 0.92))
	var button_index: int = new_game_button.get_index() if new_game_button != null else content_box.get_child_count() - 1
	content_box.move_child(_record_footer_label, button_index)

func _make_record_stamp_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.19, 0.018, 0.025, 0.62)
	style.border_color = Color(0.68, 0.055, 0.075, 0.94)
	style.border_width_left = 7
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 7.0
	style.content_margin_bottom = 7.0
	return style

func _make_damage_record_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.012, 0.009, 0.012, 0.90)
	style.border_color = Color(0.52, 0.075, 0.082, 0.94)
	style.border_width_left = 9
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 2
	style.content_margin_left = 18.0
	style.content_margin_right = 18.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	style.set_corner_radius_all(0)
	return style

func _make_environment_stamp_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.16, 0.008, 0.018, 0.72)
	style.border_color = Color(0.88, 0.075, 0.085, 0.94)
	style.border_width_left = 8
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 7.0
	style.content_margin_bottom = 7.0
	style.set_corner_radius_all(0)
	return style

func _make_restart_style(state: String) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	var normalized_state: String = state.strip_edges().to_lower()
	match normalized_state:
		"hover", "focus":
			style.bg_color = Color(0.58, 0.025, 0.045, 1.0)
			style.border_color = Color(1.0, 0.42, 0.23, 1.0)
			style.border_width_left = 10
		"pressed":
			style.bg_color = Color(0.25, 0.012, 0.020, 1.0)
			style.border_color = Color(0.92, 0.62, 0.28, 1.0)
			style.border_width_left = 12
		"disabled":
			style.bg_color = Color(0.030, 0.026, 0.030, 0.96)
			style.border_color = Color(0.30, 0.27, 0.25, 0.88)
			style.border_width_left = 5
		_:
			style.bg_color = Color(0.42, 0.018, 0.034, 0.98)
			style.border_color = Color(0.82, 0.085, 0.090, 0.98)
			style.border_width_left = 8
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.content_margin_left = 20.0
	style.content_margin_right = 20.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.52)
	style.shadow_size = 5
	return style

func _apply_summary_ink(label: Label, color: Color) -> void:
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", SUMMARY_KEYLINE)
	label.add_theme_constant_override("outline_size", 3)

func _ensure_loss_art() -> void:
	_loss_art = get_node_or_null("LossBackdropArt") as TextureRect
	if _loss_art == null:
		_loss_art = TextureRect.new()
		_loss_art.name = "LossBackdropArt"
		_loss_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_loss_art)
		move_child(_loss_art, 1)
	_loss_art.set_anchors_preset(Control.PRESET_FULL_RECT)
	_loss_art.texture = HardcoreUIAssets.loss_backdrop_texture()
	_loss_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_loss_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_loss_art.z_index = 0
	_loss_art.modulate = Color(1.82, 1.34, 1.28, 1.0)
	if backdrop != null:
		backdrop.z_index = -1
	if panel != null:
		panel.z_index = 10

func _ensure_pressure_layer() -> void:
	_pressure_layer = get_node_or_null("LossPressureLayer") as Control
	if _pressure_layer == null:
		_pressure_layer = Control.new()
		_pressure_layer.name = "LossPressureLayer"
		_pressure_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_pressure_layer)
	_pressure_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pressure_layer.z_index = 2
	if _pressure_layer.get_child_count() == 0:
		var blood_fall: ColorRect = ColorRect.new()
		blood_fall.name = "BloodFall"
		blood_fall.mouse_filter = Control.MOUSE_FILTER_IGNORE
		blood_fall.color = Color(0.42, 0.0, 0.015, 0.20)
		blood_fall.anchor_left = 0.0
		blood_fall.anchor_top = 0.0
		blood_fall.anchor_right = 0.16
		blood_fall.anchor_bottom = 1.0
		_pressure_layer.add_child(blood_fall)
		var wound_band: ColorRect = ColorRect.new()
		wound_band.name = "WoundBand"
		wound_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
		wound_band.color = Color(0.62, 0.005, 0.018, 0.14)
		wound_band.anchor_left = 0.0
		wound_band.anchor_top = 0.14
		wound_band.anchor_right = 1.0
		wound_band.anchor_bottom = 0.18
		wound_band.rotation_degrees = -2.0
		_pressure_layer.add_child(wound_band)
		_casualty_ghost_label = Label.new()
		_casualty_ghost_label.name = "CasualtyGhost"
		_casualty_ghost_label.text = "DEBT COLLECTED"
		_casualty_ghost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_casualty_ghost_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
		_casualty_ghost_label.rotation_degrees = -2.0
		_casualty_ghost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_casualty_ghost_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_casualty_ghost_label.add_theme_font_size_override("font_size", 34)
		_casualty_ghost_label.add_theme_color_override("font_color", Color(0.98, 0.24, 0.19, 0.92))
		_casualty_ghost_label.add_theme_color_override("font_outline_color", Color(0.015, 0.006, 0.009, 0.96))
		_casualty_ghost_label.add_theme_constant_override("outline_size", 3)
		_casualty_ghost_label.add_theme_stylebox_override("normal", _make_environment_stamp_style())
		VisualTypeSystem.set_impact(_casualty_ghost_label)
		_casualty_ghost_label.z_index = 30
		_pressure_layer.add_child(_casualty_ghost_label)

func _sync_layout() -> void:
	if frame_panel == null:
		return
	var viewport_size: Vector2 = get_viewport_rect().size
	var frame_width: float = clampf(viewport_size.x - 96.0, 900.0, 1120.0)
	var frame_height: float = clampf(viewport_size.y - 96.0, 680.0, 780.0)
	frame_panel.custom_minimum_size = Vector2(frame_width, frame_height)
	if _casualty_ghost_label != null:
		var frame_origin: Vector2 = (viewport_size - Vector2(frame_width, frame_height)) * 0.5
		_casualty_ghost_label.position = Vector2(frame_origin.x + frame_width - 346.0, frame_origin.y + 45.0)
		_casualty_ghost_label.size = Vector2(302.0, 62.0)

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
