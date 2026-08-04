extends Node

const GoalPrimaryTest := preload("res://tests/rga_testing/metrics/goal/goal_primary_test.gd")
const RoleCommon := preload("res://tests/rga_testing/metrics/_shared/role_common.gd")

const GOAL_IDS: Array[String] = [
	"tank.frontline_absorb",
	"tank.team_fortification",
	"tank.initiate_fight",
	"tank.single_target_lockdown",
	"brawler.attrition_dps",
	"brawler.frontline_disruption",
	"brawler.skirmish_dive",
	"assassin.backline_elimination",
	"assassin.cleanup_execution",
	"assassin.disrupt_and_escape",
	"marksman.sustained_dps",
	"marksman.backline_siege",
	"marksman.tank_shredding",
	"mage.wombo_combo_burst",
	"mage.area_denial_zone",
	"mage.pick_burst",
	"mage.sustained_dps",
	"support.peel_carry",
	"support.team_amplification",
	"support.enemy_lockdown",
	"support.initiate_fight",
	"support.formation_breaking"
]

const EXPECTED_SPAN_PREFIXES: Dictionary = {
	"tank.frontline_absorb": "goal_frontline_absorb_",
	"tank.team_fortification": "goal_team_fortification_",
	"tank.initiate_fight": "goal_initiate_fight_",
	"tank.single_target_lockdown": "goal_single_target_lockdown_",
	"brawler.attrition_dps": "goal_attrition_dps_",
	"brawler.frontline_disruption": "goal_frontline_disruption_",
	"brawler.skirmish_dive": "goal_skirmish_dive_",
	"assassin.backline_elimination": "goal_backline_elimination_",
	"assassin.cleanup_execution": "goal_cleanup_execution_",
	"assassin.disrupt_and_escape": "goal_disrupt_escape_",
	"marksman.sustained_dps": "goal_marksman_sustained_dps_",
	"marksman.backline_siege": "goal_backline_siege_",
	"marksman.tank_shredding": "goal_tank_shredding_",
	"mage.wombo_combo_burst": "goal_wombo_combo_burst_",
	"mage.area_denial_zone": "goal_area_denial_zone_",
	"mage.pick_burst": "goal_pick_burst_",
	"mage.sustained_dps": "goal_mage_sustained_dps_",
	"support.peel_carry": "goal_peel_carry_",
	"support.team_amplification": "goal_team_amplification_",
	"support.enemy_lockdown": "goal_enemy_lockdown_",
	"support.initiate_fight": "goal_ally_initiate_",
	"support.formation_breaking": "goal_formation_breaking_"
}

@export var do_quit_on_finish: bool = true

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	RoleCommon.clear_identity_cache()
	var failed: bool = false
	for goal_id in GOAL_IDS:
		var subject_id: String = _subject_id(goal_id)
		_install_probe_identity(subject_id, goal_id)
		var positive_result: Dictionary = _run_goal(_positive_payload(goal_id, subject_id))
		var negative_result: Dictionary = _run_goal(_negative_payload(subject_id))
		var positive_pass: bool = bool(positive_result.get("pass", false))
		var negative_pass: bool = bool(negative_result.get("pass", false))
		var span_ok: bool = _has_span_prefix(positive_result, String(EXPECTED_SPAN_PREFIXES.get(goal_id, "")))
		print("GoalPrimaryCatalogProbe: goal=", goal_id,
			" positive=", positive_pass,
			" negative=", negative_pass,
			" span=", span_ok)
		if not positive_pass:
			printerr("GoalPrimaryCatalogProbe: FAIL positive payload did not pass for ", goal_id, " message=", String(positive_result.get("message", "")))
			failed = true
		if negative_pass:
			printerr("GoalPrimaryCatalogProbe: FAIL negative control passed for ", goal_id, " message=", String(negative_result.get("message", "")))
			failed = true
		if not span_ok:
			printerr("GoalPrimaryCatalogProbe: FAIL expected goal span prefix missing for ", goal_id)
			failed = true
	var soft_disrupt_subject: String = _subject_id("assassin.disrupt_and_escape")
	_install_probe_identity(soft_disrupt_subject, "assassin.disrupt_and_escape")
	var soft_disrupt_result: Dictionary = _run_goal(_soft_disrupt_payload(soft_disrupt_subject, 0.24, 4.0))
	var weak_slow_result: Dictionary = _run_goal(_soft_disrupt_payload(soft_disrupt_subject, 0.10, 4.0))
	if not bool(soft_disrupt_result.get("pass", false)):
		printerr("GoalPrimaryCatalogProbe: FAIL direct attack-speed slow did not satisfy disruption evidence")
		failed = true
	if bool(weak_slow_result.get("pass", false)):
		printerr("GoalPrimaryCatalogProbe: FAIL weak attack-speed slow satisfied disruption evidence")
		failed = true
	RoleCommon.clear_identity_cache()
	if failed:
		_quit(1)
		return
	print("GoalPrimaryCatalogProbe: PASS goals=", GOAL_IDS.size())
	_quit(0)

