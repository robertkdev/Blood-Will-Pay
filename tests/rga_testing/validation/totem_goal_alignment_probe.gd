extends Node

const RoleMatrixProbe := preload("res://tests/rga_testing/validation/RoleMatrixProbe.gd")
const RoleMetricsContextBuilder := preload("res://tests/rga_testing/metrics/_shared/context_builder.gd")
const TelemetryCapabilities := preload("res://tests/rga_testing/core/telemetry_capabilities.gd")
const GoalPrimaryTest := preload("res://tests/rga_testing/metrics/goal/goal_primary_test.gd")
const RoleCommon := preload("res://tests/rga_testing/metrics/_shared/role_common.gd")

const SUBJECT_ID: String = "totem"
const CURRENT_GOAL: String = "support.peel_carry"
const ALTERNATE_GOAL: String = "support.team_amplification"
const OUT_ROOT: String = "user://rga_probe/totem_goal_alignment"
const ROWS_PATH: String = "user://rga_probe/totem_goal_alignment/run_role_matrix6v6_totem"
const RUN_TIMEOUT_MS: int = 240000

@export var do_quit_on_finish: bool = true

var _finished: bool = false

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	RoleCommon.clear_identity_cache()
	var failures: Array[String] = []
	var role_matrix_ok: bool = await _run_totem_rows()
	if not role_matrix_ok:
		failures.append("TotemGoalAlignmentProbe: RoleMatrix rows did not finish")
	else:
		failures.append_array(_evaluate_goal_alignment())
	RoleCommon.clear_identity_cache()

	if not failures.is_empty():
		for failure: String in failures:
			printerr(failure)
		_quit(1)
		return
	print("TotemGoalAlignmentProbe: PASS")
	_quit(0)

func _run_totem_rows() -> bool:
	_finished = false
	var probe: Node = RoleMatrixProbe.new()
	probe.set("subject_unit_id", SUBJECT_ID)
	probe.set("quick_balance_mode", true)
	probe.set("quick_balance_seed_count", 1)
	probe.set("quick_balance_labels", PackedStringArray(["peel", "threat"]))
	probe.set("profile", "full_probe_6v6")
	probe.set("scenario_labels_6v6", PackedStringArray(["peel", "threat"]))
	probe.set("max_seeds_per_label", 1)
	probe.set("max_sims", 2)
	probe.set("metric_ids", PackedStringArray(["goal_primary"]))
	probe.set("out_root", OUT_ROOT)
	probe.set("write_reports", false)
	probe.set("resume_if_exists", false)
	probe.set("do_quit_on_finish", false)
	probe.connect("finished", Callable(self, "_on_probe_finished"), CONNECT_ONE_SHOT)
	add_child(probe)

	var start_ms: int = Time.get_ticks_msec()
	while not _finished and (Time.get_ticks_msec() - start_ms) < RUN_TIMEOUT_MS:
		await get_tree().process_frame

	if probe.get_parent() != null:
		remove_child(probe)
	probe.queue_free()
	return _finished

