extends RefCounted

# Goal: primary win condition (per-unit subject)
# Evaluates the subject's assigned primary_goal against goal-specific KPI bundles
# from the design doc. This is intentionally goal-level: approach metrics remain
# separate toolkit checks.

const VERSION: String = "1.0.0"
const METRIC_ID: String = "goal_primary"

const RoleCommon := preload("res://tests/rga_testing/metrics/_shared/role_common.gd")

const REQUIRED_CAPS: Array[String] = ["base", "targets", "mobility", "zones", "buffs", "cc"]

func get_metadata() -> Dictionary:
	return {
		"id": METRIC_ID,
		"version": VERSION,
		"required_capabilities": REQUIRED_CAPS,
		"description": "primary goal: direct goal-level win-condition checks for the subject's assigned primary_goal."
	}

func run_metric(payload: Dictionary = {}) -> Dictionary:
	var ctx: Dictionary = payload.get("context", {})
	var sims: Dictionary = ctx.get("sims", {}) if (ctx is Dictionary) else {}
	if sims.is_empty():
		return RoleCommon.fail_result([], ["no_sims_in_context"])
	var subject_set: Dictionary = RoleCommon.subject_set_from_payload(payload)
	if subject_set.is_empty():
		return RoleCommon.fail_result([], ["no_subject_specified"])
	var subject_id: String = String(subject_set.keys()[0])
	var ident: Dictionary = RoleCommon.get_identity(subject_id)
	var goal_id: String = String(ident.get("primary_goal", "")).strip_edges().to_lower()
	if goal_id == "":
		return RoleCommon.fail_result([], ["subject_has_no_primary_goal"])
	var scenario_label: String = String(ctx.get("scenario", "neutral"))
	var summary: Dictionary = _summarize_subject(sims, subject_id)
	summary["has_ramp_approach"] = _identity_has_approach(ident, "ramp")
	if int(summary.get("samples", 0)) <= 0:
		return RoleCommon.fail_result([], ["no_subject_samples"])
	var spans: Array = []
	var pass_flag: bool = false
	match goal_id:
		"tank.frontline_absorb":
			pass_flag = _eval_frontline_absorb(summary, spans)
		"tank.team_fortification":
			pass_flag = _eval_team_fortification(summary, spans)
		"tank.initiate_fight":
			pass_flag = _eval_self_initiate(summary, spans)
		"tank.single_target_lockdown":
			pass_flag = _eval_single_target_lockdown(summary, spans)
		"brawler.attrition_dps":
			pass_flag = _eval_attrition_dps(summary, spans)
		"brawler.frontline_disruption":
			pass_flag = _eval_frontline_disruption(summary, spans)
		"brawler.skirmish_dive":
			pass_flag = _eval_skirmish_dive(summary, spans)
		"assassin.backline_elimination":
			pass_flag = _eval_backline_elimination(summary, spans)
		"assassin.cleanup_execution":
			pass_flag = _eval_cleanup_execution(summary, spans)
		"assassin.disrupt_and_escape":
			pass_flag = _eval_disrupt_and_escape(summary, spans)
		"marksman.sustained_dps":
			pass_flag = _eval_marksman_sustained_dps(summary, spans)
		"marksman.backline_siege":
			pass_flag = _eval_backline_siege(summary, spans)
		"marksman.tank_shredding":
			pass_flag = _eval_tank_shredding(summary, spans)
		"mage.wombo_combo_burst":
			pass_flag = _eval_wombo_combo_burst(summary, spans)
		"mage.area_denial_zone":
			pass_flag = _eval_area_denial_zone(summary, spans)
		"mage.pick_burst":
			pass_flag = _eval_pick_burst(summary, spans)
		"mage.sustained_dps":
			pass_flag = _eval_mage_sustained_dps(summary, spans)
		"support.peel_carry":
			pass_flag = _eval_peel_carry(summary, spans)
		"support.team_amplification":
			pass_flag = _eval_team_amplification(summary, spans)
		"support.enemy_lockdown":
			pass_flag = _eval_enemy_lockdown(summary, spans)
		"support.initiate_fight":
			pass_flag = _eval_ally_initiate(summary, spans)
		"support.formation_breaking":
			pass_flag = _eval_formation_breaking(summary, spans)
		_:
			_append_span(spans, summary, "goal_unmapped", 0.0, 1.0, false, "no_goal_metric_mapping")
			pass_flag = false
	return {
		"id": METRIC_ID,
		"version": VERSION,
		"pass": pass_flag,
		"spans": spans,
		"message": "goal=%s; scenario=%s; samples=%d; direct_goal_metric=1" % [goal_id, scenario_label, int(summary.get("samples", 0))]
	}

func _eval_frontline_absorb(summary: Dictionary, spans: Array) -> bool:
	var incoming_share: float = _incoming_share(summary)
	var share_ok: bool = incoming_share >= 0.30
	var prevented_value: float = _prevented_damage(summary) + float(summary.get("redirected_damage_prevented", 0.0))
	var prevented_ok: bool = prevented_value >= 25.0
	var body_block_damage: float = float(summary.get("body_block_damage_prevented", 0.0))
	var body_block_events: int = int(summary.get("body_block_events", 0))
	var body_block_direct: bool = body_block_events >= 1 and body_block_damage >= 25.0
	var redirect_events: int = int(summary.get("redirect_events", 0))
	var redirected_damage: float = float(summary.get("redirected_damage_prevented", 0.0))
	var redirect_direct: bool = redirect_events >= 1 and redirected_damage >= 25.0
	var direct_absorb_semantic: bool = body_block_direct or redirect_direct
	var frontline_value: float = float(summary.get("frontline_zone_share", 0.0))
	var frontline_ok: bool = frontline_value >= 0.50
	var has_direct_absorb_semantic: bool = body_block_events > 0 or redirect_events > 0
	var pass_flag: bool = prevented_ok and direct_absorb_semantic if has_direct_absorb_semantic else _k_of_n([share_ok, prevented_ok, frontline_ok], 2)
	var alternate_evidence_reason: String = "alternate_frontline_evidence_satisfied"
	var share_span_ok: Variant = share_ok
	var body_block_events_span_ok: Variant = body_block_events >= 1
	var body_block_damage_span_ok: Variant = body_block_direct
	var share_reason: String = ""
	var body_block_reason: String = "direct_redirect_semantic"
	if pass_flag and body_block_events <= 0:
		share_reason = "direct_redirect_semantic" if redirect_direct else alternate_evidence_reason
		body_block_reason = share_reason
		if not share_ok:
			share_span_ok = null
		if body_block_events < 1:
			body_block_events_span_ok = null
		if not body_block_direct:
			body_block_damage_span_ok = null
	_append_span(spans, summary, "goal_frontline_absorb_damage_taken_share", incoming_share, 0.30, share_span_ok, share_reason)
	_append_span(spans, summary, "goal_frontline_absorb_ally_damage_prevented", prevented_value, 25.0, prevented_ok)
	_append_span(spans, summary, "goal_frontline_absorb_body_block_events", float(body_block_events), 1.0, body_block_events_span_ok, body_block_reason)
	_append_span(spans, summary, "goal_frontline_absorb_body_block_damage_prevented", body_block_damage, 25.0, body_block_damage_span_ok, body_block_reason)
	_append_span(spans, summary, "goal_frontline_absorb_frontline_zone_share", frontline_value, 0.50, frontline_ok, "frontline_zone_proxy")
	if has_direct_absorb_semantic:
		return prevented_ok and direct_absorb_semantic
	return pass_flag

func _eval_team_fortification(summary: Dictionary, spans: Array) -> bool:
	var ehp_per_s: float = _effective_ehp(summary) / max(1.0, float(summary.get("fight_time_s", 0.0)))
	var ehp_ok: bool = _append_span(spans, summary, "goal_team_fortification_team_ehp_per_s", ehp_per_s, 2.0, ehp_per_s >= 2.0)
	var fortification_targets: int = max(int(summary.get("ally_buffs", 0)), int(summary.get("ally_buffs_to_others", 0)))
	var buff_targets_ok: bool = _append_span(spans, summary, "goal_team_fortification_buff_uptime_targets", float(fortification_targets), 1.0, fortification_targets >= 1, "source_owned_team_fortification_target")
	var prevented_per_s: float = _prevented_damage(summary) / max(1.0, float(summary.get("fight_time_s", 0.0)))
	var prevented_ok: bool = _append_span(spans, summary, "goal_team_fortification_damage_prevented_per_s", prevented_per_s, 1.0, prevented_per_s >= 1.0)
	return _k_of_n([ehp_ok, buff_targets_ok, prevented_ok], 2)

func _eval_self_initiate(summary: Dictionary, spans: Array) -> bool:
	var distance_value: float = float(summary.get("early_max_displacement_tiles", 0.0))
	var first_action_value: float = float(summary.get("first_action_s", 99.0))
	var distance_ok: bool = distance_value >= 1.0
	var success_value: float = max(float(summary.get("cc_unique_targets", 0)), float(summary.get("max_targets_hit", 0)))
	var success_ok: bool = success_value >= 2.0
	var first_action_ok: bool = _non_negative_at_most(float(summary.get("first_action_s", -1.0)), 5.0)
	var pass_flag: bool = _k_of_n([distance_ok, success_ok, first_action_ok], 2)
	var success_span_ok: Variant = success_ok
	var success_reason: String = ""
	if pass_flag and distance_ok and first_action_ok and not success_ok:
		success_span_ok = null
		success_reason = "alternate_initiate_evidence_satisfied"
	_append_span(spans, summary, "goal_initiate_fight_engage_distance", distance_value, 1.0, distance_ok)
	_append_span(spans, summary, "goal_initiate_fight_engage_success_targets", success_value, 2.0, success_span_ok, success_reason)
	_append_span(spans, summary, "goal_initiate_fight_first_action_s", first_action_value, 5.0, first_action_ok)
	return pass_flag

