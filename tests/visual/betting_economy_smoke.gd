extends "res://tests/visual/actual_run_loop_smoke.gd"

const SMOKE_NAME: String = "BettingEconomySmoke"
const OUTPUT_DIR: String = "res://outputs/visual_iter/betting_economy_pass"
const UserSettingsScript: GDScript = preload("res://scripts/game/settings/user_settings.gd")
const BloodBuckets: GDScript = preload("res://scripts/game/economy/blood_buckets.gd")
const CombatControllerScript: GDScript = preload("res://scripts/ui/combat/controller/combat_controller.gd")
const RosterCatalog: GDScript = preload("res://scripts/game/progression/roster_catalog.gd")
const CLARITY_CAPTURE_SETTINGS_PATH: String = "user://phase5_clarity_capture_settings.cfg"

@export var viewport_size: Vector2i = Vector2i(1920, 1080)
@export_enum("none", "planning", "combat") var capture_hold_state: String = "none"
@export var capture_output_dir: String = OUTPUT_DIR
@export var capture_clarity_states: bool = false

func _run() -> void:
	DisplayServer.window_set_size(viewport_size)
	var window: Window = get_window()
	if window != null:
		window.size = viewport_size
		window.content_scale_size = viewport_size
	_previous_time_scale = Engine.time_scale
	_previous_suppress_validation_warnings = UnitFactory.suppress_validation_warnings
	UnitFactory.suppress_validation_warnings = true
	Engine.time_scale = 1.0
	if capture_clarity_states:
		await _capture_clarity_title_states()

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
	if capture_hold_state == "planning":
		Engine.time_scale = 1.0
		print("BettingEconomySmoke: CAPTURE_READY planning %dx%d" % [viewport_size.x, viewport_size.y])
		await get_tree().create_timer(90.0).timeout
		_finish()
		return

	await _start_and_verify_locked_max_bet()
	if capture_hold_state == "combat":
		Engine.time_scale = 1.0
		print("BettingEconomySmoke: CAPTURE_READY combat %dx%d" % [viewport_size.x, viewport_size.y])
		await get_tree().create_timer(90.0).timeout
	_finish()

