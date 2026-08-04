extends ItemEffectBase
class_name CompletedItemRuntimeEffect

const AbilityEffects := preload("res://scripts/game/abilities/effects.gd")
const BuffTags := preload("res://scripts/game/abilities/buff_tags.gd")

const SHORT_DURATION: float = 3.0
const MEDIUM_DURATION: float = 5.0
const LONG_DURATION: float = 8.0
const BATTLE_DURATION: float = 3600.0

var effect_id: String = ""
var _counters: Dictionary = {}
var _flags: Dictionary = {}

func _init(id: String = "") -> void:
	effect_id = String(id).strip_edges()

func on_event(unit: Unit, event: String, data: Dictionary) -> void:
	if unit == null or effect_id == "" or engine == null or buff_system == null:
		return
	match effect_id:
		"anchor":
			_anchor(unit, event, data)
		"arc_dice":
			_arc_dice(unit, event, data)
		"armageddon":
			_armageddon(unit, event, data)
		"chestplate":
			_chestplate(unit, event)
		"clockwork":
			_clockwork(unit, event)
		"codex":
			_codex(unit, event, data)
		"conductor":
			_conductor(unit, event)
		"dagger":
			_dagger(unit, event, data)
		"gamblers_eye":
			_gamblers_eye(unit, event, data)
		"guard":
			_guard(unit, event)
		"heavyheart":
			_heavyheart(unit, event)
		"hemothorn":
			_hemothorn(unit, event, data)
		"largewand":
			_largewand(unit, event, data)
		"lifetaker":
			_lifetaker(unit, event, data)
		"mageheart":
			_mageheart(unit, event, data)
		"orb_on_a_stick":
			_orb_on_a_stick(unit, event)
		"piercing_gear":
			_piercing_gear(unit, event, data)
		"relay":
			_relay(unit, event, data)
		"rendsaw":
			_rendsaw(unit, event, data)
		"sanctum":
			_sanctum(unit, event)
		"serenity":
			_serenity(unit, event)
		"stone":
			_stone(unit, event)
		"thunderplate":
			_thunderplate(unit, event, data)
		"vengeance":
			_vengeance(unit, event, data)
		"vital_battery":
			_vital_battery(unit, event)
		"wardheart":
			_wardheart(unit, event)
		"windwall":
			_windwall(unit, event)

func _anchor(unit: Unit, event: String, data: Dictionary) -> void:
	var ctx: Dictionary = _context(unit)
	if event == "combat_started":
		_shield(ctx, ctx, max(70, int(round(float(unit.max_hp) * 0.10 + float(unit.armor) * 2.0))), MEDIUM_DURATION)
	elif event == "hit_taken" and not _used(unit, "anchor_drag"):
		var attacker_team: String = String(data.get("attacker_team", ""))
		var attacker_index: int = int(data.get("attacker_index", -1))
		if attacker_team != "" and attacker_index >= 0:
			_mark_used(unit, "anchor_drag")
			_stun(attacker_team, attacker_index, 0.35, ctx)
			_apply_stats(attacker_team, attacker_index, {"attack_speed": -0.08}, SHORT_DURATION, ctx, "item")

func _arc_dice(unit: Unit, event: String, data: Dictionary) -> void:
	if event != "ability_cast":
		return
	var ctx: Dictionary = _context(unit)
	var target_index: int = _event_enemy_target_index(ctx, data)
	var cast_count: int = _bump(unit, "arc_dice_casts")
	var face_bonus: float = 0.06 * float(1 + ((cast_count - 1) % 3))
	var amount: int = int(round(22.0 + float(unit.spell_power) * (0.24 + face_bonus)))
	_damage_enemy(ctx, target_index, amount, "magic")

func _armageddon(unit: Unit, event: String, _data: Dictionary) -> void:
	if event != "hit_taken" or _used(unit, "armageddon"):
		return
	if _hp_ratio(unit) > 0.55:
		return
	_mark_used(unit, "armageddon")
	var ctx: Dictionary = _context(unit)
	var amount: int = int(round(45.0 + float(unit.attack_damage) * 0.45 + float(unit.armor) * 0.35))
	_damage_all_enemies(ctx, amount, "magic")
	_stun_first_enemy(ctx, 0.35)

