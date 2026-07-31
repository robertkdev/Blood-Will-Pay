extends "res://tests/visual/actual_run_loop_smoke.gd"

const VisionSnapshot := preload("res://scripts/util/vision_snapshot.gd")
const UserSettingsScript: GDScript = preload("res://scripts/game/settings/user_settings.gd")
const SMOKE_NAME: String = "PostCombatPlanningBeatSmoke"
const OUTPUT_DIR: String = "res://outputs/visual_iter/post_combat_planning_beat_pass"
const TEST_SETTINGS_PATH: String = "user://post_combat_planning_beat_settings.cfg"
const MIN_RESTORED_PLANNING_SECONDS: float = 55.0

var _saved_captures: int = 0

func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	var window: Window = get_window()
	if window != null:
		window.content_scale_factor = 1.0
		window.size = Vector2i(1920, 1080)
		window.content_scale_size = Vector2i(1920, 1080)
	UserSettingsScript.configure_storage_path(TEST_SETTINGS_PATH)
	UserSettingsScript.initialize(window)
	UserSettingsScript.set_ui_scale(1.0, window)
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
	var active_stage_phase: Label = _main.find_child("PhaseLabel", true, false) as Label
	_expect(active_stage_phase != null and active_stage_phase.text == "/// FIGHT", "active combat stage strip did not expose /// FIGHT")
	_assert_active_combat_shell()
	if _finish_if_failed():
		return
	await _settle_frames(2)
	_save_capture("00_active_combat.png")

	var intermission_seen: bool = await _wait_for_intermission_bar(24.0)
	_expect(intermission_seen, "post-combat intermission bar did not appear before planning returned")
	if _finish_if_failed():
		return
	await _settle_frames(2)
	_assert_result_card()
	if _finish_if_failed():
		return
	_save_capture("01_post_win_intermission_bar.png")
	await _assert_shared_result_variants()
	if _finish_if_failed():
		return
	var result_skip_requested: bool = await _request_result_skip()
	_expect(result_skip_requested, "result hold did not accept its visible Enter/Space skip affordance")

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
	var result_banner: PanelContainer = _main.find_child("BattleResultBanner", true, false) as PanelContainer
	_expect(result_banner != null and not result_banner.visible, "battle result overlay remained visible after the authored intermission")
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
	var aftermath: Control = banner.get_node_or_null("BattleResultAftermath") as Control
	var aftermath_art: TextureRect = banner.get_node_or_null("BattleResultAftermath/AftermathFieldArt") as TextureRect
	var aftermath_wash: TextureRect = banner.get_node_or_null("BattleResultAftermath/AftermathBloodWash") as TextureRect
	var rupture_field: Control = banner.get_node_or_null("BattleResultAftermath/AftermathRuptureField") as Control
	var aftermath_stamp: Label = banner.get_node_or_null("BattleResultAftermath/AftermathStamp") as Label
	_expect(card != null and card.visible, "post-win battle result card was missing")
	_expect(aftermath != null and aftermath.visible and String(aftermath.get_meta("outcome_variant", "")) == "victory", "victory should culminate in a visible environmental aftermath layer")
	_expect(aftermath_art != null and aftermath_art.texture != null and aftermath_art.modulate.a >= 0.70, "victory aftermath should preserve a perceptible physical battlefield")
	_expect(aftermath_wash != null and aftermath_wash.texture is GradientTexture2D, "victory aftermath should carry a state-specific blood/ash wash")
	_expect(rupture_field != null and rupture_field.get_child_count() >= 5, "victory aftermath should physically rupture the field around the record")
	_expect(aftermath_stamp != null and aftermath_stamp.text.contains("FIELD") and aftermath_stamp.text.contains("BREATHES"), "victory aftermath should communicate that the horror survives the outcome")
	_assert_outcome_aftermath_geometry(banner, "VICTORY")
	if card == null:
		return
	var title_label: Label = card.get_node_or_null("CardMargin/Content/OutcomeLabel") as Label
	var detail_label: Label = card.get_node_or_null("CardMargin/Content/DetailLabel") as Label
	var kicker_label: Label = card.get_node_or_null("CardMargin/Content/KickerLabel") as Label
	var outcome_signal: Label = card.get_node_or_null("CardMargin/Content/OutcomeSignal") as Label
	var record_label: Label = card.get_node_or_null("CardMargin/Content/RecordRow/RecordLabel") as Label
	var settlement_label: Label = card.get_node_or_null("CardMargin/Content/RecordRow/SettlementLabel") as Label
	var impact_stamp: Label = card.get_node_or_null("CardMargin/Content/ImpactStamp") as Label
	var hold_progress: ProgressBar = card.get_node_or_null("CardMargin/Content/ResultHoldProgress") as ProgressBar
	var hold_label: Label = card.get_node_or_null("CardMargin/Content/ResultHoldRow/ResultHoldLabel") as Label
	var skip_button: Button = card.get_node_or_null("CardMargin/Content/ResultHoldRow/ResultSkipButton") as Button
	_expect(title_label != null and title_label.text == "VICTORY", "post-win result title should read VICTORY")
	_expect(detail_label != null and detail_label.text.contains("WAGER") and detail_label.text.contains("RETURN") and detail_label.text.contains("RESULTING BANK"), "post-win result detail should expose wager, return, and resulting bank")
	_assert_result_detail_bounds(card, detail_label, "VICTORY")
	_expect(kicker_label != null and kicker_label.text == "/// SURVIVAL HAS A PRICE ///", "post-win result card should frame survival as a horror consequence")
	_expect(outcome_signal != null and outcome_signal.text.contains("WOODS REMEMBER"), "post-win result card should sustain the forest-horror threat after combat")
	_expect(record_label != null and record_label.text.contains("FIELD RECORD"), "post-win result card should expose authored field-record metadata")
	_expect(settlement_label != null and settlement_label.text.ends_with("// HOLD") and not settlement_label.text.contains("SEC"), "post-win result card should use natural hold copy without QA timing telemetry")
	_expect(impact_stamp != null and impact_stamp.text == "PAID IN BLOOD // WALKING", "post-win result card should close with an authored survival stamp")
	_expect(hold_progress != null and hold_progress.max_value == 1.0, "result card should expose visible hold progress")
	_expect(hold_label != null and hold_label.text.begins_with("AUTO-ADVANCE IN"), "result card should name its automatic advance countdown")
	_expect(skip_button != null and skip_button.text.contains("ENTER / SPACE") and not skip_button.text.contains("("), "result card should expose a threshold-free keyboard advance affordance")
	_assert_result_hold_copy_unobstructed(card, hold_progress, hold_label, skip_button, "VICTORY")
	_assert_result_frame_inside_viewport(card, skip_button, "VICTORY")
	_assert_persistent_combat_chrome("VICTORY result")
	var record_wash: TextureRect = card.get_node_or_null("RecordWash") as TextureRect
	_expect(record_wash != null and record_wash.texture != null, "result card should carry a restrained war-record texture pass")
	_expect(card.get_node_or_null("DamageMarks/DamageMarkTop") != null and card.get_node_or_null("DamageMarks/DamageMarkRake") != null and card.get_node_or_null("DamageMarks/TornCornerNW") != null, "result card should read as damaged assembled ephemera rather than an empty clean rectangle")
	var card_rect: Rect2 = card.get_global_rect()
	var viewport: Viewport = get_viewport()
	var viewport_size: Vector2 = viewport.get_visible_rect().size if viewport != null else Vector2.ZERO
	_expect(is_equal_approx(card.custom_minimum_size.x, 1040.0), "victory result should use its authored wide survival-record silhouette, got %.1f" % card.custom_minimum_size.x)
	_expect(is_equal_approx(card.custom_minimum_size.y, 388.0), "victory result should use its authored rising survival-record height, got %.1f" % card.custom_minimum_size.y)
	_expect(card_rect.size.x < viewport_size.x * 0.58, "result card should not read as a full-screen color panel (card %.1f / viewport %.1f)" % [card_rect.size.x, viewport_size.x])
	_expect(card.get_theme_stylebox("panel") is StyleBoxFlat, "result card should keep an accessible high-contrast field surface")
	_expect(String(card.get_meta("result_variant", "")) == "victory", "victory card should expose a semantic visual variant")
	_expect(String(card.get_meta("grayscale_silhouette", "")) == "rising_open_lane", "victory must remain recognizable by its open-lane silhouette without headline or color")
	_expect(String(card.get_meta("reading_path", "")) == "left_to_right_escape", "victory should use an escaping left-to-right reading path")
	_expect(String(card.get_meta("tear_direction", "")) == "rising_open", "victory result should open upward rather than sharing the defeat tear")
	var controller: Variant = _combat_controller()
	_expect(controller != null and controller.has_method("_result_minimum_dwell_seconds"), "result controller should expose its readable dwell contract")
	if controller != null and controller.has_method("_result_minimum_dwell_seconds"):
		_expect(float(controller.call("_result_minimum_dwell_seconds")) >= 6.0, "result card minimum dwell must be at least six seconds")

