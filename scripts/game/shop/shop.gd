extends Node


const ShopConfig := preload("res://scripts/game/shop/shop_config.gd")
const ShopOffer := preload("res://scripts/game/shop/shop_offer.gd")
const ShopState := preload("res://scripts/game/shop/shop_state.gd")
const ShopErrors := preload("res://scripts/game/shop/shop_errors.gd")
const ShopRng := preload("res://scripts/game/shop/shop_rng.gd")
const ShopRoller := preload("res://scripts/game/shop/shop_roller.gd")
const ShopTransactions := preload("res://scripts/game/shop/shop_transactions.gd")
const UnitCatalog := preload("res://scripts/game/shop/unit_catalog.gd")
const PlayerProgress := preload("res://scripts/game/shop/player_progress.gd")
const StakesMarket := preload("res://scripts/game/economy/stakes_market.gd")
const CommandResearch := preload("res://scripts/game/progression/command_research.gd")
const ChapterContractService := preload("res://scripts/game/progression/chapter_contract_service.gd")
const ShopAffordability := preload("res://scripts/game/shop/affordability.gd")

signal offers_changed(offers: Array)
signal locked_changed(locked: bool)
signal free_rerolls_changed(count: int)
signal error(code: String, context: Dictionary)

var state: ShopState = ShopState.new()

var _rng: ShopRng
var _catalog: UnitCatalog
var _roller: ShopRoller
var _tx: ShopTransactions
var _progress: PlayerProgress
var _contracts: ChapterContractService
var _pending_contract_chapter: int = 0
var _board_team_provider: Callable = Callable()
var _opening_starter_id: String = ""
var _opening_helper_shops_consumed: int = 0
var _opening_retry_team_bonus_active: bool = false
var paid_rerolls: int = 0
var paid_xp_purchases: int = 0
var paid_command_purchases: int = 0

func _ready() -> void:
	_rng = ShopRng.new()
	# Honor debug seed override if configured
	if int(ShopConfig.DEBUG_SEED) >= 0:
		_rng.set_seed(int(ShopConfig.DEBUG_SEED))
		if bool(ShopConfig.DEBUG_VERBOSE):
			print("[Shop] Using debug seed:", int(ShopConfig.DEBUG_SEED))
	else:
		_rng.randomize()
	_catalog = UnitCatalog.new()
	_catalog.refresh()
	_roller = ShopRoller.new()
	_roller.configure(_catalog, _rng)
	_tx = ShopTransactions.new()
	# Pass Roster to transactions for bench capacity and placement
	var roster_ref: Variant = null
	if _has_autoload("Roster"):
		roster_ref = Roster
	_tx.configure(_roller, roster_ref)
	_progress = PlayerProgress.new()
	_contracts = ChapterContractService.new()
	if _has_autoload("GameState") and not GameState.is_connected("stage_changed", Callable(self, "_on_stage_changed")):
		GameState.stage_changed.connect(_on_stage_changed)
	if _has_autoload("GameState") and not GameState.is_connected("chapter_changed", Callable(self, "_on_chapter_changed")):
		GameState.chapter_changed.connect(_on_chapter_changed)
	if _has_autoload("Economy") and not Economy.is_connected("stake_changed", Callable(self, "_on_stake_changed")):
		Economy.stake_changed.connect(_on_stake_changed)
	reset_run()

func _has_autoload(autoload_name: String) -> bool:
	var n: String = String(autoload_name)
	var path: String = "/root/%s" % n
	var node: Node = get_tree().root.get_node_or_null(path)
	return node != null

func _error_context(op: String, res: Dictionary, extra: Dictionary = {}) -> Dictionary:
	var context: Dictionary = extra.duplicate(true)
	context["op"] = op
	if res.has("need_more"):
		context["need_more"] = int(res.get("need_more", 0))
	if res.has("reason"):
		context["reason"] = String(res.get("reason", ""))
	return context