func _install_probe_identity(subject_id: String, goal_id: String) -> void:
	var parts: PackedStringArray = goal_id.split(".")
	var primary_role: String = String(parts[0]) if parts.size() > 0 else ""
	RoleCommon._identity_cache[subject_id] = {
		"unit_id": subject_id,
		"primary_role": primary_role,
		"primary_goal": goal_id,
		"approaches": [],
		"cost": 0,
		"level": 1
	}

func _run_goal(payload: Dictionary) -> Dictionary:
	var metric: Variant = GoalPrimaryTest.new()
	return metric.call("run_metric", payload)

func _positive_payload(goal_id: String, subject_id: String) -> Dictionary:
	var kernels: Dictionary = {}
	var derived: Dictionary = {}
	var subject_fields: Dictionary = {"time_alive_s": 10.0}
	var team_damage: float = 100.0
	var extra_allies: Array[Dictionary] = []

	match goal_id:
		"tank.frontline_absorb":
			subject_fields = _subject_fields({"incoming": 80.0, "pre_mit_incoming": 80.0, "post_mit_incoming": 50.0, "time_alive_s": 10.0})
			_add_subject_kernel(kernels, "redirect", subject_id, {
				"redirected_damage_prevented": 30.0,
				"body_block_events": 1,
				"body_block_damage_prevented": 30.0
			})
		"tank.team_fortification":
			subject_fields = _subject_fields({"pre_mit_incoming": 40.0, "post_mit_incoming": 10.0, "time_alive_s": 10.0})
			_add_subject_kernel(kernels, "buff_presence", subject_id, {
				"ally_buffs_to_others": 1,
				"ally_buff_magnitude_to_others": 30.0
			})
		"tank.initiate_fight":
			_add_subject_kernel(kernels, "control_mobility", subject_id, {
				"early_max_displacement_tiles": 1.5,
				"cc_unique_targets": 2,
				"first_action_s": 2.0
			})
		"tank.single_target_lockdown":
			_add_lockdown_kernel(kernels, subject_id, 2.0, 1)
		"brawler.attrition_dps":
			subject_fields = _subject_fields({"damage": 120.0, "pre_mit_incoming": 50.0, "post_mit_incoming": 20.0, "healing": 20.0, "time_alive_s": 10.0})
			team_damage = 200.0
			_add_subject_kernel(kernels, "per_unit_kpis", subject_id, {"damage_to_frontline_pct": 0.60})
			_add_ramp_kernel(kernels, subject_id)
		"brawler.frontline_disruption":
			_add_subject_kernel(kernels, "control_mobility", subject_id, {
				"cc_events": 1,
				"cc_unique_targets": 1
			})
			_add_subject_kernel(kernels, "disruption", subject_id, {
				"forced_reposition_events": 1,
				"target_swap_events": 1
			})
		"brawler.skirmish_dive":
			subject_fields = _subject_fields({"time_alive_s": 10.0})
			_add_subject_kernel(kernels, "per_unit_kpis", subject_id, {"damage_to_frontline_pct": 0.50})
		"assassin.backline_elimination":
			_add_subject_kernel(kernels, "control_mobility", subject_id, {"first_action_s": 2.0})
			_add_subject_kernel(kernels, "combat_patterns", subject_id, {
				"kill_count": 1,
				"peak_1s_dps": 40.0
			})
		"assassin.cleanup_execution":
			_add_subject_kernel(kernels, "combat_patterns", subject_id, {
				"low_hp_kill_count": 1,
				"low_hp_kill_share": 0.75,
				"overkill_rate": 0.20
			})
		"assassin.disrupt_and_escape":
			subject_fields = _subject_fields({"time_alive_s": 10.0})
			_add_subject_kernel(kernels, "control_mobility", subject_id, {"cc_seconds": 1.5})
			_add_subject_kernel(kernels, "targetability", subject_id, {
				"untargetable_windows": 1,
				"untargetable_frames_pct": 0.10,
				"key_threats_faced": 2,
				"key_threats_dodged": 1,
				"cooldown_trade_s": 2.0
			})
		"marksman.sustained_dps":
			subject_fields = _subject_fields({"damage": 80.0, "time_alive_s": 10.0})
			team_damage = 200.0
			_add_subject_kernel(kernels, "per_unit_kpis", subject_id, {
				"time_on_target_pct": 0.60,
				"attacks_over_2_tiles_pct": 0.70
			})
			_add_ramp_kernel(kernels, subject_id)
		"marksman.backline_siege":
			subject_fields = _subject_fields({"damage": 80.0, "incoming": 5.0, "time_alive_s": 10.0})
			team_damage = 200.0
			extra_allies = [_ally_unit("probe_ally_frontline", 0.0, 100.0)]
			_add_subject_kernel(kernels, "per_unit_kpis", subject_id, {
				"attacks_over_2_tiles_pct": 0.70,
				"damage_to_frontline_pct": 0.30
			})
		"marksman.tank_shredding":
			subject_fields = _subject_fields({"damage": 220.0, "time_alive_s": 10.0})
			team_damage = 300.0
			_add_subject_kernel(kernels, "per_unit_kpis", subject_id, {"damage_to_frontline_pct": 0.70})
			_add_subject_kernel(kernels, "buff_presence", subject_id, {"enemy_debuffs": 1})
		"mage.wombo_combo_burst":
			_add_subject_kernel(kernels, "combat_patterns", subject_id, {
				"peak_1s_damage_share": 0.30,
				"max_targets_hit": 3
			})
			_add_subject_kernel(kernels, "control_mobility", subject_id, {"cc_events": 1})
		"mage.area_denial_zone":
			_add_subject_kernel(kernels, "zone_exposure", subject_id, {
				"zone_exposure_events": 2,
				"zone_exposure_targets": 2,
				"zone_exposure_time_s": 2.0,
				"zone_exposure_damage": 24.0,
				"zone_radius_tiles_max": 2.0
			})
			_add_subject_kernel(kernels, "combat_patterns", subject_id, {"aoe_dps": 6.0})
		"mage.pick_burst":
			_add_subject_kernel(kernels, "combat_patterns", subject_id, {
				"peak_1s_dps": 40.0,
				"kill_count": 1,
				"counterplay_window_ms": 500.0
			})
		"mage.sustained_dps":
			subject_fields = _subject_fields({"damage": 80.0, "time_alive_s": 10.0})
			team_damage = 200.0
			_add_subject_kernel(kernels, "buff_presence", subject_id, {
				"dot_tick_events": 3,
				"dot_tick_damage": 30.0,
				"dot_uptime_s": 2.0,
				"dot_duration_applied_s": 3.0
			})
		"support.peel_carry":
			derived = {"a": {"peel_saves": 1}}
			_add_subject_kernel(kernels, "buff_presence", subject_id, {
				"ally_buffs_to_others": 1,
				"ally_buff_magnitude_to_others": 30.0,
				"cc_immunity_applied": 1
			})
		"support.team_amplification":
			subject_fields = _subject_fields({"damage": 5.0, "time_alive_s": 10.0})
			team_damage = 100.0
			_add_subject_kernel(kernels, "buff_presence", subject_id, {
				"ally_buffs_to_others": 1,
				"ally_buff_magnitude_to_others": 5.0,
				"amp_output_delta": 10.0,
				"amp_output_events": 1,
				"amp_output_beneficiaries": 1
			})
		"support.enemy_lockdown":
			_add_subject_kernel(kernels, "control_mobility", subject_id, {
				"cc_seconds": 3.0,
				"cc_unique_targets": 2
			})
			_add_lockdown_kernel(kernels, subject_id, 1.25, 1)
			_add_subject_kernel(kernels, "counterplay_pressure", subject_id, {"cleanse_bait_rate": 0.50})
		"support.initiate_fight":
			_add_subject_kernel(kernels, "buff_presence", subject_id, {"ally_buffs_to_others": 1})
			_add_subject_kernel(kernels, "control_mobility", subject_id, {
				"cc_seconds": 1.0,
				"first_action_s": 3.0
			})
		"support.formation_breaking":
			_add_subject_kernel(kernels, "disruption", subject_id, {
				"formation_break_events": 1,
				"forced_reposition_events": 1,
				"follow_up_kills": 1
			})
		_:
			pass

	return _base_payload(subject_id, subject_fields, kernels, team_damage, extra_allies, derived)

