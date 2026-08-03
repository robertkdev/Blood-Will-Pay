extends Node

const MAIN_SCENE: PackedScene = preload("res://scenes/Main.tscn")
const MainTransitionWait: GDScript = preload("res://tests/visual/main_transition_wait.gd")
const OUTPUT_DIR: String = "res://outputs/visual_iter/stats_panel_pass"
const PLAYER_TEAM: Array[String] = ["mortem", "berebell", "bonko"]

var _main: Control = null
var _view: Control = null
var _stats_panel: Control = null
var _controller: Variant = null
var _manager: CombatManager = null
var _failures: Array[String] = []

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_main = MAIN_SCENE.instantiate() as Control
	add_child(_main)
	await _settle(0.25)
	if _main.has_method("_on_start"):
		_main.call("_on_start")
	await _settle(0.20)
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
	await _settle(0.45)
	_resolve_refs()
	if _stats_panel == null or _controller == null or _manager == null:
		_fail("Stats panel, controller, or manager missing")
		_finish()
		return

	await _capture_team_tabs()
	await _capture_planning_unit_clicks()
	_start_combat()
	await _settle(4.35)
	await _capture_combat_states()
	_finish()

func _resolve_refs() -> void:
	_stats_panel = _view.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ContentRow/StatsArea/StatsPanel") as Control
	_controller = _view.get("controller")
	if _view != null:
		_manager = _view.get("manager") as CombatManager

func _capture_team_tabs() -> void:
	_expect_team_mode("initial team mode")
	_expect_scoreboard_values_visible("team damage all")
	_save("01_team_damage_all")
	_press_window("Window3s")
	await _settle(0.16)
	_expect_pressed("Window3s", true, "3s window button")
	_expect_scoreboard_values_visible("team damage 3s")
	_save("02_team_damage_3s")
	_press_window("WindowAll")
	await _settle(0.16)
	_expect_pressed("WindowAll", true, "All window button")
	_press_metric_button("DPS")
	await _settle(0.16)
	_expect_metric("dps")
	_expect_scoreboard_values_visible("team dps all")
	_save("03_team_dps_all")
	_press_metric_button("Casts")
	await _settle(0.16)
	_expect_metric("casts")
	_expect_scoreboard_values_visible("team casts all")
	_save("04_team_casts_all")
	_press_expand()
	await _settle(0.18)
	_expect_scoreboard_expanded(true)
	_expect_scoreboard_values_visible("team expanded enemy overlay")
	_save("05_team_expand_enemy_overlay")
	_press_expand()
	await _settle(0.14)
	_expect_scoreboard_expanded(false)

func _capture_planning_unit_clicks() -> void:
	var player_tile_0: int = _click_grid_unit("player", 0)
	await _settle(0.20)
	_expect_unit_mode("player", player_tile_0, "player planning unit 0")
	_save("06_unit_player_0_planning")
	var player_tile_1: int = _click_grid_unit("player", 1)
	await _settle(0.20)
	_expect_unit_mode("player", player_tile_1, "player planning unit 1")
	_save("07_unit_player_1_planning")
	var enemy_tile_0: int = _click_grid_unit("enemy", 0)
	await _settle(0.20)
	_expect_unit_mode("enemy", enemy_tile_0, "enemy planning unit 0")
	_save("08_unit_enemy_0_planning")
	_click_clear_area()
	await _settle(0.20)
	_expect_team_mode("clear area returns team mode")
	_save("09_team_after_clear")

func _start_combat() -> void:
	if _view.has_method("_on_continue_pressed"):
		_view.call("_on_continue_pressed")

