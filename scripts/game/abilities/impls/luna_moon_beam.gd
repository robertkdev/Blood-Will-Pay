extends AbilityImplBase

const LINE_LENGTH_TILES: float = 6.0
const LINE_WIDTH_TILES: float = 0.5
const BASE_DAMAGE: Array[int] = [260, 390, 580]
const SP_RATIO: float = 0.75

func _level_index(unit: Unit) -> int:
	var level: int = int(unit.level) if unit != null else 1
	return clamp(level - 1, 0, 2)

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
	var end_position: Vector2 = start + direction.normalized() * LINE_LENGTH_TILES * ctx.tile_size()
	if ctx.engine.has_method("_resolver_emit_vfx_beam_line"):
		ctx.engine._resolver_emit_vfx_beam_line(start, end_position, Color(0.62, 0.82, 1.0, 0.7), 2.0, 0.32)
	var damage: float = float(BASE_DAMAGE[_level_index(caster)]) + SP_RATIO * float(caster.spell_power)
	var hits: Array[int] = ctx.enemies_in_line(ctx.caster_team, ctx.caster_index, target_index, LINE_LENGTH_TILES, LINE_WIDTH_TILES)
	for hit_index: int in hits:
		ctx.damage_single(ctx.caster_team, ctx.caster_index, hit_index, damage, "magic")
	if ctx.engine.has_method("_resolver_emit_vfx_beam_line"):
		ctx.engine._resolver_emit_vfx_beam_line(start, end_position, Color(0.88, 0.97, 1.0, 1.0), 6.0, 0.16)
		ctx.engine._resolver_emit_vfx_beam_line(target_position - Vector2(10.0, 0.0), target_position + Vector2(10.0, 0.0), Color.WHITE, 8.0, 0.12)
	ctx.log("Moon Beam: aimed, then pierced %d enemies" % hits.size())
	return true