func _is_combat_phase() -> bool:
	if _has_autoload("GameState"):
		var gp: Node = GameState
		if int(gp.phase) == int(gp.GamePhase.COMBAT):
			return true
	if _has_autoload("Economy"):
		return bool(Economy.combat_active)
	return false

func _combat_phase_error(op: String, extra: Dictionary = {}) -> Dictionary:
	var res: Dictionary = { "ok": false, "error": ShopErrors.COMBAT_PHASE }
	error.emit(ShopErrors.COMBAT_PHASE, _error_context(op, res, extra))
	return res

func reset_run() -> void:
	# Clear state for a new run.
	state = ShopState.new([], false if ShopConfig.CLEAR_LOCK_ON_NEW_RUN else state.locked, 0)
	_opening_starter_id = ""
	_opening_helper_shops_consumed = 0
	_opening_retry_team_bonus_active = false
	paid_rerolls = 0
	paid_xp_purchases = 0
	paid_command_purchases = 0
	if _progress:
		_progress.reset()
	if _contracts:
		_contracts.reset()
	_sync_roster_max_team_size()
	_emit_all()

func set_opening_starter_id(starter_id: String) -> void:
	_opening_starter_id = String(starter_id)
	_opening_helper_shops_consumed = 0

func get_level() -> int:
	return int(_progress.level) if _progress else int(ShopConfig.STARTING_LEVEL)

func get_reroll_price() -> int:
	if _has_autoload("Economy") and Economy.has_method("reroll_price"):
		return int(Economy.reroll_price())
	return int(ShopConfig.REROLL_COST)

func get_progression_price() -> int:
	if _has_autoload("Economy") and Economy.has_method("progression_price"):
		return int(Economy.progression_price())
	return int(ShopConfig.BUY_XP_COST)

func get_progression_mode() -> String:
	return _progress.purchase_mode() if _progress != null else "xp"

func get_command_points() -> int:
	return int(_progress.command_points) if _progress != null else 0

func get_command_rank() -> int:
	return int(_progress.command_rank) if _progress != null else 0

func can_purchase_progression() -> bool:
	return _progress != null and _progress.can_purchase_progression()

func get_unlocked_command_doctrines() -> Array[String]:
	return CommandResearch.unlocked_doctrines(get_command_rank())

func apply_command_doctrine(unit: Unit, doctrine_id: String) -> Dictionary:
	return CommandResearch.apply_to_unit(unit, get_command_rank(), doctrine_id)

func get_contract_offers() -> Array[Dictionary]:
	return _contracts.pending_offers.duplicate(true) if _contracts != null else []

func has_pending_contract_choice() -> bool:
	return _contracts != null and _contracts.has_pending_choice()

func buy_contract(index: int) -> Dictionary:
	if _contracts == null:
		return {"ok": false, "error": "NO_CONTRACT_SERVICE"}
	if _is_combat_phase():
		return _combat_phase_error("buy_contract", {"contract_index": int(index)})
	var available_gold: int = int(Economy.gold) if _has_autoload("Economy") else 0
	var offers: Array[Dictionary] = get_contract_offers()
	if index < 0 or index >= offers.size():
		return {"ok": false, "error": "INVALID_CONTRACT"}
	var price: int = max(0, int(offers[index].get("price", 0)))
	var bet: int = int(Economy.current_bet) if _has_autoload("Economy") else 0
	var affordability: Dictionary = ShopAffordability.can_afford(available_gold, bet, price, false, 0)
	if not bool(affordability.get("ok", false)):
		return {
			"ok": false,
			"error": ShopErrors.WOULD_KILL_YOU,
			"need_more": int(affordability.get("need_more", 0)),
			"reason": String(affordability.get("reason", "")),
		}
	var result: Dictionary = _contracts.choose(index, available_gold)
	if not bool(result.get("ok", false)):
		return result
	var cost: int = max(0, int(result.get("gold_spent", 0)))
	if cost > 0 and _has_autoload("Economy"):
		Economy.add_gold(-cost, false, "chapter_contract")
		Economy.set_payout_modifier(float(result.get("pit_payout_multiplier", 1.0)))
	_sync_roster_max_team_size()
	return result

