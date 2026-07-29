extends AbilityImplBase

const DAMAGE_BASE: Array[int] = [145, 220, 330]
const RADIUS_TILES: float = 2.35
const AMP_DURATION: float = 4.5
const DAMAGE_AMP: Array[float] = [0.10, 0.15, 0.22]
const FIELD_ATTACK_SPEED_TAX: float = -0.16
const FIELD_ATTACK_DAMAGE_TAX: float = -20.0
const FIELD_TAX_DURATION: float = 3.0
const FIELD_MANA_BLOCK_TAG: String = "prisma_color_field_lock"
const FIELD_MANA_BLOCK_DURATION: float = 2.25

const BuffTags := preload("res://scripts/game/abilities/buff_tags.gd")

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
	_apply_team_amp(ctx, float(DAMAGE_AMP[level_index]))
	var target_index: int = _zone_target(ctx)
	if target_index < 0:
		return true
	var target_team: String = _enemy_team(ctx.caster_team)
	var center: Vector2 = ctx.position_of(target_team, target_index)
	var victims: Array[int] = ctx.enemies_in_radius_at(ctx.caster_team, center, RADIUS_TILES)
	for victim_index: int in victims:
		var result: Dictionary = ctx.damage_single(ctx.caster_team, ctx.caster_index, victim_index, float(DAMAGE_BASE[level_index]), "magic")
		if bool(result.get("processed", false)):
			ctx.emit_zone_exposure(target_team, victim_index, "prisma_color_field", 1.0, float(result.get("dealt", DAMAGE_BASE[level_index])), RADIUS_TILES)
			_apply_field_tax(ctx, target_team, victim_index)
	ctx.log("Color Theory: amplified team and burst %d enemies" % victims.size())
	return true

func _apply_field_tax(ctx: AbilityContext, target_team: String, target_index: int) -> void:
	if ctx.buff_system == null:
		return
	ctx.buff_system.apply_stats_labeled(ctx.state, target_team, target_index, "prisma_color_field_tax", {
		"attack_speed": FIELD_ATTACK_SPEED_TAX,
		"attack_damage": FIELD_ATTACK_DAMAGE_TAX
	}, FIELD_TAX_DURATION)
	ctx.buff_system.apply_tag(ctx.state, target_team, target_index, FIELD_MANA_BLOCK_TAG, FIELD_MANA_BLOCK_DURATION, {
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

func _apply_team_amp(ctx: AbilityContext, amp: float) -> void:
	if ctx.buff_system == null:
		return
	var allies: Array[Unit] = ctx.ally_team_array(ctx.caster_team)
	ctx.buff_system.push_source(ctx.caster_team, ctx.caster_index, "ability")
	for index: int in range(allies.size()):
		var ally: Unit = allies[index]
		if ally == null or not ally.is_alive():
			continue
		ctx.buff_system.apply_tag(ctx.state, ctx.caster_team, index, BuffTags.TAG_DAMAGE_AMP, AMP_DURATION, {
			"damage_amp_pct": amp,
			"kind": "prisma_color_theory"
		})
		ctx.buff_system.apply_tag(ctx.state, ctx.caster_team, index, BuffTags.TAG_ABILITY_AMP, AMP_DURATION, {
			"ability_damage_amp": amp,
			"kind": "prisma_color_theory"
		})
	ctx.buff_system.pop_source()
