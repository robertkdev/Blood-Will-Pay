extends Node

const CombatEngineScript := preload("res://scripts/game/combat/combat_engine.gd")
const BattleStateScript := preload("res://scripts/game/combat/battle_state.gd")
const ZoneExposureKernel := preload("res://tests/rga_testing/aggregators/kernels/zone_exposure_kernel.gd")
const ZoneApproachTest := preload("res://tests/rga_testing/metrics/approach/zone_approach_test.gd")
const GoalPrimaryTest := preload("res://tests/rga_testing/metrics/goal/goal_primary_test.gd")

@export var do_quit_on_finish: bool = true

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var engine: CombatEngine = CombatEngineScript.new()
	var state: BattleState = _make_state()
	engine.state = state

	var kernel: Variant = ZoneExposureKernel.new()
	var team_sizes: Dictionary = {"a": 1, "b": 2}
	var context_tags: Dictionary = {
		"unit_timelines": {
			"a": [
				{
					"unit_index": 0,
					"unit_id": "cinder"
				}
			],
			"b": [
				{
					"unit_index": 0,
					"unit_id": "brute"
				},
				{
					"unit_index": 1,
					"unit_id": "korath"
				}
			]
		}
	}
	kernel.call("attach", engine, team_sizes, context_tags, true)

	engine._resolver_emit_zone_exposure_applied("player", 0, "enemy", 0, "lingering_zone", 1.50, 12.0, 2.0)
	engine._resolver_emit_zone_exposure_applied("player", 0, "enemy", 1, "lingering_zone", 1.00, 8.0, 2.0)
	kernel.call("finalize", 2.0)

	var result: Dictionary = kernel.call("result")
	var zone_block: Dictionary = result.get("zone_exposure", {}) if (result is Dictionary) else {}
	var per_unit: Dictionary = zone_block.get("per_unit", {}) if (zone_block is Dictionary) else {}
	var side_a: Dictionary = per_unit.get("a", {}) if (per_unit is Dictionary) else {}
	var rec: Dictionary = side_a.get("cinder", {}) if (side_a is Dictionary) else {}
	var approach_result: Dictionary = _run_approach_result(result)
	var goal_result: Dictionary = _run_goal_result(result)

	var supported: bool = bool(zone_block.get("supported", false))
	var events: int = int(rec.get("zone_exposure_events", 0))
	var targets: int = int(rec.get("zone_exposure_targets", 0))
	var exposure_time_s: float = float(rec.get("zone_exposure_time_s", 0.0))
	var damage: float = float(rec.get("zone_exposure_damage", 0.0))
	var radius: float = float(rec.get("zone_radius_tiles_max", 0.0))
	var approach_pass: bool = bool(approach_result.get("pass", false))
	var goal_pass: bool = bool(goal_result.get("pass", false))
	var approach_direct_span: bool = _has_span_prefix(approach_result, "subject_zone_exposure_events")
	var goal_direct_span: bool = _has_span_prefix(goal_result, "goal_area_denial_zone_exposure_events")

	print("ZoneExposureKernelProbe: supported=", supported,
		" events=", events,
		" targets=", targets,
		" exposure_time_s=", exposure_time_s,
		" damage=", damage,
		" radius=", radius,
		" approach_pass=", approach_pass,
		" goal_pass=", goal_pass)

	var failed: bool = false
	if not supported:
		printerr("ZoneExposureKernelProbe: FAIL zone exposure signal was not connected")
		failed = true
	if events != 2 or targets != 2:
		printerr("ZoneExposureKernelProbe: FAIL exposure events or unique targets were not recorded")
		failed = true
	if exposure_time_s < 2.49 or damage < 19.9 or radius < 1.99:
		printerr("ZoneExposureKernelProbe: FAIL exposure time, damage, or radius was not recorded")
		failed = true
	if not approach_pass or not approach_direct_span:
		printerr("ZoneExposureKernelProbe: FAIL approach_zone did not pass on direct zone exposure")
		failed = true
	if not goal_pass or not goal_direct_span:
		printerr("ZoneExposureKernelProbe: FAIL goal_primary did not consume direct area-denial zone exposure")
		failed = true

	kernel.call("detach")
	if failed:
		_quit(1)
		return
	print("ZoneExposureKernelProbe: PASS")
	_quit(0)

func _make_state() -> BattleState:
	var state: BattleState = BattleStateScript.new()
	var cinder: Unit = Unit.new()
	cinder.id = "cinder"
	cinder.max_hp = 1000
	cinder.hp = 1000
	var brute: Unit = Unit.new()
	brute.id = "brute"
	brute.max_hp = 1000
	brute.hp = 1000
	var korath: Unit = Unit.new()
	korath.id = "korath"
	korath.max_hp = 1000
	korath.hp = 1000
	var player_team: Array[Unit] = [cinder]
	var enemy_team: Array[Unit] = [brute, korath]
	state.player_team = player_team
	state.enemy_team = enemy_team
	return state

func _run_approach_result(kernel_result: Dictionary) -> Dictionary:
	var metric: Variant = ZoneApproachTest.new()
	return metric.call("run_metric", _base_payload(kernel_result, false))

func _run_goal_result(kernel_result: Dictionary) -> Dictionary:
	var metric: Variant = GoalPrimaryTest.new()
	return metric.call("run_metric", _base_payload(kernel_result, true))

func _base_payload(kernel_result: Dictionary, include_goal_support: bool) -> Dictionary:
	var kernels: Dictionary = kernel_result.duplicate(true)
	if include_goal_support:
		kernels["combat_patterns"] = {
			"per_unit": {
				"a": {
					"cinder": {
						"aoe_dps": 6.0,
						"multi_target_groups": 1,
						"max_targets_hit": 2
					}
				}
			}
		}
		kernels["disruption"] = {
			"supported": true,
			"per_unit": {
				"a": {
					"cinder": {
						"forced_reposition_events": 0,
						"formation_break_events": 0
					}
				}
			}
		}
	return {
		"context": {
			"scenario": "neutral",
			"sims": {
				"probe": {
					"context": {
						"team_a_ids": ["cinder"],
						"team_b_ids": ["brute", "korath"]
					},
					"outcome": {
						"time_s": 2.0
					},
					"teams": {
						"a": {
							"damage": 20.0
						},
						"b": {
							"damage": 0.0
						}
					},
					"units": {
						"a": [
							{
								"unit_id": "cinder",
								"damage": 20.0,
								"incoming": 0.0,
								"pre_mit_incoming": 0.0,
								"post_mit_incoming": 0.0,
								"time_alive_s": 2.0
							}
						],
						"b": [
							{
								"unit_id": "brute",
								"incoming": 12.0,
								"pre_mit_incoming": 12.0
							},
							{
								"unit_id": "korath",
								"incoming": 8.0,
								"pre_mit_incoming": 8.0
							}
						]
					},
					"kernels": kernels
				}
			}
		},
		"subject_unit_ids": ["cinder"]
	}

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
