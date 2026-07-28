extends Node

const BattleStateLib := preload("res://scripts/game/combat/battle_state.gd")
const CombatEngineLib := preload("res://scripts/game/combat/combat_engine.gd")
const BossRuleLib := preload("res://scripts/game/progression/rules/providers/boss_rule.gd")
const UnitLib := preload("res://scripts/unit.gd")

var failures: Array[String] = []

func _ready() -> void:
	var state: BattleState = BattleStateLib.new()
	state.player_team = [_make_unit("hero_a", 1000, 80.0, 2), _make_unit("hero_b", 1000, 80.0, 2)]
	state.enemy_team = [
		_make_unit("boss", 400, 120.0, 5),
		_make_unit("guard_a", 200, 60.0, 2),
		_make_unit("guard_b", 200, 60.0, 2),
		_make_unit("guard_c", 200, 60.0, 2),
	]
	var spec: Dictionary = {"ids": ["boss", "guard_a", "guard_b", "guard_c"], "kind": "BOSS", "rules": {}}
	var boss_rule: BossRule = BossRuleLib.new()
	boss_rule.on_pre_spawn(spec, 8, 4)
	var rules: Dictionary = spec.get("rules", {}) as Dictionary
	var escalation: Dictionary = rules.get("escalation", {}) as Dictionary
	_expect(bool(rules.get("is_boss", false)), "boss rule should mark the encounter")
	_expect((escalation.get("phases", []) as Array).size() == 2, "boss rule should author two escalation phases")

	var engine: Variant = CombatEngineLib.new()
	boss_rule.on_pre_engine_config(state, engine, spec, 8, 4)
	engine.abilities_enabled = false
	engine.emit_position_telemetry = false
	engine.emit_target_telemetry = false
	engine.configure(state, state.player_team[0], 32)
	engine.start()

	state.enemy_team[1].hp = 0
	state.enemy_team[2].hp = 0
	state.enemy_team[3].hp = 50
	engine.process(0.1)
	_expect(engine.encounter_escalation_runtime.next_phase_index == 1, "65% threshold should trigger phase one")
	_expect(state.enemy_team[0].max_hp == 460, "phase one should enlarge the strongest survivor")
	_expect(is_equal_approx(state.enemy_team[0].attack_damage, 144.0), "phase one should transform boss offense")
	_expect(state.enemy_team[1].hp == 80 and state.enemy_team[2].hp == 80, "phase one should revive two fallen allies at 40% health")
	_expect(state.player_team[0].hp == 960 and state.player_team[1].hp == 960, "phase one arena pulse should damage every living player")

	engine.process(0.5)
	_expect(engine.encounter_escalation_runtime.next_phase_index == 1, "minimum phase gap should prevent immediate double triggering")
	state.elapsed_time = 3.0
	state.enemy_team[0].hp = 20
	state.enemy_team[1].hp = 0
	state.enemy_team[2].hp = 0
	state.enemy_team[3].hp = 0
	engine.process(0.1)
	_expect(engine.encounter_escalation_runtime.next_phase_index == 2, "30% threshold should trigger the final phase after the gap")
	_expect(state.enemy_team[1].hp == 100 and state.enemy_team[2].hp == 100 and state.enemy_team[3].hp == 100, "final phase should return every fallen ally at 50% health")
	_expect(state.player_team[0].hp == 890 and state.player_team[1].hp == 890, "final arena pulse should add 7% max-health damage")
	engine.teardown()

	if failures.is_empty():
		print("ENCOUNTER_ESCALATION_PROBE PASS phases=2 revived=5 pulse_damage=220")
		get_tree().quit(0)
	else:
		for failure: String in failures:
			push_error(failure)
		print("ENCOUNTER_ESCALATION_PROBE FAIL count=%d" % failures.size())
		get_tree().quit(1)

func _make_unit(id: String, max_hp: int, attack_damage: float, cost: int) -> Unit:
	var unit: Unit = UnitLib.new()
	unit.id = id
	unit.name = id
	unit.max_hp = max_hp
	unit.hp = max_hp
	unit.attack_damage = attack_damage
	unit.spell_power = attack_damage * 0.5
	unit.attack_speed = 1.0
	unit.cost = cost
	unit.mana_max = 100
	unit.mana_start = 0
	unit.mana = 0
	return unit

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
