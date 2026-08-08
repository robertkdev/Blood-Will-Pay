extends Node

const DataModels := preload("res://tests/rga_testing/core/data_models.gd")
const LockstepSimulator := preload("res://tests/rga_testing/core/lockstep_simulator.gd")
const CombatStatsCollector := preload("res://tests/rga_testing/aggregators/combat_stats_collector.gd")
const UnitFactory := preload("res://scripts/unit_factory.gd")
const TraitCompiler := preload("res://scripts/game/traits/trait_compiler.gd")

const COMPOSITION_OUTPUT_PATH: String = "user://balance_evidence/composition_balance_evidence.json"
const TRAIT_OUTPUT_PATH: String = "user://balance_evidence/trait_breakpoint_balance_evidence.json"
const SCENE_PATH: String = "res://tests/rga_testing/validation/CompositionTraitBalanceEvidence.tscn"
const BASE_SEED: int = 864101
const TEAM_SIZE: int = 6

@export var seeds_per_matchup: int = 2
@export var composition_timeout_s: float = 75.0
@export var trait_timeout_s: float = 75.0
@export var delta_s: float = 0.05
@export var max_wall_clock_ms: int = 10000

var _composition_rows: Array[Variant] = []
var _trait_rows: Array[Variant] = []
var _integrity_failures: Array[String] = []
var _sim_index: int = 0

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	UnitFactory.clear_cache()
	TraitCompiler.clear_cache()
	var archetypes: Array[Variant] = _composition_archetypes()
	var trait_cases: Array[Variant] = _trait_breakpoint_cases()
	_validate_composition_archetypes(archetypes)
	var checked_trait_cases: Array[Variant] = _validate_trait_cases(trait_cases)
	_run_composition_lane(archetypes)
	_run_trait_lane(checked_trait_cases)
	var composition_evidence: Dictionary[String, Variant] = _build_composition_evidence(archetypes)
	var trait_evidence: Dictionary[String, Variant] = _build_trait_evidence(checked_trait_cases)
	_write_json(COMPOSITION_OUTPUT_PATH, composition_evidence)
	_write_json(TRAIT_OUTPUT_PATH, trait_evidence)
	_print_summary(composition_evidence, trait_evidence)
	if _integrity_failures.is_empty():
		print("CompositionTraitBalanceEvidence: PASS composition=%s traits=%s" % [COMPOSITION_OUTPUT_PATH, TRAIT_OUTPUT_PATH])
		get_tree().quit(0)
		return
	for failure: String in _integrity_failures:
		push_error("CompositionTraitBalanceEvidence: " + failure)
	print("CompositionTraitBalanceEvidence: FAIL failures=%d composition=%s traits=%s" % [_integrity_failures.size(), COMPOSITION_OUTPUT_PATH, TRAIT_OUTPUT_PATH])
	get_tree().quit(1)

func _composition_archetypes() -> Array[Variant]:
	return [
		{
			"id": "sustain",
			"description": "Korath-centered durable board with healing, shielding, and Sanguine/Titan/Blessed sustain pieces.",
			"team": ["korath", "malachor", "paisley", "saffron", "vykos", "berebell"],
		},
		{
			"id": "frontline_backline",
			"description": "Two-unit tank line protecting a mixed ranged damage and support backline.",
			"team": ["brute", "bastionne", "cashmere", "cinder", "sari", "ravel"],
		},
		{
			"id": "burst",
			"description": "Damage-forward board built around assassin, execution, striker, and spell burst pressure.",
			"team": ["hexeon", "morrak", "draxelle", "repo", "volt", "cinder"],
		},
		{
			"id": "control",
			"description": "Control and disruption board with support, time, mana, and crowd-control oriented kits.",
			"team": ["juno_vale", "ravel", "quillith", "vesper", "bonko", "totem"],
		},
	]

