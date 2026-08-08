extends Node

const CombatEngineScript := preload("res://scripts/game/combat/combat_engine.gd")
const BattleStateScript := preload("res://scripts/game/combat/battle_state.gd")
const RedirectKernel := preload("res://tests/rga_testing/aggregators/kernels/redirect_kernel.gd")
const GoalPrimaryTest := preload("res://tests/rga_testing/metrics/goal/goal_primary_test.gd")

const SUBJECT_ID: String = "brute"
const ALLY_ID: String = "bonko"
const ENEMY_ID: String = "mara"

@export var do_quit_on_finish: bool = true

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var full_result: Dictionary = _run_case("full_body_block", true, true, 35.0)
	var redirect_only_result: Dictionary = _run_case("redirect_only", true, false, 35.0)
	var event_only_result: Dictionary = _run_case("event_only", false, true, 35.0)
	var damage_only_result: Dictionary = _run_case("damage_only", true, false, 0.0)
	var weak_result: Dictionary = _run_case("weak_body_block", true, true, 10.0)

	var full_rec: Dictionary = full_result.get("rec", {})
	var full_goal: Dictionary = full_result.get("goal", {})
	var redirect_only_goal: Dictionary = redirect_only_result.get("goal", {})
	var event_only_goal: Dictionary = event_only_result.get("goal", {})
	var damage_only_goal: Dictionary = damage_only_result.get("goal", {})
	var weak_goal: Dictionary = weak_result.get("goal", {})
	var full_pass: bool = bool(full_goal.get("pass", false))
	var redirect_only_pass: bool = bool(redirect_only_goal.get("pass", false))
	var event_only_pass: bool = bool(event_only_goal.get("pass", false))
	var damage_only_pass: bool = bool(damage_only_goal.get("pass", false))
	var weak_pass: bool = bool(weak_goal.get("pass", false))
	var body_block_events: int = int(full_rec.get("body_block_events", 0))
	var body_block_prevented: float = float(full_rec.get("body_block_damage_prevented", 0.0))
	var redirected_prevented: float = float(full_rec.get("redirected_damage_prevented", 0.0))
	var full_event_span: bool = _has_span(full_goal, "goal_frontline_absorb_body_block_events", true)
	var full_prevented_span: bool = _has_span(full_goal, "goal_frontline_absorb_body_block_damage_prevented", true)
	var redirect_only_event_diagnostic: bool = _has_diagnostic_span(redirect_only_goal, "goal_frontline_absorb_body_block_events", "direct_redirect_semantic")
	var redirect_only_damage_diagnostic: bool = _has_diagnostic_span(redirect_only_goal, "goal_frontline_absorb_body_block_damage_prevented", "direct_redirect_semantic")
	var redirect_only_prevented_span: bool = _has_span(redirect_only_goal, "goal_frontline_absorb_ally_damage_prevented", true)
	var event_only_prevented_span: bool = _has_span(event_only_goal, "goal_frontline_absorb_ally_damage_prevented", true)
	var damage_only_event_span: bool = _has_span(damage_only_goal, "goal_frontline_absorb_body_block_events", true)
	var weak_prevented_span: bool = _has_span(weak_goal, "goal_frontline_absorb_body_block_damage_prevented", true)

	print("FrontlineBodyBlockGoalProbe: full_pass=", full_pass,
		" body_block_events=", body_block_events,
		" body_block_prevented=", body_block_prevented,
		" redirected_prevented=", redirected_prevented,
		" full_event_span=", full_event_span,
		" full_prevented_span=", full_prevented_span,
		" redirect_only_pass=", redirect_only_pass,
		" redirect_only_event_diagnostic=", redirect_only_event_diagnostic,
		" redirect_only_damage_diagnostic=", redirect_only_damage_diagnostic,
		" event_only_pass=", event_only_pass,
		" damage_only_pass=", damage_only_pass,
		" weak_pass=", weak_pass)

	var failed: bool = false
	if not full_pass:
		printerr("FrontlineBodyBlockGoalProbe: FAIL full body-block telemetry did not pass Brute's frontline absorb goal")
		failed = true
	if body_block_events != 1 or body_block_prevented < 35.0 or redirected_prevented < 35.0:
		printerr("FrontlineBodyBlockGoalProbe: FAIL direct body-block or redirected-damage telemetry was not recorded")
		failed = true
	if not full_event_span or not full_prevented_span:
		printerr("FrontlineBodyBlockGoalProbe: FAIL full case did not emit passing body-block goal spans")
		failed = true
	if not redirect_only_pass or not redirect_only_prevented_span:
		printerr("FrontlineBodyBlockGoalProbe: FAIL redirect-only absorb telemetry did not pass the frontline absorb goal")
		failed = true
	if not redirect_only_event_diagnostic or not redirect_only_damage_diagnostic:
		printerr("FrontlineBodyBlockGoalProbe: FAIL redirect-only absorb telemetry was not kept distinct from physical body-block spans")
		failed = true
	if event_only_pass or damage_only_pass or weak_pass:
		printerr("FrontlineBodyBlockGoalProbe: FAIL a missing/weak body-block control passed")
		failed = true
	if event_only_prevented_span or damage_only_event_span or weak_prevented_span:
		printerr("FrontlineBodyBlockGoalProbe: FAIL a missing/weak body-block control emitted the wrong passing span")
		failed = true

	if failed:
		_quit(1)
		return
	print("FrontlineBodyBlockGoalProbe: PASS")
	_quit(0)

