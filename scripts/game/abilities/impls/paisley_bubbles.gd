extends AbilityImplBase

const SHIELD_BASE: Array[int] = [100, 150, 225]
const SHIELD_SP_RATIO: float = 0.6
const SHIELD_DURATION: float = 2.5
const POP_DAMAGE: Array[int] = [110, 165, 260]
const POP_SP_RATIO: float = 0.7
const POP_RADIUS_TILES: float = 1.0
const POP_STUN_DURATION: float = 0.4

func _level_index(unit: Unit) -> int:
	var level: int = int(unit.level) if unit != null else 1
	return clamp(level - 1, 0, 2)

func cast(ctx: AbilityContext) -> bool:
	if ctx == null or ctx.engine == null or ctx.state == null or ctx.buff_system == null:
		return false
	var caster: Unit = ctx.unit_at(ctx.caster_team, ctx.caster_index)
	if caster == null or not caster.is_alive():
		return false
	var level_index: int = _level_index(caster)
	var shield_amount: int = int(round(float(SHIELD_BASE[level_index]) + SHIELD_SP_RATIO * float(caster.spell_power)))
	var pop_damage: int = int(round(float(POP_DAMAGE[level_index]) + POP_SP_RATIO * float(caster.spell_power)))
	var targets: Array[int] = _two_weakest_allies(ctx)
	for ally_index: int in targets:
		var pop_data: Dictionary = {
			"kind": "paisley_bubble_pop",
			"source_team": ctx.caster_team,
			"source_index": ctx.caster_index,
			"damage": pop_damage,
			"radius_tiles": POP_RADIUS_TILES,
			"stun_duration": POP_STUN_DURATION,
			"ability_power_scale": clampf(ctx.power_scale, 0.0, 1.0),
			"pop_on_break_or_expiry": true
		}
		ctx.apply_shield(ctx.caster_team, ally_index, shield_amount, SHIELD_DURATION, pop_data)
	ctx.log("Bubbles: shielded %d weak allies; each bubble pops locally" % targets.size())
	return not targets.is_empty()

func _two_weakest_allies(ctx: AbilityContext) -> Array[int]:
	var ranked: Array[Dictionary] = []
	var allies: Array[Unit] = ctx.ally_team_array(ctx.caster_team)
	for index: int in range(allies.size()):
		var ally: Unit = allies[index]
		if ally == null or not ally.is_alive():
			continue
		ranked.append({"index": index, "ratio": float(ally.hp) / max(1.0, float(ally.max_hp))})
	ranked.sort_custom(func(first: Dictionary, second: Dictionary) -> bool:
		return float(first.get("ratio", 1.0)) < float(second.get("ratio", 1.0))
	)
	var output: Array[int] = []
	for ranked_index: int in range(min(2, ranked.size())):
		output.append(int(ranked[ranked_index].get("index", -1)))
	return output
