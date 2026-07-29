extends Node

const GoalPrimaryTest := preload("res://tests/rga_testing/metrics/goal/goal_primary_test.gd")
const RoleCommon := preload("res://tests/rga_testing/metrics/_shared/role_common.gd")

const SUBJECT_ID: String = "grint"
const ALLY_ID: String = "brute"
const ENEMY_ID: String = "mara"

@export var do_quit_on_finish: bool = true

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	RoleCommon.clear_identity_cache()
	var full_result: Dictionary = _run_goal("full_engage_success", 1.4, 2.0, 2.0)
	var low_success_result: Dictionary = _run_goal("low_success_aggregate", 1.4, 4.0, 1.0)
	var weak_result: Dictionary = _run_goal("weak_initiate", 0.2, 7.5, 0.0)

	var full_pass: bool = bool(full_result.get("pass", false))
	var low_success_pass: bool = bool(low_success_result.get("pass", false))
	var weak_pass: bool = bool(weak_result.get("pass", false))
	var full_success_value: float = _span_value(full_result, "goal_initiate_fight_engage_success_targets")
	var low_success_value: float = _span_value(low_success_result, "goal_initiate_fight_engage_success_targets")
	var full_success_span: bool = _has_span(full_result, "goal_initiate_fight_engage_success_targets", true)
	var low_success_diagnostic_span: bool = _has_diagnostic_span(low_success_result, "goal_initiate_fight_engage_success_targets", "alternate_initiate_evidence_satisfied")
	var low_distance_span: bool = _has_span(low_success_result, "goal_initiate_fight_engage_distance", true)
	var low_first_action_span: bool = _has_span(low_success_result, "goal_initiate_fight_first_action_s", true)
	var weak_success_span: bool = _has_span(weak_result, "goal_initiate_fight_engage_success_targets", true)

	print("GrintEngageSuccessGoalProbe: full_pass=", full_pass,
		" full_success=", full_success_value,
		" low_success_pass=", low_success_pass,
		" low_success=", low_success_value,
		" low_success_diagnostic_span=", low_success_diagnostic_span,
		" low_distance_span=", low_distance_span,
		" low_first_action_span=", low_first_action_span,
		" weak_pass=", weak_pass)

	var failed: bool = false
	if not full_pass or not full_success_span or full_success_value < 2.0:
		printerr("GrintEngageSuccessGoalProbe: FAIL Grint full engage-success proof did not pass")
		failed = true
	if not low_success_pass or not low_success_diagnostic_span:
		printerr("GrintEngageSuccessGoalProbe: FAIL aggregate low-success control did not keep the success-target span diagnostic")
		failed = true
	if not low_distance_span or not low_first_action_span:
		printerr("GrintEngageSuccessGoalProbe: FAIL aggregate low-success control did not pass through distance and first-action evidence")
		failed = true
	if weak_pass or weak_success_span:
		printerr("GrintEngageSuccessGoalProbe: FAIL weak initiate control passed")
		failed = true

	RoleCommon.clear_identity_cache()
	if failed:
		_quit(1)
		return
	print("GrintEngageSuccessGoalProbe: PASS")
	_quit(0)

func _run_goal(case_id: String, engage_distance: float, first_action_s: float, success_targets: float) -> Dictionary:
	var metric: Variant = GoalPrimaryTest.new()
	var control_rec: Dictionary = {
		"early_max_displacement_tiles": engage_distance,
		"first_action_s": first_action_s,
		"cc_unique_targets": success_targets,
		"cc_events": int(success_targets),
		"cc_seconds": success_targets
	}
	var control_per_unit_a: Dictionary = {}
	control_per_unit_a[SUBJECT_ID] = control_rec
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
							"damage": 20.0
						},
						"b": {
							"damage": 20.0
						}
					},
					"units": {
						"a": [
							{
								"unit_id": SUBJECT_ID,
								"damage": 10.0,
								"incoming": 10.0,
								"time_alive_s": 10.0
							},
							{
								"unit_id": ALLY_ID,
								"damage": 10.0,
								"incoming": 10.0,
								"time_alive_s": 10.0
							}
						],
						"b": [
							{
								"unit_id": ENEMY_ID,
								"damage": 20.0,
								"incoming": 20.0,
								"time_alive_s": 10.0
							}
						]
					},
					"outcome": {
						"time_s": 10.0
					},
					"kernels": {
						"control_mobility": {
							"per_unit": {
								"a": control_per_unit_a
							}
						}
					}
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

func _span_value(metric_result: Dictionary, label_prefix: String) -> float:
	var spans: Array = metric_result.get("spans", []) if (metric_result is Dictionary) else []
	for span_value in spans:
		if not (span_value is Dictionary):
			continue
		var span: Dictionary = span_value as Dictionary
		var label: String = String(span.get("label", ""))
		if label.begins_with(label_prefix):
			return float(span.get("value", 0.0))
	return 0.0

func _has_diagnostic_span(metric_result: Dictionary, label_prefix: String, expected_reason: String) -> bool:
	var spans: Array = metric_result.get("spans", []) if (metric_result is Dictionary) else []
	for span_value in spans:
		if not (span_value is Dictionary):
			continue
		var span: Dictionary = span_value as Dictionary
		var label: String = String(span.get("label", ""))
		if label.begins_with(label_prefix) and not span.has("ok") and String(span.get("reason", "")) == expected_reason:
			return true
	return false

func _quit(code: int) -> void:
	if not do_quit_on_finish:
		return
	get_tree().quit(code)