func _negative_payload(subject_id: String) -> Dictionary:
	return _base_payload(subject_id, _subject_fields({}), {}, 100.0, [], {})

func _soft_disrupt_payload(subject_id: String, slow_magnitude: float, slow_duration_s: float) -> Dictionary:
	var kernels: Dictionary = {}
	_add_subject_kernel(kernels, "buff_presence", subject_id, {
		"enemy_attack_speed_slow_events": 1,
		"enemy_attack_speed_slow_magnitude": slow_magnitude,
		"enemy_attack_speed_slow_duration_s": slow_duration_s
	})
	_add_subject_kernel(kernels, "targetability", subject_id, {
		"untargetable_windows": 1,
		"untargetable_frames_pct": 0.10,
		"key_threats_faced": 0,
		"key_threats_dodged": 0,
		"cooldown_trade_s": 0.0
	})
	return _base_payload(subject_id, _subject_fields({"time_alive_s": 10.0}), kernels, 100.0, [], {})

func _base_payload(subject_id: String, subject_fields: Dictionary, kernels: Dictionary, team_damage: float, extra_allies: Array[Dictionary], derived: Dictionary) -> Dictionary:
	var subject_unit: Dictionary = _subject_fields(subject_fields)
	subject_unit["unit_id"] = subject_id
	var team_a_units: Array[Dictionary] = [subject_unit]
	for ally in extra_allies:
		team_a_units.append(ally)
	var sim: Dictionary = {
		"context": {
			"team_a_ids": [subject_id],
			"team_b_ids": ["probe_enemy"]
		},
		"teams": {
			"a": {
				"damage": team_damage
			},
			"b": {
				"damage": 0.0
			}
		},
		"units": {
			"a": team_a_units,
			"b": [
				{
					"unit_id": "probe_enemy",
					"damage": 0.0,
					"incoming": 0.0,
					"time_alive_s": 10.0
				}
			]
		},
		"outcome": {
			"time_s": 10.0
		},
		"kernels": kernels
	}
	if not derived.is_empty():
		sim["derived"] = derived
	return {
		"context": {
			"scenario": "neutral",
			"sims": {
				"probe": sim
			}
		},
		"subject_unit_ids": [subject_id]
	}

