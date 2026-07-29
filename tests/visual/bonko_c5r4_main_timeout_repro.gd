extends "res://tests/visual/first_shop_choice_quality_smoke.gd"

const REPRO_NAME: String = "BonkoC5R4MainTimeoutRepro"
const PLAYER_IDS: Array[String] = ["bonko", "kythera", "volt", "nyxa", "luna", "teller", "hexeon", "veyra", "paisley"]
const BENCH_IDS: Array[String] = ["berebell", "mortem", "mara", "sari", "morrak", "korath", "vykos"]
const CHAPTER: int = 5
const ROUND_IN_CHAPTER: int = 4
const SHOP_SETUP_GOLD: int = 8
const GOLD_AFTER_SHOP: int = 3
const SHOP_LEVEL: int = 3
const TEAM_CAP: int = 9
const WATCHDOG_REAL_SECONDS: float = 120.0

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
	await _select_starter("bonko")
	await _settle_frames(4)
	_force_repro_state()
	await _settle_frames(6)
	print("%s: forced_state=%s" % [REPRO_NAME, JSON.stringify(_diagnostic_state())])
	_set_planning_timer_safe()
	await _press_continue(false, "Bonko C5R4 timeout repro")
	var combat_seen: bool = await _wait_for_combat_active(3.0)
	_expect(combat_seen, "Bonko C5R4 repro did not enter combat; state=%s" % JSON.stringify(_diagnostic_state()))
	if combat_seen:
		var resolved: bool = await _wait_for_preview_or_loss(WATCHDOG_REAL_SECONDS)
		if not resolved:
			_expect(false, "Bonko C5R4 repro stalled past %.1fs; state=%s" % [WATCHDOG_REAL_SECONDS, JSON.stringify(_diagnostic_state())])
		else:
			print("%s: resolved_state=%s" % [REPRO_NAME, JSON.stringify(_diagnostic_state())])
	_finish_repro()

func _force_repro_state() -> void:
	GameState.set_chapter_and_stage(CHAPTER, ROUND_IN_CHAPTER)
	GameState.set_phase(GameState.GamePhase.PREVIEW)
	if Economy != null:
		Economy.reset_run()
		Economy.gold = SHOP_SETUP_GOLD
		Economy.current_bet = 1
		Economy.preferred_bet = 1
		Economy.combat_active = false
		Economy.gold_changed.emit(Economy.gold)
		Economy.bet_changed.emit(Economy.current_bet)
	if Shop != null:
		Shop.reset_run()
		for _i: int in range(max(0, SHOP_LEVEL - 1)):
			Shop.buy_xp()
	if Economy != null:
		Economy.gold = GOLD_AFTER_SHOP
		Economy.gold_changed.emit(Economy.gold)
	if Roster != null:
		Roster.reset(true)
		Roster.set_max_team_size(TEAM_CAP)
	var controller: Variant = _combat_controller()
	_expect(controller != null, "Bonko C5R4 repro combat controller missing")
	if controller == null:
		return
	var manager: Variant = controller.get("manager")
	_expect(manager != null, "Bonko C5R4 repro combat manager missing")
	if manager == null:
		return
	manager.player_team.clear()
	for unit_id: String in PLAYER_IDS:
		var unit: Unit = UnitFactory.spawn(unit_id)
		_expect(unit != null, "Bonko C5R4 repro failed to spawn player unit %s" % unit_id)
		if unit != null:
			manager.player_team.append(unit)
	for bench_index: int in range(BENCH_IDS.size()):
		var bench_unit: Unit = UnitFactory.spawn(BENCH_IDS[bench_index])
		_expect(bench_unit != null, "Bonko C5R4 repro failed to spawn bench unit %s" % BENCH_IDS[bench_index])
		if bench_unit != null:
			Roster.set_slot(bench_index, bench_unit)
	if manager.has_method("setup_stage_preview"):
		manager.setup_stage_preview()
	if controller.has_method("refresh_all_views"):
		controller.refresh_all_views()
	var button: Button = _main.find_child("ContinueButton", true, false) as Button
	if button != null:
		button.text = "Start Battle"
		button.disabled = false

func _diagnostic_state() -> Dictionary:
	var controller: Variant = _combat_controller()
	var manager: Variant = controller.get("manager") if controller != null else null
	var engine: Variant = manager.get_engine() if manager != null and manager.has_method("get_engine") else null
	var state: Variant = engine.get("state") if engine != null else null
	return {
		"chapter": int(GameState.chapter) if GameState != null else -1,
		"round": int(GameState.stage_in_chapter) if GameState != null else -1,
		"phase": int(GameState.phase) if GameState != null else -1,
		"economy_combat_active": bool(Economy.combat_active) if Economy != null else false,
		"gold": int(Economy.gold) if Economy != null else -1,
		"board": _board_ids(),
		"bench": _bench_ids(),
		"enemy": _enemy_ids(manager),
		"engine_elapsed": float(state.elapsed_time) if state != null else -1.0,
		"engine_battle_active": bool(state.battle_active) if state != null else false,
		"engine_time_scale": float(Engine.time_scale),
		"tree_paused": bool(get_tree().paused),
		"combat_timeout_s": float(engine.get("combat_timeout_s")) if engine != null else -1.0,
		"no_progress_timeout_s": float(engine.get("no_progress_timeout_s")) if engine != null else -1.0,
		"engine_player_alive": _alive_ids(manager.player_team if manager != null else []),
		"engine_enemy_alive": _alive_ids(manager.enemy_team if manager != null else []),
		"engine_total_player_damage": int(engine.get("total_damage_player")) if engine != null else -1,
		"engine_total_enemy_damage": int(engine.get("total_damage_enemy")) if engine != null else -1,
	}

func _enemy_ids(manager: Variant) -> Array[String]:
	var output: Array[String] = []
	if manager == null:
		return output
	for unit_variant: Variant in manager.enemy_team:
		var unit: Unit = unit_variant as Unit
		output.append(_unit_id(unit))
	return output

func _alive_ids(units: Array) -> Array[String]:
	var output: Array[String] = []
	for unit_variant: Variant in units:
		var unit: Unit = unit_variant as Unit
		if unit != null and unit.is_alive():
			output.append("%s:%d/%d" % [_unit_id(unit), int(unit.hp), int(unit.max_hp)])
	return output

func _finish_repro() -> void:
	Engine.time_scale = _previous_time_scale
	UnitFactory.suppress_validation_warnings = _previous_suppress_validation_warnings
	_flush_synthetic_input()
	var exit_code: int = 0
	if _technical_failures().is_empty():
		print("%s: OK" % REPRO_NAME)
	else:
		for failure: String in _technical_failures():
			push_error("%s: %s" % [REPRO_NAME, failure])
		exit_code = 1
	_cleanup_runtime()
	get_tree().process_frame.connect(_quit_after_cleanup.bind(exit_code, 10), CONNECT_ONE_SHOT)
