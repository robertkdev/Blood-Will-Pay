extends RefCounted
class_name MovementState

# MovementState
# Holds world-space movement data with no Node/UI coupling.
# - Positions for player/enemy units (Vector2 world coords)
# - Arena bounds (Rect2 world coords)
# - Tile size (pixels per tile)
# - Minimal per-unit memory arrays reserved for future strategies

var tile_size_px: float = 72.0
var arena_bounds: Rect2 = Rect2()
var player_positions: Array[Vector2] = []
var enemy_positions: Array[Vector2] = []

# Optional per-unit memory (example: last target id); not used in approach-only
var player_last_target: Array[int] = []
var enemy_last_target: Array[int] = []

# Slot assignment memory (for hysteresis)
var player_slot_id: Array[int] = []
var enemy_slot_id: Array[int] = []
var player_slot_timer: Array[int] = []
var enemy_slot_timer: Array[int] = []

var debug_log_frames: int = 0

func configure(config_tile_size: float, player_pos: Array[Vector2], enemy_pos: Array[Vector2], bounds: Rect2) -> void:
	tile_size_px = config_tile_size
	arena_bounds = Rect2(bounds.position, bounds.size)
	player_positions = player_pos.duplicate()
	enemy_positions = enemy_pos.duplicate()
	player_last_target = _resize_int_array(player_last_target, player_positions.size())
	enemy_last_target = _resize_int_array(enemy_last_target, enemy_positions.size())
	player_slot_id = _resize_int_array(player_slot_id, player_positions.size())
	enemy_slot_id = _resize_int_array(enemy_slot_id, enemy_positions.size())
	player_slot_timer = _resize_int_array(player_slot_timer, player_positions.size(), true)
	enemy_slot_timer = _resize_int_array(enemy_slot_timer, enemy_positions.size(), true)

func set_bounds(bounds: Rect2) -> void:
	arena_bounds = Rect2(bounds.position, bounds.size)

func ensure_capacity(player_count: int, enemy_count: int) -> void:
	var fill: Vector2 = _default_position()
	_resize_vector_array(player_positions, player_count, fill)
	_resize_vector_array(enemy_positions, enemy_count, fill)
	player_last_target = _resize_int_array(player_last_target, player_count)
	enemy_last_target = _resize_int_array(enemy_last_target, enemy_count)
	player_slot_id = _resize_int_array(player_slot_id, player_count)
	enemy_slot_id = _resize_int_array(enemy_slot_id, enemy_count)
	player_slot_timer = _resize_int_array(player_slot_timer, player_count, true)
	enemy_slot_timer = _resize_int_array(enemy_slot_timer, enemy_count, true)

func set_debug_log_frames(n: int) -> void:
	debug_log_frames = max(0, int(n))

func player_positions_copy() -> Array[Vector2]:
	return player_positions.duplicate()

func enemy_positions_copy() -> Array[Vector2]:
	return enemy_positions.duplicate()

func player_positions_current() -> Array[Vector2]:
	return player_positions

func enemy_positions_current() -> Array[Vector2]:
	return enemy_positions

func copy_all_positions_to(out: Array[Vector2]) -> void:
	var total: int = player_positions.size() + enemy_positions.size()
	out.resize(total)
	var write_index: int = 0
	for player_position: Vector2 in player_positions:
		out[write_index] = player_position
		write_index += 1
	for enemy_position: Vector2 in enemy_positions:
		out[write_index] = enemy_position
		write_index += 1

func positions_changed_from(previous: Array[Vector2], threshold: float) -> bool:
	var total: int = player_positions.size() + enemy_positions.size()
	if previous.size() != total:
		return true
	var threshold_abs: float = max(0.0, threshold)
	var threshold_sq: float = threshold_abs * threshold_abs
	var read_index: int = 0
	for player_position: Vector2 in player_positions:
		if player_position.distance_squared_to(previous[read_index]) > threshold_sq:
			return true
		read_index += 1
	for enemy_position: Vector2 in enemy_positions:
		if enemy_position.distance_squared_to(previous[read_index]) > threshold_sq:
			return true
		read_index += 1
	return false

func get_player_position(idx: int) -> Vector2:
	if idx < 0 or idx >= player_positions.size():
		return _default_position()
	return player_positions[idx]

func get_enemy_position(idx: int) -> Vector2:
	if idx < 0 or idx >= enemy_positions.size():
		return _default_position()
	return enemy_positions[idx]

func bounds_copy() -> Rect2:
	return Rect2(arena_bounds.position, arena_bounds.size)

func tile_size() -> float:
	return tile_size_px

func _resize_vector_array(arr: Array[Vector2], length: int, fill: Vector2) -> void:
	if length < 0:
		length = 0
	var current: int = arr.size()
	if current < length:
		for _i in range(length - current):
			arr.append(fill)
	elif current > length:
		arr.resize(length)

func _resize_int_array(existing: Array[int], desired: int, zero_fill: bool = false) -> Array[int]:
	if desired < 0:
		desired = 0
	var fill_value: int = 0 if zero_fill else -1
	var current: int = existing.size()
	if current < desired:
		for _i in range(desired - current):
			existing.append(fill_value)
	elif current > desired:
		existing.resize(desired)
	return existing

func _default_position() -> Vector2:
	return arena_bounds.position + arena_bounds.size * 0.5

func tick_slot_memory() -> void:
	for i in range(player_slot_timer.size()):
		if player_slot_timer[i] > 0:
			player_slot_timer[i] -= 1
	for j in range(enemy_slot_timer.size()):
		if enemy_slot_timer[j] > 0:
			enemy_slot_timer[j] -= 1

func get_slot_id(team: String, idx: int) -> int:
	if team == "player":
		return (player_slot_id[idx] if idx >= 0 and idx < player_slot_id.size() else -1)
	return (enemy_slot_id[idx] if idx >= 0 and idx < enemy_slot_id.size() else -1)

func get_slot_timer(team: String, idx: int) -> int:
	if team == "player":
		return (player_slot_timer[idx] if idx >= 0 and idx < player_slot_timer.size() else 0)
	return (enemy_slot_timer[idx] if idx >= 0 and idx < enemy_slot_timer.size() else 0)

func set_slot_memory(team: String, idx: int, slot_id_value: int, frames: int) -> void:
	if idx < 0:
		return
	if team == "player":
		if idx >= player_slot_id.size():
			return
		player_slot_id[idx] = slot_id_value
		player_slot_timer[idx] = max(0, frames)
	else:
		if idx >= enemy_slot_id.size():
			return
		enemy_slot_id[idx] = slot_id_value
		enemy_slot_timer[idx] = max(0, frames)