func _subject_fields(overrides: Dictionary) -> Dictionary:
	var out: Dictionary = {
		"damage": 0.0,
		"incoming": 0.0,
		"pre_mit_incoming": 0.0,
		"post_mit_incoming": 0.0,
		"healing": 0.0,
		"shield": 0.0,
		"time_alive_s": 0.0
	}
	for key in overrides.keys():
		out[key] = overrides.get(key)
	return out

func _ally_unit(unit_id: String, damage: float, incoming: float) -> Dictionary:
	return {
		"unit_id": unit_id,
		"damage": damage,
		"incoming": incoming,
		"pre_mit_incoming": incoming,
		"post_mit_incoming": incoming,
		"time_alive_s": 10.0
	}

func _add_subject_kernel(kernels: Dictionary, kernel_key: String, subject_id: String, rec: Dictionary, supported: bool = true) -> void:
	var side_map: Dictionary = {}
	side_map[subject_id] = rec
	var block: Dictionary = {
		"per_unit": {
			"a": side_map,
			"b": {}
		}
	}
	if supported:
		block["supported"] = true
	kernels[kernel_key] = block

func _add_ramp_kernel(kernels: Dictionary, subject_id: String) -> void:
	_add_subject_kernel(kernels, "combat_patterns", subject_id, {
		"ramp_state_supported": true,
		"ramp_state_events": 2,
		"ramp_stack_max": 3,
		"ramp_time_to_peak_s": 3.0,
		"ramp_peak_duration_s": 2.0,
		"ramp_window_duration_s": 2.0
	})

func _add_lockdown_kernel(kernels: Dictionary, subject_id: String, seconds_on_priority: float, event_count: int) -> void:
	var side_map: Dictionary = {}
	side_map[subject_id] = {
		"seconds_on_priority": seconds_on_priority,
		"events": event_count
	}
	kernels["lockdown"] = {
		"a": {
			"per_unit": side_map
		},
		"b": {
			"per_unit": {}
		}
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

func _subject_id(goal_id: String) -> String:
	return "probe_goal_%s" % goal_id.replace(".", "_")

func _quit(code: int) -> void:
	if not do_quit_on_finish:
		return
	get_tree().quit(code)
