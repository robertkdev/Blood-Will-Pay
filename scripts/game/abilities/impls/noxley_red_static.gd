extends AbilityImplBase

const DAMAGE_BASE: Array[int] = [165, 250, 380]
const DOT_DAMAGE: Array[int] = [38, 58, 88]
const SP_RATIO: float = 0.95
const HEALTH_COST_PCT: float = 0.07
const HEAL_PCT: float = 0.34
const DOT_TICKS: int = 6
const DOT_INTERVAL: float = 0.45

func _level_index(unit: Unit) -> int:
	var level: int = int(unit.level) if unit != null else 1
	return clamp(level - 1, 0, 2)

func cast(ctx: AbilityContext) -> bool:
	if ctx == null or ctx.engine == null or ctx.state == null:
		return false
	var caster: Unit = ctx.unit_at(ctx.caster_team, ctx.caster_index)
	if caster == null or not caster.is_alive():
		return false
	_spend_health(ctx, caster)
	var targets: Array[int] = ctx.two_nearest_enemies(ctx.caster_team)
	if targets.is_empty():
		var fallback: int = ctx.lowest_hp_enemy(ctx.caster_team)
		if fallback >= 0:
			targets.append(fallback)
	if targets.is_empty():
		return false
	var level_index: int = _level_index(caster)
	var damage: float = float(DAMAGE_BASE[level_index]) + SP_RATIO * float(caster.spell_power)
	for target_index: int in targets:
		var result: Dictionary = ctx.damage_single(ctx.caster_team, ctx.caster_index, target_index, damage, "magic")
		if bool(result.get("processed", false)):
			var dealt: float = float(result.get("dealt", damage))
			ctx.heal_single(ctx.caster_team, ctx.caster_index, dealt * HEAL_PCT)
			if ctx.engine.ability_system != null:
				ctx.engine.ability_system.schedule_event("planned_area_tick", ctx.caster_team, ctx.caster_index, DOT_INTERVAL, {
					"target_index": target_index,
					"damage": DOT_DAMAGE[level_index],
					"damage_type": "magic",
					"ticks_left": DOT_TICKS,
					"interval": DOT_INTERVAL,
					"dot_kind": "noxley_red_static",
					"self_heal_pct": HEAL_PCT
				})
	ctx.log("Red Static: chained through %d targets" % targets.size())
	return true

func _spend_health(ctx: AbilityContext, caster: Unit) -> void:
	var cost: int = int(max(1.0, round(float(caster.max_hp) * HEALTH_COST_PCT)))
	var before: int = int(caster.hp)
	caster.hp = max(1, before - cost)
	ctx.engine._resolver_emit_unit_stat(ctx.caster_team, ctx.caster_index, {"hp": caster.hp})
