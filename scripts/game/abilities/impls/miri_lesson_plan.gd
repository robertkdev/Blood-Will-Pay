extends AbilityImplBase

const SHIELD_BASE: Array[int] = [120, 190, 290]
const SP_RATIO: float = 0.45
const SHIELD_DURATION: float = 5.0
const ENGAGE_TILES: float = 1.1
const MOVE_DURATION: float = 0.22
const ARRIVAL_STUN_DURATION: float = 1.05

func _level_index(unit: Unit) -> int:
	var level: int = int(unit.level) if unit != null else 1
	return clamp(level - 1, 0, 2)

func cast(ctx: AbilityContext) -> bool:
	if ctx == null or ctx.engine == null or ctx.state == null or ctx.buff_system == null:
		return false
	var caster: Unit = ctx.unit_at(ctx.caster_team, ctx.caster_index)
	if caster == null or not caster.is_alive():
		return false
	var student_index: int = _student_for(ctx, caster)
	var enemy_index: int = ctx.lowest_hp_enemy(ctx.caster_team)
	if student_index < 0 or enemy_index < 0:
		return false
	var shield_amount: int = int(round(float(SHIELD_BASE[_level_index(caster)]) + SP_RATIO * float(caster.spell_power)))
	ctx.apply_shield(ctx.caster_team, student_index, shield_amount, SHIELD_DURATION)
	var student_position: Vector2 = ctx.position_of(ctx.caster_team, student_index)
	var enemy_position: Vector2 = ctx.position_of(ctx._other_team(ctx.caster_team), enemy_index)
	var direction: Vector2 = enemy_position - student_position
	if direction.length() > 0.001 and ctx.engine.arena_state != null and ctx.engine.arena_state.has_method("notify_forced_movement"):
		ctx.engine.arena_state.notify_forced_movement(ctx.caster_team, student_index, direction.normalized() * ENGAGE_TILES * ctx.tile_size(), MOVE_DURATION)
	ctx.stun(ctx._other_team(ctx.caster_team), enemy_index, ARRIVAL_STUN_DURATION)
	ctx.log("Lesson Plan: sent shielded Student %d to stun target %d" % [student_index, enemy_index])
	return true

func _student_for(ctx: AbilityContext, caster: Unit) -> int:
	var allies: Array[Unit] = ctx.ally_team_array(ctx.caster_team)
	var fallback: int = -1
	for index: int in range(allies.size()):
		var ally: Unit = allies[index]
		if ally == null or not ally.is_alive() or index == ctx.caster_index:
			continue
		if fallback < 0:
			fallback = index
		if not _shares_trait(caster, ally):
			return index
	return fallback

func _shares_trait(first: Unit, second: Unit) -> bool:
	for first_trait: String in first.traits:
		for second_trait: String in second.traits:
			if first_trait == second_trait:
				return true
	return false
