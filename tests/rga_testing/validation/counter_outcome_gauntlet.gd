extends Node

const DataModels = preload("res://tests/rga_testing/core/data_models.gd")
const LockstepSimulator = preload("res://tests/rga_testing/core/lockstep_simulator.gd")
const CombatStatsCollector = preload("res://tests/rga_testing/aggregators/combat_stats_collector.gd")

const RUN_ID: String = "counter_outcome_gauntlet"
const BASE_SEED: int = 5401
const SEEDS_PER_CASE: int = 2
const DELTA_S: float = 0.05
const TIMEOUT_S: float = 90.0
const MAX_WALL_CLOCK_MS: int = 5000

var _sim_index: int = 0
var _results: Array[Dictionary] = []

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	for case: Dictionary in _cases():
		var result: Dictionary = _run_contract_case(case)
		_results.append(result)
		_print_case_result(result)
		if not bool(result.get("passed", false)):
			failures.append(String(result.get("failure", "unknown counter contract failure")))
	_write_results()
	if failures.size() > 0:
		for failure: String in failures:
			push_error(failure)
		get_tree().quit(1)
		return
	print("CounterOutcomeGauntlet: PASS cases=%d sims=%d output=%s" % [_results.size(), _sim_index, _results_path()])
	get_tree().quit(0)

func _cases() -> Array[Dictionary]:
	return [
		{
			"id": "peel_vs_backline_access",
			"label": "Peel board should protect a carry better than a no-peel board into divers.",
			"counter_team": ["bastionne", "sari", "totem", "paisley"],
			"baseline_team": ["draxelle", "sari", "volt", "luna"],
			"threat_team": ["pilfer", "bo", "creep", "hexeon"],
			"protected_index": 1,
			"baseline_protected_index": 1,
			"min_score_delta": 20.0,
			"min_protected_time_delta": 4.0,
		},
		{
			"id": "redirect_vs_backline_access",
			"label": "Redirect board should preserve the carry better than a similar non-redirect front line.",
			"counter_team": ["korath", "sari", "mara", "axiom"],
			"baseline_team": ["brute", "sari", "mara", "axiom"],
			"threat_team": ["pilfer", "bo", "creep", "hexeon"],
			"protected_index": 1,
			"baseline_protected_index": 1,
			"min_score_delta": 20.0,
			"min_protected_time_delta": 0.5,
		},
		{
			"id": "zone_vs_engage",
			"label": "Zone board should do better into engage than a comparable non-zone damage board.",
			"counter_team": ["brute", "cinder", "prisma", "sari"],
			"baseline_team": ["brute", "luna", "mara", "sari"],
			"threat_team": ["grint", "bo", "miri", "draxelle"],
			"protected_index": 3,
			"baseline_protected_index": 3,
			"min_score_delta": 20.0,
			"min_protected_time_delta": 2.0,
		},
		{
			"id": "cc_immunity_vs_lockdown",
			"label": "CC-immunity board should improve into lockdown/control versus a no-immunity board.",
			"counter_team": ["veyra", "rooket", "totem", "sari"],
			"baseline_team": ["kythera", "sari", "axiom", "mara"],
			"threat_team": ["brute", "knoll", "volt", "velour"],
			"protected_index": 3,
			"baseline_protected_index": 1,
			"min_score_delta": 20.0,
			"min_protected_time_delta": 2.0,
		},
	]

func _run_contract_case(case: Dictionary) -> Dictionary:
	var counter_team: Array[String] = _string_array(case.get("counter_team", []))
	var baseline_team: Array[String] = _string_array(case.get("baseline_team", []))
	var threat_team: Array[String] = _string_array(case.get("threat_team", []))
	var protected_index: int = int(case.get("protected_index", -1))
	var baseline_protected_index: int = int(case.get("baseline_protected_index", protected_index))
	var counter_summary: Dictionary = _run_team_set(String(case.get("id", "")), "counter", counter_team, threat_team, protected_index)
	var baseline_summary: Dictionary = _run_team_set(String(case.get("id", "")), "baseline", baseline_team, threat_team, baseline_protected_index)
	var counter_score: float = _contract_score(counter_summary)
	var baseline_score: float = _contract_score(baseline_summary)
	var score_delta: float = counter_score - baseline_score
	var protected_delta: float = float(counter_summary.get("avg_protected_time_s", 0.0)) - float(baseline_summary.get("avg_protected_time_s", 0.0))
	var win_delta: int = int(counter_summary.get("wins", 0)) - int(baseline_summary.get("wins", 0))
	var min_score_delta: float = float(case.get("min_score_delta", 20.0))
	var min_protected_time_delta: float = float(case.get("min_protected_time_delta", 0.0))
	var strength: String = _counter_strength(win_delta, score_delta, protected_delta, min_score_delta, min_protected_time_delta)
	var passed: bool = strength != "weak"
	var failure: String = ""
	if not passed:
		failure = "CounterOutcomeGauntlet: %s failed score_delta=%.1f protected_delta=%.1f win_delta=%d counter=%s baseline=%s threat=%s" % [
			String(case.get("id", "")),
			score_delta,
			protected_delta,
			win_delta,
			", ".join(counter_team),
			", ".join(baseline_team),
			", ".join(threat_team),
		]
	return {
		"id": String(case.get("id", "")),
		"label": String(case.get("label", "")),
		"passed": passed,
		"failure": failure,
		"counter": counter_summary,
		"baseline": baseline_summary,
		"strength": strength,
		"hard_counter": strength == "hard",
		"needs_tuning": strength != "hard",
		"score_delta": score_delta,
		"protected_time_delta_s": protected_delta,
		"win_delta": win_delta,
	}

