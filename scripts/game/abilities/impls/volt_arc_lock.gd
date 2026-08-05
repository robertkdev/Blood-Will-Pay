extends AbilityImplBase

const STUN_DURATION: float = 1.0
const BASE_DAMAGE: Array[int] = [215, 325, 485]
const SP_RATIO: float = 0.75

func _level_index(unit: Unit) -> int:
	var level: int = int(unit.level) if unit != null else 1
	return clamp(level - 1, 0, 2)

func cast(ctx: AbilityContext) -> bool:
	if ctx == null or ctx.engine == null or ctx.state == null or ctx.buff_system == null:
		return false
	var caster: Unit = ctx.unit_at(ctx.caster_team, ctx.caster_index)
	var target_index: int = ctx.current_target(ctx.caster_team, ctx.caster_index)
	if caster == null or not caster.is_alive() or target_index < 0:
		return false
	var target_team: String = ctx._other_team(ctx.caster_team)
	var start: Vector2 = ctx.position_of(ctx.caster_team, ctx.caster_index)
	var target_position: Vector2 = ctx.position_of(target_team, target_index)
	if ctx.engine.has_method("_resolver_emit_vfx_beam_line"):
		ctx.engine._resolver_emit_vfx_beam_line(start, target_position, Color(0.42, 0.78, 1.0, 0.95), 4.0, 0.22)
		ctx.engine._resolver_emit_vfx_beam_line(target_position - Vector2(0.0, 12.0), target_position + Vector2(0.0, 12.0), Color(0.75, 0.92, 1.0, 1.0), 7.0, STUN_DURATION)
	var damage: float = float(BASE_DAMAGE[_level_index(caster)]) + SP_RATIO * float(caster.spell_power)
	ctx.damage_single(ctx.caster_team, ctx.caster_index, target_index, damage, "magic")
	ctx.stun(target_team, target_index, STUN_DURATION)
	ctx.log("Arc Lock: caged target %d, dealt %d magic, and stunned" % [target_index, int(round(damage))])
	return true
