extends Node

const UnitCatalogScript: Script = preload("res://scripts/game/shop/unit_catalog.gd")
const ShopRngScript: Script = preload("res://scripts/game/shop/shop_rng.gd")
const ShopRollerScript: Script = preload("res://scripts/game/shop/shop_roller.gd")
const ShopConfigScript: Script = preload("res://scripts/game/shop/shop_config.gd")

const SMOKE_NAME: String = "FirstShopOfferQualitySamplingSmoke"
const SAMPLE_COUNT: int = 240
const START_SEED: int = 260626
const MIN_GOOD_RATES: Dictionary[String, float] = {
	"axiom": 1.0,
	"bo": 1.0,
	"bonko": 1.0,
	"mara": 1.0,
	"korath": 1.0,
	"morrak": 1.0,
	"mortem": 1.0,
	"repo": 1.0,
	"sari": 1.0,
}
const EXPECTED_BLOCKED_HELPERS_BY_STARTER: Dictionary[String, Array] = {
	"axiom": ["axiom", "berebell", "bo", "bonko", "brute", "mara", "grint", "korath", "morrak", "mortem", "repo"],
	"bo": ["axiom", "brute", "mara"],
	"bonko": ["axiom", "korath", "repo"],
	"mara": ["axiom", "korath", "repo"],
	"korath": ["axiom", "brute"],
	"morrak": ["brute", "grint", "korath", "repo"],
	"mortem": ["axiom", "brute"],
	"repo": ["axiom", "brute", "korath", "mortem"],
	"sari": ["axiom"],
}

var _failures: Array[String] = []

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var catalog: UnitCatalog = UnitCatalogScript.new()
	catalog.refresh()
	var rng: ShopRng = ShopRngScript.new()
	var roller: ShopRoller = ShopRollerScript.new()
	roller.configure(catalog, rng)
	var stats: Dictionary[String, Variant] = _initial_stats()
	for sample_index: int in range(SAMPLE_COUNT):
		rng.set_seed(START_SEED + sample_index)
		var starter_id: String = _starter_ids()[sample_index % _starter_ids().size()]
		var offers: Array[ShopOffer] = roller.roll_opening_for_starter(starter_id, int(ShopConfigScript.STARTING_LEVEL), int(ShopConfigScript.SLOT_COUNT))
		_expect(offers.size() == int(ShopConfigScript.SLOT_COUNT), "sample %d should have %d offers, got %d" % [sample_index, int(ShopConfigScript.SLOT_COUNT), offers.size()])
		_record_sample(stats, starter_id, offers)
	_assert_expected_blocked_config()
	_assert_rates(stats)
	_finish(stats)

func _initial_stats() -> Dictionary[String, Variant]:
	var stats: Dictionary[String, Variant] = {}
	for starter_id: String in _starter_ids():
		stats[starter_id] = _empty_starter_stats()
	return stats

func _empty_starter_stats() -> Dictionary[String, Variant]:
	var starter_stats: Dictionary[String, Variant] = {}
	var examples: Array[String] = []
	var first_examples: Array[String] = []
	var blocked_examples: Array[String] = []
	starter_stats["good_count"] = 0
	starter_stats["no_good_count"] = 0
	starter_stats["first_good_count"] = 0
	starter_stats["first_no_good_count"] = 0
	starter_stats["axiom_count"] = 0
	starter_stats["blocked_count"] = 0
	starter_stats["no_good_examples"] = examples
	starter_stats["first_no_good_examples"] = first_examples
	starter_stats["blocked_examples"] = blocked_examples
	return starter_stats

