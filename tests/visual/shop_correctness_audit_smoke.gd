extends Node

const Unit := preload("res://scripts/unit.gd")
const UnitCatalogScript: Script = preload("res://scripts/game/shop/unit_catalog.gd")
const ShopRngScript: Script = preload("res://scripts/game/shop/shop_rng.gd")
const ShopRollerScript: Script = preload("res://scripts/game/shop/shop_roller.gd")
const ShopOddsScript: Script = preload("res://scripts/game/shop/shop_odds.gd")
const ShopConfigScript: Script = preload("res://scripts/game/shop/shop_config.gd")
const ShopAffordabilityScript: Script = preload("res://scripts/game/shop/affordability.gd")
const ShopTransactionsScript: Script = preload("res://scripts/game/shop/shop_transactions.gd")
const PlayerProgressScript: Script = preload("res://scripts/game/shop/player_progress.gd")
const ShopErrorsScript: Script = preload("res://scripts/game/shop/shop_errors.gd")
const ShopStateScript: Script = preload("res://scripts/game/shop/shop_state.gd")

class FullBench:
	func first_empty_slot() -> int:
		return -1

	func set_slot(_slot: int, _unit: Unit) -> bool:
		return false

const SMOKE_NAME: String = "ShopCorrectnessAuditSmoke"
const OPENING_SAMPLE_COUNT: int = 48
const DUPLICATE_SAMPLE_COUNT: int = 200
const DETERMINISM_SEED: int = 80402026

var _failures: Array[String] = []
var _opening_flood_examples: Array[String] = []

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var catalog: UnitCatalog = UnitCatalogScript.new()
	catalog.refresh()
	var rng: ShopRng = ShopRngScript.new()
	var roller: ShopRoller = ShopRollerScript.new()
	roller.configure(catalog, rng)
	_assert_cost_pools(catalog, roller, rng)
	_assert_deterministic_rolls(roller, rng)
	_assert_generic_duplicates_are_allowed(roller, rng)
	_assert_opening_choice_quality(catalog, roller, rng)
	_assert_affordability_reserves_wager()
	_assert_lock_reroll_and_bench_full(catalog, roller)
	_assert_buy_xp_at_max_level_is_transactional(roller)
	_finish()

func _assert_cost_pools(catalog: UnitCatalog, roller: ShopRoller, rng: ShopRng) -> void:
	var max_level: int = int(ShopConfigScript.MAX_LEVEL)
	for level: int in range(int(ShopConfigScript.MIN_LEVEL), max_level + 1):
		var probabilities: Dictionary = ShopOddsScript.get_cost_probabilities(level)
		var total: float = 0.0
		for raw_cost: Variant in probabilities.keys():
			var cost: int = int(raw_cost)
			_expect(ShopConfigScript.VALID_COSTS.has(cost), "level %d exposed invalid cost tier %d" % [level, cost])
			_expect(cost <= level, "level %d exposed cost-%d offer" % [level, cost])
			total += float(probabilities[raw_cost])
		_expect(is_equal_approx(total, 1.0), "level %d cost odds should normalize to 1.0, got %.6f" % [level, total])
		rng.set_seed(910000 + level)
		var offers: Array[ShopOffer] = roller.roll(level, int(ShopConfigScript.SLOT_COUNT) * 12)
		_expect(not offers.is_empty(), "level %d should produce offers" % level)
		for offer: ShopOffer in offers:
			if offer == null:
				continue
			_expect(offer.cost > 0, "level %d produced an empty-cost offer" % level)
			_expect(offer.cost <= level, "level %d roll produced cost-%d offer" % [level, offer.cost])
			_expect(catalog.has_id(String(offer.id)), "level %d roll produced unknown unit %s" % [level, String(offer.id)])

func _assert_deterministic_rolls(roller: ShopRoller, rng: ShopRng) -> void:
	rng.set_seed(DETERMINISM_SEED)
	var first: Array[ShopOffer] = roller.roll(int(ShopConfigScript.MAX_LEVEL), int(ShopConfigScript.SLOT_COUNT))
	var first_ids: Array[String] = _offer_ids(first)
	rng.set_seed(DETERMINISM_SEED)
	var second: Array[ShopOffer] = roller.roll(int(ShopConfigScript.MAX_LEVEL), int(ShopConfigScript.SLOT_COUNT))
	var second_ids: Array[String] = _offer_ids(second)
	_expect(first_ids == second_ids, "same seed should reproduce the same shop offers (%s vs %s)" % [first_ids, second_ids])

