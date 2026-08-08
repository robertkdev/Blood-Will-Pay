extends RefCounted

# Brawler Role Identity Test (per-unit)
# Pass condition per unit: 2-of-2
#  - sustained_damage_rate leadership vs peers (multiplier OR z-score), per unit
#  - can_take_damage via focus_survival_s per unit (preferred); fallback to time_alive_s; final fallback: soak_index in range
# Overall pass if any unit on side A or B passes both conditions.

const VERSION := "1.0.0"
const METRIC_ID := "role_brawler_identity"

const RoleCommon := preload("res://tests/rga_testing/metrics/_shared/role_common.gd")

const REQUIRED_CAPS = ["base"] # focus benefits from targets if present

func get_metadata() -> Dictionary:
	return {
		"id": METRIC_ID,
		"version": VERSION,
		"required_capabilities": REQUIRED_CAPS,
		"description": "Brawler identity (per-unit) via sustained rate vs peers and survivability with clear fallbacks."
	}

func run_metric(payload: Dictionary = {}) -> Dictionary:
	var ctx: Dictionary = payload.get("context", {})
	var sims: Dictionary = ctx.get("sims", {}) if ctx is Dictionary else {}
	if sims.is_empty():
		return RoleCommon.fail_result([], ["no_sims_in_context"])

	var subject_set: Dictionary = RoleCommon.subject_set_from_payload(payload)
	var has_subject: bool = (subject_set is Dictionary and not subject_set.is_empty())
	var subj_id: String = (String(subject_set.keys()[0]) if has_subject else "")
	var thresholds_all: Dictionary = RoleCommon.load_thresholds()
	var cfg: Dictionary = RoleCommon.role_threshold(thresholds_all, "brawler")
	var metrics_cfg: Dictionary = cfg.get("metrics", {})
	var sus_cfg: Dictionary = metrics_cfg.get("sustained_damage_rate", {})
	var dmg_cfg: Dictionary = metrics_cfg.get("damage_taken_total", {})
	var can_take_cfg: Dictionary = metrics_cfg.get("can_take_damage", {})
	var composite_any: Array = can_take_cfg.get("composite_any", []) if (can_take_cfg is Dictionary) else []
	var focus_cfg: Dictionary = _metric_cfg_from_list(composite_any, "focus_survival_s")
	var hits_cfg: Dictionary = _metric_cfg_from_list(composite_any, "hits_survived")
	var fb_cfg: Dictionary = cfg.get("fallback", {})
	var fallback_all: Array = fb_cfg.get("all", []) if (fb_cfg is Dictionary) else []
	var time_alive_cfg: Dictionary = _metric_cfg_from_list(fallback_all, "time_alive_s")

	var scenario_label: String = String(ctx.get("scenario", "neutral"))
	var assumed_cost_band: int = 3

	# Comparison thresholds for sustained leadership
	var cmp: Dictionary = sus_cfg.get("comparison", {})
	var mult_req: float = float(cmp.get("median_multiplier", 1.15))
	var z_req: float = float(cmp.get("z_min", 0.5))
	var sus_tol: float = RoleCommon.resolve_tolerance(thresholds_all, sus_cfg, RoleCommon.DEFAULT_TOLERANCE)
	var mult_tol_req: float = mult_req * (1.0 - sus_tol)
	var z_tol_req: float = z_req * (1.0 - sus_tol)
	var focus_req: float = _resolve_metric_threshold([focus_cfg], "focus_survival_s", assumed_cost_band, scenario_label)
	if focus_req <= 0.0:
		focus_req = 8.0
	var hits_req: float = _resolve_metric_threshold([hits_cfg], "hits_survived", assumed_cost_band, scenario_label)
	if hits_req <= 0.0:
		hits_req = 2.0
	var time_alive_req: float = _resolve_metric_threshold([time_alive_cfg], "time_alive_s", assumed_cost_band, scenario_label)
	if time_alive_req <= 0.0:
		time_alive_req = 8.0

	# Accumulators across sims
	var peers_all: Array = []
	var rates_by_unit: Dictionary = {"a": {}, "b": {}}   # side -> uid -> Array[float]
	var focus_by_unit: Dictionary = {"a": {}, "b": {}}   # side -> uid -> { sum: float, n: int }
	var tl_by_unit: Dictionary = {"a": {}, "b": {}}      # side -> uid -> { sum: float, n: int }
	var soak_by_unit: Dictionary = {"a": {}, "b": {}}    # side -> uid -> { inc: float, soaked: float }
	var direct_attrition_by_unit: Dictionary = {"a": {}, "b": {}} # side -> uid -> direct frontline/sustain/ramp/execute/aoe evidence
	# Side-level accumulator for hits_survived (weighted by samples)
	var hits_by_side_acc: Dictionary = {"a": {"sum": 0.0, "n": 0}, "b": {"sum": 0.0, "n": 0}, "supported": false}

	for key in sims.keys():
		var entry: Dictionary = sims.get(key, {})
		if not (entry is Dictionary):
			continue
		var agg: Dictionary = entry.get("kernels", {})
		var units: Dictionary = entry.get("units", {})

		# Throughput peers band and per-unit by-index
		var th: Dictionary = agg.get("throughput", {})
		if th is Dictionary:
			var peers_block: Dictionary = th.get("peers", {})
			if peers_block is Dictionary:
				var arr_all: Variant = peers_block.get("all", [])
				if arr_all is Array:
					for r in arr_all: peers_all.append(float(r))
			var peers_idx: Dictionary = th.get("peers_by_index", {})
			if peers_idx is Dictionary:
				for side in ["a","b"]:
					var map_side: Dictionary = peers_idx.get(side, {})
					if not (map_side is Dictionary):
						continue
					var arr_units: Array = units.get(side, [])
					var uids: Array = []
					if arr_units is Array:
						for i in range(arr_units.size()):
							var u: Variant = arr_units[i]
							uids.append(String(u.get("unit_id", "")) if (u is Dictionary) else "")
					for mk in map_side.keys():
						var idx: int = int(mk)
						var uid: String = (String(uids[idx]) if (idx >= 0 and idx < uids.size()) else "")
						if uid == "":
							continue
						var rate: float = float(map_side.get(mk, 0.0))
						var bucket: Array = (rates_by_unit[side] as Dictionary).get(uid, [])
						if not (bucket is Array):
							bucket = []
						bucket.append(rate)
						(rates_by_unit[side] as Dictionary)[uid] = bucket

		# Per-unit survivability bases (time_alive, soak)
		for s in ["a","b"]:
			var arr2: Array = units.get(s, [])
			if not (arr2 is Array):
				continue
			for u2 in arr2:
				if not (u2 is Dictionary):
					continue
				var uid2: String = String(u2.get("unit_id", ""))
				if uid2 == "":
					continue
				var tlb: Dictionary = (tl_by_unit[s] as Dictionary).get(uid2, {"sum": 0.0, "n": 0})
				tlb["sum"] = float(tlb.get("sum", 0.0)) + float(u2.get("time_alive_s", 0.0))
				tlb["n"] = int(tlb.get("n", 0)) + 1
				(tl_by_unit[s] as Dictionary)[uid2] = tlb
				var skb: Dictionary = (soak_by_unit[s] as Dictionary).get(uid2, {"inc": 0.0, "soaked": 0.0})
				skb["inc"] = float(skb.get("inc", 0.0)) + float(u2.get("incoming", 0.0))
				skb["soaked"] = float(skb.get("soaked", 0.0)) + (float(u2.get("mitigated", 0.0)) + float(u2.get("shield", 0.0)))
				(soak_by_unit[s] as Dictionary)[uid2] = skb
				_bump_direct_attrition(direct_attrition_by_unit, entry, s, uid2, u2)

		# Per-unit focus survival from kernel (guard supported)
		var fs: Dictionary = agg.get("focus_survival", {})
		if fs is Dictionary and bool(fs.get("supported", false)):
			var per_map: Dictionary = fs.get("focus_survival_per_unit", {})
			if per_map is Dictionary:
				for s2 in ["a","b"]:
					var side_block: Dictionary = per_map.get(s2, {})
					if not (side_block is Dictionary):
						continue
					for uid3 in side_block.keys():
						var e: Dictionary = side_block.get(uid3, {})
						var n3: int = int(e.get("samples", 0))
						var avg3: Variant = e.get("avg_s", null)
						if n3 <= 0 or not (typeof(avg3) == TYPE_FLOAT or typeof(avg3) == TYPE_INT):
							continue
						var fb: Dictionary = (focus_by_unit[s2] as Dictionary).get(String(uid3), {"sum": 0.0, "n": 0})
						fb["sum"] = float(fb.get("sum", 0.0)) + float(avg3) * float(n3)
						fb["n"] = int(fb.get("n", 0)) + n3
						(focus_by_unit[s2] as Dictionary)[String(uid3)] = fb
		# Side-level hits_survived (aggregate by samples when present)
		var hs: Dictionary = agg.get("hits_survived", {})
		if hs is Dictionary and bool(hs.get("supported", false)):
			hits_by_side_acc["supported"] = true
			for s3 in ["a","b"]:
				var obj_h: Dictionary = hs.get(s3, {})
				if obj_h is Dictionary:
					var navg: float = RoleCommon.safe_float(obj_h, "avg", 0.0)
					var ns: int = int(obj_h.get("samples", 0))
					(hits_by_side_acc[s3] as Dictionary)["sum"] = float((hits_by_side_acc[s3] as Dictionary).get("sum", 0.0)) + navg * float(max(0, ns))
					(hits_by_side_acc[s3] as Dictionary)["n"] = int((hits_by_side_acc[s3] as Dictionary).get("n", 0)) + max(0, ns)

	# Evaluate per-unit conditions
	var med_all: float = RoleCommon.median(peers_all)
	var side_pass: Dictionary = {"a": false, "b": false}
	# Survivability threshold (absolute damage taken per match)
	var dmg_req: float = _resolve_metric_threshold([dmg_cfg], "damage_taken_total", assumed_cost_band, scenario_label)
	# Compute side-level hits averages
	var hits_avg_by_side: Dictionary = {"a": 0.0, "b": 0.0, "supported": bool(hits_by_side_acc.get("supported", false))}
	for ssum in ["a", "b"]:
		var acc: Dictionary = hits_by_side_acc.get(ssum, {})
		var nacc: int = int(acc.get("n", 0))
		hits_avg_by_side[ssum] = (float(acc.get("sum", 0.0)) / max(1.0, float(nacc))) if nacc > 0 else 0.0
	var spans: Array = []
	var subj_pass: bool = false
	for side4 in ["a","b"]:
		var passed_units: int = 0
		var rates_map: Dictionary = rates_by_unit.get(side4, {})
		if rates_map is Dictionary:
			for uid in rates_map.keys():
				if has_subject and String(uid) != subj_id:
					continue
				var samples: Array = rates_map.get(uid, [])
				var rate_med: float = RoleCommon.median(samples)
				var mult: float = RoleCommon.multiplier_vs_median(rate_med, med_all)
				var z: float = RoleCommon.z_from_band(rate_med, peers_all)
				var cond_sustained_strict: bool = (mult >= mult_req) or (z >= z_req)
				var cond_sustained_tolerated: bool = (not cond_sustained_strict) and ((mult >= mult_tol_req) or (z >= z_tol_req))
				var direct_attrition: Dictionary = _direct_attrition_eval((direct_attrition_by_unit.get(side4, {}) as Dictionary).get(uid, {}))
				var cond_direct_attrition: bool = bool(direct_attrition.get("pass", false))
				var cond_sustained: bool = cond_sustained_strict or cond_sustained_tolerated or cond_direct_attrition
				var tb: Dictionary = tl_by_unit.get(side4, {}).get(uid, {}) if (tl_by_unit.get(side4, {}) is Dictionary) else {}
				var tln: int = (int(tb.get("n", 0)) if tb is Dictionary else 0)
				var tl_avg: float = (float(tb.get("sum", 0.0)) / max(1.0, float(tln))) if tln > 0 else 0.0
				var sb: Dictionary = soak_by_unit.get(side4, {}).get(uid, {}) if (soak_by_unit.get(side4, {}) is Dictionary) else {}
				var inc_total: float = (float(sb.get("inc", 0.0)) if sb is Dictionary else 0.0)
				var inc_avg: float = (inc_total / max(1.0, float(tln)))
				var focus_bucket: Dictionary = focus_by_unit.get(side4, {}).get(uid, {}) if (focus_by_unit.get(side4, {}) is Dictionary) else {}
				var focus_n: int = int(focus_bucket.get("n", 0)) if (focus_bucket is Dictionary) else 0
				var focus_avg: float = (float(focus_bucket.get("sum", 0.0)) / max(1.0, float(focus_n))) if focus_n > 0 else 0.0
				var hits_supported: bool = bool(hits_avg_by_side.get("supported", false))
				var hits_avg: float = float(hits_avg_by_side.get(side4, 0.0))
				var cond_focus: bool = focus_n > 0 and focus_avg >= focus_req
				var cond_hits: bool = hits_supported and hits_avg >= hits_req
				var cond_time_alive: bool = tln > 0 and tl_avg >= time_alive_req
				var cond_damage_contact: bool = dmg_req > 0.0 and inc_avg >= dmg_req
				var cond_surv: bool = cond_focus or cond_hits or cond_time_alive
				var surv_reason: String = "time_alive_s"
				if cond_focus:
					surv_reason = "focus_survival_s"
				elif cond_hits:
					surv_reason = "hits_survived"
				elif cond_damage_contact:
					surv_reason = "damage_taken_total"
				var ex: Dictionary = RoleCommon.subject_extras(side4, String(uid), surv_reason)
				ex["sustained_mult_vs_median"] = mult
				ex["sustained_z"] = z
				ex["incoming_avg"] = inc_avg
				ex["req_incoming_avg"] = dmg_req
				if focus_n > 0:
					ex["focus_survival_avg_s"] = focus_avg
				else:
					ex["focus_survival_avg_s"] = null
				ex["hits_survived_avg"] = hits_avg
				ex["time_alive_avg_s"] = tl_avg
				# Include requirements for clearer reporting
				ex["req_mult"] = mult_req
				ex["req_z"] = z_req
				ex["req_mult_tolerated"] = mult_tol_req
				ex["req_z_tolerated"] = z_tol_req
				ex["sustained_strict_ok"] = cond_sustained_strict
				ex["sustained_tolerance_ok"] = cond_sustained_tolerated
				ex["direct_attrition_ok"] = cond_direct_attrition
				ex["direct_attrition_frontline_share"] = float(direct_attrition.get("frontline_share", 0.0))
				ex["direct_attrition_effective_hps"] = float(direct_attrition.get("effective_hps", 0.0))
				ex["direct_attrition_ramp_events"] = float(direct_attrition.get("ramp_events", 0.0))
				ex["direct_attrition_ramp_stack_max"] = float(direct_attrition.get("ramp_stack_max", 0.0))
				ex["direct_attrition_ramp_window_s"] = float(direct_attrition.get("ramp_window_s", 0.0))
				ex["direct_attrition_execute_events"] = float(direct_attrition.get("execute_events", 0.0))
				ex["direct_attrition_low_hp_kills"] = float(direct_attrition.get("low_hp_kills", 0.0))
				ex["direct_attrition_aoe_dps"] = float(direct_attrition.get("aoe_dps", 0.0))
				ex["direct_attrition_max_targets_hit"] = float(direct_attrition.get("max_targets_hit", 0.0))
				ex["direct_attrition_burst_peak_dps"] = float(direct_attrition.get("burst_peak_dps", 0.0))
				ex["direct_attrition_burst_peak_share"] = float(direct_attrition.get("burst_peak_share", 0.0))
				ex["direct_attrition_burst_ok"] = bool(direct_attrition.get("burst_ok", false))
				ex["direct_attrition_prevented_damage"] = float(direct_attrition.get("prevented_damage_total", 0.0))
				ex["direct_attrition_support_healing"] = float(direct_attrition.get("support_healing_total", 0.0))
				ex["direct_attrition_support_shield"] = float(direct_attrition.get("support_shield_total", 0.0))
				ex["req_focus_s"] = focus_req
				ex["req_hits_survived"] = hits_req
				ex["req_time_alive_s"] = time_alive_req
				ex["sustained_ok"] = cond_sustained
				ex["survivability_ok"] = cond_surv
				RoleCommon.append_span(spans, "unit_direct_attrition_evidence", (1.0 if cond_direct_attrition else 0.0), 1.0, cond_direct_attrition, ex)
				if cond_sustained and cond_surv:
					passed_units += 1
					RoleCommon.append_span(spans, "unit_pass", 1, 1, true, ex)
					if has_subject and String(uid) == subj_id:
						subj_pass = true
				else:
					# Emit a failing per-unit span with details so callers can see why
					RoleCommon.append_span(spans, "unit_pass", 0, 1, false, ex)
		side_pass[side4] = (passed_units > 0)
		RoleCommon.append_span(spans, "%s_unit_pass_count" % side4, passed_units, 1, side_pass[side4])

	var messages: Array = []
	messages.append("scenario=%s" % scenario_label)
	messages.append("a_pass=%s" % ("true" if side_pass["a"] else "false"))
	messages.append("b_pass=%s" % ("true" if side_pass["b"] else "false"))

	if has_subject:
		return {
			"id": METRIC_ID,
			"version": VERSION,
			"pass": subj_pass,
			"spans": spans,
			"message": "; ".join(messages)
		}
	return {
		"id": METRIC_ID,
		"version": VERSION,
		"pass": (bool(side_pass["a"]) or bool(side_pass["b"])) ,
		"spans": spans,
		"message": "; ".join(messages)
	}


