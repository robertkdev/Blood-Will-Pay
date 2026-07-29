extends "res://tests/visual/random_later_shop_progression_smoke.gd"

const ShopAffordabilityLib: Script = preload("res://scripts/game/shop/affordability.gd")
const TWO_STAGE_SMOKE_NAME: String = "NaturalBonkoTwoStageMainFlowSmoke"
const TWO_STAGE_STARTER_ID: String = "bonko"
const TWO_STAGE_SHOP_SEED: int = 4401
const TWO_STAGE_FIRST_FIGHT_TIMEOUT: float = 75.0
const TWO_STAGE_ROUND_TIMEOUT: float = 120.0
const TWO_STAGE_MAX_BATTLES: int = 8
const TWO_STAGE_MAX_BUYS_PER_SHOP: int = 2
const TWO_STAGE_SAFE_BUY_XP_GOLD: int = 6
const TWO_STAGE_MAX_RETRIES_PER_STAGE: int = 3
const TWO_STAGE_TARGET_CHAPTER: int = 2
const TWO_STAGE_TARGET_ROUND: int = 2

var _two_stage_results: Array[Dictionary] = []
var _two_stage_battles: int = 0
var _two_stage_buy_xp_clicks: int = 0

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

	_set_shop_seed(_flow_shop_seed())
	_start_main_scene()
	await _settle_frames(4)
	await _run_two_stage_flow()
	_finish_two_stage_flow()

func _run_two_stage_flow() -> void:
	await _ensure_unit_select()
	await _select_starter(_flow_starter_id())
	await _settle_frames(4)
	_expect(_node_visible("CombatView"), "CombatView did not open for natural two-stage flow")
	var repositioned: bool = await _reposition_first_board_unit("natural two-stage opener reposition")
	_expect(repositioned, "starter did not reposition before natural two-stage opener")
	if not _technical_failures().is_empty():
		return

	_set_planning_timer_safe()
	await _press_continue(true, "natural two-stage opener")
	var first_result: String = await _wait_for_first_result(_flow_first_fight_timeout())
	_expect(first_result == "shop", "natural opener should win into first shop, got %s state=%s" % [first_result, JSON.stringify(_two_stage_state())])
	if first_result != "shop":
		return
	_two_stage_battles = 1
	_expect(int(GameState.stage_in_chapter) >= 2, "natural opener should advance to at least round 2")
	var retry_counts_by_stage: Dictionary = {}

	while _two_stage_battles < _flow_max_battles() and not _reached_two_stage_target():
		var round_result: Dictionary = await _play_two_stage_round()
		_two_stage_results.append(round_result)
		if not bool(round_result.get("advanced", false)):
			if _can_retry_after_same_stage(round_result):
				var retry_key: String = "%d:%d" % [int(round_result.get("chapter_before", -1)), int(round_result.get("round_before", -1))]
				retry_counts_by_stage[retry_key] = int(retry_counts_by_stage.get(retry_key, 0)) + 1
				if int(retry_counts_by_stage.get(retry_key, 0)) > _flow_max_retries_per_stage():
					_expect(false, "natural flow repeated chapter %d round %d too many times: %s" % [
						int(round_result.get("chapter_before", -1)),
						int(round_result.get("round_before", -1)),
						JSON.stringify(round_result),
					])
					return
				continue
			_expect(false, "natural two-stage flow stopped: %s" % JSON.stringify(round_result))
			return
		if not _technical_failures().is_empty():
			return

	_expect(_reached_two_stage_target(), "natural flow should reach chapter %d round %d, got %s" % [_flow_target_chapter(), _flow_target_round(), JSON.stringify(_two_stage_state())])

