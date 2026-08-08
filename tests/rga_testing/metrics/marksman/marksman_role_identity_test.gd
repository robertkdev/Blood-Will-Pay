extends RefCounted

# Marksman Role Identity Test
# Pass condition: sustained DPS leadership (peer-relative or a direct 3-10s
# window) plus backline/ranged positional presence. Utility marksman goals may
# instead prove a modest damage floor plus ranged uptime because their primary
# goal metric separately verifies the non-DPS contribution.

const VERSION := "1.0.0"
const METRIC_ID := "role_marksman_identity"

const RoleCommon := preload("res://tests/rga_testing/metrics/_shared/role_common.gd")

const REQUIRED_CAPS = ["base"] # positioning prefers mobility/zones, but fallback allowed
const DIRECT_SUSTAINED_TEAM_SHARE_MIN: float = 0.25
const DIRECT_SUSTAINED_RATE_MIN: float = 8.0
const UTILITY_DAMAGE_SHARE_FLOOR: float = 0.05

func get_metadata() -> Dictionary:
	return {
		"id": METRIC_ID,
		"version": VERSION,
		"required_capabilities": REQUIRED_CAPS,
		"description": "Marksman identity via sustained DPS leadership and backline zoning presence (with fallback)."
	}

func run_metric(payload: Dictionary = {}) -> Dictionary:
	var ctx: Dictionary = payload.get("context", {})
	var sims: Dictionary = ctx.get("sims", {}) if ctx is Dictionary else {}
	if sims.is_empty():
		return RoleCommon.fail_result([], ["no_sims_in_context"])

	var subject_set: Dictionary = RoleCommon.subject_set_from_payload(payload)

	var thresholds_all: Dictionary = RoleCommon.load_thresholds()
	var cfg: Dictionary = RoleCommon.role_threshold(thresholds_all, "marksman")
	var kcfg: Dictionary = cfg.get("k_of_n", {"k": 2, "n": 2})
	var metrics_cfg: Dictionary = cfg.get("metrics", {})
	var sus_cfg: Dictionary = metrics_cfg.get("sustained_damage_rate", {})
	var bl_cfg: Dictionary = metrics_cfg.get("backline_zone_share", {})
	var share_cfg: Dictionary = metrics_cfg.get("team_damage_share", {})

	var scenario_label: String = String(ctx.get("scenario", "neutral"))
	var assumed_cost_band: int = 3

	# sustained comparisons
	var cmp: Dictionary = sus_cfg.get("comparison", {})
	var mult_req: float = float(cmp.get("median_multiplier", 1.25))
	var z_req: float = float(cmp.get("z_min", 1.0))
	var bl_req: float = float(RoleCommon.resolve_min_threshold(bl_cfg, assumed_cost_band, scenario_label))
	if bl_req <= 0.0:
		bl_req = 0.60
	var share_req: float = float(RoleCommon.resolve_min_threshold(share_cfg, assumed_cost_band, scenario_label))
	if share_req <= 0.0:
		share_req = 0.30
	var default_long_range_cfg: Dictionary = RoleCommon.approach_threshold(thresholds_all, "long_range")
	var default_long_range_metrics: Dictionary = default_long_range_cfg.get("metrics", {})
	var default_long_range_share_cfg: Dictionary = default_long_range_metrics.get("attacks_over_2_tiles_share", {})
	var ranged_proxy_req: float = float(RoleCommon.resolve_min_threshold(default_long_range_share_cfg, assumed_cost_band, scenario_label))
	if ranged_proxy_req <= 0.0:
		ranged_proxy_req = 0.50

	var peers_all: Array = []
	var side_top_rates: Dictionary = {"a": [], "b": []}
	var backline_shares: Dictionary = {"a": [], "b": []}
	var ranged_proxy: Dictionary = {"a": [], "b": []}
	var top_team_share: Dictionary = {"a": [], "b": []}  # legacy fallback
	var candidate_team_share: Dictionary = {"a": [], "b": []}
	var candidate_counts: Dictionary = {"a": {}, "b": {}}  # side -> uid -> int (occurrences across sims)
	var subj_id: String = (String(subject_set.keys()[0]) if (subject_set is Dictionary and not subject_set.is_empty()) else "")
	var subject_range_req: float = bl_req
	if subj_id != "":
		var subject_identity: Dictionary = RoleCommon.get_identity(subj_id)
		var subject_approaches: Array = subject_identity.get("approaches", [])
		var subject_has_long_range: bool = false
		for raw_approach: Variant in subject_approaches:
			if String(raw_approach).strip_edges().to_lower() == "long_range":
				subject_has_long_range = true
				break
		if subject_has_long_range:
			var long_range_cfg: Dictionary = RoleCommon.approach_threshold(thresholds_all, "long_range")
			var long_range_metrics: Dictionary = long_range_cfg.get("metrics", {})
			var long_range_share_cfg: Dictionary = long_range_metrics.get("attacks_over_2_tiles_share", {})
			var subject_cost_band: int = int(subject_identity.get("cost", assumed_cost_band))
			var resolved_subject_range_req: float = float(RoleCommon.resolve_min_threshold(long_range_share_cfg, subject_cost_band, scenario_label))
			if resolved_subject_range_req > 0.0:
				subject_range_req = resolved_subject_range_req
	var subj_rate_samples: Array = []
	var subj_share_samples: Array = []
	var subj_ranged_proxy: Array = []
	var subj_tot_samples: Array = []
	var subj_dist_samples: Array = []
	var subj_sustained_window_samples: Array[Dictionary] = []

	for key in sims.keys():
		var entry: Dictionary = sims.get(key, {})
		if not (entry is Dictionary):
			continue
		var kernels: Dictionary = entry.get("kernels", {})
		var th: Dictionary = kernels.get("throughput", {})
		if th is Dictionary:
			var peers_block: Dictionary = th.get("peers", {})
			if peers_block is Dictionary:
				var arr_all: Variant = peers_block.get("all", [])
				if arr_all is Array:
					for v in arr_all: peers_all.append(float(v))
				for side in ["a","b"]:
					var arr_side: Variant = peers_block.get(side, [])
					if arr_side is Array and arr_side.size() > 0:
						var mx: float = 0.0
						for r in arr_side: mx = max(mx, float(r))
						(side_top_rates[side] as Array).append(mx)
			if subj_id != "":
				var peers_idx: Dictionary = th.get("peers_by_index", {})
				if peers_idx is Dictionary:
					var units_map: Dictionary = entry.get("units", {})
					for s in ["a","b"]:
						var arr_units: Array = units_map.get(s, [])
						if not (arr_units is Array):
							continue
						var idx_to_uid: Dictionary = {}
						for i in range(arr_units.size()):
							var uu: Variant = arr_units[i]
							if uu is Dictionary:
								idx_to_uid[i] = String(uu.get("unit_id", ""))
						var map_side: Dictionary = peers_idx.get(s, {})
						if map_side is Dictionary:
							for mk in map_side.keys():
								var idx: int = int(mk)
								var uid: String = String(idx_to_uid.get(idx, ""))
								if uid == subj_id:
									subj_rate_samples.append(float(map_side.get(mk, 0.0)))
		var pos: Dictionary = kernels.get("positioning", {})
		if pos is Dictionary:
			for side2 in ["a","b"]:
				var obj: Dictionary = pos.get(side2, {})
				if obj is Dictionary and obj.has("backline_zone_share"):
					(backline_shares[side2] as Array).append(float(obj.get("backline_zone_share", 0.0)))
		var puk: Dictionary = kernels.get("per_unit_kpis", {})
		if puk is Dictionary:
			# Fallback proxy: overall share of attacks over 2 tiles by side (median across units)
			for side3 in ["a","b"]:
				var side_map: Dictionary = puk.get(side3, {})
				if side_map is Dictionary and side_map.size() > 0:
					var per_unit_vals: Array = []
					for uid in side_map.keys():
						var v: Dictionary = side_map.get(uid, {})
						if v is Dictionary:
							var ranged_hit_share: float = float(v.get("attacks_over_2_tiles_pct", 0.0))
							var ranged_damage_share: float = float(v.get("damage_over_2_tiles_pct", 0.0))
							var ranged_evidence: float = maxf(ranged_hit_share, ranged_damage_share)
							per_unit_vals.append(ranged_evidence)
						if subj_id != "" and String(uid) == subj_id and v is Dictionary:
							subj_ranged_proxy.append(maxf(float(v.get("attacks_over_2_tiles_pct", 0.0)), float(v.get("damage_over_2_tiles_pct", 0.0))))
							subj_tot_samples.append(float(v.get("time_on_target_pct", 0.0)))
							subj_dist_samples.append(float(v.get("attack_distance_median_tiles", 0.0)))
					if per_unit_vals.size() > 0:
						(ranged_proxy[side3] as Array).append(RoleCommon.median(per_unit_vals))
		if subj_id != "":
			var combat_patterns: Dictionary = kernels.get("combat_patterns", {})
			var pattern_per_unit: Dictionary = combat_patterns.get("per_unit", {}) if combat_patterns is Dictionary else {}
			for pattern_side: String in ["a", "b"]:
				var pattern_side_map: Dictionary = pattern_per_unit.get(pattern_side, {}) if pattern_per_unit is Dictionary else {}
				var pattern_rec: Dictionary = pattern_side_map.get(subj_id, {}) if pattern_side_map is Dictionary else {}
				if pattern_rec.is_empty():
					continue
				subj_sustained_window_samples.append({
					"team_share": float(pattern_rec.get("sustained_3_10s_team_share", 0.0)),
					"rate": float(pattern_rec.get("sustained_3_10s_rate", 0.0))
				})
		# Compute team damage share for candidate marksman per side, with fallback to top share
		var teams: Dictionary = entry.get("teams", {})
		var units: Dictionary = entry.get("units", {})
		for s4 in ["a","b"]:
			var t_obj: Dictionary = teams.get(s4, {})
			var u_arr: Array = units.get(s4, [])
			if not (t_obj is Dictionary) or not (u_arr is Array) or u_arr.is_empty():
				continue
			var team_total: float = float(t_obj.get("damage", 0))
			if team_total <= 0.0:
				continue
			# Build a quick lookup of unit_id -> damage for this sim/side
			var dmg_by_uid: Dictionary = {}
			for u in u_arr:
				if not (u is Dictionary):
					continue
				var uid_s: String = String((u as Dictionary).get("unit_id", ""))
				if uid_s == "":
					continue
				dmg_by_uid[uid_s] = float((u as Dictionary).get("damage", 0))
			if subj_id != "" and dmg_by_uid.has(subj_id):
				var subj_dmg: float = float(dmg_by_uid.get(subj_id, 0.0))
				var share_subj: float = subj_dmg / max(1.0, team_total)
				subj_share_samples.append(share_subj)
			# Candidate selection using per_unit_kpis when available
			var candidate_id: String = ""
			if puk is Dictionary:
				var side_map2: Dictionary = puk.get(s4, {})
				if side_map2 is Dictionary and side_map2.size() > 0:
					var best_score: float = -INF
					var tot_min: float = 0.25  # reasonable on-target requirement for attribution
					for cid in side_map2.keys():
						var stats: Dictionary = side_map2.get(cid, {})
						if not (stats is Dictionary):
							continue
						var tot: float = float(stats.get("time_on_target_pct", 0.0))
						var over2: float = maxf(float(stats.get("attacks_over_2_tiles_pct", 0.0)), float(stats.get("damage_over_2_tiles_pct", 0.0)))
						var dist: float = float(stats.get("attack_distance_median_tiles", 0.0))
						# Require some on-target time; otherwise accept as weaker candidate
						var base_ok: bool = (tot >= tot_min)
						var score: float = over2 * 1000.0 + dist  # prioritize ranged behavior
						if base_ok and score > best_score:
							best_score = score
							candidate_id = String(cid)
					# If no base_ok, pick highest score regardless (still better than top-share)
					if candidate_id == "":
						for cid2 in side_map2.keys():
							var stats2: Dictionary = side_map2.get(cid2, {})
							if not (stats2 is Dictionary):
								continue
							var over22: float = maxf(float(stats2.get("attacks_over_2_tiles_pct", 0.0)), float(stats2.get("damage_over_2_tiles_pct", 0.0)))
							var dist2: float = float(stats2.get("attack_distance_median_tiles", 0.0))
							var score2: float = over22 * 1000.0 + dist2
							if score2 > best_score:
								best_score = score2
								candidate_id = String(cid2)
			var appended: bool = false
			if candidate_id != "" and dmg_by_uid.has(candidate_id):
				var udmg2: float = float(dmg_by_uid.get(candidate_id, 0.0))
				var share2: float = udmg2 / max(1.0, team_total)
				(candidate_team_share[s4] as Array).append(share2)
				var ccount: Dictionary = candidate_counts.get(s4, {})
				ccount[candidate_id] = int(ccount.get(candidate_id, 0)) + 1
				candidate_counts[s4] = ccount
				appended = true
			# Fallback to legacy top-share when no candidate is available
			var best_share: float = 0.0
			for u2 in u_arr:
				if not (u2 is Dictionary):
					continue
				var udmg: float = float((u2 as Dictionary).get("damage", 0))
				var share: float = udmg / max(1.0, team_total)
				if share > best_share:
					best_share = share
			(top_team_share[s4] as Array).append(best_share)

	var med_all: float = RoleCommon.median(peers_all)
	var leader_med: Dictionary = {"a": RoleCommon.median(side_top_rates["a"]), "b": RoleCommon.median(side_top_rates["b"]) }
	var leader_mult: Dictionary = {"a": RoleCommon.multiplier_vs_median(leader_med["a"], med_all), "b": RoleCommon.multiplier_vs_median(leader_med["b"], med_all)}
	var leader_z: Dictionary = {"a": RoleCommon.z_from_band(leader_med["a"], peers_all), "b": RoleCommon.z_from_band(leader_med["b"], peers_all)}
	var sustained_pass: Dictionary = {"a": (leader_mult["a"] >= mult_req or leader_z["a"] >= z_req), "b": (leader_mult["b"] >= mult_req or leader_z["b"] >= z_req)}
	# Prefer candidate-based shares when we have them; fall back to top-share otherwise
	var share_med: Dictionary = {"a": 0.0, "b": 0.0}
	for s in ["a","b"]:
		if (candidate_team_share[s] as Array).size() > 0:
			share_med[s] = RoleCommon.median(candidate_team_share[s])
		else:
			share_med[s] = RoleCommon.median(top_team_share[s])
	var share_pass: Dictionary = {"a": (share_med["a"] >= share_req), "b": (share_med["b"] >= share_req)}

	# Positioning: prefer real backline share; fallback to ranged proxy
	var bl_med: Dictionary = {"a": RoleCommon.median(backline_shares["a"]), "b": RoleCommon.median(backline_shares["b"]) }
	var rp_med: Dictionary = {"a": RoleCommon.median(ranged_proxy["a"]), "b": RoleCommon.median(ranged_proxy["b"]) }
	var pos_pass: Dictionary = {"a": false, "b": false}
	for s in ["a", "b"]:
		if backline_shares[s].size() > 0:
			pos_pass[s] = (bl_med[s] >= bl_req)
		else:
			pos_pass[s] = (rp_med[s] >= ranged_proxy_req) # proxy uses its own canonical metric threshold

	var sx: String = _any_side_for_subject(sims, subj_id) if subj_id != "" else ""
	var subj_rate_med: float = RoleCommon.median(subj_rate_samples)
	var med_all_subj: float = med_all
	var subj_mult: float = 0.0
	if peers_all.size() > 0:
		subj_mult = RoleCommon.multiplier_vs_median(subj_rate_med, med_all_subj)
	var subj_z: float = RoleCommon.z_from_band(subj_rate_med, peers_all)
	var subj_share_med: float = RoleCommon.median(subj_share_samples)
	var subj_proxy_med: float = RoleCommon.median(subj_ranged_proxy)
	var direct_sustained_team_share_peak: float = 0.0
	var direct_sustained_rate_peak: float = 0.0
	var cond_direct_sustained_subj: bool = false
	for sustained_window: Dictionary in subj_sustained_window_samples:
		var window_team_share: float = float(sustained_window.get("team_share", 0.0))
		var window_rate: float = float(sustained_window.get("rate", 0.0))
		direct_sustained_team_share_peak = maxf(direct_sustained_team_share_peak, window_team_share)
		direct_sustained_rate_peak = maxf(direct_sustained_rate_peak, window_rate)
		if window_team_share >= DIRECT_SUSTAINED_TEAM_SHARE_MIN and window_rate >= DIRECT_SUSTAINED_RATE_MIN:
			cond_direct_sustained_subj = true
	var cond_peer_sustained_subj: bool = (subj_mult >= mult_req or subj_z >= z_req)
	var cond_sustained_subj: bool = cond_peer_sustained_subj or cond_direct_sustained_subj
	var cond_share_subj: bool = (subj_share_med >= share_req)
	var cond_pos_subj: bool = (subj_proxy_med >= subject_range_req)
	var tot_med: float = RoleCommon.median(subj_tot_samples)
	var dist_med: float = RoleCommon.median(subj_dist_samples)
	var TOT_MIN: float = 0.25
	var cond_tot: bool = (tot_med >= TOT_MIN)
	var subject_primary_goal: String = ""
	if subj_id != "":
		var subject_identity_for_goal: Dictionary = RoleCommon.get_identity(subj_id)
		subject_primary_goal = String(subject_identity_for_goal.get("primary_goal", "")).strip_edges().to_lower()
	var is_utility_marksman_goal: bool = subject_primary_goal.begins_with("marksman.") and subject_primary_goal != "marksman.sustained_dps"
	var cond_utility_contribution_subj: bool = is_utility_marksman_goal and subj_share_med >= UTILITY_DAMAGE_SHARE_FLOOR
	var pass_subj: bool = cond_pos_subj and cond_tot and (cond_sustained_subj or cond_utility_contribution_subj)

	# Required: sustained DPS leadership AND positional backline/ranged presence (team_damage_share is auxiliary)
	var pass_a: bool = bool(sustained_pass["a"] and pos_pass["a"])
	var pass_b: bool = bool(sustained_pass["b"] and pos_pass["b"])

	var spans: Array = []
	RoleCommon.append_span(spans, "sustained_leader_mult_a", leader_mult["a"], mult_req, sustained_pass["a"])
	RoleCommon.append_span(spans, "sustained_leader_mult_b", leader_mult["b"], mult_req, sustained_pass["b"])
	RoleCommon.append_span(spans, "sustained_leader_z_a", leader_z["a"], z_req, sustained_pass["a"])
	RoleCommon.append_span(spans, "sustained_leader_z_b", leader_z["b"], z_req, sustained_pass["b"])
	var backline_extra_a: Dictionary = {}
	var backline_extra_b: Dictionary = {}
	var backline_ok_a: Variant = pos_pass["a"]
	var backline_ok_b: Variant = pos_pass["b"]
	if sx == "a" and not bool(pos_pass["a"]) and pass_subj:
		backline_ok_a = null
		backline_extra_a["reason"] = "alternate_marksman_ranged_evidence_satisfied"
	if sx == "b" and not bool(pos_pass["b"]) and pass_subj:
		backline_ok_b = null
		backline_extra_b["reason"] = "alternate_marksman_ranged_evidence_satisfied"
	RoleCommon.append_span(spans, "backline_share_med_a", bl_med["a"], bl_req, backline_ok_a, backline_extra_a)
	RoleCommon.append_span(spans, "backline_share_med_b", bl_med["b"], bl_req, backline_ok_b, backline_extra_b)
	var dom_cand: Dictionary = {"a": "", "b": ""}
	var dom_frac: Dictionary = {"a": 0.0, "b": 0.0}
	for s2 in ["a","b"]:
		var counts: Dictionary = candidate_counts.get(s2, {})
		var best_id: String = ""
		var best_n: int = 0
		var total_n: int = 0
		for k in counts.keys():
			var n: int = int(counts.get(k, 0))
			total_n += n
			if n > best_n:
				best_n = n
				best_id = String(k)
		dom_cand[s2] = best_id
		dom_frac[s2] = (float(best_n) / max(1.0, float(total_n))) if total_n > 0 else 0.0
	var team_share_extra_a: Dictionary = {"candidate_id": dom_cand["a"], "candidate_support": dom_frac["a"]}
	var team_share_extra_b: Dictionary = {"candidate_id": dom_cand["b"], "candidate_support": dom_frac["b"]}
	var team_share_ok_a: Variant = share_pass["a"]
	var team_share_ok_b: Variant = share_pass["b"]
	if not bool(share_pass["a"]):
		team_share_ok_a = null
		team_share_extra_a["reason"] = "auxiliary_marksman_damage_share_not_required"
	if not bool(share_pass["b"]):
		team_share_ok_b = null
		team_share_extra_b["reason"] = "auxiliary_marksman_damage_share_not_required"
	RoleCommon.append_span(spans, "team_share_med_a", share_med["a"], share_req, team_share_ok_a, team_share_extra_a)
	RoleCommon.append_span(spans, "team_share_med_b", share_med["b"], share_req, team_share_ok_b, team_share_extra_b)

	var messages: Array = []
	messages.append("scenario=%s" % scenario_label)
	messages.append("a_pass=%s" % ("true" if pass_a else "false"))
	messages.append("b_pass=%s" % ("true" if pass_b else "false"))

	# Subject-specific evaluation and spans
	if subj_id != "":
		var reason: String = "" if cond_tot else "low_time_on_target"
		var ex: Dictionary = RoleCommon.subject_extras(sx, subj_id, (reason if reason != "" else ("no_samples" if (subj_rate_samples.size()==0 and subj_share_samples.size()==0) else "")))
		ex["subject_attack_distance_med_tiles"] = dist_med
		var peer_sustained_span_ok: Variant = cond_peer_sustained_subj
		var peer_sustained_ex: Dictionary = ex.duplicate(true)
		if not cond_peer_sustained_subj and cond_direct_sustained_subj:
			peer_sustained_span_ok = null
			peer_sustained_ex["reason"] = "alternate_sustained_window_evidence_satisfied"
		elif not cond_peer_sustained_subj and cond_utility_contribution_subj:
			peer_sustained_span_ok = null
			peer_sustained_ex["reason"] = "utility_marksman_goal_variant"
		RoleCommon.append_span(spans, "subject_sustained_mult", subj_mult, mult_req, peer_sustained_span_ok, peer_sustained_ex)
		RoleCommon.append_span(spans, "subject_sustained_z", subj_z, z_req, peer_sustained_span_ok, peer_sustained_ex)
		if not subj_sustained_window_samples.is_empty():
			var window_share_ok: Variant = direct_sustained_team_share_peak >= DIRECT_SUSTAINED_TEAM_SHARE_MIN
			var window_rate_ok: Variant = direct_sustained_rate_peak >= DIRECT_SUSTAINED_RATE_MIN
			var window_ex: Dictionary = ex.duplicate(true)
			if not cond_direct_sustained_subj and cond_utility_contribution_subj:
				window_share_ok = null
				window_rate_ok = null
				window_ex["reason"] = "utility_marksman_goal_variant"
			RoleCommon.append_span(spans, "subject_sustained_3_10s_team_share", direct_sustained_team_share_peak, DIRECT_SUSTAINED_TEAM_SHARE_MIN, window_share_ok, window_ex)
			RoleCommon.append_span(spans, "subject_sustained_3_10s_rate", direct_sustained_rate_peak, DIRECT_SUSTAINED_RATE_MIN, window_rate_ok, window_ex)
		if is_utility_marksman_goal:
			RoleCommon.append_span(spans, "subject_utility_damage_share_floor", subj_share_med, UTILITY_DAMAGE_SHARE_FLOOR, cond_utility_contribution_subj, ex)
		var subj_share_ex: Dictionary = ex.duplicate(true)
		var subj_share_ok: Variant = cond_share_subj
		if not cond_share_subj and pass_subj:
			subj_share_ok = null
			subj_share_ex["reason"] = "auxiliary_marksman_damage_share_not_required"
		RoleCommon.append_span(spans, "subject_team_damage_share_med", subj_share_med, share_req, subj_share_ok, subj_share_ex)
		RoleCommon.append_span(spans, "subject_ranged_proxy_med", subj_proxy_med, subject_range_req, cond_pos_subj, ex)
		RoleCommon.append_span(spans, "subject_time_on_target_med", tot_med, TOT_MIN, cond_tot, ex)
		return {
			"id": METRIC_ID,
			"version": VERSION,
			"pass": pass_subj,
			"spans": spans,
			"message": "; ".join(messages)
		}

	return {
		"id": METRIC_ID,
		"version": VERSION,
		"pass": (pass_a or pass_b),
		"spans": spans,
		"message": "; ".join(messages)
	}

func _subject_side(entry: Dictionary, subject_id: String) -> String:
	var c: Dictionary = entry.get("context", {})
	var a: Array = c.get("team_a_ids", [])
	var b: Array = c.get("team_b_ids", [])
	var sid: String = String(subject_id)
	for x in a:
		if String(x) == sid:
			return "a"
	for y in b:
		if String(y) == sid:
			return "b"
	return ""

func _any_side_for_subject(sims: Dictionary, subject_id: String) -> String:
	for k in sims.keys():
		var s: String = _subject_side(sims.get(k, {}), subject_id)
		if s != "":
			return s
	return "a"
