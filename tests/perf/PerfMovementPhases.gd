extends Node

const DataModels = preload("res://tests/rga_testing/core/data_models.gd")
const HeadlessSimPipeline = preload("res://tests/rga_testing/core/headless_sim_pipeline.gd")
const LockstepSimulator = preload("res://tests/rga_testing/core/lockstep_simulator.gd")

@export var seed: int = 525600
@export var delta_s_override: float = 0.05
@export var timeout_s: float = 75.0
@export var samples_per_case: int = 3

const TEAM_A_POOL: Array[String] = [
	"bonko", "korath", "sari", "pilfer", "mara", "axiom",
	"brute", "repo", "hexeon", "luna", "nyxa", "morrak"
]

const TEAM_B_POOL: Array[String] = [
	"repo", "bo", "sari", "pilfer", "mara", "knoll",
	"korath", "brute", "hexeon", "luna", "nyxa", "morrak"
]

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var case_defs: Array[Dictionary] = [
		{"label": "6v6_neutral", "team_size": 6, "map_params": _map_params_6v6("perf_phase_6v6_neutral")},
		{"label": "8v8_large", "team_size": 8, "map_params": _map_params_large(8)},
		{"label": "9v9_large", "team_size": 9, "map_params": _map_params_large(9)},
		{"label": "10v10_large", "team_size": 10, "map_params": _map_params_large(10)},
		{"label": "11v11_large", "team_size": 11, "map_params": _map_params_large(11)},
		{"label": "12v12_large", "team_size": 12, "map_params": _map_params_large(12)}
	]
	var failures: int = 0
	var sample_count: int = max(1, int(samples_per_case))
	print("PerfMovementPhases: cases=", case_defs.size(), " samples_per_case=", sample_count)
	for case_def in case_defs:
		var result: Dictionary = _run_case(case_def, sample_count)
		if not bool(result.get("ok", false)):
			failures += 1
	if get_tree() != null:
		get_tree().quit(1 if failures > 0 else 0)

func _run_case(case_def: Dictionary, sample_count: int) -> Dictionary:
	var samples: Array[Dictionary] = []
	var movement_values: Array[int] = []
	var elapsed_values: Array[int] = []
	var first_signature: String = ""
	var ok: bool = true
	var safe_sample_count: int = max(1, sample_count)
	for sample_index in range(safe_sample_count):
		var sample: Dictionary = _run_case_once(case_def)
		samples.append(sample)
		movement_values.append(int(sample.get("movement_usec", 0)))
		elapsed_values.append(int(sample.get("elapsed_ms", 0)))
		var sample_ok: bool = bool(sample.get("ok", false))
		if not sample_ok:
			ok = false
		var signature: String = String(sample.get("signature", ""))
		if sample_index == 0:
			first_signature = signature
		elif signature != first_signature:
			ok = false
			push_error("PerfMovementPhases: inconsistent signature for %s sample %d" % [String(case_def.get("label", "unknown")), sample_index])
	var median_movement_usec: int = _percentile_int(movement_values, 0.50)
	var representative: Dictionary = _sample_closest_to_median(samples, median_movement_usec)
	print("PerfMovementPhases case=", String(case_def.get("label", "unknown")),
		" samples=", safe_sample_count,
		" median_elapsed_ms=", _percentile_int(elapsed_values, 0.50),
		" p95_elapsed_ms=", _percentile_int(elapsed_values, 0.95),
		" min_elapsed_ms=", _min_int(elapsed_values),
		" max_elapsed_ms=", _max_int(elapsed_values),
		" frames=", int(representative.get("frames", -1)),
		" movement_frames=", int(representative.get("movement_frames", 0)),
		" sim_s=", _fmtn(float(representative.get("sim_s", -1.0))),
		" result=", String(representative.get("result", "")),
		" alive=", int(representative.get("team_a_alive", -1)), ":", int(representative.get("team_b_alive", -1)),
		" sig=", first_signature,
		" target_calls=", int(representative.get("target_calls", 0)),
		" target_skips=", int(representative.get("target_skips", 0)),
		" movement_usec=", median_movement_usec,
		" p95_movement_usec=", _percentile_int(movement_values, 0.95),
		" min_movement_usec=", _min_int(movement_values),
		" max_movement_usec=", _max_int(movement_values),
		" phases=", _phase_summary(representative),
		" slot_groups=", _hist_summary(representative.get("slot_group_sizes", {})),
		" slot_sides=", _hist_summary(representative.get("slot_side_usec", {})),
		" slot_group_usec=", _hist_summary(representative.get("slot_group_usec", {})),
		" slot_phase_usec=", _hist_summary(representative.get("slot_phase_usec", {})))
	return {"ok": ok, "signature": first_signature}

