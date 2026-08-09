extends AbilityImplBase

# Creep — Eavesdropping
# Dives into the enemy backline and spins in place, dealing AoE physical damage in rapid ticks.
# Exiled upgrade: longer duration, stronger ticks, first takedown during spin causes a chase to the next lowest-health enemy.

const BuffTags := preload("res://scripts/game/abilities/buff_tags.gd")
const MovementMath := preload("res://scripts/game/combat/movement/math.gd")

const TICK_INTERVAL: float = 0.2
const RADIUS_TILES: float = 2.3
const DR_DURING_SPIN: float = 0.30
const DASH_OVERSHOOT_TILES: float = 0.75
const MOVE_DURATION: float = 0.22

# Per-tick AD multipliers (base) by level 1/2/3
const PER_TICK_AD_BASE: Array[float] = [0.45, 0.70, 1.05]

func _level_index(u: Unit) -> int:
	var lvl: int = (int(u.level) if u != null else 1)
	return clamp(lvl - 1, 0, 2)

func _exile_active(ctx: AbilityContext) -> bool:
	if ctx == null:
		return false
	return ctx.exile_upgrade_level(ctx.caster_team, ctx.caster_index) > 0

func _other(team: String) -> String:
	return "enemy" if team == "player" else "player"

func cast(ctx: AbilityContext) -> bool:
	if ctx == null or ctx.engine == null or ctx.state == null:
		return false
	var bs: BuffSystem = ctx.buff_system
	if bs == null:
		ctx.log("[Eavesdropping] BuffSystem not available; cast aborted")
		return false
	var caster: Unit = ctx.unit_at(ctx.caster_team, ctx.caster_index)
	if caster == null or not caster.is_alive():
		return false

	var target_idx: int = _priority_backline_enemy(ctx)
	if target_idx < 0:
		return false
	_set_current_target(ctx, target_idx)

	var exiled: bool = _exile_active(ctx)
	var li: int = _level_index(caster)
	var duration: float = (1.25 if exiled else 1.00)
	var ticks: int = max(1, int(floor((duration + 1e-4) / TICK_INTERVAL)))
	var per_tick_mult: float = float(PER_TICK_AD_BASE[li]) * (1.25 if exiled else 1.0)
	var per_tick_damage: int = int(max(0.0, round(per_tick_mult * float(caster.attack_damage))))

	var target_team: String = _other(ctx.caster_team)
	var center: Vector2 = _dash_to_enemy_backline(ctx, target_team, target_idx)

	# Apply CC-immune tag and temporary damage reduction while spinning
	bs.apply_tag(ctx.state, ctx.caster_team, ctx.caster_index, BuffTags.TAG_CC_IMMUNE, duration, {"block_mana_gain": true})
	ctx.apply_stats_buff(ctx.caster_team, ctx.caster_index, {"damage_reduction": DR_DURING_SPIN}, duration)

	# Schedule ticking damage via AbilitySystem events
	var data: Dictionary = {
		"center": center,
		"damage": per_tick_damage,
		"radius": float(RADIUS_TILES),
		"ticks_left": ticks,
		"interval": float(TICK_INTERVAL),
		"exiled": exiled,
		"allow_chase": exiled,
		"chase_used": false,
		"shred_pct": 0.10,
		"shred_dur": 3.0
	}
	if ctx.engine != null and ctx.engine.ability_system != null:
		ctx.schedule_event("creep_eaves_tick", ctx.caster_team, ctx.caster_index, 0.0, data)
	ctx.log("Eavesdropping: spin %.2fs, %d ticks, %d per tick" % [duration, ticks, per_tick_damage])
	return true

func _priority_backline_enemy(ctx: AbilityContext) -> int:
	var enemies: Array[Unit] = ctx.enemy_team_array(ctx.caster_team)
	var target_team: String = _other(ctx.caster_team)
	var side_sign: float = 1.0 if ctx.caster_team == "player" else -1.0
	var candidates: Array[Dictionary] = []
	for enemy_index: int in range(enemies.size()):
		var enemy: Unit = enemies[enemy_index]
		if enemy == null or not ctx.is_targetable(target_team, enemy_index):
			continue
		var position: Vector2 = ctx.position_of(target_team, enemy_index)
		candidates.append({
			"idx": enemy_index,
			"depth": position.x * side_sign,
			"hp": int(enemy.hp)
		})
	if candidates.is_empty():
		return -1
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var depth_a: float = float(a.get("depth", 0.0))
		var depth_b: float = float(b.get("depth", 0.0))
		if not is_equal_approx(depth_a, depth_b):
			return depth_a > depth_b
		return int(a.get("hp", 0)) < int(b.get("hp", 0))
	)
	var backline_count: int = max(1, int(ceil(float(candidates.size()) * 0.5)))
	var best_index: int = -1
	var best_hp: int = 1 << 30
	for candidate_index: int in range(backline_count):
		var candidate: Dictionary = candidates[candidate_index]
		var hp: int = int(candidate.get("hp", best_hp))
		if hp < best_hp:
			best_hp = hp
			best_index = int(candidate.get("idx", -1))
	return best_index

func _set_current_target(ctx: AbilityContext, target_index: int) -> void:
	if ctx == null or ctx.state == null:
		return
	if ctx.caster_team == "player":
		if ctx.caster_index >= 0 and ctx.caster_index < ctx.state.player_targets.size():
			ctx.state.player_targets[ctx.caster_index] = target_index
	else:
		if ctx.caster_index >= 0 and ctx.caster_index < ctx.state.enemy_targets.size():
			ctx.state.enemy_targets[ctx.caster_index] = target_index

func _dash_to_enemy_backline(ctx: AbilityContext, target_team: String, target_index: int) -> Vector2:
	var start: Vector2 = ctx.position_of(ctx.caster_team, ctx.caster_index)
	var target_pos: Vector2 = ctx.position_of(target_team, target_index)
	var sign_x: float = 1.0 if ctx.caster_team == "player" else -1.0
	var backline_x: float = target_pos.x
	var found_enemy: bool = false
	var enemies: Array[Unit] = ctx.enemy_team_array(ctx.caster_team)
	for enemy_index: int in range(enemies.size()):
		var enemy: Unit = enemies[enemy_index]
		if enemy == null or not enemy.is_alive():
			continue
		var enemy_pos: Vector2 = ctx.position_of(target_team, enemy_index)
		if not found_enemy:
			backline_x = enemy_pos.x
			found_enemy = true
		elif sign_x > 0.0:
			backline_x = max(backline_x, enemy_pos.x)
		else:
			backline_x = min(backline_x, enemy_pos.x)
	var tile: float = ctx.tile_size()
	var destination: Vector2 = Vector2(backline_x + sign_x * DASH_OVERSHOOT_TILES * tile, target_pos.y)
	var clamped: Vector2 = destination
	if ctx.engine.arena_state != null and ctx.engine.arena_state.data != null:
		clamped = MovementMath.clamp_to_rect(destination, ctx.engine.arena_state.data.arena_bounds)
	var delta: Vector2 = clamped - start
	if ctx.engine.arena_state != null and ctx.engine.arena_state.has_method("notify_forced_movement") and delta.length() > 0.001:
		ctx.engine.arena_state.notify_forced_movement(ctx.caster_team, ctx.caster_index, delta, MOVE_DURATION)
	return clamped

func _emit_position(ctx: AbilityContext, position: Vector2) -> void:
	if ctx.engine.has_signal("position_updated"):
		ctx.engine.emit_signal("position_updated", ctx.caster_team, ctx.caster_index, position.x, position.y)
