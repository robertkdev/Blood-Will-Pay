extends Node

const GoalPrimaryTest := preload("res://tests/rga_testing/metrics/goal/goal_primary_test.gd")
const RoleCommon := preload("res://tests/rga_testing/metrics/_shared/role_common.gd")

const SUBJECT_ID: String = "brute"
const ALLY_ID: String = "bonko"
const ENEMY_ID: String = "mara"

@export var do_quit_on_finish: bool = true

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	RoleCommon.clear_identity_cache()
	var full_result: Dictionary = _run_goal("full_share", 60.0, 60.0, 35.0, 40.0, 40.0, 40.0, 0.60)
	var low_share_result: Dictionary = _run_goal("low_share_aggregate", 10.0, 40.0, 10.0, 90.0, 90.0, 90.0, 0.60)
	var weak_result: Dictionary = _run_goal("weak_frontline", 10.0, 10.0, 10.0, 90.0, 90.0, 90.0, 0.10)

	var full_pass: bool = bool(full_result.get("pass", false))
	var low_share_pass: bool = bool(low_share_result.get("pass", false))
	var weak_pass: bool = bool(weak_result.get("pass", false))
	var full_share_value: float = _span_value(full_result, "goal_frontline_absorb_damage_taken_share")
	var low_share_value: float = _span_value(low_share_result, "goal_frontline_absorb_damage_taken_share")
	var full_share_span: bool = _has_span(full_result, "goal_frontline_absorb_damage_taken_share", true)
	var low_share_diagnostic_span: bool = _has_diagnostic_span(low_share_result, "goal_frontline_absorb_damage_taken_share", "alternate_frontline_evidence_satisfied")
	var low_body_block_event_diagnostic: bool = _has_diagnostic_span(low_share_result, "goal_frontline_absorb_body_block_events", "alternate_frontline_evidence_satisfied")
	var low_body_block_damage_diagnostic: bool = _has_diagnostic_span(low_share_result, "goal_frontline_absorb_body_block_damage_prevented", "alternate_frontline_evidence_satisfied")
	var low_prevented_span: bool = _has_span(low_share_result, "goal_frontline_absorb_ally_damage_prevented", true)
	var low_frontline_span: bool = _has_span(low_share_result, "goal_frontline_absorb_frontline_zone_share", true)
	var weak_share_span: bool = _has_span(weak_result, "goal_frontline_absorb_damage_taken_share", true)

	print("BruteFrontlineShareGoalProbe: full_pass=", full_pass,
		" full_share=", full_share_value,
		" low_share_pass=", low_share_pass,
		" low_share=", low_share_value,
		" low_share_diagnostic_span=", low_share_diagnostic_span,
		" low_body_block_event_diagnostic=", low_body_block_event_diagnostic,
		" low_body_block_damage_diagnostic=", low_body_block_damage_diagnostic,
		" low_prevented_span=", low_prevented_span,
		" low_frontline_span=", low_frontline_span,
		" weak_pass=", weak_pass)

	var failed: bool = false
	if not full_pass or not full_share_span or full_share_value < 0.30:
		printerr("BruteFrontlineShareGoalProbe: FAIL Brute damage-share proof did not pass the frontline absorb goal")
		failed = true
	if not low_share_pass or not low_share_diagnostic_span:
		printerr("BruteFrontlineShareGoalProbe: FAIL aggregate low-share control did not preserve the diagnostic damage-share span")
		failed = true
	if not low_body_block_event_diagnostic or not low_body_block_damage_diagnostic:
		printerr("BruteFrontlineShareGoalProbe: FAIL aggregate low-share control did not keep absent body-block spans diagnostic")
		failed = true
	if not low_prevented_span or not low_frontline_span:
		printerr("BruteFrontlineShareGoalProbe: FAIL aggregate low-share control did not pass through prevention plus frontline presence")
		failed = true
	if weak_pass or weak_share_span:
		printerr("BruteFrontlineShareGoalProbe: FAIL weak frontline control passed")
		failed = true

	RoleCommon.clear_identity_cache()
	if failed:
		_quit(1)
		return
	print("BruteFrontlineShareGoalProbe: PASS")
	_quit(0)

func _run_goal(case_id: String, subject_incoming: float, subject_pre_mit: float, subject_post_mit: float, ally_incoming: float, ally_pre_mit: float, ally_post_mit: float, frontline_share: float) -> Dictionary:
	var metric: Variant = GoalPrimaryTest.new()
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
							"damage": subject_incoming + ally_incoming
						}
					},
					"units": {
						"a": [
							{
								"unit_id": SUBJECT_ID,
								"incoming": subject_incoming,
								"pre_mit_incoming": subject_pre_mit,
								"post_mit_incoming": subject_post_mit,
								"time_alive_s": 10.0
							},
							{
								"unit_id": ALLY_ID,
								"incoming": ally_incoming,
								"pre_mit_incoming": ally_pre_mit,
								"post_mit_incoming": ally_post_mit,
								"time_alive_s": 10.0
							}
						],
						"b": [
							{
								"unit_id": ENEMY_ID,
								"incoming": 0.0,
								"time_alive_s": 10.0
							}
						]
					},
					"outcome": {
						"time_s": 10.0
					},
					"kernels": {
						"positioning": {
							"a": {
								"frontline_zone_share": frontline_share
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

func _quit(code: int) -> void:
	if not do_quit_on_finish:
		return
	get_tree().quit(code)