func _play_two_stage_round() -> Dictionary:
	var chapter_before: int = int(GameState.chapter)
	var round_before: int = int(GameState.stage_in_chapter)
	if _flow_verbose_round_logs():
		print("%s: round_start chapter=%d round=%d state=%s" % [
			_flow_smoke_name(),
			chapter_before,
			round_before,
			JSON.stringify(_two_stage_state()),
		])
	var result: Dictionary = {
		"chapter_before": chapter_before,
		"round_before": round_before,
		"gold_before": int(Economy.gold),
		"level_before": int(Shop.get_level()),
		"cap_before": _roster_max_team_size(),
		"board_before": _board_ids(),
		"bench_before": _bench_ids(),
		"offers_before": _offer_summaries(),
	}

	var xp_before_buys: bool = await _buy_xp_if_needed("chapter %d round %d pre-buy" % [chapter_before, round_before], true)
	if xp_before_buys:
		_two_stage_buy_xp_clicks += 1
	await _deploy_until_blocked()

	var bought_ids: Array[String] = []
	var max_buys_this_shop: int = _max_natural_buys_for_round(chapter_before, round_before)
	for buy_index: int in range(max_buys_this_shop):
		if int(Economy.gold) <= 1:
			break
		if _should_reserve_gold_for_round_four_gate(chapter_before, round_before):
			break
		var bought_id: String = await _buy_best_two_stage_offer(buy_index)
		if bought_id == "":
			break
		bought_ids.append(bought_id)
		await _settle_frames(3)
		var xp_after_buy: bool = await _buy_xp_if_needed("chapter %d round %d post-buy %d" % [chapter_before, round_before, buy_index], false)
		if xp_after_buy:
			_two_stage_buy_xp_clicks += 1
		await _deploy_until_blocked()

	var preferred_swaps: int = await _field_best_available_units("chapter %d round %d natural fielding" % [chapter_before, round_before])

	if chapter_before == 1 and round_before == 2:
		_expect(_board_ids().size() >= 2, "first shop should buy and deploy a second unit naturally; state=%s" % JSON.stringify(_two_stage_state()))
	if chapter_before == 1 and round_before == 4:
		_expect(_roster_max_team_size() >= 3, "round 4 cap should allow third deploy; state=%s" % JSON.stringify(_two_stage_state()))
		_expect(_board_ids().size() >= 3, "round 4 should deploy at least three units before combat; state=%s" % JSON.stringify(_two_stage_state()))

	result["bought_ids"] = bought_ids
	result["gold_after_shop"] = int(Economy.gold)
	result["level_after_shop"] = int(Shop.get_level())
	result["cap_after_shop"] = _roster_max_team_size()
	result["board_after_shop"] = _board_ids()
	result["bench_after_shop"] = _bench_ids()
	result["preferred_swaps"] = preferred_swaps

	_set_planning_timer_safe()
	await _press_continue(false, "natural two-stage chapter %d round %d" % [chapter_before, round_before])
	var combat_seen: bool = await _wait_for_combat_active(3.0)
	if not combat_seen and _advanced_from(chapter_before, round_before, int(GameState.chapter), int(GameState.stage_in_chapter)):
		result["resolved"] = true
		result["fight_result"] = "shop"
		result["chapter_after"] = int(GameState.chapter)
		result["round_after"] = int(GameState.stage_in_chapter)
		result["gold_after"] = int(Economy.gold)
		result["board_after"] = _board_ids()
		result["bench_after"] = _bench_ids()
		result["advanced"] = true
		_two_stage_battles += 1
		if _flow_verbose_round_logs():
			print("%s: round_result %s" % [_flow_smoke_name(), JSON.stringify(result)])
		else:
			print("%s: chapter=%d round=%d result=shop advanced=true next=%d:%d board=%d bench=%d gold=%d fast_resolved=true" % [
				_flow_smoke_name(),
				chapter_before,
				round_before,
				int(result.get("chapter_after", -1)),
				int(result.get("round_after", -1)),
				_board_ids().size(),
				_bench_ids().size(),
				int(Economy.gold),
			])
		return result
	_expect(combat_seen, "natural two-stage Start Battle did not enter combat; state=%s" % JSON.stringify(_two_stage_state()))
	if not combat_seen:
		result["resolved"] = false
		result["fight_result"] = "start_not_entered"
		result["chapter_after"] = int(GameState.chapter)
		result["round_after"] = int(GameState.stage_in_chapter)
		result["gold_after"] = int(Economy.gold)
		result["board_after"] = _board_ids()
		result["bench_after"] = _bench_ids()
		result["advanced"] = false
		return result
	var resolved: bool = await _wait_for_preview_or_loss(_flow_round_timeout())
	var fight_result: String = _second_fight_result(resolved)
	result["resolved"] = resolved
	result["fight_result"] = fight_result
	result["chapter_after"] = int(GameState.chapter)
	result["round_after"] = int(GameState.stage_in_chapter)
	result["gold_after"] = int(Economy.gold)
	result["board_after"] = _board_ids()
	result["bench_after"] = _bench_ids()
	result["advanced"] = resolved and fight_result == "shop" and _advanced_from(chapter_before, round_before, int(GameState.chapter), int(GameState.stage_in_chapter))
	if _flow_verbose_round_logs():
		print("%s: round_result %s" % [_flow_smoke_name(), JSON.stringify(result)])
	else:
		print("%s: chapter=%d round=%d result=%s advanced=%s next=%d:%d board=%d bench=%d gold=%d" % [
			_flow_smoke_name(),
			chapter_before,
			round_before,
			fight_result,
			str(bool(result.get("advanced", false))),
			int(result.get("chapter_after", -1)),
			int(result.get("round_after", -1)),
			_board_ids().size(),
			_bench_ids().size(),
			int(Economy.gold),
		])
	if resolved and (fight_result == "shop" or fight_result == "loss"):
		_two_stage_battles += 1
	return result

