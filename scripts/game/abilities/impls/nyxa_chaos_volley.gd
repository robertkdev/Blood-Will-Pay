extends AbilityImplBase

# Nyxa — Chaos Volley
# For the next four attacks, fires at random enemies.
# Gains +1 bonus arrow per cast, up to a maximum of four.

const BuffTags := preload("res://scripts/game/abilities/buff_tags.gd")
const KEY_BONUS := "nyxa_cv_bonus_arrows" # persistent: number of extra arrows per attack (0..3)
const KEY_DMG_STACKS := "nyxa_cv_damage_stacks" # persistent: number of casts beyond cap (after reaching 4 total shots)
const TAG_ACTIVE := BuffTags.TAG_NYXA # timed tag during which multishot applies
const INITIAL_VOLLEY_SHOTS := 4
const INITIAL_VOLLEY_BASE := [80, 120, 170]
const INITIAL_VOLLEY_AD_SCALE := 0.65
const INITIAL_VOLLEY_SP_SCALE := 0.40
const VOLLEY_AD_BUFF_PCT := 0.15

func cast(ctx: AbilityContext) -> bool:
	if ctx == null:
		return false
	var bs: BuffSystem = ctx.buff_system
	if bs == null:
		ctx.log("[Chaos Volley] BuffSystem not available; cast aborted")
		return false

	# Increment persistent bonus arrows, capped at 3 (total shots = 1 + bonus => max 4)
	var current_bonus: int = int(bs.get_stack(ctx.state, ctx.caster_team, ctx.caster_index, KEY_BONUS))
	var new_bonus: int = min(3, current_bonus + 1)
	var delta_bonus: int = new_bonus - current_bonus
	if delta_bonus != 0:
		bs.add_stack(ctx.state, ctx.caster_team, ctx.caster_index, KEY_BONUS, delta_bonus)
	# Beyond the 3rd cast, stack damage bonus that scales with AD on ability shots
	var over_cap_cast: bool = (current_bonus >= 3)
	var dmg_stacks_after: int = int(bs.get_stack(ctx.state, ctx.caster_team, ctx.caster_index, KEY_DMG_STACKS))
	if over_cap_cast:
		dmg_stacks_after += 1
		bs.add_stack(ctx.state, ctx.caster_team, ctx.caster_index, KEY_DMG_STACKS, 1)

	# Duration approximates 4 attacks at current attack speed
	var caster: Unit = ctx.unit_at(ctx.caster_team, ctx.caster_index)
	var atk_spd: float = 1.0
	if caster:
		atk_spd = max(0.1, float(caster.attack_speed))
	var duration_s: float = clamp(4.0 / atk_spd, 2.0, 8.0)

	# Apply/refresh active tag with metadata for resolver and VFX
	var ad: float = 0.0
	if caster:
		ad = max(0.0, float(caster.attack_damage))
	var damage_bonus_per_stack: int = int(max(1.0, round(0.35 * ad))) # +35% AD per extra cast beyond cap
	var meta: Dictionary = {
		"extra": new_bonus, # number of extra shots (total = 1 + extra)
		"damage_bonus": int(max(0, dmg_stacks_after)) * damage_bonus_per_stack,
		"block_mana_gain": true
	}
	bs.apply_tag(ctx.state, ctx.caster_team, ctx.caster_index, TAG_ACTIVE, duration_s, meta)
	var total_shots: int = 1 + int(meta["extra"])
	ctx.emit_ramp_state("stack_window", total_shots, float(total_shots + int(meta["damage_bonus"])), 4, duration_s, "nyxa_chaos_volley")
	if dmg_stacks_after > 0:
		ctx.emit_ramp_state("damage_stack", dmg_stacks_after, float(int(meta["damage_bonus"])), 0, duration_s, "nyxa_chaos_volley_damage")
	# Lean into the frenzy: modest attack-damage steroid so every arrow hurts more
	if ad > 0.0:
		var delta_ad: float = ad * VOLLEY_AD_BUFF_PCT
		bs.apply_stats_buff(ctx.state, ctx.caster_team, ctx.caster_index, {"attack_damage": delta_ad}, duration_s)

	var dmg_bonus_msg: String = (" (+%d per shot)" % int(meta["damage_bonus"])) if int(meta["damage_bonus"]) > 0 else ""
	ctx.log("Chaos Volley: %d shots for %.1fs%s" % [total_shots, duration_s, dmg_bonus_msg])
	_initial_volley(ctx, caster, _level_index(caster))
	return true

func _level_index(u: Unit) -> int:
	var lvl: int = (int(u.level) if u != null else 1)
	return clamp(lvl - 1, 0, 2)

func _initial_volley(ctx: AbilityContext, caster: Unit, lvl_idx: int) -> void:
	if ctx == null or caster == null:
		return
	var alive: Array[int] = _alive_enemy_indices(ctx, ctx.caster_team)
	if alive.is_empty():
		return
	var shots: int = min(INITIAL_VOLLEY_SHOTS, alive.size())
	var rng: RandomNumberGenerator = (ctx.rng if ctx.rng != null else RandomNumberGenerator.new())
	if ctx.rng == null:
		rng.randomize()
	for _i in range(shots):
		if alive.is_empty():
			break
		var pick: int = rng.randi_range(0, alive.size() - 1)
		var enemy_index: int = int(alive[pick])
		alive.remove_at(pick)
		var dmg: float = _initial_volley_damage(caster, lvl_idx)
		ctx.damage_single(ctx.caster_team, ctx.caster_index, enemy_index, dmg, "physical")

func _alive_enemy_indices(ctx: AbilityContext, team: String) -> Array[int]:
	var out: Array[int] = []
	var enemies: Array[Unit] = ctx.enemy_team_array(team)
	var target_team: String = "enemy" if team == "player" else "player"
	for i in range(enemies.size()):
		var enemy: Unit = enemies[i]
		if enemy != null and ctx.is_targetable(target_team, i):
			out.append(i)
	return out

func _initial_volley_damage(caster: Unit, lvl_idx: int) -> float:
	var ad: float = 0.0
	var sp: float = 0.0
	if caster != null:
		ad = max(0.0, float(caster.attack_damage))
		sp = max(0.0, float(caster.spell_power))
	return max(0.0, float(INITIAL_VOLLEY_BASE[lvl_idx]) + INITIAL_VOLLEY_AD_SCALE * ad + INITIAL_VOLLEY_SP_SCALE * sp)