func _run_team_set(case_id: String, variant_id: String, team_a_ids: Array[String], team_b_ids: Array[String], protected_index: int) -> Dictionary:
	var wins: int = 0
	var losses: int = 0
	var timeouts: int = 0
	var total_time_s: float = 0.0
	var total_alive: float = 0.0
	var total_enemy_alive: float = 0.0
	var total_damage: float = 0.0
	var total_enemy_damage: float = 0.0
	var total_healing: float = 0.0
	var total_shield: float = 0.0
	var total_mitigated: float = 0.0
	var total_protected_time: float = 0.0
	var samples: Array[Dictionary] = []
	for repeat_index: int in range(SEEDS_PER_CASE):
		var seed: int = BASE_SEED + _sim_index * 37 + repeat_index
		var sample: Dictionary = _simulate(case_id, variant_id, team_a_ids, team_b_ids, protected_index, seed)
		samples.append(sample)
		var result: String = String(sample.get("result", "missing"))
		if result == "team_a":
			wins += 1
		elif result == "team_b":
			losses += 1
		else:
			timeouts += 1
		total_time_s += float(sample.get("time_s", 0.0))
		total_alive += float(sample.get("team_a_alive", 0))
		total_enemy_alive += float(sample.get("team_b_alive", 0))
		total_damage += float(sample.get("a_damage", 0))
		total_enemy_damage += float(sample.get("b_damage", 0))
		total_healing += float(sample.get("a_healing", 0))
		total_shield += float(sample.get("a_shield", 0))
		total_mitigated += float(sample.get("a_mitigated", 0))
		total_protected_time += float(sample.get("protected_time_s", 0.0))
	var count: float = max(1.0, float(SEEDS_PER_CASE))
	return {
		"variant": variant_id,
		"team": team_a_ids.duplicate(),
		"threat": team_b_ids.duplicate(),
		"wins": wins,
		"losses": losses,
		"timeouts": timeouts,
		"avg_time_s": total_time_s / count,
		"avg_alive": total_alive / count,
		"avg_enemy_alive": total_enemy_alive / count,
		"avg_damage": total_damage / count,
		"avg_enemy_damage": total_enemy_damage / count,
		"avg_healing": total_healing / count,
		"avg_shield": total_shield / count,
		"avg_mitigated": total_mitigated / count,
		"avg_protected_time_s": total_protected_time / count,
		"samples": samples,
	}

