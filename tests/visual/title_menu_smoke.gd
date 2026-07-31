extends Node

const MAIN_SCENE: PackedScene = preload("res://scenes/Main.tscn")
const UserSettingsScript: GDScript = preload("res://scripts/game/settings/user_settings.gd")
const TEST_SETTINGS_PATH: String = "user://title_menu_smoke_settings.cfg"
const VIEWPORT_SIZE: Vector2i = Vector2i(1920, 1080)

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	DisplayServer.window_set_size(VIEWPORT_SIZE)
	var window: Window = get_window()
	if window != null:
		window.size = VIEWPORT_SIZE
		window.content_scale_size = VIEWPORT_SIZE
	UserSettingsScript.configure_storage_path(TEST_SETTINGS_PATH)
	UserSettingsScript.initialize(window)
	UserSettingsScript.set_ui_scale(1.0, window)
	UserSettingsScript.set_reduced_motion(false)
	var main: Control = MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame

	var failures: Array[String] = []
	var title_page: Control = main.get_node_or_null("TitlePage") as Control
	_expect(title_page != null and title_page.visible, "TitlePage should be visible before the main menu", failures)
	var title_menu: Control = main.get_node_or_null("TitleMenu") as Control
	_expect(title_menu != null, "TitleMenu missing", failures)
	if title_menu != null:
		_expect(not title_menu.visible, "TitleMenu should wait behind the title page on main start", failures)
		var artwork: TextureRect = main.get_node_or_null("TitlePage/Artwork") as TextureRect
		_expect(artwork != null, "TitlePage Artwork missing", failures)
		if artwork != null:
			_expect(artwork.texture != null, "TitlePage Artwork texture missing", failures)
			_expect(artwork.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED, "TitlePage Artwork should preserve the full composition", failures)
			_expect(artwork.anchor_left == 0.0 and artwork.anchor_top == 0.0 and artwork.anchor_right == 1.0 and artwork.anchor_bottom == 1.0, "TitlePage Artwork should fill the viewport", failures)
		var enter_button: Button = main.get_node_or_null("TitlePage/Center/Stack/EnterButton") as Button
		_expect(enter_button != null, "TitlePage EnterButton missing", failures)
		var continue_prompt: Label = main.get_node_or_null("TitlePage/Center/Stack/ContinuePrompt") as Label
		_expect(continue_prompt == null, "TitlePage must not restore the generic ContinuePrompt", failures)
		var entry_affordance: PanelContainer = main.get_node_or_null("TitlePage/Center/Stack/EntryAffordance") as PanelContainer
		var entry_order: Label = main.get_node_or_null("TitlePage/Center/Stack/EntryAffordance/EntryCopy/EntryOrder") as Label
		var entry_action: Label = main.get_node_or_null("TitlePage/Center/Stack/EntryAffordance/EntryCopy/EntryAction") as Label
		_expect(entry_affordance != null and entry_affordance.is_visible_in_tree() and entry_affordance.modulate.a >= 0.90, "TitlePage should expose a visible entry affordance", failures)
		_expect(entry_affordance != null and _rect_inside(entry_affordance.get_global_rect(), title_page.get_global_rect().grow(1.0)), "TitlePage entry affordance should remain inside the authored composition", failures)
		_expect(entry_order != null and entry_order.is_visible_in_tree() and entry_order.text.contains("ENTRY ORDER"), "TitlePage entry affordance should use authored field-order language", failures)
		_expect(entry_action != null and entry_action.is_visible_in_tree() and entry_action.text.contains("ENTER"), "TitlePage entry affordance should clearly communicate entry", failures)
		var visible_entry_copy: String = "%s %s" % [entry_order.text if entry_order != null else "", entry_action.text if entry_action != null else ""]
		_expect(not visible_entry_copy.to_upper().contains("PRESS ANY KEY") and not visible_entry_copy.to_upper().contains("CLICK OR PRESS"), "TitlePage must not restore the forbidden generic input prompt", failures)
		var title_distress: Control = main.get_node_or_null("TitlePage/TitleMarkDistress") as Control
		_expect(title_distress != null and title_distress.visible, "TitlePage should carry a restrained non-text registration treatment", failures)
		if title_distress != null:
			var expected_marks: Array[String] = ["BloodRegistration", "MisregisterSlash", "InkKnockout", "LowerRegistration"]
			for mark_name: String in expected_marks:
				var mark: ColorRect = title_distress.get_node_or_null(mark_name) as ColorRect
				_expect(mark != null and mark.visible and mark.color.a >= 0.60, "TitlePage distress mark %s should remain perceptible" % mark_name, failures)
				if mark != null:
					var stays_restrained: bool = mark.size.x <= 10.0 or mark.size.y <= 8.0
					_expect(stays_restrained, "TitlePage distress mark %s should stay thin enough to preserve the baked wordmark" % mark_name, failures)
		if enter_button != null:
			_expect(enter_button.text == "", "TitlePage full-screen interaction surface should remain text-free", failures)
			_expect(enter_button.flat, "TitlePage interaction surface should remain visually transparent", failures)
			_expect(enter_button.accessibility_name.contains("Blood Will Pay"), "TitlePage should expose the renamed title to assistive technology", failures)
			_expect(enter_button.accessibility_description.contains("click anywhere"), "TitlePage should retain non-visual entry instructions for assistive technology", failures)
			_expect(enter_button.has_focus(), "TitlePage interaction surface should receive initial focus", failures)
			enter_button.emit_signal("pressed")
			await get_tree().process_frame
			await get_tree().process_frame
		_expect(title_menu.visible, "TitleMenu is not visible after entering from title page", failures)
		_expect_command_chrome_visible(title_menu, "Title-page dismissal", failures)
		var expected_focus: Control = main.get_node_or_null("TitleMenu/Center/VBox/ContinueRunButton") as Control
		if expected_focus == null or not expected_focus.visible:
			expected_focus = main.get_node_or_null("TitleMenu/Center/VBox/StartButton") as Control
		_expect(expected_focus != null and expected_focus.has_focus(), "TitlePage dismissal should hand focus to the main menu", failures)
		main.call("_show_title_page")
		await get_tree().process_frame
		var key_event: InputEventKey = InputEventKey.new()
		key_event.pressed = true
		key_event.keycode = KEY_ENTER
		main.call("_unhandled_input", key_event)
		await get_tree().process_frame
		_expect(title_menu.visible, "Keyboard input should dismiss the title page", failures)
		main.call("_show_title_page")
		await get_tree().process_frame
		var joy_event: InputEventJoypadButton = InputEventJoypadButton.new()
		joy_event.pressed = true
		joy_event.button_index = JOY_BUTTON_A
		main.call("_unhandled_input", joy_event)
		await get_tree().process_frame
		_expect(title_menu.visible, "Controller input should dismiss the title page", failures)
		var title_label: Label = title_menu.get_node_or_null("Center/VBox/GameTitle") as Label
		_expect(title_label != null, "GameTitle missing", failures)
		if title_label != null:
			var normalized_title: String = title_label.text.replace("\n", " ").strip_edges().to_lower()
			_expect(normalized_title == "blood will pay", "GameTitle should use the new game name", failures)
			_expect(title_label.get_theme_font_size("font_size") >= 54, "GameTitle is not visually prioritized", failures)
			_expect(title_label.horizontal_alignment == HORIZONTAL_ALIGNMENT_LEFT, "GameTitle should use an asymmetric field-record alignment", failures)
			_expect(title_label.get_theme_constant("outline_size") <= 2, "GameTitle should avoid a glossy poster-style outline", failures)
		var subtitle: Label = title_menu.get_node_or_null("Center/VBox/Subtitle") as Label
		_expect(subtitle != null and subtitle.text == "Their lives. Your odds.", "Title menu should use the new tagline", failures)
		var title_record_mark: Label = title_menu.get_node_or_null("Center/VBox/TitleRecordMark") as Label
		_expect(title_record_mark != null and title_record_mark.text == "FIELD RECORD 01 // DEBT OUTSTANDING", "Title rail should bridge into an in-world field record", failures)
		_expect(title_record_mark != null and title_record_mark.get_theme_font_size("font_size") >= 17, "Title record mark should remain functional-size copy", failures)
		var consequence_mark: Label = title_menu.get_node_or_null("Center/VBox/WarDebtConsequenceMark") as Label
		_expect(consequence_mark != null and consequence_mark.text.contains("BWP CASUALTY OFFICE"), "Title rail should name the Blood Will Pay casualty institution", failures)
		var misregister: Label = title_menu.get_node_or_null("Center/VBox/GameTitle/Misregister") as Label
		var strike_band: ColorRect = title_menu.get_node_or_null("Center/VBox/GameTitle/StrikeBand") as ColorRect
		_expect(misregister != null and misregister.text == title_label.text, "GameTitle should expose a misregistered duplicate impression", failures)
		_expect(strike_band != null and strike_band.color.a >= 0.75, "GameTitle should carry a visible struck-through treatment", failures)
		var threat_signal: Label = title_menu.get_node_or_null("ImmediateThreatSignal") as Label
		_expect(threat_signal != null and threat_signal.text.contains("CONTACT MOVING"), "Command menu should expose an immediate authored danger signal", failures)
		var action_docket: Label = title_menu.get_node_or_null("Center/VBox/ActionDocket") as Label
		_expect(action_docket != null and action_docket.visible and action_docket.text.contains("ENTER THE INTAKE"), "Desktop command rail should expose an authored active-order docket", failures)
		_expect(action_docket != null and action_docket.get_theme_font_size("font_size") >= 16, "Command-rail action docket should use readable utility type", failures)
		var hero: TextureRect = title_menu.get_node_or_null("TitleHero") as TextureRect
		_expect(hero == null, "TitleHero should not render a background unit over the menu", failures)
		var content_panel: PanelContainer = title_menu.get_node_or_null("ContentPanel") as PanelContainer
		_expect(content_panel != null, "ContentPanel missing", failures)
		if content_panel != null:
			var content_style: StyleBox = content_panel.get_theme_stylebox("panel")
			_expect(content_style is StyleBoxFlat, "ContentPanel should use the authored hardcore document surface", failures)
			if content_style is StyleBoxFlat:
				var content_flat: StyleBoxFlat = content_style as StyleBoxFlat
				_expect(content_flat.bg_color.a < 0.86, "ContentPanel should leave the horror environment visible beneath the record", failures)
				_expect(content_flat.border_width_top > 0 and content_flat.border_width_left == 0 and content_flat.border_width_right == 0 and content_flat.border_width_bottom == 0, "ContentPanel should use one asymmetrical document edge instead of a uniform dashboard frame", failures)
		var title_panel: Panel = title_menu.get_node_or_null("TitlePanel") as Panel
		_expect(title_panel != null, "TitlePanel missing", failures)
		if title_panel != null:
			var rail_style: StyleBox = title_panel.get_theme_stylebox("panel")
			_expect(rail_style is StyleBoxFlat, "TitlePanel should use an authored field-record rail", failures)
			if rail_style is StyleBoxFlat:
				var rail_flat: StyleBoxFlat = rail_style as StyleBoxFlat
				_expect(rail_flat.border_width_left > rail_flat.border_width_right, "TitlePanel should keep an asymmetric blood edge", failures)
		var registration_mark: Label = title_menu.get_node_or_null("ContentPanel/Margin/Stack/Header/ConstructionRule/RegistrationMark") as Label
		_expect(registration_mark != null and registration_mark.text == "FIELD ORDER // NO RETREAT", "Command shell should use in-world war-horror registration copy", failures)
		var copy_index: Label = title_menu.get_node_or_null("ContentPanel/Margin/Stack/Header/ConstructionRule/CopyIndex") as Label
		_expect(copy_index != null and copy_index.text == "COPY 01 / 01", "Command shell should expose a bounded field-record copy index", failures)
		var backing: Panel = title_menu.get_node_or_null("ContentRecordBacking") as Panel
		var fasteners: Label = title_menu.get_node_or_null("ContentFasteners") as Label
		_expect(backing != null and backing.z_index < content_panel.z_index, "Command shell should retain a visible rear document layer", failures)
		_expect(fasteners != null and fasteners.text == "O\nO", "Command shell should expose an anchored binding treatment", failures)
		_expect(_find_label_containing_text(title_menu, "CUT // PASTE // SURVIVE") == null, "Command shell should not advertise its collage technique", failures)
		_expect(_find_label_containing_text(title_menu, "FIELD ORDER // FIRST BLOOD") != null, "Home screen should present a dominant issued order", failures)
		var initial_home_search: LineEdit = title_menu.get_node_or_null("ContentPanel/Margin/Stack/Header/SearchField") as LineEdit
		_expect(initial_home_search != null and initial_home_search.text == "", "Home search should start empty before rendering its order (found '%s')" % (initial_home_search.text if initial_home_search != null else "<missing>"), failures)
		var opening_order: PanelContainer = title_menu.get_node_or_null("ContentPanel/Margin/Stack/ContentScroll/ContentBody/OpeningOrder") as PanelContainer
		var route_manifest: VBoxContainer = title_menu.get_node_or_null("ContentPanel/Margin/Stack/ContentScroll/ContentBody/HomeRouteManifest") as VBoxContainer
		_expect(opening_order != null, "Home screen should expose one dominant opening order", failures)
		_expect(route_manifest != null, "Home screen should replace equal dashboard cards with a route manifest", failures)
		_expect(title_menu.find_child("HomeRouteGrid", true, false) == null, "Home screen should not rebuild the equal-card dashboard grid", failures)
		if route_manifest != null:
			var manifest_width: float = route_manifest.size.x
			for record_number: String in ["01", "02", "03", "04"]:
				var route: Button = route_manifest.get_node_or_null("ManifestRoute%s" % record_number) as Button
				_expect(route != null, "Available Records should expose joined row %s" % record_number, failures)
				if route != null:
					var bound_copy: HBoxContainer = route.get_node_or_null("BoundCopy") as HBoxContainer
					var serial: Label = route.get_node_or_null("BoundCopy/Serial") as Label
					var record_title: Label = route.get_node_or_null("BoundCopy/RecordCopy/RecordTitle") as Label
					var record_description: Label = route.get_node_or_null("BoundCopy/RecordCopy/RecordDescription") as Label
					_expect(route.size.x >= manifest_width - 2.0, "Record %s should fill the manifest width" % record_number, failures)
					_expect(bound_copy != null and serial != null and record_title != null and record_description != null, "Record %s should bind serial, title, and description in one focusable row" % record_number, failures)
					_expect_stylebox_flat(route, "focus", "Record %s should expose a persistent focus surface" % record_number, failures)
			var first_route: Button = route_manifest.get_node_or_null("ManifestRoute01") as Button
			if first_route != null:
				var route_focus: StyleBoxFlat = first_route.get_theme_stylebox("focus") as StyleBoxFlat
				var route_pressed: StyleBoxFlat = first_route.get_theme_stylebox("pressed") as StyleBoxFlat
				_expect(route_focus != null and route_pressed != null and route_focus.border_color != route_pressed.border_color, "Record focus must remain distinct from the blood pressed state", failures)
		var search_field: LineEdit = title_menu.get_node_or_null("ContentPanel/Margin/Stack/Header/SearchField") as LineEdit
		_expect(search_field != null, "SearchField missing", failures)
		if search_field != null:
			_expect_stylebox_flat(search_field, "normal", "SearchField normal should use the authored paper-input styling", failures)
			_expect_stylebox_flat(search_field, "focus", "SearchField focus should use the authored paper-input styling", failures)
		var how_to_play_button: Button = title_menu.get_node_or_null("Center/VBox/HowToPlayButton") as Button
		var units_button: Button = title_menu.get_node_or_null("Center/VBox/UnitsButton") as Button
		var rga_button: Button = title_menu.get_node_or_null("Center/VBox/RGAGlossaryButton") as Button
		var settings_button: Button = title_menu.get_node_or_null("Center/VBox/SettingsButton") as Button
		_expect(how_to_play_button != null, "HowToPlayButton missing", failures)
		_expect(units_button != null, "UnitsButton missing", failures)
		_expect(rga_button != null, "RGAGlossaryButton missing", failures)
		_expect(settings_button != null, "SettingsButton missing", failures)
		var persistent_actions: Array[Button] = [how_to_play_button, units_button, rga_button, settings_button]
		for persistent_action: Button in persistent_actions:
			_expect(persistent_action != null and persistent_action.modulate.a >= 0.99, "First command-menu state should keep every navigation route visibly available", failures)
		_expect_button_states(how_to_play_button, "HowToPlayButton", failures)
		_expect_button_states(units_button, "UnitsButton", failures)
		_expect_button_states(rga_button, "RGAGlossaryButton", failures)
		_expect_button_states(settings_button, "SettingsButton", failures)
		if units_button != null and search_field != null:
			units_button.emit_signal("pressed")
			await get_tree().process_frame
			search_field.text = "hexeon"
			search_field.emit_signal("text_changed", "hexeon")
			await get_tree().process_frame
			_expect(_find_label_containing_text(title_menu, "Hexeon") != null, "Unit search did not find Hexeon", failures)
			_expect(_find_label_containing_text(title_menu, "Prismatic Guillotine") != null, "Unit card did not show ability info", failures)
			_expect(_find_label_containing_text(title_menu, "Attack Targeting:") != null, "Unit card did not show attack targeting", failures)
			_expect(_find_label_containing_text(title_menu, "Ability Targeting:") != null, "Unit card did not show ability targeting", failures)
			_expect(_find_label_containing_text(title_menu, "Positioning:") == null, "Unit card should not prescribe positioning", failures)
			_expect_content_panels_generated(title_menu, "Units page cards should use generated texture styling", failures)
		if rga_button != null and search_field != null:
			rga_button.emit_signal("pressed")
			await get_tree().process_frame
			search_field.text = "threshold"
			search_field.emit_signal("text_changed", "threshold")
			await get_tree().process_frame
			_expect(_find_label_containing_text(title_menu, "Active Trait") != null, "Combat terms search did not expose player-facing trait terminology", failures)
			_expect(_find_label_containing_text(title_menu, "PASS / LEAN / FAIL") == null, "Combat terms should not expose backend verdict terminology", failures)
			_expect_content_panels_generated(title_menu, "RGA cards should use generated texture styling", failures)
			search_field.text = "definitely-no-such-combat-term"
			search_field.emit_signal("text_changed", "definitely-no-such-combat-term")
			await get_tree().process_frame
			_expect(_find_label_containing_text(title_menu, "Nothing Found") != null, "Combat terms unmatched search should explain the empty state", failures)
			_expect(_find_label_containing_text(title_menu, "clear the search") != null, "Combat terms empty state should provide recovery guidance", failures)
			var clear_search_button: Button = title_menu.find_child("ClearSearchButton", true, false) as Button
			_expect(clear_search_button != null, "Combat terms empty state should expose Clear Search", failures)
			if clear_search_button != null:
				clear_search_button.emit_signal("pressed")
				await get_tree().process_frame
				_expect(search_field.text == "", "Clear Search should reset the query", failures)
				_expect(_find_label_containing_text(title_menu, "Role") != null, "Clear Search should restore combat terms", failures)
		if how_to_play_button != null and search_field != null:
			how_to_play_button.emit_signal("pressed")
			await get_tree().process_frame
			search_field.text = "combine"
			search_field.emit_signal("text_changed", "combine")
			await get_tree().process_frame
			_expect(_find_label_containing_text(title_menu, "combine into a stronger copy") != null, "Tutorial search did not expose combine guidance", failures)
			_expect(_find_label_containing_text(title_menu, "up to level 4") != null, "Tutorial should explain the current level-4 cap", failures)
			_expect(_find_label_containing_text(title_menu, "up to level 3") == null, "Tutorial should not teach the retired level-3 cap", failures)
			search_field.text = "contract"
			search_field.emit_signal("text_changed", "contract")
			await get_tree().process_frame
			_expect(_find_label_containing_text(title_menu, "PRICE, REWARD, RISK, and NEXT FIGHT") != null, "Tutorial should explain chapter-contract decision fields", failures)
			search_field.text = "board slots"
			search_field.emit_signal("text_changed", "board slots")
			await get_tree().process_frame
			_expect(_find_label_containing_text(title_menu, "add board slots") != null, "Tutorial should explain that Buy XP adds board slots", failures)
			var content_scroll: ScrollContainer = title_menu.find_child("ContentScroll", true, false) as ScrollContainer
			if content_scroll != null and units_button != null:
				content_scroll.scroll_vertical = 400
				units_button.emit_signal("pressed")
				await get_tree().process_frame
				how_to_play_button.emit_signal("pressed")
				await get_tree().process_frame
				await get_tree().process_frame
				_expect(content_scroll.scroll_vertical == 0, "How to Play should reopen at the beginning", failures)
			_expect_content_panels_generated(title_menu, "How To Play cards should use generated texture styling", failures)
		if settings_button != null:
			settings_button.emit_signal("pressed")
			_expect_command_chrome_visible(title_menu, "Settings transition immediate frame", failures)
			await get_tree().process_frame
			_expect_command_chrome_visible(title_menu, "Settings transition settled frame", failures)
			_expect(bool(settings_button.get_meta("active_page", false)), "Settings should retain a persistent active-page state", failures)
			_expect(settings_button.text.begins_with("ACTIVE //"), "Settings active-page state should be visible in its label", failures)
			var settings_pressed_style: StyleBoxFlat = settings_button.get_theme_stylebox("pressed") as StyleBoxFlat
			var settings_focus_style: StyleBoxFlat = settings_button.get_theme_stylebox("focus") as StyleBoxFlat
			_expect(settings_pressed_style != null and settings_focus_style != null, "Settings should expose authored active and keyboard-focus surfaces", failures)
			if settings_pressed_style != null and settings_focus_style != null:
				_expect(settings_pressed_style.border_color != settings_focus_style.border_color, "Settings active-page state should remain distinct from keyboard focus", failures)
				_expect(settings_focus_style.border_color.b > settings_focus_style.border_color.r, "Settings keyboard focus should use the non-red signal-blue channel", failures)
			var settings_docket: PanelContainer = title_menu.find_child("SettingsDocket", true, false) as PanelContainer
			var settings_docket_title: Label = title_menu.find_child("SettingsDocketTitle", true, false) as Label
			_expect(settings_docket != null and settings_docket_title != null and settings_docket_title.text.contains("ACTIVE PAGE"), "Settings should open as a joined local-machine field record", failures)
			var volume_slider: HSlider = title_menu.find_child("MasterVolumeSlider", true, false) as HSlider
			_expect(volume_slider != null, "Settings did not expose master volume slider", failures)
			if volume_slider != null:
				_expect_stylebox_flat(volume_slider, "slider", "MasterVolumeSlider track should use the authored hardcore styling", failures)
				_expect_stylebox_flat(volume_slider, "grabber_area", "MasterVolumeSlider filled area should use the authored blood-fill styling", failures)
			var fullscreen_check: CheckBox = title_menu.find_child("FullscreenCheck", true, false) as CheckBox
			var motion_check: CheckBox = title_menu.find_child("ReducedMotionCheck", true, false) as CheckBox
			var ui_scale_option: OptionButton = title_menu.find_child("UIScaleOption", true, false) as OptionButton
			var readability_setting: PanelContainer = title_menu.find_child("ReadabilitySetting", true, false) as PanelContainer
			var readability_status: Label = title_menu.find_child("ReadabilityStatus", true, false) as Label
			var scale_guidance: Label = title_menu.find_child("UIScaleGuidance", true, false) as Label
			var accept_binding: Button = title_menu.find_child("Binding_ui_accept", true, false) as Button
			var cancel_binding: Button = title_menu.find_child("Binding_ui_cancel", true, false) as Button
			var reset_bindings: Button = title_menu.find_child("ResetBindingsButton", true, false) as Button
			_expect(fullscreen_check != null, "FullscreenCheck missing", failures)
			_expect(motion_check != null, "Settings should expose Reduced Motion", failures)
			_expect(ui_scale_option != null and ui_scale_option.item_count == 3, "Settings should expose three supported UI scales", failures)
			_expect(readability_setting != null, "Settings should expose a visible readability and contrast record", failures)
			_expect(readability_status != null and readability_status.text.contains("HIGH CONTRAST"), "Settings should state the enforced high-contrast default", failures)
			_expect(readability_status != null and readability_status.get_theme_font_size("font_size") >= 18, "Readability status should remain functional-size copy", failures)
			_expect(scale_guidance != null and not scale_guidance.text.contains("every supported scale"), "UI scale guidance should avoid an unbounded responsiveness claim", failures)
			_expect(accept_binding != null, "Settings should expose Confirm remapping", failures)
			_expect(cancel_binding != null, "Settings should expose Menu / Back remapping", failures)
			_expect(reset_bindings != null, "Settings should expose binding reset", failures)
			_expect_flat_button_states(fullscreen_check, "FullscreenCheck", failures)
			_expect_flat_button_states(motion_check, "ReducedMotionCheck", failures)
		var start_button: Button = title_menu.get_node_or_null("Center/VBox/StartButton") as Button
		_expect(start_button != null, "StartButton missing", failures)
		if start_button != null:
			var stateful_start_copy: String = String(start_button.text)
			start_button.text = "New Run"
			title_menu.call("_build_navigation")
			_expect(String(start_button.text) == "New Run", "Title menu navigation rebuild should preserve the save-aware New Run label", failures)
			start_button.text = stateful_start_copy
			var continue_button: Button = title_menu.find_child("ContinueRunButton", true, false) as Button
			var continue_is_primary: bool = continue_button != null and continue_button.visible
			var primary_run_button: Button = continue_button if continue_is_primary else start_button
			_expect(primary_run_button.visible and primary_run_button.modulate.a >= 0.99, "First command-menu state should expose its primary run route without waiting for the intro sequence", failures)
			_expect(primary_run_button.text == ("Continue Run" if continue_is_primary else "New Run"), "Primary command route should use an unmistakable run action label", failures)
			_expect(
				String(start_button.get_meta("visual_role", "")) == ("secondary" if continue_is_primary else "primary"),
				"StartButton hierarchy should follow whether Continue Run is the primary action",
				failures
			)
			if continue_is_primary:
				_expect(String(continue_button.get_meta("visual_role", "")) == "primary", "Continue Run should own the primary hierarchy role", failures)
			else:
				_expect(start_button.custom_minimum_size.x >= 300.0, "StartButton is not visually prioritized without a resumable run", failures)
			var start_style: StyleBox = start_button.get_theme_stylebox("normal")
			_expect(start_style is StyleBoxTexture, "Title StartButton should use generated hierarchy styling", failures)
			var ledger_button: Button = title_menu.find_child("BlackLedgerButton", true, false) as Button
			var quit_button: Button = title_menu.find_child("QuitButton", true, false) as Button
			_expect(ledger_button != null and String(ledger_button.get_meta("visual_role", "")) == "ledger", "Black Ledger should use a distinct ledger hierarchy role", failures)
			_expect(quit_button != null and String(quit_button.get_meta("visual_role", "")) == "quit", "Quit should use a distinct destructive hierarchy role", failures)
			_expect(settings_button != null and String(settings_button.get_meta("visual_role", "")).contains("navigation"), "Settings should remain in the navigation hierarchy", failures)
			start_button.emit_signal("pressed")
			await get_tree().process_frame
			var unit_select: Control = main.get_node_or_null("UnitSelect") as Control
			_expect(unit_select != null and unit_select.visible, "StartButton did not open UnitSelect", failures)

	if failures.size() > 0:
		remove_child(main)
		main.free()
		await get_tree().process_frame
		for failure: String in failures:
			push_error("TitleMenuSmoke: " + failure)
		get_tree().quit(1)
		return

	remove_child(main)
	main.free()
	await get_tree().process_frame
	print("TitleMenuSmoke: OK")
	get_tree().quit(0)