func _assert_generic_duplicates_are_allowed(roller: ShopRoller, rng: ShopRng) -> void:
	var duplicate_seen: bool = false
	for sample_index: int in range(DUPLICATE_SAMPLE_COUNT):
		rng.set_seed(120000 + sample_index)
		var offers: Array[ShopOffer] = roller.roll(int(ShopConfigScript.MAX_LEVEL), int(ShopConfigScript.SLOT_COUNT))
		var ids: Array[String] = _offer_ids(offers)
		if _has_duplicate(ids):
			duplicate_seen = true
			break
	_expect(duplicate_seen, "normal shop rolls should retain legitimate duplicate offers")

func _assert_opening_choice_quality(catalog: UnitCatalog, roller: ShopRoller, rng: ShopRng) -> void:
	var starter_ids: Array[String] = _configured_starter_ids(catalog)
	for starter_id: String in starter_ids:
		var blocked_ids: Array[String] = _blocked_ids(starter_id)
		var eligible_cost_one_ids: Array[String] = []
		for candidate_id: String in catalog.get_ids_by_cost(1):
			if not blocked_ids.has(candidate_id):
				eligible_cost_one_ids.append(candidate_id)
		var can_offer_choice: bool = eligible_cost_one_ids.size() >= 2
		for sample_index: int in range(OPENING_SAMPLE_COUNT):
			var seed: int = 260626 + sample_index
			rng.set_seed(seed)
			var offers: Array[ShopOffer] = roller.roll_opening_for_starter(starter_id, int(ShopConfigScript.STARTING_LEVEL), int(ShopConfigScript.SLOT_COUNT))
			var ids: Array[String] = _offer_ids(offers)
			var helpers: Array[String] = _helper_ids(starter_id)
			_expect(offers.size() == int(ShopConfigScript.SLOT_COUNT), "%s seed %d should have five opening offers" % [starter_id, seed])
			_expect(not ids.is_empty() and helpers.has(ids[0]), "%s seed %d should put a viable helper in slot 1, got %s" % [starter_id, seed, ids])
			_expect(not _has_any(ids, blocked_ids), "%s seed %d exposed a blocked opening unit: %s" % [starter_id, seed, ids])
			if can_offer_choice and _unique_ids(ids).size() < 2:
				if _opening_flood_examples.size() < 12:
					_opening_flood_examples.append("%s seed=%d offers=%s" % [starter_id, seed, ids])
				_expect(false, "%s seed %d should expose at least two distinct opening choices when two eligible cost-1 units exist" % [starter_id, seed])

func _assert_affordability_reserves_wager() -> void:
	var denied: Dictionary = ShopAffordabilityScript.can_afford(4, 1, 4, false, 0)
	var allowed: Dictionary = ShopAffordabilityScript.can_afford(5, 1, 4, false, 0)
	_expect(not bool(denied.get("ok", false)), "4g should not permit a 4g purchase while reserving 1g")
	_expect(int(denied.get("need_more", 0)) == 1, "4g reserve-floor denial should report one gold needed")
	_expect(bool(allowed.get("ok", false)), "5g should permit a 4g purchase while reserving 1g")

