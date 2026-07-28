extends "res://tests/visual/first_shop_choice_quality_smoke.gd"

const RANDOM_LATER_SMOKE_NAME: String = "RandomLaterShopProgressionSmoke"
const SAMPLE_STARTERS: Array[String] = ["axiom", "berebell", "bo", "bonko", "brute", "cashmere", "grint", "knoll", "korath", "morrak", "mortem", "pilfer", "repo", "sari"]
const SAMPLE_SEEDS: Array[int] = [4101, 4201, 4301, 4401, 4501, 4601, 4701, 4751, 4801, 4901, 5001, 5051, 5101, 5201]
# The generic buyer must reach the first boss. Beating the escalated boss now
# requires item, combine, and encounter adaptation outside this route's scope.
const TARGET_STAGE: int = 4
const MAX_POST_OPENER_BATTLES: int = 5
const MAX_BUYS_PER_SHOP: int = 2
const AUDIT_GOLD_TARGET: int = 12
const RANDOM_SAFE_BUY_XP_GOLD: int = 6
const MIN_RANDOM_OFFER_SCORE: int = 70
const RANDOM_FIRST_FIGHT_TIMEOUT: float = 30.0
const RANDOM_ROUND_TIMEOUT: float = 42.0
const MAX_RANDOM_DEPLOY_ATTEMPTS: int = 10

var _sample_results: Array[Dictionary] = []
var _random_audit_gold_added: int = 0

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

	var sample_starters: Array[String] = _random_sample_starters()
	var sample_seeds: Array[int] = _random_sample_seeds()
	if sample_starters.size() != sample_seeds.size():
		_expect(false, "random later starter/seed sample arrays must match")
		_finish_random_later_shop_progression()
		return

	for sample_index: int in range(sample_seeds.size()):
		var starter_id: String = sample_starters[sample_index]
		var seed: int = sample_seeds[sample_index]
		var sample_result: Dictionary = await _run_seeded_sample(seed, starter_id)
		_sample_results.append(sample_result)
		await _cleanup_between_starters()
		if not bool(sample_result.get("reached_target", false)):
			_expect(false, "starter %s seed %d did not reach Stage %d: %s" % [starter_id, seed, _random_target_stage(), JSON.stringify(sample_result)])
			break
		if not _technical_failures().is_empty():
			break
	_finish_random_later_shop_progression()

func _run_seeded_sample(seed: int, starter_id: String) -> Dictionary:
	var failure_start: int = _failures.size()
	var shop_error_start: int = _shop_errors.size()
	_set_shop_seed(seed)
	_start_main_scene()
	await _settle_frames(4)
	await _ensure_unit_select()
	await _select_starter(starter_id)
	await _settle_frames(4)

	_set_planning_timer_safe()
	var first_shop_ready: bool = await _wait_for_shop_after_win(RANDOM_FIRST_FIGHT_TIMEOUT)
	_expect(first_shop_ready, "random later starter %s seed %d opener should auto-resolve into shop" % [starter_id, seed])
	if not first_shop_ready:
		return _sample_output(seed, starter_id, [], failure_start, shop_error_start)

	var battle_results: Array[Dictionary] = []
	var post_opener_battles: int = 0
	while int(GameState.stage_in_chapter) < _random_target_stage() and post_opener_battles < _random_max_post_opener_battles():
		var battle_result: Dictionary = await _play_random_shop_round(starter_id, seed, post_opener_battles + 1)
		battle_results.append(battle_result)
		if not bool(battle_result.get("resolved", false)):
			break
		if String(battle_result.get("fight_result", "")) == "loss":
			break
		post_opener_battles += 1
		if not _failures_since(failure_start).is_empty():
			break
	return _sample_output(seed, starter_id, battle_results, failure_start, shop_error_start)

