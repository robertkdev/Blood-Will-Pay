extends RefCounted

## Pure pacing metric and verdict helpers shared by the longitudinal harness and
## its controlled fast/slow contract test. The input is deliberately JSON-shaped
## so reports can be inspected or analyzed outside Godot without replaying a run.

const SCHEMA_VERSION: String = "gamble-battle.pacing.v1"

static func thresholds() -> Dictionary[String, Variant]:
	return {
		"time_to_first_decision_seconds": {"min": 1.0, "max": 45.0, "unit": "seconds", "basis": "run"},
		"onboarding_to_first_combat_seconds": {"min": 1.0, "max": 75.0, "unit": "seconds", "basis": "run"},
		"planning_time_use_seconds": {"min": 1.0, "max": 60.0, "unit": "seconds", "basis": "p50/p90"},
		"action_density_per_planning_minute": {"min": 1.0, "max": 30.0, "unit": "actions_per_minute", "basis": "p50"},
		"combat_duration_seconds": {"min": 0.75, "max": 50.0, "boss_max": 90.0, "unit": "seconds", "basis": "p50/p90"},
		"result_dwell_seconds": {"min": 1.0, "max": 8.0, "unit": "seconds", "basis": "p50/p90"},
		"recovery_seconds": {"min": 0.0, "max": 5.0, "unit": "seconds", "basis": "p50/p90"},
		"shop_decision_seconds": {"min": 1.0, "max": 45.0, "unit": "seconds", "basis": "p50/p90"},
		"max_dead_time_seconds": {"min": 0.0, "max": 8.0, "unit": "seconds", "basis": "maximum"},
		"boss_interval_stages": {"min": 4.0, "max": 6.0, "unit": "stages", "basis": "p50"},
		"loss_retry_recovery_seconds": {"min": 0.0, "max": 30.0, "unit": "seconds", "basis": "maximum"},
		"run_length_stages": {"min": 5.0, "max": 1000.0, "unit": "stages", "basis": "target"},
	}

static func analyze(report: Dictionary[String, Variant]) -> Dictionary[String, Variant]:
	var stages: Array[Dictionary] = _dictionary_array(report.get("stages", []))
	var run: Dictionary[String, Variant] = _dictionary_value(report.get("run", {}))
	var sample: Dictionary[String, Variant] = _dictionary_value(report.get("sample", {}))
	var scope: String = String(run.get("scope", sample.get("scope", "campaign")))
	var threshold_map: Dictionary[String, Variant] = thresholds()
	var metric_results: Dictionary[String, Variant] = {}

	var first_decision: float = float(run.get("time_to_first_decision_seconds", -1.0))
	metric_results["time_to_first_decision_seconds"] = _check_scalar(first_decision, _threshold(threshold_map, "time_to_first_decision_seconds"))
	var first_combat: float = float(run.get("onboarding_to_first_combat_seconds", -1.0))
	metric_results["onboarding_to_first_combat_seconds"] = _check_scalar(first_combat, _threshold(threshold_map, "onboarding_to_first_combat_seconds"))

	var planning_values: Array[float] = _stage_metric_values(stages, "planning_time_use_seconds")
	metric_results["planning_time_use_seconds"] = _not_applicable("loss/retry sample begins at the forced terminal fight and does not include a planning beat") if scope == "loss_retry" else _check_distribution(planning_values, _threshold(threshold_map, "planning_time_use_seconds"))
	var action_density_values: Array[float] = _stage_metric_values(stages, "action_density_per_planning_minute")
	metric_results["action_density_per_planning_minute"] = _not_applicable("loss/retry sample intentionally contains no shop/deployment action sequence") if scope == "loss_retry" else _check_distribution_at(action_density_values, _threshold(threshold_map, "action_density_per_planning_minute"), "p50")
	var combat_values: Array[float] = _stage_metric_values(stages, "combat_duration_seconds")
	metric_results["combat_duration_seconds"] = _check_combat_distribution(stages, combat_values, _threshold(threshold_map, "combat_duration_seconds"))
	var result_values: Array[float] = _stage_metric_values(stages, "result_dwell_seconds")
	metric_results["result_dwell_seconds"] = _check_distribution(result_values, _threshold(threshold_map, "result_dwell_seconds"))
	var recovery_values: Array[float] = _stage_metric_values(stages, "recovery_seconds")
	metric_results["recovery_seconds"] = _not_applicable("loss/retry sample uses the explicit retry recovery metric") if scope == "loss_retry" else _check_distribution(recovery_values, _threshold(threshold_map, "recovery_seconds"))
	var shop_values: Array[float] = _stage_metric_values(stages, "shop_decision_seconds")
	metric_results["shop_decision_seconds"] = _not_applicable("no shop was part of this scoped sample") if scope == "loss_retry" else _check_distribution(shop_values, _threshold(threshold_map, "shop_decision_seconds"))

	var dead_time: float = float(run.get("max_dead_time_seconds", -1.0))
	metric_results["max_dead_time_seconds"] = _check_scalar(dead_time, _threshold(threshold_map, "max_dead_time_seconds"), false)
	var boss_intervals: Array[float] = _float_array(run.get("boss_intervals", []))
	metric_results["boss_interval_stages"] = _not_applicable("boss cadence requires a campaign-span sample") if scope != "campaign" else _check_distribution(boss_intervals, _threshold(threshold_map, "boss_interval_stages"), false)
	var retry_values: Array[float] = _float_array(run.get("loss_retry_recovery_seconds", []))
	metric_results["loss_retry_recovery_seconds"] = _check_scalar_max(retry_values, _threshold(threshold_map, "loss_retry_recovery_seconds"))

	var target_stage: int = int(run.get("target_stage", 0))
	var highest_stage: int = int(run.get("highest_stage", 0))
	var reached_target: bool = bool(run.get("reached_target", false))
	metric_results["run_length_stages"] = _not_applicable("run length requires a campaign-span sample") if scope != "campaign" else _check_run_length(highest_stage, target_stage, reached_target, _threshold(threshold_map, "run_length_stages"))

	var skip_supported: bool = bool(run.get("skip_response_supported", false))
	metric_results["result_skip_response"] = {
		"status": "N/A" if not skip_supported else "PASS",
		"supported": skip_supported,
		"response_seconds": run.get("skip_response_seconds", null),
		"note": "Result-skip latency is outside the longitudinal sample and is covered by InteractionLatencySmoke.tscn." if not skip_supported else "Result skip response was observed.",
	}

	var failures: Array[String] = []
	for metric_name: String in metric_results.keys():
		var metric: Dictionary[String, Variant] = _dictionary_value(metric_results[metric_name])
		if String(metric.get("status", "FAIL")) == "FAIL":
			failures.append(metric_name + ":" + String(metric.get("reason", "failed")))
	var verdict: String = "PASS" if failures.is_empty() else "FAIL"
	return {
		"schema_version": SCHEMA_VERSION,
		"verdict": verdict,
		"failures": failures,
		"thresholds": threshold_map,
		"metrics": metric_results,
		"stage_count": stages.size(),
		"boss_count": int(run.get("boss_count", 0)),
		"highest_stage": highest_stage,
		"reached_target": reached_target,
	}

