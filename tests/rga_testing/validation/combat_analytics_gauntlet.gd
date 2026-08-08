extends Node

const DataModels = preload("res://tests/rga_testing/core/data_models.gd")
const LockstepSimulator = preload("res://tests/rga_testing/core/lockstep_simulator.gd")
const CombatStatsCollector = preload("res://tests/rga_testing/aggregators/combat_stats_collector.gd")
const RGASettings = preload("res://tests/rga_testing/settings.gd")
const UnitCatalog = preload("res://tests/rga_testing/io/unit_catalog.gd")
const UnitFactory = preload("res://scripts/unit_factory.gd")
const ItemCatalog = preload("res://scripts/game/items/item_catalog.gd")
const TraitCompiler = preload("res://scripts/game/traits/trait_compiler.gd")
const TeamOddsEstimator = preload("res://scripts/game/combat/team_odds_estimator.gd")

const RUN_ID: String = "combat_analytics_gauntlet"
const OUT_ROOT: String = "user://combat_analytics"
const DATA_AFFINITIES_PATH: String = "res://data/identity/unit_build_affinities.json"
const UNIT_TIMEOUT_S: float = 75.0
const TRAIT_TIMEOUT_S: float = 90.0
const BASE_SEED: int = 910501

@export var output_label: String = "latest"
@export var tile_size_px: float = 1.0
@export var use_perf_adaptive: bool = true
@export var perf_fast_dt: float = 0.2
@export var unit_seeds_per_matchup: int = 2
@export var trait_seeds_per_matchup: int = 1
@export var max_unit_pairs_per_scenario: int = 0
@export var max_trait_pairs: int = 0
@export var focus_unit_ids: PackedStringArray = PackedStringArray()
@export var run_no_items: bool = true
@export var run_primary_items: bool = true
@export var run_trait_stack: bool = true
@export var candidate_item_loadouts_path: String = ""
@export var progress_every_rows: int = 250
@export var unit_wall_timeout_ms: int = 15000
@export var trait_wall_timeout_ms: int = 30000
@export var do_quit_on_finish: bool = true

var _unit_ids: Array[String] = []
var _unit_meta_by_id: Dictionary = {}
var _primary_items_by_unit: Dictionary = {}
var _trait_ids: Array[String] = []
var _trait_thresholds: Dictionary = {}
var _trait_carriers: Dictionary = {}
var _unit_rating_cache: Dictionary = {}
var _candidate_item_scenarios: Array[Dictionary] = []
var _rows_file: FileAccess = null
var _row_count: int = 0
var _wall_timeout_count: int = 0
var _phase_counts: Dictionary = {}
var _started_ms: int = 0

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	_started_ms = Time.get_ticks_msec()
	ItemCatalog.reload()
	UnitFactory.clear_cache()
	TraitCompiler.clear_cache()
	_reset_items_autoload()
	_prepare_output()
	_load_unit_catalog()
	_load_primary_item_loadouts()
	_load_trait_catalog()
	_load_candidate_item_scenarios()
	_write_manifest("started")
	_open_rows()
	print("CombatAnalyticsGauntlet: units=%d traits=%d unit_seeds=%d trait_seeds=%d tile_size=%.2f rows=%s" % [_unit_ids.size(), _trait_ids.size(), unit_seeds_per_matchup, trait_seeds_per_matchup, tile_size_px, _rows_path()])
	if run_no_items:
		_run_unit_matrix("no_items", false)
	if run_primary_items:
		_run_unit_matrix("primary_items", true)
	_run_candidate_item_matrices()
	if run_trait_stack:
		_run_trait_stack_matrix()
	_close_rows()
	if _row_count <= 0:
		push_error("CombatAnalyticsGauntlet: no rows were produced")
		_write_manifest("failed")
		_quit(1)
		return
	if _wall_timeout_count > 0:
		push_error("CombatAnalyticsGauntlet: %d rows hit their wall-clock timeout" % _wall_timeout_count)
		_write_manifest("failed")
		_quit(1)
		return
	_write_manifest("complete")
	var elapsed_s: float = float(Time.get_ticks_msec() - _started_ms) / 1000.0
	print("CombatAnalyticsGauntlet: PASS rows=%d elapsed_s=%.2f manifest=%s" % [_row_count, elapsed_s, _manifest_path()])
	_quit(0)

