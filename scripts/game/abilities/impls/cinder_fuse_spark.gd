extends AbilityImplBase

const DAMAGE_BASE: Array[int] = [125, 190, 285]
const BURN_TICK_BASE: Array[int] = [24, 38, 58]
const SP_RATIO: float = 0.60
const RADIUS_TILES: float = 2.15
const BURN_TICKS: int = 4
const BURN_INTERVAL: float = 0.5
const ZONE_ATTACK_SPEED_TAX: float = -0.18
const ZONE_ATTACK_DAMAGE_TAX: float = -24.0
const ZONE_TAX_DURATION: float = 2.0
const ZONE_TAX_LABEL: String = "cinder_fuse_heat_tax"
const ZONE_MANA_BLOCK_TAG: String = "cinder_fuse_heat_lock"
const ZONE_MANA_BLOCK_DURATION: float = 1.6

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
	var target_index: int = _zone_target(ctx)
	if target_index < 0:
		return false
	var level_index: int = _level_index(caster)
	var target_team: String = _enemy_team(ctx.caster_team)
	var center: Vector2 = ctx.position_of(target_team, target_index)
	var damage: int = int(max(0.0, round(float(DAMAGE_BASE[level_index]) + SP_RATIO * float(caster.spell_power))))
	var burn_damage: int = int(max(1, BURN_TICK_BASE[level_index]))
	var victims: Array[int] = ctx.enemies_in_radius_at(ctx.caster_team, center, RADIUS_TILES)
	for victim_index: int in victims:
		var result: Dictionary = ctx.damage_single(ctx.caster_team, ctx.caster_index, victim_index, float(damage), "magic")
		if bool(result.get("processed", false)):
			var dealt: float = float(result.get("dealt", damage))
			ctx.emit_zone_exposure(target_team, victim_index, "cinder_fuse_zone", BURN_INTERVAL, dealt, RADIUS_TILES)
			_apply_zone_tax(ctx, target_team, victim_index)
	if ctx.engine.ability_system != null:
		ctx.engine.ability_system.schedule_event("cinder_fuse_tick", ctx.caster_team, ctx.caster_index, BURN_INTERVAL, {
			"center": center,
			"radius": RADIUS_TILES,
			"damage": burn_damage,
			"ticks_left": BURN_TICKS,
			"interval": BURN_INTERVAL,
			"debuff_label": ZONE_TAX_LABEL,
			"debuff_fields": {
				"attack_speed": ZONE_ATTACK_SPEED_TAX,
				"attack_damage": ZONE_ATTACK_DAMAGE_TAX
			},
			"debuff_duration": ZONE_TAX_DURATION,
			"debuff_tag": ZONE_MANA_BLOCK_TAG,
			"debuff_tag_data": {
				"block_mana_gain": true,
				"is_debuff": true,
				"cleanseable": true
			},
			"debuff_tag_duration": ZONE_MANA_BLOCK_DURATION
		})
	ctx.log("Fuse Spark: zone hit %d targets for %d, burn %d x%d" % [victims.size(), damage, burn_damage, BURN_TICKS])
	return not victims.is_empty()

func _apply_zone_tax(ctx: AbilityContext, target_team: String, target_index: int) -> void:
	if ctx.buff_system == null:
		return
	ctx.buff_system.apply_stats_labeled(ctx.state, target_team, target_index, ZONE_TAX_LABEL, {
		"attack_speed": ZONE_ATTACK_SPEED_TAX,
		"attack_damage": ZONE_ATTACK_DAMAGE_TAX
	}, ZONE_TAX_DURATION)
	ctx.buff_system.apply_tag(ctx.state, target_team, target_index, ZONE_MANA_BLOCK_TAG, ZONE_MANA_BLOCK_DURATION, {
		"block_mana_gain": true,
		"is_debuff": true,
		"cleanseable": true
	})

func _zone_target(ctx: AbilityContext) -> int:
	var enemies: Array[Unit] = ctx.enemy_team_array(ctx.caster_team)
	var target_team: String = _enemy_team(ctx.caster_team)
	var current_target: int = ctx.current_target(ctx.caster_team, ctx.caster_index)
	var best_index: int = -1
	var best_score: float = -INF
	for index: int in range(enemies.size()):
		var enemy: Unit = enemies[index]
		if enemy == null or not enemy.is_alive():
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
