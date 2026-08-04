extends AbilityImplBase

const KNOCKUP_DURATION: float = 0.75
const RADIUS_TILES: float = 1.25
const LEAP_TILES: float = 1.5
const MOVE_DURATION: float = 0.25

func cast(ctx: AbilityContext) -> bool:
	if ctx == null or ctx.engine == null or ctx.state == null or ctx.buff_system == null:
		return false
	var caster: Unit = ctx.unit_at(ctx.caster_team, ctx.caster_index)
	if caster == null or not caster.is_alive():
		return false
	var target_index: int = ctx.current_target(ctx.caster_team, ctx.caster_index)
	if target_index < 0:
		target_index = ctx.lowest_hp_enemy(ctx.caster_team)
	if target_index < 0:
		return false
	var target_team: String = ctx._other_team(ctx.caster_team)
	var start: Vector2 = ctx.position_of(ctx.caster_team, ctx.caster_index)
	var target_position: Vector2 = ctx.position_of(target_team, target_index)
	var direction: Vector2 = target_position - start
	var leap_vector: Vector2 = Vector2.ZERO
	if direction.length() > 0.001:
		leap_vector = direction.normalized() * min(direction.length(), LEAP_TILES * ctx.tile_size())
	if leap_vector.length() > 0.001 and ctx.engine.arena_state != null and ctx.engine.arena_state.has_method("notify_forced_movement"):
		ctx.engine.arena_state.notify_forced_movement(ctx.caster_team, ctx.caster_index, leap_vector, MOVE_DURATION)
	var impact_center: Vector2 = start + leap_vector
	var victims: Array[int] = ctx.enemies_in_radius_at(ctx.caster_team, impact_center, RADIUS_TILES)
	for victim_index: int in victims:
		ctx.stun(target_team, victim_index, KNOCKUP_DURATION)
		if ctx.engine.has_method("_resolver_emit_vfx_knockup"):
			ctx.engine._resolver_emit_vfx_knockup(target_team, victim_index, KNOCKUP_DURATION)
	ctx.log("Slam: leapt and knocked up %d nearby enemies" % victims.size())
	return true