func _trait_breakpoint_cases() -> Array[Variant]:
	return [
		{
			"id": "titan_first_breakpoint",
			"trait_id": "Titan",
			"threshold_index": 0,
			"active_team": ["korath", "brute", "sari", "cashmere", "bo", "volt"],
			"below_team": ["korath", "grint", "sari", "cashmere", "bo", "volt"],
		},
		{
			"id": "blessed_first_breakpoint",
			"trait_id": "Blessed",
			"threshold_index": 0,
			"active_team": ["korath", "paisley", "sari", "cashmere", "bo", "volt"],
			"below_team": ["korath", "grint", "sari", "cashmere", "bo", "volt"],
		},
		{
			"id": "sanguine_first_breakpoint",
			"trait_id": "Sanguine",
			"threshold_index": 0,
			"active_team": ["berebell", "mortem", "sari", "cashmere", "bo", "volt"],
			"below_team": ["berebell", "grint", "sari", "cashmere", "bo", "volt"],
		},
		{
			"id": "bulwark_first_breakpoint",
			"trait_id": "Bulwark",
			"threshold_index": 0,
			"active_team": ["bastionne", "rooket", "sari", "cashmere", "bo", "volt"],
			"below_team": ["bastionne", "grint", "sari", "cashmere", "bo", "volt"],
		},
		{
			"id": "fortified_first_breakpoint",
			"trait_id": "Fortified",
			"threshold_index": 0,
			"active_team": ["bo", "brute", "sari", "cashmere", "volt", "grint"],
			"below_team": ["bo", "berebell", "sari", "cashmere", "volt", "grint"],
		},
		{
			"id": "mentor_second_breakpoint",
			"trait_id": "Mentor",
			"threshold_index": 1,
			"active_team": ["axiom", "miri", "sari", "cashmere", "bo", "volt"],
			"below_team": ["axiom", "grint", "sari", "cashmere", "bo", "volt"],
		},
	]

func _validate_composition_archetypes(archetypes: Array[Variant]) -> void:
	var seen_ids: Dictionary[String, bool] = {}
	for archetype_value: Variant in archetypes:
		var archetype: Dictionary[String, Variant] = _string_variant_dictionary(archetype_value)
		var archetype_id: String = String(archetype.get("id", "")).strip_edges()
		var team: Array[String] = _string_array(archetype.get("team", []))
		_expect(archetype_id != "", "composition archetype has an empty id")
		_expect(not seen_ids.has(archetype_id), "composition archetype id is duplicated: %s" % archetype_id)
		seen_ids[archetype_id] = true
		_validate_board(team, "composition %s" % archetype_id)

func _validate_trait_cases(cases: Array[Variant]) -> Array[Variant]:
	var checked: Array[Variant] = []
	for case_value: Variant in cases:
		var case_data: Dictionary[String, Variant] = _string_variant_dictionary(case_value)
		var case_copy: Dictionary[String, Variant] = case_data.duplicate(true)
		var case_id: String = String(case_copy.get("id", ""))
		var trait_id: String = String(case_copy.get("trait_id", ""))
		var threshold_index: int = int(case_copy.get("threshold_index", -1))
		var active_team: Array[String] = _string_array(case_copy.get("active_team", []))
		var below_team: Array[String] = _string_array(case_copy.get("below_team", []))
		_validate_board(active_team, "%s active" % case_id)
		_validate_board(below_team, "%s below" % case_id)
		var active_snapshot: Dictionary[String, Variant] = _compiled_snapshot(active_team, trait_id, "%s active" % case_id)
		var below_snapshot: Dictionary[String, Variant] = _compiled_snapshot(below_team, trait_id, "%s below" % case_id)
		var thresholds: Array[int] = _int_array(active_snapshot.get("thresholds", []))
		_expect(threshold_index >= 0 and threshold_index < thresholds.size(), "%s has invalid threshold index %d for live thresholds %s" % [case_id, threshold_index, str(thresholds)])
		var active_count_expected: int = -1
		if threshold_index >= 0 and threshold_index < thresholds.size():
			active_count_expected = thresholds[threshold_index]
		var below_count_expected: int = max(0, active_count_expected - 1)
		var below_tier_expected: int = _tier_for_count(thresholds, below_count_expected)
		_expect(int(active_snapshot.get("count", -999)) == active_count_expected, "%s compiler active count expected %d but got %d" % [case_id, active_count_expected, int(active_snapshot.get("count", -999))])
		_expect(int(active_snapshot.get("tier", -999)) == threshold_index, "%s compiler active tier expected %d but got %d" % [case_id, threshold_index, int(active_snapshot.get("tier", -999))])
		_expect(int(below_snapshot.get("count", -999)) == below_count_expected, "%s compiler below count expected %d but got %d" % [case_id, below_count_expected, int(below_snapshot.get("count", -999))])
		_expect(int(below_snapshot.get("tier", -999)) == below_tier_expected, "%s compiler below tier expected %d but got %d" % [case_id, below_tier_expected, int(below_snapshot.get("tier", -999))])
		case_copy["active_team"] = active_team
		case_copy["below_team"] = below_team
		case_copy["active_count_expected"] = active_count_expected
		case_copy["below_count_expected"] = below_count_expected
		case_copy["active_tier_expected"] = threshold_index
		case_copy["below_tier_expected"] = below_tier_expected
		case_copy["active_compiled"] = active_snapshot
		case_copy["below_compiled"] = below_snapshot
		checked.append(case_copy)
	return checked

