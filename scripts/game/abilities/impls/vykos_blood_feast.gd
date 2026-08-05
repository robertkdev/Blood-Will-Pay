extends AbilityImplBase

const CONE_RADIUS_TILES: float = 2.0
const CONE_HALF_ANGLE_DEGREES: float = 30.0
const BASE_DAMAGE: Array[int] = [200, 350, 500]
const AD_RATIO: float = 1.2
const HEAL_FROM_DAMAGE: Array[float] = [0.20, 0.30, 0.40]

func _level_index(unit: Unit) -> int:
	var level: int = int(unit.level) if unit != null else 1
	return clamp(level - 1, 0, 2)

func cast(ctx: AbilityContext) -> bool:
	if ctx == null or ctx.engine == null or ctx.state == null:
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
	var origin: Vector2 = ctx.position_of(ctx.caster_team, ctx.caster_index)
	var target_position: Vector2 = ctx.position_of(target_team, target_index)
	var forward: Vector2 = (target_position - origin).normalized()
	var victims: Array[int] = _cone_hits(ctx, origin, forward)
	var level_index: int = _level_index(caster)
	var damage: float = float(BASE_DAMAGE[level_index]) + AD_RATIO * float(caster.attack_damage)
	var total_dealt: float = 0.0
	for victim_index: int in victims:
		var result: Dictionary = ctx.damage_single(ctx.caster_team, ctx.caster_index, victim_index, damage, "physical")
		total_dealt += float(result.get("dealt", 0.0))
	ctx.heal_single(ctx.caster_team, ctx.caster_index, total_dealt * float(HEAL_FROM_DAMAGE[level_index]))
	ctx.log("Crimson Harvest: cone hit %d and healed only from actual damage" % victims.size())
	return not victims.is_empty()

func _cone_hits(ctx: AbilityContext, origin: Vector2, forward: Vector2) -> Array[int]:
	var output: Array[int] = []
	if forward == Vector2.ZERO:
		return output
	var target_team: String = ctx._other_team(ctx.caster_team)
	var enemies: Array[Unit] = ctx.enemy_team_array(ctx.caster_team)
	var maximum_distance: float = CONE_RADIUS_TILES * ctx.tile_size()
	var cosine_threshold: float = cos(deg_to_rad(CONE_HALF_ANGLE_DEGREES))
	for index: int in range(enemies.size()):
		var enemy: Unit = enemies[index]
		if enemy == null or not enemy.is_alive():
			continue
		var offset: Vector2 = ctx.position_of(target_team, index) - origin
		if offset.length() > 0.0 and offset.length() <= maximum_distance and forward.dot(offset.normalized()) >= cosine_threshold:
			output.append(index)
	return output
