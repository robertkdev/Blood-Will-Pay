extends AbilityImplBase

const DAMAGE_BASE: Array[int] = [145, 220, 330]
const RADIUS_TILES: float = 2.35
const FIELD_DURATION: float = 3.0
const FIELD_INTERVAL: float = 0.20
const FIELD_MANA_BLOCK_TAG: String = "prisma_color_field_lock"

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
	var target_index: int = _zone_target(ctx)
	if target_index < 0:
		return false
	var target_team: String = _enemy_team(ctx.caster_team)
	var center: Vector2 = ctx.position_of(target_team, target_index)
	if ctx.engine.has_signal("target_start"):
		ctx.engine.emit_signal("target_start", ctx.caster_team, ctx.caster_index, target_team, target_index)
	if ctx.engine.ability_system == null:
		return false
	ctx.schedule_event("prisma_color_field_tick", ctx.caster_team, ctx.caster_index, 0.0, {
		"center": center,
		"radius": RADIUS_TILES,
		"damage": DAMAGE_BASE[level_index],
		"damage_applied": false,
		"ticks_left": int(ceil(FIELD_DURATION / FIELD_INTERVAL)),
		"interval": FIELD_INTERVAL,
		"mana_block_tag": FIELD_MANA_BLOCK_TAG
	})
	ctx.log("Color Theory: painted one persistent denial field")
	return true

func _zone_target(ctx: AbilityContext) -> int:
	var enemies: Array[Unit] = ctx.enemy_team_array(ctx.caster_team)
	var target_team: String = _enemy_team(ctx.caster_team)
	var current_target: int = ctx.current_target(ctx.caster_team, ctx.caster_index)
	var best_index: int = -1
	var best_score: float = -INF
	for index: int in range(enemies.size()):
		var enemy: Unit = enemies[index]
		if enemy == null or not ctx.is_targetable(target_team, index):
			continue
		var enemy_position: Vector2 = ctx.position_of(target_team, index)
		var score: float = _zone_target_score(ctx, enemy, enemy_position)
		if index == current_target:
			score += 1.0
		if score > best_score:
			best_score = score
			best_index = index
	if best_index >= 0:
		return best_index
	return ctx.lowest_hp_enemy(ctx.caster_team)

func _zone_target_score(ctx: AbilityContext, enemy: Unit, enemy_position: Vector2) -> float:
	var score: float = 0.0
	score += float(ctx.enemies_in_radius_at(ctx.caster_team, enemy_position, RADIUS_TILES).size()) * 1.35
	if enemy.has_approach("engage"):
		score += 5.0
	if enemy.has_approach("access_backline"):
		score += 4.0
	if enemy.has_approach("reposition"):
		score += 1.25
	if enemy.has_approach("ramp"):
		score += 1.0
	var role: String = String(enemy.get_primary_role()).strip_edges().to_lower()
	if role == "brawler" or role == "assassin":
		score += 1.15
	elif role == "tank":
		score += 0.75
	var goal: String = String(enemy.get_primary_goal()).strip_edges().to_lower()
	if goal.find("initiate") >= 0 or goal.find("frontline_disruption") >= 0 or goal.find("skirmish") >= 0:
		score += 1.75
	score += clampf(float(enemy.cost), 1.0, 5.0) * 0.20
	return score