func _assert_shared_result_variants() -> void:
	var controller: Variant = _combat_controller()
	_expect(controller != null and controller.has_method("_show_result_banner"), "result controller should expose the shared banner builder")
	if controller == null or not controller.has_method("_show_result_banner"):
		return
	var accelerated_scale: float = Engine.time_scale
	Engine.time_scale = 0.0
	var defeat_detail: String = String(controller.call("_build_result_economy_detail", "defeat"))
	controller.call("_show_result_banner", "DEFEAT", defeat_detail, Color(0.72, 0.18, 0.16, 1.0), Color(1.0, 0.66, 0.60, 1.0))
	_pin_result_variant_visible()
	await _settle_result_variant()
	_expect_result_copy("DEFEAT", "LOST")
	_save_capture("result_defeat.png")
	var tie_detail: String = String(controller.call("_build_result_economy_detail", "tie"))
	controller.call("_show_result_banner", "STALEMATE", tie_detail, Color(0.76, 0.62, 0.32, 1.0), Color(0.98, 0.85, 0.58, 1.0))
	_pin_result_variant_visible()
	await _settle_result_variant()
	_expect_result_copy("STALEMATE", "RETURNED")
	_save_capture("result_stalemate.png")
	await _assert_compact_defeat_result(controller, defeat_detail)
	Engine.time_scale = accelerated_scale