func _chestplate(unit: Unit, event: String) -> void:
	if event != "combat_started":
		return
	var ctx: Dictionary = _context(unit)
	_shield(ctx, ctx, max(80, int(round(float(unit.armor) * 4.0 + float(unit.max_hp) * 0.06))), LONG_DURATION)

func _clockwork(unit: Unit, event: String) -> void:
	var ctx: Dictionary = _context(unit)
	if event == "combat_started":
		_apply_stats(String(ctx.get("team", "")), int(ctx.get("index", -1)), {"attack_speed": 0.08, "mana_regen": 4.0}, LONG_DURATION, ctx, "item")
	elif event == "hit_dealt":
		if _bump(unit, "clockwork_hits") % 3 == 0:
			_gain_mana(String(ctx.get("team", "")), int(ctx.get("index", -1)), 8)

func _codex(unit: Unit, event: String, _data: Dictionary) -> void:
	if event != "ability_cast":
		return
	var ctx: Dictionary = _context(unit)
	var ally_index: int = _lowest_hp_ally_index(String(ctx.get("team", "")))
	_shield({"team": String(ctx.get("team", "")), "index": ally_index}, ctx, int(round(70.0 + float(unit.spell_power) * 0.45 + float(unit.armor) * 1.4)), MEDIUM_DURATION)
	_apply_stats(String(ctx.get("team", "")), ally_index, {"spell_power": 14.0}, MEDIUM_DURATION, ctx, "item")

func _conductor(unit: Unit, event: String) -> void:
	var ctx: Dictionary = _context(unit)
	if event == "combat_started":
		_apply_stats(String(ctx.get("team", "")), int(ctx.get("index", -1)), {"mana_regen": 6.0}, LONG_DURATION, ctx, "item")
	elif event == "ability_cast":
		var ally_index: int = _lowest_mana_ally_index(String(ctx.get("team", "")))
		_gain_mana(String(ctx.get("team", "")), ally_index, 12)
		_apply_stats(String(ctx.get("team", "")), ally_index, {"attack_speed": 0.06}, SHORT_DURATION, ctx, "item")

func _dagger(unit: Unit, event: String, data: Dictionary) -> void:
	if event != "hit_dealt":
		return
	var count: int = _bump(unit, "dagger_hits")
	if count % 3 != 0:
		return
	var ctx: Dictionary = _context(unit)
	_damage_enemy(ctx, int(data.get("target_index", -1)), int(round(float(unit.attack_damage) * 0.40)), "physical")
	_apply_stats(String(ctx.get("team", "")), int(ctx.get("index", -1)), {"attack_speed": 0.08}, SHORT_DURATION, ctx, "item")

func _gamblers_eye(unit: Unit, event: String, data: Dictionary) -> void:
	if event != "hit_dealt" or not bool(data.get("crit", false)):
		return
	var ctx: Dictionary = _context(unit)
	var amount: int = int(round(18.0 + float(unit.attack_damage) * 0.20 + float(unit.spell_power) * 0.15))
	_damage_enemy(ctx, int(data.get("target_index", -1)), amount, "true")
	if int(data.get("after_hp", 1)) <= 0:
		_apply_stats(String(ctx.get("team", "")), int(ctx.get("index", -1)), {"crit_damage": 0.12}, MEDIUM_DURATION, ctx, "item")

func _guard(unit: Unit, event: String) -> void:
	if event != "combat_started":
		return
	var ctx: Dictionary = _context(unit)
	_apply_stats(String(ctx.get("team", "")), int(ctx.get("index", -1)), {"damage_reduction": 0.08}, LONG_DURATION, ctx, "item")
	_shield(ctx, ctx, max(100, int(round(float(unit.max_hp) * 0.08 + float(unit.armor) * 2.0))), LONG_DURATION)

func _heavyheart(unit: Unit, event: String) -> void:
	if event != "hit_taken" or _used(unit, "heavyheart"):
		return
	if _hp_ratio(unit) > 0.50:
		return
	_mark_used(unit, "heavyheart")
	var ctx: Dictionary = _context(unit)
	var pulse: int = max(80, int(round(float(unit.max_hp) * 0.12)))
	_heal(ctx, ctx, pulse)
	_shield(ctx, ctx, pulse, MEDIUM_DURATION)