func _simulate(case_id: String, variant_id: String, team_a_ids: Array[String], team_b_ids: Array[String], protected_index: int, seed: int) -> Dictionary:
	var job: DataModels.SimJob = DataModels.SimJob.new()
	job.run_id = RUN_ID
	job.sim_index = _sim_index
	job.seed = seed
	job.team_a_ids = team_a_ids.duplicate()
	job.team_b_ids = team_b_ids.duplicate()
	job.team_size = max(team_a_ids.size(), team_b_ids.size())
	job.scenario_id = "open_field"
	job.map_params = _map_params(case_id)
	# Counter contracts must expose the named answer before the fast dive opener.
	# This tests whether the mechanic works when available, while the neutral RGA
	# matrix separately measures ordinary mana timing and whole-fight balance.
	if variant_id == "counter" and case_id == "peel_vs_backline_access":
		job.map_params["team_a_initial_mana_ids"] = ["bastionne", "totem", "paisley"]
		job.map_params["team_a_initial_mana_pct"] = 1.0
	elif variant_id == "counter" and case_id == "redirect_vs_backline_access":
		job.map_params["team_a_subject_id"] = "korath"
		job.map_params["team_a_subject_initial_mana_pct"] = 1.0
	job.deterministic = true
	job.delta_s = DELTA_S
	job.timeout_s = TIMEOUT_S
	job.abilities = true
	job.ability_metrics = false
	job.alternate_order = false
	job.bridge_projectile_to_hit = true
	job.capabilities = PackedStringArray(["base"])
	job.metadata = {
		"scenario_label": "counter_outcome_gauntlet_" + case_id,
		"case_id": case_id,
		"variant_id": variant_id,
		"perf_adaptive": true,
		"perf_fast_dt": 0.20,
		"perf_margin_tiles": 0.75,
		"max_wall_clock_ms": MAX_WALL_CLOCK_MS,
	}
	var simulator: LockstepSimulator = LockstepSimulator.new()
	var collector: CombatStatsCollector = CombatStatsCollector.new()
	var sim_out: Dictionary = simulator.run(job, false, collector)
	var outcome: Variant = sim_out.get("engine_outcome", null)
	var aggregates: Dictionary = sim_out.get("aggregates", {}) if typeof(sim_out.get("aggregates", {})) == TYPE_DICTIONARY else {}
	var teams: Dictionary = aggregates.get("teams", {}) if typeof(aggregates.get("teams", {})) == TYPE_DICTIONARY else {}
	var team_a: Dictionary = teams.get("a", {}) if typeof(teams.get("a", {})) == TYPE_DICTIONARY else {}
	var team_b: Dictionary = teams.get("b", {}) if typeof(teams.get("b", {})) == TYPE_DICTIONARY else {}
	var units: Dictionary = aggregates.get("units", {}) if typeof(aggregates.get("units", {})) == TYPE_DICTIONARY else {}
	var units_a: Array = units.get("a", []) if typeof(units.get("a", [])) == TYPE_ARRAY else []
	var units_b: Array = units.get("b", []) if typeof(units.get("b", [])) == TYPE_ARRAY else []
	var protected_entry: Dictionary = _protected_entry(units_a, protected_index)
	var protected_time_s: float = float(protected_entry.get("time_alive_s", 0.0))
	var row: Dictionary = {
		"case_id": case_id,
		"variant": variant_id,
		"seed": seed,
		"result": String(outcome.result) if outcome != null else "missing",
		"time_s": float(outcome.time_s) if outcome != null else -1.0,
		"team_a_alive": int(outcome.team_a_alive) if outcome != null else 0,
		"team_b_alive": int(outcome.team_b_alive) if outcome != null else 0,
		"wall_timeout": bool(sim_out.get("wall_timeout", false)),
		"wall_elapsed_ms": int(sim_out.get("wall_elapsed_ms", 0)),
		"a_damage": int(team_a.get("damage", 0)),
		"b_damage": int(team_b.get("damage", 0)),
		"a_healing": int(team_a.get("healing", 0)),
		"a_shield": int(team_a.get("shield", 0)),
		"a_mitigated": int(team_a.get("mitigated", 0)),
		"protected_time_s": protected_time_s,
		"protected_incoming": int(protected_entry.get("incoming", 0)),
		"protected_pre_mit_incoming": int(protected_entry.get("pre_mit_incoming", 0)),
		"protected_shield": int(protected_entry.get("shield", 0)),
		"protected_damage": int(protected_entry.get("damage", 0)),
		"protected_casts": int(protected_entry.get("casts", 0)),
		"team_a_units": _compact_unit_rows(units_a, float(outcome.time_s) if outcome != null else 0.0),
		"team_b_units": _compact_unit_rows(units_b, float(outcome.time_s) if outcome != null else 0.0),
	}
	_sim_index += 1
	return row

func _map_params(case_id: String) -> Dictionary:
	var map_id: String = "counter_outcome_gauntlet_" + case_id
	return {
		"map_id": map_id,
		"formation": "role_based",
		"openness": 0.82,
		"obstacle_density": 0.12,
		"artillery_range": 8.0,
		"tile_size": 1.0,
		"half_width_tiles": 8.0,
		"half_height_tiles": 5.0,
		"row_spacing_tiles": 1.5,
		"depth_gap": 1.4,
	}

func _contract_score(summary: Dictionary) -> float:
	var wins: float = float(summary.get("wins", 0))
	var losses: float = float(summary.get("losses", 0))
	var timeouts: float = float(summary.get("timeouts", 0))
	var avg_alive: float = float(summary.get("avg_alive", 0.0))
	var avg_enemy_alive: float = float(summary.get("avg_enemy_alive", 0.0))
	var avg_damage: float = float(summary.get("avg_damage", 0.0))
	var avg_enemy_damage: float = float(summary.get("avg_enemy_damage", 0.0))
	var avg_protected_time: float = float(summary.get("avg_protected_time_s", 0.0))
	var damage_ratio: float = avg_damage / max(1.0, avg_enemy_damage)
	return wins * 100.0 - losses * 40.0 - timeouts * 60.0 + (avg_alive - avg_enemy_alive) * 25.0 + damage_ratio * 25.0 + avg_protected_time * 1.5