func _assert_compact_defeat_result(controller: Variant, defeat_detail: String) -> void:
	var window: Window = get_window()
	if window == null:
		return
	DisplayServer.window_set_size(Vector2i(1280, 720))
	window.size = Vector2i(1280, 720)
	window.content_scale_size = Vector2i(1280, 720)
	UserSettingsScript.set_ui_scale(1.5, window)
	await _settle_frames(3)
	controller.call("_show_result_banner", "DEFEAT", defeat_detail, Color(0.72, 0.18, 0.16, 1.0), Color(1.0, 0.66, 0.60, 1.0))
	_pin_result_variant_visible()
	await _settle_frames(3)
	var banner: PanelContainer = _main.find_child("BattleResultBanner", true, false) as PanelContainer
	var card: PanelContainer = banner.get_node_or_null("Center/BattleResultCard") as PanelContainer if banner != null else null
	var title_label: Label = card.get_node_or_null("CardMargin/Content/OutcomeLabel") as Label if card != null else null
	_expect(card != null and bool(card.get_meta("compact_centered_stack", false)), "150% defeat result did not enter its centered compact stack")
	_expect(card != null and is_equal_approx(float(card.get_meta("ui_scale_compensation", 0.0)), 1.5), "150% defeat result did not compensate its logical frame for UI scale")
	_expect(card != null and card.custom_minimum_size.x <= 470.0, "150% defeat logical width stayed too large for the 1280px safe area")
	_expect(title_label != null and title_label.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER, "150% defeat headline drifted back to the right edge")
	if banner != null and card != null:
		_assert_result_frame_inside_viewport(card, card.get_node_or_null("CardMargin/Content/ResultHoldRow/ResultSkipButton") as Button, "DEFEAT 1280x720 150%")
	_save_capture("result_defeat_1280x720_150pct.png")
	UserSettingsScript.set_ui_scale(1.0, window)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	window.size = Vector2i(1920, 1080)
	window.content_scale_size = Vector2i(1920, 1080)
	await _settle_frames(3)

func _settle_result_variant() -> void:
	# The real victory intermission remains active while the shared variants are
	# exercised.  Keep this capture window shorter than its accelerated timeout
	# so the intermission callback cannot hide the later stalemate card.
	await _settle_frames(2)

func _pin_result_variant_visible() -> void:
	var banner: PanelContainer = _main.find_child("BattleResultBanner", true, false) as PanelContainer
	_expect(banner != null, "shared result banner should exist for variant capture")
	if banner == null:
		return
	banner.visible = true
	banner.modulate.a = 1.0
	var card: PanelContainer = banner.get_node_or_null("Center/BattleResultCard") as PanelContainer
	if card != null:
		card.scale = Vector2.ONE

