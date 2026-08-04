extends "res://tests/visual/actual_run_loop_smoke.gd"

const VisionSnapshot := preload("res://scripts/util/vision_snapshot.gd")
const SMOKE_NAME: String = "PostCombatPlanningBeatSmoke"
const OUTPUT_DIR: String = "res://outputs/visual_iter/post_combat_planning_beat_pass"
const MIN_RESTORED_PLANNING_SECONDS: float = 55.0

var _saved_captures: int = 0

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
	_expect(combat_opened, "combat view did not open for Bonko")
	if not combat_opened:
		_finish()
		return
	var opener_started: bool = await _wait_for_combat_active(5.0)
	_expect(opener_started, "opening fight did not start immediately after starter select")
	_expect(not _bottom_planning_visible(), "bottom planning/shop area stayed visible during the opening fight")
	if _finish_if_failed():
		return

	var intermission_seen: bool = await _wait_for_intermission_bar(24.0)
	_expect(intermission_seen, "post-combat intermission bar did not appear before planning returned")
	if _finish_if_failed():
		return
	await _settle_frames(2)
	_assert_result_card()
	_assert_shared_result_variants()
	if _finish_if_failed():
		return
	_save_capture("01_post_win_intermission_bar.png")

	var restored: bool = await _wait_for_post_win_planning(8.0)
	_expect(restored, "post-win planning did not restore after intermission")
	if _finish_if_failed():
		return

	_expect(int(GameState.stage_in_chapter) >= 2, "post-win planning did not advance to the next stage")
	_expect(not Economy.combat_active, "economy still marked combat active after post-win planning restored")
	_expect(Shop.state != null and Shop.state.offers.size() == int(SHOP_CONFIG.SLOT_COUNT), "post-win planning did not restore a full shop")
	_expect(_continue_button_text() == "Start Battle", "post-win planning did not restore Start Battle, got %s" % _continue_button_text())
	_expect(not _continue_button_disabled(), "post-win Start Battle button stayed disabled")
	_expect(_planning_time_left() >= MIN_RESTORED_PLANNING_SECONDS, "post-win planning timer was not reset; got %.2f" % _planning_time_left())
	_normalize_restored_planning_capture_timer()
	await get_tree().process_frame
	_save_capture("02_post_win_planning_restored.png")
	await _settle_frames(12)
	_expect(GameState.phase == GameState.GamePhase.PREVIEW, "post-win planning did not remain in PREVIEW for the first beat")
	_expect(_continue_button_text() == "Start Battle", "post-win planning button changed during the first beat")
	_finish()

