extends AbilityImplBase

const DAMAGE_BASE: Array[int] = [205, 310, 470]
const DOT_DAMAGE: Array[int] = [48, 72, 110]
const SP_RATIO: float = 0.95
const HEALTH_COST_PCT: float = 0.04
const MANA_REFUND: int = 20
const HEAL_PCT: float = 0.40
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
	var targets: Array[int] = ctx.two_nearest_enemies(ctx.caster_team)
	if targets.is_empty():
		var fallback: int = ctx.lowest_hp_enemy(ctx.caster_team)
		if fallback >= 0:
			targets.append(fallback)
	if targets.is_empty():
		return false
	_spend_health(ctx, caster)
	ctx.request_post_cast_mana_refund(MANA_REFUND)
	var level_index: int = _level_index(caster)
	var damage: float = float(DAMAGE_BASE[level_index]) + SP_RATIO * float(caster.spell_power)
	var target_team: String = ctx._other_team(ctx.caster_team)
	for target_index: int in targets:
		var result: Dictionary = ctx.damage_single(ctx.caster_team, ctx.caster_index, target_index, damage, "magic")
		if bool(result.get("processed", false)):
			var dealt: float = float(result.get("dealt", damage))
			ctx.heal_from_dealt(ctx.caster_team, ctx.caster_index, dealt * HEAL_PCT)
			_record_dot_debuff_presence(ctx, target_team, target_index, level_index)
			if ctx.engine.ability_system != null:
				var static_center: Vector2 = ctx.position_of(target_team, target_index)
				ctx.schedule_event("planned_area_tick", ctx.caster_team, ctx.caster_index, DOT_INTERVAL, {
					"target_index": target_index,
					"center": static_center,
					"damage": DOT_DAMAGE[level_index],
					"damage_type": "magic",
					"ticks_left": DOT_TICKS,
					"interval": DOT_INTERVAL,
					"dot_kind": "noxley_red_static",
					"self_heal_pct": HEAL_PCT
				})
	ctx.log("Red Static: chained through %d targets" % targets.size())
	return true

func _record_dot_debuff_presence(ctx: AbilityContext, target_team: String, target_index: int, level_index: int) -> void:
	if ctx.buff_system == null:
		return
	# The source stack is deliberately nestable: direct-contract casts need an
	# explicit owner, while AbilitySystem casts retain their outer owner after
	# this balanced push/pop pair.
	ctx.buff_system.push_source(ctx.caster_team, ctx.caster_index, "ability")
	ctx.buff_system.record_debuff(ctx.state, target_team, target_index, "noxley_red_static_dot", {
		"damage_per_tick": DOT_DAMAGE[level_index],
		"ticks": DOT_TICKS,
		"interval": DOT_INTERVAL
	}, float(DOT_DAMAGE[level_index] * DOT_TICKS), float(DOT_TICKS) * DOT_INTERVAL)
	ctx.buff_system.pop_source()

func _spend_health(ctx: AbilityContext, caster: Unit) -> void:
	var cost: int = int(max(1.0, round(float(caster.max_hp) * HEALTH_COST_PCT)))
	var before: int = int(caster.hp)
	caster.hp = max(1, before - cost)
	ctx.engine._resolver_emit_unit_stat(ctx.caster_team, ctx.caster_index, {"hp": caster.hp})
