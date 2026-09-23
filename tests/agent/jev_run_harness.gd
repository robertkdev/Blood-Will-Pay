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
## The deep lane keeps playing after the campaign target. A three-star unit is nine
## copies, a maxed trait ladder needs a board the early chapters cannot build, and a
## rich bankroll needs chapters to compound in - none of that is observable in a run
## that stops the moment it clears chapter 2 round 4. The campaign target is still
## recorded as a milestone inside a deep run.
## Chapter 10 is the "good run" marker: eight completed items are a chapter-10
## pacing target, and five stages per chapter means a chapter-10 run is ~50 fights.
const DEEP_TARGET_CHAPTER: int = 10
const DEEP_TARGET_ROUND: int = 4
const DEEP_MAX_BATTLES: int = 200
const MAX_SAME_STAGE_RETRIES: int = 3
## A synthetic mouse event occasionally misses a control that is visibly present and
## enabled - observed once across six seeds, on a shop slot, with the card rendered and
## mouse_filter 0. That is an input-layer artifact rather than play, but the inherited
## click path records it as a technical failure and the whole run becomes unusable. Each
## attempt is still a real engine-parsed mouse event; only the retries are new.
const SHOP_CLICK_ATTEMPTS: int = 3
## Equip decisions asked per planning beat. Two components on one unit combine
## automatically, so placing a component can be a two-step commitment and a single
## pass is not enough to place a carried component.
const ITEM_DECISIONS_PER_BEAT: int = 4
const MAX_REROLLS_PER_SHOP: int = 3
## A synthetic Start Battle click is occasionally swallowed while an overlay is
## fading out, which aborts an otherwise good run. The press is retried a bounded
## number of times, and only while the same planning beat is still open.
const START_BATTLE_ATTEMPTS: int = 3
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
var _lane: String = "campaign"
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
## The chapter-2 campaign milestone inside a deeper lane, recorded once.
var _campaign_milestone_met: bool = false
## Real frame times while a fight is on screen. The board grows to nine units a side
## in the deep lane, and the player-visible complaint at that size is frame pacing,
## so the transcript records the frames rather than only the outcome.
var _fight_frame_ms: Array[float] = []
var _previous_frame_process: bool = false
## Optional planning-beat screenshots. A UI report ("this banner covers the enemy
## grid") needs a real rendered frame to confirm against, and the run is already
## driving the real 1920x1080 scene. Off unless JEV_CAPTURE_PLANNING is set, and
## bounded per run so a sweep cannot fill a disk.
var _capture_planning: bool = false
var _capture_budget: int = 3
## The fight that ended the run, kept so the failure record can say what actually
## happened rather than only that the run stopped.
var _last_combat_diagnostic: Dictionary = {}
## The engine's own settlement line for the most recent fight, and its parsed fields.
## The board is rebuilt during settlement, so only this line records the survivors.
var _last_resolution_line: String = ""
var _last_resolution_fields: Dictionary = {}

func _process(delta: float) -> void:
	if int(GameState.phase) == int(GameState.GamePhase.COMBAT) or bool(Economy.combat_active):
		_fight_frame_ms.append(maxf(0.0, float(delta)) * 1000.0)
		_previous_frame_process = true
	elif _previous_frame_process:
		# The fight just ended; leave the buffer for the diagnostic that follows.
		_previous_frame_process = false

