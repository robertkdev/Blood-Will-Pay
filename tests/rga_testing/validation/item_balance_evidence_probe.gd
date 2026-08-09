extends Node

const DataModels := preload("res://tests/rga_testing/core/data_models.gd")
const LockstepSimulator := preload("res://tests/rga_testing/core/lockstep_simulator.gd")
const CombatStatsCollector := preload("res://tests/rga_testing/aggregators/combat_stats_collector.gd")
const ItemCatalog := preload("res://scripts/game/items/item_catalog.gd")
const EffectRegistry := preload("res://scripts/game/items/effects/effect_registry.gd")

const RUN_ID: String = "item_balance_evidence_probe"
const OUTPUT_PATH: String = "user://balance_evidence/item_balance_evidence.json"
const AFFINITIES_PATH: String = "res://data/identity/unit_build_affinities.json"
const EXPECTED_COMPLETED_ITEM_COUNT: int = 36
const BASE_SEED: int = 714230

# Each item is listed in the carrier's live primary build lane. The sample spans
# the six combat roles plus two defensive/support specializations. This is a
# causal sample, not a claim that eight 1v1s balance the full 36-item catalog.
const SAMPLE_CASES: Array[Variant] = [
	{"case_id": "tank_anchor", "carrier": "brute", "opponent": "berebell", "item": "anchor", "role": "tank"},
	{"case_id": "marksman_bandana", "carrier": "sari", "opponent": "brute", "item": "bandana", "role": "marksman"},
	{"case_id": "mage_orb", "carrier": "cashmere", "opponent": "brute", "item": "orb_on_a_stick", "role": "mage"},
	{"case_id": "brawler_blood_engine", "carrier": "berebell", "opponent": "brute", "item": "blood_engine", "role": "brawler"},
	{"case_id": "assassin_shiv", "carrier": "hexeon", "opponent": "cashmere", "item": "shiv", "role": "assassin"},
	{"case_id": "support_conductor", "carrier": "axiom", "opponent": "berebell", "item": "conductor", "role": "support"},
	{"case_id": "support_serenity", "carrier": "totem", "opponent": "cashmere", "item": "serenity", "role": "support"},
	{"case_id": "support_windwall", "carrier": "totem", "opponent": "sari", "item": "windwall", "role": "support"},
]

@export var seeds_per_case: int = 1
@export var combat_timeout_s: float = 65.0
@export var max_wall_clock_ms: int = 20000
@export var do_quit_on_finish: bool = true

