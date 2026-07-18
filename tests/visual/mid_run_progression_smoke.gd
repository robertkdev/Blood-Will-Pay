extends "res://tests/visual/first_shop_choice_quality_smoke.gd"

const MID_RUN_SMOKE_NAME: String = "MidRunProgressionSmoke"
const STARTER_ID: String = "bonko"
const MID_RUN_FIRST_FIGHT_TIMEOUT: float = 30.0
const MID_RUN_ROUND_TIMEOUT: float = 90.0
const MID_RUN_HEARTBEAT_SECONDS: float = 10.0
const MAX_DEPLOY_ATTEMPTS: int = 10
# This smoke owns the deterministic opening-to-Chapter-2 bridge. Chapter-contract
# and endless progression have dedicated probes with their own decision setup.
const ROUND_PLANS: Array[Dictionary] = [
	{
		"label": "round_2_frontline_pair",
		"offers": ["morrak", "grint", "mortem", "korath", "sari"],
		"buy_xp": 1,
		"buy": ["morrak", "grint"],
		"gold": 16,
		"min_stage_after": 3,
	},
	{
		"label": "round_3_body_width",
		"offers": ["sari", "brute", "berebell", "bo", "cashmere"],
		"buy_xp": 1,
		"buy": ["sari", "brute"],
		"gold": 16,
		"min_stage_after": 4,
	},
	{
		"label": "round_4_boss_gate",
		"offers": ["meridian", "malachor", "nullora", "quillith", "gable"],
		"buy_xp": 3,
		"buy": ["meridian", "malachor", "nullora", "quillith", "gable"],
		"field": ["meridian", "malachor", "nullora", "quillith", "gable"],
		"bench_out": ["bonko", "morrak", "grint", "sari", "brute"],
		"gold": 40,
		"min_stage_after": 5,
	},
	{
		"label": "round_5_mirror_check",
		"offers": ["korath", "repo", "mortem", "berebell", "morrak"],
		"buy_xp": 4,
		"buy": ["korath"],
		"gold": 32,
		"min_chapter_after": 2,
	},
]

var _mid_run_results: Array[Dictionary] = []
var _audit_gold_added_total: int = 0
var _resolved_battle_count: int = 0

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

	_start_main_scene()
	await _settle_frames(4)
	await _run_mid_run_progression_flow()
	_finish_mid_run_progression()

func _run_mid_run_progression_flow() -> void:
	await _ensure_unit_select()
	await _select_starter(STARTER_ID)
	var combat_opened: bool = await _wait_for_combat_view_visible(20.0)
	_expect(combat_opened, "CombatView did not open for mid-run progression")
	_set_planning_timer_safe()
	var repositioned: bool = await _reposition_first_board_unit("mid-run opener reposition") if combat_opened else false
	_expect(repositioned, "starter did not reposition before mid-run opener")
	if not _technical_failures().is_empty():
		return

	_expect(_first_fight_placeholder_visible(), "forced opener placeholder missing before mid-run progression")
	await _press_continue(true, "mid-run forced opener")
	var first_result: String = await _wait_for_first_result(MID_RUN_FIRST_FIGHT_TIMEOUT)
	_expect(first_result == "shop", "mid-run opener should win into shop, got %s" % first_result)
	if first_result != "shop":
		return
	_resolved_battle_count = 1
	_expect(int(GameState.stage_in_chapter) >= 2, "mid-run opener should reach at least Stage 1 Round 2")
	_expect(Shop.state != null and Shop.state.offers.size() == int(SHOP_CONFIG.SLOT_COUNT), "mid-run first shop should have full offers")

	for raw_plan: Dictionary in ROUND_PLANS:
		var advanced: bool = await _play_planned_round(raw_plan)
		if not advanced:
			return

