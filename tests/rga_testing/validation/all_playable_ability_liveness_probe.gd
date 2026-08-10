extends Node

const CombatEngineScript := preload("res://scripts/game/combat/combat_engine.gd")
const BattleStateScript := preload("res://scripts/game/combat/battle_state.gd")
const AbilityCatalog := preload("res://scripts/game/abilities/ability_catalog.gd")
const UnitFactoryScript := preload("res://scripts/unit_factory.gd")

const EXPECTED_PLAYABLE_COUNT: int = 51
const TILE_SIZE: float = 100.0
const ARENA_BOUNDS: Rect2 = Rect2(Vector2.ZERO, Vector2(1000.0, 800.0))
const SCHEDULED_SIGNATURE_MAX_DEPTH: int = 3
const SCHEDULED_SIGNATURE_MAX_ITEMS: int = 16

# These resources are deliberately outside the one-profile/one-ability playable gate.
# Playable Creep uses creep_playable_eavesdropping, whose implementation inherits
# the legacy creep_eavesdropping implementation.
const NON_PLAYABLE_DEFINITION_EXCEPTIONS: Array[String] = [
	"creep_eavesdropping",
	"kythera_glyph_bloom",
]

# This probe proves a legal, committed cast and an immediate authoritative effect.
# These abilities have defining follow-up behavior that belongs in deeper probes.
const DELAYED_FOLLOW_UP_EXCEPTIONS: Array[String] = [
	"bo_writ_of_severance",
	"caldera_molten_core",
	"cinder_fuse_spark",
	"creep_playable_eavesdropping",
	"korath_absorb_release",
	"kythera_siphon",
	"malachor_debt_of_flesh",
	"noxley_red_static",
	"orielle_spell_debt",
	"quorra_timeplate_lunge",
	"vesper_late_fee",
	"veyra_harden",
]

const ARMED_BASIC_ATTACK_EXCEPTIONS: Array[String] = [
	"berebell_unstable",
	"bonko_bonk",
	"nyxa_chaos_volley",
	"sari_default",
]

const MULTI_CAST_EXCEPTION: String = "mortem_blood_feast"

@export var do_quit_on_finish: bool = true

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	var profiles: Array[UnitProfile] = _load_playable_profiles(failures)
	_expect(profiles.size() == EXPECTED_PLAYABLE_COUNT,
		"expected %d playable profiles, loaded %d" % [EXPECTED_PLAYABLE_COUNT, profiles.size()], failures)

	var seen_profile_ids: Dictionary[String, bool] = {}
	var seen_ability_ids: Dictionary[String, bool] = {}
	var passed_count: int = 0
	for profile: UnitProfile in profiles:
		var before_failure_count: int = failures.size()
		var progress_unit_id: String = String(profile.id).strip_edges() if profile != null else "<null>"
		var progress_ability_id: String = String(profile.ability_id).strip_edges() if profile != null else "<null>"
		print("AllPlayableAbilityLivenessProbe: START unit=%s ability=%s" % [progress_unit_id, progress_ability_id])
		_validate_profile_and_cast(profile, seen_profile_ids, seen_ability_ids, failures)
		if failures.size() == before_failure_count:
			passed_count += 1
		await get_tree().process_frame

	_expect(seen_profile_ids.size() == EXPECTED_PLAYABLE_COUNT,
		"expected %d unique playable ids, found %d" % [EXPECTED_PLAYABLE_COUNT, seen_profile_ids.size()], failures)
	_expect(seen_ability_ids.size() == EXPECTED_PLAYABLE_COUNT,
		"expected %d unique playable ability ids, found %d" % [EXPECTED_PLAYABLE_COUNT, seen_ability_ids.size()], failures)
	_validate_definition_exceptions(seen_ability_ids, failures)

	print("AllPlayableAbilityLivenessProbe: checked=", profiles.size(), " passed=", passed_count,
		" failed=", profiles.size() - passed_count)
	print("AllPlayableAbilityLivenessProbe: NON_PLAYABLE_DEFINITION_EXCEPTIONS=",
		", ".join(NON_PLAYABLE_DEFINITION_EXCEPTIONS))
	print("AllPlayableAbilityLivenessProbe: DELAYED_FOLLOW_UP_EXCEPTIONS=",
		", ".join(DELAYED_FOLLOW_UP_EXCEPTIONS))
	print("AllPlayableAbilityLivenessProbe: ARMED_BASIC_ATTACK_EXCEPTIONS=",
		", ".join(ARMED_BASIC_ATTACK_EXCEPTIONS), " MULTI_CAST_EXCEPTION=", MULTI_CAST_EXCEPTION)

	if not failures.is_empty():
		for failure: String in failures:
			push_error("AllPlayableAbilityLivenessProbe: " + failure)
		_finish(1)
		return
	print("AllPlayableAbilityLivenessProbe: PASS all 51 profiles committed a legal cast with immediate authoritative effect evidence")
	_finish(0)

