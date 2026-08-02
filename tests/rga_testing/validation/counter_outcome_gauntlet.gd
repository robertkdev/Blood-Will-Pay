extends Node

const DataModels = preload("res://tests/rga_testing/core/data_models.gd")
const LockstepSimulator = preload("res://tests/rga_testing/core/lockstep_simulator.gd")
const CombatStatsCollector = preload("res://tests/rga_testing/aggregators/combat_stats_collector.gd")
const HeadlessSimPipeline = preload("res://tests/rga_testing/core/headless_sim_pipeline.gd")
const UnitFactory = preload("res://scripts/unit_factory.gd")

const RUN_ID: String = "counter_outcome_gauntlet"
const BASE_SEED: int = 5401
const SEEDS_PER_CASE: int = 2
const DELTA_S: float = 0.05
const TIMEOUT_S: float = 90.0
const MAX_WALL_CLOCK_MS: int = 10000

@export var focus_case_ids: PackedStringArray = PackedStringArray()

var _sim_index: int = 0
var _results: Array[Dictionary] = []

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	var cases: Array[Dictionary] = _cases()
	for case_index: int in range(cases.size()):
		var case: Dictionary = cases[case_index]
		var case_id: String = String(case.get("id", ""))
		if not focus_case_ids.is_empty() and not focus_case_ids.has(case_id):
			continue
		var result: Dictionary = _run_contract_case(case, case_index)
		_results.append(result)
		_print_case_result(result)
		if not bool(result.get("passed", false)):
			failures.append(String(result.get("failure", "unknown counter contract failure")))
	if _results.is_empty():
		failures.append("CounterOutcomeGauntlet: no cases matched focus_case_ids=%s" % [focus_case_ids])
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
			"label": "Dedicated carry peel should protect a carry better than a role- and slot-cost-matched engage/control support shell into divers.",
			"counter_team": ["brute", "sari", "totem", "axiom"],
			"baseline_team": ["brute", "sari", "miri", "knoll"],
			"threat_team": ["pilfer", "bo", "creep", "mortem"],
			"protected_index": 1,
			"baseline_protected_index": 1,
			"require_slot_role_cost_match": true,
			"max_threat_cost_delta": 1,
			"min_score_delta": 20.0,
			"min_protected_time_delta": 4.0,
			"min_protected_shield_delta": 250.0,
		},
		{
			"id": "redirect_vs_backline_access",
			"label": "Redirect board should preserve the carry better than a similar non-redirect front line.",
			"counter_team": ["korath", "sari", "cashmere", "axiom"],
			"baseline_team": ["brute", "sari", "cashmere", "axiom"],
			"threat_team": ["pilfer", "bo", "creep", "hexeon"],
			"protected_index": 1,
			"baseline_protected_index": 1,
			"min_score_delta": 20.0,
			"min_protected_time_delta": 3.0,
		},
		{
			"id": "zone_vs_engage",
			"label": "Zone board should do better into engage than a comparable non-zone damage board.",
			"counter_team": ["brute", "cinder", "prisma", "sari"],
			"baseline_team": ["brute", "luna", "ivara", "sari"],
			"threat_team": ["grint", "bo", "miri", "draxelle"],
			"protected_index": 3,
			"baseline_protected_index": 3,
			"min_score_delta": 20.0,
			"min_protected_time_delta": 2.0,
		},
		{
			"id": "cc_immunity_vs_lockdown",
			"label": "CC-immunity board should improve into lockdown/control versus a role- and slot-cost-matched no-immunity board.",
			"counter_team": ["veyra", "rooket", "totem", "sari"],
			"baseline_team": ["kythera", "teller", "velour", "sari"],
			"threat_team": ["brute", "knoll", "volt", "velour"],
			"protected_index": 3,
			"baseline_protected_index": 3,
			"require_slot_role_cost_match": true,
			"min_score_delta": 20.0,
			"min_protected_time_delta": 2.0,
			"min_cc_prevented_delta": 1.0,
		},
		{
			"id": "long_range_vs_zone",
			"label": "Long-range siege should punish zone control better than a comparable non-siege shell.",
			"counter_team": ["brute", "nyxa", "omenry", "gable"],
			"baseline_team": ["bastionne", "volt", "luna", "prisma"],
			"threat_team": ["caldera", "cinder", "prisma", "juno_vale"],
			"protected_index": 2,
			"baseline_protected_index": 2,
			"min_score_delta": 20.0,
			"min_protected_time_delta": 0.0,
		},
		{
			"id": "control_vs_reset",
			"label": "Control board should deny reset chains better than a comparable no-control shell.",
			"counter_team": ["bastionne", "knoll", "velour", "sari"],
			"baseline_team": ["brute", "sari", "luna", "saffron"],
			"threat_team": ["egress", "hexeon", "bo", "pilfer"],
			"protected_index": 3,
			"baseline_protected_index": 1,
			"min_score_delta": 20.0,
			"min_protected_time_delta": 0.0,
		},
		{
			"id": "execute_vs_attrition",
			"label": "Execute pressure should break sustain/attrition better than a no-execute damage shell.",
			"counter_team": ["morrak", "egress", "hexeon", "sari"],
			"baseline_team": ["kett", "sari", "volt", "luna"],
			"threat_team": ["veyra", "bonko", "noxley", "velour"],
			"protected_index": -1,
			"baseline_protected_index": -1,
			"min_score_delta": 20.0,
			"min_protected_time_delta": 0.0,
		},
		{
			"id": "attrition_vs_burst",
			"label": "Attrition should stabilize into burst better than a role- and slot-cost-matched non-sustain board.",
			"counter_team": ["veyra", "bonko", "noxley", "velour"],
			"baseline_team": ["kythera", "bo", "prisma", "miri"],
			"threat_team": ["vesper", "cashmere", "volt", "luna"],
			"protected_index": -1,
			"baseline_protected_index": -1,
			"require_slot_role_cost_match": true,
			"min_score_delta": 20.0,
			"min_protected_time_delta": 0.0,
		},
		{
			"id": "formation_breaking_vs_peel_ball",
			"label": "Formation-breaking should punish a clumped peel ball better than ordinary damage.",
			"counter_team": ["ravel", "juno_vale", "sari", "morrak"],
			"baseline_team": ["miri", "sari", "luna", "omenry"],
			"threat_team": ["brute", "sari", "totem", "saffron"],
			"protected_index": -1,
			"baseline_protected_index": -1,
			"min_score_delta": 20.0,
			"min_protected_time_delta": 0.0,
		},
	]

