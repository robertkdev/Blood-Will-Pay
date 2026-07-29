extends Node

const SlotStrategyScript: Script = preload("res://scripts/game/combat/movement/strategies/slot_strategy.gd")
const UnitFactoryScript: Script = preload("res://scripts/unit_factory.gd")

@export var samples_per_case: int = 3

const UNIT_IDS: Array[String] = [
	"bonko", "korath", "sari", "pilfer", "mara", "axiom",
	"brute", "repo", "hexeon", "luna", "nyxa", "morrak"
]

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var cases: Array[Dictionary] = [
		{"label": "dict_single_6", "mode": "dict", "count": 6, "target_count": 1, "iterations": 180},
		{"label": "dict_single_7", "mode": "dict", "count": 7, "target_count": 1, "iterations": 120},
		{"label": "dict_single_8", "mode": "dict", "count": 8, "target_count": 1, "iterations": 72},
		{"label": "dict_single_9", "mode": "dict", "count": 9, "target_count": 1, "iterations": 48},
		{"label": "dict_single_10", "mode": "dict", "count": 10, "target_count": 1, "iterations": 36},
		{"label": "dict_single_11", "mode": "dict", "count": 11, "target_count": 1, "iterations": 30},
		{"label": "dict_single_12", "mode": "dict", "count": 12, "target_count": 1, "iterations": 24},
		{"label": "dict_pair_10", "mode": "dict", "count": 10, "target_count": 2, "iterations": 108},
		{"label": "dict_pair_11", "mode": "dict", "count": 11, "target_count": 2, "iterations": 102},
		{"label": "dict_pair_12", "mode": "dict", "count": 12, "target_count": 2, "iterations": 96},
		{"label": "dict_split_12", "mode": "dict", "count": 12, "target_count": 3, "iterations": 72},
		{"label": "dict_quad_12", "mode": "dict", "count": 12, "target_count": 4, "iterations": 120},
		{"label": "dict_spread_12", "mode": "dict", "count": 12, "target_count": 12, "iterations": 180},
		{"label": "array_single_6", "mode": "array", "count": 6, "target_count": 1, "iterations": 180},
		{"label": "array_single_7", "mode": "array", "count": 7, "target_count": 1, "iterations": 120},
		{"label": "array_single_8", "mode": "array", "count": 8, "target_count": 1, "iterations": 72},
		{"label": "array_single_9", "mode": "array", "count": 9, "target_count": 1, "iterations": 48},
		{"label": "array_single_10", "mode": "array", "count": 10, "target_count": 1, "iterations": 36},
		{"label": "array_single_11", "mode": "array", "count": 11, "target_count": 1, "iterations": 30},
		{"label": "array_single_12", "mode": "array", "count": 12, "target_count": 1, "iterations": 24},
		{"label": "array_pair_10", "mode": "array", "count": 10, "target_count": 2, "iterations": 108},
		{"label": "array_pair_11", "mode": "array", "count": 11, "target_count": 2, "iterations": 102},
		{"label": "array_pair_12", "mode": "array", "count": 12, "target_count": 2, "iterations": 96},
		{"label": "array_split_12", "mode": "array", "count": 12, "target_count": 3, "iterations": 72},
		{"label": "array_quad_12", "mode": "array", "count": 12, "target_count": 4, "iterations": 120},
		{"label": "array_spread_12", "mode": "array", "count": 12, "target_count": 12, "iterations": 180}
	]
	var aggregate_signature: int = 23
	var total_ms: int = 0
	var sample_count: int = max(1, int(samples_per_case))
	for case_data in cases:
		var result: Dictionary = _run_case(case_data, sample_count)
		total_ms += int(result.get("median_ms", 0))
		aggregate_signature = _mix(aggregate_signature, int(result.get("signature", 0)))
		print("PerfSlotTeamAssignment case=", String(case_data.get("label", "")),
			" mode=", String(case_data.get("mode", "")),
			" count=", int(case_data.get("count", 0)),
			" target_count=", int(case_data.get("target_count", 0)),
			" iterations=", int(case_data.get("iterations", 0)),
			" samples=", sample_count,
			" median_ms=", int(result.get("median_ms", 0)),
			" p95_ms=", int(result.get("p95_ms", 0)),
			" min_ms=", int(result.get("min_ms", 0)),
			" max_ms=", int(result.get("max_ms", 0)),
			" map_size=", int(result.get("map_size", 0)),
			" signature=", int(result.get("signature", 0)))
	print("PerfSlotTeamAssignment: median_total_ms=", total_ms, " aggregate_sig=", aggregate_signature)
	get_tree().quit(0)

