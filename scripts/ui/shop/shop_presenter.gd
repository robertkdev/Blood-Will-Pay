extends RefCounted
class_name ShopPresenter

const ShopConfig := preload("res://scripts/game/shop/shop_config.gd")
const ShopPanel := preload("res://scripts/ui/shop/shop_panel.gd")
const ShopButtons := preload("res://scripts/ui/shop/shop_buttons.gd")
const ShopErrors := preload("res://scripts/game/shop/shop_errors.gd")
const ShopAffordability := preload("res://scripts/game/shop/affordability.gd")

const OPENING_FIGHT_LABEL: String = "OPENING FIGHT"
const OPENING_FIGHT_HINT: String = "Win this opener to unlock the shop"
const OPENING_FIGHT_MESSAGE: String = "Opening fight is fixed. Win it to unlock the shop."

var _parent: Node = null
var _grid: GridContainer = null
var _panel: ShopPanel = null
var _buttons: ShopButtons = null
var _message_label: Label = null
var _message_timer: Timer = null
var _drop_grid: BoardGrid = null

signal grid_updated
signal promotions_emitted(promotions)
signal first_purchase_needs_deploy(unit_id: String, bench_slot: int)

func _root() -> Node:
	var tree := (_parent.get_tree() if _parent else null)
	return tree.root if tree else null

func _has_shop() -> bool:
	if Engine.has_singleton("Shop"):
		return true
	var r: Node = _root()
	return r != null and r.get_node_or_null("Shop") != null

func _has_economy() -> bool:
	if Engine.has_singleton("Economy"):
		return true
	var r: Node = _root()
	return r != null and r.get_node_or_null("Economy") != null

func _has_game_state() -> bool:
	if Engine.has_singleton("GameState"):
		return true
	var r: Node = _root()
	return r != null and r.get_node_or_null("GameState") != null

func _roster_node() -> Node:
	if Engine.has_singleton("Roster"):
		return Roster
	var r: Node = _root()
	return (r.get_node_or_null("Roster") if r != null else null)

func configure(parent: Node, grid: GridContainer) -> void:
	_parent = parent
	_grid = grid
	if _grid:
		_grid.columns = ShopConfig.SLOT_COUNT
	_panel = ShopPanel.new()
	_panel.configure(_grid, ShopConfig.SLOT_COUNT)
	_panel.first_fight_placeholder_pressed.connect(_on_first_fight_placeholder_pressed)
	# Button bar mounted above grid inside the host container
	_buttons = ShopButtons.new()
	_buttons.configure(_panel.get_host_container())
	_buttons.reroll_pressed.connect(_on_reroll)
	_buttons.lock_pressed.connect(_on_lock)
	_buttons.buy_xp_pressed.connect(_on_buy_xp)
	_wire()
	_refresh_now()
	_rebuild_drop_grid()

func teardown() -> void:
	_unwire()
	if _buttons != null and _buttons.has_method("teardown"):
		_buttons.teardown()
	if _panel != null and _panel.has_method("clear"):
		_panel.clear()
	if _message_timer != null and is_instance_valid(_message_timer):
		_message_timer.stop()
		var timer_parent: Node = _message_timer.get_parent()
		if timer_parent != null:
			timer_parent.remove_child(_message_timer)
		_message_timer.free()
	if _message_label != null and is_instance_valid(_message_label):
		var label_parent: Node = _message_label.get_parent()
		if label_parent != null:
			label_parent.remove_child(_message_label)
		_message_label.free()
	_message_timer = null
	_drop_grid = null
	_message_label = null
	_buttons = null
	_panel = null
	_grid = null
	_parent = null

func _wire() -> void:
	if not _has_shop():
		return
	if not Shop.is_connected("offers_changed", Callable(self, "_on_offers_changed")):
		Shop.offers_changed.connect(_on_offers_changed)
	if not Shop.is_connected("locked_changed", Callable(self, "_on_locked_changed")):
		Shop.locked_changed.connect(_on_locked_changed)
	if not Shop.is_connected("error", Callable(self, "_on_shop_error")):
		Shop.error.connect(_on_shop_error)
	# React to economy/phase changes for live affordability/tooltip updates
	if _has_economy():
		if not Economy.is_connected("gold_changed", Callable(self, "_on_economy_changed")):
			Economy.gold_changed.connect(_on_economy_changed)
		if not Economy.is_connected("bet_changed", Callable(self, "_on_economy_changed")):
			Economy.bet_changed.connect(_on_economy_changed)
	if _has_game_state():
		if not GameState.is_connected("phase_changed", Callable(self, "_on_phase_changed")):
			GameState.phase_changed.connect(_on_phase_changed)