func _expect_result_copy(expected_title: String, detail_token: String) -> void:
	var banner: PanelContainer = _main.find_child("BattleResultBanner", true, false) as PanelContainer
	var title_label: Label = banner.get_node_or_null("Center/BattleResultCard/CardMargin/Content/OutcomeLabel") as Label if banner != null else null
	var detail_label: Label = banner.get_node_or_null("Center/BattleResultCard/CardMargin/Content/DetailLabel") as Label if banner != null else null
	var impact_stamp: Label = banner.get_node_or_null("Center/BattleResultCard/CardMargin/Content/ImpactStamp") as Label if banner != null else null
	var kicker_label: Label = banner.get_node_or_null("Center/BattleResultCard/CardMargin/Content/KickerLabel") as Label if banner != null else null
	var outcome_signal: Label = banner.get_node_or_null("Center/BattleResultCard/CardMargin/Content/OutcomeSignal") as Label if banner != null else null
	var settlement_label: Label = banner.get_node_or_null("Center/BattleResultCard/CardMargin/Content/RecordRow/SettlementLabel") as Label if banner != null else null
	var hold_progress: ProgressBar = banner.get_node_or_null("Center/BattleResultCard/CardMargin/Content/ResultHoldProgress") as ProgressBar if banner != null else null
	var hold_label: Label = banner.get_node_or_null("Center/BattleResultCard/CardMargin/Content/ResultHoldRow/ResultHoldLabel") as Label if banner != null else null
	var skip_button: Button = banner.get_node_or_null("Center/BattleResultCard/CardMargin/Content/ResultHoldRow/ResultSkipButton") as Button if banner != null else null
	var aftermath: Control = banner.get_node_or_null("BattleResultAftermath") as Control if banner != null else null
	var aftermath_art: TextureRect = banner.get_node_or_null("BattleResultAftermath/AftermathFieldArt") as TextureRect if banner != null else null
	var aftermath_wash: TextureRect = banner.get_node_or_null("BattleResultAftermath/AftermathBloodWash") as TextureRect if banner != null else null
	var rupture_field: Control = banner.get_node_or_null("BattleResultAftermath/AftermathRuptureField") as Control if banner != null else null
	var aftermath_stamp: Label = banner.get_node_or_null("BattleResultAftermath/AftermathStamp") as Label if banner != null else null
	_expect(banner != null and banner.visible and banner.modulate.a > 0.99, "shared result card should remain visibly captureable for %s" % expected_title)
	_expect(title_label != null and title_label.text == expected_title, "shared result card should render %s" % expected_title)
	_expect(detail_label != null and detail_label.text.contains(detail_token), "%s detail should contain %s" % [expected_title, detail_token])
	_expect(detail_label != null and detail_label.text.contains("WAGER") and detail_label.text.contains("RESULTING BANK"), "%s detail should state wager and resulting bank without relying on color" % expected_title)
	var card: PanelContainer = banner.get_node_or_null("Center/BattleResultCard") as PanelContainer if banner != null else null
	_assert_result_detail_bounds(card, detail_label, expected_title)
	_assert_result_hold_copy_unobstructed(card, hold_progress, hold_label, skip_button, expected_title)
	_assert_result_frame_inside_viewport(card, skip_button, expected_title)
	_assert_persistent_combat_chrome("%s result" % expected_title)
	_expect(impact_stamp != null and impact_stamp.text != "FIELD RECORD CLOSED", "%s should carry an authored result-specific settlement stamp" % expected_title)
	_expect(card != null and String(card.get_meta("result_variant", "")) == expected_title.to_lower(), "%s should expose a semantic visual variant" % expected_title)
	_expect(hold_label != null and hold_label.text.begins_with("AUTO-ADVANCE IN ") and not hold_label.text.contains("."), "%s countdown should use natural integer copy rather than QA telemetry" % expected_title)
	_expect(skip_button != null and skip_button.text.contains("ENTER / SPACE") and not skip_button.text.contains("("), "%s advance affordance should not expose a decimal guard threshold" % expected_title)
	_expect(aftermath != null and aftermath.visible and String(aftermath.get_meta("outcome_variant", "")) == expected_title.to_lower(), "%s should expose a matching environmental aftermath variant" % expected_title)
	_expect(aftermath_art != null and aftermath_art.texture != null and aftermath_art.modulate.a >= 0.68, "%s should retain the physical battlefield behind its casualty record" % expected_title)
	_expect(aftermath_wash != null and aftermath_wash.texture is GradientTexture2D, "%s should carry a material outcome wash" % expected_title)
	_expect(rupture_field != null and rupture_field.get_child_count() >= 5, "%s should rupture the surrounding field rather than presenting only a clean card" % expected_title)
	_expect(aftermath_stamp != null and not aftermath_stamp.text.strip_edges().is_empty(), "%s should state its environmental consequence outside the data card" % expected_title)
	_assert_outcome_aftermath_geometry(banner, expected_title)
	if expected_title == "DEFEAT":
		_expect(card != null and card.custom_minimum_size == Vector2(820.0, 448.0), "defeat should use a centered consequence silhouette without a dead right-side rail")
		_expect(card != null and String(card.get_meta("grayscale_silhouette", "")) == "descending_grave_jaw", "defeat should remain recognizable as a closing grave-jaw silhouette in grayscale")
		_expect(card != null and String(card.get_meta("reading_path", "")) == "centered_grave_descent", "defeat should drive a centered downward reading path")
		_expect(title_label != null and title_label.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER, "defeat headline should center instead of clustering against the right edge")
		_expect(card != null and String(card.get_meta("tear_direction", "")) == "downward_collapse", "defeat should collapse downward")
		_expect(kicker_label != null and kicker_label.text.contains("WOODS COLLECT"), "defeat should name the environmental threat")
		_expect(outcome_signal != null and outcome_signal.text.contains("DARK KEEPS"), "defeat should communicate a visceral horror consequence")
		_expect(settlement_label != null and settlement_label.text.contains("FORFEITED"), "defeat should expose forfeiture rather than generic settlement")
		_expect(impact_stamp != null and impact_stamp.text.contains("BLOOD TAKEN"), "defeat should carry a distinct blood-cost stamp")
	elif expected_title == "STALEMATE":
		_expect(card != null and card.custom_minimum_size == Vector2(800.0, 456.0), "stalemate should use a materially narrower suspended-record silhouette")
		_expect(card != null and String(card.get_meta("grayscale_silhouette", "")) == "locked_vertical_deadlock", "stalemate should remain recognizable as a locked vertical deadlock in grayscale")
		_expect(card != null and String(card.get_meta("reading_path", "")) == "centered_suspension", "stalemate should suspend the reading path in the center")
		_expect(title_label != null and title_label.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER, "stalemate headline should be visibly trapped on the center axis")
		_expect(card != null and String(card.get_meta("tear_direction", "")) == "suspended_split", "stalemate should use a suspended split tear")
		_expect(kicker_label != null and kicker_label.text.contains("DEBT WAITS"), "stalemate should read as unresolved danger")
		_expect(outcome_signal != null and outcome_signal.text.contains("NOTHING LET YOU LEAVE"), "stalemate should communicate unresolved forest horror")
		_expect(settlement_label != null and settlement_label.text.contains("RETURNED"), "stalemate should expose returned escrow rather than generic settlement")
		_expect(impact_stamp != null and impact_stamp.text.contains("NO ESCAPE"), "stalemate should carry a distinct unresolved stamp")

