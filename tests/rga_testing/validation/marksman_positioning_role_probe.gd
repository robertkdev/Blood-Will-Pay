extends Node

const MarksmanRoleTest := preload("res://tests/rga_testing/metrics/marksman/marksman_role_identity_test.gd")

const SUBJECT_ID: String = "sari"
const UTILITY_SUBJECT_ID: String = "marble"
const DIRECT_WINDOW_SUBJECT_ID: String = "teller"
const ALLY_ID: String = "frontline_dummy"
const TARGET_ID: String = "target_dummy"

@export var do_quit_on_finish: bool = true

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var positive_metric: Dictionary = _run_metric_result(_make_positive_payload())
	var auxiliary_metric: Dictionary = _run_metric_result(_make_auxiliary_share_payload())
	var alternate_metric: Dictionary = _run_metric_result(_make_alternate_ranged_payload())
	var utility_metric: Dictionary = _run_metric_result(_make_utility_payload())
	var utility_negative_metric: Dictionary = _run_metric_result(_make_utility_negative_payload())
	var direct_window_metric: Dictionary = _run_metric_result(_make_direct_window_payload())
	var negative_metric: Dictionary = _run_metric_result(_make_negative_payload())
	var positive_pass: bool = bool(positive_metric.get("pass", false))
	var auxiliary_pass: bool = bool(auxiliary_metric.get("pass", false))
	var alternate_pass: bool = bool(alternate_metric.get("pass", false))
	var utility_pass: bool = bool(utility_metric.get("pass", false))
	var utility_negative_pass: bool = bool(utility_negative_metric.get("pass", false))
	var direct_window_pass: bool = bool(direct_window_metric.get("pass", false))
	var negative_pass: bool = bool(negative_metric.get("pass", false))
	var backline_share: float = _span_value(positive_metric, "backline_share_med_a")
	var candidate_share: float = _span_value(positive_metric, "team_share_med_a")
	var subject_share: float = _span_value(positive_metric, "subject_team_damage_share_med")
	var auxiliary_candidate_share: float = _span_value(auxiliary_metric, "team_share_med_a")
	var auxiliary_subject_share: float = _span_value(auxiliary_metric, "subject_team_damage_share_med")
	var alternate_backline_share: float = _span_value(alternate_metric, "backline_share_med_a")
	var ranged_proxy: float = _span_value(positive_metric, "subject_ranged_proxy_med")
	var time_on_target: float = _span_value(positive_metric, "subject_time_on_target_med")
	var sustained_span: bool = _has_passing_span(positive_metric, "subject_sustained_mult")
	var backline_span: bool = _has_passing_span(positive_metric, "backline_share_med_a")
	var candidate_share_span: bool = _has_passing_span(positive_metric, "team_share_med_a")
	var subject_share_span: bool = _has_passing_span(positive_metric, "subject_team_damage_share_med")
	var auxiliary_candidate_diag: bool = _has_diagnostic_span(auxiliary_metric, "team_share_med_a", "auxiliary_marksman_damage_share_not_required")
	var auxiliary_subject_diag: bool = _has_diagnostic_span(auxiliary_metric, "subject_team_damage_share_med", "auxiliary_marksman_damage_share_not_required")
	var alternate_backline_diag: bool = _has_diagnostic_span(alternate_metric, "backline_share_med_a", "alternate_marksman_ranged_evidence_satisfied")
	var utility_sustained_diag: bool = _has_diagnostic_span(utility_metric, "subject_sustained_mult", "utility_marksman_goal_variant")
	var utility_floor_span: bool = _has_passing_span(utility_metric, "subject_utility_damage_share_floor")
	var direct_window_sustained_diag: bool = _has_diagnostic_span(direct_window_metric, "subject_sustained_mult", "alternate_sustained_window_evidence_satisfied")
	var direct_window_share_span: bool = _has_passing_span(direct_window_metric, "subject_sustained_3_10s_team_share")
	var direct_window_rate_span: bool = _has_passing_span(direct_window_metric, "subject_sustained_3_10s_rate")
	var ranged_span: bool = _has_passing_span(positive_metric, "subject_ranged_proxy_med")
	var tot_span: bool = _has_passing_span(positive_metric, "subject_time_on_target_med")
	var candidate_id: String = _span_extra_string(positive_metric, "team_share_med_a", "candidate_id")

	print("MarksmanPositioningRoleProbe: positive_pass=", positive_pass,
		" backline_share=", backline_share,
		" candidate_share=", candidate_share,
		" subject_share=", subject_share,
		" auxiliary_pass=", auxiliary_pass,
		" auxiliary_candidate_share=", auxiliary_candidate_share,
		" auxiliary_subject_share=", auxiliary_subject_share,
		" auxiliary_candidate_diag=", auxiliary_candidate_diag,
		" auxiliary_subject_diag=", auxiliary_subject_diag,
		" alternate_pass=", alternate_pass,
		" alternate_backline_share=", alternate_backline_share,
		" alternate_backline_diag=", alternate_backline_diag,
		" utility_pass=", utility_pass,
		" utility_negative_pass=", utility_negative_pass,
		" direct_window_pass=", direct_window_pass,
		" ranged_proxy=", ranged_proxy,
		" time_on_target=", time_on_target,
		" candidate_id=", candidate_id,
		" negative_pass=", negative_pass)

	var failed: bool = false
	if not positive_pass:
		printerr("MarksmanPositioningRoleProbe: FAIL role_marksman_identity did not pass on sustained backline marksman evidence")
		failed = true
	if backline_share < 0.70 or ranged_proxy < 0.80 or time_on_target < 0.60:
		printerr("MarksmanPositioningRoleProbe: FAIL direct positioning/ranged evidence was below proof threshold")
		failed = true
	if candidate_share < 0.35 or subject_share < 0.35:
		printerr("MarksmanPositioningRoleProbe: FAIL auxiliary damage-share diagnostics were below proof threshold")
		failed = true
	if candidate_id != SUBJECT_ID:
		printerr("MarksmanPositioningRoleProbe: FAIL candidate team-share diagnostic did not select the marksman subject")
		failed = true
	if not sustained_span or not backline_span or not candidate_share_span or not subject_share_span or not ranged_span or not tot_span:
		printerr("MarksmanPositioningRoleProbe: FAIL role_marksman_identity did not emit all expected passing marksman spans")
		failed = true
	if not auxiliary_pass or not auxiliary_candidate_diag or not auxiliary_subject_diag:
		printerr("MarksmanPositioningRoleProbe: FAIL low damage-share rows did not stay diagnostic when sustained positioning proved marksman")
		failed = true
	if not alternate_pass or not alternate_backline_diag:
		printerr("MarksmanPositioningRoleProbe: FAIL low side backline row did not stay diagnostic when subject ranged evidence proved marksman")
		failed = true
	if not utility_pass or not utility_sustained_diag or not utility_floor_span:
		printerr("MarksmanPositioningRoleProbe: FAIL utility marksman goal did not pass through its ranged damage-floor contract")
		failed = true
	if utility_negative_pass:
		printerr("MarksmanPositioningRoleProbe: FAIL utility marksman passed without the minimum damage contribution")
		failed = true
	if not direct_window_pass or not direct_window_sustained_diag or not direct_window_share_span or not direct_window_rate_span:
		printerr("MarksmanPositioningRoleProbe: FAIL direct sustained-window evidence did not satisfy marksman throughput identity")
		failed = true
	if negative_pass:
		printerr("MarksmanPositioningRoleProbe: FAIL weak negative marksman payload passed role_marksman_identity")
		failed = true

	if failed:
		_quit(1)
		return
	print("MarksmanPositioningRoleProbe: PASS")
	_quit(0)

