extends Node

const CombatEngineScript := preload("res://scripts/game/combat/combat_engine.gd")
const BattleStateScript := preload("res://scripts/game/combat/battle_state.gd")
const BuffSystemScript := preload("res://scripts/game/abilities/buff_system.gd")
const BuffTags := preload("res://scripts/game/abilities/buff_tags.gd")
const HealingService := preload("res://scripts/game/traits/runtime/healing_service.gd")
const CombatStatsCollectorScript := preload("res://tests/rga_testing/aggregators/combat_stats_collector.gd")

@export var do_quit_on_finish: bool = true

var _redirect_events: int = 0
var _redirected_damage: int = 0
var _redirect_before_hp: int = -1
var _redirect_after_hp: int = -1
var _hit_events: int = 0
var _hit_damage: int = 0
var _on_hit_events: int = 0
var _pressure_events: int = 0

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	_test_modifier_composition(failures)
	_test_pressure_scaling(failures)
	_test_korath_snapshot_fail_closed(failures)
	_test_korath_conservation(failures)
	_test_korath_lethal_redirect(failures)
	_test_hexeon_sustain_counter(failures)
	if not failures.is_empty():
		for failure: String in failures:
			printerr("SustainBalanceContractProbe: FAIL ", failure)
		_quit(1)
		return
	print("SustainBalanceContractProbe: PASS modifier_composition pressure_scaling redirect_snapshot_fail_closed redirect_conservation redirect_lethal_single_proc active_recast_guard hexeon_sustain_counter")
	_quit(0)

func _test_modifier_composition(failures: Array[String]) -> void:
	var state: BattleState = BattleStateScript.new()
	var unit: Unit = _unit("support", 1000, 500)
	var team: Array[Unit] = [unit]
	state.player_team = team
	var buffs: BuffSystem = BuffSystemScript.new()
	buffs.apply_tag(state, "player", 0, BuffTags.TAG_HEALING_MODS, 9999.0, {
		"healing_received_pct": 0.60,
		"shield_strength_pct": 0.60,
	})
	buffs.apply_tag(state, "player", 0, BuffTags.TAG_HEALING_REDUCTION, 4.0, {
		"healing_received_pct": -0.70,
		"shield_strength_pct": -0.70,
	})
	var heal_result: Dictionary[String, Variant] = _typed_dictionary(HealingService.apply_heal(state, buffs, "player", 0, 100.0))
	if int(heal_result.get("healed", 0)) != 90:
		failures.append("positive and negative healing modifiers did not combine to 90")
	var shield_result: Dictionary[String, Variant] = _typed_dictionary(buffs.apply_shield(state, "player", 0, 100, 10.0))
	if int(shield_result.get("shield", 0)) != 90:
		failures.append("positive and negative shield modifiers did not combine to 90")

func _test_pressure_scaling(failures: Array[String]) -> void:
	var state: BattleState = BattleStateScript.new()
	var unit: Unit = _unit("support", 1000, 500)
	var team: Array[Unit] = [unit]
	state.player_team = team
	state.sustain_effectiveness = 0.50
	var buffs: BuffSystem = BuffSystemScript.new()
	var heal_result: Dictionary[String, Variant] = _typed_dictionary(HealingService.apply_heal(state, buffs, "player", 0, 200.0))
	if int(heal_result.get("healed", 0)) != 100:
		failures.append("50 percent Arena Pressure healing multiplier was not applied")
	var shield_result: Dictionary[String, Variant] = _typed_dictionary(buffs.apply_shield(state, "player", 0, 200, 10.0))
	if int(shield_result.get("shield", 0)) != 100:
		failures.append("50 percent Arena Pressure shield multiplier was not applied")