func _eval_single_target_lockdown(summary: Dictionary, spans: Array) -> bool:
	var seconds_ok: bool = _append_span(spans, summary, "goal_single_target_lockdown_seconds_on_priority", float(summary.get("lockdown_seconds_on_priority", 0.0)), 1.0, float(summary.get("lockdown_seconds_on_priority", 0.0)) >= 1.0)
	var coverage: float = float(summary.get("lockdown_seconds_on_priority", 0.0)) / max(1.0, float(summary.get("fight_time_s", 0.0)))
	var coverage_ok: bool = _append_span(spans, summary, "goal_single_target_lockdown_cc_coverage_ratio", coverage, 0.10, coverage >= 0.10)
	var events_ok: bool = _append_span(spans, summary, "goal_single_target_lockdown_events_on_priority", float(summary.get("lockdown_events_on_priority", 0)), 1.0, int(summary.get("lockdown_events_on_priority", 0)) >= 1)
	var counterplay_value: float = float(summary.get("cleanse_pressure_events", 0)) + float(summary.get("tenacity_tax_events", 0)) + float(summary.get("cc_prevented_by_immunity", 0))
	var counterplay_ok: bool = _append_span(spans, summary, "goal_single_target_lockdown_cleanse_tenacity_tax", counterplay_value, 1.0, counterplay_value >= 1.0)
	return _k_of_n([seconds_ok, coverage_ok, events_ok, counterplay_ok], 1)

func _eval_attrition_dps(summary: Dictionary, spans: Array) -> bool:
	var frontline_ok: bool = _append_span(spans, summary, "goal_attrition_dps_damage_to_frontline_share", float(summary.get("damage_to_frontline_pct", 0.0)), 0.40, float(summary.get("damage_to_frontline_pct", 0.0)) >= 0.40)
	var sustain_ok: bool = _append_span(spans, summary, "goal_attrition_dps_sustain_effective_hps", _effective_ehp(summary) / max(1.0, float(summary.get("time_alive_s", 0.0))), 2.0, (_effective_ehp(summary) / max(1.0, float(summary.get("time_alive_s", 0.0)))) >= 2.0)
	var persistence_ok: bool = _goal_ramp_ok(summary, spans, "goal_attrition_dps")
	var survival_ok: bool = _append_span(spans, summary, "goal_attrition_dps_self_survival_s", float(summary.get("time_alive_s", 0.0)), 8.0, float(summary.get("time_alive_s", 0.0)) >= 8.0)
	return _k_of_n([frontline_ok, sustain_ok, persistence_ok, survival_ok], 2)

func _eval_frontline_disruption(summary: Dictionary, spans: Array) -> bool:
	var cc_ok: bool = _append_span(spans, summary, "goal_frontline_disruption_disrupt_events", float(summary.get("cc_events", 0)), 1.0, int(summary.get("cc_events", 0)) >= 1)
	var targets_ok: bool = _append_span(spans, summary, "goal_frontline_disruption_unique_targets", float(summary.get("cc_unique_targets", 0)), 1.0, int(summary.get("cc_unique_targets", 0)) >= 1)
	var enemy_response: float = float(summary.get("forced_reposition_events", 0)) + float(summary.get("target_swap_events", 0)) + float(summary.get("formation_break_events", 0))
	var movement_ok: bool = false
	if _has_direct_disruption(summary):
		movement_ok = _append_span(spans, summary, "goal_frontline_disruption_enemy_response_events", enemy_response, 1.0, enemy_response >= 1.0)
	else:
		movement_ok = _append_span(spans, summary, "goal_frontline_disruption_enemy_reposition_proxy", float(summary.get("early_max_displacement_tiles", 0.0)), 0.75, float(summary.get("early_max_displacement_tiles", 0.0)) >= 0.75, "uses_subject_displacement_until_enemy_reposition_exists")
	return _k_of_n([cc_ok, targets_ok, movement_ok], 2)

func _eval_skirmish_dive(summary: Dictionary, spans: Array) -> bool:
	var damage_contact_value: float = float(summary.get("backline_damage_share", max(0.0, 1.0 - float(summary.get("damage_to_frontline_pct", 1.0)))))
	var direct_contact_frac: float = _backline_contact_fraction(summary)
	var contact_value: float = max(damage_contact_value, direct_contact_frac)
	var contact_reason: String = "direct_backline_access" if direct_contact_frac > damage_contact_value else ""
	var contact_ok: bool = _append_span(spans, summary, "goal_skirmish_dive_backline_contact_proxy", contact_value, 0.25, contact_value >= 0.25, contact_reason)
	var escape_ok: bool = _append_span(spans, summary, "goal_skirmish_dive_escape_survival_s", float(summary.get("time_alive_s", 0.0)), 8.0, float(summary.get("time_alive_s", 0.0)) >= 8.0)
	var cooldown_ok: bool = false
	if _has_direct_cooldown_pressure(summary):
		var forced_ok: bool = _append_span(spans, summary, "goal_skirmish_dive_cooldowns_forced_s", float(summary.get("cooldowns_forced_s", 0.0)), 1.0, float(summary.get("cooldowns_forced_s", 0.0)) >= 1.0)
		var threat_draw_ok: bool = _append_span(spans, summary, "goal_skirmish_dive_threat_draw_events", float(summary.get("cooldown_threat_draw_events", 0)), 1.0, int(summary.get("cooldown_threat_draw_events", 0)) >= 1, "direct_cooldown_pressure")
		_append_span(spans, summary, "goal_skirmish_dive_threat_draw_casters", float(summary.get("cooldown_threat_draw_casters", 0)), 1.0, int(summary.get("cooldown_threat_draw_casters", 0)) >= 1, "direct_cooldown_pressure")
		_append_span(spans, summary, "goal_skirmish_dive_key_threat_share", float(summary.get("cooldown_key_threat_share", 0.0)), 0.50, float(summary.get("cooldown_key_threat_share", 0.0)) >= 0.50, "direct_cooldown_pressure")
		cooldown_ok = forced_ok or threat_draw_ok
	else:
		cooldown_ok = _append_span(spans, summary, "goal_skirmish_dive_threat_draw_proxy", float(summary.get("cc_events", 0)) + float(summary.get("total_path_tiles", 0.0)), 1.0, (float(summary.get("cc_events", 0)) + float(summary.get("total_path_tiles", 0.0))) >= 1.0, "cooldowns_spent_not_yet_direct")
	return _k_of_n([contact_ok, escape_ok, cooldown_ok], 2)

func _eval_backline_elimination(summary: Dictionary, spans: Array) -> bool:
	var contact_ok: bool = _append_span(spans, summary, "goal_backline_elimination_first_action_s", float(summary.get("first_action_s", 99.0)), 5.0, _non_negative_at_most(float(summary.get("first_action_s", -1.0)), 5.0))
	var kill_ok: bool = _append_span(spans, summary, "goal_backline_elimination_kill_count", float(summary.get("kill_count", 0)), 1.0, int(summary.get("kill_count", 0)) >= 1)
	var burst_ok: bool = _append_span(spans, summary, "goal_backline_elimination_peak_1s_dps", float(summary.get("peak_1s_dps", 0.0)), 35.0, float(summary.get("peak_1s_dps", 0.0)) >= 35.0)
	return _k_of_n([contact_ok, kill_ok, burst_ok], 2)

func _eval_cleanup_execution(summary: Dictionary, spans: Array) -> bool:
	var kills_ok: bool = _append_span(spans, summary, "goal_cleanup_execution_low_hp_kills", float(summary.get("low_hp_kill_count", 0)), 1.0, int(summary.get("low_hp_kill_count", 0)) >= 1)
	var share_ok: bool = _append_span(spans, summary, "goal_cleanup_execution_low_hp_conversion_rate", float(summary.get("low_hp_kill_share", 0.0)), 0.50, float(summary.get("low_hp_kill_share", 0.0)) >= 0.50)
	var overkill_ok: bool = _append_span(spans, summary, "goal_cleanup_execution_overkill_rate", float(summary.get("overkill_rate", 0.0)), 0.60, float(summary.get("overkill_rate", 0.0)) <= 0.60)
	return _k_of_n([kills_ok, share_ok, overkill_ok], 2)

