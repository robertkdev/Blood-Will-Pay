extends "res://tests/visual/first_shop_choice_quality_smoke.gd"

const ChapterCatalog := preload("res://scripts/game/progression/chapter_catalog.gd")
const ProgressionConfig := preload("res://scripts/game/progression/progression_config.gd")
const RosterCatalog := preload("res://scripts/game/progression/roster_catalog.gd")
const StageTypes := preload("res://scripts/game/progression/stage_types.gd")

const SMOKE_TITLE: String = "ProceduralDefaultMainFlowSmoke"
const TEST_SEED: int = 730711
const STARTER_ID: String = "bonko"
const FIRST_CHAPTER: int = ProgressionConfig.PROCEDURAL_START_CHAPTER
const FIRST_ROUND: int = ProgressionConfig.CREEP_STAGE
const WATCHDOG_SECONDS: float = 80.0

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

	_start_main_scene()
	await _settle_frames(4)
	await _ensure_unit_select()
	RosterCatalog.set_procedural_seed(TEST_SEED)
	await _select_starter(STARTER_ID)
	await _settle_frames(4)
	_prepare_default_entry_state()
	await _settle_frames(6)
	_validate_default_preview()
	if _technical_failures().is_empty():
		await _play_first_procedural_round()
	_finish_procedural_entry()

func _prepare_default_entry_state() -> void:
	GameState.set_chapter_and_stage(FIRST_CHAPTER, FIRST_ROUND)
	GameState.set_phase(GameState.GamePhase.PREVIEW)
	var controller: Variant = _combat_controller()
	_expect(controller != null, "procedural default combat controller missing")
	if controller == null:
		return
	var manager: Variant = controller.get("manager")
	_expect(manager != null, "procedural default combat manager missing")
	if manager == null:
		return
	if manager.has_method("setup_stage_preview"):
		manager.setup_stage_preview()
	if controller.has_method("refresh_all_views"):
		controller.refresh_all_views()
	var button: Button = _main.find_child("ContinueButton", true, false) as Button
	if button != null:
		button.disabled = false
		button.visible = true

func _validate_default_preview() -> void:
	_expect(ChapterCatalog.display_name_for(FIRST_CHAPTER) == "Chapter 1", "chapter catalog should label the opening generated chapter Chapter 1")
	var chapter_label: Label = _main.find_child("ChapterLabel", true, false) as Label
	_expect(chapter_label != null, "procedural default chapter label missing")
	if chapter_label != null:
		_expect(String(chapter_label.text) == "Chapter 1", "procedural default chapter label expected Chapter 1 got %s" % chapter_label.text)
		_expect(String(chapter_label.tooltip_text).contains("Challenge:"), "procedural default chapter hover should preview challenges")
	var board_capacity_label: Label = _main.find_child("BoardCapacityLabel", true, false) as Label
	_expect(board_capacity_label != null, "procedural default board capacity label missing")
	if board_capacity_label != null:
		_expect(String(board_capacity_label.text).ends_with("/3"), "procedural default board capacity should start at x/3, got %s" % board_capacity_label.text)
	var win_odds_label: Label = _main.find_child("WinOddsLabel", true, false) as Label
	_expect(win_odds_label != null, "procedural default win odds label missing")
	if win_odds_label != null:
		_expect(String(win_odds_label.text).begins_with("Est. Win ") and String(win_odds_label.text).contains("-"), "procedural default odds label should show an estimated range, got %s" % win_odds_label.text)
	var spec: Dictionary = RosterCatalog.get_spec(FIRST_CHAPTER, FIRST_ROUND)
	var rules: Dictionary = spec.get(StageTypes.KEY_RULES, {})
	_expect(String(spec.get(StageTypes.KEY_KIND, "")) == StageTypes.KIND_CREEPS, "opening round should be generated creeps")
	_expect(bool(rules.get("procedural", false)), "opening preview spec should carry procedural marker")
	_expect(int(rules.get("target_rating", 0)) == int(ProgressionConfig.EASIEST_REFERENCE_RATING), "opening target rating should match easiest reference")
	_expect(int(rules.get("difficulty_rating", 0)) == int(ProgressionConfig.EASIEST_REFERENCE_RATING), "opening difficulty rating should match easiest reference")
	var controller: Variant = _combat_controller()
	var manager: Variant = controller.get("manager") if controller != null else null
	_expect(manager != null, "procedural default manager missing for preview validation")
	if manager != null:
		var preview_enemy_ids: Array[String] = _enemy_ids(manager)
		_expect(not preview_enemy_ids.is_empty(), "opening preview should show generated enemies")
		print("%s: preview chapter=%d round=%d enemy=%s spec=%s" % [SMOKE_TITLE, FIRST_CHAPTER, FIRST_ROUND, JSON.stringify(preview_enemy_ids), JSON.stringify(_spec_summary(spec))])

