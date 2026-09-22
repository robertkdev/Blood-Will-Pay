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
const MAX_REROLLS_PER_SHOP: int = 3
const WAGER_PRESET_SHARES: Array[float] = [0.0, 0.1, 0.25, 0.5, 0.75, 1.0]
const COMBAT_LOG_KEYWORDS: Array[String] = [
	"timeout",
	"stalemate",
	"tie",
	"victory",
	"defeat",
	"boss phase",
	"escalat",
	"reinforcement",
	"sudden death",
]
# Assertions inherited from the fixed-policy two-stage smoke. They describe what that
# scripted policy does, not what the game requires: a combining player legitimately
# ends the first shop with one stronger body instead of two separate ones. They are
# recorded as skipped notes rather than failures so every other assertion stays live.
const INHERITED_POLICY_ASSERTION_PREFIXES: Array[String] = [
	"first shop should buy and deploy a second unit naturally",
	"round 4 cap should allow third deploy",
	"round 4 should deploy at least three units before combat",
]

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
## Planning-beat and shop-revision identity.
##
## Keying shop telemetry on (chapter, stage) merges repeat attempts at the same
## stage into a single beat, and counting every purchase decision as a shop counts
## decisions as if they were visits. Neither can be inferred reliably downstream:
## a beat also ends when the countdown restarts without the stage changing. Both
## identifiers are emitted explicitly instead.
##
## A beat is one shop visit. A revision is one distinct shop contents state: the
## initial roll, then each reroll or purchase that changes what is on the shelf.
var _planning_beat_id: int = 0
var _shop_revision_id: int = 0
var _recent_fights: Array[Dictionary] = []
var _reserve_floor_buckets: int = DEFAULT_RESERVE_FLOOR_BUCKETS
var _combat_log_lines: int = 0
var _speed_scale: float = 1.0
var _use_real_timer: bool = true
var _seed_explicit: bool = false
var _last_combat_outcome: String = ""
## Duration the engine reported when it settled the last fight. Read from the
## engine's own resolution line because the battle state is already reset by the
## time the diagnostic runs, which made a post-settlement read report zero.
var _last_combat_elapsed_s: float = -1.0

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
	Engine.time_scale = _speed_scale
	if Shop != null and not Shop.is_connected("error", Callable(self, "_on_shop_error")):
		Shop.error.connect(_on_shop_error)
	if _seed_explicit:
		_set_shop_seed(_campaign_seed)
	_prepare_run_dir()
	print("%s: boot mode=%s seed=%s speed=%.2f real_timer=%s target=chapter %d round %d" % [
		JEV_HARNESS_NAME,
		_run_mode,
		str(_campaign_seed) if _seed_explicit else "random",
		_speed_scale,
		str(_use_real_timer),
		CAMPAIGN_TARGET_CHAPTER,
		CAMPAIGN_TARGET_ROUND,
	])
	_append_event("run_start", {
		"mode": _run_mode,
		"seed": _campaign_seed,
		# Revision and policy identity travel with the run so a transcript cannot be
		# mistaken for a different build or a different rule set.
		"repo_revision": OS.get_environment("JEV_REVISION").strip_edges(),
		"rules_sha256": OS.get_environment("JEV_RULES_SHA").strip_edges(),
		"shop_seed_explicit": _seed_explicit,
		"time_scale": _speed_scale,
		"real_planning_timer": _use_real_timer,
		"target_chapter": CAMPAIGN_TARGET_CHAPTER,
		"target_round": CAMPAIGN_TARGET_ROUND,
		"engine_time_scale": Engine.time_scale,
		"entrypoint": "scenes/Main.tscn",
		"player_facing_entrypoint": true,
		"input_path": "engine_parsed_mouse_events",
		"handler_fallback": false,
		"drag_lifecycle_fallback": false,
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
	_ensure_combat_log_connected()
	_begin_planning_beat()
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
		var round_wall_start: float = Time.get_unix_time_from_system()
		var decisions_before_round: int = _decision_index
		var planning_before_round: float = _planning_time_left()
		var round_result: Dictionary = await _play_two_stage_round()
		_rounds.append(round_result)
		_append_event("round", round_result)
		_append_event("round_timing", {
			"chapter": int(round_result.get("chapter_before", -1)),
			"round": int(round_result.get("round_before", -1)),
			"wall_seconds": snappedf(Time.get_unix_time_from_system() - round_wall_start, 0.01),
			"decisions": _decision_index - decisions_before_round,
			"planning_seconds_at_start": snappedf(planning_before_round, 0.01),
			"planning_seconds_at_end": snappedf(_planning_time_left(), 0.01),
			"fight_result": String(round_result.get("fight_result", "")),
			"advanced": bool(round_result.get("advanced", false)),
		})
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

## One shop visit. Called at the top of every round and before the opening
## planning phase, so a replayed stage is its own beat instead of being folded
## into the stage key it shares with the attempt that failed.
func _begin_planning_beat() -> void:
	_planning_beat_id += 1
	_shop_revision_id += 1

## The shelf changed: a reroll replaced it, or a purchase consumed an offer.
func _bump_shop_revision() -> void:
	_shop_revision_id += 1

## Offers still on the shelf. Distinguishes the initial presentation of a shop
## from the depleted state a decision can also be asked in.
##
## A purchased slot is replaced by a blank placeholder rather than removed, so the
## count has to key on the offer's identity; counting non-null entries reports a
## sold-out shelf as full.
func _shop_offers_remaining() -> int:
	if Shop == null or Shop.state == null:
		return 0
	var remaining: int = 0
	for offer: ShopOffer in Shop.state.offers:
		if offer != null and String(offer.id).strip_edges() != "":
			remaining += 1
	return remaining

func _play_two_stage_round() -> Dictionary:
	_begin_planning_beat()
	return await super._play_two_stage_round()

func _second_fight_result(resolved: bool) -> String:
	# The inherited classifier falls back to "shop" whenever the phase returns to
	# PREVIEW, which makes a drawn or lost fight look like a completed stage and
	# turns the campaign loop into a retry treadmill. Classify from the settlement:
	# an advanced stage is a win, and otherwise the engine's own verdict decides.
	if not resolved:
		return "timeout"
	var outcome: String = ""
	if get_tree().root.get_node_or_null("LossOverlayLayer") != null:
		outcome = "loss"
	elif _stage_advanced_from_round():
		outcome = "shop"
	elif _last_combat_outcome != "":
		match _last_combat_outcome:
			"tie":
				outcome = "tie"
			"defeat":
				outcome = "loss"
			"victory":
				outcome = "shop"
			_:
				outcome = _last_combat_outcome
	else:
		# No engine verdict captured: fall back to the reserve read.
		var reserve_start: int = int(Economy.last_blood_reserve_start)
		if reserve_start > 0 and int(Economy.blood_buckets) >= reserve_start:
			outcome = "tie"
		else:
			outcome = "loss"
	_record_combat_diagnostic(outcome)
	return outcome

func _record_combat_diagnostic(outcome: String) -> void:
	# A drawn stage is the hardest outcome to read from the outside: the fight
	# resolves without advancing and without costing anything. Record the engine's
	# own numbers so the reason is visible in the transcript.
	var controller: Variant = _combat_controller()
	var manager: Variant = controller.get("manager") if controller != null else null
	if manager == null:
		return
	var engine: Variant = manager.get_engine()
	if engine == null:
		return
	var player_team: Array = manager.get("player_team")
	var enemy_team: Array = manager.get("enemy_team")
	_append_event("combat_diagnostic", {
		"outcome": outcome,
		"engine_outcome": _last_combat_outcome,
		"fight_index": _battles + 1,
		"player_damage": int(engine.get("total_damage_player")),
		"enemy_damage": int(engine.get("total_damage_enemy")),
		# The engine's own reported duration. Reading state.elapsed_time here reported
		# zero for every fight, because settlement had already reset the battle state.
		"engine_reported_elapsed_s": _last_combat_elapsed_s,
		"combat_timeout_s": float(engine.get("combat_timeout_s")),
		"no_progress_timeout_s": float(engine.get("no_progress_timeout_s")),
		# These readings are taken after settlement: the board may already be rebuilt
		# for the next stage and the units healed. They are labelled as such rather
		# than presented as the fight's final state; the engine's own "Combat resolved"
		# log line in combat_log is the authoritative record of the fight.
		"post_settlement_player_alive": _alive_count(player_team),
		"post_settlement_enemy_alive": _alive_count(enemy_team),
		"post_settlement_player_board": _team_ids(player_team),
		"post_settlement_enemy_board": _team_ids(enemy_team),
		"buckets_after": int(Economy.blood_buckets),
		"reserve_before_wager": int(Economy.last_blood_reserve_start),
		"wager": int(Economy.last_wager_start),
		"combat_active": bool(Economy.combat_active),
	})

func _alive_count(team: Array) -> int:
	var count: int = 0
	for unit_value: Variant in team:
		var unit: Unit = unit_value as Unit
		if unit != null and unit.is_alive():
			count += 1
	return count

func _health_fraction(team: Array) -> float:
	var current: float = 0.0
	var maximum: float = 0.0
	for unit_value: Variant in team:
		var unit: Unit = unit_value as Unit
		if unit == null:
			continue
		current += max(0.0, float(unit.hp))
		maximum += max(0.0, float(unit.max_hp))
	if maximum <= 0.0:
		return 0.0
	return current / maximum

func _team_ids(team: Array) -> Array[String]:
	var output: Array[String] = []
	for unit_value: Variant in team:
		var unit: Unit = unit_value as Unit
		output.append(_unit_id(unit))
	return output

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
	if seed_value.is_valid_int() and seed_value.to_int() >= 0:
		_seed_explicit = true
		_campaign_seed = seed_value.to_int()
	else:
		# No seed: the shipped random shop rolls stay in place. Report -1 so the
		# transcript cannot be mistaken for a reproducible seeded run.
		_campaign_seed = -1
	var speed_value: String = OS.get_environment("JEV_SPEED").strip_edges()
	if speed_value.is_valid_float() and speed_value.to_float() > 0.0:
		_speed_scale = clampf(speed_value.to_float(), 0.25, 16.0)
	var timer_value: String = OS.get_environment("JEV_REAL_TIMER").strip_edges().to_lower()
	if timer_value in ["0", "false", "held", "off"]:
		# Fast-sweep only: hold the planning beat open instead of the shipped
		# countdown. Every report that uses this must say so.
		_use_real_timer = false
	var starter_value: String = OS.get_environment("JEV_STARTER").strip_edges().to_lower()
	if not starter_value.is_empty():
		_starter_id = starter_value
	_reserve_floor_buckets = _load_reserve_floor()

func _set_planning_timer_safe() -> void:
	# The shipped planning beat is a live 120-second countdown that auto-starts the
	# fight when it expires: that countdown is part of what "playable" means, so by
	# default the run leaves it alone. Only the fast-sweep mode holds it open.
	if _use_real_timer:
		return
	super._set_planning_timer_safe()

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

func _use_synthetic_input() -> bool:
	# Drive the game through real mouse events parsed by the engine, not by calling
	# button handlers. A click has to survive hit-testing, focus, disabled state and
	# mouse filters the way a player's click does.
	return true

func _allow_button_signal_fallback() -> bool:
	# A click that misses the real control must fail loudly. The silent pressed-signal
	# fallback would turn a mis-aimed click into a passed test.
	return false

func _expect(condition: bool, message: String) -> void:
	for prefix: String in INHERITED_POLICY_ASSERTION_PREFIXES:
		if message.begins_with(prefix):
			if not condition:
				_append_event("inherited_policy_assertion_skipped", {"message": message})
			return
	super._expect(condition, message)

func _allow_drag_lifecycle_fallback() -> bool:
	return false

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
		# The heuristic arm used to return here without recording anything, so its
		# transcript carried no shop events at all and the analyzer reported zero
		# purchases for the baseline it was being compared against. Record what the
		# inherited policy actually did - the id it bought and the gold it spent, both
		# measured around the call - and label the basis so a policy action is never
		# mistaken for a Jev decision executed by the harness.
		var policy_gold_before: int = int(Economy.gold)
		var policy_bought: String = await super._buy_best_two_stage_offer(buy_index)
		var policy_gold_after: int = int(Economy.gold)
		if policy_bought == "":
			_append_event("shop_pass", {
				"buy_index": buy_index,
				"basis": "inherited_policy",
				"gold_before": policy_gold_before,
				"gold_after": policy_gold_after,
			})
			return ""
		_bump_shop_revision()
		_append_event("shop_purchase", {
			"buy_index": buy_index,
			"unit_id": policy_bought,
			"cost": max(0, policy_gold_before - policy_gold_after),
			"gold_before": policy_gold_before,
			"gold_after": policy_gold_after,
			"basis": "inherited_policy",
		})
		return policy_bought
	for reroll_attempt: int in range(MAX_REROLLS_PER_SHOP):
		var candidates: Array[Dictionary] = _shop_candidates()
		if candidates.is_empty():
			return ""
		var state: Dictionary = _plan_state()
		state["buy_index"] = buy_index
		state["rerolls_this_shop"] = reroll_attempt
		var decision: Dictionary = await _ask_decision("shop_buy", state, candidates)
		var chosen: String = String(decision.get("choice_id", ""))
		if chosen == "pass":
			_append_event("shop_pass", {"buy_index": buy_index, "review_flags": decision.get("review_flags", [])})
			return ""
		if chosen == "reroll":
			if not await _click_reroll():
				_append_event("reroll_failed", {"buy_index": buy_index, "attempt": reroll_attempt})
				return ""
			await _settle_frames(4)
			continue
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
			if clicked:
				# The shelf is narrower now, so the next decision sees a new revision.
				_bump_shop_revision()
			_append_event("shop_purchase", {
				"buy_index": buy_index,
				"slot": slot,
				"unit_id": unit_id,
				"cost": cost,
				"gold_before": gold_before,
				"gold_after": int(Economy.gold),
				"clicked": clicked,
			})
			return unit_id if clicked else ""
		_append_event("decision_rejected", {"kind": "shop_buy", "choice_id": chosen, "reason": "not_an_offer_candidate"})
		return ""
	_append_event("reroll_budget_exhausted", {"buy_index": buy_index, "rerolls": MAX_REROLLS_PER_SHOP})
	return ""

func _reroll_button() -> Button:
	if _main == null:
		return null
	for node: Node in _main.find_children("*", "Button", true, false):
		var button: Button = node as Button
		if button != null and button.text.strip_edges().begins_with("Reroll"):
			return button
	return null

func _click_reroll() -> bool:
	var button: Button = _reroll_button()
	if button == null or button.disabled:
		return false
	var gold_before: int = int(Economy.gold)
	var clicked: bool = await _click_button(button, "Jev reroll")
	await _settle_frames(4)
	if clicked:
		_bump_shop_revision()
	_append_event("reroll", {
		"gold_before": gold_before,
		"gold_after": int(Economy.gold),
		"clicked": clicked,
		"offers": _offer_summaries(),
	})
	return clicked

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
	_ensure_combat_log_connected()
	_last_combat_outcome = ""
	# Snapshot everything about the fight BEFORE it starts. After settlement the board
	# is rebuilt for the next planning beat and the units are healed, so a read taken
	# afterwards describes the next stage, not the fight that just resolved.
	_append_event("fight_start", {
		"fight_index": _battles + 1,
		"label": label,
		"board": _board_ids(),
		"bench": _bench_ids(),
		"deployed_traits": _trait_snapshot(_board_units()),
		# Both sides, captured before the fight: identity, level, items and tile per
		# unit, plus the traits each board actually activates.
		"player_units": _team_units_snapshot(_board_units(), _player_placements()),
		"enemy_units": _team_units_snapshot(_enemy_units(), _enemy_placements()),
		"enemy_traits": _trait_snapshot(_enemy_units()),
		"wager": int(Economy.current_bet),
		"buckets": int(Economy.blood_buckets),
		"stake_unit": int(Economy.stake_unit),
		"encounter_kind": String(Economy.encounter_quote_kind),
		"quoted_multiplier": float(Economy.gross_payout_multiplier()),
		"shown_win_odds": float(Economy.projected_win_probability),
		"planning_seconds_left": snappedf(_planning_time_left(), 0.01),
	})
	await super._press_continue(expect_forced, label)

func _ensure_combat_log_connected() -> void:
	# The engine explains a forced result (timeout, stalled board) through
	# log_line only. Capture it so a drawn stage can be explained after the fact.
	var controller: Variant = _combat_controller()
	var manager: Variant = controller.get("manager") if controller != null else null
	if manager == null:
		return
	if manager.has_signal("log_line") and not manager.is_connected("log_line", Callable(self, "_on_combat_log_line")):
		manager.log_line.connect(_on_combat_log_line)
func _on_combat_log_line(text: String) -> void:
	# The engine announces every settlement through this line. It is the authority
	# for the outcome: a defeat can leave the bankroll untouched (the early retry
	# transfusion), so a bankroll-only read used to report a loss as a draw.
	if text.begins_with("Combat resolved: "):
		var remainder: String = text.substr("Combat resolved: ".length())
		_last_combat_outcome = remainder.split(" ")[0].strip_edges()
		for token: String in remainder.split(" "):
			if not token.begins_with("elapsed="):
				continue
			var raw_value: String = token.trim_prefix("elapsed=").trim_suffix(".").trim_suffix("s")
			if raw_value.is_valid_float():
				_last_combat_elapsed_s = float(raw_value)
			break
	# Per-hit lines dominate the combat log; keep the lines that explain a
	# resolution instead of truncating the transcript inside the first fight.
	var lowered: String = text.to_lower()
	var interesting: bool = false
	for keyword: String in COMBAT_LOG_KEYWORDS:
		if lowered.contains(keyword):
			interesting = true
			break
	if not interesting:
		return
	if _combat_log_lines >= 200:
		return
	_combat_log_lines += 1
	_append_event("combat_log", {"line": text})

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
	var controller_node: Control = _main.get_node_or_null("CombatView") as Control if _main != null else null
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
		"planning_beat_id": _planning_beat_id,
		"shop_revision_id": _shop_revision_id,
		"shop_offers_remaining": _shop_offers_remaining(),
		"stage_retry_count": int(_same_stage_retries.get("%d:%d" % [int(GameState.chapter), int(GameState.stage_in_chapter)], 0)),
		# Traits count unique units, and only the fielded board fights. Reporting the
		# benched units' traits as if they were active is what let "this offer activates
		# a trait" be true while the board activated nothing.
		"traits": _trait_snapshot(_board_units()),
		"traits_owned": _trait_snapshot(_owned_units()),
		"planning_time_left": float(controller_node.get("planning_time_left")) if controller_node != null else -1.0,
		"planning_timer_total": float(controller_node.get("planning_timer_total")) if controller_node != null else -1.0,
		"time_scale": Engine.time_scale,
		"shop_seed_explicit": _seed_explicit,
		"campaign": {"mode": _run_mode, "seed": _campaign_seed, "target_chapter": CAMPAIGN_TARGET_CHAPTER, "target_round": CAMPAIGN_TARGET_ROUND},
	}
	return state

func _board_units() -> Array[Unit]:
	var units: Array[Unit] = []
	var controller: Variant = _combat_controller()
	var manager: Variant = controller.get("manager") if controller != null else null
	if manager != null:
		for unit_value: Variant in manager.get("player_team"):
			var board_unit: Unit = unit_value as Unit
			if board_unit != null:
				units.append(board_unit)
	return units

func _enemy_units() -> Array[Unit]:
	var units: Array[Unit] = []
	var controller: Variant = _combat_controller()
	var manager: Variant = controller.get("manager") if controller != null else null
	if manager != null:
		for unit_value: Variant in manager.get("enemy_team"):
			var enemy_unit: Unit = unit_value as Unit
			if enemy_unit != null:
				units.append(enemy_unit)
	return units

func _player_placements() -> Array[int]:
	var controller: Variant = _combat_controller()
	var placement: Variant = controller.get("grid_placement") if controller != null else null
	if placement == null or not placement.has_method("get_player_placements"):
		return []
	var out: Array[int] = []
	for value: Variant in placement.call("get_player_placements"):
		out.append(int(value))
	return out

## Enemy tile per unit. The placement layer builds the enemy views, so the tile is
## read from the view rather than guessed; an unplaced unit reports -1.
func _enemy_placements() -> Array[int]:
	var tiles_by_unit: Dictionary = {}
	var controller: Variant = _combat_controller()
	var placement: Variant = controller.get("grid_placement") if controller != null else null
	if placement != null and placement.has_method("get_enemy_views"):
		for view_value: Variant in placement.call("get_enemy_views"):
			var slot_view: Variant = view_value
			if slot_view == null:
				continue
			tiles_by_unit[slot_view.get("unit")] = int(slot_view.get("tile_idx"))
	var out: Array[int] = []
	for unit: Unit in _enemy_units():
		out.append(int(tiles_by_unit.get(unit, -1)))
	return out

## One team's pre-combat state. A fight can only be read after the fact if who was
## on the board, at what level, holding what, standing where, is recorded before it
## starts - settlement rebuilds the board and heals the units.
func _team_units_snapshot(team: Array[Unit], placements: Array[int]) -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	for index: int in range(team.size()):
		var unit: Unit = team[index]
		if unit == null:
			continue
		records.append({
			"id": _unit_id(unit),
			"level": int(unit.level),
			"items": Items.get_equipped(unit) if Items != null else [],
			"tile": int(placements[index]) if index < placements.size() else -1,
		})
	return records

func _owned_units() -> Array[Unit]:
	var units: Array[Unit] = _board_units()
	for bench_unit: Unit in Roster.compact():
		if bench_unit != null and not units.has(bench_unit):
			units.append(bench_unit)
	return units

func _trait_snapshot(units: Array[Unit]) -> Array[Dictionary]:
	# Traits count unique units, so a second copy of a unit you already field is an
	# upgrade play, not a trait play. Report counts, the next threshold, and whether
	# a tier is already live so flex and vertical decisions are made on facts.
	var compiled: Dictionary = TraitCompiler.compile(units)
	var counts: Dictionary = compiled.get("counts", {})
	var tiers: Dictionary = compiled.get("tiers", {})
	var thresholds: Dictionary = compiled.get("thresholds", {})
	var snapshot: Array[Dictionary] = []
	for trait_key: Variant in counts.keys():
		var trait_id: String = String(trait_key)
		var count: int = int(counts[trait_id])
		var ladder: Array = thresholds.get(trait_id, [2, 4, 6, 8])
		var next_threshold: int = 0
		for raw_threshold: Variant in ladder:
			if int(raw_threshold) > count:
				next_threshold = int(raw_threshold)
				break
		snapshot.append({
			"id": trait_id,
			"count": count,
			"tier": int(tiers.get(trait_id, 0)),
			"active": int(tiers.get(trait_id, 0)) > 0,
			"next_threshold": next_threshold,
			"needed": max(0, next_threshold - count) if next_threshold > 0 else 0,
		})
	snapshot.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return int(left.get("count", 0)) > int(right.get("count", 0))
	)
	return snapshot

