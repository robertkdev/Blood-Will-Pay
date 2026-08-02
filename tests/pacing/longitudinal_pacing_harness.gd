extends "res://tests/visual/natural_bonko_two_stage_main_flow_smoke.gd"

## Longitudinal pacing run over Main.tscn.
##
## The inherited natural-input flow supplies real clicks, drags, purchases,
## deployment, and autobattler resolution. This harness adds only observer
## telemetry and deliberate human-like pauses so the report measures player
## rhythm rather than a zero-delay test bot.

const PacingMetrics: Script = preload("res://tests/pacing/pacing_metrics.gd")
const PacingRecorder: Script = preload("res://tests/pacing/pacing_recorder.gd")

const PACING_SMOKE_NAME: String = "LongitudinalPacingHarness"
const PACING_STARTER_ID: String = "bonko"
const PACING_SHOP_SEED: int = 4401
const PACING_TARGET_STAGE: int = 9
const PACING_TARGET_CHAPTER: int = 2
const PACING_TARGET_ROUND: int = 4
const PACING_MAX_BATTLES: int = 12
const PACING_FIRST_FIGHT_TIMEOUT: float = 90.0
const PACING_ROUND_TIMEOUT: float = 90.0
const PACING_HUMAN_ACTION_DELAY_SECONDS: float = 1.5
const PACING_OPENING_DECISION_DELAY_SECONDS: float = 0.5
const PACING_HUMAN_SHOP_DELAY_SECONDS: float = 2.0
const PACING_HUMAN_PLAN_DELAY_SECONDS: float = 2.0
const PACING_CLEANUP_FRAMES: int = 20

var _recorder: Variant = null
var _reports: Array[Dictionary] = []
var _analysis: Dictionary[String, Variant] = {}
var _campaign_report: Dictionary[String, Variant] = {}
var _loss_report: Dictionary[String, Variant] = {}
var _awaiting_opening_decision: bool = false

func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	var window: Window = get_window()
	if window != null:
		window.size = Vector2i(1920, 1080)
		window.content_scale_size = Vector2i(1920, 1080)
	_previous_time_scale = Engine.time_scale
	_previous_suppress_validation_warnings = UnitFactory.suppress_validation_warnings
	UnitFactory.suppress_validation_warnings = true
	Engine.time_scale = 1.0
	_set_shop_seed(PACING_SHOP_SEED)

	_start_main_scene()
	await _settle_frames(8)
	var campaign_failure_start: int = _failures.size()
	_recorder = PacingRecorder.new()
	_recorder.begin(_main, {
		"id": "natural_campaign_bonko",
		"scope": "campaign",
		"starter": PACING_STARTER_ID,
		"seed": PACING_SHOP_SEED,
		"target_stage": PACING_TARGET_STAGE,
		"time_scale": Engine.time_scale,
		"entrypoint": "scenes/Main.tscn",
	})
	_awaiting_opening_decision = true
	await _run_campaign_sample()
	var campaign_target_reached: bool = _reached_two_stage_target()
	_recorder.finish("target_reached" if campaign_target_reached else "campaign_stopped", PACING_TARGET_STAGE)
	_campaign_report = _recorder.build_report()
	_campaign_report["run"] = _with_technical_failures(_campaign_report.get("run", {}), campaign_failure_start)
	_recorder.stop()
	await _cleanup_between_starters()

	await _run_loss_retry_sample()
	_reports = [_campaign_report, _loss_report]
	var suite: Dictionary[String, Variant] = {"schema_version": PacingMetrics.SCHEMA_VERSION, "runs": _reports}
	_analysis = PacingMetrics.analyze_suite(suite)
	_write_outputs(suite, _analysis)
	_finish_pacing(suite)

