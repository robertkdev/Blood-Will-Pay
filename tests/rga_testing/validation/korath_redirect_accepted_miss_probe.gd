extends Node

const RedirectApproachTest := preload("res://tests/rga_testing/metrics/approach/redirect_approach_test.gd")

const SUBJECT_ID: String = "korath"
const ALLY_ID: String = "brute"
const ENEMY_ID: String = "mara"

@export var do_quit_on_finish: bool = true

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var full_result: Dictionary = _run_metric(_make_payload("full_redirect", _full_redirect_rec(), 0.0, 0.0))
	var body_block_result: Dictionary = _run_metric(_make_payload("body_block_aggregate", _body_block_rec(), 0.0, 0.0))
	var weak_result: Dictionary = _run_metric(_make_payload("weak_redirect", _weak_redirect_rec(), 150.0, 200.0))

	var full_pass: bool = bool(full_result.get("pass", false))
	var body_block_pass: bool = bool(body_block_result.get("pass", false))
	var weak_pass: bool = bool(weak_result.get("pass", false))
	var full_target_swap_span: bool = _has_span(full_result, "subject_redirect_target_swap_events", true)
	var full_threat_swap_span: bool = _has_span(full_result, "subject_redirect_explicit_threat_swap_events", true)
	var full_taunt_span: bool = _has_span(full_result, "subject_redirect_taunt_events", true)
	var body_block_span: bool = _has_span(body_block_result, "subject_redirect_body_block_events", true)
	var body_block_prevented_span: bool = _has_span(body_block_result, "subject_redirect_body_block_damage_prevented", true)
	var body_block_target_swap_diagnostic: bool = _has_diagnostic_span(body_block_result, "subject_redirect_target_swap_events", "alternate_redirect_evidence_satisfied")
	var body_block_threat_swap_diagnostic: bool = _has_diagnostic_span(body_block_result, "subject_redirect_explicit_threat_swap_events", "alternate_redirect_evidence_satisfied")
	var body_block_taunt_diagnostic: bool = _has_diagnostic_span(body_block_result, "subject_redirect_taunt_events", "alternate_redirect_evidence_satisfied")
	var weak_proxy_span: bool = _has_span(weak_result, "subject_redirect_incoming_share_proxy", true)

	print("KorathRedirectAcceptedMissProbe: full_pass=", full_pass,
		" body_block_pass=", body_block_pass,
		" weak_pass=", weak_pass,
		" full_target_swap_span=", full_target_swap_span,
		" full_threat_swap_span=", full_threat_swap_span,
		" full_taunt_span=", full_taunt_span,
		" body_block_target_swap_diagnostic=", body_block_target_swap_diagnostic,
		" body_block_threat_swap_diagnostic=", body_block_threat_swap_diagnostic,
		" body_block_taunt_diagnostic=", body_block_taunt_diagnostic)

	var failed: bool = false
	if not full_pass or not full_target_swap_span or not full_threat_swap_span or not full_taunt_span:
		printerr("KorathRedirectAcceptedMissProbe: FAIL full threat-swap/taunt proof did not pass")
		failed = true
	if not body_block_pass or not body_block_span or not body_block_prevented_span:
		printerr("KorathRedirectAcceptedMissProbe: FAIL body-block aggregate control did not pass")
		failed = true
	if not body_block_target_swap_diagnostic or not body_block_threat_swap_diagnostic or not body_block_taunt_diagnostic:
		printerr("KorathRedirectAcceptedMissProbe: FAIL body-block aggregate control did not keep missing redirect submodes diagnostic")
		failed = true
	if weak_pass:
		printerr("KorathRedirectAcceptedMissProbe: FAIL direct-supported weak payload passed")
		failed = true
	if not weak_proxy_span:
		printerr("KorathRedirectAcceptedMissProbe: FAIL weak payload did not prove proxy evidence is ignored when direct redirect is supported")
		failed = true

	if failed:
		_quit(1)
		return
	print("KorathRedirectAcceptedMissProbe: PASS")
	_quit(0)

