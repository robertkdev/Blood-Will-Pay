extends AbilityImplBase

const HEAL_BASE: Array[int] = [300, 450, 675]
const SHIELD_DURATION: float = 4.5

func _level_index(unit: Unit) -> int:
	var level: int = int(unit.level) if unit != null else 1
	return clamp(level - 1, 0, 2)

func cast(ctx: AbilityContext) -> bool:
	if ctx == null or ctx.engine == null or ctx.state == null:
		return false
	var caster: Unit = ctx.unit_at(ctx.caster_team, ctx.caster_index)
	if caster == null or not caster.is_alive():
		return false
	var ally_index: int = _most_threatened_ally(ctx)
	if ally_index < 0:
		return false
	var ally: Unit = ctx.unit_at(ctx.caster_team, ally_index)
	if ally == null:
		return false
	var heal_amount: float = float(HEAL_BASE[_level_index(caster)]) + 0.65 * float(caster.spell_power)
	var missing_hp: int = max(0, int(ally.max_hp) - int(ally.hp))
	var heal_result: Dictionary = ctx.heal_single(ctx.caster_team, ally_index, heal_amount)
	var overheal: int = max(0, int(round(heal_amount)) - missing_hp)
	if overheal > 0 and ctx.buff_system != null:
		ctx.buff_system.apply_shield(ctx.state, ctx.caster_team, ally_index, overheal, SHIELD_DURATION)
		ctx.buff_system.record_buff(ctx.state, ctx.caster_team, ally_index, "saffron_overheal_shield", {"overheal": overheal}, float(overheal), SHIELD_DURATION)
	ctx.log("Golden Poultice: healed ally %d and converted %d overheal into shield" % [ally_index, overheal])
	return bool(heal_result.get("processed", false))

func _most_threatened_ally(ctx: AbilityContext) -> int:
	var allies: Array[Unit] = ctx.ally_team_array(ctx.caster_team)
	var best_index: int = -1
	var best_score: float = INF
	for index: int in range(allies.size()):
		var ally: Unit = allies[index]
		if ally == null or not ally.is_alive():
			continue
		var score: float = float(ally.hp) / max(1.0, float(ally.max_hp))
		if index == ctx.caster_index:
			score += 0.2
		if score < best_score:
			best_score = score
			best_index = index
	return best_index
