extends Node

const CombatEngineScript := preload("res://scripts/game/combat/combat_engine.gd")
const BattleStateScript := preload("res://scripts/game/combat/battle_state.gd")
const UnitFactoryScript := preload("res://scripts/unit_factory.gd")
const BuffTags := preload("res://scripts/game/abilities/buff_tags.gd")
const NoxleyRedStatic := preload("res://scripts/game/abilities/impls/noxley_red_static.gd")
const CreepEavesdropping := preload("res://scripts/game/abilities/impls/creep_eavesdropping.gd")
const OmenryCondemningShot := preload("res://scripts/game/abilities/impls/omenry_condemning_shot.gd")

@export var do_quit_on_finish: bool = true

var _debuff_events: Array[Dictionary] = []

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	print("AbilityContractRegressionProbe: repo")
	await get_tree().process_frame
	_check_repo_cost_and_heal(failures)
	print("AbilityContractRegressionProbe: noxley")
	await get_tree().process_frame
	_check_noxley_health_cost_and_dot_telemetry(failures)
	print("AbilityContractRegressionProbe: ivara opener")
	await get_tree().process_frame
	_check_ivara_opening_mana_and_cadence(failures)
	print("AbilityContractRegressionProbe: quorra opener")
	await get_tree().process_frame
	_check_quorra_opening_lunge_mana(failures)
	print("AbilityContractRegressionProbe: quillith")
	await get_tree().process_frame
	_check_quillith_solo_and_team_mana(failures)
	print("AbilityContractRegressionProbe: quillith power")
	await get_tree().process_frame
	_check_quillith_power_contracts(failures)
	print("AbilityContractRegressionProbe: exile")
	await get_tree().process_frame
	_check_exile_upgrade_contract(failures)
	print("AbilityContractRegressionProbe: gable")
	await get_tree().process_frame
	_check_gable_vulnerability(failures)
	print("AbilityContractRegressionProbe: omenry")
	await get_tree().process_frame
	_check_omenry_range_window(failures)
	print("AbilityContractRegressionProbe: kett")
	await get_tree().process_frame
	_check_kett_stacking_debuff(failures)
	print("AbilityContractRegressionProbe: sable")
	await get_tree().process_frame
	_check_sable_transactional_refund(failures)
	print("AbilityContractRegressionProbe: teller")
	await get_tree().process_frame
	_check_teller_margin_call(failures)
	print("AbilityContractRegressionProbe: velour")
	await get_tree().process_frame
	_check_velour_self_exclusion(failures)
	print("AbilityContractRegressionProbe: vesper")
	await get_tree().process_frame
	_check_vesper_readable_delay(failures)
	if not failures.is_empty():
		for failure: String in failures:
			push_error(failure)
		_finish(1)
		return
	print("AbilityContractRegressionProbe: PASS")
	_finish(0)

func _check_repo_cost_and_heal(failures: Array[String]) -> void:
	var ability_def: AbilityDef = load("res://data/abilities/repo_writ_of_severance.tres") as AbilityDef
	_expect(ability_def != null, "Repo ability definition did not load", failures)
	if ability_def != null:
		_expect(int(ability_def.base_cost) == 60, "Repo ability cost must remain 60", failures)

	var repo: Unit = _make_unit("repo", 1800)
	repo.ability_id = "repo_writ_of_severance"
	repo.mana_max = 60
	repo.mana = 60
	var enemy: Unit = _make_unit("repo_target", 5000)
	enemy.armor = 40.0
	enemy.magic_resist = 40.0
	var fixture: Dictionary = _make_fixture([repo], [enemy])
	var state: BattleState = fixture["state"] as BattleState
	var engine: CombatEngine = fixture["engine"] as CombatEngine
	state.player_targets = [0]
	var cast_result: Dictionary = engine.ability_system.try_cast("player", 0)
	_expect(bool(cast_result.get("cast", false)), "Repo Repossession did not cast through the public cast boundary", failures)
	_expect(is_equal_approx(float(repo.armor), 18.0) and is_equal_approx(float(repo.magic_resist), 18.0), "Repo Repossession did not transfer 18 Armor and Magic Resist to Repo", failures)
	_expect(is_equal_approx(float(enemy.armor), 22.0) and is_equal_approx(float(enemy.magic_resist), 22.0), "Repo Repossession did not debit the current target by 18 Armor and Magic Resist", failures)
	_expect(int(repo.mana) == 0, "Repo Repossession successful cast did not spend its full mana cost", failures)
	_teardown_fixture(engine)

