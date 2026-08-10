extends Node

const SMOKE_NAME: String = "CombatArenaBoundsSmoke"
const MainTransitionWait: GDScript = preload("res://tests/visual/main_transition_wait.gd")
const PhaseTransitionControllerScript: GDScript = preload("res://scripts/ui/combat/phase_transition_controller.gd")
const MAIN_SCENE: PackedScene = preload("res://scenes/Main.tscn")
const PLAYER_TEAM: Array[String] = ["mortem", "berebell", "bonko"]
const VIEWPORT_SIZE: Vector2i = Vector2i(1920, 1080)
const COMPACT_VIEWPORT_SIZE: Vector2i = Vector2i(1280, 720)

var _main: Control = null
var _view: Control = null
var _manager: CombatManager = null
var _viewport: SubViewport = null
var _failures: Array[String] = []
var _diagnostics: Dictionary[String, Variant] = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_run")

func _run() -> void:
	DisplayServer.window_set_size(VIEWPORT_SIZE)
	var window: Window = get_window()
	if window != null:
		window.size = VIEWPORT_SIZE
		window.content_scale_size = VIEWPORT_SIZE
	_viewport = SubViewport.new()
	_viewport.size = VIEWPORT_SIZE
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)
	_main = MAIN_SCENE.instantiate() as Control
	_main.set_anchors_preset(Control.PRESET_FULL_RECT)
	_viewport.add_child(_main)
	await _settle_frames(8)
	var authoritative_viewport_rect: Rect2 = _main.get_viewport().get_visible_rect()
	_expect(Vector2i(authoritative_viewport_rect.size) == VIEWPORT_SIZE, "authoritative combat viewport must be 1920x1080, got=%s" % str(authoritative_viewport_rect.size))
	if Vector2i(authoritative_viewport_rect.size) != VIEWPORT_SIZE:
		await _finish()
		return
	if _main.has_method("_on_start"):
		_main.call("_on_start")
	await _settle_frames(8)
	if _main.has_method("_on_unit_selected"):
		_main.call("_on_unit_selected", "mortem")
	_view = await MainTransitionWait.for_combat_view(self, _main)
	if _view == null:
		_fail("CombatView missing")
		await _finish()
		return
	if _view.has_method("set_player_team_ids"):
		_view.call("set_player_team_ids", PLAYER_TEAM)
	if _view.has_method("_init_game"):
		_view.call("_init_game")
	await _settle_frames(18)
	_manager = _view.get("manager") as CombatManager
	if _manager == null:
		_fail("manager missing")
		await _finish()
		return

	var planning_area: Control = _view.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ContentRow/BoardColumn/PlanningArea") as Control
	var battle_area: Control = _view.get_node_or_null("MarginContainer/VBoxContainer/BattleArea") as Control
	var stats_area: Control = _view.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ContentRow/StatsArea") as Control
	if planning_area == null or battle_area == null or stats_area == null:
		_fail("planning layout refs missing")
		await _finish()
		return
	var planning_rect_before: Rect2 = planning_area.get_global_rect()
	var battle_rect_before: Rect2 = battle_area.get_global_rect()
	var stats_rect_before: Rect2 = stats_area.get_global_rect()
	_expect(planning_rect_before.size.x > 0.0 and planning_rect_before.size.y > 0.0, "planning board rect should be measurable before combat")
	_expect(stats_rect_before.size.x > 0.0 and stats_rect_before.size.y > 0.0, "team metrics rect should be measurable before combat")

	if _view.has_method("_on_continue_pressed"):
		_view.call("_on_continue_pressed")
	var combat_started: bool = await _wait_for_combat_active(5.0)
	_expect(combat_started, "combat did not start after the authored countdown and grid crossfade")
	if not combat_started:
		await _finish()
		return
	await _settle_frames(4)

	var arena_container: Control = _view.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ArenaContainer") as Control
	var arena_units: Control = _view.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ArenaContainer/ArenaUnits") as Control
	if arena_container == null or arena_units == null:
		_fail("arena layout refs missing")
		await _finish()
		return
	var arena_rect: Rect2 = arena_container.get_global_rect()
	var combat_board_rect: Rect2 = planning_area.get_global_rect()
	var engine_bounds: Rect2 = _manager.get_arena_bounds()
	var viewport_rect: Rect2 = _view.get_viewport().get_visible_rect()
	_diagnostics = {
		"arena_rect": arena_rect,
		"battle_rect": battle_area.get_global_rect(),
		"planning_rect": combat_board_rect,
		"engine_bounds": engine_bounds,
	}
	_expect(_rect_close(arena_rect, battle_area.get_global_rect(), 3.0), "arena container should expand to the live full battle field arena=%s field=%s" % [str(arena_rect), str(battle_area.get_global_rect())])
	_expect(arena_rect.size.y >= battle_rect_before.size.y, "combat field should not shrink below the planning shell's battle-area height")
	_expect(not stats_area.visible or stats_area.modulate.a <= 0.20, "team metrics should recede while the full combat field is active")
	_expect(_rect_inside(arena_rect, viewport_rect.grow(3.0)), "combat arena should remain inside the viewport arena=%s viewport=%s" % [str(arena_rect), str(viewport_rect)])
	_expect(_rect_inside(engine_bounds, arena_rect.grow(3.0)), "engine arena bounds should stay inside the live arena rect engine=%s board=%s arena=%s" % [str(engine_bounds), str(combat_board_rect), str(arena_rect)])
	_expect(engine_bounds.position.x >= arena_rect.position.x + 51.0, "engine bounds should reserve the actor footprint on the left")
	_expect(engine_bounds.position.y >= arena_rect.position.y + 65.0, "engine bounds should reserve health-bar space above actors")
	_expect(engine_bounds.end.x <= arena_rect.end.x - 51.0, "engine bounds should reserve the actor footprint on the right")
	_expect(engine_bounds.end.y <= arena_rect.end.y - 51.0, "engine bounds should reserve the actor footprint below")
	_assert_exchange_receipt_survives_layout(arena_container)
	for child: Node in arena_units.get_children():
		var control: Control = child as Control
		if control == null or not control.visible:
			continue
		_expect(_rect_inside(control.get_global_rect(), arena_rect.grow(1.0)), "arena actor body should stay inside the live arena rect: %s" % str(control.get_global_rect()))
		for plate_name: String in ["BarPlate", "FocusPlate"]:
			var plate: Control = control.find_child(plate_name, true, false) as Control
			if plate != null and plate.visible:
				_expect(_rect_inside(plate.get_global_rect(), arena_rect.grow(1.0)), "%s should stay inside the live arena rect: %s" % [plate_name, str(plate.get_global_rect())])

	_viewport.size = COMPACT_VIEWPORT_SIZE
	await _settle_frames(30)
	var compact_arena_rect: Rect2 = arena_container.get_global_rect()
	var compact_engine_bounds: Rect2 = _manager.get_arena_bounds()
	var compact_viewport_rect: Rect2 = _view.get_viewport().get_visible_rect()
	_expect(Vector2i(compact_viewport_rect.size) == COMPACT_VIEWPORT_SIZE, "combat viewport should resize to 1280x720, got=%s" % str(compact_viewport_rect.size))
	_expect(_rect_inside(compact_arena_rect, compact_viewport_rect.grow(3.0)), "compact combat arena should remain inside the viewport")
	_expect(_rect_inside(compact_engine_bounds, compact_arena_rect.grow(3.0)), "compact engine bounds should stay inside the live arena")
	_expect(compact_engine_bounds.position.x >= compact_arena_rect.position.x + 51.0, "compact engine bounds should reserve the actor footprint on the left")
	_expect(compact_engine_bounds.position.y >= compact_arena_rect.position.y + 65.0, "compact engine bounds should reserve health-bar space above actors")
	_expect(compact_engine_bounds.end.x <= compact_arena_rect.end.x - 51.0, "compact engine bounds should reserve the actor footprint on the right")
	_expect(compact_engine_bounds.end.y <= compact_arena_rect.end.y - 51.0, "compact engine bounds should reserve the actor footprint below")
	await _assert_direct_battle_return_geometry()
	await _finish()