func _eval_disrupt_and_escape(summary: Dictionary, spans: Array) -> bool:
	var cc_seconds: float = float(summary.get("cc_seconds", 0.0))
	var cc_disrupt_ok: bool = cc_seconds >= 1.0
	var slow_events: int = int(summary.get("enemy_attack_speed_slow_events", 0))
	var slow_magnitude_total: float = float(summary.get("enemy_attack_speed_slow_magnitude", 0.0))
	var slow_duration_total_s: float = float(summary.get("enemy_attack_speed_slow_duration_s", 0.0))
	var slow_magnitude_avg: float = slow_magnitude_total / max(1.0, float(slow_events))
	var slow_duration_avg_s: float = slow_duration_total_s / max(1.0, float(slow_events))
	var slow_disrupt_ok: bool = slow_events >= 1 and slow_magnitude_avg >= 0.20 and slow_duration_avg_s >= 1.0
	var disrupt_ok: bool = cc_disrupt_ok or slow_disrupt_ok
	var cc_span_ok: Variant = cc_disrupt_ok
	var cc_reason: String = ""
	if slow_disrupt_ok and not cc_disrupt_ok:
		cc_span_ok = null
		cc_reason = "alternate_direct_attack_speed_slow_evidence"
	_append_span(spans, summary, "goal_disrupt_escape_disruption_time", cc_seconds, 1.0, cc_span_ok, cc_reason)
	var slow_span_ok: Variant = slow_disrupt_ok
	var slow_reason: String = "direct_attack_speed_slow_evidence"
	if cc_disrupt_ok and not slow_disrupt_ok:
		slow_span_ok = null
		slow_reason = "alternate_direct_cc_evidence"
	_append_span(spans, summary, "goal_disrupt_escape_attack_speed_slow_events", float(slow_events), 1.0, slow_span_ok, slow_reason)
	_append_span(spans, summary, "goal_disrupt_escape_attack_speed_slow_avg_magnitude", slow_magnitude_avg, 0.20, slow_span_ok, slow_reason)
	_append_span(spans, summary, "goal_disrupt_escape_attack_speed_slow_avg_duration_s", slow_duration_avg_s, 1.0, slow_span_ok, slow_reason)
	var escape_ok: bool = _append_span(spans, summary, "goal_disrupt_escape_survival_s", float(summary.get("time_alive_s", 0.0)), 8.0, float(summary.get("time_alive_s", 0.0)) >= 8.0)
	if _has_direct_targetability(summary):
		var frames_ok: bool = _append_span(spans, summary, "goal_disrupt_escape_untargetable_frames_pct", float(summary.get("untargetable_frames_pct", 0.0)), 0.05, float(summary.get("untargetable_frames_pct", 0.0)) >= 0.05)
		var dodge_rate: float = _key_threat_dodge_rate(summary)
		var threat_ok: bool = _append_span(spans, summary, "goal_disrupt_escape_key_threat_dodge_rate", dodge_rate, 0.50, dodge_rate >= 0.50)
		var cooldown_ok: bool = _append_span(spans, summary, "goal_disrupt_escape_cooldown_trade_s", float(summary.get("cooldown_trade_s", 0.0)), 1.0, float(summary.get("cooldown_trade_s", 0.0)) >= 1.0)
		return _k_of_n([disrupt_ok, escape_ok, frames_ok, threat_ok, cooldown_ok], 3)
	if _has_direct_cooldown_pressure(summary):
		var forced_ok: bool = _append_span(spans, summary, "goal_disrupt_escape_cooldowns_forced_s", float(summary.get("cooldowns_forced_s", 0.0)), 1.0, float(summary.get("cooldowns_forced_s", 0.0)) >= 1.0)
		_append_span(spans, summary, "goal_disrupt_escape_threat_draw_events", float(summary.get("cooldown_threat_draw_events", 0)), 1.0, int(summary.get("cooldown_threat_draw_events", 0)) >= 1, "direct_cooldown_pressure")
		_append_span(spans, summary, "goal_disrupt_escape_key_threat_share", float(summary.get("cooldown_key_threat_share", 0.0)), 0.50, float(summary.get("cooldown_key_threat_share", 0.0)) >= 0.50, "direct_cooldown_pressure")
		return _k_of_n([disrupt_ok, escape_ok, forced_ok], 2)
	var damage_taken_ok: bool = _append_span(spans, summary, "goal_disrupt_escape_incoming_share_proxy", _incoming_share(summary), 0.45, _incoming_share(summary) <= 0.45, "targetability_window_telemetry_missing")
	return _k_of_n([disrupt_ok, escape_ok, damage_taken_ok], 2)

func _eval_marksman_sustained_dps(summary: Dictionary, spans: Array) -> bool:
	var damage_share: float = _damage_share(summary)
	var sustained_team_share: float = float(summary.get("sustained_3_10s_team_share", 0.0))
	var sustained_rate: float = float(summary.get("sustained_3_10s_rate", 0.0))
	var sustained_team_share_ok: bool = _append_span(spans, summary, "goal_marksman_sustained_dps_sustained_3_10s_team_share", sustained_team_share, 0.25, sustained_team_share >= 0.25, "direct_sustained_window")
	var sustained_rate_ok: bool = _append_span(spans, summary, "goal_marksman_sustained_dps_sustained_3_10s_rate", sustained_rate, 8.0, sustained_rate >= 8.0, "direct_sustained_window")
	var sustained_window_ok: bool = sustained_team_share_ok and sustained_rate_ok
	var damage_share_ok: bool = damage_share >= 0.25
	var damage_share_span_ok: Variant = damage_share_ok
	var damage_share_reason: String = ""
	if not damage_share_ok and sustained_window_ok:
		damage_share_span_ok = null
		damage_share_reason = "alternate_sustained_window_evidence_satisfied"
	_append_span(spans, summary, "goal_marksman_sustained_dps_team_damage_share", damage_share, 0.25, damage_share_span_ok, damage_share_reason)
	_append_span(spans, summary, "goal_marksman_sustained_dps_early_0_3s_share", float(summary.get("early_0_3s_share", 0.0)), 0.50, null, "diagnostic_not_pass_condition")
	_append_span(spans, summary, "goal_marksman_sustained_dps_sustained_3_10s_own_share", float(summary.get("sustained_3_10s_share", 0.0)), 0.30, null, "diagnostic_not_pass_condition")
	var uptime_ok: bool = _append_span(spans, summary, "goal_marksman_sustained_dps_time_on_target", float(summary.get("time_on_target_pct", 0.0)), 0.40, float(summary.get("time_on_target_pct", 0.0)) >= 0.40)
	var range_ok: bool = _append_span(spans, summary, "goal_marksman_sustained_dps_attacks_over_2_tiles", float(summary.get("attacks_over_2_tiles_pct", 0.0)), 0.50, float(summary.get("attacks_over_2_tiles_pct", 0.0)) >= 0.50)
	var survival_ok: bool = _append_span(spans, summary, "goal_marksman_sustained_dps_survival_s", float(summary.get("time_alive_s", 0.0)), 8.0, float(summary.get("time_alive_s", 0.0)) >= 8.0)
	var ramp_ok: bool = _goal_ramp_ok(summary, spans, "goal_marksman_sustained_dps")
	return _k_of_n([damage_share_ok or sustained_window_ok, uptime_ok, range_ok, survival_ok, ramp_ok], 2)

func _eval_backline_siege(summary: Dictionary, spans: Array) -> bool:
	var long_range_damage_share: float = float(summary.get("damage_over_2_tiles_pct", summary.get("attacks_over_2_tiles_pct", 0.0)))
	var range_ok: bool = _append_span(spans, summary, "goal_backline_siege_long_range_damage_share", long_range_damage_share, 0.60, long_range_damage_share >= 0.60)
	var exposure_ok: bool = _append_span(spans, summary, "goal_backline_siege_pressure_without_exposure", _incoming_share(summary), 0.25, _incoming_share(summary) <= 0.25)
	var damage_ok: bool = _append_span(spans, summary, "goal_backline_siege_team_damage_share", _damage_share(summary), 0.20, _damage_share(summary) >= 0.20)
	var backline_damage_share: float = float(summary.get("backline_damage_share", 0.0))
	var backline_ok: bool = _append_span(spans, summary, "goal_backline_siege_backline_damage_share", backline_damage_share, 0.55, backline_damage_share >= 0.55)
	return _k_of_n([range_ok, exposure_ok, damage_ok, backline_ok], 2)

func _eval_tank_shredding(summary: Dictionary, spans: Array) -> bool:
	var frontline_ok: bool = _append_span(spans, summary, "goal_tank_shredding_damage_to_frontline", float(summary.get("damage_to_frontline_pct", 0.0)), 0.50, float(summary.get("damage_to_frontline_pct", 0.0)) >= 0.50)
	var damage_ok: bool = _append_span(spans, summary, "goal_tank_shredding_post_mit_damage", float(summary.get("damage", 0.0)), 200.0, float(summary.get("damage", 0.0)) >= 200.0)
	var debuff_ok: bool = _append_span(spans, summary, "goal_tank_shredding_pen_or_debuff_events", float(summary.get("enemy_debuffs", 0)), 1.0, int(summary.get("enemy_debuffs", 0)) >= 1)
	return _k_of_n([frontline_ok, damage_ok, debuff_ok], 2)