static func analyze_suite(suite: Dictionary[String, Variant]) -> Dictionary[String, Variant]:
	var runs: Array[Dictionary] = _dictionary_array(suite.get("runs", []))
	var run_results: Array[Dictionary] = []
	var failures: Array[String] = []
	for run: Dictionary in runs:
		var result: Dictionary[String, Variant] = analyze(run)
		run_results.append(result)
		if String(result.get("verdict", "FAIL")) == "FAIL":
			var run_id: String = String(_dictionary_value(run.get("sample", {})).get("id", "run"))
			for failure: String in _string_array(result.get("failures", [])):
				failures.append(run_id + ":" + failure)
	var verdict: String = "PASS" if failures.is_empty() else "FAIL"
	return {
		"schema_version": SCHEMA_VERSION,
		"verdict": verdict,
		"failures": failures,
		"runs": run_results,
		"run_count": runs.size(),
	}

static func render_markdown(suite: Dictionary[String, Variant], analysis: Dictionary[String, Variant]) -> String:
	var lines: Array[String] = []
	var threshold_map: Dictionary[String, Variant] = thresholds()
	lines.append("# Gamble Battle Longitudinal Pacing Report")
	lines.append("")
	lines.append("- Schema: `%s`" % SCHEMA_VERSION)
	lines.append("- Verdict: **%s**" % str(analysis.get("verdict", "FAIL")))
	lines.append("- Runs: %d" % int(analysis.get("run_count", 0)))
	lines.append("")
	lines.append("## Run results")
	lines.append("")
	lines.append("| Run | Verdict | Stages | Highest | Target reached |")
	lines.append("| --- | --- | ---: | ---: | --- |")
	var runs: Array[Dictionary] = _dictionary_array(suite.get("runs", []))
	var results: Array[Dictionary] = _dictionary_array(analysis.get("runs", []))
	for index: int in range(runs.size()):
		var run: Dictionary[String, Variant] = runs[index]
		var result: Dictionary[String, Variant] = results[index] if index < results.size() else {}
		var sample: Dictionary[String, Variant] = _dictionary_value(run.get("sample", {}))
		var run_data: Dictionary[String, Variant] = _dictionary_value(run.get("run", {}))
		lines.append("| %s | %s | %d | %d | %s |" % [
			str(sample.get("id", "run")),
			str(result.get("verdict", "FAIL")),
			int(result.get("stage_count", 0)),
			int(result.get("highest_stage", 0)),
			str(bool(result.get("reached_target", false))),
		])
		if not _string_array(result.get("failures", [])).is_empty():
			lines.append("")
			lines.append("Failures: `%s`" % "; ".join(_string_array(result.get("failures", []))))
		var terminal: String = str(run_data.get("terminal", ""))
		if terminal != "":
			lines.append("Terminal: `%s`" % terminal)
	lines.append("")
	lines.append("## Per-stage timelines")
	lines.append("")
	for run_value: Dictionary in runs:
		var sample_for_timeline: Dictionary[String, Variant] = _dictionary_value(run_value.get("sample", {}))
		lines.append("### %s (%s)" % [str(sample_for_timeline.get("id", "run")), str(sample_for_timeline.get("scope", "campaign"))])
		lines.append("")
		lines.append("| Stage | Kind | Plan s | Actions | Actions/min | Combat s | Result dwell s | Recovery s | Shop decision s | Dead gap s |")
		lines.append("| ---: | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |")
		for stage_value: Dictionary in _dictionary_array(run_value.get("stages", [])):
			var stage_metrics: Dictionary[String, Variant] = _dictionary_value(stage_value.get("metrics", {}))
			lines.append("| %d | %s | %.2f | %d | %.2f | %.2f | %.2f | %.2f | %.2f | %.2f |" % [
				int(stage_value.get("global_stage", 0)),
				str(stage_value.get("kind", "")),
				float(stage_metrics.get("planning_time_use_seconds", -1.0)),
				int(stage_metrics.get("action_count", 0)),
				float(stage_metrics.get("action_density_per_planning_minute", -1.0)),
				float(stage_metrics.get("combat_duration_seconds", -1.0)),
				float(stage_metrics.get("result_dwell_seconds", -1.0)),
				float(stage_metrics.get("recovery_seconds", -1.0)),
				float(stage_metrics.get("shop_decision_seconds", -1.0)),
				float(stage_metrics.get("max_dead_time_seconds", -1.0)),
			])
		lines.append("")
	lines.append("## Metric thresholds")
	lines.append("")
	lines.append("Thresholds are guardrails for a normal player rhythm, not balance targets. A value of `-1` in a stage row means the beat was not applicable or was not observed in that scoped sample.")
	lines.append("")
	lines.append("| Metric | Min | Max | Basis |")
	lines.append("| --- | ---: | ---: | --- |")
	for threshold_key: Variant in threshold_map.keys():
		var threshold_name: String = str(threshold_key)
		var bounds: Dictionary[String, Variant] = _dictionary_value(threshold_map[threshold_key])
		lines.append("| %s | %s | %s | %s |" % [
			threshold_name,
			str(bounds.get("min", "N/A")),
			str(bounds.get("max", "N/A")),
			str(bounds.get("basis", "")),
		])
	return "\n".join(lines) + "\n"