var _sim_index: int = 0

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var started_ms: int = Time.get_ticks_msec()
	var failures: Array[String] = []
	ItemCatalog.reload()
	var primary_surface: Dictionary[String, Variant] = _load_primary_surface(failures)
	var catalog_evidence: Dictionary[String, Variant] = _catalog_evidence(primary_surface, failures)
	_validate_sample_contract(primary_surface, failures)

	var raw_runs: Array[Variant] = []
	var causal_pairs: Array[Variant] = []
	for case_index: int in range(SAMPLE_CASES.size()):
		var case_def: Dictionary[String, Variant] = _string_variant_dictionary(SAMPLE_CASES[case_index])
		for seed_index: int in range(max(1, seeds_per_case)):
			var seed: int = BASE_SEED + case_index * 1009 + seed_index * 37
			for swapped: bool in [false, true]:
				var baseline: Dictionary[String, Variant] = _simulate(case_def, seed, swapped, "no_item")
				var equipped: Dictionary[String, Variant] = _simulate(case_def, seed, swapped, "one_item")
				raw_runs.append(baseline)
				raw_runs.append(equipped)
				causal_pairs.append(_causal_pair(case_def, baseline, equipped))

	var case_summaries: Array[Variant] = []
	for case_value: Variant in SAMPLE_CASES:
		var case_def: Dictionary[String, Variant] = _string_variant_dictionary(case_value)
		case_summaries.append(_case_summary(case_def, causal_pairs))
	_validate_runtime_application(raw_runs, failures)
	_validate_causal_liveness(case_summaries, failures)
	for run_value: Variant in raw_runs:
		var run: Dictionary[String, Variant] = _string_variant_dictionary(run_value)
		if bool(run.get("wall_timeout", false)):
			failures.append("wall-clock timeout invalidated %s seed=%d side=%s variant=%s" % [
				String(run.get("case_id", "")),
				int(run.get("seed", 0)),
				String(run.get("carrier_side", "")),
				String(run.get("variant", "")),
			])

	var elapsed_s: float = float(Time.get_ticks_msec() - started_ms) / 1000.0
	var report: Dictionary[String, Variant] = {
		"schema_version": "item_balance_evidence_v1",
		"run_id": RUN_ID,
		"generated_at_unix": int(Time.get_unix_time_from_system()),
		"status": "pass" if failures.is_empty() else "fail",
		"output_path": ProjectSettings.globalize_path(OUTPUT_PATH),
		"elapsed_wall_s": elapsed_s,
		"configuration": {
			"seeds_per_case": max(1, seeds_per_case),
			"side_swaps_per_seed": 2,
			"variants_per_side": 2,
			"simulation_count": raw_runs.size(),
			"combat_timeout_s": combat_timeout_s,
			"max_wall_clock_ms": max_wall_clock_ms,
			"base_seed": BASE_SEED,
		},
		"catalog_coverage": catalog_evidence,
		"sample_cases": SAMPLE_CASES.duplicate(true),
		"case_summaries": case_summaries,
		"causal_pairs": causal_pairs,
		"raw_runs": raw_runs,
		"failures": failures,
		"source_constants": {
			"completed_catalog": "res://data/items/completed/*.tres via scripts/game/items/item_catalog.gd",
			"effect_handlers": "res://scripts/game/items/effects/effect_registry.gd",
			"primary_bundles": AFFINITIES_PATH,
			"runtime": "res://tests/rga_testing/core/lockstep_simulator.gd with live CombatEngine and test-isolated SimulationItemRuntime catalog modifiers plus EffectRegistry wiring",
		},
		"limitations": [
			"The causal lane is a deliberately manageable eight-item, one-item-at-a-time 1v1 sample; it does not estimate all 36 items' teamfight power.",
			"Same-seed pairing and side swaps reduce RNG and side-order confounding, but an item can change event order and therefore later RNG consumption.",
			"Healing and shield deltas depend on the live CombatStatsCollector signal surface; un-emitted sustain is not observable here.",
			"Catalog coverage proves definition, handler, component, and primary-bundle reachability, not trigger magnitude correctness for every effect.",
			"No subjective win-rate or power threshold is enforced; failures are limited to catalog/runtime integrity and invalid wall-clock evidence.",
		],
	}
	_write_report(report)
	print("ItemBalanceEvidenceProbe: status=%s simulations=%d completed_items=%d output=%s elapsed_s=%.2f" % [
		String(report.get("status", "")),
		raw_runs.size(),
		int(catalog_evidence.get("completed_item_count", 0)),
		ProjectSettings.globalize_path(OUTPUT_PATH),
		elapsed_s,
	])
	for failure: String in failures:
		push_error("ItemBalanceEvidenceProbe: " + failure)
	if do_quit_on_finish:
		get_tree().quit(0 if failures.is_empty() else 1)

