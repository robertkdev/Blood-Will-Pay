extends Node

const UnitCatalogScript := preload("res://scripts/game/shop/unit_catalog.gd")
const UnitFactoryScript := preload("res://scripts/unit_factory.gd")
const AttackVisualCatalogScript := preload("res://scripts/ui/combat/attack_visual_catalog.gd")

const CONTRACT_PATH: String = "res://tests/design/unit_ability_quality_contract_v1.json"
const SCORE_FIELDS: Array[String] = [
	"cohesion",
	"uniqueness",
	"team_utility",
	"player_clarity",
	"visual_satisfaction",
	"counterplay",
	"cost_fit",
]
const EFFECT_FAMILIES: Array[String] = [
	"damage",
	"movement",
	"hard_cc",
	"ally_defense",
	"self_defense",
	"sustain",
	"offensive_buff",
	"enemy_debuff",
	"resource",
	"execute_reset",
	"economy",
	"zone",
]
const VERDICTS: Array[String] = ["keep", "simplify", "redesign"]
const MAX_PLAYER_WORDS: int = 28

func _ready() -> void:
	var failures: Array[String] = _validate_contract()
	if failures.is_empty():
		print("AbilityDesignContractSmoke: PASS units=51 schema=1")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("AbilityDesignContractSmoke: " + failure)
	get_tree().quit(1)

func _validate_contract() -> Array[String]:
	var failures: Array[String] = []
	var root: Dictionary = _read_contract(failures)
	if root.is_empty():
		return failures
	if int(root.get("schema_version", 0)) != 1:
		failures.append("schema_version must be 1")
	var budgets: Dictionary = root.get("effect_family_budgets", {}) as Dictionary
	for cost: int in range(1, 6):
		if int(budgets.get(str(cost), 0)) <= 0:
			failures.append("missing positive effect-family budget for cost %d" % cost)
	var entries_value: Variant = root.get("units", [])
	if not entries_value is Array:
		failures.append("units must be an array")
		return failures
	var entries: Array = entries_value as Array
	var catalog: UnitCatalog = UnitCatalogScript.new()
	catalog.refresh()
	var expected_ids: Array[String] = _playable_ids(catalog)
	var seen: Dictionary[String, bool] = {}
	var seen_test_ids: Dictionary[String, bool] = {}
	var signature_shapes: Dictionary[String, bool] = {}
	for entry_value: Variant in entries:
		if not entry_value is Dictionary:
			failures.append("unit entry must be an object")
			continue
		var entry: Dictionary = entry_value as Dictionary
		var unit_id: String = String(entry.get("unit_id", "")).strip_edges()
		if unit_id == "":
			failures.append("unit entry is missing unit_id")
			continue
		if seen.has(unit_id):
			failures.append("duplicate unit entry %s" % unit_id)
			continue
		seen[unit_id] = true
		_validate_entry(entry, unit_id, catalog, budgets, seen_test_ids, failures)
		_validate_visual_signature(unit_id, signature_shapes, failures)
	for expected_id: String in expected_ids:
		if not seen.has(expected_id):
			failures.append("missing playable unit %s" % expected_id)
	for seen_id: String in seen.keys():
		if not expected_ids.has(seen_id):
			failures.append("unexpected or non-playable unit %s" % seen_id)
	if entries.size() != expected_ids.size():
		failures.append("contract count %d does not match playable roster %d" % [entries.size(), expected_ids.size()])
	if signature_shapes.size() < 20:
		failures.append("playable roster needs at least 20 distinct visual motifs, got %d" % signature_shapes.size())
	return failures

func _validate_visual_signature(unit_id: String, signature_shapes: Dictionary[String, bool], failures: Array[String]) -> void:
	var unit: Unit = UnitFactoryScript.spawn(unit_id)
	if unit == null:
		failures.append("%s could not spawn for visual signature validation" % unit_id)
		return
	var style: Dictionary[String, Variant] = AttackVisualCatalogScript.style_for(unit, "player", false)
	if not bool(style.get("signature_overridden", false)):
		failures.append("%s has no explicit visual signature" % unit_id)
	var shape: String = String(style.get("shape", "")).strip_edges()
	if shape == "":
		failures.append("%s visual signature has no shape" % unit_id)
		return
	signature_shapes[shape] = true

func _read_contract(failures: Array[String]) -> Dictionary:
	var file: FileAccess = FileAccess.open(CONTRACT_PATH, FileAccess.READ)
	if file == null:
		failures.append("cannot open %s" % CONTRACT_PATH)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		failures.append("contract root must be a JSON object")
		return {}
	return parsed as Dictionary

func _playable_ids(catalog: UnitCatalog) -> Array[String]:
	var ids: Array[String] = []
	for cost: int in catalog.get_all_costs():
		for unit_id: String in catalog.get_ids_by_cost(cost):
			var flags: Dictionary = catalog.get_unit_meta(unit_id).get("flags", {}) as Dictionary
			if bool(flags.get("hidden", false)) or bool(flags.get("enemy_only", false)):
				continue
			ids.append(unit_id)
	ids.sort()
	return ids