func _prepare_output() -> void:
	var out_abs: String = ProjectSettings.globalize_path(_out_dir())
	DirAccess.make_dir_recursive_absolute(out_abs)
	var rows_abs: String = ProjectSettings.globalize_path(_rows_path())
	if FileAccess.file_exists(rows_abs):
		DirAccess.remove_absolute(rows_abs)
	var manifest_abs: String = ProjectSettings.globalize_path(_manifest_path())
	if FileAccess.file_exists(manifest_abs):
		DirAccess.remove_absolute(manifest_abs)

func _open_rows() -> void:
	_rows_file = FileAccess.open(_rows_path(), FileAccess.WRITE)
	if _rows_file == null:
		push_error("CombatAnalyticsGauntlet: could not open " + _rows_path())
		_quit(1)

func _close_rows() -> void:
	if _rows_file != null:
		_rows_file.close()
	_rows_file = null

func _load_unit_catalog() -> void:
	var settings: RGASettings = RGASettings.new()
	var catalog: RGAUnitCatalog = UnitCatalog.new()
	var entries: Array = catalog.list(settings)
	_unit_ids.clear()
	_unit_meta_by_id.clear()
	for entry_value in entries:
		if not (entry_value is Dictionary):
			continue
		var entry: Dictionary = entry_value as Dictionary
		var unit_id: String = String(entry.get("id", "")).strip_edges()
		if unit_id == "":
			continue
		var unit: Unit = UnitFactory.spawn(unit_id)
		if unit == null:
			continue
		_unit_ids.append(unit_id)
		_unit_meta_by_id[unit_id] = {
			"id": unit_id,
			"name": String(unit.name),
			"cost": int(unit.cost),
			"level": int(unit.level),
			"role": String(unit.get_primary_role()),
			"goal": String(unit.get_primary_goal()),
			"approaches": _string_array(unit.get_approaches()),
			"traits": _string_array(unit.traits),
		}
	_unit_ids.sort()

func _load_primary_item_loadouts() -> void:
	_primary_items_by_unit.clear()
	if not FileAccess.file_exists(DATA_AFFINITIES_PATH):
		push_warning("CombatAnalyticsGauntlet: missing " + DATA_AFFINITIES_PATH + "; item matrix will use empty loadouts")
		return
	var file: FileAccess = FileAccess.open(DATA_AFFINITIES_PATH, FileAccess.READ)
	if file == null:
		push_warning("CombatAnalyticsGauntlet: could not open " + DATA_AFFINITIES_PATH)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("CombatAnalyticsGauntlet: affinity JSON did not parse as dictionary")
		return
	var root: Dictionary = parsed as Dictionary
	var units_value: Variant = root.get("units", {})
	if typeof(units_value) != TYPE_DICTIONARY:
		return
	var units: Dictionary = units_value as Dictionary
	for unit_id: String in _unit_ids:
		var payload_value: Variant = units.get(unit_id, {})
		if typeof(payload_value) != TYPE_DICTIONARY:
			continue
		var payload: Dictionary = payload_value as Dictionary
		var lanes_value: Variant = payload.get("lanes", [])
		if not (lanes_value is Array):
			continue
		for lane_value in lanes_value:
			if not (lane_value is Dictionary):
				continue
			var lane: Dictionary = lane_value as Dictionary
			if String(lane.get("lane_id", "")) != "primary":
				continue
			_primary_items_by_unit[unit_id] = _validated_item_ids(lane.get("items", []), 3)
			break

