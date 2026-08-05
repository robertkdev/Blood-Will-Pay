extends Node

const DataModels = preload("res://tests/rga_testing/core/data_models.gd")
const HeadlessSimPipeline = preload("res://tests/rga_testing/core/headless_sim_pipeline.gd")
const LockstepSimulator = preload("res://tests/rga_testing/core/lockstep_simulator.gd")

@export var samples_per_case: int = 2
@export var seed: int = 525600
@export var delta_s_override: float = 0.05
@export var timeout_s: float = 75.0

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
		{"label": "8v8", "team_size": 8},
		{"label": "12v12", "team_size": 12}
	]
	var sample_count: int = max(1, int(samples_per_case))
	var total_start_ms: int = Time.get_ticks_msec()
	var aggregate_payload: Dictionary = {}
	var failures: int = 0
	print("PerfLargeBoard: cases=", case_defs.size(), " samples_per_case=", sample_count)
	for case_def in case_defs:
		var result: Dictionary = _run_case(case_def, sample_count)
		var label: String = String(result.get("label", "unknown"))
		aggregate_payload[label] = {
			"signature": String(result.get("signature", "")),
			"frames": int(result.get("frames", -1)),
			"sim_s": float(result.get("sim_s", -1.0)),
			"result": String(result.get("result", "")),
			"team_a_alive": int(result.get("team_a_alive", -1)),
			"team_b_alive": int(result.get("team_b_alive", -1))
		}
		if not bool(result.get("consistent", false)):
			failures += 1
	var total_ms: int = Time.get_ticks_msec() - total_start_ms
	var aggregate_sig: String = _signature_for(aggregate_payload)
	print("PerfLargeBoard: total_ms=", total_ms, " aggregate_sig=", aggregate_sig, " inconsistent_cases=", failures)
	if get_tree() != null:
		get_tree().quit(1 if failures > 0 else 0)

func _run_case(case_def: Dictionary, sample_count: int) -> Dictionary:
	var label: String = String(case_def.get("label", "unknown"))
	var team_size: int = max(1, int(case_def.get("team_size", 1)))
	var ms_values: Array[int] = []
	var first_signature: String = ""
	var consistent: bool = true
	var frames: int = -1
	var sim_s: float = -1.0
	var result: String = ""
	var team_a_alive: int = -1
	var team_b_alive: int = -1
	for sample_index in range(sample_count):
		var sample_result: Dictionary = _run_sample(label, team_size, sample_index)
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
	print("PerfLargeBoard case=", label,
		" team_size=", team_size,
		" median_ms=", median_ms,
		" p95_ms=", p95_ms,
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

func _run_sample(label: String, team_size: int, sample_index: int) -> Dictionary:
	var start_ms: int = Time.get_ticks_msec()
	var job: DataModels.SimJob = _make_job(label, team_size, sample_index)
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
	return {
		"ms": max(0, elapsed_ms),
		"signature": _signature_for(payload),
		"frames": frames,
		"sim_s": sim_s,
		"result": result,
		"team_a_alive": team_a_alive,
		"team_b_alive": team_b_alive
	}

func _make_job(label: String, team_size: int, sample_index: int) -> DataModels.SimJob:
	var job: DataModels.SimJob = DataModels.SimJob.new()
	job.run_id = "perf_large_board_%s" % String(label)
	job.sim_index = int(sample_index)
	job.seed = int(seed)
	job.team_a_ids = _pick_ids(TEAM_A_POOL, team_size)
	job.team_b_ids = _pick_ids(TEAM_B_POOL, team_size)
	job.team_size = int(team_size)
	job.scenario_id = "open_field"
	job.map_params = _map_params_large(team_size)
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
		"profile": "perf_large_board",
		"perf_collision_iterations": 2,
		"perf_friendly_soft": true,
		"perf_avoidance_weight": 0.6
	}
	return job

func _pick_ids(pool: Array[String], count: int) -> Array[String]:
	var out: Array[String] = []
	for index in range(max(0, count)):
		out.append(String(pool[index % pool.size()]))
	return out

func _map_params_large(team_size: int) -> Dictionary:
	return {
		"tile_size": 96.0,
		"formation": "role_based",
		"depth_gap": 1.5,
		"map_id": "perf_large_%d" % int(team_size),
		"openness": 0.8,
		"choke_count": 1,
		"obstacle_density": 0.18,
		"artillery_range": 8.0,
		"half_width_tiles": 9.0,
		"half_height_tiles": max(6.0, float(team_size) * 0.55),
		"row_spacing_tiles": 1.0
	}

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
