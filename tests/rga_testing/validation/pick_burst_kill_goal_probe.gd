extends Node

const CombatEngineScript := preload("res://scripts/game/combat/combat_engine.gd")
const BattleStateScript := preload("res://scripts/game/combat/battle_state.gd")
const CombatPatternKernel := preload("res://tests/rga_testing/aggregators/kernels/combat_pattern_kernel.gd")
const GoalPrimaryTest := preload("res://tests/rga_testing/metrics/goal/goal_primary_test.gd")

const SUBJECT_ID: String = "mara"
const TARGET_ID: String = "target_dummy"

@export var do_quit_on_finish: bool = true

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var lethal_result: Dictionary = _run_case("lethal_pick", [50, 50], [70, 20, 0], [0.50, 0.20])
	var nonlethal_result: Dictionary = _run_case("nonlethal_pick", [40, 40], [120, 80, 40], [0.50, 0.20])
	var diffuse_result: Dictionary = _run_case("diffuse_control", [12, 12], [120, 108, 96], [0.10, 1.10])

	var lethal_rec: Dictionary = lethal_result.get("rec", {})
	var lethal_goal: Dictionary = lethal_result.get("goal", {})
	var nonlethal_goal: Dictionary = nonlethal_result.get("goal", {})
	var diffuse_goal: Dictionary = diffuse_result.get("goal", {})
	var lethal_pass: bool = bool(lethal_goal.get("pass", false))
	var nonlethal_pass: bool = bool(nonlethal_goal.get("pass", false))
	var diffuse_pass: bool = bool(diffuse_goal.get("pass", false))
	var lethal_kills: int = int(lethal_rec.get("kill_count", 0))
	var lethal_peak_dps: float = float(lethal_rec.get("peak_1s_dps", 0.0))
	var lethal_counterplay_ms: float = float(lethal_rec.get("counterplay_window_ms", -1.0))
	var lethal_kill_span: bool = _has_span(lethal_goal, "goal_pick_burst_kill_count", true)
	var nonlethal_kill_span: bool = _has_span(nonlethal_goal, "goal_pick_burst_kill_count", true)
	var diffuse_kill_span: bool = _has_span(diffuse_goal, "goal_pick_burst_kill_count", true)

	print("PickBurstKillGoalProbe: lethal_pass=", lethal_pass,
		" lethal_kills=", lethal_kills,
		" lethal_peak_dps=", lethal_peak_dps,
		" lethal_counterplay_ms=", lethal_counterplay_ms,
		" lethal_kill_span=", lethal_kill_span,
		" nonlethal_pass=", nonlethal_pass,
		" nonlethal_kill_span=", nonlethal_kill_span,
		" diffuse_pass=", diffuse_pass,
		" diffuse_kill_span=", diffuse_kill_span)

	var failed: bool = false
	if not lethal_pass:
		printerr("PickBurstKillGoalProbe: FAIL lethal pick-burst telemetry did not pass the real Mara goal")
		failed = true
	if lethal_kills != 1 or not lethal_kill_span:
		printerr("PickBurstKillGoalProbe: FAIL lethal combat telemetry did not emit a passing kill-count span")
		failed = true
	if lethal_peak_dps < 35.0 or lethal_counterplay_ms < 400.0:
		printerr("PickBurstKillGoalProbe: FAIL lethal case did not preserve burst DPS and counterplay-window proof")
		failed = true
	if not nonlethal_pass:
		printerr("PickBurstKillGoalProbe: FAIL nonlethal aggregate pick-burst path should still pass by DPS plus counterplay")
		failed = true
	if nonlethal_kill_span:
		printerr("PickBurstKillGoalProbe: FAIL nonlethal control emitted a passing kill-count span")
		failed = true
	if diffuse_pass or diffuse_kill_span:
		printerr("PickBurstKillGoalProbe: FAIL diffuse control passed the goal or kill-count span")
		failed = true

	if failed:
		_quit(1)
		return
	print("PickBurstKillGoalProbe: PASS")
	_quit(0)

