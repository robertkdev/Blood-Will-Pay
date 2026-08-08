extends Node

const CombatEngineScript := preload("res://scripts/game/combat/combat_engine.gd")
const BattleStateScript := preload("res://scripts/game/combat/battle_state.gd")
const HexeonExecute := preload("res://scripts/game/abilities/impls/hexeon_prismatic_guillotine.gd")
const CombatPatternKernel := preload("res://tests/rga_testing/aggregators/kernels/combat_pattern_kernel.gd")
const ExecuteApproachTest := preload("res://tests/rga_testing/metrics/approach/execute_approach_test.gd")

@export var do_quit_on_finish: bool = true

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var low_case: Dictionary = _run_execute_case("low_hp_threshold", 110, 1000)
	var high_case: Dictionary = _run_execute_case("above_threshold", 500, 1000)
	var metric_result: Dictionary = _run_metric_result(low_case, high_case)

	var low_rec: Dictionary = low_case.get("record", {}) if (low_case is Dictionary) else {}
	var high_rec: Dictionary = high_case.get("record", {}) if (high_case is Dictionary) else {}
	var low_cast: bool = bool(low_case.get("cast", false))
	var high_cast: bool = bool(high_case.get("cast", false))
	var low_target_alive: bool = bool(low_case.get("target_alive", true))
	var high_target_alive: bool = bool(high_case.get("target_alive", false))
	var low_bonus_events: int = int(low_rec.get("execute_bonus_events", 0))
	var low_bonus_damage: float = float(low_rec.get("execute_bonus_damage", 0.0))
	var low_bonus_hp_pct: float = float(low_rec.get("execute_bonus_target_hp_pct_avg", 1.0))
	var low_bonus_threshold: float = float(low_rec.get("execute_bonus_threshold_pct_max", 0.0))
	var low_kills: int = int(low_rec.get("low_hp_kill_count", 0))
	var low_outside_threshold: int = int(low_rec.get("execute_bonus_outside_threshold_events", 0))
	var high_bonus_events: int = int(high_rec.get("execute_bonus_events", 0))
	var high_kills: int = int(high_rec.get("kill_count", 0))
	var metric_pass: bool = bool(metric_result.get("pass", false))
	var metric_bonus_span: bool = _has_span_label(metric_result, "subject_execute_bonus_damage_share")
	var metric_outside_span: bool = _has_span_label(metric_result, "subject_execute_bonus_outside_threshold_events")

	print("HexeonExecuteLiveProbe: low_cast=", low_cast,
		" low_target_alive=", low_target_alive,
		" low_bonus_events=", low_bonus_events,
		" low_bonus_damage=", low_bonus_damage,
		" low_bonus_hp_pct=", low_bonus_hp_pct,
		" low_bonus_threshold=", low_bonus_threshold,
		" low_kills=", low_kills,
		" low_outside_threshold=", low_outside_threshold,
		" high_cast=", high_cast,
		" high_target_alive=", high_target_alive,
		" high_bonus_events=", high_bonus_events,
		" high_kills=", high_kills,
		" metric_pass=", metric_pass)

	var failed: bool = false
	if not low_cast or not high_cast:
		printerr("HexeonExecuteLiveProbe: FAIL Hexeon ability did not cast in both threshold cases")
		failed = true
	if low_target_alive:
		printerr("HexeonExecuteLiveProbe: FAIL low-HP target was not executed")
		failed = true
	if high_target_alive == false:
		printerr("HexeonExecuteLiveProbe: FAIL above-threshold target was executed or killed")
		failed = true
	if low_bonus_events != 1 or low_bonus_damage <= 0.0 or low_kills != 1:
		printerr("HexeonExecuteLiveProbe: FAIL low-HP execute bonus or kill telemetry was not captured")
		failed = true
	if low_bonus_hp_pct > low_bonus_threshold + 0.001 or low_outside_threshold != 0:
		printerr("HexeonExecuteLiveProbe: FAIL low-HP execute was recorded outside threshold")
		failed = true
	if high_bonus_events != 0 or high_kills != 0:
		printerr("HexeonExecuteLiveProbe: FAIL above-threshold case produced execute bonus or kill telemetry")
		failed = true
	if not metric_pass or not metric_bonus_span or not metric_outside_span:
		printerr("HexeonExecuteLiveProbe: FAIL approach_execute did not consume live threshold evidence")
		failed = true

	if failed:
		_quit(1)
		return
	print("HexeonExecuteLiveProbe: PASS")
	_quit(0)

