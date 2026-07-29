extends Node

const SMOKE_NAME: String = "CombatArenaBoundsSmoke"
const MainTransitionWait: GDScript = preload("res://tests/visual/main_transition_wait.gd")
const MAIN_SCENE: PackedScene = preload("res://scenes/Main.tscn")
const PLAYER_TEAM: Array[String] = ["mortem", "berebell", "bonko"]
const VIEWPORT_SIZE: Vector2i = Vector2i(1920, 1080)
const COMPACT_VIEWPORT_SIZE: Vector2i = Vector2i(1280, 720)

var _main: Control = null
var _view: Control = null
var _manager: CombatManager = null
var _viewport: SubViewport = null
var _failures: Array[String] = []

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
	var stats_area: Control = _view.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ContentRow/StatsArea") as Control
	if planning_area == null or stats_area == null:
		_fail("planning layout refs missing")
		await _finish()
		return
	var planning_rect_before: Rect2 = planning_area.get_global_rect()
	var stats_rect_before: Rect2 = stats_area.get_global_rect()
	_expect(planning_rect_before.size.x > 0.0 and planning_rect_before.size.y > 0.0, "planning board rect should be measurable before combat")
	_expect(stats_rect_before.size.x > 0.0 and stats_rect_before.size.y > 0.0, "team metrics rect should be measurable before combat")

	if _view.has_method("_on_continue_pressed"):
		_view.call("_on_continue_pressed")
	await _settle_frames(40)

	var arena_container: Control = _view.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ArenaContainer") as Control
	var arena_units: Control = _view.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ArenaContainer/ArenaUnits") as Control
	if arena_container == null or arena_units == null:
		_fail("arena layout refs missing")
		await _finish()
		return
	var arena_rect: Rect2 = arena_container.get_global_rect()
	var combat_board_rect: Rect2 = planning_area.get_global_rect()
	var combat_stats_rect: Rect2 = stats_area.get_global_rect()
	var engine_bounds: Rect2 = _manager.get_arena_bounds()
	var viewport_rect: Rect2 = _view.get_viewport().get_visible_rect()
	_expect(_rect_close(arena_rect, combat_board_rect, 3.0), "arena container should match the live combat board rect arena=%s board=%s" % [str(arena_rect), str(combat_board_rect)])
	_expect(absf(arena_rect.position.x - planning_rect_before.position.x) <= 3.0, "combat reflow should preserve board x alignment")
	_expect(arena_rect.size.distance_to(planning_rect_before.size) <= 3.0, "combat reflow should preserve board size")
	_expect(absf(combat_stats_rect.position.x - stats_rect_before.position.x) <= 3.0, "combat reflow should preserve metrics x alignment before=%s combat=%s" % [str(stats_rect_before), str(combat_stats_rect)])
	_expect(combat_stats_rect.size.distance_to(stats_rect_before.size) <= 3.0, "combat reflow should preserve metrics size")
	_expect(_rect_inside(arena_rect, viewport_rect.grow(3.0)), "combat arena should remain inside the viewport arena=%s viewport=%s" % [str(arena_rect), str(viewport_rect)])
	_expect(_rect_inside(engine_bounds, arena_rect.grow(3.0)), "engine arena bounds should stay inside the live arena rect engine=%s board=%s arena=%s" % [str(engine_bounds), str(combat_board_rect), str(arena_rect)])
	_expect(engine_bounds.position.x >= arena_rect.position.x + 51.0, "engine bounds should reserve the actor footprint on the left")
	_expect(engine_bounds.position.y >= arena_rect.position.y + 65.0, "engine bounds should reserve health-bar space above actors")
	_expect(engine_bounds.end.x <= arena_rect.end.x - 51.0, "engine bounds should reserve the actor footprint on the right")
	_expect(engine_bounds.end.y <= arena_rect.end.y - 51.0, "engine bounds should reserve the actor footprint below")
	_expect(not arena_rect.intersects(combat_stats_rect), "arena container should not overlap live team metrics area arena=%s stats=%s" % [str(arena_rect), str(combat_stats_rect)])
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
	await _finish()

func _rect_close(a: Rect2, b: Rect2, tolerance: float) -> bool:
	return a.position.distance_to(b.position) <= tolerance and a.size.distance_to(b.size) <= tolerance

func _rect_inside(inner: Rect2, outer: Rect2) -> bool:
	return outer.has_point(inner.position) and outer.has_point(inner.end)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)

func _fail(message: String) -> void:
	if not _failures.has(message):
		_failures.append(message)

func _settle_frames(count: int) -> void:
	for _index: int in range(count):
		await get_tree().process_frame

func _finish() -> void:
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