static func _check_scalar(value: float, bounds: Dictionary[String, Variant], check_minimum: bool = true) -> Dictionary[String, Variant]:
	if value < 0.0:
		return {"status": "FAIL", "value": value, "reason": "missing"}
	var minimum: float = float(bounds.get("min", 0.0))
	var maximum: float = float(bounds.get("max", INF))
	if check_minimum and value < minimum:
		return {"status": "FAIL", "value": value, "reason": "too_fast", "min": minimum, "max": maximum}
	if value > maximum:
		return {"status": "FAIL", "value": value, "reason": "too_slow", "min": minimum, "max": maximum}
	return {"status": "PASS", "value": value, "min": minimum, "max": maximum}

static func _check_distribution(values: Array[float], bounds: Dictionary[String, Variant], check_minimum: bool = true) -> Dictionary[String, Variant]:
	return _check_distribution_at(values, bounds, "p90", check_minimum)

static func _check_distribution_at(values: Array[float], bounds: Dictionary[String, Variant], percentile: String, check_minimum: bool = true) -> Dictionary[String, Variant]:
	if values.is_empty():
		return {"status": "FAIL", "count": 0, "reason": "missing"}
	var summary: Dictionary[String, Variant] = _summary(values)
	var selected: float = float(summary.get(percentile, -1.0))
	var minimum: float = float(bounds.get("min", 0.0))
	var maximum: float = float(bounds.get("max", INF))
	if check_minimum and selected < minimum:
		summary["status"] = "FAIL"
		summary["reason"] = "too_fast"
	elif selected > maximum:
		summary["status"] = "FAIL"
		summary["reason"] = "too_slow"
	else:
		summary["status"] = "PASS"
	summary["min"] = minimum
	summary["max"] = maximum
	summary["checked_percentile"] = percentile
	return summary