func _run_case(case_data: Dictionary, sample_count: int) -> Dictionary:
	var ms_values: Array[int] = []
	var first_signature: int = 0
	var map_size: int = 0
	for sample_index in range(max(1, sample_count)):
		var sample: Dictionary = _run_case_once(
			int(case_data.get("count", 0)),
			int(case_data.get("target_count", 1)),
			int(case_data.get("iterations", 0)),
			String(case_data.get("mode", "dict")))
		ms_values.append(int(sample.get("time_ms", 0)))
		if sample_index == 0:
			first_signature = int(sample.get("signature", 0))
			map_size = int(sample.get("map_size", 0))
		elif int(sample.get("signature", 0)) != first_signature:
			push_error("PerfSlotTeamAssignment: inconsistent signature for %s sample %d" % [String(case_data.get("label", "")), sample_index])
	return {
		"median_ms": _percentile_int(ms_values, 0.50),
		"p95_ms": _percentile_int(ms_values, 0.95),
		"min_ms": _min_int(ms_values),
		"max_ms": _max_int(ms_values),
		"map_size": map_size,
		"signature": first_signature
	}

func _run_case_once(count: int, target_count: int, iterations: int, mode: String) -> Dictionary:
	var strategy: SlotStrategy = SlotStrategyScript.new()
	var units: Array[Unit] = _spawn_units(count)
	var positions: Array[Vector2] = _positions_for(count, Vector2(300.0, 384.0), -1.0)
	var targets: Array[int] = _targets_for(count, target_count)
	var target_positions: Array[Vector2] = _target_positions_for(max(1, target_count))
	var alive: Array[bool] = _bool_array(count, true)
	var target_alive: Array[bool] = _bool_array(max(1, target_count), true)
	var groups: Dictionary = _groups_for(targets, max(1, target_count))
	var profiles: Array[MovementProfile] = _profiles_for(count)
	var previous_slots: Dictionary[int, Dictionary] = _previous_slots_for(count)
	var last_map: Dictionary = {}
	var slot_positions: Array[Vector2] = _vector2_array(count, Vector2.ZERO)
	var slot_indices: Array[int] = _int_array(count, -1)
	var slot_los: Array[bool] = _bool_array(count, false)
	var slot_slow_radii: Array[float] = _float_array(count, 0.0)
	var slot_corridor_radii: Array[float] = _float_array(count, 0.0)
	var slot_corridor_eps: Array[float] = _float_array(count, 0.0)
	var guard_sum: int = 0
	var started_usec: int = Time.get_ticks_usec()
	for iteration in range(max(0, iterations)):
		_nudge_targets(target_positions, iteration)
		if mode == "array":
			slot_indices.fill(-1)
			slot_los.fill(false)
			strategy.assign_slots_for_team_into_arrays(
				"player",
				units,
				positions,
				alive,
				targets,
				target_positions,
				target_alive,
				groups,
				profiles,
				96.0,
				slot_positions,
				slot_indices,
				slot_los,
				slot_slow_radii,
				slot_corridor_radii,
				slot_corridor_eps,
				0,
				[],
				previous_slots,
				6)
			guard_sum += _assigned_slot_count(slot_indices)
		else:
			last_map = strategy.assign_slots_for_team(
				"player",
				units,
				positions,
				alive,
				targets,
				target_positions,
				target_alive,
				groups,
				profiles,
				96.0,
				0,
				[],
				previous_slots,
				6)
			guard_sum += last_map.size()
	var elapsed_ms: int = int((Time.get_ticks_usec() - started_usec) / 1000)
	var final_size: int = _assigned_slot_count(slot_indices) if mode == "array" else last_map.size()
	var signature: int = _array_signature(slot_positions, slot_indices, slot_los, slot_slow_radii, guard_sum) if mode == "array" else _map_signature(last_map, guard_sum)
	return {
		"time_ms": elapsed_ms,
		"map_size": final_size,
		"signature": signature
	}

func _spawn_units(count: int) -> Array[Unit]:
	var out: Array[Unit] = []
	for index in range(max(0, count)):
		var id: String = UNIT_IDS[index % UNIT_IDS.size()]
		var unit: Unit = UnitFactory.spawn(id)
		if unit != null:
			out.append(unit)
	return out

