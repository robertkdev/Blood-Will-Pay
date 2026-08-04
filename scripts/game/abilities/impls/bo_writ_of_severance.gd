extends AbilityImplBase

const CHARGE_TILES: float = 3.0
const MOVE_DURATION: float = 0.45
const KNOCKUP_DURATION: float = 0.75

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
	var charge_vector: Vector2 = direction.normalized() * CHARGE_TILES * ctx.tile_size()
	if ctx.engine.has_method("_resolver_emit_vfx_beam_line"):
		ctx.engine._resolver_emit_vfx_beam_line(start, start + charge_vector, Color(0.95, 0.82, 0.38, 0.9), 5.0, MOVE_DURATION)
	if ctx.engine.arena_state != null and ctx.engine.arena_state.has_method("notify_forced_movement"):
		ctx.engine.arena_state.notify_forced_movement(ctx.caster_team, ctx.caster_index, charge_vector, MOVE_DURATION)
	ctx.stun(target_team, target_index, KNOCKUP_DURATION)
	if ctx.engine.has_method("_resolver_emit_vfx_knockup"):
		ctx.engine._resolver_emit_vfx_knockup(target_team, target_index, KNOCKUP_DURATION)
	ctx.log("Breakthrough: charged and knocked up target %d" % target_index)
	return true