func _load_playable_profiles(failures: Array[String]) -> Array[UnitProfile]:
	var profiles: Array[UnitProfile] = []
	var directory: DirAccess = DirAccess.open("res://data/units")
	if directory == null:
		failures.append("could not open res://data/units")
		return profiles
	var file_names: Array[String] = []
	directory.list_dir_begin()
	while true:
		var file_name: String = directory.get_next()
		if file_name == "":
			break
		if directory.current_is_dir() or file_name.begins_with(".") or not file_name.ends_with(".tres"):
			continue
		file_names.append(file_name)
	directory.list_dir_end()
	file_names.sort()
	for file_name: String in file_names:
		var path: String = "res://data/units/" + file_name
		var resource: Resource = ResourceLoader.load(path)
		if resource is UnitProfile:
			var profile: UnitProfile = resource as UnitProfile
			profiles.append(profile)
		else:
			failures.append("%s did not load as UnitProfile" % path)
	return profiles

func _validate_profile_and_cast(
		profile: UnitProfile,
		seen_profile_ids: Dictionary[String, bool],
		seen_ability_ids: Dictionary[String, bool],
		failures: Array[String]) -> void:
	if profile == null:
		failures.append("encountered null playable profile")
		return
	var unit_id: String = String(profile.id).strip_edges()
	var ability_id: String = String(profile.ability_id).strip_edges()
	var label: String = unit_id if unit_id != "" else String(profile.resource_path)
	var profile_contract_ok: bool = true
	profile_contract_ok = _unit_expect(unit_id != "", label, "profile id is empty", failures) and profile_contract_ok
	profile_contract_ok = _unit_expect(ability_id != "", label, "ability_id is empty", failures) and profile_contract_ok
	profile_contract_ok = _unit_expect(not seen_profile_ids.has(unit_id), label, "duplicate profile id", failures) and profile_contract_ok
	profile_contract_ok = _unit_expect(not seen_ability_ids.has(ability_id), label, "duplicate playable ability_id %s" % ability_id, failures) and profile_contract_ok
	profile_contract_ok = _unit_expect(int(profile.cost) >= 1 and int(profile.cost) <= 5, label,
		"profile cost %d is outside 1..5" % int(profile.cost), failures) and profile_contract_ok
	profile_contract_ok = _unit_expect(not bool(profile.hidden) and not bool(profile.enemy_only), label,
		"profile in data/units is hidden or enemy_only", failures) and profile_contract_ok
	if unit_id != "":
		seen_profile_ids[unit_id] = true
	if ability_id != "":
		seen_ability_ids[ability_id] = true
	if not profile_contract_ok:
		return

	var ability_def: AbilityDef = AbilityCatalog.get_def(ability_id)
	if not _unit_expect(ability_def != null, label, "missing AbilityDef for %s" % ability_id, failures):
		return
	var definition_ok: bool = true
	definition_ok = _unit_expect(String(ability_def.id) == ability_id, label,
		"AbilityDef.id %s does not match %s" % [String(ability_def.id), ability_id], failures) and definition_ok
	definition_ok = _unit_expect(String(ability_def.name).strip_edges() != "", label, "AbilityDef.name is empty", failures) and definition_ok
	definition_ok = _unit_expect(String(ability_def.description).strip_edges() != "", label, "AbilityDef.description is empty", failures) and definition_ok
	definition_ok = _unit_expect(String(ability_def.targeting_summary).strip_edges() != "", label,
		"AbilityDef.targeting_summary is empty", failures) and definition_ok
	definition_ok = _unit_expect(not ability_def.tags.is_empty(), label, "AbilityDef.tags is empty", failures) and definition_ok
	definition_ok = _unit_expect(int(ability_def.base_cost) > 0, label,
		"AbilityDef.base_cost must be positive", failures) and definition_ok

	var impl_path: String = AbilityCatalog.resolve_impl_path(ability_id)
	definition_ok = _unit_expect(impl_path != "", label, "implementation path did not resolve", failures) and definition_ok
	var impl_script: Script = AbilityCatalog.get_impl_script(ability_id)
	definition_ok = _unit_expect(impl_script != null, label, "implementation script did not load", failures) and definition_ok
	var impl: Variant = AbilityCatalog.new_instance(ability_id)
	definition_ok = _unit_expect(impl != null and impl.has_method("cast"), label,
		"implementation instance has no cast method", failures) and definition_ok
	if not definition_ok:
		return

	var caster: Unit = UnitFactoryScript.spawn(unit_id)
	if not _unit_expect(caster != null, label, "UnitFactory.spawn failed", failures):
		return
	var spawn_ok: bool = true
	spawn_ok = _unit_expect(String(caster.ability_id) == ability_id, label,
		"spawned ability_id %s does not match profile" % String(caster.ability_id), failures) and spawn_ok
	spawn_ok = _unit_expect(int(caster.cost) == int(profile.cost), label,
		"spawned tier cost %d does not match profile cost %d" % [int(caster.cost), int(profile.cost)], failures) and spawn_ok
	spawn_ok = _unit_expect(int(caster.mana_max) == int(ability_def.base_cost), label,
		"spawned mana_max %d does not match base_cost %d" % [int(caster.mana_max), int(ability_def.base_cost)], failures) and spawn_ok
	if not spawn_ok:
		return

	var fixture: Dictionary[String, Variant] = _make_fixture(caster)
	var state: BattleState = fixture.get("state") as BattleState
	var engine: CombatEngine = fixture.get("engine") as CombatEngine
	if not _unit_expect(state != null and engine != null and engine.ability_system != null and engine.buff_system != null,
			label, "combat fixture failed to initialize", failures):
		_teardown_fixture(engine)
		return

	caster.mana = int(ability_def.base_cost)
	var mana_before: int = int(caster.mana)
	var commits: Array[Dictionary] = []
	var commit_callback: Callable = _on_ability_committed.bind(commits)
	var semantic_events: Array[String] = []
	var target_callback: Callable = _on_semantic_target.bind(semantic_events)
	var buff_callback: Callable = _on_semantic_buff.bind(semantic_events)
	var debuff_callback: Callable = _on_semantic_debuff.bind(semantic_events)
	var zone_callback: Callable = _on_semantic_zone_exposure.bind(semantic_events)
	engine.ability_committed.connect(commit_callback)
	engine.target_start.connect(target_callback)
	engine.buff_applied.connect(buff_callback)
	engine.debuff_applied.connect(debuff_callback)
	engine.zone_exposure_applied.connect(zone_callback)
	var before: Dictionary[String, Variant] = _effect_snapshot(state, engine)
	var result: Dictionary = engine.ability_system.try_cast("player", 0)
	var after: Dictionary[String, Variant] = _effect_snapshot(state, engine)
	var evidence: Array[String] = _effect_categories(before, after)
	for semantic_event: String in semantic_events:
		if not evidence.has(semantic_event):
			evidence.append(semantic_event)
	var authoritative_evidence: Array[String] = _authoritative_categories(evidence)

	_unit_expect(bool(result.get("cast", false)), label,
		"try_cast failed: %s" % String(result.get("reason", "unknown")), failures)
	_unit_expect(_matching_commit_count(commits, ability_id) == 1, label,
		"expected exactly one matching ability_committed event, got %d" % _matching_commit_count(commits, ability_id), failures)
	if _matching_commit_count(commits, ability_id) == 1:
		var commit: Dictionary = _matching_commit(commits, ability_id)
		_unit_expect(String(commit.get("commitment_kind", "")) == "ability", label,
			"commitment_kind was not ability", failures)
		_unit_expect(float(commit.get("cooldown_s", 0.0)) > 0.0, label,
			"committed cooldown must be positive", failures)
	_unit_expect(mana_before == int(ability_def.base_cost), label, "fixture did not fill exact base mana cost", failures)
	_unit_expect(int(caster.mana) >= 0 and int(caster.mana) < mana_before, label,
		"successful cast did not spend mana (before=%d after=%d)" % [mana_before, int(caster.mana)], failures)
	_unit_expect(state.player_cds.size() > 0 and float(state.player_cds[0]) > 0.0, label,
		"successful cast did not impose a basic-attack cooldown", failures)
	_unit_expect(not authoritative_evidence.is_empty(), label,
		"cast had no immediate authoritative unit/buff/movement/target effect; observed=%s" % ",".join(evidence), failures)

	if engine.ability_committed.is_connected(commit_callback):
		engine.ability_committed.disconnect(commit_callback)
	if engine.target_start.is_connected(target_callback):
		engine.target_start.disconnect(target_callback)
	if engine.buff_applied.is_connected(buff_callback):
		engine.buff_applied.disconnect(buff_callback)
	if engine.debuff_applied.is_connected(debuff_callback):
		engine.debuff_applied.disconnect(debuff_callback)
	if engine.zone_exposure_applied.is_connected(zone_callback):
		engine.zone_exposure_applied.disconnect(zone_callback)
	print("AllPlayableAbilityLivenessProbe: ", label, " -> ", ability_id,
		" cast=", bool(result.get("cast", false)), " evidence=", ",".join(evidence))
	_teardown_fixture(engine)