func _eval_wombo_combo_burst(summary: Dictionary, spans: Array) -> bool:
	var burst_ok: bool = float(summary.get("peak_1s_damage_share", 0.0)) >= 0.25
	var targets_ok: bool = int(summary.get("max_targets_hit", 0)) >= 2
	var sync_ok: bool = int(summary.get("cc_events", 0)) >= 1
	var pass_flag: bool = _k_of_n([burst_ok, targets_ok, sync_ok], 2)
	var burst_span_ok: Variant = burst_ok
	var targets_span_ok: Variant = targets_ok
	var sync_span_ok: Variant = sync_ok
	var burst_reason: String = ""
	var targets_reason: String = ""
	var sync_reason: String = "cc_sync_rate_not_yet_direct"
	if pass_flag:
		if not burst_ok:
			burst_span_ok = null
			burst_reason = "alternate_wombo_evidence_satisfied"
		if not targets_ok:
			targets_span_ok = null
			targets_reason = "alternate_wombo_evidence_satisfied"
		if not sync_ok:
			sync_span_ok = null
			sync_reason = "alternate_wombo_evidence_satisfied"
	_append_span(spans, summary, "goal_wombo_combo_burst_peak_1s_share", float(summary.get("peak_1s_damage_share", 0.0)), 0.25, burst_span_ok, burst_reason)
	_append_span(spans, summary, "goal_wombo_combo_burst_targets_hit", float(summary.get("max_targets_hit", 0)), 2.0, targets_span_ok, targets_reason)
	_append_span(spans, summary, "goal_wombo_combo_burst_cc_sync_proxy", float(summary.get("cc_events", 0)), 1.0, sync_span_ok, sync_reason)
	return pass_flag

func _eval_area_denial_zone(summary: Dictionary, spans: Array) -> bool:
	var zone_ok: bool = false
	if _has_direct_zone_exposure(summary):
		var events_ok: bool = _append_span(spans, summary, "goal_area_denial_zone_exposure_events", float(summary.get("zone_exposure_events", 0)), 1.0, int(summary.get("zone_exposure_events", 0)) >= 1, "direct_zone_exposure")
		var targets_ok: bool = _append_span(spans, summary, "goal_area_denial_zone_exposure_targets", float(summary.get("zone_exposure_targets", 0)), 1.0, int(summary.get("zone_exposure_targets", 0)) >= 1, "direct_zone_exposure")
		var time_ok: bool = _append_span(spans, summary, "goal_area_denial_zone_exposure_time_s", float(summary.get("zone_exposure_time_s", 0.0)), 1.0, float(summary.get("zone_exposure_time_s", 0.0)) >= 1.0, "direct_zone_exposure")
		var damage_ok: bool = _append_span(spans, summary, "goal_area_denial_zone_exposure_damage", float(summary.get("zone_exposure_damage", 0.0)), 1.0, float(summary.get("zone_exposure_damage", 0.0)) >= 1.0, "direct_zone_exposure")
		var radius_ok: bool = _append_span(spans, summary, "goal_area_denial_zone_radius_tiles_max", float(summary.get("zone_radius_tiles_max", 0.0)), 1.0, float(summary.get("zone_radius_tiles_max", 0.0)) >= 1.0, "direct_zone_exposure")
		zone_ok = events_ok and _k_of_n([targets_ok, time_ok, damage_ok, radius_ok], 1)
		_append_span(spans, summary, "goal_area_denial_zone_zone_occupancy_proxy", float(summary.get("frontline_zone_share", 0.0)) + float(summary.get("backline_zone_share", 0.0)), 0.55, (float(summary.get("frontline_zone_share", 0.0)) + float(summary.get("backline_zone_share", 0.0))) >= 0.55, "positioning_fallback_diagnostic")
	else:
		zone_ok = _append_span(spans, summary, "goal_area_denial_zone_zone_occupancy", float(summary.get("frontline_zone_share", 0.0)) + float(summary.get("backline_zone_share", 0.0)), 0.55, (float(summary.get("frontline_zone_share", 0.0)) + float(summary.get("backline_zone_share", 0.0))) >= 0.55)
	var aoe_ok: bool = _append_span(spans, summary, "goal_area_denial_zone_aoe_dps", float(summary.get("aoe_dps", 0.0)), 5.0, float(summary.get("aoe_dps", 0.0)) >= 5.0)
	var reposition_ok: bool = false
	if _has_direct_disruption(summary):
		var reposition_events: float = float(summary.get("forced_reposition_events", 0)) + float(summary.get("formation_break_events", 0))
		reposition_ok = _append_span(spans, summary, "goal_area_denial_zone_forced_reposition_events", reposition_events, 1.0, reposition_events >= 1.0)
	else:
		reposition_ok = _append_span(spans, summary, "goal_area_denial_zone_forced_reposition_proxy", float(summary.get("cc_unique_targets", 0)) + float(summary.get("multi_target_groups", 0)), 1.0, (int(summary.get("cc_unique_targets", 0)) + int(summary.get("multi_target_groups", 0))) >= 1, "forced_reposition_not_yet_direct")
	return _k_of_n([zone_ok, aoe_ok, reposition_ok], 2)

func _eval_pick_burst(summary: Dictionary, spans: Array) -> bool:
	var burst_ok: bool = _append_span(spans, summary, "goal_pick_burst_peak_1s_dps", float(summary.get("peak_1s_dps", 0.0)), 35.0, float(summary.get("peak_1s_dps", 0.0)) >= 35.0)
	var kill_ok: bool = _append_span(spans, summary, "goal_pick_burst_kill_count", float(summary.get("kill_count", 0)), 1.0, int(summary.get("kill_count", 0)) >= 1)
	var counterplay_value: float = float(summary.get("counterplay_window_ms", -1.0))
	var counterplay_ok: bool = _append_span(spans, summary, "goal_pick_burst_counterplay_window_ms", counterplay_value, 400.0, counterplay_value <= 0.0 or counterplay_value >= 400.0)
	return _k_of_n([burst_ok, kill_ok, counterplay_ok], 2)

func _eval_mage_sustained_dps(summary: Dictionary, spans: Array) -> bool:
	var damage_share: float = _damage_share(summary)
	var sustained_team_share: float = float(summary.get("sustained_3_10s_team_share", 0.0))
	var sustained_rate: float = float(summary.get("sustained_3_10s_rate", 0.0))
	var sustained_team_share_ok: bool = _append_span(spans, summary, "goal_mage_sustained_dps_sustained_3_10s_team_share", sustained_team_share, 0.20, sustained_team_share >= 0.20, "direct_sustained_window")
	var sustained_rate_ok: bool = _append_span(spans, summary, "goal_mage_sustained_dps_sustained_3_10s_rate", sustained_rate, 8.0, sustained_rate >= 8.0, "direct_sustained_window")
	var sustained_window_ok: bool = sustained_team_share_ok and sustained_rate_ok
	var damage_share_ok: bool = damage_share >= 0.20
	var damage_share_span_ok: Variant = damage_share_ok
	var damage_share_reason: String = ""
	if not damage_share_ok and sustained_window_ok:
		damage_share_span_ok = null
		damage_share_reason = "alternate_sustained_window_evidence_satisfied"
	_append_span(spans, summary, "goal_mage_sustained_dps_team_damage_share", damage_share, 0.20, damage_share_span_ok, damage_share_reason)
	var dot_ok: bool = _goal_dot_ok(summary, spans, "goal_mage_sustained_dps")
	var zone_ok: bool = _goal_zone_ok(summary, spans, "goal_mage_sustained_dps")
	var ramp_ok: bool = _goal_ramp_ok(summary, spans, "goal_mage_sustained_dps")
	var on_hit_ok: bool = _goal_on_hit_ok(summary, spans, "goal_mage_sustained_dps")
	_append_span(spans, summary, "goal_mage_sustained_dps_aoe_dps_diagnostic", float(summary.get("aoe_dps", 0.0)), 5.0, float(summary.get("aoe_dps", 0.0)) >= 5.0, "diagnostic_not_pass_condition")
	return (damage_share_ok or sustained_window_ok) and (dot_ok or zone_ok or ramp_ok or on_hit_ok)