func pass_contract() -> Dictionary:
	return _contracts.pass_choice() if _contracts != null else {"ok": false, "error": "NO_CONTRACT_SERVICE"}

func apply_pending_champion_contract(unit: Unit, doctrine_id: String) -> Dictionary:
	if _contracts == null:
		return {"ok": false, "error": "NO_CONTRACT_SERVICE"}
	if _is_combat_phase():
		return _combat_phase_error("apply_champion_contract")
	if unit == null or not _owned_units().has(unit):
		return {"ok": false, "error": "UNIT_NOT_OWNED"}
	return _contracts.apply_champion_contract(unit, doctrine_id)

func get_contract_enemy_multiplier() -> float:
	return float(_contracts.pit_enemy_multiplier) if _contracts != null else 1.0

func get_contract_battle_config() -> Dictionary:
	return _contracts.battle_config() if _contracts != null else {}

func get_contract_snapshot() -> Dictionary:
	return _contracts.snapshot() if _contracts != null else {}

func restore_contract_snapshot(snapshot_data: Dictionary) -> void:
	if _contracts == null:
		_contracts = ChapterContractService.new()
	_contracts.restore(snapshot_data)
	if _has_autoload("Economy"):
		Economy.set_payout_modifier(_contracts.pit_payout_multiplier)
	_sync_roster_max_team_size()

func snapshot_run_state() -> Dictionary:
	var serialized_offers: Array[Dictionary] = []
	for offer: ShopOffer in state.offers:
		serialized_offers.append(_serialize_offer(offer))
	return {
		"offers": serialized_offers,
		"locked": state.locked,
		"free_rerolls": state.free_rerolls,
		"progress": _progress.snapshot() if _progress != null else {},
		"contracts": get_contract_snapshot(),
		"pending_contract_chapter": _pending_contract_chapter,
		"opening_starter_id": _opening_starter_id,
		"opening_helper_shops_consumed": _opening_helper_shops_consumed,
		"opening_retry_team_bonus_active": _opening_retry_team_bonus_active,
		"paid_rerolls": paid_rerolls,
		"paid_xp_purchases": paid_xp_purchases,
		"paid_command_purchases": paid_command_purchases,
		"rng_seed": _rng.get_seed() if _rng != null else 0,
		"rng_state": _rng.get_state() if _rng != null else 0,
	}

func restore_run_state(snapshot_data: Dictionary) -> void:
	var restored_offers: Array[ShopOffer] = []
	var raw_offers: Variant = snapshot_data.get("offers", [])
	if raw_offers is Array:
		for raw_offer: Variant in raw_offers:
			if raw_offer is Dictionary:
				restored_offers.append(_deserialize_offer(raw_offer as Dictionary))
	state = ShopState.new(
		restored_offers,
		bool(snapshot_data.get("locked", false)),
		max(0, int(snapshot_data.get("free_rerolls", 0)))
	)
	if _progress == null:
		_progress = PlayerProgress.new()
	var progress_value: Variant = snapshot_data.get("progress", {})
	if progress_value is Dictionary:
		_progress.restore(progress_value as Dictionary)
	var contract_value: Variant = snapshot_data.get("contracts", {})
	if contract_value is Dictionary:
		restore_contract_snapshot(contract_value as Dictionary)
	_pending_contract_chapter = max(0, int(snapshot_data.get("pending_contract_chapter", 0)))
	_opening_starter_id = String(snapshot_data.get("opening_starter_id", ""))
	_opening_helper_shops_consumed = max(0, int(snapshot_data.get("opening_helper_shops_consumed", 0)))
	_opening_retry_team_bonus_active = bool(snapshot_data.get("opening_retry_team_bonus_active", false))
	paid_rerolls = max(0, int(snapshot_data.get("paid_rerolls", 0)))
	paid_xp_purchases = max(0, int(snapshot_data.get("paid_xp_purchases", 0)))
	paid_command_purchases = max(0, int(snapshot_data.get("paid_command_purchases", 0)))
	if _rng != null:
		_rng.set_seed(int(snapshot_data.get("rng_seed", _rng.get_seed())))
		if snapshot_data.has("rng_state"):
			_rng.set_state(int(snapshot_data.get("rng_state", 0)))
	_sync_roster_max_team_size()
	_emit_all()