func _load_primary_surface(failures: Array[String]) -> Dictionary[String, Variant]:
	var surface: Dictionary[String, Variant] = {
		"bundles_by_unit": {},
		"mentions_by_item": {},
		"carriers_by_item": {},
		"primary_bundle_count": 0,
	}
	var file: FileAccess = FileAccess.open(AFFINITIES_PATH, FileAccess.READ)
	if file == null:
		failures.append("could not open primary-build affinity source " + AFFINITIES_PATH)
		return surface
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		failures.append("primary-build affinity source did not parse as a dictionary")
		return surface
	var root: Dictionary[String, Variant] = _string_variant_dictionary(parsed)
	var units_value: Variant = root.get("units", {})
	if typeof(units_value) != TYPE_DICTIONARY:
		failures.append("primary-build affinity source has no units dictionary")
		return surface
	var units: Dictionary[String, Variant] = _string_variant_dictionary(units_value)
	var bundles_by_unit: Dictionary[String, Variant] = {}
	var mentions_by_item: Dictionary[String, int] = {}
	var carriers_by_item: Dictionary[String, Variant] = {}
	for unit_key: Variant in units.keys():
		var unit_id: String = String(unit_key)
		var payload_value: Variant = units[unit_key]
		if typeof(payload_value) != TYPE_DICTIONARY:
			continue
		var payload: Dictionary[String, Variant] = _string_variant_dictionary(payload_value)
		var lanes_value: Variant = payload.get("lanes", [])
		if not (lanes_value is Array):
			continue
		for lane_value: Variant in lanes_value:
			if typeof(lane_value) != TYPE_DICTIONARY:
				continue
			var lane: Dictionary[String, Variant] = _string_variant_dictionary(lane_value)
			if String(lane.get("lane_id", "")) != "primary":
				continue
			var item_ids: Array[String] = _string_array(lane.get("items", []))
			var unique_ids: Dictionary[String, bool] = {}
			for item_id: String in item_ids:
				if unique_ids.has(item_id):
					failures.append("primary bundle %s repeats item %s" % [unit_id, item_id])
				unique_ids[item_id] = true
				var item_def: ItemDef = ItemCatalog.get_def(item_id)
				if item_def == null or String(item_def.type) != "completed":
					failures.append("primary bundle %s references non-completed item %s" % [unit_id, item_id])
				mentions_by_item[item_id] = int(mentions_by_item.get(item_id, 0)) + 1
				var carriers: Array[String] = _string_array(carriers_by_item.get(item_id, []))
				carriers.append(unit_id)
				carriers_by_item[item_id] = carriers
			bundles_by_unit[unit_id] = item_ids
			break
	surface["bundles_by_unit"] = bundles_by_unit
	surface["mentions_by_item"] = mentions_by_item
	surface["carriers_by_item"] = carriers_by_item
	surface["primary_bundle_count"] = bundles_by_unit.size()
	return surface

func _catalog_evidence(primary_surface: Dictionary[String, Variant], failures: Array[String]) -> Dictionary[String, Variant]:
	var registry: EffectRegistry = EffectRegistry.new()
	registry.configure(null, null, null)
	var completed_values: Array[Variant] = _variant_array(ItemCatalog.by_type("completed"))
	var registered_effect_ids: Array[String] = _string_array(registry.registered_effect_ids())
	var mentions_by_item: Dictionary[String, int] = _string_int_dictionary(primary_surface.get("mentions_by_item", {}))
	var carriers_by_item: Dictionary[String, Variant] = _string_variant_dictionary(primary_surface.get("carriers_by_item", {}))
	var rows: Array[Variant] = []
	var seen_ids: Dictionary[String, bool] = {}
	var with_handlers: int = 0
	var mentioned_count: int = 0
	for item_value: Variant in completed_values:
		var item: ItemDef = item_value as ItemDef
		if item == null:
			failures.append("completed catalog returned a non-ItemDef value")
			continue
		var item_id: String = String(item.id).strip_edges()
		if item_id == "":
			failures.append("completed catalog contains blank item id")
			continue
		if seen_ids.has(item_id):
			failures.append("completed catalog contains duplicate id " + item_id)
		seen_ids[item_id] = true
		var effects: Array[String] = _string_array(item.effects)
		var missing_handlers: Array[String] = []
		for effect_id: String in effects:
			if effect_id == "" or not registry.has_handler(effect_id):
				missing_handlers.append(effect_id)
		if effects.is_empty():
			failures.append("completed item %s declares no runtime effects" % item_id)
		if not missing_handlers.is_empty():
			failures.append("completed item %s has missing handlers %s" % [item_id, JSON.stringify(missing_handlers)])
		elif not effects.is_empty():
			with_handlers += 1
		var components: Array[String] = _string_array(item.components)
		if components.size() != 2:
			failures.append("completed item %s declares %d components instead of 2" % [item_id, components.size()])
		for component_id: String in components:
			var component: ItemDef = ItemCatalog.get_def(component_id)
			if component == null or String(component.type) != "component":
				failures.append("completed item %s references invalid component %s" % [item_id, component_id])
		var mention_count: int = int(mentions_by_item.get(item_id, 0))
		if mention_count > 0:
			mentioned_count += 1
		rows.append({
			"item_id": item_id,
			"name": String(item.name),
			"effects": effects,
			"all_effects_registered": missing_handlers.is_empty() and not effects.is_empty(),
			"missing_handlers": missing_handlers,
			"components": components,
			"stat_mods": item.stat_mods.duplicate(true),
			"tags": _string_array(item.tags),
			"build_axes": _string_array(item.build_axes),
			"primary_bundle_mentions": mention_count,
			"primary_bundle_carriers": _string_array(carriers_by_item.get(item_id, [])),
			"causal_sampled": _is_sampled_item(item_id),
		})
	rows.sort_custom(func(left_value: Variant, right_value: Variant) -> bool:
		var left: Dictionary[String, Variant] = _string_variant_dictionary(left_value)
		var right: Dictionary[String, Variant] = _string_variant_dictionary(right_value)
		return String(left.get("item_id", "")) < String(right.get("item_id", ""))
	)
	if rows.size() != EXPECTED_COMPLETED_ITEM_COUNT:
		failures.append("completed catalog count=%d expected=%d" % [rows.size(), EXPECTED_COMPLETED_ITEM_COUNT])
	registry.clear()
	return {
		"expected_completed_item_count": EXPECTED_COMPLETED_ITEM_COUNT,
		"completed_item_count": rows.size(),
		"items_with_all_handlers": with_handlers,
		"items_mentioned_in_primary_bundles": mentioned_count,
		"items_never_mentioned_in_primary_bundles": rows.size() - mentioned_count,
		"primary_bundle_count": int(primary_surface.get("primary_bundle_count", 0)),
		"registered_effect_ids": registered_effect_ids,
		"items": rows,
	}

