extends AbilityImplBase

const MovementMath = preload("res://scripts/game/combat/movement/math.gd")

const DAMAGE_BASE: Array[int] = [260, 390, 585]
const AD_RATIO: float = 1.25
const CLEAVE_RADIUS_TILES: float = 1.85
const HOOK_TILES: float = 2.1
const MOVE_DURATION: float = 0.18
const STUN_DURATION: float = 0.8

func _level_index(unit: Unit) -> int:
	var level: int = int(unit.level) if unit != null else 1
	return clamp(level - 1, 0, 2)

func _enemy_team(team: String) -> String:
	return "enemy" if team == "player" else "player"

func cast(ctx: AbilityContext) -> bool:
	if ctx == null or ctx.engine == null or ctx.state == null:
		return false
	var caster: Unit = ctx.unit_at(ctx.caster_team, ctx.caster_index)
	if caster == null or not caster.is_alive():
		return false
	var target_index: int = _furthest_enemy(ctx)
	if target_index < 0:
		return false
	var target_team: String = _enemy_team(ctx.caster_team)
	_hook_target_toward_caster(ctx, target_team, target_index)
	ctx.stun(target_team, target_index, STUN_DURATION)
	var center: Vector2 = ctx.position_of(target_team, target_index)
	var victims: Array[int] = ctx.enemies_in_radius_at(ctx.caster_team, center, CLEAVE_RADIUS_TILES)
	if victims.is_empty():
		victims.append(target_index)
	var damage: float = float(DAMAGE_BASE[_level_index(caster)]) + AD_RATIO * float(caster.attack_damage)
	for victim_index: int in victims:
		ctx.damage_single(ctx.caster_team, ctx.caster_index, victim_index, damage, "physical")
	ctx.log("Colossus Hook: pulled target %d and cleaved %d enemies" % [target_index, victims.size()])
	return true

func _furthest_enemy(ctx: AbilityContext) -> int:
	var enemies: Array[Unit] = ctx.enemy_team_array(ctx.caster_team)
	var target_team: String = _enemy_team(ctx.caster_team)
	var caster_position: Vector2 = ctx.position_of(ctx.caster_team, ctx.caster_index)
	var best_index: int = -1
	var best_distance: float = -1.0
	for index: int in range(enemies.size()):
		var enemy: Unit = enemies[index]
		if enemy == null or not enemy.is_alive():
			continue
		var distance: float = caster_position.distance_to(ctx.position_of(target_team, index))
		if distance > best_distance:
			best_distance = distance
			best_index = index
	return best_index

func _hook_target_toward_caster(ctx: AbilityContext, target_team: String, target_index: int) -> void:
	var target_position: Vector2 = ctx.position_of(target_team, target_index)
	var caster_position: Vector2 = ctx.position_of(ctx.caster_team, ctx.caster_index)
	var delta: Vector2 = caster_position - target_position
	if delta.length() <= 0.001:
		return
	var destination: Vector2 = target_position + delta.normalized() * HOOK_TILES * ctx.tile_size()
	if ctx.engine.arena_state != null and ctx.engine.arena_state.has_method("notify_forced_movement"):
		ctx.engine.arena_state.notify_forced_movement(target_team, target_index, destination - target_position, MOVE_DURATION)
	_set_unit_position(ctx, target_team, target_index, destination)

func _set_unit_position(ctx: AbilityContext, team: String, index: int, destination: Vector2) -> void:
	if ctx.engine.arena_state == null or ctx.engine.arena_state.data == null:
		return
	var movement_data: Variant = ctx.engine.arena_state.data
	var clamped: Vector2 = MovementMath.clamp_to_rect(destination, movement_data.arena_bounds)
	if team == "player" and index >= 0 and index < movement_data.player_positions.size():
		movement_data.player_positions[index] = clamped
	elif team == "enemy" and index >= 0 and index < movement_data.enemy_positions.size():
		movement_data.enemy_positions[index] = clamped
	if ctx.engine.has_signal("position_updated"):
		ctx.engine.emit_signal("position_updated", team, index, clamped.x, clamped.y)
