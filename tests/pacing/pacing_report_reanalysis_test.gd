extends Node

## Re-analyzes a captured Main.tscn pacing run after metric-contract changes.
## This never invents events: it loads the fresh runtime event stream, applies
## the same recorder helper used during live capture, and emits a separate
## evidence packet so the original capture remains auditable.

const PacingMetrics: Script = preload("res://tests/pacing/pacing_metrics.gd")
const PacingRecorder: Script = preload("res://tests/pacing/pacing_recorder.gd")

const CAPTURE_PATH: String = "user://pacing/competent_policy_pacing_suite.json"
const OUTPUT_SUITE_PATH: String = "user://pacing/competent_policy_pacing_reanalysis_suite.json"
const OUTPUT_REPORT_PATH: String = "user://pacing/competent_policy_pacing_reanalysis_report.md"

var _failures: Array[String] = []

func _ready() -> void:
	var suite: Dictionary[String, Variant] = _load_suite()
	if suite.is_empty():
		_failures.append("captured competent pacing suite was unavailable")
	else:
		var runs: Array[Dictionary] = _dictionary_array(suite.get("runs", []))
		if runs.is_empty():
			_failures.append("captured competent pacing suite had no runs")
		else:
			for index: int in range(runs.size()):
				runs[index] = _recompute_run(runs[index])
			suite["runs"] = runs
			suite["reanalysis_source"] = CAPTURE_PATH
			var analysis: Dictionary[String, Variant] = PacingMetrics.analyze_suite(suite)
			_write_outputs(suite, analysis)
			print("PacingReportReanalysisTest: verdict=%s failures=%s" % [analysis.get("verdict", "FAIL"), JSON.stringify(analysis.get("failures", []))])
			if String(analysis.get("verdict", "FAIL")) != "PASS":
				_failures.append("captured competent pacing suite remains red: %s" % JSON.stringify(analysis.get("failures", [])))
	for failure: String in _failures:
		push_error("PacingReportReanalysisTest: " + failure)
	await get_tree().create_timer(0.5).timeout
	get_tree().quit(1 if not _failures.is_empty() else 0)

func _load_suite() -> Dictionary[String, Variant]:
	if not FileAccess.file_exists(CAPTURE_PATH):
		return {}
	var file: FileAccess = FileAccess.open(CAPTURE_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return _dictionary_value(parsed)

func _recompute_run(run: Dictionary[String, Variant]) -> Dictionary[String, Variant]:
	var run_copy: Dictionary[String, Variant] = run.duplicate(true)
	var run_events: Array[Dictionary] = _dictionary_array(run_copy.get("events", []))
	var run_data: Dictionary[String, Variant] = _dictionary_value(run_copy.get("run", {}))
	run_data["max_dead_time_seconds"] = PacingRecorder.max_dead_time_for_events(run_events)
	run_copy["run"] = run_data
	var stages: Array[Dictionary] = _dictionary_array(run_copy.get("stages", []))
	for index: int in range(stages.size()):
		var stage: Dictionary[String, Variant] = stages[index]
		var stage_events: Array[Dictionary] = _dictionary_array(stage.get("events", []))
		var stage_metrics: Dictionary[String, Variant] = _dictionary_value(stage.get("metrics", {}))
		stage_metrics["max_dead_time_seconds"] = PacingRecorder.max_dead_time_for_events(stage_events)
		stage["metrics"] = stage_metrics
		stages[index] = stage
	run_copy["stages"] = stages
	return run_copy

func _write_outputs(suite: Dictionary[String, Variant], analysis: Dictionary[String, Variant]) -> void:
	var suite_file: FileAccess = FileAccess.open(OUTPUT_SUITE_PATH, FileAccess.WRITE)
	if suite_file != null:
		suite_file.store_string(JSON.stringify(suite, "\t"))
	var report_file: FileAccess = FileAccess.open(OUTPUT_REPORT_PATH, FileAccess.WRITE)
	if report_file != null:
		var note: String = "<!-- Re-analysis of the fresh Main.tscn event capture at %s; no gameplay events were changed. -->\n\n" % CAPTURE_PATH
		report_file.store_string(note + PacingMetrics.render_markdown(suite, analysis))

func _dictionary_value(value: Variant) -> Dictionary[String, Variant]:
	var output: Dictionary[String, Variant] = {}
	if value is Dictionary:
		for key: Variant in (value as Dictionary).keys():
			output[String(key)] = (value as Dictionary)[key]
	return output

func _dictionary_array(value: Variant) -> Array[Dictionary]:
	var output: Array[Dictionary] = []
	if not value is Array:
		return output
	for item: Variant in value as Array:
		if item is Dictionary:
			output.append(_dictionary_value(item))
	return output
