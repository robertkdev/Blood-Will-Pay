extends "res://tests/visual/first_shop_choice_quality_smoke.gd"

const ALL_SMOKE_NAME: String = "AllStarterMainFlowSmoke"

var _starter_results: Array[Dictionary] = []

func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	var window: Window = get_window()
	if window != null:
		window.size = Vector2i(1920, 1080)
		window.content_scale_size = Vector2i(1920, 1080)
	_previous_time_scale = Engine.time_scale
	_previous_suppress_validation_warnings = UnitFactory.suppress_validation_warnings
	UnitFactory.suppress_validation_warnings = true
	Engine.time_scale = _flow_time_scale()
	if Shop != null and not Shop.is_connected("error", Callable(self, "_on_shop_error")):
		Shop.error.connect(_on_shop_error)

	var catalog: UnitCatalog = UnitCatalogLib.new()
	catalog.refresh()
	var starter_ids: Array[String] = _starter_ids_for_run(catalog)
	print("%s: starters=%s" % [_smoke_name(), ",".join(starter_ids)])
	_expect(not starter_ids.is_empty(), "starter catalog should not be empty")
	for starter_id: String in starter_ids:
		var result: Dictionary = await _run_starter_main_flow(starter_id, catalog)
		_starter_results.append(result)
		_assert_starter_main_flow(result)
		print("%s: result starter=%s first=%s moved=%s second=%s" % [
			_smoke_name(),
			starter_id,
			String(result.get("first_fight_result", "")),
			str(bool(result.get("moved_to_board", false))),
			str(bool(result.get("second_fight_resolved", false))),
		])
		if _finish_all_if_failed():
			return
		await _cleanup_between_starters()
	_assert_all_starters_summary(starter_ids)
	_finish_all_starters()

func _finish_all_if_failed() -> bool:
	if _technical_failures().is_empty():
		return false
	_finish_all_starters()
	return true

func _finish_all_starters() -> void:
	Engine.time_scale = _previous_time_scale
	UnitFactory.suppress_validation_warnings = _previous_suppress_validation_warnings
	_flush_synthetic_input()
	var exit_code: int = 0
	if _technical_failures().is_empty():
		var summary: Dictionary = _all_starter_summary()
		print("%s: PASS starters=%d first_shop=%d retry=%d deployed=%d second_resolved=%d" % [
			_smoke_name(),
			int(summary.get("starter_count", 0)),
			int(summary.get("first_shop_count", 0)),
			int(summary.get("first_retry_count", 0)),
			int(summary.get("deploy_success_count", 0)),
			int(summary.get("second_resolved_count", 0)),
		])
	else:
		for failure: String in _technical_failures():
			push_error("%s: %s" % [_smoke_name(), failure])
		exit_code = 1
	_cleanup_runtime()
	get_tree().process_frame.connect(_quit_after_cleanup.bind(exit_code, 10), CONNECT_ONE_SHOT)

func _smoke_name() -> String:
	return ALL_SMOKE_NAME

func _flow_time_scale() -> float:
	return 8.0

func _first_fight_timeout_seconds() -> float:
	return FIRST_FIGHT_TIMEOUT

func _second_fight_timeout_seconds() -> float:
	return SECOND_FIGHT_TIMEOUT

func _starter_ids_for_run(catalog: UnitCatalog) -> Array[String]:
	return catalog.list_starter_ids(int(SHOP_CONFIG.STARTING_LEVEL))

func _prepare_opener_planning(_starter_id: String) -> void:
	_set_planning_timer_safe()

func _prepare_first_shop_planning(_result: Dictionary) -> void:
	_set_planning_time_left(5.0)

func _require_opener_board_reposition() -> bool:
	return false

