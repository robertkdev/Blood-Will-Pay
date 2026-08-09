extends AbilityImplBase

const BuffTags := preload("res://scripts/game/abilities/buff_tags.gd")

const MANA_GRANT: Array[int] = [5, 10, 20]
const PUPIL_DAMAGE_AMP: Array[float] = [0.10, 0.15, 0.25]
const PUPIL_AMP_DURATION: float = 6.0

func _level_index(unit: Unit) -> int:
	var level: int = int(unit.level) if unit != null else 1
	return clamp(level - 1, 0, 2)

func cast(ctx: AbilityContext) -> bool:
	if ctx == null or ctx.engine == null or ctx.state == null or ctx.buff_system == null:
		return false
	var caster: Unit = ctx.unit_at(ctx.caster_team, ctx.caster_index)
	if caster == null or not caster.is_alive():
		return false
	var pupil_index: int = ctx.pupil_for(ctx.caster_team, ctx.caster_index)
	var pupil: Unit = ctx.unit_at(ctx.caster_team, pupil_index)
	if pupil_index < 0 or pupil == null or not pupil.is_alive():
		return false
	var level_index: int = _level_index(caster)
	var before_mana: int = int(pupil.mana)
	var mana_grant: int = int(round(ctx.scale_power(float(MANA_GRANT[level_index]))))
	pupil.mana = min(int(pupil.mana_max), before_mana + mana_grant)
	var granted: int = int(pupil.mana) - before_mana
	ctx.engine._resolver_emit_unit_stat(ctx.caster_team, pupil_index, {"mana": pupil.mana})
	ctx.buff_system.apply_tag(ctx.state, ctx.caster_team, pupil_index, BuffTags.TAG_DAMAGE_AMP, PUPIL_AMP_DURATION, {
		"damage_amp_pct": ctx.scale_power(float(PUPIL_DAMAGE_AMP[level_index])),
		"kind": "mentor_damage_amp"
	})
	ctx.log("Mentor's Reserve: Pupil gained %d mana and one damage amp" % granted)
	return true