func set_level(lv: int) -> void:
	if _progress:
		_progress.set_level(int(lv))
		_sync_roster_max_team_size()
		# No signal bridging here; UI can subscribe to PlayerProgress later if needed

func add_free_rerolls(n: int) -> void:
	var add: int = max(0, int(n))
	if add == 0:
		return
	state = ShopState.new(state.offers, state.locked, state.free_rerolls + add)
	free_rerolls_changed.emit(state.free_rerolls)

func mark_opening_retry_shop() -> void:
	_opening_retry_team_bonus_active = true
	_sync_roster_max_team_size()

func grant_free_rerolls(n: int) -> void:
	# Alias for external callers (e.g., Trader trait)
	add_free_rerolls(n)

func toggle_lock() -> void:
	if _is_combat_phase():
		_combat_phase_error("toggle_lock")
		return
	var next: ShopState = _tx.toggle_lock(state)
	var changed: bool = next.locked != state.locked
	state = next
	if changed:
		locked_changed.emit(state.locked)

func reroll() -> Dictionary:
	# Spends gold when successful; updates internal state and emits signals.
	if _is_combat_phase():
		return _combat_phase_error("reroll")
	var lvl: int = get_level()
	var gold: int = int(Economy.gold) if _has_autoload("Economy") else 0
	var opening_starter_id: String = _opening_starter_id if _should_apply_opening_shop_guard() else ""
	var res: Dictionary = _tx.reroll(state, lvl, gold, opening_starter_id, get_reroll_price())
	if not bool(res.get("ok", false)):
		error.emit(String(res.get("error", "UNKNOWN")), _error_context("reroll", res))
		return res
	if opening_starter_id != "":
		_opening_helper_shops_consumed += 1
	var cost: int = int(res.get("gold_spent", 0))
	# Spend gold or record combat spend
	if cost > 0 and _has_autoload("Economy"):
		paid_rerolls += 1
		if _is_combat_phase() and Economy.has_method("adjust_combat_spent"):
			Economy.adjust_combat_spent(cost)
		else:
			Economy.add_gold(-cost)
	state = (res.get("state") as ShopState)
	_quote_unpriced_offers(state.offers)
	_emit_all()
	return res

func _should_apply_opening_shop_guard() -> bool:
	if _opening_starter_id == "":
		return false
	if _opening_helper_shops_consumed >= int(ShopConfig.OPENING_HELPER_GUARDED_SHOPS):
		return false
	if get_level() != int(ShopConfig.STARTING_LEVEL):
		return false
	if not _has_autoload("GameState"):
		return false
	if int(GameState.chapter) != 1:
		return false
	if int(GameState.stage_in_chapter) >= 2 and int(GameState.stage_in_chapter) <= 3:
		return true
	if int(GameState.stage_in_chapter) != 1:
		return false
	if not _has_autoload("Economy"):
		return false
	return int(Economy.current_bet) == 0