func _hemothorn(unit: Unit, event: String, data: Dictionary) -> void:
	if event != "hit_dealt":
		return
	var ctx: Dictionary = _context(unit)
	var dealt: int = max(0, int(data.get("dealt", 0)))
	var amount: int = max(10, int(round(float(unit.attack_damage) * 0.10)))
	_damage_enemy(ctx, int(data.get("target_index", -1)), amount, "true")
	_heal(ctx, ctx, max(8, int(round(float(dealt) * 0.20))))

func _largewand(unit: Unit, event: String, data: Dictionary) -> void:
	if event != "ability_cast":
		return
	var ctx: Dictionary = _context(unit)
	_damage_enemy(ctx, _event_enemy_target_index(ctx, data), int(round(30.0 + float(unit.spell_power) * 0.55)), "magic")

func _lifetaker(unit: Unit, event: String, data: Dictionary) -> void:
	if event != "hit_dealt":
		return
	var ctx: Dictionary = _context(unit)
	if int(data.get("after_hp", 1)) <= 0:
		_heal(ctx, ctx, max(60, int(round(float(unit.max_hp) * 0.16))))
		_apply_stats(String(ctx.get("team", "")), int(ctx.get("index", -1)), {"attack_damage": max(4.0, float(unit.attack_damage) * 0.12)}, MEDIUM_DURATION, ctx, "item")
	else:
		_heal(ctx, ctx, max(4, int(round(float(data.get("dealt", 0)) * 0.08))))

func _mageheart(unit: Unit, event: String, _data: Dictionary) -> void:
	var ctx: Dictionary = _context(unit)
	if event == "combat_started":
		_shield(ctx, ctx, int(round(60.0 + float(unit.spell_power) * 0.45 + float(unit.max_hp) * 0.04)), MEDIUM_DURATION)
	elif event == "ability_cast":
		_heal(ctx, ctx, int(round(35.0 + float(unit.spell_power) * 0.25)))

func _orb_on_a_stick(unit: Unit, event: String) -> void:
	if event != "ability_cast":
		return
	var ctx: Dictionary = _context(unit)
	var ally_index: int = _lowest_hp_ally_index(String(ctx.get("team", "")))
	_shield({"team": String(ctx.get("team", "")), "index": ally_index}, ctx, int(round(55.0 + float(unit.spell_power) * 0.35)), MEDIUM_DURATION)
	_gain_mana(String(ctx.get("team", "")), ally_index, 8)

func _piercing_gear(unit: Unit, event: String, data: Dictionary) -> void:
	if event != "hit_dealt":
		return
	var ctx: Dictionary = _context(unit)
	var target_team: String = _other_team(String(ctx.get("team", "")))
	var target_index: int = int(data.get("target_index", -1))
	var target: Unit = _unit_at(target_team, target_index)
	if target == null:
		return
	_apply_stats(target_team, target_index, {
		"armor": -max(4.0, float(target.armor) * 0.08),
		"magic_resist": -max(4.0, float(target.magic_resist) * 0.08),
	}, MEDIUM_DURATION, ctx, "on_hit")

func _relay(unit: Unit, event: String, data: Dictionary) -> void:
	if event != "ability_cast" and not (event == "hit_dealt" and bool(data.get("crit", false))):
		return
	var ctx: Dictionary = _context(unit)
	var primary_index: int = _event_enemy_target_index(ctx, data)
	var chain_index: int = _next_enemy_index(String(ctx.get("team", "")), primary_index)
	if chain_index < 0:
		chain_index = primary_index
	_damage_enemy(ctx, chain_index, int(round(24.0 + max(float(unit.attack_damage), float(unit.spell_power)) * 0.24)), "magic")

func _rendsaw(unit: Unit, event: String, data: Dictionary) -> void:
	if event != "hit_dealt":
		return
	var ctx: Dictionary = _context(unit)
	var target_team: String = _other_team(String(ctx.get("team", "")))
	var target_index: int = int(data.get("target_index", -1))
	_apply_stats(target_team, target_index, {"armor": -12.0}, MEDIUM_DURATION, ctx, "on_hit")
	_damage_enemy(ctx, target_index, int(round(12.0 + float(unit.attack_damage) * 0.16)), "physical")

func _sanctum(unit: Unit, event: String) -> void:
	if event != "combat_started":
		return
	var ctx: Dictionary = _context(unit)
	_shield(ctx, ctx, max(90, int(round(float(unit.magic_resist) * 4.0 + float(unit.max_hp) * 0.06))), LONG_DURATION)
	_apply_tag(String(ctx.get("team", "")), int(ctx.get("index", -1)), BuffTags.TAG_CC_IMMUNE, 2.0, {"item": "sanctum"}, ctx)

