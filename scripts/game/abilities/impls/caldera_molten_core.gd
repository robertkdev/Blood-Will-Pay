extends AbilityImplBase

const DAMAGE_BASE: Array[int] = [170, 260, 390]
const TICK_DAMAGE: Array[int] = [28, 42, 64]
const RADIUS_TILES: float = 2.25
const ENGAGE_TILES: float = 1.55
const MOVE_DURATION: float = 0.20
const DR_DURATION: float = 4.0
const ZONE_TICKS: int = 4
const ZONE_INTERVAL: float = 0.45

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
	var target_team: String = _enemy_team(ctx.caster_team)
	var target_position: Vector2 = ctx.position_of(target_team, target_index)
	_engage_toward(ctx, target_position)
	if ctx.buff_system != null:
		ctx.apply_stats_buff(ctx.caster_team, ctx.caster_index, {"damage_reduction": 0.30}, DR_DURATION)
	var level_index: int = _level_index(caster)
	var damage: int = int(max(1.0, round(float(DAMAGE_BASE[level_index]) + 0.35 * float(caster.max_hp) / 10.0)))
	var victims: Array[int] = ctx.enemies_in_radius_at(ctx.caster_team, target_position, RADIUS_TILES)
	for victim_index: int in victims:
		var result: Dictionary = ctx.damage_single(ctx.caster_team, ctx.caster_index, victim_index, float(damage), "magic")
		if bool(result.get("processed", false)):
			ctx.emit_zone_exposure(target_team, victim_index, "caldera_molten_core", ZONE_INTERVAL, float(result.get("dealt", damage)), RADIUS_TILES)
	if ctx.engine.ability_system != null:
		ctx.schedule_event("planned_area_tick", ctx.caster_team, ctx.caster_index, ZONE_INTERVAL, {
			"center": target_position,
			"radius": RADIUS_TILES,
			"damage": TICK_DAMAGE[level_index],
			"damage_type": "magic",
			"ticks_left": ZONE_TICKS,
			"interval": ZONE_INTERVAL,
			"dot_kind": "caldera_molten_floor",
			"zone_kind": "caldera_molten_floor"
		})
	ctx.log("Molten Core: engaged and burned %d targets" % victims.size())
	return true

func _engage_toward(ctx: AbilityContext, target_position: Vector2) -> void:
	if ctx.engine.arena_state == null or not ctx.engine.arena_state.has_method("notify_forced_movement"):
		return
	var start: Vector2 = ctx.position_of(ctx.caster_team, ctx.caster_index)
	var delta: Vector2 = target_position - start
	if delta.length() <= 0.001:
		return
	ctx.engine.arena_state.notify_forced_movement(ctx.caster_team, ctx.caster_index, delta.normalized() * ENGAGE_TILES * ctx.tile_size(), MOVE_DURATION)