func _can_retry_after_same_stage(round_result: Dictionary) -> bool:
	if String(round_result.get("fight_result", "")) != "shop":
		return false
	if not bool(round_result.get("resolved", false)):
		return false
	if int(round_result.get("chapter_after", -1)) != int(round_result.get("chapter_before", -2)):
		return false
	if int(round_result.get("round_after", -1)) != int(round_result.get("round_before", -2)):
		return false
	return int(Economy.gold) > 0

func _buy_xp_if_needed(label: String, before_buys: bool = false) -> bool:
	if int(Economy.gold) < _flow_safe_buy_xp_gold():
		return false
	if before_buys and _should_buy_upgrade_before_xp():
		return false
	if not _bench_ids().is_empty() and _board_ids().size() >= _roster_max_team_size():
		return await _click_buy_xp(label)
	if int(GameState.chapter) == 1 and int(GameState.stage_in_chapter) >= 4 and int(Shop.get_level()) < 2:
		return await _click_buy_xp(label)
	return false

func _click_buy_xp(label: String) -> bool:
	var button: Button = _button_with_text("Buy XP")
	_expect(button != null, "%s Buy XP button missing" % label)
	if button == null:
		return false
	_expect(not button.disabled, "%s Buy XP button disabled with state=%s" % [label, JSON.stringify(_two_stage_state())])
	if button.disabled:
		return false
	var before_gold: int = int(Economy.gold)
	var before_level: int = int(Shop.get_level())
	var clicked: bool = await _click_button(button, "%s Buy XP" % label)
	await _settle_frames(4)
	_expect(clicked, "%s Buy XP click did not fire" % label)
	_expect(int(Economy.gold) == before_gold - int(SHOP_CONFIG.BUY_XP_COST), "%s Buy XP should spend exactly %d gold; state=%s" % [label, int(SHOP_CONFIG.BUY_XP_COST), JSON.stringify(_two_stage_state())])
	_expect(int(Shop.get_level()) >= before_level, "%s Buy XP should not reduce level; state=%s" % [label, JSON.stringify(_two_stage_state())])
	return clicked

func _buy_best_two_stage_offer(buy_index: int) -> String:
	var summaries: Array[Dictionary] = _offer_summaries()
	var best_slot: int = -1
	var best_score: int = -9999
	var best_id: String = ""
	var best_cost: int = 0
	for summary: Dictionary in summaries:
		var unit_id: String = String(summary.get("id", ""))
		var cost: int = int(summary.get("cost", 0))
		if unit_id == "" or cost <= 0:
			continue
		if not _can_afford_shop_cost(cost):
			continue
		var score: int = _two_stage_offer_score(summary)
		if score > best_score:
			best_score = score
			best_slot = int(summary.get("slot", -1))
			best_id = unit_id
			best_cost = cost
	if best_slot < 0:
		return ""
	if _should_skip_full_board_buy(best_id, best_cost):
		return ""
	var clicked: bool = await _click_shop_slot(best_slot)
	_expect(clicked, "natural two-stage buy %d failed on slot %d; state=%s" % [buy_index, best_slot, JSON.stringify(_two_stage_state())])
	return best_id if clicked else ""

func _should_skip_full_board_buy(unit_id: String, cost: int) -> bool:
	var cap: int = _roster_max_team_size()
	if cap < 0:
		return false
	if _board_ids().size() < cap:
		return false
	if int(Economy.gold) - cost >= _flow_safe_buy_xp_gold():
		return false
	if _would_bought_unit_improve_field(unit_id, cap):
		return false
	if not _bench_ids().is_empty():
		return true
	return not _would_bought_unit_improve_field(unit_id, cap)