func _eval_peel_carry(summary: Dictionary, spans: Array) -> bool:
	var saves_ok: bool = _append_span(spans, summary, "goal_peel_carry_peel_saves", float(summary.get("team_peel_saves", 0)), 1.0, int(summary.get("team_peel_saves", 0)) >= 1)
	var carry_ehp_ok: bool = _append_span(spans, summary, "goal_peel_carry_damage_prevented_on_carry", _effective_ehp(summary), 25.0, _effective_ehp(summary) >= 25.0)
	var cc_ok: bool = _append_span(spans, summary, "goal_peel_carry_interrupt_events", float(summary.get("cc_events", 0)), 1.0, int(summary.get("cc_events", 0)) >= 1)
	var ally_protection_events: float = float(summary.get("ally_buffs_to_others", 0)) + float(summary.get("cleanse_applied", 0))
	var direct_protection_ok: bool = _append_span(spans, summary, "goal_peel_carry_ally_protection_events", ally_protection_events, 1.0, ally_protection_events >= 1.0, "direct_support_utility")
	var protection_magnitude: float = float(summary.get("ally_buff_magnitude_to_others", 0.0))
	var magnitude_ok: bool = _append_span(spans, summary, "goal_peel_carry_ally_protection_magnitude", protection_magnitude, 25.0, protection_magnitude >= 25.0, "direct_support_utility")
	_append_span(spans, summary, "goal_peel_carry_cc_immunity_applied", float(summary.get("cc_immunity_applied", 0)), 1.0, int(summary.get("cc_immunity_applied", 0)) >= 1, "direct_support_utility")
	if _has_direct_cooldown_pressure(summary):
		var cooldown_value: float = float(summary.get("cooldowns_forced_s", 0.0))
		var cooldown_ok: bool = _append_span(spans, summary, "goal_peel_carry_counter_cooldown_trade_s", cooldown_value, 1.0, cooldown_value >= 1.0)
		var threat_draw_ok: bool = int(summary.get("cooldown_threat_draw_casters", 0)) >= 1
		var key_threat_ok: bool = float(summary.get("cooldown_key_threat_share", 0.0)) >= 0.50
		var efficiency_value: float = float(summary.get("cooldown_trade_efficiency", 0.0))
		var efficiency_raw_ok: bool = efficiency_value >= 1.0
		var efficiency_span_ok: Variant = efficiency_raw_ok
		var efficiency_reason: String = "direct_cooldown_pressure"
		if not efficiency_raw_ok and cooldown_ok and threat_draw_ok and key_threat_ok:
			efficiency_span_ok = null
			efficiency_reason = "alternate_cooldown_trade_evidence_satisfied"
		var efficiency_ok: bool = _append_span(spans, summary, "goal_peel_carry_cooldown_trade_efficiency", efficiency_value, 1.0, efficiency_span_ok, efficiency_reason)
		_append_span(spans, summary, "goal_peel_carry_threat_draw_casters", float(summary.get("cooldown_threat_draw_casters", 0)), 1.0, threat_draw_ok, "direct_cooldown_pressure")
		cooldown_ok = cooldown_ok or efficiency_ok
		return _k_of_n([saves_ok, carry_ehp_ok, cc_ok, direct_protection_ok, magnitude_ok, cooldown_ok], 1)
	return _k_of_n([saves_ok, carry_ehp_ok, cc_ok, direct_protection_ok, magnitude_ok], 1)

func _eval_team_amplification(summary: Dictionary, spans: Array) -> bool:
	var buff_ok: bool = _append_span(spans, summary, "goal_team_amplification_buff_uptime_targets", float(summary.get("ally_buffs_to_others", 0)), 1.0, int(summary.get("ally_buffs_to_others", 0)) >= 1)
	var magnitude_ok: bool = _append_span(spans, summary, "goal_team_amplification_amp_delta_team", float(summary.get("ally_buff_magnitude_to_others", 0.0)), 1.0, float(summary.get("ally_buff_magnitude_to_others", 0.0)) >= 1.0)
	var output_ok: bool = _append_span(spans, summary, "goal_team_amplification_amp_output_delta", float(summary.get("amp_output_delta", 0.0)), 1.0, float(summary.get("amp_output_delta", 0.0)) >= 1.0, "direct_buff_output")
	var opportunity_ok: bool = _append_span(spans, summary, "goal_team_amplification_opportunity_cost_proxy", _damage_share(summary), 0.20, _damage_share(summary) <= 0.20, "opportunity_cost_not_yet_direct")
	return _k_of_n([buff_ok, magnitude_ok, output_ok, opportunity_ok], 2)

func _eval_enemy_lockdown(summary: Dictionary, spans: Array) -> bool:
	var multi_ok: bool = _append_span(spans, summary, "goal_enemy_lockdown_multi_target_lockdown_seconds", float(summary.get("cc_seconds", 0.0)), 2.0, float(summary.get("cc_seconds", 0.0)) >= 2.0)
	var stagger_ok: bool = _append_span(spans, summary, "goal_enemy_lockdown_stagger_unique_targets", float(summary.get("cc_unique_targets", 0)), 2.0, int(summary.get("cc_unique_targets", 0)) >= 2)
	var priority_ok: bool = _append_span(spans, summary, "goal_enemy_lockdown_priority_controlled_time", float(summary.get("lockdown_seconds_on_priority", 0.0)), 1.0, float(summary.get("lockdown_seconds_on_priority", 0.0)) >= 1.0)
	var cleanse_ok: bool = _append_span(spans, summary, "goal_enemy_lockdown_cleanse_bait_rate", float(summary.get("cleanse_bait_rate", 0.0)), 0.25, float(summary.get("cleanse_bait_rate", 0.0)) >= 0.25)
	return _k_of_n([multi_ok, stagger_ok, priority_ok, cleanse_ok], 2)

func _eval_ally_initiate(summary: Dictionary, spans: Array) -> bool:
	var enable_ok: bool = _append_span(spans, summary, "goal_ally_initiate_enable_rate_proxy", float(summary.get("ally_buffs_to_others", 0)), 1.0, int(summary.get("ally_buffs_to_others", 0)) >= 1, "ally_enable_conversion_not_yet_direct")
	var window_ok: bool = _append_span(spans, summary, "goal_ally_initiate_ally_damage_window_proxy", float(summary.get("cc_seconds", 0.0)), 1.0, float(summary.get("cc_seconds", 0.0)) >= 1.0)
	var fail_ok: bool = _append_span(spans, summary, "goal_ally_initiate_first_action_s", float(summary.get("first_action_s", 99.0)), 6.0, _non_negative_at_most(float(summary.get("first_action_s", -1.0)), 6.0))
	return _k_of_n([enable_ok, window_ok, fail_ok], 2)

func _eval_formation_breaking(summary: Dictionary, spans: Array) -> bool:
	if not _has_direct_disruption(summary):
		var spread_proxy_ok: bool = _append_span(spans, summary, "goal_formation_breaking_spread_proxy", float(summary.get("cc_unique_targets", 0)), 2.0, int(summary.get("cc_unique_targets", 0)) >= 2, "formation_spread_not_yet_direct")
		var reposition_proxy_ok: bool = _append_span(spans, summary, "goal_formation_breaking_enemy_reposition_proxy", float(summary.get("cc_events", 0)) + float(summary.get("early_max_displacement_tiles", 0.0)), 1.0, (int(summary.get("cc_events", 0)) + float(summary.get("early_max_displacement_tiles", 0.0))) >= 1.0)
		var follow_proxy_ok: bool = _append_span(spans, summary, "goal_formation_breaking_follow_up_kill_rate_proxy", float(summary.get("kill_count", 0)), 1.0, int(summary.get("kill_count", 0)) >= 1, "follow_up_kill_rate_not_yet_direct")
		return _k_of_n([spread_proxy_ok, reposition_proxy_ok, follow_proxy_ok], 2)
	var spread_ok: bool = _append_span(spans, summary, "goal_formation_breaking_formation_break_events", float(summary.get("formation_break_events", 0)), 1.0, int(summary.get("formation_break_events", 0)) >= 1)
	var reposition_value: float = float(summary.get("forced_reposition_events", 0)) + float(summary.get("target_swap_events", 0))
	var reposition_ok: bool = _append_span(spans, summary, "goal_formation_breaking_enemy_response_events", reposition_value, 1.0, reposition_value >= 1.0)
	var follow_ok: bool = _append_span(spans, summary, "goal_formation_breaking_follow_up_kills", float(summary.get("follow_up_kills", 0)), 1.0, int(summary.get("follow_up_kills", 0)) >= 1)
	return _k_of_n([spread_ok, reposition_ok, follow_ok], 2)

func _summarize_subject(sims: Dictionary, subject_id: String) -> Dictionary:
	var summary: Dictionary = {
		"unit_id": subject_id,
		"subject_side": "",
		"samples": 0,
		"damage": 0.0,
		"team_damage": 0.0,
		"incoming": 0.0,
		"team_incoming": 0.0,
		"pre_mit_incoming": 0.0,
		"post_mit_incoming": 0.0,
		"healing": 0.0,
		"shield": 0.0,
		"time_alive_s": 0.0,
		"fight_time_s": 0.0,
		"team_peel_saves": 0
	}
	var first_action_values: Array[float] = []
	for key in sims.keys():
		var entry: Dictionary = sims.get(key, {})
		var side: String = _subject_side(entry, subject_id)
		if side == "":
			continue
		if String(summary.get("subject_side", "")) == "":
			summary["subject_side"] = side
		summary["samples"] = int(summary.get("samples", 0)) + 1
		var unit_rec: Dictionary = _subject_unit(entry, side, subject_id)
		_add_unit_totals(summary, unit_rec)
		summary["team_damage"] = float(summary.get("team_damage", 0.0)) + _team_value(entry, side, "damage")
		summary["team_incoming"] = float(summary.get("team_incoming", 0.0)) + _team_incoming(entry, side)
		summary["fight_time_s"] = float(summary.get("fight_time_s", 0.0)) + _fight_time(entry)
		_merge_pattern(summary, _subject_kernel_rec(entry, side, subject_id, "combat_patterns"))
		_merge_control(summary, _subject_kernel_rec(entry, side, subject_id, "control_mobility"), first_action_values)
		_merge_per_unit_kpis(summary, _subject_kernel_rec(entry, side, subject_id, "per_unit_kpis"))
		_merge_buffs(summary, _subject_kernel_rec(entry, side, subject_id, "buff_presence"))
		_merge_redirect(summary, _subject_kernel_rec(entry, side, subject_id, "redirect"))
		_merge_targetability(summary, _subject_kernel_rec(entry, side, subject_id, "targetability"))
		_merge_cooldown_pressure(summary, _subject_kernel_rec(entry, side, subject_id, "cooldown_pressure"))
		_merge_counterplay_pressure(summary, _subject_kernel_rec(entry, side, subject_id, "counterplay_pressure"))
		_merge_lockdown(summary, entry, side, subject_id)
		_merge_positioning(summary, entry, side)
		var kernels: Dictionary = entry.get("kernels", {})
		if RoleCommon.kernel_supported(kernels, "zone_exposure"):
			summary["direct_zone_exposure_supported"] = true
		_merge_zone_exposure(summary, _subject_kernel_rec(entry, side, subject_id, "zone_exposure"))
		_merge_support(summary, entry, side, subject_id)
		_merge_disruption(summary, entry, side, subject_id)
		_merge_backline_access(summary, entry, side, subject_id)
	if int(summary.get("samples", 0)) > 0:
		var samples: float = float(summary.get("samples", 1))
		summary["time_alive_s"] = float(summary.get("time_alive_s", 0.0)) / samples
		summary["fight_time_s"] = float(summary.get("fight_time_s", 0.0)) / samples
		summary["first_action_s"] = RoleCommon.median(first_action_values)
	return summary

