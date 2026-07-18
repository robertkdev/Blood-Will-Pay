extends "res://tests/visual/actual_run_loop_smoke.gd"

const SMOKE_NAME: String = "BettingEconomySmoke"
const OUTPUT_DIR: String = "res://outputs/visual_iter/betting_economy_pass"

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

	_verify_direct_economy_contract()
	if _finish_if_failed():
		return

	_prepare_fresh_run()
	_main = MAIN_SCENE.instantiate() as Control
	_main.set_anchors_preset(Control.PRESET_FULL_RECT)
	_main.offset_left = 0.0
	_main.offset_top = 0.0
	_main.offset_right = 0.0
	_main.offset_bottom = 0.0
	get_tree().root.add_child(_main)
	await _settle_frames(4)

	await _ensure_unit_select()
	if _finish_if_failed():
		return
	await _select_starter("bonko")
	if _finish_if_failed():
		return
	var combat_opened: bool = await _wait_for_combat_view_visible(20.0)
	_expect(combat_opened, "CombatView did not open after selecting Bonko")
	_set_planning_timer_safe()
	var repositioned: bool = await _reposition_first_board_unit("betting smoke board reposition") if combat_opened else false
	_expect(repositioned, "starter board unit did not reposition before betting smoke opener")
	if _finish_if_failed():
		return
	_expect(_first_fight_placeholder_visible(), "forced opener placeholder missing before betting smoke")
	await _press_continue(true, "betting smoke forced opener")
	Engine.time_scale = 8.0
	var shop_ready: bool = await _wait_for_shop_after_win(30.0)
	_expect(shop_ready, "betting smoke did not reach post-opener shop")
	if _finish_if_failed():
		return

	await _settle_frames(4)
	_save_capture("01_post_shop_bet_slider_visible.png")
	await _verify_post_shop_bet_controls()
	if _finish_if_failed():
		return

	await _start_and_verify_locked_max_bet()
	_finish()

func _uses_manual_opening_continue() -> bool:
	return true

func _verify_direct_economy_contract() -> void:
	if get_tree().root.get_node_or_null("/root/Economy") == null:
		_expect(false, "Economy autoload missing")
		return
	Economy.reset_run()
	var starting_gold: int = int(Economy.STARTING_GOLD)
	_expect(int(Economy.gold) == starting_gold, "reset_run should start with configured starting gold")
	_expect(int(Economy.current_bet) == 1, "reset_run should start with bet 1")
	_expect(Economy.set_bet(starting_gold), "set_bet should accept an all-in starting-gold wager")
	Economy.start_combat()
	_expect(bool(Economy.combat_active), "start_combat should mark combat active")
	_expect(int(Economy.gold) == 0, "all-in escrow should leave 0 gold")
	_expect(int(Economy.combat_credit_base) == max(0, 2 * starting_gold - 1), "all-in wager should expose expected combat credit")
	_expect(int(Economy.last_gold_start) == starting_gold, "start_combat should capture starting gold")
	_expect(int(Economy.last_bet_start) == starting_gold, "start_combat should capture starting bet")
	var locked_bet: int = int(Economy.current_bet)
	var ignored_ok: bool = Economy.set_bet(1)
	_expect(ignored_ok, "set_bet during combat should still report an active positive wager")
	_expect(int(Economy.current_bet) == locked_bet, "set_bet during combat should not change current_bet")
	Economy.resolve(true)
	_expect(not bool(Economy.combat_active), "resolve win should clear combat_active")
	_expect(int(Economy.gold) == starting_gold * 2, "all-in win should pay out to double the wager")
	_expect(int(Economy.preferred_bet) == starting_gold * 2, "all-in win should remember next full-gold preferred bet")
	_expect(int(Economy.current_bet) == 0, "resolve should clear current_bet after win")

	Economy.reset_run()
	_expect(Economy.set_bet(starting_gold), "set_bet should accept second all-in wager")
	Economy.start_combat()
	Economy.resolve(false)
	_expect(not bool(Economy.combat_active), "resolve loss should clear combat_active")
	_expect(int(Economy.gold) == 0, "2-gold all-in loss should leave 0 gold")
	_expect(int(Economy.current_bet) == 0, "resolve should clear current_bet after loss")
	Economy.reset_run()

func _prepare_fresh_run() -> void:
	if get_tree().root.get_node_or_null("/root/Economy") != null:
		Economy.reset_run()
	if get_tree().root.get_node_or_null("/root/Shop") != null:
		Shop.reset_run()
	if get_tree().root.get_node_or_null("/root/Roster") != null and Roster.has_method("reset"):
		Roster.reset()
	if get_tree().root.get_node_or_null("/root/Items") != null and Items.has_method("reset_run"):
		Items.reset_run()
	if get_tree().root.get_node_or_null("/root/GameState") != null and GameState.has_method("reset_run"):
		GameState.reset_run()

