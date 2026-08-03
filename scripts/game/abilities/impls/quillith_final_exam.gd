extends AbilityImplBase

const BuffTags = preload("res://scripts/game/abilities/buff_tags.gd")

const AMP_DURATION: float = 4.0
const DAMAGE_AMP: Array[float] = [0.18, 0.27, 0.40]
const STAT_AMP: Array[float] = [70.0, 105.0, 158.0]
const PUPIL_SHIELD: Array[int] = [260, 390, 585]
const TEAM_SHIELD: Array[int] = [70, 105, 158]
const MANA_GRANT: Array[int] = [18, 27, 40]
const RECAST_DAMAGE: Array[int] = [220, 330, 495]

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
	var pupil_index: int = _pupil_index(ctx)
	var level_index: int = _level_index(caster)
	if pupil_index >= 0:
		_apply_exam_buffs(ctx, pupil_index, level_index)
	var target_index: int = ctx.current_target(ctx.caster_team, ctx.caster_index)
	if target_index < 0:
		target_index = ctx.lowest_hp_enemy(ctx.caster_team)
	if target_index >= 0:
		var target_team: String = _enemy_team(ctx.caster_team)
		if ctx.engine.has_method("_resolver_emit_reset_triggered"):
			ctx.engine._resolver_emit_reset_triggered(ctx.caster_team, ctx.caster_index, target_team, target_index, "quillith_final_exam_recast", 2, 0.0, 0.55)
		ctx.damage_single(ctx.caster_team, ctx.caster_index, target_index, float(RECAST_DAMAGE[level_index]) + 0.35 * float(caster.spell_power), "magic")
	if pupil_index >= 0:
		ctx.log("Final Exam: named pupil %d and forced a reduced recast" % pupil_index)
	else:
		ctx.log("Final Exam: no pupil available; forced reduced recast only")
	return pupil_index >= 0 or target_index >= 0

func _pupil_index(ctx: AbilityContext) -> int:
	var allies: Array[Unit] = ctx.ally_team_array(ctx.caster_team)
	var best_index: int = -1
	var best_score: float = -INF
	for index: int in range(allies.size()):
		if index == ctx.caster_index:
			continue
		var ally: Unit = allies[index]
		if ally == null or not ally.is_alive():
			continue
		var score: float = float(ally.attack_damage) + float(ally.spell_power) + float(ally.attack_speed) * 35.0
		var role_id: String = String(ally.primary_role).strip_edges().to_lower()
		if role_id == "marksman" or role_id == "mage" or role_id == "assassin":
			score += 120.0
		if score > best_score:
			best_score = score
			best_index = index
	return best_index

func _apply_exam_buffs(ctx: AbilityContext, pupil_index: int, level_index: int) -> void:
	if ctx.buff_system == null:
		return
	var amp: float = DAMAGE_AMP[level_index]
	var stat_bonus: float = STAT_AMP[level_index]
	var mana_grant: int = MANA_GRANT[level_index]
	var allies: Array[Unit] = ctx.ally_team_array(ctx.caster_team)
	ctx.buff_system.push_source(ctx.caster_team, ctx.caster_index, "ability")
	for index: int in range(allies.size()):
		var ally: Unit = allies[index]
		if ally == null or not ally.is_alive():
			continue
		if index == pupil_index:
			ctx.buff_system.apply_tag(ctx.state, ctx.caster_team, index, BuffTags.TAG_DAMAGE_AMP, AMP_DURATION, {
				"damage_amp_pct": amp,
				"kind": "quillith_final_exam"
			})
			ctx.buff_system.apply_tag(ctx.state, ctx.caster_team, index, BuffTags.TAG_ABILITY_AMP, AMP_DURATION, {
				"ability_damage_amp": amp,
				"kind": "quillith_final_exam"
			})
			ctx.buff_system.apply_stats_labeled(ctx.state, ctx.caster_team, index, "quillith_pupil_exam", {
				"attack_damage": stat_bonus,
				"spell_power": stat_bonus,
				"mana_regen": 10.0
			}, AMP_DURATION)
			ctx.buff_system.apply_shield(ctx.state, ctx.caster_team, index, PUPIL_SHIELD[level_index], AMP_DURATION)
			ctx.buff_system.record_buff(ctx.state, ctx.caster_team, index, "quillith_pupil_amp", {
				"mana": mana_grant,
				"amp": amp
			}, stat_bonus, AMP_DURATION)
		elif index != ctx.caster_index:
			ctx.buff_system.apply_shield(ctx.state, ctx.caster_team, index, TEAM_SHIELD[level_index], AMP_DURATION)
			ctx.buff_system.record_buff(ctx.state, ctx.caster_team, index, "quillith_team_mana", {
				"mana": int(round(float(mana_grant) * 0.5))
			}, float(TEAM_SHIELD[level_index]), AMP_DURATION)
		if index != ctx.caster_index and int(ally.mana_max) > 0:
			var ally_mana_grant: int = mana_grant if index == pupil_index else int(round(float(mana_grant) * 0.5))
			ally.mana = min(int(ally.mana_max), int(ally.mana) + ally_mana_grant)
	ctx.buff_system.pop_source()