func _play_planned_round(plan: Dictionary) -> bool:
	var label: String = String(plan.get("label", "planned_round"))
	var offer_ids: Array[String] = _string_array(plan.get("offers", []))
	var buy_ids: Array[String] = _string_array(plan.get("buy", []))
	var field_ids: Array[String] = _string_array(plan.get("field", []))
	var bench_out_ids: Array[String] = _string_array(plan.get("bench_out", []))
	var buy_xp_count: int = int(plan.get("buy_xp", 0))
	var target_gold: int = int(plan.get("gold", buy_ids.size()))
	var min_stage_after: int = int(plan.get("min_stage_after", 0))
	var min_chapter_after: int = int(plan.get("min_chapter_after", 0))
	var failure_start: int = _failures.size()
	var shop_error_start: int = _shop_errors.size()
	var chapter_before: int = int(GameState.chapter)
	var stage_before: int = int(GameState.stage_in_chapter)
	var board_before: Array[String] = _board_ids()
	var bench_before: Array[String] = _bench_ids()
	var result: Dictionary = {
		"label": label,
		"chapter_before": chapter_before,
		"stage_before": stage_before,
		"board_before": board_before,
		"bench_before": bench_before,
		"target_gold": target_gold,
		"planned_buy_xp": buy_xp_count,
		"planned_buys": buy_ids,
		"planned_field": field_ids,
		"planned_bench_out": bench_out_ids,
		"level_before_xp": int(Shop.get_level()),
		"cap_before_xp": _roster_max_team_size(),
	}

	_audit_gold_added_total += _add_gold_to_at_least(target_gold)
	await _settle_frames(2)
	if buy_xp_count > 0:
		var bought_xp: int = await _buy_xp_clicks(buy_xp_count, label)
		result["bought_xp"] = bought_xp
		_expect(bought_xp == buy_xp_count, "%s should buy XP %d time(s), got %d" % [label, buy_xp_count, bought_xp])
		if bought_xp != buy_xp_count:
			_record_round_result(result, failure_start, shop_error_start)
			return false
		await _settle_frames(2)
	result["level_after_xp"] = int(Shop.get_level())
	result["cap_after_xp"] = _roster_max_team_size()
	_expect(_roster_max_team_size() >= _expected_roster_cap_min(), "%s roster cap should respect progression minimum, got cap=%d min=%d" % [label, _roster_max_team_size(), _expected_roster_cap_min()])
	_expect(_roster_max_team_size() >= int(Shop.get_level()), "%s roster cap should not be below shop level, got cap=%d level=%d" % [label, _roster_max_team_size(), int(Shop.get_level())])
	var offers: Array[ShopOffer] = _offers_for_ids(offer_ids)
	_expect(offers.size() == int(SHOP_CONFIG.SLOT_COUNT), "%s should build %d forced offers, got %d" % [label, int(SHOP_CONFIG.SLOT_COUNT), offers.size()])
	if offers.size() != int(SHOP_CONFIG.SLOT_COUNT):
		return false
	_force_shop_offers(offers, int(Economy.gold))
	await _settle_frames(4)
	result["forced_offers"] = _offer_summaries()
	result["gold_before_buys"] = int(Economy.gold)

	var bought_ids: Array[String] = []
	for unit_id: String in buy_ids:
		var bought: bool = await _buy_offer_id(unit_id)
		_expect(bought, "%s could not buy planned offer %s from %s" % [label, unit_id, JSON.stringify(_offer_summaries())])
		if not bought:
			result["bought_ids"] = bought_ids
			_record_round_result(result, failure_start, shop_error_start)
			return false
		bought_ids.append(unit_id)
		await _settle_frames(3)
	result["bought_ids"] = bought_ids
	result["bench_after_buys"] = _bench_ids()
	result["cap_after_buys"] = _roster_max_team_size()
	print("%s: %s bought=%s bench=%s board=%s gold=%d" % [
		MID_RUN_SMOKE_NAME,
		label,
		JSON.stringify(bought_ids),
		JSON.stringify(_bench_ids()),
		JSON.stringify(_board_ids()),
		int(Economy.gold),
	])

	print("%s: %s deploy begin bench=%s board=%s" % [MID_RUN_SMOKE_NAME, label, JSON.stringify(_bench_ids()), JSON.stringify(_board_ids())])
	var deployed_count: int = await _deploy_all_bench_units()
	result["deployed_count"] = deployed_count
	result["bench_after_deploy"] = _bench_ids()
	result["board_after_deploy"] = _board_ids()
	result["cap_after_deploy"] = _roster_max_team_size()
	print("%s: %s deploy end deployed=%d bench=%s board=%s" % [
		MID_RUN_SMOKE_NAME,
		label,
		deployed_count,
		JSON.stringify(_bench_ids()),
		JSON.stringify(_board_ids()),
	])
	var available_owned_count: int = board_before.size() + bench_before.size() + bought_ids.size()
	var current_cap: int = _roster_max_team_size()
	var expected_board_size: int = min(available_owned_count, current_cap) if current_cap >= 0 else available_owned_count
	_expect(_board_ids().size() == expected_board_size, "%s should field exactly %d units under cap=%d, got %s" % [label, expected_board_size, current_cap, JSON.stringify(_board_ids())])
	_expect(_board_ids().size() <= current_cap or current_cap < 0, "%s board should not exceed roster cap=%d, got %d" % [label, current_cap, _board_ids().size()])
	if _board_ids().size() != expected_board_size:
		_record_round_result(result, failure_start, shop_error_start)
		return false
	if not field_ids.is_empty():
		var field_swaps: int = await _field_preferred_units(field_ids, bench_out_ids, label)
		result["field_swaps"] = field_swaps
		result["bench_after_field"] = _bench_ids()
		result["board_after_field"] = _board_ids()
		for field_id: String in field_ids:
			_expect(_board_ids().has(field_id), "%s should field %s before battle, board=%s bench=%s" % [label, field_id, JSON.stringify(_board_ids()), JSON.stringify(_bench_ids())])
		if not _field_ids_on_board(field_ids):
			_record_round_result(result, failure_start, shop_error_start)
			return false

	_set_planning_timer_safe()
	print("%s: %s battle start request phase=%d timer=%.2f" % [MID_RUN_SMOKE_NAME, label, int(GameState.phase), _planning_time_left()])
	await _press_continue(false, "%s battle" % label)
	print("%s: %s battle wait begin phase=%d combat_active=%s" % [MID_RUN_SMOKE_NAME, label, int(GameState.phase), str(bool(Economy.combat_active))])
	var resolved: bool = await _wait_for_preview_or_loss(MID_RUN_ROUND_TIMEOUT)
	var fight_result: String = _second_fight_result(resolved)
	var chapter_after: int = int(GameState.chapter)
	var stage_after: int = int(GameState.stage_in_chapter)
	var advanced: bool = fight_result == "shop" and (chapter_after > chapter_before or stage_after > stage_before)
	result["resolved"] = resolved
	result["fight_result"] = fight_result
	result["combat_snapshot"] = _combat_snapshot()
	result["chapter_after"] = chapter_after
	result["stage_after"] = stage_after
	result["gold_after"] = int(Economy.gold)
	result["advanced"] = advanced
	_expect(resolved, "%s did not resolve" % label)
	_expect(fight_result == "shop", "%s should win and return to shop, got %s" % [label, fight_result])
	if min_chapter_after > 0:
		_expect(chapter_after >= min_chapter_after, "%s should reach chapter >= %d, got chapter %d stage %d" % [label, min_chapter_after, chapter_after, stage_after])
	if min_stage_after > 0:
		_expect(stage_after >= min_stage_after, "%s should reach stage >= %d, got %d" % [label, min_stage_after, stage_after])
	_record_round_result(result, failure_start, shop_error_start)
	if advanced:
		_resolved_battle_count += 1
		print("%s: %s advanced chapter %d stage %d -> chapter %d stage %d board=%s" % [
			MID_RUN_SMOKE_NAME,
			label,
			chapter_before,
			stage_before,
			chapter_after,
			stage_after,
			JSON.stringify(_board_ids()),
		])
	return advanced

