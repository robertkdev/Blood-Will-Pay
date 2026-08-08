extends Node

const CombatEngineScript := preload("res://scripts/game/combat/combat_engine.gd")
const BattleStateScript := preload("res://scripts/game/combat/battle_state.gd")
const MorrakReapingLine := preload("res://scripts/game/abilities/impls/morrak_reaping_line.gd")
const TraitKeys := preload("res://scripts/game/traits/runtime/trait_keys.gd")

@export var do_quit_on_finish: bool = true

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var state: BattleState = _make_state()
	var engine: CombatEngine = CombatEngineScript.new()
	engine.abilities_enabled = false
	engine.emit_auto_attack_logs = false
	engine.emit_ability_logs = false
	engine.configure(state, state.player_team[0], 1, Callable())
	engine.set_arena(
		72.0,
		[Vector2(100.0, 140.0)],
		[Vector2(250.0, 140.0), Vector2(310.0, 140.0)],
		Rect2(0.0, 0.0, 900.0, 360.0)
	)
	engine.start()

	var failed: bool = false
	if engine.buff_system == null:
		printerr("MorrakReapingLineCanonicalStackProbe: FAIL missing BuffSystem")
		failed = true
	if failed:
		_finish(engine, 1)
		return

	var morrak: Unit = state.player_team[0]
	var high_target: Unit = state.enemy_team[0]
	var execute_target: Unit = state.enemy_team[1]
	var expected_striker: int = 3
	var expected_executioner: int = 4
	var expected_hit_damage: int = 110 + (12 * expected_striker) + (10 * expected_executioner)
	var expected_heal: int = int(round(0.30 * float(morrak.max_hp)))
	var before_high_hp: int = int(high_target.hp)
	var before_morrak_hp: int = int(morrak.hp)

	var striker_res: Dictionary = engine.buff_system.add_stack(state, "player", 0, TraitKeys.STRIKER, expected_striker)
	var exec_res: Dictionary = engine.buff_system.add_stack(state, "player", 0, TraitKeys.EXECUTIONER, expected_executioner)
	if not bool(striker_res.get("processed", false)) or not bool(exec_res.get("processed", false)):
		printerr("MorrakReapingLineCanonicalStackProbe: FAIL could not add canonical stacks")
		_finish(engine, 1)
		return

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 14142
	var ctx: AbilityContext = AbilityContext.new(engine, state, rng, "player", 0)
	ctx.buff_system = engine.buff_system
	var ability: Variant = MorrakReapingLine.new()
	var preferred_target: int = int(ability.call("_preferred_target", ctx, 0.33))
	var cast_ok: bool = bool(ability.call("cast", ctx))

	var canonical_striker: int = int(engine.buff_system.get_stack(state, "player", 0, TraitKeys.STRIKER))
	var canonical_executioner: int = int(engine.buff_system.get_stack(state, "player", 0, TraitKeys.EXECUTIONER))
	var legacy_striker: int = int(engine.buff_system.get_stack(state, "player", 0, "striker_stacks"))
	var legacy_executioner: int = int(engine.buff_system.get_stack(state, "player", 0, "executioner_stacks"))
	var high_damage: int = before_high_hp - int(high_target.hp)
	var execute_target_alive: bool = execute_target.is_alive()
	var morrak_heal: int = int(morrak.hp) - before_morrak_hp

	print("MorrakReapingLineCanonicalStackProbe: cast_ok=", cast_ok,
		" preferred_target=", preferred_target,
		" canonical_striker=", canonical_striker,
		" canonical_executioner=", canonical_executioner,
		" legacy_striker=", legacy_striker,
		" legacy_executioner=", legacy_executioner,
		" high_damage=", high_damage,
		" expected_hit_damage=", expected_hit_damage,
		" execute_target_alive=", execute_target_alive,
		" morrak_heal=", morrak_heal,
		" expected_heal=", expected_heal)

	if not cast_ok:
		printerr("MorrakReapingLineCanonicalStackProbe: FAIL Reaping Line did not cast")
		failed = true
	if preferred_target != 1:
		printerr("MorrakReapingLineCanonicalStackProbe: FAIL Reaping Line did not prefer the executable enemy")
		failed = true
	if canonical_striker != expected_striker or canonical_executioner != expected_executioner:
		printerr("MorrakReapingLineCanonicalStackProbe: FAIL canonical stack count changed")
		failed = true
	if legacy_striker != 0 or legacy_executioner != 0:
		printerr("MorrakReapingLineCanonicalStackProbe: FAIL probe unexpectedly used legacy stacks")
		failed = true
	if high_damage != expected_hit_damage:
		printerr("MorrakReapingLineCanonicalStackProbe: FAIL canonical stacks did not scale Reaping Line damage")
		failed = true
	if execute_target_alive:
		printerr("MorrakReapingLineCanonicalStackProbe: FAIL canonical Executioner stacks did not enable low-HP execute")
		failed = true
	if morrak_heal != expected_heal:
		printerr("MorrakReapingLineCanonicalStackProbe: FAIL execute heal did not apply")
		failed = true

	if failed:
		_finish(engine, 1)
		return
	print("MorrakReapingLineCanonicalStackProbe: PASS")
	_finish(engine, 0)

func _make_state() -> BattleState:
	var state: BattleState = BattleStateScript.new()
	var morrak: Unit = _make_unit("morrak", 1000)
	morrak.hp = 700
	morrak.level = 1
	morrak.attack_damage = 0.0
	# Keep this enemy lower in absolute HP than the executable target while its
	# HP percentage remains above the threshold. This guards against selecting
	# only the lowest absolute-HP enemy and missing a valid execute elsewhere.
	var high_target: Unit = _make_unit("enemy_high", 600)
	high_target.hp = 450
	var execute_target: Unit = _make_unit("enemy_execute", 2000)
	execute_target.hp = 500
	state.player_team = [morrak]
	state.enemy_team = [high_target, execute_target]
	state.player_cds = [0.0]
	state.enemy_cds = [0.0, 0.0]
	state.player_targets = [0]
	state.enemy_targets = [0, 0]
	state.player_damage_this_round = [0]
	state.enemy_damage_this_round = [0, 0]
	state.player_pupil_map = [-1]
	state.enemy_pupil_map = [-1, -1]
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

func _finish(engine: CombatEngine, code: int) -> void:
	if engine != null:
		engine.stop()
		engine.teardown()
	_quit(code)

func _quit(code: int) -> void:
	if not do_quit_on_finish:
		return
	get_tree().quit(code)
