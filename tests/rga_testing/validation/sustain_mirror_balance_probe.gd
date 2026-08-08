extends Node

const DataModels := preload("res://tests/rga_testing/core/data_models.gd")
const LockstepSimulator := preload("res://tests/rga_testing/core/lockstep_simulator.gd")
const CombatStatsCollector := preload("res://tests/rga_testing/aggregators/combat_stats_collector.gd")

const OUTPUT_PATH: String = "user://balance_evidence/sustain_mirror_probe.json"
const BASE_SEED: int = 751001
const DELTA_S: float = 0.05

@export var seeds_per_case: int = 2
@export var timeout_s: float = 60.0
@export var enforce_thresholds: bool = false

var _rows: Array[Variant] = []
var _failures: Array[String] = []

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var cases: Array[Variant] = [
		{
			"id": "korath_vertical",
			"team": ["korath", "brute", "paisley", "sari", "cashmere", "berebell"],
			"description": "Exact mirror with active Titan and Blessed thresholds around Korath.",
		},
		{
			"id": "korath_no_vertical",
			"team": ["korath", "sari", "cashmere", "berebell", "bo", "volt"],
			"description": "Exact mirror with Korath but no active Titan or Blessed threshold.",
		},
		{
			"id": "sustain_control",
			"team": ["grint", "brute", "paisley", "sari", "cashmere", "berebell"],
			"description": "Exact mirror control with comparable tank/support shape and no Korath.",
		},
	]
	for case_index: int in range(cases.size()):
		var case_data: Dictionary[String, Variant] = _string_variant_dictionary(cases[case_index])
		for seed_index: int in range(max(1, seeds_per_case)):
			var seed: int = BASE_SEED + case_index * 100 + seed_index
			_rows.append(_run_case(case_data, seed, seed_index % 2 == 1))
	var summary: Dictionary[String, Variant] = _build_summary(cases)
	if enforce_thresholds:
		_enforce_thresholds(summary)
	summary["failures"] = _failures.duplicate()
	_write_summary(summary)
	_print_summary(summary)
	if _failures.is_empty():
		print("SustainMirrorBalanceProbe: PASS output=%s" % OUTPUT_PATH)
		get_tree().quit(0)
	else:
		for failure: String in _failures:
			push_error("SustainMirrorBalanceProbe: " + failure)
		print("SustainMirrorBalanceProbe: FAIL failures=%d output=%s" % [_failures.size(), OUTPUT_PATH])
		get_tree().quit(1)

func _run_case(case_data: Dictionary[String, Variant], seed: int, alternate_order: bool) -> Dictionary[String, Variant]:
	var team_ids: Array[String] = _string_array(case_data.get("team", []))
	var job: DataModels.SimJob = DataModels.SimJob.new()
	job.run_id = "sustain_mirror_probe"
	job.sim_index = _rows.size()
	job.seed = seed
	job.team_a_ids = team_ids.duplicate()
	job.team_b_ids = team_ids.duplicate()
	job.team_size = team_ids.size()
	job.scenario_id = "exact_mirror"
	job.map_params = {
		"formation": "role_based",
		"map_id": "exact_mirror_role_based",
		"openness": 0.85,
		"obstacle_density": 0.0,
		"artillery_range": 8.0,
	}
	job.deterministic = true
	job.delta_s = DELTA_S
	job.timeout_s = max(5.0, timeout_s)
	job.abilities = true
	job.ability_metrics = true
	job.alternate_order = alternate_order
	job.bridge_projectile_to_hit = true
	job.metadata = {
		"scenario_label": "exact_mirror",
		"case_id": String(case_data.get("id", "")),
		"max_wall_clock_ms": 20000,
	}
	var collector: CombatStatsCollector = CombatStatsCollector.new()
	var simulator: LockstepSimulator = LockstepSimulator.new()
	var result: Dictionary[String, Variant] = _string_variant_dictionary(simulator.run(job, true, collector))
	return _row_from_result(case_data, seed, alternate_order, team_ids.size(), result)

