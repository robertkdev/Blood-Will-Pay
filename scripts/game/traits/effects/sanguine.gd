extends TraitHandler

const StackUtils := preload("res://scripts/game/traits/runtime/stack_utils.gd")
const GroupApply := preload("res://scripts/game/traits/runtime/group_apply.gd")
const HealingService := preload("res://scripts/game/traits/runtime/healing_service.gd")

const TRAIT_ID := "Sanguine"

# Omnivamp (members) by tier (thresholds 2/4/6)
const MEMBER_OMNI := [0.20, 0.40, 0.80]
# Allies receive half omnivamp at higher tiers (T4+)
const ALLY_FACTOR := 0.5

# T4: convert overheal into a shield up to 20% of damage dealt (per hit)
const OVERHEAL_TO_SHIELD_PCT := 0.20

# T6: funnel 50% of remaining overheal to the lowest-HP ally
const FUNNEL_OVERHEAL_PCT := 0.50

const BATTLE_LONG := 9999.0

func on_battle_start(ctx):
	assert(ctx != null and ctx.state != null)
	assert(ctx.buff_system != null)
	_apply_omnivamp(ctx, "player")
	_apply_omnivamp(ctx, "enemy")

func on_hit_applied(ctx, event: Dictionary):
	# Heal on ability damage only; basic attacks already lifesteal via unit.lifesteal.
	if ctx == null or ctx.state == null:
		return
	var team: String = String(event.get("team", "player"))
	var src_idx: int = int(event.get("source_index", -1))
	var dealt: int = int(event.get("dealt", 0))
	if src_idx < 0 or dealt <= 0:
		return
	var t: int = StackUtils.tier(ctx, team, TRAIT_ID)
	if t < 0:
		return
	# Ability damage heuristic: AbilityEffects emits 0.0/0.0 cooldowns
	var pcd: float = float(event.get("player_cd", 0.0))
	var ecd: float = float(event.get("enemy_cd", 0.0))
	var is_ability: bool = (pcd == 0.0 and ecd == 0.0)
	if not is_ability:
		return

	var mem_indices: Array[int] = StackUtils.members(ctx, team, TRAIT_ID)
	var is_member: bool = mem_indices.find(src_idx) >= 0
	var omni: float = StackUtils.value_by_tier(t, MEMBER_OMNI)
	if omni <= 0.0:
		return
	# Allies gain half at higher tiers only
	if not is_member:
		if t >= 1:
			omni *= ALLY_FACTOR
		else:
			return

	var u: Unit = ctx.unit_at(team, src_idx)
	if u == null or not u.is_alive():
		return

	var raw_heal: int = int(max(0.0, floor(float(dealt) * omni)))
	if raw_heal <= 0:
		return
	var hres: Dictionary = HealingService.apply_heal(ctx.state, ctx.buff_system, team, src_idx, float(raw_heal))
	var overheal: int = int(hres.get("overheal", 0))
	_emit_heal(ctx, team, src_idx, team, src_idx, hres)

	if overheal > 0 and t >= 1 and ctx.buff_system != null:
		# T4: convert part of overheal into a shield up to 20% of damage dealt
		var cap_by_dmg: int = int(floor(OVERHEAL_TO_SHIELD_PCT * float(dealt)))
		var shield_amt: int = min(overheal, max(0, cap_by_dmg))
		if shield_amt > 0:
			ctx.buff_system.apply_shield(ctx.state, team, src_idx, shield_amt, BATTLE_LONG)
			overheal -= shield_amt

	if overheal > 0 and t >= 2:
		# T6: funnel 50% of remaining overheal to the lowest-HP ally (excluding self)
		var ally_idx: int = _lowest_hp_ally_excluding(ctx, team, src_idx)
		if ally_idx >= 0:
			var funnel: int = int(floor(float(overheal) * FUNNEL_OVERHEAL_PCT))
			if funnel > 0:
				var ally: Unit = ctx.unit_at(team, ally_idx)
				if ally != null and ally.is_alive():
					var funnel_result: Dictionary = HealingService.apply_heal(ctx.state, ctx.buff_system, team, ally_idx, float(funnel))
					_emit_heal(ctx, team, src_idx, team, ally_idx, funnel_result)

func _emit_heal(ctx: TraitContext, source_team: String, source_index: int, target_team: String, target_index: int, result: Dictionary) -> void:
	if ctx == null or ctx.engine == null or not bool(result.get("processed", false)):
		return
	if not ctx.engine.has_method("_resolver_emit_heal_applied"):
		return
	ctx.engine._resolver_emit_heal_applied(
		source_team,
		source_index,
		target_team,
		target_index,
		int(result.get("healed", 0)),
		int(result.get("overheal", 0)),
		int(result.get("before_hp", 0)),
		int(result.get("after_hp", 0))
	)

func _apply_omnivamp(ctx, team: String) -> void:
	var t: int = StackUtils.tier(ctx, team, TRAIT_ID)
	if t < 0:
		return
	var omni_mem: float = StackUtils.value_by_tier(t, MEMBER_OMNI)
	if omni_mem <= 0.0:
		return
	var mem_indices: Array[int] = StackUtils.members(ctx, team, TRAIT_ID)
	if mem_indices.size() > 0:
		GroupApply.stats(ctx.buff_system, ctx.state, team, mem_indices, {"lifesteal": omni_mem}, BATTLE_LONG)

	# Allies half at higher tiers only
	if t >= 1:
		var arr: Array[Unit] = (ctx.state.player_team if team == "player" else ctx.state.enemy_team)
		var nonmem: Array[int] = []
		var mem_set: Dictionary = {}
		for i in mem_indices:
			mem_set[int(i)] = true
		for i in range(arr.size()):
			if arr[i] == null:
				continue
			if not mem_set.has(i):
				nonmem.append(i)
		if nonmem.size() > 0:
			GroupApply.stats(ctx.buff_system, ctx.state, team, nonmem, {"lifesteal": omni_mem * ALLY_FACTOR}, BATTLE_LONG)

func _lowest_hp_ally_excluding(ctx, team: String, exclude_idx: int) -> int:
	var arr: Array[Unit] = (ctx.state.player_team if team == "player" else ctx.state.enemy_team)
	var best_idx: int = -1
	var best_hp: int = 1 << 30
	for i in range(arr.size()):
		if i == exclude_idx:
			continue
		var u: Unit = arr[i]
		if u == null or not u.is_alive():
			continue
		if int(u.hp) < best_hp:
			best_hp = int(u.hp)
			best_idx = i
	return best_idx