func _check_noxley_health_cost_and_dot_telemetry(failures: Array[String]) -> void:
	var ability_def: AbilityDef = load("res://data/abilities/noxley_red_static.tres") as AbilityDef
	_expect(ability_def != null, "Noxley ability definition did not load", failures)
	if ability_def != null:
		_expect(int(ability_def.base_cost) == 50, "Noxley recurring mana cap must remain 50", failures)
		_expect(int(ability_def.starting_mana_bonus) == 0, "Noxley must not receive a removed opening-mana bonus", failures)

	var no_target_noxley: Unit = _make_unit("noxley", 2000)
	var unavailable_enemy: Unit = _make_unit("unavailable_enemy", 3000)
	var no_target_fixture: Dictionary = _make_fixture([no_target_noxley], [unavailable_enemy])
	var no_target_state: BattleState = no_target_fixture["state"] as BattleState
	var no_target_engine: CombatEngine = no_target_fixture["engine"] as CombatEngine
	var no_target_ctx: AbilityContext = _context(no_target_engine, no_target_state)
	unavailable_enemy.hp = 0
	var no_target_ability: Variant = NoxleyRedStatic.new()
	var no_target_hp_before: int = int(no_target_noxley.hp)
	_expect(not bool(no_target_ability.call("cast", no_target_ctx)), "Noxley cast without a valid target should fail", failures)
	_expect(int(no_target_noxley.hp) == no_target_hp_before, "Noxley paid health before finding a valid target", failures)
	_teardown_fixture(no_target_engine)

	var cost_noxley: Unit = _make_unit("noxley", 2000)
	var cost_enemy: Unit = _make_unit("cost_enemy", 3000)
	var cost_fixture: Dictionary = _make_fixture([cost_noxley], [cost_enemy])
	var cost_state: BattleState = cost_fixture["state"] as BattleState
	var cost_engine: CombatEngine = cost_fixture["engine"] as CombatEngine
	var cost_ctx: AbilityContext = _context(cost_engine, cost_state)
	var cost_ability: Variant = NoxleyRedStatic.new()
	cost_ability.call("_spend_health", cost_ctx, cost_noxley)
	_expect(int(cost_noxley.hp) == 1920, "Noxley health cost must be 4% of max HP", failures)
	_teardown_fixture(cost_engine)

	var telemetry_noxley: Unit = _make_unit("noxley", 2000)
	telemetry_noxley.ability_id = "noxley_red_static"
	telemetry_noxley.mana_max = 50
	telemetry_noxley.mana = 0
	var telemetry_enemy: Unit = _make_unit("telemetry_enemy", 5000)
	var telemetry_fixture: Dictionary = _make_fixture([telemetry_noxley], [telemetry_enemy])
	var telemetry_engine: CombatEngine = telemetry_fixture["engine"] as CombatEngine
	_expect(int(telemetry_noxley.mana) == 0, "Noxley should enter combat without a special opening-mana bonus", failures)
	telemetry_noxley.mana = 50
	_debuff_events.clear()
	telemetry_engine.debuff_applied.connect(_on_debuff_applied)
	var telemetry_cast_result: Dictionary = telemetry_engine.ability_system.try_cast("player", 0)
	var telemetry_cast_ok: bool = bool(telemetry_cast_result.get("cast", false))
	_expect(telemetry_cast_ok, "Noxley DoT telemetry fixture did not cast", failures)
	_expect(int(telemetry_noxley.mana) == 20, "Noxley's 20-mana refund was not preserved after the shared mana reset", failures)
	var dot_event: Dictionary = _find_debuff_event("noxley_red_static_dot")
	_expect(not dot_event.is_empty(), "Noxley did not emit explicit DoT debuff-presence telemetry", failures)
	if not dot_event.is_empty():
		_expect(String(dot_event.get("source_team", "")) == "player" and int(dot_event.get("source_index", -1)) == 0, "Noxley DoT telemetry was not owned by its caster", failures)
		_expect(String(dot_event.get("target_team", "")) == "enemy" and int(dot_event.get("target_index", -1)) == 0, "Noxley DoT telemetry targeted the wrong unit", failures)
		var dot_fields: Dictionary = dot_event.get("fields", {}) if dot_event.get("fields", {}) is Dictionary else {}
		_expect(int(dot_fields.get("damage_per_tick", 0)) == 48 and int(dot_fields.get("ticks", 0)) == 6, "Noxley DoT telemetry did not classify its level-1 tick payload", failures)
		_expect(is_equal_approx(float(dot_event.get("duration", 0.0)), 2.7), "Noxley DoT telemetry did not report its full duration", failures)
	var scheduled_events: Array[Dictionary] = _scheduled_events(telemetry_engine)
	_expect(scheduled_events.size() == 1, "Noxley cast did not schedule exactly one delayed effect for its only target", failures)
	if scheduled_events.size() == 1:
		var scheduled_event: Dictionary = scheduled_events[0] as Dictionary
		var scheduled_data: Dictionary = scheduled_event.get("data", {}) if scheduled_event.get("data", {}) is Dictionary else {}
		var scheduled_center: Variant = scheduled_data.get("center", null)
		_expect(scheduled_center is Vector2, "Noxley delayed static did not store its impact center", failures)
		if scheduled_center is Vector2:
			_expect((scheduled_center as Vector2).is_equal_approx(telemetry_engine.get_enemy_position(0)), "Noxley delayed static stored the wrong impact center", failures)
		telemetry_noxley.hp = 0
		var hp_before_dead_source_tick: int = int(telemetry_enemy.hp)
		var one_tick_data: Dictionary = scheduled_data.duplicate(true)
		one_tick_data["ticks_left"] = 1
		telemetry_engine.ability_system.call("_handle_planned_area_tick", "player", 0, one_tick_data)
		_expect(int(telemetry_enemy.hp) == hp_before_dead_source_tick, "Noxley delayed static continued after its source died", failures)
		_expect(int(telemetry_noxley.hp) == 0, "Noxley delayed static healed a dead source", failures)
	telemetry_engine.debuff_applied.disconnect(_on_debuff_applied)
	_teardown_fixture(telemetry_engine)

	var field_caster: Unit = _make_unit("noxley_field_source", 2000)
	var dead_mark: Unit = _make_unit("dead_mark", 1000)
	var origin_bystander: Unit = _make_unit("origin_bystander", 1000)
	var field_bystander: Unit = _make_unit("field_bystander", 1000)
	var field_fixture: Dictionary = _make_fixture([field_caster], [dead_mark, origin_bystander, field_bystander])
	var field_engine: CombatEngine = field_fixture["engine"] as CombatEngine
	_set_positions(field_engine, [Vector2(64.0, 128.0)], [Vector2(400.0, 128.0), Vector2.ZERO, Vector2(440.0, 128.0)])
	dead_mark.hp = 0
	var origin_hp_before: int = int(origin_bystander.hp)
	var field_hp_before: int = int(field_bystander.hp)
	var dead_mark_tick: Dictionary = {
		"target_index": 0,
		"center": Vector2(400.0, 128.0),
		"damage": 48,
		"damage_type": "magic",
		"ticks_left": 1,
		"interval": 0.45,
		"dot_kind": "noxley_red_static",
		"radius": 1.25
	}
	field_engine.ability_system.call("_handle_planned_area_tick", "player", 0, dead_mark_tick)
	_expect(int(field_bystander.hp) < field_hp_before, "Noxley static field did not persist at a killed mark's stored impact center", failures)
	_expect(int(origin_bystander.hp) == origin_hp_before, "Noxley static field redirected to world origin after its mark died", failures)
	_teardown_fixture(field_engine)

func _check_quorra_opening_lunge_mana(failures: Array[String]) -> void:
	var ability_def: AbilityDef = load("res://data/abilities/quorra_timeplate_lunge.tres") as AbilityDef
	_expect(ability_def != null, "Quorra ability definition did not load", failures)
	if ability_def == null:
		return
	_expect(int(ability_def.base_cost) == 55, "Quorra recurring Lunge cadence must remain 55 mana", failures)
	_expect(int(ability_def.starting_mana_bonus) == 0, "Quorra must not receive a removed opening-mana bonus", failures)

	var quorra: Unit = UnitFactoryScript.spawn("quorra")
	_expect(quorra != null, "Quorra opener fixture failed to spawn Quorra", failures)
	if quorra == null:
		return
	quorra.mana = 0
	var enemy: Unit = _make_unit("quorra_target", 5000)
	enemy.attack_speed = 1.0
	var fixture: Dictionary = _make_fixture([quorra], [enemy])
	var state: BattleState = fixture["state"] as BattleState
	var engine: CombatEngine = fixture["engine"] as CombatEngine
	_expect(int(quorra.mana) == 0, "Quorra should enter combat without a special opening-mana bonus", failures)
	quorra.mana = 55
	_debuff_events.clear()
	engine.debuff_applied.connect(_on_debuff_applied)
	var cast_result: Dictionary = engine.ability_system.try_cast("player", 0)
	_expect(bool(cast_result.get("cast", false)), "Quorra full-mana Timeplate Lunge did not cast", failures)
	_expect(int(quorra.mana) == 0, "Quorra Timeplate Lunge did not spend its recurring mana cost", failures)
	_expect(engine.buff_system.has_tag(state, "enemy", 0, "quorra_timeplate_wound"), "Quorra Timeplate Lunge did not apply its cleanseable wound", failures)
	var scheduled_events: Array[Dictionary] = _scheduled_events(engine)
	_expect(scheduled_events.size() == 1, "Quorra opening Lunge did not schedule exactly one wound sequence", failures)
	if scheduled_events.size() == 1:
		var scheduled_event: Dictionary = scheduled_events[0] as Dictionary
		var scheduled_data: Dictionary = scheduled_event.get("data", {}) if scheduled_event.get("data", {}) is Dictionary else {}
		_expect(String(scheduled_data.get("wound_tag", "")) == "quorra_timeplate_wound", "Quorra wound sequence did not retain its cleanseable wound tag", failures)
	if engine.debuff_applied.is_connected(Callable(self, "_on_debuff_applied")):
		engine.debuff_applied.disconnect(_on_debuff_applied)
	_teardown_fixture(engine)