func _capture_clarity_title_states() -> void:
	var window: Window = get_window()
	UserSettingsScript.configure_storage_path(CLARITY_CAPTURE_SETTINGS_PATH)
	UserSettingsScript.initialize(window)
	UserSettingsScript.set_ui_scale(1.0, window)
	UserSettingsScript.set_reduced_motion(true)

	var preview_main: Control = MAIN_SCENE.instantiate() as Control
	preview_main.set_anchors_preset(Control.PRESET_FULL_RECT)
	get_tree().root.add_child(preview_main)
	await _settle_frames(8)
	var enter_button: Button = preview_main.get_node_or_null("TitlePage/Center/Stack/EnterButton") as Button
	if enter_button != null:
		enter_button.pressed.emit()
	await _settle_frames(8)
	var title_menu: Control = preview_main.get_node_or_null("TitleMenu") as Control
	if title_menu != null:
		title_menu.call("_select_section", "how_to_play", true)
	await _settle_frames(8)
	_save_capture("00_tutorial.png")

	UserSettingsScript.set_ui_scale(1.5, window)
	UserSettingsScript.set_reduced_motion(true)
	if title_menu != null:
		title_menu.call_deferred("_refresh_scaled_layout")
	await _settle_frames(12)
	if title_menu != null:
		title_menu.call("_select_section", "settings", true)
	await _settle_frames(8)
	_save_capture("00_settings_150_percent.png")

	if preview_main.has_method("_reset_run_state"):
		preview_main.call("_reset_run_state")
	var preview_parent: Node = preview_main.get_parent()
	if preview_parent != null:
		preview_parent.remove_child(preview_main)
	preview_main.free()
	await _settle_frames(6)
	UserSettingsScript.set_ui_scale(1.0, window)
	UserSettingsScript.set_reduced_motion(false)

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
	var normal_quote: float = float(Economy.gross_payout_multiplier())
	Economy.set_projected_win_probability(0.10)
	_expect(is_equal_approx(float(Economy.gross_payout_multiplier()), normal_quote), "projected win estimate must not price a wager")
	Economy.set_projected_win_probability(0.99)
	_expect(is_equal_approx(float(Economy.gross_payout_multiplier()), normal_quote), "changing projected win estimate must leave the wager quote unchanged")
	Economy.set_encounter_quote_kind("CREEPS")
	_expect(is_equal_approx(float(Economy.gross_payout_multiplier()), 1.5), "Creeps should use the 1.5x encounter-tier wager quote")
	Economy.set_encounter_quote_kind("BOSS")
	_expect(is_equal_approx(float(Economy.gross_payout_multiplier()), 3.0), "Boss should use the 3.0x encounter-tier wager quote")
	Economy.set_encounter_quote_kind("NORMAL")
	_expect(is_equal_approx(float(Economy.gross_payout_multiplier()), normal_quote), "Normal should restore the 2.0x encounter-tier wager quote")
	Economy.set_encounter_quote_kind("ELITE")
	Economy.set_payout_modifier(1.25)
	var persisted_quote: float = float(Economy.gross_payout_multiplier())
	var economy_record: Dictionary = Economy.snapshot_run_record()
	Economy.set_encounter_quote_kind("NORMAL")
	Economy.set_payout_modifier(1.0)
	Economy.restore_run_record(economy_record)
	_expect(String(Economy.encounter_quote_kind) == "ELITE", "encounter quote kind should round-trip through an active-run record")
	_expect(is_equal_approx(float(Economy.payout_modifier), 1.25), "Pit payout modifier should round-trip through an active-run record")
	_expect(is_equal_approx(float(Economy.quoted_gross_multiplier), persisted_quote), "restored encounter and Pit modifiers should reproduce the exact wager quote")
	Economy.reset_run()
	_verify_stage_quote_capture_boundary()
	_expect(Economy.set_bet(starting_gold), "set_bet should accept an all-in starting-gold wager")
	Economy.start_combat()
	_expect(bool(Economy.combat_active), "start_combat should mark combat active")
	_expect(int(Economy.gold) == 0, "all-in escrow should leave 0 gold")
	_expect(int(Economy.combat_credit_base) == max(0, 2 * starting_gold - 1), "all-in wager should expose expected combat credit")
	_expect(int(Economy.last_gold_start) == starting_gold, "start_combat should capture starting gold")
	_expect(int(Economy.last_bet_start) == starting_gold, "start_combat should capture starting bet")
	var locked_bet: int = int(Economy.current_bet)
	var locked_quote: float = float(Economy.get("_locked_gross_multiplier"))
	Economy.set_encounter_quote_kind("BOSS")
	_expect(is_equal_approx(float(Economy.get("_locked_gross_multiplier")), locked_quote), "combat must retain its exact locked encounter-tier quote")
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
	_expect(int(Economy.gold) == 0, "starting-reserve all-in loss should leave 0 gold")
	_expect(int(Economy.current_bet) == 0, "resolve should clear current_bet after loss")
	Economy.reset_run()

