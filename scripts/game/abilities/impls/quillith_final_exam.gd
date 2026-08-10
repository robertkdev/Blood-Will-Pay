extends AbilityImplBase

const AbilityCatalog = preload("res://scripts/game/abilities/ability_catalog.gd")
const RECAST_POWER: float = 0.55

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
	if ctx.buff_system != null and ctx.buff_system.is_stunned(pupil):
		return false
	var impl: Variant = AbilityCatalog.new_instance(String(pupil.ability_id))
	if impl == null or not impl.has_method("cast"):
		return false
	if ctx.engine.ability_system == null:
		return false
	var recast_ctx: AbilityContext = AbilityContext.new(ctx.engine, ctx.state, ctx.rng, ctx.caster_team, pupil_index)
	recast_ctx.buff_system = ctx.buff_system
	recast_ctx.power_scale = RECAST_POWER
	var recast_ok: bool = ctx.engine.ability_system.cast_implementation(impl, recast_ctx, "quillith_pupil")
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
	return -1