func _validate_sample_contract(primary_surface: Dictionary[String, Variant], failures: Array[String]) -> void:
	var bundles_by_unit: Dictionary[String, Variant] = _string_variant_dictionary(primary_surface.get("bundles_by_unit", {}))
	for case_value: Variant in SAMPLE_CASES:
		var case_def: Dictionary[String, Variant] = _string_variant_dictionary(case_value)
		var carrier: String = String(case_def.get("carrier", ""))
		var item_id: String = String(case_def.get("item", ""))
		var role: String = String(case_def.get("role", ""))
		var item: ItemDef = ItemCatalog.get_def(item_id)
		if item == null or String(item.type) != "completed":
			failures.append("sample %s references missing completed item %s" % [String(case_def.get("case_id", "")), item_id])
		elif not _string_array(item.tags).has(role):
			failures.append("sample %s item %s is not tagged for declared role %s" % [String(case_def.get("case_id", "")), item_id, role])
		var bundle: Array[String] = _string_array(bundles_by_unit.get(carrier, []))
		if not bundle.has(item_id):
			failures.append("sample %s is not on carrier %s's primary bundle" % [item_id, carrier])

func _simulate(case_def: Dictionary[String, Variant], seed: int, swapped: bool, variant: String) -> Dictionary[String, Variant]:
	var carrier: String = String(case_def.get("carrier", ""))
	var opponent: String = String(case_def.get("opponent", ""))
	var item_id: String = String(case_def.get("item", ""))
	var carrier_side: String = "b" if swapped else "a"
	var team_a_ids: Array[String] = []
	var team_b_ids: Array[String] = []
	if swapped:
		team_a_ids.append(opponent)
		team_b_ids.append(carrier)
	else:
		team_a_ids.append(carrier)
		team_b_ids.append(opponent)
	var empty_loadout: Array[String] = []
	var carrier_loadout: Array[String] = []
	if variant == "one_item":
		carrier_loadout.append(item_id)
	var team_a_items: Array[Variant] = []
	var team_b_items: Array[Variant] = []
	team_a_items.append(empty_loadout.duplicate() if swapped else carrier_loadout.duplicate())
	team_b_items.append(carrier_loadout.duplicate() if swapped else empty_loadout.duplicate())
	var job: DataModels.SimJob = DataModels.SimJob.new()
	job.run_id = RUN_ID
	job.sim_index = _sim_index
	job.seed = seed
	job.team_a_ids = team_a_ids
	job.team_b_ids = team_b_ids
	job.team_size = 1
	job.scenario_id = "open_field"
	job.map_params = {
		"map_id": "item_causal_1v1",
		"formation": "role_based",
		"openness": 0.85,
		"obstacle_density": 0.15,
		"tile_size": 1.0,
		"depth_gap": 1.2,
		"half_width_tiles": 6.0,
		"half_height_tiles": 5.0,
		"row_spacing_tiles": 2.0,
	}
	job.deterministic = true
	job.delta_s = 0.05
	job.timeout_s = max(1.0, combat_timeout_s)
	job.abilities = true
	job.bridge_projectile_to_hit = true
	job.capabilities = PackedStringArray(["base"])
	job.metadata = {
		"scenario_label": "item_causal_1v1",
		"team_a_items": team_a_items,
		"team_b_items": team_b_items,
		"perf_adaptive": true,
		"perf_fast_dt": 0.20,
		"perf_margin_tiles": 0.75,
		"max_wall_clock_ms": max(0, max_wall_clock_ms),
	}
	_sim_index += 1
	var simulator: LockstepSimulator = LockstepSimulator.new()
	var collector: CombatStatsCollector = CombatStatsCollector.new()
	var sim_out: Dictionary[String, Variant] = _string_variant_dictionary(simulator.run(job, false, collector))
	if sim_out.has("simulation_input_error"):
		return {
			"case_id": String(case_def.get("case_id", "")),
			"carrier": carrier,
			"opponent": opponent,
			"item": item_id,
			"role": String(case_def.get("role", "")),
			"variant": variant,
			"seed": seed,
			"carrier_side": carrier_side,
			"simulation_input_error": String(sim_out.get("simulation_input_error", "")),
			"carrier_items": [],
		}
	return _run_row(case_def, job, sim_out, carrier_side, variant)

