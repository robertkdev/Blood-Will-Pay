extends Node

const CombatEngineScript := preload("res://scripts/game/combat/combat_engine.gd")
const BuffPresenceKernel := preload("res://tests/rga_testing/aggregators/kernels/buff_presence_kernel.gd")
const GoalPrimaryTest := preload("res://tests/rga_testing/metrics/goal/goal_primary_test.gd")

const SUBJECT_ID: String = "kythera"
const ALLY_ID: String = "bonko"
const ENEMY_ID: String = "mara"

@export var do_quit_on_finish: bool = true

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var full_result: Dictionary = _run_case("full_fortification", true, 40.0, 10.0)
	var self_result: Dictionary = _run_case("self_fortification", true, 40.0, 10.0, 0)
	var no_buff_result: Dictionary = _run_case("no_buff_aggregate", false, 40.0, 10.0)
	var buff_only_result: Dictionary = _run_case("buff_only", true, 0.0, 0.0)
	var weak_result: Dictionary = _run_case("weak_fortification", false, 0.0, 0.0)

	var full_rec: Dictionary = full_result.get("rec", {})
	var self_rec: Dictionary = self_result.get("rec", {})
	var full_goal: Dictionary = full_result.get("goal", {})
	var self_goal: Dictionary = self_result.get("goal", {})
	var no_buff_goal: Dictionary = no_buff_result.get("goal", {})
	var buff_only_goal: Dictionary = buff_only_result.get("goal", {})
	var weak_goal: Dictionary = weak_result.get("goal", {})
	var full_pass: bool = bool(full_goal.get("pass", false))
	var self_pass: bool = bool(self_goal.get("pass", false))
	var no_buff_pass: bool = bool(no_buff_goal.get("pass", false))
	var buff_only_pass: bool = bool(buff_only_goal.get("pass", false))
	var weak_pass: bool = bool(weak_goal.get("pass", false))
	var ally_buffs: int = int(full_rec.get("ally_buffs_to_others", 0))
	var self_buffs: int = int(self_rec.get("ally_buffs", 0))
	var self_buffs_to_others: int = int(self_rec.get("ally_buffs_to_others", 0))
	var full_buff_span: bool = _has_span(full_goal, "goal_team_fortification_buff_uptime_targets", true)
	var self_buff_span: bool = _has_span(self_goal, "goal_team_fortification_buff_uptime_targets", true)
	var no_buff_false_span: bool = _has_span(no_buff_goal, "goal_team_fortification_buff_uptime_targets", false)
	var no_buff_prevention_span: bool = _has_span(no_buff_goal, "goal_team_fortification_damage_prevented_per_s", true)
	var buff_only_buff_span: bool = _has_span(buff_only_goal, "goal_team_fortification_buff_uptime_targets", true)
	var weak_buff_span: bool = _has_span(weak_goal, "goal_team_fortification_buff_uptime_targets", true)

	print("TeamFortificationBuffGoalProbe: full_pass=", full_pass,
		" ally_buffs=", ally_buffs,
		" full_buff_span=", full_buff_span,
		" self_pass=", self_pass,
		" self_buffs=", self_buffs,
		" self_buffs_to_others=", self_buffs_to_others,
		" self_buff_span=", self_buff_span,
		" no_buff_pass=", no_buff_pass,
		" no_buff_false_span=", no_buff_false_span,
		" no_buff_prevention_span=", no_buff_prevention_span,
		" buff_only_pass=", buff_only_pass,
		" buff_only_buff_span=", buff_only_buff_span,
		" weak_pass=", weak_pass)

	var failed: bool = false
	if not full_pass or ally_buffs != 1 or not full_buff_span:
		printerr("TeamFortificationBuffGoalProbe: FAIL full fortification telemetry did not pass with a direct ally-buff span")
		failed = true
	if not self_pass or self_buffs != 1 or self_buffs_to_others != 0 or not self_buff_span:
		printerr("TeamFortificationBuffGoalProbe: FAIL self fortification telemetry did not pass with a source-owned same-team buff span")
		failed = true
	if not no_buff_pass:
		printerr("TeamFortificationBuffGoalProbe: FAIL no-buff aggregate fortification path should pass through EHP and prevention")
		failed = true
	if not no_buff_false_span or not no_buff_prevention_span:
		printerr("TeamFortificationBuffGoalProbe: FAIL no-buff aggregate path did not preserve the failed buff span and passed prevention span")
		failed = true
	if buff_only_pass or not buff_only_buff_span:
		printerr("TeamFortificationBuffGoalProbe: FAIL buff-only control should expose the buff span without passing the whole goal")
		failed = true
	if weak_pass or weak_buff_span:
		printerr("TeamFortificationBuffGoalProbe: FAIL weak control passed or emitted a direct buff span")
		failed = true

	if failed:
		_quit(1)
		return
	print("TeamFortificationBuffGoalProbe: PASS")
	_quit(0)

