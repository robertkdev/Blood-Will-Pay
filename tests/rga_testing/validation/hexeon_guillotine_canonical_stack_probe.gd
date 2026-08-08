extends Node

const CombatEngineScript := preload("res://scripts/game/combat/combat_engine.gd")
const BattleStateScript := preload("res://scripts/game/combat/battle_state.gd")
const HexeonGuillotine := preload("res://scripts/game/abilities/impls/hexeon_prismatic_guillotine.gd")
const TraitKeys := preload("res://scripts/game/traits/runtime/trait_keys.gd")

@export var do_quit_on_finish: bool = true

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var damage_case: Dictionary = _run_damage_case()
	var execute_case: Dictionary = _run_execute_case()
	var failed: bool = false

	print("HexeonGuillotineCanonicalStackProbe: damage_cast=", bool(damage_case.get("cast_ok", false)),
		" damage_canonical_kalei=", int(damage_case.get("canonical_kalei", 0)),
		" damage_legacy_kalei=", int(damage_case.get("legacy_kalei", 0)),
		" damage_dealt=", int(damage_case.get("damage_dealt", 0)),
		" expected_damage=", int(damage_case.get("expected_damage", 0)),
		" execute_cast=", bool(execute_case.get("cast_ok", false)),
		" execute_canonical_executioner=", int(execute_case.get("canonical_executioner", 0)),
		" execute_legacy_executioner=", int(execute_case.get("legacy_executioner", 0)),
		" execute_target_alive=", bool(execute_case.get("target_alive", true)))

	if not bool(damage_case.get("cast_ok", false)):
		printerr("HexeonGuillotineCanonicalStackProbe: FAIL damage case did not cast")
		failed = true
	if int(damage_case.get("canonical_kalei", 0)) != int(damage_case.get("expected_kalei", 0)):
		printerr("HexeonGuillotineCanonicalStackProbe: FAIL canonical Kaleidoscope stack count changed")
		failed = true
	if int(damage_case.get("legacy_kalei", 0)) != 0:
		printerr("HexeonGuillotineCanonicalStackProbe: FAIL damage case unexpectedly used legacy Kaleidoscope stacks")
		failed = true
	if int(damage_case.get("damage_dealt", 0)) != int(damage_case.get("expected_damage", 0)):
		printerr("HexeonGuillotineCanonicalStackProbe: FAIL canonical Kaleidoscope stacks did not scale damage")
		failed = true
	if not bool(execute_case.get("cast_ok", false)):
		printerr("HexeonGuillotineCanonicalStackProbe: FAIL execute case did not cast")
		failed = true
	if int(execute_case.get("canonical_executioner", 0)) != int(execute_case.get("expected_executioner", 0)):
		printerr("HexeonGuillotineCanonicalStackProbe: FAIL canonical Executioner stack count changed")
		failed = true
	if int(execute_case.get("legacy_executioner", 0)) != 0:
		printerr("HexeonGuillotineCanonicalStackProbe: FAIL execute case unexpectedly used legacy Executioner stacks")
		failed = true
	if bool(execute_case.get("target_alive", true)):
		printerr("HexeonGuillotineCanonicalStackProbe: FAIL canonical Executioner stacks did not enable low-HP execute")
		failed = true

	if failed:
		_quit(1)
		return
	print("HexeonGuillotineCanonicalStackProbe: PASS")
	_quit(0)

