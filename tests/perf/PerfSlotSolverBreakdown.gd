extends Node

const SlotStrategyScript: Script = preload("res://scripts/game/combat/movement/strategies/slot_strategy.gd")

@export var samples_per_case: int = 3

const INF_COST: float = 1e30
const TAU: float = PI * 2.0

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var cases: Array[Dictionary] = [
		{"label": "hungarian_10", "kind": "hungarian", "count": 10, "iterations": 320, "offset": 0.35},
		{"label": "hungarian_11", "kind": "hungarian", "count": 11, "iterations": 280, "offset": 0.38},
		{"label": "hungarian_12", "kind": "hungarian", "count": 12, "iterations": 240, "offset": 0.41},
		{"label": "dp_12_initial", "kind": "dp_initial", "count": 12, "iterations": 90, "offset": 0.29},
		{"label": "dp_12_pruned", "kind": "dp_pruned", "count": 12, "iterations": 160, "offset": 0.41},
		{"label": "rotation_6", "kind": "rotation_eval", "count": 6, "iterations": 160, "offset": 0.17},
		{"label": "rotation_8", "kind": "rotation_eval", "count": 8, "iterations": 80, "offset": 0.23},
		{"label": "rotation_9", "kind": "rotation_eval", "count": 9, "iterations": 60, "offset": 0.25},
		{"label": "rotation_10", "kind": "rotation_eval", "count": 10, "iterations": 50, "offset": 0.27},
		{"label": "rotation_11", "kind": "rotation_eval", "count": 11, "iterations": 40, "offset": 0.31},
		{"label": "rotation_12", "kind": "rotation_eval", "count": 12, "iterations": 30, "offset": 0.29}
	]
	var sample_count: int = max(1, int(samples_per_case))
	var aggregate_signature: int = 113
	var median_total_ms: int = 0
	print("PerfSlotSolverBreakdown: cases=", cases.size(), " samples_per_case=", sample_count)
	for case_data in cases:
		var result: Dictionary = _run_case(case_data, sample_count)
		median_total_ms += int(result.get("median_ms", 0))
		aggregate_signature = _mix(aggregate_signature, int(result.get("signature", 0)))
		print("PerfSlotSolverBreakdown case=", String(case_data.get("label", "")),
			" kind=", String(case_data.get("kind", "")),
			" count=", int(case_data.get("count", 0)),
			" iterations=", int(case_data.get("iterations", 0)),
			" samples=", sample_count,
			" median_ms=", int(result.get("median_ms", 0)),
			" p95_ms=", int(result.get("p95_ms", 0)),
			" min_ms=", int(result.get("min_ms", 0)),
			" max_ms=", int(result.get("max_ms", 0)),
			" signature=", int(result.get("signature", 0)))
	print("PerfSlotSolverBreakdown: median_total_ms=", median_total_ms, " aggregate_sig=", aggregate_signature)
	get_tree().quit(0)

func _run_case(case_data: Dictionary, sample_count: int) -> Dictionary:
	var ms_values: Array[int] = []
	var first_signature: int = 0
	for sample_index in range(max(1, sample_count)):
		var sample: Dictionary = _run_case_once(case_data)
		ms_values.append(int(sample.get("time_ms", 0)))
		var signature: int = int(sample.get("signature", 0))
		if sample_index == 0:
			first_signature = signature
		elif signature != first_signature:
			push_error("PerfSlotSolverBreakdown: inconsistent signature for %s sample %d" % [String(case_data.get("label", "")), sample_index])
	return {
		"median_ms": _percentile_int(ms_values, 0.50),
		"p95_ms": _percentile_int(ms_values, 0.95),
		"min_ms": _min_int(ms_values),
		"max_ms": _max_int(ms_values),
		"signature": first_signature
	}