func _check_ivara_opening_mana_and_cadence(failures: Array[String]) -> void:
	var ability_def: AbilityDef = load("res://data/abilities/ivara_open_bid.tres") as AbilityDef
	_expect(ability_def != null, "Ivara ability definition did not load", failures)
	if ability_def == null:
		return
	_expect(int(ability_def.base_cost) == 35, "Ivara Open Bid cost must remain 35", failures)
	_expect(int(ability_def.starting_mana_bonus) == 0, "Ivara must not receive a removed opening-mana bonus", failures)

	var ivara: Unit = UnitFactoryScript.spawn("ivara")
	_expect(ivara != null, "Ivara fixture failed to spawn Ivara", failures)
	if ivara == null:
		return
	ivara.mana = 0
	var lower_hp_enemy: Unit = _make_unit("ivara_lower_hp_target", 5000)
	var highest_hp_enemy: Unit = _make_unit("ivara_highest_hp_target", 7000)
	var fixture: Dictionary = _make_fixture([ivara], [lower_hp_enemy, highest_hp_enemy])
	var state: BattleState = fixture["state"] as BattleState
	var engine: CombatEngine = fixture["engine"] as CombatEngine
	_expect(int(ivara.mana) == 0 and int(ivara.mana_start) == 0, "Ivara should enter combat with its persistent zero mana start", failures)
	ivara.mana = 34
	var short_cast: Dictionary = engine.ability_system.try_cast("player", 0)
	_expect(not bool(short_cast.get("cast", false)) and String(short_cast.get("reason", "")) == "not_enough_mana", "Ivara Open Bid must reject 34 mana", failures)
	ivara.mana = 35
	var full_cast: Dictionary = engine.ability_system.try_cast("player", 0)
	_expect(bool(full_cast.get("cast", false)), "Ivara Open Bid must cast at 35 mana", failures)
	_expect(int(ivara.mana) == 0, "Ivara Open Bid did not spend its full mana cost", failures)
	_expect(state.player_targets[0] == 1, "Ivara Open Bid did not focus the highest-Health enemy", failures)
	_expect(engine.buff_system.has_tag(state, "enemy", 1, "ivara_open_bid_mark"), "Ivara Open Bid did not apply its visible cleanseable mark", failures)
	_teardown_fixture(engine)

func _check_quillith_solo_and_team_mana(failures: Array[String]) -> void:
	var solo_quillith: Unit = _make_unit("quillith", 1800)
	solo_quillith.ability_id = "quillith_final_exam"
	solo_quillith.mana_max = 36
	solo_quillith.mana = 36
	var solo_enemy: Unit = _make_unit("solo_enemy", 3000)
	var solo_fixture: Dictionary = _make_fixture([solo_quillith], [solo_enemy])
	var solo_engine: CombatEngine = solo_fixture["engine"] as CombatEngine
	var solo_cast: Dictionary = solo_engine.ability_system.try_cast("player", 0)
	_expect(not bool(solo_cast.get("cast", false)), "Quillith must not cast Final Exam without a living pupil", failures)
	_expect(String(solo_cast.get("reason", "")) == "cast_failed", "Quillith missing-pupil cast must fail at the public cast boundary", failures)
	_expect(int(solo_quillith.mana) == 36, "Quillith missing-pupil cast must not spend mana", failures)
	_teardown_fixture(solo_engine)

	var team_quillith: Unit = _make_unit("quillith", 1800)
	team_quillith.ability_id = "quillith_final_exam"
	team_quillith.mana_max = 36
	team_quillith.mana = 36
	var pupil: Unit = _make_unit("noxley", 1800)
	pupil.ability_id = "noxley_red_static"
	var team_enemy: Unit = _make_unit("team_enemy", 4000)
	var team_fixture: Dictionary = _make_fixture([team_quillith, pupil], [team_enemy])
	var team_state: BattleState = team_fixture["state"] as BattleState
	var team_engine: CombatEngine = team_fixture["engine"] as CombatEngine
	team_state.player_pupil_map[0] = 1
	var pupil_hp_before: int = int(pupil.hp)
	var enemy_hp_before: int = int(team_enemy.hp)
	_debuff_events.clear()
	team_engine.debuff_applied.connect(_on_debuff_applied)
	var team_cast: Dictionary = team_engine.ability_system.try_cast("player", 0)
	_expect(bool(team_cast.get("cast", false)), "Quillith paired-pupil cast failed at the public cast boundary", failures)
	_expect(int(team_quillith.mana) == 0, "Quillith successful Final Exam must spend its 36 mana", failures)
	_expect(int(pupil.hp) == pupil_hp_before - 27, "Quillith Noxley repeat must pay Health cost then heal 40% of its actual reduced damage", failures)
	_expect(enemy_hp_before - int(team_enemy.hp) == 113, "Quillith Final Exam must recast the paired pupil's 205 damage at 55% power", failures)
	var quillith_dot: Dictionary = _find_debuff_event("noxley_red_static_dot")
	_expect(int(quillith_dot.get("source_index", -1)) == 1, "Quillith repeat must attribute pupil debuffs to the paired pupil", failures)
	var queued: Array[Dictionary] = _scheduled_events(team_engine)
	_expect(queued.size() == 1, "Quillith Noxley repeat did not retain its delayed static through the event queue", failures)
	if queued.size() == 1:
		var queued_event: Dictionary = queued[0] as Dictionary
		var queued_data: Dictionary = queued_event.get("data", {}) if queued_event.get("data", {}) is Dictionary else {}
		_expect(is_equal_approx(float(queued_data.get("ability_power_scale", 0.0)), 0.55), "Quillith delayed static lost its 55% power envelope", failures)
		var hp_before_dot: int = int(team_enemy.hp)
		team_engine.ability_system.tick(0.45)
		_expect(enemy_hp_before - hp_before_dot == 113 and hp_before_dot - int(team_enemy.hp) == 26, "Quillith Noxley delayed static must deal one 55%-scaled tick", failures)
		var repeated: Array[Dictionary] = _scheduled_events(team_engine)
		_expect(repeated.size() == 1, "Repeating delayed effects must survive the queue", failures)
		if repeated.size() == 1:
			var repeated_event: Dictionary = repeated[0] as Dictionary
			var repeated_data: Dictionary = repeated_event.get("data", {}) if repeated_event.get("data", {}) is Dictionary else {}
			_expect(is_equal_approx(float(repeated_data.get("ability_power_scale", 0.0)), 0.55), "Repeating delayed effects must retain their original power scale", failures)
	if team_engine.debuff_applied.is_connected(Callable(self, "_on_debuff_applied")):
		team_engine.debuff_applied.disconnect(_on_debuff_applied)
	_teardown_fixture(team_engine)

	var fallback_quillith: Unit = _make_unit("quillith", 1800)
	fallback_quillith.ability_id = "quillith_final_exam"
	fallback_quillith.mana_max = 36
	fallback_quillith.mana = 36
	var dead_pupil: Unit = _make_unit("dead_pupil", 1800)
	dead_pupil.ability_id = "noxley_red_static"
	dead_pupil.hp = 0
	var unrelated_ally: Unit = _make_unit("unrelated_ally", 1800)
	unrelated_ally.ability_id = "noxley_red_static"
	var fallback_enemy: Unit = _make_unit("fallback_enemy", 4000)
	var fallback_fixture: Dictionary = _make_fixture([fallback_quillith, dead_pupil, unrelated_ally], [fallback_enemy])
	var fallback_state: BattleState = fallback_fixture["state"] as BattleState
	var fallback_engine: CombatEngine = fallback_fixture["engine"] as CombatEngine
	fallback_state.player_pupil_map[0] = 1
	var fallback_cast: Dictionary = fallback_engine.ability_system.try_cast("player", 0)
	_expect(not bool(fallback_cast.get("cast", false)), "Quillith must not substitute another ally when its paired pupil is dead", failures)
	_expect(int(fallback_quillith.mana) == 36, "Quillith must not spend mana when its paired pupil is dead", failures)
	_teardown_fixture(fallback_engine)