func _verify_post_shop_bet_controls() -> void:
	var slider: HSlider = _bet_slider()
	var value_label: Label = _bet_value_label()
	var label: Label = _bet_static_label()
	_expect(slider != null, "post-shop BetSlider missing")
	_expect(value_label != null, "post-shop BetValue missing")
	_expect(label != null, "post-shop BetLabel missing")
	if slider == null or value_label == null:
		return
	var gold: int = int(Economy.gold)
	_expect(gold > 1, "post-opener gold should allow a meaningful bet, got %d" % gold)
	_expect(slider.visible, "post-shop bet slider should be visible")
	_expect(slider.editable, "post-shop bet slider should be editable")
	_expect(label == null or label.visible, "post-shop Bet label should be visible")
	_expect(int(slider.min_value) == 1, "post-shop bet slider min should be 1")
	_expect(int(slider.max_value) == gold, "post-shop bet slider max should equal current gold")
	var max_bet: int = int(slider.max_value)
	slider.value = max_bet
	await _settle_frames(3)
	_expect(int(Economy.current_bet) == max_bet, "max-bet slider should update Economy.current_bet")
	_expect(int(Economy.preferred_bet) == max_bet, "max-bet slider should update Economy.preferred_bet")
	_expect(String(value_label.text) == str(max_bet), "max-bet slider should repaint BetValue to %d, got %s" % [max_bet, String(value_label.text)])
	_save_capture("02_post_shop_max_bet_selected.png")

func _start_and_verify_locked_max_bet() -> void:
	var slider: HSlider = _bet_slider()
	var value_label: Label = _bet_value_label()
	if slider == null or value_label == null:
		_expect(false, "bet controls missing before locked-bet verification")
		return
	var selected_bet: int = int(Economy.current_bet)
	var starting_gold: int = int(Economy.gold)
	var expected_credit: int = max(0, int(Economy.quoted_payout(selected_bet)) - 1)
	_expect(selected_bet == int(slider.max_value), "selected bet should still be max before combat")
	await _press_continue(false, "betting smoke max-bet fight")
	await _settle_frames(4)
	_save_capture("03_combat_bet_locked.png")
	_expect(int(GameState.phase) == int(GameState.GamePhase.COMBAT), "max-bet Start Battle should enter combat phase")
	_expect(bool(Economy.combat_active), "max-bet Start Battle should mark Economy combat active")
	_expect(int(Economy.current_bet) == selected_bet, "combat should preserve selected bet")
	_expect(int(Economy.gold) == max(0, starting_gold - selected_bet), "combat should escrow selected bet")
	_expect(int(Economy.last_gold_start) == starting_gold, "combat should capture pre-escrow gold")
	_expect(int(Economy.last_bet_start) == selected_bet, "combat should capture selected bet")
	_expect(int(Economy.combat_credit_base) == expected_credit, "combat credit base should derive from the locked odds quote")
	_expect(not slider.visible, "bet slider should hide while combat is active")
	_expect(not slider.editable, "bet slider should lock while combat is active")
	_expect(String(value_label.text) == "Bet: %d (locked)" % selected_bet, "combat should show locked bet copy, got %s" % String(value_label.text))
	var ignored_ok: bool = Economy.set_bet(1)
	_expect(ignored_ok, "set_bet during Main-scene combat should report existing positive wager")
	_expect(int(Economy.current_bet) == selected_bet, "set_bet during Main-scene combat should not change wager")
	slider.value = 1
	await _settle_frames(2)
	_expect(int(Economy.current_bet) == selected_bet, "hidden combat slider changes should not alter wager")
	_expect(String(value_label.text) == "Bet: %d (locked)" % selected_bet, "hidden combat slider changes should not repaint locked copy")

func _bet_slider() -> HSlider:
	return _main.find_child("BetSlider", true, false) as HSlider if _main != null else null

func _bet_value_label() -> Label:
	return _main.find_child("BetValue", true, false) as Label if _main != null else null

func _bet_static_label() -> Label:
	return _main.find_child("BetLabel", true, false) as Label if _main != null else null

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

func _finish() -> void:
	Engine.time_scale = _previous_time_scale
	UnitFactory.suppress_validation_warnings = _previous_suppress_validation_warnings
	_restore_actual_opening_entry()
	_flush_synthetic_input()
	var exit_code: int = 0
	if _failures.is_empty():
		print(SMOKE_NAME + ": OK")
	else:
		for failure: String in _failures:
			push_error(SMOKE_NAME + ": " + failure)
		exit_code = 1
	_cleanup_runtime()
	get_tree().process_frame.connect(_quit_after_cleanup.bind(exit_code, 10), CONNECT_ONE_SHOT)
