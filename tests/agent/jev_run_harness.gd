extends "res://tests/pacing/competent_policy_pacing_harness.gd"

## Jev plays Blood Will Pay.
##
## This harness runs one real campaign through scenes/Main.tscn with the same
## natural clicks and drags the longitudinal pacing harness uses. It differs in
## one place: the planning decisions a human player makes - starter, shop
## purchase, level purchase, wager, and chapter contract - are asked of an
## external TypeSafe Jev controller instead of a hardcoded heuristic.
##
## Bridge contract, where <dir> is the JEV_RUN_DIR environment variable:
##   harness -> <dir>/observation_<n>.json  (state + legal candidates)
##   controller -> <dir>/decision_<n>.json  (chosen candidate id)
## The controller owns decisions.jsonl; this harness owns run_events.jsonl and
## run_summary.json. Nothing is decided here - the harness only executes.
##
## JEV_MODE=heuristic replays the same seed through the inherited rule-based
## policy so a Jev run has a comparable baseline on identical seed and starter.

const JEV_HARNESS_NAME: String = "JevRunHarness"
const DEFAULT_RUN_DIR: String = "user://jev_run"
const JEV_RULES_PATH: String = "res://tools/jev/policy/jev_run_rules.json"
const DEFAULT_RESERVE_FLOOR_BUCKETS: int = 2
const DECISION_POLL_SECONDS: float = 0.05
const DECISION_TIMEOUT_SECONDS: float = 240.0
const CAMPAIGN_TARGET_CHAPTER: int = 2
const CAMPAIGN_TARGET_ROUND: int = 4
const CAMPAIGN_MAX_BATTLES: int = 30
const MAX_SAME_STAGE_RETRIES: int = 3
const WAGER_PRESET_SHARES: Array[float] = [0.0, 0.1, 0.25, 0.5, 0.75, 1.0]

var _run_dir: String = DEFAULT_RUN_DIR
var _run_mode: String = "jev"
var _campaign_seed: int = 4401
var _decision_index: int = 0
var _starter_id: String = "bonko"
var _battles: int = 0
var _rounds: Array[Dictionary] = []
var _events: Array[Dictionary] = []
var _decision_kinds: Dictionary[String, int] = {}
var _same_stage_retries: Dictionary[String, int] = {}
var _recent_fights: Array[Dictionary] = []
var _reserve_floor_buckets: int = DEFAULT_RESERVE_FLOOR_BUCKETS