func _rect_close(a: Rect2, b: Rect2, tolerance: float) -> bool:
	return a.position.distance_to(b.position) <= tolerance and a.size.distance_to(b.size) <= tolerance

func _rect_inside(inner: Rect2, outer: Rect2) -> bool:
	return outer.has_point(inner.position) and outer.has_point(inner.end)


func _assert_exchange_receipt_survives_layout(arena_container: Control) -> void:
	var controller: Variant = _view.get("controller") if _view != null else null
	var arena_bridge: Variant = controller.get("arena_bridge") if controller != null else null
	var arena_controller: Variant = arena_bridge.get("arena") if arena_bridge != null else null
	_expect(arena_controller != null and arena_controller.has_method("present_combat_exchange_focus"), "combat exchange presenter is missing")
	if arena_controller == null or not arena_controller.has_method("present_combat_exchange_focus"):
		return
	arena_controller.call("present_combat_exchange_focus", "player", 0, "enemy", 0, 37, true)
	_expect(int(arena_container.get_meta("combat_exchange_damage", 0)) == 37, "resolved exchange receipt did not record its damage")
	if arena_controller.has_method("reflow_combat_readouts"):
		arena_controller.call("reflow_combat_readouts")
	var exchange_focus: Control = arena_container.get_node_or_null("CombatExchangeFocus") as Control
	_expect(int(arena_container.get_meta("combat_exchange_damage", 0)) == 37, "readout layout erased the resolved exchange damage")
	_expect(bool(arena_container.get_meta("combat_exchange_critical", false)), "readout layout erased the resolved critical flag")
	_expect(exchange_focus != null and String(exchange_focus.get_meta("exchange_receipt", "")) == "engine_resolved_damage", "readout layout replaced the resolved exchange focus receipt")
	var target_actor: UnitActor = arena_controller.call("get_actor", "enemy", 0) as UnitActor
	_expect(target_actor != null, "exchange receipt target actor is missing")
	if target_actor != null:
		target_actor.visible = false
		arena_controller.call("reflow_combat_readouts")
		_expect(int(arena_container.get_meta("combat_exchange_damage", 0)) == 37, "target removal erased the last resolved exchange damage")
		_expect(exchange_focus != null and String(exchange_focus.get_meta("exchange_receipt", "")) == "engine_resolved_damage", "target removal replaced the last resolved hit with a default anchor")
		target_actor.visible = true