func _can_afford_shop_cost(cost: int) -> bool:
	var in_combat: bool = GameState != null and int(GameState.phase) == int(GameState.GamePhase.COMBAT)
	var bet: int = int(Economy.current_bet) if Economy != null else 0
	var spent: int = int(Economy.combat_spent) if Economy != null and in_combat else 0
	var aff: Dictionary = ShopAffordabilityLib.can_afford(int(Economy.gold), bet, int(cost), in_combat, spent)
	return bool(aff.get("ok", false))

func _would_bought_unit_improve_field(unit_id: String, cap: int) -> bool:
	if unit_id == "":
		return false
	var current_desired: Array[String] = _best_field_ids(cap)
	var candidate_available: Array[String] = _board_ids()
	candidate_available.append_array(_bench_ids())
	candidate_available.append(unit_id)
	var candidate_desired: Array[String] = _best_field_ids_from_available(cap, candidate_available)
	return candidate_desired.has(unit_id) and not current_desired.has(unit_id)

func _should_buy_upgrade_before_xp() -> bool:
	var best_upgrade_cost: int = _best_upgrade_offer_cost()
	if best_upgrade_cost <= 0:
		return false
	var gold_after_xp: int = int(Economy.gold) - int(SHOP_CONFIG.BUY_XP_COST)
	return gold_after_xp < best_upgrade_cost + 1

func _best_upgrade_offer_cost() -> int:
	var best_cost: int = 0
	var best_score: int = -999999
	for summary: Dictionary in _offer_summaries():
		var cost: int = int(summary.get("cost", 0))
		if cost <= 0 or cost > max(0, int(Economy.gold) - 1):
			continue
		var score: int = _two_stage_offer_score(summary)
		if score >= 180 and score > best_score:
			best_score = score
			best_cost = cost
	return best_cost

func _two_stage_offer_score(summary: Dictionary) -> int:
	var unit_id: String = String(summary.get("id", ""))
	var primary_role: String = String(summary.get("primary_role", ""))
	var cost: int = int(summary.get("cost", 0))
	var owned_ids: Array[String] = _board_ids()
	owned_ids.append_array(_bench_ids())
	var duplicate_penalty: int = -35 if owned_ids.has(unit_id) else 0
	var frontline_count: int = _frontline_count(owned_ids)
	var support_count: int = _role_count(owned_ids, "support")
	var role_score: int = 0
	match primary_role:
		"tank":
			role_score = 115 if frontline_count < 2 else 40
		"marksman":
			role_score = 78 if frontline_count > 0 else 55
		"mage":
			role_score = 72 if frontline_count > 0 else 50
		"brawler":
			role_score = 108 if frontline_count < 2 else 70
		"support":
			role_score = -30 if support_count > 0 else 30
		_:
			role_score = 20
	return cost * 80 + role_score + duplicate_penalty

func _deploy_until_blocked() -> int:
	var deployed_count: int = 0
	var attempts: int = 0
	while attempts < MAX_RANDOM_DEPLOY_ATTEMPTS and not _bench_ids().is_empty():
		attempts += 1
		var before_board_size: int = _board_ids().size()
		var moved: bool = await _drag_first_bench_unit_to_board()
		await _settle_frames(4)
		var after_board_size: int = _board_ids().size()
		if moved and after_board_size > before_board_size:
			deployed_count += 1
		else:
			break
	return deployed_count

func _field_best_available_units(label: String) -> int:
	var cap: int = _roster_max_team_size()
	if cap < 0:
		return 0
	var desired: Array[String] = _best_field_ids(cap)
	if desired.is_empty():
		return 0
	return await _field_preferred_units(desired, _board_ids(), label)

func _best_field_ids(cap: int) -> Array[String]:
	var available: Array[String] = _board_ids()
	available.append_array(_bench_ids())
	return _best_field_ids_from_available(cap, available)

