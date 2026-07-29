extends Node

const MAIN_SCENE: PackedScene = preload("res://scenes/Main.tscn")
const MainTransitionWait: GDScript = preload("res://tests/visual/main_transition_wait.gd")
const UNIT_FACTORY := preload("res://scripts/unit_factory.gd")
const PLAYER_TEAM: Array[String] = ["mortem", "berebell", "bonko"]

var _main: Control = null
var _view: Control = null
var _stats_panel: Control = null
var _scoreboard: Node = null
var _unit_panel: Control = null
var _manager: CombatManager = null
var _previous_suppress_validation_warnings: bool = false
var _failures: Array[String] = []
var _last_activation_target: String = ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_run")

func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	var window: Window = get_window()
	if window != null:
		window.size = Vector2i(1920, 1080)
		window.content_scale_size = Vector2i(1920, 1080)
	_previous_suppress_validation_warnings = UNIT_FACTORY.suppress_validation_warnings
	UNIT_FACTORY.suppress_validation_warnings = true

	_main = MAIN_SCENE.instantiate() as Control
	_main.set_anchors_preset(Control.PRESET_FULL_RECT)
	_main.offset_left = 0.0
	_main.offset_top = 0.0
	_main.offset_right = 0.0
	_main.offset_bottom = 0.0
	add_child(_main)
	await _settle_frames(8)
	if _main.has_method("_on_start"):
		_main.call("_on_start")
	await _settle_frames(8)
	if _main.has_method("_on_unit_selected"):
		_main.call("_on_unit_selected", "mortem")
	_view = await MainTransitionWait.for_combat_view(self, _main)
	if _view == null:
		_fail("CombatView missing")
		_finish()
		return
	if _view.has_method("set_player_team_ids"):
		_view.call("set_player_team_ids", PLAYER_TEAM)
	if _view.has_method("_init_game"):
		_view.call("_init_game")
	await _settle_frames(18)
	_resolve_refs()
	if _stats_panel == null or _scoreboard == null or _unit_panel == null or _manager == null:
		_fail("Stats panel refs missing")
		_finish()
		return
	_expect_generated_stats_styles("initial")

	await _verify_team_tab_clicks("planning team")
	await _verify_unit_mode_tab_clicks("planning unit")
	_start_combat()
	await _settle_frames(90)
	await _verify_team_tab_clicks("combat team")
	await _verify_unit_mode_tab_clicks("combat unit")
	_finish()

func _resolve_refs() -> void:
	_stats_panel = _view.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ContentRow/StatsArea/StatsPanel") as Control
	if _stats_panel != null:
		_scoreboard = _stats_panel.find_child("Scoreboard", true, false)
		_unit_panel = _stats_panel.find_child("UnitPanel", true, false) as Control
	_manager = _view.get("manager") as CombatManager

func _verify_team_tab_clicks(context: String) -> void:
	if _stats_panel.has_method("show_team_metrics"):
		_stats_panel.call("show_team_metrics")
	await _settle_frames(2)
	await _click_metric("DPS")
	await _settle_frames(3)
	_expect_team_mode("%s DPS click" % context)
	_expect_metric("dps", "%s DPS click" % context)
	await _click_metric("Casts")
	await _settle_frames(3)
	_expect_team_mode("%s Casts click" % context)
	_expect_metric("casts", "%s Casts click" % context)
	await _click_window("Window3s")
	await _settle_frames(3)
	_expect_team_mode("%s 3s click" % context)
	_expect_window("3S", "%s 3s click" % context)
	await _click_window("WindowAll")
	await _settle_frames(3)
	_expect_team_mode("%s All click" % context)
	_expect_window("ALL", "%s All click" % context)

