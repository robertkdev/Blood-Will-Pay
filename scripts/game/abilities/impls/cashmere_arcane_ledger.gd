extends AbilityImplBase

# Cashmere — Arcane Ledger
# Fires an arcane blast at the current target, dealing
#   170/255/380 + 0.8×SP + 20×ArcanistStacks magic damage.
# On kill, 25% chance to grant +1 gold (no cap).

const BASE_BY_LEVEL := [170, 255, 380]
const TraitKeys := preload("res://scripts/game/traits/runtime/trait_keys.gd")
const ARCANIST_KEY := "arcanist_stacks" # Legacy fallback for old saved/test state.
const DROP_CHANCE := 0.25

func _level_index(u: Unit) -> int:
	var lvl: int = (int(u.level) if u != null else 1)
	return clamp(lvl - 1, 0, 2)

func _award_gold(n: int) -> void:
	if n <= 0:
		return
	Economy.add_stake_units(n, true, "cashmere_arcane_ledger")

func cast(ctx: AbilityContext) -> bool:
	if ctx == null or ctx.engine == null or ctx.state == null:
		return false
	var caster: Unit = ctx.unit_at(ctx.caster_team, ctx.caster_index)
	if caster == null or not caster.is_alive():
		return false
	var target_idx: int = ctx.current_target(ctx.caster_team, ctx.caster_index)
	if target_idx < 0:
		return false

	# Prefer unified TraitKeys; fallback to legacy key for back-compat
	var arcanist: int = 0
	if ctx.buff_system != null:
		arcanist = int(ctx.buff_system.get_stack(ctx.state, ctx.caster_team, ctx.caster_index, TraitKeys.ARCANIST))
		if arcanist <= 0:
			arcanist = int(ctx.buff_system.get_stack(ctx.state, ctx.caster_team, ctx.caster_index, ARCANIST_KEY))
	var li: int = _level_index(caster)
	var dmg_f: float = float(BASE_BY_LEVEL[li]) + 0.8 * float(caster.spell_power) + 20.0 * float(max(0, arcanist))
	var res: Dictionary = ctx.damage_single(ctx.caster_team, ctx.caster_index, target_idx, max(0.0, dmg_f), "magic")
	var killed: bool = false
	if not res.is_empty():
		var after_hp: int = int(res.get("after_hp", 1))
		var processed: bool = bool(res.get("processed", false))
		killed = processed and after_hp <= 0
	if killed:
		var roll: float = (ctx.rng.randf() if ctx.rng != null else 0.0)
		if roll < DROP_CHANCE:
			_award_gold(1)
			ctx.log("Arcane Ledger: +1U")
	return true