func _add_unit_totals(summary: Dictionary, unit_rec: Dictionary) -> void:
	if unit_rec.is_empty():
		return
	for key in ["damage", "incoming", "pre_mit_incoming", "post_mit_incoming", "healing", "shield"]:
		summary[key] = float(summary.get(key, 0.0)) + float(unit_rec.get(key, 0.0))
	summary["time_alive_s"] = float(summary.get("time_alive_s", 0.0)) + float(unit_rec.get("time_alive_s", 0.0))

func _merge_pattern(summary: Dictionary, rec: Dictionary) -> void:
	for key in ["total_damage", "peak_1s_damage", "peak_1s_damage_share", "peak_1s_dps", "counterplay_window_ms", "overkill_rate", "kill_count", "low_hp_kill_count", "low_hp_kill_share", "max_targets_hit", "multi_target_groups", "aoe_dps", "late_early_dps_ratio", "early_0_3s_share", "sustained_3_10s_share", "sustained_3_10s_rate", "sustained_3_10s_team_share", "sustained_3_10s_window_s"]:
		if rec.has(key):
			summary[key] = max(float(summary.get(key, 0.0)), float(rec.get(key, 0.0)))
	if bool(rec.get("ramp_state_supported", false)):
		summary["direct_ramp_state_supported"] = true
	if rec.has("ramp_state_events"):
		summary["ramp_state_events"] = int(summary.get("ramp_state_events", 0)) + int(rec.get("ramp_state_events", 0))
	for ramp_key in ["ramp_stack_max", "ramp_peak_duration_s", "ramp_window_duration_s", "ramp_time_to_peak_s"]:
		if rec.has(ramp_key):
			summary[ramp_key] = max(float(summary.get(ramp_key, 0.0)), float(rec.get(ramp_key, 0.0)))

func _merge_control(summary: Dictionary, rec: Dictionary, first_action_values: Array[float]) -> void:
	for key in ["cc_seconds", "cc_events", "cc_unique_targets", "early_max_displacement_tiles", "total_path_tiles", "max_step_tiles", "post_cast_displacement_tiles"]:
		if rec.has(key):
			summary[key] = max(float(summary.get(key, 0.0)), float(rec.get(key, 0.0)))
	var first_action: float = float(rec.get("first_action_s", -1.0))
	if first_action >= 0.0:
		first_action_values.append(first_action)

func _merge_per_unit_kpis(summary: Dictionary, rec: Dictionary) -> void:
	for key in ["time_on_target_pct", "attack_distance_median_tiles", "attacks_over_2_tiles_pct", "damage_over_2_tiles_pct", "damage_to_frontline_pct", "kiting_tax"]:
		if rec.has(key):
			summary[key] = max(float(summary.get(key, 0.0)), float(rec.get(key, 0.0)))
	if rec.has("damage_to_frontline_pct"):
		var backline_damage_share: float = max(0.0, 1.0 - float(rec.get("damage_to_frontline_pct", 1.0)))
		summary["backline_damage_share"] = max(float(summary.get("backline_damage_share", 0.0)), backline_damage_share)

func _merge_buffs(summary: Dictionary, rec: Dictionary) -> void:
	for key in ["ally_buffs", "ally_buffs_to_others", "ally_buff_magnitude_to_others", "amp_output_events", "amp_output_delta", "amp_output_pct_total", "amp_output_beneficiaries", "enemy_debuffs", "enemy_debuff_magnitude", "enemy_attack_speed_slow_events", "enemy_attack_speed_slow_magnitude", "enemy_attack_speed_slow_duration_s", "cc_immunity_applied", "cc_prevented", "cleanse_applied"]:
		if rec.has(key):
			summary[key] = float(summary.get(key, 0.0)) + float(rec.get(key, 0.0))
	for key in ["on_hit_effects", "dot_tick_events", "dot_tick_targets", "dot_application_events"]:
		if rec.has(key):
			summary[key] = int(summary.get(key, 0)) + int(rec.get(key, 0))
	for key in ["on_hit_magnitude", "dot_tick_damage", "dot_duration_applied_s", "dot_uptime_s"]:
		if rec.has(key):
			summary[key] = float(summary.get(key, 0.0)) + float(rec.get(key, 0.0))
	if rec.has("cc_immunity"):
		summary["cc_immunity_applied"] = float(summary.get("cc_immunity_applied", 0.0)) + float(rec.get("cc_immunity", 0.0))

func _merge_redirect(summary: Dictionary, rec: Dictionary) -> void:
	for key in ["redirect_events", "redirected_damage_prevented", "ally_damage_prevented", "body_block_events", "body_block_damage_prevented", "redirect_end_risk_events", "redirect_end_risk_s"]:
		if rec.has(key):
			summary[key] = float(summary.get(key, 0.0)) + float(rec.get(key, 0.0))

func _merge_targetability(summary: Dictionary, rec: Dictionary) -> void:
	if rec.is_empty():
		return
	for key_float in ["untargetable_time_s", "cooldown_trade_s"]:
		if rec.has(key_float):
			summary[key_float] = float(summary.get(key_float, 0.0)) + float(rec.get(key_float, 0.0))
	for key_max in ["untargetable_frames_pct", "key_threat_dodge_rate", "threat_dodge_rate"]:
		if rec.has(key_max):
			summary[key_max] = max(float(summary.get(key_max, 0.0)), float(rec.get(key_max, 0.0)))
	for key_int in ["untargetable_windows", "key_threats_faced", "key_threats_dodged", "threats_faced", "threats_dodged"]:
		if rec.has(key_int):
			summary[key_int] = int(summary.get(key_int, 0)) + int(rec.get(key_int, 0))

func _merge_cooldown_pressure(summary: Dictionary, rec: Dictionary) -> void:
	if rec.is_empty():
		return
	for key_float_sum in ["cooldowns_forced_s", "self_cooldown_s", "cooldown_threat_draw_s", "cooldown_trade_efficiency_denominator_s"]:
		if rec.has(key_float_sum):
			summary[key_float_sum] = float(summary.get(key_float_sum, 0.0)) + float(rec.get(key_float_sum, 0.0))
	for key_float_max in ["cooldown_trade_efficiency", "cooldown_key_threat_share"]:
		if rec.has(key_float_max):
			summary[key_float_max] = max(float(summary.get(key_float_max, 0.0)), float(rec.get(key_float_max, 0.0)))
	for key_int_sum in ["cooldowns_forced", "key_cooldowns_forced", "self_cooldowns_spent", "cooldown_threat_draw_events"]:
		if rec.has(key_int_sum):
			summary[key_int_sum] = int(summary.get(key_int_sum, 0)) + int(rec.get(key_int_sum, 0))
	for key_int_max in ["cooldown_threat_draw_casters", "cooldown_threat_draw_abilities"]:
		if rec.has(key_int_max):
			summary[key_int_max] = max(int(summary.get(key_int_max, 0)), int(rec.get(key_int_max, 0)))

func _merge_counterplay_pressure(summary: Dictionary, rec: Dictionary) -> void:
	if rec.is_empty():
		return
	for key_float_sum in ["tenacity_tax_s", "cc_raw_duration_s", "cc_effective_duration_s"]:
		if rec.has(key_float_sum):
			summary[key_float_sum] = float(summary.get(key_float_sum, 0.0)) + float(rec.get(key_float_sum, 0.0))
	for key_float in ["cleanse_bait_rate", "max_tenacity_seen"]:
		if rec.has(key_float):
			summary[key_float] = max(float(summary.get(key_float, 0.0)), float(rec.get(key_float, 0.0)))
	for key_int in ["debuffs_applied_for_counterplay", "cleanse_pressure_events", "cleanse_pressure_removed", "cleanse_bait_events", "cleansed_debuffs", "tenacity_tax_events", "cc_prevented_by_immunity"]:
		if rec.has(key_int):
			summary[key_int] = int(summary.get(key_int, 0)) + int(rec.get(key_int, 0))