func _load_candidate_item_scenarios() -> void:
	_candidate_item_scenarios.clear()
	var clean_path: String = String(candidate_item_loadouts_path).strip_edges()
	if clean_path == "":
		return
	if not FileAccess.file_exists(clean_path):
		push_warning("CombatAnalyticsGauntlet: missing candidate loadouts " + clean_path)
		return
	var file: FileAccess = FileAccess.open(clean_path, FileAccess.READ)
	if file == null:
		push_warning("CombatAnalyticsGauntlet: could not open " + clean_path)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("CombatAnalyticsGauntlet: candidate loadout JSON did not parse as dictionary")
		return
	var root: Dictionary = parsed as Dictionary
	var scenarios_value: Variant = root.get("scenarios", [])
	if not (scenarios_value is Array):
		push_warning("CombatAnalyticsGauntlet: candidate loadout JSON has no scenarios array")
		return
	var scenario_index: int = 0
	for scenario_value in scenarios_value:
		if not (scenario_value is Dictionary):
			continue
		var scenario: Dictionary = scenario_value as Dictionary
		var scenario_id: String = String(scenario.get("scenario_id", "")).strip_edges()
		if scenario_id == "":
			scenario_id = "candidate_items_%d" % scenario_index
		var focus_units: Array[String] = []
		for raw_unit_id: String in _string_array(scenario.get("focus_unit_ids", [])):
			var unit_id: String = String(raw_unit_id).strip_edges()
			if unit_id != "" and _unit_ids.has(unit_id) and not focus_units.has(unit_id):
				focus_units.append(unit_id)
		var items_by_unit: Dictionary = {}
		var raw_items_by_unit: Variant = scenario.get("items_by_unit", {})
		if typeof(raw_items_by_unit) == TYPE_DICTIONARY:
			var source_items: Dictionary = raw_items_by_unit as Dictionary
			for unit_key_value in source_items.keys():
				var item_unit_id: String = String(unit_key_value).strip_edges()
				if item_unit_id == "" or not _unit_ids.has(item_unit_id):
					continue
				var item_ids: Array[String] = _validated_item_ids(source_items[unit_key_value], 3)
				if item_ids.is_empty():
					continue
				items_by_unit[item_unit_id] = item_ids
				if not focus_units.has(item_unit_id):
					focus_units.append(item_unit_id)
		if focus_units.is_empty() or items_by_unit.is_empty():
			continue
		focus_units.sort()
		_candidate_item_scenarios.append({
			"scenario_id": scenario_id,
			"focus_unit_ids": focus_units,
			"items_by_unit": items_by_unit,
		})
		scenario_index += 1

func _load_trait_catalog() -> void:
	_trait_ids.clear()
	_trait_thresholds.clear()
	_trait_carriers.clear()
	var dir: DirAccess = DirAccess.open("res://data/traits")
	if dir == null:
		push_warning("CombatAnalyticsGauntlet: cannot open res://data/traits")
		return
	dir.list_dir_begin()
	while true:
		var file_name: String = dir.get_next()
		if file_name == "":
			break
		if dir.current_is_dir() or file_name.begins_with(".") or not file_name.ends_with(".tres"):
			continue
		var path: String = "res://data/traits/" + file_name
		var def: TraitDef = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as TraitDef
		if def == null:
			continue
		var trait_id: String = String(def.id).strip_edges()
		if trait_id == "":
			continue
		_trait_ids.append(trait_id)
		_trait_thresholds[trait_id] = _int_array(def.thresholds)
	dir.list_dir_end()
	_trait_ids.sort()
	for trait_id: String in _trait_ids:
		var carriers: Array[String] = []
		for unit_id: String in _unit_ids:
			var meta: Dictionary = _unit_meta(unit_id)
			var traits: Array[String] = _string_array(meta.get("traits", []))
			if traits.has(trait_id):
				carriers.append(unit_id)
		carriers.sort_custom(func(left: String, right: String) -> bool:
			return _unit_rating(left) > _unit_rating(right)
		)
		_trait_carriers[trait_id] = carriers