func _run_row(case_def: Dictionary[String, Variant], job: DataModels.SimJob, sim_out: Dictionary[String, Variant], carrier_side: String, variant: String) -> Dictionary[String, Variant]:
	var outcome: DataModels.EngineOutcome = sim_out.get("engine_outcome", null) as DataModels.EngineOutcome
	var aggregates: Dictionary[String, Variant] = _string_variant_dictionary(sim_out.get("aggregates", {}))
	var teams: Dictionary[String, Variant] = _string_variant_dictionary(aggregates.get("teams", {}))
	var carrier_metrics: Dictionary[String, Variant] = _string_variant_dictionary(teams.get(carrier_side, {}))
	var opponent_side: String = "b" if carrier_side == "a" else "a"
	var opponent_metrics: Dictionary[String, Variant] = _string_variant_dictionary(teams.get(opponent_side, {}))
	var item_loadouts: Dictionary[String, Variant] = _string_variant_dictionary(sim_out.get("item_loadouts", {}))
	var carrier_items: Array[String] = _side_first_loadout(item_loadouts, carrier_side)
	var opponent_items: Array[String] = _side_first_loadout(item_loadouts, opponent_side)
	var result: String = String(outcome.result) if outcome != null else "missing"
	var carrier_win_result: String = "team_a" if carrier_side == "a" else "team_b"
	var opponent_win_result: String = "team_b" if carrier_side == "a" else "team_a"
	return {
		"case_id": String(case_def.get("case_id", "")),
		"carrier": String(case_def.get("carrier", "")),
		"opponent": String(case_def.get("opponent", "")),
		"item": String(case_def.get("item", "")),
		"role": String(case_def.get("role", "")),
		"variant": variant,
		"seed": int(job.seed),
		"carrier_side": carrier_side,
		"carrier_items": carrier_items,
		"opponent_items": opponent_items,
		"result": result,
		"carrier_win": 1.0 if result == carrier_win_result else 0.0,
		"carrier_loss": 1.0 if result == opponent_win_result else 0.0,
		"stall": 1.0 if result == "timeout" or result == "wall_timeout" else 0.0,
		"tie": 1.0 if result == "tie" or result == "draw" else 0.0,
		"time_s": float(outcome.time_s) if outcome != null else -1.0,
		"wall_timeout": bool(sim_out.get("wall_timeout", false)),
		"wall_elapsed_ms": int(sim_out.get("wall_elapsed_ms", 0)),
		"carrier_damage": float(carrier_metrics.get("damage", 0)),
		"carrier_healing": float(carrier_metrics.get("healing", 0)),
		"carrier_shield": float(carrier_metrics.get("shield", 0)),
		"carrier_mitigated": float(carrier_metrics.get("mitigated", 0)),
		"carrier_casts": float(carrier_metrics.get("casts", 0)),
		"opponent_damage": float(opponent_metrics.get("damage", 0)),
		"opponent_healing": float(opponent_metrics.get("healing", 0)),
		"opponent_shield": float(opponent_metrics.get("shield", 0)),
		"opponent_mitigated": float(opponent_metrics.get("mitigated", 0)),
		"opponent_casts": float(opponent_metrics.get("casts", 0)),
	}

