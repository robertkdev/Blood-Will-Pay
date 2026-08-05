extends AbilityImplBase

const BuffTags := preload("res://scripts/game/abilities/buff_tags.gd")

const BONUS_ARROW_KEY: String = "nyxa_cv_bonus_arrows"
const EMPOWERED_ATTACKS: int = 4

func cast(ctx: AbilityContext) -> bool:
	if ctx == null or ctx.state == null or ctx.buff_system == null:
		return false
	var caster: Unit = ctx.unit_at(ctx.caster_team, ctx.caster_index)
	if caster == null or not caster.is_alive():
		return false
	var current_bonus: int = int(ctx.buff_system.get_stack(ctx.state, ctx.caster_team, ctx.caster_index, BONUS_ARROW_KEY))
	var new_bonus: int = min(3, current_bonus + 1)
	if new_bonus > current_bonus:
		ctx.buff_system.add_stack(ctx.state, ctx.caster_team, ctx.caster_index, BONUS_ARROW_KEY, 1)
	var duration: float = clamp(float(EMPOWERED_ATTACKS) / max(0.1, float(caster.attack_speed)), 2.0, 8.0)
	ctx.buff_system.apply_tag(ctx.state, ctx.caster_team, ctx.caster_index, BuffTags.TAG_NYXA, duration, {
		"extra": new_bonus,
		"damage_bonus": 0,
		"attacks_left": EMPOWERED_ATTACKS
	})
	ctx.emit_ramp_state("stack_window", 1 + new_bonus, float(1 + new_bonus), 4, duration, "nyxa_chaos_volley")
	ctx.log("Chaos Volley: next four attacks fire %d arrows" % (1 + new_bonus))
	return true