func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)

func _expect_command_chrome_visible(title_menu: Control, context: String, failures: Array[String]) -> void:
	var title_panel: Panel = title_menu.get_node_or_null("TitlePanel") as Panel
	var content_panel: PanelContainer = title_menu.get_node_or_null("ContentPanel") as PanelContainer
	var title_label: Label = title_menu.get_node_or_null("Center/VBox/GameTitle") as Label
	var section_title: Label = title_menu.find_child("SectionTitle", true, false) as Label
	var settings_button: Button = title_menu.get_node_or_null("Center/VBox/SettingsButton") as Button
	_expect(title_panel != null and title_panel.visible and title_panel.modulate.a >= 0.99, "%s should keep the command rail visible" % context, failures)
	_expect(content_panel != null and content_panel.visible and content_panel.modulate.a >= 0.99, "%s should keep the command record visible" % context, failures)
	_expect(title_label != null and title_label.visible and title_label.modulate.a >= 0.99 and title_label.text.strip_edges() != "", "%s should keep the title label visible" % context, failures)
	_expect(section_title != null and section_title.visible and section_title.modulate.a >= 0.99 and section_title.text.strip_edges() != "", "%s should keep the active record label visible" % context, failures)
	_expect(settings_button != null and settings_button.visible and settings_button.modulate.a >= 0.99 and settings_button.text.strip_edges() != "", "%s should keep the Settings route visible" % context, failures)

