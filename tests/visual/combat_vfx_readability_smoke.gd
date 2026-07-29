extends Node

const SMOKE_NAME: String = "CombatVfxReadabilitySmoke"
const COMBAT_VIEW_SCENE: PackedScene = preload("res://scenes/CombatView.tscn")
const ARENA_PATH: String = "MarginContainer/VBoxContainer/BattleArea/ArenaContainer"
const INSTALLER_NAME: String = "CombatVfxInstaller"
const BRIDGE_NAME: String = "CombatVfxBridge"
const PLAYER_IDS: Array[String] = ["saffron"]
const ENEMY_IDS: Array[String] = ["brute"]
const EXPECTED_READABILITY_MODULATE: Color = Color(0.74, 0.62, 0.54, 0.42)
const MAX_EXPECTED_ACTIVE_LINES: int = 10
const MAX_EXPECTED_ACTIVE_BURSTS: int = 16

var _view: Control = null
var _manager: CombatManager = null
var _failures: Array[String] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_run")

func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1600, 900))
	_view = COMBAT_VIEW_SCENE.instantiate() as Control
	if _view == null:
		_fail("CombatView instantiate failed")
		await _finish()
		return
	add_child(_view)
	await _settle_frames(8)

	_manager = _view.get("manager") as CombatManager
	if _manager == null:
		_fail("CombatView manager missing")
		await _finish()
		return

	var options: Dictionary[String, Variant] = {
		"label": SMOKE_NAME,
		"stage": 1,
		"seed": 73,
		"deterministic_rolls": true,
		"abilities_enabled": true,
	}
	var result: Dictionary[String, Variant] = _manager.start_custom_battle(PLAYER_IDS, ENEMY_IDS, options)
	if not bool(result.get("ok", false)):
		_fail("custom battle failed reason=%s" % String(result.get("reason", "unknown")))
		await _finish()
		return
	await _settle_frames(8)

	var installers: Array[Node] = _view.find_children(INSTALLER_NAME, "Node", true, false)
	_expect(installers.size() == 1, "expected exactly one %s, found %d" % [INSTALLER_NAME, installers.size()])
	if installers.size() != 1:
		await _finish()
		return
	var installer: Node = installers[0]
	_expect(installer.get_parent() == _view, "%s should be a direct CombatView child" % INSTALLER_NAME)

	var arena_container: Control = _view.get_node_or_null(ARENA_PATH) as Control
	if arena_container == null:
		_fail("ArenaContainer missing")
		await _finish()
		return
	_expect(arena_container.visible, "ArenaContainer should be visible while combat is active")
	_expect(arena_container.clip_contents, "ArenaContainer should clip combat VFX")

	var bridges: Array[Node] = _view.find_children(BRIDGE_NAME, "Control", true, false)
	_expect(bridges.size() == 1, "expected exactly one %s, found %d" % [BRIDGE_NAME, bridges.size()])
	if bridges.size() != 1:
		await _finish()
		return
	var bridge: CombatVfxBridge = bridges[0] as CombatVfxBridge
	if bridge == null:
		_fail("CombatVfxBridge has the wrong runtime type")
		await _finish()
		return

	_expect(bridge.get_parent() == arena_container, "CombatVfxBridge should be parented to ArenaContainer")
	_expect(bridge.z_as_relative, "CombatVfxBridge should use relative z ordering")
	_expect(bridge.z_index == 5, "CombatVfxBridge relative z_index should be 5, got %d" % bridge.z_index)
	_expect(bridge.self_modulate.is_equal_approx(EXPECTED_READABILITY_MODULATE), "CombatVfxBridge readability modulate mismatch expected=%s actual=%s" % [str(EXPECTED_READABILITY_MODULATE), str(bridge.self_modulate)])
	_expect(String(bridge.get_meta("gothic_readability_profile", "")) == "v2", "CombatVfxBridge readability metadata should be v2")

	var engine: Object = _manager.get_engine() as Object
	_expect(engine != null, "Combat engine should exist while combat is active")
	_expect(installer.get("_bridge") == bridge, "CombatVfxInstaller should own the live bridge")
	_expect(installer.get("_manager") == _manager, "CombatVfxInstaller should resolve the live manager")
	_expect(installer.get("_bound_engine") == engine, "CombatVfxInstaller should bind the live engine")
	_expect(bool(installer.get("_was_active")), "CombatVfxInstaller should report an active arena")
	_expect(bridge.manager == _manager, "CombatVfxBridge manager reference mismatch")
	_expect(bridge.get("_bound_manager") == _manager, "CombatVfxBridge signal manager should be bound")
	_expect(bridge.get("_bound_engine") == engine, "CombatVfxBridge signal engine should be bound")

	_exercise_line_cap(bridge, arena_container)
	_exercise_burst_cap(bridge)
	arena_container.visible = false
	await _settle_frames(3)
	_expect(not bool(installer.get("_was_active")), "CombatVfxInstaller should leave active state when the arena hides")
	_expect(bridge.get("_bound_manager") == null, "CombatVfxBridge should unbind manager signals while the arena is hidden")
	_expect(bridge.get("_bound_engine") == null, "CombatVfxBridge should unbind engine signals while the arena is hidden")
	var cleared_lines: Array[Dictionary] = bridge.get("_lines") as Array[Dictionary]
	var cleared_bursts: Array[Dictionary] = bridge.get("_bursts") as Array[Dictionary]
	_expect(cleared_lines.is_empty() and cleared_bursts.is_empty(), "CombatVfxBridge should clear queued effects when the arena hides")
	await _finish()

