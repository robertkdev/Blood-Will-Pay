extends RefCounted
class_name CombatEngine
const Trace := preload("res://scripts/util/trace.gd")
const AbilitySystemLib := preload("res://scripts/game/abilities/ability_system.gd")
const BuffSystemLib := preload("res://scripts/game/abilities/buff_system.gd")
# Use a minimal service to allow loading while iterating on movement.
const MovementServiceLib := preload("res://scripts/game/combat/movement/movement_service2.gd")
const MovementProfileLib := preload("res://scripts/game/combat/movement/movement_profile.gd")
const Targeting := preload("res://scripts/game/combat/targeting.gd")
const EncounterEscalationRuntimeLib := preload("res://scripts/game/combat/encounter_escalation_runtime.gd")
const ContractBattleRuntimeLib := preload("res://scripts/game/combat/contract_battle_runtime.gd")
const UnitUpgradeRuntimeLib := preload("res://scripts/game/combat/unit_upgrade_runtime.gd")

signal projectile_fired(source_team: String, source_index: int, target_index: int, damage: int, crit: bool)
signal stats_updated(player, enemy)
signal team_stats_updated(player_team, enemy_team)
signal unit_stat_changed(team: String, index: int, fields: Dictionary)
signal log_line(text: String)
signal victory(stage: int)
signal defeat(stage: int)
signal tie(stage: int)
signal vfx_knockup(team: String, index: int, duration: float)
signal vfx_beam_line(start: Vector2, end: Vector2, color: Color, width: float, duration: float)
signal position_updated(team: String, index: int, x: float, y: float)
signal target_start(source_team: String, source_index: int, target_team: String, target_index: int)
signal target_end(source_team: String, source_index: int, target_team: String, target_index: int)
signal ability_cast(source_team: String, source_index: int, target_team: String, target_index: int, position: Vector2)
signal ability_committed(source_team: String, source_index: int, ability_id: String, target_team: String, target_index: int, position: Vector2, cooldown_s: float, commitment_kind: String)
signal encounter_escalated(phase_id: String, label: String, champion_index: int, revived_indices: Array[int], affected_player_indices: Array[int], pulse_damage: int, intensity: int)
signal contract_battle_event(event_type: String, label: String, affected_player_indices: Array[int], affected_enemy_indices: Array[int], value: int, intensity: int)
signal unit_upgrade_event(event_type: String, label: String, affected_player_indices: Array[int], value: int, intensity: int)

const POSITION_EMIT_INTERVAL: float = 0.1
var position_emit_interval_override: float = -1.0
var emit_position_telemetry: bool = true
var emit_target_telemetry: bool = true
var target_recheck_interval_s: float = 0.35
var _target_recheck_accum: float = 0.0

# Emitted after damage is applied (single or paired)
# Provides detailed data for deterministic logging/analytics.
signal hit_applied(source_team: String, source_index: int, target_index: int, rolled_damage: int, dealt_damage: int, crit: bool, before_hp: int, after_hp: int, player_cd: float, enemy_cd: float)

# New analytics signals
signal heal_applied(source_team: String, source_index: int, target_team: String, target_index: int, healed: int, overheal: int, before_hp: int, after_hp: int)
signal shield_absorbed(target_team: String, target_index: int, absorbed: int)
signal hit_mitigated(source_team: String, source_index: int, target_team: String, target_index: int, pre_mit: int, post_pre_shield: int)
signal hit_overkill(source_team: String, source_index: int, target_team: String, target_index: int, overkill: int)
signal hit_components(source_team: String, source_index: int, target_team: String, target_index: int, phys: int, mag: int, tru: int)
signal amp_output_applied(source_team: String, source_index: int, beneficiary_team: String, beneficiary_index: int, target_team: String, target_index: int, amount: float, amp_pct: float, kind: String)
signal damage_redirected(source_team: String, source_index: int, original_target_team: String, original_target_index: int, redirect_team: String, redirect_index: int, amount: int, kind: String)
signal redirect_semantic_applied(source_team: String, source_index: int, target_team: String, target_index: int, kind: String, duration_s: float, amount: float, risk_s: float)
signal cc_applied(source_team: String, source_index: int, target_team: String, target_index: int, kind: String, duration: float)
signal buff_applied(source_team: String, source_index: int, target_team: String, target_index: int, kind: String, fields: Dictionary, magnitude: float, duration: float)
signal debuff_applied(source_team: String, source_index: int, target_team: String, target_index: int, kind: String, fields: Dictionary, magnitude: float, duration: float)
signal on_hit_proc(source_team: String, source_index: int, target_team: String, target_index: int, kind: String, fields: Dictionary, magnitude: float)
signal dot_tick_applied(source_team: String, source_index: int, target_team: String, target_index: int, amount: int, kind: String)
signal execute_bonus_applied(source_team: String, source_index: int, target_team: String, target_index: int, base_damage: int, bonus_damage: int, threshold_pct: float, target_hp_pct: float, kind: String)
signal reset_triggered(source_team: String, source_index: int, target_team: String, target_index: int, kind: String, chain_index: int, time_since_previous_s: float, power_scale: float)
signal ramp_state_changed(source_team: String, source_index: int, kind: String, stacks: int, value: float, peak_stacks: int, duration_s: float, reason: String)
signal targetability_window(team: String, index: int, is_targetable: bool, duration: float, reason: String)
signal targetability_threat_interaction(source_team: String, source_index: int, target_team: String, target_index: int, kind: String, cooldown_s: float, key_threat: bool, dodged: bool)
signal cc_prevented(source_team: String, source_index: int, target_team: String, target_index: int, kind: String)
signal cc_taxed(source_team: String, source_index: int, target_team: String, target_index: int, kind: String, raw_duration: float, effective_duration: float, tenacity: float, prevented: bool)
signal cleanse_applied(source_team: String, source_index: int, target_team: String, target_index: int, removed: int)
signal zone_exposure_applied(source_team: String, source_index: int, target_team: String, target_index: int, kind: String, duration_s: float, damage: float, radius_tiles: float)

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var state: BattleState
var player_ref: Unit
var stage: int = 1
var select_closest_target: Callable = Callable()

var process_player_first: bool = true
var alternate_order: bool = false
var deterministic_rolls: bool = true

var total_damage_player: int = 0
var total_damage_enemy: int = 0
var debug_pairs: int = 0
var debug_shots: int = 0
var debug_double_lethals: int = 0
var _frame_delta_last: float = 0.0
var _seed_locked: bool = false
var _seed_value: int = 0
var _position_emit_accum: float = 0.0
var _last_player_positions: Array = []
var _last_enemy_positions: Array = []
var _last_targets_player: Array = []
var _last_targets_enemy: Array = []
var _movement_player_targets_scratch: Array[int] = []
var _movement_enemy_targets_scratch: Array[int] = []

var arena_state: Variant = MovementServiceLib.new()
var target_controller: TargetController = TargetController.new()
var cooldown_scheduler: CooldownScheduler = CooldownScheduler.new()
var attack_resolver: AttackResolver = AttackResolver.new()
var outcome_resolver: OutcomeResolver = OutcomeResolver.new()
var projectile_handler: ProjectileHandler = ProjectileHandler.new()
var regen_system: RegenSystem = RegenSystem.new()
var ability_system: AbilitySystem = null
var buff_system: BuffSystem = null
var encounter_escalation_runtime: RefCounted = EncounterEscalationRuntimeLib.new()
var encounter_escalation_config: Dictionary = {}
var contract_battle_runtime: RefCounted = ContractBattleRuntimeLib.new()
var contract_battle_config: Dictionary = {}
var unit_upgrade_runtime: RefCounted = UnitUpgradeRuntimeLib.new()
var _connected_ability_system: AbilitySystem = null
var _connected_buff_system: BuffSystem = null
## Removed passive damage system (was: tick accumulator + constants)

