extends "res://tests/visual/actual_run_loop_smoke.gd"

const UnitCatalogLib: Script = preload("res://scripts/game/shop/unit_catalog.gd")
const SMOKE_NAME: String = "FirstShopChoiceQualitySmoke"
const TARGET_STARTERS: Array[String] = ["axiom", "bo", "bonko", "cashmere", "korath", "morrak", "mortem", "repo", "sari"]
const TARGET_HELPERS: Dictionary = {
	"axiom": ["sari", "sari", "sari", "sari", "sari"],
	"bo": ["berebell", "cashmere", "cashmere", "grint", "brute"],
	"bonko": ["morrak", "grint", "mortem", "axiom", "korath"],
	"cashmere": ["korath", "repo", "brute", "bonko", "brute"],
	"korath": ["brute", "bonko", "sari", "morrak", "berebell"],
	"morrak": ["repo", "berebell", "brute", "sari", "bonko"],
	"mortem": ["morrak", "bonko", "sari", "brute", "berebell"],
	"repo": ["axiom", "berebell", "bonko", "grint", "sari"],
	"sari": ["bonko", "grint", "brute", "berebell", "morrak"],
}
const FIRST_FIGHT_TIMEOUT: float = 30.0
const SECOND_FIGHT_TIMEOUT: float = 35.0

var _shop_errors: Array[Dictionary] = []
var _choice_results: Array[Dictionary] = []

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
	if Shop != null and not Shop.is_connected("error", Callable(self, "_on_shop_error")):
		Shop.error.connect(_on_shop_error)

	for starter_id: String in TARGET_STARTERS:
		var starter_result: Dictionary = await _run_starter_choice_sweep(starter_id)
		_choice_results.append(starter_result)
		_assert_starter_has_viable_helper(starter_result)
		if _finish_choice_if_failed():
			return
	_finish_choice_quality()

func _finish_choice_if_failed() -> bool:
	if _technical_failures().is_empty():
		return false
	_finish_choice_quality()
	return true

func _uses_manual_opening_continue() -> bool:
	return true

func _finish_choice_quality() -> void:
	Engine.time_scale = _previous_time_scale
	UnitFactory.suppress_validation_warnings = _previous_suppress_validation_warnings
	_flush_synthetic_input()
	var exit_code: int = 0
	if _technical_failures().is_empty():
		var summary: Dictionary = _choice_summary()
		print("%s: PASS starters=%d trials=%d advanced=%d" % [
			SMOKE_NAME,
			int(summary.get("starter_count", 0)),
			int(summary.get("trial_count", 0)),
			int(summary.get("advanced_count", 0)),
		])
	else:
		for failure: String in _technical_failures():
			push_error("%s: %s" % [SMOKE_NAME, failure])
		exit_code = 1
	_cleanup_runtime()
	get_tree().process_frame.connect(_quit_after_cleanup.bind(exit_code, 10), CONNECT_ONE_SHOT)

func _run_starter_choice_sweep(starter_id: String) -> Dictionary:
	var snapshot: Dictionary = await _capture_first_shop_snapshot(starter_id)
	var result: Dictionary = {
		"id": starter_id,
		"snapshot": snapshot.get("summary", {}),
		"trials": [],
	}
	if not bool(snapshot.get("ok", false)):
		result["error"] = String(snapshot.get("error", "snapshot_failed"))
		return result
	var offers: Array[ShopOffer] = _offers_for_starter(starter_id)
	var offer_summaries: Array[Dictionary] = _offer_summaries_for_offers(offers)
	_expect(offers.size() == int(SHOP_CONFIG.SLOT_COUNT), "%s deterministic helper set should have %d offers, got %d" % [starter_id, int(SHOP_CONFIG.SLOT_COUNT), offers.size()])
	var gold_before_buy: int = int(snapshot.get("gold", 0))
	for slot_index: int in range(offers.size()):
		var offer: ShopOffer = offers[slot_index]
		if offer == null or String(offer.id) == "":
			continue
		var offer_summary: Dictionary = offer_summaries[slot_index] if slot_index < offer_summaries.size() else _offer_summary_from_offer(slot_index, offer)
		var trial: Dictionary = await _run_offer_slot_trial(starter_id, offers, gold_before_buy, slot_index, offer_summary)
		var trials: Array = result.get("trials", []) as Array
		trials.append(trial)
		result["trials"] = trials
	return result

