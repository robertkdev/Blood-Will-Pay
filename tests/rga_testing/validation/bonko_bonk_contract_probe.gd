extends Node

const CombatEngineScript: GDScript = preload("res://scripts/game/combat/combat_engine.gd")
const BattleStateScript: GDScript = preload("res://scripts/game/combat/battle_state.gd")
const BonkoBonk: GDScript = preload("res://scripts/game/abilities/impls/bonko_bonk.gd")
const BuffTags: GDScript = preload("res://scripts/game/abilities/buff_tags.gd")

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
	var failures: Array[String] = []
	if engine.buff_system == null:
		failures.append("missing BuffSystem")
		_finish(engine, failures)
		return

	var ramp_events: Array[Dictionary] = []
	engine.ramp_state_changed.connect(_on_ramp_state_changed.bind(ramp_events))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 24680
	var ctx: AbilityContext = AbilityContext.new(engine, state, rng, "player", 0)
	ctx.buff_system = engine.buff_system
	var ability: Variant = BonkoBonk.new()
	var target: Unit = state.enemy_team[0]
	var hp_before: int = int(target.hp)
	var first_cast_ok: bool = bool(ability.call("cast", ctx))
	var first_damage: int = hp_before - int(target.hp)
	var first_stunned: bool = engine.buff_system.is_stunned(target)

	target.hp = target.max_hp
	var second_hp_before: int = int(target.hp)
	var second_cast_ok: bool = bool(ability.call("cast", ctx))
	var second_damage: int = second_hp_before - int(target.hp)
	var has_legacy_empower: bool = engine.buff_system.has_tag(state, "player", 0, BuffTags.TAG_BONKO_EMPOWER)

	_expect(first_cast_ok, "Bonk did not cast", failures)
	_expect(first_damage > 0, "Bonk did not damage its current target", failures)
	_expect(first_stunned, "Bonk did not stun its current target", failures)
	_expect(second_cast_ok, "Bonk did not recast against an already-stunned target", failures)
	_expect(second_damage > first_damage, "already-stunned target did not take conditional bonus damage", failures)
	_expect(not has_legacy_empower, "Bonk applied the retired persistent empower tag", failures)
	_expect(ramp_events.is_empty(), "Bonk emitted retired ramp telemetry", failures)

	print("BonkoBonkContractProbe: first_damage=%d second_damage=%d stunned=%s ramp_events=%d legacy_empower=%s" % [
		first_damage,
		second_damage,
		str(first_stunned),
		ramp_events.size(),
		str(has_legacy_empower),
	])
	_finish(engine, failures)

func _on_ramp_state_changed(source_team: String, source_index: int, kind: String, stacks: int, value: float, peak_stacks: int, duration_s: float, reason: String, ramp_events: Array[Dictionary]) -> void:
	ramp_events.append({
		"source_team": source_team,
		"source_index": source_index,
		"kind": kind,
		"stacks": stacks,
		"value": value,
		"peak_stacks": peak_stacks,
		"duration_s": duration_s,
		"reason": reason,
	})

func _make_state() -> BattleState:
	var state: BattleState = BattleStateScript.new()
	var bonko: Unit = _make_unit("bonko", 2000)
	bonko.attack_damage = 100.0
	var target: Unit = _make_unit("target_dummy", 2000)
	state.player_team = [bonko]
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
	unit.id = unit_id
	unit.name = unit_id
	unit.max_hp = max_hp
	unit.hp = max_hp
	unit.armor = 0.0
	unit.magic_resist = 0.0
	unit.damage_reduction = 0.0
	unit.damage_reduction_flat = 0.0
	return unit

func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)

func _finish(engine: CombatEngine, failures: Array[String]) -> void:
	if engine != null:
		engine.stop()
		engine.teardown()
	var code: int = 0
	if failures.is_empty():
		print("BonkoBonkContractProbe: PASS")
	else:
		code = 1
		for failure: String in failures:
			push_error("BonkoBonkContractProbe: %s" % failure)
	if do_quit_on_finish:
		get_tree().quit(code)