func _run_unit_matrix(scenario_id: String, with_items: bool) -> void:
	var phase_started: int = Time.get_ticks_msec()
	var pair_count: int = 0
	var completed_pairs: int = 0
	var team_a_unit_ids: Array[String] = _unit_ids_for_focus()
	for team_a_id: String in team_a_unit_ids:
		for team_b_id: String in _unit_ids:
			if max_unit_pairs_per_scenario > 0 and pair_count >= max_unit_pairs_per_scenario:
				break
			pair_count += 1
			for seed_index: int in range(max(1, unit_seeds_per_matchup)):
				# Reuse the exact seed across no-items and primary-items phases so
				# item deltas are paired rather than confounded by different RNG.
				var seed: int = BASE_SEED + seed_index + pair_count * 101
				var team_a_items: Array = [_items_for_unit(team_a_id) if with_items else []]
				var team_b_items: Array = [_items_for_unit(team_b_id) if with_items else []]
				var row: Dictionary = _simulate_case(
					"unit_matchup",
					scenario_id,
					[team_a_id],
					[team_b_id],
					team_a_items,
					team_b_items,
					seed,
					UNIT_TIMEOUT_S,
					unit_wall_timeout_ms,
					{
						"unit_a": team_a_id,
						"unit_b": team_b_id,
						"with_items": with_items,
					}
				)
				_write_row(row)
			completed_pairs += 1
			_print_progress_if_needed(scenario_id, "unit_pair=%s_vs_%s" % [team_a_id, team_b_id])
		if max_unit_pairs_per_scenario > 0 and pair_count >= max_unit_pairs_per_scenario:
			break
	var elapsed_s: float = float(Time.get_ticks_msec() - phase_started) / 1000.0
	_phase_counts[scenario_id] = {"pairs": completed_pairs, "elapsed_s": elapsed_s}
	print("CombatAnalyticsGauntlet: phase=%s pairs=%d elapsed_s=%.2f rows=%d" % [scenario_id, completed_pairs, elapsed_s, _row_count])

func _run_candidate_item_matrices() -> void:
	for scenario_index: int in range(_candidate_item_scenarios.size()):
		var scenario: Dictionary = _candidate_item_scenarios[scenario_index]
		var scenario_id: String = String(scenario.get("scenario_id", "candidate_items_%d" % scenario_index))
		var focus_units: Array[String] = _string_array(scenario.get("focus_unit_ids", []))
		var items_by_unit: Dictionary = scenario.get("items_by_unit", {}) as Dictionary
		var phase_started: int = Time.get_ticks_msec()
		var pair_count: int = 0
		var completed_pairs: int = 0
		for team_a_id: String in focus_units:
			if not _unit_ids.has(team_a_id) or not items_by_unit.has(team_a_id):
				continue
			var candidate_items: Array[String] = _validated_item_ids(items_by_unit.get(team_a_id, []), 3)
			if candidate_items.is_empty():
				continue
			for team_b_id: String in _unit_ids:
				if max_unit_pairs_per_scenario > 0 and pair_count >= max_unit_pairs_per_scenario:
					break
				pair_count += 1
				for seed_index: int in range(max(1, unit_seeds_per_matchup)):
					var seed: int = BASE_SEED + 1200000 + scenario_index * 100003 + seed_index + pair_count * 101
					var row: Dictionary = _simulate_case(
						"unit_matchup",
						scenario_id,
						[team_a_id],
						[team_b_id],
						[candidate_items],
						[_items_for_unit(team_b_id)],
						seed,
						UNIT_TIMEOUT_S,
						unit_wall_timeout_ms,
						{
							"unit_a": team_a_id,
							"unit_b": team_b_id,
							"with_items": true,
							"candidate_item_scenario": true,
							"candidate_items": candidate_items,
						}
					)
					_write_row(row)
				completed_pairs += 1
				_print_progress_if_needed(scenario_id, "unit_pair=%s_vs_%s" % [team_a_id, team_b_id])
			if max_unit_pairs_per_scenario > 0 and pair_count >= max_unit_pairs_per_scenario:
				break
		var elapsed_s: float = float(Time.get_ticks_msec() - phase_started) / 1000.0
		_phase_counts[scenario_id] = {"pairs": completed_pairs, "elapsed_s": elapsed_s}
		print("CombatAnalyticsGauntlet: phase=%s pairs=%d elapsed_s=%.2f rows=%d" % [scenario_id, completed_pairs, elapsed_s, _row_count])

