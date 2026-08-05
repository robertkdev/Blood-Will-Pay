extends AbilityImplBase

const SHIELD_BASE: Array[int] = [110, 170, 255]
const SHIELD_SP_RATIO: float = 0.45
const SHIELD_DURATION: float = 3.0

func _level_index(unit: Unit) -> int:
	var level: int = int(unit.level) if unit != null else 1
	return clamp(level - 1, 0, 2)

func carry_index(state: BattleState, team: String, exclude_index: int = -1) -> int:
	if state == null:
		return -1
	var allies: Array[Unit] = state.player_team if team == "player" else state.enemy_team
	var totals: Array[int] = state.player_damage_this_round if team == "player" else state.enemy_damage_this_round
	var best_index: int = -1
	var best_damage: int = -1
	var best_tiebreak: float = -1.0
	for index: int in range(allies.size()):
		var ally: Unit = allies[index]
		if ally == null or not ally.is_alive() or index == exclude_index:
			continue
		var damage: int = int(totals[index]) if index < totals.size() else 0
		var role_bonus: float = 1000.0 if String(ally.get_primary_role()) in ["marksman", "mage", "assassin"] else 0.0
		var tiebreak: float = role_bonus + float(ally.attack_damage) + float(ally.spell_power)
		if damage > best_damage or (damage == best_damage and tiebreak > best_tiebreak):
			best_damage = damage
			best_tiebreak = tiebreak
			best_index = index
	return best_index

func cast(ctx: AbilityContext) -> bool:
	if ctx == null or ctx.engine == null or ctx.state == null or ctx.buff_system == null:
		return false
	var caster: Unit = ctx.unit_at(ctx.caster_team, ctx.caster_index)
	if caster == null or not caster.is_alive():
		return false
	var ally_index: int = carry_index(ctx.state, ctx.caster_team, ctx.caster_index)
	if ally_index < 0:
		ally_index = ctx.lowest_hp_ally(ctx.caster_team)
	if ally_index < 0:
		return false
	var shield_amount: int = int(round(float(SHIELD_BASE[_level_index(caster)]) + SHIELD_SP_RATIO * float(caster.spell_power)))
	ctx.buff_system.cleanse(ctx.state, ctx.caster_team, ally_index)
	ctx.buff_system.apply_shield(ctx.state, ctx.caster_team, ally_index, shield_amount, SHIELD_DURATION)
	ctx.log("Cleanse: cleansed and shielded carry %d" % ally_index)
	return true