func _verify_stage_quote_capture_boundary() -> void:
	if get_tree().root.get_node_or_null("/root/GameState") == null:
		_expect(false, "GameState autoload missing for quote-capture boundary")
		return
	var original_chapter: int = int(GameState.chapter)
	var original_stage: int = int(GameState.stage_in_chapter)
	var controller: CombatController = CombatControllerScript.new() as CombatController
	for stage_index: int in [1, 5]:
		GameState.chapter = 1
		GameState.stage_in_chapter = stage_index
		var stage_spec: Dictionary = RosterCatalog.get_spec(1, stage_index)
		var expected_kind: String = String(stage_spec.get("kind", "NORMAL"))
		Economy.set_encounter_quote_kind("CREEPS" if expected_kind != "CREEPS" else "BOSS")
		var captured_quote: float = float(controller.call("_capture_current_encounter_quote_multiplier"))
		var expected_quote: float = float(Economy.encounter_quote_multiplier(expected_kind))
		_expect(is_equal_approx(captured_quote, expected_quote), "battle-start quote capture did not resolve stage %d kind %s (expected %.2f, got %.2f)" % [stage_index, expected_kind, expected_quote, captured_quote])
	GameState.chapter = original_chapter
	GameState.stage_in_chapter = original_stage
	Economy.set_encounter_quote_kind("NORMAL")

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
	var all_in_button: Button = _main.find_child("AllInButton", true, false) as Button if _main != null else null
	var wager_summary: Label = _main.find_child("WagerSummary", true, false) as Label if _main != null else null
	_expect(slider != null, "post-shop BetSlider missing")
	_expect(value_label != null, "post-shop BetValue missing")
	_expect(label != null, "post-shop BetLabel missing")
	_expect(all_in_button != null, "post-shop All In button missing")
	_expect(wager_summary != null, "post-shop wager summary missing")
	if slider == null or value_label == null:
		return
	var gold: int = int(Economy.gold)
	_expect(gold > 1, "post-opener gold should allow a meaningful bet, got %d" % gold)
	_expect(slider.visible, "post-shop bet slider should be visible")
	_expect(slider.editable, "post-shop bet slider should be editable")
	_expect(slider.get_theme_stylebox("slider") is StyleBoxTexture, "post-shop wager rail should use the generated track asset")
	_expect(slider.get_theme_stylebox("grabber_area") is StyleBoxTexture, "post-shop wager fill should use the generated fill asset")
	_expect(slider.get_theme_icon("grabber") != null, "post-shop wager should use the generated grabber asset")
	_expect(slider.get_theme_icon("grabber_highlight") != null, "post-shop wager should expose a distinct hover grabber")
	_expect(slider.get_theme_icon("grabber_disabled") != null, "post-shop wager should expose a disabled grabber")
	var authored_rail: TextureRect = slider.get_node_or_null("HardcoreWagerRail") as TextureRect
	_expect(authored_rail != null and authored_rail.visible and authored_rail.texture != null, "post-shop wager should render its authored rail behind the grabber")
	_expect(label == null or label.visible, "post-shop Bet label should be visible")
	_expect(int(slider.min_value) == 1, "post-shop bet slider min should be 1")
	_expect(int(slider.max_value) == gold, "post-shop bet slider max should equal current gold")
	_expect(is_equal_approx(slider.step, 1.0), "post-shop bet slider should move in whole-gold steps")
	var max_bet: int = int(slider.max_value)
	if all_in_button != null:
		all_in_button.emit_signal("pressed")
	await _settle_frames(12)
	_expect(int(slider.value) == max_bet, "All In should select the maximum wager")
	_expect(int(Economy.current_bet) == max_bet, "max-bet slider should update Economy.current_bet")
	_expect(int(Economy.preferred_bet) == max_bet, "max-bet slider should update Economy.preferred_bet")
	_expect(String(value_label.text) == BloodBuckets.format_amount(max_bet), "max-bet slider should repaint BetValue to bucket copy %s, got %s" % [BloodBuckets.format_amount(max_bet), String(value_label.text)])
	if all_in_button != null:
		var armed_style: StyleBoxTexture = all_in_button.get_theme_stylebox("normal") as StyleBoxTexture
		_expect(String(all_in_button.text) == "ALL IN!", "armed all-in control should switch to emphatic action copy")
		_expect(armed_style != null and armed_style.texture != null and String(armed_style.texture.resource_path).ends_with("button_wager_selected.png"), "armed all-in control should use the authored selected wager state")
	if wager_summary != null:
		var summary_copy: String = String(wager_summary.text)
		_expect(summary_copy.begins_with("DECISION //"), "wager summary should identify the planning decision: %s" % summary_copy)
		_expect(summary_copy.contains("ALL IN") and summary_copy.contains("RISK " + BloodBuckets.format_amount(max_bet)), "all-in summary should expose its armed wager: %s" % summary_copy)
		_expect(summary_copy.contains("EST. WIN ") and summary_copy.contains("-") and summary_copy.contains("WIN RESERVE ") and summary_copy.contains("LOSS RESERVE "), "wager summary should show an estimated range and both reserve outcomes: %s" % summary_copy)
	var bottom_storage: Control = _main.find_child("BottomStorageArea", true, false) as Control if _main != null else null
	var shop_grid: GridContainer = _main.find_child("ShopGrid", true, false) as GridContainer if _main != null else null
	_expect_control_inside_viewport(bottom_storage, "post-shop footer")
	_expect_control_inside_viewport(shop_grid, "post-shop grid")
	if shop_grid != null:
		for child: Node in shop_grid.get_children():
			var card: Control = child as Control
			if card != null and card.visible:
				_expect_control_inside_viewport(card, "post-shop card %s" % String(card.name))
	_save_capture("02_post_shop_max_bet_selected.png")

