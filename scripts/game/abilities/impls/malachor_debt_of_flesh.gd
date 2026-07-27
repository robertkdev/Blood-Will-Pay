extends AbilityImplBase

const DAMAGE_BASE: Array[int] = [260, 390, 585]
const TICK_DAMAGE: Array[int] = [62, 94, 142]
const LOCKDOWN_DURATION: float = 2.6
const DEBT_DURATION: float = 5.5
const TICK_INTERVAL: float = 0.55
const TICK_COUNT: int = 5
const SELF_DR: float = 0.18
const SELF_HEAL_PCT: float = 0.08
const SELF_SHIELD_PCT: float = 0.08

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
	var target_index: int = _priority_lockdown_target(ctx)
	if target_index < 0:
		return false
	var level_index: int = _level_index(caster)
	var target_team: String = _enemy_team(ctx.caster_team)
	_prepare_debt_window(ctx, caster)
	var damage: float = float(DAMAGE_BASE[level_index]) + 0.08 * float(caster.max_hp)
	var result: Dictionary = ctx.damage_single(ctx.caster_team, ctx.caster_index, target_index, damage, "magic")
	ctx.stun(target_team, target_index, LOCKDOWN_DURATION)
	if ctx.buff_system != null:
		ctx.buff_system.apply_tag(ctx.state, target_team, target_index, "root", LOCKDOWN_DURATION, {})
		ctx.buff_system.record_debuff(ctx.state, target_team, target_index, "malachor_flesh_debt_lock", {
			"duration": LOCKDOWN_DURATION
		}, LOCKDOWN_DURATION, LOCKDOWN_DURATION)
	_schedule_debt_ticks(ctx, target_index, level_index)
	ctx.log("Debt of Flesh: pinned target %d under a flesh debt clock" % target_index)
	return bool(result.get("processed", true))

func _priority_lockdown_target(ctx: AbilityContext) -> int:
	var enemies: Array[Unit] = ctx.enemy_team_array(ctx.caster_team)
	var target_team: String = _enemy_team(ctx.caster_team)
	var best_index: int = -1
	var best_score: float = -INF
	for index: int in range(enemies.size()):
		var enemy: Unit = enemies[index]
		if enemy == null or not ctx.is_targetable(target_team, index):
			continue
		var score: float = float(enemy.attack_damage) + 0.65 * float(enemy.spell_power)
		var role_id: String = String(enemy.primary_role).strip_edges().to_lower()
		var goal_id: String = String(enemy.primary_goal).strip_edges().to_lower()
		if role_id == "assassin" or role_id == "marksman" or role_id == "mage":
			score += 240.0
		if goal_id.find("backline") >= 0 or goal_id.find("burst") >= 0:
			score += 160.0
		if score > best_score:
			best_score = score
			best_index = index
	return best_index

func _prepare_debt_window(ctx: AbilityContext, caster: Unit) -> void:
	if caster == null:
		return
	var self_damage: int = max(1, int(round(float(caster.max_hp) * 0.08)))
	caster.hp = max(1, int(caster.hp) - self_damage)
	ctx.heal_single(ctx.caster_team, ctx.caster_index, float(caster.max_hp) * SELF_HEAL_PCT)
	if ctx.buff_system == null:
		return
	ctx.buff_system.apply_stats_labeled(ctx.state, ctx.caster_team, ctx.caster_index, "malachor_debt_hide", {
		"damage_reduction": SELF_DR,
		"armor": 55.0,
		"magic_resist": 55.0
	}, DEBT_DURATION)
	ctx.buff_system.apply_shield(ctx.state, ctx.caster_team, ctx.caster_index, int(round(float(caster.max_hp) * SELF_SHIELD_PCT)), DEBT_DURATION)

func _schedule_debt_ticks(ctx: AbilityContext, target_index: int, level_index: int) -> void:
	if ctx.engine.ability_system == null:
		return
	ctx.engine.ability_system.schedule_event("planned_area_tick", ctx.caster_team, ctx.caster_index, TICK_INTERVAL, {
		"target_index": target_index,
		"damage": TICK_DAMAGE[level_index],
		"damage_type": "magic",
		"ticks_left": TICK_COUNT,
		"interval": TICK_INTERVAL,
		"dot_kind": "malachor_flesh_debt_tick",
		"debuff_label": "malachor_flesh_debt",
		"debuff_duration": DEBT_DURATION,
		"debuff_fields": {
			"armor": -18.0,
			"magic_resist": -18.0
		},
		"self_heal_pct": 0.25
	})