func _best_field_ids_from_available(cap: int, available: Array[String]) -> Array[String]:
	var desired: Array[String] = []
	if available.has(_flow_starter_id()):
		desired.append(_flow_starter_id())
	var max_tanks: int = 2
	var frontline_available: int = _frontline_count(available)
	var min_frontline: int = mini(frontline_available, 2 if cap >= 2 else 1)
	var damage_available: int = _damage_count(available)
	var min_damage: int = mini(damage_available, 2 if cap >= 4 else 1 if cap >= 3 else 0)
	while desired.size() < cap and desired.size() < available.size():
		var best_id: String = ""
		var best_score: int = -999999
		var needs_frontline: bool = _frontline_count(desired) < min_frontline
		var needs_damage: bool = _damage_count(desired) < min_damage
		for unit_id: String in available:
			if desired.has(unit_id):
				continue
			if needs_frontline and not _is_frontline_unit(unit_id):
				continue
			if not needs_frontline and needs_damage and not _is_damage_unit(unit_id):
				continue
			if _unit_role(unit_id) == "support" and _role_count(desired, "support") >= 1 and _has_non_support_candidate(available, desired):
				continue
			if _unit_role(unit_id) == "tank" and _role_count(desired, "tank") >= max_tanks:
				continue
			var score: int = _field_score(unit_id)
			if score > best_score:
				best_score = score
				best_id = unit_id
		if best_id == "":
			for unit_id: String in available:
				if desired.has(unit_id):
					continue
				var fallback_score: int = _field_score(unit_id)
				if fallback_score > best_score:
					best_score = fallback_score
					best_id = unit_id
		if best_id == "":
			break
		desired.append(best_id)
	return desired

func _field_score(unit_id: String) -> int:
	var catalog: UnitCatalog = UnitCatalogLib.new()
	catalog.refresh()
	var cost: int = catalog.get_cost(unit_id) if catalog.has_id(unit_id) else 1
	var role: String = catalog.get_primary_role(unit_id) if catalog.has_id(unit_id) else ""
	var role_score: int = 0
	match role:
		"tank":
			role_score = 65
		"marksman":
			role_score = 60
		"mage":
			role_score = 58
		"brawler":
			role_score = 52
		"support":
			role_score = 40
		_:
			role_score = 20
	var starter_bonus: int = 250 if unit_id == _flow_starter_id() else 0
	return cost * 100 + role_score + starter_bonus

func _unit_role(unit_id: String) -> String:
	var catalog: UnitCatalog = UnitCatalogLib.new()
	catalog.refresh()
	return catalog.get_primary_role(unit_id) if catalog.has_id(unit_id) else ""

func _is_frontline_unit(unit_id: String) -> bool:
	var role: String = _unit_role(unit_id)
	return role == "tank" or role == "brawler"

func _is_damage_unit(unit_id: String) -> bool:
	var role: String = _unit_role(unit_id)
	return role == "brawler" or role == "marksman" or role == "mage" or role == "assassin"

func _damage_count(unit_ids: Array[String]) -> int:
	var count: int = 0
	for unit_id: String in unit_ids:
		if _is_damage_unit(unit_id):
			count += 1
	return count

func _has_non_support_candidate(available: Array[String], desired: Array[String]) -> bool:
	for unit_id: String in available:
		if desired.has(unit_id):
			continue
		if _unit_role(unit_id) != "support":
			return true
	return false

func _role_count(unit_ids: Array[String], role: String) -> int:
	var count: int = 0
	for unit_id: String in unit_ids:
		if _unit_role(unit_id) == role:
			count += 1
	return count

func _field_preferred_units(field_ids: Array[String], bench_out_ids: Array[String], label: String) -> int:
	var swaps: int = 0
	for field_id: String in field_ids:
		if _board_ids().has(field_id):
			continue
		if not _bench_ids().has(field_id):
			continue
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

func _next_board_swap_id(field_ids: Array[String], bench_out_ids: Array[String]) -> String:
	var board: Array[String] = _board_ids()
	var desired_counts: Dictionary = _id_counts(field_ids)
	var seen_counts: Dictionary = {}
	for unit_id: String in bench_out_ids:
		if not board.has(unit_id):
			continue
		seen_counts[unit_id] = int(seen_counts.get(unit_id, 0)) + 1
		if int(seen_counts.get(unit_id, 0)) > int(desired_counts.get(unit_id, 0)):
			return unit_id
	for board_id: String in board:
		if not field_ids.has(board_id):
			return board_id
	return ""

func _id_counts(unit_ids: Array[String]) -> Dictionary:
	var counts: Dictionary = {}
	for unit_id: String in unit_ids:
		counts[unit_id] = int(counts.get(unit_id, 0)) + 1
	return counts

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
			print("%s: %s fallback bench_to_board route_ok=%s status=%s" % [_flow_smoke_name(), label, str(route_ok), JSON.stringify(router.last_route_status)])
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
			print("%s: %s fallback board_to_bench route_ok=%s status=%s" % [_flow_smoke_name(), label, str(route_ok), JSON.stringify(router.last_route_status)])
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

