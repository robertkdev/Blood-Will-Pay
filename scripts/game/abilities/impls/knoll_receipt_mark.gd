extends AbilityImplBase

const STUN_DURATION: float = 1.05
const MARK_DURATION: float = 4.0
const DEFENSE_SHRED: float = 18.0

func cast(ctx: AbilityContext) -> bool:
	if ctx == null or ctx.engine == null or ctx.state == null or ctx.buff_system == null:
		return false
	var caster: Unit = ctx.unit_at(ctx.caster_team, ctx.caster_index)
	var target_index: int = ctx.current_target(ctx.caster_team, ctx.caster_index)
	if caster == null or not caster.is_alive():
		return false
	if target_index < 0:
		target_index = ctx.lowest_hp_enemy(ctx.caster_team)
	if target_index < 0:
		return false
	var target_team: String = ctx._other_team(ctx.caster_team)
	ctx.stun(target_team, target_index, STUN_DURATION)
	ctx.apply_stats_labeled(target_team, target_index, "knoll_receipt_mark", {
		"armor": -DEFENSE_SHRED,
		"magic_resist": -DEFENSE_SHRED
	}, MARK_DURATION)
	ctx.buff_system.record_debuff(ctx.state, target_team, target_index, "receipt_mark", {"marked": true}, DEFENSE_SHRED, MARK_DURATION)
	ctx.log("Receipt Mark: target %d stunned and defenses shredded" % target_index)
	return true