func _capture_first_shop_snapshot(starter_id: String) -> Dictionary:
	var failure_start: int = _failures.size()
	var shop_error_start: int = _shop_errors.size()
	_start_main_scene()
	await _settle_frames(4)
	await _ensure_unit_select()
	await _select_starter(starter_id)
	var combat_opened: bool = await _wait_for_combat_view_visible(20.0)
	_expect(combat_opened, "choice snapshot %s combat view did not open" % starter_id)
	_set_planning_timer_safe()
	var board_repositioned: bool = await _reposition_first_board_unit("choice snapshot %s board reposition" % starter_id) if combat_opened else false
	await _press_continue(true, "choice snapshot %s forced first fight" % starter_id)
	var first_result: String = await _wait_for_first_result(FIRST_FIGHT_TIMEOUT)
	var output: Dictionary = {
		"ok": first_result == "shop",
		"summary": {
			"first_fight_result": first_result,
			"stage_after_first": int(GameState.stage_in_chapter),
			"gold_after_first": int(Economy.gold),
			"board_after_first": _board_ids(),
			"combat_opened": combat_opened,
			"board_repositioned": board_repositioned,
			"shop_errors": _shop_errors_since(shop_error_start),
			"technical_failures": _failures_since(failure_start),
		},
		"gold": int(Economy.gold),
		"offer_summaries": _offer_summaries_for_offers(_offers_for_starter(starter_id)),
	}
	if first_result != "shop":
		output["error"] = "first_result_" + first_result
	await _cleanup_between_starters()
	return output

func _run_offer_slot_trial(starter_id: String, offers: Array[ShopOffer], gold_before_buy: int, slot_index: int, offer_summary: Dictionary) -> Dictionary:
	var failure_start: int = _failures.size()
	var shop_error_start: int = _shop_errors.size()
	_start_main_scene()
	await _settle_frames(4)
	await _ensure_unit_select()
	await _select_starter(starter_id)
	var combat_opened: bool = await _wait_for_combat_view_visible(20.0)
	_expect(combat_opened, "choice trial %s slot %d combat view did not open" % [starter_id, slot_index])
	_set_planning_timer_safe()
	var board_repositioned: bool = await _reposition_first_board_unit("choice trial %s slot %d board reposition" % [starter_id, slot_index]) if combat_opened else false
	await _press_continue(true, "choice trial %s slot %d forced first fight" % [starter_id, slot_index])
	var first_result: String = await _wait_for_first_result(FIRST_FIGHT_TIMEOUT)
	var result: Dictionary = {
		"slot": slot_index,
		"offer": offer_summary,
		"first_fight_result": first_result,
		"combat_opened": combat_opened,
		"board_repositioned": board_repositioned,
		"stage_after_first": int(GameState.stage_in_chapter),
		"gold_after_first_actual": int(Economy.gold),
	}
	if first_result != "shop":
		result["error"] = "first_result_" + first_result
		result["technical_failures"] = _failures_since(failure_start)
		result["shop_errors"] = _shop_errors_since(shop_error_start)
		await _cleanup_between_starters()
		return result
	_force_shop_offers(offers, gold_before_buy)
	await _settle_frames(4)
	result["gold_before_buy_forced"] = int(Economy.gold)
	result["forced_offers"] = _offer_summaries()
	result["shop_buy_clicked"] = await _click_shop_slot(slot_index)
	await _settle_frames(4)
	result["bench_after_buy"] = _bench_ids()
	result["deploy_prompt_visible"] = _deploy_prompt_visible()
	var moved_to_board: bool = false
	if not _bench_ids().is_empty():
		moved_to_board = await _drag_first_bench_unit_to_board()
		await _settle_frames(4)
	result["moved_to_board"] = moved_to_board
	result["bench_after_deploy"] = _bench_ids()
	result["board_after_deploy"] = _board_ids()
	if moved_to_board:
		await _press_continue(false, "choice trial %s slot %d second fight" % [starter_id, slot_index])
		var second_resolved: bool = await _wait_for_preview_or_loss(SECOND_FIGHT_TIMEOUT)
		result["second_fight_resolved"] = second_resolved
		result["second_fight_result"] = _second_fight_result(second_resolved)
		result["stage_after_second"] = int(GameState.stage_in_chapter)
		result["gold_after_second"] = int(Economy.gold)
		result["advanced_after_second"] = int(result["stage_after_second"]) > int(result["stage_after_first"])
	else:
		result["second_fight_resolved"] = false
		result["second_fight_result"] = "not_started"
		result["advanced_after_second"] = false
	result["technical_failures"] = _failures_since(failure_start)
	result["shop_errors"] = _shop_errors_since(shop_error_start)
	await _cleanup_between_starters()
	print("%s: trial starter=%s slot=%d offer=%s advanced=%s stage=%d" % [
		SMOKE_NAME,
		starter_id,
		slot_index,
		String(offer_summary.get("id", "")),
		str(bool(result.get("advanced_after_second", false))),
		int(result.get("stage_after_second", -1)),
	])
	return result

