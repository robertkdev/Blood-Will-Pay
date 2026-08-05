extends Node

const DataModels = preload("res://tests/rga_testing/core/data_models.gd")
const HeadlessSimPipeline = preload("res://tests/rga_testing/core/headless_sim_pipeline.gd")
const LockstepSimulator = preload("res://tests/rga_testing/core/lockstep_simulator.gd")

@export var samples_per_case: int = 3
@export var seed: int = 525600
@export var delta_s_override: float = 0.05
@export var timeout_s: float = 90.0
@export var use_roles_aggregator: bool = false
@export var pos_emit_interval: float = 0.1
@export var collision_iterations: int = 2
@export var friendly_soft: bool = true
@export var avoidance_weight: float = 0.6

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var total_start_ms: int = Time.get_ticks_msec()
	var case_defs: Array[Dictionary] = _case_defs()
	var sample_count: int = max(1, int(samples_per_case))
	var failures: int = 0
	var aggregate_payload: Dictionary = {}
	print("Perf6v6: cases=", case_defs.size(), " samples_per_case=", sample_count, " roles_aggregator=", bool(use_roles_aggregator))
	for case_def in case_defs:
		var case_result: Dictionary = _run_case(case_def, sample_count)
		var label: String = String(case_result.get("label", "unknown"))
		aggregate_payload[label] = {
			"signature": String(case_result.get("signature", "")),
			"frames": int(case_result.get("frames", -1)),
			"sim_s": float(case_result.get("sim_s", -1.0)),
			"result": String(case_result.get("result", "")),
			"team_a_alive": int(case_result.get("team_a_alive", -1)),
			"team_b_alive": int(case_result.get("team_b_alive", -1))
		}
		if not bool(case_result.get("consistent", false)):
			failures += 1
	var total_ms: int = Time.get_ticks_msec() - total_start_ms
	var aggregate_sig: String = _signature_for(aggregate_payload)
	print("Perf6v6: total_ms=", total_ms, " aggregate_sig=", aggregate_sig, " inconsistent_cases=", failures)
	if get_tree() != null:
		get_tree().quit(1 if failures > 0 else 0)

func _run_case(case_def: Dictionary, sample_count: int) -> Dictionary:
	var label: String = String(case_def.get("label", "unknown"))
	var case_seed: int = int(case_def.get("seed", seed))
	var map_params: Dictionary = {}
	var raw_map_params: Variant = case_def.get("map_params", {})
	if raw_map_params is Dictionary:
		map_params = (raw_map_params as Dictionary).duplicate(true)
	var ms_values: Array[int] = []
	var first_signature: String = ""
	var consistent: bool = true
	var frames: int = -1
	var sim_s: float = -1.0
	var result: String = ""
	var team_a_alive: int = -1
	var team_b_alive: int = -1
	for sample_index in range(sample_count):
		var sample_result: Dictionary = _run_sample(label, case_seed, sample_index, map_params)
		var elapsed_ms: int = int(sample_result.get("ms", 0))
		var signature: String = String(sample_result.get("signature", ""))
		ms_values.append(elapsed_ms)
		if sample_index == 0:
			first_signature = signature
			frames = int(sample_result.get("frames", -1))
			sim_s = float(sample_result.get("sim_s", -1.0))
			result = String(sample_result.get("result", ""))
			team_a_alive = int(sample_result.get("team_a_alive", -1))
			team_b_alive = int(sample_result.get("team_b_alive", -1))
		elif signature != first_signature:
			consistent = false
	var median_ms: int = _percentile_int(ms_values, 0.50)
	var p95_ms: int = _percentile_int(ms_values, 0.95)
	var min_ms: int = _min_int(ms_values)
	var max_ms: int = _max_int(ms_values)
	print("Perf6v6 case=", label,
		" median_ms=", median_ms,
		" p95_ms=", p95_ms,
		" min_ms=", min_ms,
		" max_ms=", max_ms,
		" frames=", frames,
		" sim_s=", _fmtn(sim_s),
		" result=", result,
		" alive=", team_a_alive, ":", team_b_alive,
		" sig=", first_signature,
		" consistent=", consistent)
	return {
		"label": label,
		"signature": first_signature,
		"consistent": consistent,
		"frames": frames,
		"sim_s": sim_s,
		"result": result,
		"team_a_alive": team_a_alive,
		"team_b_alive": team_b_alive
	}

