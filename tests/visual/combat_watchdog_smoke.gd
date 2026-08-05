extends Node

const BattleStateLib = preload("res://scripts/game/combat/battle_state.gd")
const CombatEngineLib = preload("res://scripts/game/combat/combat_engine.gd")

const TILE_SIZE: float = 64.0
const BOUNDS: Rect2 = Rect2(0.0, 0.0, 640.0, 360.0)

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	_run_stalled_case("no-progress", 0.25, 5.0, "Combat no-progress timeout", "tie", failures)
	_run_stalled_case("absolute", 0.0, 0.25, "Combat timeout", "tie", failures)
	if failures.size() > 0:
		for failure: String in failures:
			push_error("CombatWatchdogSmoke: " + failure)
		get_tree().quit(1)
		return
	print("CombatWatchdogSmoke: OK")
	get_tree().quit(0)

func _run_stalled_case(label: String, no_progress_timeout: float, absolute_timeout: float, expected_log: String, expected_outcome: String, failures: Array[String]) -> void:
	var state: BattleState = BattleStateLib.new()
	state.reset()
	var player: Unit = _make_stalled_unit("watchdog_player")
	var enemy: Unit = _make_stalled_unit("watchdog_enemy")
	state.player_team.append(player)
	state.enemy_team.append(enemy)

	var engine: CombatEngine = CombatEngineLib.new()
	engine.abilities_enabled = false
	engine.deterministic_rolls = true
	engine.combat_timeout_s = float(absolute_timeout)
	engine.no_progress_timeout_s = float(no_progress_timeout)
	var outcome: Dictionary = {"value": ""}
	var logs: Array[String] = []
	engine.defeat.connect(func(_stage: int) -> void:
		if String(outcome.get("value", "")) == "":
			outcome["value"] = "defeat"
	)
	engine.victory.connect(func(_stage: int) -> void:
		if String(outcome.get("value", "")) == "":
			outcome["value"] = "victory"
	)
	engine.tie.connect(func(_stage: int) -> void:
		if String(outcome.get("value", "")) == "":
			outcome["value"] = "tie"
	)
	engine.log_line.connect(func(text: String) -> void:
		logs.append(String(text))
	)
	engine.configure(state, player, 1, Callable())
	engine.set_arena(TILE_SIZE, [Vector2(64.0, 180.0)], [Vector2(512.0, 180.0)], BOUNDS)
	engine.start()

	for _frame: int in range(20):
		if String(outcome.get("value", "")) != "":
			break
		engine.process(0.05)

	_expect(String(outcome.get("value", "")) == expected_outcome, "%s case should force %s outcome, got '%s'" % [label, expected_outcome, String(outcome.get("value", ""))], failures)
	_expect(not state.battle_active, "%s case should stop battle after watchdog outcome" % label, failures)
	_expect(_logs_contain(logs, expected_log), "%s case did not log expected watchdog message" % label, failures)
	engine.teardown()
	state.reset()

func _make_stalled_unit(id: String) -> Unit:
	var unit: Unit = Unit.new()
	unit.id = String(id)
	unit.name = String(id)
	unit.max_hp = 100
	unit.hp = 100
	unit.attack_damage = 0.0
	unit.attack_speed = 0.01
	unit.attack_range = 1
	unit.move_speed = 0.0
	unit.mana_max = 0
	unit.mana = 0
	unit.mana_start = 0
	unit.mana_regen = 0.0
	unit.ability_id = ""
	return unit

func _logs_contain(logs: Array[String], expected: String) -> bool:
	for line: String in logs:
		if line.find(expected) >= 0:
			return true
	return false

func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
