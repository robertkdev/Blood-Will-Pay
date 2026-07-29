extends Node

const SlotStrategyScript: Script = preload("res://scripts/game/combat/movement/strategies/slot_strategy.gd")

@export var samples_per_case: int = 3

const INF_COST: float = 1e30
const TAU: float = PI * 2.0

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var cases: Array[Dictionary] = [
		{"label": "dp_6_initial", "count": 6, "iterations": 2400, "offset": 0.23, "bound": "initial"},
		{"label": "dp_6_pruned", "count": 6, "iterations": 2400, "offset": 0.31, "bound": "pruned"},
		{"label": "dp_7_initial", "count": 7, "iterations": 1200, "offset": 0.19, "bound": "initial"},
		{"label": "dp_7_pruned", "count": 7, "iterations": 1200, "offset": 0.27, "bound": "pruned"},
		{"label": "dp_9_initial", "count": 9, "iterations": 320, "offset": 0.25, "bound": "initial"},
		{"label": "dp_9_pruned", "count": 9, "iterations": 320, "offset": 0.35, "bound": "pruned"},
		{"label": "dp_10_initial", "count": 10, "iterations": 160, "offset": 0.17, "bound": "initial"},
		{"label": "dp_10_pruned", "count": 10, "iterations": 160, "offset": 0.23, "bound": "pruned"},
		{"label": "dp_11_initial", "count": 11, "iterations": 120, "offset": 0.27, "bound": "initial"},
		{"label": "dp_11_pruned", "count": 11, "iterations": 120, "offset": 0.33, "bound": "pruned"},
		{"label": "dp_12_initial", "count": 12, "iterations": 90, "offset": 0.29, "bound": "initial"},
		{"label": "dp_12_pruned", "count": 12, "iterations": 160, "offset": 0.41, "bound": "pruned"}
	]
	var sample_count: int = max(1, int(samples_per_case))
	var aggregate_signature: int = 71
	var median_total_ms: int = 0
	for case_data in cases:
		var result: Dictionary = _run_case(case_data, sample_count)
		median_total_ms += int(result.get("median_ms", 0))
		aggregate_signature = _mix(aggregate_signature, int(result.get("signature", 0)))
		print("PerfSlotDpSearch case=", String(case_data.get("label", "")),
			" count=", int(case_data.get("count", 0)),
			" iterations=", int(case_data.get("iterations", 0)),
			" samples=", sample_count,
			" median_ms=", int(result.get("median_ms", 0)),
			" p95_ms=", int(result.get("p95_ms", 0)),
			" min_ms=", int(result.get("min_ms", 0)),
			" max_ms=", int(result.get("max_ms", 0)),
			" signature=", int(result.get("signature", 0)))
	print("PerfSlotDpSearch: median_total_ms=", median_total_ms, " aggregate_sig=", aggregate_signature)
	get_tree().quit(0)

func _run_case(case_data: Dictionary, sample_count: int) -> Dictionary:
	var ms_values: Array[int] = []
	var first_signature: int = 0
	for sample_index in range(sample_count):
		var sample: Dictionary = _run_case_once(case_data)
		ms_values.append(int(sample.get("time_ms", 0)))
		var signature: int = int(sample.get("signature", 0))
		if sample_index == 0:
			first_signature = signature
		elif signature != first_signature:
			push_error("PerfSlotDpSearch: inconsistent signature for %s sample %d" % [String(case_data.get("label", "")), sample_index])
	return {
		"median_ms": _percentile_int(ms_values, 0.50),
		"p95_ms": _percentile_int(ms_values, 0.95),
		"min_ms": _min_int(ms_values),
		"max_ms": _max_int(ms_values),
		"signature": first_signature
	}

func _run_case_once(case_data: Dictionary) -> Dictionary:
	var count: int = int(case_data.get("count", 0))
	var iterations: int = max(0, int(case_data.get("iterations", 0)))
	var offset: float = float(case_data.get("offset", 0.0))
	var costs: Array = _cost_matrix(count, offset)
	var bound_mode: String = String(case_data.get("bound", "initial"))
	var incumbent_cost: float = INF_COST
	if bound_mode == "pruned":
		var warmup: Dictionary = SlotStrategyScript._best_assignment_dp(costs, INF_COST)
		incumbent_cost = max(0.0, float(warmup.get("cost", 0.0)) - 0.0001)
	var guard_signature: int = 97
	var started_usec: int = Time.get_ticks_usec()
	for iteration in range(iterations):
		var iter_offset: float = offset + float(iteration % 7) * 0.003
		var iter_costs: Array = costs if (iteration % 2) == 0 else _cost_matrix(count, iter_offset)
		var result: Dictionary = SlotStrategyScript._best_assignment_dp(iter_costs, incumbent_cost)
		guard_signature = _mix(guard_signature, _result_signature(result))
	var elapsed_ms: int = int((Time.get_ticks_usec() - started_usec) / 1000)
	return {
		"time_ms": elapsed_ms,
		"signature": guard_signature
	}

func _cost_matrix(count: int, offset: float) -> Array:
	var costs: Array = []
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