func _run_case_once(case_def: Dictionary) -> Dictionary:
	var label: String = String(case_def.get("label", "unknown"))
	var team_size: int = max(1, int(case_def.get("team_size", 1)))
	var raw_map_params: Variant = case_def.get("map_params", {})
	var map_params: Dictionary = raw_map_params.duplicate(true) if raw_map_params is Dictionary else {}
	var start_ms: int = Time.get_ticks_msec()
	var job: DataModels.SimJob = _make_job(label, team_size, map_params)
	var pipeline: HeadlessSimPipeline = HeadlessSimPipeline.new()
	var collector: RefCounted = pipeline._new_combined_aggregator(false)
	var sim: LockstepSimulator = LockstepSimulator.new()
	var out: Dictionary = sim.run(job, false, collector)
	var elapsed_ms: int = Time.get_ticks_msec() - start_ms
	var outcome: Variant = out.get("engine_outcome", null)
	var frames: int = -1
	var sim_s: float = -1.0
	var result: String = ""
	var team_a_alive: int = -1
	var team_b_alive: int = -1
	if outcome != null:
		frames = int(outcome.frames)
		sim_s = float(outcome.time_s)
		result = String(outcome.result)
		team_a_alive = int(outcome.team_a_alive)
		team_b_alive = int(outcome.team_b_alive)
	var payload: Dictionary = {
		"aggregates": out.get("aggregates", {}),
		"outcome": {
			"result": result,
			"time_s": sim_s,
			"frames": frames,
			"team_a_alive": team_a_alive,
			"team_b_alive": team_b_alive
		}
	}
	var signature: String = _signature_for(payload)
	var diagnostics: Dictionary = out.get("movement_diagnostics", {}) if out.get("movement_diagnostics", {}) is Dictionary else {}
	var movement_frames: int = int(diagnostics.get("frames", 0))
	var total_usec: int = int(diagnostics.get("total_usec", 0))
	var target_calls: int = int(diagnostics.get("target_calls", 0))
	var target_skips: int = int(diagnostics.get("target_skips", 0))
	var ok: bool = movement_frames > 0 and total_usec > 0
	if not ok:
		push_error("PerfMovementPhases: missing movement diagnostics for " + label)
	return {
		"ok": ok,
		"label": label,
		"elapsed_ms": elapsed_ms,
		"frames": frames,
		"movement_frames": movement_frames,
		"sim_s": sim_s,
		"result": result,
		"team_a_alive": team_a_alive,
		"team_b_alive": team_b_alive,
		"signature": signature,
		"target_calls": target_calls,
		"target_skips": target_skips,
		"movement_usec": total_usec,
		"phases_usec": diagnostics.get("phases_usec", {}),
		"slot_group_sizes": diagnostics.get("slot_group_sizes", {}),
		"slot_side_usec": diagnostics.get("slot_side_usec", {}),
		"slot_group_usec": diagnostics.get("slot_group_usec", {}),
		"slot_phase_usec": diagnostics.get("slot_phase_usec", {})
	}

func _make_job(label: String, team_size: int, map_params: Dictionary) -> DataModels.SimJob:
	var job: DataModels.SimJob = DataModels.SimJob.new()
	job.run_id = "perf_movement_phases_%s" % String(label)
	job.sim_index = 0
	job.seed = int(seed)
	job.team_a_ids = _pick_ids(TEAM_A_POOL, team_size)
	job.team_b_ids = _pick_ids(TEAM_B_POOL, team_size)
	job.team_size = int(team_size)
	job.scenario_id = "open_field"
	job.map_params = map_params.duplicate(true)
	job.deterministic = true
	job.delta_s = max(0.001, float(delta_s_override))
	job.timeout_s = max(1.0, float(timeout_s))
	job.abilities = true
	job.ability_metrics = true
	job.alternate_order = false
	job.bridge_projectile_to_hit = true
	job.capabilities = PackedStringArray(["base"])
	job.metadata = {
		"scenario_label": String(label),
		"profile": "perf_movement_phases",
		"perf_collision_iterations": 2,
		"perf_friendly_soft": true,
		"perf_avoidance_weight": 0.6,
		"perf_movement_diagnostics": true
	}
	return job

func _pick_ids(pool: Array[String], count: int) -> Array[String]:
	var out: Array[String] = []
	for index in range(max(0, count)):
		out.append(String(pool[index % pool.size()]))
	return out