func _offers_for_ids(unit_ids: Array[String]) -> Array[ShopOffer]:
	var offers: Array[ShopOffer] = []
	var catalog: UnitCatalog = UnitCatalogLib.new()
	catalog.refresh()
	for unit_id: String in unit_ids:
		if offers.size() >= int(SHOP_CONFIG.SLOT_COUNT):
			break
		if not catalog.has_id(unit_id):
			_expect(false, "mid-run forced offer id %s missing from catalog" % unit_id)
			continue
		offers.append(_offer_for_id(catalog, unit_id))
	return offers

func _buy_offer_id(unit_id: String) -> bool:
	var slot_index: int = _shop_slot_for_id(unit_id)
	if slot_index < 0:
		return false
	return await _click_shop_slot(slot_index)

func _buy_xp_clicks(count: int, label: String) -> int:
	var purchased: int = 0
	for i: int in range(max(0, int(count))):
		var button: Button = _button_with_text("Buy XP")
		_expect(button != null, "%s Buy XP button missing" % label)
		if button == null:
			return purchased
		_expect(not button.disabled, "%s Buy XP button disabled before click %d" % [label, i + 1])
		if button.disabled:
			return purchased
		var before_gold: int = int(Economy.gold)
		var before_level: int = int(Shop.get_level())
		var clicked: bool = await _click_button(button, "%s Buy XP %d" % [label, i + 1])
		await _settle_frames(4)
		_expect(clicked, "%s Buy XP click %d did not fire" % [label, i + 1])
		if not clicked:
			return purchased
		_expect(int(Economy.gold) == before_gold - int(SHOP_CONFIG.BUY_XP_COST), "%s Buy XP click %d should spend %d gold" % [label, i + 1, int(SHOP_CONFIG.BUY_XP_COST)])
		_expect(int(Shop.get_level()) >= before_level, "%s Buy XP click %d should not lower level" % [label, i + 1])
		_expect(_roster_max_team_size() >= _expected_roster_cap_min(), "%s Buy XP click %d should keep cap=%d at/above min=%d" % [label, i + 1, _roster_max_team_size(), _expected_roster_cap_min()])
		_expect(_roster_max_team_size() >= int(Shop.get_level()), "%s Buy XP click %d should keep cap=%d at/above level=%d" % [label, i + 1, _roster_max_team_size(), int(Shop.get_level())])
		purchased += 1
	return purchased