func _counter_strength(win_delta: int, score_delta: float, protected_delta: float, min_score_delta: float, min_protected_time_delta: float) -> String:
	if win_delta > 0:
		return "hard"
	if score_delta >= min_score_delta:
		return "soft_pressure"
	if protected_delta >= min_protected_time_delta and score_delta >= 0.0:
		return "soft_protection"
	return "weak"

func _protected_entry(units_a: Array, protected_index: int) -> Dictionary:
	if protected_index < 0 or protected_index >= units_a.size():
		return {}
	var unit_data: Variant = units_a[protected_index]
	if typeof(unit_data) != TYPE_DICTIONARY:
		return {}
	return (unit_data as Dictionary).duplicate()

func _compact_unit_rows(units_data: Array, total_time_s: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for raw_entry: Variant in units_data:
		if typeof(raw_entry) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = raw_entry as Dictionary
		var deaths: int = int(entry.get("deaths", 0))
		var time_alive: float = float(entry.get("time_alive_s", 0.0))
		out.append({
			"unit_id": String(entry.get("unit_id", "")),
			"alive": deaths <= 0 and time_alive >= total_time_s - 0.001,
			"time_alive_s": time_alive,
			"damage": int(entry.get("damage", 0)),
			"incoming": int(entry.get("incoming", 0)),
			"pre_mit_incoming": int(entry.get("pre_mit_incoming", 0)),
			"mitigated": int(entry.get("mitigated", 0)),
			"healing": int(entry.get("healing", 0)),
			"shield": int(entry.get("shield", 0)),
			"casts": int(entry.get("casts", 0)),
			"kills": int(entry.get("kills", 0)),
			"deaths": deaths
		})
	return out

func _print_case_result(result: Dictionary) -> void:
	var counter: Dictionary = result.get("counter", {}) if typeof(result.get("counter", {})) == TYPE_DICTIONARY else {}
	var baseline: Dictionary = result.get("baseline", {}) if typeof(result.get("baseline", {})) == TYPE_DICTIONARY else {}
	print("CounterOutcomeGauntlet: case=%s pass=%s strength=%s win_delta=%d score_delta=%.1f protected_delta=%.1f counter[w=%d l=%d t=%d alive=%.1f prot=%.1f dmg=%.0f] baseline[w=%d l=%d t=%d alive=%.1f prot=%.1f dmg=%.0f]" % [
		String(result.get("id", "")),
		str(bool(result.get("passed", false))),
		String(result.get("strength", "unknown")),
		int(result.get("win_delta", 0)),
		float(result.get("score_delta", 0.0)),
		float(result.get("protected_time_delta_s", 0.0)),
		int(counter.get("wins", 0)),
		int(counter.get("losses", 0)),
		int(counter.get("timeouts", 0)),
		float(counter.get("avg_alive", 0.0)),
		float(counter.get("avg_protected_time_s", 0.0)),
		float(counter.get("avg_damage", 0.0)),
		int(baseline.get("wins", 0)),
		int(baseline.get("losses", 0)),
		int(baseline.get("timeouts", 0)),
		float(baseline.get("avg_alive", 0.0)),
		float(baseline.get("avg_protected_time_s", 0.0)),
		float(baseline.get("avg_damage", 0.0)),
	])

func _write_results() -> void:
	var path: String = _results_path()
	var dir_path: String = ProjectSettings.globalize_path("user://rga_probe/counter_outcome_gauntlet")
	var dir_error: Error = DirAccess.make_dir_recursive_absolute(dir_path)
	if dir_error != OK:
		push_warning("CounterOutcomeGauntlet: could not create " + dir_path)
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("CounterOutcomeGauntlet: could not write " + path)
		return
	file.store_string(JSON.stringify({
		"run_id": RUN_ID,
		"sims": _sim_index,
		"results": _results,
	}, "\t"))
	file.close()

func _results_path() -> String:
	return "user://rga_probe/counter_outcome_gauntlet/results.json"

func _string_array(value: Variant) -> Array[String]:
	var out: Array[String] = []
	if value is PackedStringArray:
		for item: String in value:
			out.append(String(item))
	elif value is Array:
		for raw_item in value:
			out.append(String(raw_item))
	return out