func _assert_active_combat_shell() -> void:
	var combat: Control = _main.get_node_or_null("CombatView") as Control
	_expect(combat != null, "active combat shell missing")
	if combat == null:
		return
	_expect(String(combat.get_meta("tactical_phase_visual", "")) == "combat", "combat shell did not expose its semantic combat state")
	var threat_boundary: Control = combat.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ArenaContainer/CombatThreatBoundary") as Control
	var objective: Label = combat.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ArenaContainer/CombatThreatBoundary/CombatObjectiveSignal") as Label
	var woodland: TextureRect = combat.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ArenaContainer/ArenaWoodlandHorizon") as TextureRect
	var silhouettes: Control = combat.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ArenaContainer/ArenaWoodlandSilhouettes") as Control
	var palisade: ColorRect = combat.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ArenaContainer/ArenaWoodlandSilhouettes/RuinedPalisadeBeam") as ColorRect
	var watch_post: ColorRect = combat.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ArenaContainer/ArenaWoodlandSilhouettes/HostileWatchPost") as ColorRect
	var fog: TextureRect = combat.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ArenaContainer/ArenaGroundFog") as TextureRect
	var smoke: TextureRect = combat.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ArenaContainer/ArenaHostileSmoke") as TextureRect
	var wet_reflection: TextureRect = combat.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ArenaContainer/ArenaWetGroundReflection") as TextureRect
	var war_aftermath: Control = combat.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ArenaContainer/ArenaWarAftermath") as Control
	var onset_geometry: Control = combat.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ArenaContainer/ArenaWarAftermath/OnsetAftermathGeometry") as Control
	var midfight_geometry: Control = combat.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ArenaContainer/ArenaWarAftermath/MidfightAftermathGeometry") as Control
	var collapse_geometry: Control = combat.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ArenaContainer/ArenaWarAftermath/CollapseAftermathGeometry") as Control
	var reduced_geometry: Control = combat.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ArenaContainer/ArenaWarAftermath/ReducedMotionGrimeLock") as Control
	var cell_seams: GridContainer = combat.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ArenaContainer/ArenaCellSeams") as GridContainer
	var battle_area: Control = combat.get_node_or_null("MarginContainer/VBoxContainer/BattleArea") as Control
	var arena_container: Control = combat.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ArenaContainer") as Control
	var planning_geometry: Control = combat.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ContentRow/BoardColumn/PlanningArea/PlanningDeploymentGeometry") as Control
	var actions: Control = combat.get_node_or_null("MarginContainer/VBoxContainer/ActionsRow") as Control
	var stats: Control = combat.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ContentRow/StatsArea") as Control
	var items: Control = combat.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ContentRow/LeftItemArea") as Control
	_expect(threat_boundary != null and threat_boundary.visible, "combat shell lacks non-color threat-boundary geometry")
	_expect(objective != null and objective.text.contains("SURVIVE"), "combat shell lacks an explicit survival objective signal")
	_expect(woodland != null and woodland.texture != null and woodland.visible, "combat shell lacks the title-connected woodland horizon")
	_expect(silhouettes != null and silhouettes.visible and silhouettes.get_child_count() >= 12, "combat shell lacks authored hostile woodland depth")
	_expect(palisade != null and watch_post != null, "combat shell lacks ruined fortification and distant hostile structure silhouettes")
	_expect(fog != null and fog.texture != null and smoke != null and smoke.texture != null, "combat shell lacks bounded fog/smoke weather layers")
	_expect(wet_reflection != null and wet_reflection.texture is GradientTexture2D, "combat shell lacks the wet-ground reflection that makes the woodland feel physical")
	_expect(war_aftermath != null and String(war_aftermath.get_meta("visual_role", "")) == "non_unit_physical_war_aftermath", "combat shell lacks a semantic non-unit physical war-aftermath layer")
	_expect(onset_geometry != null and int(onset_geometry.get_meta("physical_evidence_count", 0)) >= 6, "combat onset lacks practical cart, crater, barricade, and earthwork evidence")
	_expect(midfight_geometry != null and int(midfight_geometry.get_meta("physical_evidence_count", 0)) >= 10, "combat midfight lacks a materially denser wreckage, impact, smoke, and contamination composition")
	_expect(collapse_geometry != null and int(collapse_geometry.get_meta("physical_evidence_count", 0)) >= 9, "combat casualty pressure lacks a bounded collapse composition")
	_expect(reduced_geometry != null and int(reduced_geometry.get_meta("physical_evidence_count", 0)) >= 4, "reduced motion lacks a sparse static battlefield-evidence composition")
	_expect(onset_geometry != null and bool(onset_geometry.get_meta("protected_center_clear", false)), "combat onset evidence does not preserve the playable center")
	_expect(reduced_geometry != null and onset_geometry != null and float(reduced_geometry.get_meta("overlay_density", 1.0)) < float(onset_geometry.get_meta("overlay_density", 0.0)), "reduced motion is not lower-density than the kinetic onset")
	_expect(cell_seams != null and cell_seams.z_index >= -1 and cell_seams.get_child_count() == 48, "combat grid seams do not stay above the environment")
	var pressure_phase: String = String(arena_container.get_meta("battlefield_pressure_phase", "")) if arena_container != null else ""
	_expect(not pressure_phase.is_empty(), "combat environment did not publish its evolving pressure phase")
	_expect(arena_container != null and String(arena_container.get_meta("battlefield_environment_signature", "")).begins_with("physical_warfield/"), "combat environment lacks a measurable physical-composition signature")
	_expect(arena_container != null and String(arena_container.get_meta("battlefield_grid_priority", "")) == "cell_seams_above_environment", "combat environment does not publish grid-priority protection")
	var viewport_height: float = get_viewport().get_visible_rect().size.y
	_expect(battle_area != null and battle_area.get_global_rect().size.y >= viewport_height * 0.78, "combat field remained a narrow middle band instead of occupying the survival surface")
	_expect(arena_container != null and bool(arena_container.get_meta("use_full_combat_bounds", false)), "combat actors were not promoted from the planning strip into full-field bounds")
	_expect(planning_geometry != null and not planning_geometry.visible, "planning deployment geometry stayed active during combat")
	_expect(actions != null and not actions.visible, "planning action chrome stayed visible during combat")
	_expect(stats != null and not stats.visible, "planning metrics rail stayed visible during combat")
	_expect(items != null and not items.visible, "planning item rail stayed visible during combat")
	var tactical_record: Label = combat.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/TacticalFieldRecordShell/TacticalRecordMark") as Label
	_expect(tactical_record != null and not tactical_record.visible, "decorative tactical-record caption remained over the live battlefield")
	_assert_persistent_combat_chrome("active combat")