func _unwire() -> void:
	if Engine.has_singleton("Shop"):
		if Shop.is_connected("offers_changed", Callable(self, "_on_offers_changed")):
			Shop.offers_changed.disconnect(_on_offers_changed)
		if Shop.is_connected("locked_changed", Callable(self, "_on_locked_changed")):
			Shop.locked_changed.disconnect(_on_locked_changed)
		if Shop.is_connected("error", Callable(self, "_on_shop_error")):
			Shop.error.disconnect(_on_shop_error)
	if Engine.has_singleton("Economy"):
		if Economy.is_connected("gold_changed", Callable(self, "_on_economy_changed")):
			Economy.gold_changed.disconnect(_on_economy_changed)
		if Economy.is_connected("bet_changed", Callable(self, "_on_economy_changed")):
			Economy.bet_changed.disconnect(_on_economy_changed)
	if Engine.has_singleton("GameState") and GameState.is_connected("phase_changed", Callable(self, "_on_phase_changed")):
		GameState.phase_changed.disconnect(_on_phase_changed)

func _refresh_now() -> void:
	if not _has_shop():
		return
	_apply_empty_state()
	# If Shop has current offers (after reroll), show them; else show empties
	if Shop and Shop.state and Shop.state.offers != null:
		_panel.set_offers(Shop.state.offers)
	else:
		_panel.set_offers([])
	_on_locked_changed(Shop.state.locked if Shop and Shop.state else false)
	_refresh_cards_state()
	_refresh_progress()

func _on_offers_changed(offers: Array) -> void:
	if _panel:
		_apply_empty_state()
		_panel.set_offers(offers)
		_refresh_cards_state()
		_refresh_progress()
		_rebuild_drop_grid()

func _on_locked_changed(locked: bool) -> void:
	if _buttons:
		_buttons.set_locked(locked)

func _refresh_progress() -> void:
	if _buttons == null:
		return
	var lvl: int = 1
	var xp: int = 0
	var need: int = 0
	if _has_shop():
		if Shop and Shop.has_method("get_level"):
			lvl = int(Shop.get_level())
		if Shop and Shop.has_method("get_xp"):
			xp = int(Shop.get_xp())
		if Shop and Shop.has_method("get_xp_to_next"):
			need = int(Shop.get_xp_to_next())
	_buttons.set_progress(lvl, xp, need)
	var reroll_price: int = int(Shop.get_reroll_price()) if _has_shop() and Shop.has_method("get_reroll_price") else int(ShopConfig.REROLL_COST)
	var progression_price: int = int(Shop.get_progression_price()) if _has_shop() and Shop.has_method("get_progression_price") else int(ShopConfig.BUY_XP_COST)
	var progression_mode: String = String(Shop.get_progression_mode()) if _has_shop() and Shop.has_method("get_progression_mode") else "xp"
	var command_rank: int = int(Shop.get_command_rank()) if _has_shop() and Shop.has_method("get_command_rank") else 0
	_buttons.set_action_prices(reroll_price, progression_price, progression_mode, command_rank)
	var progression_available: bool = bool(Shop.can_purchase_progression()) if _has_shop() and Shop.has_method("can_purchase_progression") else true
	_buttons.set_progression_available(progression_available, progression_mode)

func _on_economy_changed(_v := 0) -> void:
	_refresh_cards_state()
	_refresh_progress()

func _on_phase_changed(_prev: int, _next: int) -> void:
	_refresh_now()

func _is_shop_locked_by_combat() -> bool:
	if _has_game_state() and int(GameState.phase) == int(GameState.GamePhase.COMBAT):
		return true
	if _has_economy():
		return bool(Economy.combat_active)
	return false

