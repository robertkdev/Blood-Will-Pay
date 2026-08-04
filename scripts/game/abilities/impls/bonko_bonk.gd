extends AbilityImplBase

const BASE_DAMAGE: Array[int] = [150, 225, 340]
const AD_RATIO: float = 1.0
const STUNNED_BONUS_RATIO: float = 0.5
const STUN_DURATION: float = 1.0

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
	var target: Unit = ctx.unit_at(target_team, target_index)
	if target == null or not target.is_alive():
		return false
	var was_stunned: bool = ctx.buff_system.is_stunned(target)
	var damage: float = float(BASE_DAMAGE[_level_index(caster)]) + AD_RATIO * float(caster.attack_damage)
	if was_stunned:
		damage *= 1.0 + STUNNED_BONUS_RATIO
	ctx.damage_single(ctx.caster_team, ctx.caster_index, target_index, damage, "physical")
	ctx.stun(target_team, target_index, STUN_DURATION)
	ctx.log("BONK: target %d%s" % [target_index, " (stunned bonus)" if was_stunned else ""])
	return true