func _expect_control_inside_viewport(control: Control, label: String) -> void:
	_expect(control != null, "%s missing" % label)
	if control == null:
		return
	var rect: Rect2 = control.get_global_rect()
	var viewport_rect: Rect2 = get_viewport().get_visible_rect()
	_expect(rect.position.x >= viewport_rect.position.x - 1.0, "%s left edge escaped viewport: %s" % [label, str(rect)])
	_expect(rect.position.y >= viewport_rect.position.y - 1.0, "%s top edge escaped viewport: %s" % [label, str(rect)])
	_expect(rect.end.x <= viewport_rect.end.x + 1.0, "%s right edge escaped viewport: %s" % [label, str(rect)])
	_expect(rect.end.y <= viewport_rect.end.y + 1.0, "%s bottom edge escaped viewport: %s viewport=%s" % [label, str(rect), str(viewport_rect)])

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
	var combat_started: bool = await _wait_for_combat_active(10.0)
	_expect(combat_started, "max-bet Start Battle should reach combat before locked-wager verification")
	await _settle_frames(4)
	_save_capture("03_combat_bet_locked.png")
	_expect(int(GameState.phase) == int(GameState.GamePhase.COMBAT), "max-bet Start Battle should enter combat phase")
	_expect(bool(Economy.combat_active), "max-bet Start Battle should mark Economy combat active")
	_expect(int(Economy.current_bet) == selected_bet, "combat should preserve selected bet")
	_expect(int(Economy.gold) == max(0, starting_gold - selected_bet), "combat should escrow selected bet")
	_expect(int(Economy.last_gold_start) == starting_gold, "combat should capture pre-escrow gold")
	_expect(int(Economy.last_bet_start) == selected_bet, "combat should capture selected bet")
	_expect(int(Economy.combat_credit_base) == expected_credit, "combat credit base should derive from the locked odds quote expected=%d actual=%d locked=%.4f current=%.4f" % [expected_credit, int(Economy.combat_credit_base), float(Economy.get("_locked_gross_multiplier")), float(Economy.quoted_gross_multiplier)])
	_expect(not slider.visible, "bet slider should hide while combat is active")
	_expect(not slider.editable, "bet slider should lock while combat is active")
	_expect(String(value_label.text) == "Wager: %s (locked)" % BloodBuckets.format_amount(selected_bet), "combat should show locked bucket copy, got %s" % String(value_label.text))
	var wager_summary: Label = _main.find_child("WagerSummary", true, false) as Label if _main != null else null
	_expect(wager_summary != null and String(wager_summary.text).to_upper().contains("LOCKED"), "combat should show visibly locked wager summary")
	var ignored_ok: bool = Economy.set_bet(1)
	_expect(ignored_ok, "set_bet during Main-scene combat should report existing positive wager")
	_expect(int(Economy.current_bet) == selected_bet, "set_bet during Main-scene combat should not change wager")
	slider.value = 1
	await _settle_frames(2)
	_expect(int(Economy.current_bet) == selected_bet, "hidden combat slider changes should not alter wager")
	_expect(String(value_label.text) == "Wager: %s (locked)" % BloodBuckets.format_amount(selected_bet), "hidden combat slider changes should not repaint locked bucket copy")

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
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(capture_output_dir))
	var texture: ViewportTexture = get_viewport().get_texture()
	if texture == null or not texture.get_rid().is_valid():
		push_error("%s: skipped %s; viewport texture unavailable" % [SMOKE_NAME, filename])
		return
	var image: Image = texture.get_image()
	if image == null or image.is_empty():
		push_error("%s: skipped %s; viewport image unavailable" % [SMOKE_NAME, filename])
		return
	var path: String = "%s/%s" % [capture_output_dir, filename]
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
	await get_tree().create_timer(2.0, true, false, true).timeout
	get_tree().quit(exit_code)
