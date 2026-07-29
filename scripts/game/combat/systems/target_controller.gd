extends RefCounted
class_name TargetController

signal target_start(team: String, index: int, target_team: String, target_index: int)
signal target_end(team: String, index: int, target_team: String, target_index: int)

const Targeting := preload("res://scripts/game/combat/targeting.gd")

var state: BattleState
var selector: Callable = Callable()
var _arena_resolver: Callable
var _resolving_player: Array[bool] = []
var _resolving_enemy: Array[bool] = []

func _init() -> void:
	_arena_resolver = Callable(self, "_resolve_for_arena")

func configure(_state: BattleState, _selector: Callable = Callable()) -> void:
	state = _state
	selector = _selector if _selector.is_valid() else Callable()
	_sync_arrays()
	_prime_targets()

func current_target(team: String, shooter_index: int) -> int:
	_sync_arrays()
	if shooter_index < 0:
		return -1
	var targets: Array[int] = _targets_for(team)
	if shooter_index >= targets.size():
		return -1
	var resolving: Array[bool] = _resolving_for(team)
	if bool(resolving[shooter_index]):
		return _safe_target(team, shooter_index, targets)
	resolving[shooter_index] = true
	var result: int = _current_target_impl(team, shooter_index, targets)
	resolving[shooter_index] = false
	return result

func _current_target_impl(team: String, shooter_index: int, targets: Array[int]) -> int:
	var idx: int = int(targets[shooter_index])
	if _is_target_alive(team, idx):
		return idx
	return refresh_target(team, shooter_index)

func _safe_target(team: String, shooter_index: int, targets: Array[int]) -> int:
	var idx: int = (int(targets[shooter_index]) if shooter_index < targets.size() else -1)
	var enemy_team: Array[Unit] = _enemy_team_for(team)
	if BattleState.is_target_alive(enemy_team, idx):
		return idx
	return Targeting.pick_first_alive(enemy_team)

func refresh_target(team: String, shooter_index: int) -> int:
	_sync_arrays()
	if shooter_index < 0:
		return -1
	var targets: Array[int] = _targets_for(team)
	if shooter_index >= targets.size():
		return -1
	var previous: int = int(targets[shooter_index])
	var selection: int = _select_target(team, shooter_index)
	if previous == selection:
		return selection
	targets[shooter_index] = selection
	if previous >= 0:
		_emit_target_end(team, shooter_index, previous)
	if selection >= 0:
		_emit_target_start(team, shooter_index, selection)
	return selection

func resolver_for_arena() -> Callable:
	return _arena_resolver

func target_array(team: String) -> Array[int]:
	_sync_arrays()
	return _targets_for(team)

func copy_arena_targets(player_out: Array[int], enemy_out: Array[int]) -> void:
	if not state:
		player_out.clear()
		enemy_out.clear()
		return
	_sync_arrays()
	var player_count: int = state.player_team.size()
	var enemy_count: int = state.enemy_team.size()
	player_out.resize(player_count)
	enemy_out.resize(enemy_count)
	for i in range(player_count):
		var player_unit: Unit = state.player_team[i]
		if player_unit == null or not player_unit.is_alive():
			player_out[i] = -1
			continue
		var player_target: int = int(state.player_targets[i])
		if BattleState.is_target_alive(state.enemy_team, player_target):
			player_out[i] = player_target
		else:
			player_out[i] = current_target("player", i)
	for j in range(enemy_count):
		var enemy_unit: Unit = state.enemy_team[j]
		if enemy_unit == null or not enemy_unit.is_alive():
			enemy_out[j] = -1
			continue
		var enemy_target: int = int(state.enemy_targets[j])
		if BattleState.is_target_alive(state.player_team, enemy_target):
			enemy_out[j] = enemy_target
		else:
			enemy_out[j] = current_target("enemy", j)

# Public: re-select targets for all units on both teams.
# Useful to reprime after arena positions become available.
func prime_targets() -> void:
	_prime_targets()