# First-attack wind-up to reduce immediate burst on entering range
var first_attack_windup_s: float = 0.25
var _first_attack_windup_done: Dictionary = {}

# Feature toggles
var abilities_enabled: bool = true
var emit_auto_attack_logs: bool = false
var emit_ability_logs: bool = false

var _resolver_emitters: Dictionary[String, Callable] = {}
var combat_timeout_s: float = 45.0
var no_progress_timeout_s: float = 12.0
var _last_progress_time: float = 0.0
var _last_progress_total_damage: int = 0
var _last_progress_positions: Array[Vector2] = []

func set_seed(seed: int) -> void:
	if rng == null:
		rng = RandomNumberGenerator.new()
	var coerced: int = int(seed)
	if coerced < 0:
		coerced = int(abs(seed))
	_seed_value = coerced
	_seed_locked = true
	rng.seed = coerced

func configure_encounter_escalation(config: Dictionary) -> void:
	encounter_escalation_config = config.duplicate(true)
	if state != null:
		encounter_escalation_runtime.configure(state, encounter_escalation_config)

func configure_contract_battle(config: Dictionary) -> void:
	contract_battle_config = config.duplicate(true)
	if state != null:
		contract_battle_runtime.configure(state, contract_battle_config)

func configure(_state: BattleState, _player: Unit, _stage: int, _selector: Callable = Callable()) -> void:
	Trace.step("CombatEngine.configure: begin")
	_disconnect_signal_bindings()
	state = _state
	player_ref = _player
	stage = _stage
	encounter_escalation_runtime.configure(state, encounter_escalation_config)
	contract_battle_runtime.configure(state, contract_battle_config)
	unit_upgrade_runtime.configure(state)
	# Prefer engine-provided closest-target selector if none supplied
	select_closest_target = (_selector if _selector.is_valid() else Callable(self, "_engine_select_closest_target"))
	if _seed_locked:
		rng.seed = _seed_value
	else:
		rng.randomize()
	_resolver_emitters = _build_resolver_emitters()
	if outcome_resolver == null:
		outcome_resolver = OutcomeResolver.new()
	target_controller.configure(state, select_closest_target)
	cooldown_scheduler.configure(state, target_controller, buff_system)
	cooldown_scheduler.rng = rng
	cooldown_scheduler.apply_rules(process_player_first, alternate_order)
	# Ensure buff and ability systems
	if buff_system == null:
		buff_system = BuffSystemLib.new()
	# Ability system is optional based on toggle
	if abilities_enabled:
		if ability_system == null:
			ability_system = AbilitySystemLib.new()
		ability_system.emit_ability_logs = emit_ability_logs
		ability_system.configure(self, state, rng, buff_system)
	else:
		ability_system = null
	attack_resolver.configure(state, target_controller, rng, player_ref, _resolver_emitters, ability_system, buff_system)
	attack_resolver.emit_auto_attack_logs = emit_auto_attack_logs
	attack_resolver.set_deterministic_rolls(deterministic_rolls)
	outcome_resolver.configure(state, rng)
	projectile_handler.configure(attack_resolver)
	# Ensure regen system enforces mana blocking via BuffSystem
	regen_system.buff_system = buff_system
	regen_system.ability_system = ability_system
	# Ensure movement service (already constructed at declaration)
	# Provide BuffSystem to movement via adapter if supported
	if arena_state and arena_state.has_method("set_buff_system"):
		arena_state.set_buff_system(buff_system)
	arena_state.ensure_capacity(state.player_team.size(), state.enemy_team.size())
	_sync_movement_profiles()
	_reset_position_tracking()
	_reset_target_tracking()
	_position_emit_accum = 0.0
	_target_recheck_accum = 0.0
	_refresh_signal_bindings()
	_update_totals_cache()
	_reset_debug_counters()
	Trace.step("CombatEngine.configure: done")

func teardown() -> void:
	_disconnect_signal_bindings()
	if ability_system != null and ability_system.has_method("teardown"):
		ability_system.teardown()
	if buff_system != null and buff_system.has_method("clear"):
		buff_system.clear()
	if attack_resolver != null and attack_resolver.has_method("teardown"):
		attack_resolver.teardown()
	if projectile_handler != null:
		projectile_handler.resolver = null
	if regen_system != null:
		regen_system.buff_system = null
		regen_system.ability_system = null
	if target_controller != null:
		target_controller.state = null
		target_controller.selector = Callable()
		target_controller._resolving_player.clear()
		target_controller._resolving_enemy.clear()
	if cooldown_scheduler != null:
		cooldown_scheduler.state = null
		cooldown_scheduler.target_controller = null
		cooldown_scheduler.buff_system = null
		cooldown_scheduler.rng = null
		cooldown_scheduler._player_order.clear()
		cooldown_scheduler._enemy_order.clear()
	if outcome_resolver != null:
		outcome_resolver.state = null
		outcome_resolver.rng = null
	if arena_state != null and arena_state.has_method("configure"):
		arena_state.configure(1.0, [], [], Rect2())
	state = null
	player_ref = null
	select_closest_target = Callable()
	ability_system = null
	buff_system = null
	_connected_ability_system = null
	_connected_buff_system = null
	_resolver_emitters.clear()
	_last_player_positions.clear()
	_last_enemy_positions.clear()
	_last_targets_player.clear()
	_last_targets_enemy.clear()
	_movement_player_targets_scratch.clear()
	_movement_enemy_targets_scratch.clear()
	_first_attack_windup_done.clear()
	_target_recheck_accum = 0.0
	encounter_escalation_config.clear()
	encounter_escalation_runtime.configure(null, {})
	contract_battle_config.clear()
	contract_battle_runtime.configure(null, {})
	unit_upgrade_runtime.configure(null)

func set_arena(tile_size: float, player_pos: Array, enemy_pos: Array, bounds: Rect2) -> void:
	# Cast/convert to typed arrays of Vector2 for movement.configure signature
	var p: Array[Vector2] = []
	for v in player_pos:
		if typeof(v) == TYPE_VECTOR2:
			p.append(v)
	var e: Array[Vector2] = []
	for v2 in enemy_pos:
		if typeof(v2) == TYPE_VECTOR2:
			e.append(v2)
	# Movement service already exists; keep configuration idempotent
	arena_state.configure(tile_size, p, e, bounds)
	# Now that arena positions are available, reprime targets so initial
	# selections can use real distances (closest enemy at round start).
	if target_controller != null:
		target_controller.prime_targets()
	_sync_movement_profiles()

func set_arena_bounds(bounds: Rect2) -> void:
	if arena_state != null and arena_state.has_method("set_bounds"):
		arena_state.set_bounds(bounds)

func _engine_select_closest_target(my_team: String, my_index: int, enemy_team: String) -> int:
	if state == null:
		return -1
	var ally_arr: Array[Unit] = state.player_team if my_team == "player" else state.enemy_team
	var enemy_arr: Array[Unit] = state.enemy_team if enemy_team == "enemy" else state.player_team
	if my_index < 0 or my_index >= ally_arr.size():
		return -1
	var attacker: Unit = ally_arr[my_index]
	if attacker == null or not attacker.is_alive():
		return -1
	var ally_positions: Array[Vector2] = _positions_for_team(my_team)
	var enemy_positions: Array[Vector2] = _positions_for_team(enemy_team)
	var src_pos: Vector2 = _position_at(ally_positions, my_index, Vector2.ZERO)
	var current_target: int = _current_target_index(my_team, my_index)
	return Targeting.pick_by_priority(
		attacker,
		src_pos,
		ally_arr,
		ally_positions,
		enemy_arr,
		enemy_positions,
		current_target,
		arena_state.tile_size())

