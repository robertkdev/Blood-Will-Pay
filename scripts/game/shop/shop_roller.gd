extends RefCounted
class_name ShopRoller

const ShopConfig := preload("res://scripts/game/shop/shop_config.gd")
const ShopOdds := preload("res://scripts/game/shop/shop_odds.gd")
const ShopOffer := preload("res://scripts/game/shop/shop_offer.gd")

var _catalog: UnitCatalog
var _rng: ShopRng

func configure(catalog: UnitCatalog, rng: ShopRng) -> void:
	_catalog = catalog
	_rng = rng

func clear_runtime() -> void:
	_catalog = null
	_rng = null

func roll(level: int, count: int = ShopConfig.SLOT_COUNT) -> Array[ShopOffer]:
	# Generate up to `count` offers using odds by level and the unit catalog.
	var out: Array[ShopOffer] = []
	if _catalog == null:
		return out
	_catalog.ensure_ready()
	var probs: Dictionary = ShopOdds.get_cost_probabilities(int(level))
	# Filter to costs that have at least one unit in the catalog
	var filtered: Dictionary = {}
	for k in probs.keys():
		var c: int = int(k)
		if _catalog.count_by_cost(c) > 0:
			filtered[c] = float(probs[k])
	if filtered.is_empty():
		# As a fallback, consider any catalog cost equally
		for c in _catalog.get_all_costs():
			filtered[int(c)] = 1.0
	if filtered.is_empty():
		return out

	var used: Dictionary = {}
	var allow_dupes: bool = bool(ShopConfig.ALLOW_DUPLICATES)
	var n: int = max(0, int(count))
	for _i in range(n):
		# Choose a cost tier per odds
		var cost: int = int(_rng.pick_weighted(filtered))
		var offer_id: String = _pick_id_for_cost(cost, allow_dupes, used)
		if offer_id == "":
			# Try other costs in order of current filtered keys
			for kc in filtered.keys():
				offer_id = _pick_id_for_cost(int(kc), allow_dupes, used)
				if offer_id != "":
					cost = int(kc)
					break
		if offer_id == "":
			break
		var offer: ShopOffer = _offer_for_id(offer_id)
		out.append(offer)
		if not allow_dupes:
			used[offer_id] = true
	return out

func roll_opening_for_starter(starter_id: String, level: int, count: int = ShopConfig.SLOT_COUNT) -> Array[ShopOffer]:
	var offers: Array[ShopOffer] = roll(level, count)
	var helper_ids: Array[String] = _opening_helper_ids(starter_id)
	if helper_ids.is_empty() or offers.is_empty():
		return offers
	_replace_blocked_opening_helpers(starter_id, offers, helper_ids)
	var existing_index: int = _index_of_any_offer(offers, helper_ids)
	if existing_index == 0:
		return offers
	if existing_index > 0:
		var existing_helper: ShopOffer = offers[existing_index]
		offers[existing_index] = offers[0]
		offers[0] = existing_helper
		return offers
	var helper_id: String = _pick_opening_helper_id(helper_ids)
	if helper_id == "":
		return offers
	var helper_offer: ShopOffer = _offer_for_id(helper_id)
	if helper_offer == null:
		return offers
	if offers.size() < int(count):
		offers.insert(0, helper_offer)
	else:
		offers[0] = helper_offer
	return offers

func _replace_blocked_opening_helpers(starter_id: String, offers: Array[ShopOffer], helper_ids: Array[String]) -> void:
	var blocked_ids: Array[String] = _opening_blocked_helper_ids(starter_id)
	if blocked_ids.is_empty():
		return
	for index: int in range(offers.size()):
		var offer: ShopOffer = offers[index]
		if offer == null or not blocked_ids.has(String(offer.id)):
			continue
		var replacement_id: String = _pick_opening_helper_id(helper_ids)
		var replacement_offer: ShopOffer = _offer_for_id(replacement_id)
		if replacement_offer != null:
			offers[index] = replacement_offer

func _pick_id_for_cost(cost: int, allow_dupes: bool, used: Dictionary) -> String:
	var ids: Array[String] = _catalog.get_ids_by_cost(cost)
	if ids.is_empty():
		return ""
	if allow_dupes:
		return _catalog.pick_id_by_cost(cost, _rng)
	# No duplicates: try a few random picks to avoid bias
	var attempts: int = min(8, ids.size())
	for _a in range(attempts):
		var candidate: String = _catalog.pick_id_by_cost(cost, _rng)
		if candidate != "" and not used.has(candidate):
			return candidate
	# Fallback: linear scan for first unused
	for id: String in ids:
		var sid: String = String(id)
		if not used.has(sid):
			return sid
	return ""

func _opening_helper_ids(starter_id: String) -> Array[String]:
	var helpers: Array[String] = []
	var raw_helpers: Array = ShopConfig.FIRST_SHOP_HELPERS_BY_STARTER.get(String(starter_id), []) as Array
	for raw_helper: Variant in raw_helpers:
		var helper_id: String = String(raw_helper)
		if _catalog.has_id(helper_id):
			helpers.append(helper_id)
	return helpers

func _opening_blocked_helper_ids(starter_id: String) -> Array[String]:
	var blocked_helpers: Array[String] = []
	var raw_helpers: Array = ShopConfig.FIRST_SHOP_BLOCKED_HELPERS_BY_STARTER.get(String(starter_id), []) as Array
	for raw_helper: Variant in raw_helpers:
		var helper_id: String = String(raw_helper)
		if _catalog.has_id(helper_id):
			blocked_helpers.append(helper_id)
	return blocked_helpers

func _index_of_any_offer(offers: Array[ShopOffer], helper_ids: Array[String]) -> int:
	for index: int in range(offers.size()):
		var offer: ShopOffer = offers[index]
		if offer != null and helper_ids.has(String(offer.id)):
			return index
	return -1

func _pick_opening_helper_id(helper_ids: Array[String]) -> String:
	if helper_ids.is_empty():
		return ""
	if _rng != null:
		return String(_rng.pick(helper_ids))
	return helper_ids[0]

func _offer_for_id(unit_id: String) -> ShopOffer:
	if _catalog == null or not _catalog.has_id(unit_id):
		return null
	return ShopOffer.new(
		unit_id,
		_catalog.get_name(unit_id),
		_catalog.get_cost(unit_id),
		_catalog.get_sprite_path(unit_id),
		_catalog.get_roles(unit_id),
		_catalog.get_traits(unit_id),
		_catalog.get_primary_role(unit_id),
		_catalog.get_primary_goal(unit_id),
		_catalog.get_approaches(unit_id),
		_catalog.get_identity_path(unit_id),
		_catalog.get_alt_goals(unit_id)
	)
