extends Node

const DataModels := preload("res://tests/rga_testing/core/data_models.gd")
const LockstepSimulator := preload("res://tests/rga_testing/core/lockstep_simulator.gd")
const ItemCatalog := preload("res://scripts/game/items/item_catalog.gd")

const RUN_ID: String = "counter_focus_diagnostic"
const OUTPUT_PATH: String = "user://counter_focus_diagnostic.json"
const DELTA_S: float = 0.05
const TIMEOUT_S: float = 60.0

var _sim_index: int = 0
var _rows: Array[Dictionary] = []

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	ItemCatalog.reload()
	for scenario: Dictionary in _scenarios():
		_run_scenario(scenario)
	_write_results()
	print("CounterFocusDiagnostic: PASS scenarios=%d output=%s" % [_rows.size(), OUTPUT_PATH])
	get_tree().quit(0)

func _scenarios() -> Array[Dictionary]:
	return [
		{
			"id": "nullora_primary_vs_bastionne_meridian",
			"team_a": ["nullora"],
			"team_b": ["bastionne", "meridian"],
			"team_a_items": [["relay", "gamblers_eye", "mind_siphon"]],
			"team_b_items": [["anchor", "guard", "wardheart"], ["arc_dice", "orb_on_a_stick", "spellblade"]],
			"seed": 756585,
		},
		{
			"id": "nullora_primary_vs_quillith_meridian",
			"team_a": ["nullora"],
			"team_b": ["quillith", "meridian"],
			"team_a_items": [["relay", "gamblers_eye", "mind_siphon"]],
			"team_b_items": [["anchor", "orb_on_a_stick", "vital_battery"], ["arc_dice", "orb_on_a_stick", "spellblade"]],
			"seed": 755809,
		},
		{
			"id": "malachor_primary_vs_quillith_meridian_bastionne_draxelle",
			"team_a": ["malachor"],
			"team_b": ["quillith", "meridian", "bastionne", "draxelle"],
			"team_a_items": [["anchor", "vital_battery", "orb_on_a_stick"]],
			"team_b_items": [
				["anchor", "orb_on_a_stick", "vital_battery"],
				["arc_dice", "orb_on_a_stick", "spellblade"],
				["anchor", "vital_battery", "orb_on_a_stick"],
				["guard", "wardheart", "anchor"]
			],
			"seed": 761629,
		},
		{
			"id": "vesper_off_vs_omenry",
			"team_a": ["vesper"],
			"team_b": ["omenry"],
			"team_a_items": [["relay", "mind_siphon", "vengeance"]],
			"team_b_items": [["bandana", "dagger", "hyperstone"]],
			"seed": 781805,
		},
		{
			"id": "vesper_off_vs_gable",
			"team_a": ["vesper"],
			"team_b": ["gable"],
			"team_a_items": [["relay", "mind_siphon", "vengeance"]],
			"team_b_items": [["bandana", "clockwork", "dagger"]],
			"seed": 781999,
		},
		{
			"id": "stall_bastionne_off_vs_malachor_meridian",
			"team_a": ["bastionne"],
			"team_b": ["malachor", "meridian"],
			"team_a_items": [["anchor", "guard", "wardheart"]],
			"team_b_items": [["guard", "wardheart", "anchor"], ["arc_dice", "orb_on_a_stick", "spellblade"]],
			"seed": 722247,
		},
		{
			"id": "stall_quillith_primary_vs_malachor_meridian",
			"team_a": ["quillith"],
			"team_b": ["malachor", "meridian"],
			"team_a_items": [["conductor", "orb_on_a_stick", "relay"]],
			"team_b_items": [["anchor", "vital_battery", "guard"], ["arc_dice", "orb_on_a_stick", "spellblade"]],
			"seed": 763375,
		},
	]

func _run_scenario(scenario: Dictionary) -> void:
	var job: DataModels.SimJob = DataModels.SimJob.new()
	job.run_id = RUN_ID
	job.sim_index = _sim_index
	job.seed = int(scenario.get("seed", 0))
	job.team_a_ids = _string_array(scenario.get("team_a", []))
	job.team_b_ids = _string_array(scenario.get("team_b", []))
	job.team_size = max(job.team_a_ids.size(), job.team_b_ids.size())
	job.scenario_id = "open_field"
	job.map_params = {
		"map_id": "counter_focus_diagnostic_open_field",
		"formation": "role_based",
		"openness": 0.82,
		"obstacle_density": 0.18,
		"artillery_range": 8.0,
	}
	job.deterministic = true
	job.delta_s = DELTA_S
	job.timeout_s = TIMEOUT_S
	job.abilities = true
	job.ability_metrics = false
	job.alternate_order = false
	job.bridge_projectile_to_hit = true
	job.capabilities = PackedStringArray(["base", "cc", "targets", "mobility", "zones"])
	job.metadata = {
		"scenario_label": String(scenario.get("id", "")),
		"team_a_items": _duplicate_loadouts(scenario.get("team_a_items", [])),
		"team_b_items": _duplicate_loadouts(scenario.get("team_b_items", [])),
		"perf_adaptive": true,
		"perf_fast_dt": 0.20,
		"perf_pos_emit_interval": 0.25,
	}
	var simulator: LockstepSimulator = LockstepSimulator.new()
	var result: Dictionary = simulator.run(job, true, null)
	var outcome: Variant = result.get("engine_outcome", null)
	var events: Array = result.get("events", []) as Array
	var summary: Dictionary = _event_summary(events)
	_rows.append({
		"id": String(scenario.get("id", "")),
		"seed": job.seed,
		"team_a": job.team_a_ids.duplicate(),
		"team_b": job.team_b_ids.duplicate(),
		"team_a_items": _duplicate_loadouts(scenario.get("team_a_items", [])),
		"team_b_items": _duplicate_loadouts(scenario.get("team_b_items", [])),
		"result": String(outcome.result) if outcome != null else "missing",
		"time_s": float(outcome.time_s) if outcome != null else 0.0,
		"team_a_alive": int(outcome.team_a_alive) if outcome != null else 0,
		"team_b_alive": int(outcome.team_b_alive) if outcome != null else 0,
		"event_summary": summary,
		"key_events": _key_events(events),
	})
	_sim_index += 1