func _positions_for_team(team: String) -> Array[Vector2]:
	if arena_state == null:
		return []
	if team == "player":
		if arena_state.has_method("player_positions_current"):
			return arena_state.player_positions_current()
		return arena_state.player_positions_copy()
	if arena_state.has_method("enemy_positions_current"):
		return arena_state.enemy_positions_current()
	return arena_state.enemy_positions_copy()

func _position_at(positions: Array[Vector2], index: int, fallback: Vector2) -> Vector2:
	if index >= 0 and index < positions.size():
		return positions[index]
	return fallback

func _current_target_index(team: String, index: int) -> int:
	if state == null or index < 0:
		return -1
	var targets: Array[int] = state.player_targets if team == "player" else state.enemy_targets
	if index >= targets.size():
		return -1
	return int(targets[index])

func _sync_movement_profiles() -> void:
	if arena_state == null or state == null or not arena_state.has_method("set_profiles"):
		return
	arena_state.set_profiles("player", _movement_profiles_for_team("player", state.player_team))
	arena_state.set_profiles("enemy", _movement_profiles_for_team("enemy", state.enemy_team))

func _movement_profiles_for_team(team: String, units: Array[Unit]) -> Array[MovementProfile]:
	var profiles: Array[MovementProfile] = []
	for i in range(units.size()):
		var unit: Unit = units[i]
		profiles.append(_movement_profile_for_unit(team, i, unit, units))
	return profiles

func _movement_profile_for_unit(team: String, index: int, unit: Unit, units: Array[Unit]) -> MovementProfile:
	var side_bias: float = 1.0 if ((index + (0 if team == "player" else 1)) % 2 == 0) else -1.0
	var profile: MovementProfile
	if unit == null:
		return MovementProfileLib.new("approach", 0.95, 1.00, 0.0, 0.0, side_bias)
	var role: String = String(unit.get_primary_role()).strip_edges().to_lower()
	var attack_range_tiles: float = float(unit.attack_range)
	var has_long_range: bool = _unit_has_approach(unit, "long_range")
	var has_reposition: bool = _unit_has_approach(unit, "reposition")
	var has_access_backline: bool = _unit_has_approach(unit, "access_backline")
	if role == "marksman":
		profile = MovementProfileLib.new("kite", 0.72, 1.02, 0.18, 1.0, side_bias)
	elif role == "mage":
		if attack_range_tiles >= 3.0 or has_long_range or _unit_has_approach(unit, "zone"):
			profile = MovementProfileLib.new("kite", 0.76, 1.02, 0.12, 0.75, side_bias)
		else:
			profile = MovementProfileLib.new("strafe", 0.88, 1.00, 0.08, 0.0, side_bias)
	elif role == "support":
		if attack_range_tiles >= 3.0 or has_long_range:
			profile = MovementProfileLib.new("kite", 0.78, 1.02, 0.10, 0.65, side_bias)
		else:
			profile = MovementProfileLib.new("strafe", 0.88, 1.00, 0.08, 0.0, side_bias)
	elif role == "assassin":
		profile = MovementProfileLib.new("strafe", 0.86, 0.98, 0.16, 0.10, side_bias)
	elif role == "brawler":
		if has_access_backline or has_reposition:
			profile = MovementProfileLib.new("strafe", 0.86, 0.98, 0.12, 0.0, side_bias)
		else:
			profile = MovementProfileLib.new("approach", 0.88, 0.98, 0.0, 0.0, side_bias)
	elif role == "tank":
		profile = MovementProfileLib.new("approach", 0.86, 0.94, 0.0, 0.0, side_bias)
	elif attack_range_tiles >= 3.0:
		profile = MovementProfileLib.new("kite", 0.78, 1.02, 0.10, 0.65, side_bias)
	else:
		profile = MovementProfileLib.new("strafe" if has_reposition else "approach", 0.88, 1.00, 0.08 if has_reposition else 0.0, 0.0, side_bias)
	_configure_movement_anchor(profile, index, unit, units)
	return profile

func _configure_movement_anchor(profile: MovementProfile, index: int, unit: Unit, units: Array[Unit]) -> void:
	if profile == null or unit == null:
		return
	var role: String = String(unit.get_primary_role()).strip_edges().to_lower()
	var wants_anchor: bool = role == "support" or _unit_has_approach(unit, "peel") or _unit_has_approach(unit, "amp") or _unit_has_approach(unit, "cc_immunity")
	if not wants_anchor:
		return
	var anchor_index: int = _movement_anchor_index(index, units)
	if anchor_index < 0:
		return
	profile.anchor_index = anchor_index
	profile.anchor_min_tiles = 0.75
	profile.anchor_max_tiles = 2.85
	profile.anchor_strength = 0.55

func _movement_anchor_index(source_index: int, units: Array[Unit]) -> int:
	var best_index: int = -1
	var best_score: float = 0.0
	for i in range(units.size()):
		if i == source_index:
			continue
		var ally: Unit = units[i]
		if ally == null or not ally.is_alive():
			continue
		var score: float = _movement_anchor_score(ally)
		if score > best_score:
			best_score = score
			best_index = i
	return best_index

func _movement_anchor_score(unit: Unit) -> float:
	if unit == null:
		return 0.0
	var role: String = String(unit.get_primary_role()).strip_edges().to_lower()
	var score: float = 0.0
	if role == "marksman":
		score += 4.0
	elif role == "mage":
		score += 3.0
	elif role == "support":
		score += 0.5
	if _unit_has_approach(unit, "long_range"):
		score += 1.0
	if _unit_has_approach(unit, "ramp"):
		score += 0.75
	if float(unit.attack_range) >= 3.0:
		score += 0.5
	return score

func _unit_has_approach(unit: Unit, approach_id: String) -> bool:
	if unit == null:
		return false
	var key: String = String(approach_id).strip_edges().to_lower()
	for raw_approach in unit.get_approaches():
		if String(raw_approach).strip_edges().to_lower() == key:
			return true
	return false

func get_arena_bounds_copy() -> Rect2:
	return arena_state.bounds_copy()

func get_player_position(idx: int) -> Vector2:
	return arena_state.get_player_position(idx)

func get_enemy_position(idx: int) -> Vector2:
	return arena_state.get_enemy_position(idx)

func get_player_positions_copy() -> Array:
	return arena_state.player_positions_copy()

func get_enemy_positions_copy() -> Array:
	return arena_state.enemy_positions_copy()

func notify_forced_movement(team: String, idx: int, vec: Vector2, dur: float) -> void:
	if arena_state and arena_state.has_method("notify_forced_movement"):
		arena_state.notify_forced_movement(team, idx, vec, dur)

func start() -> void:
	Trace.step("CombatEngine.start: begin")
	if not state:
		return
	state.battle_active = true
	_first_attack_windup_done.clear()
	_last_progress_time = 0.0
	_last_progress_total_damage = 0
	_last_progress_positions.clear()
	if outcome_resolver != null:
		outcome_resolver.reset()
	attack_resolver.reset_totals()
	attack_resolver.begin_frame()
	state.regen_tick_accum = 0.0
	state.elapsed_time = 0.0
	state.player_cds = BattleState.fill_cds_for(state.player_team)
	state.enemy_cds = BattleState.fill_cds_for(state.enemy_team)
	state.player_targets.clear()
	state.enemy_targets.clear()
	target_controller.configure(state, select_closest_target)
	cooldown_scheduler.configure(state, target_controller, buff_system)
	cooldown_scheduler.apply_rules(process_player_first, alternate_order)
	cooldown_scheduler.reset_turn()
	# Randomize starting side once per battle when not explicitly set by rules
	if rng:
		cooldown_scheduler._next_player_first = (rng.randf() < 0.5) if alternate_order else cooldown_scheduler._next_player_first
	attack_resolver.set_deterministic_rolls(deterministic_rolls)
	arena_state.ensure_capacity(state.player_team.size(), state.enemy_team.size())
	_position_emit_accum = 0.0
	_reset_position_tracking()
	_reset_target_tracking()
	_emit_position_updates(true)
	_emit_target_events(true)
	total_damage_player = 0
	total_damage_enemy = 0
	_reset_debug_counters()
	_emit_stats_snapshot()
	Trace.step("CombatEngine.start: done")

