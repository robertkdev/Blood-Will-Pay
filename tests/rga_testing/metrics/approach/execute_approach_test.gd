extends RefCounted

# Approach: execute (per-unit subject)
# Pass condition: subject applies low-health execute bonus damage and converts it.

const VERSION: String = "1.0.0"
const METRIC_ID: String = "approach_execute"

const RoleCommon := preload("res://tests/rga_testing/metrics/_shared/role_common.gd")

const REQUIRED_CAPS: Array[String] = ["base"]

func get_metadata() -> Dictionary:
	return {
		"id": METRIC_ID,
		"version": VERSION,
		"required_capabilities": REQUIRED_CAPS,
		"description": "execute: subject execute bonus damage share, low-health kill conversion, and overkill guardrail."
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
	var cost_band: int = int(ident.get("cost", 3))
	var scenario_label: String = String(ctx.get("scenario", "neutral"))
	var thresholds_all: Dictionary = RoleCommon.load_thresholds()
	var cfg: Dictionary = RoleCommon.approach_threshold(thresholds_all, "execute")
	var metrics_cfg: Dictionary = cfg.get("metrics", {})
	var share_cfg: Dictionary = metrics_cfg.get("low_hp_kill_share", {})
	var kills_cfg: Dictionary = metrics_cfg.get("low_hp_kills", {})
	var overkill_cfg: Dictionary = metrics_cfg.get("overkill_rate", {})
	var bonus_share_cfg: Dictionary = metrics_cfg.get("execute_bonus_damage_share", {})
	var bonus_events_cfg: Dictionary = metrics_cfg.get("execute_bonus_events", {})
	var share_req: float = RoleCommon.resolve_min_threshold(share_cfg, cost_band, scenario_label)
	var kills_req: float = RoleCommon.resolve_min_threshold(kills_cfg, cost_band, scenario_label)
	var overkill_max: float = RoleCommon.resolve_max_threshold(overkill_cfg, cost_band, scenario_label)
	var bonus_share_req: float = RoleCommon.resolve_min_threshold(bonus_share_cfg, cost_band, scenario_label)
	var bonus_events_req: float = RoleCommon.resolve_min_threshold(bonus_events_cfg, cost_band, scenario_label)
	if share_req <= 0.0:
		share_req = 0.50
	if kills_req <= 0.0:
		kills_req = 1.0
	if overkill_max <= 0.0:
		overkill_max = 0.60
	if bonus_share_req <= 0.0:
		bonus_share_req = 0.10
	if bonus_events_req <= 0.0:
		bonus_events_req = 1.0

	var total_kills: int = 0
	var total_low_hp_kills: int = 0
	var total_bonus_events: int = 0
	var total_bonus_damage: float = 0.0
	var total_bonus_targets: int = 0
	var total_outside_threshold: int = 0
	var overkill_samples: Array[float] = []
	var bonus_share_samples: Array[float] = []
	var considered: int = 0
	var direct_supported: bool = false
	for key in sims.keys():
		var rec: Dictionary = _subject_pattern(sims.get(key, {}), subject_id)
		if rec.is_empty():
			continue
		considered += 1
		total_kills += int(rec.get("kill_count", 0))
		total_low_hp_kills += int(rec.get("low_hp_kill_count", 0))
		overkill_samples.append(float(rec.get("overkill_rate", 0.0)))
		if rec.has("execute_bonus_events") or rec.has("execute_bonus_damage_share"):
			direct_supported = true
			var rec_bonus_events: int = int(rec.get("execute_bonus_events", 0))
			total_bonus_events += rec_bonus_events
			total_bonus_damage += float(rec.get("execute_bonus_damage", 0.0))
			total_bonus_targets += int(rec.get("execute_bonus_targets", 0))
			total_outside_threshold += int(rec.get("execute_bonus_outside_threshold_events", 0))
			# Execute share is conditional on an execute window existing. Including
			# zero-event fights in the median erases valid sparse finishers.
			if rec_bonus_events > 0:
				bonus_share_samples.append(float(rec.get("execute_bonus_damage_share", 0.0)))

	var low_hp_share: float = float(total_low_hp_kills) / max(1.0, float(total_kills))
	var overkill_value: float = RoleCommon.median(overkill_samples)
	var bonus_share_value: float = RoleCommon.median(bonus_share_samples)
	var share_pass: bool = total_kills > 0 and low_hp_share >= share_req
	var kills_pass: bool = total_low_hp_kills >= int(round(kills_req))
	var bonus_events_pass: bool = direct_supported and total_bonus_events >= int(round(bonus_events_req))
	var bonus_share_pass: bool = direct_supported and bonus_share_value >= bonus_share_req
	var outside_threshold_ok: bool = total_outside_threshold <= 0
	var overkill_ok: bool = overkill_samples.size() <= 0 or overkill_value <= overkill_max
	var kcfg: Dictionary = cfg.get("k_of_n", {"k": 3, "n": 5})
	var eval_result: Dictionary = RoleCommon.k_of_n([bonus_events_pass, bonus_share_pass, share_pass, kills_pass, overkill_ok], int(kcfg.get("k", 3)), int(kcfg.get("n", 5)))
	var pass_flag: bool = bonus_events_pass and bool(eval_result.get("pass", false)) and outside_threshold_ok
	var direct_conversion_pass: bool = bonus_events_pass and total_bonus_damage > 0.0 and total_kills > 0 and overkill_ok and outside_threshold_ok
	if direct_supported and total_bonus_damage > 0.0:
		pass_flag = direct_conversion_pass
	if not direct_supported:
		pass_flag = share_pass and kills_pass and overkill_ok
	var bonus_share_span_ok: Variant = bonus_share_pass
	var alternate_execute_evidence_satisfied: bool = pass_flag and direct_supported and total_bonus_damage > 0.0
	if alternate_execute_evidence_satisfied and not bonus_share_pass:
		bonus_share_span_ok = null

	var spans: Array = []
	var extras: Dictionary = RoleCommon.subject_extras(_any_side_for_subject(sims, subject_id), subject_id, ("no_kills" if total_kills <= 0 else ""))
	extras["considered"] = considered
	extras["kill_count"] = total_kills
	extras["low_hp_kill_count"] = total_low_hp_kills
	extras["direct_execute_bonus"] = direct_supported
	extras["execute_bonus_events"] = total_bonus_events
	extras["execute_bonus_damage"] = total_bonus_damage
	extras["execute_bonus_targets"] = total_bonus_targets
	extras["k"] = int(eval_result.get("k", 0))
	extras["n"] = int(eval_result.get("n", 0))
	extras["true_count"] = int(eval_result.get("true_count", 0))
	RoleCommon.append_span(spans, "subject_execute_bonus_events", total_bonus_events, bonus_events_req, bonus_events_pass if direct_supported else null, extras)
	RoleCommon.append_span(spans, "subject_execute_bonus_damage_share", bonus_share_value, bonus_share_req, bonus_share_span_ok if direct_supported else null, _extras_for_span(extras, bonus_share_span_ok, "alternate_execute_evidence_satisfied"))
	RoleCommon.append_span(spans, "subject_execute_bonus_damage", total_bonus_damage, null, direct_supported and total_bonus_damage > 0.0, extras)
	RoleCommon.append_span(spans, "subject_execute_bonus_outside_threshold_events", total_outside_threshold, 0, outside_threshold_ok if direct_supported else null, extras)
	var low_hp_share_span_ok: Variant = share_pass
	var low_hp_kills_span_ok: Variant = kills_pass
	if direct_conversion_pass:
		if not share_pass:
			low_hp_share_span_ok = null
		if not kills_pass:
			low_hp_kills_span_ok = null
	RoleCommon.append_span(spans, "subject_low_hp_kill_share", low_hp_share, share_req, low_hp_share_span_ok, _extras_for_span(extras, low_hp_share_span_ok, "direct_execute_conversion_satisfied"))
	RoleCommon.append_span(spans, "subject_low_hp_kills", total_low_hp_kills, kills_req, low_hp_kills_span_ok, _extras_for_span(extras, low_hp_kills_span_ok, "direct_execute_conversion_satisfied"))
	RoleCommon.append_span(spans, "subject_execute_overkill_rate_med", overkill_value, overkill_max, overkill_ok, extras)

	return {
		"id": METRIC_ID,
		"version": VERSION,
		"pass": pass_flag,
		"spans": spans,
		"message": "scenario=%s; considered=%d; direct_execute=%s; bonus_events=%d; kills=%d" % [scenario_label, considered, str(direct_supported), total_bonus_events, total_kills]
	}

func _subject_pattern(entry: Dictionary, subject_id: String) -> Dictionary:
	var side: String = _subject_side(entry, subject_id)
	if side == "":
		return {}
	var kernels: Dictionary = entry.get("kernels", {})
	var patterns: Dictionary = kernels.get("combat_patterns", {}) if (kernels is Dictionary) else {}
	var per_unit: Dictionary = patterns.get("per_unit", {}) if (patterns is Dictionary) else {}
	var side_map: Dictionary = per_unit.get(side, {}) if (per_unit is Dictionary) else {}
	var rec: Dictionary = side_map.get(subject_id, {}) if (side_map is Dictionary) else {}
	return rec if rec is Dictionary else {}

func _extras_for_span(base_extras: Dictionary, span_ok: Variant, diagnostic_reason: String) -> Dictionary:
	if span_ok != null:
		return base_extras
	var diagnostic_extras: Dictionary = base_extras.duplicate(true)
	diagnostic_extras["reason"] = diagnostic_reason
	return diagnostic_extras

func _subject_side(entry: Dictionary, subject_id: String) -> String:
	var context: Dictionary = entry.get("context", {})
	var team_a: Array = context.get("team_a_ids", [])
	var team_b: Array = context.get("team_b_ids", [])
	for unit_id in team_a:
		if String(unit_id) == subject_id:
			return "a"
	for unit_id_b in team_b:
		if String(unit_id_b) == subject_id:
			return "b"
	return ""

func _any_side_for_subject(sims: Dictionary, subject_id: String) -> String:
	for key in sims.keys():
		var side: String = _subject_side(sims.get(key, {}), subject_id)
		if side != "":
			return side
	return ""