func _make_fixture(caster: Unit) -> Dictionary[String, Variant]:
	caster.hp = max(1, int(round(float(caster.max_hp) * 0.62)))
	var player_units: Array[Unit] = [caster]
	for ally_index: int in range(1, 6):
		player_units.append(_make_ally(ally_index))
	var enemy_units: Array[Unit] = []
	for enemy_index: int in range(6):
		enemy_units.append(_make_enemy(enemy_index))

	var state: BattleState = BattleStateScript.new()
	state.player_team = player_units
	state.enemy_team = enemy_units
	state.player_cds = _float_values(player_units.size(), 0.0)
	state.enemy_cds = _float_values(enemy_units.size(), 0.0)
	state.player_targets = _int_values(player_units.size(), 0)
	state.enemy_targets = _int_values(enemy_units.size(), 1)
	state.player_damage_this_round = _int_values(player_units.size(), 0)
	state.enemy_damage_this_round = _int_values(enemy_units.size(), 0)
	state.player_pupil_map = _int_values(player_units.size(), -1)
	state.enemy_pupil_map = _int_values(enemy_units.size(), -1)
	state.player_pupil_map[0] = 1

	var engine: CombatEngine = CombatEngineScript.new()
	engine.abilities_enabled = true
	engine.emit_auto_attack_logs = false
	engine.emit_ability_logs = false
	engine.emit_position_telemetry = false
	engine.emit_target_telemetry = false
	engine.deterministic_rolls = true
	engine.set_seed(51051)
	engine.configure(state, caster, 1, Callable())
	engine.arena_state.configure(TILE_SIZE, _player_positions(), _enemy_positions(), ARENA_BOUNDS)
	engine.start()
	state.player_targets = _int_values(player_units.size(), 0)
	state.enemy_targets = _int_values(enemy_units.size(), 1)
	engine.buff_system.apply_tag(state, "player", 1, "root", 6.0, {
		"is_debuff": true,
		"cleanseable": true,
		"fixture": true,
	})
	engine.buff_system.apply_shield(state, "enemy", 3, 120, 8.0)
	return {"state": state, "engine": engine}

