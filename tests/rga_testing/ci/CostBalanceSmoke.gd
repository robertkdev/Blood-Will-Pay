extends Node

const ShopConfig := preload("res://scripts/game/shop/shop_config.gd")
const ShopOdds := preload("res://scripts/game/shop/shop_odds.gd")
const ShopRollerScript := preload("res://scripts/game/shop/shop_roller.gd")
const ShopRngScript := preload("res://scripts/game/shop/shop_rng.gd")
const UnitCatalogScript := preload("res://scripts/game/shop/unit_catalog.gd")
const RGASettingsScript := preload("res://tests/rga_testing/settings.gd")
const RGAUnitCatalogScript := preload("res://tests/rga_testing/io/unit_catalog.gd")

const COST_1_UNITS: Array[String] = [
	"axiom",
	"berebell",
	"bo",
	"bonko",
	"brute",
	"mara",
	"grint",
	"knoll",
	"korath",
	"morrak",
	"mortem",
	"pilfer",
	"repo",
	"sari",
]
const COST_2_UNITS: Array[String] = [
	"cinder",
	"kythera",
	"luna",
	"miri",
	"nyxa",
	"paisley",
	"rooket",
	"teller",
	"totem",
	"veyra",
	"velour",
	"volt",
	"vykos",
]
const COST_3_UNITS: Array[String] = [
	"caldera",
	"creep",
	"egress",
	"hexeon",
	"ivara",
	"juno_vale",
	"kett",
	"marble",
	"noxley",
	"prisma",
	"quorra",
	"sable",
]
const COST_4_UNITS: Array[String] = [
	"bastionne",
	"draxelle",
	"gable",
	"omenry",
	"orielle",
	"ravel",
	"saffron",
	"vesper",
]
const COST_5_UNITS: Array[String] = [
	"malachor",
	"meridian",
	"nullora",
	"quillith",
]

const ROLL_SHOPS_PER_LEVEL: int = 600
const EPSILON: float = 0.0001

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	var rga_entries: Array[Dictionary] = _active_rga_entries()
	var shop_catalog: UnitCatalog = UnitCatalogScript.new()
	shop_catalog.refresh()

	_validate_expected_tiers(rga_entries, shop_catalog, failures)
	_validate_starter_surface(shop_catalog, failures)
	_validate_identity_surface(rga_entries, failures)
	_validate_shop_odds(failures)
	_validate_shop_rolls(shop_catalog, failures)

	if failures.is_empty():
		print("CostBalanceSmoke: PASS units=", rga_entries.size(), " tiers=1:", COST_1_UNITS.size(), " 2:", COST_2_UNITS.size(), " 3:", COST_3_UNITS.size(), " 4:", COST_4_UNITS.size(), " 5:", COST_5_UNITS.size())
		get_tree().quit(0)
		return
	for failure: String in failures:
		printerr("CostBalanceSmoke: ", failure)
	get_tree().quit(1)

func _active_rga_entries() -> Array[Dictionary]:
	var settings: RGASettings = RGASettingsScript.new()
	settings.role_filter = PackedStringArray([])
	settings.goal_filter = PackedStringArray([])
	settings.approach_filter = PackedStringArray([])
	settings.cost_filter = PackedInt32Array([])
	var catalog: RGAUnitCatalog = RGAUnitCatalogScript.new()
	return catalog.list(settings)