func _capture_combat_states() -> void:
	_expect_team_mode("combat team mode")
	_press_metric_button("Damage")
	await _settle(0.14)
	_expect_metric("damage")
	_expect_scoreboard_values_visible("combat damage")
	_expect_scoreboard_activity("combat damage", true)
	_save("10_combat_team_damage")
	_press_metric_button("DPS")
	await _settle(0.16)
	_expect_metric("dps")
	_expect_scoreboard_values_visible("combat dps")
	_expect_scoreboard_activity("combat dps", true)
	_save("11_combat_team_dps")
	_press_metric_button("Casts")
	await _settle(0.16)
	_expect_metric("casts")
	_expect_scoreboard_values_visible("combat casts")
	_save("12_combat_team_casts")
	_press_metric_button("Damage")
	await _settle(0.14)
	_expect_metric("damage")
	_click_actor_unit("player", 0)
	await _settle(0.20)
	_expect_unit_mode("player", 0, "combat player actor 0")
	_save("13_combat_unit_player_0")
	_click_actor_unit("player", 1)
	await _settle(0.20)
	_expect_unit_mode("player", 1, "combat player actor 1")
	_save("14_combat_unit_player_1")
	var enemy_actor_indices: Array[int] = _available_actor_indices("enemy", 6)
	if enemy_actor_indices.is_empty():
		_fail("No enemy combat actors available for unit selection")
	else:
		var first_enemy_index: int = enemy_actor_indices[0]
		_click_actor_unit("enemy", first_enemy_index)
		await _settle(0.20)
		_expect_unit_mode("enemy", first_enemy_index, "combat enemy actor %d" % first_enemy_index)
		_save("15_combat_unit_enemy_%d" % first_enemy_index)
		if enemy_actor_indices.size() > 1:
			var second_enemy_index: int = enemy_actor_indices[1]
			_click_actor_unit("enemy", second_enemy_index)
			await _settle(0.20)
			_expect_unit_mode("enemy", second_enemy_index, "combat enemy actor %d" % second_enemy_index)
			_save("16_combat_unit_enemy_%d" % second_enemy_index)
		else:
			print("StatsPanelDeepCapture: skipped second combat enemy actor selection because only one enemy actor is available")
	_press_window("Window3s")
	await _settle(0.16)
	_expect_pressed("Window3s", true, "combat 3s window")
	_click_clear_area()
	await _settle(0.20)
	_expect_team_mode("combat clear area returns team mode")
	_expect_scoreboard_values_visible("combat clear area 3s")
	_save("17_combat_team_3s_after_clear")

func _press_window(button_name: String) -> void:
	var button: Button = _stats_panel.find_child(button_name, true, false) as Button
	if button == null:
		_fail("Window button missing: %s" % button_name)
		return
	button.emit_signal("pressed")

func _press_metric_button(label: String) -> void:
	var tabs: Control = _stats_panel.find_child("MetricTabs", true, false) as Control
	if tabs == null:
		_fail("MetricTabs missing")
		return
	for child: Node in tabs.find_children("*", "Button", true, false):
		var button: Button = child as Button
		if button != null and button.text == label:
			button.emit_signal("pressed")
			return
	_fail("Metric button missing: %s" % label)

func _press_expand() -> void:
	var button: Button = _stats_panel.find_child("ExpandButton", true, false) as Button
	if button == null:
		_fail("ExpandButton missing")
		return
	button.emit_signal("pressed")

func _click_grid_unit(team: String, index: int) -> int:
	var slot_views: Array = _controller.get("player_views") if team == "player" else _controller.get("enemy_views")
	var seen: int = 0
	for slot_view: UnitSlotView in slot_views:
		if slot_view == null or slot_view.view == null:
			continue
		if seen == index:
			_emit_click(slot_view.view)
			return slot_view.tile_idx
		seen += 1
	_fail("Grid unit missing for %s index %d" % [team, index])
	return -999

func _click_actor_unit(team: String, index: int) -> void:
	var actor: Control = _get_actor_unit(team, index)
	if actor == null:
		_fail("Actor missing for %s index %d" % [team, index])
		return
	var hit: Control = actor.get_node_or_null("SelectHit") as Control
	if hit != null:
		_emit_click(hit)
	else:
		_emit_click(actor)

func _available_actor_indices(team: String, max_scan: int) -> Array[int]:
	var indices: Array[int] = []
	for index: int in range(max_scan):
		if _get_actor_unit(team, index) != null:
			indices.append(index)
	return indices

func _get_actor_unit(team: String, index: int) -> Control:
	var bridge: Variant = _controller.get("arena_bridge")
	if bridge == null:
		return null
	var actor: Control = null
	if team == "player" and bridge.has_method("get_player_actor"):
		actor = bridge.get_player_actor(index) as Control
	elif team == "enemy" and bridge.has_method("get_enemy_actor"):
		actor = bridge.get_enemy_actor(index) as Control
	return actor