func stop() -> void:
	if not state:
		return
	state.battle_active = false
	# Revert and clear any lingering stat buffs so unit bases don't persist between rounds
	if buff_system != null and buff_system.has_method("clear_reverting_stats"):
		buff_system.clear_reverting_stats()

func process(delta: float) -> void:
	if not state or (outcome_resolver != null and outcome_resolver.outcome_sent):
		return
	if delta <= 0.0:
		return
	_frame_delta_last = delta
	cooldown_scheduler.apply_rules(process_player_first, alternate_order)
	attack_resolver.set_deterministic_rolls(deterministic_rolls)
	attack_resolver.begin_frame()
	if not state.battle_active:
		var idle_outcome: String = ""
		if outcome_resolver != null:
			idle_outcome = outcome_resolver.evaluate_idle(attack_resolver.totals())
		if idle_outcome != "":
			_update_totals_cache()
			_emit_outcome(idle_outcome)
		return
	state.elapsed_time += delta
	_retarget_if_due(delta)
	target_controller.copy_arena_targets(_movement_player_targets_scratch, _movement_enemy_targets_scratch)
	arena_state.update_movement_with_targets(state, delta, _movement_player_targets_scratch, _movement_enemy_targets_scratch)
	_update_combat_progress_watchdog()
	_process_encounter_escalation()
	_process_contract_battle(delta)
	_process_unit_upgrades()
	var timeout_outcome: String = _combat_timeout_outcome()
	if timeout_outcome != "":
		_emit_outcome(timeout_outcome)
		return
	_position_emit_accum += delta
	var __pei: float = (position_emit_interval_override if position_emit_interval_override > 0.0 else POSITION_EMIT_INTERVAL)
	while _position_emit_accum >= __pei:
		_emit_position_updates()
		_position_emit_accum -= __pei
	var board_pre: String = ""
	if outcome_resolver != null:
		board_pre = outcome_resolver.evaluate_board(attack_resolver.totals())
	if board_pre != "":
		_update_totals_cache()
		_emit_outcome(board_pre)
		return
	# Passive damage disabled
	var frame_data: Dictionary = cooldown_scheduler.advance(delta)
	_apply_regen(int(frame_data.get("regen_ticks", 0)))
	if buff_system != null:
		buff_system.tick(state, delta)
	if ability_system != null:
		ability_system.tick(delta)
	_emit_target_events()
	var ordered: Array[AttackEvent] = frame_data.get("ordered", []) as Array[AttackEvent]
	if ordered.size() > 0:
		var gated: Array[AttackEvent] = _filter_events_in_range(ordered)
		if gated.size() > 0:
			attack_resolver.resolve_ordered(gated)
	_emit_target_events()
	_process_encounter_escalation()
	if _evaluate_outcome():
		return
	_update_totals_cache()
	_reset_debug_counters()

func _retarget_if_due(delta: float) -> void:
	if target_controller == null:
		return
	if target_recheck_interval_s <= 0.0:
		return
	_target_recheck_accum += max(0.0, delta)
	if _target_recheck_accum < target_recheck_interval_s:
		return
	while _target_recheck_accum >= target_recheck_interval_s:
		_target_recheck_accum -= target_recheck_interval_s
	target_controller.refresh_live_targets()

func on_projectile_hit(source_team: String, source_index: int, target_index: int, damage: int, crit: bool) -> void:
	if not state or not state.battle_active or (outcome_resolver != null and outcome_resolver.outcome_sent):
		return
	var result: Dictionary = projectile_handler.handle_hit(source_team, source_index, target_index, damage, crit)
	if not result.get("processed", false):
		return
	_update_totals_cache()
	_mark_combat_progress()
	_reset_debug_counters()
	_process_encounter_escalation()
	_evaluate_outcome()

func _apply_regen(ticks: int) -> void:
	regen_system.apply_ticks(state, ticks, player_ref, _resolver_emitters)

func _process_encounter_escalation() -> void:
	if encounter_escalation_runtime == null:
		return
	var event: Dictionary = encounter_escalation_runtime.process()
	if event.is_empty():
		return
	var champion_index: int = int(event.get("champion_index", -1))
	var revived_indices: Array[int] = []
	for revived_value: Variant in event.get("revived_indices", []):
		var revived_index: int = int(revived_value)
		revived_indices.append(revived_index)
		if revived_index >= 0 and revived_index < state.enemy_cds.size():
			state.enemy_cds[revived_index] = 0.0
		emit_signal("unit_stat_changed", "enemy", revived_index, {"hp": true, "mana": true})
		emit_signal("vfx_knockup", "enemy", revived_index, 0.55)
	var affected_player_indices: Array[int] = []
	for player_value: Variant in event.get("affected_player_indices", []):
		var player_index: int = int(player_value)
		affected_player_indices.append(player_index)
		emit_signal("unit_stat_changed", "player", player_index, {"hp": true})
		emit_signal("vfx_knockup", "player", player_index, 0.18)
	if champion_index >= 0:
		emit_signal("unit_stat_changed", "enemy", champion_index, {"hp": true, "max_hp": true, "attack_damage": true, "spell_power": true, "attack_speed": true, "mana": true})
		emit_signal("vfx_knockup", "enemy", champion_index, 0.85)
	if target_controller != null:
		target_controller.refresh_live_targets()
	_emit_stats_snapshot()
	var label: String = String(event.get("label", "BOSS PHASE"))
	var pulse_damage: int = int(event.get("pulse_damage", 0))
	emit_signal("log_line", "[BOSS PHASE %d] %s — %d reinforcement(s) return; arena pulse deals %d total damage." % [
		int(event.get("phase_number", 1)),
		label,
		revived_indices.size(),
		pulse_damage,
	])
	emit_signal(
		"encounter_escalated",
		String(event.get("phase_id", "boss_phase")),
		label,
		champion_index,
		revived_indices,
		affected_player_indices,
		pulse_damage,
		int(event.get("intensity", 1))
	)

func _process_contract_battle(delta: float) -> void:
	if contract_battle_runtime == null:
		return
	var events: Array[Dictionary] = contract_battle_runtime.process(delta)
	for event: Dictionary in events:
		var event_type: String = String(event.get("event_type", "contract_effect"))
		var label: String = String(event.get("label", "CONTRACT ACTIVATED"))
		var affected_player_indices: Array[int] = []
		var affected_enemy_indices: Array[int] = []
		for player_value: Variant in event.get("player_indices", []):
			affected_player_indices.append(int(player_value))
		for enemy_value: Variant in event.get("enemy_indices", []):
			affected_enemy_indices.append(int(enemy_value))
		if event_type == "starting_ward" or event_type == "death_inheritance":
			var shield_values: Array[int] = []
			for shield_value: Variant in event.get("player_values", []):
				shield_values.append(int(shield_value))
			var duration_s: float = max(0.5, float(event.get("duration_s", 8.0)))
			for value_index: int in range(affected_player_indices.size()):
				var player_index: int = affected_player_indices[value_index]
				var shield_amount: int = int(shield_values[value_index]) if value_index < shield_values.size() else 0
				if shield_amount > 0 and buff_system != null:
					buff_system.apply_shield(state, "player", player_index, shield_amount, duration_s)
				emit_signal("unit_stat_changed", "player", player_index, {"hp": true, "shield": true})
				emit_signal("vfx_knockup", "player", player_index, 0.16)
		else:
			for player_index: int in affected_player_indices:
				emit_signal("unit_stat_changed", "player", player_index, {"hp": true})
				emit_signal("vfx_knockup", "player", player_index, 0.24)
			for enemy_index: int in affected_enemy_indices:
				emit_signal("unit_stat_changed", "enemy", enemy_index, {"hp": true})
				emit_signal("vfx_knockup", "enemy", enemy_index, 0.24)
		var value: int = max(0, int(event.get("value", 0)))
		if value > 0:
			_mark_combat_progress()
		_emit_stats_snapshot()
		emit_signal("log_line", "[CONTRACT] %s - %d total value." % [label, value])
		emit_signal(
			"contract_battle_event",
			event_type,
			label,
			affected_player_indices,
			affected_enemy_indices,
			value,
			max(1, int(event.get("intensity", 1)))
		)