func _validate_expected_tiers(rga_entries: Array[Dictionary], shop_catalog: UnitCatalog, failures: Array[String]) -> void:
	var expected_by_cost: Dictionary[int, Array] = {
		1: COST_1_UNITS,
		2: COST_2_UNITS,
		3: COST_3_UNITS,
		4: COST_4_UNITS,
		5: COST_5_UNITS,
	}
	var rga_by_cost: Dictionary[int, Array] = {}
	for entry: Dictionary in rga_entries:
		var cost: int = int(entry.get("cost", 0))
		var id: String = String(entry.get("id", "")).strip_edges()
		if not rga_by_cost.has(cost):
			rga_by_cost[cost] = []
		rga_by_cost[cost].append(id)
		if not ShopConfig.VALID_COSTS.has(cost):
			failures.append("unit %s has cost %d outside VALID_COSTS" % [id, cost])
	for cost_key: int in expected_by_cost.keys():
		var expected: Array[String] = _sorted_string_copy(expected_by_cost[cost_key])
		var rga_actual: Array[String] = _sorted_string_copy(rga_by_cost.get(cost_key, []))
		var shop_actual: Array[String] = _sorted_string_copy(shop_catalog.get_ids_by_cost(cost_key))
		_expect_lists_equal("RGA cost %d roster" % cost_key, expected, rga_actual, failures)
		_expect_lists_equal("shop cost %d roster" % cost_key, expected, shop_actual, failures)
	for unexpected_cost: int in rga_by_cost.keys():
		if not expected_by_cost.has(unexpected_cost):
			failures.append("unexpected RGA cost tier %d ids=%s" % [unexpected_cost, _format_list(_sorted_string_copy(rga_by_cost[unexpected_cost]))])
	_expect_lists_equal("valid cost list", [1, 2, 3, 4, 5], ShopConfig.VALID_COSTS, failures)

func _validate_starter_surface(shop_catalog: UnitCatalog, failures: Array[String]) -> void:
	var starters: Array[String] = _sorted_string_copy(shop_catalog.list_starter_ids(ShopConfig.STARTING_LEVEL))
	var expected_starters: Array[String] = _sorted_string_copy(COST_1_UNITS)
	_expect_lists_equal("level 1 starters", expected_starters, starters, failures)
	var premium_units: Array[String] = []
	premium_units.append_array(COST_2_UNITS)
	premium_units.append_array(COST_3_UNITS)
	premium_units.append_array(COST_4_UNITS)
	premium_units.append_array(COST_5_UNITS)
	for premium_id: String in premium_units:
		if starters.has(premium_id):
			failures.append("premium unit %s should not be starter-visible at level 1" % premium_id)

func _validate_identity_surface(rga_entries: Array[Dictionary], failures: Array[String]) -> void:
	for entry: Dictionary in rga_entries:
		var id: String = String(entry.get("id", "")).strip_edges()
		var role_id: String = String(entry.get("primary_role", "")).strip_edges()
		var goal_id: String = String(entry.get("primary_goal", "")).strip_edges()
		var approaches: Array = entry.get("approaches", [])
		if role_id == "":
			failures.append("%s is missing primary_role" % id)
		if goal_id == "":
			failures.append("%s is missing primary_goal" % id)
		if approaches.is_empty():
			failures.append("%s has no approach tags to express its excitement factor" % id)

func _validate_shop_odds(failures: Array[String]) -> void:
	for level: int in range(ShopConfig.MIN_LEVEL, ShopConfig.MAX_LEVEL + 1):
		var probabilities: Dictionary = ShopOdds.get_cost_probabilities(level)
		var total: float = 0.0
		for raw_cost: Variant in probabilities.keys():
			var cost: int = int(raw_cost)
			var probability: float = float(probabilities[raw_cost])
			total += probability
			if not ShopConfig.VALID_COSTS.has(cost):
				failures.append("level %d odds include invalid cost %d" % [level, cost])
			if probability <= 0.0:
				failures.append("level %d cost %d has non-positive probability %.4f" % [level, cost, probability])
		if absf(total - 1.0) > EPSILON:
			failures.append("level %d odds sum to %.4f, expected 1.0" % [level, total])
		_validate_expected_level_access(level, probabilities, failures)

func _validate_expected_level_access(level: int, probabilities: Dictionary, failures: Array[String]) -> void:
	if level == 1:
		_expect_cost_access(level, probabilities, [1], failures)
	elif level == 2:
		_expect_cost_access(level, probabilities, [1, 2], failures)
	elif level == 3:
		_expect_cost_access(level, probabilities, [1, 2, 3], failures)
	elif level == 4:
		_expect_cost_access(level, probabilities, [1, 2, 3, 4], failures)
	else:
		_expect_cost_access(level, probabilities, [1, 2, 3, 4, 5], failures)