func _check_quillith_power_contracts(failures: Array[String]) -> void:
	var repo_mentor: Unit = _make_unit("quillith_repo", 1800)
	repo_mentor.ability_id = "quillith_final_exam"
	repo_mentor.mana_max = 36
	repo_mentor.mana = 36
	var repo_pupil: Unit = _make_unit("repo_pupil", 1800)
	repo_pupil.ability_id = "repo_writ_of_severance"
	var repo_enemy: Unit = _make_unit("repo_power_target", 4000)
	repo_enemy.armor = 40.0
	repo_enemy.magic_resist = 40.0
	var repo_fixture: Dictionary = _make_fixture([repo_mentor, repo_pupil], [repo_enemy])
	var repo_state: BattleState = repo_fixture["state"] as BattleState
	var repo_engine: CombatEngine = repo_fixture["engine"] as CombatEngine
	repo_state.player_pupil_map[0] = 1
	repo_state.player_targets = [0, 0]
	_expect(_cast_success(repo_engine), "Quillith paired Repo cast failed", failures)
	_expect(is_equal_approx(float(repo_pupil.armor), 9.9) and is_equal_approx(float(repo_pupil.magic_resist), 9.9), "Quillith Repo credit must transfer Armor and MR at exactly 55%", failures)
	_expect(is_equal_approx(float(repo_enemy.armor), 30.1) and is_equal_approx(float(repo_enemy.magic_resist), 30.1), "Quillith Repo debit must transfer Armor and MR at exactly 55%", failures)
	_teardown_fixture(repo_engine)

	var paisley_mentor: Unit = _make_unit("quillith_paisley", 1000)
	paisley_mentor.ability_id = "quillith_final_exam"
	paisley_mentor.mana_max = 36
	paisley_mentor.mana = 36
	var paisley_pupil: Unit = _make_unit("paisley_pupil", 1000)
	paisley_pupil.ability_id = "paisley_bubbles"
	paisley_pupil.hp = 400
	var paisley_enemy: Unit = _make_unit("paisley_power_target", 4000)
	var paisley_fixture: Dictionary = _make_fixture([paisley_mentor, paisley_pupil], [paisley_enemy])
	var paisley_state: BattleState = paisley_fixture["state"] as BattleState
	var paisley_engine: CombatEngine = paisley_fixture["engine"] as CombatEngine
	paisley_state.player_pupil_map[0] = 1
	_set_positions(paisley_engine, [Vector2(64.0, 128.0), Vector2(96.0, 128.0)], [Vector2(128.0, 128.0)])
	_expect(_cast_success(paisley_engine), "Quillith paired Paisley cast failed", failures)
	_expect(int(paisley_pupil.ui_shield) == 55, "Quillith Paisley shield must be 55% of its authored amount", failures)
	var paisley_hp_before: int = int(paisley_enemy.hp)
	_debuff_events.clear()
	paisley_engine.debuff_applied.connect(_on_debuff_applied)
	var paisley_broken_shield: int = paisley_engine.buff_system.break_shields_on(paisley_state, "player", 1)
	_expect(paisley_broken_shield == 55, "Quillith Paisley shield break must use the scaled live shield", failures)
	_expect(int(paisley_hp_before - paisley_enemy.hp) == 61, "Quillith Paisley pop damage must be 55% once", failures)
	var paisley_stun: Dictionary = _find_debuff_event("stun")
	var paisley_stun_fields: Dictionary = paisley_stun.get("fields", {}) if paisley_stun.get("fields", {}) is Dictionary else {}
	_expect(is_equal_approx(float(paisley_stun_fields.get("duration", 0.0)), 0.4) and int(paisley_stun.get("source_index", -1)) == 1, "Quillith Paisley pop stun must retain its authored lifetime and pupil attribution", failures)
	if paisley_engine.debuff_applied.is_connected(Callable(self, "_on_debuff_applied")):
		paisley_engine.debuff_applied.disconnect(_on_debuff_applied)
	_teardown_fixture(paisley_engine)

	var rooket_mentor: Unit = _make_unit("quillith_rooket", 1800)
	rooket_mentor.ability_id = "quillith_final_exam"
	rooket_mentor.mana_max = 36
	rooket_mentor.mana = 36
	var rooket_pupil: Unit = _make_unit("rooket_pupil", 1800)
	rooket_pupil.ability_id = "rooket_brace_shot"
	var rooket_enemy: Unit = _make_unit("rooket_power_target", 5000)
	rooket_enemy.armor = 100.0
	var rooket_fixture: Dictionary = _make_fixture([rooket_mentor, rooket_pupil], [rooket_enemy])
	var rooket_state: BattleState = rooket_fixture["state"] as BattleState
	var rooket_engine: CombatEngine = rooket_fixture["engine"] as CombatEngine
	rooket_state.player_pupil_map[0] = 1
	rooket_state.player_targets = [0, 0]
	var rooket_hp_before: int = int(rooket_enemy.hp)
	_expect(_cast_success(rooket_engine), "Quillith paired Rooket cast failed", failures)
	rooket_engine.ability_system.tick(0.35)
	_expect(int(rooket_hp_before - rooket_enemy.hp) == 69, "Quillith Rooket delayed shot must deal 55% once before normal armor mitigation", failures)
	_expect(is_equal_approx(float(rooket_enemy.armor), 84.6) and is_equal_approx(float(rooket_enemy.attack_speed), 0.89), "Quillith Rooket delayed shred must be 55% once", failures)
	_teardown_fixture(rooket_engine)

	var kythera_mentor: Unit = _make_unit("quillith_kythera", 1800)
	kythera_mentor.ability_id = "quillith_final_exam"
	kythera_mentor.mana_max = 36
	kythera_mentor.mana = 36
	var kythera_pupil: Unit = _make_unit("kythera_pupil", 1800)
	kythera_pupil.ability_id = "kythera_siphon"
	var kythera_enemy: Unit = _make_unit("kythera_power_target", 5000)
	kythera_enemy.magic_resist = 100.0
	var kythera_fixture: Dictionary = _make_fixture([kythera_mentor, kythera_pupil], [kythera_enemy])
	var kythera_state: BattleState = kythera_fixture["state"] as BattleState
	var kythera_engine: CombatEngine = kythera_fixture["engine"] as CombatEngine
	kythera_state.player_pupil_map[0] = 1
	kythera_state.player_targets = [0, 0]
	_expect(_cast_success(kythera_engine), "Quillith paired Kythera cast failed", failures)
	kythera_engine.buff_system.tick(kythera_state, 1.0)
	kythera_engine.ability_system.tick(1.0)
	kythera_engine.buff_system.tick(kythera_state, 1.0)
	kythera_engine.ability_system.tick(1.0)
	_expect(is_equal_approx(float(kythera_enemy.magic_resist), 98.9), "Quillith Kythera drain must retain a single 55% scale", failures)
	kythera_engine.buff_system.tick(kythera_state, 1.0)
	kythera_engine.ability_system.tick(1.0)
	_expect(is_equal_approx(float(kythera_enemy.magic_resist), 99.45), "Quillith Kythera must apply its third 55% drain after prior temporary drains expire", failures)
	_expect(is_equal_approx(float(kythera_pupil.magic_resist), 2.0), "Quillith Kythera gain must use drained output without applying 55% twice", failures)
	_teardown_fixture(kythera_engine)

	var gable_mentor: Unit = _make_unit("quillith_gable", 1800)
	gable_mentor.ability_id = "quillith_final_exam"
	gable_mentor.mana_max = 36
	gable_mentor.mana = 36
	var gable_pupil: Unit = _make_unit("gable_pupil", 1800)
	gable_pupil.ability_id = "gable_market_corner"
	var gable_marked: Unit = _make_unit("gable_power_mark", 4000)
	gable_marked.attack_damage = 300.0
	var gable_secondary: Unit = _make_unit("gable_power_secondary", 4000)
	var gable_fixture: Dictionary = _make_fixture([gable_mentor, gable_pupil], [gable_marked, gable_secondary])
	var gable_state: BattleState = gable_fixture["state"] as BattleState
	var gable_engine: CombatEngine = gable_fixture["engine"] as CombatEngine
	gable_state.player_pupil_map[0] = 1
	_set_positions(gable_engine, [Vector2(32.0, 128.0), Vector2(64.0, 128.0)], [Vector2(128.0, 128.0), Vector2(160.0, 128.0)])
	_expect(_cast_success(gable_engine), "Quillith paired Gable cast failed", failures)
	var gable_secondary_hp_before: int = int(gable_secondary.hp)
	gable_engine.emit_signal("hit_applied", "player", 1, 0, 100, 100, false, int(gable_marked.hp), int(gable_marked.hp) - 100, 0.0, 0.0)
	_expect(int(gable_secondary_hp_before - gable_secondary.hp) == 30, "Quillith Gable mark must apply 55% power to its authored 55% ricochet", failures)
	_teardown_fixture(gable_engine)

	var korath_mentor: Unit = _make_unit("quillith_korath", 1800)
	korath_mentor.ability_id = "quillith_final_exam"
	korath_mentor.mana_max = 36
	korath_mentor.mana = 36
	var korath_pupil: Unit = _make_unit("korath_pupil", 1800)
	korath_pupil.ability_id = "korath_absorb_release"
	korath_pupil.hp = 1000
	var korath_ally: Unit = _make_unit("korath_protected_ally", 1800)
	var korath_enemy: Unit = _make_unit("korath_power_target", 4000)
	var korath_fixture: Dictionary = _make_fixture([korath_mentor, korath_pupil, korath_ally], [korath_enemy])
	var korath_state: BattleState = korath_fixture["state"] as BattleState
	var korath_engine: CombatEngine = korath_fixture["engine"] as CombatEngine
	korath_state.player_pupil_map[0] = 1
	_expect(_cast_success(korath_engine), "Quillith paired Korath cast failed", failures)
	var korath_hit: Dictionary = korath_engine.attack_resolver.apply_ability_damage("enemy", 0, 2, 200.0, "true")
	_expect(int(korath_hit.get("redirected", 0)) == 27 and int(korath_pupil.hp) == 973, "Quillith Korath must redirect exactly 55% of its authored absorb ratio", failures)
	korath_engine.ability_system.tick(3.0)
	_expect(int(korath_pupil.hp) == 1198, "Quillith Korath release must retain its redirected pool and scale only the authored base heal", failures)
	_teardown_fixture(korath_engine)

	var velour_mentor: Unit = _make_unit("quillith_velour", 1000)
	velour_mentor.ability_id = "quillith_final_exam"
	velour_mentor.mana_max = 36
	velour_mentor.mana = 36
	velour_mentor.hp = 100
	var velour_pupil: Unit = _make_unit("velour_pupil", 1000)
	velour_pupil.ability_id = "velour_silk_knot"
	var velour_enemy: Unit = _make_unit("velour_power_target", 5000)
	var velour_fixture: Dictionary = _make_fixture([velour_mentor, velour_pupil], [velour_enemy])
	var velour_state: BattleState = velour_fixture["state"] as BattleState
	var velour_engine: CombatEngine = velour_fixture["engine"] as CombatEngine
	velour_state.player_pupil_map[0] = 1
	_expect(_cast_success(velour_engine), "Quillith paired Velour cast failed", failures)
	var velour_root: Dictionary = velour_engine.buff_system.get_tag(velour_state, "enemy", 0, "root")
	_expect(int(velour_mentor.hp) == 169 and is_equal_approx(float(velour_root.get("remaining", 0.0)), 1.5), "Quillith Velour must scale healing while retaining the authored root lifetime", failures)
	_teardown_fixture(velour_engine)

	var axiom_mentor: Unit = _make_unit("quillith_axiom", 1800)
	axiom_mentor.ability_id = "quillith_final_exam"
	axiom_mentor.mana_max = 36
	axiom_mentor.mana = 36
	var axiom_pupil: Unit = _make_unit("axiom_pupil", 1800)
	axiom_pupil.ability_id = "axiom_mentors_reserve"
	var axiom_student: Unit = _make_unit("axiom_student", 1800)
	axiom_student.mana_max = 20
	var axiom_enemy: Unit = _make_unit("axiom_power_target", 5000)
	var axiom_fixture: Dictionary = _make_fixture([axiom_mentor, axiom_pupil, axiom_student], [axiom_enemy])
	var axiom_state: BattleState = axiom_fixture["state"] as BattleState
	var axiom_engine: CombatEngine = axiom_fixture["engine"] as CombatEngine
	axiom_state.player_pupil_map[0] = 1
	axiom_state.player_pupil_map[1] = 2
	_expect(_cast_success(axiom_engine), "Quillith paired Axiom cast failed", failures)
	var axiom_amp: Dictionary = axiom_engine.buff_system.get_tag_data(axiom_state, "player", 2, BuffTags.TAG_DAMAGE_AMP)
	_expect(int(axiom_student.mana) == 3 and is_equal_approx(float(axiom_amp.get("damage_amp_pct", 0.0)), 0.055), "Quillith Axiom nested pupil outputs must be 55%", failures)
	_teardown_fixture(axiom_engine)

	var stunned_mentor: Unit = _make_unit("quillith_stunned_pupil", 1800)
	stunned_mentor.ability_id = "quillith_final_exam"
	stunned_mentor.mana_max = 36
	stunned_mentor.mana = 36
	var stunned_pupil: Unit = _make_unit("stunned_noxley", 1800)
	stunned_pupil.ability_id = "noxley_red_static"
	var stunned_enemy: Unit = _make_unit("stunned_pupil_target", 4000)
	var stunned_fixture: Dictionary = _make_fixture([stunned_mentor, stunned_pupil], [stunned_enemy])
	var stunned_state: BattleState = stunned_fixture["state"] as BattleState
	var stunned_engine: CombatEngine = stunned_fixture["engine"] as CombatEngine
	stunned_state.player_pupil_map[0] = 1
	stunned_engine.buff_system.apply_stun(stunned_state, "player", 1, 1.0)
	var stunned_cast: Dictionary = stunned_engine.ability_system.try_cast("player", 0)
	_expect(not bool(stunned_cast.get("cast", false)) and int(stunned_mentor.mana) == 36 and int(stunned_enemy.hp) == 4000, "A stunned paired pupil must produce no Final Exam echo", failures)
	_teardown_fixture(stunned_engine)

	_check_callback_teardown_contract(failures)