func _run_contract_case(case: Dictionary, case_index: int) -> Dictionary:
	var counter_team: Array[String] = _string_array(case.get("counter_team", []))
	var baseline_team: Array[String] = _string_array(case.get("baseline_team", []))
	var threat_team: Array[String] = _string_array(case.get("threat_team", []))
	var protected_index: int = int(case.get("protected_index", -1))
	var baseline_protected_index: int = int(case.get("baseline_protected_index", protected_index))
	var paired_seeds: Array[int] = _paired_seeds(case_index)
	var counter_cost: int = _team_total_cost(counter_team)
	var baseline_cost: int = _team_total_cost(baseline_team)
	var threat_cost: int = _team_total_cost(threat_team)
	var validation_errors: Array[String] = _case_validation_errors(
		counter_team,
		baseline_team,
		threat_team,
		counter_cost,
		baseline_cost,
		threat_cost,
		protected_index,
		baseline_protected_index,
		bool(case.get("require_slot_role_cost_match", false)),
		int(case.get("max_threat_cost_delta", -1))
	)
	if not validation_errors.is_empty():
		var validation_failure: String = "CounterOutcomeGauntlet: %s invalid comparison: %s" % [
			String(case.get("id", "")),
			"; ".join(validation_errors),
		]
		return {
			"id": String(case.get("id", "")),
			"label": String(case.get("label", "")),
			"passed": false,
			"failure": validation_failure,
			"counter": _unrun_summary("counter", counter_team, threat_team, counter_cost, threat_cost, paired_seeds),
			"baseline": _unrun_summary("baseline", baseline_team, threat_team, baseline_cost, threat_cost, paired_seeds),
			"strength": "invalid",
			"hard_counter": false,
			"needs_tuning": true,
			"score_delta": 0.0,
			"protected_time_delta_s": 0.0,
			"win_delta": 0,
			"counter_cost": counter_cost,
			"baseline_cost": baseline_cost,
			"threat_cost": threat_cost,
			"paired_seeds": paired_seeds.duplicate(),
		}
	var counter_summary: Dictionary = _run_team_set(String(case.get("id", "")), "counter", counter_team, threat_team, protected_index, paired_seeds)
	var baseline_summary: Dictionary = _run_team_set(String(case.get("id", "")), "baseline", baseline_team, threat_team, baseline_protected_index, paired_seeds)
	var counter_score: float = _contract_score(counter_summary)
	var baseline_score: float = _contract_score(baseline_summary)
	var score_delta: float = counter_score - baseline_score
	var protected_delta: float = float(counter_summary.get("avg_protected_time_s", 0.0)) - float(baseline_summary.get("avg_protected_time_s", 0.0))
	var protected_shield_delta: float = float(counter_summary.get("avg_protected_shield", 0.0)) - float(baseline_summary.get("avg_protected_shield", 0.0))
	var win_delta: int = int(counter_summary.get("wins", 0)) - int(baseline_summary.get("wins", 0))
	var cc_prevented_delta: float = float(counter_summary.get("avg_cc_prevented", 0.0)) - float(baseline_summary.get("avg_cc_prevented", 0.0))
	var min_score_delta: float = float(case.get("min_score_delta", 20.0))
	var min_protected_time_delta: float = float(case.get("min_protected_time_delta", 0.0))
	var protection_applicable: bool = protected_index >= 0 and baseline_protected_index >= 0
	var protected_shield_applicable: bool = case.has("min_protected_shield_delta")
	var min_protected_shield_delta: float = float(case.get("min_protected_shield_delta", 0.0))
	var cc_prevention_applicable: bool = case.has("min_cc_prevented_delta")
	var min_cc_prevented_delta: float = float(case.get("min_cc_prevented_delta", 0.0))
	var strength: String = _counter_strength(win_delta, score_delta, protected_delta, protected_shield_delta, cc_prevented_delta, min_score_delta, min_protected_time_delta, min_protected_shield_delta, min_cc_prevented_delta, protection_applicable, protected_shield_applicable, cc_prevention_applicable)
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
		"protected_shield_delta": protected_shield_delta,
		"cc_prevented_delta": cc_prevented_delta,
		"win_delta": win_delta,
		"counter_cost": counter_cost,
		"baseline_cost": baseline_cost,
		"threat_cost": threat_cost,
		"paired_seeds": paired_seeds.duplicate(),
	}