func _verify_unit_mode_tab_clicks(context: String) -> void:
	var unit: Unit = _first_player_unit()
	if unit == null:
		_fail("%s: player unit missing" % context)
		return
	if _stats_panel.has_method("show_unit_metrics_ctx"):
		_stats_panel.call("show_unit_metrics_ctx", "player", 0, unit)
	await _settle_frames(3)
	_expect_unit_mode("%s setup" % context)
	_expect_unit_info_labels("%s setup" % context)
	await _click_metric("Damage")
	await _settle_frames(3)
	_expect_team_mode("%s Damage click should leave unit detail" % context)
	_expect_metric("damage", "%s Damage click" % context)
	if _stats_panel.has_method("show_unit_metrics_ctx"):
		_stats_panel.call("show_unit_metrics_ctx", "player", 0, unit)
	await _settle_frames(3)
	await _click_window("Window3s")
	await _settle_frames(3)
	_expect_team_mode("%s 3s click should leave unit detail" % context)
	_expect_window("3S", "%s 3s click" % context)

func _start_combat() -> void:
	if _view.has_method("_on_continue_pressed"):
		_view.call("_on_continue_pressed")

func _first_player_unit() -> Unit:
	if _manager == null or _manager.player_team.is_empty():
		return null
	return _manager.player_team[0] as Unit

func _click_metric(label: String) -> void:
	var tabs: Control = _stats_panel.find_child("MetricTabs", true, false) as Control
	if tabs == null:
		_fail("MetricTabs missing")
		return
	for child: Node in tabs.find_children("*", "Button", true, false):
		var button: Button = child as Button
		if button != null and button.text == label:
			await _click_control(button)
			return
	_fail("Metric button missing: %s" % label)

func _click_window(button_name: String) -> void:
	var button: Button = _stats_panel.find_child(button_name, true, false) as Button
	if button == null:
		_fail("Window button missing: %s" % button_name)
		return
	await _click_control(button)

func _click_control(control: Control) -> void:
	_last_activation_target = _node_path(control)
	if control == null or not is_instance_valid(control):
		_fail("Click target is invalid: %s" % _last_activation_target)
		return
	var rect: Rect2 = control.get_global_rect()
	var center: Vector2 = rect.get_center()
	_send_mouse_motion(center)
	await get_tree().process_frame
	_send_mouse_button(center, true)
	await get_tree().process_frame
	_send_mouse_button(center, false)
	await get_tree().process_frame

func _send_mouse_motion(position: Vector2) -> void:
	get_viewport().warp_mouse(position)
	var event: InputEventMouseMotion = InputEventMouseMotion.new()
	event.position = position
	event.global_position = position
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _send_mouse_button(position: Vector2, pressed: bool) -> void:
	get_viewport().warp_mouse(position)
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	event.position = position
	event.global_position = position
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _expect_team_mode(context: String) -> void:
	if _scoreboard == null or not (_scoreboard as CanvasItem).visible:
		_fail("%s: scoreboard is not visible" % context)
	if _unit_panel == null or _unit_panel.visible:
		_fail("%s: unit panel is still visible" % context)

func _expect_unit_mode(context: String) -> void:
	if _scoreboard == null or (_scoreboard as CanvasItem).visible:
		_fail("%s: scoreboard is visible in unit mode" % context)
	if _unit_panel == null or not _unit_panel.visible:
		_fail("%s: unit panel is not visible" % context)

func _expect_unit_info_labels(context: String) -> void:
	if _unit_panel == null:
		_fail("%s: unit panel missing for info label check" % context)
		return
	var attack_label: Label = _unit_panel.find_child("AttackInfo", true, false) as Label
	if attack_label == null or not String(attack_label.text).begins_with("Attack:"):
		_fail("%s: attack info label missing or empty" % context)
	var attack_targeting_label: Label = _unit_panel.find_child("AttackTargetingInfo", true, false) as Label
	if attack_targeting_label == null or not String(attack_targeting_label.text).begins_with("Attack Targeting:"):
		_fail("%s: attack targeting info label missing or empty" % context)
	var ability_label: Label = _unit_panel.find_child("AbilityInfo", true, false) as Label
	if ability_label == null or not String(ability_label.text).begins_with("Ability:"):
		_fail("%s: ability info label missing or empty" % context)
	var ability_targeting_label: Label = _unit_panel.find_child("AbilityTargetingInfo", true, false) as Label
	if ability_targeting_label == null or not String(ability_targeting_label.text).begins_with("Ability Targeting:"):
		_fail("%s: ability targeting info label missing or empty" % context)
	if ability_targeting_label != null and String(ability_targeting_label.text).find("Positioning:") >= 0:
		_fail("%s: unit info should not prescribe positioning" % context)
	var stats_grid: GridContainer = _unit_panel.find_child("StatsGrid", true, false) as GridContainer
	if stats_grid == null or stats_grid.get_child_count() == 0:
		_fail("%s: unit stat cards missing" % context)
	else:
		var stat_card: PanelContainer = stats_grid.get_child(0) as PanelContainer
		if stat_card == null or not (stat_card.get_theme_stylebox("panel") is StyleBoxTexture):
			_fail("%s: unit stat cards should use the generated card asset" % context)