func _positions_for(count: int, center: Vector2, side: float) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for index in range(max(0, count)):
		var row: int = index / 4
		var column: int = index % 4
		var x_offset: float = side * float(row) * 70.0
		var y_offset: float = (float(column) - 1.5) * 76.0 + float((index * 19) % 31)
		out.append(center + Vector2(x_offset, y_offset))
	return out

func _target_positions_for(count: int) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for index in range(max(1, count)):
		out.append(Vector2(720.0 + float(index) * 86.0, 330.0 + float((index * 73) % 160)))
	return out

func _targets_for(count: int, target_count: int) -> Array[int]:
	var out: Array[int] = []
	var safe_targets: int = max(1, target_count)
	for index in range(max(0, count)):
		out.append(index % safe_targets)
	return out

func _groups_for(targets: Array[int], target_count: int) -> Dictionary:
	var groups: Dictionary = {}
	for target_index in range(max(1, target_count)):
		groups[target_index] = []
	for attacker_index in range(targets.size()):
		var target: int = int(targets[attacker_index])
		if not groups.has(target):
			groups[target] = []
		(groups[target] as Array).append(attacker_index)
	return groups

func _profiles_for(count: int) -> Array[MovementProfile]:
	var out: Array[MovementProfile] = []
	for index in range(max(0, count)):
		var band_max: float = 1.05 + float(index % 3) * 0.05
		out.append(MovementProfile.new("approach", 0.95, band_max))
	return out

func _previous_slots_for(count: int) -> Dictionary[int, Dictionary]:
	var out: Dictionary[int, Dictionary] = {}
	for index in range(max(0, count)):
		out[index] = {
			"slot": (index * 2) % max(1, count),
			"frames": 1 + (index % 6)
		}
	return out

func _bool_array(count: int, value: bool) -> Array[bool]:
	var out: Array[bool] = []
	for _index in range(max(0, count)):
		out.append(value)
	return out

func _int_array(count: int, value: int) -> Array[int]:
	var out: Array[int] = []
	for _index in range(max(0, count)):
		out.append(value)
	return out

func _float_array(count: int, value: float) -> Array[float]:
	var out: Array[float] = []
	for _index in range(max(0, count)):
		out.append(value)
	return out

func _vector2_array(count: int, value: Vector2) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for _index in range(max(0, count)):
		out.append(value)
	return out

func _nudge_targets(target_positions: Array[Vector2], iteration: int) -> void:
	for index in range(target_positions.size()):
		target_positions[index] = target_positions[index] + Vector2(float((iteration + index) % 3) - 1.0, float((iteration * 2 + index) % 5) - 2.0)

func _map_signature(slot_map: Dictionary, guard_sum: int) -> int:
	var signature: int = _mix(31, guard_sum)
	var keys: Array = slot_map.keys()
	keys.sort()
	for key_value in keys:
		var key: int = int(key_value)
		var slot_data: Dictionary = slot_map[key]
		var position: Vector2 = slot_data.get("position", Vector2.ZERO)
		signature = _mix(signature, key)
		signature = _mix(signature, int(slot_data.get("slot_index", -1)))
		signature = _mix(signature, int(round(position.x * 100.0)))
		signature = _mix(signature, int(round(position.y * 100.0)))
		signature = _mix(signature, int(round(float(slot_data.get("angle", 0.0)) * 10000.0)))
		signature = _mix(signature, int(round(float(slot_data.get("slow_radius", 0.0)) * 100.0)))
	return signature

func _array_signature(slot_positions: Array[Vector2], slot_indices: Array[int], slot_los: Array[bool], slow_radii: Array[float], guard_sum: int) -> int:
	var signature: int = _mix(43, guard_sum)
	for index in range(slot_indices.size()):
		var slot_index: int = int(slot_indices[index])
		if slot_index < 0:
			continue
		var position: Vector2 = slot_positions[index]
		signature = _mix(signature, index)
		signature = _mix(signature, slot_index)
		signature = _mix(signature, 1 if slot_los[index] else 0)
		signature = _mix(signature, int(round(position.x * 100.0)))
		signature = _mix(signature, int(round(position.y * 100.0)))
		signature = _mix(signature, int(round(float(slow_radii[index]) * 100.0)))
	return signature

func _assigned_slot_count(slot_indices: Array[int]) -> int:
	var count: int = 0
	for slot_index in slot_indices:
		if int(slot_index) >= 0:
			count += 1
	return count

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

func _mix(current: int, value: int) -> int:
	return int((current * 1315423911 + value * 2654435761 + 97) & 0x7fffffffffffffff)
