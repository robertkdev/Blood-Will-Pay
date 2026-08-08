extends Node

const CombatEngineScript := preload("res://scripts/game/combat/combat_engine.gd")
const BattleStateScript := preload("res://scripts/game/combat/battle_state.gd")
const UnitFactoryScript := preload("res://scripts/unit_factory.gd")
const ManaScript := preload("res://scripts/game/stats/mana.gd")
const BuffTags := preload("res://scripts/game/abilities/buff_tags.gd")
const RepoWritOfSeverance := preload("res://scripts/game/abilities/impls/repo_writ_of_severance.gd")
const NoxleyRedStatic := preload("res://scripts/game/abilities/impls/noxley_red_static.gd")
const QuillithFinalExam := preload("res://scripts/game/abilities/impls/quillith_final_exam.gd")
const CreepEavesdropping := preload("res://scripts/game/abilities/impls/creep_eavesdropping.gd")
const GableMarketCorner := preload("res://scripts/game/abilities/impls/gable_market_corner.gd")
const OmenryCondemningShot := preload("res://scripts/game/abilities/impls/omenry_condemning_shot.gd")
const KettUnionBreaker := preload("res://scripts/game/abilities/impls/kett_union_breaker.gd")
const TellerMarginCall := preload("res://scripts/game/abilities/impls/teller_margin_call.gd")
const VelourSilkKnot := preload("res://scripts/game/abilities/impls/velour_silk_knot.gd")
const VesperLateFee := preload("res://scripts/game/abilities/impls/vesper_late_fee.gd")

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
	_check_teller_overflow(failures)
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
		_expect(int(ability_def.base_cost) == 60, "Repo ability cost must be 60 for mana liveness", failures)

	var repo: Unit = _make_unit("repo", 1800)
	repo.spell_power = 0.0
	var enemy: Unit = _make_unit("repo_target", 5000)
	var fixture: Dictionary = _make_fixture([repo], [enemy])
	var state: BattleState = fixture["state"] as BattleState
	var engine: CombatEngine = fixture["engine"] as CombatEngine
	var ctx: AbilityContext = _context(engine, state)
	repo.hp = 1200
	var hp_before: int = int(repo.hp)
	var ability: Variant = RepoWritOfSeverance.new()
	var cast_ok: bool = bool(ability.call("cast", ctx))
	_expect(cast_ok, "Repo flat-heal fixture did not cast", failures)
	_expect(int(repo.hp) - hp_before == 90, "Repo level-1 cast with zero SP must heal its 90 flat base", failures)
	_teardown_fixture(engine)

