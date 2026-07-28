extends Node

const SlotStrategyScript: Script = preload("res://scripts/game/combat/movement/strategies/slot_strategy.gd")
const UnitFactoryScript: Script = preload("res://scripts/unit_factory.gd")

const UNIT_IDS: Array[String] = [
	"bonko", "korath", "sari", "pilfer", "mara", "axiom",
	"brute", "repo", "hexeon", "luna", "nyxa", "morrak"
]

const TILE_SIZE: float = 96.0
const EPSILON: float = 0.001

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	_check_case("single", 1, 1, failures)
	_check_case("single_target_6", 6, 1, failures)
	_check_case("single_target_12", 12, 1, failures)
	_check_case("split_target_12", 12, 3, failures)
	if failures.size() > 0:
		for failure in failures:
			push_error(failure)
		get_tree().quit(1)
		return
	print("SlotArrayAssignmentParityProbe: PASS")
	get_tree().quit(0)

func _check_case(label: String, count: int, target_count: int, failures: Array[String]) -> void:
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
	var slot_map: Dictionary = strategy.assign_slots_for_team(
		"player",
		units,
		positions,
		alive,
		targets,
		target_positions,
		target_alive,
		groups,
		profiles,
		TILE_SIZE,
		0,
		[],
		previous_slots,
		6)
	var out_positions: Array[Vector2] = []
	var out_slot_indices: Array[int] = []
	var out_los_arrive: Array[bool] = []
	var out_slow_radii: Array[float] = []
	var out_corridor_radii: Array[float] = []
	var out_corridor_eps: Array[float] = []
	for _index in range(count):
		out_positions.append(Vector2.ZERO)
		out_slot_indices.append(-1)
		out_los_arrive.append(false)
		out_slow_radii.append(0.0)
		out_corridor_radii.append(0.0)
		out_corridor_eps.append(0.0)
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
		TILE_SIZE,
		out_positions,
		out_slot_indices,
		out_los_arrive,
		out_slow_radii,
		out_corridor_radii,
		out_corridor_eps,
		0,
		[],
		previous_slots,
		6)
	_compare_outputs(label, slot_map, out_positions, out_slot_indices, out_los_arrive, out_slow_radii, out_corridor_radii, out_corridor_eps, failures)

func _compare_outputs(label: String, slot_map: Dictionary, out_positions: Array[Vector2], out_slot_indices: Array[int], out_los_arrive: Array[bool], out_slow_radii: Array[float], out_corridor_radii: Array[float], out_corridor_eps: Array[float], failures: Array[String]) -> void:
	var assigned_count: int = 0
	for slot_index in out_slot_indices:
		if int(slot_index) >= 0:
			assigned_count += 1
	if assigned_count != slot_map.size():
		failures.append("%s assigned count mismatch map=%d arrays=%d" % [label, slot_map.size(), assigned_count])
	var keys: Array = slot_map.keys()
	keys.sort()
	for key_value in keys:
		var key: int = int(key_value)
		if key < 0 or key >= out_slot_indices.size():
			failures.append("%s key outside array bounds key=%d" % [label, key])
			continue
		var slot_value: Variant = slot_map.get(key)
		if not (slot_value is Dictionary):
			failures.append("%s legacy slot data missing key=%d" % [label, key])
			continue
		var slot_data: Dictionary = slot_value
		var expected_position: Vector2 = slot_data.get("position", Vector2.ZERO)
		var expected_index: int = int(slot_data.get("slot_index", -1))
		var expected_mode: String = String(slot_data.get("mode", "ring"))
		var expected_los: bool = expected_mode == "los_arrive"
		_expect(out_slot_indices[key] == expected_index, "%s slot index mismatch key=%d map=%d arrays=%d" % [label, key, expected_index, out_slot_indices[key]], failures)
		_expect(out_los_arrive[key] == expected_los, "%s slot mode mismatch key=%d mode=%s arrays_los=%s" % [label, key, expected_mode, str(out_los_arrive[key])], failures)
		_expect(out_positions[key].distance_to(expected_position) <= EPSILON, "%s position mismatch key=%d map=%s arrays=%s" % [label, key, str(expected_position), str(out_positions[key])], failures)
		_expect(absf(out_slow_radii[key] - float(slot_data.get("slow_radius", 0.0))) <= EPSILON, "%s slow radius mismatch key=%d" % [label, key], failures)
		_expect(absf(out_corridor_radii[key] - float(slot_data.get("corridor_radius", 0.0))) <= EPSILON, "%s corridor radius mismatch key=%d" % [label, key], failures)
		_expect(absf(out_corridor_eps[key] - float(slot_data.get("corridor_eps", 0.0))) <= EPSILON, "%s corridor eps mismatch key=%d" % [label, key], failures)

func _spawn_units(count: int) -> Array[Unit]:
	var out: Array[Unit] = []
	for index in range(max(0, count)):
		var id: String = UNIT_IDS[index % UNIT_IDS.size()]
		var unit: Unit = UnitFactoryScript.spawn(id)
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

func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
