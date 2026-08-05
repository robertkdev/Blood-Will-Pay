extends Node

const DataModels = preload("res://tests/rga_testing/core/data_models.gd")
const LockstepSimulator = preload("res://tests/rga_testing/core/lockstep_simulator.gd")

@export var seed: int = 525600
@export var delta_s_override: float = 0.05
@export var timeout_s: float = 75.0
@export var samples_per_case: int = 1

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
		{"label": "6v6_neutral", "team_size": 6, "map_params": _map_params_6v6("perf_group_shape_6v6_neutral")},
		{"label": "8v8_large", "team_size": 8, "map_params": _map_params_large(8)},
		{"label": "9v9_large", "team_size": 9, "map_params": _map_params_large(9)},
		{"label": "10v10_large", "team_size": 10, "map_params": _map_params_large(10)},
		{"label": "11v11_large", "team_size": 11, "map_params": _map_params_large(11)},
		{"label": "12v12_large", "team_size": 12, "map_params": _map_params_large(12)}
	]
	var failures: int = 0
	var sample_count: int = max(1, int(samples_per_case))
	var aggregate_payload: Dictionary = {}
	print("PerfTargetGroupShapes: cases=", case_defs.size(), " samples_per_case=", sample_count)
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
	var aggregate_sig: String = _signature_for(aggregate_payload)
	print("PerfTargetGroupShapes: aggregate_sig=", aggregate_sig, " inconsistent_cases=", failures)
	if get_tree() != null:
		get_tree().quit(1 if failures > 0 else 0)

func _run_case(case_def: Dictionary, sample_count: int) -> Dictionary:
	var label: String = String(case_def.get("label", "unknown"))
	var samples: Array[Dictionary] = []
	var first_signature: String = ""
	var consistent: bool = true
	for sample_index in range(max(1, sample_count)):
		var sample: Dictionary = _run_case_once(case_def, sample_index)
		samples.append(sample)
		var signature: String = String(sample.get("signature", ""))
		if sample_index == 0:
			first_signature = signature
		elif signature != first_signature:
			consistent = false
			push_error("PerfTargetGroupShapes: inconsistent signature for %s sample %d" % [label, sample_index])
	var representative: Dictionary = samples[0] if not samples.is_empty() else {}
	var diagnostics: Dictionary = representative.get("diagnostics", {}) if representative.get("diagnostics", {}) is Dictionary else {}
	print("PerfTargetGroupShapes case=", label,
		" samples=", max(1, sample_count),
		" frames=", int(representative.get("frames", -1)),
		" diag_frames=", int(diagnostics.get("frames", 0)),
		" sim_s=", _fmtn(float(representative.get("sim_s", -1.0))),
		" result=", String(representative.get("result", "")),
		" alive=", int(representative.get("team_a_alive", -1)), ":", int(representative.get("team_b_alive", -1)),
		" sig=", first_signature,
		" group_sizes=", _hist_summary(diagnostics, "combined_group_sizes"),
		" max_group_sizes=", _hist_summary(diagnostics, "combined_max_group_sizes"),
		" player_single_target_frames=", int(diagnostics.get("player_single_target_frames", 0)),
		" enemy_single_target_frames=", int(diagnostics.get("enemy_single_target_frames", 0)),
		" player_group_events=", int(diagnostics.get("player_group_events", 0)),
		" enemy_group_events=", int(diagnostics.get("enemy_group_events", 0)))
	return {
		"label": label,
		"signature": first_signature,
		"consistent": consistent,
		"frames": int(representative.get("frames", -1)),
		"sim_s": float(representative.get("sim_s", -1.0)),
		"result": String(representative.get("result", "")),
		"team_a_alive": int(representative.get("team_a_alive", -1)),
		"team_b_alive": int(representative.get("team_b_alive", -1))
	}

func _run_case_once(case_def: Dictionary, sample_index: int) -> Dictionary:
	var label: String = String(case_def.get("label", "unknown"))
	var team_size: int = max(1, int(case_def.get("team_size", 1)))
	var raw_map_params: Variant = case_def.get("map_params", {})
	var map_params: Dictionary = raw_map_params.duplicate(true) if raw_map_params is Dictionary else {}
	var job: DataModels.SimJob = _make_job(label, team_size, map_params, sample_index)
	var sim: LockstepSimulator = LockstepSimulator.new()
	var out: Dictionary = sim.run(job, false, null)
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
	var diagnostics: Dictionary = out.get("target_group_diagnostics", {}) if out.get("target_group_diagnostics", {}) is Dictionary else {}
	var payload: Dictionary = {
		"outcome": {
			"result": result,
			"time_s": sim_s,
			"frames": frames,
			"team_a_alive": team_a_alive,
			"team_b_alive": team_b_alive
		},
		"target_group_diagnostics": diagnostics
	}
	return {
		"signature": _signature_for(payload),
		"frames": frames,
		"sim_s": sim_s,
		"result": result,
		"team_a_alive": team_a_alive,
		"team_b_alive": team_b_alive,
		"diagnostics": diagnostics
	}

func _make_job(label: String, team_size: int, map_params: Dictionary, sample_index: int) -> DataModels.SimJob:
	var job: DataModels.SimJob = DataModels.SimJob.new()
	job.run_id = "perf_target_group_shapes_%s" % String(label)
	job.sim_index = int(sample_index)
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
		"profile": "perf_target_group_shapes",
		"perf_collision_iterations": 2,
		"perf_friendly_soft": true,
		"perf_avoidance_weight": 0.6,
		"perf_target_group_diagnostics": true
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
		"map_id": "perf_group_shape_large_%d" % int(team_size),
		"openness": 0.8,
		"choke_count": 1,
		"obstacle_density": 0.18,
		"artillery_range": 8.0,
		"half_width_tiles": 9.0,
		"half_height_tiles": max(6.0, float(team_size) * 0.55),
		"row_spacing_tiles": 1.0
	}

func _hist_summary(root: Dictionary, key: String) -> String:
	var hist_value: Variant = root.get(key, {})
	if not (hist_value is Dictionary):
		return ""
	var hist: Dictionary = hist_value
	var keys: Array = hist.keys()
	keys.sort_custom(func(a: Variant, b: Variant) -> bool: return int(a) < int(b))
	var parts: Array[String] = []
	for raw_key in keys:
		var size_key: String = String(raw_key)
		parts.append("%s:%d" % [size_key, int(hist.get(raw_key, 0))])
	return ",".join(parts)

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
