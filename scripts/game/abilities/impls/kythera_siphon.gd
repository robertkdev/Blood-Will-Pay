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
	var target_team: String = "enemy" if ctx.caster_team == "player" else "player"
	var target: Unit = ctx.unit_at(target_team, target_index)
	if target == null or not target.is_alive():
		return false
	if ctx.buff_system.has_tag(ctx.state, ctx.caster_team, ctx.caster_index, BuffTags.TAG_KYTHERA):
		return false
	var aegis_stacks: int = int(ctx.buff_system.get_stack(ctx.state, ctx.caster_team, ctx.caster_index, TraitKeys.AEGIS))
	var siphon_per_second: int = min(3, 1 + int(floor(float(max(0, aegis_stacks)) / 3.0)))
	var drain_state: RefCounted = RefCounted.new()
	drain_state.set_meta("capacity", max(0.0, float(target.magic_resist)))
	drain_state.set_meta("drained_total", 0.0)
	var metadata: Dictionary = {
		"target_index": target_index,
		"per_sec": siphon_per_second,
		"drained_total": 0.0,
		"drain_state": drain_state,
		"share_radius_tiles": SHARE_RADIUS_TILES,
		"share_with_nearby_allies": true
	}
	ctx.buff_system.apply_tag(ctx.state, ctx.caster_team, ctx.caster_index, BuffTags.TAG_KYTHERA, DURATION, metadata)
	for tick_index: int in range(int(DURATION)):
		ctx.schedule_event("kythera_siphon_tick", ctx.caster_team, ctx.caster_index, float(tick_index + 1), {
			"target_index": target_index,
			"damage": 0,
			"per_sec": siphon_per_second,
			"drain_state": drain_state,
			"remain": max(0.0, DURATION - float(tick_index + 1))
		})
	ctx.schedule_event("kythera_siphon_end", ctx.caster_team, ctx.caster_index, DURATION, metadata)
	ctx.log("Siphon: drains MR, then shares the completed resistance nearby")
	return true
