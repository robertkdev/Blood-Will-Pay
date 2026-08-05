extends AbilityImplBase

const MovementMath := preload("res://scripts/game/combat/movement/math.gd")

const DISARM_DURATION: float = 1.25
const MOVE_DURATION: float = 0.24

func cast(ctx: AbilityContext) -> bool:
	if ctx == null or ctx.engine == null or ctx.state == null or ctx.buff_system == null:
		return false
	var caster: Unit = ctx.unit_at(ctx.caster_team, ctx.caster_index)
	var farthest: Array[int] = ctx.two_furthest_enemies(ctx.caster_team)
	if caster == null or not caster.is_alive() or farthest.is_empty():
		return false
	var target_index: int = int(farthest[0])
	var target_team: String = ctx._other_team(ctx.caster_team)
	var caster_position: Vector2 = ctx.position_of(ctx.caster_team, ctx.caster_index)
	var target_position: Vector2 = ctx.position_of(target_team, target_index)
	_set_position(ctx, ctx.caster_team, ctx.caster_index, target_position)
	_set_position(ctx, target_team, target_index, caster_position)
	ctx.buff_system.apply_tag(ctx.state, target_team, target_index, "disarm", DISARM_DURATION, {
		"is_debuff": true,
		"cleanseable": true,
		"kind": "pilfer_pocket_swap_disarm"
	})
	ctx.log("Pocket Swap: swapped with far target %d and disarmed it" % target_index)
	return true

func _set_position(ctx: AbilityContext, team: String, index: int, destination: Vector2) -> void:
	if ctx.engine.arena_state == null:
		return
	var movement_data: Variant = ctx.engine.arena_state.data
	if movement_data == null:
		return
	var clamped: Vector2 = MovementMath.clamp_to_rect(destination, movement_data.arena_bounds)
	var start: Vector2 = ctx.position_of(team, index)
	if ctx.engine.arena_state.has_method("notify_forced_movement"):
		ctx.engine.arena_state.notify_forced_movement(team, index, clamped - start, MOVE_DURATION)
	if team == "player" and index >= 0 and index < movement_data.player_positions.size():
		movement_data.player_positions[index] = clamped
	elif team == "enemy" and index >= 0 and index < movement_data.enemy_positions.size():
		movement_data.enemy_positions[index] = clamped
	if ctx.engine.has_signal("position_updated"):
		ctx.engine.emit_signal("position_updated", team, index, clamped.x, clamped.y)
