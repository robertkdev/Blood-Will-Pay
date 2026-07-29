extends RefCounted
class_name MovementService

# Thin adapter that delegates to MovementService2 (the full implementation)
# so any code referencing MovementService gets the corrected behavior.

const MovementService2 := preload("res://scripts/game/combat/movement/movement_service2.gd")
const MovementProfile := preload("res://scripts/game/combat/movement/movement_profile.gd")

var _impl: MovementService2 = MovementService2.new()

# Expose tuning/data via pass-throughs for callers that introspect
var tuning: set = _set_tuning, get = _get_tuning
var data: set = _set_data, get = _get_data

func _set_tuning(v):
	_impl.tuning = v

func _get_tuning():
	return _impl.tuning

func _set_data(v):
	_impl.data = v

func _get_data():
	return _impl.data

func configure(tile_size: float, player_pos: Array, enemy_pos: Array, bounds: Rect2) -> void:
	_impl.configure(tile_size, player_pos, enemy_pos, bounds)

func set_bounds(bounds: Rect2) -> void:
	_impl.set_bounds(bounds)

func set_buff_system(buff_system) -> void:
	_impl.set_buff_system(buff_system)

func set_profiles(team: String, arr: Array) -> void:
	_impl.set_profiles(team, arr)

func get_profile(team: String, idx: int) -> MovementProfile:
	return _impl.get_profile(team, idx)

func notify_forced_movement(team: String, idx: int, vec: Vector2, dur: float) -> void:
	_impl.notify_forced_movement(team, idx, vec, dur)

func set_debug_log_frames(n: int) -> void:
	_impl.set_debug_log_frames(n)

func set_debug_watch(team: String, indices: Array) -> void:
	_impl.set_debug_watch(team, indices)

func enable_movement_debug(frames: int, watch_players: Array = [], watch_enemies: Array = []) -> void:
	set_debug_log_frames(frames)
	if watch_players.size() > 0:
		set_debug_watch("player", watch_players)
	if watch_enemies.size() > 0:
		set_debug_watch("enemy", watch_enemies)

func ensure_capacity(player_count: int, enemy_count: int) -> void:
	_impl.ensure_capacity(player_count, enemy_count)

func player_positions_copy() -> Array:
	return _impl.player_positions_copy()

func enemy_positions_copy() -> Array:
	return _impl.enemy_positions_copy()

func player_positions_current() -> Array[Vector2]:
	return _impl.player_positions_current()

func enemy_positions_current() -> Array[Vector2]:
	return _impl.enemy_positions_current()

func copy_all_positions_to(out: Array[Vector2]) -> void:
	_impl.copy_all_positions_to(out)

func positions_changed_from(previous: Array[Vector2], threshold: float) -> bool:
	return _impl.positions_changed_from(previous, threshold)

func get_player_position(idx: int) -> Vector2:
	return _impl.get_player_position(idx)

func get_enemy_position(idx: int) -> Vector2:
	return _impl.get_enemy_position(idx)

func bounds_copy() -> Rect2:
	return _impl.bounds_copy()

func tile_size() -> float:
	return _impl.tile_size()

func update_movement(state, delta: float, target_resolver: Callable) -> void:
	_impl.update_movement(state, delta, target_resolver)

func update_movement_with_targets(state, delta: float, player_targets: Array[int], enemy_targets: Array[int]) -> void:
	_impl.update_movement_with_targets(state, delta, player_targets, enemy_targets)

func update(delta: float, state, target_resolver: Callable) -> void:
	_impl.update(delta, state, target_resolver)