func _offer_traits(slot: int) -> Array[String]:
	var output: Array[String] = []
	if Shop == null or Shop.state == null:
		return output
	if slot < 0 or slot >= Shop.state.offers.size():
		return output
	var offer: ShopOffer = Shop.state.offers[slot] as ShopOffer
	if offer == null:
		return output
	for raw_trait: Variant in offer.traits:
		output.append(String(raw_trait))
	return output

func _offer_package_level(slot: int) -> int:
	if Shop == null or Shop.state == null:
		return 1
	if slot < 0 or slot >= Shop.state.offers.size():
		return 1
	var offer: ShopOffer = Shop.state.offers[slot] as ShopOffer
	if offer == null:
		return 1
	return max(1, int(offer.package_level))

## Copies already owned at the level this offer would arrive at. CombineService groups
## three-of-a-kind by identity *and* level, so identity alone overstates progress.
func _owned_at_offer_level(unit_id: String, level: int) -> int:
	var count: int = 0
	for unit: Unit in _owned_units():
		if _unit_id(unit) == unit_id and int(unit.level) == level:
			count += 1
	return count

## Pure facts about one shop offer.
##
## Extracted so the rules that feed Jev's shop decisions can be pinned by fixtures
## rather than only exercised inside a live campaign. The inline version this
## replaced reported a benched-only identity as "already fielded" (it keyed off
## board-plus-bench ownership while the trait snapshot only counts deployed units)
## and computed combine progress from identity alone.
static func summarize_offer_facts(
	offer_traits: Array[String],
	package_level: int,
	board_copies: int,
	bench_copies: int,
	owned_at_offer_level: int,
	board_count_by_trait: Dictionary,
	next_threshold_by_trait: Dictionary,
	board_has_room: bool
) -> Dictionary:
	var traits_after_deploy: Array[String] = []
	var activates_after_deploy: Array[String] = []
	if board_copies <= 0:
		for trait_id: String in offer_traits:
			traits_after_deploy.append(trait_id)
			var current_count: int = int(board_count_by_trait.get(trait_id, 0))
			var next_threshold: int = int(next_threshold_by_trait.get(trait_id, 0))
			if next_threshold > 0 and current_count < next_threshold and current_count + 1 >= next_threshold:
				activates_after_deploy.append(trait_id)
	var copies_after_purchase: int = owned_at_offer_level + 1
	var combine_needed: int = (3 - (copies_after_purchase % 3)) % 3
	return {
		"already_deployed": board_copies > 0,
		"board_copies": board_copies,
		"bench_copies": bench_copies,
		"copies_owned": board_copies + bench_copies,
		"package_level": max(1, int(package_level)),
		"owned_at_offer_level": owned_at_offer_level,
		"copies_after_purchase": copies_after_purchase,
		"combines_on_purchase": combine_needed == 0,
		"combine_needed": combine_needed,
		"traits": offer_traits,
		"adds_traits": traits_after_deploy,
		"activates_traits": activates_after_deploy,
		"traits_after_deploy": traits_after_deploy,
		"activates_after_deploy": activates_after_deploy,
		# A purchase lands on the bench, so any trait gain is a claim about a later
		# deployment, not about this purchase.
		"trait_gain_requires_deploy": board_copies <= 0,
		"deploy_requires_replacement": board_copies <= 0 and not board_has_room,
	}