func _serenity(unit: Unit, event: String) -> void:
	if event != "combat_started" and event != "hit_taken":
		return
	var ctx: Dictionary = _context(unit)
	var team: String = String(ctx.get("team", ""))
	var index: int = int(ctx.get("index", -1))
	if event == "combat_started":
		if _state() != null:
			_push_source(ctx, "item")
			buff_system.cleanse(_state(), team, index)
			_pop_source()
		_shield(ctx, ctx, int(round(50.0 + float(unit.magic_resist) * 2.0)), MEDIUM_DURATION)
	elif not _used(unit, "serenity_hit"):
		_mark_used(unit, "serenity_hit")
		_heal(ctx, ctx, max(35, int(round(float(unit.max_hp) * 0.07))))

func _stone(unit: Unit, event: String) -> void:
	var ctx: Dictionary = _context(unit)
	if event == "combat_started":
		_apply_stats(String(ctx.get("team", "")), int(ctx.get("index", -1)), {"damage_reduction": 0.06}, LONG_DURATION, ctx, "item")
		_shield(ctx, ctx, max(80, int(round((float(unit.armor) + float(unit.magic_resist)) * 2.0))), LONG_DURATION)
	elif event == "hit_taken" and not _used(unit, "stone_first_hit"):
		_mark_used(unit, "stone_first_hit")
		_apply_stats(String(ctx.get("team", "")), int(ctx.get("index", -1)), {"damage_reduction_flat": 8.0}, MEDIUM_DURATION, ctx, "item")

func _thunderplate(unit: Unit, event: String, data: Dictionary) -> void:
	var ctx: Dictionary = _context(unit)
	if event == "hit_taken":
		var attacker_team: String = String(data.get("attacker_team", ""))
		var attacker_index: int = int(data.get("attacker_index", -1))
		if attacker_team != "" and attacker_index >= 0:
			_damage_team_target(attacker_team, attacker_index, ctx, int(round(20.0 + float(unit.armor) * 0.55)), "magic")
	elif event == "hit_dealt":
		_apply_stats(String(ctx.get("team", "")), int(ctx.get("index", -1)), {"attack_speed": 0.04}, SHORT_DURATION, ctx, "item")

func _vengeance(unit: Unit, event: String, data: Dictionary) -> void:
	if event != "hit_taken":
		return
	var ctx: Dictionary = _context(unit)
	var attacker_team: String = String(data.get("attacker_team", ""))
	var attacker_index: int = int(data.get("attacker_index", -1))
	if attacker_team == "" or attacker_index < 0:
		return
	_damage_team_target(attacker_team, attacker_index, ctx, int(round(18.0 + float(unit.magic_resist) * 0.50 + float(unit.attack_damage) * 0.15)), "magic")
	if bool(data.get("crit", false)) or _hp_ratio(unit) <= 0.5:
		_apply_stats(String(ctx.get("team", "")), int(ctx.get("index", -1)), {"attack_damage": max(4.0, float(unit.attack_damage) * 0.10)}, MEDIUM_DURATION, ctx, "item")

func _vital_battery(unit: Unit, event: String) -> void:
	if event != "combat_started":
		return
	var ctx: Dictionary = _context(unit)
	_shield(ctx, ctx, max(80, int(round(float(unit.max_hp) * 0.10))), LONG_DURATION)
	_gain_mana(String(ctx.get("team", "")), int(ctx.get("index", -1)), 12)
	var ally_index: int = _lowest_hp_ally_index(String(ctx.get("team", "")))
	if ally_index != int(ctx.get("index", -1)):
		_shield({"team": String(ctx.get("team", "")), "index": ally_index}, ctx, 50, MEDIUM_DURATION)

func _wardheart(unit: Unit, event: String) -> void:
	if event != "hit_taken" or _used(unit, "wardheart"):
		return
	if _hp_ratio(unit) > 0.55:
		return
	_mark_used(unit, "wardheart")
	var ctx: Dictionary = _context(unit)
	var amount: int = max(70, int(round(float(unit.max_hp) * 0.10 + float(unit.magic_resist) * 1.5)))
	_shield(ctx, ctx, amount, MEDIUM_DURATION)
	_heal(ctx, ctx, int(round(float(amount) * 0.45)))
	var ally_index: int = _lowest_hp_ally_index(String(ctx.get("team", "")))
	_shield({"team": String(ctx.get("team", "")), "index": ally_index}, ctx, int(round(float(amount) * 0.55)), MEDIUM_DURATION)