func _run_damage_case() -> Dictionary:
	var state: BattleState = _make_state(1000, 1000)
	var engine: CombatEngine = _make_engine(state)
	var expected_kalei: int = 5
	var expected_damage: int = 300 + (12 * expected_kalei)
	var target: Unit = state.enemy_team[0]
	var before_hp: int = int(target.hp)
	var stack_res: Dictionary = engine.buff_system.add_stack(state, "player", 0, TraitKeys.KALEIDOSCOPE, expected_kalei)
	if not bool(stack_res.get("processed", false)):
		_finish_engine(engine)
		return {"cast_ok": false}
	var cast_ok: bool = _cast_hexeon(engine, state)
	var result: Dictionary = {
		"cast_ok": cast_ok,
		"expected_kalei": expected_kalei,
		"canonical_kalei": int(engine.buff_system.get_stack(state, "player", 0, TraitKeys.KALEIDOSCOPE)),
		"legacy_kalei": int(engine.buff_system.get_stack(state, "player", 0, "kaleidoscope_stacks")),
		"damage_dealt": before_hp - int(target.hp),
		"expected_damage": expected_damage
	}
	_finish_engine(engine)
	return result

func _run_execute_case() -> Dictionary:
	var state: BattleState = _make_state(190, 1000)
	var engine: CombatEngine = _make_engine(state)
	var expected_executioner: int = 4
	var stack_res: Dictionary = engine.buff_system.add_stack(state, "player", 0, TraitKeys.EXECUTIONER, expected_executioner)
	if not bool(stack_res.get("processed", false)):
		_finish_engine(engine)
		return {"cast_ok": false}
	var cast_ok: bool = _cast_hexeon(engine, state)
	var target: Unit = state.enemy_team[0]
	var result: Dictionary = {
		"cast_ok": cast_ok,
		"expected_executioner": expected_executioner,
		"canonical_executioner": int(engine.buff_system.get_stack(state, "player", 0, TraitKeys.EXECUTIONER)),
		"legacy_executioner": int(engine.buff_system.get_stack(state, "player", 0, "executioner_stacks")),
		"target_alive": target.is_alive()
	}
	_finish_engine(engine)
	return result

func _make_engine(state: BattleState) -> CombatEngine:
	var engine: CombatEngine = CombatEngineScript.new()
	engine.abilities_enabled = false
	engine.emit_auto_attack_logs = false
	engine.emit_ability_logs = false
	engine.configure(state, state.player_team[0], 1, Callable())
	engine.set_arena(
		72.0,
		[Vector2(100.0, 140.0)],
		[Vector2(300.0, 140.0)],
		Rect2(0.0, 0.0, 900.0, 360.0)
	)
	engine.start()
	return engine

func _cast_hexeon(engine: CombatEngine, state: BattleState) -> bool:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 17320
	var ctx: AbilityContext = AbilityContext.new(engine, state, rng, "player", 0)
	ctx.buff_system = engine.buff_system
	var ability: Variant = HexeonGuillotine.new()
	return bool(ability.call("cast", ctx))

func _make_state(target_hp: int, target_max_hp: int) -> BattleState:
	var state: BattleState = BattleStateScript.new()
	var hexeon: Unit = _make_unit("hexeon", 1000)
	hexeon.level = 1
	hexeon.spell_power = 0.0
	var target: Unit = _make_unit("target_dummy", target_max_hp)
	target.hp = int(target_hp)
	state.player_team = [hexeon]
	state.enemy_team = [target]
	state.player_cds = [0.0]
	state.enemy_cds = [0.0]
	state.player_targets = [0]
	state.enemy_targets = [0]
	state.player_damage_this_round = [0]
	state.enemy_damage_this_round = [0]
	state.player_pupil_map = [-1]
	state.enemy_pupil_map = [-1]
	return state

func _make_unit(unit_id: String, max_hp: int) -> Unit:
	var unit: Unit = Unit.new()
	unit.id = String(unit_id)
	unit.name = String(unit_id)
	unit.max_hp = int(max_hp)
	unit.hp = int(max_hp)
	unit.armor = 0.0
	unit.magic_resist = 0.0
	unit.damage_reduction = 0.0
	unit.damage_reduction_flat = 0.0
	return unit

func _finish_engine(engine: CombatEngine) -> void:
	if engine != null:
		engine.stop()
		engine.teardown()

func _quit(code: int) -> void:
	if not do_quit_on_finish:
		return
	get_tree().quit(code)