func _causal_pair(case_def: Dictionary[String, Variant], baseline: Dictionary[String, Variant], equipped: Dictionary[String, Variant]) -> Dictionary[String, Variant]:
	var metrics: Array[String] = [
		"carrier_win", "carrier_loss", "stall", "tie", "time_s",
		"carrier_damage", "carrier_healing", "carrier_shield", "carrier_mitigated", "carrier_casts",
		"opponent_damage", "opponent_healing", "opponent_shield", "opponent_mitigated", "opponent_casts",
	]
	var deltas: Dictionary[String, float] = {}
	for metric: String in metrics:
		deltas[metric] = float(equipped.get(metric, 0.0)) - float(baseline.get(metric, 0.0))
	return {
		"case_id": String(case_def.get("case_id", "")),
		"carrier": String(case_def.get("carrier", "")),
		"opponent": String(case_def.get("opponent", "")),
		"item": String(case_def.get("item", "")),
		"seed": int(baseline.get("seed", 0)),
		"carrier_side": String(baseline.get("carrier_side", "")),
		"baseline_result": String(baseline.get("result", "")),
		"equipped_result": String(equipped.get("result", "")),
		"baseline": baseline.duplicate(true),
		"equipped": equipped.duplicate(true),
		"delta_item_minus_baseline": deltas,
	}

func _case_summary(case_def: Dictionary[String, Variant], causal_pairs: Array[Variant]) -> Dictionary[String, Variant]:
	var selected: Array[Variant] = []
	for pair_value: Variant in causal_pairs:
		var pair: Dictionary[String, Variant] = _string_variant_dictionary(pair_value)
		if String(pair.get("case_id", "")) == String(case_def.get("case_id", "")):
			selected.append(pair)
	var metric_names: Array[String] = [
		"carrier_win", "carrier_loss", "stall", "tie", "time_s",
		"carrier_damage", "carrier_healing", "carrier_shield", "carrier_mitigated", "carrier_casts",
		"opponent_damage", "opponent_healing", "opponent_shield", "opponent_mitigated", "opponent_casts",
	]
	var baseline_means: Dictionary[String, float] = {}
	var equipped_means: Dictionary[String, float] = {}
	var delta_means: Dictionary[String, float] = {}
	for metric: String in metric_names:
		var baseline_values: Array[float] = []
		var equipped_values: Array[float] = []
		var delta_values: Array[float] = []
		for pair_value: Variant in selected:
			var pair: Dictionary[String, Variant] = _string_variant_dictionary(pair_value)
			var baseline: Dictionary[String, Variant] = _string_variant_dictionary(pair.get("baseline", {}))
			var equipped: Dictionary[String, Variant] = _string_variant_dictionary(pair.get("equipped", {}))
			var deltas: Dictionary[String, float] = _string_float_dictionary(pair.get("delta_item_minus_baseline", {}))
			baseline_values.append(float(baseline.get(metric, 0.0)))
			equipped_values.append(float(equipped.get(metric, 0.0)))
			delta_values.append(float(deltas.get(metric, 0.0)))
		baseline_means[metric] = _mean(baseline_values)
		equipped_means[metric] = _mean(equipped_values)
		delta_means[metric] = _mean(delta_values)
	return {
		"case_id": String(case_def.get("case_id", "")),
		"carrier": String(case_def.get("carrier", "")),
		"opponent": String(case_def.get("opponent", "")),
		"item": String(case_def.get("item", "")),
		"role": String(case_def.get("role", "")),
		"paired_observations": selected.size(),
		"baseline_mean": baseline_means,
		"one_item_mean": equipped_means,
		"delta_item_minus_baseline": delta_means,
	}

