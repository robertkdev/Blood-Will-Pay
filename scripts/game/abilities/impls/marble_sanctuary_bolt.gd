extends AbilityImplBase

const DAMAGE_BASE: Array[int] = [260, 390, 585]
const AD_RATIO: float = 1.55
const SHIELD_BASE: Array[int] = [150, 225, 335]
const SHIELD_DURATION: float = 4.0
const DEBUFF_DURATION: float = 4.5
const ATTACK_SPEED_SLOW: float = -0.22

func _level_index(unit: Unit) -> int:
	var level: int = int(unit.level) if unit != null else 1
	return clamp(level - 1, 0, 2)

func _enemy_team(team: String) -> String:
	return "enemy" if team == "player" else "player"

func cast(ctx: AbilityContext) -> bool:
	if ctx == null or ctx.engine == null or ctx.state == null:
		return false
	var caster: Unit = ctx.unit_at(ctx.caster_team, ctx.caster_index)
	if caster == null or not caster.is_alive():
		return false
	var level_index: int = _level_index(caster)
	var ally_index: int = ctx.lowest_hp_ally(ctx.caster_team)
	if ally_index >= 0 and ctx.buff_system != null:
		ctx.buff_system.apply_shield(ctx.state, ctx.caster_team, ally_index, SHIELD_BASE[level_index], SHIELD_DURATION)
	var targets: Array[int] = ctx.two_furthest_enemies(ctx.caster_team)
	if targets.is_empty():
		return ally_index >= 0
	var target_index: int = targets[0]
	var target_team: String = _enemy_team(ctx.caster_team)
	var damage: float = float(DAMAGE_BASE[level_index]) + AD_RATIO * float(caster.attack_damage)
	ctx.damage_single(ctx.caster_team, ctx.caster_index, target_index, damage, "physical")
	if ctx.buff_system != null:
		ctx.buff_system.apply_stats_labeled(ctx.state, target_team, target_index, "marble_sanctuary_bolt", {
			"attack_speed": ATTACK_SPEED_SLOW
		}, DEBUFF_DURATION)
	ctx.log("Sanctuary Bolt: shielded ally %d and tagged enemy %d" % [ally_index, target_index])
	return true
