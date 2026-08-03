extends AbilityImplBase

const BuffTags = preload("res://scripts/game/abilities/buff_tags.gd")

const SHIELD_BASE: Array[int] = [260, 390, 585]
const DAMAGE_BASE: Array[int] = [180, 270, 405]
const LOCKDOWN_DURATION: float = 2.2
const GATE_DURATION: float = 4.5
const GATE_ARMOR: float = 40.0
const GATE_MR: float = 40.0
const GATE_DR: float = 0.18
const SELF_GATE_STAT_SCALE: float = 0.5
const SELF_GATE_DR: float = 0.08
const SELF_GATE_SHIELD_SCALE: float = 0.45
const SELF_IMMUNITY_SCALE: float = 0.5
const IMMUNITY_DURATION: float = 1.4
const MAX_ALLIES: int = 4

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
	var target_team: String = _enemy_team(ctx.caster_team)
	var level_index: int = _level_index(caster)
	ctx.damage_single(ctx.caster_team, ctx.caster_index, target_index, float(DAMAGE_BASE[level_index]) + 0.10 * float(caster.max_hp), "magic")
	ctx.stun(target_team, target_index, LOCKDOWN_DURATION)
	if ctx.buff_system != null:
		ctx.buff_system.apply_tag(ctx.state, target_team, target_index, "root", LOCKDOWN_DURATION, {})
		ctx.buff_system.record_debuff(ctx.state, target_team, target_index, "bastionne_gate_lock", {
			"duration": LOCKDOWN_DURATION
		}, LOCKDOWN_DURATION, LOCKDOWN_DURATION)
	ctx.emit_redirect_semantic(target_team, target_index, "no_pass_gate_wall", GATE_DURATION, float(SHIELD_BASE[level_index]), 0.35)
	_raise_gate(ctx, level_index)
	ctx.log("No-Pass Writ: locked target %d and raised gate for allies" % target_index)
	return true

func _priority_lockdown_target(ctx: AbilityContext) -> int:
	var enemies: Array[Unit] = ctx.enemy_team_array(ctx.caster_team)
	var target_team: String = _enemy_team(ctx.caster_team)
	var best_index: int = -1
	var best_score: float = -INF
	for index: int in range(enemies.size()):
		var enemy: Unit = enemies[index]
		if enemy == null or not ctx.is_targetable(target_team, index):
			continue
		var score: float = float(enemy.attack_damage) + float(enemy.spell_power) * 0.5
		var role_id: String = String(enemy.primary_role).strip_edges().to_lower()
		var goal_id: String = String(enemy.primary_goal).strip_edges().to_lower()
		if role_id == "marksman" or role_id == "assassin" or role_id == "mage":
			score += 300.0
		if goal_id.find("backline") >= 0 or goal_id.find("sustained_dps") >= 0 or goal_id.find("burst") >= 0:
			score += 180.0
		if goal_id.find("peel_carry") >= 0:
			score += 80.0
		if score > best_score:
			best_score = score
			best_index = index
	return best_index

func _raise_gate(ctx: AbilityContext, level_index: int) -> void:
	if ctx.buff_system == null:
		return
	var allies: Array[Unit] = ctx.ally_team_array(ctx.caster_team)
	var applied: int = 0
	for index: int in range(allies.size()):
		if applied >= MAX_ALLIES:
			return
		var ally: Unit = allies[index]
		if ally == null or not ally.is_alive():
			continue
		var is_self: bool = index == ctx.caster_index
		var armor_bonus: float = GATE_ARMOR * SELF_GATE_STAT_SCALE if is_self else GATE_ARMOR
		var mr_bonus: float = GATE_MR * SELF_GATE_STAT_SCALE if is_self else GATE_MR
		var dr_bonus: float = SELF_GATE_DR if is_self else GATE_DR
		var shield_amount: int = int(round(float(SHIELD_BASE[level_index]) * SELF_GATE_SHIELD_SCALE)) if is_self else SHIELD_BASE[level_index]
		var immunity_duration: float = IMMUNITY_DURATION * SELF_IMMUNITY_SCALE if is_self else IMMUNITY_DURATION
		ctx.buff_system.apply_stats_labeled(ctx.state, ctx.caster_team, index, "bastionne_no_pass_gate", {
			"armor": armor_bonus,
			"magic_resist": mr_bonus,
			"damage_reduction": dr_bonus
		}, GATE_DURATION)
		ctx.buff_system.apply_shield(ctx.state, ctx.caster_team, index, shield_amount, GATE_DURATION)
		ctx.buff_system.apply_tag(ctx.state, ctx.caster_team, index, BuffTags.TAG_CC_IMMUNE, immunity_duration, {
			"block_mana_gain": true
		})
		applied += 1
