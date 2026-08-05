extends AbilityImplBase

const COMBO_KEY: String = "mortem_blood_feast_combo"
const SLASH_DAMAGE: Array[int] = [90, 135, 200]
const CLEAVE_DAMAGE: Array[int] = [120, 180, 270]
const SP_RATIO: float = 0.5
const CLEAVE_HEAL_RATIO: float = 0.35
const CLEAVE_RADIUS_TILES: float = 2.0

func _level_index(unit: Unit) -> int:
	var level: int = int(unit.level) if unit != null else 1
	return clamp(level - 1, 0, 2)

func cast(ctx: AbilityContext) -> bool:
	if ctx == null or ctx.engine == null or ctx.state == null or ctx.buff_system == null:
		return false
	var caster: Unit = ctx.unit_at(ctx.caster_team, ctx.caster_index)
	var target_index: int = ctx.current_target(ctx.caster_team, ctx.caster_index)
	if caster == null or not caster.is_alive():
		return false
	if target_index < 0:
		target_index = ctx.lowest_hp_enemy(ctx.caster_team)
	if target_index < 0:
		return false
	var stage: int = int(ctx.buff_system.get_stack(ctx.state, ctx.caster_team, ctx.caster_index, COMBO_KEY)) % 3
	var level_index: int = _level_index(caster)
	if stage < 2:
		var slash_damage: float = float(SLASH_DAMAGE[level_index]) + SP_RATIO * float(caster.spell_power)
		ctx.damage_single(ctx.caster_team, ctx.caster_index, target_index, slash_damage, "magic")
		ctx.log("Blood Feast: slash %d of 2" % (stage + 1))
	else:
		var target_team: String = ctx._other_team(ctx.caster_team)
		var center: Vector2 = ctx.position_of(target_team, target_index)
		var hits: Array[int] = ctx.enemies_in_radius_at(ctx.caster_team, center, CLEAVE_RADIUS_TILES)
		var cleave_damage: float = float(CLEAVE_DAMAGE[level_index]) + SP_RATIO * float(caster.spell_power)
		var total_dealt: float = 0.0
		for hit_index: int in hits:
			var result: Dictionary = ctx.damage_single(ctx.caster_team, ctx.caster_index, hit_index, cleave_damage, "magic")
			total_dealt += float(result.get("dealt", 0.0))
		ctx.heal_single(ctx.caster_team, ctx.caster_index, total_dealt * CLEAVE_HEAL_RATIO)
		ctx.log("Blood Feast: third slash cleaved %d and healed from damage" % hits.size())
	ctx.buff_system.add_stack(ctx.state, ctx.caster_team, ctx.caster_index, COMBO_KEY, 1)
	return true
