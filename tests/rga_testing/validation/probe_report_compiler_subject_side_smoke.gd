extends Node

const ProbeReportCompiler := preload("res://tests/rga_testing/validation/probe_report_compiler.gd")

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var ok: bool = true
	ok = _assert_unit_attributed_side_filter() and ok
	ok = _assert_non_attrition_brawler_direct_attrition_filter() and ok
	ok = _assert_suffix_side_filter_fallback() and ok
	if ok:
		print("ProbeReportCompilerSubjectSideSmoke: PASS")
		get_tree().quit(0)
	else:
		printerr("ProbeReportCompilerSubjectSideSmoke: FAIL")
		get_tree().quit(1)

func _assert_unit_attributed_side_filter() -> bool:
	var metric: Dictionary[String, Variant] = {
		"id": "role_brawler_identity",
		"status": "pass",
		"message": "synthetic brawler side filter",
		"spans": [
			_span("unit_direct_attrition_evidence", 0.0, 1.0, false, {
				"unit_id": "bonko",
				"subject_side": "a",
				"subject_role": "brawler",
				"reason": "synthetic_subject_fail"
			}),
			_span("unit_pass", 1.0, 1.0, true, {
				"unit_id": "bonko",
				"subject_side": "a",
				"subject_role": "brawler",
				"reason": "synthetic_subject_pass"
			}),
			_span("a_unit_pass_count", 1.0, 1.0, true),
			_span("b_unit_pass_count", 0.0, 1.0, false)
		]
	}
	var report: Dictionary[String, Variant] = _typed_dictionary(ProbeReportCompiler.compile("bonko", {}, {"metrics": [metric]}, {"run_id": "subject_side_unit"}))
	var spans: Array[Dictionary] = _diagnostic_spans(report)
	var labels: Array[String] = _labels(spans)
	if not labels.has("unit_direct_attrition_evidence"):
		printerr("Smoke: missing subject-attributed failure in diagnostics")
		return false
	if labels.has("b_unit_pass_count"):
		printerr("Smoke: opponent-side b_unit_pass_count leaked into diagnostics")
		return false
	if int((report.get("diagnostics", {}) as Dictionary).get("lower_level_fail_span_count", -1)) != 1:
		printerr("Smoke: expected one unit-attributed diagnostic failure, got ", report.get("diagnostics", {}))
		return false
	return true

func _assert_non_attrition_brawler_direct_attrition_filter() -> bool:
	var metric: Dictionary[String, Variant] = {
		"id": "role_brawler_identity",
		"status": "pass",
		"message": "synthetic non-attrition brawler filter",
		"spans": [
			_span("unit_direct_attrition_evidence", 0.0, 1.0, false, {
				"unit_id": "bo",
				"subject_side": "a",
				"subject_role": "brawler",
				"reason": "synthetic_skirmish_direct_attrition"
			}),
			_span("unit_pass", 1.0, 1.0, true, {
				"unit_id": "bo",
				"subject_side": "a",
				"subject_role": "brawler",
				"reason": "synthetic_skirmish_pass"
			}),
			_span("a_unit_pass_count", 1.0, 1.0, true),
			_span("b_unit_pass_count", 0.0, 1.0, false)
		]
	}
	var report: Dictionary[String, Variant] = _typed_dictionary(ProbeReportCompiler.compile("bo", {}, {"metrics": [metric]}, {"run_id": "non_attrition_brawler"}))
	var spans: Array[Dictionary] = _diagnostic_spans(report)
	var labels: Array[String] = _labels(spans)
	if labels.has("unit_direct_attrition_evidence"):
		printerr("Smoke: non-attrition brawler direct-attrition diagnostic leaked into report")
		return false
	if int((report.get("diagnostics", {}) as Dictionary).get("lower_level_fail_span_count", -1)) != 0:
		printerr("Smoke: expected zero non-attrition brawler diagnostics, got ", report.get("diagnostics", {}))
		return false
	return true

func _assert_suffix_side_filter_fallback() -> bool:
	var metric: Dictionary[String, Variant] = {
		"id": "role_mage_identity",
		"status": "pass",
		"message": "synthetic mage side suffix filter",
		"spans": [
			_span("magic_share_med_a", 0.10, 0.35, false),
			_span("magic_peak_over_mean_med_a", 2.00, 1.70, true),
			_span("magic_share_med_b", 0.10, 0.35, false),
			_span("magic_peak_over_mean_med_b", 2.00, 1.70, true)
		]
	}
	var report: Dictionary[String, Variant] = _typed_dictionary(ProbeReportCompiler.compile("mara", {}, {"metrics": [metric]}, {"run_id": "subject_side_suffix"}))
	var spans: Array[Dictionary] = _diagnostic_spans(report)
	var labels: Array[String] = _labels(spans)
	if not labels.has("magic_share_med_a"):
		printerr("Smoke: missing side-A suffix failure in diagnostics")
		return false
	if labels.has("magic_share_med_b"):
		printerr("Smoke: side-B suffix failure leaked into non-swapped diagnostics")
		return false
	if int((report.get("diagnostics", {}) as Dictionary).get("lower_level_fail_span_count", -1)) != 1:
		printerr("Smoke: expected one suffix diagnostic failure, got ", report.get("diagnostics", {}))
		return false
	return true

func _span(label: String, value: float, want: float, ok: bool, extras: Dictionary[String, Variant] = {}) -> Dictionary[String, Variant]:
	var span: Dictionary[String, Variant] = {
		"label": label,
		"value": value,
		"want": want,
		"ok": ok
	}
	for key: String in extras.keys():
		span[key] = extras[key]
	return span

func _diagnostic_spans(report: Dictionary[String, Variant]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var diagnostics: Dictionary[String, Variant] = _typed_dictionary(report.get("diagnostics", {}))
	var raw_spans_value: Variant = diagnostics.get("lower_level_fail_spans", [])
	if not (raw_spans_value is Array):
		return out
	for raw_span: Variant in raw_spans_value:
		if raw_span is Dictionary:
			var typed_span: Dictionary = raw_span
			out.append(typed_span)
	return out

func _typed_dictionary(raw_value: Variant) -> Dictionary[String, Variant]:
	var out: Dictionary[String, Variant] = {}
	if not (raw_value is Dictionary):
		return out
	var source: Dictionary = raw_value
	for key: Variant in source.keys():
		out[String(key)] = source[key]
	return out

func _labels(spans: Array[Dictionary]) -> Array[String]:
	var out: Array[String] = []
	for span: Dictionary in spans:
		out.append(String(span.get("label", "")))
	return out