func _click_clear_area() -> void:
	var clear_area: Control = _view.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ArenaContainer/ArenaBackground") as Control
	if clear_area == null:
		clear_area = _view.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ContentRow/BoardColumn/PlanningArea") as Control
	if clear_area == null:
		_fail("Clear area missing")
		return
	_emit_click(clear_area)

func _emit_click(target: Control) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = target.get_global_rect().size * 0.5
	event.global_position = target.get_global_rect().get_center()
	target.emit_signal("gui_input", event)

func _expect_team_mode(context: String) -> void:
	var title: Label = _stats_panel.find_child("Title", true, false) as Label
	var scoreboard: Control = _stats_panel.find_child("Scoreboard", true, false) as Control
	var unit_panel: Control = _stats_panel.find_child("UnitPanel", true, false) as Control
	if title == null or title.text != "Team Metrics":
		_fail("%s: title is not Team Metrics" % context)
	if scoreboard == null or not scoreboard.visible:
		_fail("%s: scoreboard not visible" % context)
	if unit_panel == null or unit_panel.visible:
		_fail("%s: unit panel unexpectedly visible" % context)

func _expect_unit_mode(team: String, index: int, context: String) -> void:
	var title: Label = _stats_panel.find_child("Title", true, false) as Label
	var scoreboard: Control = _stats_panel.find_child("Scoreboard", true, false) as Control
	var unit_panel: Control = _stats_panel.find_child("UnitPanel", true, false) as Control
	var expected_title: String = "Enemy Unit" if team == "enemy" else "Player Unit"
	if title == null or title.text != expected_title:
		_fail("%s: title is not %s" % [context, expected_title])
	if scoreboard == null or scoreboard.visible:
		_fail("%s: scoreboard unexpectedly visible" % context)
	if unit_panel == null or not unit_panel.visible:
		_fail("%s: unit panel not visible" % context)
	if String(_stats_panel.get("_unit_team")) != team:
		_fail("%s: expected team %s got %s" % [context, team, String(_stats_panel.get("_unit_team"))])
	if int(_stats_panel.get("_unit_index")) != index:
		_fail("%s: expected index %d got %d" % [context, index, int(_stats_panel.get("_unit_index"))])

func _expect_metric(metric: String) -> void:
	var scoreboard: Node = _stats_panel.find_child("Scoreboard", true, false)
	if scoreboard == null:
		_fail("Scoreboard missing for metric check")
		return
	if String(scoreboard.get("metric")) != metric:
		_fail("Expected metric %s got %s" % [metric, String(scoreboard.get("metric"))])

func _expect_pressed(button_name: String, expected: bool, context: String) -> void:
	var button: Button = _stats_panel.find_child(button_name, true, false) as Button
	if button == null:
		_fail("%s missing" % context)
		return
	if bool(button.button_pressed) != expected:
		_fail("%s pressed expected %s got %s" % [context, str(expected), str(button.button_pressed)])

func _expect_scoreboard_expanded(expected: bool) -> void:
	var scoreboard: Node = _stats_panel.find_child("Scoreboard", true, false)
	if scoreboard == null:
		_fail("Scoreboard missing for expanded check")
		return
	if bool(scoreboard.get("expanded")) != expected:
		_fail("Scoreboard expanded expected %s got %s" % [str(expected), str(scoreboard.get("expanded"))])

func _expect_scoreboard_values_visible(context: String) -> void:
	_force_scoreboard_refresh()
	var scoreboard: Node = _stats_panel.find_child("Scoreboard", true, false)
	if scoreboard == null:
		_fail("%s: scoreboard missing for row visibility check" % context)
		return
	var visible_rows: int = 0
	for child: Node in scoreboard.find_children("*", "", true, false):
		var row: ScoreboardRow = child as ScoreboardRow
		if row == null or not row.is_visible_in_tree():
			continue
		visible_rows += 1
		var name_label: Label = row.get_node_or_null("HBox/Content/Name") as Label
		var value_label: Label = row.get_node_or_null("HBox/Content/Value") as Label
		if name_label == null or value_label == null:
			_fail("%s: scoreboard row labels missing" % context)
			continue
		if value_label.text.strip_edges() == "":
			_fail("%s: scoreboard value empty for %s" % [context, name_label.text])
		var name_rect: Rect2 = name_label.get_global_rect()
		var value_rect: Rect2 = value_label.get_global_rect()
		if name_rect.end.x > value_rect.position.x - 4.0:
			_fail("%s: scoreboard value overlaps name for %s" % [context, name_label.text])
	if visible_rows <= 0:
		_fail("%s: no visible scoreboard rows" % context)