func _record_sample(stats: Dictionary[String, Variant], starter_id: String, offers: Array[ShopOffer]) -> void:
	var offer_ids: Array[String] = []
	for offer: ShopOffer in offers:
		if offer != null:
			offer_ids.append(String(offer.id))
	var starter_stats: Dictionary[String, Variant] = stats[starter_id] as Dictionary[String, Variant]
	var good_helpers: Array[String] = _good_helpers_for(starter_id)
	var blocked_helpers: Array[String] = _blocked_helpers_for(starter_id)
	var has_good: bool = _has_any(offer_ids, good_helpers)
	var has_blocked: bool = _has_any(offer_ids, blocked_helpers)
	var first_offer_id: String = _first_offer_id(offers)
	var first_has_good: bool = good_helpers.has(first_offer_id)
	var has_axiom: bool = offer_ids.has("axiom")
	starter_stats["sample_count"] = int(starter_stats.get("sample_count", 0)) + 1
	if has_good:
		starter_stats["good_count"] = int(starter_stats.get("good_count", 0)) + 1
	else:
		starter_stats["no_good_count"] = int(starter_stats.get("no_good_count", 0)) + 1
		var examples: Array[String] = _string_array(starter_stats.get("no_good_examples", []))
		if examples.size() < 3:
			examples.append(",".join(offer_ids))
		starter_stats["no_good_examples"] = examples
	if first_has_good:
		starter_stats["first_good_count"] = int(starter_stats.get("first_good_count", 0)) + 1
	else:
		starter_stats["first_no_good_count"] = int(starter_stats.get("first_no_good_count", 0)) + 1
		var first_examples: Array[String] = _string_array(starter_stats.get("first_no_good_examples", []))
		if first_examples.size() < 3:
			first_examples.append("%s|%s" % [first_offer_id, ",".join(offer_ids)])
		starter_stats["first_no_good_examples"] = first_examples
	if has_axiom:
		starter_stats["axiom_count"] = int(starter_stats.get("axiom_count", 0)) + 1
	if has_blocked:
		starter_stats["blocked_count"] = int(starter_stats.get("blocked_count", 0)) + 1
		var blocked_examples: Array[String] = _string_array(starter_stats.get("blocked_examples", []))
		if blocked_examples.size() < 3:
			blocked_examples.append(",".join(offer_ids))
		starter_stats["blocked_examples"] = blocked_examples
	stats[starter_id] = starter_stats

func _assert_rates(stats: Dictionary[String, Variant]) -> void:
	for starter_id: String in _starter_ids():
		var starter_stats: Dictionary[String, Variant] = stats[starter_id] as Dictionary[String, Variant]
		var good_count: int = int(starter_stats.get("good_count", 0))
		var first_good_count: int = int(starter_stats.get("first_good_count", 0))
		var sample_count: int = int(starter_stats.get("sample_count", 0))
		var blocked_count: int = int(starter_stats.get("blocked_count", 0))
		var rate: float = float(good_count) / float(max(1, sample_count))
		var first_rate: float = float(first_good_count) / float(max(1, sample_count))
		var required_rate: float = float(MIN_GOOD_RATES.get(starter_id, 0.0))
		_expect(rate >= required_rate, "%s known-good first-shop helper rate %.3f below %.3f" % [starter_id, rate, required_rate])
		_expect(first_rate >= required_rate, "%s first-slot known-good helper rate %.3f below %.3f" % [starter_id, first_rate, required_rate])
		_expect(blocked_count == 0, "%s known-bad first-shop helpers appeared in %d samples" % [starter_id, blocked_count])

func _assert_expected_blocked_config() -> void:
	for starter_id: String in _starter_ids():
		var configured_helpers: Array[String] = _blocked_helpers_for(starter_id)
		var expected_helpers: Array[String] = _expected_blocked_helpers_for(starter_id)
		for helper_id: String in expected_helpers:
			_expect(configured_helpers.has(helper_id), "%s matrix-proven first-shop trap %s should be blocked" % [starter_id, helper_id])

func _finish(stats: Dictionary[String, Variant]) -> void:
	var exit_code: int = 0
	if _failures.is_empty():
		print("%s: PASS samples=%d %s" % [SMOKE_NAME, SAMPLE_COUNT, _summary_string(stats)])
	else:
		for failure: String in _failures:
			push_error("%s: %s" % [SMOKE_NAME, failure])
		exit_code = 1
	get_tree().quit(exit_code)