func _test_korath_snapshot_fail_closed(failures: Array[String]) -> void:
	_reset_combat_observation()
	var state: BattleState = BattleStateScript.new()
	var korath: Unit = _unit("korath", 1000, 1000)
	var ally: Unit = _unit("brute", 1000, 1000)
	var attacker: Unit = _unit("cashmere", 1000, 1000)
	var player_team: Array[Unit] = [korath, ally]
	var enemy_team: Array[Unit] = [attacker]
	state.player_team = player_team
	state.enemy_team = enemy_team
	var engine: CombatEngine = CombatEngineScript.new()
	engine.set_seed(7000)
	engine.configure(state, korath, 1)
	engine.redirected_damage_applied.connect(_on_redirected_damage_applied)
	_set_two_vs_one_arena(engine)
	engine.start()

	# The redirect percentage alone is not authority to protect every ally. A
	# cast must provide a valid nearby-ally snapshot.
	engine.buff_system.apply_tag(state, "player", 0, BuffTags.TAG_KORATH, 3.0, {
		"ally_redirect_pct": 0.50,
		"pool": 0,
		"pool_cap": 400,
	})
	var missing_snapshot_hit: Dictionary[String, Variant] = _typed_dictionary(
		engine.attack_resolver.apply_ability_damage("enemy", 0, 1, 200.0, "true")
	)
	if int(missing_snapshot_hit.get("redirected", 0)) != 0 or int(missing_snapshot_hit.get("redirected_dealt", 0)) != 0:
		failures.append("Korath redirected ally damage when protected_indices was missing")
	if int(korath.hp) != 1000 or int(ally.hp) != 800:
		failures.append("missing protected_indices did not fail closed onto the original ally")

	engine.buff_system.apply_tag(state, "player", 0, BuffTags.TAG_KORATH, 3.0, {
		"protected_indices": "1",
	})
	var malformed_snapshot_hit: Dictionary[String, Variant] = _typed_dictionary(
		engine.attack_resolver.apply_ability_damage("enemy", 0, 1, 200.0, "true")
	)
	if int(malformed_snapshot_hit.get("redirected", 0)) != 0 or int(malformed_snapshot_hit.get("redirected_dealt", 0)) != 0:
		failures.append("Korath redirected ally damage when protected_indices was malformed")
	if int(korath.hp) != 1000 or int(ally.hp) != 600:
		failures.append("malformed protected_indices did not fail closed onto the original ally")
	if _redirect_events != 0 or _redirected_damage != 0:
		failures.append("denied snapshot redirects emitted redirected-damage telemetry")
	var totals: Dictionary[String, Variant] = _typed_dictionary(engine.attack_resolver.totals())
	if int(totals.get("enemy", 0)) != 400:
		failures.append("fail-closed snapshot hits were not attributed exactly once")
	engine.teardown()

