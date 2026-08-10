extends AbilityImplBase

const BuffTags := preload("res://scripts/game/abilities/buff_tags.gd")

const DURATION: float = 5.0
const MISSING_HP_DAMAGE: Array[float] = [0.12, 0.16, 0.20]
const ATTACK_HEALING: Array[float] = [0.30, 0.45, 0.55]

func _level_index(unit: Unit) -> int:
	var level: int = int(unit.level) if unit != null else 1
	return clamp(level - 1, 0, 2)

func cast(ctx: AbilityContext) -> bool:
	if ctx == null or ctx.state == null or ctx.buff_system == null:
		return false
	var caster: Unit = ctx.unit_at(ctx.caster_team, ctx.caster_index)
	if caster == null or not caster.is_alive():
		return false
	var level_index: int = _level_index(caster)
	ctx.apply_stats_buff(ctx.caster_team, ctx.caster_index, {
		"lifesteal": float(ATTACK_HEALING[level_index])
	}, DURATION)
	ctx.buff_system.apply_tag(ctx.state, ctx.caster_team, ctx.caster_index, BuffTags.TAG_BEREBELL, DURATION, {
		"missing_pct": ctx.scale_power(float(MISSING_HP_DAMAGE[level_index]))
	})
	ctx.log("Unstable: attacks punish wounded targets and heal Berebell for %.1fs" % DURATION)
	return true