func _resolve_metric_threshold(list: Array, metric_name: String, cost: int, scenario: String) -> float:
	if list == null:
		return -1.0
	for entry in list:
		if entry is Dictionary and String(entry.get("metric", "")) == metric_name:
			return RoleCommon.resolve_min_threshold(entry, cost, scenario)
	return -1.0

func _metric_cfg_from_list(list: Array, metric_name: String) -> Dictionary:
	if list == null:
		return {}
	for entry in list:
		if entry is Dictionary and String(entry.get("metric", "")) == metric_name:
			return (entry as Dictionary)
	return {}

func _resolve_fallback_threshold(list: Array, metric_name: String, cost: int, scenario: String) -> float:
	return _resolve_metric_threshold(list, metric_name, cost, scenario)

func _resolve_soak_range(list: Array) -> Array:
	for entry in list:
		if entry is Dictionary and String(entry.get("metric", "")) == "soak_index_range":
			var r: Dictionary = entry.get("range", {})
			if r is Dictionary:
				return [float(r.get("min", 0.0)), float(r.get("max", 1.0))]
	return []

func _bump_direct_attrition(store: Dictionary, entry: Dictionary, side: String, uid: String, unit_entry: Dictionary) -> void:
	if String(side) == "" or String(uid) == "":
		return
	var side_store: Dictionary = store.get(side, {})
	var rec: Dictionary = side_store.get(uid, {
		"samples": 0,
		"frontline_sum": 0.0,
		"frontline_samples": 0,
		"sustain_total": 0.0,
		"time_alive_total": 0.0,
		"ramp_events": 0.0,
		"ramp_stack_max": 0.0,
		"ramp_peak_duration_s": 0.0,
		"ramp_window_duration_s": 0.0,
		"execute_events": 0.0,
		"execute_bonus_damage": 0.0,
		"low_hp_kills": 0.0,
		"aoe_dps_total": 0.0,
		"aoe_dps_samples": 0,
		"max_targets_hit": 0.0,
		"burst_peak_dps_total": 0.0,
		"burst_peak_dps_samples": 0,
		"burst_peak_share_max": 0.0,
		"prevented_damage_total": 0.0,
		"support_healing_total": 0.0,
		"support_shield_total": 0.0
	})
	rec["samples"] = int(rec.get("samples", 0)) + 1
	rec["sustain_total"] = float(rec.get("sustain_total", 0.0)) + float(unit_entry.get("healing", 0.0)) + float(unit_entry.get("shield", 0.0))
	var prevented_damage: float = _prevented_damage_from_unit(unit_entry)
	rec["sustain_total"] = float(rec.get("sustain_total", 0.0)) + prevented_damage
	rec["prevented_damage_total"] = float(rec.get("prevented_damage_total", 0.0)) + prevented_damage
	rec["time_alive_total"] = float(rec.get("time_alive_total", 0.0)) + max(0.0, float(unit_entry.get("time_alive_s", 0.0)))
	var kernels: Dictionary = entry.get("kernels", {}) if (entry is Dictionary) else {}
	var support: Dictionary = kernels.get("support", {}) if (kernels is Dictionary) else {}
	var heal_map: Dictionary = support.get("healing_per_unit", {}) if (support is Dictionary) else {}
	var heal_side: Dictionary = heal_map.get(side, {}) if (heal_map is Dictionary) else {}
	var heal_rec: Dictionary = heal_side.get(uid, {}) if (heal_side is Dictionary) else {}
	if heal_rec is Dictionary:
		var support_healing: float = float(heal_rec.get("healed", 0.0))
		rec["sustain_total"] = float(rec.get("sustain_total", 0.0)) + support_healing
		rec["support_healing_total"] = float(rec.get("support_healing_total", 0.0)) + support_healing
	var shield_map: Dictionary = support.get("shield_absorbed_per_unit", {}) if (support is Dictionary) else {}
	var shield_side: Dictionary = shield_map.get(side, {}) if (shield_map is Dictionary) else {}
	var shield_rec: Dictionary = shield_side.get(uid, {}) if (shield_side is Dictionary) else {}
	if shield_rec is Dictionary:
		var support_shield: float = float(shield_rec.get("absorbed", 0.0))
		rec["sustain_total"] = float(rec.get("sustain_total", 0.0)) + support_shield
		rec["support_shield_total"] = float(rec.get("support_shield_total", 0.0)) + support_shield
	var per_unit_kpis: Dictionary = kernels.get("per_unit_kpis", {}) if (kernels is Dictionary) else {}
	var kpi_side: Dictionary = per_unit_kpis.get(side, {}) if (per_unit_kpis is Dictionary) else {}
	var kpi_rec: Dictionary = kpi_side.get(uid, {}) if (kpi_side is Dictionary) else {}
	if kpi_rec is Dictionary and kpi_rec.has("damage_to_frontline_pct"):
		rec["frontline_sum"] = float(rec.get("frontline_sum", 0.0)) + float(kpi_rec.get("damage_to_frontline_pct", 0.0))
		rec["frontline_samples"] = int(rec.get("frontline_samples", 0)) + 1
	var patterns: Dictionary = kernels.get("combat_patterns", {}) if (kernels is Dictionary) else {}
	var per_unit_patterns: Dictionary = patterns.get("per_unit", {}) if (patterns is Dictionary) else {}
	var pattern_side: Dictionary = per_unit_patterns.get(side, {}) if (per_unit_patterns is Dictionary) else {}
	var pattern_rec: Dictionary = pattern_side.get(uid, {}) if (pattern_side is Dictionary) else {}
	if pattern_rec is Dictionary:
		rec["ramp_events"] = float(rec.get("ramp_events", 0.0)) + float(pattern_rec.get("ramp_state_events", 0.0))
		rec["ramp_stack_max"] = max(float(rec.get("ramp_stack_max", 0.0)), float(pattern_rec.get("ramp_stack_max", 0.0)))
		rec["ramp_peak_duration_s"] = max(float(rec.get("ramp_peak_duration_s", 0.0)), float(pattern_rec.get("ramp_peak_duration_s", 0.0)))
		rec["ramp_window_duration_s"] = max(float(rec.get("ramp_window_duration_s", 0.0)), float(pattern_rec.get("ramp_window_duration_s", 0.0)))
		rec["execute_events"] = float(rec.get("execute_events", 0.0)) + float(pattern_rec.get("execute_bonus_events", 0.0))
		rec["execute_bonus_damage"] = float(rec.get("execute_bonus_damage", 0.0)) + float(pattern_rec.get("execute_bonus_damage", 0.0))
		rec["low_hp_kills"] = float(rec.get("low_hp_kills", 0.0)) + float(pattern_rec.get("low_hp_kill_count", 0.0))
		rec["aoe_dps_total"] = float(rec.get("aoe_dps_total", 0.0)) + float(pattern_rec.get("aoe_dps", 0.0))
		rec["aoe_dps_samples"] = int(rec.get("aoe_dps_samples", 0)) + 1
		rec["max_targets_hit"] = max(float(rec.get("max_targets_hit", 0.0)), float(pattern_rec.get("max_targets_hit", 0.0)))
		rec["burst_peak_dps_total"] = float(rec.get("burst_peak_dps_total", 0.0)) + float(pattern_rec.get("peak_1s_dps", 0.0))
		rec["burst_peak_dps_samples"] = int(rec.get("burst_peak_dps_samples", 0)) + 1
		rec["burst_peak_share_max"] = max(float(rec.get("burst_peak_share_max", 0.0)), float(pattern_rec.get("peak_1s_damage_share", 0.0)))
	side_store[uid] = rec
	store[side] = side_store

