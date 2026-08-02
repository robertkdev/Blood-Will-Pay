extends "res://tests/visual/actual_run_loop_smoke.gd"

const SMOKE_NAME: String = "NaturalBuyXPVisualSmoke"
const OUTPUT_DIR: String = "res://outputs/visual_iter/natural_buy_xp_pass"
const STARTER_ID: String = "bonko"
const MIN_SAFE_BUY_XP_GOLD: int = 5
const EXPECTED_REWARD_FUNDED_GOLD: int = 6
const MAX_REWARD_FUNDED_ATTEMPTS: int = 1
const GUARANTEED_BUY_XP_GOLD_POOL: String = "res://tests/visual/fixtures/guaranteed_buy_xp_gold_pool.tres"
const OPENING_STAGE_CACHE_KEY: String = "1:1"

var _attempts_used: int = 0
var _success_stage_in_chapter: int = 0
var _success_gold_before: int = 0
var _success_gold_after: int = 0
var _finished: bool = false
var _saved_roster_runtime: Dictionary = {}
var _stage_one_reward_overridden: bool = false

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

	for attempt_index: int in range(1, MAX_REWARD_FUNDED_ATTEMPTS + 1):
		_attempts_used = attempt_index
		_start_attempt_scene()
		await _settle_frames(4)
		var succeeded: bool = await _run_natural_buy_xp_attempt(attempt_index)
		if succeeded or not _failures.is_empty():
			break
		_cleanup_runtime()
		await _settle_frames(4)

	if _success_gold_before < MIN_SAFE_BUY_XP_GOLD and _failures.is_empty():
		_expect(false, "reward-funded Buy XP path did not reach %d safe gold after deterministic opener reward" % MIN_SAFE_BUY_XP_GOLD)
	_finish_natural_buy_xp()

func _force_reward_funded_opening() -> void:
	if _stage_one_reward_overridden:
		return
	if not ResourceLoader.exists(GUARANTEED_BUY_XP_GOLD_POOL):
		_expect(false, "test reward pool missing: %s" % GUARANTEED_BUY_XP_GOLD_POOL)
		return
	_saved_roster_runtime = RunLoopRosterCatalog.snapshot_runtime()
	var opening_spec: Dictionary = RunLoopRosterCatalog.get_spec(1, 1)
	if opening_spec.is_empty():
		_expect(false, "chapter 1 stage 1 procedural roster spec missing")
		return
	var raw_rules: Variant = opening_spec.get(RunLoopStageTypes.KEY_RULES, {})
	var rules: Dictionary = (raw_rules.duplicate(true) if typeof(raw_rules) == TYPE_DICTIONARY else {})
	rules["rewards"] = {
		"pool_path": GUARANTEED_BUY_XP_GOLD_POOL,
		"rolls_per_kill": 1,
		"only_creeps": true,
		"source_team": "player",
		"max_triggers": 1,
	}
	opening_spec[RunLoopStageTypes.KEY_RULES] = rules
	RunLoopRosterCatalog._procedural_spec_cache[OPENING_STAGE_CACHE_KEY] = opening_spec.duplicate(true)
	_stage_one_reward_overridden = true

func _restore_reward_funded_opening() -> void:
	if not _stage_one_reward_overridden:
		return
	RunLoopRosterCatalog.restore_runtime(_saved_roster_runtime)
	_saved_roster_runtime.clear()
	_stage_one_reward_overridden = false

func _start_attempt_scene() -> void:
	_main = MAIN_SCENE.instantiate() as Control
	_main.set_anchors_preset(Control.PRESET_FULL_RECT)
	_main.offset_left = 0.0
	_main.offset_top = 0.0
	_main.offset_right = 0.0
	_main.offset_bottom = 0.0
	get_tree().root.add_child(_main)

func _run_natural_buy_xp_attempt(attempt_index: int) -> bool:
	await _ensure_unit_select()
	if not _failures.is_empty():
		return false
	_force_reward_funded_opening()
	if not _failures.is_empty():
		return false
	await _select_starter(STARTER_ID)
	_set_planning_timer_safe()
	await _settle_frames(4)
	_expect(_node_visible("CombatView"), "CombatView did not open for natural Buy XP smoke")
	if not _failures.is_empty():
		return false

	await _press_continue(true, "natural Buy XP forced opener")
	var shop_ready: bool = await _wait_for_shop_after_win(30.0)
	_expect(shop_ready, "natural Buy XP path did not reach the first shop")
	if not _failures.is_empty():
		return false
	_expect(int(Economy.gold) == EXPECTED_REWARD_FUNDED_GOLD, "reward-funded opener should reach exactly %d gold, got %d" % [EXPECTED_REWARD_FUNDED_GOLD, int(Economy.gold)])
	if int(Economy.gold) < MIN_SAFE_BUY_XP_GOLD:
		print("%s: attempt %d reached first shop with gold=%d; expected reward-funded safe-gold opener" % [SMOKE_NAME, attempt_index, int(Economy.gold)])
		return false
	return await _attempt_natural_buy_xp_success()