func _validate_causal_liveness(case_summaries: Array[Variant], failures: Array[String]) -> void:
	var liveness_metrics: Array[String] = [
		"time_s", "carrier_damage", "carrier_healing", "carrier_shield", "carrier_mitigated",
		"opponent_damage", "opponent_healing", "opponent_shield", "opponent_mitigated",
	]
	for summary_value: Variant in case_summaries:
		var summary: Dictionary[String, Variant] = _string_variant_dictionary(summary_value)
		if int(summary.get("paired_observations", 0)) <= 0:
			failures.append("sample %s produced no paired observations" % String(summary.get("case_id", "")))
			continue
		var deltas: Dictionary[String, float] = _string_float_dictionary(summary.get("delta_item_minus_baseline", {}))
		var any_change: bool = false
		for metric: String in liveness_metrics:
			if absf(float(deltas.get(metric, 0.0))) > 0.0001:
				any_change = true
				break
		if not any_change:
			failures.append("sample %s showed no causal runtime change under its equipped item" % String(summary.get("case_id", "")))

func _validate_runtime_application(raw_runs: Array[Variant], failures: Array[String]) -> void:
	for run_value: Variant in raw_runs:
		var run: Dictionary[String, Variant] = _string_variant_dictionary(run_value)
		var case_id: String = String(run.get("case_id", ""))
		var variant: String = String(run.get("variant", ""))
		var expected_item: String = String(run.get("item", ""))
		var input_error: String = String(run.get("simulation_input_error", ""))
		if input_error != "":
			failures.append("sample %s rejected its item loadout: %s" % [case_id, input_error])
			continue
		var carrier_items: Array[String] = _string_array(run.get("carrier_items", []))
		if variant == "no_item" and not carrier_items.is_empty():
			failures.append("sample %s baseline unexpectedly equipped %s" % [case_id, JSON.stringify(carrier_items)])
		elif variant == "one_item" and (carrier_items.size() != 1 or carrier_items[0] != expected_item):
			failures.append("sample %s expected equipped %s but simulator applied %s" % [case_id, expected_item, JSON.stringify(carrier_items)])

func _side_first_loadout(loadouts: Dictionary[String, Variant], side: String) -> Array[String]:
	var key: String = "team_a" if side == "a" else "team_b"
	var team_value: Variant = loadouts.get(key, [])
	if not (team_value is Array):
		return []
	var team_loadouts: Array = team_value as Array
	if team_loadouts.is_empty() or not (team_loadouts[0] is Array):
		return []
	return _string_array(team_loadouts[0])

func _is_sampled_item(item_id: String) -> bool:
	for case_value: Variant in SAMPLE_CASES:
		var case_def: Dictionary[String, Variant] = _string_variant_dictionary(case_value)
		if String(case_def.get("item", "")) == item_id:
			return true
	return false

func _string_variant_dictionary(value: Variant) -> Dictionary[String, Variant]:
	var output: Dictionary[String, Variant] = {}
	if typeof(value) == TYPE_DICTIONARY:
		output.assign(value)
	return output

func _string_int_dictionary(value: Variant) -> Dictionary[String, int]:
	var output: Dictionary[String, int] = {}
	if typeof(value) == TYPE_DICTIONARY:
		output.assign(value)
	return output

func _string_float_dictionary(value: Variant) -> Dictionary[String, float]:
	var output: Dictionary[String, float] = {}
	if typeof(value) == TYPE_DICTIONARY:
		output.assign(value)
	return output

func _variant_array(value: Variant) -> Array[Variant]:
	var output: Array[Variant] = []
	if typeof(value) == TYPE_ARRAY:
		output.assign(value)
	return output

func _mean(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var total: float = 0.0
	for value: float in values:
		total += value
	return total / float(values.size())

func _string_array(value: Variant) -> Array[String]:
	var out: Array[String] = []
	if value is Array:
		for entry: Variant in value:
			out.append(String(entry))
	elif value is PackedStringArray:
		for entry: String in value:
			out.append(String(entry))
	elif typeof(value) == TYPE_STRING:
		out.append(String(value))
	return out

func _write_report(report: Dictionary[String, Variant]) -> void:
	var output_dir: String = OUTPUT_PATH.get_base_dir()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
	var file: FileAccess = FileAccess.open(OUTPUT_PATH, FileAccess.WRITE)
	if file == null:
		push_error("ItemBalanceEvidenceProbe: could not write " + OUTPUT_PATH)
		return
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