func _row_from_result(case_data: Dictionary[String, Variant], seed: int, alternate_order: bool, team_size: int, result: Dictionary[String, Variant]) -> Dictionary[String, Variant]:
	var outcome: DataModels.EngineOutcome = result.get("engine_outcome", null) as DataModels.EngineOutcome
	var aggregates: Dictionary[String, Variant] = _string_variant_dictionary(result.get("aggregates", {}))
	var teams: Dictionary[String, Variant] = _string_variant_dictionary(aggregates.get("teams", {}))
	var team_a: Dictionary[String, Variant] = _string_variant_dictionary(teams.get("a", {}))
	var team_b: Dictionary[String, Variant] = _string_variant_dictionary(teams.get("b", {}))
	var units: Dictionary[String, Variant] = _string_variant_dictionary(aggregates.get("units", {}))
	var time_value: float = float(outcome.time_s) if outcome != null else max(5.0, timeout_s)
	var team_a_alive: int = int(outcome.team_a_alive) if outcome != null else 0
	var team_b_alive: int = int(outcome.team_b_alive) if outcome != null else 0
	var casualties: int = max(0, team_size * 2 - team_a_alive - team_b_alive)
	var damage_total: int = int(team_a.get("damage", 0)) + int(team_b.get("damage", 0))
	var healing_total: int = int(team_a.get("healing", 0)) + int(team_b.get("healing", 0))
	var shield_total: int = int(team_a.get("shield", 0)) + int(team_b.get("shield", 0))
	var first_casualty_s: float = _first_casualty_time(units, time_value)
	var outcome_result: String = String(outcome.result) if outcome != null else "missing"
	return {
		"case_id": String(case_data.get("id", "")),
		"description": String(case_data.get("description", "")),
		"seed": seed,
		"alternate_order": alternate_order,
		"team_size": team_size,
		"outcome": outcome_result,
		"time_s": time_value,
		"team_a_alive": team_a_alive,
		"team_b_alive": team_b_alive,
		"casualties": casualties,
		"first_casualty_s": first_casualty_s,
		"damage": damage_total,
		"healing": healing_total,
		"shield_absorbed": shield_total,
		"sustain_to_damage_ratio": float(healing_total + shield_total) / max(1.0, float(damage_total)),
		"no_casualty_timeout": outcome_result == "timeout" and casualties == 0,
		"wall_timeout": bool(result.get("wall_timeout", false)),
		"wall_elapsed_ms": int(result.get("wall_elapsed_ms", 0)),
	}

func _first_casualty_time(units: Dictionary[String, Variant], combat_time_s: float) -> float:
	var first_time: float = -1.0
	for side: String in ["a", "b"]:
		var side_units: Array[Variant] = _variant_array(units.get(side, []))
		for entry_value: Variant in side_units:
			if typeof(entry_value) != TYPE_DICTIONARY:
				continue
			var entry: Dictionary[String, Variant] = _string_variant_dictionary(entry_value)
			if int(entry.get("deaths", 0)) <= 0:
				continue
			var death_time: float = float(entry.get("time_alive_s", combat_time_s))
			if first_time < 0.0 or death_time < first_time:
				first_time = death_time
	return first_time

func _build_summary(cases: Array[Variant]) -> Dictionary[String, Variant]:
	var by_case: Dictionary[String, Variant] = {}
	for case_value: Variant in cases:
		var case_data: Dictionary[String, Variant] = _string_variant_dictionary(case_value)
		var case_id: String = String(case_data.get("id", ""))
		var case_rows: Array[Variant] = []
		for row_value: Variant in _rows:
			var row: Dictionary[String, Variant] = _string_variant_dictionary(row_value)
			if String(row.get("case_id", "")) == case_id:
				case_rows.append(row)
		by_case[case_id] = _summarize_case(case_rows)
	return {
		"schema_version": "sustain_mirror_v1",
		"generated_at_utc": Time.get_datetime_string_from_system(true),
		"source_scene": "res://tests/rga_testing/validation/SustainMirrorBalanceProbe.tscn",
		"seeds_per_case": max(1, seeds_per_case),
		"timeout_s": max(5.0, timeout_s),
		"enforce_thresholds": enforce_thresholds,
		"cases": by_case,
		"rows": _rows.duplicate(true),
	}