func _run_team_set(case_id: String, variant_id: String, team_a_ids: Array[String], team_b_ids: Array[String], protected_index: int, seeds: Array[int]) -> Dictionary:
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
	var total_protected_shield: float = 0.0
	var total_cc_prevented: float = 0.0
	var total_cc_immunity_applied: float = 0.0
	var samples: Array[Dictionary] = []
	for seed: int in seeds:
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
		total_protected_shield += float(sample.get("protected_shield", 0.0))
		total_cc_prevented += float(sample.get("a_cc_prevented", 0.0))
		total_cc_immunity_applied += float(sample.get("a_cc_immunity_applied", 0.0))
	var count: float = max(1.0, float(seeds.size()))
	return {
		"variant": variant_id,
		"team": team_a_ids.duplicate(),
		"threat": team_b_ids.duplicate(),
		"team_cost": _team_total_cost(team_a_ids),
		"threat_cost": _team_total_cost(team_b_ids),
		"seeds": seeds.duplicate(),
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
		"avg_protected_shield": total_protected_shield / count,
		"avg_cc_prevented": total_cc_prevented / count,
		"avg_cc_immunity_applied": total_cc_immunity_applied / count,
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
	var pipeline: RefCounted = HeadlessSimPipeline.new()
	var collector: RefCounted = pipeline.call("_new_combined_aggregator", true) as RefCounted
	var sim_out: Dictionary = simulator.run(job, false, collector)
	var outcome: Variant = sim_out.get("engine_outcome", null)
	var aggregates: Dictionary = sim_out.get("aggregates", {}) if typeof(sim_out.get("aggregates", {})) == TYPE_DICTIONARY else {}
	var teams: Dictionary = aggregates.get("teams", {}) if typeof(aggregates.get("teams", {})) == TYPE_DICTIONARY else {}
	var team_a: Dictionary = teams.get("a", {}) if typeof(teams.get("a", {})) == TYPE_DICTIONARY else {}
	var team_b: Dictionary = teams.get("b", {}) if typeof(teams.get("b", {})) == TYPE_DICTIONARY else {}
	var units: Dictionary = aggregates.get("units", {}) if typeof(aggregates.get("units", {})) == TYPE_DICTIONARY else {}
	var units_a: Array = units.get("a", []) if typeof(units.get("a", [])) == TYPE_ARRAY else []
	var units_b: Array = units.get("b", []) if typeof(units.get("b", [])) == TYPE_ARRAY else []
	var kernels: Dictionary = aggregates.get("kernels", {}) if typeof(aggregates.get("kernels", {})) == TYPE_DICTIONARY else {}
	var buff_presence: Dictionary = kernels.get("buff_presence", {}) if typeof(kernels.get("buff_presence", {})) == TYPE_DICTIONARY else {}
	var side_a_buffs: Dictionary = buff_presence.get("a", {}) if typeof(buff_presence.get("a", {})) == TYPE_DICTIONARY else {}
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
		"a_cc_prevented": int(side_a_buffs.get("cc_prevented", 0)),
		"a_cc_immunity_applied": int(side_a_buffs.get("cc_immunity_applied", 0)),
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

func _counter_strength(win_delta: int, score_delta: float, protected_delta: float, protected_shield_delta: float, cc_prevented_delta: float, min_score_delta: float, min_protected_time_delta: float, min_protected_shield_delta: float, min_cc_prevented_delta: float, protection_applicable: bool, protected_shield_applicable: bool, cc_prevention_applicable: bool) -> String:
	if win_delta > 0:
		return "hard"
	if score_delta >= min_score_delta:
		return "soft_pressure"
	if protection_applicable and protected_delta >= min_protected_time_delta and score_delta >= 0.0:
		return "soft_protection"
	if protected_shield_applicable and win_delta >= 0 and score_delta >= 0.0 and protected_delta > 0.0 and protected_shield_delta >= min_protected_shield_delta:
		return "soft_protection"
	if cc_prevention_applicable and win_delta >= 0 and cc_prevented_delta >= min_cc_prevented_delta:
		return "soft_counterplay"
	return "weak"

func _paired_seeds(case_index: int) -> Array[int]:
	var seeds: Array[int] = []
	for repeat_index: int in range(SEEDS_PER_CASE):
		seeds.append(BASE_SEED + case_index * 1000 + repeat_index)
	return seeds

func _team_total_cost(unit_ids: Array[String]) -> int:
	var total_cost: int = 0
	for unit_id: String in unit_ids:
		var unit: Unit = UnitFactory.spawn(unit_id)
		if unit == null:
			return -1
		total_cost += max(0, int(unit.cost))
	return total_cost

func _case_validation_errors(counter_team: Array[String], baseline_team: Array[String], threat_team: Array[String], counter_cost: int, baseline_cost: int, threat_cost: int, protected_index: int, baseline_protected_index: int, require_slot_role_cost_match: bool, max_threat_cost_delta: int) -> Array[String]:
	var errors: Array[String] = []
	if counter_team.size() != baseline_team.size():
		errors.append("counter unit count %d != baseline unit count %d" % [counter_team.size(), baseline_team.size()])
	if counter_cost < 0 or baseline_cost < 0 or threat_cost < 0:
		errors.append("one or more teams contain an unresolved unit id")
	elif counter_cost != baseline_cost:
		errors.append("counter cost %d != baseline cost %d" % [counter_cost, baseline_cost])
	if max_threat_cost_delta >= 0 and counter_cost >= 0 and threat_cost >= 0 and abs(threat_cost - counter_cost) > max_threat_cost_delta:
		errors.append("threat cost %d exceeds allowed delta %d from counter cost %d" % [threat_cost, max_threat_cost_delta, counter_cost])
	if protected_index >= counter_team.size():
		errors.append("protected_index %d outside counter team size %d" % [protected_index, counter_team.size()])
	if baseline_protected_index >= baseline_team.size():
		errors.append("baseline_protected_index %d outside baseline team size %d" % [baseline_protected_index, baseline_team.size()])
	if require_slot_role_cost_match and counter_team.size() == baseline_team.size():
		for slot_index: int in range(counter_team.size()):
			var counter_unit: Unit = UnitFactory.spawn(counter_team[slot_index])
			var baseline_unit: Unit = UnitFactory.spawn(baseline_team[slot_index])
			if counter_unit == null or baseline_unit == null:
				continue
			var counter_role: String = String(counter_unit.get_primary_role()).strip_edges().to_lower()
			var baseline_role: String = String(baseline_unit.get_primary_role()).strip_edges().to_lower()
			if int(counter_unit.cost) != int(baseline_unit.cost) or counter_role != baseline_role:
				errors.append("slot %d mismatch %s(c%d,%s) vs %s(c%d,%s)" % [slot_index, counter_team[slot_index], int(counter_unit.cost), counter_role, baseline_team[slot_index], int(baseline_unit.cost), baseline_role])
	return errors

func _unrun_summary(variant_id: String, team_ids: Array[String], threat_ids: Array[String], team_cost: int, threat_cost: int, seeds: Array[int]) -> Dictionary:
	return {
		"variant": variant_id,
		"team": team_ids.duplicate(),
		"threat": threat_ids.duplicate(),
		"team_cost": team_cost,
		"threat_cost": threat_cost,
		"seeds": seeds.duplicate(),
		"wins": 0,
		"losses": 0,
		"timeouts": 0,
		"samples": [],
	}

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
	var paired_seeds: Array = result.get("paired_seeds", []) as Array
	print("CounterOutcomeGauntlet: case=%s pass=%s strength=%s costs=%d/%d threat_cost=%d seeds=%s win_delta=%d score_delta=%.1f protected_delta=%.1f counter[w=%d l=%d t=%d alive=%.1f prot=%.1f dmg=%.0f] baseline[w=%d l=%d t=%d alive=%.1f prot=%.1f dmg=%.0f]" % [
		String(result.get("id", "")),
		str(bool(result.get("passed", false))),
		String(result.get("strength", "unknown")),
		int(result.get("counter_cost", -1)),
		int(result.get("baseline_cost", -1)),
		int(result.get("threat_cost", -1)),
		str(paired_seeds),
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
