extends Node

const MODEL_PATH: String = "res://data/model.json"


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	var file: FileAccess = FileAccess.open(MODEL_PATH, FileAccess.READ)
	if file == null:
		failures.append("Unable to open %s" % MODEL_PATH)
		_finish(failures)
		return

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		failures.append("Planning model is not valid JSON object data")
		_finish(failures)
		return

	var model: Dictionary = parsed as Dictionary
	var meta: Dictionary = model.get("meta", {}) as Dictionary
	var catalog: Dictionary = model.get("catalog", {}) as Dictionary
	var archetypes: Array[Dictionary] = _dictionary_array(model.get("archetypes", []))
	var edges: Array[Dictionary] = _dictionary_array(model.get("counterEdges", []))
	var traits: Array[Dictionary] = _dictionary_array(model.get("traits", []))
	var bridges: Array[Dictionary] = _dictionary_array(model.get("bridgeUnits", []))
	var promised_pairs: Array[Dictionary] = _dictionary_array(model.get("promisedPairs", []))

	_expect(failures, int(meta.get("boardCap", 0)) == 10, "Board cap must remain 10")
	_expect(failures, int(meta.get("baseRosterCount", 0)) == 49, "Base roster snapshot must remain 49")
	_expect(failures, int(meta.get("plannedRosterCount", 0)) == 72, "Planned roster must be 72")
	_expect(failures, int(meta.get("activeTraitCount", 0)) == 21, "Active trait count must be 21")
	_expect(failures, archetypes.size() == 9, "Exactly nine RGA archetypes are required")
	_expect(failures, edges.size() == 36, "Nine archetypes require 36 authored unordered matchups")
	_expect(failures, traits.size() == 21, "Every active trait needs a planning contract")
	_expect(failures, bridges.size() == 23, "Exactly 23 numbered bridge units are required")
	_expect(failures, promised_pairs.size() == 4, "Four promised double verticals are required")

	_validate_counter_tournament(archetypes, edges, failures)
	_validate_bridge_supply(catalog, traits, bridges, failures)
	_validate_promised_pairs(meta, traits, bridges, promised_pairs, failures)
	_finish(failures)


func _validate_counter_tournament(
	archetypes: Array[Dictionary],
	edges: Array[Dictionary],
	failures: Array[String]
) -> void:
	var archetype_ids: Dictionary[String, bool] = {}
	var degrees: Dictionary[String, int] = {}
	var seen_pairs: Dictionary[String, bool] = {}

	for archetype: Dictionary in archetypes:
		var archetype_id: String = String(archetype.get("id", ""))
		_expect(failures, not archetype_id.is_empty(), "Archetype IDs cannot be empty")
		_expect(failures, not archetype_ids.has(archetype_id), "Duplicate archetype ID: %s" % archetype_id)
		archetype_ids[archetype_id] = true
		for bucket: String in ["hard_win", "soft_win", "soft_loss", "hard_loss"]:
			degrees["%s|%s" % [archetype_id, bucket]] = 0

	for edge: Dictionary in edges:
		var winner: String = String(edge.get("winner", ""))
		var loser: String = String(edge.get("loser", ""))
		var strength: String = String(edge.get("strength", ""))
		_expect(failures, archetype_ids.has(winner), "Unknown counter winner: %s" % winner)
		_expect(failures, archetype_ids.has(loser), "Unknown counter loser: %s" % loser)
		_expect(failures, winner != loser, "Counter edges cannot be mirrors")
		_expect(failures, strength == "hard" or strength == "soft", "Counter strength must be hard or soft")

		var ordered_ids: Array[String] = [winner, loser]
		ordered_ids.sort()
		var pair_key: String = "%s|%s" % [ordered_ids[0], ordered_ids[1]]
		_expect(failures, not seen_pairs.has(pair_key), "Duplicate unordered counter pair: %s" % pair_key)
		seen_pairs[pair_key] = true

		var winner_bucket: String = "%s|%s_win" % [winner, strength]
		var loser_bucket: String = "%s|%s_loss" % [loser, strength]
		degrees[winner_bucket] = degrees.get(winner_bucket, 0) + 1
		degrees[loser_bucket] = degrees.get(loser_bucket, 0) + 1

	for archetype: Dictionary in archetypes:
		var archetype_id: String = String(archetype.get("id", ""))
		var row_sum: int = (
			2 * degrees.get("%s|hard_win" % archetype_id, 0)
			+ degrees.get("%s|soft_win" % archetype_id, 0)
			- degrees.get("%s|soft_loss" % archetype_id, 0)
			- 2 * degrees.get("%s|hard_loss" % archetype_id, 0)
		)
		for bucket: String in ["hard_win", "soft_win", "soft_loss", "hard_loss"]:
			_expect(
				failures,
				degrees.get("%s|%s" % [archetype_id, bucket], 0) == 2,
				"%s must have exactly two %s edges" % [archetype_id, bucket]
			)
		_expect(failures, row_sum == 0, "%s counter row must sum to zero" % archetype_id)


