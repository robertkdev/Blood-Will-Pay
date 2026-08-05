extends RefCounted
class_name ShopTransactions

const UnitUpgradePaths := preload("res://scripts/game/units/unit_upgrade_paths.gd")

const ShopConfig := preload("res://scripts/game/shop/shop_config.gd")
const ShopErrors := preload("res://scripts/game/shop/shop_errors.gd")
const ShopAffordability := preload("res://scripts/game/shop/affordability.gd")
const UnitFactory := preload("res://scripts/unit_factory.gd")
const PlayerProgress := preload("res://scripts/game/shop/player_progress.gd")
const CombineService := preload("res://scripts/game/shop/combine_service.gd")

var _roller: ShopRoller
var _roster
var _combiner: CombineService
var _remove_from_board_cb: Callable = Callable()
var _board_team_provider: Callable = Callable()

func configure(roller: ShopRoller, roster = null) -> void:
	_roller = roller
	_roster = roster
	_combiner = CombineService.new()
	_combiner.configure(_roster if _roster != null else (Roster if Engine.has_singleton("Roster") else null))

func set_board_team_provider(cb: Callable) -> void:
	_board_team_provider = cb if cb != null else Callable()
	if _combiner != null and cb != null:
		_combiner.set_team_provider(cb)

func set_remove_from_board(cb: Callable) -> void:
	if _combiner != null and cb != null:
		_combiner.set_remove_from_board(cb)
	# Also keep a direct reference for selling from board
	_remove_from_board_cb = cb if cb != null else Callable()

func combine_now() -> Array:
	# Public helper to attempt a combine immediately using current bench + board.
	# Returns the list of promotion dicts (same shape as buy_unit result) for UI effects.
	var promos: Array = []
	if _combiner != null:
		var res: Variant = _combiner.combine()
		if res is Array:
			promos = res.duplicate()
	return promos

func toggle_lock(state: ShopState) -> ShopState:
	# Returns a new state with lock flipped. Offers and free_rerolls preserved.
	var locked: bool = not bool(state.locked)
	return ShopState.new(state.offers, locked, state.free_rerolls)

func reroll(state: ShopState, level: int, available_gold: int, opening_starter_id: String = "", quoted_cost: int = ShopConfig.REROLL_COST) -> Dictionary:
	# Fail fast; no side-effects outside the returned payload.
	# Returns { ok: bool, error?: String, state?: ShopState, gold_spent?: int }
	if _roller == null:
		return { "ok": false, "error": ShopErrors.UNKNOWN }

	# Lock handling
	var locked_now: bool = bool(state.locked)
	if locked_now and not ShopConfig.CLEAR_LOCK_ON_REROLL:
		return { "ok": false, "error": ShopErrors.SHOP_LOCKED }

	# Cost computation (free reroll consumes a charge)
	var cost: int = max(0, int(quoted_cost))
	var new_free: int = int(state.free_rerolls)
	if new_free > 0:
		cost = 0
		new_free = max(0, new_free - 1)

	# Affordability check (phase-aware)
	var in_combat: bool = false
	if Engine.has_singleton("GameState"):
		in_combat = (GameState.phase == GameState.GamePhase.COMBAT)
	var bet: int = (int(Economy.current_bet) if Engine.has_singleton("Economy") else 0)
	var spent: int = ((int(Economy.combat_spent) if Engine.has_singleton("Economy") else 0) if in_combat else 0)
	var aff: Dictionary = ShopAffordability.can_afford(int(available_gold), bet, cost, in_combat, spent)
	if not bool(aff.get("ok", false)):
		return { "ok": false, "error": ShopErrors.WOULD_KILL_YOU, "need_more": int(aff.get("need_more", 0)) }

	# Generate new offers
	var offers: Array[ShopOffer] = []
	if String(opening_starter_id) != "" and _roller.has_method("roll_opening_for_starter"):
		offers = _roller.roll_opening_for_starter(String(opening_starter_id), int(level), int(ShopConfig.SLOT_COUNT))
	else:
		offers = _roller.roll(int(level), int(ShopConfig.SLOT_COUNT))
	if offers.is_empty():
		return { "ok": false, "error": ShopErrors.NO_OFFERS }

	# Clear lock if configured; otherwise preserve (should not reach here if locked and not clearing)
	var next_locked: bool = false if ShopConfig.CLEAR_LOCK_ON_REROLL else bool(state.locked)
	var new_state: ShopState = ShopState.new(offers, next_locked, new_free)
	return { "ok": true, "state": new_state, "gold_spent": cost }

