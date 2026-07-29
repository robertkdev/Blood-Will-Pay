extends Node

const MovementServiceScript: Script = preload("res://scripts/game/combat/movement/movement_service2.gd")
const UnitFactoryScript: Script = preload("res://scripts/unit_factory.gd")

@export var samples_per_case: int = 3

const UNIT_IDS: Array[String] = [
	"bonko", "korath", "sari", "pilfer", "mara", "axiom",
	"brute", "repo", "hexeon", "luna", "nyxa", "morrak"
]
const TAU: float = PI * 2.0

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var cases: Array[Dictionary] = [
		{"label": "slot_step_8v8", "kind": "slot", "count": 8, "other_count": 8, "iterations": 2400},
		{"label": "slot_step_8v8_no_anchor", "kind": "slot", "count": 8, "other_count": 8, "iterations": 2400, "anchors": false},
		{"label": "slot_step_10v10", "kind": "slot", "count": 10, "other_count": 10, "iterations": 1800},
		{"label": "slot_step_10v10_no_anchor", "kind": "slot", "count": 10, "other_count": 10, "iterations": 1800, "anchors": false},
		{"label": "slot_step_12v12", "kind": "slot", "count": 12, "other_count": 12, "iterations": 1400},
		{"label": "slot_step_12v12_no_anchor", "kind": "slot", "count": 12, "other_count": 12, "iterations": 1400, "anchors": false},
		{"label": "arrive_step_8v8", "kind": "arrive", "count": 8, "other_count": 8, "iterations": 3200, "anchors": false},
		{"label": "in_band_8v8", "kind": "in_band", "count": 8, "other_count": 8, "iterations": 2400},
		{"label": "in_band_8v8_no_anchor", "kind": "in_band", "count": 8, "other_count": 8, "iterations": 2400, "anchors": false}
	]
	var sample_count: int = max(1, int(samples_per_case))
	var aggregate_signature: int = 53
	var total_ms: int = 0
	for case_data in cases:
		var result: Dictionary = _run_case(case_data, sample_count)
		total_ms += int(result.get("median_ms", 0))
		aggregate_signature = _mix(aggregate_signature, int(result.get("signature", 0)))
		print("PerfMovementStepHelpers case=", String(case_data.get("label", "")),
			" kind=", String(case_data.get("kind", "")),
			" count=", int(case_data.get("count", 0)),
			" other_count=", int(case_data.get("other_count", 0)),
			" iterations=", int(case_data.get("iterations", 0)),
			" samples=", sample_count,
			" median_ms=", int(result.get("median_ms", 0)),
			" p95_ms=", int(result.get("p95_ms", 0)),
			" min_ms=", int(result.get("min_ms", 0)),
			" max_ms=", int(result.get("max_ms", 0)),
			" signature=", int(result.get("signature", 0)))
	print("PerfMovementStepHelpers: median_total_ms=", total_ms, " aggregate_sig=", aggregate_signature)
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
			push_error("PerfMovementStepHelpers: inconsistent signature for %s sample %d" % [String(case_data.get("label", "")), sample_index])
	return {
		"median_ms": _percentile_int(ms_values, 0.50),
		"p95_ms": _percentile_int(ms_values, 0.95),
		"min_ms": _min_int(ms_values),
		"max_ms": _max_int(ms_values),
		"signature": first_signature
	}

func _run_case_once(case_data: Dictionary) -> Dictionary:
	var count: int = max(0, int(case_data.get("count", 0)))
	var other_count: int = max(0, int(case_data.get("other_count", 0)))
	var iterations: int = max(0, int(case_data.get("iterations", 0)))
	var kind: String = String(case_data.get("kind", "slot"))
	var service: MovementService2 = MovementServiceScript.new()
	var units: Array[Unit] = _spawn_units(count)
	var positions: Array[Vector2] = _positions_for(count, Vector2(360.0, 380.0), -1.0)
	var other_positions: Array[Vector2] = _positions_for(other_count, Vector2(680.0, 376.0), 1.0)
	var alive: Array[bool] = _bool_array(count, true)
	var other_alive: Array[bool] = _bool_array(other_count, true)
	var use_anchors: bool = bool(case_data.get("anchors", true))
	var profiles: Array[MovementProfile] = _profiles_for(count, use_anchors)
	service.configure(96.0, positions, other_positions, Rect2(Vector2(192.0, 96.0), Vector2(768.0, 576.0)))
	service._refresh_inner_bounds()
	var signature: int = 67
	var started_usec: int = Time.get_ticks_usec()
	for iteration in range(iterations):
		var nudge: Vector2 = Vector2(float(iteration % 5) * 0.15, float((iteration * 3) % 7) * 0.12)
		for index in range(count):
			var unit: Unit = units[index]
			var current: Vector2 = positions[index]
			var target: Vector2 = other_positions[index % max(1, other_positions.size())] + nudge
			var step: Vector2 = Vector2.ZERO
			if kind == "in_band":
				step = service._compute_in_band_step(
					"player",
					index,
					current,
					target,
					unit,
					0.08,
					1.0,
					64.0,
					positions,
					other_positions,
					alive,
					other_alive,
					profiles[index])
			else:
				var slot_angle: float = float(index) * TAU / max(1.0, float(count)) + float(iteration % 3) * 0.015
				var slot_pos: Vector2 = target + Vector2(cos(slot_angle), sin(slot_angle)) * 128.0
				if kind == "arrive":
					step = service._compute_arrive_step(
						current,
						slot_pos,
						target,
						unit,
						0.08,
						1.0,
						144.0,
						128.0,
						12.0)
				else:
					step = service._compute_slot_step(
						"player",
						index,
						current,
						slot_pos,
						target,
						unit,
						profiles[index],
						0.08,
						1.0,
						1.0,
						0.45,
						0.35,
						144.0,
						128.0,
						54.0,
						64.0,
						positions,
						other_positions,
						alive,
						other_alive,
						0)
			signature = _mix(signature, int(round(step.x * 1000.0)))
			signature = _mix(signature, int(round(step.y * 1000.0)))
	var elapsed_ms: int = int((Time.get_ticks_usec() - started_usec) / 1000)
	return {
		"time_ms": elapsed_ms,
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

func _profiles_for(count: int, use_anchors: bool = true) -> Array[MovementProfile]:
	var out: Array[MovementProfile] = []
	for index in range(max(0, count)):
		var side_bias: float = -1.0 if (index % 2) == 0 else 1.0
		var anchor_index: int = max(0, index - 1) if use_anchors and (index % 4) == 0 else -1
		var anchor_strength: float = 0.18 if use_anchors and anchor_index >= 0 and anchor_index != index else 0.0
		out.append(MovementProfile.new("approach", 0.90, 1.10, 0.35, 0.25, side_bias, anchor_index, 1.0, 4.0, anchor_strength))
	return out

func _positions_for(count: int, center: Vector2, side: float) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for index in range(max(0, count)):
		var row: int = index / 4
		var column: int = index % 4
		var x_offset: float = side * float(row) * 58.0 + float((index * 13) % 17)
		var y_offset: float = (float(column) - 1.5) * 68.0 + float((index * 19) % 29)
		out.append(center + Vector2(x_offset, y_offset))
	return out

func _bool_array(count: int, value: bool) -> Array[bool]:
	var out: Array[bool] = []
	for _index in range(max(0, count)):
		out.append(value)
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