func _run_sample(label: String, case_seed: int, sample_index: int, map_params: Dictionary) -> Dictionary:
	var start_ms: int = Time.get_ticks_msec()
	var job: DataModels.SimJob = _make_job(label, case_seed, sample_index, map_params)
	var pipeline: HeadlessSimPipeline = HeadlessSimPipeline.new()
	var collector: RefCounted = pipeline._new_combined_aggregator(use_roles_aggregator)
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
	return {
		"ms": max(0, elapsed_ms),
		"signature": _signature_for(payload),
		"frames": frames,
		"sim_s": sim_s,
		"result": result,
		"team_a_alive": team_a_alive,
		"team_b_alive": team_b_alive
	}

func _make_job(label: String, case_seed: int, sample_index: int, map_params: Dictionary) -> DataModels.SimJob:
	var job: DataModels.SimJob = DataModels.SimJob.new()
	job.run_id = "perf_6v6_%s" % String(label)
	job.sim_index = int(sample_index)
	job.seed = int(case_seed)
	job.team_a_ids = _team_a_ids()
	job.team_b_ids = _team_b_ids()
	job.team_size = 6
	job.scenario_id = "open_field"
	job.map_params = map_params.duplicate(true)
	job.deterministic = true
	job.delta_s = max(0.001, float(delta_s_override))
	job.timeout_s = max(1.0, float(timeout_s))
	job.abilities = true
	job.ability_metrics = true
	job.alternate_order = false
	job.bridge_projectile_to_hit = true
	if bool(use_roles_aggregator):
		job.capabilities = PackedStringArray(["base", "cc", "targets", "mobility", "zones", "buffs"])
	else:
		job.capabilities = PackedStringArray(["base"])
	var metadata: Dictionary = {
		"scenario_label": String(label),
		"profile": "perf_6v6"
	}
	if float(pos_emit_interval) > 0.0:
		metadata["perf_pos_emit_interval"] = float(pos_emit_interval)
	metadata["perf_collision_iterations"] = max(1, int(collision_iterations))
	metadata["perf_friendly_soft"] = bool(friendly_soft)
	metadata["perf_avoidance_weight"] = float(avoidance_weight)
	job.metadata = metadata
	return job

func _team_a_ids() -> Array[String]:
	var out: Array[String] = []
	out.append("bonko")
	out.append("korath")
	out.append("sari")
	out.append("pilfer")
	out.append("mara")
	out.append("axiom")
	return out

func _team_b_ids() -> Array[String]:
	var out: Array[String] = []
	out.append("repo")
	out.append("bo")
	out.append("sari")
	out.append("pilfer")
	out.append("mara")
	out.append("knoll")
	return out

func _case_defs() -> Array[Dictionary]:
	var cases: Array[Dictionary] = []
	cases.append({
		"label": "neutral",
		"seed": int(seed),
		"map_params": _map_params_neutral()
	})
	cases.append({
		"label": "burst",
		"seed": int(seed),
		"map_params": _map_params_burst()
	})
	cases.append({
		"label": "peel",
		"seed": int(seed),
		"map_params": _map_params_peel()
	})
	return cases

func _base_map_params(map_id: String) -> Dictionary:
	return {
		"tile_size": 96.0,
		"formation": "role_based",
		"depth_gap": 1.5,
		"map_id": String(map_id)
	}

func _map_params_neutral() -> Dictionary:
	var out: Dictionary = _base_map_params("perf_6v6_neutral")
	out["openness"] = 0.7
	out["choke_count"] = 0
	out["obstacle_density"] = 0.25
	out["artillery_range"] = 8.0
	return out

func _map_params_burst() -> Dictionary:
	var out: Dictionary = _base_map_params("perf_6v6_burst")
	out["openness"] = 0.55
	out["choke_count"] = 1
	out["obstacle_density"] = 0.35
	out["artillery_range"] = 7.0
	return out

func _map_params_peel() -> Dictionary:
	var out: Dictionary = _base_map_params("perf_6v6_peel")
	out["openness"] = 0.6
	out["choke_count"] = 0
	out["obstacle_density"] = 0.2
	out["artillery_range"] = 8.0
	return out

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
	var out: int = int(values[0])
	for value in values:
		out = min(out, int(value))
	return out

func _max_int(values: Array[int]) -> int:
	if values.is_empty():
		return 0
	var out: int = int(values[0])
	for value in values:
		out = max(out, int(value))
	return out

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