func _make_ally(index: int) -> Unit:
	var roles: Array[String] = ["marksman", "mage", "tank", "support", "brawler"]
	var goals: Array[String] = ["sustained_dps", "burst", "frontline", "peel_carry", "direct_attrition"]
	var max_hp_values: Array[int] = [8000, 7200, 12000, 7600, 10000]
	var hp_values: Array[int] = [2200, 3200, 4500, 3800, 5200]
	var attack_damage_values: Array[float] = [360.0, 90.0, 130.0, 100.0, 260.0]
	var spell_power_values: Array[float] = [40.0, 380.0, 40.0, 300.0, 80.0]
	var attack_speed_values: Array[float] = [1.35, 0.85, 0.7, 0.9, 1.05]
	var attack_range_values: Array[int] = [5, 4, 1, 4, 1]
	var armor_values: Array[float] = [20.0, 18.0, 85.0, 30.0, 48.0]
	var magic_resist_values: Array[float] = [18.0, 24.0, 70.0, 42.0, 36.0]
	var approaches_by_index: Array[Array] = [
		["long_range", "ramp"],
		["burst", "zone"],
		["peel", "redirect"],
		["amp", "cc_immunity"],
		["sustain", "reposition"],
	]
	var unit: Unit = Unit.new()
	unit.id = "liveness_ally_%d" % index
	unit.name = unit.id
	unit.level = 1
	unit.cost = 2 + (index % 3)
	unit.max_hp = max_hp_values[index - 1]
	unit.hp = hp_values[index - 1]
	unit.attack_damage = attack_damage_values[index - 1]
	unit.spell_power = spell_power_values[index - 1]
	unit.attack_speed = attack_speed_values[index - 1]
	unit.attack_range = attack_range_values[index - 1]
	unit.armor = armor_values[index - 1]
	unit.magic_resist = magic_resist_values[index - 1]
	unit.mana_max = 100
	unit.mana = 0
	if index == 1:
		# Quillith's Final Exam contract requires a living Pupil with a castable
		# ability. Kett supplies a deterministic scheduled-effect recast fixture.
		unit.ability_id = "kett_union_breaker"
	var approaches: Array[String] = []
	for value: Variant in approaches_by_index[index - 1]:
		approaches.append(String(value))
	unit.set_identity_data(roles[index - 1], goals[index - 1], approaches)
	unit.traits = ["FixtureTrait%d" % index]
	return unit

