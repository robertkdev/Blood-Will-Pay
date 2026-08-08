extends RefCounted
class_name CooldownScheduler

var state: BattleState
var target_controller: TargetController
var buff_system: BuffSystem = null

# Scheduling rules
var process_player_first: bool = true
var alternate_order: bool = false
# Pairs are deprecated; always resolve ordered
# Pairs path removed; always resolve ordered

var max_regen_loops: int = 10
var _next_player_first: bool = true

# Deterministic randomization support (provided by engine RNG)
var rng: RandomNumberGenerator = null

# One-time shuffled iteration order per team (removes index bias)
var _player_order: Array[int] = []
var _enemy_order: Array[int] = []

func configure(_state: BattleState, _target_controller: TargetController, _buff_system: BuffSystem = null) -> void:
	state = _state
	target_controller = _target_controller
	buff_system = _buff_system
	_sync_cooldowns()
	_next_player_first = process_player_first
	_refresh_orders()

func apply_rules(_process_player_first: bool, _alternate_order: bool) -> void:
	process_player_first = _process_player_first
	alternate_order = _alternate_order

func reset_turn() -> void:
	_sync_cooldowns()
	_next_player_first = process_player_first
	_refresh_orders()

func advance(delta: float) -> Dictionary:
	if not state or delta <= 0.0:
		return {"pairs": [], "ordered": [], "regen_ticks": 0}
	_sync_cooldowns()
	var regen_ticks: int = _accumulate_regen(delta)
	var player_events: Array[AttackEvent] = _collect_events("player", state.player_team, state.player_cds, delta)
	var enemy_events: Array[AttackEvent] = _collect_events("enemy", state.enemy_team, state.enemy_cds, delta)
	var result: Dictionary = {"pairs": [], "ordered": [], "regen_ticks": regen_ticks}
	var player_first: bool = _next_player_first
	if alternate_order:
		_next_player_first = not _next_player_first
	else:
		_next_player_first = process_player_first
	var pi: int = 0
	var ei: int = 0
	var ordered: Array[AttackEvent] = []
	while pi < player_events.size() or ei < enemy_events.size():
		if player_first:
			if pi < player_events.size():
				ordered.append(player_events[pi])
				pi += 1
				player_first = false
				continue
			player_first = false
		else:
			if ei < enemy_events.size():
				ordered.append(enemy_events[ei])
				ei += 1
				player_first = true
				continue
			player_first = true
		if pi < player_events.size():
			ordered.append(player_events[pi])
			pi += 1
		if ei < enemy_events.size():
			ordered.append(enemy_events[ei])
			ei += 1
	result["ordered"] = ordered
	return result

func _accumulate_regen(delta: float) -> int:
	var ticks: int = 0
	state.regen_tick_accum += delta
	while state.regen_tick_accum >= 1.0 and ticks < max_regen_loops:
		state.regen_tick_accum -= 1.0
		ticks += 1
	return ticks

func _collect_events(team: String, units: Array[Unit], cds: Array[float], delta: float) -> Array[AttackEvent]:
	var events: Array[AttackEvent] = []
	var order: Array[int] = _order_for(team, units.size())
	for idx in order:
		if idx >= cds.size():
			cds.append(0.0)
		cds[idx] -= delta
		var unit: Unit = units[idx]
		if not unit or not unit.is_alive():
			continue
		# Skip scheduling when stunned; prevent CD backlog
		if buff_system != null and buff_system.is_stunned(unit):
			if cds[idx] < 0.0:
				cds[idx] = 0.0
			continue
		# Disarm prevents basic attacks without blocking movement or ability casts.
		if buff_system != null and buff_system.has_tag(state, team, idx, "disarm"):
			if cds[idx] < 0.0:
				cds[idx] = 0.0
			continue
		var cooldown: float = _compute_cooldown(unit)
		var max_shots: int = clamp(int(ceil(delta / max(0.01, cooldown))) + 2, 1, 100)
		var shots: int = 0
		while cds[idx] <= 0.0 and shots < max_shots:
			var target_idx: int = target_controller.current_target(team, idx)
			if target_idx < 0:
				# No valid target (for example, every living enemy is untargetable).
				# Keep the unit ready and retry on a later frame without spending a shot.
				cds[idx] = 0.0
				break
			var evt: AttackEvent = AttackEvent.new(team, idx, target_idx, 0, false, 0.0)
			cds[idx] += cooldown
			evt.pending_cooldown = cds[idx]
			events.append(evt)
			shots += 1
	return events

func _compute_cooldown(unit: Unit) -> float:
	var atk_speed: float = max(0.01, unit.attack_speed)
	return 1.0 / atk_speed

func _sync_cooldowns() -> void:
	if not state:
		return
	state.player_cds = _resize_float_array_in_place(state.player_cds, state.player_team.size())
	state.enemy_cds = _resize_float_array_in_place(state.enemy_cds, state.enemy_team.size())
	_ensure_order_sizes()

func _resize_float_array_in_place(existing: Array[float], desired: int) -> Array[float]:
	if desired < 0:
		desired = 0
	if existing.size() > desired:
		existing.resize(desired)
	while existing.size() < desired:
		existing.append(0.0)
	return existing

func _order_for(team: String, count: int) -> Array[int]:
	if team == "player":
		if _player_order.size() == count:
			return _player_order
		return _player_order.slice(0, count)
	if _enemy_order.size() == count:
		return _enemy_order
	return _enemy_order.slice(0, count)

func _refresh_orders() -> void:
	var p_size: int = state.player_team.size() if state else 0
	var e_size: int = state.enemy_team.size() if state else 0
	_player_order.clear()
	_enemy_order.clear()
	for i in range(p_size): _player_order.append(i)
	for j in range(e_size): _enemy_order.append(j)
	if rng != null:
		if _player_order.size() > 1:
			for k in range(_player_order.size() - 1, 0, -1):
				var r: int = int(rng.randi() % (k + 1))
				var tmp: int = _player_order[k]
				_player_order[k] = _player_order[r]
				_player_order[r] = tmp
		if _enemy_order.size() > 1:
			for k2 in range(_enemy_order.size() - 1, 0, -1):
				var r2: int = int(rng.randi() % (k2 + 1))
				var tmp2: int = _enemy_order[k2]
				_enemy_order[k2] = _enemy_order[r2]
				_enemy_order[r2] = tmp2

func _ensure_order_sizes() -> void:
	# Append new indices at the end if team sizes grew (e.g., summons)
	var p_size: int = state.player_team.size() if state else 0
	var e_size: int = state.enemy_team.size() if state else 0
	while _player_order.size() < p_size:
		_player_order.append(_player_order.size())
	while _enemy_order.size() < e_size:
		_enemy_order.append(_enemy_order.size())