func _assert_persistent_combat_chrome(context: String) -> void:
	var stage_bar: Control = _main.find_child("StageProgressTopBar", true, false) as Control if _main != null else null
	var chapter_label: Label = _main.find_child("ChapterLabel", true, false) as Label if _main != null else null
	var phase_label: Label = _main.find_child("PhaseLabel", true, false) as Label if _main != null else null
	var system_menu: Button = _main.find_child("SystemMenuButton", true, false) as Button if _main != null else null
	var instruction_ribbon: Label = _main.find_child("CombatObjectiveSignal", true, false) as Label if _main != null else null
	_expect(stage_bar != null and stage_bar.is_visible_in_tree(), "%s lost the stage/chapter strip" % context)
	_expect(chapter_label != null and chapter_label.is_visible_in_tree() and chapter_label.modulate.a >= 0.99, "%s lost persistent chapter copy" % context)
	_expect(phase_label != null and phase_label.is_visible_in_tree() and phase_label.modulate.a >= 0.99, "%s lost persistent phase copy" % context)
	_expect(system_menu != null and system_menu.is_visible_in_tree() and system_menu.text == "SYS // MENU" and system_menu.modulate.a >= 0.99, "%s lost the authored persistent system-menu action" % context)
	_expect(system_menu != null and bool(system_menu.get_meta("authored_system_command", false)), "%s system-menu action regressed to a generic fallback button" % context)
	_expect(chapter_label != null and not chapter_label.text.strip_edges().is_empty(), "%s left the stage strip visibly blank" % context)
	_expect(phase_label != null and not phase_label.text.strip_edges().is_empty(), "%s left the phase strip visibly blank" % context)
	_expect(instruction_ribbon != null and instruction_ribbon.is_visible_in_tree() and not instruction_ribbon.text.strip_edges().is_empty(), "%s lost or emptied the persistent instruction ribbon" % context)
	var visible_stage_tokens: int = 0
	if stage_bar != null:
		for token_index: int in range(1, 6):
			var token: Control = stage_bar.find_child("StageToken%d" % token_index, true, false) as Control
			if token != null and token.is_visible_in_tree():
				visible_stage_tokens += 1
	_expect(visible_stage_tokens >= 1, "%s lost every stage marker from the persistent HUD" % context)
	if stage_bar != null:
		_expect(stage_bar.z_index >= 200, "%s stage strip is not protected above combat/result pressure layers" % context)
	if system_menu != null:
		_expect(system_menu.z_index >= 200, "%s Menu is not protected above combat/result pressure layers" % context)
	if instruction_ribbon != null:
		_expect(not instruction_ribbon.z_as_relative and instruction_ribbon.z_index >= 200, "%s instruction ribbon is not protected above combat/result pressure layers" % context)