func _windwall(unit: Unit, event: String) -> void:
	if event != "combat_started" and event != "hit_taken":
		return
	var ctx: Dictionary = _context(unit)
	var team: String = String(ctx.get("team", ""))
	if event == "combat_started":
		for ally_index: int in _ally_indices(team):
			_shield({"team": team, "index": ally_index}, ctx, int(round(35.0 + float(unit.spell_power) * 0.18 + float(unit.magic_resist) * 0.70)), MEDIUM_DURATION)
	else:
		_apply_stats(team, int(ctx.get("index", -1)), {"magic_resist": 10.0}, MEDIUM_DURATION, ctx, "item")

func _context(unit: Unit) -> Dictionary:
	return _team_index_of(unit)

func _hp_ratio(unit: Unit) -> float:
	if unit == null or int(unit.max_hp) <= 0:
		return 0.0
	return float(max(0, int(unit.hp))) / float(max(1, int(unit.max_hp)))

func _event_enemy_target_index(ctx: Dictionary, data: Dictionary) -> int:
	var team: String = String(ctx.get("team", ""))
	var target_team: String = String(data.get("target_team", _other_team(team)))
	var target_index: int = int(data.get("target_index", -1))
	if target_index >= 0 and target_team == _other_team(team):
		return target_index
	return _first_enemy_index(team)

func _damage_enemy(source_ctx: Dictionary, target_index: int, amount: int, damage_type: String) -> void:
	var source_team: String = String(source_ctx.get("team", ""))
	var source_index: int = int(source_ctx.get("index", -1))
	if source_team == "" or source_index < 0 or target_index < 0 or amount <= 0:
		return
	var state: BattleState = _state()
	if state == null:
		return
	AbilityEffects.damage_single(engine, state, source_team, source_index, target_index, float(amount), damage_type)

func _damage_team_target(target_team: String, target_index: int, source_ctx: Dictionary, amount: int, damage_type: String) -> void:
	var source_team: String = String(source_ctx.get("team", ""))
	var source_index: int = int(source_ctx.get("index", -1))
	if source_team == "" or source_index < 0 or target_team != _other_team(source_team):
		return
	_damage_enemy(source_ctx, target_index, amount, damage_type)

func _damage_all_enemies(source_ctx: Dictionary, amount: int, damage_type: String) -> void:
	var source_team: String = String(source_ctx.get("team", ""))
	for target_index: int in _enemy_indices(source_team):
		_damage_enemy(source_ctx, target_index, amount, damage_type)

func _heal(target_ctx: Dictionary, source_ctx: Dictionary, amount: int) -> void:
	var target_team: String = String(target_ctx.get("team", ""))
	var target_index: int = int(target_ctx.get("index", -1))
	var source_team: String = String(source_ctx.get("team", ""))
	var source_index: int = int(source_ctx.get("index", -1))
	var state: BattleState = _state()
	if state == null or target_team == "" or target_index < 0 or amount <= 0:
		return
	AbilityEffects.heal_single(engine, state, target_team, target_index, float(amount), source_team, source_index)

func _shield(target_ctx: Dictionary, source_ctx: Dictionary, amount: int, duration: float) -> void:
	var target_team: String = String(target_ctx.get("team", ""))
	var target_index: int = int(target_ctx.get("index", -1))
	var state: BattleState = _state()
	if state == null or target_team == "" or target_index < 0 or amount <= 0:
		return
	_push_source(source_ctx, "item")
	buff_system.apply_shield(state, target_team, target_index, int(amount), float(duration))
	_pop_source()

func _stun(target_team: String, target_index: int, duration: float, source_ctx: Dictionary) -> void:
	var state: BattleState = _state()
	if state == null or target_team == "" or target_index < 0 or duration <= 0.0:
		return
	_push_source(source_ctx, "item")
	AbilityEffects.stun(buff_system, engine, state, target_team, target_index, duration, String(source_ctx.get("team", "")), int(source_ctx.get("index", -1)))
	_pop_source()

func _stun_first_enemy(source_ctx: Dictionary, duration: float) -> void:
	var team: String = String(source_ctx.get("team", ""))
	var target_index: int = _first_enemy_index(team)
	if target_index >= 0:
		_stun(_other_team(team), target_index, duration, source_ctx)

