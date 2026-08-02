extends Node

const CounterOutcomeGauntlet := preload("res://tests/rga_testing/validation/counter_outcome_gauntlet.gd")
const CombatEngineScript := preload("res://scripts/game/combat/combat_engine.gd")
const BattleStateScript := preload("res://scripts/game/combat/battle_state.gd")
const UnitFactory := preload("res://scripts/unit_factory.gd")
const TotemCleanse := preload("res://scripts/game/abilities/impls/totem_cleanse.gd")
const MiriLessonPlan := preload("res://scripts/game/abilities/impls/miri_lesson_plan.gd")

const CASE_ID: String = "peel_vs_backline_access"
const PROTECTED_INDEX: int = 1
const SUPPORT_INDEX: int = 2

@export var do_quit_on_finish: bool = true

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	var peel_case: Dictionary[String, Variant] = _peel_case()
	_expect(not peel_case.is_empty(), "Peel counter fixture is missing", failures)
	if not peel_case.is_empty():
		_check_fixture_contract(peel_case, failures)
	if not failures.is_empty():
		for failure: String in failures:
			push_error(failure)
		_finish(1)
		return
	print("PeelCounterFixtureContractProbe: PASS")
	_finish(0)

func _check_fixture_contract(peel_case: Dictionary[String, Variant], failures: Array[String]) -> void:
	var counter_ids: Array[String] = _string_array(peel_case.get("counter_team", []))
	var baseline_ids: Array[String] = _string_array(peel_case.get("baseline_team", []))
	var protected_index: int = int(peel_case.get("protected_index", -1))
	var baseline_protected_index: int = int(peel_case.get("baseline_protected_index", -1))
	var counter_units: Array[Unit] = _spawn_team(counter_ids, "counter", failures)
	var baseline_units: Array[Unit] = _spawn_team(baseline_ids, "baseline", failures)

	_expect(bool(peel_case.get("require_slot_role_cost_match", false)), "Peel fixture must require role-and-slot-cost parity", failures)
	_expect(counter_ids.size() == baseline_ids.size(), "Peel fixture team sizes differ", failures)
	_expect(protected_index == PROTECTED_INDEX and baseline_protected_index == PROTECTED_INDEX, "Peel fixture must compare the same protected slot", failures)
	if counter_ids.size() > PROTECTED_INDEX and baseline_ids.size() > PROTECTED_INDEX:
		_expect(counter_ids[PROTECTED_INDEX] == "sari" and baseline_ids[PROTECTED_INDEX] == "sari", "Peel fixture must protect Sari in both variants", failures)

	var comparable_slots: int = min(counter_units.size(), baseline_units.size())
	for index: int in range(comparable_slots):
		var counter_unit: Unit = counter_units[index]
		var baseline_unit: Unit = baseline_units[index]
		if counter_unit == null or baseline_unit == null:
			continue
		_expect(int(counter_unit.cost) == int(baseline_unit.cost), "Peel fixture slot %d cost mismatch: %s=%d vs %s=%d" % [index, counter_unit.id, counter_unit.cost, baseline_unit.id, baseline_unit.cost], failures)
		var counter_role: String = String(counter_unit.get_primary_role()).strip_edges().to_lower()
		var baseline_role: String = String(baseline_unit.get_primary_role()).strip_edges().to_lower()
		_expect(counter_role == baseline_role, "Peel fixture slot %d role mismatch: %s=%s vs %s=%s" % [index, counter_unit.id, counter_role, baseline_unit.id, baseline_role], failures)

	if counter_units.size() <= SUPPORT_INDEX or baseline_units.size() <= SUPPORT_INDEX:
		failures.append("Peel fixture is missing its cost-2 support comparison slot")
		return
	var counter_support: Unit = counter_units[SUPPORT_INDEX]
	var baseline_support: Unit = baseline_units[SUPPORT_INDEX]
	if counter_support == null or baseline_support == null:
		failures.append("Peel fixture support comparison slot did not spawn")
		return
	_expect(String(counter_support.id) == "totem", "Peel counter slot must contain Totem", failures)
	_expect(String(baseline_support.id) == "miri", "Peel baseline slot must contain Miri", failures)

	var counter_state: BattleState = _state_for(counter_units)
	var totem_ability: Variant = TotemCleanse.new()
	var peel_target: int = int(totem_ability.call("_best_peel_target", counter_state, "player", SUPPORT_INDEX))
	_expect(peel_target == PROTECTED_INDEX, "Totem fixture target must be protected Sari, got index %d" % peel_target, failures)

	var baseline_state: BattleState = _state_for(baseline_units)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 5401
	var engine: CombatEngine = CombatEngineScript.new()
	var miri_context: AbilityContext = AbilityContext.new(engine, baseline_state, rng, "player", SUPPORT_INDEX)
	var miri_ability: Variant = MiriLessonPlan.new()
	var lesson_target: int = int(miri_ability.call("_student_for", miri_context, baseline_support))
	_expect(lesson_target == 0, "Miri baseline must invest Lesson Plan in Brute instead of protected Sari, got index %d" % lesson_target, failures)

func _peel_case() -> Dictionary[String, Variant]:
	var output: Dictionary[String, Variant] = {}
	var gauntlet: Node = CounterOutcomeGauntlet.new()
	var raw_cases: Variant = gauntlet.call("_cases")
	if raw_cases is Array:
		for raw_case: Variant in raw_cases:
			if not (raw_case is Dictionary):
				continue
			var case_data: Dictionary[String, Variant] = {}
			for raw_key: Variant in (raw_case as Dictionary).keys():
				case_data[String(raw_key)] = (raw_case as Dictionary).get(raw_key)
			if String(case_data.get("id", "")) != CASE_ID:
				continue
			for case_key: String in case_data:
				output[case_key] = case_data[case_key]
			break
	gauntlet.free()
	return output

func _spawn_team(unit_ids: Array[String], variant_id: String, failures: Array[String]) -> Array[Unit]:
	var output: Array[Unit] = []
	for unit_id: String in unit_ids:
		var unit: Unit = UnitFactory.spawn(unit_id)
		if unit == null:
			failures.append("Peel %s fixture could not spawn %s" % [variant_id, unit_id])
		output.append(unit)
	return output

func _state_for(units: Array[Unit]) -> BattleState:
	var state: BattleState = BattleStateScript.new()
	state.player_team = units.duplicate()
	state.enemy_team = []
	state.player_cds = _float_zeros(units.size())
	state.enemy_cds = []
	state.player_targets = _int_zeros(units.size())
	state.enemy_targets = []
	state.player_damage_this_round = _int_zeros(units.size())
	state.enemy_damage_this_round = []
	state.player_pupil_map = _negative_ones(units.size())
	state.enemy_pupil_map = []
	return state

func _string_array(value: Variant) -> Array[String]:
	var output: Array[String] = []
	if value is Array:
		for raw_item: Variant in value:
			output.append(String(raw_item))
	return output

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

func _negative_ones(count: int) -> Array[int]:
	var output: Array[int] = []
	for _index: int in range(count):
		output.append(-1)
	return output

func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)

func _finish(code: int) -> void:
	if do_quit_on_finish:
		get_tree().quit(code)