func _evaluate_goal_alignment() -> Array[String]:
	var failures: Array[String] = []
	var ctx: Dictionary = RoleMetricsContextBuilder.build(ROWS_PATH, TelemetryCapabilities.all_caps(), "")
	var sims: Dictionary = ctx.get("sims", {}) if (ctx is Dictionary) else {}
	if sims.size() != 2:
		failures.append("TotemGoalAlignmentProbe: expected 2 Totem sims, found %d at %s" % [sims.size(), ROWS_PATH])
		return failures

	RoleCommon.clear_identity_cache()
	var current_identity: Dictionary = RoleCommon.get_identity(SUBJECT_ID).duplicate(true)
	if String(current_identity.get("primary_goal", "")) != CURRENT_GOAL:
		failures.append("TotemGoalAlignmentProbe: expected current goal %s, found %s" % [CURRENT_GOAL, String(current_identity.get("primary_goal", ""))])
		return failures

	var current_goal: Dictionary = _run_goal(ctx)
	var current_pass: bool = bool(current_goal.get("pass", false))
	var current_save_pass: bool = _has_span_status(current_goal, "goal_peel_carry_peel_saves", true)
	var current_interrupt_pass: bool = _has_span_status(current_goal, "goal_peel_carry_interrupt_events", true)
	var current_protection_pass: bool = _has_span_status(current_goal, "goal_peel_carry_ally_protection_events", true)
	var current_cc_immunity_pass: bool = _has_span_status(current_goal, "goal_peel_carry_cc_immunity_applied", true)

	var alternate_identity: Dictionary = current_identity.duplicate(true)
	alternate_identity["primary_goal"] = ALTERNATE_GOAL
	RoleCommon._identity_cache[SUBJECT_ID] = alternate_identity
	var alternate_goal: Dictionary = _run_goal(ctx)
	var alternate_pass: bool = bool(alternate_goal.get("pass", false))
	var alternate_buff_pass: bool = _has_span_status(alternate_goal, "goal_team_amplification_buff_uptime_targets", true)
	var alternate_magnitude_pass: bool = _has_span_status(alternate_goal, "goal_team_amplification_amp_delta_team", true)
	var alternate_output_pass: bool = _has_span_status(alternate_goal, "goal_team_amplification_amp_output_delta", true)
	var alternate_has_peel_rows: bool = _has_span_prefix(alternate_goal, "goal_peel_carry_")

	print("TotemGoalAlignmentProbe: current_pass=", current_pass,
		" current_save_pass=", current_save_pass,
		" current_interrupt_pass=", current_interrupt_pass,
		" current_protection_pass=", current_protection_pass,
		" current_cc_immunity_pass=", current_cc_immunity_pass,
		" alternate_pass=", alternate_pass,
		" alternate_buff_pass=", alternate_buff_pass,
		" alternate_magnitude_pass=", alternate_magnitude_pass,
		" alternate_output_pass=", alternate_output_pass,
		" alternate_has_peel_rows=", alternate_has_peel_rows)

	if not current_pass or not current_save_pass or not current_interrupt_pass or not current_protection_pass or not current_cc_immunity_pass:
		failures.append("TotemGoalAlignmentProbe: current peel-carry contract did not match expected live save-plus-interrupt proof shape")
	if not alternate_pass or not alternate_buff_pass or not alternate_magnitude_pass or not alternate_output_pass:
		failures.append("TotemGoalAlignmentProbe: alternate team-amplification contract did not pass on the same live Totem rows")
	if alternate_has_peel_rows:
		failures.append("TotemGoalAlignmentProbe: alternate team-amplification contract still emitted peel-carry rows")
	return failures

func _run_goal(ctx: Dictionary) -> Dictionary:
	var metric: Variant = GoalPrimaryTest.new()
	return metric.call("run_metric", {
		"context": ctx,
		"subject_unit_ids": [SUBJECT_ID]
	})

func _has_span_status(metric_result: Dictionary, label_prefix: String, required_ok: bool) -> bool:
	var span: Dictionary = _span(metric_result, label_prefix)
	return not span.is_empty() and span.has("ok") and bool(span.get("ok", false)) == required_ok

func _has_span_prefix(metric_result: Dictionary, label_prefix: String) -> bool:
	return not _span(metric_result, label_prefix).is_empty()

func _span(metric_result: Dictionary, label_prefix: String) -> Dictionary:
	var spans: Array = metric_result.get("spans", []) if (metric_result is Dictionary) else []
	for span_value in spans:
		if not (span_value is Dictionary):
			continue
		var span: Dictionary = span_value as Dictionary
		var label: String = String(span.get("label", ""))
		if label.begins_with(label_prefix):
			return span
	return {}

func _on_probe_finished(unit_id: String, _report_path: String) -> void:
	if String(unit_id) == SUBJECT_ID:
		_finished = true

func _quit(code: int) -> void:
	if not do_quit_on_finish:
		return
	get_tree().quit(code)