func _run() -> void:
	_read_environment()
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
	_set_shop_seed(_campaign_seed)
	_prepare_run_dir()
	print("%s: boot mode=%s seed=%d target=chapter %d round %d" % [
		JEV_HARNESS_NAME,
		_run_mode,
		_campaign_seed,
		CAMPAIGN_TARGET_CHAPTER,
		CAMPAIGN_TARGET_ROUND,
	])
	_append_event("run_start", {
		"mode": _run_mode,
		"seed": _campaign_seed,
		"target_chapter": CAMPAIGN_TARGET_CHAPTER,
		"target_round": CAMPAIGN_TARGET_ROUND,
		"engine_time_scale": Engine.time_scale,
		"entrypoint": "scenes/Main.tscn",
	})

	_start_main_scene()
	await _settle_frames(10)
	await _ensure_unit_select()
	await _decide_starter()
	await _select_starter(_starter_id)
	await _settle_frames(6)
	if not _node_visible("CombatView"):
		_abort_run("CombatView did not open after starter selection")
		return
	_set_planning_timer_safe()
	var opener_result: String = ""
	var opener_attempts: int = 0
	while opener_attempts < MAX_SAME_STAGE_RETRIES:
		opener_attempts += 1
		await _start_opening_fight_if_waiting()
		opener_result = await _wait_for_first_result(_flow_first_fight_timeout())
		_append_event("opener_result", {
			"result": opener_result,
			"attempt": opener_attempts,
			"chapter": int(GameState.chapter),
			"round": int(GameState.stage_in_chapter),
		})
		if opener_result == "shop":
			break
		if opener_result == "loss":
			_append_event("run_end", {"reason": "opener_loss"})
			_finish_jev_run("opener_loss")
			return
		if opener_result == "retry":
			# A lost opener is recoverable and stays on chapter 1 stage 1.
			await _settle_frames(8)
			continue
		_abort_run("opener did not resolve into the first shop: %s" % opener_result)
		return
	if opener_result != "shop":
		_append_event("run_end", {"reason": "opener_stall", "attempts": opener_attempts})
		_finish_jev_run("opener_stall")
		return
	_battles = 1

	while _battles < CAMPAIGN_MAX_BATTLES and not _campaign_target_reached():
		var round_result: Dictionary = await _play_two_stage_round()
		_rounds.append(round_result)
		_append_event("round", round_result)
		_recent_fights.append({
			"chapter": int(round_result.get("chapter_before", -1)),
			"round": int(round_result.get("round_before", -1)),
			"result": String(round_result.get("fight_result", "")),
			"advanced": bool(round_result.get("advanced", false)),
			"board_after": round_result.get("board_after", []),
		})
		while _recent_fights.size() > 4:
			_recent_fights.remove_at(0)
		if get_tree().root.get_node_or_null("LossOverlayLayer") != null:
			_append_event("run_end", {"reason": "loss", "chapter": int(GameState.chapter), "round": int(GameState.stage_in_chapter)})
			_finish_jev_run("loss")
			return
		if bool(round_result.get("advanced", false)):
			_battles += 1
			continue
		if _can_retry_after_same_stage(round_result):
			var stage_key: String = "%d:%d" % [
				int(round_result.get("chapter_before", -1)),
				int(round_result.get("round_before", -1)),
			]
			var attempts: int = int(_same_stage_retries.get(stage_key, 0)) + 1
			_same_stage_retries[stage_key] = attempts
			_append_event("same_stage_retry", {
				"chapter": int(round_result.get("chapter_before", -1)),
				"round": int(round_result.get("round_before", -1)),
				"attempt": attempts,
				"fight_result": String(round_result.get("fight_result", "")),
				"board": round_result.get("board_after", []),
				"buckets": int(Economy.blood_buckets),
			})
			if attempts > MAX_SAME_STAGE_RETRIES:
				# A stage the run cannot convert is evidence, not something to grind
				# through: stop and let the analysis read the stall.
				_append_event("run_end", {
					"reason": "stage_stall",
					"chapter": int(round_result.get("chapter_before", -1)),
					"round": int(round_result.get("round_before", -1)),
					"attempts": attempts,
					"fight_result": String(round_result.get("fight_result", "")),
				})
				_finish_jev_run("stage_stall")
				return
			_battles += 1
			continue
		if String(round_result.get("fight_result", "")) == "loss":
			_append_event("run_end", {"reason": "loss", "chapter": int(GameState.chapter), "round": int(GameState.stage_in_chapter)})
			_finish_jev_run("loss")
			return
		_abort_run("campaign stopped: %s" % JSON.stringify(round_result))
		return
	if not _failures.is_empty():
		_finish_jev_run("technical_failure")
		return
	_finish_jev_run("target_reached" if _campaign_target_reached() else "battle_budget_reached")

func _campaign_target_reached() -> bool:
	if int(GameState.chapter) > CAMPAIGN_TARGET_CHAPTER:
		return true
	return int(GameState.chapter) == CAMPAIGN_TARGET_CHAPTER and int(GameState.stage_in_chapter) >= CAMPAIGN_TARGET_ROUND

func _second_fight_result(resolved: bool) -> String:
	# The inherited classifier falls back to "shop" whenever the phase returns to
	# PREVIEW, which makes a drawn or lost fight look like a completed stage and
	# turns the campaign loop into a retry treadmill. Classify from the live
	# settlement instead: an advanced stage is a win, a restored reserve is a tie,
	# and anything else is a loss.
	if not resolved:
		return "timeout"
	if get_tree().root.get_node_or_null("LossOverlayLayer") != null:
		return "loss"
	if _stage_advanced_from_round():
		return "shop"
	var reserve_start: int = int(Economy.last_blood_reserve_start)
	if reserve_start > 0 and int(Economy.blood_buckets) >= reserve_start:
		return "tie"
	return "loss"