func buy_xp(progress: PlayerProgress, available_gold: int, quoted_cost: int = ShopConfig.BUY_XP_COST) -> Dictionary:
	# Returns { ok: bool, error?: String, gold_spent?: int, level?: int, xp?: int, xp_to_next?: int }
	var cost: int = max(0, int(quoted_cost))
	var in_combat: bool = false
	if Engine.has_singleton("GameState"):
		in_combat = (GameState.phase == GameState.GamePhase.COMBAT)
	var bet: int = (int(Economy.current_bet) if Engine.has_singleton("Economy") else 0)
	var spent: int = (int(Economy.combat_spent) if in_combat and Engine.has_singleton("Economy") else 0)
	var aff: Dictionary = ShopAffordability.can_afford(int(available_gold), bet, cost, in_combat, spent)
	if not bool(aff.get("ok", false)):
		return { "ok": false, "error": ShopErrors.WOULD_KILL_YOU, "need_more": int(aff.get("need_more", 0)) }
	if progress == null:
		return { "ok": false, "error": ShopErrors.UNKNOWN }
	var progress_result: Dictionary = progress.purchase_progression()
	if not bool(progress_result.get("ok", true)):
		return {
			"ok": false,
			"error": String(progress_result.get("error", ShopErrors.ACTION_FAILED)),
			"command_points": int(progress_result.get("command_points", 0)),
			"command_rank": int(progress_result.get("command_rank", 0)),
		}
	var result: Dictionary = {
		"ok": true,
		"gold_spent": cost,
		"level": int(progress.level),
		"xp": int(progress.xp),
		"xp_to_next": int(progress.xp_to_next()),
	}
	result.merge(progress_result, true)
	return result

func buy_unit(state: ShopState, slot_index: int, available_gold: int, _level: int) -> Dictionary:
	# Returns { ok, state?, gold_spent?, bench_slot?, unit_id?, error? }
	if _roller == null:
		return { "ok": false, "error": ShopErrors.UNKNOWN }
	if state == null or state.offers == null or state.offers.is_empty():
		return { "ok": false, "error": ShopErrors.NO_OFFERS }
	var idx: int = int(slot_index)
	if idx < 0 or idx >= state.offers.size():
		return { "ok": false, "error": ShopErrors.INVALID_SLOT }
	var offer: ShopOffer = state.offers[idx]
	if offer == null:
		return { "ok": false, "error": ShopErrors.INVALID_SLOT }
	var cost: int = int(offer.price) if int(offer.price) > 0 else int(offer.cost)
	# Affordability (phase-aware)
	var in_combat: bool = false
	if Engine.has_singleton("GameState"):
		in_combat = (GameState.phase == GameState.GamePhase.COMBAT)
	var bet: int = (int(Economy.current_bet) if Engine.has_singleton("Economy") else 0)
	var spent: int = (int(Economy.combat_spent) if in_combat and Engine.has_singleton("Economy") else 0)
	var aff: Dictionary = ShopAffordability.can_afford(int(available_gold), bet, cost, in_combat, spent)
	if not bool(aff.get("ok", false)):
		return { "ok": false, "error": ShopErrors.WOULD_KILL_YOU, "need_more": int(aff.get("need_more", 0)) }
	# Roster capacity
	var bench_slot: int = -1
	if _roster != null and _roster.has_method("first_empty_slot"):
		bench_slot = int(_roster.first_empty_slot())
	elif Engine.has_singleton("Roster"):
		bench_slot = int(Roster.first_empty_slot())
	if bench_slot == -1:
		return { "ok": false, "error": ShopErrors.BENCH_FULL }
	# Spawn unit
	var u: Unit = UnitFactory.spawn_at_level(String(offer.id), max(1, int(offer.package_level)))
	if u == null:
		return { "ok": false, "error": ShopErrors.UNKNOWN }
	u.purchase_value = cost
	u.market_package_kind = String(offer.package_kind)
	if u.market_package_kind == "current_grade":
		UnitUpgradePaths.apply_capital_charter(u)
	# Place in bench
	var placed: bool = false
	if _roster != null and _roster.has_method("set_slot"):
		placed = bool(_roster.set_slot(bench_slot, u))
	elif Engine.has_singleton("Roster"):
		placed = bool(Roster.set_slot(bench_slot, u))
	if not placed:
		return { "ok": false, "error": ShopErrors.BENCH_FULL }
	# Leave the purchased slot as a blank placeholder to preserve layout and indicate sold/empty
	var new_offers: Array[ShopOffer] = state.offers.duplicate()
	new_offers[idx] = ShopOffer.new("", "", 0, "")
	var new_state: ShopState = ShopState.new(new_offers, state.locked, state.free_rerolls)
	# Attempt bench/board combines (chained) and capture results
	var promotions: Array = []
	if _combiner != null:
		var comb_res: Variant = _combiner.combine()
		if comb_res is Array:
			promotions = comb_res.duplicate()
	return { "ok": true, "state": new_state, "gold_spent": cost, "bench_slot": bench_slot, "unit_id": String(offer.id), "promotions": promotions }