func _button_with_text(text: String) -> Button:
	if _main == null or not is_instance_valid(_main):
		return null
	var buttons: Array[Node] = _main.find_children("*", "Button", true, false)
	for node: Node in buttons:
		var button: Button = node as Button
		if button != null and (String(button.text) == text or String(button.text).begins_with(text + " ")):
			return button
	return null

func _roster_max_team_size() -> int:
	if get_tree().root.get_node_or_null("/root/Roster") == null:
		return -1
	return int(Roster.max_team_size)

func _expected_roster_cap_min() -> int:
	if get_tree().root.get_node_or_null("/root/GameState") == null:
		return 1
	if int(GameState.chapter) > 1 or int(GameState.stage_in_chapter) >= 2:
		return max(int(Shop.get_level()) + int(SHOP_CONFIG.POST_OPENING_TEAM_SIZE_BONUS), int(SHOP_CONFIG.POST_OPENING_MIN_TEAM_SIZE))
	return int(Shop.get_level())

func _shop_slot_for_id(unit_id: String) -> int:
	var summaries: Array[Dictionary] = _offer_summaries()
	for summary: Dictionary in summaries:
		if String(summary.get("id", "")) == unit_id:
			return int(summary.get("slot", -1))
	return -1

func _field_preferred_units(field_ids: Array[String], bench_out_ids: Array[String], label: String) -> int:
	var swaps: int = 0
	for field_id: String in field_ids:
		if _board_ids().has(field_id):
			continue
		if not _bench_ids().has(field_id):
			_expect(false, "%s cannot field %s because it is not on bench=%s" % [label, field_id, JSON.stringify(_bench_ids())])
			return swaps
		var current_cap: int = _roster_max_team_size()
		if current_cap >= 0 and _board_ids().size() >= current_cap:
			var bench_out_id: String = _next_board_swap_id(field_ids, bench_out_ids)
			_expect(bench_out_id != "", "%s needs a board unit to bench before fielding %s" % [label, field_id])
			if bench_out_id == "":
				return swaps
			var benched: bool = await _drag_board_unit_id_to_bench(bench_out_id, "%s bench out %s" % [label, bench_out_id])
			_expect(benched, "%s failed to bench %s before fielding %s" % [label, bench_out_id, field_id])
			if not benched:
				return swaps
		var fielded: bool = await _drag_bench_unit_id_to_board(field_id, "%s field %s" % [label, field_id])
		_expect(fielded, "%s failed to field %s" % [label, field_id])
		if not fielded:
			return swaps
		swaps += 1
	return swaps