func _check_noxley_health_cost_and_dot_telemetry(failures: Array[String]) -> void:
	var ability_def: AbilityDef = load("res://data/abilities/noxley_red_static.tres") as AbilityDef
	_expect(ability_def != null, "Noxley ability definition did not load", failures)
	if ability_def != null:
		_expect(int(ability_def.base_cost) == 50, "Noxley recurring mana cap must remain 50", failures)
		_expect(int(ability_def.starting_mana_bonus) == 20, "Noxley must open with its 20-mana cost reduction", failures)

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
	var telemetry_state: BattleState = telemetry_fixture["state"] as BattleState
	var telemetry_engine: CombatEngine = telemetry_fixture["engine"] as CombatEngine
	_expect(int(telemetry_noxley.mana) == 20, "Noxley's opening 20-mana reduction was not applied", failures)
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
	var scheduled_events_value: Variant = telemetry_engine.ability_system.get("_events")
	var scheduled_events: Array = scheduled_events_value if scheduled_events_value is Array else []
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
		_expect(int(telemetry_enemy.hp) < hp_before_dead_source_tick, "Noxley delayed static stopped when its source died", failures)
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
	_expect(int(ability_def.starting_mana_bonus) == 55, "Quorra must open with a full Timeplate Lunge", failures)

	var quorra: Unit = UnitFactoryScript.spawn("quorra")
	_expect(quorra != null, "Quorra opener fixture failed to spawn Quorra", failures)
	if quorra == null:
		return
	quorra.mana = 0
	var enemy: Unit = _make_unit("quorra_target", 5000)
	enemy.attack_speed = 1.0
	var fixture: Dictionary = _make_fixture([quorra], [enemy])
	var engine: CombatEngine = fixture["engine"] as CombatEngine
	_expect(int(quorra.mana) == 55, "Quorra starting mana did not produce an immediate opener", failures)
	_debuff_events.clear()
	engine.debuff_applied.connect(_on_debuff_applied)
	var cast_result: Dictionary = engine.ability_system.try_cast("player", 0)
	_expect(bool(cast_result.get("cast", false)), "Quorra full-mana opening Lunge did not cast", failures)
	_expect(int(quorra.mana) == 0, "Quorra opening Lunge did not spend its recurring mana cost", failures)
	_expect(is_equal_approx(float(enemy.attack_speed), 0.76), "Quorra opening Lunge did not apply its -0.24 attack-speed slow", failures)
	var quorra_slow_events: int = _count_attack_speed_slow_events(-0.24)
	_expect(quorra_slow_events == 1, "Quorra opening Lunge did not emit exactly one slow application (got %d; events=%s)" % [quorra_slow_events, JSON.stringify(_debuff_events)], failures)
	var scheduled_events_value: Variant = engine.ability_system.get("_events")
	var scheduled_events: Array = scheduled_events_value if scheduled_events_value is Array else []
	_expect(scheduled_events.size() == 1, "Quorra opening Lunge did not schedule exactly one wound sequence", failures)
	if scheduled_events.size() == 1:
		var scheduled_event: Dictionary = scheduled_events[0] as Dictionary
		var scheduled_data: Dictionary = scheduled_event.get("data", {}) if scheduled_event.get("data", {}) is Dictionary else {}
		_expect(not scheduled_data.has("debuff_fields"), "Quorra wound ticks would repeatedly extend the cast-time slow", failures)
	if engine.debuff_applied.is_connected(Callable(self, "_on_debuff_applied")):
		engine.debuff_applied.disconnect(_on_debuff_applied)
	_teardown_fixture(engine)