func _validate_board(team: Array[String], label: String) -> void:
	_expect(team.size() == TEAM_SIZE, "%s board must have %d units but has %d" % [label, TEAM_SIZE, team.size()])
	var seen: Dictionary[String, bool] = {}
	for unit_id: String in team:
		_expect(unit_id != "", "%s board contains an empty unit id" % label)
		_expect(not seen.has(unit_id), "%s board contains duplicate unit id %s" % [label, unit_id])
		seen[unit_id] = true
		var unit: Unit = UnitFactory.spawn(unit_id)
		_expect(unit != null, "%s board could not spawn unit %s" % [label, unit_id])

func _compiled_snapshot(team: Array[String], trait_id: String, label: String) -> Dictionary[String, Variant]:
	var units: Array[Unit] = []
	for unit_id: String in team:
		var unit: Unit = UnitFactory.spawn(unit_id)
		if unit != null:
			units.append(unit)
	var compiled: Dictionary[String, Variant] = _string_variant_dictionary(TraitCompiler.compile(units))
	var counts: Dictionary[String, Variant] = _string_variant_dictionary(compiled.get("counts", {}))
	var tiers: Dictionary[String, Variant] = _string_variant_dictionary(compiled.get("tiers", {}))
	var thresholds_by_trait: Dictionary[String, Variant] = _string_variant_dictionary(compiled.get("thresholds", {}))
	var snapshot: Dictionary[String, Variant] = {
		"board_label": label,
		"trait_id": trait_id,
		"count": int(counts.get(trait_id, 0)),
		"tier": int(tiers.get(trait_id, -1)),
		"thresholds": _int_array(thresholds_by_trait.get(trait_id, [])),
		"all_counts": counts.duplicate(true),
		"all_tiers": tiers.duplicate(true),
	}
	return snapshot

func _run_composition_lane(archetypes: Array[Variant]) -> void:
	var expected_rows: int = int(archetypes.size() * (archetypes.size() - 1) / 2) * max(1, seeds_per_matchup) * 2
	print("CompositionTraitBalanceEvidence: composition lane start archetypes=%d expected_rows=%d" % [archetypes.size(), expected_rows])
	for left_index: int in range(archetypes.size()):
		for right_index: int in range(left_index + 1, archetypes.size()):
			var left: Dictionary[String, Variant] = _string_variant_dictionary(archetypes[left_index])
			var right: Dictionary[String, Variant] = _string_variant_dictionary(archetypes[right_index])
			var left_id: String = String(left.get("id", ""))
			var right_id: String = String(right.get("id", ""))
			var pair_id: String = "%s_vs_%s" % [left_id, right_id]
			for seed_index: int in range(max(1, seeds_per_matchup)):
				var seed: int = BASE_SEED + left_index * 10000 + right_index * 1000 + seed_index * 101
				var alternate_order: bool = seed_index % 2 == 1
				_composition_rows.append(_run_composition_match(left, right, pair_id, seed, false, alternate_order))
				_composition_rows.append(_run_composition_match(right, left, pair_id, seed, true, alternate_order))
			print("CompositionTraitBalanceEvidence: composition pair=%s rows=%d" % [pair_id, _composition_rows.size()])

func _run_composition_match(team_a_def: Dictionary[String, Variant], team_b_def: Dictionary[String, Variant], pair_id: String, seed: int, side_swap: bool, alternate_order: bool) -> Dictionary[String, Variant]:
	var team_a_ids: Array[String] = _string_array(team_a_def.get("team", []))
	var team_b_ids: Array[String] = _string_array(team_b_def.get("team", []))
	var result: Dictionary[String, Variant] = _simulate(team_a_ids, team_b_ids, seed, composition_timeout_s, alternate_order, "composition_archetypes", {
		"lane": "composition",
		"pair_id": pair_id,
		"side_swap": side_swap,
		"team_a_archetype": String(team_a_def.get("id", "")),
		"team_b_archetype": String(team_b_def.get("id", "")),
	})
	var row: Dictionary[String, Variant] = _row_from_result(result, team_a_ids, team_b_ids, composition_timeout_s, seed, alternate_order)
	row["lane"] = "composition"
	row["pair_id"] = pair_id
	row["side_swap"] = side_swap
	row["team_a_archetype"] = String(team_a_def.get("id", ""))
	row["team_b_archetype"] = String(team_b_def.get("id", ""))
	row["winner_archetype"] = _winner_label(row, String(row["team_a_archetype"]), String(row["team_b_archetype"]))
	return row