func _validate_entry(entry: Dictionary, unit_id: String, catalog: UnitCatalog, budgets: Dictionary, seen_test_ids: Dictionary[String, bool], failures: Array[String]) -> void:
	if not catalog.has_id(unit_id):
		failures.append("%s is absent from UnitCatalog" % unit_id)
		return
	var profile: UnitProfile = load("res://data/units/%s.tres" % unit_id) as UnitProfile
	if profile == null:
		failures.append("%s profile could not load" % unit_id)
		return
	_expect_equal(unit_id, "ability_id", String(profile.ability_id), String(entry.get("ability_id", "")), failures)
	_expect_equal(unit_id, "cost", str(profile.cost), str(int(entry.get("cost", 0))), failures)
	_expect_equal(unit_id, "traits", _sorted_join(catalog.get_traits(unit_id)), _sorted_join(_string_array(entry.get("traits", []))), failures)
	_expect_equal(unit_id, "primary_role", catalog.get_primary_role(unit_id), String(entry.get("primary_role", "")), failures)
	_expect_equal(unit_id, "primary_goal", catalog.get_primary_goal(unit_id), String(entry.get("primary_goal", "")), failures)
	_expect_equal(unit_id, "approaches", _sorted_join(catalog.get_approaches(unit_id)), _sorted_join(_string_array(entry.get("approaches", []))), failures)
	for field: String in ["core_promise", "player_explanation", "team_utility", "signature_moment", "problem", "direction"]:
		if String(entry.get(field, "")).strip_edges() == "":
			failures.append("%s is missing %s" % [unit_id, field])
	var explanation: String = String(entry.get("player_explanation", "")).strip_edges()
	if explanation.split(" ", false).size() > MAX_PLAYER_WORDS:
		failures.append("%s player explanation exceeds %d words" % [unit_id, MAX_PLAYER_WORDS])
	var verdict: String = String(entry.get("verdict", ""))
	if not VERDICTS.has(verdict):
		failures.append("%s has invalid verdict %s" % [unit_id, verdict])
	var families: Array[String] = _string_array(entry.get("effect_families", []))
	if families.is_empty():
		failures.append("%s has no effect families" % unit_id)
	for family: String in families:
		if not EFFECT_FAMILIES.has(family):
			failures.append("%s has unknown effect family %s" % [unit_id, family])
	var budget: int = int(budgets.get(str(profile.cost), 0))
	if families.size() > budget and verdict == "keep":
		failures.append("%s keep verdict exceeds cost-%d family budget %d with %d families" % [unit_id, profile.cost, budget, families.size()])
	if families.size() > budget and String(entry.get("complexity_breach", "")).strip_edges() == "":
		failures.append("%s exceeds family budget without complexity_breach" % unit_id)
	_validate_scores(entry, unit_id, verdict, failures)
	_validate_counterplay(entry, unit_id, failures)
	_validate_test_cases(entry, unit_id, seen_test_ids, failures)

func _validate_scores(entry: Dictionary, unit_id: String, verdict: String, failures: Array[String]) -> void:
	var scores: Dictionary = entry.get("scores", {}) as Dictionary
	var total: int = 0
	for field: String in SCORE_FIELDS:
		var score: int = int(scores.get(field, -1))
		if score < 0 or score > 2:
			failures.append("%s score %s must be 0..2" % [unit_id, field])
			continue
		total += score
	if verdict == "keep" and total < 11:
		failures.append("%s keep verdict requires score total >= 11, got %d" % [unit_id, total])
	if verdict == "keep":
		for field: String in SCORE_FIELDS:
			if int(scores.get(field, 0)) == 0:
				failures.append("%s keep verdict cannot have zero score for %s" % [unit_id, field])

func _validate_counterplay(entry: Dictionary, unit_id: String, failures: Array[String]) -> void:
	var counterplay: Dictionary = entry.get("counterplay", {}) as Dictionary
	var levers: Array[String] = _string_array(counterplay.get("levers", []))
	if levers.size() < 2:
		failures.append("%s needs at least two counterplay levers" % unit_id)
	if String(counterplay.get("failure_state", "")).strip_edges() == "":
		failures.append("%s needs a counterplay failure_state" % unit_id)

func _validate_test_cases(entry: Dictionary, unit_id: String, seen_test_ids: Dictionary[String, bool], failures: Array[String]) -> void:
	var cases_value: Variant = entry.get("test_cases", [])
	if not cases_value is Array:
		failures.append("%s test_cases must be an array" % unit_id)
		return
	var cases: Array = cases_value as Array
	if cases.size() < 2:
		failures.append("%s needs at least two test cases" % unit_id)
	var has_visual: bool = false
	var has_behavior: bool = false
	for case_value: Variant in cases:
		if not case_value is Dictionary:
			failures.append("%s test case must be an object" % unit_id)
			continue
		var test_case: Dictionary = case_value as Dictionary
		var test_id: String = String(test_case.get("id", "")).strip_edges()
		var test_type: String = String(test_case.get("type", "")).strip_edges()
		if test_id == "":
			failures.append("%s test case is missing id" % unit_id)
		elif seen_test_ids.has(test_id):
			failures.append("duplicate test id %s" % test_id)
		else:
			seen_test_ids[test_id] = true
		if test_type == "visual":
			has_visual = true
		else:
			has_behavior = true
		var assertions: Array[String] = _string_array(test_case.get("assertions", []))
		if assertions.is_empty():
			failures.append("%s test %s has no assertions" % [unit_id, test_id])
	if not has_visual:
		failures.append("%s needs a temporal visual test case" % unit_id)
	if not has_behavior:
		failures.append("%s needs a behavioral or RGA test case" % unit_id)

func _expect_equal(unit_id: String, field: String, expected: String, actual: String, failures: Array[String]) -> void:
	if expected != actual:
		failures.append("%s %s expected '%s' got '%s'" % [unit_id, field, expected, actual])

func _string_array(value: Variant) -> Array[String]:
	var out: Array[String] = []
	if value is Array:
		for item: Variant in value as Array:
			out.append(String(item))
	elif value is PackedStringArray:
		for item: String in value as PackedStringArray:
			out.append(item)
	return out

func _sorted_join(values: Array[String]) -> String:
	var copy: Array[String] = values.duplicate()
	copy.sort()
	return "|".join(copy)