func buy_xp() -> Dictionary:
	if _is_combat_phase():
		return _combat_phase_error("buy_xp")
	var gold: int = int(Economy.gold) if _has_autoload("Economy") else 0
	var res: Dictionary = _tx.buy_xp(_progress, gold, get_progression_price())
	if not bool(res.get("ok", false)):
		error.emit(String(res.get("error", "UNKNOWN")), _error_context("buy_xp", res))
		return res
	var cost: int = int(res.get("gold_spent", 0))
	if cost > 0 and _has_autoload("Economy"):
		var purchase_kind: String = String(res.get("purchase_kind", "xp"))
		if purchase_kind == "command":
			paid_command_purchases += 1
		else:
			paid_xp_purchases += 1
		if _is_combat_phase() and Economy.has_method("adjust_combat_spent"):
			Economy.adjust_combat_spent(cost)
		else:
			Economy.add_gold(-cost)
	_sync_roster_max_team_size()
	# Offers unchanged; emit reroll/free_rerolls unchanged; but UI may want progress snapshot via getters
	return res

func _sync_roster_max_team_size() -> void:
	if not _has_autoload("Roster"):
		return
	var level_delta: int = max(0, get_level() - int(ShopConfig.STARTING_LEVEL))
	var target_size: int = int(ShopConfig.DEFAULT_BOARD_CAPACITY) + level_delta
	if _contracts != null:
		target_size += max(0, int(_contracts.stable_board_bonus))
	if _is_opening_retry_team_bonus_active():
		target_size = max(target_size, int(ShopConfig.POST_OPENING_MIN_TEAM_SIZE))
	if _is_past_early_run_cap_floor_stage():
		target_size = max(target_size, int(ShopConfig.EARLY_RUN_CAP_FLOOR_TEAM_SIZE))
	if _is_past_early_level_two_cap_floor_stage():
		target_size = max(target_size, int(ShopConfig.EARLY_LEVEL_TWO_CAP_FLOOR_TEAM_SIZE))
	if _is_past_chapter_two_cap_floor_stage():
		target_size = max(target_size, int(ShopConfig.CHAPTER_TWO_CAP_FLOOR_TEAM_SIZE))
	if _is_past_chapter_three_cap_floor_stage():
		target_size = max(target_size, int(ShopConfig.CHAPTER_THREE_CAP_FLOOR_TEAM_SIZE))
	if _is_past_chapter_four_cap_floor_stage():
		target_size = max(target_size, int(ShopConfig.CHAPTER_FOUR_CAP_FLOOR_TEAM_SIZE))
	if _is_past_chapter_five_cap_floor_stage():
		target_size = max(target_size, int(ShopConfig.CHAPTER_FIVE_CAP_FLOOR_TEAM_SIZE))
	target_size = min(target_size, int(ShopConfig.MAX_BOARD_CAPACITY))
	if Roster.has_method("set_max_team_size"):
		Roster.set_max_team_size(target_size)
	else:
		Roster.max_team_size = target_size

func _is_past_opening_fight() -> bool:
	if not _has_autoload("GameState"):
		return false
	return int(GameState.chapter) > 1 or int(GameState.stage_in_chapter) >= 2

func _is_opening_retry_team_bonus_active() -> bool:
	if not _opening_retry_team_bonus_active:
		return false
	if not _has_autoload("GameState"):
		return false
	if int(GameState.chapter) == 1 and int(GameState.stage_in_chapter) == 1:
		return true
	_opening_retry_team_bonus_active = false
	return false

func _is_past_early_run_cap_floor_stage() -> bool:
	if not _has_autoload("GameState"):
		return false
	return int(GameState.stage) >= int(ShopConfig.EARLY_RUN_CAP_FLOOR_STAGE)

func _is_past_early_level_two_cap_floor_stage() -> bool:
	if not _has_autoload("GameState"):
		return false
	if get_level() < 2:
		return false
	return int(GameState.stage) >= int(ShopConfig.EARLY_LEVEL_TWO_CAP_FLOOR_STAGE)

func _is_past_chapter_two_cap_floor_stage() -> bool:
	if not _has_autoload("GameState"):
		return false
	return int(GameState.stage) >= int(ShopConfig.CHAPTER_TWO_CAP_FLOOR_STAGE)

func _is_past_chapter_three_cap_floor_stage() -> bool:
	if not _has_autoload("GameState"):
		return false
	return int(GameState.stage) >= int(ShopConfig.CHAPTER_THREE_CAP_FLOOR_STAGE)

