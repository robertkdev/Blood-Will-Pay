extends Node

const CombatEngineScript := preload("res://scripts/game/combat/combat_engine.gd")
const BattleStateScript := preload("res://scripts/game/combat/battle_state.gd")
const RedirectKernel := preload("res://tests/rga_testing/aggregators/kernels/redirect_kernel.gd")
const RedirectApproachTest := preload("res://tests/rga_testing/metrics/approach/redirect_approach_test.gd")

@export var do_quit_on_finish: bool = true

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
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
					"unit_id": "korath"
				},
				{
					"unit_index": 1,
					"unit_id": "brute"
				}
			],
			"b": [
				{
					"unit_index": 0,
					"unit_id": "mara"
				}
			]
		}
	}
	kernel.call("attach", engine, team_sizes, context_tags, true)

	engine.emit_signal("target_start", "enemy", 0, "player", 1)
	kernel.call("tick", 0.50)
	engine.emit_signal("target_end", "enemy", 0, "player", 1)
	engine.emit_signal("target_start", "enemy", 0, "player", 0)
	kernel.call("tick", 1.25)
	engine.emit_signal("target_end", "enemy", 0, "player", 0)
	engine._resolver_emit_redirect_semantic_applied("player", 0, "enemy", 0, "taunt", 1.0, 0.0, 0.0)
	engine._resolver_emit_redirect_semantic_applied("player", 0, "enemy", 0, "body_block", 0.5, 18.0, 0.75)
	kernel.call("finalize", 2.0)

	var result: Dictionary = kernel.call("result")
	var redirect_block: Dictionary = result.get("redirect", {}) if (result is Dictionary) else {}
	var per_unit: Dictionary = redirect_block.get("per_unit", {}) if (redirect_block is Dictionary) else {}
	var side_a: Dictionary = per_unit.get("a", {}) if (per_unit is Dictionary) else {}
	var rec: Dictionary = side_a.get("korath", {}) if (side_a is Dictionary) else {}
	var metric_result: Dictionary = _run_metric_result(result)

	var supported: bool = bool(redirect_block.get("supported", false))
	var focus_start_events: int = int(rec.get("focus_start_events", 0))
	var target_swap_events: int = int(rec.get("target_swap_to_subject_events", 0))
	var focus_time_s: float = float(rec.get("enemy_focus_time_s", 0.0))
	var taunt_events: int = int(rec.get("taunt_events", 0))
	var body_block_events: int = int(rec.get("body_block_events", 0))
	var body_block_prevented: float = float(rec.get("body_block_damage_prevented", 0.0))
	var end_risk_events: int = int(rec.get("redirect_end_risk_events", 0))
	var end_risk_s: float = float(rec.get("redirect_end_risk_s", 0.0))
	var metric_pass: bool = bool(metric_result.get("pass", false))
	var metric_direct_span: bool = _has_span_prefix(metric_result, "subject_redirect_target_swap_events")
	var metric_semantic_span: bool = _has_span_prefix(metric_result, "subject_redirect_body_block_events")

	print("RedirectThreatKernelProbe: supported=", supported,
		" focus_starts=", focus_start_events,
		" target_swaps=", target_swap_events,
		" focus_time_s=", focus_time_s,
		" taunts=", taunt_events,
		" body_blocks=", body_block_events,
		" body_block_prevented=", body_block_prevented,
		" end_risk_events=", end_risk_events,
		" end_risk_s=", end_risk_s,
		" metric_pass=", metric_pass)

	var failed: bool = false
	if not supported:
		printerr("RedirectThreatKernelProbe: FAIL redirect target signals were not connected")
		failed = true
	if focus_start_events != 1 or target_swap_events != 1:
		printerr("RedirectThreatKernelProbe: FAIL focus start or target swap was not recorded")
		failed = true
	if focus_time_s < 1.24:
		printerr("RedirectThreatKernelProbe: FAIL enemy focus duration was not recorded")
		failed = true
	if taunt_events != 1 or body_block_events != 1:
		printerr("RedirectThreatKernelProbe: FAIL taunt or body-block semantic events were not recorded")
		failed = true
	if body_block_prevented < 17.9 or end_risk_events != 1 or end_risk_s < 0.74:
		printerr("RedirectThreatKernelProbe: FAIL body-block prevention or redirect end-risk was not recorded")
		failed = true
	if not metric_pass:
		printerr("RedirectThreatKernelProbe: FAIL approach_redirect did not pass on direct threat-swap telemetry")
		failed = true
	if not metric_direct_span:
		printerr("RedirectThreatKernelProbe: FAIL approach_redirect did not emit the target-swap span")
		failed = true
	if not metric_semantic_span:
		printerr("RedirectThreatKernelProbe: FAIL approach_redirect did not emit the body-block semantic span")
		failed = true

	kernel.call("detach")
	if failed:
		_quit(1)
		return
	print("RedirectThreatKernelProbe: PASS")
	_quit(0)

func _make_state() -> BattleState:
	var state: BattleState = BattleStateScript.new()
	var korath: Unit = Unit.new()
	korath.id = "korath"
	korath.max_hp = 1000
	korath.hp = 1000
	var brute: Unit = Unit.new()
	brute.id = "brute"
	brute.max_hp = 1000
	brute.hp = 1000
	var enemy: Unit = Unit.new()
	enemy.id = "mara"
	enemy.max_hp = 1000
	enemy.hp = 1000
	var player_team: Array[Unit] = [korath, brute]
	var enemy_team: Array[Unit] = [enemy]
	state.player_team = player_team
	state.enemy_team = enemy_team
	return state

func _run_metric_result(kernel_result: Dictionary) -> Dictionary:
	var metric: Variant = RedirectApproachTest.new()
	var payload: Dictionary = {
		"context": {
			"scenario": "neutral",
			"sims": {
				"probe": {
					"context": {
						"team_a_ids": ["korath", "brute"],
						"team_b_ids": ["mara"]
					},
					"kernels": kernel_result,
					"units": {
						"a": [
							{
								"unit_id": "korath",
								"incoming": 0.0,
								"pre_mit_incoming": 0.0
							},
							{
								"unit_id": "brute",
								"incoming": 0.0,
								"pre_mit_incoming": 0.0
							}
						],
						"b": [
							{
								"unit_id": "mara",
								"incoming": 0.0,
								"pre_mit_incoming": 0.0
							}
						]
					}
				}
			}
		},
		"subject_unit_ids": ["korath"]
	}
	return metric.call("run_metric", payload)

func _has_span_prefix(metric_result: Dictionary, prefix: String) -> bool:
	var spans: Array = metric_result.get("spans", []) if (metric_result is Dictionary) else []
	for span_value in spans:
		if not (span_value is Dictionary):
			continue
		var label: String = String((span_value as Dictionary).get("label", ""))
		if label.begins_with(prefix):
			return true
	return false

func _quit(code: int) -> void:
	if not do_quit_on_finish:
		return
	get_tree().quit(code)