func _run_trait_lane(cases: Array[Variant]) -> void:
	print("CompositionTraitBalanceEvidence: trait lane start cases=%d expected_rows=%d" % [cases.size(), cases.size() * max(1, seeds_per_matchup) * 2])
	for case_index: int in range(cases.size()):
		var case_data: Dictionary[String, Variant] = _string_variant_dictionary(cases[case_index])
		for seed_index: int in range(max(1, seeds_per_matchup)):
			var seed: int = BASE_SEED + 500000 + case_index * 10000 + seed_index * 101
			var alternate_order: bool = seed_index % 2 == 1
			_trait_rows.append(_run_trait_match(case_data, seed, false, alternate_order))
			_trait_rows.append(_run_trait_match(case_data, seed, true, alternate_order))
		print("CompositionTraitBalanceEvidence: trait case=%s rows=%d" % [String(case_data.get("id", "")), _trait_rows.size()])

func _run_trait_match(case_data: Dictionary[String, Variant], seed: int, side_swap: bool, alternate_order: bool) -> Dictionary[String, Variant]:
	var active_team: Array[String] = _string_array(case_data.get("active_team", []))
	var below_team: Array[String] = _string_array(case_data.get("below_team", []))
	var team_a_ids: Array[String] = below_team if side_swap else active_team
	var team_b_ids: Array[String] = active_team if side_swap else below_team
	var team_a_condition: String = "below" if side_swap else "active"
	var team_b_condition: String = "active" if side_swap else "below"
	var result: Dictionary[String, Variant] = _simulate(team_a_ids, team_b_ids, seed, trait_timeout_s, alternate_order, "trait_breakpoint", {
		"lane": "trait",
		"case_id": String(case_data.get("id", "")),
		"trait_id": String(case_data.get("trait_id", "")),
		"side_swap": side_swap,
		"team_a_condition": team_a_condition,
		"team_b_condition": team_b_condition,
	})
	var row: Dictionary[String, Variant] = _row_from_result(result, team_a_ids, team_b_ids, trait_timeout_s, seed, alternate_order)
	row["lane"] = "trait"
	row["case_id"] = String(case_data.get("id", ""))
	row["trait_id"] = String(case_data.get("trait_id", ""))
	row["side_swap"] = side_swap
	row["team_a_condition"] = team_a_condition
	row["team_b_condition"] = team_b_condition
	row["winner_condition"] = _winner_label(row, team_a_condition, team_b_condition)
	row["active_compiled"] = _string_variant_dictionary(case_data.get("active_compiled", {})).duplicate(true)
	row["below_compiled"] = _string_variant_dictionary(case_data.get("below_compiled", {})).duplicate(true)
	return row

func _simulate(team_a_ids: Array[String], team_b_ids: Array[String], seed: int, timeout_value: float, alternate_order: bool, scenario_label: String, metadata: Dictionary[String, Variant]) -> Dictionary[String, Variant]:
	var job: DataModels.SimJob = DataModels.SimJob.new()
	job.run_id = "composition_trait_balance_evidence"
	job.sim_index = _sim_index
	_sim_index += 1
	job.seed = seed
	job.team_a_ids = team_a_ids.duplicate()
	job.team_b_ids = team_b_ids.duplicate()
	job.team_size = max(team_a_ids.size(), team_b_ids.size())
	job.scenario_id = "open_field"
	job.map_params = _map_params(job.team_size)
	job.deterministic = true
	job.delta_s = max(0.01, delta_s)
	job.timeout_s = max(5.0, timeout_value)
	job.abilities = true
	job.ability_metrics = false
	job.alternate_order = alternate_order
	job.bridge_projectile_to_hit = true
	job.capabilities = PackedStringArray(["base"])
	var job_metadata: Dictionary[String, Variant] = metadata.duplicate(true)
	job_metadata["scenario_label"] = scenario_label
	job_metadata["team_a_items"] = _empty_loadouts(team_a_ids.size())
	job_metadata["team_b_items"] = _empty_loadouts(team_b_ids.size())
	job_metadata["perf_adaptive"] = true
	job_metadata["perf_fast_dt"] = 0.2
	job_metadata["perf_margin_tiles"] = 0.75
	job_metadata["max_wall_clock_ms"] = max(0, max_wall_clock_ms)
	job.metadata = job_metadata
	var collector: CombatStatsCollector = CombatStatsCollector.new()
	var simulator: LockstepSimulator = LockstepSimulator.new()
	return _string_variant_dictionary(simulator.run(job, false, collector))