func _validate_bridge_supply(
	catalog: Dictionary,
	traits: Array[Dictionary],
	bridges: Array[Dictionary],
	failures: Array[String]
) -> void:
	var bridge_trait_supply: Dictionary[String, int] = {}
	var bridge_role_counts: Dictionary[String, int] = {}
	var bridge_cost_counts: Dictionary[String, int] = {}
	var covered_approaches: Dictionary[String, bool] = {}

	for bridge_index: int in range(bridges.size()):
		var bridge: Dictionary = bridges[bridge_index]
		var expected_label: String = "Temporary Unit %02d" % (bridge_index + 1)
		var bridge_traits: Array[String] = _string_array(bridge.get("traits", []))
		var bridge_approaches: Array[String] = _string_array(bridge.get("approaches", []))
		var role: String = String(bridge.get("role", ""))
		var cost_key: String = str(int(bridge.get("cost", 0)))

		_expect(failures, String(bridge.get("label", "")) == expected_label, "Bridge labels must be sequential")
		_expect(failures, bridge_traits.size() == 2, "%s must bridge exactly two active traits" % expected_label)
		for trait_id: String in bridge_traits:
			bridge_trait_supply[trait_id] = bridge_trait_supply.get(trait_id, 0) + 1
		for approach: String in bridge_approaches:
			covered_approaches[approach] = true
		bridge_role_counts[role] = bridge_role_counts.get(role, 0) + 1
		bridge_cost_counts[cost_key] = bridge_cost_counts.get(cost_key, 0) + 1

	var base_roles: Dictionary = catalog.get("baseRoleCounts", {}) as Dictionary
	var target_roles: Dictionary = catalog.get("targetFinalRoleCounts", {}) as Dictionary
	for role_variant: Variant in target_roles.keys():
		var role: String = String(role_variant)
		var final_role_count: int = int(base_roles.get(role, 0)) + bridge_role_counts.get(role, 0)
		_expect(failures, final_role_count == int(target_roles.get(role, 0)), "%s role target mismatch" % role)

	var base_costs: Dictionary = catalog.get("baseCostCounts", {}) as Dictionary
	var target_costs: Dictionary = catalog.get("targetFinalCostCounts", {}) as Dictionary
	for cost_variant: Variant in target_costs.keys():
		var cost_key: String = String(cost_variant)
		var final_cost_count: int = int(base_costs.get(cost_key, 0)) + bridge_cost_counts.get(cost_key, 0)
		_expect(failures, final_cost_count == int(target_costs.get(cost_key, 0)), "Cost %s target mismatch" % cost_key)

	for approach: String in _string_array(catalog.get("approaches", [])):
		_expect(failures, covered_approaches.has(approach), "Bridge roster misses approach: %s" % approach)

	for trait_row: Dictionary in traits:
		var trait_id: String = String(trait_row.get("id", ""))
		var thresholds: Array[int] = _int_array(trait_row.get("thresholds", []))
		var current_carriers: Array[String] = _string_array(trait_row.get("currentCarriers", []))
		var maximum: int = thresholds.max() if not thresholds.is_empty() else 0
		var planned_supply: int = current_carriers.size() + bridge_trait_supply.get(trait_id, 0)
		var redundancy_target: int = maximum + (2 if maximum >= 8 or maximum <= 2 else 1)
		_expect(failures, maximum > 0, "%s needs at least one threshold" % trait_id)
		_expect(failures, planned_supply >= maximum, "%s cannot reach its natural capstone" % trait_id)
		_expect(failures, planned_supply >= redundancy_target, "%s lacks drafting redundancy" % trait_id)


