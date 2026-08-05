extends AbilityImplBase

const HEAL_BASE: Array[int] = [125, 190, 285]
const SP_RATIO: float = 0.55
const KNOT_DURATION: float = 1.5

func _level_index(unit: Unit) -> int:
	var level: int = int(unit.level) if unit != null else 1
	return clamp(level - 1, 0, 2)

func cast(ctx: AbilityContext) -> bool:
	if ctx == null or ctx.engine == null or ctx.state == null or ctx.buff_system == null:
		return false
	var caster: Unit = ctx.unit_at(ctx.caster_team, ctx.caster_index)
	var ally_index: int = ctx.lowest_hp_ally(ctx.caster_team)
	if caster == null or not caster.is_alive() or ally_index < 0:
		return false
	var threat_index: int = _nearest_threat_to_ally(ctx, ally_index)
	if threat_index < 0:
		return false
	var threat_team: String = ctx._other_team(ctx.caster_team)
	var ally_position: Vector2 = ctx.position_of(ctx.caster_team, ally_index)
	var threat_position: Vector2 = ctx.position_of(threat_team, threat_index)
	if ctx.engine.has_method("_resolver_emit_vfx_beam_line"):
		ctx.engine._resolver_emit_vfx_beam_line(ally_position, threat_position, Color(0.86, 0.42, 0.82, 0.95), 4.0, KNOT_DURATION)
	ctx.buff_system.apply_tag(ctx.state, threat_team, threat_index, "root", KNOT_DURATION, {
		"is_debuff": true,
		"cleanseable": true,
		"kind": "velour_silk_knot"
	})
	var heal_amount: float = float(HEAL_BASE[_level_index(caster)]) + SP_RATIO * float(caster.spell_power)
	ctx.heal_single(ctx.caster_team, ally_index, heal_amount)
	ctx.log("Silk Knot: rooted threat %d and healed ally %d while linked" % [threat_index, ally_index])
	return true

func _nearest_threat_to_ally(ctx: AbilityContext, ally_index: int) -> int:
	var ally_position: Vector2 = ctx.position_of(ctx.caster_team, ally_index)
	var threat_team: String = ctx._other_team(ctx.caster_team)
	var enemies: Array[Unit] = ctx.enemy_team_array(ctx.caster_team)
	var best_index: int = -1
	var best_distance: float = INF
	for index: int in range(enemies.size()):
		var enemy: Unit = enemies[index]
		if enemy == null or not enemy.is_alive():
			continue
		var distance: float = ally_position.distance_to(ctx.position_of(threat_team, index))
		if distance < best_distance:
			best_distance = distance
			best_index = index
	return best_index
