extends AbilityImplBase

const AbilityCatalog = preload("res://scripts/game/abilities/ability_catalog.gd")
const RECAST_POWER: float = 0.55

class ReducedAbilityContext extends AbilityContext:
	var power_scale: float = 1.0

	func _init(_engine: CombatEngine, _state: BattleState, _rng: RandomNumberGenerator, _caster_team: String, _caster_index: int, _power_scale: float) -> void:
		super(_engine, _state, _rng, _caster_team, _caster_index)
		power_scale = clamp(_power_scale, 0.0, 1.0)

	func damage_single(source_team: String, source_index: int, target_index: int, amount: float, type: String = "physical") -> Dictionary:
		return super.damage_single(source_team, source_index, target_index, amount * power_scale, type)

	func heal_single(target_team: String, target_index: int, amount: float) -> Dictionary:
		return super.heal_single(target_team, target_index, amount * power_scale)

	func stun(target_team: String, target_index: int, duration_s: float) -> Dictionary:
		return super.stun(target_team, target_index, duration_s * power_scale)

func cast(ctx: AbilityContext) -> bool:
	if ctx == null or ctx.engine == null or ctx.state == null:
		return false
	var caster: Unit = ctx.unit_at(ctx.caster_team, ctx.caster_index)
	if caster == null or not caster.is_alive():
		return false
	var pupil_index: int = _pupil_index(ctx)
	if pupil_index < 0:
		return false
	var pupil: Unit = ctx.unit_at(ctx.caster_team, pupil_index)
	if pupil == null or String(pupil.ability_id) == "" or String(pupil.ability_id) == "quillith_final_exam":
		return false
	var impl: Variant = AbilityCatalog.new_instance(String(pupil.ability_id))
	if impl == null or not impl.has_method("cast"):
		return false
	var recast_ctx: ReducedAbilityContext = ReducedAbilityContext.new(ctx.engine, ctx.state, ctx.rng, ctx.caster_team, pupil_index, RECAST_POWER)
	recast_ctx.buff_system = ctx.buff_system
	var recast_ok: bool = bool(impl.cast(recast_ctx))
	if not recast_ok:
		return false
	if ctx.engine.has_method("_resolver_emit_reset_triggered"):
		var target_index: int = recast_ctx.current_target(ctx.caster_team, pupil_index)
		ctx.engine._resolver_emit_reset_triggered(ctx.caster_team, pupil_index, ctx._other_team(ctx.caster_team), target_index, "quillith_final_exam_recast", 1, 0.0, RECAST_POWER)
	ctx.log("Final Exam: pupil %d repeated %s at 55%% power" % [pupil_index, String(pupil.ability_id)])
	return true

func _pupil_index(ctx: AbilityContext) -> int:
	var paired_index: int = ctx.pupil_for(ctx.caster_team, ctx.caster_index)
	var paired: Unit = ctx.unit_at(ctx.caster_team, paired_index)
	if paired_index >= 0 and paired != null and paired.is_alive() and String(paired.ability_id) != "quillith_final_exam":
		return paired_index
	var allies: Array[Unit] = ctx.ally_team_array(ctx.caster_team)
	var best_index: int = -1
	var best_score: float = -INF
	for index: int in range(allies.size()):
		if index == ctx.caster_index:
			continue
		var ally: Unit = allies[index]
		if ally == null or not ally.is_alive() or String(ally.ability_id) == "" or String(ally.ability_id) == "quillith_final_exam":
			continue
		var score: float = float(ally.cost * 200) + float(ally.attack_damage) + float(ally.spell_power)
		if score > best_score:
			best_score = score
			best_index = index
	return best_index