func _run_trait_stack_matrix() -> void:
	var phase_started: int = Time.get_ticks_msec()
	var pair_count: int = 0
	var completed_pairs: int = 0
	for trait_a: String in _trait_ids:
		var team_a: Array[String] = _team_for_trait_stack(trait_a)
		if team_a.is_empty():
			continue
		for trait_b: String in _trait_ids:
			var team_b: Array[String] = _team_for_trait_stack(trait_b)
			if team_b.is_empty():
				continue
			if max_trait_pairs > 0 and pair_count >= max_trait_pairs:
				break
			pair_count += 1
			for seed_index: int in range(max(1, trait_seeds_per_matchup)):
				var seed: int = BASE_SEED + 900000 + seed_index + pair_count * 131
				var row: Dictionary = _simulate_case(
					"trait_stack",
					"trait_max_stack_no_items",
					team_a,
					team_b,
					_empty_loadouts(team_a.size()),
					_empty_loadouts(team_b.size()),
					seed,
					TRAIT_TIMEOUT_S,
					trait_wall_timeout_ms,
					{
						"trait_a": trait_a,
						"trait_b": trait_b,
						"trait_a_threshold": _top_trait_threshold(trait_a),
						"trait_b_threshold": _top_trait_threshold(trait_b),
						"trait_a_carriers": _string_array(_trait_carriers.get(trait_a, [])),
						"trait_b_carriers": _string_array(_trait_carriers.get(trait_b, [])),
					}
				)
				_write_row(row)
			completed_pairs += 1
			_print_progress_if_needed("trait_stack", "trait_pair=%s_vs_%s" % [trait_a, trait_b])
		if max_trait_pairs > 0 and pair_count >= max_trait_pairs:
			break
	var elapsed_s: float = float(Time.get_ticks_msec() - phase_started) / 1000.0
	_phase_counts["trait_stack"] = {"pairs": completed_pairs, "elapsed_s": elapsed_s}
	print("CombatAnalyticsGauntlet: phase=trait_stack pairs=%d elapsed_s=%.2f rows=%d" % [completed_pairs, elapsed_s, _row_count])

func _simulate_case(case_type: String, scenario_id: String, team_a_ids: Array[String], team_b_ids: Array[String], team_a_items: Array, team_b_items: Array, seed: int, timeout_s: float, max_wall_clock_ms: int, metadata: Dictionary) -> Dictionary:
	var job: DataModels.SimJob = DataModels.SimJob.new()
	job.run_id = RUN_ID
	job.sim_index = _row_count
	job.seed = int(seed)
	job.team_a_ids = team_a_ids.duplicate()
	job.team_b_ids = team_b_ids.duplicate()
	job.team_size = max(team_a_ids.size(), team_b_ids.size())
	job.scenario_id = "open_field"
	job.map_params = _map_params_for_case(scenario_id, job.team_size)
	job.deterministic = true
	job.delta_s = 0.05
	job.timeout_s = timeout_s
	job.abilities = true
	job.ability_metrics = false
	job.alternate_order = false
	job.bridge_projectile_to_hit = true
	job.capabilities = PackedStringArray(["base"])
	var job_meta: Dictionary = {
		"scenario_label": scenario_id,
		"team_a_items": _duplicate_loadouts(team_a_items),
		"team_b_items": _duplicate_loadouts(team_b_items),
		"perf_adaptive": use_perf_adaptive,
		"perf_fast_dt": max(0.05, float(perf_fast_dt)),
		"perf_margin_tiles": 0.75,
		"max_wall_clock_ms": max(0, int(max_wall_clock_ms)),
	}
	for key_value in metadata.keys():
		job_meta[String(key_value)] = metadata[key_value]
	job.metadata = job_meta
	var simulator: LockstepSimulator = LockstepSimulator.new()
	var collector: CombatStatsCollector = CombatStatsCollector.new()
	var sim_out: Dictionary = simulator.run(job, false, collector)
	return _row_from_sim(case_type, scenario_id, job, sim_out, metadata)