func _run_starter_main_flow(starter_id: String, catalog: UnitCatalog) -> Dictionary:
	var failure_start: int = _failures.size()
	var shop_error_start: int = _shop_errors.size()
	_start_main_scene()
	await _settle_frames(4)
	var unit_select_started_reset: bool = _unit_select_reset()
	await _ensure_unit_select()
	await _select_starter(starter_id)
	var combat_opened: bool = await _wait_for_combat_view_visible(20.0)
	var board_repositioned: bool = false
	var first_result: String = await _wait_for_first_result(_first_fight_timeout_seconds())
	var result: Dictionary = {
		"id": starter_id,
		"name": catalog.get_name(starter_id),
		"role": catalog.get_primary_role(starter_id),
		"goal": catalog.get_primary_goal(starter_id),
		"unit_select_started_reset": unit_select_started_reset,
		"combat_opened": combat_opened,
		"board_repositioned": board_repositioned,
		"first_fight_result": first_result,
		"stage_after_first": int(GameState.stage_in_chapter),
		"gold_after_first": int(Economy.gold),
		"shop_level_after_first": int(Shop.get_level()),
		"offers_after_first": _offer_summaries(),
		"bench_after_first": _bench_ids(),
		"board_after_first": _board_ids(),
		"shop_errors": _shop_errors_since(shop_error_start),
	}
	if first_result == "shop":
		await _exercise_first_shop(result)
	elif first_result == "loss":
		result["loss_reset_ok"] = await _reset_from_loss()
	else:
		result["retry_state"] = _state_snapshot()
	result["technical_failures"] = _failures_since(failure_start)
	return result

func _exercise_first_shop(result: Dictionary) -> void:
	_prepare_first_shop_planning(result)
	var bought: bool = await _press_affordable_shop_card()
	await _settle_frames(4)
	var bench_after_buy: Array[String] = _bench_ids()
	var deploy_prompt_visible: bool = _deploy_prompt_visible()
	var moved_to_board: bool = false
	if not bench_after_buy.is_empty():
		moved_to_board = await _drag_first_bench_unit_to_board()
		await _settle_frames(4)
	result["shop_buy_clicked"] = bought
	result["bench_after_buy"] = bench_after_buy
	result["deploy_prompt_visible"] = deploy_prompt_visible
	result["moved_to_board"] = moved_to_board
	result["bench_after_deploy"] = _bench_ids()
	result["board_after_deploy"] = _board_ids()
	if moved_to_board:
		await _press_continue(false, "starter first-shop second fight")
		var second_resolved: bool = await _wait_for_preview_or_loss(_second_fight_timeout_seconds())
		result["second_fight_resolved"] = second_resolved
		result["second_fight_result"] = _second_fight_result(second_resolved)
		result["stage_after_second"] = int(GameState.stage_in_chapter)
		result["gold_after_second"] = int(Economy.gold)
		if get_tree().root.get_node_or_null("LossOverlayLayer") != null:
			result["loss_reset_ok"] = await _reset_from_loss()
	else:
		result["second_fight_resolved"] = false
		result["second_fight_result"] = "not_started"

func _assert_starter_main_flow(result: Dictionary) -> void:
	var starter_id: String = String(result.get("id", ""))
	var failures: Array[String] = result.get("technical_failures", []) as Array[String]
	_expect(failures.is_empty(), "%s had technical failures: %s" % [starter_id, JSON.stringify(failures)])
	var shop_errors: Array[Dictionary] = result.get("shop_errors", []) as Array[Dictionary]
	_expect(shop_errors.is_empty(), "%s emitted shop errors: %s" % [starter_id, JSON.stringify(shop_errors)])
	_expect(bool(result.get("unit_select_started_reset", false)), "%s should start from reset UnitSelect" % starter_id)
	_expect(bool(result.get("combat_opened", false)), "%s should open CombatView" % starter_id)
	if _require_opener_board_reposition():
		_expect(bool(result.get("board_repositioned", false)), "%s opener board unit should reposition by drag" % starter_id)
	var first_result: String = String(result.get("first_fight_result", ""))
	_expect(first_result == "shop", "%s should reach first shop, got %s" % [starter_id, first_result])
	var offers_after_first: Array[Dictionary] = result.get("offers_after_first", []) as Array[Dictionary]
	_expect(offers_after_first.size() == int(SHOP_CONFIG.SLOT_COUNT), "%s first shop should have full offers" % starter_id)
	if TARGET_STARTERS.has(starter_id):
		_expect(_offers_have_good_first_shop_helper(starter_id, offers_after_first), "%s first shop should include a known advancing helper, got %s" % [starter_id, JSON.stringify(offers_after_first)])
		_expect(_first_offer_is_good_first_shop_helper(starter_id, offers_after_first), "%s first shop first slot should be a known advancing helper, got %s" % [starter_id, JSON.stringify(offers_after_first)])
	_expect(bool(result.get("shop_buy_clicked", false)), "%s should buy an affordable first-shop card" % starter_id)
	_expect(bool(result.get("deploy_prompt_visible", false)), "%s first-shop buy should show deploy prompt" % starter_id)
	_expect(bool(result.get("moved_to_board", false)), "%s first-shop helper should move to board" % starter_id)
	_expect(bool(result.get("second_fight_resolved", false)), "%s second fight should resolve" % starter_id)