func _test_korath_conservation(failures: Array[String]) -> void:
	_reset_combat_observation()
	var state: BattleState = BattleStateScript.new()
	var korath: Unit = _unit("korath", 1000, 1000)
	korath.ability_id = "korath_absorb_release"
	korath.mana_max = 40
	korath.mana = 40
	var ally: Unit = _unit("brute", 1000, 1000)
	var attacker: Unit = _unit("cashmere", 1000, 1000)
	var player_team: Array[Unit] = [korath, ally]
	var enemy_team: Array[Unit] = [attacker]
	state.player_team = player_team
	state.enemy_team = enemy_team
	var engine: CombatEngine = CombatEngineScript.new()
	engine.set_seed(7001)
	engine.configure(state, korath, 1)
	engine.redirected_damage_applied.connect(_on_redirected_damage_applied)
	engine.arena_pressure_changed.connect(_on_arena_pressure_changed)
	_set_two_vs_one_arena(engine)
	engine.start()
	var protected_indices: Array[int] = [1]
	engine.buff_system.apply_tag(state, "player", 0, BuffTags.TAG_KORATH, 3.0, {
		"pct": 0.25,
		"ally_redirect_pct": 0.50,
		"protected_indices": protected_indices,
		"pool": 0,
		"pool_cap": 400,
		"block_mana_gain": true,
	})
	var recast_result: Dictionary[String, Variant] = _typed_dictionary(engine.ability_system.try_cast("player", 0))
	if String(recast_result.get("reason", "")) != "absorb_release_active":
		failures.append("Korath could recast while Absorb & Release was active")
	if int(korath.mana) != 40:
		failures.append("active recast guard consumed Korath mana")
	var hit_result: Dictionary[String, Variant] = _typed_dictionary(
		engine.attack_resolver.apply_ability_damage("enemy", 0, 1, 200.0, "true")
	)
	if int(hit_result.get("dealt", 0)) != 100 or int(ally.hp) != 900:
		failures.append("ally did not receive the non-redirected half of the hit")
	if int(hit_result.get("redirected_dealt", 0)) != 100 or int(korath.hp) != 900:
		failures.append("redirected half was not conserved as Korath HP damage")
	if int(korath.mana) != 40:
		failures.append("redirected damage refilled Korath mana during the active")
	var meta: Dictionary[String, Variant] = _typed_dictionary(
		engine.buff_system.get_tag_data(state, "player", 0, BuffTags.TAG_KORATH)
	)
	if int(meta.get("pool", 0)) != 100:
		failures.append("stored pressure did not accumulate the redirected amount")
	if _redirect_events != 1 or _redirected_damage != 100:
		failures.append("dedicated redirected-damage telemetry was not emitted once")
	var totals: Dictionary[String, Variant] = _typed_dictionary(engine.attack_resolver.totals())
	if int(totals.get("enemy", 0)) != 200:
		failures.append("damage totals did not conserve original plus transferred damage")
	var no_protected_indices: Array[int] = []
	engine.buff_system.apply_tag(state, "player", 0, BuffTags.TAG_KORATH, 3.0, {
		"protected_indices": no_protected_indices,
	})
	var unprotected_hit: Dictionary[String, Variant] = _typed_dictionary(
		engine.attack_resolver.apply_ability_damage("enemy", 0, 1, 200.0, "true")
	)
	if int(unprotected_hit.get("redirected", 0)) != 0 or int(korath.hp) != 900 or int(ally.hp) != 700:
		failures.append("Korath redirected damage from an ally outside the protected nearby snapshot")
	state.elapsed_time = 55.0
	engine.call("_update_arena_pressure")
	if not is_equal_approx(float(state.sustain_effectiveness), 0.20) or _pressure_events != 1:
		failures.append("Arena Pressure did not reach its 20 percent floor at 55 seconds")
	engine.teardown()