func _assert_starter_has_viable_helper(starter_result: Dictionary) -> void:
	var starter_id: String = String(starter_result.get("id", ""))
	var trials: Array = starter_result.get("trials", []) as Array
	_expect(trials.size() > 0, "%s did not produce first-shop helper trials" % starter_id)
	var advanced_slots: Array[String] = []
	for raw_trial: Variant in trials:
		var trial: Dictionary = raw_trial as Dictionary
		if bool(trial.get("advanced_after_second", false)):
			var offer: Dictionary = trial.get("offer", {}) as Dictionary
			advanced_slots.append("%d:%s" % [int(trial.get("slot", -1)), String(offer.get("id", ""))])
	_expect(not advanced_slots.is_empty(), "%s had no first-shop helper that advanced beyond Stage 2" % starter_id)

func _start_main_scene() -> void:
	_main = MAIN_SCENE.instantiate() as Control
	_main.set_anchors_preset(Control.PRESET_FULL_RECT)
	_main.offset_left = 0.0
	_main.offset_top = 0.0
	_main.offset_right = 0.0
	_main.offset_bottom = 0.0
	get_tree().root.add_child(_main)

func _wait_for_first_result(timeout_seconds: float) -> String:
	var deadline: int = Time.get_ticks_msec() + int(timeout_seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		if get_tree().root.get_node_or_null("LossOverlayLayer") != null:
			return "loss"
		if GameState.phase == GameState.GamePhase.PREVIEW and not Economy.combat_active:
			if int(GameState.stage_in_chapter) >= 2:
				if Shop.state != null and Shop.state.offers.size() == int(SHOP_CONFIG.SLOT_COUNT):
					return "shop"
			else:
				return "retry"
	return "timeout"

func _second_fight_result(resolved: bool) -> String:
	if not resolved:
		return "timeout"
	if get_tree().root.get_node_or_null("LossOverlayLayer") != null:
		return "loss"
	if GameState.phase == GameState.GamePhase.PREVIEW:
		return "shop"
	return "unknown"

func _cleanup_between_starters() -> void:
	_cleanup_runtime()
	await _settle_frames(4)

func _force_shop_offers(offers: Array[ShopOffer], gold: int) -> void:
	if Economy != null:
		var delta: int = int(gold) - int(Economy.gold)
		if delta != 0:
			Economy.add_gold(delta)
	if Shop != null:
		Shop.state = ShopState.new(offers, false, 0)
		if Shop.has_method("_emit_all"):
			Shop.call("_emit_all")
		else:
			Shop.offers_changed.emit(Shop.state.offers)

func _click_shop_slot(slot_index: int) -> bool:
	var grid: GridContainer = _main.find_child("ShopGrid", true, false) as GridContainer
	if grid == null:
		_expect(false, "shop grid missing")
		return false
	if slot_index < 0 or slot_index >= grid.get_child_count():
		_expect(false, "shop slot %d missing" % slot_index)
		return false
	var card: ShopCard = grid.get_child(slot_index) as ShopCard
	if card == null:
		_expect(false, "shop slot %d is not a shop card" % slot_index)
		return false
	return await _click_button(card, "shop slot %d" % slot_index)

func _offer_summaries() -> Array[Dictionary]:
	var output: Array[Dictionary] = []
	if Shop == null or Shop.state == null:
		return output
	for index: int in range(Shop.state.offers.size()):
		var offer: ShopOffer = Shop.state.offers[index] as ShopOffer
		if offer == null:
			output.append({"slot": index, "id": "", "cost": 0})
		else:
			output.append(_offer_summary_from_offer(index, offer))
	return output

func _offers_for_starter(starter_id: String) -> Array[ShopOffer]:
	var output: Array[ShopOffer] = []
	var catalog: UnitCatalog = UnitCatalogLib.new()
	catalog.refresh()
	for helper_id: String in _helper_ids_for_starter(starter_id):
		if not catalog.has_id(helper_id):
			_expect(false, "%s helper id %s missing from catalog" % [starter_id, helper_id])
			continue
		output.append(_offer_for_id(catalog, helper_id))
	return output

func _helper_ids_for_starter(starter_id: String) -> Array[String]:
	var output: Array[String] = []
	var raw: Array = TARGET_HELPERS.get(starter_id, []) as Array
	for value: Variant in raw:
		output.append(String(value))
	return output

func _offer_for_id(catalog: UnitCatalog, unit_id: String) -> ShopOffer:
	return ShopOffer.new(
		unit_id,
		catalog.get_name(unit_id),
		catalog.get_cost(unit_id),
		catalog.get_sprite_path(unit_id),
		catalog.get_roles(unit_id),
		catalog.get_traits(unit_id),
		catalog.get_primary_role(unit_id),
		catalog.get_primary_goal(unit_id),
		catalog.get_approaches(unit_id),
		catalog.get_identity_path(unit_id),
		catalog.get_alt_goals(unit_id)
	)

func _offer_summaries_for_offers(offers: Array[ShopOffer]) -> Array[Dictionary]:
	var output: Array[Dictionary] = []
	for index: int in range(offers.size()):
		output.append(_offer_summary_from_offer(index, offers[index]))
	return output

func _offer_summary_from_offer(slot_index: int, offer: ShopOffer) -> Dictionary:
	return {
		"slot": slot_index,
		"id": String(offer.id),
		"name": String(offer.name),
		"cost": int(offer.cost),
		"primary_role": String(offer.primary_role),
		"primary_goal": String(offer.primary_goal),
	}

func _bench_ids() -> Array[String]:
	var output: Array[String] = []
	var units: Array[Unit] = Roster.compact()
	for unit: Unit in units:
		output.append(_unit_id(unit))
	return output

func _board_ids() -> Array[String]:
	var output: Array[String] = []
	var controller: Variant = _combat_controller()
	if controller == null:
		return output
	var manager: Variant = controller.get("manager")
	if manager == null:
		return output
	for unit_variant: Variant in manager.player_team:
		var unit: Unit = unit_variant as Unit
		output.append(_unit_id(unit))
	return output

func _unit_id(unit: Unit) -> String:
	if unit == null:
		return ""
	if "id" in unit:
		return String(unit.id)
	return String(unit.name)

func _failures_since(start_index: int) -> Array[String]:
	var output: Array[String] = []
	for index: int in range(start_index, _failures.size()):
		output.append(String(_failures[index]))
	return output

func _shop_errors_since(start_index: int) -> Array[Dictionary]:
	var output: Array[Dictionary] = []
	for index: int in range(start_index, _shop_errors.size()):
		output.append(_shop_errors[index].duplicate(true))
	return output

func _technical_failures() -> Array[String]:
	var output: Array[String] = []
	for failure: String in _failures:
		output.append(failure)
	for error_entry: Dictionary in _shop_errors:
		output.append("shop error %s %s" % [String(error_entry.get("code", "")), JSON.stringify(error_entry.get("context", {}))])
	return output

func _choice_summary() -> Dictionary:
	var trial_count: int = 0
	var advanced_count: int = 0
	for starter: Dictionary in _choice_results:
		var trials: Array = starter.get("trials", []) as Array
		for raw_trial: Variant in trials:
			var trial: Dictionary = raw_trial as Dictionary
			trial_count += 1
			if bool(trial.get("advanced_after_second", false)):
				advanced_count += 1
	return {
		"starter_count": TARGET_STARTERS.size(),
		"trial_count": trial_count,
		"advanced_count": advanced_count,
	}

func _on_shop_error(code: String, context: Dictionary) -> void:
	_shop_errors.append({
		"code": code,
		"context": context.duplicate(true),
		"stage": int(GameState.stage) if GameState != null else -1,
		"gold": int(Economy.gold) if Economy != null else -1,
		"level": int(Shop.get_level()) if Shop != null else -1,
	})