func _expect_cost_access(level: int, probabilities: Dictionary, expected_costs: Array[int], failures: Array[String]) -> void:
	var actual_costs: Array[int] = []
	for raw_cost: Variant in probabilities.keys():
		actual_costs.append(int(raw_cost))
	actual_costs.sort()
	var sorted_expected: Array[int] = expected_costs.duplicate()
	sorted_expected.sort()
	_expect_lists_equal("level %d cost access" % level, sorted_expected, actual_costs, failures)

func _validate_shop_rolls(shop_catalog: UnitCatalog, failures: Array[String]) -> void:
	var rng: ShopRng = ShopRngScript.new()
	rng.set_seed(92624)
	var roller: ShopRoller = ShopRollerScript.new()
	roller.configure(shop_catalog, rng)
	for level: int in range(ShopConfig.MIN_LEVEL, ShopConfig.MAX_LEVEL + 1):
		var observed_counts: Dictionary[int, int] = {}
		var observed_ids: Dictionary[String, bool] = {}
		for _shop_index: int in range(ROLL_SHOPS_PER_LEVEL):
			var offers: Array[ShopOffer] = roller.roll(level, ShopConfig.SLOT_COUNT)
			for offer: ShopOffer in offers:
				var cost: int = int(offer.cost)
				observed_counts[cost] = int(observed_counts.get(cost, 0)) + 1
				observed_ids[String(offer.id)] = true
		var observed_costs: Array[int] = []
		for raw_cost: Variant in observed_counts.keys():
			observed_costs.append(int(raw_cost))
		observed_costs.sort()
		var expected_costs: Array[int] = _positive_costs_for_level(level)
		_expect_lists_equal("level %d rolled costs" % level, expected_costs, observed_costs, failures)
		for cost: int in expected_costs:
			if int(observed_counts.get(cost, 0)) <= 0:
				failures.append("level %d never rolled cost %d" % [level, cost])
		if level >= 2:
			_expect_any_observed("level %d premium roll coverage" % level, COST_2_UNITS, observed_ids, failures)
		if level >= 3:
			_expect_any_observed("level %d capstone roll coverage" % level, COST_3_UNITS, observed_ids, failures)
		if level >= 4:
			_expect_any_observed("level %d pivot roll coverage" % level, COST_4_UNITS, observed_ids, failures)
		if level >= 5:
			_expect_any_observed("level %d capstone roll coverage" % level, COST_5_UNITS, observed_ids, failures)
		print("CostBalanceSmoke: level=", level, " observed_cost_counts=", observed_counts)

func _positive_costs_for_level(level: int) -> Array[int]:
	var probabilities: Dictionary = ShopOdds.get_cost_probabilities(level)
	var out: Array[int] = []
	for raw_cost: Variant in probabilities.keys():
		if float(probabilities[raw_cost]) > 0.0:
			out.append(int(raw_cost))
	out.sort()
	return out

func _expect_any_observed(label: String, unit_ids: Array[String], observed_ids: Dictionary[String, bool], failures: Array[String]) -> void:
	for unit_id: String in unit_ids:
		if observed_ids.has(unit_id):
			return
	failures.append("%s did not observe any of %s" % [label, _format_list(unit_ids)])

func _expect_lists_equal(label: String, expected: Array, actual: Array, failures: Array[String]) -> void:
	var expected_text: String = _format_list(expected)
	var actual_text: String = _format_list(actual)
	if expected_text != actual_text:
		failures.append("%s expected [%s] got [%s]" % [label, expected_text, actual_text])

func _sorted_string_copy(values: Array) -> Array[String]:
	var out: Array[String] = []
	for value: Variant in values:
		out.append(str(value))
	out.sort()
	return out

func _format_list(values: Array) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for value: Variant in values:
		parts.append(str(value))
	return ",".join(parts)
