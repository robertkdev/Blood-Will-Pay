extends Node

const UnitFactory = preload("res://scripts/unit_factory.gd")
const BattleStateLib = preload("res://scripts/game/combat/battle_state.gd")
const CombatEngineLib = preload("res://scripts/game/combat/combat_engine.gd")
const MovementServiceLib = preload("res://scripts/game/combat/movement/movement_service2.gd")
const MovementProfileLib = preload("res://scripts/game/combat/movement/movement_profile.gd")
const Targeting = preload("res://scripts/game/combat/targeting.gd")

const TILE_SIZE: float = 64.0
const BOUNDS: Rect2 = Rect2(Vector2.ZERO, Vector2(640.0, 360.0))

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	_check_assassin_backline_priority(failures)
	_check_marksman_front_to_back_priority(failures)
	_check_periodic_retarget(failures)
	_check_ranged_kites_when_crowded(failures)
	_check_melee_closes_distance(failures)
	if failures.size() > 0:
		for failure in failures:
			push_error(failure)
		get_tree().quit(1)
		return
	print("MovementTargetPriorityProbe: PASS")
	get_tree().quit(0)

func _check_assassin_backline_priority(failures: Array[String]) -> void:
	var assassin: Unit = _spawn("hexeon")
	var tank: Unit = _spawn("brute")
	var carry: Unit = _spawn("sari")
	var allies: Array[Unit] = [assassin]
	var ally_positions: Array[Vector2] = [Vector2(64.0, 180.0)]
	var enemies: Array[Unit] = [tank, carry]
	var enemy_positions: Array[Vector2] = [Vector2(128.0, 180.0), Vector2(352.0, 180.0)]
	var picked: int = Targeting.pick_by_priority(
		assassin,
		Vector2(64.0, 180.0),
		allies,
		ally_positions,
		enemies,
		enemy_positions,
		-1,
		TILE_SIZE)
	_expect(picked == 1, "assassin should prioritize backline carry over nearer tank; picked=%d" % picked, failures)

func _check_marksman_front_to_back_priority(failures: Array[String]) -> void:
	var marksman: Unit = _spawn("sari")
	var tank: Unit = _spawn("brute")
	var mage: Unit = _spawn("mara")
	mage.hp = max(1, int(float(mage.max_hp) * 0.45))
	var allies: Array[Unit] = [marksman]
	var ally_positions: Array[Vector2] = [Vector2(64.0, 180.0)]
	var enemies: Array[Unit] = [tank, mage]
	var enemy_positions: Array[Vector2] = [Vector2(224.0, 180.0), Vector2(360.0, 180.0)]
	var picked: int = Targeting.pick_by_priority(
		marksman,
		Vector2(64.0, 180.0),
		allies,
		ally_positions,
		enemies,
		enemy_positions,
		-1,
		TILE_SIZE)
	_expect(picked == 0, "marksman should use front-to-back tank pressure before chasing farther mage; picked=%d" % picked, failures)

func _check_periodic_retarget(failures: Array[String]) -> void:
	var state: BattleState = BattleStateLib.new()
	state.reset()
	var assassin: Unit = _spawn("hexeon")
	var tank: Unit = _spawn("brute")
	var carry: Unit = _spawn("sari")
	state.player_team.append(assassin)
	state.enemy_team.append(tank)
	state.enemy_team.append(carry)
	var engine: CombatEngine = CombatEngineLib.new()
	engine.abilities_enabled = false
	engine.emit_auto_attack_logs = false
	engine.emit_ability_logs = false
	engine.configure(state, assassin, 1, Callable())
	engine.set_arena(TILE_SIZE, [Vector2(64.0, 180.0)], [Vector2(128.0, 180.0), Vector2(352.0, 180.0)], BOUNDS)
	engine.start()
	state.player_targets[0] = 0
	engine.process(0.36)
	var picked: int = engine.target_controller.current_target("player", 0)
	engine.teardown()
	_expect(picked == 1, "periodic retarget should replace stale tank target with assassin backline target; picked=%d" % picked, failures)

func _check_ranged_kites_when_crowded(failures: Array[String]) -> void:
	var state: BattleState = BattleStateLib.new()
	state.reset()
	var marksman: Unit = _spawn("sari")
	var tank: Unit = _spawn("brute")
	state.player_team.append(marksman)
	state.enemy_team.append(tank)
	var movement: MovementService2 = MovementServiceLib.new()
	movement.configure(TILE_SIZE, [Vector2(120.0, 180.0)], [Vector2(156.0, 180.0)], BOUNDS)
	movement.set_profiles("player", [MovementProfileLib.new("kite", 0.72, 1.02, 0.0, 1.0, 1.0)])
	movement.set_profiles("enemy", [MovementProfileLib.new("approach", 0.86, 0.94, 0.0, 0.0, -1.0)])
	var start_distance: float = movement.get_player_position(0).distance_to(movement.get_enemy_position(0))
	movement.update_movement(state, 0.20, Callable(self, "_target_zero"))
	var end_distance: float = movement.get_player_position(0).distance_to(movement.get_enemy_position(0))
	_expect(end_distance > start_distance + 4.0, "ranged profile should kite when inside minimum band; start=%.2f end=%.2f" % [start_distance, end_distance], failures)

func _check_melee_closes_distance(failures: Array[String]) -> void:
	var state: BattleState = BattleStateLib.new()
	state.reset()
	var brawler: Unit = _spawn("bonko")
	var tank: Unit = _spawn("brute")
	state.player_team.append(brawler)
	state.enemy_team.append(tank)
	var movement: MovementService2 = MovementServiceLib.new()
	movement.configure(TILE_SIZE, [Vector2(64.0, 180.0)], [Vector2(352.0, 180.0)], BOUNDS)
	movement.set_profiles("player", [MovementProfileLib.new("approach", 0.88, 0.98, 0.0, 0.0, 1.0)])
	movement.set_profiles("enemy", [MovementProfileLib.new("approach", 0.86, 0.94, 0.0, 0.0, -1.0)])
	var start_distance: float = movement.get_player_position(0).distance_to(movement.get_enemy_position(0))
	movement.update_movement(state, 0.30, Callable(self, "_target_zero"))
	var end_distance: float = movement.get_player_position(0).distance_to(movement.get_enemy_position(0))
	_expect(end_distance < start_distance - 8.0, "melee profiles should close distance; start=%.2f end=%.2f" % [start_distance, end_distance], failures)

func _spawn(unit_id: String) -> Unit:
	var unit: Unit = UnitFactory.spawn(unit_id)
	if unit == null:
		push_error("MovementTargetPriorityProbe: failed to spawn " + unit_id)
	return unit

func _target_zero(_team: String, _index: int) -> int:
	return 0

func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