func sell_unit(u: Unit) -> Dictionary:
	if u == null:
		return { "ok": false, "error": ShopErrors.INVALID_UNIT }
	if _is_combat_phase():
		return { "ok": false, "error": ShopErrors.COMBAT_PHASE }
	var roster_ref: Variant = _effective_roster()
	var slot: int = _bench_slot_for(roster_ref, u)
	var removed: bool = false
	if slot != -1:
		removed = _clear_roster_slot(roster_ref, slot, u)
		if not removed:
			return { "ok": false, "error": ShopErrors.ACTION_FAILED }
	else:
		removed = _remove_from_board(u)
		if not removed:
			return { "ok": false, "error": ShopErrors.NOT_FOUND }
	if Engine.has_singleton("Items") and Items.has_method("remove_all"):
		Items.remove_all(u)
	var value: int = _calculate_sell_value(u)
	return { "ok": true, "gold_gained": value }

func _effective_roster():
	if _roster != null:
		return _roster
	if Engine.has_singleton("Roster"):
		return Roster
	return null

func _bench_slot_for(roster_ref, u: Unit) -> int:
	if roster_ref == null or u == null:
		return -1
	if roster_ref.has_method("slot_count") and roster_ref.has_method("get_slot"):
		var count: int = int(roster_ref.slot_count())
		for i in range(count):
			var cur: Unit = roster_ref.get_slot(i)
			if cur == u:
				return i
	return -1

func _clear_roster_slot(roster_ref, slot: int, u: Unit) -> bool:
	if roster_ref == null:
		return false
	var ok: bool = false
	if roster_ref.has_method("set_slot"):
		ok = bool(roster_ref.set_slot(slot, null))
	if not ok and roster_ref.has_method("remove"):
		ok = bool(roster_ref.remove(u))
	return ok

func _remove_from_board(u: Unit) -> bool:
	if u == null:
		return false
	if _remove_from_board_cb != null and _remove_from_board_cb.is_valid():
		var res: Variant = _remove_from_board_cb.call(u)
		if bool(res):
			return true
	if _board_team_provider != null and _board_team_provider.is_valid():
		var team: Variant = _board_team_provider.call()
		if team is Array:
			var arr: Array = team
			for i in range(arr.size()):
				if arr[i] == u:
					arr.remove_at(i)
					return true
	return false

func _calculate_sell_value(u: Unit) -> int:
	if u == null:
		return 0
	if int(u.purchase_value) > 0:
		return int(u.purchase_value)
	var base_cost: int = max(0, int(u.cost))
	var lvl: int = max(1, int(u.level))
	var mult: int = 1
	for _i in range(max(0, lvl - 1)):
		mult *= 3
	return base_cost * mult

func _is_combat_phase() -> bool:
	if Engine.has_singleton("GameState"):
		return int(GameState.phase) == int(GameState.GamePhase.COMBAT)
	return false