func _process_unit_upgrades() -> void:
	if unit_upgrade_runtime == null:
		return
	var events: Array[Dictionary] = unit_upgrade_runtime.process()
	for event: Dictionary in events:
		var event_type: String = String(event.get("event_type", "unit_upgrade"))
		var label: String = String(event.get("label", "LEGACY AWAKENS"))
		var affected_player_indices: Array[int] = []
		for player_value: Variant in event.get("player_indices", []):
			affected_player_indices.append(int(player_value))
		var stat_index: int = int(event.get("stat_index", -1))
		var stat_value: Variant = event.get("stat_fields", {})
		if stat_index >= 0 and stat_value is Dictionary and not (stat_value as Dictionary).is_empty() and buff_system != null:
			buff_system.apply_stats_labeled(
				state,
				"player",
				stat_index,
				"unit_upgrade_%s" % event_type,
				stat_value as Dictionary,
				max(0.5, float(event.get("duration_s", 90.0)))
			)
		var shield_values: Array[int] = []
		for shield_value: Variant in event.get("player_values", []):
			shield_values.append(int(shield_value))
		var shield_duration_s: float = max(0.5, float(event.get("shield_duration_s", 8.0)))
		for value_index: int in range(affected_player_indices.size()):
			var player_index: int = affected_player_indices[value_index]
			var shield_amount: int = int(shield_values[value_index]) if value_index < shield_values.size() else 0
			if shield_amount > 0 and buff_system != null:
				buff_system.apply_shield(state, "player", player_index, shield_amount, shield_duration_s)
			emit_signal("unit_stat_changed", "player", player_index, {"hp": true, "mana": true, "shield": true, "attack_speed": true, "attack_damage": true, "spell_power": true})
			emit_signal("vfx_knockup", "player", player_index, 0.25 if int(event.get("intensity", 1)) < 3 else 0.48)
		var value: int = max(0, int(event.get("value", 0)))
		_mark_combat_progress()
		_emit_stats_snapshot()
		emit_signal("log_line", "[UNIT LEGACY] %s - %d total effect." % [label, value])
		emit_signal(
			"unit_upgrade_event",
			event_type,
			label,
			affected_player_indices,
			value,
			max(1, int(event.get("intensity", 1)))
		)

## Passive damage removed

func _evaluate_outcome() -> bool:
	var frame_outcome: String = ""
	if outcome_resolver != null:
		frame_outcome = outcome_resolver.evaluate_frame(attack_resolver.frame_status())
	if frame_outcome != "":
		_update_totals_cache()
		_emit_outcome(frame_outcome)
		return true
	var board_outcome: String = ""
	if outcome_resolver != null:
		board_outcome = outcome_resolver.evaluate_board(attack_resolver.totals())
	if board_outcome != "":
		_update_totals_cache()
		_emit_outcome(board_outcome)
		return true
	return false

func _emit_outcome(kind: String) -> void:
	if kind == "":
		return
	if outcome_resolver != null:
		outcome_resolver.mark_emitted()
	# Mark inactive and revert any lingering stat buffs BEFORE notifying listeners,
	# so planning UI and intermission handlers see base stats.
	state.battle_active = false
	stop()
	match kind:
		"victory":
			emit_signal("victory", stage)
		"defeat":
			emit_signal("defeat", stage)
		"tie":
			emit_signal("tie", stage)
		_:
			# Fallback: default to defeat if unknown outcome
			emit_signal("defeat", stage)

func _emit_stats_snapshot() -> void:
	emit_signal("stats_updated", player_ref, BattleState.first_alive(state.enemy_team))
	emit_signal("team_stats_updated", state.player_team, state.enemy_team)

func _update_totals_cache() -> void:
	var totals: Dictionary = attack_resolver.totals()
	total_damage_player = int(totals.get("player", total_damage_player))
	total_damage_enemy = int(totals.get("enemy", total_damage_enemy))

func _update_combat_progress_watchdog() -> void:
	if state == null or arena_state == null:
		return
	var total_damage: int = total_damage_player + total_damage_enemy
	if total_damage > _last_progress_total_damage or bool(arena_state.positions_changed_from(_last_progress_positions, 0.5)):
		_last_progress_time = float(state.elapsed_time)
		_last_progress_total_damage = total_damage
		arena_state.copy_all_positions_to(_last_progress_positions)

func _mark_combat_progress() -> void:
	if state == null:
		return
	_last_progress_time = float(state.elapsed_time)
	_last_progress_total_damage = total_damage_player + total_damage_enemy
	if arena_state != null:
		arena_state.copy_all_positions_to(_last_progress_positions)

func _combat_timeout_outcome() -> String:
	if state == null or not state.battle_active:
		return ""
	if combat_timeout_s > 0.0 and float(state.elapsed_time) >= combat_timeout_s:
		emit_signal("log_line", "Combat timeout: forcing result from current board state.")
		return _fallback_timeout_outcome()
	if no_progress_timeout_s > 0.0 and float(state.elapsed_time) - _last_progress_time >= no_progress_timeout_s:
		emit_signal("log_line", "Combat no-progress timeout: forcing result from current board state.")
		return _fallback_timeout_outcome()
	return ""

func _fallback_timeout_outcome() -> String:
	if state == null:
		return "defeat"
	var player_alive: int = _alive_count(state.player_team)
	var enemy_alive: int = _alive_count(state.enemy_team)
	if enemy_alive <= 0 and player_alive > 0:
		return "victory"
	if player_alive <= 0 and enemy_alive > 0:
		return "defeat"
	if total_damage_player > total_damage_enemy:
		return "victory"
	if total_damage_enemy > total_damage_player:
		return "defeat"
	return "tie"

func _alive_count(units: Array[Unit]) -> int:
	var count: int = 0
	for unit: Unit in units:
		if unit != null and unit.is_alive():
			count += 1
	return count

func _all_positions() -> Array[Vector2]:
	var out: Array[Vector2] = []
	if arena_state == null:
		return out
	var player_positions: Array = arena_state.player_positions_copy()
	for player_position in player_positions:
		if player_position is Vector2:
			out.append(player_position)
	var enemy_positions: Array = arena_state.enemy_positions_copy()
	for enemy_position in enemy_positions:
		if enemy_position is Vector2:
			out.append(enemy_position)
	return out

func _positions_changed(current: Array[Vector2], previous: Array[Vector2]) -> bool:
	if current.size() != previous.size():
		return true
	for index: int in range(current.size()):
		if current[index].distance_to(previous[index]) > 0.5:
			return true
	return false

func _reset_debug_counters() -> void:
	debug_pairs = attack_resolver.debug_pairs
	debug_shots = attack_resolver.debug_shots
	debug_double_lethals = attack_resolver.debug_double_lethals