func _run_case(case_id: String, damages: Array[int], hp_values: Array[int], deltas: Array[float]) -> Dictionary:
	var engine: CombatEngine = CombatEngineScript.new()
	var state: BattleState = _make_state(int(hp_values[0]))
	engine.state = state
	var kernel: Variant = CombatPatternKernel.new()
	var team_sizes: Dictionary = {"a": 1, "b": 1}
	var context_tags: Dictionary = {
		"unit_timelines": {
			"a": [
				{
					"unit_index": 0,
					"unit_id": SUBJECT_ID
				}
			],
			"b": [
				{
					"unit_index": 0,
					"unit_id": TARGET_ID
				}
			]
		}
	}
	kernel.call("attach", engine, team_sizes, context_tags, true)
	engine.emit_signal("ability_cast", "player", 0, "enemy", 0, Vector2.ZERO)
	for i in range(damages.size()):
		kernel.call("tick", deltas[i])
		engine.emit_signal("hit_applied", "player", 0, 0, damages[i], damages[i], false, hp_values[i], hp_values[i + 1], 0.0, 0.0)
	kernel.call("finalize", 3.0)

	var result: Dictionary = kernel.call("result")
	var combat_patterns: Dictionary = result.get("combat_patterns", {}) if (result is Dictionary) else {}
	var per_unit: Dictionary = combat_patterns.get("per_unit", {}) if (combat_patterns is Dictionary) else {}
	var side_a: Dictionary = per_unit.get("a", {}) if (per_unit is Dictionary) else {}
	var rec: Dictionary = side_a.get(SUBJECT_ID, {}) if (side_a is Dictionary) else {}
	var goal_result: Dictionary = _run_goal(case_id, result, float(rec.get("total_damage", 0.0)))
	kernel.call("detach")
	return {
		"rec": rec,
		"goal": goal_result
	}

func _make_state(target_hp: int) -> BattleState:
	var state: BattleState = BattleStateScript.new()
	var attacker: Unit = Unit.new()
	attacker.id = SUBJECT_ID
	attacker.max_hp = 1000
	attacker.hp = 1000
	var target: Unit = Unit.new()
	target.id = TARGET_ID
	target.max_hp = target_hp
	target.hp = target_hp
	var player_team: Array[Unit] = [attacker]
	var enemy_team: Array[Unit] = [target]
	state.player_team = player_team
	state.enemy_team = enemy_team
	return state

func _run_goal(case_id: String, kernel_result: Dictionary, subject_damage: float) -> Dictionary:
	var metric: Variant = GoalPrimaryTest.new()
	var payload: Dictionary = {
		"context": {
			"scenario": "burst",
			"sims": {
				case_id: {
					"context": {
						"team_a_ids": [SUBJECT_ID],
						"team_b_ids": [TARGET_ID]
					},
					"teams": {
						"a": {
							"damage": subject_damage
						},
						"b": {
							"damage": 0.0
						}
					},
					"units": {
						"a": [
							{
								"unit_id": SUBJECT_ID,
								"damage": subject_damage,
								"incoming": 0.0,
								"time_alive_s": 3.0
							}
						],
						"b": [
							{
								"unit_id": TARGET_ID,
								"damage": 0.0
							}
						]
					},
					"outcome": {
						"time_s": 3.0
					},
					"kernels": kernel_result
				}
			}
		},
		"subject_unit_ids": [SUBJECT_ID]
	}
	return metric.call("run_metric", payload)

func _has_span(metric_result: Dictionary, label_prefix: String, required_ok: bool) -> bool:
	var spans: Array = metric_result.get("spans", []) if (metric_result is Dictionary) else []
	for span_value in spans:
		if not (span_value is Dictionary):
			continue
		var span: Dictionary = span_value as Dictionary
		var label: String = String(span.get("label", ""))
		if label.begins_with(label_prefix) and bool(span.get("ok", false)) == required_ok:
			return true
	return false

func _quit(code: int) -> void:
	if not do_quit_on_finish:
		return
	get_tree().quit(code)