func _attempt_natural_buy_xp_success() -> bool:
	if int(Shop.get_level()) >= 2:
		return true
	if int(Economy.gold) < MIN_SAFE_BUY_XP_GOLD:
		return false
	var buy_xp: Button = _button_with_text_prefix("Buy XP")
	_expect(buy_xp != null, "Buy XP button missing at natural safe-gold moment")
	if buy_xp == null:
		return false
	_expect(not buy_xp.disabled, "Buy XP button disabled at natural safe-gold moment")
	if buy_xp.disabled:
		return false
	var before_gold: int = int(Economy.gold)
	var before_level: int = int(Shop.get_level())
	var before_stage: int = int(GameState.stage_in_chapter)
	_expect(before_gold >= MIN_SAFE_BUY_XP_GOLD, "natural Buy XP should start from safe gold, got %d" % before_gold)
	_normalize_capture_timer()
	await get_tree().process_frame
	_save_capture("01_natural_buy_xp_ready.png")

	var clicked: bool = await _click_button(buy_xp, "natural Buy XP")
	_expect(clicked, "natural Buy XP click did not fire")
	await _settle_frames(12)
	_normalize_capture_timer()
	await get_tree().process_frame
	_save_capture("02_natural_buy_xp_success.png")

	_success_stage_in_chapter = before_stage
	_success_gold_before = before_gold
	_success_gold_after = int(Economy.gold)
	_expect(int(Economy.gold) == before_gold - int(SHOP_CONFIG.BUY_XP_COST), "natural Buy XP should spend exactly %d gold" % int(SHOP_CONFIG.BUY_XP_COST))
	_expect(int(Shop.get_level()) == before_level + 1, "natural Buy XP should advance one shop level")
	_expect(int(Shop.get_level()) == 2, "natural Buy XP should reach level 2")
	_expect(int(Shop.get_xp()) == 2, "natural Buy XP should preserve 2 overflow XP at level 2")
	_expect(_progress_label_text() == "Lvl 2 (2/6)", "natural Buy XP should repaint progress to Lvl 2 (2/6), got %s" % _progress_label_text())
	return _failures.is_empty()

func _uses_manual_opening_continue() -> bool:
	return true

func _button_with_text_prefix(text: String) -> Button:
	if _main == null:
		return null
	var buttons: Array[Node] = _main.find_children("*", "Button", true, false)
	for node: Node in buttons:
		var button: Button = node as Button
		if button != null and String(button.text).begins_with(text):
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

func _normalize_capture_timer() -> void:
	var combat: Control = _main.get_node_or_null("CombatView") as Control
	if combat == null:
		return
	combat.set("planning_timer_total", 60.0)
	combat.set("planning_time_left", 60.0)
	var timer_label: Label = combat.get_node_or_null("MarginContainer/VBoxContainer/PlanningTimerLabel") as Label
	if timer_label != null:
		timer_label.text = "Planning: 1:00"

func _save_capture(filename: String) -> void:
	if _is_framebuffer_unavailable():
		print("%s: skipped %s because framebuffer capture is unavailable" % [SMOKE_NAME, filename])
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var texture: ViewportTexture = get_viewport().get_texture()
	if texture == null or not texture.get_rid().is_valid():
		push_error("%s: skipped %s; viewport texture unavailable" % [SMOKE_NAME, filename])
		return
	var image: Image = texture.get_image()
	if image == null or image.is_empty():
		push_error("%s: skipped %s; viewport image unavailable" % [SMOKE_NAME, filename])
		return
	var path: String = "%s/%s" % [OUTPUT_DIR, filename]
	var error: Error = image.save_png(path)
	if error != OK:
		push_error("%s: failed to save %s error=%s" % [SMOKE_NAME, ProjectSettings.globalize_path(path), str(int(error))])
		return
	print("%s: saved %s" % [SMOKE_NAME, ProjectSettings.globalize_path(path)])

func _is_framebuffer_unavailable() -> bool:
	var display_name: String = DisplayServer.get_name().to_lower()
	var driver_name: String = RenderingServer.get_current_rendering_driver_name().to_lower()
	return display_name == "headless" or display_name == "server" or display_name == "dummy" or driver_name.contains("dummy")

func _finish_natural_buy_xp() -> void:
	if _finished:
		return
	_finished = true
	Engine.time_scale = _previous_time_scale
	UnitFactory.suppress_validation_warnings = _previous_suppress_validation_warnings
	_restore_reward_funded_opening()
	_flush_synthetic_input()
	var exit_code: int = 0
	if _failures.is_empty():
		print("%s: OK attempts=%d stage=%d gold_before=%d gold_after=%d" % [SMOKE_NAME, _attempts_used, _success_stage_in_chapter, _success_gold_before, _success_gold_after])
	else:
		for failure: String in _failures:
			push_error(SMOKE_NAME + ": " + failure)
		exit_code = 1
	_cleanup_runtime()
	get_tree().process_frame.connect(_quit_after_cleanup.bind(exit_code, 10), CONNECT_ONE_SHOT)

func _finish() -> void:
	_finish_natural_buy_xp()