func _offers_have_good_first_shop_helper(starter_id: String, offers: Array[Dictionary]) -> bool:
	var good_helpers: Array[String] = _good_first_shop_helpers_for(starter_id)
	for offer: Dictionary in offers:
		if good_helpers.has(String(offer.get("id", ""))):
			return true
	return false

func _first_offer_is_good_first_shop_helper(starter_id: String, offers: Array[Dictionary]) -> bool:
	if offers.is_empty():
		return false
	var good_helpers: Array[String] = _good_first_shop_helpers_for(starter_id)
	var first_offer: Dictionary = offers[0]
	return good_helpers.has(String(first_offer.get("id", "")))

func _good_first_shop_helpers_for(starter_id: String) -> Array[String]:
	var helpers: Array[String] = []
	var raw_helpers: Array = SHOP_CONFIG.FIRST_SHOP_HELPERS_BY_STARTER.get(starter_id, []) as Array
	for raw_helper: Variant in raw_helpers:
		helpers.append(String(raw_helper))
	return helpers

func _assert_all_starters_summary(starter_ids: Array[String]) -> void:
	var summary: Dictionary = _all_starter_summary()
	_expect(int(summary.get("starter_count", 0)) == starter_ids.size(), "all-starter result count mismatch")
	_expect(int(summary.get("first_retry_count", 0)) == 0, "no current starter should enter first-fight retry")
	_expect(int(summary.get("first_shop_count", 0)) == starter_ids.size(), "all starters should reach first shop")
	_expect(int(summary.get("deploy_success_count", 0)) == starter_ids.size(), "all starters should deploy a helper")
	_expect(int(summary.get("second_resolved_count", 0)) == starter_ids.size(), "all starters should resolve second fight")

func _all_starter_summary() -> Dictionary:
	var first_shop_count: int = 0
	var first_retry_count: int = 0
	var deploy_success_count: int = 0
	var second_resolved_count: int = 0
	var retry_starter: String = ""
	for result: Dictionary in _starter_results:
		var first_result: String = String(result.get("first_fight_result", ""))
		if first_result == "shop":
			first_shop_count += 1
		elif first_result == "retry":
			first_retry_count += 1
			retry_starter = String(result.get("id", ""))
		if bool(result.get("moved_to_board", false)):
			deploy_success_count += 1
		if bool(result.get("second_fight_resolved", false)):
			second_resolved_count += 1
	return {
		"starter_count": _starter_results.size(),
		"first_shop_count": first_shop_count,
		"first_retry_count": first_retry_count,
		"retry_starter": retry_starter,
		"deploy_success_count": deploy_success_count,
		"second_resolved_count": second_resolved_count,
	}

func _reset_from_loss() -> bool:
	await _press_loss_new_game()
	await _settle_frames(8)
	return get_tree().root.get_node_or_null("LossOverlayLayer") == null and _node_visible("UnitSelect") and _unit_select_reset()

func _state_snapshot() -> Dictionary:
	return {
		"stage": int(GameState.stage),
		"stage_in_chapter": int(GameState.stage_in_chapter),
		"phase": int(GameState.phase),
		"gold": int(Economy.gold),
		"shop_level": int(Shop.get_level()),
		"shop_xp": int(Shop.get_xp()),
		"bench": _bench_ids(),
		"board": _board_ids(),
	}