func _shop_candidates() -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	var summaries: Array[Dictionary] = _offer_summaries()
	var board_ids: Array[String] = _board_ids()
	var bench_ids: Array[String] = _bench_ids()
	var board_has_room: bool = board_ids.size() < _roster_max_team_size()
	var count_by_trait: Dictionary[String, int] = {}
	var threshold_by_trait: Dictionary[String, int] = {}
	for entry: Dictionary in _trait_snapshot(_board_units()):
		var entry_id: String = String(entry.get("id", ""))
		count_by_trait[entry_id] = int(entry.get("count", 0))
		threshold_by_trait[entry_id] = int(entry.get("next_threshold", 0))
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
		var slot_index: int = int(summary.get("slot", -1))
		var offer_level: int = _offer_package_level(slot_index)
		var facts: Dictionary = summarize_offer_facts(
			_offer_traits(slot_index),
			offer_level,
			board_ids.count(unit_id),
			bench_ids.count(unit_id),
			_owned_at_offer_level(unit_id, offer_level),
			count_by_trait,
			threshold_by_trait,
			board_has_room
		)
		var copies: int = int(facts.get("copies_owned", 0))
		var combine_needed: int = int(facts.get("combine_needed", 0))
		var adds_traits: Array = facts.get("adds_traits", []) as Array
		var activates_traits: Array = facts.get("activates_traits", []) as Array
		# Only two or more same-level copies are actually on the road to a combine;
		# a first copy is a body, not combine progress.
		var combine_relevant: bool = int(facts.get("copies_after_purchase", 0)) >= 2
		var combine_text: String = "no combine progress yet"
		if bool(facts.get("combines_on_purchase", false)):
			combine_text = "this purchase completes a three-of-a-kind at level %d" % offer_level
		elif combine_relevant:
			combine_text = "%d more at level %d for the next combine" % [combine_needed, offer_level]
		var trait_text: String = "Adds no trait count."
		if bool(facts.get("already_deployed", false)):
			trait_text = "Adds no trait count (already deployed)."
		elif not adds_traits.is_empty():
			trait_text = "Would add traits %s once deployed" % ", ".join(adds_traits)
			trait_text += " (needs a swap: the board is full)." if bool(facts.get("deploy_requires_replacement", false)) else "."
		var activation_text: String = ""
		if not activates_traits.is_empty():
			activation_text = " Similarly activates %s once deployed." % ", ".join(activates_traits)
		candidates.append({
			"id": "offer_%d" % int(summary.get("slot", -1)),
			"label": "%s (cost %d, %s%s)" % [
				String(summary.get("name", unit_id)),
				cost,
				String(summary.get("primary_role", "unit")),
				", owns %d copies" % copies if copies > 0 else "",
			],
			"effect": "Buy %s at level %d for %d buckets; %d copies owned, %s. %s%s Leaves %d buckets." % [
				unit_id,
				offer_level,
				cost,
				copies,
				combine_text,
				trait_text,
				activation_text,
				int(Economy.gold) - cost,
			],
			"affordable": true,
			"slot": int(summary.get("slot", -1)),
			"unit_id": unit_id,
			"cost": cost,
			"primary_role": String(summary.get("primary_role", "")),
			"copies_owned": copies,
			"combine_needed": combine_needed,
			"combines_on_purchase": bool(facts.get("combines_on_purchase", false)),
			"combine_relevant": combine_relevant,
			"package_level": offer_level,
			"owned_at_offer_level": int(facts.get("owned_at_offer_level", 0)),
			"board_copies": int(facts.get("board_copies", 0)),
			"bench_copies": int(facts.get("bench_copies", 0)),
			"already_deployed": bool(facts.get("already_deployed", false)),
			"traits": facts.get("traits", []),
			"adds_traits": adds_traits,
			"activates_traits": activates_traits,
			"trait_gain_requires_deploy": bool(facts.get("trait_gain_requires_deploy", false)),
			"deploy_requires_replacement": bool(facts.get("deploy_requires_replacement", false)),
			"buckets_after": int(Economy.gold) - cost,
		})
	var pass_candidate: Dictionary = {
		"id": "pass",
		"label": "Buy nothing in this shop.",
		"effect": "Keep all %d buckets for the wager, the next shop, or level XP." % int(Economy.gold),
		"affordable": true,
	}
	candidates.append(pass_candidate)
	var reroll_price: int = int(Economy.reroll_price())
	if reroll_price > 0 and int(Economy.gold) - reroll_price >= _reserve_floor_buckets:
		candidates.append({
			"id": "reroll",
			"label": "Reroll the shop for %d buckets." % reroll_price,
			# Neutral on purpose. This used to read "This is the gamble: it pays only
			# when the new roll beats the flex pick in front of you", which pre-judged
			# the action inside the candidate itself. Every policy variant then produced
			# identical decisions, so the stance being compared never reached the model.
			"effect": "Replace every current offer with a new roll. Costs %d buckets and leaves %d. What arrives is not known in advance." % [reroll_price, int(Economy.gold) - reroll_price],
			"affordable": true,
			"cost": reroll_price,
		})
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
		"planning_beat_id": _planning_beat_id,
		"shop_revision_id": _shop_revision_id,
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