func _wait_for_intermission_bar(timeout_seconds: float) -> bool:
	var deadline: int = Time.get_ticks_msec() + int(timeout_seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		if get_tree().root.get_node_or_null("LossOverlayLayer") != null:
			return false
		if _intermission_bar_visible():
			_expect(GameState.phase != GameState.GamePhase.PREVIEW, "planning returned before the intermission beat was visible")
			return true
		if GameState.phase == GameState.GamePhase.PREVIEW and int(GameState.stage_in_chapter) >= 2:
			return false
	return false

func _wait_for_post_win_planning(timeout_seconds: float) -> bool:
	var deadline: int = Time.get_ticks_msec() + int(timeout_seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		if get_tree().root.get_node_or_null("LossOverlayLayer") != null:
			return false
		if GameState.phase == GameState.GamePhase.PREVIEW and int(GameState.stage_in_chapter) >= 2:
			return true
	return false

func _intermission_bar_visible() -> bool:
	var bar: ProgressBar = _main.find_child("GothicIntermissionBar", true, false) as ProgressBar
	return bar != null and bar.visible

func _assert_result_card() -> void:
	var banner: PanelContainer = _main.find_child("BattleResultBanner", true, false) as PanelContainer
	_expect(banner != null and banner.visible, "post-win battle result overlay was not visible during intermission")
	if banner == null:
		return
	var card: PanelContainer = banner.get_node_or_null("Center/BattleResultCard") as PanelContainer
	_expect(card != null and card.visible, "post-win battle result card was missing")
	if card == null:
		return
	var title_label: Label = card.get_node_or_null("CardMargin/Content/OutcomeLabel") as Label
	var detail_label: Label = card.get_node_or_null("CardMargin/Content/DetailLabel") as Label
	var kicker_label: Label = card.get_node_or_null("CardMargin/Content/KickerLabel") as Label
	_expect(title_label != null and title_label.text == "VICTORY", "post-win result title should read VICTORY")
	_expect(detail_label != null and detail_label.text.contains("Preparing"), "post-win result detail should explain the transition")
	_expect(kicker_label != null and kicker_label.text == "BATTLE OUTCOME", "post-win result card should include its outcome context")
	var card_rect: Rect2 = card.get_global_rect()
	var viewport: Viewport = get_viewport()
	var viewport_size: Vector2 = viewport.get_visible_rect().size if viewport != null else Vector2.ZERO
	_expect(card_rect.size.x >= 500.0 and card_rect.size.x <= 640.0, "result card width should stay restrained, got %.1f" % card_rect.size.x)
	_expect(card_rect.size.y >= 150.0 and card_rect.size.y <= 230.0, "result card height should stay restrained, got %.1f" % card_rect.size.y)
	_expect(card_rect.size.x < viewport_size.x * 0.55, "result card should not read as a full-screen color panel")
	_expect(card.get_theme_stylebox("panel") != null, "result card should have a gothic panel style")

func _assert_shared_result_variants() -> void:
	var controller: Variant = _combat_controller()
	_expect(controller != null and controller.has_method("_show_result_banner"), "result controller should expose the shared banner builder")
	if controller == null or not controller.has_method("_show_result_banner"):
		return
	controller.call("_show_result_banner", "DEFEAT", "Round lost. Resolving the aftermath.", Color(0.72, 0.18, 0.16, 1.0), Color(1.0, 0.66, 0.60, 1.0))
	_expect_result_copy("DEFEAT", "aftermath")
	controller.call("_show_result_banner", "STALEMATE", "Wager returned. Preparing your next decision.", Color(0.76, 0.62, 0.32, 1.0), Color(0.98, 0.85, 0.58, 1.0))
	_expect_result_copy("STALEMATE", "Wager returned")
	controller.call("_show_result_banner", "VICTORY", "Round secured. Preparing your next decision.", Color(0.42, 0.78, 0.24, 1.0), Color(0.82, 1.0, 0.66, 1.0))
	_expect_result_copy("VICTORY", "Preparing")

func _expect_result_copy(expected_title: String, detail_token: String) -> void:
	var banner: PanelContainer = _main.find_child("BattleResultBanner", true, false) as PanelContainer
	var title_label: Label = banner.get_node_or_null("Center/BattleResultCard/CardMargin/Content/OutcomeLabel") as Label if banner != null else null
	var detail_label: Label = banner.get_node_or_null("Center/BattleResultCard/CardMargin/Content/DetailLabel") as Label if banner != null else null
	_expect(title_label != null and title_label.text == expected_title, "shared result card should render %s" % expected_title)
	_expect(detail_label != null and detail_label.text.contains(detail_token), "%s detail should contain %s" % [expected_title, detail_token])

func _bottom_planning_visible() -> bool:
	var combat: Control = _main.get_node_or_null("CombatView") as Control
	if combat == null:
		return false
	var bench: Control = combat.get_node_or_null("MarginContainer/VBoxContainer/BenchArea") as Control
	var bottom: Control = combat.get_node_or_null("MarginContainer/VBoxContainer/BottomStorageArea") as Control
	return (bench != null and bench.visible) or (bottom != null and bottom.visible)

func _continue_button_text() -> String:
	var button: Button = _continue_button()
	return String(button.text) if button != null else "<missing>"

func _continue_button_disabled() -> bool:
	var button: Button = _continue_button()
	return true if button == null else bool(button.disabled)

func _continue_button() -> Button:
	if _main == null or not is_instance_valid(_main):
		return null
	return _main.find_child("ContinueButton", true, false) as Button

func _normalize_restored_planning_capture_timer() -> void:
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
		_save_vision_capture(filename)
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
	_saved_captures += 1
	print("%s: saved %s" % [SMOKE_NAME, ProjectSettings.globalize_path(path)])

func _save_vision_capture(filename: String) -> void:
	var root_node: Node = self
	if _main != null:
		root_node = _main
	var result: Dictionary[String, Variant] = VisionSnapshot.capture(root_node, filename.get_basename(), OUTPUT_DIR)
	if not bool(result.get("ok", false)):
		push_error("%s: vision fallback failed for %s reason=%s" % [SMOKE_NAME, filename, str(result.get("reason", ""))])
		return
	_saved_captures += 1
	print("%s: saved %s via %s" % [SMOKE_NAME, ProjectSettings.globalize_path(str(result.get("path", ""))), str(result.get("kind", ""))])

func _is_framebuffer_unavailable() -> bool:
	var display_name: String = DisplayServer.get_name().to_lower()
	var driver_name: String = RenderingServer.get_current_rendering_driver_name().to_lower()
	return display_name == "headless" or display_name == "server" or display_name == "dummy" or driver_name.contains("dummy")

func _finish() -> void:
	Engine.time_scale = _previous_time_scale
	UnitFactory.suppress_validation_warnings = _previous_suppress_validation_warnings
	_flush_synthetic_input()
	var exit_code: int = 0
	if _failures.is_empty():
		print("%s: OK captures=%d output=%s" % [SMOKE_NAME, _saved_captures, ProjectSettings.globalize_path(OUTPUT_DIR)])
	else:
		for failure: String in _failures:
			push_error(SMOKE_NAME + ": " + failure)
		exit_code = 1
	_cleanup_runtime()
	get_tree().process_frame.connect(_quit_after_cleanup.bind(exit_code, 10), CONNECT_ONE_SHOT)