func _map_params(team_size: int) -> Dictionary[String, Variant]:
	var safe_team_size: int = max(1, team_size)
	return {
		"map_id": "balance_evidence_role_based",
		"formation": "role_based",
		"openness": 0.82,
		"obstacle_density": 0.18,
		"artillery_range": 8.0,
		"tile_size": 1.0,
		"depth_gap": 1.2,
		"half_width_tiles": max(6.0, 5.8 + float(safe_team_size) * 0.18),
		"half_height_tiles": max(5.0, 3.8 + float(safe_team_size) * 0.55),
		"row_spacing_tiles": max(1.2, 4.0 / max(1.0, float(safe_team_size))),
	}

func _row_from_result(result: Dictionary[String, Variant], team_a_ids: Array[String], team_b_ids: Array[String], timeout_value: float, seed: int, alternate_order: bool) -> Dictionary[String, Variant]:
	var outcome: DataModels.EngineOutcome = result.get("engine_outcome", null) as DataModels.EngineOutcome
	var aggregates: Dictionary[String, Variant] = _string_variant_dictionary(result.get("aggregates", {}))
	var teams: Dictionary[String, Variant] = _string_variant_dictionary(aggregates.get("teams", {}))
	var team_a: Dictionary[String, Variant] = _string_variant_dictionary(teams.get("a", {}))
	var team_b: Dictionary[String, Variant] = _string_variant_dictionary(teams.get("b", {}))
	var result_label: String = String(outcome.result) if outcome != null else "missing"
	var time_s: float = float(outcome.time_s) if outcome != null else 0.0
	var team_a_alive: int = int(outcome.team_a_alive) if outcome != null else 0
	var team_b_alive: int = int(outcome.team_b_alive) if outcome != null else 0
	var team_a_casualties: int = max(0, team_a_ids.size() - team_a_alive)
	var team_b_casualties: int = max(0, team_b_ids.size() - team_b_alive)
	var total_casualties: int = team_a_casualties + team_b_casualties
	var timeout_observed: bool = result_label == "timeout" or result_label == "wall_timeout"
	var late_low_casualty: bool = time_s >= max(5.0, timeout_value) * 0.9 and total_casualties <= 1
	var a_damage: int = int(team_a.get("damage", 0))
	var b_damage: int = int(team_b.get("damage", 0))
	var a_healing: int = int(team_a.get("healing", 0))
	var b_healing: int = int(team_b.get("healing", 0))
	var a_shield: int = int(team_a.get("shield", 0))
	var b_shield: int = int(team_b.get("shield", 0))
	return {
		"sim_index": _sim_index - 1,
		"seed": seed,
		"alternate_order": alternate_order,
		"team_a_ids": team_a_ids.duplicate(),
		"team_b_ids": team_b_ids.duplicate(),
		"result": result_label,
		"time_s": time_s,
		"team_a_alive": team_a_alive,
		"team_b_alive": team_b_alive,
		"team_a_casualties": team_a_casualties,
		"team_b_casualties": team_b_casualties,
		"total_casualties": total_casualties,
		"timeout_observed": timeout_observed,
		"no_casualty_timeout": timeout_observed and total_casualties == 0,
		"late_low_casualty": late_low_casualty,
		"stall_observed": timeout_observed or late_low_casualty,
		"team_a_damage": a_damage,
		"team_b_damage": b_damage,
		"total_damage": a_damage + b_damage,
		"team_a_healing": a_healing,
		"team_b_healing": b_healing,
		"total_healing": a_healing + b_healing,
		"team_a_shield_absorbed": a_shield,
		"team_b_shield_absorbed": b_shield,
		"total_shield_absorbed": a_shield + b_shield,
		"sustain_to_damage_ratio": float(a_healing + b_healing + a_shield + b_shield) / max(1.0, float(a_damage + b_damage)),
		"wall_timeout": bool(result.get("wall_timeout", false)),
		"wall_elapsed_ms": int(result.get("wall_elapsed_ms", 0)),
	}

func _winner_label(row: Dictionary[String, Variant], team_a_label: String, team_b_label: String) -> String:
	var result_label: String = String(row.get("result", ""))
	if result_label == "team_a":
		return team_a_label
	if result_label == "team_b":
		return team_b_label
	return result_label

