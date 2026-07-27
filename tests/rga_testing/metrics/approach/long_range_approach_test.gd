extends RefCounted

# Approach: long_range (per-unit subject)
# Pass condition: subject's median attacks_over_2_tiles_pct >= threshold.

const VERSION: String = "1.0.0"
const METRIC_ID: String = "approach_long_range"

const RoleCommon := preload("res://tests/rga_testing/metrics/_shared/role_common.gd")

const REQUIRED_CAPS: Array[String] = ["targets"]

func get_metadata() -> Dictionary:
	return {
		"id": METRIC_ID,
		"version": VERSION,
		"required_capabilities": REQUIRED_CAPS,
		"description": "long_range: subject median attacks over 2 tiles share meets threshold."
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
	var cfg: Dictionary = RoleCommon.approach_threshold(thresholds_all, "long_range")
	if cfg.is_empty():
		cfg = RoleCommon.approach_threshold(thresholds_all, "poke")
	var metrics_cfg: Dictionary = cfg.get("metrics", {})
	var share_cfg: Dictionary = metrics_cfg.get("attacks_over_2_tiles_share", {})
	var share_req: float = float(RoleCommon.resolve_min_threshold(share_cfg, cost_band, scenario_label))

	var samples: Array[float] = []
	var damage_samples: Array[float] = []
	for key in sims.keys():
		var entry: Dictionary = sims.get(key, {})
		var side: String = _subject_side(entry, subject_id)
		if side == "":
			continue
		var kernels: Dictionary = entry.get("kernels", {})
		var per_unit_kpis: Dictionary = kernels.get("per_unit_kpis", {})
		if not (per_unit_kpis is Dictionary):
			continue
		var side_map: Dictionary = per_unit_kpis.get(side, {})
		if not (side_map is Dictionary):
			continue
		var rec: Dictionary = side_map.get(subject_id, {})
		if not (rec is Dictionary):
			continue
		var value: float = float(rec.get("attacks_over_2_tiles_pct", -1.0))
		if value >= 0.0:
			samples.append(value)
		var damage_value: float = float(rec.get("damage_over_2_tiles_pct", -1.0))
		if damage_value >= 0.0:
			damage_samples.append(damage_value)

	var median_value: float = _median(samples)
	var median_damage_value: float = _median(damage_samples)
	var count_share_ok: bool = median_value >= share_req and samples.size() > 0
	var damage_share_ok: bool = median_damage_value >= share_req and damage_samples.size() > 0
	var pass_flag: bool = count_share_ok or damage_share_ok
	var spans: Array = []
	var extras: Dictionary = RoleCommon.subject_extras(_any_side_for_subject(sims, subject_id), subject_id, ("no_samples" if samples.is_empty() else ""))
	var count_span_ok: Variant = count_share_ok
	var count_extras: Dictionary = extras.duplicate(true)
	if not count_share_ok and damage_share_ok:
		count_span_ok = null
		count_extras["reason"] = "alternate_long_range_damage_share_satisfied"
	RoleCommon.append_span(spans, "subject_attacks_over_2_tiles_med", median_value, share_req, count_span_ok, count_extras)
	var damage_span_ok: Variant = damage_share_ok
	var damage_extras: Dictionary = extras.duplicate(true)
	if not damage_share_ok and count_share_ok:
		damage_span_ok = null
		damage_extras["reason"] = "alternate_long_range_hit_share_satisfied"
	RoleCommon.append_span(spans, "subject_damage_over_2_tiles_med", median_damage_value, share_req, damage_span_ok, damage_extras)

	var messages: Array[String] = []
	messages.append("scenario=%s" % scenario_label)
	messages.append("hit_samples=%d; damage_samples=%d" % [samples.size(), damage_samples.size()])

	return {
		"id": METRIC_ID,
		"version": VERSION,
		"pass": pass_flag,
		"spans": spans,
		"message": "; ".join(messages)
	}

func _median(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var sorted_values: Array[float] = []
	for value in values:
		sorted_values.append(float(value))
	sorted_values.sort()
	var count: int = sorted_values.size()
	var mid: int = count / 2
	if (count % 2) == 1:
		return float(sorted_values[mid])
	return 0.5 * (float(sorted_values[mid - 1]) + float(sorted_values[mid]))

func _subject_side(entry: Dictionary, subject_id: String) -> String:
	var context: Dictionary = entry.get("context", {})
	var team_a: Array = context.get("team_a_ids", [])
	var team_b: Array = context.get("team_b_ids", [])
	var sid: String = String(subject_id)
	for unit_id in team_a:
		if String(unit_id) == sid:
			return "a"
	for unit_id in team_b:
		if String(unit_id) == sid:
			return "b"
	return ""

func _any_side_for_subject(sims: Dictionary, subject_id: String) -> String:
	for key in sims.keys():
		var side: String = _subject_side(sims.get(key, {}), subject_id)
		if side != "":
			return side
	return ""
