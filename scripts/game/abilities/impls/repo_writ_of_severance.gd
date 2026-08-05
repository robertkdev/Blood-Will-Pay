extends AbilityImplBase

const RESIST_TRANSFER: Array[float] = [18.0, 28.0, 42.0]
const TRANSFER_DURATION: float = 4.0

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
	var amount: float = float(RESIST_TRANSFER[_level_index(caster)])
	ctx.buff_system.apply_stats_labeled(ctx.state, target_team, target_index, "repo_repossession_debit", {
		"armor": -amount,
		"magic_resist": -amount
	}, TRANSFER_DURATION)
	ctx.buff_system.apply_stats_labeled(ctx.state, ctx.caster_team, ctx.caster_index, "repo_repossession_credit", {
		"armor": amount,
		"magic_resist": amount
	}, TRANSFER_DURATION)
	ctx.log("Repossession: transferred %.0f Armor and MR from target %d" % [amount, target_index])
	return true