func _play_random_shop_round(starter_id: String, seed: int, round_index: int) -> Dictionary:
	var stage_before: int = int(GameState.stage_in_chapter)
	var board_before: Array[String] = _board_ids()
	var result: Dictionary = {
		"starter": starter_id,
		"round_index": round_index,
		"stage_before": stage_before,
		"offers_before": _offer_summaries(),
		"board_before": board_before,
	}
	_random_audit_gold_added += _add_random_audit_gold_to_at_least(_random_audit_gold_target())
	await _settle_frames(2)
	var bought_ids: Array[String] = []
	for buy_index: int in range(_random_max_buys_per_shop()):
		var bought_id: String = await _buy_best_random_offer(starter_id, seed, round_index, buy_index)
		if bought_id == "":
			break
		bought_ids.append(bought_id)
		await _settle_frames(3)
	result["bought_ids"] = bought_ids
	result["bench_after_buys"] = _bench_ids()
	var deployed_count: int = await _deploy_all_random_bench_units()
	var buy_xp_count: int = await _buy_random_xp_if_bench_blocked(starter_id, seed, round_index)
	if buy_xp_count > 0:
		result["buy_xp_count"] = buy_xp_count
		deployed_count += await _deploy_all_random_bench_units()
	result["deployed_count"] = deployed_count
	result["bench_after_deploy"] = _bench_ids()
	result["board_after_deploy"] = _board_ids()
	result["cap_after_deploy"] = _roster_max_team_size()
	_expect(not bought_ids.is_empty(), "random later starter %s seed %d round %d should buy at least one natural offer from %s" % [starter_id, seed, round_index, JSON.stringify(result.get("offers_before", []))])
	_expect(not _board_ids().is_empty(), "random later starter %s seed %d round %d should have a board before combat" % [starter_id, seed, round_index])
	if bought_ids.is_empty() or _board_ids().is_empty():
		return result

	_set_planning_timer_safe()
	await _press_continue(false, "random later %s seed %d round %d battle" % [starter_id, seed, round_index])
	var combat_seen: bool = await _wait_for_combat_active(3.0)
	_expect(combat_seen, "random later starter %s seed %d round %d did not enter combat after Start Battle" % [starter_id, seed, round_index])
	if not combat_seen:
		result["resolved"] = false
		result["fight_result"] = "start_not_entered"
		result["stage_after"] = int(GameState.stage_in_chapter)
		result["advanced"] = false
		result["gold_after"] = int(Economy.gold)
		return result
	var resolved: bool = await _wait_for_preview_or_loss(RANDOM_ROUND_TIMEOUT)
	var fight_result: String = _second_fight_result(resolved)
	var stage_after: int = int(GameState.stage_in_chapter)
	result["resolved"] = resolved
	result["fight_result"] = fight_result
	result["stage_after"] = stage_after
	result["advanced"] = fight_result == "shop" and stage_after > stage_before
	result["gold_after"] = int(Economy.gold)
	_expect(resolved, "random later starter %s seed %d round %d did not resolve" % [starter_id, seed, round_index])
	return result

func _buy_best_random_offer(starter_id: String, seed: int, round_index: int, buy_index: int) -> String:
	var summaries: Array[Dictionary] = _offer_summaries()
	var best_slot: int = -1
	var best_score: int = -9999
	var best_id: String = ""
	for summary: Dictionary in summaries:
		var unit_id: String = String(summary.get("id", ""))
		var cost: int = int(summary.get("cost", 0))
		if unit_id == "" or cost <= 0:
			continue
		if cost > int(Economy.gold):
			continue
		var score: int = _random_offer_score(summary)
		if score > best_score:
			best_score = score
			best_slot = int(summary.get("slot", -1))
			best_id = unit_id
	if best_slot < 0 or best_score < MIN_RANDOM_OFFER_SCORE:
		return ""
	var clicked: bool = await _click_shop_slot(best_slot)
	_expect(clicked, "random later starter %s seed %d round %d buy %d failed on slot %d" % [starter_id, seed, round_index, buy_index, best_slot])
	return best_id if clicked else ""

func _random_offer_score(summary: Dictionary) -> int:
	var unit_id: String = String(summary.get("id", ""))
	var primary_role: String = String(summary.get("primary_role", ""))
	var owned_ids: Array[String] = _board_ids()
	owned_ids.append_array(_bench_ids())
	var duplicate_penalty: int = -30 if owned_ids.has(unit_id) else 0
	var frontline_count: int = _frontline_count(owned_ids)
	match primary_role:
		"tank":
			return (110 if frontline_count < 2 else 70) + duplicate_penalty
		"brawler":
			return (105 if frontline_count < 2 else 85) + duplicate_penalty
		"marksman":
			return 90 + duplicate_penalty
		"mage":
			return 88 + duplicate_penalty
		"support":
			return 45 + duplicate_penalty
	return 50 + duplicate_penalty

func _frontline_count(unit_ids: Array[String]) -> int:
	var count: int = 0
	var catalog: UnitCatalog = UnitCatalogLib.new()
	catalog.refresh()
	for unit_id: String in unit_ids:
		var role: String = catalog.get_primary_role(unit_id) if catalog.has_id(unit_id) else ""
		if role == "tank" or role == "brawler":
			count += 1
	return count

func _deploy_all_random_bench_units() -> int:
	var deployed_count: int = 0
	var attempts: int = 0
	while attempts < _random_max_deploy_attempts() and not _bench_ids().is_empty():
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