# Public: periodically re-score live targets. This lets smarter selectors react
# to backline access, low-health enemies, and peel threats without per-frame AI.
func refresh_live_targets() -> void:
	if not state:
		return
	_sync_arrays()
	for i in range(state.player_team.size()):
		var player_unit: Unit = state.player_team[i]
		if player_unit != null and player_unit.is_alive():
			refresh_target("player", i)
	for j in range(state.enemy_team.size()):
		var enemy_unit: Unit = state.enemy_team[j]
		if enemy_unit != null and enemy_unit.is_alive():
			refresh_target("enemy", j)

func _resolve_for_arena(team: String, shooter_index: int) -> int:
	if not state or shooter_index < 0:
		return -1
	var targets: Array[int] = _targets_for(team)
	if shooter_index >= targets.size():
		return current_target(team, shooter_index)
	var idx: int = int(targets[shooter_index])
	if _is_target_alive(team, idx):
		return idx
	return current_target(team, shooter_index)

func _sync_arrays() -> void:
	if not state:
		return
	var player_size: int = state.player_team.size()
	var enemy_size: int = state.enemy_team.size()
	if state.player_targets.size() != player_size:
		state.player_targets = _resize_targets_in_place(state.player_targets, player_size)
	if state.enemy_targets.size() != enemy_size:
		state.enemy_targets = _resize_targets_in_place(state.enemy_targets, enemy_size)
	if _resolving_player.size() != player_size:
		_resolving_player = _resize_resolving_in_place(_resolving_player, player_size)
	if _resolving_enemy.size() != enemy_size:
		_resolving_enemy = _resize_resolving_in_place(_resolving_enemy, enemy_size)

func _targets_for(team: String) -> Array[int]:
	return state.player_targets if team == "player" else state.enemy_targets

func _resolving_for(team: String) -> Array[bool]:
	return _resolving_player if team == "player" else _resolving_enemy

func _enemy_team_for(team: String) -> Array[Unit]:
	return state.enemy_team if team == "player" else state.player_team

func _enemy_team_name(team: String) -> String:
	return "enemy" if team == "player" else "player"

func _emit_target_start(team: String, shooter_index: int, target_index: int) -> void:
	emit_signal("target_start", team, shooter_index, _enemy_team_name(team), target_index)

func _emit_target_end(team: String, shooter_index: int, target_index: int) -> void:
	emit_signal("target_end", team, shooter_index, _enemy_team_name(team), target_index)

func _is_target_alive(team: String, idx: int) -> bool:
	var enemy_team: Array[Unit] = _enemy_team_for(team)
	return BattleState.is_target_alive(enemy_team, idx)

func _select_target(team: String, shooter_index: int) -> int:
	var enemy_team: Array[Unit] = _enemy_team_for(team)
	var enemy_team_name: String = _enemy_team_name(team)
	if selector.is_valid():
		var result: Variant = selector.call(team, shooter_index, enemy_team_name)
		if typeof(result) == TYPE_INT:
			var idx: int = int(result)
			if BattleState.is_target_alive(enemy_team, idx):
				return idx
	return Targeting.pick_first_alive(enemy_team)

func _prime_targets() -> void:
	if not state:
		return
	for i in range(state.player_team.size()):
		refresh_target("player", i)
	for j in range(state.enemy_team.size()):
		refresh_target("enemy", j)

func _resize_targets_in_place(existing: Array[int], desired: int) -> Array[int]:
	if desired < 0:
		desired = 0
	if existing.size() > desired:
		existing.resize(desired)
	while existing.size() < desired:
		existing.append(-1)
	return existing

func _resize_resolving_in_place(existing: Array[bool], desired: int) -> Array[bool]:
	if desired < 0:
		desired = 0
	if existing.size() > desired:
		existing.resize(desired)
	while existing.size() < desired:
		existing.append(false)
	return existing