func _run_execute_case(case_id: String, target_hp: int, target_max_hp: int) -> Dictionary:
	var engine: CombatEngine = CombatEngineScript.new()
	var state: BattleState = _make_state(target_hp, target_max_hp)
	engine.abilities_enabled = false
	engine.emit_auto_attack_logs = false
	engine.emit_ability_logs = false
	engine.configure(state, state.player_team[0], 1)
	engine.set_arena(72.0, [Vector2(100.0, 180.0)], [Vector2(520.0, 180.0)], Rect2(0.0, 0.0, 900.0, 360.0))
	engine.start()
	engine.attack_resolver.emit_auto_attack_logs = false

	var kernel: Variant = CombatPatternKernel.new()
	kernel.call("attach", engine, {"a": 1, "b": 1}, _context_tags(), true)
	kernel.call("tick", 0.10)

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 9917
	var ctx: AbilityContext = AbilityContext.new(engine, state, rng, "player", 0)
	ctx.buff_system = engine.buff_system
	var ability: Variant = HexeonExecute.new()
	var cast_result: bool = bool(ability.call("cast", ctx))
	kernel.call("tick", 0.10)
	kernel.call("finalize", 0.20)

	var kernel_result: Dictionary = kernel.call("result")
	var rec: Dictionary = _subject_record(kernel_result, "a", "hexeon")
	var target: Unit = state.enemy_team[0]
	var target_alive: bool = target != null and target.is_alive()

	kernel.call("detach")
	engine.stop()
	engine.teardown()
	return {
		"id": String(case_id),
		"cast": cast_result,
		"target_alive": target_alive,
		"record": rec,
		"kernels": kernel_result
	}

func _make_state(target_hp: int, target_max_hp: int) -> BattleState:
	var state: BattleState = BattleStateScript.new()
	var hexeon: Unit = _make_unit("hexeon", 1000, 40.0, 0.0)
	var target: Unit = _make_unit("korath", target_max_hp, 20.0, 0.0)
	target.hp = int(target_hp)
	var player_team: Array[Unit] = [hexeon]
	var enemy_team: Array[Unit] = [target]
	state.player_team = player_team
	state.enemy_team = enemy_team
	state.player_cds = [0.0]
	state.enemy_cds = [0.0]
	state.player_targets = [0]
	state.enemy_targets = [0]
	state.player_damage_this_round = [0]
	state.enemy_damage_this_round = [0]
	state.player_pupil_map = [-1]
	state.enemy_pupil_map = [-1]
	return state

func _make_unit(unit_id: String, hp_value: int, attack_damage: float, spell_power: float) -> Unit:
	var unit: Unit = Unit.new()
	unit.id = String(unit_id)
	unit.max_hp = int(hp_value)
	unit.hp = int(hp_value)
	unit.level = 1
	unit.attack_damage = float(attack_damage)
	unit.spell_power = float(spell_power)
	unit.armor = 0.0
	unit.magic_resist = 0.0
	unit.mana = 0
	unit.mana_max = 100
	return unit

func _context_tags() -> Dictionary:
	return {
		"unit_timelines": {
			"a": [
				{
					"unit_index": 0,
					"unit_id": "hexeon"
				}
			],
			"b": [
				{
					"unit_index": 0,
					"unit_id": "korath"
				}
			]
		}
	}

func _subject_record(kernel_result: Dictionary, side: String, unit_id: String) -> Dictionary:
	var combat_patterns: Dictionary = kernel_result.get("combat_patterns", {}) if (kernel_result is Dictionary) else {}
	var per_unit: Dictionary = combat_patterns.get("per_unit", {}) if (combat_patterns is Dictionary) else {}
	var side_map: Dictionary = per_unit.get(side, {}) if (per_unit is Dictionary) else {}
	var rec: Dictionary = side_map.get(unit_id, {}) if (side_map is Dictionary) else {}
	return rec if rec is Dictionary else {}

func _run_metric_result(low_case: Dictionary, high_case: Dictionary) -> Dictionary:
	var metric: Variant = ExecuteApproachTest.new()
	var payload: Dictionary = {
		"context": {
			"scenario": "threshold_sensitivity",
			"sims": {
				"low_hp_threshold": {
					"context": {
						"team_a_ids": ["hexeon"],
						"team_b_ids": ["korath"],
						"scenario_label": "low_hp_threshold"
					},
					"kernels": low_case.get("kernels", {})
				},
				"above_threshold": {
					"context": {
						"team_a_ids": ["hexeon"],
						"team_b_ids": ["korath"],
						"scenario_label": "above_threshold"
					},
					"kernels": high_case.get("kernels", {})
				}
			}
		},
		"subject_unit_ids": ["hexeon"]
	}
	return metric.call("run_metric", payload)

func _has_span_label(metric_result: Dictionary, expected_label: String) -> bool:
	var spans: Array = metric_result.get("spans", []) if (metric_result is Dictionary) else []
	for span_value in spans:
		if not (span_value is Dictionary):
			continue
		var span: Dictionary = span_value
		if String(span.get("label", "")) == expected_label:
			return true
	return false

func _quit(code: int) -> void:
	if not do_quit_on_finish:
		return
	get_tree().quit(code)
