extends Node

const CombatEngineScript := preload("res://scripts/game/combat/combat_engine.gd")
const PerUnitKpisKernel := preload("res://tests/rga_testing/aggregators/kernels/per_unit_kpis_kernel.gd")
const GoalPrimaryTest := preload("res://tests/rga_testing/metrics/goal/goal_primary_test.gd")

const SUBJECT_ID: String = "bo"
const FRONTLINE_ID: String = "brute"
const BACKLINE_ID: String = "mara"

@export var do_quit_on_finish: bool = true

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var dive_result: Dictionary = _run_case("backline_dive", 20, 80)
	var direct_result: Dictionary = _run_direct_contact_case("direct_backline_contact")
	var frontline_result: Dictionary = _run_case("frontline_only", 100, 0)
	var dive_rec: Dictionary = dive_result.get("rec", {})
	var dive_goal: Dictionary = dive_result.get("goal", {})
	var direct_goal: Dictionary = direct_result.get("goal", {})
	var frontline_goal: Dictionary = frontline_result.get("goal", {})
	var dive_pass: bool = bool(dive_goal.get("pass", false))
	var direct_pass: bool = bool(direct_goal.get("pass", false))
	var frontline_pass: bool = bool(frontline_goal.get("pass", false))
	var damage_to_frontline: float = float(dive_rec.get("damage_to_frontline_pct", 0.0))
	var contact_value: float = 1.0 - damage_to_frontline
	var dive_contact_span: bool = _has_span(dive_goal, "goal_skirmish_dive_backline_contact_proxy", true)
	var direct_contact_span: Dictionary = _find_span(direct_goal, "goal_skirmish_dive_backline_contact_proxy")
	var direct_contact_ok: bool = bool(direct_contact_span.get("ok", false))
	var direct_contact_value: float = float(direct_contact_span.get("value", 0.0))
	var direct_contact_reason: String = String(direct_contact_span.get("reason", ""))
	var frontline_contact_fail_span: bool = _has_span(frontline_goal, "goal_skirmish_dive_backline_contact_proxy", false)
	var dive_survival_span: bool = _has_span(dive_goal, "goal_skirmish_dive_escape_survival_s", true)

	print("SkirmishDiveBacklineGoalProbe: dive_pass=", dive_pass,
		" damage_to_frontline=", damage_to_frontline,
		" contact_value=", contact_value,
		" dive_contact_span=", dive_contact_span,
		" direct_pass=", direct_pass,
		" direct_contact_ok=", direct_contact_ok,
		" direct_contact_value=", direct_contact_value,
		" direct_contact_reason=", direct_contact_reason,
		" dive_survival_span=", dive_survival_span,
		" frontline_pass=", frontline_pass,
		" frontline_contact_fail_span=", frontline_contact_fail_span)

	var failed: bool = false
	if not dive_pass:
		printerr("SkirmishDiveBacklineGoalProbe: FAIL backline-dive telemetry did not pass Bo's skirmish-dive goal")
		failed = true
	if damage_to_frontline > 0.21 or contact_value < 0.79 or not dive_contact_span:
		printerr("SkirmishDiveBacklineGoalProbe: FAIL per-unit KPI telemetry did not emit a passing backline-contact span")
		failed = true
	if not direct_pass or not direct_contact_ok or direct_contact_value < 1.0 or direct_contact_reason != "direct_backline_access":
		printerr("SkirmishDiveBacklineGoalProbe: FAIL direct backline-access telemetry did not satisfy the contact span")
		failed = true
	if not dive_survival_span:
		printerr("SkirmishDiveBacklineGoalProbe: FAIL survival span did not pass in the positive control")
		failed = true
	if frontline_pass or not frontline_contact_fail_span:
		printerr("SkirmishDiveBacklineGoalProbe: FAIL frontline-only control passed or failed to expose the contact miss")
		failed = true

	if failed:
		_quit(1)
		return
	print("SkirmishDiveBacklineGoalProbe: PASS")
	_quit(0)

