extends AbilityImplBase

const KNOCKBACK_TILES: float = 1.25
const DASH_MAX_TILES: float = 1.2
const MOVE_DURATION: float = 0.20

func cast(ctx: AbilityContext) -> bool:
	if ctx == null or ctx.engine == null or ctx.state == null:
		return false
	var caster: Unit = ctx.unit_at(ctx.caster_team, ctx.caster_index)
	var target_index: int = ctx.current_target(ctx.caster_team, ctx.caster_index)
	if caster == null or not caster.is_alive() or target_index < 0:
		return false
	var target_team: String = ctx._other_team(ctx.caster_team)
	var start: Vector2 = ctx.position_of(ctx.caster_team, ctx.caster_index)
	var target_position: Vector2 = ctx.position_of(target_team, target_index)
	var direction: Vector2 = target_position - start
	if direction.length() <= 0.001:
		return false
	var forward: Vector2 = direction.normalized()
	var dash_vector: Vector2 = forward * min(direction.length(), DASH_MAX_TILES * ctx.tile_size())
	var knockback_vector: Vector2 = forward * KNOCKBACK_TILES * ctx.tile_size()
	if ctx.engine.has_method("_resolver_emit_vfx_beam_line"):
		ctx.engine._resolver_emit_vfx_beam_line(start, target_position + knockback_vector, Color(1.0, 0.85, 0.4, 0.95), 4.0, MOVE_DURATION)
	if ctx.engine.arena_state != null and ctx.engine.arena_state.has_method("notify_forced_movement"):
		ctx.engine.arena_state.notify_forced_movement(ctx.caster_team, ctx.caster_index, dash_vector, MOVE_DURATION)
		ctx.engine.arena_state.notify_forced_movement(target_team, target_index, knockback_vector, MOVE_DURATION)
	ctx.log("Body Check: displaced target %d away from its carry line" % target_index)
	return true
