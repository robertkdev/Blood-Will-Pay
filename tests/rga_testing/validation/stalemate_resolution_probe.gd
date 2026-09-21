extends Node

## Forced-result contract for the combat engine.
##
## A fight that runs out of time while both boards are still standing must not
## resolve into a draw: a draw refunds the whole wager, so the player can replay
## the same stage forever without paying for it. This probe drives durable boards
## into the timeout path and requires a decisive verdict every time.

const CombatManagerLib: Script = preload("res://scripts/combat_manager.gd")

const ARENA_SIZE: Vector2 = Vector2(640.0, 360.0)
const TILE_SIZE: float = 64.0
const COMBAT_TIMEOUT_S: float = 4.0
const NO_PROGRESS_TIMEOUT_S: float = 1.5
const CASE_TIMEOUT_S: float = 45.0

var _outcome: String = ""
var _resolution_log: Array[String] = []
var _forced_cases: int = 0

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	var cases: Array[Dictionary] = [
		{
			"label": "durable mirror",
			"player": ["brute", "repo", "bonko", "grint"],
			"enemy": ["brute", "repo", "bonko", "grint"],
		},
		{
			"label": "sustain versus sustain",
			"player": ["korath", "grint", "sari", "bonko"],
			"enemy": ["korath", "repo", "mara", "bonko"],
		},
	]
	for case: Dictionary in cases:
		await _run_case(case, failures)
	if failures.is_empty():
		print("StalemateResolutionProbe: PASS cases=%d forced=%d" % [cases.size(), _forced_cases])
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("StalemateResolutionProbe: %s" % failure)
	print("StalemateResolutionProbe: FAIL cases=%d failures=%d" % [cases.size(), failures.size()])
	get_tree().quit(1)

func _run_case(case: Dictionary, failures: Array[String]) -> void:
	# A fresh manager per case: a manager that has already resolved one battle does
	# not reliably drive a second one inside the same probe run.
	var manager: CombatManager = CombatManagerLib.new()
	manager.name = "CombatManager"
	add_child(manager)
	manager.victory.connect(func(_stage: int) -> void: _outcome = "victory")
	manager.defeat.connect(func(_stage: int) -> void: _outcome = "defeat")
	manager.tie.connect(func(_stage: int) -> void: _outcome = "tie")
	manager.log_line.connect(func(text: String) -> void: _resolution_log.append(text))

	var label: String = String(case.get("label", "?"))
	var player_ids: Array[String] = _to_ids(case.get("player", []))
	var enemy_ids: Array[String] = _to_ids(case.get("enemy", []))
	_outcome = ""
	_resolution_log.clear()
	manager.cache_arena_config(
		TILE_SIZE,
		_positions_for(player_ids.size(), true),
		_positions_for(enemy_ids.size(), false),
		Rect2(Vector2.ZERO, ARENA_SIZE)
	)
	var started: Dictionary = manager.start_custom_battle(player_ids, enemy_ids, {
		"label": "StalemateResolutionProbe",
		"stage": 1,
		"deterministic_rolls": true,
		"abilities_enabled": true,
		"seed": 90210,
	})
	if not bool(started.get("ok", false)):
		failures.append("%s: battle did not start (%s)" % [label, str(started.get("reason", "unknown"))])
		await _retire_manager(manager)
		return
	var engine: Variant = manager.get_engine()
	if engine == null:
		failures.append("%s: engine missing after start" % label)
		await _retire_manager(manager)
		return
	engine.set("combat_timeout_s", COMBAT_TIMEOUT_S)
	engine.set("no_progress_timeout_s", NO_PROGRESS_TIMEOUT_S)

	var deadline: int = Time.get_ticks_msec() + int(CASE_TIMEOUT_S * 1000.0)
	while _outcome == "" and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	if _outcome == "":
		failures.append("%s: no outcome after %.0fs" % [label, CASE_TIMEOUT_S])
		await _retire_manager(manager)
		return
	if _outcome == "tie":
		var player_alive: int = _alive_count(manager.get("player_team"))
		var enemy_alive: int = _alive_count(manager.get("enemy_team"))
		if player_alive > 0 and enemy_alive > 0:
			failures.append("%s: a forced result returned a draw with both boards standing (%d vs %d)" % [label, player_alive, enemy_alive])
			await _retire_manager(manager)
			return
	var forced: bool = false
	for line: String in _resolution_log:
		if line.begins_with("Combat timeout") or line.begins_with("Combat no-progress timeout"):
			forced = true
	_forced_cases += 1
	print("StalemateResolutionProbe: %s resolved as %s (forced=%s)" % [label, _outcome, str(forced)])
	await _retire_manager(manager)

func _retire_manager(manager: CombatManager) -> void:
	var engine: Variant = manager.get_engine()
	if engine != null:
		engine.stop()
	manager.queue_free()
	await get_tree().process_frame

func _to_ids(values: Array) -> Array[String]:
	var output: Array[String] = []
	for value: Variant in values:
		output.append(String(value))
	return output

func _positions_for(count: int, is_player: bool) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	if count <= 0:
		return positions
	var x: float = 290.0 if is_player else 350.0
	var spacing: float = min(72.0, ARENA_SIZE.y / float(count + 1))
	for index: int in range(count):
		positions.append(Vector2(x, spacing * float(index + 1)))
	return positions

func _alive_count(team: Variant) -> int:
	var count: int = 0
	if not team is Array:
		return count
	for unit_value: Variant in team as Array:
		var unit: Unit = unit_value as Unit
		if unit != null and unit.is_alive():
			count += 1
	return count