func _merge_lockdown(summary: Dictionary, entry: Dictionary, side: String, subject_id: String) -> void:
	var kernels: Dictionary = entry.get("kernels", {})
	var lockdown: Dictionary = kernels.get("lockdown", {}) if (kernels is Dictionary) else {}
	var side_block: Dictionary = lockdown.get(side, {}) if (lockdown is Dictionary) else {}
	var per_unit: Dictionary = side_block.get("per_unit", {}) if (side_block is Dictionary) else {}
	var rec: Dictionary = per_unit.get(subject_id, {}) if (per_unit is Dictionary) else {}
	if rec is Dictionary:
		summary["lockdown_seconds_on_priority"] = float(summary.get("lockdown_seconds_on_priority", 0.0)) + float(rec.get("seconds_on_priority", 0.0))
		summary["lockdown_events_on_priority"] = int(summary.get("lockdown_events_on_priority", 0)) + int(rec.get("events", 0))

func _merge_positioning(summary: Dictionary, entry: Dictionary, side: String) -> void:
	var kernels: Dictionary = entry.get("kernels", {})
	var positioning: Dictionary = kernels.get("positioning", {}) if (kernels is Dictionary) else {}
	var side_block: Dictionary = positioning.get(side, {}) if (positioning is Dictionary) else {}
	if side_block is Dictionary:
		summary["frontline_zone_share"] = max(float(summary.get("frontline_zone_share", 0.0)), float(side_block.get("frontline_zone_share", 0.0)))
		summary["backline_zone_share"] = max(float(summary.get("backline_zone_share", 0.0)), float(side_block.get("backline_zone_share", 0.0)))

func _merge_zone_exposure(summary: Dictionary, rec: Dictionary) -> void:
	if rec.is_empty():
		return
	summary["direct_zone_exposure_supported"] = true
	for key_float_sum in ["zone_exposure_time_s", "zone_exposure_damage"]:
		if rec.has(key_float_sum):
			summary[key_float_sum] = float(summary.get(key_float_sum, 0.0)) + float(rec.get(key_float_sum, 0.0))
	for key_float_max in ["zone_radius_tiles_max"]:
		if rec.has(key_float_max):
			summary[key_float_max] = max(float(summary.get(key_float_max, 0.0)), float(rec.get(key_float_max, 0.0)))
	for key_int_sum in ["zone_exposure_events"]:
		if rec.has(key_int_sum):
			summary[key_int_sum] = int(summary.get(key_int_sum, 0)) + int(rec.get(key_int_sum, 0))
	for key_int_max in ["zone_exposure_targets"]:
		if rec.has(key_int_max):
			summary[key_int_max] = max(int(summary.get(key_int_max, 0)), int(rec.get(key_int_max, 0)))

func _merge_support(summary: Dictionary, entry: Dictionary, side: String, subject_id: String) -> void:
	var derived: Dictionary = entry.get("derived", {})
	var side_derived: Dictionary = derived.get(side, {}) if (derived is Dictionary) else {}
	if side_derived is Dictionary:
		summary["team_peel_saves"] = int(summary.get("team_peel_saves", 0)) + int(side_derived.get("peel_saves", 0))
	var kernels: Dictionary = entry.get("kernels", {})
	var support: Dictionary = kernels.get("support", {}) if (kernels is Dictionary) else {}
	var heal_map: Dictionary = support.get("healing_per_unit", {}) if (support is Dictionary) else {}
	var side_heal: Dictionary = heal_map.get(side, {}) if (heal_map is Dictionary) else {}
	var heal_rec: Dictionary = side_heal.get(subject_id, {}) if (side_heal is Dictionary) else {}
	if heal_rec is Dictionary:
		summary["healing"] = float(summary.get("healing", 0.0)) + float(heal_rec.get("healed", 0.0))
	var shield_map: Dictionary = support.get("shield_absorbed_per_unit", {}) if (support is Dictionary) else {}
	var side_shield: Dictionary = shield_map.get(side, {}) if (shield_map is Dictionary) else {}
	var shield_rec: Dictionary = side_shield.get(subject_id, {}) if (side_shield is Dictionary) else {}
	if shield_rec is Dictionary:
		summary["shield"] = float(summary.get("shield", 0.0)) + float(shield_rec.get("absorbed", 0.0))

func _merge_disruption(summary: Dictionary, entry: Dictionary, side: String, subject_id: String) -> void:
	var kernels: Dictionary = entry.get("kernels", {})
	var disruption: Dictionary = kernels.get("disruption", {}) if (kernels is Dictionary) else {}
	if not (disruption is Dictionary):
		return
	if bool(disruption.get("supported", false)):
		summary["direct_disruption_supported"] = true
	var per_unit: Dictionary = disruption.get("per_unit", {})
	var side_map: Dictionary = per_unit.get(side, {}) if (per_unit is Dictionary) else {}
	var rec: Dictionary = side_map.get(subject_id, {}) if (side_map is Dictionary) else {}
	if rec.is_empty():
		return
	for key in ["forced_reposition_distance_tiles", "formation_spread_increase_tiles"]:
		if rec.has(key):
			summary[key] = float(summary.get(key, 0.0)) + float(rec.get(key, 0.0))
	for key_int in ["forced_reposition_events", "target_swap_events", "formation_break_events", "follow_up_kills"]:
		if rec.has(key_int):
			summary[key_int] = int(summary.get(key_int, 0)) + int(rec.get(key_int, 0))

func _merge_backline_access(summary: Dictionary, entry: Dictionary, side: String, subject_id: String) -> void:
	var kernels: Dictionary = entry.get("kernels", {}) if (entry is Dictionary) else {}
	var backline_access: Dictionary = kernels.get("backline_access", {}) if (kernels is Dictionary) else {}
	if not (backline_access is Dictionary) or not bool(backline_access.get("supported", false)):
		return
	var side_block: Dictionary = backline_access.get(side, {}) if (backline_access is Dictionary) else {}
	if not (side_block is Dictionary):
		return
	summary["backline_access_samples"] = int(summary.get("backline_access_samples", 0)) + 1
	var entered_by_unit: Dictionary = side_block.get("entered_by_unit", {}) if (side_block is Dictionary) else {}
	if not (entered_by_unit is Dictionary) or not entered_by_unit.has(subject_id):
		return
	summary["backline_access_contact_count"] = int(summary.get("backline_access_contact_count", 0)) + 1
	var contact_s: float = float(entered_by_unit.get(subject_id, -1.0))
	var best_contact_s: float = float(summary.get("backline_access_first_contact_s", -1.0))
	if best_contact_s < 0.0 or (contact_s >= 0.0 and contact_s < best_contact_s):
		summary["backline_access_first_contact_s"] = contact_s

func _subject_kernel_rec(entry: Dictionary, side: String, subject_id: String, kernel_key: String) -> Dictionary:
	var kernels: Dictionary = entry.get("kernels", {})
	var block: Dictionary = kernels.get(kernel_key, {}) if (kernels is Dictionary) else {}
	var per_unit: Dictionary = block.get("per_unit", {}) if (block is Dictionary) else {}
	var side_map: Dictionary = {}
	if per_unit is Dictionary and not per_unit.is_empty():
		side_map = per_unit.get(side, {})
	elif block is Dictionary and block.has(side):
		side_map = block.get(side, {})
	var rec: Dictionary = side_map.get(subject_id, {}) if (side_map is Dictionary) else {}
	return rec if rec is Dictionary else {}

func _subject_unit(entry: Dictionary, side: String, subject_id: String) -> Dictionary:
	var units: Dictionary = entry.get("units", {})
	var arr: Array = units.get(side, []) if (units is Dictionary) else []
	for value in arr:
		if not (value is Dictionary):
			continue
		var unit_entry: Dictionary = value
		if String(unit_entry.get("unit_id", "")) == subject_id:
			return unit_entry
	return {}

func _team_value(entry: Dictionary, side: String, key: String) -> float:
	var teams: Dictionary = entry.get("teams", {})
	var side_block: Dictionary = teams.get(side, {}) if (teams is Dictionary) else {}
	return float(side_block.get(key, 0.0)) if (side_block is Dictionary) else 0.0

func _team_incoming(entry: Dictionary, side: String) -> float:
	var units: Dictionary = entry.get("units", {})
	var arr: Array = units.get(side, []) if (units is Dictionary) else []
	var total: float = 0.0
	for value in arr:
		if value is Dictionary:
			var unit_entry: Dictionary = value
			total += max(float(unit_entry.get("incoming", 0.0)), float(unit_entry.get("pre_mit_incoming", 0.0)))
	return total

func _fight_time(entry: Dictionary) -> float:
	var outcome: Dictionary = entry.get("outcome", {})
	return float(outcome.get("time_s", 0.0)) if (outcome is Dictionary) else 0.0

func _subject_side(entry: Dictionary, subject_id: String) -> String:
	var context: Dictionary = entry.get("context", {})
	var team_a: Array = context.get("team_a_ids", []) if (context is Dictionary) else []
	var team_b: Array = context.get("team_b_ids", []) if (context is Dictionary) else []
	for unit_id in team_a:
		if String(unit_id) == subject_id:
			return "a"
	for unit_id_b in team_b:
		if String(unit_id_b) == subject_id:
			return "b"
	return ""

func _incoming_share(summary: Dictionary) -> float:
	return float(summary.get("incoming", 0.0)) / max(1.0, float(summary.get("team_incoming", 0.0)))

func _damage_share(summary: Dictionary) -> float:
	return float(summary.get("damage", 0.0)) / max(1.0, float(summary.get("team_damage", 0.0)))