func _buy_random_xp_if_bench_blocked(starter_id: String, seed: int, round_index: int) -> int:
	var purchases: int = 0
	while not _bench_ids().is_empty() and _board_is_at_cap() and int(Economy.gold) >= _random_safe_buy_xp_gold():
		var button: Button = _button_with_text_prefix("Buy XP")
		_expect(button != null, "random later starter %s seed %d round %d Buy XP button missing" % [starter_id, seed, round_index])
		if button == null:
			return purchases
		_expect(not button.disabled, "random later starter %s seed %d round %d Buy XP disabled with gold=%d cap=%d board=%s bench=%s" % [starter_id, seed, round_index, int(Economy.gold), _roster_max_team_size(), JSON.stringify(_board_ids()), JSON.stringify(_bench_ids())])
		if button.disabled:
			return purchases
		var before_gold: int = int(Economy.gold)
		var before_level: int = int(Shop.get_level())
		var clicked: bool = await _click_button(button, "random later %s seed %d round %d Buy XP" % [starter_id, seed, round_index])
		await _settle_frames(4)
		_expect(clicked, "random later starter %s seed %d round %d Buy XP click did not fire" % [starter_id, seed, round_index])
		if not clicked:
			return purchases
		purchases += 1
		_expect(int(Economy.gold) == before_gold - int(SHOP_CONFIG.BUY_XP_COST), "random later starter %s seed %d round %d Buy XP should spend %d gold" % [starter_id, seed, round_index, int(SHOP_CONFIG.BUY_XP_COST)])
		_expect(int(Shop.get_level()) >= before_level, "random later starter %s seed %d round %d Buy XP should not lower level" % [starter_id, seed, round_index])
	return purchases

func _board_is_at_cap() -> bool:
	var cap: int = _roster_max_team_size()
	if cap < 0:
		return false
	return _board_ids().size() >= cap

func _roster_max_team_size() -> int:
	if Roster == null:
		return -1
	return int(Roster.get("max_team_size"))

func _button_with_text(text: String) -> Button:
	if _main == null:
		return null
	var buttons: Array[Node] = _main.find_children("*", "Button", true, false)
	for node: Node in buttons:
		var button: Button = node as Button
		if button != null and String(button.text) == text:
			return button
	return null

func _button_with_text_prefix(text: String) -> Button:
	if _main == null:
		return null
	var buttons: Array[Node] = _main.find_children("*", "Button", true, false)
	for node: Node in buttons:
		var button: Button = node as Button
		if button != null and String(button.text).begins_with(text):
			return button
	return null

func _add_random_audit_gold_to_at_least(target_gold: int) -> int:
	var before_gold: int = int(Economy.gold)
	if before_gold >= target_gold:
		return 0
	var delta: int = int(target_gold) - before_gold
	Economy.add_gold(delta)
	return delta

func _set_shop_seed(seed: int) -> void:
	var rng: Variant = Shop.get("_rng") if Shop != null else null
	if rng != null and rng.has_method("set_seed"):
		rng.call("set_seed", seed)
	else:
		_expect(false, "Shop RNG seed control unavailable")

func _sample_output(seed: int, starter_id: String, battle_results: Array[Dictionary], failure_start: int, shop_error_start: int) -> Dictionary:
	return {
		"starter": starter_id,
		"seed": seed,
		"reached_target": int(GameState.stage_in_chapter) >= _random_target_stage(),
		"final_stage": int(GameState.stage_in_chapter),
		"battle_results": battle_results,
		"technical_failures": _failures_since(failure_start),
		"shop_errors": _shop_errors_since(shop_error_start),
	}

func _finish_random_later_shop_progression() -> void:
	Engine.time_scale = _previous_time_scale
	UnitFactory.suppress_validation_warnings = _previous_suppress_validation_warnings
	_flush_synthetic_input()
	var exit_code: int = 0
	if _technical_failures().is_empty():
		var reached_count: int = 0
		for sample_result: Dictionary in _sample_results:
			if bool(sample_result.get("reached_target", false)):
				reached_count += 1
		print("%s: OK samples=%d reached=%d starters=%s target_stage=%d audit_gold_added=%d" % [
			RANDOM_LATER_SMOKE_NAME,
			_sample_results.size(),
			reached_count,
			JSON.stringify(_random_sample_starters()),
			_random_target_stage(),
			_random_audit_gold_added,
		])
	else:
		for failure: String in _technical_failures():
			push_error("%s: %s" % [RANDOM_LATER_SMOKE_NAME, failure])
		print("%s: results=%s" % [RANDOM_LATER_SMOKE_NAME, JSON.stringify(_sample_results)])
		exit_code = 1
	_cleanup_runtime()
	get_tree().process_frame.connect(_quit_after_cleanup.bind(exit_code, 10), CONNECT_ONE_SHOT)

func _random_sample_starters() -> Array[String]:
	return SAMPLE_STARTERS.duplicate()

func _random_sample_seeds() -> Array[int]:
	return SAMPLE_SEEDS.duplicate()

func _random_target_stage() -> int:
	return TARGET_STAGE

func _random_max_post_opener_battles() -> int:
	return MAX_POST_OPENER_BATTLES

func _random_max_buys_per_shop() -> int:
	return MAX_BUYS_PER_SHOP

func _random_audit_gold_target() -> int:
	return AUDIT_GOLD_TARGET

func _random_safe_buy_xp_gold() -> int:
	return RANDOM_SAFE_BUY_XP_GOLD

func _random_max_deploy_attempts() -> int:
	return MAX_RANDOM_DEPLOY_ATTEMPTS