func _prevented_damage_from_unit(unit_entry: Dictionary) -> float:
	if not (unit_entry is Dictionary):
		return 0.0
	if unit_entry.has("pre_mit_incoming") and unit_entry.has("post_mit_incoming"):
		var pre_mit: float = float(unit_entry.get("pre_mit_incoming", 0.0))
		var post_mit: float = float(unit_entry.get("post_mit_incoming", 0.0))
		return max(0.0, pre_mit - post_mit)
	return max(0.0, float(unit_entry.get("mitigated", 0.0)))

func _direct_attrition_eval(rec: Dictionary) -> Dictionary:
	if not (rec is Dictionary) or rec.is_empty():
		return {"pass": false}
	var frontline_samples: int = int(rec.get("frontline_samples", 0))
	var frontline_share: float = (float(rec.get("frontline_sum", 0.0)) / max(1.0, float(frontline_samples))) if frontline_samples > 0 else 0.0
	var effective_hps: float = float(rec.get("sustain_total", 0.0)) / max(1.0, float(rec.get("time_alive_total", 0.0)))
	var ramp_events: float = float(rec.get("ramp_events", 0.0))
	var ramp_stack_max: float = float(rec.get("ramp_stack_max", 0.0))
	var ramp_window_s: float = max(float(rec.get("ramp_peak_duration_s", 0.0)), float(rec.get("ramp_window_duration_s", 0.0)))
	var execute_events: float = float(rec.get("execute_events", 0.0))
	var low_hp_kills: float = float(rec.get("low_hp_kills", 0.0))
	var aoe_samples: int = int(rec.get("aoe_dps_samples", 0))
	var aoe_dps: float = float(rec.get("aoe_dps_total", 0.0)) / max(1.0, float(aoe_samples))
	var max_targets_hit: float = float(rec.get("max_targets_hit", 0.0))
	var burst_samples: int = int(rec.get("burst_peak_dps_samples", 0))
	var burst_peak_dps: float = float(rec.get("burst_peak_dps_total", 0.0)) / max(1.0, float(burst_samples))
	var burst_peak_share: float = float(rec.get("burst_peak_share_max", 0.0))
	var frontline_ok: bool = frontline_samples > 0 and frontline_share >= 0.40
	var sustain_ok: bool = effective_hps >= 2.0
	var ramp_ok: bool = ramp_events >= 1.0 and (ramp_stack_max >= 2.0 or ramp_window_s >= 1.0)
	var execute_ok: bool = execute_events >= 1.0 or low_hp_kills >= 1.0
	var aoe_ok: bool = aoe_dps >= 4.0 or max_targets_hit >= 2.0
	var burst_ok: bool = burst_peak_dps >= 25.0 or burst_peak_share >= 0.25
	var pressure_ok: bool = ramp_ok or execute_ok or aoe_ok or burst_ok
	return {
		"pass": frontline_ok and sustain_ok and pressure_ok,
		"frontline_share": frontline_share,
		"effective_hps": effective_hps,
		"ramp_events": ramp_events,
		"ramp_stack_max": ramp_stack_max,
		"ramp_window_s": ramp_window_s,
		"execute_events": execute_events,
		"low_hp_kills": low_hp_kills,
		"aoe_dps": aoe_dps,
		"max_targets_hit": max_targets_hit,
		"burst_peak_dps": burst_peak_dps,
		"burst_peak_share": burst_peak_share,
		"prevented_damage_total": float(rec.get("prevented_damage_total", 0.0)),
		"support_healing_total": float(rec.get("support_healing_total", 0.0)),
		"support_shield_total": float(rec.get("support_shield_total", 0.0)),
		"frontline_ok": frontline_ok,
		"sustain_ok": sustain_ok,
		"ramp_ok": ramp_ok,
		"execute_ok": execute_ok,
		"aoe_ok": aoe_ok,
		"burst_ok": burst_ok,
		"pressure_ok": pressure_ok
	}