func _build_composition_evidence(archetypes: Array[Variant]) -> Dictionary[String, Variant]:
	return {
		"schema_version": "composition_balance_evidence_v1",
		"generated_at_utc": Time.get_datetime_string_from_system(true),
		"source_scene": SCENE_PATH,
		"method": {
			"team_size": TEAM_SIZE,
			"items": "disabled with explicit empty loadouts",
			"abilities": true,
			"deterministic_seeds_per_matchup": max(1, seeds_per_matchup),
			"paired_side_swaps": true,
			"alternate_iteration_order_on_odd_seed_index": true,
			"timeout_s": max(5.0, composition_timeout_s),
			"stall_definition": "simulated timeout, wall timeout, or at least 90% of the timeout elapsed with at most one total casualty",
			"interpretation": "descriptive current-build evidence; no balance pass threshold is enforced",
		},
		"archetypes": archetypes.duplicate(true),
		"summary_by_archetype": _summarize_composition_archetypes(archetypes),
		"summary_by_matchup": _summarize_by_key(_composition_rows, "pair_id"),
		"rows": _composition_rows.duplicate(true),
		"integrity_failures": _integrity_failures.duplicate(),
	}

func _build_trait_evidence(cases: Array[Variant]) -> Dictionary[String, Variant]:
	return {
		"schema_version": "trait_breakpoint_balance_evidence_v1",
		"generated_at_utc": Time.get_datetime_string_from_system(true),
		"source_scene": SCENE_PATH,
		"method": {
			"team_size": TEAM_SIZE,
			"items": "disabled with explicit empty loadouts",
			"abilities": true,
			"deterministic_seeds_per_case": max(1, seeds_per_matchup),
			"paired_side_swaps": true,
			"unique_unit_ids_required": true,
			"active_vs_below": "live threshold count versus exactly one fewer carrier at equal team size",
			"compiler_integrity": "actual unique-unit count, live thresholds, and tier are captured and asserted before combat",
			"replacement_caveat": "the one carrier-to-filler substitution changes unit identity as well as the trait breakpoint; outcomes are descriptive, not a causal trait-effect estimate",
			"timeout_s": max(5.0, trait_timeout_s),
			"stall_definition": "simulated timeout, wall timeout, or at least 90% of the timeout elapsed with at most one total casualty",
			"interpretation": "descriptive current-build evidence; no balance pass threshold is enforced",
		},
		"cases": cases.duplicate(true),
		"summary_by_trait": _summarize_traits(cases),
		"rows": _trait_rows.duplicate(true),
		"integrity_failures": _integrity_failures.duplicate(),
	}

func _summarize_composition_archetypes(archetypes: Array[Variant]) -> Dictionary[String, Variant]:
	var output: Dictionary[String, Variant] = {}
	for archetype_value: Variant in archetypes:
		var archetype: Dictionary[String, Variant] = _string_variant_dictionary(archetype_value)
		var archetype_id: String = String(archetype.get("id", ""))
		var normalized_rows: Array[Variant] = []
		for row_value: Variant in _composition_rows:
			var row: Dictionary[String, Variant] = _string_variant_dictionary(row_value)
			var side: String = ""
			if String(row.get("team_a_archetype", "")) == archetype_id:
				side = "a"
			elif String(row.get("team_b_archetype", "")) == archetype_id:
				side = "b"
			if side == "":
				continue
			normalized_rows.append(_normalize_labeled_row(row, side, archetype_id))
		output[archetype_id] = _summarize_normalized_rows(normalized_rows)
	return output

func _summarize_traits(cases: Array[Variant]) -> Dictionary[String, Variant]:
	var output: Dictionary[String, Variant] = {}
	for case_value: Variant in cases:
		var case_data: Dictionary[String, Variant] = _string_variant_dictionary(case_value)
		var trait_id: String = String(case_data.get("trait_id", ""))
		var case_id: String = String(case_data.get("id", ""))
		var case_rows: Array[Variant] = []
		for row_value: Variant in _trait_rows:
			var row: Dictionary[String, Variant] = _string_variant_dictionary(row_value)
			if String(row.get("case_id", "")) == case_id:
				case_rows.append(row)
		var active_rows: Array[Variant] = []
		var below_rows: Array[Variant] = []
		for row_value: Variant in case_rows:
			var row: Dictionary[String, Variant] = _string_variant_dictionary(row_value)
			var active_side: String = "a" if String(row.get("team_a_condition", "")) == "active" else "b"
			var below_side: String = "b" if active_side == "a" else "a"
			active_rows.append(_normalize_labeled_row(row, active_side, "active"))
			below_rows.append(_normalize_labeled_row(row, below_side, "below"))
		output[trait_id] = {
			"case_id": case_id,
			"active_compiled": _string_variant_dictionary(case_data.get("active_compiled", {})).duplicate(true),
			"below_compiled": _string_variant_dictionary(case_data.get("below_compiled", {})).duplicate(true),
			"active": _summarize_normalized_rows(active_rows),
			"below": _summarize_normalized_rows(below_rows),
			"matchup": _summarize_rows(case_rows),
		}
	return output