func _check_callback_teardown_contract(failures: Array[String]) -> void:
	var gable: Unit = _make_unit("gable_cleanup", 1800)
	gable.ability_id = "gable_market_corner"
	gable.mana_max = 55
	gable.mana = 55
	var gable_near: Unit = _make_unit("gable_near", 3000)
	var gable_marked: Unit = _make_unit("gable_marked", 3000)
	gable_marked.cost = 4
	gable_marked.attack_damage = 300.0
	var gable_fixture: Dictionary = _make_fixture([gable], [gable_near, gable_marked])
	var gable_engine: CombatEngine = gable_fixture["engine"] as CombatEngine
	_expect(_cast_success(gable_engine), "Gable callback cleanup fixture did not cast", failures)
	var gable_near_before: int = int(gable_near.hp)
	gable_engine.ability_system.teardown()
	gable_engine.emit_signal("hit_applied", "player", 0, 1, 100, 100, false, int(gable_marked.hp), int(gable_marked.hp) - 100, 0.0, 0.0)
	_expect(int(gable_near.hp) == gable_near_before, "Gable teardown must disconnect its hit callback", failures)

	var malachor: Unit = _make_unit("malachor_cleanup", 1800)
	malachor.ability_id = "malachor_debt_of_flesh"
	malachor.mana_max = 50
	malachor.mana = 50
	var malachor_ally: Unit = _make_unit("malachor_cleanup_ally", 1800)
	malachor_ally.hp = 900
	var malachor_enemy: Unit = _make_unit("malachor_cleanup_target", 4000)
	var malachor_fixture: Dictionary = _make_fixture([malachor, malachor_ally], [malachor_enemy])
	var malachor_engine: CombatEngine = malachor_fixture["engine"] as CombatEngine
	_expect(_cast_success(malachor_engine), "Malachor callback cleanup fixture did not cast", failures)
	var malachor_ally_before: int = int(malachor_ally.hp)
	malachor_engine.ability_system.teardown()
	malachor_engine.emit_signal("hit_applied", "enemy", 0, 1, 100, 100, false, int(malachor_ally.hp), int(malachor_ally.hp) - 100, 0.0, 0.0)
	_expect(int(malachor_ally.hp) == malachor_ally_before, "Malachor teardown must disconnect its hit callback", failures)