func _refresh_cards_state() -> void:
	if _panel == null:
		return
	var gold: int = 0
	if _has_economy():
		gold = int(Economy.gold)
	var bench_full: bool = false
	var roster: Node = _roster_node()
	if roster != null and roster.has_method("first_empty_slot"):
		bench_full = (int(roster.call("first_empty_slot")) == -1)
	var in_combat: bool = _is_shop_locked_by_combat()
	var forced_first_fight: bool = _is_forced_first_fight()
	if _buttons:
		_buttons.set_enabled(not in_combat and not forced_first_fight)
		if forced_first_fight:
			var first_tip: String = OPENING_FIGHT_MESSAGE
			_buttons.set_reroll_tooltip(first_tip)
			_buttons.set_lock_tooltip(first_tip)
			_buttons.set_buy_xp_tooltip(first_tip)
		elif in_combat:
			var combat_tip: String = "Shop locked during battle"
			_buttons.set_reroll_tooltip(combat_tip)
			_buttons.set_lock_tooltip(combat_tip)
			_buttons.set_buy_xp_tooltip(combat_tip)
		else:
			_buttons.set_lock_tooltip("")
	var cards: Array = _panel.get_cards()
	if cards.is_empty():
		return
	var bet: int = (int(Economy.current_bet) if _has_economy() else 0)
	var spent: int = (int(Economy.combat_spent) if _has_economy() and in_combat else 0)
	var idx: int = 0
	for c in cards:
		if c is ShopCard:
			var sc: ShopCard = c
			# affordability tint only
			var price: int = 0
			if Shop and Shop.state and idx < Shop.state.offers.size():
				var off: Variant = Shop.state.offers[idx]
				if off != null:
					price = int(off.price) if int(off.price) > 0 else int(off.cost)
			var aff := ShopAffordability.can_afford(gold, bet, price, in_combat, spent)
			var affordable: bool = bool(aff.get("ok", false))
			sc.set_affordable(affordable)
			if not affordable:
				var need: int = int(aff.get("need_more", 0))
				var msg := "Not enough gold"
				var reason := String(aff.get("reason", ""))
				if reason == ShopAffordability.REASON_RESERVE_FLOOR:
					msg = "Must keep at least 1 health (need +%d)" % max(1, need)
				elif reason == ShopAffordability.REASON_CREDIT_LIMIT:
					msg = "Exceeds combat credit (need +%d)" % max(1, need)
				if sc.has_method("set_status_tip"):
					sc.call("set_status_tip", msg)
				else:
					sc.tooltip_text = msg
			if in_combat:
				sc.set_shop_disabled("Shop locked during battle")
			elif bench_full:
				sc.set_shop_disabled("Bench full")
			else:
				# Re-enable if previously disabled for bench full (lightweight approach)
				sc.disabled = not affordable
				sc.modulate = Color(1,1,1,1)
			# Connect click -> buy
			if not sc.is_connected("clicked", Callable(self, "_on_card_clicked")):
				sc.clicked.connect(_on_card_clicked)
		idx += 1

	# Buttons hints
	if forced_first_fight or in_combat:
		return
	if _buttons:
		var r_cost: int = int(Shop.get_reroll_price()) if _has_shop() and Shop.has_method("get_reroll_price") else int(ShopConfig.REROLL_COST)
		var aff_r := ShopAffordability.can_afford(gold, bet, r_cost, in_combat, spent)
		var msg_r := ""
		if not bool(aff_r.get("ok", false)):
			var need_r: int = int(aff_r.get("need_more", 0))
			var reason_r := String(aff_r.get("reason", ""))
			if reason_r == ShopAffordability.REASON_RESERVE_FLOOR:
				msg_r = "Must keep at least 1 health (need +%d)" % max(1, need_r)
			elif reason_r == ShopAffordability.REASON_CREDIT_LIMIT:
				msg_r = "Exceeds combat credit (need +%d)" % max(1, need_r)
			else:
				msg_r = "Not enough gold"
		_buttons.set_reroll_tooltip(msg_r)

		var x_cost: int = int(Shop.get_progression_price()) if _has_shop() and Shop.has_method("get_progression_price") else int(ShopConfig.BUY_XP_COST)
		var aff_x := ShopAffordability.can_afford(gold, bet, x_cost, in_combat, spent)
		var msg_x := ""
		if not bool(aff_x.get("ok", false)):
			var need_x: int = int(aff_x.get("need_more", 0))
			var reason_x := String(aff_x.get("reason", ""))
			if reason_x == ShopAffordability.REASON_RESERVE_FLOOR:
				msg_x = "Must keep at least 1 health (need +%d)" % max(1, need_x)
			elif reason_x == ShopAffordability.REASON_CREDIT_LIMIT:
				msg_x = "Exceeds combat credit (need +%d)" % max(1, need_x)
			else:
				msg_x = "Not enough gold"
		_buttons.set_buy_xp_tooltip(msg_x)

func _on_card_clicked(slot_index: int) -> void:
	if not _has_shop():
		return
	if _is_forced_first_fight():
		_show_message(OPENING_FIGHT_MESSAGE, 2.0)
		return
	if _is_shop_locked_by_combat():
		_show_message("Shop locked during battle", 2.0)
		_refresh_cards_state()
		return
	var res: Dictionary = Shop.buy_unit(int(slot_index))
	# Emit promotions for UI effects if present
	if typeof(res) == TYPE_DICTIONARY:
		if bool(res.get("ok", false)):
			var unit_id: String = String(res.get("unit_id", "unit"))
			var bench_slot: int = int(res.get("bench_slot", -1))
			_show_message("Bought %s. Drag it from bench to board." % unit_id.capitalize(), 3.0)
			first_purchase_needs_deploy.emit(unit_id, bench_slot)
			var promos: Variant = res.get("promotions", null)
			if promos is Array and promos.size() > 0:
				promotions_emitted.emit(promos)
	_refresh_progress()

func _on_first_fight_placeholder_pressed() -> void:
	if _is_forced_first_fight():
		_show_message(OPENING_FIGHT_MESSAGE, 2.5)