func _row_from_sim(case_type: String, scenario_id: String, job: DataModels.SimJob, sim_out: Dictionary, metadata: Dictionary) -> Dictionary:
	var outcome: Variant = sim_out.get("engine_outcome", null)
	var aggregates: Dictionary = sim_out.get("aggregates", {}) if typeof(sim_out.get("aggregates", {})) == TYPE_DICTIONARY else {}
	var teams: Dictionary = aggregates.get("teams", {}) if typeof(aggregates.get("teams", {})) == TYPE_DICTIONARY else {}
	var team_a: Dictionary = teams.get("a", {}) if typeof(teams.get("a", {})) == TYPE_DICTIONARY else {}
	var team_b: Dictionary = teams.get("b", {}) if typeof(teams.get("b", {})) == TYPE_DICTIONARY else {}
	var units: Dictionary = aggregates.get("units", {}) if typeof(aggregates.get("units", {})) == TYPE_DICTIONARY else {}
	var row: Dictionary = {
		"run_id": RUN_ID,
		"sim_index": int(job.sim_index),
		"case_type": case_type,
		"scenario": scenario_id,
		"seed": int(job.seed),
		"team_size": int(job.team_size),
		"team_a_ids": job.team_a_ids.duplicate(),
		"team_b_ids": job.team_b_ids.duplicate(),
		"team_a_items": _duplicate_loadouts(job.metadata.get("team_a_items", [])),
		"team_b_items": _duplicate_loadouts(job.metadata.get("team_b_items", [])),
		"metadata": metadata.duplicate(true),
		"result": String(outcome.result) if outcome != null else "missing",
		"time_s": float(outcome.time_s) if outcome != null else -1.0,
		"frames": int(outcome.frames) if outcome != null else -1,
		"wall_timeout": bool(sim_out.get("wall_timeout", false)),
		"wall_elapsed_ms": int(sim_out.get("wall_elapsed_ms", 0)),
		"team_a_alive": int(outcome.team_a_alive) if outcome != null else 0,
		"team_b_alive": int(outcome.team_b_alive) if outcome != null else 0,
		"a_damage": int(team_a.get("damage", 0)),
		"b_damage": int(team_b.get("damage", 0)),
		"a_healing": int(team_a.get("healing", 0)),
		"b_healing": int(team_b.get("healing", 0)),
		"a_shield": int(team_a.get("shield", 0)),
		"b_shield": int(team_b.get("shield", 0)),
		"a_mitigated": int(team_a.get("mitigated", 0)),
		"b_mitigated": int(team_b.get("mitigated", 0)),
		"a_kills": int(team_a.get("kills", 0)),
		"b_kills": int(team_b.get("kills", 0)),
		"a_deaths": int(team_a.get("deaths", 0)),
		"b_deaths": int(team_b.get("deaths", 0)),
		"a_casts": int(team_a.get("casts", 0)),
		"b_casts": int(team_b.get("casts", 0)),
		"a_units": _duplicate_array(units.get("a", [])),
		"b_units": _duplicate_array(units.get("b", [])),
	}
	return row

func _write_row(row: Dictionary) -> void:
	if _rows_file == null:
		return
	_rows_file.store_string(JSON.stringify(row) + "\n")
	_rows_file.flush()
	_row_count += 1
	if bool(row.get("wall_timeout", false)):
		_wall_timeout_count += 1

func _print_progress_if_needed(phase_id: String, detail: String) -> void:
	var cadence: int = max(1, int(progress_every_rows))
	if _row_count > 0 and _row_count % cadence == 0:
		print("CombatAnalyticsGauntlet: progress rows=%d phase=%s %s" % [_row_count, phase_id, detail])