func _expect_content_panels_generated(title_menu: Control, message: String, failures: Array[String]) -> void:
	var body: Control = null
	if title_menu != null:
		body = title_menu.get_node_or_null("ContentPanel/Margin/Stack/ContentScroll/ContentBody") as Control
	_expect(body != null, "ContentBody missing", failures)
	if body == null:
		return
	var panel_count: int = 0
	for node: Node in body.find_children("*", "PanelContainer", true, false):
		var panel: PanelContainer = node as PanelContainer
		if panel == null:
			continue
		panel_count += 1
		_expect_stylebox_authored(panel, "panel", "%s: %s" % [message, str(panel.name)], failures)
	_expect(panel_count > 0, message, failures)

func _expect_button_states(button: Button, label: String, failures: Array[String]) -> void:
	_expect(button != null, "%s missing" % label, failures)
	if button == null:
		return
	var states: Array[String] = ["normal", "hover", "pressed", "focus"]
	for state: String in states:
		_expect_stylebox_flat(button, state, "%s %s should use asymmetrical field-navigation styling" % [label, state], failures)

func _expect_flat_button_states(button: Button, label: String, failures: Array[String]) -> void:
	_expect(button != null, "%s missing" % label, failures)
	if button == null:
		return
	var states: Array[String] = ["normal", "hover", "pressed", "focus"]
	for state: String in states:
		_expect_stylebox_flat(button, state, "%s %s should use authored hardcore styling" % [label, state], failures)