func _run_metric(payload: Dictionary) -> Dictionary:
	var metric: Variant = RedirectApproachTest.new()
	return metric.call("run_metric", payload)

func _make_payload(case_id: String, redirect_rec: Dictionary, subject_incoming: float, ally_incoming: float) -> Dictionary:
	return {
		"context": {
			"scenario": "neutral",
			"sims": {
				case_id: {
					"context": {
						"team_a_ids": [SUBJECT_ID, ALLY_ID],
						"team_b_ids": [ENEMY_ID]
					},
					"units": {
						"a": [
							{
								"unit_id": SUBJECT_ID,
								"incoming": subject_incoming,
								"pre_mit_incoming": subject_incoming
							},
							{
								"unit_id": ALLY_ID,
								"incoming": ally_incoming,
								"pre_mit_incoming": ally_incoming
							}
						],
						"b": [
							{
								"unit_id": ENEMY_ID,
								"incoming": 0.0,
								"pre_mit_incoming": 0.0
							}
						]
					},
					"kernels": {
						"redirect": {
							"supported": true,
							"per_unit": {
								"a": {
									SUBJECT_ID: redirect_rec
								}
							}
						}
					}
				}
			}
		},
		"subject_unit_ids": [SUBJECT_ID]
	}

func _full_redirect_rec() -> Dictionary:
	return {
		"redirect_events": 1,
		"redirected_damage_prevented": 10.0,
		"focus_start_events": 1,
		"target_swap_to_subject_events": 1,
		"enemy_focus_time_s": 1.2,
		"taunt_events": 1,
		"taunt_duration_s": 1.0,
		"explicit_threat_swap_events": 1,
		"body_block_events": 0,
		"body_block_damage_prevented": 0.0
	}

func _body_block_rec() -> Dictionary:
	return {
		"redirect_events": 0,
		"redirected_damage_prevented": 0.0,
		"focus_start_events": 0,
		"target_swap_to_subject_events": 0,
		"enemy_focus_time_s": 0.0,
		"taunt_events": 0,
		"taunt_duration_s": 0.0,
		"explicit_threat_swap_events": 0,
		"body_block_events": 1,
		"body_block_damage_prevented": 30.0
	}

func _weak_redirect_rec() -> Dictionary:
	return {
		"redirect_events": 0,
		"redirected_damage_prevented": 0.0,
		"focus_start_events": 0,
		"target_swap_to_subject_events": 0,
		"enemy_focus_time_s": 0.0,
		"taunt_events": 0,
		"taunt_duration_s": 0.0,
		"explicit_threat_swap_events": 0,
		"body_block_events": 0,
		"body_block_damage_prevented": 0.0
	}

func _has_span(metric_result: Dictionary, expected_label: String, required_ok: bool) -> bool:
	var spans: Array = metric_result.get("spans", []) if (metric_result is Dictionary) else []
	for span_value in spans:
		if not (span_value is Dictionary):
			continue
		var span: Dictionary = span_value as Dictionary
		var label: String = String(span.get("label", ""))
		if label == expected_label and bool(span.get("ok", false)) == required_ok:
			return true
	return false

func _has_diagnostic_span(metric_result: Dictionary, expected_label: String, expected_reason: String) -> bool:
	var spans: Array = metric_result.get("spans", []) if (metric_result is Dictionary) else []
	for span_value in spans:
		if not (span_value is Dictionary):
			continue
		var span: Dictionary = span_value as Dictionary
		var label: String = String(span.get("label", ""))
		var reason: String = String(span.get("reason", ""))
		if label == expected_label and not span.has("ok") and reason == expected_reason:
			return true
	return false

func _quit(code: int) -> void:
	if not do_quit_on_finish:
		return
	get_tree().quit(code)
