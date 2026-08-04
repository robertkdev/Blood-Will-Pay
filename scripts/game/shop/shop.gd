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
var _opening_starter_id: String = ""
var _opening_helper_shops_consumed: int = 0
var _opening_retry_team_bonus_active: bool = false

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
	if _has_autoload("GameState") and not GameState.is_connected("stage_changed", Callable(self, "_on_stage_changed")):
		GameState.stage_changed.connect(_on_stage_changed)
	reset_run()

func _exit_tree() -> void:
	clear_runtime()

func clear_runtime() -> void:
	state = ShopState.new()
	_opening_starter_id = ""
	_opening_helper_shops_consumed = 0
	_opening_retry_team_bonus_active = false
	if _tx != null and _tx.has_method("clear_runtime"):
		_tx.clear_runtime()
	if _roller != null and _roller.has_method("clear_runtime"):
		_roller.clear_runtime()
	if _catalog != null and _catalog.has_method("clear_runtime"):
		_catalog.clear_runtime()
	_rng = null
	_catalog = null
	_roller = null
	_tx = null
	_progress = null

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
	if _progress:
		_progress.reset()
	_sync_roster_max_team_size()
	_emit_all()

func set_opening_starter_id(starter_id: String) -> void:
	_opening_starter_id = String(starter_id)
	_opening_helper_shops_consumed = 0

func get_level() -> int:
	return int(_progress.level) if _progress else int(ShopConfig.STARTING_LEVEL)

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
	var res: Dictionary = _tx.reroll(state, lvl, gold, opening_starter_id)
	if not bool(res.get("ok", false)):
		error.emit(String(res.get("error", "UNKNOWN")), _error_context("reroll", res))
		return res
	if opening_starter_id != "":
		_opening_helper_shops_consumed += 1
	var cost: int = int(res.get("gold_spent", 0))
	# Spend gold or record combat spend
	if cost > 0 and _has_autoload("Economy"):
		if _is_combat_phase() and Economy.has_method("adjust_combat_spent"):
			Economy.adjust_combat_spent(cost)
		else:
			Economy.add_gold(-cost)
	state = (res.get("state") as ShopState)
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
	var res: Dictionary = _tx.buy_xp(_progress, gold)
	if not bool(res.get("ok", false)):
		error.emit(String(res.get("error", "UNKNOWN")), _error_context("buy_xp", res))
		return res
	var cost: int = int(res.get("gold_spent", 0))
	if cost > 0 and _has_autoload("Economy"):
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
	var target_size: int = min(int(ShopConfig.MAX_BOARD_CAPACITY), int(ShopConfig.DEFAULT_BOARD_CAPACITY) + level_delta)
	if _is_opening_retry_team_bonus_active():
		target_size = max(target_size, int(ShopConfig.POST_OPENING_MIN_TEAM_SIZE))
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

func get_xp() -> int:
	return int(_progress.xp) if _progress else 0

func get_xp_to_next() -> int:
	return int(_progress.xp_to_next()) if _progress else 0

func buy_unit(slot_index: int) -> Dictionary:
	if _is_combat_phase():
		return _combat_phase_error("buy_unit", {"slot": int(slot_index)})
	var lvl: int = get_level()
	var gold: int = int(Economy.gold) if _has_autoload("Economy") else 0
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
	var res: Dictionary = _tx.sell_unit(u)
	if bool(res.get("ok", false)) and _has_autoload("Economy"):
		var g: int = int(res.get("gold_gained", 0))
		if g > 0:
			# Selling during combat should free up credit as well
			if _is_combat_phase() and Economy.has_method("adjust_combat_spent"):
				Economy.adjust_combat_spent(-g)
		Economy.add_gold(g)
	else:
		error.emit(String(res.get("error", "UNKNOWN")), _error_context("sell_unit", res))
	return res

func set_board_team_provider(cb: Callable) -> void:
	# Allows UI/controller layer to provide the current player_team for board-aware combines
	if _tx != null and cb != null:
		_tx.set_board_team_provider(cb)

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