func _make_enemy(index: int) -> Unit:
	var roles: Array[String] = ["tank", "assassin", "mage", "support", "brawler", "marksman"]
	var goals: Array[String] = ["frontline", "backline_access", "burst", "peel_carry", "direct_attrition", "sustained_dps"]
	var max_values: Array[int] = [18000, 15000, 14000, 16000, 17000, 12000]
	var hp_values: Array[int] = [18000, 9000, 11000, 13000, 15000, 900]
	var attack_damage_values: Array[float] = [140.0, 480.0, 100.0, 120.0, 310.0, 440.0]
	var spell_power_values: Array[float] = [20.0, 40.0, 460.0, 280.0, 50.0, 30.0]
	var attack_speed_values: Array[float] = [0.65, 1.25, 0.8, 0.9, 1.0, 1.5]
	var attack_range_values: Array[int] = [1, 1, 4, 4, 1, 5]
	var armor_values: Array[float] = [95.0, 28.0, 22.0, 36.0, 58.0, 20.0]
	var magic_resist_values: Array[float] = [80.0, 24.0, 30.0, 48.0, 44.0, 18.0]
	var unit: Unit = Unit.new()
	unit.id = "liveness_enemy_%d" % index
	unit.name = unit.id
	unit.level = 1
	unit.cost = 1 + (index % 5)
	unit.max_hp = max_values[index]
	unit.hp = hp_values[index]
	unit.attack_damage = attack_damage_values[index]
	unit.spell_power = spell_power_values[index]
	unit.attack_speed = attack_speed_values[index]
	unit.attack_range = attack_range_values[index]
	unit.armor = armor_values[index]
	unit.magic_resist = magic_resist_values[index]
	var approaches: Array[String] = []
	if index == 1:
		approaches.append("access_backline")
		approaches.append("burst")
		approaches.append("reposition")
	elif index == 5:
		approaches.append("long_range")
		approaches.append("ramp")
	elif index == 0:
		approaches.append("peel")
	else:
		approaches.append("zone")
	unit.set_identity_data(roles[index], goals[index], approaches)
	return unit

func _player_positions() -> Array[Vector2]:
	return [
		Vector2(300.0, 400.0),
		Vector2(245.0, 400.0),
		Vector2(250.0, 345.0),
		Vector2(250.0, 455.0),
		Vector2(190.0, 365.0),
		Vector2(190.0, 435.0),
	]

func _enemy_positions() -> Array[Vector2]:
	return [
		Vector2(450.0, 400.0),
		Vector2(480.0, 350.0),
		Vector2(480.0, 450.0),
		Vector2(520.0, 370.0),
		Vector2(520.0, 430.0),
		Vector2(580.0, 400.0),
	]

func _effect_snapshot(state: BattleState, engine: CombatEngine) -> Dictionary[String, Variant]:
	return {
		"units": [_unit_team_snapshot(state.player_team, true), _unit_team_snapshot(state.enemy_team, false)],
		"buffs": [_buff_team_snapshot(engine, state.player_team), _buff_team_snapshot(engine, state.enemy_team)],
		"stacks": [_stack_team_snapshot(engine, state.player_team), _stack_team_snapshot(engine, state.enemy_team)],
		"scheduled": _scheduled_snapshot(engine),
		"positions": [_position_snapshot(engine, "player"), _position_snapshot(engine, "enemy")],
		"targets": [state.player_targets.duplicate(), state.enemy_targets.duplicate()],
		"forced": _forced_snapshot(engine),
	}