func _is_past_chapter_four_cap_floor_stage() -> bool:
	if not _has_autoload("GameState"):
		return false
	return int(GameState.stage) >= int(ShopConfig.CHAPTER_FOUR_CAP_FLOOR_STAGE)

func _is_past_chapter_five_cap_floor_stage() -> bool:
	if not _has_autoload("GameState"):
		return false
	return int(GameState.stage) >= int(ShopConfig.CHAPTER_FIVE_CAP_FLOOR_STAGE)

func _on_stage_changed(_prev: int, _next: int) -> void:
	_sync_roster_max_team_size()

func _on_chapter_changed(_previous: int, next_chapter: int) -> void:
	_pending_contract_chapter = max(1, int(next_chapter))
	call_deferred("_open_pending_contract_market")

func _on_stake_changed(_stake_unit: int, _stake_rank: int) -> void:
	for offer: ShopOffer in state.offers:
		if offer == null or String(offer.id) == "":
			continue
		offer.price = 0
	_quote_unpriced_offers(state.offers)
	offers_changed.emit(state.offers)

func _open_pending_contract_market() -> void:
	if _pending_contract_chapter <= 0 or _contracts == null:
		return
	var current_stake_unit: int = int(Economy.stake_unit) if _has_autoload("Economy") else 1
	_contracts.begin_chapter(_pending_contract_chapter, current_stake_unit)
	if _has_autoload("Economy"):
		Economy.set_payout_modifier(1.0)
	_pending_contract_chapter = 0
	offers_changed.emit(state.offers)

func get_xp() -> int:
	return int(_progress.xp) if _progress else 0

func get_xp_to_next() -> int:
	return int(_progress.xp_to_next()) if _progress else 0

func buy_unit(slot_index: int) -> Dictionary:
	if _is_combat_phase():
		return _combat_phase_error("buy_unit", {"slot": int(slot_index)})
	var lvl: int = get_level()
	var gold: int = int(Economy.gold) if _has_autoload("Economy") else 0
	_quote_unpriced_offers(state.offers)
	var res: Dictionary = _tx.buy_unit(state, int(slot_index), gold, lvl)
	if not bool(res.get("ok", false)):
		error.emit(String(res.get("error", "UNKNOWN")), _error_context("buy_unit", res, {"slot": int(slot_index)}))
		return res
	var cost: int = int(res.get("gold_spent", 0))
	if cost > 0 and _has_autoload("Economy"):
		if _is_combat_phase() and Economy.has_method("adjust_combat_spent"):
			Economy.adjust_combat_spent(cost)
		else:
			Economy.add_gold(-cost)
	state = (res.get("state") as ShopState)
	_emit_all()
	return res

func sell_unit(u: Unit) -> Dictionary:
	if _is_combat_phase():
		return _combat_phase_error("sell_unit")
	var res: Dictionary = _tx.sell_unit(u)
	if bool(res.get("ok", false)) and _has_autoload("Economy"):
		var g: int = int(res.get("gold_gained", 0))
		if g > 0:
			# Selling during combat should free up credit as well
			if _is_combat_phase() and Economy.has_method("adjust_combat_spent"):
				Economy.adjust_combat_spent(-g)
		Economy.add_gold(g, false, "unit_sale")
	else:
		error.emit(String(res.get("error", "UNKNOWN")), _error_context("sell_unit", res))
	return res

func set_board_team_provider(cb: Callable) -> void:
	# Allows UI/controller layer to provide the current player_team for board-aware combines
	if _tx != null and cb != null:
		_tx.set_board_team_provider(cb)
	_board_team_provider = cb if cb != null else Callable()

func set_remove_from_board(cb: Callable) -> void:
	# Allows UI/controller to provide removal of a specific board unit when consumed by a combine
	if _tx != null and cb != null:
		_tx.set_remove_from_board(cb)