func _assert_outcome_aftermath_geometry(banner: PanelContainer, outcome: String) -> void:
	_expect(banner != null, "%s outcome geometry cannot be checked without a result banner" % outcome)
	if banner == null:
		return
	var aftermath: Control = banner.get_node_or_null("BattleResultAftermath") as Control
	var victory_geometry: Control = banner.get_node_or_null("BattleResultAftermath/VictoryAftermathGeometry") as Control
	var stalemate_geometry: Control = banner.get_node_or_null("BattleResultAftermath/StalemateAftermathGeometry") as Control
	var defeat_geometry: Control = banner.get_node_or_null("BattleResultAftermath/DefeatAftermathGeometry") as Control
	var expected_signature: String = "opened_survivor_lane" if outcome == "VICTORY" else "crosswise_deadlock" if outcome == "STALEMATE" else "collapsed_canopy_grave"
	_expect(aftermath != null and String(aftermath.get_meta("physical_geometry_signature", "")) == expected_signature, "%s lacks its distinct physical aftermath signature" % outcome)
	_expect(aftermath != null and int(aftermath.get_meta("flat_rectangle_count", -1)) == 0, "%s aftermath regressed to giant flat rectangle construction" % outcome)
	_assert_physical_aftermath_painter(victory_geometry, "victory", 6)
	_assert_physical_aftermath_painter(stalemate_geometry, "stalemate", 6)
	_assert_physical_aftermath_painter(defeat_geometry, "defeat", 7)
	if victory_geometry != null:
		_expect(victory_geometry.visible == (outcome == "VICTORY"), "%s leaked the victory survivor-lane composition" % outcome)
	if stalemate_geometry != null:
		_expect(stalemate_geometry.visible == (outcome == "STALEMATE"), "%s leaked the stalemate deadlock composition" % outcome)
	if defeat_geometry != null:
		_expect(defeat_geometry.visible == (outcome == "DEFEAT"), "%s leaked the defeat collapse composition" % outcome)