func _check_exile_upgrade_contract(failures: Array[String]) -> void:
	var creep: Unit = _make_unit("creep", 1800)
	creep.traits = ["Exile"]
	var creep_peer: Unit = _make_unit("creep_peer", 1800)
	creep_peer.traits = ["Exile"]
	var creep_enemy: Unit = _make_unit("creep_enemy", 2500)
	var creep_fixture: Dictionary = _make_fixture([creep, creep_peer], [creep_enemy])
	var creep_state: BattleState = creep_fixture["state"] as BattleState
	var creep_engine: CombatEngine = creep_fixture["engine"] as CombatEngine
	var creep_ctx: AbilityContext = _context(creep_engine, creep_state)
	var creep_ability: Variant = CreepEavesdropping.new()
	_expect(not bool(creep_ability.call("_exile_active", creep_ctx)), "Creep Exile upgrade activated on a two-Exile board", failures)
	creep_engine.buff_system.apply_tag(creep_state, "player", 0, BuffTags.TAG_EXILE_UPGRADE, 9999.0, {"level": 1})
	_expect(bool(creep_ability.call("_exile_active", creep_ctx)), "Creep Exile upgrade ignored its active tag", failures)
	_teardown_fixture(creep_engine)

	var totem: Unit = _make_unit("totem", 1800)
	totem.ability_id = "totem_cleanse"
	totem.mana_max = 60
	totem.traits = ["Exile"]
	var carry: Unit = _make_unit("carry", 1800)
	carry.primary_role = "marksman"
	carry.traits = ["Exile"]
	var totem_enemy: Unit = _make_unit("totem_enemy", 2500)
	var totem_fixture: Dictionary = _make_fixture([totem, carry], [totem_enemy])
	var totem_state: BattleState = totem_fixture["state"] as BattleState
	var totem_engine: CombatEngine = totem_fixture["engine"] as CombatEngine
	totem_engine.buff_system.apply_tag(totem_state, "player", 1, "root", 3.0, {"is_debuff": true})
	totem_engine.ability_system.tick(0.01)
	_expect(int(carry.ui_shield) > 0, "Totem autocast requires any active Exile count and did not cleanse/shield its carry", failures)
	_expect(not totem_engine.buff_system.has_tag(totem_state, "player", 1, "root"), "Totem autocast did not cleanse the carry's root", failures)
	_expect(int(totem.mana) == 0, "Totem autocast did not consume the caster's mana", failures)
	_teardown_fixture(totem_engine)

func _check_gable_vulnerability(failures: Array[String]) -> void:
	var gable: Unit = _make_unit("gable", 2200)
	gable.ability_id = "gable_market_corner"
	gable.mana_max = 55
	gable.mana = 55
	var first: Unit = _make_unit("first", 5000)
	var second: Unit = _make_unit("second", 5000)
	var third: Unit = _make_unit("third", 6000)
	third.cost = 4
	third.attack_damage = 300.0
	var fixture: Dictionary = _make_fixture([gable], [first, second, third])
	var engine: CombatEngine = fixture["engine"] as CombatEngine
	_set_positions(engine, [Vector2(64.0, 128.0)], [Vector2(256.0, 128.0), Vector2(320.0, 128.0), Vector2(384.0, 128.0)])
	_debuff_events.clear()
	engine.debuff_applied.connect(_on_debuff_applied)
	var cast_result: Dictionary = engine.ability_system.try_cast("player", 0)
	_expect(bool(cast_result.get("cast", false)), "Gable Market Corner did not cast through the public cast boundary", failures)
	_expect(not _find_debuff_event("gable_market_corner_mark").is_empty(), "Gable Market Corner did not mark the highest-value enemy", failures)
	var second_hp_before: int = int(second.hp)
	engine.emit_signal("hit_applied", "player", 0, 2, 100, 100, false, int(third.hp), int(third.hp) - 100, 0.0, 0.0)
	_expect(absi(second_hp_before - int(second.hp) - 55) <= 1, "Gable Market Corner did not ricochet 55% of a subsequent marked-target hit to the nearest other enemy", failures)
	_expect(int(gable.mana) == 0, "Gable Market Corner successful cast did not spend its full mana cost", failures)
	if engine.debuff_applied.is_connected(Callable(self, "_on_debuff_applied")):
		engine.debuff_applied.disconnect(_on_debuff_applied)
	_teardown_fixture(engine)