func _run_case(case_id: String, frontline_damage: int, backline_damage: int) -> Dictionary:
	var engine: CombatEngine = CombatEngineScript.new()
	engine.arena_state.configure(1.0, [Vector2.ZERO], [Vector2(1.0, 0.0), Vector2(3.0, 0.0)], Rect2(Vector2(-4.0, -4.0), Vector2(8.0, 8.0)))
	var kernel: Variant = PerUnitKpisKernel.new()
	var team_sizes: Dictionary = {"a": 1, "b": 2}
	var context_tags: Dictionary = {
		"metadata": {
			"tile_size": 1.0
		},
		"unit_timelines": {
			"a": [
				{
					"unit_index": 0,
					"unit_id": SUBJECT_ID
				}
			],
			"b": [
				{
					"unit_index": 0,
					"unit_id": FRONTLINE_ID,
					"entries": [
						{
							"tag": "frontline"
						}
					]
				},
				{
					"unit_index": 1,
					"unit_id": BACKLINE_ID
				}
			]
		}
	}
	kernel.call("attach", engine, team_sizes, context_tags, true)
	kernel.call("tick", 1.0)
	if frontline_damage > 0:
		engine.emit_signal("hit_applied", "player", 0, 0, frontline_damage, frontline_damage, false, 1000, 1000 - frontline_damage, 0.0, 0.0)
	if backline_damage > 0:
		engine.emit_signal("hit_applied", "player", 0, 1, backline_damage, backline_damage, false, 1000, 1000 - backline_damage, 0.0, 0.0)
	kernel.call("tick", 9.0)
	kernel.call("finalize", 10.0)

	var result: Dictionary = kernel.call("result")
	var kpis: Dictionary = result.get("per_unit_kpis", {}) if (result is Dictionary) else {}
	var side_a: Dictionary = kpis.get("a", {}) if (kpis is Dictionary) else {}
	var rec: Dictionary = side_a.get(SUBJECT_ID, {}) if (side_a is Dictionary) else {}
	var goal_result: Dictionary = _run_goal(case_id, result)
	kernel.call("detach")
	return {
		"rec": rec,
		"goal": goal_result
	}

func _run_direct_contact_case(case_id: String) -> Dictionary:
	var kernel_result: Dictionary = {
		"per_unit_kpis": {
			"a": {
				SUBJECT_ID: {
					"damage_to_frontline_pct": 1.0
				}
			}
		},
		"backline_access": {
			"supported": true,
			"a": {
				"entered_by_unit": {
					SUBJECT_ID: 2.0
				},
				"entries": [
					{
						"first_backline_contact_s": 2.0,
						"unit_id": SUBJECT_ID,
						"unit_index": 0
					}
				],
				"first_backline_contact_s": 2.0,
				"first_backline_rank": 1,
				"first_backline_unit_id": SUBJECT_ID,
				"samples": 1
			},
			"b": {
				"entered_by_unit": {},
				"entries": [],
				"first_backline_contact_s": null,
				"first_backline_rank": null,
				"first_backline_unit_id": "",
				"samples": 0
			}
		}
	}
	return {
		"goal": _run_goal(case_id, kernel_result)
	}

func _run_goal(case_id: String, kernel_result: Dictionary) -> Dictionary:
	var metric: Variant = GoalPrimaryTest.new()
	var payload: Dictionary = {
		"context": {
			"scenario": "neutral",
			"sims": {
				case_id: {
					"context": {
						"team_a_ids": [SUBJECT_ID],
						"team_b_ids": [FRONTLINE_ID, BACKLINE_ID]
					},
					"teams": {
						"a": {
							"damage": 100.0
						},
						"b": {
							"damage": 0.0
						}
					},
					"units": {
						"a": [
							{
								"unit_id": SUBJECT_ID,
								"damage": 100.0,
								"incoming": 0.0,
								"time_alive_s": 10.0
							}
						],
						"b": [
							{
								"unit_id": FRONTLINE_ID,
								"incoming": 0.0
							},
							{
								"unit_id": BACKLINE_ID,
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

func _find_span(metric_result: Dictionary, label_prefix: String) -> Dictionary:
	var spans: Array = metric_result.get("spans", []) if (metric_result is Dictionary) else []
	for span_value in spans:
		if not (span_value is Dictionary):
			continue
		var span: Dictionary = span_value as Dictionary
		var label: String = String(span.get("label", ""))
		if label.begins_with(label_prefix):
			return span
	return {}

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