func _check_ivara_opening_mana_and_cadence(failures: Array[String]) -> void:
	var ability_def: AbilityDef = load("res://data/abilities/ivara_open_bid.tres") as AbilityDef
	_expect(ability_def != null, "Ivara ability definition did not load", failures)
	if ability_def == null:
		return
	_expect(int(ability_def.base_cost) == 55, "Ivara recurring cast cost must remain 55", failures)
	_expect(int(ability_def.starting_mana_bonus) == 20, "Ivara opener must grant exactly 20 starting mana", failures)

	var ivara: Unit = UnitFactoryScript.spawn("ivara")
	_expect(ivara != null, "Ivara opener fixture failed to spawn Ivara", failures)
	if ivara == null:
		return
	ivara.mana = 0
	var enemy: Unit = _make_unit("ivara_target", 50000)
	enemy.attack_damage = 0.0
	enemy.attack_speed = 0.01
	var fixture: Dictionary = _make_fixture([ivara], [enemy])
	var state: BattleState = fixture["state"] as BattleState
	var engine: CombatEngine = fixture["engine"] as CombatEngine
	engine.set_arena(
		100.0,
		[Vector2(100.0, 250.0)],
		[Vector2(200.0, 250.0)],
		Rect2(Vector2.ZERO, Vector2(800.0, 600.0)))

	_expect(int(ivara.mana) == 20, "Ivara starting mana bonus was not applied exactly once", failures)
	_expect(int(ivara.mana_start) == 0, "Ivara ability bonus must not mutate persistent mana_start", failures)

	var first_cc: Dictionary[String, float] = {"time": -1.0}
	var cc_callback: Callable = _record_ivara_first_cc.bind(state, first_cc)
	engine.cc_applied.connect(cc_callback)
	for _attack_index: int in range(4):
		ManaScript.gain_on_attack(state, "player", 0, ivara, engine.ability_system, engine.buff_system)
	if engine.cc_applied.is_connected(cc_callback):
		engine.cc_applied.disconnect(cc_callback)
	_expect(float(first_cc["time"]) >= 0.0, "Ivara's 20 opening mana did not produce a stun on its fourth attack", failures)
	var four_attack_cadence_s: float = 4.0 / max(0.01, float(ivara.attack_speed))
	_expect(four_attack_cadence_s <= 6.0,
		"Ivara's four-attack opening cadence exceeds 6s (%.2fs)" % four_attack_cadence_s, failures)

	ivara.mana = 54
	var short_cast: Dictionary = engine.ability_system.try_cast("player", 0)
	_expect(not bool(short_cast.get("cast", false)) and String(short_cast.get("reason", "")) == "not_enough_mana",
		"Ivara later cast must still reject 54 mana", failures)
	ivara.mana = 55
	var full_cast: Dictionary = engine.ability_system.try_cast("player", 0)
	_expect(bool(full_cast.get("cast", false)), "Ivara later cast must succeed at 55 mana", failures)
	_expect(int(ivara.mana) == 0, "Ivara later 55-mana cast did not spend its full cadence cost", failures)
	_teardown_fixture(engine)

	var capped_ivara: Unit = UnitFactoryScript.spawn("ivara")
	_expect(capped_ivara != null, "Ivara capped-opener fixture failed to spawn Ivara", failures)
	if capped_ivara == null:
		return
	capped_ivara.mana = 50
	var cap_enemy: Unit = _make_unit("ivara_cap_target", 50000)
	var cap_fixture: Dictionary = _make_fixture([capped_ivara], [cap_enemy])
	var cap_engine: CombatEngine = cap_fixture["engine"] as CombatEngine
	_expect(int(capped_ivara.mana) == 55, "Ivara starting mana bonus must cap at mana_max", failures)
	_teardown_fixture(cap_engine)

func _record_ivara_first_cc(
		source_team: String,
		source_index: int,
		_target_team: String,
		_target_index: int,
		kind: String,
		_duration: float,
		state: BattleState,
		first_cc: Dictionary[String, float]) -> void:
	if source_team != "player" or source_index != 0 or kind != "stun":
		return
	if float(first_cc.get("time", -1.0)) >= 0.0:
		return
	first_cc["time"] = float(state.elapsed_time)

