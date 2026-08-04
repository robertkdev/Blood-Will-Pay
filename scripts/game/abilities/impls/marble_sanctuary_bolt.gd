extends AbilityImplBase

const DAMAGE_BASE: Array[int] = [720, 1080, 1620]
const AD_RATIO: float = 3.20
const SHIELD_BASE: Array[int] = [125, 190, 285]
const SHIELD_DURATION: float = 4.0
const DEBUFF_DURATION: float = 4.5
const ATTACK_SPEED_SLOW: float = -0.22
const BOLT_WIDTH_TILES: float = 0.65

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
	var level_index: int = _level_index(caster)
	var targets: Array[int] = ctx.two_furthest_enemies(ctx.caster_team)
	if targets.is_empty():
		return false
	var target_index: int = targets[0]
	var target_team: String = _enemy_team(ctx.caster_team)
	var ally_index: int = _intersecting_low_hp_ally(ctx, ctx.position_of(target_team, target_index))
	if ally_index >= 0 and ctx.buff_system != null:
		ctx.buff_system.apply_shield(ctx.state, ctx.caster_team, ally_index, SHIELD_BASE[level_index], SHIELD_DURATION)
	if ctx.engine.has_signal("target_start"):
		ctx.engine.emit_signal("target_start", ctx.caster_team, ctx.caster_index, target_team, target_index)
	var damage: float = float(DAMAGE_BASE[level_index]) + AD_RATIO * float(caster.attack_damage)
	ctx.damage_single(ctx.caster_team, ctx.caster_index, target_index, damage, "physical")
	if ctx.buff_system != null:
		ctx.buff_system.apply_stats_labeled(ctx.state, target_team, target_index, "marble_sanctuary_bolt", {
			"attack_speed": ATTACK_SPEED_SLOW
		}, DEBUFF_DURATION)
	ctx.log("Sanctuary Bolt: shielded ally %d and tagged enemy %d" % [ally_index, target_index])
	return true

func _intersecting_low_hp_ally(ctx: AbilityContext, target_position: Vector2) -> int:
	var allies: Array[Unit] = ctx.ally_team_array(ctx.caster_team)
	var start: Vector2 = ctx.position_of(ctx.caster_team, ctx.caster_index)
	var segment: Vector2 = target_position - start
	var length_squared: float = segment.length_squared()
	if length_squared <= 0.001:
		return -1
	var width: float = BOLT_WIDTH_TILES * ctx.tile_size()
	var best_index: int = -1
	var best_hp_pct: float = INF
	for ally_index: int in range(allies.size()):
		var ally: Unit = allies[ally_index]
		if ally == null or not ally.is_alive() or ally_index == ctx.caster_index:
			continue
		var ally_position: Vector2 = ctx.position_of(ctx.caster_team, ally_index)
		var projection: float = (ally_position - start).dot(segment) / length_squared
		if projection <= 0.0 or projection >= 1.0:
			continue
		var closest: Vector2 = start + segment * projection
		if ally_position.distance_to(closest) > width:
			continue
		var hp_pct: float = float(ally.hp) / max(1.0, float(ally.max_hp))
		if hp_pct < best_hp_pct:
			best_hp_pct = hp_pct
			best_index = ally_index
	return best_index