func _map_params_6v6(map_id: String) -> Dictionary:
	return {
		"tile_size": 96.0,
		"formation": "role_based",
		"depth_gap": 1.5,
		"map_id": String(map_id),
		"openness": 0.7,
		"choke_count": 0,
		"obstacle_density": 0.25,
		"artillery_range": 8.0
	}

func _map_params_large(team_size: int) -> Dictionary:
	return {
		"tile_size": 96.0,
		"formation": "role_based",
		"depth_gap": 1.5,
		"map_id": "perf_phase_large_%d" % int(team_size),
		"openness": 0.8,
		"choke_count": 1,
		"obstacle_density": 0.18,
		"artillery_range": 8.0,
		"half_width_tiles": 9.0,
		"half_height_tiles": max(6.0, float(team_size) * 0.55),
		"row_spacing_tiles": 1.0
	}

func _phase_summary(sample: Dictionary) -> String:
	var phases_value: Variant = sample.get("phases_usec", {})
	if not (phases_value is Dictionary):
		return ""
	var phases: Dictionary = phases_value
	var total_usec: float = max(1.0, float(sample.get("movement_usec", 0)))
	var rows: Array[Dictionary] = []
	for phase_key in phases.keys():
		var usec: int = int(phases.get(phase_key, 0))
		rows.append({
			"name": String(phase_key),
			"usec": usec,
			"pct": (float(usec) / total_usec) * 100.0
		})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("usec", 0)) > int(b.get("usec", 0)))
	var parts: Array[String] = []
	var max_rows: int = min(6, rows.size())
	for index in range(max_rows):
		var row: Dictionary = rows[index]
		parts.append("%s:%dus:%0.1f%%" % [String(row.get("name", "")), int(row.get("usec", 0)), float(row.get("pct", 0.0))])
	return ",".join(parts)

func _hist_summary(value: Variant) -> String:
	if not (value is Dictionary):
		return ""
	var hist: Dictionary = value
	var keys: Array = hist.keys()
	keys.sort()
	var parts: Array[String] = []
	for raw_key in keys:
		parts.append("%s:%d" % [String(raw_key), int(hist.get(raw_key, 0))])
	return ",".join(parts)

func _sample_closest_to_median(samples: Array[Dictionary], median_movement_usec: int) -> Dictionary:
	if samples.is_empty():
		return {}
	var best: Dictionary = samples[0]
	var best_delta: int = abs(int(best.get("movement_usec", 0)) - median_movement_usec)
	for sample in samples:
		var delta: int = abs(int(sample.get("movement_usec", 0)) - median_movement_usec)
		if delta < best_delta:
			best_delta = delta
			best = sample
	return best

func _signature_for(val: Variant) -> String:
	var parts: Array[String] = []
	_collect_sig(parts, val, "root")
	parts.sort()
	var acc: int = 5381
	for part in parts:
		for character in String(part).to_utf8_buffer():
			acc = ((acc << 5) + acc) + int(character)
	return str(acc) + ":" + str(parts.size())

func _collect_sig(out: Array[String], value: Variant, key: String) -> void:
	match typeof(value):
		TYPE_DICTIONARY:
			var dict_value: Dictionary = value
			var keys: Array = dict_value.keys()
			keys.sort()
			for dict_key in keys:
				_collect_sig(out, dict_value.get(dict_key), String(key) + "." + String(dict_key))
		TYPE_ARRAY:
			var index: int = 0
			for item in (value as Array):
				_collect_sig(out, item, String(key) + "[" + str(index) + "]")
				index += 1
		TYPE_FLOAT, TYPE_INT:
			out.append(String(key) + "=" + _fmtn(float(value)))
		TYPE_BOOL:
			out.append(String(key) + "=" + ("1" if bool(value) else "0"))
		TYPE_STRING, TYPE_STRING_NAME:
			out.append(String(key) + "=" + String(value))
		_:
			pass

func _fmtn(value: float) -> String:
	return "%0.6f" % value

func _percentile_int(values: Array[int], pct: float) -> int:
	if values.is_empty():
		return 0
	var sorted_values: Array[int] = []
	for value in values:
		sorted_values.append(int(value))
	sorted_values.sort()
	var index: int = int(ceil(float(sorted_values.size()) * clampf(float(pct), 0.0, 1.0))) - 1
	index = clampi(index, 0, sorted_values.size() - 1)
	return int(sorted_values[index])

func _min_int(values: Array[int]) -> int:
	if values.is_empty():
		return 0
	var best: int = int(values[0])
	for value in values:
		best = min(best, int(value))
	return best

func _max_int(values: Array[int]) -> int:
	if values.is_empty():
		return 0
	var best: int = int(values[0])
	for value in values:
		best = max(best, int(value))
	return best