static func _check_combat_distribution(stages: Array[Dictionary], values: Array[float], bounds: Dictionary[String, Variant]) -> Dictionary[String, Variant]:
	var result: Dictionary[String, Variant] = _check_distribution(values, bounds)
	if String(result.get("status", "FAIL")) == "FAIL" or values.is_empty():
		return result
	var boss_max: float = float(bounds.get("boss_max", bounds.get("max", INF)))
	var boss_durations: Array[float] = []
	for stage: Dictionary in stages:
		var metrics: Dictionary[String, Variant] = _dictionary_value(stage.get("metrics", {}))
		var duration_value: Variant = metrics.get("combat_duration_seconds", null)
		if bool(stage.get("is_boss", false)) and (duration_value is float or duration_value is int):
			boss_durations.append(float(duration_value))
	if not boss_durations.is_empty():
		var boss_summary: Dictionary[String, Variant] = _summary(boss_durations)
		result["boss_p90"] = float(boss_summary.get("p90", -1.0))
		if float(boss_summary.get("p90", -1.0)) > boss_max:
			result["status"] = "FAIL"
			result["reason"] = "boss_too_slow"
	return result

static func _check_scalar_max(values: Array[float], bounds: Dictionary[String, Variant]) -> Dictionary[String, Variant]:
	if values.is_empty():
		return {"status": "N/A", "count": 0, "reason": "no_loss_retry_observed"}
	var maximum: float = float(bounds.get("max", INF))
	var highest: float = values[0]
	for value: float in values:
		highest = max(highest, value)
	return {"status": "PASS" if highest <= maximum else "FAIL", "value": highest, "max": maximum, "count": values.size(), "reason": "too_slow" if highest > maximum else ""}

static func _not_applicable(note: String) -> Dictionary[String, Variant]:
	return {"status": "N/A", "note": note}

static func _check_run_length(highest_stage: int, target_stage: int, reached_target: bool, bounds: Dictionary[String, Variant]) -> Dictionary[String, Variant]:
	var minimum: int = int(bounds.get("min", 0.0))
	if highest_stage < minimum:
		return {"status": "FAIL", "value": highest_stage, "target": target_stage, "reason": "run_too_short", "min": minimum}
	if target_stage > 0 and not reached_target:
		return {"status": "FAIL", "value": highest_stage, "target": target_stage, "reason": "target_not_reached", "min": minimum}
	return {"status": "PASS", "value": highest_stage, "target": target_stage, "min": minimum}

static func _summary(values: Array[float]) -> Dictionary[String, Variant]:
	var sorted_values: Array[float] = values.duplicate()
	sorted_values.sort()
	var count: int = sorted_values.size()
	var p50_index: int = clampi(int(ceil(float(count) * 0.50)) - 1, 0, count - 1)
	var p90_index: int = clampi(int(ceil(float(count) * 0.90)) - 1, 0, count - 1)
	return {
		"count": count,
		"min_value": sorted_values[0],
		"max_value": sorted_values[count - 1],
		"p50": sorted_values[p50_index],
		"p90": sorted_values[p90_index],
		"values": sorted_values,
	}

static func _stage_metric_values(stages: Array[Dictionary], key: String) -> Array[float]:
	var values: Array[float] = []
	for stage: Dictionary in stages:
		var metrics: Dictionary[String, Variant] = _dictionary_value(stage.get("metrics", {}))
		var value: Variant = metrics.get(key, null)
		if value is float or value is int:
			if float(value) >= 0.0:
				values.append(float(value))
	return values

static func _threshold(all_thresholds: Dictionary[String, Variant], key: String) -> Dictionary[String, Variant]:
	return _dictionary_value(all_thresholds.get(key, {}))

static func _dictionary_value(value: Variant) -> Dictionary[String, Variant]:
	if value is Dictionary:
		var output: Dictionary[String, Variant] = {}
		for key: Variant in (value as Dictionary).keys():
			output[String(key)] = (value as Dictionary)[key]
		return output
	return {}

static func _dictionary_array(value: Variant) -> Array[Dictionary]:
	var output: Array[Dictionary] = []
	if not value is Array:
		return output
	for item: Variant in value as Array:
		if item is Dictionary:
			output.append(_dictionary_value(item))
	return output

static func _float_array(value: Variant) -> Array[float]:
	var output: Array[float] = []
	if not value is Array:
		return output
	for item: Variant in value as Array:
		if item is float or item is int:
			output.append(float(item))
	return output

static func _string_array(value: Variant) -> Array[String]:
	var output: Array[String] = []
	if not value is Array:
		return output
	for item: Variant in value as Array:
		output.append(String(item))
	return output