func _validate_promised_pairs(
	meta: Dictionary,
	traits: Array[Dictionary],
	bridges: Array[Dictionary],
	promised_pairs: Array[Dictionary],
	failures: Array[String]
) -> void:
	var board_cap: int = int(meta.get("boardCap", 0))
	var trait_caps: Dictionary[String, int] = {}
	var unit_traits: Dictionary[String, PackedStringArray] = {}

	for trait_row: Dictionary in traits:
		var trait_id: String = String(trait_row.get("id", ""))
		var thresholds: Array[int] = _int_array(trait_row.get("thresholds", []))
		trait_caps[trait_id] = thresholds.max() if not thresholds.is_empty() else 0
		for unit_id: String in _string_array(trait_row.get("currentCarriers", [])):
			var carried_traits: PackedStringArray = unit_traits.get(unit_id, PackedStringArray())
			carried_traits.append(trait_id)
			unit_traits[unit_id] = carried_traits

	for bridge: Dictionary in bridges:
		var bridge_id: String = String(bridge.get("id", ""))
		unit_traits[bridge_id] = PackedStringArray(_string_array(bridge.get("traits", [])))

	for promised_pair: Dictionary in promised_pairs:
		var pair_traits: Array[String] = _string_array(promised_pair.get("traits", []))
		var board: Array[String] = _string_array(promised_pair.get("board", []))
		_expect(failures, pair_traits.size() == 2, "Promised pairs must name exactly two traits")
		_expect(failures, board.size() == board_cap, "Promised pair boards must use exactly 10 slots")
		if pair_traits.size() != 2:
			continue

		var first_trait: String = pair_traits[0]
		var second_trait: String = pair_traits[1]
		var first_cap: int = trait_caps.get(first_trait, 0)
		var second_cap: int = trait_caps.get(second_trait, 0)
		var required_overlap: int = maxi(0, first_cap + second_cap - board_cap)
		var first_count: int = 0
		var second_count: int = 0
		var actual_overlap: int = 0
		var seen_units: Dictionary[String, bool] = {}

		for unit_id: String in board:
			_expect(failures, unit_traits.has(unit_id), "Unknown board unit: %s" % unit_id)
			_expect(failures, not seen_units.has(unit_id), "Duplicate board unit: %s" % unit_id)
			seen_units[unit_id] = true
			var carried_traits: PackedStringArray = unit_traits.get(unit_id, PackedStringArray())
			var has_first: bool = carried_traits.has(first_trait)
			var has_second: bool = carried_traits.has(second_trait)
			first_count += 1 if has_first else 0
			second_count += 1 if has_second else 0
			actual_overlap += 1 if has_first and has_second else 0

		_expect(failures, first_count >= first_cap, "%s board misses %s capstone" % [String(promised_pair.get("identity", "")), first_trait])
		_expect(failures, second_count >= second_cap, "%s board misses %s capstone" % [String(promised_pair.get("identity", "")), second_trait])
		_expect(failures, int(promised_pair.get("requiredOverlap", -1)) == required_overlap, "Stored overlap lower bound is wrong")
		_expect(failures, int(promised_pair.get("plannedOverlap", -1)) == actual_overlap, "Stored overlap count is wrong")
		_expect(failures, actual_overlap >= required_overlap, "Promised pair is not simultaneously fieldable")


func _dictionary_array(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if value is Array:
		for entry: Variant in value:
			if entry is Dictionary:
				result.append(entry as Dictionary)
	return result


func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for entry: Variant in value:
			result.append(String(entry))
	return result


func _int_array(value: Variant) -> Array[int]:
	var result: Array[int] = []
	if value is Array:
		for entry: Variant in value:
			result.append(int(entry))
	return result


func _expect(failures: Array[String], condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("RGA_TRAIT_MATRIX_PLAN_SMOKE: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("RGA_TRAIT_MATRIX_PLAN_SMOKE: %s" % failure)
	get_tree().quit(1)
