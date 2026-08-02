extends AbilityImplBase

const HEAL_BASE: Array[int] = [85, 135, 205]
const SHIELD_BASE: Array[int] = [90, 145, 220]
const SP_RATIO: float = 0.42
const PROTECT_DURATION: float = 4.0
const STUN_DURATION: float = 1.15
const DAMAGE_BASE: Array[int] = [70, 110, 165]
const SELF_HEAL_MULT: float = 0.75
const SELF_SHIELD_MULT: float = 1.35
const SECONDARY_STUN_DURATION: float = 0.95

func _level_index(unit: Unit) -> int:
	var level: int = int(unit.level) if unit != null else 1
	return clamp(level - 1, 0, 2)

func _enemy_team(team: String) -> String:
	return "enemy" if team == "player" else "player"

func cast(ctx: AbilityContext) -> bool:
	if ctx == null or ctx.engine == null or ctx.state == null:
		return false
	var buff_system: BuffSystem = ctx.buff_system
	if buff_system == null:
		ctx.log("[Silk Knot] BuffSystem not available; cast aborted")
		return false
	var caster: Unit = ctx.unit_at(ctx.caster_team, ctx.caster_index)
	if caster == null or not caster.is_alive():
		return false
	var level_index: int = _level_index(caster)
	var heal_amount: int = int(max(0.0, round(float(HEAL_BASE[level_index]) + SP_RATIO * float(caster.spell_power))))
	var shield_amount: int = int(max(0.0, round(float(SHIELD_BASE[level_index]) + SP_RATIO * float(caster.spell_power))))
	var protected_allies: Array[int] = _two_lowest_allies(ctx)
	for ally_index: int in protected_allies:
		ctx.heal_single(ctx.caster_team, ally_index, float(heal_amount))
		buff_system.apply_shield(ctx.state, ctx.caster_team, ally_index, shield_amount, PROTECT_DURATION)
	ctx.heal_single(ctx.caster_team, ctx.caster_index, float(heal_amount) * SELF_HEAL_MULT)
	buff_system.apply_shield(ctx.state, ctx.caster_team, ctx.caster_index, int(round(float(shield_amount) * SELF_SHIELD_MULT)), PROTECT_DURATION)
	var lockdown_targets: Array[int] = _lockdown_targets(ctx)
	var target_team: String = _enemy_team(ctx.caster_team)
	for target_position: int in range(lockdown_targets.size()):
		var target_index: int = lockdown_targets[target_position]
		var stun_duration: float = STUN_DURATION if target_position == 0 else SECONDARY_STUN_DURATION
		var damage_scale: float = 1.0 if target_position == 0 else 0.55
		ctx.stun(target_team, target_index, stun_duration)
		ctx.damage_single(ctx.caster_team, ctx.caster_index, target_index, float(DAMAGE_BASE[level_index]) * damage_scale, "magic")
	ctx.log("Silk Knot: protected %d allies and pinned %d threats" % [protected_allies.size(), lockdown_targets.size()])
	return not protected_allies.is_empty() or not lockdown_targets.is_empty()

func _two_lowest_allies(ctx: AbilityContext) -> Array[int]:
	var pairs: Array[Dictionary] = []
	var allies: Array[Unit] = ctx.ally_team_array(ctx.caster_team)
	for index: int in range(allies.size()):
		if index == ctx.caster_index:
			continue
		var ally: Unit = allies[index]
		if ally == null or not ally.is_alive():
			continue
		var hp_ratio: float = float(ally.hp) / max(1.0, float(ally.max_hp))
		pairs.append({"index": index, "ratio": hp_ratio})
	pairs.sort_custom(func(first: Dictionary, second: Dictionary) -> bool:
		return float(first.get("ratio", 1.0)) < float(second.get("ratio", 1.0))
	)
	var output: Array[int] = []
	for pair_index: int in range(min(2, pairs.size())):
		output.append(int(pairs[pair_index].get("index", -1)))
	return output

func _lockdown_targets(ctx: AbilityContext) -> Array[int]:
	var enemies: Array[Unit] = ctx.enemy_team_array(ctx.caster_team)
	var target_team: String = _enemy_team(ctx.caster_team)
	var current_index: int = ctx.current_target(ctx.caster_team, ctx.caster_index)
	var scored: Array[Dictionary] = []
	for index: int in range(enemies.size()):
		var enemy: Unit = enemies[index]
		if enemy == null or not ctx.is_targetable(target_team, index):
			continue
		var score: float = float(enemy.attack_damage) + float(enemy.spell_power) * 0.65 + float(enemy.attack_speed) * 25.0
		var role_id: String = String(enemy.primary_role).strip_edges().to_lower()
		var goal_id: String = String(enemy.primary_goal).strip_edges().to_lower()
		if role_id == "assassin" or role_id == "marksman" or role_id == "mage":
			score += 240.0
		if goal_id.find("backline") >= 0 or goal_id.find("burst") >= 0:
			score += 140.0
		if index == current_index:
			score += 60.0
		scored.append({"index": index, "score": score})
	scored.sort_custom(func(first: Dictionary, second: Dictionary) -> bool:
		return float(first.get("score", 0.0)) > float(second.get("score", 0.0))
	)
	var output: Array[int] = []
	for entry_index: int in range(min(2, scored.size())):
		output.append(int(scored[entry_index].get("index", -1)))
	return output
