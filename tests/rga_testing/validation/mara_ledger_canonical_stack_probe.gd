extends Node

const CombatEngineScript := preload("res://scripts/game/combat/combat_engine.gd")
const BattleStateScript := preload("res://scripts/game/combat/battle_state.gd")
const MaraLedger := preload("res://scripts/game/abilities/impls/mara_arcane_ledger.gd")
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
	engine.start()

	var failed: bool = false
	if engine.buff_system == null:
		printerr("MaraLedgerCanonicalStackProbe: FAIL missing BuffSystem")
		failed = true
	if failed:
		_finish(engine, 1)
		return

	var mara: Unit = state.player_team[0]
	var target: Unit = state.enemy_team[0]
	var expected_stacks: int = 4
	var expected_damage: int = 170 + (20 * expected_stacks)
	var before_hp: int = int(target.hp)

	var stack_res: Dictionary = engine.buff_system.add_stack(state, "player", 0, TraitKeys.ARCANIST, expected_stacks)
	if not bool(stack_res.get("processed", false)):
		printerr("MaraLedgerCanonicalStackProbe: FAIL could not add canonical Arcanist stacks")
		_finish(engine, 1)
		return

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 27182
	var ctx: AbilityContext = AbilityContext.new(engine, state, rng, "player", 0)
	ctx.buff_system = engine.buff_system
	var ability: Variant = MaraLedger.new()
	var cast_ok: bool = bool(ability.call("cast", ctx))

	var canonical_stacks: int = int(engine.buff_system.get_stack(state, "player", 0, TraitKeys.ARCANIST))
	var legacy_stacks: int = int(engine.buff_system.get_stack(state, "player", 0, "arcanist_stacks"))
	var after_hp: int = int(target.hp)
	var damage_dealt: int = before_hp - after_hp

	print("MaraLedgerCanonicalStackProbe: cast_ok=", cast_ok,
		" canonical_stacks=", canonical_stacks,
		" legacy_stacks=", legacy_stacks,
		" spell_power=", float(mara.spell_power),
		" damage_dealt=", damage_dealt,
		" expected_damage=", expected_damage,
		" target_after_hp=", after_hp)

	if not cast_ok:
		printerr("MaraLedgerCanonicalStackProbe: FAIL Arcane Ledger did not cast")
		failed = true
	if canonical_stacks != expected_stacks:
		printerr("MaraLedgerCanonicalStackProbe: FAIL canonical Arcanist stack count changed")
		failed = true
	if legacy_stacks != 0:
		printerr("MaraLedgerCanonicalStackProbe: FAIL probe unexpectedly used legacy Arcanist stacks")
		failed = true
	if damage_dealt != expected_damage:
		printerr("MaraLedgerCanonicalStackProbe: FAIL Arcane Ledger did not consume canonical Arcanist stacks")
		failed = true
	if after_hp <= 0:
		printerr("MaraLedgerCanonicalStackProbe: FAIL probe killed target and risked economy autoload side effects")
		failed = true

	if failed:
		_finish(engine, 1)
		return
	print("MaraLedgerCanonicalStackProbe: PASS")
	_finish(engine, 0)

func _make_state() -> BattleState:
	var state: BattleState = BattleStateScript.new()
	var mara: Unit = _make_unit("mara", 1000)
	mara.level = 1
	mara.spell_power = 0.0
	var target: Unit = _make_unit("target_dummy", 1000)
	target.magic_resist = 0.0
	state.player_team = [mara]
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

func _finish(engine: CombatEngine, code: int) -> void:
	if engine != null:
		engine.stop()
		engine.teardown()
	_quit(code)

func _quit(code: int) -> void:
	if not do_quit_on_finish:
		return
	get_tree().quit(code)