func _field_ids_on_board(field_ids: Array[String]) -> bool:
	var board: Array[String] = _board_ids()
	for field_id: String in field_ids:
		if not board.has(field_id):
			return false
	return true

func _next_board_swap_id(field_ids: Array[String], bench_out_ids: Array[String]) -> String:
	var board: Array[String] = _board_ids()
	for unit_id: String in bench_out_ids:
		if board.has(unit_id):
			return unit_id
	for board_id: String in board:
		if not field_ids.has(board_id):
			return board_id
	return ""

func _drag_bench_unit_id_to_board(unit_id: String, label: String) -> bool:
	var combat: Control = _main.get_node_or_null("CombatView") as Control
	if combat == null:
		return false
	var controller: Variant = combat.get("controller")
	if controller == null or controller.manager == null or controller.player_grid_helper == null:
		return false
	var bench_grid: GridContainer = combat.get_node_or_null("MarginContainer/VBoxContainer/BenchArea/BenchGrid") as GridContainer
	if bench_grid == null:
		return false
	var unit_view: UnitView = _find_unit_view_by_id(bench_grid, unit_id)
	if unit_view == null:
		return false
	var target_tile: int = _first_empty_board_tile(controller)
	if target_tile < 0:
		return false
	var moved_unit: Unit = unit_view.unit as Unit
	var before_size: int = controller.manager.player_team.size()
	var target_center: Vector2 = controller.player_grid_helper.get_center(target_tile)
	var dragged: bool = await _drag_control_to(unit_view, target_center, label)
	await _settle_frames(6)
	if dragged and moved_unit != null and controller.manager.player_team.has(moved_unit) and controller.manager.player_team.size() >= before_size + 1:
		return true
	var fallback_view: UnitView = _find_unit_view_by_id(bench_grid, unit_id)
	if fallback_view != null and is_instance_valid(fallback_view):
		var router: MoveRouter = controller.move_router as MoveRouter
		if router != null and router.has_method("route_bench_to_board"):
			var route_ok: bool = router.route_bench_to_board(fallback_view, target_tile)
			print("%s: %s fallback bench_to_board route_ok=%s status=%s" % [MID_RUN_SMOKE_NAME, label, str(route_ok), JSON.stringify(router.last_route_status)])
			await _settle_frames(6)
	return moved_unit != null and controller.manager.player_team.has(moved_unit) and controller.manager.player_team.size() >= before_size + 1