func _assert_lock_reroll_and_bench_full(catalog: UnitCatalog, roller: ShopRoller) -> void:
	var transactions: ShopTransactions = ShopTransactionsScript.new()
	var offers: Array[ShopOffer] = roller.roll(int(ShopConfigScript.STARTING_LEVEL), int(ShopConfigScript.SLOT_COUNT))
	var state: ShopState = ShopStateScript.new(offers, false, 1)
	var locked_state: ShopState = transactions.toggle_lock(state)
	_expect(locked_state.locked, "lock toggle should persist a locked shop state")
	_expect(_offer_ids(locked_state.offers) == _offer_ids(state.offers), "lock toggle should preserve offers")
	_expect(locked_state.free_rerolls == state.free_rerolls, "lock toggle should preserve free rerolls")
	transactions.configure(roller, null)
	var reroll_result: Dictionary = transactions.reroll(locked_state, int(ShopConfigScript.STARTING_LEVEL), 5)
	_expect(bool(reroll_result.get("ok", false)), "reroll should be allowed with a locked state when configured to clear lock")
	var rerolled_state: ShopState = reroll_result.get("state", null) as ShopState
	_expect(rerolled_state != null and not rerolled_state.locked, "paid reroll should clear the lock when configured")
	_expect(int(reroll_result.get("gold_spent", -1)) == 0, "free reroll should consume a free charge before gold")

	var full_bench: RefCounted = FullBench.new()
	transactions.configure(roller, full_bench)
	var one_offer: Array[ShopOffer] = roller.roll(int(ShopConfigScript.STARTING_LEVEL), 1)
	var full_state: ShopState = ShopStateScript.new(one_offer)
	var buy_result: Dictionary = transactions.buy_unit(full_state, 0, 5, int(ShopConfigScript.STARTING_LEVEL))
	_expect(not bool(buy_result.get("ok", false)), "bench-full purchase should be rejected")
	_expect(String(buy_result.get("error", "")) == String(ShopErrorsScript.BENCH_FULL), "bench-full purchase should return BENCH_FULL, got %s" % String(buy_result.get("error", "")))

func _assert_buy_xp_at_max_level_is_transactional(roller: ShopRoller) -> void:
	var progress: PlayerProgress = PlayerProgressScript.new()
	progress.set_level(int(ShopConfigScript.MAX_LEVEL))
	var transactions: ShopTransactions = ShopTransactionsScript.new()
	transactions.configure(roller, null)
	var result: Dictionary = transactions.buy_xp(progress, int(ShopConfigScript.BUY_XP_COST) + 2)
	_expect(not bool(result.get("ok", false)), "Buy XP at max level should be rejected before spending")
	_expect(String(result.get("error", "")) == String(ShopErrorsScript.MAX_LEVEL), "Buy XP at max level should return MAX_LEVEL, got %s" % String(result.get("error", "")))
	_expect(progress.is_at_max_level(), "max-level progress should remain at max level after rejected Buy XP")
	_expect(progress.xp == 0, "max-level progress should not accumulate hidden XP")

func _configured_starter_ids(catalog: UnitCatalog) -> Array[String]:
	var ids: Array[String] = []
	for raw_id: Variant in ShopConfigScript.FIRST_SHOP_HELPERS_BY_STARTER.keys():
		var starter_id: String = String(raw_id)
		if catalog.has_id(starter_id):
			ids.append(starter_id)
	ids.sort()
	return ids

func _helper_ids(starter_id: String) -> Array[String]:
	var helpers: Array[String] = []
	var raw_helpers: Array = ShopConfigScript.FIRST_SHOP_HELPERS_BY_STARTER.get(starter_id, []) as Array
	for raw_helper: Variant in raw_helpers:
		var helper_id: String = String(raw_helper)
		if not helpers.has(helper_id):
			helpers.append(helper_id)
	return helpers

func _blocked_ids(starter_id: String) -> Array[String]:
	var blocked: Array[String] = []
	var raw_ids: Array = ShopConfigScript.FIRST_SHOP_BLOCKED_HELPERS_BY_STARTER.get(starter_id, []) as Array
	for raw_id: Variant in raw_ids:
		blocked.append(String(raw_id))
	return blocked

func _offer_ids(offers: Array[ShopOffer]) -> Array[String]:
	var ids: Array[String] = []
	for offer: ShopOffer in offers:
		if offer != null:
			ids.append(String(offer.id))
	return ids

func _unique_ids(ids: Array[String]) -> Array[String]:
	var unique: Array[String] = []
	for id: String in ids:
		if not unique.has(id):
			unique.append(id)
	return unique

func _has_duplicate(ids: Array[String]) -> bool:
	return _unique_ids(ids).size() < ids.size()

func _has_any(values: Array[String], targets: Array[String]) -> bool:
	for target: String in targets:
		if values.has(target):
			return true
	return false

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

func _finish() -> void:
	if _failures.is_empty():
		print("%s: PASS opening_flood_examples=%s" % [SMOKE_NAME, _opening_flood_examples])
		get_tree().quit(0)
		return
	for failure: String in _failures:
		push_error("%s: %s" % [SMOKE_NAME, failure])
	if not _opening_flood_examples.is_empty():
		push_error("%s: opening flood examples=%s" % [SMOKE_NAME, _opening_flood_examples])
	get_tree().quit(1)