func _unit_team_snapshot(units: Array[Unit], player_team: bool) -> Array[Dictionary]:
	var output: Array[Dictionary] = []
	for index: int in range(units.size()):
		var unit: Unit = units[index]
		if unit == null:
			output.append({"null": true})
			continue
		var row: Dictionary[String, Variant] = {
			"hp": int(unit.hp),
			"max_hp": int(unit.max_hp),
			"attack_damage": float(unit.attack_damage),
			"spell_power": float(unit.spell_power),
			"attack_speed": float(unit.attack_speed),
			"armor": float(unit.armor),
			"magic_resist": float(unit.magic_resist),
			"damage_reduction": float(unit.damage_reduction),
			"damage_reduction_flat": float(unit.damage_reduction_flat),
			"crit_chance": float(unit.crit_chance),
			"crit_damage": float(unit.crit_damage),
			"lifesteal": float(unit.lifesteal),
			"true_damage": float(unit.true_damage),
			"move_speed": float(unit.move_speed),
			"mana_max": int(unit.mana_max),
			"mana_regen": float(unit.mana_regen),
			"ui_shield": int(unit.ui_shield),
		}
		# Caster mana is intentionally excluded: a mana reset alone is not effect proof.
		if not player_team or index != 0:
			row["mana"] = int(unit.mana)
		output.append(row)
	return output

func _buff_team_snapshot(engine: CombatEngine, units: Array[Unit]) -> Array[Array]:
	var output: Array[Array] = []
	for unit: Unit in units:
		var signatures: Array[String] = []
		if unit != null:
			var raw_buffs: Variant = engine.buff_system._buffs.get(unit, [])
			if raw_buffs is Array:
				for raw_buff: Variant in raw_buffs:
					if raw_buff is Dictionary:
						signatures.append(var_to_str(raw_buff))
		signatures.sort()
		output.append(signatures)
	return output

func _stack_team_snapshot(engine: CombatEngine, units: Array[Unit]) -> Array[String]:
	var output: Array[String] = []
	for unit: Unit in units:
		var raw_stacks: Variant = engine.buff_system._stacks.get(unit, {}) if unit != null else {}
		output.append(var_to_str(raw_stacks))
	return output

func _scheduled_snapshot(engine: CombatEngine) -> Array[String]:
	var output: Array[String] = []
	if engine.ability_system == null:
		return output
	for raw_event: Variant in engine.ability_system._events:
		if not (raw_event is Dictionary):
			continue
		var event: Dictionary = raw_event
		output.append("%s|%s|%d|%.4f|%s" % [
			String(event.get("name", "")),
			String(event.get("team", "")),
			int(event.get("index", -1)),
			float(event.get("t", 0.0)),
			_scheduled_event_data_signature(event.get("data", {})),
		])
	output.sort()
	return output

func _scheduled_event_data_signature(raw_data: Variant) -> String:
	if not (raw_data is Dictionary):
		return _scheduled_value_signature(raw_data)
	var data: Dictionary[String, Variant] = {}
	for raw_key: Variant in (raw_data as Dictionary).keys():
		data[String(raw_key)] = (raw_data as Dictionary).get(raw_key, null)
	var keys: Array[String] = []
	for key: String in data.keys():
		keys.append(key)
	keys.sort()
	var fields: Array[String] = []
	for key: String in keys:
		fields.append("%s=%s" % [key, _scheduled_value_signature(data.get(key, null), 0)])
	return "{%s}" % ",".join(fields)

func _scheduled_value_signature(value: Variant, depth: int = 0) -> String:
	if value is Object:
		var object_value: Object = value as Object
		return "object:%s" % object_value.get_class()
	var type_id: int = typeof(value)
	match type_id:
		TYPE_NIL:
			return "null"
		TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING, TYPE_STRING_NAME, TYPE_NODE_PATH:
			return "scalar:%s" % var_to_str(value)
		TYPE_ARRAY:
			var array_size: int = (value as Array).size()
			if depth >= SCHEDULED_SIGNATURE_MAX_DEPTH:
				return "array:%d:max_depth" % array_size
			var array_items: Array[String] = []
			var array_limit: int = mini(array_size, SCHEDULED_SIGNATURE_MAX_ITEMS)
			for item_index: int in range(array_limit):
				array_items.append(_scheduled_value_signature((value as Array)[item_index], depth + 1))
			return "array:%d[%s%s]" % [array_size, ",".join(array_items), ",..." if array_size > array_limit else ""]
		TYPE_DICTIONARY:
			var dictionary_size: int = (value as Dictionary).size()
			if depth >= SCHEDULED_SIGNATURE_MAX_DEPTH:
				return "dictionary:%d:max_depth" % dictionary_size
			var dictionary_data: Dictionary[String, Variant] = {}
			for raw_key: Variant in (value as Dictionary).keys():
				dictionary_data[String(raw_key)] = (value as Dictionary).get(raw_key, null)
			var dictionary_keys: Array[String] = []
			for copied_key: String in dictionary_data.keys():
				dictionary_keys.append(copied_key)
			dictionary_keys.sort()
			var dictionary_fields: Array[String] = []
			var dictionary_limit: int = mini(dictionary_keys.size(), SCHEDULED_SIGNATURE_MAX_ITEMS)
			for key_index: int in range(dictionary_limit):
				var selected_key: String = dictionary_keys[key_index]
				dictionary_fields.append("%s=%s" % [selected_key, _scheduled_value_signature(dictionary_data.get(selected_key, null), depth + 1)])
			return "dictionary:%d{%s%s}" % [dictionary_size, ",".join(dictionary_fields), ",..." if dictionary_size > dictionary_limit else ""]
		_:
			return "value:%d:%s" % [type_id, var_to_str(value)]