func _drag_board_unit_id_to_bench(unit_id: String, label: String) -> bool:
	var combat: Control = _main.get_node_or_null("CombatView") as Control
	if combat == null:
		return false
	var controller: Variant = combat.get("controller")
	if controller == null or controller.manager == null or controller.bench_grid_helper == null:
		return false
	var player_grid: GridContainer = combat.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ContentRow/BoardColumn/PlanningArea/BottomArea/PlayerGrid") as GridContainer
	if player_grid == null:
		return false
	var unit_view: UnitView = _find_unit_view_by_id(player_grid, unit_id)
	if unit_view == null:
		return false
	var target_tile: int = _first_empty_bench_tile(controller)
	if target_tile < 0:
		return false
	var moved_unit: Unit = unit_view.unit as Unit
	var target_center: Vector2 = controller.bench_grid_helper.get_center(target_tile)
	var dragged: bool = await _drag_control_to(unit_view, target_center, label)
	await _settle_frames(6)
	if dragged and moved_unit != null and Roster.compact().has(moved_unit) and not controller.manager.player_team.has(moved_unit):
		return true
	var fallback_view: UnitView = _find_unit_view_by_id(player_grid, unit_id)
	if fallback_view != null and is_instance_valid(fallback_view):
		var router: MoveRouter = controller.move_router as MoveRouter
		if router != null and router.has_method("route_board_to_bench"):
			var route_ok: bool = router.route_board_to_bench(fallback_view, target_tile)
			print("%s: %s fallback board_to_bench route_ok=%s status=%s" % [MID_RUN_SMOKE_NAME, label, str(route_ok), JSON.stringify(router.last_route_status)])
			await _settle_frames(6)
	return moved_unit != null and Roster.compact().has(moved_unit) and not controller.manager.player_team.has(moved_unit)

func _find_unit_view_by_id(root: Node, unit_id: String) -> UnitView:
	for child: Node in root.get_children():
		if child is UnitView:
			var view: UnitView = child as UnitView
			if _unit_id(view.unit as Unit) == unit_id:
				return view
		var nested: UnitView = _find_unit_view_by_id(child, unit_id)
		if nested != null:
			return nested
	return null

func _first_empty_bench_tile(controller: Variant) -> int:
	if controller == null or controller.bench_grid_helper == null:
		return -1
	for index: int in range(controller.bench_grid_helper.size()):
		if not controller.bench_grid_helper.is_occupied(index):
			return index
	return -1

func _deploy_all_bench_units() -> int:
	var deployed_count: int = 0
	var attempts: int = 0
	while attempts < MAX_DEPLOY_ATTEMPTS and not _bench_ids().is_empty():
		attempts += 1
		var before_board_size: int = _board_ids().size()
		var before_bench: Array[String] = _bench_ids()
		print("%s: deploy attempt %d bench=%s board=%s" % [MID_RUN_SMOKE_NAME, attempts, JSON.stringify(before_bench), JSON.stringify(_board_ids())])
		var moved: bool = await _drag_first_bench_unit_to_board()
		await _settle_frames(4)
		var after_board_size: int = _board_ids().size()
		print("%s: deploy attempt %d moved=%s before_board=%d after_board=%d bench=%s board=%s" % [
			MID_RUN_SMOKE_NAME,
			attempts,
			str(moved),
			before_board_size,
			after_board_size,
			JSON.stringify(_bench_ids()),
			JSON.stringify(_board_ids()),
		])
		if moved and after_board_size > before_board_size:
			deployed_count += 1
		else:
			break
	return deployed_count

func _wait_for_preview_or_loss(timeout_seconds: float) -> bool:
	var deadline: int = Time.get_ticks_msec() + int(timeout_seconds * 1000.0)
	var next_heartbeat: int = Time.get_ticks_msec() + int(MID_RUN_HEARTBEAT_SECONDS * 1000.0)
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		if get_tree().root.get_node_or_null("LossOverlayLayer") != null:
			return true
		if GameState.phase == GameState.GamePhase.PREVIEW and not Economy.combat_active:
			return true
		var now: int = Time.get_ticks_msec()
		if now >= next_heartbeat:
			print("%s: wait heartbeat %s" % [MID_RUN_SMOKE_NAME, JSON.stringify(_combat_snapshot())])
			next_heartbeat = now + int(MID_RUN_HEARTBEAT_SECONDS * 1000.0)
	print("%s: wait timeout %s" % [MID_RUN_SMOKE_NAME, JSON.stringify(_combat_snapshot())])
	return false