func _run_campaign_sample() -> void:
	_two_stage_results.clear()
	_two_stage_battles = 0
	_two_stage_buy_xp_clicks = 0
	# Main normally schedules an opening auto-start. If that deferred action is
	# not accepted on this frame, continue through the same visible opening-fight
	# control a player would use instead of waiting out a false harness timeout.
	await _ensure_unit_select()
	await _select_starter(_flow_starter_id())
	await _settle_frames(4)
	_expect(_node_visible("CombatView"), "CombatView did not open for pacing campaign")
	if GameState.phase == GameState.GamePhase.PREVIEW and not Economy.combat_active:
		await _reposition_first_board_unit("pacing opening decision")
		_set_planning_timer_safe()
		await _press_continue(true, "pacing opening fight")
	var first_result: String = await _wait_for_first_result(_flow_first_fight_timeout())
	_expect(first_result == "shop", "pacing opener should win into first shop, got %s state=%s" % [first_result, JSON.stringify(_two_stage_state())])
	if first_result != "shop":
		return
	_two_stage_battles = 1
	while _two_stage_battles < _flow_max_battles() and not _reached_two_stage_target():
		var round_result: Dictionary = await _play_two_stage_round()
		_two_stage_results.append(round_result)
		if not bool(round_result.get("advanced", false)):
			if _can_retry_after_same_stage(round_result):
				continue
			if String(round_result.get("fight_result", "")) == "loss":
				return
			_expect(false, "pacing campaign stopped: %s" % JSON.stringify(round_result))
			return
		if not _technical_failures().is_empty():
			return
	_expect(_reached_two_stage_target(), "pacing campaign should reach chapter %d round %d, got %s" % [_flow_target_chapter(), _flow_target_round(), JSON.stringify(_two_stage_state())])

func _run_loss_retry_sample() -> void:
	await _cleanup_between_starters()
	_set_shop_seed(PACING_SHOP_SEED + 1)
	_start_main_scene()
	await _settle_frames(8)
	# The production opener auto-starts immediately after starter confirmation.
	# Hold only this controlled loss sample at the real planning screen so the
	# harness can set the all-in bet and exercise the player-visible retry path.
	var loss_combat_view: Node = _main.get_node_or_null("CombatView") as Node
	var loss_controller: Object = loss_combat_view.get("controller") as Object if loss_combat_view != null else null
	if loss_controller != null:
		loss_controller.set("auto_combat", false)
	print("%s: controlled loss auto_combat=%s" % [PACING_SMOKE_NAME, str(loss_controller.get("auto_combat") if loss_controller != null else "missing")])
	_recorder = PacingRecorder.new()
	_recorder.begin(_main, {
		"id": "natural_loss_retry",
		"scope": "loss_retry",
		"starter": "axiom",
		"seed": PACING_SHOP_SEED + 1,
		"target_stage": 0,
		"time_scale": Engine.time_scale,
		"entrypoint": "scenes/Main.tscn",
	})
	_awaiting_opening_decision = true
	var failure_start: int = _failures.size()
	await _ensure_unit_select()
	await _select_starter("axiom")
	var loss_manager: Object = loss_combat_view.get("manager") as Object if loss_combat_view != null else null
	# Opening defeats intentionally receive recovery gold, so they cannot prove
	# the terminal loss overlay. Move this scoped fixture to the next real stage
	# before forcing the all-in defeat.
	GameState.set_chapter_and_stage(1, 2)
	if loss_manager != null and loss_manager.has_method("setup_stage_preview"):
		loss_manager.call("setup_stage_preview")
	_apply_controlled_loss_fixture(loss_manager)
	_set_bet_to_max()
	_set_planning_timer_safe()
	await _pace_delay(PACING_HUMAN_PLAN_DELAY_SECONDS)
	if loss_controller != null and is_instance_valid(loss_controller):
		loss_controller.set("auto_combat", true)
	await _press_continue(true, "loss retry forced opener")
	var loss_seen: bool = await _wait_for_loss_overlay(PACING_FIRST_FIGHT_TIMEOUT)
	if loss_seen:
		_recorder.mark("loss_overlay_visible")
		await _press_loss_new_game()
		await _settle_frames(8)
		if _node_visible("UnitSelect") and _unit_select_reset():
			_recorder.mark("retry_recovered")
		else:
			_expect(false, "loss retry New Game did not restore clean unit select")
	else:
		_expect(false, "controlled loss sample did not produce a loss overlay")
	var terminal: String = "loss_retry_recovered" if loss_seen and _node_visible("UnitSelect") else "loss_retry_failed"
	_recorder.finish(terminal)
	_loss_report = _recorder.build_report()
	_loss_report["run"] = _with_technical_failures(_loss_report.get("run", {}), failure_start)
	_recorder.stop()
	await _cleanup_between_starters()