func _position_snapshot(engine: CombatEngine, team: String) -> Array[Vector2]:
	if team == "player":
		return engine.arena_state.player_positions_current().duplicate()
	return engine.arena_state.enemy_positions_current().duplicate()

func _forced_snapshot(engine: CombatEngine) -> Dictionary[String, int]:
	var output: Dictionary[String, int] = {}
	if engine.arena_state == null or engine.arena_state.forced == null:
		return output
	output["player"] = int(engine.arena_state.forced._team_counts.get("player", 0))
	output["enemy"] = int(engine.arena_state.forced._team_counts.get("enemy", 0))
	return output

func _effect_categories(before: Dictionary[String, Variant], after: Dictionary[String, Variant]) -> Array[String]:
	var categories: Array[String] = []
	if before.get("units") != after.get("units"):
		categories.append("unit_state")
	if before.get("buffs") != after.get("buffs") or before.get("stacks") != after.get("stacks"):
		categories.append("buff_state")
	if before.get("scheduled") != after.get("scheduled"):
		categories.append("scheduled_event")
	if before.get("positions") != after.get("positions"):
		categories.append("position")
	if before.get("targets") != after.get("targets"):
		categories.append("target")
	if before.get("forced") != after.get("forced"):
		categories.append("forced_movement")
	return categories

func _authoritative_categories(categories: Array[String]) -> Array[String]:
	# Scheduling is the immediate authoritative state for deliberately delayed
	# abilities; semantic engine events cover transient marks, buffs, and zones
	# that are not retained in the generic state snapshot.
	var authoritative: Array[String] = []
	for category: String in categories:
		# Target acquisition alone is telemetry, not proof that the ability applied
		# its contractual effect.
		if category != "semantic_target":
			authoritative.append(category)
	return authoritative

func _on_semantic_target(
		source_team: String,
		source_index: int,
		target_team: String,
		target_index: int,
		sink: Array[String]) -> void:
	if source_team != "" and source_index >= 0 and target_team != "" and target_index >= 0:
		sink.append("semantic_target")

func _on_semantic_buff(
		source_team: String,
		source_index: int,
		target_team: String,
		target_index: int,
		kind: String,
		_fields: Dictionary,
		_magnitude: float,
		_duration: float,
		sink: Array[String]) -> void:
	if source_team != "" and source_index >= 0 and target_team != "" and target_index >= 0 and kind != "":
		sink.append("semantic_buff")

func _on_semantic_debuff(
		source_team: String,
		source_index: int,
		target_team: String,
		target_index: int,
		kind: String,
		_fields: Dictionary,
		_magnitude: float,
		_duration: float,
		sink: Array[String]) -> void:
	if source_team != "" and source_index >= 0 and target_team != "" and target_index >= 0 and kind != "":
		sink.append("semantic_debuff")

func _on_semantic_zone_exposure(
		source_team: String,
		source_index: int,
		target_team: String,
		target_index: int,
		kind: String,
		_duration_s: float,
		_damage: float,
		_radius_tiles: float,
		sink: Array[String]) -> void:
	if source_team != "" and source_index >= 0 and target_team != "" and target_index >= 0 and kind != "":
		sink.append("semantic_zone")

