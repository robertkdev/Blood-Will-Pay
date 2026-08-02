extends AbilityImplBase

const IdentityKeys := preload("res://scripts/game/identity/identity_keys.gd")

# Repo - Writ of Severance
# Heals for 90/130/170 plus 90%/130%/170% SP, then slashes the current
# target for 215%/325%/520% AD physical damage. Damage is increased by 60%
# against Tank-class enemies. On kill, immediately recasts at 75% damage.

const HEAL_BASE: Array[int] = [90, 130, 170]
const HEAL_SP_MULT: Array[float] = [0.90, 1.30, 1.70]
const AD_MULT: Array[float] = [2.15, 3.25, 5.20]
const BONUS_VS_TANK: float = 0.60
const RECAST_DMG_SCALE: float = 0.75

func _level_index(unit: Unit) -> int:
	var level: int = int(unit.level) if unit != null else 1
	return clamp(level - 1, 0, 2)

func _is_tank_identity(unit: Unit) -> bool:
	if unit == null:
		return false
	if unit.is_primary_role(IdentityKeys.ROLE_TANK):
		return true
	# Legacy fallback while migration completes.
	for role_value: Variant in unit.roles:
		var role_name: String = String(role_value).to_lower()
		if role_name.find("tank") >= 0:
			return true
	return false

func _slash(ctx: AbilityContext, target_index: int, base_damage: float) -> Dictionary:
	var target: Unit = ctx.unit_at(ctx._other_team(ctx.caster_team), target_index)
	var damage: float = base_damage
	if _is_tank_identity(target):
		damage *= 1.0 + BONUS_VS_TANK
	return ctx.damage_single(ctx.caster_team, ctx.caster_index, target_index, max(0.0, damage), "physical")

func cast(ctx: AbilityContext) -> bool:
	if ctx == null or ctx.engine == null or ctx.state == null:
		return false
	var caster: Unit = ctx.unit_at(ctx.caster_team, ctx.caster_index)
	if caster == null or not caster.is_alive():
		return false
	var target_index: int = ctx.current_target(ctx.caster_team, ctx.caster_index)
	if target_index < 0:
		return false

	var level_index: int = _level_index(caster)
	var heal_amount: float = float(HEAL_BASE[level_index]) + HEAL_SP_MULT[level_index] * float(caster.spell_power)
	ctx.heal_single(ctx.caster_team, ctx.caster_index, heal_amount)

	var raw_damage: float = AD_MULT[level_index] * float(caster.attack_damage)
	var result: Dictionary = _slash(ctx, target_index, raw_damage)
	var after_hp: int = int(result.get("after_hp", 1))
	var dealt: int = int(result.get("dealt", 0))
	var killed: bool = after_hp <= 0
	if killed:
		# Recast at 75% damage on a new current target.
		var next_index: int = ctx.current_target(ctx.caster_team, ctx.caster_index)
		if next_index >= 0 and ctx.is_alive(ctx._other_team(ctx.caster_team), next_index):
			var recast_result: Dictionary = _slash(ctx, next_index, raw_damage * RECAST_DMG_SCALE)
			if bool(recast_result.get("processed", false)) and ctx.engine.has_method("_resolver_emit_reset_triggered"):
				ctx.engine._resolver_emit_reset_triggered(ctx.caster_team, ctx.caster_index, ctx._other_team(ctx.caster_team), next_index, "repo_kill_recast", 1, 0.0, RECAST_DMG_SCALE)
			ctx.log("Writ of Severance: recast at 75%")
	else:
		ctx.log("Writ of Severance: dealt %d (raw %.0f)" % [dealt, raw_damage])
	return true