func _assert_direct_battle_return_geometry() -> void:
	var fixture_host: Control = Control.new()
	fixture_host.name = "DirectBattleTransitionFixture"
	fixture_host.position = Vector2.ZERO
	fixture_host.size = Vector2(800.0, 600.0)
	_viewport.add_child(fixture_host)
	var planning_area: Control = Control.new()
	planning_area.name = "PlanningArea"
	planning_area.position = Vector2(100.0, 100.0)
	planning_area.size = Vector2(400.0, 300.0)
	fixture_host.add_child(planning_area)
	var planning_top: Control = Control.new()
	planning_top.name = "TopArea"
	planning_top.position = Vector2.ZERO
	planning_top.size = Vector2(400.0, 140.0)
	planning_area.add_child(planning_top)
	var planning_bottom: Control = Control.new()
	planning_bottom.name = "BottomArea"
	planning_bottom.position = Vector2(0.0, 160.0)
	planning_bottom.size = Vector2(400.0, 140.0)
	planning_area.add_child(planning_bottom)
	var arena: Control = Control.new()
	arena.name = "ArenaContainer"
	arena.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fixture_host.add_child(arena)
	await _settle_frames(2)
	var transition: PhaseTransitionController = PhaseTransitionControllerScript.new() as PhaseTransitionController
	transition.configure(fixture_host, planning_area, arena)
	var combat_rect: Rect2 = arena.get_global_rect()
	transition.mark_combat()
	var planning_rect: Rect2 = transition.get_planning_commit_rect()
	_expect(planning_rect.size.x > 1.0 and planning_rect.size.y > 1.0, "direct battle did not capture its planning return target")
	_expect(_rect_close(arena.get_global_rect(), combat_rect, 1.0), "direct battle geometry normalization moved the live arena")
	_expect(is_zero_approx(arena.anchor_left) and is_zero_approx(arena.anchor_right) and is_zero_approx(arena.anchor_top) and is_zero_approx(arena.anchor_bottom), "direct battle did not normalize arena anchors")
	transition.capture_combat_rect()
	transition.start_return(false)
	await _settle_frames(2)
	var return_start_rect: Rect2 = arena.get_global_rect()
	await get_tree().create_timer(0.40).timeout
	var return_mid_rect: Rect2 = arena.get_global_rect()
	_expect(return_mid_rect.size.x < return_start_rect.size.x and return_mid_rect.size.y < return_start_rect.size.y, "direct battle return did not reverse the arena geometry")
	await get_tree().create_timer(0.50).timeout
	await _settle_frames(2)
	_expect(transition.get_state_name() == "idle", "direct battle return did not finish")
	_expect(_rect_close(arena.get_global_rect(), planning_rect, 2.0), "direct battle return missed its committed planning geometry")
	transition.teardown()
	_viewport.remove_child(fixture_host)
	fixture_host.free()

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)

func _fail(message: String) -> void:
	if not _failures.has(message):
		_failures.append(message)

func _settle_frames(count: int) -> void:
	for _index: int in range(count):
		await get_tree().process_frame

func _wait_for_combat_active(timeout_seconds: float) -> bool:
	var deadline: int = Time.get_ticks_msec() + int(timeout_seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if int(GameState.phase) == int(GameState.GamePhase.COMBAT) and Economy.combat_active:
			return true
		await get_tree().process_frame
	return false

func _finish() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://outputs/visual_debug"))
	var result_file: FileAccess = FileAccess.open("res://outputs/visual_debug/combat_arena_bounds_smoke_result.json", FileAccess.WRITE)
	if result_file != null:
		result_file.store_string(JSON.stringify({"ok": _failures.is_empty(), "failures": _failures, "diagnostics": _diagnostics}, "\t"))
		result_file.close()
	if _view != null and is_instance_valid(_view) and _view.has_method("_teardown"):
		_view.call("_teardown")
	if _main != null and is_instance_valid(_main):
		var main_parent: Node = _main.get_parent()
		if main_parent != null:
			main_parent.remove_child(_main)
		_main.free()
		_main = null
	if _viewport != null and is_instance_valid(_viewport):
		remove_child(_viewport)
		_viewport.free()
		_viewport = null
	_view = null
	_manager = null
	await _settle_frames(2)
	if _failures.is_empty():
		print(SMOKE_NAME + ": OK")
		get_tree().quit(0)
		return
	for failure: String in _failures:
		push_error(SMOKE_NAME + ": " + failure)
	get_tree().quit(1)
