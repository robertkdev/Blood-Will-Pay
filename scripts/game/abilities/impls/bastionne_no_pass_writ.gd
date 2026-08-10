extends AbilityImplBase

const SHIELD_BASE: Array[int] = [260, 390, 585]
const DAMAGE_BASE: Array[int] = [180, 270, 405]
const ROOT_DURATION: float = 2.2
const GATE_DURATION: float = 4.5

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
	if ctx.buff_system != null:
		var root_result: Dictionary = ctx.apply_cc_tag(target_team, target_index, "root", ROOT_DURATION, {})
		var root_duration: float = float(root_result.get("remaining", ctx.scale_power(ROOT_DURATION)))
		if bool(root_result.get("processed", false)):
			ctx.buff_system.record_debuff(ctx.state, target_team, target_index, "bastionne_gate_lock", {"duration": root_duration}, root_duration, root_duration)
	_raise_gate(ctx, level_index)
	ctx.emit_redirect_semantic(target_team, target_index, "no_pass_gate_wall", GATE_DURATION, float(SHIELD_BASE[level_index]), 0.35)
	ctx.log("No-Pass Writ: rooted target %d and shielded allies behind the gate" % target_index)
	return true

func _priority_lockdown_target(ctx: AbilityContext) -> int:
	var enemies: Array[Unit] = ctx.enemy_team_array(ctx.caster_team)
	var best_index: int = -1
	var best_score: float = -INF
	for index: int in range(enemies.size()):
		var enemy: Unit = enemies[index]
		if enemy == null or not enemy.is_alive():
			continue
		var score: float = float(enemy.attack_damage) + float(enemy.spell_power) * 0.5
		var role_id: String = String(enemy.primary_role).strip_edges().to_lower()
		if role_id == "marksman" or role_id == "assassin" or role_id == "mage":
			score += 300.0
		if score > best_score:
			best_score = score
			best_index = index
	return best_index

func _raise_gate(ctx: AbilityContext, level_index: int) -> void:
	if ctx.buff_system == null:
		return
	var caster_position: Vector2 = ctx.position_of(ctx.caster_team, ctx.caster_index)
	var forward_sign: float = 1.0 if ctx.caster_team == "player" else -1.0
	var allies: Array[Unit] = ctx.ally_team_array(ctx.caster_team)
	for index: int in range(allies.size()):
		var ally: Unit = allies[index]
		if ally == null or not ally.is_alive():
			continue
		var ally_position: Vector2 = ctx.position_of(ctx.caster_team, index)
		var behind_gate: bool = (ally_position.x - caster_position.x) * forward_sign <= 0.0
		if behind_gate:
			ctx.apply_shield(ctx.caster_team, index, SHIELD_BASE[level_index], GATE_DURATION)