func _refresh_signal_bindings() -> void:
	if ability_system != null and ability_system.has_signal("ability_cast"):
		if not ability_system.is_connected("ability_cast", Callable(self, "_on_ability_system_cast")):
			ability_system.ability_cast.connect(_on_ability_system_cast)
		if ability_system.has_signal("ability_committed") and not ability_system.is_connected("ability_committed", Callable(self, "_on_ability_system_committed")):
			ability_system.ability_committed.connect(_on_ability_system_committed)
		_connected_ability_system = ability_system
	else:
		_connected_ability_system = null
	if buff_system != null:
		if buff_system.has_signal("buff_applied") and not buff_system.is_connected("buff_applied", Callable(self, "_on_buff_system_buff_applied")):
			buff_system.buff_applied.connect(_on_buff_system_buff_applied)
		if buff_system.has_signal("debuff_applied") and not buff_system.is_connected("debuff_applied", Callable(self, "_on_buff_system_debuff_applied")):
			buff_system.debuff_applied.connect(_on_buff_system_debuff_applied)
		if buff_system.has_signal("on_hit_proc") and not buff_system.is_connected("on_hit_proc", Callable(self, "_on_buff_system_on_hit_proc")):
			buff_system.on_hit_proc.connect(_on_buff_system_on_hit_proc)
		if buff_system.has_signal("cc_prevented") and not buff_system.is_connected("cc_prevented", Callable(self, "_on_buff_system_cc_prevented")):
			buff_system.cc_prevented.connect(_on_buff_system_cc_prevented)
		if buff_system.has_signal("cc_taxed") and not buff_system.is_connected("cc_taxed", Callable(self, "_on_buff_system_cc_taxed")):
			buff_system.cc_taxed.connect(_on_buff_system_cc_taxed)
		if buff_system.has_signal("cleanse_applied") and not buff_system.is_connected("cleanse_applied", Callable(self, "_on_buff_system_cleanse_applied")):
			buff_system.cleanse_applied.connect(_on_buff_system_cleanse_applied)
		_connected_buff_system = buff_system
	else:
		_connected_buff_system = null

func _disconnect_signal_bindings() -> void:
	if _connected_ability_system != null and _connected_ability_system.has_signal("ability_cast"):
		if _connected_ability_system.is_connected("ability_cast", Callable(self, "_on_ability_system_cast")):
			_connected_ability_system.ability_cast.disconnect(_on_ability_system_cast)
		if _connected_ability_system.has_signal("ability_committed") and _connected_ability_system.is_connected("ability_committed", Callable(self, "_on_ability_system_committed")):
			_connected_ability_system.ability_committed.disconnect(_on_ability_system_committed)
	_connected_ability_system = null
	if _connected_buff_system != null:
		if _connected_buff_system.has_signal("buff_applied") and _connected_buff_system.is_connected("buff_applied", Callable(self, "_on_buff_system_buff_applied")):
			_connected_buff_system.buff_applied.disconnect(_on_buff_system_buff_applied)
		if _connected_buff_system.has_signal("debuff_applied") and _connected_buff_system.is_connected("debuff_applied", Callable(self, "_on_buff_system_debuff_applied")):
			_connected_buff_system.debuff_applied.disconnect(_on_buff_system_debuff_applied)
		if _connected_buff_system.has_signal("on_hit_proc") and _connected_buff_system.is_connected("on_hit_proc", Callable(self, "_on_buff_system_on_hit_proc")):
			_connected_buff_system.on_hit_proc.disconnect(_on_buff_system_on_hit_proc)
		if _connected_buff_system.has_signal("cc_prevented") and _connected_buff_system.is_connected("cc_prevented", Callable(self, "_on_buff_system_cc_prevented")):
			_connected_buff_system.cc_prevented.disconnect(_on_buff_system_cc_prevented)
		if _connected_buff_system.has_signal("cc_taxed") and _connected_buff_system.is_connected("cc_taxed", Callable(self, "_on_buff_system_cc_taxed")):
			_connected_buff_system.cc_taxed.disconnect(_on_buff_system_cc_taxed)
		if _connected_buff_system.has_signal("cleanse_applied") and _connected_buff_system.is_connected("cleanse_applied", Callable(self, "_on_buff_system_cleanse_applied")):
			_connected_buff_system.cleanse_applied.disconnect(_on_buff_system_cleanse_applied)
	_connected_buff_system = null

func _reset_position_tracking() -> void:
	_last_player_positions = []
	_last_enemy_positions = []

func _reset_target_tracking() -> void:
	_last_targets_player = []
	_last_targets_enemy = []

func _emit_position_updates(force: bool = false) -> void:
	if state == null or arena_state == null:
		return
	if not emit_position_telemetry:
		return
	var player_count: int = state.player_team.size()
	if player_count > 0:
		_last_player_positions.resize(player_count)
		for i in range(player_count):
			var unit: Unit = state.player_team[i]
			if unit == null:
				_last_player_positions[i] = null
				continue
			var pos: Vector2 = arena_state.get_player_position(i)
			var last: Variant = _last_player_positions[i] if i < _last_player_positions.size() else null
			var emit_now: bool = force
			if not emit_now:
				emit_now = not (last is Vector2 and pos.is_equal_approx(last))
			if emit_now:
				# Debug: print player position when it changes (guarded)
				if log_position_updates:
					print("[Move] player ", i, " ", (unit.name if unit != null else "?"), " pos=", pos)
				emit_signal("position_updated", "player", i, pos.x, pos.y)
			_last_player_positions[i] = pos
	else:
		_last_player_positions.clear()
	var enemy_count: int = state.enemy_team.size()
	if enemy_count > 0:
		_last_enemy_positions.resize(enemy_count)
		for j in range(enemy_count):
			var enemy: Unit = state.enemy_team[j]
			if enemy == null:
				_last_enemy_positions[j] = null
				continue
			var epos: Vector2 = arena_state.get_enemy_position(j)
			var elast: Variant = _last_enemy_positions[j] if j < _last_enemy_positions.size() else null
			var emit_enemy: bool = force
			if not emit_enemy:
				emit_enemy = not (elast is Vector2 and epos.is_equal_approx(elast))
			if emit_enemy:
				# Debug: print enemy position when it changes (guarded)
				if log_position_updates:
					print("[Move] enemy  ", j, " ", (enemy.name if enemy != null else "?"), " pos=", epos)
				emit_signal("position_updated", "enemy", j, epos.x, epos.y)
			_last_enemy_positions[j] = epos
	else:
		_last_enemy_positions.clear()

func _emit_target_events(force: bool = false) -> void:
	if target_controller == null or state == null:
		return
	if not emit_target_telemetry:
		return
	var player_targets: Array = target_controller.target_array("player")
	var enemy_targets: Array = target_controller.target_array("enemy")
	_last_targets_player = _emit_target_events_for_team("player", "enemy", player_targets, _last_targets_player, force)
	_last_targets_enemy = _emit_target_events_for_team("enemy", "player", enemy_targets, _last_targets_enemy, force)

func _emit_target_events_for_team(team: String, target_team: String, current: Array, previous: Array, force: bool) -> Array:
	var curr_count: int = current.size()
	var prev_count: int = previous.size()
	if previous.size() < curr_count:
		previous.resize(curr_count)
	for i in range(curr_count):
		var new_target: int = int(current[i])
		var prev_target: int = (int(previous[i]) if i < prev_count else -1)
		if force:
			if new_target >= 0:
				emit_signal("target_start", team, i, target_team, new_target)
		else:
			if prev_target != new_target:
				if prev_target >= 0:
					emit_signal("target_end", team, i, target_team, prev_target)
				if new_target >= 0:
					emit_signal("target_start", team, i, target_team, new_target)
		previous[i] = new_target
	if not force and prev_count > curr_count:
		for j in range(curr_count, prev_count):
			var prev_val: int = int(previous[j])
			if prev_val >= 0:
				emit_signal("target_end", team, j, target_team, prev_val)
	if previous.size() > curr_count:
		previous.resize(curr_count)
	return previous