func _test_korath_lethal_redirect(failures: Array[String]) -> void:
	_reset_combat_observation()
	var state: BattleState = BattleStateScript.new()
	var korath: Unit = _unit("korath", 1000, 100)
	var ally: Unit = _unit("brute", 1000, 1000)
	ally.armor = 0.0
	var attacker: Unit = _unit("cashmere", 1000, 1000)
	var player_team: Array[Unit] = [korath, ally]
	var enemy_team: Array[Unit] = [attacker]
	state.player_team = player_team
	state.enemy_team = enemy_team
	var engine: CombatEngine = CombatEngineScript.new()
	engine.set_seed(7003)
	engine.configure(state, korath, 1)
	engine.redirected_damage_applied.connect(_on_redirected_damage_applied)
	engine.hit_applied.connect(_on_hit_applied)
	engine.on_hit_proc.connect(_on_on_hit_proc)
	_set_two_vs_one_arena(engine)
	engine.start()
	var collector: CombatStatsCollector = CombatStatsCollectorScript.new()
	collector.attach(engine, state, true)
	var protected_indices: Array[int] = [1]
	engine.buff_system.apply_tag(state, "player", 0, BuffTags.TAG_KORATH, 3.0, {
		"ally_redirect_pct": 0.50,
		"protected_indices": protected_indices,
		"pool": 0,
		"pool_cap": 400,
	})
	engine.buff_system.apply_tag(state, "enemy", 0, BuffTags.TAG_BONKO_EMPOWER, 9999.0, {
		"hits_left": 2,
		"heal_missing_pct": 0.0,
		"extra_ad_ratio": 1.0,
		"block_mana_gain": true,
	})

	# A 200-point basic hit splits exactly 100/100. Korath starts at 100 HP,
	# so the bodyguard transfer must be lethal while still remaining one hit
	# and one on-hit proc against the original ally.
	var hit_result: Dictionary[String, Variant] = _typed_dictionary(
		engine.attack_resolver.apply_projectile_hit("enemy", 0, 1, 200, false, false)
	)
	if int(hit_result.get("dealt", 0)) != 100 or int(ally.hp) != 900:
		failures.append("lethal redirect changed the original ally's conserved half-hit")
	if int(hit_result.get("redirected_dealt", 0)) != 100 or int(korath.hp) != 0 or korath.is_alive():
		failures.append("lethal redirected damage did not kill Korath at zero HP")
	if int(hit_result.get("dealt", 0)) + int(hit_result.get("redirected_dealt", 0)) != 200:
		failures.append("lethal redirect did not conserve the full 200 damage")
	if _redirect_events != 1 or _redirected_damage != 100 or _redirect_before_hp != 100 or _redirect_after_hp != 0:
		failures.append("lethal redirect telemetry did not report one exact 100-to-0 transfer")
	if _hit_events != 1 or _hit_damage != 100:
		failures.append("redirected damage emitted a duplicate hit_applied event")
	if _on_hit_events != 1:
		failures.append("redirected damage emitted a duplicate on-hit proc")
	var empower_meta: Dictionary[String, Variant] = _typed_dictionary(
		engine.buff_system.get_tag_data(state, "enemy", 0, BuffTags.TAG_BONKO_EMPOWER)
	)
	if int(empower_meta.get("hits_left", -1)) != 1:
		failures.append("redirected damage consumed Bonko's on-hit charge twice")
	var totals: Dictionary[String, Variant] = _typed_dictionary(engine.attack_resolver.totals())
	if int(totals.get("enemy", 0)) != 200:
		failures.append("lethal redirect was not counted exactly once in combat totals")

	var analytics: Dictionary[String, Variant] = _typed_dictionary(collector.result())
	var teams: Dictionary[String, Variant] = _typed_dictionary(analytics.get("teams", {}))
	var player_metrics: Dictionary[String, Variant] = _typed_dictionary(teams.get("a", {}))
	var enemy_metrics: Dictionary[String, Variant] = _typed_dictionary(teams.get("b", {}))
	if int(player_metrics.get("deaths", 0)) != 1 or int(enemy_metrics.get("kills", 0)) != 1:
		failures.append("redirect telemetry did not produce one Korath casualty and one attacker kill")
	if int(enemy_metrics.get("damage", 0)) != 200:
		failures.append("redirect telemetry double-counted or dropped lethal transferred damage")
	var units: Dictionary[String, Variant] = _typed_dictionary(analytics.get("units", {}))
	var player_units: Array[Variant] = _typed_variant_array(units.get("a", []))
	if player_units.size() != 2:
		failures.append("casualty telemetry did not retain both player units")
	else:
		var korath_metrics: Dictionary[String, Variant] = _typed_dictionary(player_units[0])
		var ally_metrics: Dictionary[String, Variant] = _typed_dictionary(player_units[1])
		if int(korath_metrics.get("deaths", 0)) != 1 or int(ally_metrics.get("deaths", 0)) != 0:
			failures.append("casualty telemetry assigned the redirect death to the wrong unit")
	collector.detach()
	engine.teardown()

