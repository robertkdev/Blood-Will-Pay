extends Node

const TargetingScript: Script = preload("res://scripts/game/combat/targeting.gd")
const UnitFactoryScript: Script = preload("res://scripts/unit_factory.gd")

@export var iterations: int = 180
@export var samples_per_case: int = 3

const TEAM_A_IDS: Array[String] = [
	"bonko", "korath", "sari", "pilfer", "mara", "axiom",
	"brute", "repo", "hexeon", "luna", "nyxa", "morrak"
]

const TEAM_B_IDS: Array[String] = [
	"repo", "bo", "sari", "pilfer", "mara", "knoll",
	"korath", "brute", "hexeon", "luna", "nyxa", "morrak"
]

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var sample_count: int = max(1, int(samples_per_case))
	var ms_values: Array[int] = []
	var first_signature: int = 0
	for sample_index in range(sample_count):
		var sample: Dictionary = _run_sample()
		ms_values.append(int(sample.get("time_ms", 0)))
		var signature: int = int(sample.get("signature", 0))
		if sample_index == 0:
			first_signature = signature
		elif signature != first_signature:
			push_error("PerfTargeting: inconsistent signature for sample %d" % sample_index)
	print("PerfTargeting: iterations=", max(0, iterations),
		" samples=", sample_count,
		" median_ms=", _percentile_int(ms_values, 0.50),
		" p95_ms=", _percentile_int(ms_values, 0.95),
		" min_ms=", _min_int(ms_values),
		" max_ms=", _max_int(ms_values),
		" signature=", first_signature)
	get_tree().quit(0)

func _run_sample() -> Dictionary:
	var team_a: Array[Unit] = _spawn_units(TEAM_A_IDS)
	var team_b: Array[Unit] = _spawn_units(TEAM_B_IDS)
	var positions_a: Array[Vector2] = _positions_for(team_a.size(), Vector2(280.0, 380.0), -1.0)
	var positions_b: Array[Vector2] = _positions_for(team_b.size(), Vector2(720.0, 380.0), 1.0)
	var current_a: Array[int] = _initial_targets(team_a.size(), team_b.size(), 2)
	var current_b: Array[int] = _initial_targets(team_b.size(), team_a.size(), 5)
	var guard_sum: int = 0
	var started_usec: int = Time.get_ticks_usec()
	for iteration in range(max(0, iterations)):
		for a_index in range(team_a.size()):
			var selected_a: int = Targeting.pick_by_priority(
				team_a[a_index],
				positions_a[a_index],
				team_a,
				positions_a,
				team_b,
				positions_b,
				current_a[a_index],
				96.0)
			current_a[a_index] = selected_a
			guard_sum = _mix(guard_sum, selected_a + 17 + iteration)
		for b_index in range(team_b.size()):
			var selected_b: int = Targeting.pick_by_priority(
				team_b[b_index],
				positions_b[b_index],
				team_b,
				positions_b,
				team_a,
				positions_a,
				current_b[b_index],
				96.0)
			current_b[b_index] = selected_b
			guard_sum = _mix(guard_sum, selected_b + 31 + iteration)
	var elapsed_ms: int = int((Time.get_ticks_usec() - started_usec) / 1000)
	return {
		"time_ms": elapsed_ms,
		"signature": _signature_for(current_a, current_b, guard_sum)
	}

func _spawn_units(ids: Array[String]) -> Array[Unit]:
	var out: Array[Unit] = []
	for id in ids:
		var unit: Unit = UnitFactory.spawn(String(id))
		if unit != null:
			out.append(unit)
	return out

func _positions_for(count: int, center: Vector2, side: float) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for index in range(max(0, count)):
		var row: int = index / 4
		var column: int = index % 4
		var x_offset: float = side * float(row) * 68.0
		var y_offset: float = (float(column) - 1.5) * 74.0 + float((index * 17) % 23)
		out.append(center + Vector2(x_offset, y_offset))
	return out

func _initial_targets(count: int, target_count: int, offset: int) -> Array[int]:
	var out: Array[int] = []
	for index in range(max(0, count)):
		out.append((index + offset) % max(1, target_count))
	return out

func _signature_for(current_a: Array[int], current_b: Array[int], guard_sum: int) -> int:
	var signature: int = _mix(41, guard_sum)
	for value in current_a:
		signature = _mix(signature, int(value))
	for value_b in current_b:
		signature = _mix(signature, int(value_b))
	return signature

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