func set_enabled(enabled: bool) -> void:
	if _buttons:
		_buttons.set_enabled(bool(enabled))

func _on_reroll() -> void:
	if not _has_shop():
		return
	if _is_forced_first_fight():
		_show_message(OPENING_FIGHT_MESSAGE, 2.0)
		return
	if _is_shop_locked_by_combat():
		_show_message("Shop locked during battle", 2.0)
		_refresh_cards_state()
		return
	if Shop:
		Shop.reroll()
	_refresh_progress()

func _on_lock() -> void:
	if not _has_shop():
		return
	if _is_forced_first_fight():
		_show_message(OPENING_FIGHT_MESSAGE, 2.0)
		return
	if _is_shop_locked_by_combat():
		_show_message("Shop locked during battle", 2.0)
		_refresh_cards_state()
		return
	if Shop:
		Shop.toggle_lock()
	_refresh_progress()

func _on_buy_xp() -> void:
	if not _has_shop():
		return
	if _is_forced_first_fight():
		_show_message(OPENING_FIGHT_MESSAGE, 2.0)
		return
	if _is_shop_locked_by_combat():
		_show_message("Shop locked during battle", 2.0)
		_refresh_cards_state()
		return
	if Shop:
		Shop.buy_xp()
		_refresh_progress()
		_refresh_cards_state()

func _apply_empty_state() -> void:
	if _panel == null:
		return
	if _is_forced_first_fight():
		_panel.set_empty_state(OPENING_FIGHT_LABEL, OPENING_FIGHT_HINT, true)
	else:
		_panel.set_empty_state("LEDGER", "Reroll to reveal", false)

func _is_forced_first_fight() -> bool:
	if not _has_game_state() or not _has_shop():
		return false
	var first_stage: bool = int(GameState.chapter) == 1 and int(GameState.stage_in_chapter) == 1
	var preview_phase: bool = int(GameState.phase) == int(GameState.GamePhase.PREVIEW)
	var offers_empty: bool = true
	if Shop and Shop.state and Shop.state.offers != null:
		offers_empty = Shop.state.offers.is_empty()
	return first_stage and preview_phase and offers_empty

func _rebuild_drop_grid() -> void:
	if _grid == null:
		return
	var tiles: Array = []
	for c in _grid.get_children():
		if c is Control:
			tiles.append(c)
	if _drop_grid == null:
		_drop_grid = load("res://scripts/board_grid.gd").new()
	_drop_grid.configure(tiles, int(ShopConfig.SLOT_COUNT), 1)
	grid_updated.emit()

func get_drop_grid() -> BoardGrid:
	return _drop_grid

func get_button_bar() -> HBoxContainer:
	return (_buttons.get_bar() if _buttons else null)

func _ensure_message_label() -> void:
	if _message_label and is_instance_valid(_message_label):
		return
	var host := (_panel.get_host_container() if _panel else null)
	if host == null:
		return
	_message_label = Label.new()
	_message_label.modulate = Color(1,0.6,0.6,0.95)
	host.add_child(_message_label)
	host.move_child(_message_label, 1) # below buttons
	if _message_timer == null or not is_instance_valid(_message_timer):
		_message_timer = Timer.new()
		_message_timer.one_shot = true
		_message_timer.process_callback = Timer.TIMER_PROCESS_IDLE
		host.add_child(_message_timer)
		_message_timer.timeout.connect(_on_message_timer_timeout)

func _show_message(text: String, seconds: float = 2.0) -> void:
	_ensure_message_label()
	if _message_label == null:
		return
	_message_label.text = String(text)
	_message_label.visible = true
	if _message_timer != null and is_instance_valid(_message_timer):
		_message_timer.stop()
		_message_timer.wait_time = max(0.1, float(seconds))
		_message_timer.start()

func _on_message_timer_timeout() -> void:
	if _message_label != null and is_instance_valid(_message_label):
		_message_label.visible = false

func _on_shop_error(code: String, context: Dictionary) -> void:
	var msg: String = _shop_error_message(code, context)
	_show_message(msg, 2.5)

func _shop_error_message(code: String, context: Dictionary) -> String:
	var need_more: int = int(context.get("need_more", 0))
	if code == ShopErrors.WOULD_KILL_YOU and need_more > 0:
		var op: String = String(context.get("op", ""))
		if op == "buy_xp":
			return "Need +%d gold to buy XP and keep 1 health." % max(1, need_more)
		if op == "reroll":
			return "Need +%d gold to reroll and keep 1 health." % max(1, need_more)
		if op == "buy_unit":
			return "Need +%d gold to buy safely." % max(1, need_more)
		return "Need +%d gold to keep 1 health." % max(1, need_more)
	return ShopErrors.message(code)