func _write_manifest(status: String) -> void:
	var elapsed_s: float = float(Time.get_ticks_msec() - _started_ms) / 1000.0 if _started_ms > 0 else 0.0
	var manifest: Dictionary = {
		"status": status,
		"run_id": RUN_ID,
		"rows_path": ProjectSettings.globalize_path(_rows_path()),
		"manifest_path": ProjectSettings.globalize_path(_manifest_path()),
		"generated_at_unix": int(Time.get_unix_time_from_system()),
		"elapsed_s": elapsed_s,
		"row_count": _row_count,
		"wall_timeout_count": _wall_timeout_count,
		"output_label": _safe_output_label(),
		"tile_size": float(tile_size_px),
		"use_perf_adaptive": use_perf_adaptive,
		"perf_fast_dt": float(perf_fast_dt),
		"unit_timeout_s": UNIT_TIMEOUT_S,
		"trait_timeout_s": TRAIT_TIMEOUT_S,
		"unit_seeds_per_matchup": unit_seeds_per_matchup,
		"trait_seeds_per_matchup": trait_seeds_per_matchup,
		"max_unit_pairs_per_scenario": max_unit_pairs_per_scenario,
		"max_trait_pairs": max_trait_pairs,
		"focus_unit_ids": _string_array(focus_unit_ids),
		"run_no_items": run_no_items,
		"run_primary_items": run_primary_items,
		"run_trait_stack": run_trait_stack,
		"candidate_item_loadouts_path": String(candidate_item_loadouts_path),
		"candidate_item_scenarios": _candidate_item_scenarios.duplicate(true),
		"progress_every_rows": progress_every_rows,
		"unit_wall_timeout_ms": unit_wall_timeout_ms,
		"trait_wall_timeout_ms": trait_wall_timeout_ms,
		"phase_counts": _phase_counts.duplicate(true),
		"units": _unit_meta_by_id.duplicate(true),
		"primary_items_by_unit": _primary_items_by_unit.duplicate(true),
		"trait_thresholds": _trait_thresholds.duplicate(true),
		"trait_carriers": _trait_carriers.duplicate(true),
		"mapping_notes": [
			"Simulations instantiate tests/rga_testing/core/lockstep_simulator.gd.",
			"LockstepSimulator instantiates the live CombatEngine, TraitRuntime, Item autoload loadouts, projectile-to-hit bridge, targeting, movement, and ability systems.",
			"Full exhaustive runs use fast RGA geometry by default (tile_size=1) so every matchup can be covered quickly.",
			"Live-scale smoke runs use tile_size=80 to match current Main combat tile scale and check whether conclusions are sensitive to board geometry.",
			"Unit item scenario equips each unit's current primary build-lane items from data/identity/unit_build_affinities.json.",
			"Trait stack scenario uses strongest live carriers for the trait's highest threshold, duplicating carriers only if the live roster has too few carriers.",
			"perf_adaptive only enlarges far-approach steps when teams are outside attack range and no projectile hit is pending.",
			"wall_timeout rows are marked explicitly when one simulation consumes too much wall-clock time before simulated victory/defeat/timeout."
		],
	}
	var file: FileAccess = FileAccess.open(_manifest_path(), FileAccess.WRITE)
	if file == null:
		push_warning("CombatAnalyticsGauntlet: could not write " + _manifest_path())
		return
	file.store_string(JSON.stringify(manifest, "\t"))
	file.close()

func _map_params_for_case(scenario_id: String, team_size: int) -> Dictionary:
	var safe_team_size: int = max(1, int(team_size))
	return {
		"map_id": scenario_id,
		"formation": "role_based",
		"openness": 0.82,
		"obstacle_density": 0.18,
		"artillery_range": 8.0,
		"tile_size": max(0.001, float(tile_size_px)),
		"depth_gap": 1.2,
		"half_width_tiles": max(6.0, 5.8 + float(safe_team_size) * 0.18),
		"half_height_tiles": max(5.0, 3.8 + float(safe_team_size) * 0.55),
		"row_spacing_tiles": max(1.2, 4.0 / max(1.0, float(safe_team_size))),
	}

func _items_for_unit(unit_id: String) -> Array[String]:
	var existing: Variant = _primary_items_by_unit.get(String(unit_id), [])
	return _validated_item_ids(existing, 3)

func _unit_ids_for_focus() -> Array[String]:
	var out: Array[String] = []
	for unit_id: String in _string_array(focus_unit_ids):
		var clean_id: String = String(unit_id).strip_edges()
		if clean_id == "" or not _unit_ids.has(clean_id) or out.has(clean_id):
			continue
		out.append(clean_id)
	if out.is_empty():
		return _unit_ids.duplicate()
	out.sort()
	return out