func _check_omenry_range_window(failures: Array[String]) -> void:
	var omenry: Unit = _make_unit("omenry", 2200)
	omenry.attack_range = 5
	var isolated_target: Unit = _make_unit("isolated_target", 5000)
	var fixture: Dictionary = _make_fixture([omenry], [isolated_target])
	var state: BattleState = fixture["state"] as BattleState
	var engine: CombatEngine = fixture["engine"] as CombatEngine
	_set_positions(engine, [Vector2(64.0, 128.0)], [Vector2(384.0, 128.0)])
	var ctx: AbilityContext = _context(engine, state)
	var ability: Variant = OmenryCondemningShot.new()
	var cast_ok: bool = bool(ability.call("cast", ctx))
	_expect(cast_ok, "Omenry range-window fixture did not cast", failures)
	_expect(int(omenry.attack_range) == 7, "Omenry Condemning Shot did not grant its five-second +2 range window", failures)
	engine.buff_system.tick(state, 5.01)
	_expect(int(omenry.attack_range) == 5, "Omenry Condemning Shot range window did not expire after five seconds", failures)
	_teardown_fixture(engine)

func _check_kett_stacking_debuff(failures: Array[String]) -> void:
	var kett: Unit = _make_unit("kett", 2200)
	kett.ability_id = "kett_union_breaker"
	kett.mana_max = 50
	kett.mana = 50
	var target: Unit = _make_unit("kett_target", 10000)
	target.armor = 100.0
	target.attack_speed = 1.0
	var fixture: Dictionary = _make_fixture([kett], [target])
	var state: BattleState = fixture["state"] as BattleState
	var engine: CombatEngine = fixture["engine"] as CombatEngine
	state.player_targets = [0]
	var cast_result: Dictionary = engine.ability_system.try_cast("player", 0)
	_expect(bool(cast_result.get("cast", false)), "Kett Union Breaker did not cast through the public cast boundary", failures)
	var scheduled_events: Array[Dictionary] = _scheduled_events(engine)
	_expect(scheduled_events.size() == 3, "Kett Union Breaker did not schedule its three readable hit beats", failures)
	engine.ability_system.tick(0.01)
	engine.ability_system.tick(0.22)
	engine.ability_system.tick(0.22)
	_expect(is_equal_approx(float(target.armor), 70.0), "Kett should apply three -10 Armor debuffs", failures)
	_expect(is_equal_approx(float(target.attack_speed), 1.0), "Kett Union Breaker must not apply a removed attack-speed shred", failures)
	_expect(engine.buff_system.is_stunned(target), "Kett Union Breaker finisher did not briefly stun its target", failures)
	_expect(int(kett.mana) == 0, "Kett Union Breaker successful cast did not spend its full mana cost", failures)
	_teardown_fixture(engine)

func _check_sable_transactional_refund(failures: Array[String]) -> void:
	var sable: Unit = _make_unit("sable", 2200)
	sable.ability_id = "sable_footnote_piercer"
	sable.mana_max = 50
	sable.mana = 50
	var first: Unit = _make_unit("sable_first", 5000)
	var second: Unit = _make_unit("sable_second", 4500)
	var fixture: Dictionary = _make_fixture([sable], [first, second])
	var state: BattleState = fixture["state"] as BattleState
	var engine: CombatEngine = fixture["engine"] as CombatEngine
	_set_positions(engine, [Vector2(64.0, 128.0)], [Vector2(256.0, 128.0), Vector2(320.0, 128.0)])
	state.player_targets = [0]
	var cast_result: Dictionary = engine.ability_system.try_cast("player", 0)
	_expect(bool(cast_result.get("cast", false)), "Sable transactional refund fixture did not cast", failures)
	_expect(int(sable.mana) == 34, "Sable refund was not preserved after the shared mana reset", failures)
	_teardown_fixture(engine)

func _check_teller_margin_call(failures: Array[String]) -> void:
	var teller: Unit = _make_unit("teller", 2200)
	teller.ability_id = "teller_margin_call"
	teller.mana_max = 60
	teller.mana = 60
	teller.attack_damage = 100.0
	var nearer: Unit = _make_unit("teller_nearer", 2000)
	var farther_a: Unit = _make_unit("teller_farther_a", 2000)
	var farther_b: Unit = _make_unit("teller_farther_b", 2000)
	var fixture: Dictionary = _make_fixture([teller], [nearer, farther_a, farther_b])
	var engine: CombatEngine = fixture["engine"] as CombatEngine
	_set_positions(engine, [Vector2(64.0, 128.0)], [Vector2(192.0, 256.0), Vector2(320.0, 96.0), Vector2(448.0, 160.0)])
	var cast_result: Dictionary = engine.ability_system.try_cast("player", 0)
	_expect(bool(cast_result.get("cast", false)), "Teller Margin Call did not cast through the public cast boundary", failures)
	_expect(int(nearer.hp) == int(nearer.max_hp), "Teller Margin Call fired at a nearer enemy instead of its two furthest targets", failures)
	_expect(int(farther_a.hp) < int(farther_a.max_hp) and int(farther_b.hp) < int(farther_b.max_hp), "Teller Margin Call did not fire down both furthest-enemy shot paths", failures)
	_expect(int(teller.mana) == 0, "Teller Margin Call successful cast did not spend its full mana cost", failures)
	_teardown_fixture(engine)

func _check_velour_self_exclusion(failures: Array[String]) -> void:
	var velour: Unit = _make_unit("velour", 1000)
	velour.ability_id = "velour_silk_knot"
	velour.mana_max = 60
	velour.mana = 60
	velour.hp = 100
	var first_ally: Unit = _make_unit("first_ally", 1000)
	first_ally.hp = 200
	var enemy: Unit = _make_unit("velour_enemy", 3000)
	var fixture: Dictionary = _make_fixture([velour, first_ally], [enemy])
	var state: BattleState = fixture["state"] as BattleState
	var engine: CombatEngine = fixture["engine"] as CombatEngine
	var cast_result: Dictionary = engine.ability_system.try_cast("player", 0)
	_expect(bool(cast_result.get("cast", false)), "Velour Silk Knot did not cast through the public cast boundary", failures)
	_expect(int(velour.hp) == 225, "Velour Silk Knot must heal the lowest-Health ally, including its caster", failures)
	_expect(int(first_ally.hp) == 200, "Velour Silk Knot healed a healthier ally instead of the lowest-Health ally", failures)
	_expect(engine.buff_system.has_tag(state, "enemy", 0, "root"), "Velour Silk Knot did not root the nearest threat", failures)
	_expect(int(velour.mana) == 0, "Velour Silk Knot successful cast did not spend its full mana cost", failures)
	_teardown_fixture(engine)