func _stage_advanced_from_round() -> bool:
	if int(GameState.chapter) > _transition_chapter_before:
		return true
	if int(GameState.chapter) == _transition_chapter_before and int(GameState.stage_in_chapter) > _transition_round_before:
		return true
	return false

func _read_environment() -> void:
	var dir_value: String = OS.get_environment("JEV_RUN_DIR")
	if not dir_value.strip_edges().is_empty():
		_run_dir = dir_value.strip_edges()
	var mode_value: String = OS.get_environment("JEV_MODE").strip_edges().to_lower()
	if mode_value == "heuristic":
		_run_mode = "heuristic"
	var seed_value: String = OS.get_environment("JEV_RUN_SEED").strip_edges()
	if seed_value.is_valid_int():
		_campaign_seed = seed_value.to_int()
	var starter_value: String = OS.get_environment("JEV_STARTER").strip_edges().to_lower()
	if not starter_value.is_empty():
		_starter_id = starter_value
	_reserve_floor_buckets = _load_reserve_floor()

func _load_reserve_floor() -> int:
	# The floor lives in the policy file so the rules and the guard cannot drift.
	var raw_text: String = FileAccess.get_file_as_string(JEV_RULES_PATH) if FileAccess.file_exists(JEV_RULES_PATH) else ""
	var trimmed: String = raw_text.strip_edges()
	if trimmed.length() < 2 or not trimmed.begins_with("{"):
		return DEFAULT_RESERVE_FLOOR_BUCKETS
	var parsed: Variant = JSON.parse_string(trimmed)
	if not parsed is Dictionary:
		return DEFAULT_RESERVE_FLOOR_BUCKETS
	var reserve: Variant = (parsed as Dictionary).get("reserve", {})
	if reserve is Dictionary:
		var floor_value: Variant = (reserve as Dictionary).get("minimum_reserve_buckets", DEFAULT_RESERVE_FLOOR_BUCKETS)
		if floor_value is float or floor_value is int:
			return max(1, int(floor_value))
	return DEFAULT_RESERVE_FLOOR_BUCKETS

func _prepare_run_dir() -> void:
	DirAccess.make_dir_recursive_absolute(_run_dir)
	if not DirAccess.dir_exists_absolute(_run_dir):
		push_error("%s: run directory is not writable: %s" % [JEV_HARNESS_NAME, _run_dir])

func _flow_smoke_name() -> String:
	return JEV_HARNESS_NAME

func _flow_sample_id() -> String:
	return "jev_%s_seed_%d" % [_run_mode, _campaign_seed]

func _flow_output_stem() -> String:
	return "jev_run_%s" % _run_mode

func _flow_starter_id() -> String:
	return _starter_id

func _flow_shop_seed() -> int:
	return _campaign_seed

func _flow_target_chapter() -> int:
	return CAMPAIGN_TARGET_CHAPTER

func _flow_target_round() -> int:
	return CAMPAIGN_TARGET_ROUND

func _flow_max_battles() -> int:
	return CAMPAIGN_MAX_BATTLES

func _flow_verbose_round_logs() -> bool:
	return true

# --- decision seams ---------------------------------------------------------

func _decide_starter() -> void:
	if _run_mode != "jev":
		return
	var select: UnitSelect = _main.get_node_or_null("UnitSelect") as UnitSelect
	if select == null:
		_abort_run("unit select missing for the starter decision")
		return
	var candidates: Array[Dictionary] = []
	for raw_id: Variant in select.buttons_by_id.keys():
		var unit_id: String = String(raw_id)
		var button: Button = select.buttons_by_id[raw_id] as Button
		var label: String = unit_id
		if button != null and not button.text.strip_edges().is_empty():
			label = button.text.strip_edges().replace("\n", " / ")
		candidates.append({
			"id": unit_id,
			"label": label,
			"effect": "Start the run with %s." % unit_id,
		})
	if candidates.is_empty():
		_abort_run("no starter candidates were offered")
		return
	var decision: Dictionary = await _ask_decision("starter", _plan_state(), candidates)
	var chosen: String = String(decision.get("choice_id", ""))
	for candidate: Dictionary in candidates:
		if String(candidate.get("id", "")) == chosen:
			_starter_id = chosen
			_append_event("starter_selected", {"unit_id": _starter_id, "shown_label": String(candidate.get("label", ""))})
			return
	_append_event("decision_rejected", {"kind": "starter", "choice_id": chosen, "reason": "not_a_starter_candidate"})
	_starter_id = String(candidates[0].get("id", "bonko"))