func _expect_scoreboard_activity(context: String, require_positive_total: bool) -> void:
	if not require_positive_total:
		return
	if _is_framebuffer_unavailable():
		return
	_force_scoreboard_refresh()
	var scoreboard: Node = _stats_panel.find_child("Scoreboard", true, false)
	if scoreboard == null:
		_fail("%s: scoreboard missing for activity check" % context)
		return
	var total: float = 0.0
	for child: Node in scoreboard.find_children("*", "", true, false):
		var row: ScoreboardRow = child as ScoreboardRow
		if row == null or row.team == "enemy":
			continue
		total += max(0.0, float(row.value))
	if total <= 0.0:
		_fail("%s: expected positive player scoreboard total" % context)

func _force_scoreboard_refresh() -> void:
	var scoreboard: Node = _stats_panel.find_child("Scoreboard", true, false)
	if scoreboard != null and scoreboard.has_method("_rebuild_now"):
		scoreboard.call("_rebuild_now")

func _save(stem: String) -> void:
	var full_name: String = "%s_full.png" % stem
	var panel_name: String = "%s_panel.png" % stem
	if _is_framebuffer_unavailable():
		print("StatsPanelDeepCapture: skipped %s screenshots because framebuffer capture is unavailable" % stem)
		return
	var image: Image = _viewport_image()
	if image == null:
		_fail("Viewport image unavailable for %s" % stem)
		return
	_save_image(image, full_name)
	var stats_area: Control = _view.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ContentRow/StatsArea") as Control
	if stats_area == null:
		_fail("StatsArea missing for crop %s" % stem)
		return
	var rect: Rect2 = stats_area.get_global_rect()
	var viewport_size: Vector2i = image.get_size()
	var crop: Rect2i = Rect2i(
		Vector2i(maxi(0, int(floor(rect.position.x))), maxi(0, int(floor(rect.position.y)))),
		Vector2i(mini(viewport_size.x, int(ceil(rect.size.x))), mini(viewport_size.y, int(ceil(rect.size.y))))
	)
	if crop.position.x + crop.size.x > viewport_size.x:
		crop.size.x = viewport_size.x - crop.position.x
	if crop.position.y + crop.size.y > viewport_size.y:
		crop.size.y = viewport_size.y - crop.position.y
	if crop.size.x <= 0 or crop.size.y <= 0:
		_fail("Invalid stats crop for %s" % stem)
		return
	_save_image(image.get_region(crop), panel_name)

func _viewport_image() -> Image:
	var texture: ViewportTexture = get_viewport().get_texture()
	if texture == null or not texture.get_rid().is_valid():
		return null
	var image: Image = texture.get_image()
	if image == null or image.is_empty():
		return null
	return image

func _is_framebuffer_unavailable() -> bool:
	var display_name: String = DisplayServer.get_name().to_lower()
	return display_name == "headless" or display_name == "server" or display_name == "dummy"

func _save_image(image: Image, filename: String) -> void:
	var path: String = "%s/%s" % [OUTPUT_DIR, filename]
	var err: Error = image.save_png(path)
	if err != OK:
		_fail("Failed to save %s error=%d" % [ProjectSettings.globalize_path(path), int(err)])
		return
	print("StatsPanelDeepCapture: saved %s" % ProjectSettings.globalize_path(path))

func _settle(seconds: float) -> void:
	for _frame_index: int in range(3):
		await get_tree().process_frame
	await get_tree().create_timer(seconds).timeout
	for _frame_index: int in range(2):
		await get_tree().process_frame

func _fail(message: String) -> void:
	if not _failures.has(message):
		_failures.append(message)

func _finish() -> void:
	if _failures.is_empty():
		print("StatsPanelDeepCapture: OK output=%s" % ProjectSettings.globalize_path(OUTPUT_DIR))
		get_tree().quit(0)
		return
	for failure: String in _failures:
		push_error("StatsPanelDeepCapture: " + failure)
	get_tree().quit(1)