func _summary_string(stats: Dictionary[String, Variant]) -> String:
	var parts: Array[String] = []
	for starter_id: String in _sorted_keys(stats):
		var starter_stats: Dictionary[String, Variant] = stats[starter_id] as Dictionary[String, Variant]
		var good_count: int = int(starter_stats.get("good_count", 0))
		var first_good_count: int = int(starter_stats.get("first_good_count", 0))
		var sample_count: int = int(starter_stats.get("sample_count", 0))
		var no_good_count: int = int(starter_stats.get("no_good_count", 0))
		var first_no_good_count: int = int(starter_stats.get("first_no_good_count", 0))
		var axiom_count: int = int(starter_stats.get("axiom_count", 0))
		var blocked_count: int = int(starter_stats.get("blocked_count", 0))
		var rate: float = float(good_count) / float(max(1, sample_count))
		var first_rate: float = float(first_good_count) / float(max(1, sample_count))
		parts.append("%s_good=%d/%d(%.3f) first_good=%d/%d(%.3f) no_good=%d first_no_good=%d blocked_seen=%d axiom_seen=%d examples=[%s] first_examples=[%s] blocked_examples=[%s]" % [
			starter_id,
			good_count,
			sample_count,
			rate,
			first_good_count,
			sample_count,
			first_rate,
			no_good_count,
			first_no_good_count,
			blocked_count,
			axiom_count,
			";".join(_string_array(starter_stats.get("no_good_examples", []))),
			";".join(_string_array(starter_stats.get("first_no_good_examples", []))),
			";".join(_string_array(starter_stats.get("blocked_examples", []))),
		])
	return " ".join(parts)

func _sorted_keys(stats: Dictionary[String, Variant]) -> Array[String]:
	var keys: Array[String] = []
	for key: String in stats.keys():
		keys.append(key)
	keys.sort()
	return keys

func _has_any(values: Array[String], targets: Array[String]) -> bool:
	for target: String in targets:
		if values.has(target):
			return true
	return false

func _first_offer_id(offers: Array[ShopOffer]) -> String:
	if offers.is_empty() or offers[0] == null:
		return ""
	return String(offers[0].id)

func _starter_ids() -> Array[String]:
	var ids: Array[String] = ["axiom", "bo", "bonko", "mara", "korath", "morrak", "mortem", "repo", "sari"]
	return ids

func _good_helpers_for(starter_id: String) -> Array[String]:
	var helpers: Array[String] = []
	match starter_id:
		"axiom":
			helpers.append("sari")
		"bo":
			helpers.append("berebell")
			helpers.append("grint")
		"bonko":
			helpers.append("morrak")
			helpers.append("grint")
			helpers.append("mortem")
		"mara":
			helpers.append("brute")
			helpers.append("bonko")
		"korath":
			helpers.append("bonko")
			helpers.append("sari")
			helpers.append("morrak")
			helpers.append("berebell")
		"morrak":
			helpers.append("berebell")
			helpers.append("sari")
			helpers.append("bonko")
		"mortem":
			helpers.append("morrak")
			helpers.append("bonko")
			helpers.append("sari")
			helpers.append("berebell")
		"repo":
			helpers.append("berebell")
			helpers.append("bonko")
			helpers.append("sari")
		"sari":
			helpers.append("bonko")
			helpers.append("grint")
			helpers.append("brute")
			helpers.append("berebell")
			helpers.append("morrak")
	return helpers

func _blocked_helpers_for(starter_id: String) -> Array[String]:
	var helpers: Array[String] = []
	var raw_helpers: Array = ShopConfigScript.FIRST_SHOP_BLOCKED_HELPERS_BY_STARTER.get(starter_id, []) as Array
	for raw_helper: Variant in raw_helpers:
		helpers.append(String(raw_helper))
	return helpers

func _expected_blocked_helpers_for(starter_id: String) -> Array[String]:
	var helpers: Array[String] = []
	var raw_helpers: Array = EXPECTED_BLOCKED_HELPERS_BY_STARTER.get(starter_id, []) as Array
	for raw_helper: Variant in raw_helpers:
		helpers.append(String(raw_helper))
	return helpers

func _string_array(values: Variant) -> Array[String]:
	var output: Array[String] = []
	if values is Array:
		for value: Variant in values:
			output.append(String(value))
	elif values is PackedStringArray:
		var packed_values: PackedStringArray = values as PackedStringArray
		for value: String in packed_values:
			output.append(value)
	elif typeof(values) == TYPE_STRING:
		output.append(String(values))
	return output

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