func _run_case(case_id: String, emit_buff: bool, pre_mit_incoming: float, post_mit_incoming: float, buff_target_index: int = 1) -> Dictionary:
	var engine: CombatEngine = CombatEngineScript.new()
	var kernel: Variant = BuffPresenceKernel.new()
	var team_sizes: Dictionary = {"a": 2, "b": 1}
	var context_tags: Dictionary = {
		"unit_timelines": {
			"a": [
				{
					"unit_index": 0,
					"unit_id": SUBJECT_ID
				},
				{
					"unit_index": 1,
					"unit_id": ALLY_ID
				}
			],
			"b": [
				{
					"unit_index": 0,
					"unit_id": ENEMY_ID
				}
			]
		}
	}
	kernel.call("attach", engine, team_sizes, context_tags, true)
	if emit_buff:
		engine.emit_signal("buff_applied", "player", 0, "player", int(buff_target_index), "fortify", {"armor": 12}, 12.0, 5.0)
	kernel.call("finalize", 2.0)

	var result: Dictionary = kernel.call("result")
	var buff_presence: Dictionary = result.get("buff_presence", {}) if (result is Dictionary) else {}
	var per_unit: Dictionary = buff_presence.get("per_unit", {}) if (buff_presence is Dictionary) else {}
	var side_a: Dictionary = per_unit.get("a", {}) if (per_unit is Dictionary) else {}
	var rec: Dictionary = side_a.get(SUBJECT_ID, {}) if (side_a is Dictionary) else {}
	var goal_result: Dictionary = _run_goal(case_id, result, pre_mit_incoming, post_mit_incoming)
	kernel.call("detach")
	return {
		"rec": rec,
		"goal": goal_result
	}

func _run_goal(case_id: String, kernel_result: Dictionary, pre_mit_incoming: float, post_mit_incoming: float) -> Dictionary:
	var metric: Variant = GoalPrimaryTest.new()
	var incoming: float = max(pre_mit_incoming, post_mit_incoming)
	var payload: Dictionary = {
		"context": {
			"scenario": "neutral",
			"sims": {
				case_id: {
					"context": {
						"team_a_ids": [SUBJECT_ID, ALLY_ID],
						"team_b_ids": [ENEMY_ID]
					},
					"teams": {
						"a": {
							"damage": 0.0
						},
						"b": {
							"damage": 0.0
						}
					},
					"units": {
						"a": [
							{
								"unit_id": SUBJECT_ID,
								"incoming": incoming,
								"pre_mit_incoming": pre_mit_incoming,
								"post_mit_incoming": post_mit_incoming,
								"time_alive_s": 10.0
							},
							{
								"unit_id": ALLY_ID,
								"incoming": 0.0,
								"time_alive_s": 10.0
							}
						],
						"b": [
							{
								"unit_id": ENEMY_ID,
								"incoming": 0.0
							}
						]
					},
					"outcome": {
						"time_s": 10.0
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
