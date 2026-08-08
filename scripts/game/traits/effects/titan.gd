extends TraitHandler

const StackUtils := preload("res://scripts/game/traits/runtime/stack_utils.gd")
const TickAccumulator := preload("res://scripts/game/traits/runtime/tick_accumulator.gd")
const TraitKeys := preload("res://scripts/game/traits/runtime/trait_keys.gd")
const Health := preload("res://scripts/game/stats/health.gd")
const HealingService := preload("res://scripts/game/traits/runtime/healing_service.gd")

const TRAIT_ID := "Titan"

# Tier tables
const MEMBER_MAX_HP_PCT := [0.20, 0.40, 0.60, 0.90]
const ALLY_REGEN_PCT := [0.02, 0.03, 0.04, 0.05]
const STACKS_ON_CAST := [1, 2, 3, 4]
const PULSE_SECONDS := 4.0
const SHIELD_CAP_PCT_T4 := 0.20 # At tier 4 (index 3), overheal converts to shields up to 20% Max HP
const BATTLE_LONG := 9999.0

var _accum_player: TickAccumulator = TickAccumulator.new()
var _accum_enemy: TickAccumulator = TickAccumulator.new()

# Track last seen Titan stacks per unit to avoid duplicate adds while abilities still add stacks.
# Keyed by "team|index" -> int
var _last_stack_seen: Dictionary = {}

func on_battle_start(ctx):
	_accum_player.configure(PULSE_SECONDS)
	_accum_enemy.configure(PULSE_SECONDS)
	_last_stack_seen.clear()
	# Apply member Max HP bonus per team by tier
	_apply_member_max_hp_bonus(ctx, "player")
	_apply_member_max_hp_bonus(ctx, "enemy")

func on_tick(ctx, delta: float):
	# Regen pulses every 4s for allies on teams where Titan is active
	var d: float = max(0.0, float(delta))
	if d <= 0.0:
		return
	if StackUtils.is_active(ctx, "player", TRAIT_ID):
		_accum_player.accumulate(d)
		var n: int = _accum_player.consume_pulses()
		if n > 0:
			for _i in range(n):
				_apply_regen_pulse(ctx, "player")
	if StackUtils.is_active(ctx, "enemy", TRAIT_ID):
		_accum_enemy.accumulate(d)
		var m: int = _accum_enemy.consume_pulses()
		if m > 0:
			for _j in range(m):
				_apply_regen_pulse(ctx, "enemy")

func on_ability_cast(ctx, team: String, index: int, _ability_id: String):
	# Add Titan stacks on cast for members when trait is active; avoid duplicate adds if ability already handled it.
	var t: int = StackUtils.tier(ctx, team, TRAIT_ID)
	if t < 0:
		return
	# membership check
	var mem: Array[int] = StackUtils.members(ctx, team, TRAIT_ID)
	if mem.find(int(index)) < 0:
		return
	var key: String = _key(team, index)
	var current: int = StackUtils.get_count(ctx, team, index, TRAIT_ID)
	var last: int = int(_last_stack_seen.get(key, -1))
	# If we have seen a prior value and current increased, assume ability already added; just record and return.
	if last >= 0 and current > last:
		_last_stack_seen[key] = current
		return
	var add_n: int = int(StackUtils.value_by_tier(t, STACKS_ON_CAST))
	if add_n <= 0:
		_last_stack_seen[key] = current
		return
	var new_count: int = StackUtils.add_stacks(ctx, team, index, TRAIT_ID, add_n)
	_last_stack_seen[key] = new_count

func _apply_member_max_hp_bonus(ctx, team: String) -> void:
	var t: int = StackUtils.tier(ctx, team, TRAIT_ID)
	if t < 0:
		return
	var pct: float = StackUtils.value_by_tier(t, MEMBER_MAX_HP_PCT)
	if pct <= 0.0:
		return
	var indices: Array[int] = StackUtils.members(ctx, team, TRAIT_ID)
	for i in indices:
		var u: Unit = ctx.unit_at(team, int(i))
		if u == null:
			continue
		var delta_hp: int = int(floor(pct * float(u.max_hp)))
		if delta_hp != 0:
			ctx.buff_system.apply_stats_buff(ctx.state, team, int(i), {"max_hp": delta_hp}, BATTLE_LONG)

func _apply_regen_pulse(ctx, team: String) -> void:
	var t: int = StackUtils.tier(ctx, team, TRAIT_ID)
	if t < 0:
		return
	var regen_pct: float = StackUtils.value_by_tier(t, ALLY_REGEN_PCT)
	if regen_pct <= 0.0:
		return
	var arr: Array[Unit] = (ctx.state.player_team if team == "player" else ctx.state.enemy_team)
	var shield_cap_pct: float = (SHIELD_CAP_PCT_T4 if t >= 3 else 0.0)
	for i in range(arr.size()):
		var u: Unit = arr[i]
		if u == null or not u.is_alive():
			continue
		var heal_amt: int = int(max(0.0, floor(regen_pct * float(u.max_hp))))
		if heal_amt <= 0:
			continue
		# Route through HealingService so generic healing mods apply (e.g., Blessed),
		# then enforce Titan T4 shield cap separately.
		var hres2: Dictionary = HealingService.apply_heal(ctx.state, ctx.buff_system, team, i, float(heal_amt))
		var healed: int = int(hres2.get("healed", 0))
		var overheal: int = int(hres2.get("overheal", 0))
		if ctx.engine != null and ctx.engine.has_method("_resolver_emit_heal_applied"):
			ctx.engine._resolver_emit_heal_applied(
				team,
				i,
				team,
				i,
				healed,
				overheal,
				int(hres2.get("before_hp", 0)),
				int(hres2.get("after_hp", 0))
			)
		if shield_cap_pct > 0.0 and overheal > 0 and ctx.buff_system != null:
			var cap: int = int(floor(shield_cap_pct * float(u.max_hp)))
			var have: int = int(u.ui_shield)
			var add_shield: int = min(overheal, max(0, cap - have))
			if add_shield > 0:
				ctx.buff_system.apply_shield(ctx.state, team, i, add_shield, BATTLE_LONG)

func _key(team: String, index: int) -> String:
	return String(team) + "|" + str(int(index))
