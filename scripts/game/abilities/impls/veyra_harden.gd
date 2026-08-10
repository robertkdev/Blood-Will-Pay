extends AbilityImplBase

const BuffTags := preload("res://scripts/game/abilities/buff_tags.gd")
const MovementMath := preload("res://scripts/game/combat/movement/math.gd")

const DURATION: float = 4.0
const RADIUS_TILES: float = 2.0
const DAMAGE_REDUCTION: float = 0.25

func cast(ctx: AbilityContext) -> bool:
	if ctx == null or ctx.engine == null or ctx.state == null or ctx.buff_system == null:
		return false
	var caster: Unit = ctx.unit_at(ctx.caster_team, ctx.caster_index)
	if caster == null or not caster.is_alive():
		return false
	var targets: Array[int] = _allies_in_radius(ctx)
	for ally_index: int in targets:
		ctx.apply_stats_buff(ctx.caster_team, ally_index, {"damage_reduction": DAMAGE_REDUCTION}, DURATION)
		ctx.buff_system.apply_tag(ctx.state, ctx.caster_team, ally_index, BuffTags.TAG_CC_IMMUNE, DURATION, {"kind": "veyra_harden"})
	ctx.log("Harden: %d nearby allies gained DR and CC immunity" % targets.size())
	return not targets.is_empty()

func _allies_in_radius(ctx: AbilityContext) -> Array[int]:
	var output: Array[int] = []
	var center: Vector2 = ctx.position_of(ctx.caster_team, ctx.caster_index)
	var allies: Array[Unit] = ctx.ally_team_array(ctx.caster_team)
	for index: int in range(allies.size()):
		var ally: Unit = allies[index]
		if ally == null or not ally.is_alive():
			continue
		var position: Vector2 = ctx.position_of(ctx.caster_team, index)
		if MovementMath.within_radius_tiles(center, position, RADIUS_TILES, ctx.tile_size(), ctx._range_epsilon()):
			output.append(index)
	return output