func _on_ability_committed(
		source_team: String,
		source_index: int,
		ability_id: String,
		target_team: String,
		target_index: int,
		position: Vector2,
		cooldown_s: float,
		commitment_kind: String,
		sink: Array[Dictionary]) -> void:
	sink.append({
		"source_team": source_team,
		"source_index": source_index,
		"ability_id": ability_id,
		"target_team": target_team,
		"target_index": target_index,
		"position": position,
		"cooldown_s": cooldown_s,
		"commitment_kind": commitment_kind,
	})

func _matching_commit_count(commits: Array[Dictionary], ability_id: String) -> int:
	var count: int = 0
	for commit: Dictionary in commits:
		if String(commit.get("source_team", "")) == "player" \
				and int(commit.get("source_index", -1)) == 0 \
				and String(commit.get("ability_id", "")) == ability_id:
			count += 1
	return count

func _matching_commit(commits: Array[Dictionary], ability_id: String) -> Dictionary:
	for commit: Dictionary in commits:
		if String(commit.get("source_team", "")) == "player" \
				and int(commit.get("source_index", -1)) == 0 \
				and String(commit.get("ability_id", "")) == ability_id:
			return commit
	return {}

func _validate_definition_exceptions(seen_ability_ids: Dictionary[String, bool], failures: Array[String]) -> void:
	var definition_ids: Array[String] = []
	var directory: DirAccess = DirAccess.open("res://data/abilities")
	if directory == null:
		failures.append("could not open res://data/abilities")
		return
	var file_names: Array[String] = []
	directory.list_dir_begin()
	while true:
		var file_name: String = directory.get_next()
		if file_name == "":
			break
		if directory.current_is_dir() or file_name.begins_with(".") or not file_name.ends_with(".tres"):
			continue
		file_names.append(file_name)
	directory.list_dir_end()
	file_names.sort()
	for file_name: String in file_names:
		var path: String = "res://data/abilities/" + file_name
		var resource: Resource = ResourceLoader.load(path)
		if not (resource is AbilityDef):
			failures.append("%s did not load as AbilityDef" % path)
			continue
		var ability_def: AbilityDef = resource as AbilityDef
		var ability_id: String = String(ability_def.id).strip_edges()
		_expect(ability_id != "", "%s has an empty AbilityDef.id" % path, failures)
		_expect(not definition_ids.has(ability_id), "duplicate AbilityDef.id %s" % ability_id, failures)
		if ability_id != "" and not definition_ids.has(ability_id):
			definition_ids.append(ability_id)

	var unreferenced: Array[String] = []
	for ability_id: String in definition_ids:
		if not seen_ability_ids.has(ability_id):
			unreferenced.append(ability_id)
	unreferenced.sort()
	var expected_unreferenced: Array[String] = NON_PLAYABLE_DEFINITION_EXCEPTIONS.duplicate()
	expected_unreferenced.sort()
	_expect(unreferenced == expected_unreferenced,
		"unreferenced AbilityDefs were %s, expected exactly %s" % [
			", ".join(unreferenced),
			", ".join(expected_unreferenced),
		], failures)
	_expect(definition_ids.size() == EXPECTED_PLAYABLE_COUNT + NON_PLAYABLE_DEFINITION_EXCEPTIONS.size(),
		"expected %d total AbilityDefs, found %d" % [
			EXPECTED_PLAYABLE_COUNT + NON_PLAYABLE_DEFINITION_EXCEPTIONS.size(),
			definition_ids.size(),
		], failures)
	for ability_id: String in NON_PLAYABLE_DEFINITION_EXCEPTIONS:
		_expect(not seen_ability_ids.has(ability_id),
			"non-playable exception %s unexpectedly belongs to a playable profile" % ability_id, failures)
		_expect(AbilityCatalog.get_def(ability_id) != null,
			"declared non-playable exception %s has no AbilityDef" % ability_id, failures)

func _float_values(count: int, value: float) -> Array[float]:
	var output: Array[float] = []
	for _index: int in range(count):
		output.append(value)
	return output

func _int_values(count: int, value: int) -> Array[int]:
	var output: Array[int] = []
	for _index: int in range(count):
		output.append(value)
	return output

func _unit_expect(condition: bool, unit_id: String, message: String, failures: Array[String]) -> bool:
	if not condition:
		failures.append("[%s] %s" % [unit_id, message])
	return condition

func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)

func _teardown_fixture(engine: CombatEngine) -> void:
	if engine == null:
		return
	engine.stop()
	engine.teardown()

func _finish(code: int) -> void:
	if do_quit_on_finish:
		get_tree().quit(code)