# Public helper to avoid external scripts depending on internal fields
func set_movement_debug_frames(frames: int) -> void:
	if arena_state != null and arena_state.has_method("set_debug_log_frames"):
		arena_state.set_debug_log_frames(int(max(0, frames)))

func _build_resolver_emitters() -> Dictionary[String, Callable]:
	return {
		"projectile_fired": Callable(self, "_resolver_emit_projectile"),
		"log_line": Callable(self, "_resolver_emit_log"),
		"unit_stat_changed": Callable(self, "_resolver_emit_unit_stat"),
		"stats_updated": Callable(self, "_resolver_emit_stats"),
		"team_stats_updated": Callable(self, "_resolver_emit_team_stats"),
		"hit_applied": Callable(self, "_resolver_emit_hit"),
		"heal_applied": Callable(self, "_resolver_emit_heal_applied"),
		"shield_absorbed": Callable(self, "_resolver_emit_shield_absorbed"),
		"hit_mitigated": Callable(self, "_resolver_emit_hit_mitigated"),
		"hit_overkill": Callable(self, "_resolver_emit_hit_overkill"),
		"hit_components": Callable(self, "_resolver_emit_hit_components"),
		"amp_output_applied": Callable(self, "_resolver_emit_amp_output_applied"),
		"damage_redirected": Callable(self, "_resolver_emit_damage_redirected"),
		"redirect_semantic_applied": Callable(self, "_resolver_emit_redirect_semantic_applied"),
		"dot_tick_applied": Callable(self, "_resolver_emit_dot_tick_applied"),
		"reset_triggered": Callable(self, "_resolver_emit_reset_triggered"),
		"ramp_state_changed": Callable(self, "_resolver_emit_ramp_state_changed"),
		"targetability_window": Callable(self, "_resolver_emit_targetability_window"),
		"targetability_threat_interaction": Callable(self, "_resolver_emit_targetability_threat_interaction"),
		"cc_taxed": Callable(self, "_resolver_emit_cc_taxed"),
		"zone_exposure_applied": Callable(self, "_resolver_emit_zone_exposure_applied")
	}

func _filter_events_in_range(events: Array[AttackEvent]) -> Array[AttackEvent]:
	var out: Array[AttackEvent] = []
	if not state:
		return out
	const MovementMath := preload("res://scripts/game/combat/movement/math.gd")
	var ts: float = arena_state.tile_size()
	var epsilon: float = 0.5
	# Use MovementService tuning epsilon to keep parity
	if arena_state != null:
		epsilon = float(arena_state.tuning.range_epsilon)
	for evt in events:
		if evt == null:
			continue
		var team: String = evt.team
		var idx: int = evt.shooter_index
		var tgt_idx: int = evt.target_index
		var shooter: Unit = null
		if team == "player":
			if idx >= 0 and idx < state.player_team.size():
				shooter = state.player_team[idx]
		else:
			if idx >= 0 and idx < state.enemy_team.size():
				shooter = state.enemy_team[idx]
		if not shooter or not shooter.is_alive():
			continue
		var spos: Vector2 = arena_state.get_player_position(idx) if team == "player" else arena_state.get_enemy_position(idx)
		var tpos: Vector2 = arena_state.get_enemy_position(tgt_idx) if team == "player" else arena_state.get_player_position(tgt_idx)
		var prof: Variant = arena_state.get_profile(team, idx) if arena_state and arena_state.has_method("get_profile") else null
		var band_mult: float = (prof.band_max if prof != null else 1.0)
		if MovementMath.within_range(shooter, spos, tpos, ts, epsilon, band_mult):
			# One-time wind-up on first attack after being in range
			var cds: Array[float] = state.player_cds if team == "player" else state.enemy_cds
			var key: String = String(team) + ":" + str(idx)
			if not _first_attack_windup_done.has(key):
				_first_attack_windup_done[key] = true
				if idx >= 0 and idx < cds.size():
					cds[idx] = max(float(cds[idx]), float(first_attack_windup_s))
					if team == "player":
						state.player_cds = cds
					else:
						state.enemy_cds = cds
				# Skip scheduling this immediate event; it will fire after wind-up
				continue
			out.append(evt)
		else:
			# Not in range: keep shooter ready without accumulating extra cooldown debt.
			# Setting CD to max(negative small, 0) ensures at most one retry next frame.
			var cds: Array[float] = state.player_cds if team == "player" else state.enemy_cds
			if idx >= 0 and idx < cds.size():
				cds[idx] = min(float(cds[idx]), 0.0)
				if team == "player":
					state.player_cds = cds
				else:
					state.enemy_cds = cds
	return out

func _resolver_emit_projectile(team: String, source_index: int, target_index: int, damage: int, crit: bool) -> void:
	emit_signal("projectile_fired", team, source_index, target_index, damage, crit)

func _resolver_emit_log(text: String) -> void:
	emit_signal("log_line", text)

func _resolver_emit_unit_stat(team: String, index: int, fields: Dictionary) -> void:
	emit_signal("unit_stat_changed", team, index, fields)

func _resolver_emit_stats(player, enemy) -> void:
	emit_signal("stats_updated", player, enemy)

func _resolver_emit_team_stats(player_team, enemy_team) -> void:
	emit_signal("team_stats_updated", player_team, enemy_team)

func _resolver_emit_hit(team: String, source_index: int, target_index: int, rolled: int, dealt: int, crit: bool, before_hp: int, after_hp: int, player_cd: float, enemy_cd: float) -> void:
	emit_signal("hit_applied", team, source_index, target_index, rolled, dealt, crit, before_hp, after_hp, player_cd, enemy_cd)

func _resolver_emit_heal_applied(source_team: String, source_index: int, target_team: String, target_index: int, healed: int, overheal: int, before_hp: int, after_hp: int) -> void:
	emit_signal("heal_applied", source_team, source_index, target_team, target_index, healed, overheal, before_hp, after_hp)

func _resolver_emit_shield_absorbed(target_team: String, target_index: int, absorbed: int) -> void:
	emit_signal("shield_absorbed", target_team, target_index, absorbed)

func _resolver_emit_hit_mitigated(source_team: String, source_index: int, target_team: String, target_index: int, pre_mit: int, post_pre_shield: int) -> void:
	emit_signal("hit_mitigated", source_team, source_index, target_team, target_index, pre_mit, post_pre_shield)

func _resolver_emit_hit_overkill(source_team: String, source_index: int, target_team: String, target_index: int, overkill: int) -> void:
	emit_signal("hit_overkill", source_team, source_index, target_team, target_index, overkill)

func _resolver_emit_hit_components(source_team: String, source_index: int, target_team: String, target_index: int, phys: int, mag: int, tru: int) -> void:
	emit_signal("hit_components", source_team, source_index, target_team, target_index, phys, mag, tru)

func _resolver_emit_amp_output_applied(source_team: String, source_index: int, beneficiary_team: String, beneficiary_index: int, target_team: String, target_index: int, amount: float, amp_pct: float, kind: String) -> void:
	emit_signal("amp_output_applied", source_team, source_index, beneficiary_team, beneficiary_index, target_team, target_index, max(0.0, float(amount)), float(amp_pct), String(kind))

func _resolver_emit_damage_redirected(source_team: String, source_index: int, original_target_team: String, original_target_index: int, redirect_team: String, redirect_index: int, amount: int, kind: String) -> void:
	emit_signal("damage_redirected", source_team, source_index, original_target_team, original_target_index, redirect_team, redirect_index, amount, kind)