func _run_metric_result(payload: Dictionary) -> Dictionary:
	var metric: Variant = MarksmanRoleTest.new()
	return metric.call("run_metric", payload)

func _make_positive_payload() -> Dictionary:
	return _make_payload(45.0, 120.0, 300.0, 0.76, 0.86, 0.72, 4.2)

func _make_auxiliary_share_payload() -> Dictionary:
	return _make_payload(45.0, 45.0, 300.0, 0.76, 0.86, 0.72, 4.2)

func _make_alternate_ranged_payload() -> Dictionary:
	return _make_payload(45.0, 120.0, 300.0, 0.12, 0.86, 0.72, 4.2)

func _make_negative_payload() -> Dictionary:
	return _make_payload(12.0, 24.0, 300.0, 0.18, 0.20, 0.18, 1.4)

func _make_utility_payload() -> Dictionary:
	return _make_payload(12.0, 24.0, 300.0, 0.12, 0.86, 0.72, 4.2, UTILITY_SUBJECT_ID)

func _make_utility_negative_payload() -> Dictionary:
	return _make_payload(12.0, 6.0, 300.0, 0.12, 0.86, 0.72, 4.2, UTILITY_SUBJECT_ID)

func _make_direct_window_payload() -> Dictionary:
	var payload: Dictionary = _make_payload(12.0, 60.0, 300.0, 0.12, 0.86, 0.72, 4.2, DIRECT_WINDOW_SUBJECT_ID)
	var sims: Dictionary = (payload.get("context", {}) as Dictionary).get("sims", {})
	var probe: Dictionary = sims.get("probe", {})
	var kernels: Dictionary = probe.get("kernels", {})
	kernels["combat_patterns"] = {
		"per_unit": {
			"a": {
				DIRECT_WINDOW_SUBJECT_ID: {
					"sustained_3_10s_team_share": 0.27,
					"sustained_3_10s_rate": 30.0
				}
			},
			"b": {}
		}
	}
	probe["kernels"] = kernels
	sims["probe"] = probe
	(payload.get("context", {}) as Dictionary)["sims"] = sims
	return payload