func _normalize_labeled_row(row: Dictionary[String, Variant], side: String, label: String) -> Dictionary[String, Variant]:
	var own_result: String = "tie"
	var raw_result: String = String(row.get("result", ""))
	if raw_result == "team_a":
		own_result = "win" if side == "a" else "loss"
	elif raw_result == "team_b":
		own_result = "win" if side == "b" else "loss"
	elif raw_result == "timeout" or raw_result == "wall_timeout":
		own_result = raw_result
	return {
		"label": label,
		"result": own_result,
		"time_s": float(row.get("time_s", 0.0)),
		"casualties": int(row.get("team_a_casualties", 0)) if side == "a" else int(row.get("team_b_casualties", 0)),
		"damage": int(row.get("team_a_damage", 0)) if side == "a" else int(row.get("team_b_damage", 0)),
		"healing": int(row.get("team_a_healing", 0)) if side == "a" else int(row.get("team_b_healing", 0)),
		"shield_absorbed": int(row.get("team_a_shield_absorbed", 0)) if side == "a" else int(row.get("team_b_shield_absorbed", 0)),
		"timeout_observed": bool(row.get("timeout_observed", false)),
		"stall_observed": bool(row.get("stall_observed", false)),
	}

func _summarize_normalized_rows(rows: Array[Variant]) -> Dictionary[String, Variant]:
	var samples: int = rows.size()
	var wins: int = 0
	var losses: int = 0
	var ties: int = 0
	var timeouts: int = 0
	var stalls: int = 0
	var time_total: float = 0.0
	var casualty_total: int = 0
	var damage_total: int = 0
	var healing_total: int = 0
	var shield_total: int = 0
	for row_value: Variant in rows:
		var row: Dictionary[String, Variant] = _string_variant_dictionary(row_value)
		var result_label: String = String(row.get("result", ""))
		if result_label == "win":
			wins += 1
		elif result_label == "loss":
			losses += 1
		elif result_label == "timeout" or result_label == "wall_timeout":
			timeouts += 1
		else:
			ties += 1
		if bool(row.get("stall_observed", false)):
			stalls += 1
		time_total += float(row.get("time_s", 0.0))
		casualty_total += int(row.get("casualties", 0))
		damage_total += int(row.get("damage", 0))
		healing_total += int(row.get("healing", 0))
		shield_total += int(row.get("shield_absorbed", 0))
	return {
		"samples": samples,
		"wins": wins,
		"losses": losses,
		"ties": ties,
		"timeouts": timeouts,
		"stalls": stalls,
		"win_rate_resolved": float(wins) / max(1.0, float(wins + losses)),
		"timeout_rate": float(timeouts) / max(1.0, float(samples)),
		"stall_rate": float(stalls) / max(1.0, float(samples)),
		"mean_time_s": time_total / max(1.0, float(samples)),
		"mean_casualties": float(casualty_total) / max(1.0, float(samples)),
		"mean_damage": float(damage_total) / max(1.0, float(samples)),
		"mean_healing": float(healing_total) / max(1.0, float(samples)),
		"mean_shield_absorbed": float(shield_total) / max(1.0, float(samples)),
	}

func _summarize_by_key(rows: Array[Variant], key: String) -> Dictionary[String, Variant]:
	var grouped: Dictionary[String, Variant] = {}
	for row_value: Variant in rows:
		var row: Dictionary[String, Variant] = _string_variant_dictionary(row_value)
		var value: String = String(row.get(key, ""))
		if not grouped.has(value):
			grouped[value] = []
		var group: Array[Variant] = _variant_array(grouped[value])
		group.append(row)
		grouped[value] = group
	var output: Dictionary[String, Variant] = {}
	for value_key: Variant in grouped.keys():
		var value: String = String(value_key)
		output[value] = _summarize_rows(_dictionary_array(grouped[value]))
	return output

