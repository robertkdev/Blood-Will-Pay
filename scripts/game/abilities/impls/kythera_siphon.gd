extends AbilityImplBase

const TraitKeys := preload("res://scripts/game/traits/runtime/trait_keys.gd")
const BuffTags := preload("res://scripts/game/abilities/buff_tags.gd")

const DURATION: float = 3.0
const SHARE_RADIUS_TILES: float = 2.0

func cast(ctx: AbilityContext) -> bool:
	if ctx == null or ctx.engine == null or ctx.state == null or ctx.buff_system == null:
		return false
	var caster: Unit = ctx.unit_at(ctx.caster_team, ctx.caster_index)
	var target_index: int = ctx.current_target(ctx.caster_team, ctx.caster_index)
	if caster == null or not caster.is_alive() or target_index < 0:
		return false
	if ctx.buff_system.has_tag(ctx.state, ctx.caster_team, ctx.caster_index, BuffTags.TAG_KYTHERA):
		return false
	var aegis_stacks: int = int(ctx.buff_system.get_stack(ctx.state, ctx.caster_team, ctx.caster_index, TraitKeys.AEGIS))
	var siphon_per_second: int = min(3, 1 + int(floor(float(max(0, aegis_stacks)) / 3.0)))
	var metadata: Dictionary = {
		"target_index": target_index,
		"per_sec": siphon_per_second,
		"drained_total": 0.0,
		"share_radius_tiles": SHARE_RADIUS_TILES,
		"share_with_nearby_allies": true
	}
	ctx.buff_system.apply_tag(ctx.state, ctx.caster_team, ctx.caster_index, BuffTags.TAG_KYTHERA, DURATION, metadata)
	for tick_index: int in range(int(DURATION)):
		ctx.engine.ability_system.schedule_event("kythera_siphon_tick", ctx.caster_team, ctx.caster_index, float(tick_index + 1), {
			"target_index": target_index,
			"damage": 0,
			"remain": max(0.0, DURATION - float(tick_index + 1))
		})
	ctx.engine.ability_system.schedule_event("kythera_siphon_end", ctx.caster_team, ctx.caster_index, DURATION, metadata)
	ctx.log("Siphon: drains MR, then shares the completed resistance nearby")
	return true
