extends AbilityImplBase

const TraitKeys := preload("res://scripts/game/traits/runtime/trait_keys.gd")

const BASE_DAMAGE: Array[int] = [170, 255, 380]
const SP_RATIO: float = 0.8
const ARCANIST_DAMAGE_PER_STACK: float = 20.0
const STAKE_AWARDED_KEY: String = "mara_stake_awarded"

func _level_index(unit: Unit) -> int:
	var level: int = int(unit.level) if unit != null else 1
	return clamp(level - 1, 0, 2)

func cast(ctx: AbilityContext) -> bool:
	if ctx == null or ctx.engine == null or ctx.state == null:
		return false
	var caster: Unit = ctx.unit_at(ctx.caster_team, ctx.caster_index)
	var target_index: int = ctx.current_target(ctx.caster_team, ctx.caster_index)
	if caster == null or not caster.is_alive() or target_index < 0:
		return false
	var stacks: int = 0
	if ctx.buff_system != null:
		stacks = int(ctx.buff_system.get_stack(ctx.state, ctx.caster_team, ctx.caster_index, TraitKeys.ARCANIST))
	var damage: float = float(BASE_DAMAGE[_level_index(caster)]) + SP_RATIO * float(caster.spell_power) + ARCANIST_DAMAGE_PER_STACK * float(max(0, stacks))
	var result: Dictionary = ctx.damage_single(ctx.caster_team, ctx.caster_index, target_index, damage, "magic")
	var killed: bool = bool(result.get("processed", false)) and int(result.get("after_hp", 1)) <= 0
	var already_awarded: bool = ctx.buff_system != null and int(ctx.buff_system.get_stack(ctx.state, ctx.caster_team, ctx.caster_index, STAKE_AWARDED_KEY)) > 0
	if killed and not already_awarded:
		Economy.add_stake_units(1, true, "mara_arcane_ledger")
		if ctx.buff_system != null:
			ctx.buff_system.add_stack(ctx.state, ctx.caster_team, ctx.caster_index, STAKE_AWARDED_KEY, 1)
		ctx.log("Arcane Ledger: +1 blood Stake, capped this combat")
	return true