func _summarize_rows(rows: Array[Variant]) -> Dictionary[String, Variant]:
	var samples: int = rows.size()
	var result_counts: Dictionary[String, int] = {}
	var stalls: int = 0
	var no_casualty_timeouts: int = 0
	var time_total: float = 0.0
	var casualty_total: int = 0
	var damage_total: int = 0
	var healing_total: int = 0
	var shield_total: int = 0
	for row_value: Variant in rows:
		var row: Dictionary[String, Variant] = _string_variant_dictionary(row_value)
		var result_label: String = String(row.get("result", ""))
		result_counts[result_label] = int(result_counts.get(result_label, 0)) + 1
		if bool(row.get("stall_observed", false)):
			stalls += 1
		if bool(row.get("no_casualty_timeout", false)):
			no_casualty_timeouts += 1
		time_total += float(row.get("time_s", 0.0))
		casualty_total += int(row.get("total_casualties", 0))
		damage_total += int(row.get("total_damage", 0))
		healing_total += int(row.get("total_healing", 0))
		shield_total += int(row.get("total_shield_absorbed", 0))
	return {
		"samples": samples,
		"result_counts": result_counts,
		"stalls": stalls,
		"no_casualty_timeouts": no_casualty_timeouts,
		"stall_rate": float(stalls) / max(1.0, float(samples)),
		"mean_time_s": time_total / max(1.0, float(samples)),
		"mean_total_casualties": float(casualty_total) / max(1.0, float(samples)),
		"mean_total_damage": float(damage_total) / max(1.0, float(samples)),
		"mean_total_healing": float(healing_total) / max(1.0, float(samples)),
		"mean_total_shield_absorbed": float(shield_total) / max(1.0, float(samples)),
	}

func _write_json(path: String, payload: Dictionary[String, Variant]) -> void:
	var output_dir: String = ProjectSettings.globalize_path("user://balance_evidence")
	DirAccess.make_dir_recursive_absolute(output_dir)
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_integrity_failures.append("could not write %s" % path)
		return
	file.store_string(JSON.stringify(payload, "  "))
	file.close()

func _print_summary(composition_evidence: Dictionary[String, Variant], trait_evidence: Dictionary[String, Variant]) -> void:
	var composition_summary: Dictionary[String, Variant] = _string_variant_dictionary(composition_evidence.get("summary_by_archetype", {}))
	for archetype_key: Variant in composition_summary.keys():
		var archetype_id: String = String(archetype_key)
		var summary: Dictionary[String, Variant] = _string_variant_dictionary(composition_summary[archetype_key])
		print("CompositionTraitBalanceEvidence: composition=%s samples=%d wins=%d losses=%d timeout_rate=%.2f stall_rate=%.2f mean_time=%.2f" % [archetype_id, int(summary.get("samples", 0)), int(summary.get("wins", 0)), int(summary.get("losses", 0)), float(summary.get("timeout_rate", 0.0)), float(summary.get("stall_rate", 0.0)), float(summary.get("mean_time_s", 0.0))])
	var trait_summary: Dictionary[String, Variant] = _string_variant_dictionary(trait_evidence.get("summary_by_trait", {}))
	for trait_key: Variant in trait_summary.keys():
		var trait_id: String = String(trait_key)
		var summary: Dictionary[String, Variant] = _string_variant_dictionary(trait_summary[trait_key])
		var active: Dictionary[String, Variant] = _string_variant_dictionary(summary.get("active", {}))
		var below: Dictionary[String, Variant] = _string_variant_dictionary(summary.get("below", {}))
		print("CompositionTraitBalanceEvidence: trait=%s active_wins=%d below_wins=%d active_stall=%.2f below_stall=%.2f active_heal=%.1f below_heal=%.1f" % [trait_id, int(active.get("wins", 0)), int(below.get("wins", 0)), float(active.get("stall_rate", 0.0)), float(below.get("stall_rate", 0.0)), float(active.get("mean_healing", 0.0)), float(below.get("mean_healing", 0.0))])

func _tier_for_count(thresholds: Array[int], count: int) -> int:
	var tier: int = -1
	for index: int in range(thresholds.size()):
		if count >= thresholds[index]:
			tier = index
	return tier

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

func _empty_loadouts(count: int) -> Array[Array]:
	var output: Array[Array] = []
	for _index: int in range(max(0, count)):
		output.append([])
	return output

func _string_array(value: Variant) -> Array[String]:
	var output: Array[String] = []
	if value is Array:
		for entry: Variant in value:
			output.append(String(entry))
	return output

func _int_array(value: Variant) -> Array[int]:
	var output: Array[int] = []
	if value is Array:
		for entry: Variant in value:
			output.append(int(entry))
	return output

func _dictionary_array(value: Variant) -> Array[Variant]:
	var output: Array[Variant] = []
	if value is Array:
		for entry: Variant in value:
			if entry is Dictionary:
				output.append(_string_variant_dictionary(entry))
	return output

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_integrity_failures.append(message)