func _apply_controlled_loss_fixture(loss_manager: Object) -> void:
	if loss_manager == null:
		_expect(false, "controlled loss manager missing")
		return
	var team_value: Variant = loss_manager.get("player_team")
	if not team_value is Array or (team_value as Array).is_empty():
		_expect(false, "controlled loss player team missing")
		return
	for unit_value: Variant in team_value as Array:
		if unit_value == null or not unit_value is Object:
			continue
		var unit: Object = unit_value as Object
		unit.set("max_hp", 1)
		unit.set("hp", 1)
		unit.set("attack_damage", 0.0)

func _select_starter(unit_id: String) -> void:
	var decision_delay: float = PACING_HUMAN_ACTION_DELAY_SECONDS
	if _awaiting_opening_decision:
		decision_delay = PACING_OPENING_DECISION_DELAY_SECONDS
		_awaiting_opening_decision = false
	await _pace_delay(decision_delay)
	await super._select_starter(unit_id)
	if _recorder != null:
		_recorder.mark("starter_selected", {"unit_id": unit_id})

func _reposition_first_board_unit(label: String) -> bool:
	var moved: bool = await super._reposition_first_board_unit(label)
	if moved and _recorder != null:
		_recorder.mark("planning_reposition", {"label": label})
	return moved

func _buy_best_two_stage_offer(buy_index: int) -> String:
	var shop_ready: bool = await _wait_for_shop_ready(5.0)
	if not shop_ready:
		_expect(false, "pacing shop did not become actionable before buy %d" % buy_index)
		return ""
	await _settle_frames(2)
	await _pace_delay(PACING_HUMAN_SHOP_DELAY_SECONDS)
	var bought_id: String = await super._buy_best_two_stage_offer(buy_index)
	if bought_id != "" and _recorder != null:
		_recorder.mark("shop_purchase_verified", {"unit_id": bought_id, "buy_index": buy_index})
	return bought_id

func _click_buy_xp(label: String) -> bool:
	await _pace_delay(PACING_HUMAN_ACTION_DELAY_SECONDS)
	return await super._click_buy_xp(label)

func _deploy_until_blocked() -> int:
	var had_bench: bool = not _bench_ids().is_empty()
	if had_bench:
		await _pace_delay(PACING_HUMAN_ACTION_DELAY_SECONDS)
	var deployed: int = await super._deploy_until_blocked()
	if deployed > 0 and _recorder != null:
		_recorder.mark("deployment", {"count": deployed})
	return deployed

func _field_best_available_units(label: String) -> int:
	if not _bench_ids().is_empty():
		await _pace_delay(PACING_HUMAN_ACTION_DELAY_SECONDS)
	var swaps: int = await super._field_best_available_units(label)
	if swaps > 0 and _recorder != null:
		_recorder.mark("planning_reposition", {"label": label, "count": swaps})
	return swaps

func _press_continue(expect_forced: bool, label: String) -> void:
	await _pace_delay(PACING_HUMAN_PLAN_DELAY_SECONDS)
	await super._press_continue(expect_forced, label)

func _flow_smoke_name() -> String:
	return PACING_SMOKE_NAME

func _flow_starter_id() -> String:
	return PACING_STARTER_ID

func _flow_shop_seed() -> int:
	return PACING_SHOP_SEED

func _flow_first_fight_timeout() -> float:
	return PACING_FIRST_FIGHT_TIMEOUT

func _flow_round_timeout() -> float:
	return PACING_ROUND_TIMEOUT

func _flow_max_battles() -> int:
	return PACING_MAX_BATTLES

func _flow_target_chapter() -> int:
	return PACING_TARGET_CHAPTER

func _flow_target_round() -> int:
	return PACING_TARGET_ROUND

func _flow_verbose_round_logs() -> bool:
	return false