func _resolver_emit_redirect_semantic_applied(source_team: String, source_index: int, target_team: String, target_index: int, kind: String, duration_s: float, amount: float, risk_s: float) -> void:
	emit_signal("redirect_semantic_applied", source_team, source_index, target_team, target_index, String(kind), max(0.0, float(duration_s)), max(0.0, float(amount)), max(0.0, float(risk_s)))

func _resolver_emit_dot_tick_applied(source_team: String, source_index: int, target_team: String, target_index: int, amount: int, kind: String) -> void:
	emit_signal("dot_tick_applied", source_team, source_index, target_team, target_index, amount, kind)

func _resolver_emit_execute_bonus_applied(source_team: String, source_index: int, target_team: String, target_index: int, base_damage: int, bonus_damage: int, threshold_pct: float, target_hp_pct: float, kind: String) -> void:
	emit_signal("execute_bonus_applied", source_team, source_index, target_team, target_index, max(0, int(base_damage)), max(0, int(bonus_damage)), clamp(float(threshold_pct), 0.0, 1.0), clamp(float(target_hp_pct), 0.0, 1.0), String(kind))

func _resolver_emit_reset_triggered(source_team: String, source_index: int, target_team: String, target_index: int, kind: String, chain_index: int, time_since_previous_s: float, power_scale: float) -> void:
	emit_signal("reset_triggered", source_team, source_index, target_team, target_index, kind, chain_index, time_since_previous_s, power_scale)

func _resolver_emit_ramp_state_changed(source_team: String, source_index: int, kind: String, stacks: int, value: float, peak_stacks: int, duration_s: float, reason: String) -> void:
	emit_signal("ramp_state_changed", source_team, source_index, String(kind), max(0, int(stacks)), max(0.0, float(value)), max(0, int(peak_stacks)), max(0.0, float(duration_s)), String(reason))

func _resolver_emit_targetability_window(team: String, index: int, is_targetable: bool, duration: float, reason: String) -> void:
	emit_signal("targetability_window", team, index, is_targetable, duration, reason)

func _resolver_emit_targetability_threat_interaction(source_team: String, source_index: int, target_team: String, target_index: int, kind: String, cooldown_s: float, key_threat: bool, dodged: bool) -> void:
	emit_signal("targetability_threat_interaction", source_team, source_index, target_team, target_index, kind, cooldown_s, key_threat, dodged)

func _resolver_emit_ability_committed(source_team: String, source_index: int, ability_id: String, target_team: String, target_index: int, position: Vector2, cooldown_s: float, commitment_kind: String) -> void:
	emit_signal("ability_committed", source_team, source_index, ability_id, target_team, target_index, position, max(0.0, float(cooldown_s)), commitment_kind)

func _resolver_emit_cc_applied(source_team: String, source_index: int, target_team: String, target_index: int, kind: String, duration: float) -> void:
	emit_signal("cc_applied", source_team, source_index, target_team, target_index, kind, duration)

func _resolver_emit_cc_taxed(source_team: String, source_index: int, target_team: String, target_index: int, kind: String, raw_duration: float, effective_duration: float, tenacity: float, prevented: bool) -> void:
	emit_signal("cc_taxed", source_team, source_index, target_team, target_index, kind, max(0.0, float(raw_duration)), max(0.0, float(effective_duration)), max(0.0, float(tenacity)), bool(prevented))

func _resolver_emit_zone_exposure_applied(source_team: String, source_index: int, target_team: String, target_index: int, kind: String, duration_s: float, damage: float, radius_tiles: float) -> void:
	emit_signal("zone_exposure_applied", source_team, source_index, target_team, target_index, String(kind), max(0.0, float(duration_s)), max(0.0, float(damage)), max(0.0, float(radius_tiles)))

func _resolver_emit_vfx_knockup(team: String, index: int, duration: float) -> void:
	emit_signal("vfx_knockup", team, index, duration)

func _resolver_emit_vfx_beam_line(start_pos: Vector2, end: Vector2, color: Color, width: float, duration: float) -> void:
	# Visual-only signal to draw a transient beam line in the arena UI.
	emit_signal("vfx_beam_line", start_pos, end, color, width, duration)

func _on_ability_system_cast(team: String, index: int, _ability_id: String, target_team: String, target_index: int, target_point: Vector2) -> void:
	var tgt_team: String = String(target_team)
	if tgt_team == "":
		tgt_team = ("enemy" if team == "player" else "player")
	var tgt_index: int = int(target_index)
	if tgt_index < 0 and target_controller != null:
		tgt_index = target_controller.current_target(team, index)
	if tgt_index < 0:
		tgt_team = String(team)
		tgt_index = index
	var pos: Vector2 = target_point
	if arena_state != null and state != null:
		if pos == Vector2.ZERO:
			if tgt_team == "player" and tgt_index >= 0 and tgt_index < state.player_team.size():
				pos = arena_state.get_player_position(tgt_index)
			elif tgt_team == "enemy" and tgt_index >= 0 and tgt_index < state.enemy_team.size():
				pos = arena_state.get_enemy_position(tgt_index)
		if pos == Vector2.ZERO:
			if team == "player" and index >= 0 and index < state.player_team.size():
				pos = arena_state.get_player_position(index)
			elif team == "enemy" and index >= 0 and index < state.enemy_team.size():
				pos = arena_state.get_enemy_position(index)
	emit_signal("ability_cast", team, index, tgt_team, tgt_index, pos)

func _on_ability_system_committed(team: String, index: int, ability_id: String, target_team: String, target_index: int, target_point: Vector2, cooldown_s: float, commitment_kind: String) -> void:
	var tgt_team: String = String(target_team)
	if tgt_team == "":
		tgt_team = ("enemy" if team == "player" else "player")
	var tgt_index: int = int(target_index)
	if tgt_index < 0:
		tgt_team = String(team)
		tgt_index = index
	emit_signal("ability_committed", team, index, ability_id, tgt_team, tgt_index, target_point, max(0.0, float(cooldown_s)), commitment_kind)

func _on_buff_system_buff_applied(source_team: String, source_index: int, target_team: String, target_index: int, kind: String, fields: Dictionary, magnitude: float, duration: float) -> void:
	emit_signal("buff_applied", source_team, source_index, target_team, target_index, kind, fields, magnitude, duration)

func _on_buff_system_debuff_applied(source_team: String, source_index: int, target_team: String, target_index: int, kind: String, fields: Dictionary, magnitude: float, duration: float) -> void:
	emit_signal("debuff_applied", source_team, source_index, target_team, target_index, kind, fields, magnitude, duration)

func _on_buff_system_on_hit_proc(source_team: String, source_index: int, target_team: String, target_index: int, kind: String, fields: Dictionary, magnitude: float) -> void:
	emit_signal("on_hit_proc", source_team, source_index, target_team, target_index, kind, fields, magnitude)

func _on_buff_system_cc_prevented(source_team: String, source_index: int, target_team: String, target_index: int, kind: String) -> void:
	emit_signal("cc_prevented", source_team, source_index, target_team, target_index, kind)

func _on_buff_system_cc_taxed(source_team: String, source_index: int, target_team: String, target_index: int, kind: String, raw_duration: float, effective_duration: float, tenacity: float, prevented: bool) -> void:
	emit_signal("cc_taxed", source_team, source_index, target_team, target_index, kind, max(0.0, float(raw_duration)), max(0.0, float(effective_duration)), max(0.0, float(tenacity)), bool(prevented))

func _on_buff_system_cleanse_applied(source_team: String, source_index: int, target_team: String, target_index: int, removed: int) -> void:
	emit_signal("cleanse_applied", source_team, source_index, target_team, target_index, removed)
var log_position_updates: bool = false