func _validated_item_ids(value: Variant, limit: int) -> Array[String]:
	var out: Array[String] = []
	var raw_items: Array[String] = _string_array(value)
	for item_id: String in raw_items:
		if out.size() >= max(0, int(limit)):
			break
		var clean_id: String = String(item_id).strip_edges()
		if clean_id == "":
			continue
		if ItemCatalog.get_def(clean_id) == null:
			continue
		if out.has(clean_id):
			continue
		out.append(clean_id)
	return out

func _team_for_trait_stack(trait_id: String) -> Array[String]:
	var carriers: Array[String] = _string_array(_trait_carriers.get(trait_id, []))
	var threshold: int = _top_trait_threshold(trait_id)
	if threshold <= 0 or carriers.is_empty():
		return []
	var team: Array[String] = []
	for index: int in range(threshold):
		team.append(carriers[index % carriers.size()])
	return team

func _top_trait_threshold(trait_id: String) -> int:
	var thresholds: Array[int] = _int_array(_trait_thresholds.get(trait_id, []))
	var top: int = 0
	for threshold: int in thresholds:
		top = max(top, int(threshold))
	return top

func _unit_rating(unit_id: String) -> float:
	var key: String = String(unit_id)
	if _unit_rating_cache.has(key):
		return float(_unit_rating_cache[key])
	var unit: Unit = UnitFactory.spawn(key)
	if unit == null:
		_unit_rating_cache[key] = 0.0
		return 0.0
	var rating: float = TeamOddsEstimator.unit_rating(unit)
	_unit_rating_cache[key] = rating
	return rating

func _empty_loadouts(count: int) -> Array:
	var out: Array = []
	for _index: int in range(max(0, int(count))):
		out.append([])
	return out

func _duplicate_loadouts(loadouts: Variant) -> Array:
	var out: Array = []
	if not (loadouts is Array):
		return out
	for entry_value in loadouts:
		out.append(_string_array(entry_value))
	return out

func _duplicate_array(value: Variant) -> Array:
	var out: Array = []
	if not (value is Array):
		return out
	for entry_value in value:
		if entry_value is Dictionary:
			out.append((entry_value as Dictionary).duplicate(true))
		else:
			out.append(entry_value)
	return out

func _unit_meta(unit_id: String) -> Dictionary:
	var value: Variant = _unit_meta_by_id.get(String(unit_id), {})
	if typeof(value) == TYPE_DICTIONARY:
		return value as Dictionary
	return {}

func _string_array(value: Variant) -> Array[String]:
	var out: Array[String] = []
	if value is Array:
		for raw_value in value:
			out.append(String(raw_value))
	elif value is PackedStringArray:
		for raw_string: String in value:
			out.append(String(raw_string))
	elif typeof(value) == TYPE_STRING:
		out.append(String(value))
	return out

func _int_array(value: Variant) -> Array[int]:
	var out: Array[int] = []
	if value is Array:
		for raw_value in value:
			out.append(int(raw_value))
	elif value is PackedInt32Array:
		for raw_int: int in value:
			out.append(int(raw_int))
	return out

func _reset_items_autoload() -> void:
	var items_node: Node = _items_autoload()
	if items_node != null and items_node.has_method("reset_run"):
		items_node.call("reset_run")

func _items_autoload() -> Node:
	var loop: MainLoop = Engine.get_main_loop()
	if loop == null or not loop.has_method("get_root"):
		return null
	var root: Window = loop.get_root()
	if root == null:
		return null
	return root.get_node_or_null("/root/Items")

func _out_dir() -> String:
	return OUT_ROOT + "/" + _safe_output_label()

func _rows_path() -> String:
	return _out_dir() + "/combat_rows.jsonl"

func _manifest_path() -> String:
	return _out_dir() + "/manifest.json"

func _safe_output_label() -> String:
	var clean: String = String(output_label).strip_edges()
	if clean == "":
		clean = "latest"
	clean = clean.replace("\\", "_").replace("/", "_").replace(":", "_")
	return clean

func _quit(code: int) -> void:
	if do_quit_on_finish and get_tree() != null:
		get_tree().quit(code)