func _test_hexeon_sustain_counter(failures: Array[String]) -> void:
	var state: BattleState = BattleStateScript.new()
	var hexeon: Unit = _unit("hexeon", 1000, 1000)
	hexeon.ability_id = "hexeon_prismatic_guillotine"
	hexeon.mana_max = 40
	hexeon.mana = 40
	# Keep the target above Hexeon's execute-setup window so this isolates the
	# non-execute sustain-fracture branch.
	var target: Unit = _unit("support", 4000, 4000)
	var player_team: Array[Unit] = [hexeon]
	var enemy_team: Array[Unit] = [target]
	state.player_team = player_team
	state.enemy_team = enemy_team
	var engine: CombatEngine = CombatEngineScript.new()
	engine.set_seed(7002)
	engine.configure(state, hexeon, 1)
	_set_one_vs_one_arena(engine)
	engine.start()
	var cast_result: Dictionary[String, Variant] = _typed_dictionary(engine.ability_system.try_cast("player", 0))
	if not bool(cast_result.get("cast", false)):
		failures.append("Hexeon could not cast the sustain-counter contract ability")
	elif not engine.buff_system.has_tag(state, "enemy", 0, BuffTags.TAG_HEALING_REDUCTION_HEXEON):
		failures.append("Hexeon did not apply the promised healing-reduction debuff")
	else:
		var reduction: Dictionary[String, Variant] = _typed_dictionary(
			engine.buff_system.get_tag_data(state, "enemy", 0, BuffTags.TAG_HEALING_REDUCTION_HEXEON)
		)
		if not is_equal_approx(float(reduction.get("healing_received_pct", 0.0)), -0.50):
			failures.append("Hexeon healing reduction was not 50 percent")
		if not is_equal_approx(float(reduction.get("shield_strength_pct", 0.0)), -0.50):
			failures.append("Hexeon shield generation reduction was not 50 percent")
	engine.teardown()

func _set_two_vs_one_arena(engine: CombatEngine) -> void:
	var player_positions: Array[Vector2] = [Vector2(128.0, 128.0), Vector2(192.0, 128.0)]
	var enemy_positions: Array[Vector2] = [Vector2(384.0, 128.0)]
	engine.set_arena(64.0, player_positions, enemy_positions, Rect2(0.0, 0.0, 512.0, 256.0))

func _set_one_vs_one_arena(engine: CombatEngine) -> void:
	var player_positions: Array[Vector2] = [Vector2(128.0, 128.0)]
	var enemy_positions: Array[Vector2] = [Vector2(384.0, 128.0)]
	engine.set_arena(64.0, player_positions, enemy_positions, Rect2(0.0, 0.0, 512.0, 256.0))

func _typed_dictionary(value: Variant) -> Dictionary[String, Variant]:
	var typed: Dictionary[String, Variant] = {}
	if typeof(value) == TYPE_DICTIONARY:
		typed.assign(value)
	return typed

func _typed_variant_array(value: Variant) -> Array[Variant]:
	var typed: Array[Variant] = []
	if typeof(value) == TYPE_ARRAY:
		typed.assign(value)
	return typed

func _reset_combat_observation() -> void:
	_redirect_events = 0
	_redirected_damage = 0
	_redirect_before_hp = -1
	_redirect_after_hp = -1
	_hit_events = 0
	_hit_damage = 0
	_on_hit_events = 0
	_pressure_events = 0

func _unit(unit_id: String, max_hp: int, hp: int) -> Unit:
	var unit: Unit = Unit.new()
	unit.id = unit_id
	unit.name = unit_id.capitalize()
	unit.max_hp = max_hp
	unit.hp = hp
	unit.attack_damage = 100.0
	unit.attack_speed = 1.0
	unit.attack_range = 1.0
	return unit

func _on_redirected_damage_applied(_source_team: String, _source_index: int, _original_target_team: String, _original_target_index: int, _redirect_team: String, _redirect_index: int, dealt_damage: int, _before_hp: int, _after_hp: int, _kind: String) -> void:
	_redirect_events += 1
	_redirected_damage += max(0, dealt_damage)
	_redirect_before_hp = _before_hp
	_redirect_after_hp = _after_hp

func _on_hit_applied(_source_team: String, _source_index: int, _target_index: int, _rolled_damage: int, dealt_damage: int, _crit: bool, _before_hp: int, _after_hp: int, _player_cd: float, _enemy_cd: float) -> void:
	_hit_events += 1
	_hit_damage += max(0, dealt_damage)

func _on_on_hit_proc(_source_team: String, _source_index: int, _target_team: String, _target_index: int, _kind: String, _fields: Variant, _magnitude: float) -> void:
	_on_hit_events += 1

func _on_arena_pressure_changed(_effectiveness: float, _stage: int) -> void:
	_pressure_events += 1

func _quit(code: int) -> void:
	if do_quit_on_finish:
		get_tree().quit(code)
