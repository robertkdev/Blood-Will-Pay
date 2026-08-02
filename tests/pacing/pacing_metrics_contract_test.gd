extends Node

const PacingMetrics: Script = preload("res://tests/pacing/pacing_metrics.gd")

var _failures: Array[String] = []

func _ready() -> void:
	var normal_report: Dictionary[String, Variant] = _make_report(
		"controlled_normal",
		[4.0, 6.0, 5.0, 8.0, 4.0],
		[8.0, 10.0, 6.0, 4.0, 7.0],
		[8.0, 12.0, 20.0, 30.0, 10.0],
		[2.0, 2.5, 3.0, 3.0, 2.0],
		[1.0, 1.5, 2.0, 2.5, 1.0],
		[4.0, 3.0, 5.0, 6.0, 4.0],
		{"time_to_first_decision_seconds": 3.0, "onboarding_to_first_combat_seconds": 8.0, "max_dead_time_seconds": 2.0, "boss_intervals": [5.0], "boss_count": 1, "loss_retry_recovery_seconds": [4.0], "target_stage": 5, "highest_stage": 5, "reached_target": true, "skip_response_supported": false, "terminal": "target_reached"}
	)
	var fast_report: Dictionary[String, Variant] = _make_report(
		"controlled_known_fast",
		[0.25, 0.25, 0.25, 0.25, 0.25],
		[60.0, 60.0, 60.0, 60.0, 60.0],
		[0.2, 0.2, 0.2, 0.2, 0.2],
		[0.2, 0.2, 0.2, 0.2, 0.2],
		[0.0, 0.0, 0.0, 0.0, 0.0],
		[0.2, 0.2, 0.2, 0.2, 0.2],
		{"time_to_first_decision_seconds": 0.2, "onboarding_to_first_combat_seconds": 0.4, "max_dead_time_seconds": 0.0, "boss_intervals": [5.0], "boss_count": 1, "loss_retry_recovery_seconds": [1.0], "target_stage": 5, "highest_stage": 5, "reached_target": true, "skip_response_supported": false, "terminal": "target_reached"}
	)
	var slow_report: Dictionary[String, Variant] = _make_report(
		"controlled_known_slow",
		[75.0, 75.0, 75.0, 75.0, 75.0],
		[0.5, 0.5, 0.5, 0.5, 0.5],
		[65.0, 65.0, 65.0, 65.0, 65.0],
		[12.0, 12.0, 12.0, 12.0, 12.0],
		[6.0, 6.0, 6.0, 6.0, 6.0],
		[70.0, 70.0, 70.0, 70.0, 70.0],
		{"time_to_first_decision_seconds": 60.0, "onboarding_to_first_combat_seconds": 100.0, "max_dead_time_seconds": 20.0, "boss_intervals": [5.0], "boss_count": 1, "loss_retry_recovery_seconds": [40.0], "target_stage": 5, "highest_stage": 5, "reached_target": true, "skip_response_supported": false, "terminal": "target_reached"}
	)
	var normal_result: Dictionary[String, Variant] = PacingMetrics.analyze(normal_report)
	var fast_result: Dictionary[String, Variant] = PacingMetrics.analyze(fast_report)
	var slow_result: Dictionary[String, Variant] = PacingMetrics.analyze(slow_report)
	_expect(String(normal_result.get("verdict", "FAIL")) == "PASS", "normal rhythm should pass")
	_expect(String(fast_result.get("verdict", "PASS")) == "FAIL", "known-fast rhythm should fail")
	_expect(String(slow_result.get("verdict", "PASS")) == "FAIL", "known-slow rhythm should fail")
	_expect(_has_failure(fast_result, "planning_time_use_seconds:too_fast"), "known-fast planning should fail as too_fast")
	_expect(_has_failure(fast_result, "combat_duration_seconds:too_fast"), "known-fast combat should fail as too_fast")
	_expect(_has_failure(slow_result, "planning_time_use_seconds:too_slow"), "known-slow planning should fail as too_slow")
	_expect(_has_failure(slow_result, "combat_duration_seconds:too_slow"), "known-slow combat should fail as too_slow")
	var suite: Dictionary[String, Variant] = {"runs": [normal_report, fast_report, slow_report]}
	var suite_result: Dictionary[String, Variant] = PacingMetrics.analyze_suite(suite)
	_expect(String(suite_result.get("verdict", "PASS")) == "FAIL", "mixed suite should fail when a controlled case fails")
	print("PacingMetricsContractTest: normal=%s fast=%s slow=%s suite=%s" % [normal_result.get("verdict"), fast_result.get("verdict"), slow_result.get("verdict"), suite_result.get("verdict")])
	for failure: String in _failures:
		push_error("PacingMetricsContractTest: " + failure)
	await get_tree().create_timer(1.0).timeout
	get_tree().quit(1 if not _failures.is_empty() else 0)

func _make_report(sample_id: String, planning: Array[float], action_density: Array[float], combat: Array[float], result_dwell: Array[float], recovery: Array[float], shop: Array[float], run: Dictionary[String, Variant]) -> Dictionary[String, Variant]:
	var stages: Array[Dictionary] = []
	for index: int in range(planning.size()):
		stages.append({
			"global_stage": index + 1,
			"chapter": 1,
			"round": index + 1,
			"kind": "BOSS" if index + 1 == 4 else "NORMAL",
			"is_boss": index + 1 == 4,
			"events": [],
			"metrics": {
				"planning_time_use_seconds": planning[index],
				"action_density_per_planning_minute": action_density[index],
				"combat_duration_seconds": combat[index],
				"result_dwell_seconds": result_dwell[index],
				"recovery_seconds": recovery[index],
				"shop_decision_seconds": shop[index],
			},
		})
	return {
		"schema_version": PacingMetrics.SCHEMA_VERSION,
		"sample": {"id": sample_id},
		"run": run,
		"stages": stages,
	}

func _has_failure(result: Dictionary[String, Variant], expected: String) -> bool:
	var failures_value: Variant = result.get("failures", [])
	if not failures_value is Array:
		return false
	for failure: Variant in failures_value as Array:
		if String(failure) == expected:
			return true
	return false

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
