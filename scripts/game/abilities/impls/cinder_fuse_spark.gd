extends AbilityImplBase

const DAMAGE_BASE: Array[int] = [125, 190, 285]
const BURN_TICK_BASE: Array[int] = [24, 38, 58]
const SP_RATIO: float = 0.60
const RADIUS_TILES: float = 2.15
const BURN_TICKS: int = 4
const BURN_INTERVAL: float = 0.5
const MANA_BLOCK_TAG: String = "cinder_fuse_heat_lock"
const MANA_BLOCK_DURATION: float = 1.6

func _level_index(unit: Unit) -> int:
	var level: int = int(unit.level) if unit != null else 1
	return clamp(level - 1, 0, 2)

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
	var center: Vector2 = ctx.position_of(target_team, target_index)
	var level_index: int = _level_index(caster)
	var damage: float = float(DAMAGE_BASE[level_index]) + SP_RATIO * float(caster.spell_power)
	var victims: Array[int] = ctx.enemies_in_radius_at(ctx.caster_team, center, RADIUS_TILES)
	for victim_index: int in victims:
		var result: Dictionary = ctx.damage_single(ctx.caster_team, ctx.caster_index, victim_index, damage, "magic")
		if bool(result.get("processed", false)):
			ctx.emit_zone_exposure(target_team, victim_index, "cinder_fuse_zone", BURN_INTERVAL, float(result.get("dealt", 0.0)), RADIUS_TILES)
			ctx.buff_system.apply_tag(ctx.state, target_team, victim_index, MANA_BLOCK_TAG, MANA_BLOCK_DURATION, {
				"block_mana_gain": true,
				"is_debuff": true,
				"cleanseable": true
			})
	if ctx.engine.ability_system != null:
		ctx.schedule_event("cinder_fuse_tick", ctx.caster_team, ctx.caster_index, BURN_INTERVAL, {
			"center": center,
			"radius": RADIUS_TILES,
			"damage": int(BURN_TICK_BASE[level_index]),
			"ticks_left": BURN_TICKS,
			"interval": BURN_INTERVAL,
			"debuff_tag": MANA_BLOCK_TAG,
			"debuff_tag_data": {"block_mana_gain": true, "is_debuff": true, "cleanseable": true},
			"debuff_tag_duration": MANA_BLOCK_DURATION
		})
	ctx.log("Fuse Spark: visible zone damaged and blocked mana for %d enemies" % victims.size())
	return not victims.is_empty()
