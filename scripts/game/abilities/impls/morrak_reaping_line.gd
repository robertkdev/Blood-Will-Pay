extends AbilityImplBase

const TraitKeys := preload("res://scripts/game/traits/runtime/trait_keys.gd")

const LINE_LENGTH_TILES: float = 4.0
const LINE_WIDTH_TILES: float = 1.1
const BASE_DAMAGE: Array[int] = [110, 165, 250]
const AD_RATIO: float = 0.9

func _level_index(unit: Unit) -> int:
	var level: int = int(unit.level) if unit != null else 1
	return clamp(level - 1, 0, 2)

func _execute_threshold(ctx: AbilityContext) -> float:
	var executioner_stacks: int = 0
	if ctx.buff_system != null:
		executioner_stacks = int(ctx.buff_system.get_stack(ctx.state, ctx.caster_team, ctx.caster_index, TraitKeys.EXECUTIONER))
	return clamp(0.12 + 0.02 * float(max(0, executioner_stacks)), 0.0, 0.40)

func cast(ctx: AbilityContext) -> bool:
	if ctx == null or ctx.engine == null or ctx.state == null:
		return false
	var caster: Unit = ctx.unit_at(ctx.caster_team, ctx.caster_index)
	var target_index: int = ctx.current_target(ctx.caster_team, ctx.caster_index)
	if caster == null or not caster.is_alive() or target_index < 0:
		return false
	var damage: float = float(BASE_DAMAGE[_level_index(caster)]) + AD_RATIO * float(caster.attack_damage)
	var threshold: float = _execute_threshold(ctx)
	var target_team: String = ctx._other_team(ctx.caster_team)
	var hits: Array[int] = ctx.enemies_in_line(ctx.caster_team, ctx.caster_index, target_index, LINE_LENGTH_TILES, LINE_WIDTH_TILES)
	for hit_index: int in hits:
		var victim: Unit = ctx.unit_at(target_team, hit_index)
		if victim == null or not victim.is_alive():
			continue
		var hp_ratio: float = float(victim.hp) / max(1.0, float(victim.max_hp))
		if hp_ratio <= threshold:
			ctx.emit_execute_bonus(target_team, hit_index, 0.0, float(victim.hp), threshold, hp_ratio, "morrak_reaping_line")
			ctx.damage_single(ctx.caster_team, ctx.caster_index, hit_index, float(victim.hp), "true")
		else:
			ctx.damage_single(ctx.caster_team, ctx.caster_index, hit_index, damage, "physical")
	ctx.log("Reaping Line: cleaved %d enemies; honest execute threshold %.0f%%" % [hits.size(), threshold * 100.0])
	return true