func _expect_stylebox_texture(control: Control, style_name: String, message: String, failures: Array[String]) -> void:
	_expect(control != null, message, failures)
	if control == null:
		return
	var style: StyleBox = control.get_theme_stylebox(style_name)
	_expect(style is StyleBoxTexture, message, failures)

func _expect_stylebox_flat(control: Control, style_name: String, message: String, failures: Array[String]) -> void:
	_expect(control != null, message, failures)
	if control == null:
		return
	var style: StyleBox = control.get_theme_stylebox(style_name)
	_expect(style is StyleBoxFlat, message, failures)
	if style is StyleBoxFlat:
		var flat_style: StyleBoxFlat = style as StyleBoxFlat
		var border_recorded: bool = flat_style.border_width_left > 0 or flat_style.border_width_top > 0 or flat_style.border_width_right > 0 or flat_style.border_width_bottom > 0
		_expect(border_recorded, "%s should retain a visible authored edge" % message, failures)

func _expect_stylebox_authored(control: Control, style_name: String, message: String, failures: Array[String]) -> void:
	_expect(control != null, message, failures)
	if control == null:
		return
	var style: StyleBox = control.get_theme_stylebox(style_name)
	var authored: bool = style is StyleBoxTexture or style is StyleBoxFlat
	_expect(authored, message, failures)
	if style is StyleBoxFlat:
		var flat_style: StyleBoxFlat = style as StyleBoxFlat
		var border_recorded: bool = flat_style.border_width_left > 0 or flat_style.border_width_top > 0 or flat_style.border_width_right > 0 or flat_style.border_width_bottom > 0
		_expect(border_recorded, "%s should retain a visible authored edge" % message, failures)

func _find_label_containing_text(root: Node, needle: String) -> Label:
	if root == null:
		return null
	var label: Label = root as Label
	if label != null and String(label.text).contains(needle):
		return label
	for child: Node in root.get_children():
		var found: Label = _find_label_containing_text(child, needle)
		if found != null:
			return found
	return null

func _rect_inside(inner: Rect2, outer: Rect2) -> bool:
	return outer.has_point(inner.position) and outer.has_point(inner.end)

func _find_visible_label(root: Node) -> Label:
	if root == null:
		return null
	var label: Label = root as Label
	if label != null and label.visible and label.text.strip_edges() != "":
		return label
	for child: Node in root.get_children():
		var found: Label = _find_visible_label(child)
		if found != null:
			return found
	return null