func _buy_best_two_stage_offer(buy_index: int) -> String:
	if _run_mode != "jev":
		return await super._buy_best_two_stage_offer(buy_index)
	var candidates: Array[Dictionary] = _shop_candidates()
	if candidates.is_empty():
		return ""
	var state: Dictionary = _plan_state()
	state["buy_index"] = buy_index
	var decision: Dictionary = await _ask_decision("shop_buy", state, candidates)
	var chosen: String = String(decision.get("choice_id", ""))
	if chosen == "pass":
		_append_event("shop_pass", {"buy_index": buy_index, "review_flags": decision.get("review_flags", [])})
		return ""
	for candidate: Dictionary in candidates:
		if String(candidate.get("id", "")) != chosen:
			continue
		var slot: int = int(candidate.get("slot", -1))
		var unit_id: String = String(candidate.get("unit_id", ""))
		var cost: int = int(candidate.get("cost", 0))
		var reserve_after: int = int(Economy.gold) - cost
		if reserve_after < _reserve_floor_buckets:
			# The policy asks for a reserve floor and the model still buys through
			# it, so this state gets its own focused question instead of another
			# line in the general rules.
			var confirmed: bool = await _confirm_reserve_break(
				"buy %s for %d buckets" % [unit_id, cost],
				reserve_after,
			)
			if not confirmed:
				_append_event("reserve_guard_pass", {
					"kind": "shop_buy",
					"unit_id": unit_id,
					"cost": cost,
					"reserve_after": reserve_after,
					"floor": _reserve_floor_buckets,
				})
				return ""
		var gold_before: int = int(Economy.gold)
		var clicked: bool = await _click_shop_slot(slot)
		await _settle_frames(3)
		_append_event("shop_purchase", {
			"buy_index": buy_index,
			"slot": slot,
			"unit_id": unit_id,
			"cost": int(candidate.get("cost", 0)),
			"gold_before": gold_before,
			"gold_after": int(Economy.gold),
			"clicked": clicked,
		})
		return unit_id if clicked else ""
	_append_event("decision_rejected", {"kind": "shop_buy", "choice_id": chosen, "reason": "not_an_offer_candidate"})
	return ""

func _buy_xp_if_needed(label: String, before_buys: bool = false) -> bool:
	if _run_mode != "jev":
		return await super._buy_xp_if_needed(label, before_buys)
	if not _level_purchase_is_legal():
		return false
	var gold: int = int(Economy.gold)
	var candidates: Array[Dictionary] = [
		{
			"id": "buy_xp",
			"label": "Buy XP for %d buckets (level %d -> capacity %d)." % [
				int(SHOP_CONFIG.BUY_XP_COST),
				int(Shop.get_level()),
				_level_board_capacity(_level_after_xp_purchase(int(Shop.get_level()), int(Shop.get_xp()))),
			],
			"effect": "Spend %d of %d buckets on %d XP." % [int(SHOP_CONFIG.BUY_XP_COST), gold, int(SHOP_CONFIG.XP_PER_BUY)],
		},
		{"id": "pass", "label": "Do not buy XP now.", "effect": "Keep %d buckets for bodies." % gold},
	]
	var state: Dictionary = _plan_state()
	state["decision_label"] = label
	state["before_buys"] = before_buys
	var decision: Dictionary = await _ask_decision("buy_xp", state, candidates)
	var chosen: String = String(decision.get("choice_id", ""))
	if chosen != "buy_xp":
		return false
	var xp_price: int = int(SHOP_CONFIG.BUY_XP_COST)
	var xp_reserve_after: int = int(Economy.gold) - xp_price
	if xp_reserve_after < _reserve_floor_buckets:
		var confirmed_xp: bool = await _confirm_reserve_break(
			"buy %d XP for %d buckets" % [int(SHOP_CONFIG.XP_PER_BUY), xp_price],
			xp_reserve_after,
		)
		if not confirmed_xp:
			_append_event("reserve_guard_pass", {
				"kind": "buy_xp",
				"cost": xp_price,
				"reserve_after": xp_reserve_after,
				"floor": _reserve_floor_buckets,
			})
			return false
	var gold_before: int = int(Economy.gold)
	var bought: bool = await _click_buy_xp(label)
	_append_event("buy_xp", {
		"label": label,
		"before_buys": before_buys,
		"bought": bought,
		"gold_before": gold_before,
		"gold_after": int(Economy.gold),
		"level_after": int(Shop.get_level()),
	})
	return bought