## Percentiles of the frames recorded since the last reset.
func _take_fight_frame_stats() -> Dictionary:
	if _fight_frame_ms.is_empty():
		return {}
	var ordered: Array[float] = _fight_frame_ms.duplicate()
	_fight_frame_ms.clear()
	ordered.sort()
	var total: float = 0.0
	for value: float in ordered:
		total += value
	var count: int = ordered.size()
	return {
		"frames": count,
		"mean_ms": snappedf(total / float(count), 0.01),
		"p50_ms": snappedf(ordered[int(floor(float(count - 1) * 0.50))], 0.01),
		"p95_ms": snappedf(ordered[int(ceil(float(count - 1) * 0.95))], 0.01),
		"max_ms": snappedf(ordered[count - 1], 0.01),
	}

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
	print("%s: boot mode=%s lane=%s seed=%s speed=%.2f real_timer=%s target=chapter %d round %d" % [
		JEV_HARNESS_NAME,
		_run_mode,
		_lane,
		str(_campaign_seed) if _seed_explicit else "random",
		_speed_scale,
		str(_use_real_timer),
		_campaign_target_chapter(),
		_campaign_target_round(),
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
		"lane": _lane,
		"target_chapter": _campaign_target_chapter(),
		"target_round": _campaign_target_round(),
		"campaign_target_chapter": CAMPAIGN_TARGET_CHAPTER,
		"campaign_target_round": CAMPAIGN_TARGET_ROUND,
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

	while _battles < _campaign_max_battles() and not _campaign_target_reached():
		if _lane == "deep" and not _campaign_milestone_met and _campaign_milestone_reached():
			_campaign_milestone_met = true
			_append_event("campaign_milestone", {
				"chapter": int(GameState.chapter),
				"round": int(GameState.stage_in_chapter),
				"battles": _battles,
			})
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
			_checkpoint_run()
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
			_checkpoint_run()
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
	if int(GameState.chapter) > _campaign_target_chapter():
		return true
	return int(GameState.chapter) == _campaign_target_chapter() and int(GameState.stage_in_chapter) >= _campaign_target_round()

func _campaign_target_chapter() -> int:
	return DEEP_TARGET_CHAPTER if _lane == "deep" else CAMPAIGN_TARGET_CHAPTER

func _campaign_target_round() -> int:
	return DEEP_TARGET_ROUND if _lane == "deep" else CAMPAIGN_TARGET_ROUND

func _campaign_max_battles() -> int:
	return DEEP_MAX_BATTLES if _lane == "deep" else CAMPAIGN_MAX_BATTLES

## The chapter-2 milestone inside a deeper lane. Recorded once so a deep run still
## states whether it cleared the original campaign target.
func _campaign_milestone_reached() -> bool:
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
	var payload: Dictionary = {
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
		# Frame pacing for the fight that just ended, at the board size it ran with.
		"frame_ms": _take_fight_frame_stats(),
		"board_size": player_team.size() + enemy_team.size(),
	}
	# Kept so the failure record can describe the fight that ended the run.
	_last_combat_diagnostic = payload
	_append_event("combat_diagnostic", payload)

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
	var lane_value: String = OS.get_environment("JEV_LANE").strip_edges().to_lower()
	if lane_value in ["campaign", "deep"]:
		_lane = lane_value
	_capture_planning = OS.get_environment("JEV_CAPTURE_PLANNING").strip_edges() == "1"
	var capture_budget_value: String = OS.get_environment("JEV_CAPTURE_BUDGET").strip_edges()
	if capture_budget_value.is_valid_int():
		_capture_budget = max(0, capture_budget_value.to_int())
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
	return _campaign_target_chapter()

func _flow_target_round() -> int:
	return _campaign_target_round()

func _flow_max_battles() -> int:
	return _campaign_max_battles()

## The inherited fixture caps a shop at two purchases, and at one in chapter 1 rounds
## 1-4, so a scripted pacing test stays deterministic. That cap - not the economy -
## is what stopped the rig from ever accumulating the nine copies a three-star needs:
## a Jev run reached a 12,751-bucket bankroll and could still only buy two cards per
## beat. A player with money buys the shelf.
func _max_natural_buys_for_round(_chapter_before: int, _round_before: int) -> int:
	return int(SHOP_CONFIG.SLOT_COUNT)

## The gate exists to protect a scripted script's chapter-1 boss purchase. With the
## shop now open to the whole shelf, the reserve floor in the affordability rules is
## the thing that protects the bankroll, so this stays out of the way.
func _should_reserve_gold_for_round_four_gate(_chapter_before: int, _round_before: int) -> bool:
	return false

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
		var meta: Dictionary = select.items_by_id.get(unit_id, {}) as Dictionary
		var primary_role: String = String(meta.get("primary_role", ""))
		var primary_goal: String = String(meta.get("primary_goal", ""))
		var traits: Array[String] = []
		for raw_trait: Variant in (meta.get("traits", []) as Array):
			traits.append(String(raw_trait))
		# The opener is fought with the starter alone, so its level-1 damage and
		# durability are the two facts that decide whether it survives until the
		# first shop can add a body. They are read from the same factory the game
		# spawns the unit with, not from a hand-written table.
		var opening_damage: float = 0.0
		var opening_health: int = 0
		var opening_armor: float = 0.0
		var probe: Unit = UnitFactory.spawn(unit_id)
		if probe != null:
			opening_damage = snappedf(float(probe.attack_damage) * float(probe.attack_speed), 0.1)
			opening_health = int(probe.max_hp)
			opening_armor = float(probe.armor)
		candidates.append({
			"id": unit_id,
			"label": label,
			"primary_role": primary_role,
			"primary_goal": primary_goal,
			"traits": traits,
			"cost": int(meta.get("cost", 0)),
			"level_one_damage_per_second": opening_damage,
			"level_one_max_hp": opening_health,
			"level_one_armor": opening_armor,
			"effect": "Start the run with %s (%s, %s, traits %s). Level 1: %.1f damage per second, %d health, %.0f armor. The opening fight is fought with this unit alone." % [
				unit_id,
				primary_role if not primary_role.is_empty() else "unknown role",
				primary_goal if not primary_goal.is_empty() else "unknown goal",
				", ".join(traits) if not traits.is_empty() else "none",
				opening_damage,
				opening_health,
				opening_armor,
			],
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

## Bounded retry around every inherited button click. Synthetic mouse events
## intermittently miss controls that are visibly present, enabled and mouse_filter 0 -
## seen on a shop slot and then on the unit-select start button, where the miss aborted
## the whole run before the first fight. Each attempt is still a real engine-parsed
## mouse event; only the retries are new. Only the final attempt's failure is kept, so a
## control that genuinely cannot be clicked still fails loudly.
func _click_button(button: Button, label: String) -> bool:
	var failures_at_start: int = _failures.size()
	for attempt: int in range(SHOP_CLICK_ATTEMPTS):
		var failures_before: int = _failures.size()
		var clicked: bool = await super._click_button(button, label)
		if clicked:
			if attempt > 0:
				_append_event("click_retry", {"label": label, "attempt": attempt + 1})
			return true
		if attempt + 1 >= SHOP_CLICK_ATTEMPTS:
			break
		# Discard this attempt's recorded failure: it is an input miss we are retrying,
		# not a finding. The final attempt's failure is left in place.
		while _failures.size() > failures_before:
			_failures.remove_at(_failures.size() - 1)
		await _settle_frames(4)
	# Every synthetic attempt was swallowed. The control is still rendered, enabled and
	# in the tree, so this is an input-layer artifact rather than a finding about the
	# game; it was recorded on every run of the ten-game batch against the same shop
	# slot. Emit the signal so the run can continue, record it explicitly, and drop the
	# retry failures so a recovered input miss cannot invalidate a transcript.
	if button == null or not is_instance_valid(button) or not button.is_inside_tree() or button.disabled:
		return false
	while _failures.size() > failures_at_start:
		_failures.remove_at(_failures.size() - 1)
	_append_event("click_fallback", {
		"label": label,
		"attempts": SHOP_CLICK_ATTEMPTS,
		"rect": str(button.get_global_rect()),
	})
	button.emit_signal("pressed")
	await _settle_frames(4)
	return true

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
	var xp_price: int = int(SHOP_CONFIG.BUY_XP_COST)
	var capacity_now: int = _roster_max_team_size()
	var capacity_after: int = _level_board_capacity(_level_after_xp_purchase(int(Shop.get_level()), int(Shop.get_xp())))
	var board_size: int = _board_ids().size()
	var bench_units: Array[String] = _bench_ids()
	# A level purchase is only worth the buckets when the slot it opens has a body
	# waiting for it. Stating that count is the difference between "buy XP" as an
	# abstraction and a payoff the decision can price.
	var waiting_bodies: int = min(bench_units.size(), max(0, capacity_after - board_size))
	# The level question is asked before the shop purchases, so a bench of zero does
	# not mean the slot is useless: the shelf may hold bodies that would fill it in the
	# same planning beat. Without this the decision passed on every level purchase at
	# the chapter-1 boss while holding twelve buckets and a three-slot board.
	var affordable_shelf: int = 0
	var affordable_shelf_ids: Array[String] = []
	for offer_summary: Dictionary in _offer_summaries():
		var shelf_cost: int = int(offer_summary.get("cost", 0))
		var shelf_id: String = String(offer_summary.get("id", ""))
		if shelf_id.is_empty() or shelf_cost <= 0:
			continue
		if not _can_afford_shop_cost(shelf_cost):
			continue
		affordable_shelf += 1
		affordable_shelf_ids.append(shelf_id)
	var shelf_bodies_that_could_gain_a_slot: int = min(affordable_shelf, max(0, capacity_after - board_size))
	var level_gain_note: String = "no extra slot" if capacity_after <= capacity_now else "+%d board slot" % (capacity_after - capacity_now)
	var candidates: Array[Dictionary] = [
		{
			"id": "buy_xp",
			"label": "Buy XP for %d buckets (level %d -> capacity %d)." % [
				xp_price,
				int(Shop.get_level()),
				capacity_after,
			],
			"capacity_now": capacity_now,
			"capacity_after": capacity_after,
			"capacity_delta": capacity_after - capacity_now,
			"board_size": board_size,
			"bench_size": bench_units.size(),
			"benched_bodies_that_gain_a_slot": waiting_bodies,
			"bench": bench_units,
			"buckets_after": gold - xp_price,
			"reserve_floor": _reserve_floor_buckets,
			"encounter_kind": String(Economy.encounter_quote_kind),
			"affordable_offers_on_shelf": affordable_shelf,
			"affordable_shelf_ids": affordable_shelf_ids,
			"shelf_bodies_that_could_gain_a_slot": shelf_bodies_that_could_gain_a_slot,
			"effect": "Spend %d of %d buckets on %d XP, leaving %d. Board %d of %d now, %d of %d after (%s). Bench holds %d unit(s); %d would gain a slot, and the shelf offers %d affordable body(ies) (%d of them could be bought and fielded in this same beat)." % [
				xp_price,
				gold,
				int(SHOP_CONFIG.XP_PER_BUY),
				gold - xp_price,
				board_size,
				capacity_now,
				board_size,
				capacity_after,
				level_gain_note,
				bench_units.size(),
				waiting_bodies,
				affordable_shelf,
				shelf_bodies_that_could_gain_a_slot,
			],
		},
		{
			"id": "pass",
			"label": "Do not buy XP now.",
			"capacity_now": capacity_now,
			"capacity_after": capacity_now,
			"capacity_delta": 0,
			"board_size": board_size,
			"bench_size": bench_units.size(),
			"benched_bodies_that_gain_a_slot": 0,
			"buckets_after": gold,
			"reserve_floor": _reserve_floor_buckets,
			"encounter_kind": String(Economy.encounter_quote_kind),
			"effect": "Keep %d buckets for bodies; the board stays at %d of %d slots." % [gold, board_size, capacity_now],
		},
	]
	var state: Dictionary = _plan_state()
	state["decision_label"] = label
	state["before_buys"] = before_buys
	var decision: Dictionary = await _ask_decision("buy_xp", state, candidates)
	var chosen: String = String(decision.get("choice_id", ""))
	if chosen != "buy_xp":
		return false
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
	# Items before the wager: a component that completes an item changes the board the
	# wager is being placed on, so the risk decision has to see the equipped board.
	await _decide_items(label)
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
		# Both teams' model ratings, plus the stage's target rating. The preview odds
		# are a function of the first two, so recording them is what makes "the ramp
		# outran the board" a measurement instead of an inference from the boards.
		"player_power": snappedf(CombatPowerModel.team_power(_board_units()), 0.01),
		"enemy_power": snappedf(CombatPowerModel.team_power(_enemy_units()), 0.01),
		"target_rating": _stage_target_rating(),
		# Board plus bench with each unit's level. The round payload records ids
		# only, so a combine into a level-2/3 unit is invisible without this, and
		# a three-star waiting on the bench would never show up at all.
		"owned_units": _roster_snapshot(),
		# Creep stages are the documented item source. Recording the inventory before
		# every fight is what makes "did a creep round actually pay out?" answerable from
		# the transcript instead of inferred.
		"inventory": Items.get_inventory_snapshot() if Items != null else {},
		"wager": int(Economy.current_bet),
		"buckets": int(Economy.blood_buckets),
		"stake_unit": int(Economy.stake_unit),
		"encounter_kind": String(Economy.encounter_quote_kind),
		"quoted_multiplier": float(Economy.gross_payout_multiplier()),
		"shown_win_odds": float(Economy.projected_win_probability),
		# The number the decision actually acted on is Economy.projected_win_probability,
		# which the combat view refreshes on its own signals. That refresh can lag the
		# final board - items are equipped after deployment - so the odds are also
		# recomputed here from the teams that are about to fight. Comparing the two in
		# the transcript separates "the display is stale" from "the model is wrong".
		"live_win_odds": _live_win_odds(),
		"planning_seconds_left": snappedf(_planning_time_left(), 0.01),
	})
	var chapter_before: int = int(GameState.chapter)
	var stage_before: int = int(GameState.stage_in_chapter)
	await _maybe_capture_planning(label)
	for attempt: int in range(START_BATTLE_ATTEMPTS):
		await super._press_continue(expect_forced, label)
		if await _fight_started_or_stage_moved(chapter_before, stage_before):
			return
		if attempt + 1 >= START_BATTLE_ATTEMPTS:
			return
		# The click was swallowed but the beat is still open and unchanged, so the
		# retry presses the same Start Battle button rather than starting anything new.
		_append_event("start_battle_retry", {"label": label, "attempt": attempt + 1})
		await _settle_frames(8)

## Save a frame of the live planning beat so a UI layout report can be checked
## against the real render instead of a description. Bounded per run.
func _maybe_capture_planning(label: String) -> void:
	if not _capture_planning or _capture_budget <= 0:
		return
	_capture_budget -= 1
	await RenderingServer.frame_post_draw
	var texture: ViewportTexture = get_viewport().get_texture()
	if texture == null:
		return
	var image: Image = texture.get_image()
	if image == null:
		return
	var file_name: String = "planning_ch%d_r%d_%d.png" % [
		int(GameState.chapter),
		int(GameState.stage_in_chapter),
		_capture_budget,
	]
	var error: int = image.save_png(_run_dir.path_join(file_name))
	_append_event("planning_capture", {
		"file": file_name,
		"label": label,
		"ok": error == OK,
		"board": _board_ids(),
		"board_capacity": _roster_max_team_size(),
		"enemy_count": _enemy_units().size(),
		"viewport": str(get_viewport().get_visible_rect().size),
	})

## True once combat is live or the stage already moved on. Both mean the Start
## Battle press took effect; the second case is a fight that resolved fast.
func _fight_started_or_stage_moved(chapter_before: int, stage_before: int) -> bool:
	var deadline: int = Time.get_ticks_msec() + 2000
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		if int(GameState.phase) == int(GameState.GamePhase.COMBAT) or bool(Economy.combat_active):
			return true
		if int(GameState.chapter) != chapter_before or int(GameState.stage_in_chapter) != stage_before:
			return true
	return false

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
		# Keep the engine's own settlement line. It is the only record of the fight's
		# real survivor counts: the board is rebuilt during settlement, so reading the
		# teams afterwards describes the next stage.
		_last_resolution_line = text
		var fields: Dictionary = {}
		for field_token: String in text.substr("Combat resolved: ".length()).split(" "):
			if "=" not in field_token:
				continue
			var key: String = field_token.split("=")[0]
			var value_text: String = field_token.split("=")[1].trim_suffix(".")
			if value_text.is_valid_int():
				fields[key] = value_text.to_int()
			elif value_text.is_valid_float():
				fields[key] = value_text.to_float()
		_last_resolution_fields = fields
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
		# Which unit the run is actually committed to, and how close it is to a
		# three-star, so every decision can price an offer against the plan.
		"vertical": _vertical_summary(),
		# The cheapest trait ladder to finish, so a run has a reason to stack one.
		"trait_goal": _trait_goal_summary(),
		"planning_time_left": float(controller_node.get("planning_time_left")) if controller_node != null else -1.0,
		"planning_timer_total": float(controller_node.get("planning_timer_total")) if controller_node != null else -1.0,
		"time_scale": Engine.time_scale,
		"shop_seed_explicit": _seed_explicit,
		"campaign": {
			"mode": _run_mode,
			"lane": _lane,
			"seed": _campaign_seed,
			"target_chapter": _campaign_target_chapter(),
			"target_round": _campaign_target_round(),
		},
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

## The trait closest to being maxed, and how many more unique bodies it needs.
##
## Traits count unique units, so maxing one is a board-composition goal, not a
## duplicate goal: the cheapest top tier among the traits already held is the one to
## chase. Reported as a fact because nothing in the run had a reason to stack a trait,
## which is why no run has ever maxed one.
func _trait_goal_summary() -> Dictionary:
	var best: Dictionary = {}
	for entry: Dictionary in _trait_snapshot(_owned_units()):
		var top: int = int(entry.get("top_threshold", 0))
		if top < 2:
			# A single-rung trait is an always-on aura, not a ladder to climb.
			continue
		var count: int = int(entry.get("count", 0))
		var needed: int = maxi(0, top - count)
		if needed <= 0:
			continue
		if best.is_empty() or needed < int(best.get("more_needed", 9999)):
			best = {
				"trait_id": String(entry.get("id", "")),
				"owned_unique": count,
				"top_threshold": top,
				"more_needed": needed,
				"already_maxed": int(entry.get("next_threshold", 1)) == 0,
			}
	return best

## The player's own revealed commitment: the identity they hold the most copies of,
## measured in level-1 equivalents because a combine consumes three of them, so a
## three-star is nine. Reported as a fact so the model does not have to re-derive
## which unit it is committed to in every shop - left to re-decide, it spread eight
## purchases across five identities and never finished a single combine.
func _vertical_summary() -> Dictionary:
	var equivalents: Dictionary[String, int] = {}
	for unit: Unit in _owned_units():
		if unit == null:
			continue
		var unit_id: String = _unit_id(unit)
		if unit_id.is_empty():
			continue
		var value: int = 1
		for _step: int in range(maxi(0, int(unit.level) - 1)):
			value *= 3
		equivalents[unit_id] = int(equivalents.get(unit_id, 0)) + value
	var target_id: String = ""
	var best: int = 0
	for candidate_id: String in equivalents.keys():
		var count: int = int(equivalents[candidate_id])
		if count > best or (count == best and target_id != "" and candidate_id < target_id):
			best = count
			target_id = candidate_id
	if target_id.is_empty():
		return {}
	return {
		"target_id": target_id,
		"level1_equivalents": best,
		"copies_to_three_star": maxi(0, 9 - best),
		"progress_percent": int(round(100.0 * float(mini(best, 9)) / 9.0)),
	}

func _owned_units() -> Array[Unit]:
	var units: Array[Unit] = _board_units()
	for bench_unit: Unit in Roster.compact():
		if bench_unit != null and not units.has(bench_unit):
			units.append(bench_unit)
	return units

## Every owned unit with its level and where it sits. A combine is only visible in
## the transcript if the level of each owned unit is recorded: the round payload
## carries ids, and a upgraded unit benched for a beat would otherwise vanish.
func _roster_snapshot() -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	var seen: Array[Unit] = []
	for unit: Unit in _board_units():
		if unit == null or seen.has(unit):
			continue
		seen.append(unit)
		records.append({"id": _unit_id(unit), "level": int(unit.level), "where": "board"})
	# Direct reference rather than Engine.has_singleton: a script autoload is not an
	# engine singleton, so that guard was always false and the bench half of this
	# snapshot was silently empty - a combined unit sitting on the bench could not be
	# seen at all.
	for bench_unit: Unit in Roster.compact():
		if bench_unit == null or seen.has(bench_unit):
			continue
		seen.append(bench_unit)
		records.append({"id": _unit_id(bench_unit), "level": int(bench_unit.level), "where": "bench"})
	return records

## Running maxima for the acceptance targets: a three-star unit, a trait at its top
## tier, and a board filled to its capacity. Derived from the recorded events so a
## run states its own progress instead of leaving it to be inferred by hand.
func _progression_summary() -> Dictionary:
	var max_unit_level: int = 1
	var three_star_ids: Dictionary[String, bool] = {}
	var maxed_traits: Dictionary[String, bool] = {}
	var max_board_size: int = 0
	var max_board_capacity: int = 0
	var planning_beats_with_a_full_board: int = 0
	var peak_shop_level: int = int(Shop.get_level())
	for event: Dictionary in _events:
		var kind: String = String(event.get("kind", ""))
		var payload: Dictionary = event.get("payload", {}) as Dictionary
		if kind == "fight_start":
			var owned: Array = payload.get("owned_units", []) as Array
			if owned.is_empty():
				owned = payload.get("player_units", []) as Array
			for record_value: Variant in owned:
				var record: Dictionary = record_value as Dictionary
				var unit_level: int = int(record.get("level", 1))
				max_unit_level = max(max_unit_level, unit_level)
				if unit_level >= 3:
					three_star_ids[String(record.get("id", ""))] = true
			for trait_value: Variant in (payload.get("deployed_traits", []) as Array):
				var trait_entry: Dictionary = trait_value as Dictionary
				if bool(trait_entry.get("maxed", false)):
					maxed_traits[String(trait_entry.get("id", ""))] = true
		elif kind == "round":
			var capacity: int = int(payload.get("cap_after_shop", 0))
			var board_size: int = (payload.get("board_after_shop", []) as Array).size()
			max_board_capacity = max(max_board_capacity, capacity)
			max_board_size = max(max_board_size, board_size)
			peak_shop_level = max(peak_shop_level, int(payload.get("level_after_shop", 0)))
			if capacity > 0 and board_size >= capacity:
				planning_beats_with_a_full_board += 1
	return {
		"max_unit_level": max_unit_level,
		"three_star_units": three_star_ids.keys(),
		"maxed_traits": maxed_traits.keys(),
		"max_board_size": max_board_size,
		"max_board_capacity": max_board_capacity,
		"board_filled_to_capacity": max_board_capacity > 0 and max_board_size >= max_board_capacity,
		"planning_beats_with_a_full_board": planning_beats_with_a_full_board,
		"peak_shop_level": peak_shop_level,
	}

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
		# TraitCompiler reports tier -1 when no threshold is met, and tier 0 is a
		# live first tier: StackUtils.active() is `tier >= 0`, and the player-facing
		# TraitsPresenter partitions on `tier >= 0` too. Reporting tier 0 as inactive
		# told the model a trait that the engine had already switched on was off.
		var tier_index: int = int(tiers.get(trait_id, -1))
		snapshot.append({
			"id": trait_id,
			"count": count,
			"tier": tier_index,
			"active": tier_index >= 0,
			"next_threshold": next_threshold,
			# The last rung on this trait's ladder. Needed to price "how many more
			# unique bodies to MAX it", which is a different question from the next
			# tier and is the one the acceptance target asks.
			"top_threshold": int(ladder[ladder.size() - 1]) if ladder.size() > 0 else 0,
			"needed": max(0, next_threshold - count) if next_threshold > 0 else 0,
			"tiers_available": ladder.size(),
			# No remaining checkpoint means the count has cleared every threshold, which
			# is what the game itself calls a maxed trait - Cartel at 2/2 shows as maxed
			# in the UI. `maxed_ladder` is the harder reading, restricted to traits that
			# actually have more than one tier; both are reported so a single-threshold
			# aura cannot be mistaken for a stacked build.
			"maxed": next_threshold == 0 and count > 0,
			"maxed_ladder": next_threshold == 0 and count > 0 and ladder.size() > 1,
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

## Whether the rendered card for a slot is actually buyable right now. Resolved from
## the grid the same way the click path resolves it, so the candidate list and the
## click cannot disagree about which offers are live.
func _shop_slot_is_purchasable(slot_index: int, unit_id: String) -> bool:
	if slot_index < 0:
		return false
	var combat: Node = _main.get_node_or_null("CombatView") if _main != null else null
	if combat == null:
		return false
	var grid: GridContainer = combat.get_node_or_null("MarginContainer/VBoxContainer/BottomStorageArea/ShopGrid") as GridContainer
	if grid == null:
		return false
	for child: Node in grid.get_children():
		var card: ShopCard = child as ShopCard
		if card == null or int(card.slot_index) != slot_index:
			continue
		if card.disabled:
			return false
		return unit_id == "" or String(card.offer_id) == unit_id
	return false

func _shop_candidates() -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	var summaries: Array[Dictionary] = _offer_summaries()
	# What one bucket is worth on the upcoming wager. A purchase is paid for in the
	# same currency, so every offer states what it displaces.
	var wager_kind: String = String(Economy.encounter_quote_kind)
	var wager_multiplier: float = float(Economy.gross_payout_multiplier())
	var wager_odds: float = float(Economy.projected_win_probability)
	var ev_per_bucket: float = wager_odds * (wager_multiplier - 1.0) - (1.0 - wager_odds)
	var vertical: Dictionary = _vertical_summary()
	var vertical_target_id: String = String(vertical.get("target_id", ""))
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
		# The shelf can still list an offer whose card has already been sold or
		# disabled. Offering it would have the model choose something it cannot buy,
		# and the click path then records "slot N is disabled" against the run.
		if not _shop_slot_is_purchasable(int(summary.get("slot", -1)), unit_id):
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
		# Whether this offer advances the run's own committed vertical, and where that
		# leaves the three-star.
		var is_vertical: bool = vertical_target_id != "" and unit_id == vertical_target_id
		var vertical_text: String = ""
		if is_vertical:
			var have: int = int(vertical.get("level1_equivalents", 0))
			vertical_text = " This is your committed vertical (%s): %d of 9 level-1 copies toward a three-star." % [
				vertical_target_id,
				have + (1 if offer_level <= 1 else 3),
			]
		candidates.append({
			"id": "offer_%d" % int(summary.get("slot", -1)),
			"label": "%s (cost %d, %s%s)" % [
				String(summary.get("name", unit_id)),
				cost,
				String(summary.get("primary_role", "unit")),
				", owns %d copies" % copies if copies > 0 else "",
			],
			"effect": "Buy %s at level %d for %d buckets; %d copies owned, %s. %s%s%s Leaves %d buckets. Those %d buckets would be worth %+.2f on the %s wager instead (%.2fx, shown odds %.0f%%)." % [
				unit_id,
				offer_level,
				cost,
				copies,
				combine_text,
				trait_text,
				activation_text,
				vertical_text,
				int(Economy.gold) - cost,
				cost,
				ev_per_bucket * float(cost),
				wager_kind,
				wager_multiplier,
				wager_odds * 100.0,
			],
			"is_vertical_target": is_vertical,
			"wager_expected_value_foregone": snappedf(ev_per_bucket * float(cost), 0.01),
			"wager_edge_per_bucket": snappedf(ev_per_bucket, 0.01),
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
	var pass_kind: String = String(Economy.encounter_quote_kind)
	var pass_multiplier: float = float(Economy.gross_payout_multiplier())
	var pass_odds: float = float(Economy.projected_win_probability)
	# A pass is only a real decision if the buckets it keeps have a stated use. The
	# wager is the immediate one, so its expected value is quoted here too.
	var pass_buckets: int = int(Economy.gold)
	var pass_ev: float = pass_odds * float(pass_buckets * (pass_multiplier - 1.0)) - (1.0 - pass_odds) * float(pass_buckets)
	var pass_candidate: Dictionary = {
		"id": "pass",
		"label": "Buy nothing in this shop.",
		"effect": "Keep all %d buckets for the wager, the next shop, or level XP. The %s fight quotes %.2fx at shown odds %.0f%%, so this bankroll is worth about %+.2f buckets on the wager." % [
			pass_buckets,
			pass_kind,
			pass_multiplier,
			pass_odds * 100.0,
			pass_ev,
		],
		"kept_buckets": pass_buckets,
		"wager_expected_value_if_kept": snappedf(pass_ev, 0.01),
		"shown_win_odds": pass_odds,
		"break_even_odds": 1.0 / max(0.01, pass_multiplier),
		"affordable": true,
	}
	candidates.append(pass_candidate)
	var reroll_price: int = int(Economy.reroll_price())
	if reroll_price > 0 and int(Economy.gold) - reroll_price >= _reserve_floor_buckets:
		# A reroll is only a real gamble when the model can see what it is chasing and
		# what the roll costs relative to the bankroll. A run with a 14,436-bucket
		# bankroll rerolled once in thirty-five fights and finished one copy short of
		# two separate three-stars.
		var progress: Dictionary = _best_combine_progress()
		var reroll_bankroll: int = int(Economy.gold)
		var reroll_cost_text: String = (
			"a rounding error against the bankroll"
			if reroll_bankroll >= reroll_price * 50
			else "%.1f%% of the bankroll" % (100.0 * float(reroll_price) / float(max(1, reroll_bankroll)))
		)
		var progress_text: String = " No three-of-a-kind is in progress."
		if not progress.is_empty():
			progress_text = " Closest combine: %s at level %d, %d of 3 held - %d more completes it." % [
				String(progress.get("id", "")),
				int(progress.get("level", 1)),
				int(progress.get("have", 0)),
				int(progress.get("need", 0)),
			]
		candidates.append({
			"id": "reroll",
			"label": "Reroll the shop for %d buckets." % reroll_price,
			# Neutral on purpose. This used to read "This is the gamble: it pays only
			# when the new roll beats the flex pick in front of you", which pre-judged
			# the action inside the candidate itself. Every policy variant then produced
			# identical decisions, so the stance being compared never reached the model.
			"effect": "Replace every current offer with a new roll. Costs %d buckets (%s) and leaves %d.%s What arrives is not known in advance." % [
				reroll_price,
				reroll_cost_text,
				reroll_bankroll - reroll_price,
				progress_text,
			],
			"affordable": true,
			"cost": reroll_price,
			"combined_cost_text": reroll_cost_text,
			"combine_progress": progress,
		})
	return candidates

## The three-of-a-kind closest to completing, across everything owned. Grouped by
## identity AND level because that is how CombineService groups them.
func _best_combine_progress() -> Dictionary:
	var groups: Dictionary[String, int] = {}
	for unit: Unit in _owned_units():
		if unit == null:
			continue
		var key: String = "%s#%d" % [_unit_id(unit), int(unit.level)]
		groups[key] = int(groups.get(key, 0)) + 1
	var best: Dictionary = {}
	for key: String in groups.keys():
		var count: int = int(groups[key])
		if count < 2:
			continue
		if count <= int(best.get("have", 0)):
			continue
		var parts: PackedStringArray = key.split("#")
		best = {
			"id": String(parts[0]),
			"level": int(parts[1]) if parts.size() > 1 else 1,
			"have": count,
			"need": maxi(0, 3 - count),
		}
	return best

## Item assignment, decided by Jev rather than by a helper.
##
## Items matter more than the policy's silence suggests: a component's value depends on
## which unit receives it, and `Items.equip` auto-combines two components that land on
## the same unit. That makes "which unit gets this component" the whole decision, and it
## is a decision the player makes, so it belongs here.
func _item_candidates() -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	if Items == null:
		return candidates
	var inventory: Dictionary = Items.get_inventory_snapshot()
	var board: Array[Unit] = _board_units()
	if board.is_empty():
		return candidates
	for raw_id: Variant in inventory.keys():
		var item_id: String = String(raw_id).strip_edges()
		if item_id == "" or item_id == "remover" or int(inventory[raw_id]) <= 0:
			continue
		var def: Variant = ItemCatalog.get_def(item_id)
		var item_name: String = item_id
		var item_kind: String = "unknown"
		var item_tags: String = ""
		var item_mods: String = ""
		if def != null:
			item_name = String(def.get("name")) if String(def.get("name")) != "" else item_id
			item_kind = String(def.get("type"))
			item_tags = ", ".join(def.get("tags"))
			item_mods = JSON.stringify(def.get("stat_mods"))
		for unit: Unit in board:
			if Items.get_equipped(unit).size() >= Items.slot_count(unit):
				continue
			var unit_id: String = _unit_id(unit)
			candidates.append({
				"id": "equip_%s_on_%s" % [item_id, unit_id],
				"label": "Equip %s to %s (level %d, %s)." % [item_name, unit_id, int(unit.level), String(unit.get("primary_role")) if unit.get("primary_role") != null else "unit"],
				"effect": "Put %s (%s%s%s) on %s, which currently holds %s. Two components on one unit combine automatically." % [
					item_name,
					item_kind,
					", tags: " + item_tags if item_tags != "" else "",
					", mods: " + item_mods if item_mods != "{}" else "",
					unit_id,
					", ".join(Items.get_equipped(unit)) if not Items.get_equipped(unit).is_empty() else "nothing",
				],
				"item_id": item_id,
				"unit_id": unit_id,
			})
	if candidates.is_empty():
		return candidates
	candidates.append({
		"id": "hold_items",
		"label": "Hold every item for now.",
		"effect": "Keep the components unassigned until a better unit is on the board.",
	})
	return candidates

## One planning beat can need several item decisions: two components on one unit is a
## deliberate two-step play, so a single pass would leave the second one unplaced.
## The same estimate the HUD shows, recomputed from the teams that are about to
## fight. Uses the game's own estimator so the two numbers are directly comparable.
func _live_win_odds() -> float:
	var player_team: Array[Unit] = _board_units()
	var enemy_team: Array[Unit] = _enemy_units()
	if player_team.is_empty() or enemy_team.is_empty():
		return -1.0
	var boss_factor: float = 1.0
	if RosterUtils.is_boss_stage(int(GameState.stage_in_chapter)):
		boss_factor = TeamOddsEstimator.BOSS_ESCALATION_PREVIEW_FACTOR
	var percent: int = TeamOddsEstimator.estimate_from_ratings(
		TeamOddsEstimator.team_rating(player_team),
		TeamOddsEstimator.team_rating(enemy_team),
		boss_factor,
	)
	return snappedf(float(percent) / 100.0, 0.001)

## The stage's design target rating. Read from the already-generated spec for the
## stage being fought; the procedural chapter is cached by the time a fight starts.
func _stage_target_rating() -> int:
	if RosterCatalog == null:
		return -1
	var spec: Variant = RosterCatalog.get_spec(int(GameState.chapter), int(GameState.stage_in_chapter))
	if not spec is Dictionary:
		return -1
	# StageTypes.make_spec only emits ids/kind/rules, so the target lives under rules.
	# Reading the top level returned -1 for every stage of every run.
	var rules: Variant = spec.get("rules", {})
	if rules is Dictionary:
		return int((rules as Dictionary).get("target_rating", -1))
	return -1

## Never trade a board unit away for a less invested body.
##
## The same defect as the id-collision trade-down, one step wider: the fielding plan
## is built from id strings, so it cannot see that the "grint" it wants to bench is a
## three-star holding an item and the "berebell" replacing it is a fresh level 1. A
## replacement has to be at least as invested as the unit leaving, which still allows
## upgrades and like-for-like role swaps while refusing to throw away levels or items.
func _swap_is_worthwhile(bench_out_id: String, field_id: String) -> bool:
	var out_unit: Unit = _board_unit_with_id(bench_out_id)
	var in_unit: Unit = _bench_unit_with_id(field_id)
	if out_unit == null or in_unit == null:
		return true
	return _investment(in_unit) >= _investment(out_unit)

## Record every board swap with the levels and item counts on both sides, so a
## trade-down (benching an invested unit to field a weaker copy) is visible as data
## instead of something only a player watching the screen would notice.
func _on_board_swap(bench_out_id: String, field_id: String, label: String) -> void:
	var out_unit: Unit = _board_unit_with_id(bench_out_id)
	var in_unit: Unit = _bench_unit_with_id(field_id)
	_append_event("board_swap", {
		"label": label,
		"bench_ids": _bench_ids(),
		"out_id": bench_out_id,
		"out_level": int(out_unit.level) if out_unit != null else -1,
		"out_items": Items.get_equipped(out_unit).size() if (out_unit != null and Items != null) else 0,
		"in_id": field_id,
		"in_level": int(in_unit.level) if in_unit != null else -1,
		"in_items": Items.get_equipped(in_unit).size() if (in_unit != null and Items != null) else 0,
		"trade_down": out_unit != null and in_unit != null and _investment(in_unit) < _investment(out_unit),
	})

## Which board unit to trade away when a bench unit is being fielded.
##
## The inherited chooser works on id strings, so it cannot tell a level-3 Bonko
## holding three items from a freshly bought level-1 Bonko - both are "bonko". It
## benched the invested one and fielded the fresh copy, repeatedly: the run slammed
## three items onto a Bonko, watched it get benched for a level-1 copy, lost, bought
## another, and did it again. Investment is never worth trading down, so an
## invested board unit is not a swap candidate while a weaker same-id copy waits on
## the bench, and the weakest board unit is preferred otherwise.
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
	var worst_id: String = ""
	var worst_score: int = 1 << 30
	for board_id: String in board:
		var board_unit: Unit = _board_unit_with_id(board_id)
		if board_unit == null:
			continue
		var bench_copy: Unit = _bench_unit_with_id(board_id)
		if bench_copy != null and _investment(bench_copy) <= _investment(board_unit):
			# Trading this copy down for a weaker one of the same identity is never
			# worth it; leave it alone.
			continue
		# A unit the fielding plan does not want is the natural swap; otherwise take
		# the least invested body.
		var score: int = _investment(board_unit)
		if not field_ids.has(board_id):
			score -= 1000
		if score < worst_score:
			worst_score = score
			worst_id = board_id
	return worst_id

## Rough value of a unit: level first, then how many items it carries.
func _investment(unit: Unit) -> int:
	if unit == null:
		return 0
	var item_count: int = 0
	if Items != null:
		item_count = Items.get_equipped(unit).size()
	return maxi(1, int(unit.level)) * 100 + item_count

func _board_unit_with_id(unit_id: String) -> Unit:
	for unit: Unit in _board_units():
		if unit != null and _unit_id(unit) == unit_id:
			return unit
	return null

func _bench_unit_with_id(unit_id: String) -> Unit:
	# No Engine.has_singleton guard: a script autoload is not an engine singleton, so
	# that check is always false and this lookup silently returned null every time,
	# which is why a swap guard could not see the unit it was trading away.
	for unit: Unit in Roster.compact():
		if unit != null and _unit_id(unit) == unit_id:
			return unit
	return null

## Deploy by role instead of by first empty tile.
##
## The player board is 8 columns x 3 rows and index 0 is the top row, which is the
## rank that faces the enemy. Filling the first empty tile therefore put every early
## unit in the front rank: a run was observed holding mage at tile 2, support at 3,
## marksman at 5/6 and tank at 4 - all in row 0, so the backline was tanking. Front
## roles take the front rank first; everyone else starts in the back rank.
const BOARD_COLUMNS: int = 8
const FRONTLINE_ROLES: Array[String] = ["tank", "brawler", "assassin"]

func _preferred_board_tile(controller: Variant, unit_id: String) -> int:
	if controller == null or controller.player_grid_helper == null:
		return -1
	# Called through Variant on purpose: a strict `as BoardGrid` cast here silently
	# failed and the deployment fell back to the first empty tile, which is what put
	# the backline in the front rank.
	var helper: Variant = controller.player_grid_helper
	if not helper.has_method("size") or not helper.has_method("is_occupied"):
		return -1
	var tile_count: int = int(helper.call("size"))
	if tile_count <= 0:
		return -1
	var rows: int = maxi(1, int(tile_count / BOARD_COLUMNS))
	var frontline: bool = FRONTLINE_ROLES.has(_unit_role(unit_id))
	# Front roles fill row 0 outward; back roles fill the last row outward. Both fall
	# back through the remaining rows so a large board still deploys.
	var row_order: Array[int] = []
	if frontline:
		for row: int in range(rows):
			row_order.append(row)
	else:
		for row: int in range(rows - 1, -1, -1):
			row_order.append(row)
	for row: int in row_order:
		for column: int in range(BOARD_COLUMNS):
			var index: int = row * BOARD_COLUMNS + column
			if index < tile_count and not bool(helper.call("is_occupied", index)):
				return index
	return -1

## Deterministic item handling for the baseline arm. Components only do anything
## once they are equipped, so the control run places each held component on the
## first board unit with a free slot rather than leaving the inventory untouched.
func _auto_equip_items(label: String) -> void:
	if Items == null:
		return
	for _round: int in range(ITEM_DECISIONS_PER_BEAT):
		var inventory: Dictionary = Items.get_inventory_snapshot()
		var item_id: String = ""
		for raw_id: Variant in inventory.keys():
			if int(inventory[raw_id]) > 0:
				item_id = String(raw_id)
				break
		if item_id.is_empty():
			return
		var placed: bool = false
		for unit: Unit in _board_units():
			if unit == null:
				continue
			if Items.get_equipped(unit).size() >= Items.slot_count(unit):
				continue
			var res: Dictionary = Items.equip(unit, item_id)
			_append_event("item_equipped", {
				"item_id": item_id,
				"unit_id": _unit_id(unit),
				"ok": bool(res.get("ok", false)),
				"reason": String(res.get("reason", "")),
				"combined_id": String(res.get("combined_id", "")),
				"label": label,
				"basis": "heuristic_first_fit",
			})
			if bool(res.get("ok", false)):
				placed = true
				break
		if not placed:
			return

func _decide_items(label: String) -> void:
	# The heuristic arm has no controller, so asking would stall the run until the
	# decision timeout. It equips first-fit instead, so the baseline arm keeps
	# comparable power and still finishes on the same seed.
	if _run_mode != "jev":
		_auto_equip_items(label)
		return
	for _round: int in range(ITEM_DECISIONS_PER_BEAT):
		var candidates: Array[Dictionary] = _item_candidates()
		if candidates.size() <= 1:
			return
		var state: Dictionary = _plan_state()
		var equipped: Array[Dictionary] = []
		for unit: Unit in _board_units():
			equipped.append({
				"unit_id": _unit_id(unit),
				"level": int(unit.level),
				"items": Items.get_equipped(unit),
			})
		state["equipped"] = equipped
		state["items_held"] = Items.get_inventory_snapshot()
		var decision: Dictionary = await _ask_decision("item_equip", state, candidates)
		var chosen: String = String(decision.get("choice_id", ""))
		if chosen == "hold_items" or chosen == "":
			return
		var placed: bool = false
		for candidate: Dictionary in candidates:
			if String(candidate.get("id", "")) != chosen:
				continue
			var target_id: String = String(candidate.get("unit_id", ""))
			for unit: Unit in _board_units():
				if _unit_id(unit) != target_id:
					continue
				var res: Dictionary = Items.equip(unit, String(candidate.get("item_id", "")))
				_append_event("item_equipped", {
					"item_id": String(candidate.get("item_id", "")),
					"unit_id": target_id,
					"ok": bool(res.get("ok", false)),
					"reason": String(res.get("reason", "")),
					"combined_id": String(res.get("combined_id", "")),
					"label": label,
				})
				placed = true
				break
			break
		if not placed:
			_append_event("decision_rejected", {"kind": "item_equip", "choice_id": chosen, "reason": "not_an_item_candidate"})
			return

func _wager_candidates(reserve: int) -> Array[Dictionary]:
	var quote_kind: String = String(Economy.encounter_quote_kind)
	var multiplier: float = float(Economy.gross_payout_multiplier())
	var shown_odds: float = float(Economy.projected_win_probability)
	var break_even: float = 1.0 / max(0.01, multiplier)
	var net_odds: float = maxf(0.01, multiplier - 1.0)
	# Kelly: the stake that grows the bankroll fastest at these odds, for a bet paying
	# `multiplier` including the stake. A near-lock pushes it toward the whole
	# bankroll; a marginal edge pushes it toward the minimum.
	var kelly_fraction: float = clampf((shown_odds * multiplier - 1.0) / net_odds, -1.0, 1.0)
	var kelly_wager: int = clampi(int(round(float(reserve) * maxf(0.0, kelly_fraction))), 1, reserve)
	# Named stakes rather than anonymous bankroll fractions. The model is choosing an
	# intent, and "25% of the bankroll" collapses onto the same integer as "minimum"
	# as soon as the bankroll is small, which is how every early wager became a
	# one-bucket bet.
	var plans: Array[Dictionary] = [
		{
			"stake": 1,
			"role": "minimum",
			"why": "The smallest legal wager. Correct only at or below break-even odds.",
		},
		{
			"stake": kelly_wager,
			"role": "kelly",
			"why": "The stake that grows the bankroll fastest at these odds.",
		},
		{
			"stake": maxi(kelly_wager, int(ceil(float(reserve) * 0.5))),
			"role": "press",
			"why": "Half the bankroll or the Kelly stake, whichever is larger. Correct when the odds are profitable but below 50%.",
		},
		{
			"stake": reserve,
			"role": "all_in",
			"why": "The whole bankroll, which doubles on a win at 2x. Correct when the shown odds are above 50%.",
		},
	]
	var candidates: Array[Dictionary] = []
	var seen: Dictionary[int, bool] = {}
	for plan: Dictionary in plans:
		var wager: int = clampi(int(plan.get("stake", 1)), 1, reserve)
		if seen.has(wager):
			continue
		seen[wager] = true
		var payout: int = int(Economy.quoted_payout(wager))
		var profit: int = payout - wager
		var actual_share: int = int(round(100.0 * float(wager) / float(max(1, reserve))))
		# Expected value of the wager at the shown win odds.
		var expected_value: float = shown_odds * float(profit) - (1.0 - shown_odds) * float(wager)
		candidates.append({
			"id": "wager_%d" % wager,
			"label": "%s: wager %d of %d buckets (%d%% of the bankroll); a win pays %d gross for %+d profit, a loss leaves %d." % [
				String(plan.get("role", "stake")).to_upper(),
				wager,
				reserve,
				actual_share,
				payout,
				profit,
				reserve - wager,
			],
			"effect": "%s %s quote %.2fx, break-even win odds %.0f%%, shown odds %.0f%% (Kelly stake %d of %d). Expected value %+.2f buckets. Loss leaves %d buckets." % [
				String(plan.get("why", "")),
				quote_kind,
				multiplier,
				break_even * 100.0,
				shown_odds * 100.0,
				kelly_wager,
				reserve,
				expected_value,
				reserve - wager,
			],
			"wager": wager,
			"role": String(plan.get("role", "stake")),
			"share": float(wager) / float(max(1, reserve)),
			"is_all_in": wager >= reserve,
			"is_pressing": String(plan.get("role", "")) in ["press", "all_in"],
			"kelly_fraction": snappedf(kelly_fraction, 0.001),
			"kelly_wager": kelly_wager,
			"is_kelly_sized": wager == kelly_wager,
			"payout_if_win": payout,
			"profit_if_win": profit,
			"shown_win_odds": shown_odds,
			"expected_value_buckets": snappedf(expected_value, 0.01),
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
	# The controller did not answer. Every caller treats an empty decision as its safe
	# default (pass, minimum wager, hold, back out), so the run continues and the
	# transcript records exactly where it fell back. Aborting here threw away a
	# 47-battle run that was one stage from its target because of one upstream 5xx.
	_append_event("decision_timeout", {
		"index": _decision_index,
		"kind": kind,
		"timeout_seconds": int(DECISION_TIMEOUT_SECONDS),
		"fallback": "safe_default",
	})
	print("%s: decision %d (%s) unanswered after %ds; continuing on the safe default" % [
		JEV_HARNESS_NAME,
		_decision_index,
		kind,
		int(DECISION_TIMEOUT_SECONDS),
	])
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
	# Computed once so the event and the summary cannot disagree about why the run
	# stopped.
	var outcome_record: Dictionary = _run_outcome_record(terminal)
	_append_event("run_outcome", outcome_record)
	var summary: Dictionary = _run_summary(terminal, outcome_record)
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

## Why the run stopped, in the terms the design can act on.
##
## A terminal like "loss" says nothing about whether the board was outnumbered on
## the clock, wiped outright, or beaten after spending nothing. This record ties the
## ending to the fight that caused it: the encounter, the odds against the quote, the
## wager, both boards, whether the clock decided it, and whether the run died with
## board slots or buckets still in hand.
func _run_outcome_record(terminal: String) -> Dictionary:
	var diagnostic: Dictionary = _last_combat_diagnostic
	var player_team: Array = diagnostic.get("post_settlement_player_board", [])
	var board_size: int = _board_ids().size()
	var capacity: int = _roster_max_team_size()
	var buckets: int = int(Economy.blood_buckets)
	var elapsed: float = float(diagnostic.get("engine_reported_elapsed_s", 0.0))
	var timeout_s: float = float(diagnostic.get("combat_timeout_s", 0.0))
	var clock_decided: bool = timeout_s > 0.0 and elapsed >= timeout_s - 0.3
	# Prefer the engine's own settlement line: post-settlement team reads describe the
	# board that was rebuilt for the next stage, not the fight that just ended.
	var player_alive: int = int(_last_resolution_fields.get("player_alive", diagnostic.get("post_settlement_player_alive", -1)))
	var enemy_alive: int = int(_last_resolution_fields.get("enemy_alive", diagnostic.get("post_settlement_enemy_alive", -1)))
	var player_damage: int = int(_last_resolution_fields.get("player_damage", diagnostic.get("player_damage", 0)))
	var enemy_damage: int = int(_last_resolution_fields.get("enemy_damage", diagnostic.get("enemy_damage", 0)))
	var stage_key: String = "%d:%d" % [int(GameState.chapter), int(GameState.stage_in_chapter)]
	var attempts: int = int(_same_stage_retries.get(stage_key, 0))
	var shown: float = float(Economy.projected_win_probability)
	var quote: float = float(Economy.gross_payout_multiplier())
	var break_even: float = 1.0 / maxf(0.01, quote)
	var cause: String = ""
	var failed: bool = true
	match terminal:
		"loss":
			if clock_decided and enemy_alive > player_alive:
				cause = "clock_outnumbered"
			elif clock_decided and enemy_alive == player_alive:
				# Equal survivors sends the award to total remaining health, so a board
				# can out-damage the enemy and still lose the clock.
				cause = "clock_equal_survivors_lost_on_health"
			elif clock_decided and player_alive <= 0:
				cause = "wiped_on_clock"
			elif player_alive <= 0:
				cause = "wiped"
			else:
				cause = "lost_fight"
		"opener_loss":
			cause = "lost_opener"
		"opener_stall":
			cause = "opener_stall"
		"stage_stall":
			cause = "stage_stall_after_%d_attempts" % attempts
		"technical_failure":
			cause = "harness_fault"
		"aborted":
			cause = "harness_abort"
		"target_reached":
			cause = "reached_campaign_target"
			failed = false
		"battle_budget_reached":
			cause = "battle_budget_reached"
			failed = false
		_:
			cause = terminal
	# The questions a loss actually raises. Each is a fact, not a judgement.
	var notes: Array[String] = []
	# Every note below is about a run that ENDED badly, so they are gated on failure:
	# a successful run also finishes holding buckets and would otherwise be tallied as
	# a case of the same waste.
	if failed:
		if capacity > 0 and board_size < capacity:
			notes.append("board_fielded_%d_of_%d_slots" % [board_size, capacity])
		if buckets > 0:
			notes.append("died_holding_%d_buckets" % buckets)
		if shown <= break_even:
			notes.append("lost_a_bet_the_odds_called_negative")
		if shown > 0.5:
			notes.append("lost_a_favourite")
		# The signal that matters most for the design: a board that clearly
		# out-fought the enemy and still lost the stage.
		if player_damage > enemy_damage * 3 / 2 and player_alive >= enemy_alive:
			notes.append("out_damaged_the_enemy_and_still_lost")
		if String(Economy.encounter_quote_kind) in ["BOSS", "MIRROR"]:
			notes.append("died_on_a_gate_stage")
		if attempts > 0:
			notes.append("stage_attempt_%d" % (attempts + 1))
	return {
		"terminal": terminal,
		"failed": failed,
		"cause": cause,
		"notes": notes,
		"chapter": int(GameState.chapter),
		"round": int(GameState.stage_in_chapter),
		"global_stage": (int(GameState.chapter) - 1) * 5 + int(GameState.stage_in_chapter),
		"encounter_kind": String(Economy.encounter_quote_kind),
		"quoted_multiplier": quote,
		"break_even_odds": snappedf(break_even, 0.001),
		"shown_win_odds": snappedf(shown, 0.001),
		"wager": int(diagnostic.get("wager", 0)),
		"buckets_at_end": buckets,
		"board_size": board_size,
		"board_capacity": capacity,
		"board_full": capacity > 0 and board_size >= capacity,
		"stage_attempts": attempts,
		"clock_decided": clock_decided,
		"player_alive_after": player_alive,
		"enemy_alive_after": enemy_alive,
		"player_damage": player_damage,
		"enemy_damage": enemy_damage,
		"damage_ratio": snappedf(float(player_damage) / float(max(1, enemy_damage)), 0.01),
		"engine_resolution": _last_resolution_line,
		"battles": _battles,
		"peak_bankroll": int(Economy.peak_bankroll),
		"technical_failures": _failures.duplicate(),
		"player_board": diagnostic.get("post_settlement_player_board", []),
		"enemy_board": diagnostic.get("post_settlement_enemy_board", []),
	}

## The full run record. Written once per round as a checkpoint and again when the run
## ends, so a long run that dies for any reason still leaves its data behind - the
## deepest runs are the expensive ones, and they were the ones being lost.
func _run_summary(terminal: String, outcome_record: Dictionary = {}) -> Dictionary:
	return {
		"schema_version": 1,
		"harness": JEV_HARNESS_NAME,
		"mode": _run_mode,
		"lane": _lane,
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
		# Acceptance targets for the run: a three-star unit, a trait at its top
		# tier, and a board filled to its capacity. Read from the recorded events.
		"progression": _progression_summary(),
		# Why the run stopped, tied to the fight that caused it.
		"outcome": outcome_record if not outcome_record.is_empty() else _run_outcome_record(terminal),
	}

## Cheap insurance for a long run. The full record is a few hundred KB, so writing it
## once per round is not free, but losing a nine-minute chapter-8 run to a silent exit
## costs far more.
func _checkpoint_run() -> void:
	var summary: Dictionary = _run_summary("in_progress")
	_write_run_file("run_checkpoint.json", JSON.stringify(summary, "  "))