func try_combine_now() -> Array:
	# Attempts to perform bench+board combines immediately (planning phase only).
	# Returns a list of promotion dicts for UI effects.
	if _tx != null and _tx.has_method("combine_now"):
		return _tx.combine_now()
	return []

func _emit_all() -> void:
	offers_changed.emit(state.offers)
	locked_changed.emit(state.locked)
	free_rerolls_changed.emit(state.free_rerolls)

func _quote_unpriced_offers(offers: Array[ShopOffer]) -> void:
	if offers == null or offers.is_empty():
		return
	var current_stake_unit: int = int(Economy.stake_unit) if _has_autoload("Economy") else 1
	var current_stake_rank: int = int(Economy.stake_rank) if _has_autoload("Economy") else 0
	var premium_index: int = _premium_offer_index(offers, current_stake_rank)
	var premium_level: int = StakesMarket.premium_package_level(current_stake_rank)
	var standard_level: int = max(1, premium_level - 1)
	for index: int in range(offers.size()):
		var offer: ShopOffer = offers[index]
		if offer == null or String(offer.id) == "" or int(offer.price) > 0:
			continue
		offer.stake_unit = current_stake_unit
		offer.package_level = standard_level
		offer.package_multiplier = StakesMarket.copy_equivalent_multiplier(standard_level)
		offer.package_kind = "depth_grade" if standard_level > 1 else "standard"
		if index == premium_index and premium_level > 1:
			offer.package_level = premium_level
			offer.package_multiplier = StakesMarket.copy_equivalent_multiplier(premium_level)
			offer.package_kind = "current_grade"
		offer.price = StakesMarket.unit_price(offer.cost, current_stake_unit, offer.package_multiplier)

func _premium_offer_index(offers: Array[ShopOffer], current_stake_rank: int) -> int:
	if current_stake_rank < 3:
		return -1
	for index: int in range(offers.size() - 1, -1, -1):
		var offer: ShopOffer = offers[index]
		if offer != null and String(offer.id) != "":
			return index
	return -1

func _owned_units() -> Array[Unit]:
	if not _has_autoload("Roster"):
		return []
	var current_team: Array = []
	if _board_team_provider.is_valid():
		var team_value: Variant = _board_team_provider.call()
		if team_value is Array:
			current_team = team_value
	if Roster.has_method("owned_units"):
		return Roster.owned_units(current_team)
	return Roster.compact() if Roster.has_method("compact") else []

func _serialize_offer(offer: ShopOffer) -> Dictionary:
	if offer == null:
		return {}
	return {
		"id": offer.id,
		"name": offer.name,
		"cost": offer.cost,
		"price": offer.price,
		"stake_unit": offer.stake_unit,
		"package_level": offer.package_level,
		"package_multiplier": offer.package_multiplier,
		"package_kind": offer.package_kind,
		"sprite_path": offer.sprite_path,
		"roles": offer.roles.duplicate(),
		"traits": offer.traits.duplicate(),
		"primary_role": offer.primary_role,
		"primary_goal": offer.primary_goal,
		"approaches": offer.approaches.duplicate(),
		"alt_goals": offer.alt_goals.duplicate(),
		"identity_path": offer.identity_path,
	}

func _deserialize_offer(data: Dictionary) -> ShopOffer:
	return ShopOffer.new(
		String(data.get("id", "")),
		String(data.get("name", "")),
		int(data.get("cost", 0)),
		String(data.get("sprite_path", "")),
		data.get("roles", []),
		data.get("traits", []),
		String(data.get("primary_role", "")),
		String(data.get("primary_goal", "")),
		data.get("approaches", []),
		String(data.get("identity_path", "")),
		data.get("alt_goals", []),
		int(data.get("price", 0)),
		int(data.get("stake_unit", 1)),
		int(data.get("package_level", 1)),
		int(data.get("package_multiplier", 1)),
		String(data.get("package_kind", "standard"))
	)