func _check_quillith_solo_and_team_mana(failures: Array[String]) -> void:
	var solo_quillith: Unit = _make_unit("quillith", 1800)
	solo_quillith.spell_power = 0.0
	var solo_enemy: Unit = _make_unit("solo_enemy", 3000)
	var solo_fixture: Dictionary = _make_fixture([solo_quillith], [solo_enemy])
	var solo_state: BattleState = solo_fixture["state"] as BattleState
	var solo_engine: CombatEngine = solo_fixture["engine"] as CombatEngine
	var solo_ctx: AbilityContext = _context(solo_engine, solo_state)
	var solo_before_hp: int = int(solo_enemy.hp)
	var solo_ability: Variant = QuillithFinalExam.new()
	var solo_cast: bool = bool(solo_ability.call("cast", solo_ctx))
	_expect(solo_cast, "Quillith must cast its enemy recast when no pupil exists", failures)
	_expect(int(solo_enemy.hp) < solo_before_hp, "Quillith solo recast dealt no damage", failures)
	_expect(int(solo_quillith.ui_shield) == 0, "Quillith must not self-pupil in the solo fallback", failures)
	_teardown_fixture(solo_engine)

	var team_quillith: Unit = _make_unit("quillith", 1800)
	var pupil: Unit = _make_unit("pupil", 1800)
	pupil.attack_damage = 220.0
	pupil.mana_max = 100
	pupil.mana = 0
	var bystander: Unit = _make_unit("bystander", 1800)
	bystander.attack_damage = 20.0
	bystander.mana_max = 100
	bystander.mana = 0
	var team_enemy: Unit = _make_unit("team_enemy", 4000)
	var team_fixture: Dictionary = _make_fixture([team_quillith, pupil, bystander], [team_enemy])
	var team_state: BattleState = team_fixture["state"] as BattleState
	var team_engine: CombatEngine = team_fixture["engine"] as CombatEngine
	var team_ctx: AbilityContext = _context(team_engine, team_state)
	var team_ability: Variant = QuillithFinalExam.new()
	var team_cast: bool = bool(team_ability.call("cast", team_ctx))
	_expect(team_cast, "Quillith team cast failed", failures)
	_expect(int(pupil.mana) == 18, "Quillith pupil should receive the full 18 mana at level 1", failures)
	_expect(int(bystander.mana) == 9, "Quillith non-pupil should receive half mana", failures)
	_teardown_fixture(team_engine)

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
	totem_engine.ability_system.call("_autocast_totem_if_needed", "player", 0)
	_expect(int(carry.ui_shield) == 0, "Totem autocast activated on a two-Exile board", failures)
	totem_engine.buff_system.apply_tag(totem_state, "player", 0, BuffTags.TAG_EXILE_UPGRADE, 9999.0, {"level": 1})
	totem_engine.ability_system.call("_autocast_totem_if_needed", "player", 0)
	_expect(int(carry.ui_shield) > 0, "Totem autocast ignored the active Exile upgrade tag", failures)
	_teardown_fixture(totem_engine)

func _check_gable_vulnerability(failures: Array[String]) -> void:
	var gable: Unit = _make_unit("gable", 2200)
	var first: Unit = _make_unit("first", 5000)
	var second: Unit = _make_unit("second", 5000)
	var third: Unit = _make_unit("third", 6000)
	first.armor = 40.0
	first.magic_resist = 40.0
	second.armor = 40.0
	second.magic_resist = 40.0
	third.armor = 40.0
	third.magic_resist = 40.0
	var fixture: Dictionary = _make_fixture([gable], [first, second, third])
	var state: BattleState = fixture["state"] as BattleState
	var engine: CombatEngine = fixture["engine"] as CombatEngine
	_set_positions(engine, [Vector2(64.0, 128.0)], [Vector2(256.0, 128.0), Vector2(320.0, 128.0), Vector2(384.0, 128.0)])
	var ctx: AbilityContext = _context(engine, state)
	var ability: Variant = GableMarketCorner.new()
	var cast_ok: bool = bool(ability.call("cast", ctx))
	_expect(cast_ok, "Gable vulnerability fixture did not cast", failures)
	_expect(int(gable.attack_range) == 6, "Gable Market Corner did not preserve its long-range uptime buff", failures)
	_expect(is_equal_approx(float(third.armor), 28.0), "Gable third rotation did not reduce Armor by 12", failures)
	_expect(is_equal_approx(float(third.magic_resist), 28.0), "Gable third rotation did not reduce Magic Resist by 12", failures)
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
	_teardown_fixture(engine)

func _check_kett_stacking_debuff(failures: Array[String]) -> void:
	var kett: Unit = _make_unit("kett", 2200)
	var target: Unit = _make_unit("kett_target", 10000)
	target.armor = 100.0
	target.attack_speed = 1.0
	var fixture: Dictionary = _make_fixture([kett], [target])
	var state: BattleState = fixture["state"] as BattleState
	var engine: CombatEngine = fixture["engine"] as CombatEngine
	var ctx: AbilityContext = _context(engine, state)
	var ability: Variant = KettUnionBreaker.new()
	var cast_ok: bool = bool(ability.call("cast", ctx))
	_expect(cast_ok, "Kett stacking fixture did not cast", failures)
	_expect(is_equal_approx(float(target.armor), 70.0), "Kett should apply three -10 Armor debuffs", failures)
	_expect(is_equal_approx(float(target.attack_speed), 0.85), "Kett should apply three -0.05 attack-speed debuffs", failures)
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