func _with_technical_failures(run_value: Variant, failure_start: int) -> Dictionary[String, Variant]:
	var run: Dictionary[String, Variant] = {}
	if run_value is Dictionary:
		for key: Variant in (run_value as Dictionary).keys():
			run[String(key)] = (run_value as Dictionary)[key]
	var technical: Array[String] = _failures_since(failure_start)
	run["technical_failures"] = technical
	return run

func _pace_delay(seconds: float) -> void:
	if seconds <= 0.0:
		return
	await get_tree().create_timer(seconds).timeout

func _wait_for_shop_ready(timeout_seconds: float) -> bool:
	var deadline: int = Time.get_ticks_msec() + int(timeout_seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if Shop != null and Shop.state != null and Shop.state.offers.size() >= int(SHOP_CONFIG.SLOT_COUNT):
			return true
		await get_tree().process_frame
	return Shop != null and Shop.state != null and Shop.state.offers.size() >= int(SHOP_CONFIG.SLOT_COUNT)

func _write_outputs(suite: Dictionary[String, Variant], analysis: Dictionary[String, Variant]) -> void:
	var output_dir: String = ProjectSettings.globalize_path("user://pacing")
	DirAccess.make_dir_recursive_absolute(output_dir)
	var json_path: String = "user://pacing/longitudinal_pacing_suite.json"
	var markdown_path: String = "user://pacing/longitudinal_pacing_report.md"
	var json_file: FileAccess = FileAccess.open(json_path, FileAccess.WRITE)
	if json_file != null:
		json_file.store_string(JSON.stringify(suite, "\t"))
		json_file.close()
	var markdown_file: FileAccess = FileAccess.open(markdown_path, FileAccess.WRITE)
	if markdown_file != null:
		markdown_file.store_string(PacingMetrics.render_markdown(suite, analysis))
		markdown_file.close()
	print("%s: JSON=%s MARKDOWN=%s" % [PACING_SMOKE_NAME, json_path, markdown_path])

func _finish_pacing(_suite: Dictionary[String, Variant]) -> void:
	Engine.time_scale = _previous_time_scale
	UnitFactory.suppress_validation_warnings = _previous_suppress_validation_warnings
	_flush_synthetic_input()
	var technical_failures: Array[String] = _technical_failures()
	var pacing_verdict: String = String(_analysis.get("verdict", "FAIL"))
	var exit_code: int = 0
	if not technical_failures.is_empty():
		for failure: String in technical_failures:
			push_error("%s: %s" % [PACING_SMOKE_NAME, failure])
		exit_code = 1
	elif pacing_verdict != "PASS":
		print("%s: pacing verdict=%s failures=%s" % [PACING_SMOKE_NAME, pacing_verdict, JSON.stringify(_analysis.get("failures", []))])
		exit_code = 1
	else:
		print("%s: OK verdict=%s runs=%d" % [PACING_SMOKE_NAME, pacing_verdict, int(_analysis.get("run_count", 0))])
	print("%s: stages=%d campaign_highest=%d loss_retry=%s" % [
		PACING_SMOKE_NAME,
		_analysis_stage_count(),
		_analysis_highest_stage(),
		str(int(_analysis.get("run_count", 0)) > 1),
	])
	_cleanup_runtime()
	get_tree().process_frame.connect(_quit_after_cleanup.bind(exit_code, PACING_CLEANUP_FRAMES), CONNECT_ONE_SHOT)

func _analysis_stage_count() -> int:
	var runs_value: Variant = _analysis.get("runs", [])
	if not runs_value is Array or (runs_value as Array).is_empty():
		return 0
	var first: Variant = (runs_value as Array)[0]
	if not first is Dictionary:
		return 0
	return int((first as Dictionary).get("stage_count", 0))

func _analysis_highest_stage() -> int:
	var runs_value: Variant = _analysis.get("runs", [])
	if not runs_value is Array or (runs_value as Array).is_empty():
		return 0
	var first: Variant = (runs_value as Array)[0]
	if not first is Dictionary:
		return 0
	return int((first as Dictionary).get("highest_stage", 0))