func _confirm_reserve_break(description: String, reserve_after: int) -> bool:
	var candidates: Array[Dictionary] = [
		{
			"id": "confirm",
			"label": "Do it anyway: %s, leaving %d buckets." % [description, reserve_after],
			"effect": "Spend below the reserve floor of %d. The next fight is then fought with less than the floor in hand, and losing it can end the run." % _reserve_floor_buckets,
		},
		{
			"id": "back_out",
			"label": "Keep the reserve and skip this spend (%d buckets stay)." % int(Economy.gold),
			"effect": "The floor holds, the next fight is played with the current board, and the buckets stay available for the following shop.",
		},
	]
	var state: Dictionary = _plan_state()
	state["decision_label"] = "reserve floor check: %s" % description
	state["reserve_floor_buckets"] = _reserve_floor_buckets
	state["reserve_after"] = reserve_after
	var decision: Dictionary = await _ask_decision("reserve_override", state, candidates)
	return String(decision.get("choice_id", "")) == "confirm"

func _level_purchase_is_legal() -> bool:
	if Economy == null or Shop == null:
		return false
	if int(GameState.phase) == int(GameState.GamePhase.COMBAT):
		return false
	if int(Shop.get_level()) >= int(SHOP_CONFIG.MAX_LEVEL):
		return false
	return int(Economy.gold) >= int(SHOP_CONFIG.BUY_XP_COST)

func _press_continue(expect_forced: bool, label: String) -> void:
	# Resolve the chapter contract before asking about the wager so the wager is
	# chosen against the real post-contract reserve, then hand off to the shared
	# start-battle click path.
	await _resolve_pending_contract_market()
	await _decide_wager(label)
	await super._press_continue(expect_forced, label)

func _decide_wager(label: String) -> void:
	if _run_mode != "jev":
		return
	var slider: HSlider = _main.find_child("BetSlider", true, false) as HSlider if _main != null else null
	if slider == null or not slider.editable:
		# The forced opener locks the wager to the game default; the player has no
		# choice there, so the rig does not invent one.
		return
	var reserve: int = int(Economy.blood_buckets)
	if reserve <= 0:
		return
	var candidates: Array[Dictionary] = _wager_candidates(reserve)
	if candidates.is_empty():
		return
	if candidates.size() == 1:
		# One legal wager is not a decision, but it still has to be applied: the
		# economy remembers the previous preferred wager, and leaving it stale can
		# stake buckets the planner never chose.
		_apply_wager(int(candidates[0].get("wager", 1)), label, reserve, true)
		return
	var state: Dictionary = _plan_state()
	state["decision_label"] = label
	var decision: Dictionary = await _ask_decision("wager", state, candidates)
	var chosen: String = String(decision.get("choice_id", ""))
	for candidate: Dictionary in candidates:
		if String(candidate.get("id", "")) != chosen:
			continue
		_apply_wager(int(candidate.get("wager", 0)), label, reserve, false)
		return
	_append_event("decision_rejected", {"kind": "wager", "choice_id": chosen, "reason": "not_a_wager_candidate"})

func _apply_wager(wager: int, label: String, reserve: int, auto_applied: bool) -> void:
	Economy.set_bet(wager)
	_append_event("wager_set", {
		"label": label,
		"requested": wager,
		"applied": int(Economy.current_bet),
		"auto_applied": auto_applied,
		"reserve_before": reserve,
		"reserve_if_loss": reserve - int(Economy.current_bet),
		"quote_kind": String(Economy.encounter_quote_kind),
		"quoted_multiplier": float(Economy.gross_payout_multiplier()),
		"shown_win_odds": float(Economy.projected_win_probability),
		"break_even_odds": 1.0 / max(0.01, float(Economy.gross_payout_multiplier())),
		"stake_unit": int(Economy.stake_unit),
	})

