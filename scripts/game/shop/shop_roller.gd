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
	if existing_index > 0:
		var existing_helper: ShopOffer = offers[existing_index]
		offers[existing_index] = offers[0]
		offers[0] = existing_helper
	elif existing_index == -1:
		var helper_id: String = _pick_opening_helper_id(helper_ids)
		if helper_id != "":
			var helper_offer: ShopOffer = _offer_for_id(helper_id)
			if helper_offer != null:
				if offers.size() < int(count):
					offers.insert(0, helper_offer)
				else:
					offers[0] = helper_offer
	_ensure_opening_choice_diversity(starter_id, offers, helper_ids)
	return offers

func _replace_blocked_opening_helpers(starter_id: String, offers: Array[ShopOffer], helper_ids: Array[String]) -> void:
	var blocked_ids: Array[String] = _opening_blocked_helper_ids(starter_id)
	if blocked_ids.is_empty():
		return
	for index: int in range(offers.size()):
		var offer: ShopOffer = offers[index]
		if offer == null or not blocked_ids.has(String(offer.id)):
			continue
		var replacement_id: String = _pick_opening_replacement_id(starter_id, int(offer.cost), helper_ids, offers)
		var replacement_offer: ShopOffer = _offer_for_id(replacement_id)
		if replacement_offer != null:
			offers[index] = replacement_offer

func _ensure_opening_choice_diversity(starter_id: String, offers: Array[ShopOffer], helper_ids: Array[String]) -> void:
	if offers.size() < 2:
		return
	var unique_ids: Array[String] = _unique_offer_ids(offers)
	if unique_ids.size() >= 2:
		return
	var repeated_id: String = unique_ids[0] if not unique_ids.is_empty() else ""
	if repeated_id == "":
		return
	var repeated_offer: ShopOffer = offers[0]
	if repeated_offer == null:
		return
	var candidate_ids: Array[String] = _opening_non_helper_ids(starter_id, int(repeated_offer.cost), helper_ids, repeated_id)
	if candidate_ids.is_empty():
		candidate_ids = _opening_alternative_ids(starter_id, int(repeated_offer.cost), repeated_id)
	if candidate_ids.is_empty():
		return
	var replacement_id: String = _pick_lowest_usage_id(candidate_ids, offers)
	var replacement_offer: ShopOffer = _offer_for_id(replacement_id)
	if replacement_offer == null:
		return
	for index: int in range(1, offers.size()):
		var offer: ShopOffer = offers[index]
		if offer != null and String(offer.id) == repeated_id:
			offers[index] = replacement_offer
			return

func _pick_opening_replacement_id(starter_id: String, cost: int, helper_ids: Array[String], offers: Array[ShopOffer]) -> String:
	var blocked_ids: Array[String] = _opening_blocked_helper_ids(starter_id)
	var preferred_ids: Array[String] = []
	var fallback_ids: Array[String] = []
	for candidate_id: String in _catalog.get_ids_by_cost(cost):
		if blocked_ids.has(candidate_id):
			continue
		fallback_ids.append(candidate_id)
		if not helper_ids.has(candidate_id) or _offer_id_count(offers, candidate_id) == 0:
			preferred_ids.append(candidate_id)
	var candidates: Array[String] = preferred_ids if not preferred_ids.is_empty() else fallback_ids
	return _pick_lowest_usage_id(candidates, offers)

func _opening_non_helper_ids(starter_id: String, cost: int, helper_ids: Array[String], excluded_id: String) -> Array[String]:
	var blocked_ids: Array[String] = _opening_blocked_helper_ids(starter_id)
	var candidates: Array[String] = []
	for candidate_id: String in _catalog.get_ids_by_cost(cost):
		if candidate_id == excluded_id or blocked_ids.has(candidate_id) or helper_ids.has(candidate_id):
			continue
		candidates.append(candidate_id)
	return candidates

func _opening_alternative_ids(starter_id: String, cost: int, excluded_id: String) -> Array[String]:
	var blocked_ids: Array[String] = _opening_blocked_helper_ids(starter_id)
	var candidates: Array[String] = []
	for candidate_id: String in _catalog.get_ids_by_cost(cost):
		if candidate_id == excluded_id or blocked_ids.has(candidate_id):
			continue
		candidates.append(candidate_id)
	return candidates

func _pick_lowest_usage_id(candidate_ids: Array[String], offers: Array[ShopOffer]) -> String:
	if candidate_ids.is_empty():
		return ""
	var min_count: int = 2147483647
	var least_used_ids: Array[String] = []
	for candidate_id: String in candidate_ids:
		var usage_count: int = _offer_id_count(offers, candidate_id)
		if usage_count < min_count:
			min_count = usage_count
			least_used_ids.clear()
			least_used_ids.append(candidate_id)
		elif usage_count == min_count:
			least_used_ids.append(candidate_id)
	if _rng != null:
		return String(_rng.pick(least_used_ids))
	return least_used_ids[0]

func _offer_id_count(offers: Array[ShopOffer], candidate_id: String) -> int:
	var count: int = 0
	for offer: ShopOffer in offers:
		if offer != null and String(offer.id) == candidate_id:
			count += 1
	return count

func _unique_offer_ids(offers: Array[ShopOffer]) -> Array[String]:
	var unique_ids: Array[String] = []
	for offer: ShopOffer in offers:
		if offer != null and not unique_ids.has(String(offer.id)):
			unique_ids.append(String(offer.id))
	return unique_ids

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