func _check_teller_overflow(failures: Array[String]) -> void:
	var ability: Variant = TellerMarginCall.new()
	var nonlethal: Dictionary = {"dealt": 200, "before_hp": 500, "before_cap": 350, "after_hp": 300}
	var lethal: Dictionary = {"dealt": 100, "before_hp": 100, "before_cap": 350, "after_hp": 0}
	var mitigated_lethal: Dictionary = {"dealt": 100, "before_hp": 100, "before_cap": 100, "after_hp": 0}
	_expect(int(ability.call("_overflow_damage", nonlethal, false)) == 0, "Teller overflowed from a surviving target", failures)
	_expect(int(ability.call("_overflow_damage", lethal, true)) == 250, "Teller did not preserve actual lethal HP overkill", failures)
	_expect(int(ability.call("_overflow_damage", mitigated_lethal, true)) == 0, "Teller treated mitigation loss as overflow", failures)

func _check_velour_self_exclusion(failures: Array[String]) -> void:
	var velour: Unit = _make_unit("velour", 1000)
	velour.hp = 100
	var first_ally: Unit = _make_unit("first_ally", 1000)
	first_ally.hp = 200
	var second_ally: Unit = _make_unit("second_ally", 1000)
	second_ally.hp = 300
	var enemy: Unit = _make_unit("velour_enemy", 3000)
	var fixture: Dictionary = _make_fixture([velour, first_ally, second_ally], [enemy])
	var state: BattleState = fixture["state"] as BattleState
	var engine: CombatEngine = fixture["engine"] as CombatEngine
	var ctx: AbilityContext = _context(engine, state)
	var ability: Variant = VelourSilkKnot.new()
	var selected_value: Variant = ability.call("_two_lowest_allies", ctx)
	var selected: Array[int] = []
	if selected_value is Array:
		for raw_index: Variant in selected_value:
			selected.append(int(raw_index))
	_expect(not selected.has(0), "Velour included self in allied protect targets", failures)
	_expect(selected.has(1) and selected.has(2), "Velour did not select the two lowest non-self allies", failures)
	_teardown_fixture(engine)

func _check_vesper_readable_delay(failures: Array[String]) -> void:
	var vesper: Unit = _make_unit("vesper", 1800)
	vesper.cost = 4
	var enemy: Unit = _make_unit("vesper_target", 4000)
	var fixture: Dictionary = _make_fixture([vesper], [enemy])
	var state: BattleState = fixture["state"] as BattleState
	var engine: CombatEngine = fixture["engine"] as CombatEngine
	var ctx: AbilityContext = _context(engine, state)
	var ability: Variant = VesperLateFee.new()
	var hp_before: int = int(enemy.hp)
	var position_before: Vector2 = ctx.position_of("player", 0)
	var cast_ok: bool = bool(ability.call("cast", ctx))
	_expect(cast_ok, "Vesper delayed cast did not commit", failures)
	_expect(int(enemy.hp) == hp_before, "Vesper dealt damage before its readable delay", failures)
	_expect(ctx.position_of("player", 0).is_equal_approx(position_before), "Vesper blinked before its readable delay", failures)
	engine.ability_system.tick(0.30)
	_expect(int(enemy.hp) == hp_before, "Vesper resolved before the full delay elapsed", failures)
	engine.ability_system.tick(0.10)
	_expect(int(enemy.hp) < hp_before, "Vesper delayed collection dealt no damage", failures)
	_expect(not ctx.position_of("player", 0).is_equal_approx(position_before), "Vesper did not blink when the delayed collection resolved", failures)
	_teardown_fixture(engine)

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
