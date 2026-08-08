extends Node

const CombatEngineScript := preload("res://scripts/game/combat/combat_engine.gd")
const BattleStateScript := preload("res://scripts/game/combat/battle_state.gd")
const OmenryCondemningShot := preload("res://scripts/game/abilities/impls/omenry_condemning_shot.gd")
const QuorraTimeplateLunge := preload("res://scripts/game/abilities/impls/quorra_timeplate_lunge.gd")

const TILE_SIZE: float = 64.0
const ARENA_BOUNDS: Rect2 = Rect2(0.0, 0.0, 1200.0, 640.0)
const QUEUE_START: Vector2 = Vector2(400.0, 320.0)
const QUEUE_TARGET: Vector2 = Vector2(900.0, 128.0)
const QUEUE_REPOSITION_TILES: float = 2.15
const QUEUE_MOVE_DURATION: float = 0.16
const DIRECT_START: Vector2 = Vector2(320.0, 320.0)
const DIRECT_TARGET: Vector2 = Vector2(800.0, 256.0)
const DIRECT_MOVE_DURATION: float = 0.18
const POSITION_EPSILON: float = 0.01

@export var do_quit_on_finish: bool = true

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	_check_queue_only_displacement(failures)
	_check_direct_only_displacement(failures)
	if not failures.is_empty():
		for failure: String in failures:
			push_error(failure)
		_finish(1)
		return
	print("ForcedMovementAbilityContractProbe: PASS")
	_finish(0)

func _check_queue_only_displacement(failures: Array[String]) -> void:
	var fixture: Dictionary[String, Variant] = _make_fixture(QUEUE_START, QUEUE_TARGET)
	var state: BattleState = fixture["state"] as BattleState
	var engine: CombatEngine = fixture["engine"] as CombatEngine
	var ctx: AbilityContext = _context(engine, state)
	var ability: Variant = OmenryCondemningShot.new()
	var expected: Vector2 = QUEUE_START + Vector2(-QUEUE_REPOSITION_TILES * TILE_SIZE, 0.0)

	ability.call("_reposition", ctx)
	var immediate: Vector2 = engine.get_player_position(0)
	_expect(_vector_close(immediate, QUEUE_START), "Queue-only Omenry reposition mutated canonical position before the forced impulse was consumed", failures)

	_step_movement(engine, state, QUEUE_MOVE_DURATION)
	var after_one_impulse: Vector2 = engine.get_player_position(0)
	_expect(_vector_close(after_one_impulse, expected), "Queue-only Omenry reposition did not apply exactly one expected displacement", failures)

	_step_movement(engine, state, QUEUE_MOVE_DURATION)
	var after_second_step: Vector2 = engine.get_player_position(0)
	_expect(_vector_close(after_second_step, expected), "Queue-only Omenry reposition applied a second displacement after its impulse completed", failures)
	_teardown_fixture(engine)

func _check_direct_only_displacement(failures: Array[String]) -> void:
	var fixture: Dictionary[String, Variant] = _make_fixture(DIRECT_START, DIRECT_TARGET)
	var state: BattleState = fixture["state"] as BattleState
	var engine: CombatEngine = fixture["engine"] as CombatEngine
	var ctx: AbilityContext = _context(engine, state)
	var ability: Variant = QuorraTimeplateLunge.new()

	ability.call("_blink_to_target", ctx, "enemy", 0)
	var immediate: Vector2 = engine.get_player_position(0)
	_expect(not _vector_close(immediate, DIRECT_START), "Direct-only Quorra blink did not apply an immediate displacement", failures)

	_step_movement(engine, state, DIRECT_MOVE_DURATION)
	var after_one_step: Vector2 = engine.get_player_position(0)
	_expect(_vector_close(after_one_step, immediate), "Direct-only Quorra blink retained a queued duplicate displacement", failures)

	_step_movement(engine, state, DIRECT_MOVE_DURATION)
	var after_second_step: Vector2 = engine.get_player_position(0)
	_expect(_vector_close(after_second_step, immediate), "Direct-only Quorra blink moved again after its direct displacement", failures)
	_teardown_fixture(engine)

func _make_fixture(player_position: Vector2, enemy_position: Vector2) -> Dictionary[String, Variant]:
	var player: Unit = _make_unit("movement_probe_player")
	var enemy: Unit = _make_unit("movement_probe_enemy")
	var players: Array[Unit] = [player]
	var enemies: Array[Unit] = [enemy]
	var state: BattleState = BattleStateScript.new()
	state.player_team = players
	state.enemy_team = enemies
	state.player_cds = [0.0]
	state.enemy_cds = [0.0]
	state.player_targets = [0]
	state.enemy_targets = [0]
	state.player_damage_this_round = [0]
	state.enemy_damage_this_round = [0]
	state.player_pupil_map = [-1]
	state.enemy_pupil_map = [-1]

	var engine: CombatEngine = CombatEngineScript.new()
	engine.abilities_enabled = false
	engine.emit_auto_attack_logs = false
	engine.emit_ability_logs = false
	engine.configure(state, player, 1, Callable())
	var player_positions: Array[Vector2] = [player_position]
	var enemy_positions: Array[Vector2] = [enemy_position]
	engine.set_arena(TILE_SIZE, player_positions, enemy_positions, ARENA_BOUNDS)
	engine.start()
	state.player_targets = [0]
	state.enemy_targets = [0]
	return {"state": state, "engine": engine}

func _make_unit(unit_id: String) -> Unit:
	var unit: Unit = Unit.new()
	unit.id = unit_id
	unit.name = unit_id
	unit.level = 1
	unit.max_hp = 5000
	unit.hp = 5000
	unit.attack_damage = 100.0
	unit.attack_speed = 1.0
	unit.attack_range = 1
	unit.move_speed = 0.0
	unit.armor = 0.0
	unit.magic_resist = 0.0
	return unit

func _context(engine: CombatEngine, state: BattleState) -> AbilityContext:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 73013
	return AbilityContext.new(engine, state, rng, "player", 0)

func _step_movement(engine: CombatEngine, state: BattleState, delta: float) -> void:
	var player_targets: Array[int] = [0]
	var enemy_targets: Array[int] = [0]
	engine.arena_state.update_movement_with_targets(state, delta, player_targets, enemy_targets)

func _vector_close(actual: Vector2, expected: Vector2) -> bool:
	return actual.distance_to(expected) <= POSITION_EPSILON

func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)

func _teardown_fixture(engine: CombatEngine) -> void:
	if engine == null:
		return
	engine.stop()
	engine.teardown()

func _finish(code: int) -> void:
	if do_quit_on_finish:
		get_tree().quit(code)