func _run_case(case_id: String, emit_redirected_damage: bool, emit_body_block: bool, amount: float) -> Dictionary:
	var engine: CombatEngine = CombatEngineScript.new()
	var state: BattleState = _make_state()
	engine.state = state
	var kernel: Variant = RedirectKernel.new()
	var team_sizes: Dictionary = {"a": 2, "b": 1}
	var context_tags: Dictionary = {
		"unit_timelines": {
			"a": [
				{
					"unit_index": 0,
					"unit_id": SUBJECT_ID
				},
				{
					"unit_index": 1,
					"unit_id": ALLY_ID
				}
			],
			"b": [
				{
					"unit_index": 0,
					"unit_id": ENEMY_ID
				}
			]
		}
	}
	kernel.call("attach", engine, team_sizes, context_tags, true)
	if emit_redirected_damage:
		engine.emit_signal("damage_redirected", "enemy", 0, "player", 1, "player", 0, int(amount), "body_block")
	if emit_body_block:
		engine._resolver_emit_redirect_semantic_applied("player", 0, "enemy", 0, "body_block", 0.75, amount, 0.25)
	kernel.call("finalize", 2.0)

	var result: Dictionary = kernel.call("result")
	var redirect_block: Dictionary = result.get("redirect", {}) if (result is Dictionary) else {}
	var per_unit: Dictionary = redirect_block.get("per_unit", {}) if (redirect_block is Dictionary) else {}
	var side_a: Dictionary = per_unit.get("a", {}) if (per_unit is Dictionary) else {}
	var rec: Dictionary = side_a.get(SUBJECT_ID, {}) if (side_a is Dictionary) else {}
	var goal_result: Dictionary = _run_goal(case_id, result)
	kernel.call("detach")
	return {
		"rec": rec,
		"goal": goal_result
	}

func _make_state() -> BattleState:
	var state: BattleState = BattleStateScript.new()
	var subject: Unit = Unit.new()
	subject.id = SUBJECT_ID
	subject.max_hp = 1000
	subject.hp = 1000
	var ally: Unit = Unit.new()
	ally.id = ALLY_ID
	ally.max_hp = 1000
	ally.hp = 1000
	var enemy: Unit = Unit.new()
	enemy.id = ENEMY_ID
	enemy.max_hp = 1000
	enemy.hp = 1000
	var player_team: Array[Unit] = [subject, ally]
	var enemy_team: Array[Unit] = [enemy]
	state.player_team = player_team
	state.enemy_team = enemy_team
	return state

func _run_goal(case_id: String, kernel_result: Dictionary) -> Dictionary:
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
							"damage": 0.0
						}
					},
					"units": {
						"a": [
							{
								"unit_id": SUBJECT_ID,
								"incoming": 0.0,
								"pre_mit_incoming": 0.0,
								"post_mit_incoming": 0.0,
								"time_alive_s": 2.0
							},
							{
								"unit_id": ALLY_ID,
								"incoming": 0.0,
								"pre_mit_incoming": 0.0,
								"post_mit_incoming": 0.0,
								"time_alive_s": 2.0
							}
						],
						"b": [
							{
								"unit_id": ENEMY_ID,
								"incoming": 0.0
							}
						]
					},
					"outcome": {
						"time_s": 2.0
					},
					"kernels": kernel_result
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

func _quit(code: int) -> void:
	if not do_quit_on_finish:
		return
	get_tree().quit(code)