func _should_reserve_gold_for_round_four_gate(chapter_before: int, round_before: int) -> bool:
	if chapter_before != 1:
		return false
	if round_before < 4:
		return false
	if int(Shop.get_level()) >= 2:
		return false
	return int(Economy.gold) < _flow_safe_buy_xp_gold() + 1

func _max_natural_buys_for_round(chapter_before: int, round_before: int) -> int:
	if chapter_before == 1 and round_before <= 4:
		return 1
	return _flow_max_buys_per_shop()

func _advanced_from(chapter_before: int, round_before: int, chapter_after: int, round_after: int) -> bool:
	if chapter_after > chapter_before:
		return true
	if chapter_after == chapter_before and round_after > round_before:
		return true
	return false

func _reached_two_stage_target() -> bool:
	if int(GameState.chapter) > _flow_target_chapter():
		return true
	if int(GameState.chapter) == _flow_target_chapter() and int(GameState.stage_in_chapter) >= _flow_target_round():
		return true
	return false

func _flow_smoke_name() -> String:
	return TWO_STAGE_SMOKE_NAME

func _flow_starter_id() -> String:
	return TWO_STAGE_STARTER_ID

func _flow_shop_seed() -> int:
	return TWO_STAGE_SHOP_SEED

func _flow_first_fight_timeout() -> float:
	return TWO_STAGE_FIRST_FIGHT_TIMEOUT

func _flow_round_timeout() -> float:
	return TWO_STAGE_ROUND_TIMEOUT

func _flow_verbose_round_logs() -> bool:
	return true

func _flow_max_battles() -> int:
	return TWO_STAGE_MAX_BATTLES

func _flow_max_buys_per_shop() -> int:
	return TWO_STAGE_MAX_BUYS_PER_SHOP

func _flow_max_retries_per_stage() -> int:
	return TWO_STAGE_MAX_RETRIES_PER_STAGE

func _flow_safe_buy_xp_gold() -> int:
	return TWO_STAGE_SAFE_BUY_XP_GOLD

func _flow_target_chapter() -> int:
	return TWO_STAGE_TARGET_CHAPTER

func _flow_target_round() -> int:
	return TWO_STAGE_TARGET_ROUND

func _button_with_text(text: String) -> Button:
	if _main == null:
		return null
	var buttons: Array[Node] = _main.find_children("*", "Button", true, false)
	for node: Node in buttons:
		var button: Button = node as Button
		if button != null and (String(button.text) == text or String(button.text).begins_with(text + " ")):
			return button
	return null

func _roster_max_team_size() -> int:
	if Roster == null:
		return -1
	return int(Roster.get("max_team_size"))

func _two_stage_state() -> Dictionary:
	return {
		"chapter": int(GameState.chapter) if GameState != null else -1,
		"round": int(GameState.stage_in_chapter) if GameState != null else -1,
		"phase": int(GameState.phase) if GameState != null else -1,
		"gold": int(Economy.gold) if Economy != null else -1,
		"level": int(Shop.get_level()) if Shop != null else -1,
		"xp": int(Shop.get_xp()) if Shop != null else -1,
		"cap": _roster_max_team_size(),
		"board": _board_ids(),
		"bench": _bench_ids(),
		"offers": _offer_summaries(),
	}

func _finish_two_stage_flow() -> void:
	Engine.time_scale = _previous_time_scale
	UnitFactory.suppress_validation_warnings = _previous_suppress_validation_warnings
	_flush_synthetic_input()
	var exit_code: int = 0
	if _technical_failures().is_empty():
		print("%s: OK battles=%d target_chapter=%d target_round=%d buy_xp=%d state=%s" % [
			_flow_smoke_name(),
			_two_stage_battles,
			_flow_target_chapter(),
			_flow_target_round(),
			_two_stage_buy_xp_clicks,
			JSON.stringify(_two_stage_state()),
		])
	else:
		for failure: String in _technical_failures():
			push_error("%s: %s" % [_flow_smoke_name(), failure])
		print("%s: results=%s state=%s" % [_flow_smoke_name(), JSON.stringify(_two_stage_results), JSON.stringify(_two_stage_state())])
		exit_code = 1
	_cleanup_runtime()
	get_tree().process_frame.connect(_quit_after_cleanup.bind(exit_code, 10), CONNECT_ONE_SHOT)