func _play_first_procedural_round() -> void:
	_set_planning_timer_safe()
	await _press_continue(true, "procedural default opening creep")
	var combat_seen: bool = await _wait_for_combat_active(3.0)
	if not combat_seen and int(GameState.chapter) == FIRST_CHAPTER and int(GameState.stage_in_chapter) >= ProgressionConfig.FIRST_RGA_STAGE:
		print("%s: opening combat resolved before combat-active poll" % SMOKE_TITLE)
		_validate_after_opening_round("pre-resolved")
		return
	_expect(combat_seen, "procedural default did not enter combat")
	if not combat_seen:
		return
	var resolved: bool = await _wait_for_preview_or_loss(WATCHDOG_SECONDS)
	var fight_result: String = _second_fight_result(resolved)
	_expect(resolved, "procedural default opening round did not resolve")
	_validate_after_opening_round(fight_result)

func _validate_after_opening_round(fight_result: String) -> void:
	_expect(fight_result == "shop" or fight_result == "pre-resolved", "procedural default should return to shop after opening creep win, got %s" % fight_result)
	_expect(int(GameState.chapter) == FIRST_CHAPTER, "procedural default should remain in Chapter 1 after round 1")
	_expect(int(GameState.stage_in_chapter) >= ProgressionConfig.FIRST_RGA_STAGE, "procedural default should advance to first RGA round, got round %d" % int(GameState.stage_in_chapter))
	var next_spec: Dictionary = RosterCatalog.get_spec(FIRST_CHAPTER, ProgressionConfig.FIRST_RGA_STAGE)
	var next_rules: Dictionary = next_spec.get(StageTypes.KEY_RULES, {})
	_expect(String(next_spec.get(StageTypes.KEY_KIND, "")) == StageTypes.KIND_NORMAL, "procedural default next round should be generated normal RGA")
	_expect(bool(next_rules.get("procedural", false)), "procedural default next round should carry procedural marker")
	_expect(next_rules.has("rga_challenge"), "procedural default next normal round should expose RGA metadata")
	print("%s: first_round_result=%s chapter=%d round=%d next_spec=%s" % [SMOKE_TITLE, fight_result, int(GameState.chapter), int(GameState.stage_in_chapter), JSON.stringify(_spec_summary(next_spec))])

func _spec_summary(spec: Dictionary) -> Dictionary:
	var rules: Dictionary = spec.get(StageTypes.KEY_RULES, {})
	return {
		"ids": spec.get(StageTypes.KEY_IDS, []),
		"kind": String(spec.get(StageTypes.KEY_KIND, "")),
		"procedural": bool(rules.get("procedural", false)),
		"target_rating": int(rules.get("target_rating", 0)),
		"difficulty_rating": int(rules.get("difficulty_rating", 0)),
		"theme": String(rules.get("theme", "")),
		"challenge": rules.get("rga_challenge", {}),
	}

func _enemy_ids(manager: Variant) -> Array[String]:
	var output: Array[String] = []
	if manager == null:
		return output
	for unit_value: Variant in manager.enemy_team:
		var unit: Unit = unit_value as Unit
		if unit != null:
			output.append(String(unit.id))
	return output

func _finish_procedural_entry() -> void:
	Engine.time_scale = _previous_time_scale
	UnitFactory.suppress_validation_warnings = _previous_suppress_validation_warnings
	_flush_synthetic_input()
	var exit_code: int = 0
	if _technical_failures().is_empty():
		print("%s: OK state=%s" % [SMOKE_TITLE, JSON.stringify({
			"chapter": int(GameState.chapter),
			"round": int(GameState.stage_in_chapter),
			"board": _board_ids(),
			"bench": _bench_ids(),
		})])
	else:
		for failure: String in _technical_failures():
			push_error("%s: %s" % [SMOKE_TITLE, failure])
		exit_code = 1
	_cleanup_runtime()
	await get_tree().create_timer(2.0, true, false, true).timeout
	get_tree().quit(exit_code)
