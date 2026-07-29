extends Node

const SlotStrategyScript: Script = preload("res://scripts/game/combat/movement/strategies/slot_strategy.gd")

@export var samples_per_case: int = 3

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var cases: Array[Dictionary] = [
		{"count": 6, "iterations": 180},
		{"count": 12, "iterations": 24},
		{"count": 18, "iterations": 18},
		{"count": 24, "iterations": 12}
	]
	var aggregate_signature: int = 17
	var total_ms: int = 0
	var sample_count: int = max(1, int(samples_per_case))
	for case_data in cases:
		var count: int = int(case_data.get("count", 0))
		var iterations: int = int(case_data.get("iterations", 0))
		var result: Dictionary = _run_case(count, iterations, sample_count)
		total_ms += int(result.get("median_ms", 0))
		aggregate_signature = _mix(aggregate_signature, int(result.get("signature", 0)))
		print("PerfSlotStrategy case=count_", count,
			" iterations=", iterations,
			" samples=", sample_count,
			" median_ms=", int(result.get("median_ms", 0)),
			" p95_ms=", int(result.get("p95_ms", 0)),
			" min_ms=", int(result.get("min_ms", 0)),
			" max_ms=", int(result.get("max_ms", 0)),
			" map_size=", int(result.get("map_size", 0)),
			" signature=", int(result.get("signature", 0)))
	print("PerfSlotStrategy: median_total_ms=", total_ms, " aggregate_sig=", aggregate_signature)
	get_tree().quit(0)

func _run_case(count: int, iterations: int, sample_count: int) -> Dictionary:
	var ms_values: Array[int] = []
	var first_signature: int = 0
	var map_size: int = 0
	for sample_index in range(max(1, sample_count)):
		var sample: Dictionary = _run_case_once(count, iterations)
		ms_values.append(int(sample.get("time_ms", 0)))
		if sample_index == 0:
			first_signature = int(sample.get("signature", 0))
			map_size = int(sample.get("map_size", 0))
		elif int(sample.get("signature", 0)) != first_signature:
			push_error("PerfSlotStrategy: inconsistent signature for count %d sample %d" % [count, sample_index])
	return {
		"median_ms": _percentile_int(ms_values, 0.50),
		"p95_ms": _percentile_int(ms_values, 0.95),
		"min_ms": _min_int(ms_values),
		"max_ms": _max_int(ms_values),
		"map_size": map_size,
		"signature": first_signature
	}

func _run_case_once(count: int, iterations: int) -> Dictionary:
	var target_pos: Vector2 = Vector2(512.0, 384.0)
	var attackers: Array[int] = []
	var attacker_positions: Array[Vector2] = []
	var ranges_world: Dictionary[int, float] = {}
	var previous_slots: Dictionary[int, Dictionary] = {}
	var tile_size: float = 72.0
	for index in range(count):
		attackers.append(index)
		var angle: float = (TAU * float(index) / float(max(1, count))) + (0.071 * float(index % 5))
		var radius: float = 140.0 + float((index * 37) % 90)
		attacker_positions.append(target_pos + Vector2(cos(angle), sin(angle)) * radius)
		ranges_world[index] = 112.0 + float((index * 13) % 48)
		previous_slots[index] = {
			"slot": (index * 3) % max(1, count),
			"frames": 2 + (index % 5)
		}
	var last_map: Dictionary = {}
	var guard_sum: int = 0
	var start_usec: int = Time.get_ticks_usec()
	for iteration in range(iterations):
		last_map = SlotStrategy.assign_for_target(
			"player",
			0,
			target_pos + Vector2(float(iteration % 7), float((iteration * 3) % 11)),
			attackers,
			attacker_positions,
			ranges_world,
			tile_size,
			previous_slots,
			8
		)
		guard_sum += last_map.size()
	var elapsed_ms: int = int((Time.get_ticks_usec() - start_usec) / 1000)
	return {
		"time_ms": elapsed_ms,
		"map_size": last_map.size(),
		"signature": _map_signature(last_map, guard_sum)
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

func _map_signature(slot_map: Dictionary, guard_sum: int) -> int:
	var signature: int = _mix(29, guard_sum)
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

func _mix(current: int, value: int) -> int:
	return int((current * 1315423911 + value * 2654435761 + 97) & 0x7fffffffffffffff)
