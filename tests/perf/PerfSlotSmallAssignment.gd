extends Node

const SlotStrategyScript: Script = preload("res://scripts/game/combat/movement/strategies/slot_strategy.gd")

@export var samples_per_case: int = 3

const INF_COST: float = 1e30
const TAU: float = PI * 2.0

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var cases: Array[Dictionary] = [
		{"label": "fast_2", "kind": "fast", "count": 2, "iterations": 32000, "offset": 0.19},
		{"label": "dp_2", "kind": "dp", "count": 2, "iterations": 32000, "offset": 0.19},
		{"label": "fast_3", "kind": "fast", "count": 3, "iterations": 24000, "offset": 0.31},
		{"label": "dp_3", "kind": "dp", "count": 3, "iterations": 24000, "offset": 0.31},
		{"label": "fast_4", "kind": "fast", "count": 4, "iterations": 16000, "offset": 0.43},
		{"label": "dp_4", "kind": "dp", "count": 4, "iterations": 16000, "offset": 0.43},
		{"label": "fast_5", "kind": "fast", "count": 5, "iterations": 12000, "offset": 0.37},
		{"label": "dp_5", "kind": "dp", "count": 5, "iterations": 12000, "offset": 0.37},
		{"label": "fast_6", "kind": "fast", "count": 6, "iterations": 8000, "offset": 0.29},
		{"label": "dp_6", "kind": "dp", "count": 6, "iterations": 8000, "offset": 0.29}
	]
	var sample_count: int = max(1, int(samples_per_case))
	var aggregate_signature: int = 151
	var median_total_ms: int = 0
	print("PerfSlotSmallAssignment: cases=", cases.size(), " samples_per_case=", sample_count)
	for case_data in cases:
		var result: Dictionary = _run_case(case_data, sample_count)
		median_total_ms += int(result.get("median_ms", 0))
		aggregate_signature = _mix(aggregate_signature, int(result.get("signature", 0)))
		print("PerfSlotSmallAssignment case=", String(case_data.get("label", "")),
			" kind=", String(case_data.get("kind", "")),
			" count=", int(case_data.get("count", 0)),
			" iterations=", int(case_data.get("iterations", 0)),
			" samples=", sample_count,
			" median_ms=", int(result.get("median_ms", 0)),
			" p95_ms=", int(result.get("p95_ms", 0)),
			" min_ms=", int(result.get("min_ms", 0)),
			" max_ms=", int(result.get("max_ms", 0)),
			" signature=", int(result.get("signature", 0)))
	print("PerfSlotSmallAssignment: median_total_ms=", median_total_ms, " aggregate_sig=", aggregate_signature)
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
			push_error("PerfSlotSmallAssignment: inconsistent signature for %s sample %d" % [String(case_data.get("label", "")), sample_index])
	return {
		"median_ms": _percentile_int(ms_values, 0.50),
		"p95_ms": _percentile_int(ms_values, 0.95),
		"min_ms": _min_int(ms_values),
		"max_ms": _max_int(ms_values),
		"signature": first_signature
	}

func _run_case_once(case_data: Dictionary) -> Dictionary:
	var count: int = max(0, int(case_data.get("count", 0)))
	var kind: String = String(case_data.get("kind", "fast"))
	var iterations: int = max(0, int(case_data.get("iterations", 0)))
	var offset: float = float(case_data.get("offset", 0.0))
	var matrices: Array = _cost_matrices(count, offset)
	_verify_fast_matches_dp(matrices)
	var signature: int = 173
	var started_usec: int = Time.get_ticks_usec()
	for iteration in range(iterations):
		var costs: Array = matrices[iteration % matrices.size()]
		var result: Dictionary = {}
		if kind == "dp":
			result = SlotStrategyScript._best_assignment_dp(costs, INF_COST)
		else:
			result = SlotStrategyScript._best_assignment(costs, INF_COST)
		signature = _mix(signature, _result_signature(result))
	var elapsed_ms: int = int((Time.get_ticks_usec() - started_usec) / 1000)
	return {
		"time_ms": elapsed_ms,
		"signature": signature
	}

func _verify_fast_matches_dp(matrices: Array) -> void:
	for costs_value in matrices:
		var costs: Array = costs_value
		var fast_result: Dictionary = SlotStrategyScript._best_assignment(costs, INF_COST)
		var dp_result: Dictionary = SlotStrategyScript._best_assignment_dp(costs, INF_COST)
		if _result_signature(fast_result) != _result_signature(dp_result):
			push_error("PerfSlotSmallAssignment: fast assignment mismatch")

func _cost_matrices(count: int, offset: float) -> Array:
	var matrices: Array = []
	for matrix_index in range(9):
		matrices.append(_cost_matrix(count, offset + float(matrix_index) * 0.017))
	return matrices

func _cost_matrix(count: int, offset: float) -> Array:
	var costs: Array = []
	costs.resize(max(0, count))
	for row in range(max(0, count)):
		var row_costs: Array[float] = []
		row_costs.resize(max(0, count))
		var attacker_angle: float = _wrap_angle(float(row) * 0.617 + offset + float((row * 5) % 7) * 0.053)
		var previous_slot: int = (row + 1) % max(1, count)
		var previous_frames: int = 1 + (row % 3)
		var frame_factor: float = clampf(float(previous_frames) / 6.0, 0.0, 1.0)
		for col in range(max(0, count)):
			var slot_angle: float = _wrap_angle(offset * 0.43 + (float(col) * TAU / max(1.0, float(count))))
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
	var signature: int = _mix(191, int(round(float(result.get("cost", 0.0)) * 100000.0)))
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