func _summarize_case(rows: Array[Variant]) -> Dictionary[String, Variant]:
	var samples: int = rows.size()
	var timeout_count: int = 0
	var no_casualty_timeout_count: int = 0
	var casualty_samples: int = 0
	var casualty_total: int = 0
	var time_total: float = 0.0
	var sustain_ratio_total: float = 0.0
	for row_value: Variant in rows:
		var row: Dictionary[String, Variant] = _string_variant_dictionary(row_value)
		if String(row.get("outcome", "")) == "timeout":
			timeout_count += 1
		if bool(row.get("no_casualty_timeout", false)):
			no_casualty_timeout_count += 1
		var casualties: int = int(row.get("casualties", 0))
		if casualties > 0:
			casualty_samples += 1
			casualty_total += casualties
		time_total += float(row.get("time_s", 0.0))
		sustain_ratio_total += float(row.get("sustain_to_damage_ratio", 0.0))
	return {
		"samples": samples,
		"timeout_rate": float(timeout_count) / max(1.0, float(samples)),
		"no_casualty_timeout_rate": float(no_casualty_timeout_count) / max(1.0, float(samples)),
		"casualty_sample_rate": float(casualty_samples) / max(1.0, float(samples)),
		"mean_casualties_when_any": float(casualty_total) / max(1.0, float(casualty_samples)),
		"mean_combat_time_s": time_total / max(1.0, float(samples)),
		"mean_sustain_to_damage_ratio": sustain_ratio_total / max(1.0, float(samples)),
	}

func _enforce_thresholds(summary: Dictionary[String, Variant]) -> void:
	var cases: Dictionary[String, Variant] = _string_variant_dictionary(summary.get("cases", {}))
	var korath_vertical: Dictionary[String, Variant] = _string_variant_dictionary(cases.get("korath_vertical", {}))
	var korath_no_vertical: Dictionary[String, Variant] = _string_variant_dictionary(cases.get("korath_no_vertical", {}))
	_expect(float(korath_vertical.get("no_casualty_timeout_rate", 1.0)) <= 0.25, "Korath vertical exact mirrors should not routinely time out without casualties")
	_expect(float(korath_vertical.get("casualty_sample_rate", 0.0)) >= 0.75, "Korath vertical exact mirrors should usually lose at least one unit")
	_expect(float(korath_vertical.get("timeout_rate", 1.0)) <= 0.25, "Korath vertical exact mirrors should resolve within the player-facing combat limit")
	_expect(float(korath_no_vertical.get("no_casualty_timeout_rate", 1.0)) <= 0.25, "Korath exact mirrors without vertical traits should not routinely time out without casualties")
	_expect(float(korath_no_vertical.get("timeout_rate", 1.0)) <= 0.25, "Korath exact mirrors without vertical traits should resolve within the player-facing combat limit")

func _write_summary(summary: Dictionary[String, Variant]) -> void:
	var absolute_dir: String = ProjectSettings.globalize_path("user://balance_evidence")
	DirAccess.make_dir_recursive_absolute(absolute_dir)
	var file: FileAccess = FileAccess.open(OUTPUT_PATH, FileAccess.WRITE)
	if file == null:
		_failures.append("could not write %s" % OUTPUT_PATH)
		return
	file.store_string(JSON.stringify(summary, "  "))
	file.close()

func _print_summary(summary: Dictionary[String, Variant]) -> void:
	var cases: Dictionary[String, Variant] = _string_variant_dictionary(summary.get("cases", {}))
	for case_id_value: Variant in cases.keys():
		var case_id: String = String(case_id_value)
		var case_summary: Dictionary[String, Variant] = _string_variant_dictionary(cases.get(case_id, {}))
		print("SustainMirrorBalanceProbe: case=%s samples=%d timeout_rate=%.2f no_casualty_timeout_rate=%.2f casualty_sample_rate=%.2f mean_time_s=%.2f sustain_ratio=%.3f" % [
			case_id,
			int(case_summary.get("samples", 0)),
			float(case_summary.get("timeout_rate", 0.0)),
			float(case_summary.get("no_casualty_timeout_rate", 0.0)),
			float(case_summary.get("casualty_sample_rate", 0.0)),
			float(case_summary.get("mean_combat_time_s", 0.0)),
			float(case_summary.get("mean_sustain_to_damage_ratio", 0.0)),
		])

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

func _string_variant_dictionary(value: Variant) -> Dictionary[String, Variant]:
	var output: Dictionary[String, Variant] = {}
	if typeof(value) == TYPE_DICTIONARY:
		output.assign(value)
	return output

func _variant_array(value: Variant) -> Array[Variant]:
	var output: Array[Variant] = []
	if typeof(value) == TYPE_ARRAY:
		output.assign(value)
	return output

func _string_array(value: Variant) -> Array[String]:
	var out: Array[String] = []
	if value is Array:
		for entry: Variant in value:
			out.append(String(entry))
	return out