func _apply_stats(target_team: String, target_index: int, fields: Dictionary, duration: float, source_ctx: Dictionary, source_kind: String) -> void:
	var state: BattleState = _state()
	if state == null or target_team == "" or target_index < 0 or fields.is_empty():
		return
	_push_source(source_ctx, source_kind)
	buff_system.apply_stats_buff(state, target_team, target_index, fields, duration)
	_pop_source()

func _apply_tag(target_team: String, target_index: int, tag: String, duration: float, data: Dictionary, source_ctx: Dictionary) -> void:
	var state: BattleState = _state()
	if state == null or target_team == "" or target_index < 0:
		return
	_push_source(source_ctx, "item")
	buff_system.apply_tag(state, target_team, target_index, tag, duration, data)
	_pop_source()

func _gain_mana(team: String, index: int, amount: int) -> void:
	var unit: Unit = _unit_at(team, index)
	if unit == null or amount <= 0:
		return
	unit.mana = clampi(int(unit.mana) + int(amount), 0, int(unit.mana_max))
	if engine != null and engine.has_method("_resolver_emit_unit_stat"):
		engine._resolver_emit_unit_stat(team, index, {"mana": int(unit.mana)})

func _unit_at(team: String, index: int) -> Unit:
	var state: BattleState = _state()
	if state == null or index < 0:
		return null
	var units: Array[Unit] = state.player_team if team == "player" else state.enemy_team
	if index >= units.size():
		return null
	return units[index]

func _ally_indices(team: String) -> Array[int]:
	var out: Array[int] = []
	var state: BattleState = _state()
	if state == null:
		return out
	var units: Array[Unit] = state.player_team if team == "player" else state.enemy_team
	for i: int in range(units.size()):
		if units[i] != null and units[i].is_alive():
			out.append(i)
	return out

func _enemy_indices(team: String) -> Array[int]:
	return _ally_indices(_other_team(team))

func _first_enemy_index(team: String) -> int:
	var indices: Array[int] = _enemy_indices(team)
	if indices.is_empty():
		return -1
	return int(indices[0])

func _next_enemy_index(team: String, primary_index: int) -> int:
	var indices: Array[int] = _enemy_indices(team)
	for index: int in indices:
		if index != primary_index:
			return index
	if indices.is_empty():
		return -1
	return int(indices[0])

func _lowest_hp_ally_index(team: String) -> int:
	var best_index: int = -1
	var best_ratio: float = 999.0
	for index: int in _ally_indices(team):
		var unit: Unit = _unit_at(team, index)
		if unit == null:
			continue
		var ratio: float = _hp_ratio(unit)
		if best_index < 0 or ratio < best_ratio:
			best_index = index
			best_ratio = ratio
	return best_index

func _lowest_mana_ally_index(team: String) -> int:
	var best_index: int = -1
	var best_ratio: float = 999.0
	for index: int in _ally_indices(team):
		var unit: Unit = _unit_at(team, index)
		if unit == null:
			continue
		var ratio: float = float(unit.mana) / float(max(1, int(unit.mana_max)))
		if best_index < 0 or ratio < best_ratio:
			best_index = index
			best_ratio = ratio
	return best_index

func _bump(unit: Unit, key: String) -> int:
	if not _counters.has(unit):
		_counters[unit] = {}
	var unit_counts: Dictionary = _counters[unit]
	var count: int = int(unit_counts.get(key, 0)) + 1
	unit_counts[key] = count
	return count

func _used(unit: Unit, key: String) -> bool:
	if not _flags.has(unit):
		return false
	var unit_flags: Dictionary = _flags[unit]
	return bool(unit_flags.get(key, false))

func _mark_used(unit: Unit, key: String) -> void:
	if not _flags.has(unit):
		_flags[unit] = {}
	var unit_flags: Dictionary = _flags[unit]
	unit_flags[key] = true

func _push_source(source_ctx: Dictionary, source_kind: String) -> void:
	if buff_system != null and buff_system.has_method("push_source"):
		buff_system.push_source(String(source_ctx.get("team", "")), int(source_ctx.get("index", -1)), source_kind)

func _pop_source() -> void:
	if buff_system != null and buff_system.has_method("pop_source"):
		buff_system.pop_source()