func _exercise_line_cap(bridge: CombatVfxBridge, arena_container: Control) -> void:
	var arena_rect: Rect2 = arena_container.get_global_rect()
	var start_base: Vector2 = arena_rect.position + Vector2(24.0, 32.0)
	var end_base: Vector2 = arena_rect.end - Vector2(24.0, 32.0)
	for index: int in range(MAX_EXPECTED_ACTIVE_LINES + 4):
		var offset: Vector2 = Vector2(0.0, float(index) * 2.0)
		bridge.call("_add_line", start_base + offset, end_base - offset, Color.WHITE, 2.0, 10.0, "smoke")
	var active_lines: Array[Dictionary] = bridge.get("_lines") as Array[Dictionary]
	_expect(not active_lines.is_empty(), "CombatVfxBridge line-cap exercise should create lines")
	_expect(active_lines.size() <= MAX_EXPECTED_ACTIVE_LINES, "CombatVfxBridge active line count should stay <= %d, got %d" % [MAX_EXPECTED_ACTIVE_LINES, active_lines.size()])
	_expect(active_lines.size() == MAX_EXPECTED_ACTIVE_LINES, "CombatVfxBridge should retain exactly the capped %d newest lines after overflow, got %d" % [MAX_EXPECTED_ACTIVE_LINES, active_lines.size()])

func _exercise_burst_cap(bridge: CombatVfxBridge) -> void:
	for index: int in range(MAX_EXPECTED_ACTIVE_BURSTS + 4):
		bridge.call("_add_burst", "heal", "player", 0, {
			"duration": 10.0,
			"magnitude": float(index + 1),
		})
	var active_bursts: Array[Dictionary] = bridge.get("_bursts") as Array[Dictionary]
	_expect(active_bursts.size() <= MAX_EXPECTED_ACTIVE_BURSTS, "CombatVfxBridge active burst count should stay <= %d, got %d" % [MAX_EXPECTED_ACTIVE_BURSTS, active_bursts.size()])
	_expect(active_bursts.size() == MAX_EXPECTED_ACTIVE_BURSTS, "CombatVfxBridge should retain exactly the capped %d newest bursts after overflow, got %d" % [MAX_EXPECTED_ACTIVE_BURSTS, active_bursts.size()])

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
	if _view != null and is_instance_valid(_view):
		remove_child(_view)
		_view.free()
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