func _resolve_pending_contract_market() -> void:
	if _run_mode != "jev":
		await super._resolve_pending_contract_market()
		return
	if Shop == null or not Shop.has_method("has_pending_contract_choice"):
		return
	var deadline_msec: int = Time.get_ticks_msec() + 3000
	while Time.get_ticks_msec() < deadline_msec:
		if not bool(Shop.call("has_pending_contract_choice")):
			return
		var overlay: Control = _main.find_child("ChapterContractOverlay", true, false) as Control if _main != null else null
		if overlay != null and overlay.visible:
			break
		await get_tree().process_frame
	if not bool(Shop.call("has_pending_contract_choice")):
		return
	var buttons: Array[Button] = []
	var overlay_node: Control = _main.find_child("ChapterContractOverlay", true, false) as Control if _main != null else null
	if overlay_node != null:
		for child: Node in overlay_node.find_children("Contract*", "Button", true, false):
			var button: Button = child as Button
			if button != null:
				buttons.append(button)
	if buttons.is_empty():
		_append_event("contract_market_missing", {"chapter": int(GameState.chapter)})
		return
	var candidates: Array[Dictionary] = []
	for index: int in range(buttons.size()):
		var button: Button = buttons[index]
		var button_text: String = button.text.strip_edges().replace("\n", " / ")
		candidates.append({
			"id": "contract_%d" % index,
			"label": button_text,
			"effect": "Press the on-screen contract button: %s" % button_text,
			"button_name": String(button.name),
		})
	var decision: Dictionary = await _ask_decision("contract", _plan_state(), candidates)
	var chosen: String = String(decision.get("choice_id", ""))
	for index: int in range(candidates.size()):
		if String(candidates[index].get("id", "")) != chosen:
			continue
		var target: Button = buttons[index]
		var clicked: bool = await _click_button(target, "Jev contract choice %s" % chosen)
		await _settle_frames(4)
		_append_event("contract_resolved", {
			"chapter": int(GameState.chapter),
			"button_name": String(target.name),
			"button_text": String(target.text),
			"clicked": clicked,
		})
		return
	_append_event("decision_rejected", {"kind": "contract", "choice_id": chosen, "reason": "not_a_contract_candidate"})

# --- observation and candidate construction --------------------------------

func _plan_state() -> Dictionary:
	var encounter_kind: String = String(Economy.encounter_quote_kind)
	var board: Array[String] = _board_ids()
	var bench: Array[String] = _bench_ids()
	var state: Dictionary = {
		"chapter": int(GameState.chapter),
		"stage_in_chapter": int(GameState.stage_in_chapter),
		"phase": int(GameState.phase),
		"buckets": int(Economy.blood_buckets),
		"level": int(Shop.get_level()),
		"xp": int(Shop.get_xp()),
		"level_capacity": _roster_max_team_size(),
		"board": board,
		"bench": bench,
		"board_capacity": _roster_max_team_size(),
		"offers": _offer_summaries(),
		"progression_price": int(Economy.progression_price()),
		"reroll_price": int(Economy.reroll_price()),
		"encounter_kind": encounter_kind,
		"quoted_multiplier": float(Economy.gross_payout_multiplier()),
		"shown_win_odds": float(Economy.projected_win_probability),
		"current_bet": int(Economy.current_bet),
		"stake_unit": int(Economy.stake_unit),
		"stake_rank": int(Economy.stake_rank),
		"recent_fights": _recent_fights.duplicate(true),
		"stage_retry_count": int(_same_stage_retries.get("%d:%d" % [int(GameState.chapter), int(GameState.stage_in_chapter)], 0)),
		"campaign": {"mode": _run_mode, "seed": _campaign_seed, "target_chapter": CAMPAIGN_TARGET_CHAPTER, "target_round": CAMPAIGN_TARGET_ROUND},
	}
	return state