func _prevented_damage(summary: Dictionary) -> float:
	var pre_mit: float = float(summary.get("pre_mit_incoming", 0.0))
	var post_mit: float = float(summary.get("post_mit_incoming", 0.0))
	return max(0.0, pre_mit - post_mit)

func _effective_ehp(summary: Dictionary) -> float:
	return max(0.0, _prevented_damage(summary)) + float(summary.get("healing", 0.0)) + float(summary.get("shield", 0.0)) + float(summary.get("ally_damage_prevented", 0.0))

func _has_direct_disruption(summary: Dictionary) -> bool:
	return bool(summary.get("direct_disruption_supported", false)) or summary.has("forced_reposition_events") or summary.has("target_swap_events") or summary.has("formation_break_events") or summary.has("follow_up_kills")

func _has_direct_targetability(summary: Dictionary) -> bool:
	return summary.has("untargetable_windows") or summary.has("untargetable_time_s") or summary.has("key_threats_faced") or summary.has("cooldown_trade_s")

func _has_direct_cooldown_pressure(summary: Dictionary) -> bool:
	return summary.has("cooldowns_forced") or summary.has("cooldowns_forced_s") or summary.has("key_cooldowns_forced")

func _has_direct_zone_exposure(summary: Dictionary) -> bool:
	return bool(summary.get("direct_zone_exposure_supported", false)) or summary.has("zone_exposure_events") or summary.has("zone_exposure_time_s") or summary.has("zone_exposure_damage")

func _has_direct_dot(summary: Dictionary) -> bool:
	return summary.has("dot_tick_events") or summary.has("dot_tick_damage") or summary.has("dot_uptime_s") or summary.has("dot_duration_applied_s")

func _has_direct_on_hit(summary: Dictionary) -> bool:
	return summary.has("on_hit_effects") or summary.has("on_hit_magnitude")

func _has_direct_ramp_state(summary: Dictionary) -> bool:
	return bool(summary.get("direct_ramp_state_supported", false)) or summary.has("ramp_state_events") or summary.has("ramp_stack_max") or summary.has("ramp_peak_duration_s") or summary.has("ramp_window_duration_s")

func _identity_has_approach(ident: Dictionary, approach_id: String) -> bool:
	var expected: String = String(approach_id).strip_edges().to_lower()
	var raw_approaches: Variant = ident.get("approaches", [])
	if raw_approaches is Array:
		for value: Variant in raw_approaches:
			if String(value).strip_edges().to_lower() == expected:
				return true
	elif raw_approaches is PackedStringArray:
		for packed_value: String in raw_approaches:
			if String(packed_value).strip_edges().to_lower() == expected:
				return true
	elif typeof(raw_approaches) == TYPE_STRING:
		return String(raw_approaches).strip_edges().to_lower() == expected
	return false

func _goal_dot_ok(summary: Dictionary, spans: Array, prefix: String) -> bool:
	if not _has_direct_dot(summary):
		_append_span(spans, summary, "%s_dot_tick_events" % prefix, 0.0, 2.0, false, "direct_dot_missing")
		return false
	var events_ok: bool = _append_span(spans, summary, "%s_dot_tick_events" % prefix, float(summary.get("dot_tick_events", 0)), 2.0, int(summary.get("dot_tick_events", 0)) >= 2, "direct_dot")
	var damage_ok: bool = _append_span(spans, summary, "%s_dot_tick_damage" % prefix, float(summary.get("dot_tick_damage", 0.0)), 1.0, float(summary.get("dot_tick_damage", 0.0)) >= 1.0, "direct_dot")
	var uptime_ok: bool = _append_span(spans, summary, "%s_dot_uptime_s" % prefix, float(summary.get("dot_uptime_s", 0.0)), 1.0, float(summary.get("dot_uptime_s", 0.0)) >= 1.0, "direct_dot")
	return events_ok and damage_ok and uptime_ok

func _goal_zone_ok(summary: Dictionary, spans: Array, prefix: String) -> bool:
	if not _has_direct_zone_exposure(summary):
		_append_span(spans, summary, "%s_zone_exposure_time_s" % prefix, 0.0, 1.0, false, "direct_zone_missing")
		return false
	var events_ok: bool = _append_span(spans, summary, "%s_zone_exposure_events" % prefix, float(summary.get("zone_exposure_events", 0)), 1.0, int(summary.get("zone_exposure_events", 0)) >= 1, "direct_zone_exposure")
	var time_ok: bool = _append_span(spans, summary, "%s_zone_exposure_time_s" % prefix, float(summary.get("zone_exposure_time_s", 0.0)), 1.0, float(summary.get("zone_exposure_time_s", 0.0)) >= 1.0, "direct_zone_exposure")
	var damage_ok: bool = _append_span(spans, summary, "%s_zone_exposure_damage" % prefix, float(summary.get("zone_exposure_damage", 0.0)), 1.0, float(summary.get("zone_exposure_damage", 0.0)) >= 1.0, "direct_zone_exposure")
	return events_ok and time_ok and damage_ok

func _goal_on_hit_ok(summary: Dictionary, spans: Array, prefix: String) -> bool:
	if not _has_direct_on_hit(summary):
		_append_span(spans, summary, "%s_on_hit_effects" % prefix, 0.0, 2.0, false, "direct_on_hit_missing")
		return false
	var events_ok: bool = _append_span(spans, summary, "%s_on_hit_effects" % prefix, float(summary.get("on_hit_effects", 0)), 2.0, int(summary.get("on_hit_effects", 0)) >= 2, "direct_on_hit")
	var magnitude_ok: bool = _append_span(spans, summary, "%s_on_hit_magnitude" % prefix, float(summary.get("on_hit_magnitude", 0.0)), 1.0, float(summary.get("on_hit_magnitude", 0.0)) >= 1.0, "direct_on_hit")
	return events_ok and magnitude_ok

func _goal_ramp_ok(summary: Dictionary, spans: Array, prefix: String) -> bool:
	if not bool(summary.get("has_ramp_approach", false)):
		return false
	if _has_direct_ramp_state(summary):
		var events: int = int(summary.get("ramp_state_events", 0))
		var stack_max: float = float(summary.get("ramp_stack_max", 0.0))
		var peak_duration: float = float(summary.get("ramp_peak_duration_s", 0.0))
		var window_duration: float = float(summary.get("ramp_window_duration_s", 0.0))
		var events_pass: bool = events >= 1
		var stack_pass: bool = stack_max >= 2.0
		var peak_pass: bool = peak_duration >= 1.0
		var window_pass: bool = window_duration >= 1.0
		var ramp_pass: bool = events_pass and _k_of_n([stack_pass, peak_pass, window_pass], 1)
		var stack_span_ok: Variant = stack_pass
		var stack_reason: String = "direct_ramp_state"
		if ramp_pass and not stack_pass:
			stack_span_ok = null
			stack_reason = "alternate_ramp_state_evidence_satisfied"
		_append_span(spans, summary, "%s_ramp_state_events" % prefix, float(events), 1.0, events_pass, "direct_ramp_state")
		_append_span(spans, summary, "%s_ramp_stack_max" % prefix, stack_max, 2.0, stack_span_ok, stack_reason)
		_append_span(spans, summary, "%s_ramp_peak_duration_s" % prefix, peak_duration, 1.0, peak_pass, "direct_ramp_state")
		_append_span(spans, summary, "%s_ramp_window_duration_s" % prefix, window_duration, 1.0, window_pass, "direct_ramp_state")
		return ramp_pass
	return _append_span(spans, summary, "%s_late_early_ratio" % prefix, float(summary.get("late_early_dps_ratio", 0.0)), 1.0, float(summary.get("late_early_dps_ratio", 0.0)) >= 1.0, "ramp_state_missing")

func _key_threat_dodge_rate(summary: Dictionary) -> float:
	var faced: float = float(summary.get("key_threats_faced", 0))
	if faced <= 0.0:
		return 0.0
	return float(summary.get("key_threats_dodged", 0)) / max(1.0, faced)

func _backline_contact_fraction(summary: Dictionary) -> float:
	var samples: int = int(summary.get("backline_access_samples", 0))
	if samples <= 0:
		return 0.0
	return float(summary.get("backline_access_contact_count", 0)) / max(1.0, float(samples))

func _append_span(spans: Array, summary: Dictionary, label: String, value: float, want: float, ok: Variant, reason: String = "") -> bool:
	var extras: Dictionary = RoleCommon.subject_extras(String(summary.get("subject_side", "")), String(summary.get("unit_id", "")), reason)
	extras["samples"] = int(summary.get("samples", 0))
	extras["direct_goal_metric"] = true
	for key in ["backline_damage_share", "backline_access_samples", "backline_access_contact_count", "backline_access_first_contact_s", "early_0_3s_share", "sustained_3_10s_share", "sustained_3_10s_team_share", "sustained_3_10s_rate", "sustained_3_10s_window_s"]:
		if summary.has(key):
			extras[key] = summary.get(key)
	RoleCommon.append_span(spans, label, value, want, ok, extras)
	return ok == true

func _k_of_n(values: Array[bool], k_required: int) -> bool:
	var true_count: int = 0
	for value in values:
		if bool(value):
			true_count += 1
	return true_count >= int(k_required)

func _non_negative_at_most(value: float, max_value: float) -> bool:
	return value >= 0.0 and value <= max_value