func _make_payload(subject_rate: float, subject_damage: float, team_damage: float, backline_share: float, ranged_proxy: float, time_on_target: float, attack_distance: float, subject_id: String = SUBJECT_ID) -> Dictionary:
	var ally_damage: float = max(0.0, team_damage - subject_damage)
	return {
		"context": {
			"scenario": "neutral",
			"sims": {
				"probe": {
					"context": {
						"team_a_ids": [subject_id, ALLY_ID],
						"team_b_ids": [TARGET_ID]
					},
					"units": {
						"a": [
							{
								"unit_id": subject_id,
								"damage": subject_damage
							},
							{
								"unit_id": ALLY_ID,
								"damage": ally_damage
							}
						],
						"b": [
							{
								"unit_id": TARGET_ID,
								"damage": 42.0
							}
						]
					},
					"teams": {
						"a": {
							"damage": team_damage
						},
						"b": {
							"damage": 42.0
						}
					},
					"kernels": {
						"throughput": {
							"peers": {
								"all": [subject_rate, 10.0, 14.0, 16.0],
								"a": [subject_rate, 10.0],
								"b": [14.0, 16.0]
							},
							"peers_by_index": {
								"a": {
									0: subject_rate,
									1: 10.0
								},
								"b": {
									0: 14.0,
									1: 16.0
								}
							}
						},
						"positioning": {
							"a": {
								"backline_zone_share": backline_share,
								"observed_s": 30.0
							},
							"b": {
								"backline_zone_share": 0.12,
								"observed_s": 30.0
							}
						},
						"per_unit_kpis": {
							"a": {
								subject_id: {
									"attacks_over_2_tiles_pct": ranged_proxy,
									"time_on_target_pct": time_on_target,
									"attack_distance_median_tiles": attack_distance
								},
								ALLY_ID: {
									"attacks_over_2_tiles_pct": 0.15,
									"time_on_target_pct": 0.80,
									"attack_distance_median_tiles": 1.2
								}
							},
							"b": {
								TARGET_ID: {
									"attacks_over_2_tiles_pct": 0.10,
									"time_on_target_pct": 0.70,
									"attack_distance_median_tiles": 1.0
								}
							}
						}
					}
				}
			}
		},
		"subject_unit_ids": [subject_id]
	}

func _has_passing_span(metric_result: Dictionary, label_prefix: String) -> bool:
	var spans: Array = metric_result.get("spans", []) if (metric_result is Dictionary) else []
	for span_value in spans:
		if not (span_value is Dictionary):
			continue
		var span: Dictionary = span_value as Dictionary
		var label: String = String(span.get("label", ""))
		if label.begins_with(label_prefix) and bool(span.get("ok", false)):
			return true
	return false

func _has_diagnostic_span(metric_result: Dictionary, label_prefix: String, reason: String) -> bool:
	var spans: Array = metric_result.get("spans", []) if (metric_result is Dictionary) else []
	for span_value in spans:
		if not (span_value is Dictionary):
			continue
		var span: Dictionary = span_value as Dictionary
		var label: String = String(span.get("label", ""))
		if label.begins_with(label_prefix) and not span.has("ok") and String(span.get("reason", "")) == reason:
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

func _span_extra_string(metric_result: Dictionary, label_prefix: String, key: String) -> String:
	var spans: Array = metric_result.get("spans", []) if (metric_result is Dictionary) else []
	for span_value in spans:
		if not (span_value is Dictionary):
			continue
		var span: Dictionary = span_value as Dictionary
		var label: String = String(span.get("label", ""))
		if label.begins_with(label_prefix):
			return String(span.get(key, ""))
	return ""

func _quit(code: int) -> void:
	if not do_quit_on_finish:
		return
	get_tree().quit(code)