func _add_gold_to_at_least(target_gold: int) -> int:
	var before_gold: int = int(Economy.gold)
	if before_gold >= target_gold:
		return 0
	var delta: int = int(target_gold) - before_gold
	Economy.add_gold(delta)
	return delta

func _string_array(value: Variant) -> Array[String]:
	var output: Array[String] = []
	if value is Array:
		var raw_array: Array = value
		for item: Variant in raw_array:
			output.append(String(item))
	return output

func _record_round_result(result: Dictionary, failure_start: int, shop_error_start: int) -> void:
	result["technical_failures"] = _failures_since(failure_start)
	result["shop_errors"] = _shop_errors_since(shop_error_start)
	_mid_run_results.append(result.duplicate(true))

func _combat_snapshot() -> Dictionary:
	var snapshot: Dictionary = {
		"phase": int(GameState.phase),
		"combat_active": bool(Economy.combat_active),
	}
	var controller: Variant = _combat_controller()
	if controller == null:
		snapshot["controller"] = "missing"
		return snapshot
	var manager: CombatManager = controller.get("manager") as CombatManager
	if manager == null:
		snapshot["manager"] = "missing"
		return snapshot
	snapshot["player_alive"] = _alive_count_from_units(manager.player_team)
	snapshot["enemy_alive"] = _alive_count_from_units(manager.enemy_team)
	snapshot["player_hp"] = _team_hp_total(manager.player_team)
	snapshot["enemy_hp"] = _team_hp_total(manager.enemy_team)
	var engine: CombatEngine = manager.get_engine() as CombatEngine
	if engine == null:
		snapshot["engine"] = "missing"
		return snapshot
	var state: BattleState = engine.get("state") as BattleState
	snapshot["engine_elapsed"] = float(state.elapsed_time) if state != null else -1.0
	snapshot["engine_active"] = bool(state.battle_active) if state != null else false
	snapshot["combat_timeout_s"] = float(engine.get("combat_timeout_s"))
	snapshot["no_progress_timeout_s"] = float(engine.get("no_progress_timeout_s"))
	snapshot["last_progress_time"] = float(engine.get("_last_progress_time"))
	snapshot["total_damage_player"] = int(engine.get("total_damage_player"))
	snapshot["total_damage_enemy"] = int(engine.get("total_damage_enemy"))
	snapshot["debug_shots"] = int(engine.get("debug_shots"))
	snapshot["debug_pairs"] = int(engine.get("debug_pairs"))
	var outcome_resolver: Variant = engine.get("outcome_resolver")
	snapshot["outcome_sent"] = bool(outcome_resolver.get("outcome_sent")) if outcome_resolver != null else false
	snapshot["player_targets"] = _int_array(state.player_targets) if state != null else []
	snapshot["enemy_targets"] = _int_array(state.enemy_targets) if state != null else []
	snapshot["player_cds"] = _float_array(state.player_cds) if state != null else []
	snapshot["enemy_cds"] = _float_array(state.enemy_cds) if state != null else []
	snapshot["player_positions"] = _vector_array_strings(engine.get_player_positions_copy())
	snapshot["enemy_positions"] = _vector_array_strings(engine.get_enemy_positions_copy())
	snapshot["player_distance_to_enemy"] = _player_distance_to_first_enemy(engine)
	snapshot["projectiles"] = _projectile_snapshot(controller)
	return snapshot

func _alive_count_from_units(units: Array[Unit]) -> int:
	var count: int = 0
	for unit: Unit in units:
		if unit != null and unit.is_alive():
			count += 1
	return count