func _run_case_once(case_data: Dictionary) -> Dictionary:
	var kind: String = String(case_data.get("kind", ""))
	var count: int = max(0, int(case_data.get("count", 0)))
	var iterations: int = max(0, int(case_data.get("iterations", 0)))
	var offset: float = float(case_data.get("offset", 0.0))
	var signature: int = 127
	var started_usec: int = Time.get_ticks_usec()
	for iteration in range(iterations):
		var iter_offset: float = offset + float(iteration % 7) * 0.003
		if kind == "hungarian":
			var costs_hungarian: Array[Variant] = _cost_matrix(count, iter_offset)
			var min_cost: float = SlotStrategyScript._assignment_min_cost_hungarian(costs_hungarian)
			signature = _mix(signature, int(round(min_cost * 100000.0)))
		elif kind == "dp_initial":
			var costs_initial: Array[Variant] = _cost_matrix(count, iter_offset)
			var result_initial: Dictionary = SlotStrategyScript._best_assignment_dp(costs_initial, INF_COST)
			signature = _mix(signature, _result_signature(result_initial))
		elif kind == "dp_pruned":
			var costs_pruned: Array[Variant] = _cost_matrix(count, iter_offset)
			var warmup: Dictionary = SlotStrategyScript._best_assignment_dp(costs_pruned, INF_COST)
			var incumbent_cost: float = max(0.0, float(warmup.get("cost", 0.0)) - 0.0001)
			var result_pruned: Dictionary = SlotStrategyScript._best_assignment_dp(costs_pruned, incumbent_cost)
			signature = _mix(signature, _result_signature(result_pruned))
		elif kind == "rotation_eval":
			var rotation_result: Dictionary = _rotation_eval(count, iter_offset)
			signature = _mix(signature, _result_signature(rotation_result))
	var elapsed_ms: int = int((Time.get_ticks_usec() - started_usec) / 1000)
	return {
		"time_ms": elapsed_ms,
		"signature": signature
	}

func _rotation_eval(count: int, offset: float) -> Dictionary:
	var pairs: Array[Variant] = _pairs_for(count, offset)
	var ring_angles: Array[float] = []
	ring_angles.resize(max(0, count))
	var step: float = TAU / max(1.0, float(count))
	var best_cost: float = INF_COST
	var best_assignment: Array[int] = []
	for base_entry in pairs:
		var base_pair: Array = base_entry
		var base_angle: float = float(base_pair[1])
		for slot_index in range(max(0, count)):
			ring_angles[slot_index] = _wrap_angle(base_angle + step * float(slot_index))
		var assignment_eval: Dictionary = SlotStrategyScript._evaluate_precomputed_assignment(pairs, ring_angles, best_cost)
		var current_cost: float = float(assignment_eval.get("cost", INF_COST))
		if current_cost < best_cost:
			best_cost = current_cost
			best_assignment.clear()
			var assignment_value: Variant = assignment_eval.get("assignment", [])
			if assignment_value is Array:
				var assignment_array: Array = assignment_value
				for value in assignment_array:
					best_assignment.append(int(value))
	return {"assignment": best_assignment, "cost": best_cost}

func _pairs_for(count: int, offset: float) -> Array[Variant]:
	var pairs: Array[Variant] = []
	for row in range(max(0, count)):
		var attacker_angle: float = _wrap_angle(float(row) * 0.517 + offset + float((row * 3) % 5) * 0.071)
		var previous_slot: int = (row * 2 + 3) % max(1, count)
		var previous_frames: int = 1 + (row % 6)
		var frame_factor: float = clampf(float(previous_frames) / 6.0, 0.0, 1.0)
		pairs.append([row, attacker_angle, previous_slot, frame_factor, previous_frames > 0])
	pairs.sort_custom(func(a: Array, b: Array) -> bool: return float(a[1]) < float(b[1]))
	return pairs

func _cost_matrix(count: int, offset: float) -> Array[Variant]:
	var costs: Array[Variant] = []
	costs.resize(max(0, count))
	for row in range(max(0, count)):
		var row_costs: Array[float] = []
		row_costs.resize(max(0, count))
		var attacker_angle: float = _wrap_angle(float(row) * 0.517 + offset + float((row * 3) % 5) * 0.071)
		var previous_slot: int = (row * 2 + 3) % max(1, count)
		var previous_frames: int = 1 + (row % 6)
		var frame_factor: float = clampf(float(previous_frames) / 6.0, 0.0, 1.0)
		for col in range(max(0, count)):
			var slot_angle: float = _wrap_angle(offset * 0.37 + (float(col) * TAU / max(1.0, float(count))))
			var cost: float = abs(attacker_angle - slot_angle)
			if cost > PI:
				cost = TAU - cost
			if previous_slot == col:
				cost = max(0.0, cost - 0.05 * frame_factor)
			elif previous_slot != -1:
				cost += 0.1 * frame_factor
			row_costs[col] = cost
		costs[row] = row_costs
	return costs

func _result_signature(result: Dictionary) -> int:
	var signature: int = _mix(101, int(round(float(result.get("cost", 0.0)) * 100000.0)))
	var assignment_value: Variant = result.get("assignment", [])
	if assignment_value is Array:
		var assignment: Array = assignment_value
		for value in assignment:
			signature = _mix(signature, int(value))
	return signature

func _wrap_angle(value: float) -> float:
	var wrapped: float = fmod(value, TAU)
	if wrapped < 0.0:
		wrapped += TAU
	return wrapped

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