func _event_summary(events: Array) -> Dictionary:
	var summary: Dictionary = {
		"ability_committed": {},
		"execute_bonus": {},
		"cc_applied": {},
		"cc_prevented": 0,
		"targetability_windows": {},
		"targetability_interactions": {},
		"shield_absorbed_total": 0,
		"damage_by_source": {},
		"damage_taken_by_target": {},
	}
	for event_value: Variant in events:
		if not (event_value is Dictionary):
			continue
		var event: Dictionary = event_value as Dictionary
		var kind: String = String(event.get("kind", ""))
		var data: Dictionary = event.get("data", {}) as Dictionary
		match kind:
			"ability_committed":
				_increment(summary.get("ability_committed", {}) as Dictionary, "%s:%d:%s" % [String(data.get("st", "")), int(data.get("si", -1)), String(data.get("ability_id", ""))], 1)
			"execute_bonus_applied":
				_increment(summary.get("execute_bonus", {}) as Dictionary, "%s:%d:%s" % [String(data.get("st", "")), int(data.get("si", -1)), String(data.get("kind", ""))], 1)
			"cc_applied":
				_increment(summary.get("cc_applied", {}) as Dictionary, "%s:%d->%s:%d:%s" % [String(data.get("st", "")), int(data.get("si", -1)), String(data.get("tt", "")), int(data.get("ti", -1)), String(data.get("kind", ""))], 1)
			"cc_taxed":
				if bool(data.get("prevented", false)):
					summary["cc_prevented"] = int(summary.get("cc_prevented", 0)) + 1
			"targetability_window":
				_increment(summary.get("targetability_windows", {}) as Dictionary, "%s:%d:%s:%s" % [String(data.get("team", "")), int(data.get("index", -1)), str(data.get("is_targetable", "")), String(data.get("reason", ""))], 1)
			"targetability_threat_interaction":
				_increment(summary.get("targetability_interactions", {}) as Dictionary, "%s:%d->%s:%d:%s" % [String(data.get("st", "")), int(data.get("si", -1)), String(data.get("tt", "")), int(data.get("ti", -1)), String(data.get("kind", ""))], 1)
			"shield_absorbed":
				summary["shield_absorbed_total"] = int(summary.get("shield_absorbed_total", 0)) + int(data.get("absorbed", 0))
			"hit_applied":
				var source_key: String = "%s:%d" % [String(data.get("team", "")), int(data.get("sidx", -1))]
				var target_team: String = "enemy" if String(data.get("team", "")) == "player" else "player"
				var target_key: String = "%s:%d" % [target_team, int(data.get("tidx", -1))]
				_increment(summary.get("damage_by_source", {}) as Dictionary, source_key, int(data.get("dealt", 0)))
				_increment(summary.get("damage_taken_by_target", {}) as Dictionary, target_key, int(data.get("dealt", 0)))
	return summary

func _key_events(events: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for event_value: Variant in events:
		if not (event_value is Dictionary):
			continue
		var event: Dictionary = event_value as Dictionary
		var kind: String = String(event.get("kind", ""))
		if not ["ability_committed", "execute_bonus_applied", "cc_applied", "cc_taxed", "targetability_window", "targetability_threat_interaction", "shield_absorbed"].has(kind):
			continue
		out.append(event)
		if out.size() >= 80:
			break
	return out

func _increment(map: Dictionary, key: String, amount: int) -> void:
	map[key] = int(map.get(key, 0)) + amount

func _write_results() -> void:
	var file: FileAccess = FileAccess.open(OUTPUT_PATH, FileAccess.WRITE)
	if file == null:
		push_error("CounterFocusDiagnostic: could not write %s" % OUTPUT_PATH)
		return
	file.store_string(JSON.stringify({"run_id": RUN_ID, "rows": _rows}, "\t"))
	file.close()

func _string_array(value: Variant) -> Array[String]:
	var out: Array[String] = []
	if value is PackedStringArray:
		for entry: String in value:
			out.append(entry)
	elif value is Array:
		for entry_value: Variant in value:
			out.append(String(entry_value))
	return out

func _duplicate_loadouts(value: Variant) -> Array:
	var out: Array = []
	if value is Array:
		for loadout_value: Variant in value:
			out.append(_string_array(loadout_value))
	return out
