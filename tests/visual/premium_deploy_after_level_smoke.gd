extends "res://tests/visual/first_shop_choice_quality_smoke.gd"

const PREMIUM_DEPLOY_SMOKE_NAME: String = "PremiumDeployAfterLevelSmoke"
const STARTER_ID: String = "bonko"
const PREMIUM_COST: int = 2
const BUY_XP_AUDIT_GOLD_TARGET: int = 5
const PREMIUM_AUDIT_GOLD_TARGET: int = 12

var _premium_id: String = ""
var _buy_xp_audit_gold_added: int = 0
var _premium_audit_gold_added: int = 0

func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	var window: Window = get_window()
	if window != null:
		window.size = Vector2i(1920, 1080)
		window.content_scale_size = Vector2i(1920, 1080)
	_previous_time_scale = Engine.time_scale
	_previous_suppress_validation_warnings = UnitFactory.suppress_validation_warnings
	UnitFactory.suppress_validation_warnings = true
	Engine.time_scale = 8.0

	_start_main_scene()
	await _settle_frames(4)
	await _run_premium_deploy_after_level_flow()
	_finish_premium_deploy_smoke()

func _run_premium_deploy_after_level_flow() -> void:
	await _ensure_unit_select()
	await _select_starter(STARTER_ID)
	await _settle_frames(4)
	_expect(_node_visible("CombatView"), "CombatView did not open for premium deploy smoke")
	var repositioned: bool = await _reposition_first_board_unit("premium deploy opener reposition")
	_expect(repositioned, "starter did not reposition before premium deploy opener")
	if not _failures.is_empty():
		return

	_set_planning_timer_safe()
	_expect(_first_fight_placeholder_visible(), "forced opener placeholder missing before premium deploy path")
	await _press_continue(true, "premium deploy forced opener")
	var shop_ready: bool = await _wait_for_shop_after_win(30.0)
	_expect(shop_ready, "premium deploy path did not reach the first shop")
	if not shop_ready:
		return
	_expect(int(GameState.stage_in_chapter) >= 2, "premium deploy path should reach at least Stage 1 Round 2")
	_expect(int(Shop.get_level()) == 1, "first shop should start at level 1")
	_expect(Shop.state != null and Shop.state.offers.size() == int(SHOP_CONFIG.SLOT_COUNT), "first shop should have full offers before Buy XP")

	await _audit_assisted_buy_xp_to_level_two()
	if not _failures.is_empty():
		return

	_premium_id = _first_premium_id()
	_expect(_premium_id != "", "no cost-2 premium id found in catalog")
	if _premium_id == "":
		return
	await _audit_assisted_buy_and_deploy_premium(_premium_id)

func _audit_assisted_buy_xp_to_level_two() -> void:
	_buy_xp_audit_gold_added = _add_gold_to_at_least(BUY_XP_AUDIT_GOLD_TARGET)
	await _settle_frames(2)
	var button: Button = _button_with_text("Buy XP")
	_expect(button != null, "Buy XP button missing for premium deploy level-up")
	if button == null:
		return
	var before_gold: int = int(Economy.gold)
	var before_level: int = int(Shop.get_level())
	_expect(before_gold >= BUY_XP_AUDIT_GOLD_TARGET, "Buy XP level-up should have at least %d gold, got %d" % [BUY_XP_AUDIT_GOLD_TARGET, before_gold])
	var clicked: bool = await _click_button(button, "premium deploy Buy XP")
	_expect(clicked, "premium deploy Buy XP click did not fire")
	await _settle_frames(4)
	# See the note in natural_buy_xp_visual_smoke: BUY_XP_COST is in stake units, so assert the
	# price the shop actually quoted rather than the constant.
	var quoted_xp_price: int = int(Shop.get_progression_price()) if Shop.has_method("get_progression_price") else int(SHOP_CONFIG.BUY_XP_COST)
	_expect(int(Economy.gold) == before_gold - quoted_xp_price, "premium deploy Buy XP should spend exactly the quoted %d gold" % quoted_xp_price)
	_expect(int(Shop.get_level()) == before_level + 1, "premium deploy Buy XP should advance one shop level")
	_expect(int(Shop.get_level()) == 2, "premium deploy Buy XP should reach level 2")
	_expect(int(Shop.get_xp()) == 2, "premium deploy Buy XP should preserve 2 overflow XP at level 2")
	_expect(_progress_label_text() == "Lvl 2 (2/6)", "premium deploy Buy XP should repaint progress to Lvl 2 (2/6), got %s" % _progress_label_text())

