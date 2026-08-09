extends AbilityImplBase

const DAMAGE_BASE: Array[int] = [210, 315, 475]
const TICK_DAMAGE: Array[int] = [34, 52, 78]
const RADIUS_TILES: float = 2.7
const DETONATION_DELAY: float = 1.0
const ZONE_TICKS: int = 5
const ZONE_INTERVAL: float = 0.42
const DEBT_DURATION: float = 3.0
const MANA_SLOW: float = -6.0

func _level_index(unit: Unit) -> int:
	var level: int = int(unit.level) if unit != null else 1
	return clamp(level - 1, 0, 2)

func _enemy_team(team: String) -> String:
	return "enemy" if team == "player" else "player"

func cast(ctx: AbilityContext) -> bool:
	if ctx == null or ctx.engine == null or ctx.state == null:
		return false
	var caster: Unit = ctx.unit_at(ctx.caster_team, ctx.caster_index)
	if caster == null or not caster.is_alive():
		return false
	var target_index: int = ctx.current_target(ctx.caster_team, ctx.caster_index)
	if target_index < 0:
		target_index = ctx.lowest_hp_enemy(ctx.caster_team)
	if target_index < 0:
		return false
	var center: Vector2 = ctx.position_of(_enemy_team(ctx.caster_team), target_index)
	if not ctx.schedule_implementation_callback(self, "_detonate", DETONATION_DELAY, [ctx, center]):
		return false
	ctx.emit_zone_exposure(_enemy_team(ctx.caster_team), target_index, "orielle_spell_debt_warning", DETONATION_DELAY, 0.0, RADIUS_TILES)
	ctx.log("Spell Debt: marked a delayed detonation zone")
	return true

func _detonate(ctx: AbilityContext, center: Vector2) -> void:
	if ctx == null or ctx.engine == null or ctx.state == null:
		return
	var caster: Unit = ctx.unit_at(ctx.caster_team, ctx.caster_index)
	if caster == null or not caster.is_alive():
		return
	var target_team: String = _enemy_team(ctx.caster_team)
	var level_index: int = _level_index(caster)
	var debt_stacks: int = max(3, _mana_pressure(ctx))
	var victims: Array[int] = ctx.enemies_in_radius_at(ctx.caster_team, center, RADIUS_TILES)
	var damage: float = float(DAMAGE_BASE[level_index]) + float(debt_stacks * 26) + 0.55 * float(caster.spell_power)
	for victim_index: int in victims:
		ctx.damage_single(ctx.caster_team, ctx.caster_index, victim_index, damage, "magic")
		ctx.emit_zone_exposure(target_team, victim_index, "orielle_spell_debt_zone", ZONE_INTERVAL * float(ZONE_TICKS), damage, RADIUS_TILES)
		if ctx.buff_system != null:
			ctx.apply_stats_labeled(target_team, victim_index, "orielle_debt_timing_tax", {"mana_regen": MANA_SLOW}, DEBT_DURATION)
	if ctx.engine.ability_system != null:
		ctx.schedule_event("planned_area_tick", ctx.caster_team, ctx.caster_index, ZONE_INTERVAL, {
			"center": center, "radius": RADIUS_TILES, "damage": TICK_DAMAGE[level_index], "damage_type": "magic",
			"ticks_left": ZONE_TICKS, "interval": ZONE_INTERVAL, "dot_kind": "orielle_spell_debt_tick", "zone_kind": "orielle_spell_debt_zone"
		})

func _mana_pressure(ctx: AbilityContext) -> int:
	var pressure: int = 0
	for ally: Unit in ctx.ally_team_array(ctx.caster_team):
		if ally != null and ally.is_alive() and int(ally.mana_max) > 0:
			pressure += 1 + int(float(ally.mana) / max(1.0, float(ally.mana_max)) * 2.0)
	return clamp(pressure, 3, 8)