func _check_vesper_readable_delay(failures: Array[String]) -> void:
	var vesper: Unit = _make_unit("vesper", 1800)
	vesper.ability_id = "vesper_late_fee"
	vesper.mana_max = 30
	vesper.mana = 30
	var enemy: Unit = _make_unit("vesper_target", 4000)
	enemy.hp = 1000
	var fixture: Dictionary = _make_fixture([vesper], [enemy])
	var engine: CombatEngine = fixture["engine"] as CombatEngine
	var hp_before: int = int(enemy.hp)
	var position_before: Vector2 = engine.get_player_position(0)
	var cast_result: Dictionary = engine.ability_system.try_cast("player", 0)
	_expect(bool(cast_result.get("cast", false)), "Vesper Late Fee did not cast through the public cast boundary", failures)
	_expect(int(enemy.hp) == hp_before, "Vesper dealt damage before its readable delay", failures)
	_expect(engine.get_player_position(0).is_equal_approx(position_before), "Vesper blinked before its readable one-second delay", failures)
	var queued: Array[Dictionary] = _scheduled_events(engine)
	_expect(queued.size() == 1, "Vesper readable delay did not remain owned by the combat event queue", failures)
	engine.ability_system.tick(1.05)
	_expect(not enemy.is_alive(), "Vesper Late Fee did not execute a target already below 30% Health", failures)
	_expect(not engine.get_player_position(0).is_equal_approx(position_before), "Vesper did not blink and retreat after its delayed execute", failures)
	_expect(int(vesper.mana) == 0, "Vesper Late Fee successful cast did not spend its full mana cost", failures)
	_teardown_fixture(engine)
	var remaining: Array[Dictionary] = _scheduled_events(engine)
	_expect(remaining.is_empty(), "AbilitySystem teardown did not cancel queued implementation callbacks", failures)

	var cancel_vesper: Unit = _make_unit("vesper_cancel", 1800)
	cancel_vesper.ability_id = "vesper_late_fee"
	cancel_vesper.mana_max = 30
	cancel_vesper.mana = 30
	var cancel_enemy: Unit = _make_unit("vesper_cancel_target", 4000)
	cancel_enemy.hp = 1000
	var cancel_fixture: Dictionary = _make_fixture([cancel_vesper], [cancel_enemy])
	var cancel_engine: CombatEngine = cancel_fixture["engine"] as CombatEngine
	var cancel_hp_before: int = int(cancel_enemy.hp)
	var cancel_cast: Dictionary = cancel_engine.ability_system.try_cast("player", 0)
	_expect(bool(cancel_cast.get("cast", false)), "Vesper cancellation fixture did not queue its delayed callback", failures)
	cancel_engine.ability_system.teardown()
	cancel_engine.ability_system.tick(1.1)
	var cancelled: Array[Dictionary] = _scheduled_events(cancel_engine)
	_expect(cancelled.is_empty() and int(cancel_enemy.hp) == cancel_hp_before, "AbilitySystem teardown must cancel a pending implementation callback before it can mutate combat", failures)

func _on_debuff_applied(source_team: String, source_index: int, target_team: String, target_index: int, kind: String, fields: Dictionary, magnitude: float, duration: float) -> void:
	_debuff_events.append({
		"source_team": source_team,
		"source_index": source_index,
		"target_team": target_team,
		"target_index": target_index,
		"kind": kind,
		"fields": fields.duplicate(true),
		"magnitude": magnitude,
		"duration": duration
	})

func _find_debuff_event(kind: String) -> Dictionary:
	for event: Dictionary in _debuff_events:
		if String(event.get("kind", "")) == kind:
			return event
	return {}

func _count_debuff_events(kind: String) -> int:
	var count: int = 0
	for event: Dictionary in _debuff_events:
		if String(event.get("kind", "")) == kind:
			count += 1
	return count

func _count_attack_speed_slow_events(expected_delta: float) -> int:
	var count: int = 0
	for event: Dictionary in _debuff_events:
		var fields: Dictionary = event.get("fields", {}) if event.get("fields", {}) is Dictionary else {}
		if fields.has("attack_speed") and is_equal_approx(float(fields.get("attack_speed", 0.0)), expected_delta):
			count += 1
	return count

func _make_fixture(player_units: Array[Unit], enemy_units: Array[Unit]) -> Dictionary:
	var state: BattleState = BattleStateScript.new()
	state.player_team = player_units
	state.enemy_team = enemy_units
	state.player_cds = _float_zeros(player_units.size())
	state.enemy_cds = _float_zeros(enemy_units.size())
	state.player_targets = _target_zeros(player_units.size())
	state.enemy_targets = _target_zeros(enemy_units.size())
	state.player_damage_this_round = _int_zeros(player_units.size())
	state.enemy_damage_this_round = _int_zeros(enemy_units.size())
	state.player_pupil_map = _negative_ones(player_units.size())
	state.enemy_pupil_map = _negative_ones(enemy_units.size())
	var engine: CombatEngine = CombatEngineScript.new()
	engine.abilities_enabled = true
	engine.emit_auto_attack_logs = false
	engine.emit_ability_logs = false
	engine.configure(state, player_units[0], 1, Callable())
	engine.start()
	state.player_targets = _target_zeros(player_units.size())
	state.enemy_targets = _target_zeros(enemy_units.size())
	var player_positions: Array[Vector2] = []
	for player_index: int in range(player_units.size()):
		player_positions.append(Vector2(64.0, 96.0 + float(player_index) * 64.0))
	var enemy_positions: Array[Vector2] = []
	for enemy_index: int in range(enemy_units.size()):
		enemy_positions.append(Vector2(320.0, 96.0 + float(enemy_index) * 64.0))
	_set_positions(engine, player_positions, enemy_positions)
	return {"state": state, "engine": engine}

func _context(engine: CombatEngine, state: BattleState) -> AbilityContext:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 73013
	var ctx: AbilityContext = AbilityContext.new(engine, state, rng, "player", 0)
	ctx.buff_system = engine.buff_system
	return ctx

func _scheduled_events(engine: CombatEngine) -> Array[Dictionary]:
	var output: Array[Dictionary] = []
	if engine == null or engine.ability_system == null:
		return output
	var events_value: Variant = engine.ability_system.get("_events")
	if not (events_value is Array):
		return output
	for event_value: Variant in events_value:
		if event_value is Dictionary:
			output.append(event_value as Dictionary)
	return output

func _cast_success(engine: CombatEngine) -> bool:
	if engine == null or engine.ability_system == null:
		return false
	var result: Dictionary = engine.ability_system.try_cast("player", 0)
	return bool(result.get("cast", false))

func _make_unit(unit_id: String, max_hp: int) -> Unit:
	var unit: Unit = Unit.new()
	unit.id = unit_id
	unit.name = unit_id
	unit.level = 1
	unit.cost = 1
	unit.max_hp = max_hp
	unit.hp = max_hp
	unit.attack_damage = 100.0
	unit.spell_power = 0.0
	unit.attack_speed = 1.0
	unit.attack_range = 4
	unit.armor = 0.0
	unit.magic_resist = 0.0
	unit.damage_reduction = 0.0
	unit.damage_reduction_flat = 0.0
	return unit

func _set_positions(engine: CombatEngine, player_positions: Array[Vector2], enemy_positions: Array[Vector2]) -> void:
	if engine == null or engine.arena_state == null or engine.arena_state.data == null:
		return
	for index: int in range(min(player_positions.size(), engine.arena_state.data.player_positions.size())):
		engine.arena_state.data.player_positions[index] = player_positions[index]
	for index: int in range(min(enemy_positions.size(), engine.arena_state.data.enemy_positions.size())):
		engine.arena_state.data.enemy_positions[index] = enemy_positions[index]

func _float_zeros(count: int) -> Array[float]:
	var output: Array[float] = []
	for _index: int in range(count):
		output.append(0.0)
	return output

func _int_zeros(count: int) -> Array[int]:
	var output: Array[int] = []
	for _index: int in range(count):
		output.append(0)
	return output

func _target_zeros(count: int) -> Array[int]:
	var output: Array[int] = []
	for _index: int in range(count):
		output.append(0)
	return output

func _negative_ones(count: int) -> Array[int]:
	var output: Array[int] = []
	for _index: int in range(count):
		output.append(-1)
	return output

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