func _team_hp_total(units: Array[Unit]) -> int:
	var total: int = 0
	for unit: Unit in units:
		if unit != null:
			total += max(0, int(unit.hp))
	return total

func _int_array(values: Array) -> Array[int]:
	var output: Array[int] = []
	for value: Variant in values:
		output.append(int(value))
	return output

func _float_array(values: Array) -> Array[float]:
	var output: Array[float] = []
	for value: Variant in values:
		output.append(float(value))
	return output

func _vector_array_strings(values: Array) -> Array[String]:
	var output: Array[String] = []
	for value: Variant in values:
		if value is Vector2:
			var position: Vector2 = value
			output.append("(%.1f,%.1f)" % [position.x, position.y])
	return output

func _player_distance_to_first_enemy(engine: CombatEngine) -> Array[float]:
	var output: Array[float] = []
	var enemy_positions: Array = engine.get_enemy_positions_copy()
	if enemy_positions.is_empty() or not (enemy_positions[0] is Vector2):
		return output
	var target_position: Vector2 = enemy_positions[0]
	var player_positions: Array = engine.get_player_positions_copy()
	for value: Variant in player_positions:
		if value is Vector2:
			var player_position: Vector2 = value
			output.append(player_position.distance_to(target_position))
	return output

func _projectile_snapshot(controller: Variant) -> Dictionary:
	var snapshot: Dictionary = {"bridge": "missing"}
	if controller == null:
		return snapshot
	var projectile_bridge: Variant = controller.get("projectile_bridge")
	if projectile_bridge == null:
		return snapshot
	snapshot["bridge"] = "present"
	snapshot["has_active"] = bool(projectile_bridge.has_active()) if projectile_bridge.has_method("has_active") else false
	var projectile_manager: ProjectileManager = projectile_bridge.get("projectile_manager") as ProjectileManager
	if projectile_manager == null:
		snapshot["manager"] = "missing"
		return snapshot
	if projectile_manager.has_method("debug_snapshot"):
		snapshot["manager_debug"] = projectile_manager.debug_snapshot()
	var projectiles: Array = projectile_manager.get("_projectiles")
	snapshot["count"] = projectiles.size()
	var team_counts: Dictionary = {}
	var target_control_valid: Array[bool] = []
	var target_indices: Array[int] = []
	for projectile: Dictionary in projectiles:
		var team: String = String(projectile.get("source_team", ""))
		team_counts[team] = int(team_counts.get(team, 0)) + 1
		var target_ref: WeakRef = projectile.get("target_ref", null) as WeakRef
		var target_control: Control = null
		if target_ref != null:
			target_control = target_ref.get_ref() as Control
		target_control_valid.append(target_control != null)
		target_indices.append(int(projectile.get("target_index", -1)))
	snapshot["team_counts"] = team_counts
	snapshot["target_control_valid"] = target_control_valid
	snapshot["target_indices"] = target_indices
	return snapshot

func _finish_mid_run_progression() -> void:
	Engine.time_scale = _previous_time_scale
	UnitFactory.suppress_validation_warnings = _previous_suppress_validation_warnings
	_flush_synthetic_input()
	var exit_code: int = 0
	if _technical_failures().is_empty():
		var final_board: Array[String] = _board_ids()
		print("%s: OK battles=%d chapter=%d stage=%d audit_gold_added=%d board=%s" % [
			MID_RUN_SMOKE_NAME,
			_resolved_battle_count,
			int(GameState.chapter),
			int(GameState.stage_in_chapter),
			_audit_gold_added_total,
			JSON.stringify(final_board),
		])
	else:
		for failure: String in _technical_failures():
			push_error("%s: %s" % [MID_RUN_SMOKE_NAME, failure])
		print("%s: results=%s" % [MID_RUN_SMOKE_NAME, JSON.stringify(_mid_run_results)])
		exit_code = 1
	_cleanup_runtime()
	get_tree().process_frame.connect(_quit_after_cleanup.bind(exit_code, 10), CONNECT_ONE_SHOT)