func _expect_generated_stats_styles(context: String) -> void:
	var all_button: Button = _stats_panel.find_child("WindowAll", true, false) as Button
	var three_second_button: Button = _stats_panel.find_child("Window3s", true, false) as Button
	if all_button == null or not (all_button.get_theme_stylebox("normal") is StyleBoxTexture):
		_fail("%s: All window button should use the generated small button asset" % context)
	if three_second_button == null or not (three_second_button.get_theme_stylebox("normal") is StyleBoxTexture):
		_fail("%s: 3s window button should use the generated small button asset" % context)
	var tabs: Control = _stats_panel.find_child("MetricTabs", true, false) as Control
	if tabs == null:
		_fail("%s: metric tabs missing for style check" % context)
	else:
		var found_metric_button: bool = false
		for child: Node in tabs.find_children("*", "Button", true, false):
			var button: Button = child as Button
			if button == null:
				continue
			found_metric_button = true
			if not (button.get_theme_stylebox("normal") is StyleBoxTexture):
				_fail("%s: metric tab %s should use the generated small button asset" % [context, button.text])
				break
		if not found_metric_button:
			_fail("%s: no metric buttons found for style check" % context)
	var row_frame: Panel = _stats_panel.find_child("RowFrame", true, false) as Panel
	if row_frame != null and not (row_frame.get_theme_stylebox("panel") is StyleBoxTexture):
		_fail("%s: scoreboard row should use the generated row asset" % context)

func _expect_metric(expected: String, context: String) -> void:
	if _scoreboard == null:
		_fail("%s: scoreboard missing for metric check" % context)
		return
	var actual: String = String(_scoreboard.get("metric"))
	if actual != expected:
		_fail("%s: expected metric %s got %s target=%s" % [context, expected, actual, _last_activation_target])

func _expect_window(expected: String, context: String) -> void:
	if _scoreboard == null:
		_fail("%s: scoreboard missing for window check" % context)
		return
	var actual: String = String(_scoreboard.get("window"))
	if actual != expected:
		_fail("%s: expected window %s got %s target=%s" % [context, expected, actual, _last_activation_target])

func _node_path(node: Node) -> String:
	if node == null:
		return "<none>"
	return String(node.get_path())

func _settle_frames(count: int) -> void:
	for _frame_index: int in range(count):
		await get_tree().process_frame

func _fail(message: String) -> void:
	if not _failures.has(message):
		_failures.append(message)

func _finish() -> void:
	UNIT_FACTORY.suppress_validation_warnings = _previous_suppress_validation_warnings
	if _view != null and is_instance_valid(_view) and _view.has_method("_teardown"):
		_view.call("_teardown")
	if _main != null and is_instance_valid(_main):
		var parent_node: Node = _main.get_parent()
		if parent_node != null:
			parent_node.remove_child(_main)
		_main.free()
	_main = null
	_view = null
	_stats_panel = null
	_scoreboard = null
	_unit_panel = null
	_manager = null
	if _failures.is_empty():
		print("StatsPanelClickSmoke: OK")
		get_tree().quit(0)
		return
	for failure: String in _failures:
		push_error("StatsPanelClickSmoke: " + failure)
	get_tree().quit(1)