func _shop_candidates() -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	var summaries: Array[Dictionary] = _offer_summaries()
	var owned: Array[String] = _board_ids()
	owned.append_array(_bench_ids())
	for summary: Dictionary in summaries:
		var unit_id: String = String(summary.get("id", ""))
		var cost: int = int(summary.get("cost", 0))
		if unit_id == "" or cost <= 0:
			continue
		if not _can_afford_shop_cost(cost):
			candidates.append({
				"id": "offer_%d" % int(summary.get("slot", -1)),
				"label": "%s (cost %d) - unaffordable at %d buckets." % [String(summary.get("name", unit_id)), cost, int(Economy.gold)],
				"effect": "Unaffordable under the planning floor.",
				"affordable": false,
				"slot": int(summary.get("slot", -1)),
				"unit_id": unit_id,
				"cost": cost,
			})
			continue
		var copies: int = owned.count(unit_id)
		candidates.append({
			"id": "offer_%d" % int(summary.get("slot", -1)),
			"label": "%s (cost %d, %s%s)" % [
				String(summary.get("name", unit_id)),
				cost,
				String(summary.get("primary_role", "unit")),
				", owns %d copies" % copies if copies > 0 else "",
			],
			"effect": "Buy %s for %d buckets; %d copies owned, level-up at three." % [unit_id, cost, copies],
			"affordable": true,
			"slot": int(summary.get("slot", -1)),
			"unit_id": unit_id,
			"cost": cost,
			"primary_role": String(summary.get("primary_role", "")),
			"copies_owned": copies,
			"buckets_after": int(Economy.gold) - cost,
		})
	var pass_candidate: Dictionary = {
		"id": "pass",
		"label": "Buy nothing in this shop.",
		"effect": "Keep all %d buckets for the wager, the next shop, or level XP." % int(Economy.gold),
		"affordable": true,
	}
	candidates.append(pass_candidate)
	return candidates

func _wager_candidates(reserve: int) -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	var seen: Dictionary[int, bool] = {}
	var quote_kind: String = String(Economy.encounter_quote_kind)
	var multiplier: float = float(Economy.gross_payout_multiplier())
	var shown_odds: float = float(Economy.projected_win_probability)
	var break_even: float = 1.0 / max(0.01, multiplier)
	for share: float in WAGER_PRESET_SHARES:
		var wager: int = int(round(float(reserve) * share))
		wager = clampi(wager, 1, reserve)
		if seen.has(wager):
			continue
		seen[wager] = true
		var payout: int = int(Economy.quoted_payout(wager))
		candidates.append({
			"id": "wager_%d" % wager,
			"label": "Wager %d of %d buckets (%d%% of the bankroll); win returns %d, loss leaves %d." % [
				wager,
				reserve,
				int(round(share * 100.0)),
				payout,
				reserve - wager,
			],
			"effect": "%s quote %.2fx, break-even win odds %.0f%%, shown odds %.0f%%. Loss leaves %d buckets." % [
				quote_kind,
				multiplier,
				break_even * 100.0,
				shown_odds * 100.0,
				reserve - wager,
			],
			"wager": wager,
			"share": share,
			"payout_if_win": payout,
			"buckets_if_loss": reserve - wager,
			"break_even_odds": break_even,
		})
	candidates.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return int(left.get("wager", 0)) < int(right.get("wager", 0))
	)
	return candidates

# --- file bridge ------------------------------------------------------------