func _assert_physical_aftermath_painter(group: Control, expected_variant: String, minimum_authored_evidence: int) -> void:
	_expect(group != null, "%s aftermath geometry group is missing" % expected_variant)
	if group == null:
		return
	var painter: Control = group.get_node_or_null("PhysicalAftermathPainter") as Control
	_expect(painter != null, "%s aftermath lacks the irregular physical-scene painter" % expected_variant)
	_expect(int(group.get_meta("flat_rectangle_count", -1)) == 0, "%s aftermath uses flat rectangle geometry" % expected_variant)
	_expect(int(group.get_meta("authored_evidence_spec_count", 0)) >= minimum_authored_evidence, "%s aftermath lost authored physical evidence density" % expected_variant)
	if painter != null:
		_expect(String(painter.get_meta("outcome_variant", "")) == expected_variant, "%s painter exposes the wrong outcome variant" % expected_variant)
		_expect(String(painter.get_meta("physical_material_language", "")).contains("mud_crater_broken_timber"), "%s painter does not publish physical mud/timber/crater material language" % expected_variant)
		_expect(int(painter.get_meta("flat_rectangle_count", -1)) == 0, "%s painter regressed to flat rectangle construction" % expected_variant)

func _assert_result_frame_inside_viewport(card: PanelContainer, skip_button: Button, outcome: String) -> void:
	if card == null or skip_button == null:
		return
	var viewport_rect: Rect2 = get_viewport().get_visible_rect()
	var card_rect: Rect2 = card.get_global_rect()
	var skip_rect: Rect2 = skip_button.get_global_rect()
	_expect(viewport_rect.encloses(card_rect), "%s result frame escaped the logical viewport: viewport=%s card=%s" % [outcome, str(viewport_rect), str(card_rect)])
	_expect(card_rect.encloses(skip_rect), "%s skip control escaped the lower result frame: card=%s skip=%s" % [outcome, str(card_rect), str(skip_rect)])

func _assert_result_hold_copy_unobstructed(
	card: PanelContainer,
	hold_progress: ProgressBar,
	hold_label: Label,
	skip_button: Button,
	outcome: String
) -> void:
	_expect(card != null and hold_progress != null and hold_label != null and skip_button != null, "%s result hold controls are incomplete" % outcome)
	if card == null or hold_progress == null or hold_label == null or skip_button == null:
		return
	var critical_rects: Array[Rect2] = [
		hold_progress.get_global_rect(),
		hold_label.get_global_rect(),
		skip_button.get_global_rect(),
	]
	var marks: Control = card.get_node_or_null("DamageMarks") as Control
	_expect(marks != null and marks.z_index < 2, "%s decorative damage marks are not layered behind result copy" % outcome)
	if marks == null:
		return
	for child: Node in marks.get_children():
		var mark: ColorRect = child as ColorRect
		if mark == null or not mark.visible or String(mark.name).begins_with("TornCorner"):
			continue
		var mark_rect: Rect2 = mark.get_global_rect()
		for critical_rect: Rect2 in critical_rects:
			_expect(not mark_rect.intersects(critical_rect), "%s decorative mark %s crosses hold/skip copy" % [outcome, String(mark.name)])

func _request_result_skip() -> bool:
	var controller: Variant = _combat_controller()
	if controller == null or not controller.has_method("handle_result_input"):
		return false
	Engine.time_scale = maxf(1.0, Engine.time_scale)
	var deadline: int = Time.get_ticks_msec() + 1500
	var skip_button: Button = _main.find_child("ResultSkipButton", true, false) as Button
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		if skip_button != null and not skip_button.disabled:
			break
	var skip_event: InputEventAction = InputEventAction.new()
	skip_event.action = "ui_accept"
	skip_event.pressed = true
	return bool(controller.call("handle_result_input", skip_event))

func _assert_result_detail_bounds(card: PanelContainer, detail_label: Label, outcome: String) -> void:
	_expect(card != null, "%s result card missing for detail-bounds assertion" % outcome)
	_expect(detail_label != null, "%s detail label missing for detail-bounds assertion" % outcome)
	if card == null or detail_label == null:
		return
	var card_rect: Rect2 = card.get_global_rect()
	var detail_rect: Rect2 = detail_label.get_global_rect()
	_expect(card_rect.encloses(detail_rect), "%s detail escaped result card: card=%s detail=%s" % [outcome, str(card_rect), str(detail_rect)])
	_expect(detail_label.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART, "%s detail lost smart wrapping" % outcome)
	_expect(not detail_label.clip_text, "%s detail must not use horizontal clipping" % outcome)
	_expect(detail_label.custom_minimum_size.y >= 64.0, "%s detail lacks a two-line economic context budget" % outcome)
	_expect(detail_label.text.contains("\nRESULTING BANK"), "%s detail should deliberately wrap the resulting-bank context" % outcome)

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