func _audit_assisted_buy_and_deploy_premium(unit_id: String) -> void:
	_premium_audit_gold_added = _add_gold_to_at_least(PREMIUM_AUDIT_GOLD_TARGET)
	await _settle_frames(2)
	var catalog: UnitCatalog = UnitCatalogLib.new()
	catalog.refresh()
	var offers: Array[ShopOffer] = _premium_offer_set(catalog, unit_id)
	_force_shop_offers(offers, int(Economy.gold))
	await _settle_frames(4)
	_expect(_offer_summaries().size() == int(SHOP_CONFIG.SLOT_COUNT), "premium audit shop should show a full offer row")
	_expect(int(Shop.get_level()) == 2, "premium audit shop should stay level 2")
	_expect(int(offers[0].cost) == PREMIUM_COST, "premium audit first offer should cost %d" % PREMIUM_COST)
	var bought_premium: bool = await _click_shop_slot(0)
	_expect(bought_premium, "premium audit offer did not buy")
	await _settle_frames(4)
	_expect(_bench_ids().has(unit_id), "premium audit purchase should place %s on bench, got %s" % [unit_id, JSON.stringify(_bench_ids())])
	_expect(_deploy_prompt_visible(), "premium audit purchase should show deploy guidance")
	var deployed_premium: bool = await _drag_first_bench_unit_to_board()
	_expect(deployed_premium, "premium audit unit did not deploy to board")
	await _settle_frames(4)
	_expect(_board_ids().has(unit_id), "premium audit unit should be on board after deploy, got %s" % JSON.stringify(_board_ids()))

func _add_gold_to_at_least(target_gold: int) -> int:
	var before_gold: int = int(Economy.gold)
	if before_gold >= target_gold:
		return 0
	var delta: int = int(target_gold) - before_gold
	Economy.add_gold(delta)
	return delta

func _premium_offer_set(catalog: UnitCatalog, premium_id: String) -> Array[ShopOffer]:
	var offers: Array[ShopOffer] = []
	offers.append(_offer_for_id(catalog, premium_id))
	var filler_ids: Array[String] = catalog.get_ids_by_cost(1)
	for filler_id: String in filler_ids:
		if offers.size() >= int(SHOP_CONFIG.SLOT_COUNT):
			break
		if filler_id == STARTER_ID:
			continue
		offers.append(_offer_for_id(catalog, filler_id))
	return offers

func _first_premium_id() -> String:
	var catalog: UnitCatalog = UnitCatalogLib.new()
	catalog.refresh()
	var premium_ids: Array[String] = catalog.get_ids_by_cost(PREMIUM_COST)
	if premium_ids.is_empty():
		return ""
	return premium_ids[0]

func _button_with_text(text: String) -> Button:
	var action: Button = _button_for_action_text(text)
	if action != null:
		return action
	if _main == null:
		return null
	var buttons: Array[Node] = _main.find_children("*", "Button", true, false)
	for node: Node in buttons:
		var button: Button = node as Button
		if button != null and String(button.text) == text:
			return button
	return null

func _progress_label_text() -> String:
	if _main == null:
		return ""
	var labels: Array[Node] = _main.find_children("*", "Label", true, false)
	for node: Node in labels:
		var label: Label = node as Label
		if label != null and String(label.text).begins_with("Lvl "):
			return String(label.text)
	return ""

func _finish_premium_deploy_smoke() -> void:
	Engine.time_scale = _previous_time_scale
	UnitFactory.suppress_validation_warnings = _previous_suppress_validation_warnings
	_flush_synthetic_input()
	var exit_code: int = 0
	if _failures.is_empty():
		print("%s: OK premium=%s buy_xp_audit_gold=%d premium_audit_gold=%d" % [
			PREMIUM_DEPLOY_SMOKE_NAME,
			_premium_id,
			_buy_xp_audit_gold_added,
			_premium_audit_gold_added,
		])
	else:
		for failure: String in _failures:
			push_error("%s: %s" % [PREMIUM_DEPLOY_SMOKE_NAME, failure])
		exit_code = 1
	_cleanup_runtime()
	get_tree().process_frame.connect(_quit_after_cleanup.bind(exit_code, 10), CONNECT_ONE_SHOT)