func _ask_decision(kind: String, state: Dictionary, candidates: Array[Dictionary]) -> Dictionary:
	_decision_index += 1
	var observation: Dictionary = {
		"schema_version": 1,
		"index": _decision_index,
		"kind": kind,
		"harness": JEV_HARNESS_NAME,
		"mode": _run_mode,
		"observed_at_msec": Time.get_ticks_msec(),
		"observed_at_epoch": Time.get_unix_time_from_system(),
		"state": state,
		"candidates": candidates,
	}
	_write_run_file("observation_%03d.json" % _decision_index, JSON.stringify(observation, "  "))
	var decision_path: String = _run_dir.path_join("decision_%03d.json" % _decision_index)
	var deadline: int = Time.get_ticks_msec() + int(DECISION_TIMEOUT_SECONDS * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if FileAccess.file_exists(decision_path):
			var raw_text: String = FileAccess.get_file_as_string(decision_path)
			var trimmed: String = raw_text.strip_edges()
			if trimmed.length() < 2 or not trimmed.begins_with("{") or not trimmed.ends_with("}"):
				# The controller publishes each decision atomically, so an empty or
				# torn read means "not published yet", not a broken decision.
				await get_tree().create_timer(DECISION_POLL_SECONDS, true, false, true).timeout
				continue
			var parsed: Variant = JSON.parse_string(trimmed)
			if parsed is Dictionary:
				var decision: Dictionary = parsed as Dictionary
				if int(decision.get("index", -1)) == _decision_index:
					_decision_kinds[kind] = int(_decision_kinds.get(kind, 0)) + 1
					return decision
		await get_tree().create_timer(DECISION_POLL_SECONDS, true, false, true).timeout
	_abort_run("Jev decision %d (%s) was not answered within %d seconds" % [_decision_index, kind, int(DECISION_TIMEOUT_SECONDS)])
	return {}

func _write_run_file(file_name: String, text: String) -> void:
	var path: String = _run_dir.path_join(file_name)
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("%s: could not write %s" % [JEV_HARNESS_NAME, path])
		return
	file.store_string(text)
	file.close()

func _append_event(kind: String, payload: Dictionary) -> void:
	var event: Dictionary = {
		"at_msec": Time.get_ticks_msec(),
		"at_epoch": Time.get_unix_time_from_system(),
		"kind": kind,
		"chapter": int(GameState.chapter),
		"stage_in_chapter": int(GameState.stage_in_chapter),
		"buckets": int(Economy.blood_buckets),
		"payload": payload,
	}
	_events.append(event)
	var file: FileAccess = FileAccess.open(_run_dir.path_join("run_events.jsonl"), FileAccess.READ_WRITE)
	if file == null:
		file = FileAccess.open(_run_dir.path_join("run_events.jsonl"), FileAccess.WRITE)
	if file == null:
		return
	file.seek_end()
	file.store_line(JSON.stringify(event))
	file.close()

func _abort_run(reason: String) -> void:
	_expect(false, "%s: %s" % [JEV_HARNESS_NAME, reason])
	_append_event("run_abort", {"reason": reason})
	_finish_jev_run("aborted")

func _finish_jev_run(terminal: String) -> void:
	Engine.time_scale = 1.0
	UnitFactory.suppress_validation_warnings = _previous_suppress_validation_warnings
	var summary: Dictionary = {
		"schema_version": 1,
		"harness": JEV_HARNESS_NAME,
		"mode": _run_mode,
		"seed": _campaign_seed,
		"starter": _starter_id,
		"terminal": terminal,
		"final_chapter": int(GameState.chapter),
		"final_stage_in_chapter": int(GameState.stage_in_chapter),
		"battles": _battles,
		"peak_bankroll": int(Economy.peak_bankroll),
		"buckets": int(Economy.blood_buckets),
		"rounds": _rounds,
		"events": _events,
		"decision_counts": _decision_kinds,
		"technical_failures": _failures,
	}
	_write_run_file("run_summary.json", JSON.stringify(summary, "  "))
	var verdict: String = "OK" if _failures.is_empty() else "FAIL"
	print("%s: %s terminal=%s chapter=%d round=%d battles=%d peak=%d buckets=%d decisions=%s" % [
		JEV_HARNESS_NAME,
		verdict,
		terminal,
		int(GameState.chapter),
		int(GameState.stage_in_chapter),
		_battles,
		int(Economy.peak_bankroll),
		int(Economy.blood_buckets),
		JSON.stringify(_decision_kinds),
	])
	for failure: String in _failures:
		push_error("%s: %s" % [JEV_HARNESS_NAME, failure])
	print("%s: JEV_RUN_COMPLETE" % JEV_HARNESS_NAME)
	_flush_synthetic_input()
	_cleanup_runtime()
	var exit_code: int = 0 if _failures.is_empty() else 1
	get_tree().process_frame.connect(_quit_after_cleanup.bind(exit_code, CLEANUP_DRAIN_FRAMES), CONNECT_ONE_SHOT)
