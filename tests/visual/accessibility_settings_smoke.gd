extends Node

const SMOKE_NAME: String = "AccessibilitySettingsSmoke"
const MAIN_SCENE: PackedScene = preload("res://scenes/Main.tscn")
const UserSettingsScript: GDScript = preload("res://scripts/game/settings/user_settings.gd")
const TEST_SETTINGS_PATH: String = "user://accessibility_settings_smoke.cfg"
const TEST_ACCOUNT_PROFILE_PATH: String = "user://accessibility_settings_account_profile.json"
const OUTPUT_DIR: String = "res://outputs/visual_iter/accessibility_settings_pass"
const STRESS_VIEWPORT_SIZE: Vector2i = Vector2i(1024, 576)

@export var viewport_size: Vector2i = Vector2i(1280, 720)

var _main: Control = null
var _failures: Array[String] = []
var _original_scale: float = 1.0
var _original_window_size: Vector2i = Vector2i.ZERO
var _original_accept_events: Array[InputEvent] = []
var _original_cancel_events: Array[InputEvent] = []

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var window: Window = get_window()
	_original_scale = window.content_scale_factor if window != null else 1.0
	_original_window_size = window.size if window != null else Vector2i.ZERO
	DisplayServer.window_set_size(viewport_size)
	if window != null:
		window.size = viewport_size
		window.content_scale_size = viewport_size
	_original_accept_events = _copy_events(&"ui_accept")
	_original_cancel_events = _copy_events(&"ui_cancel")
	_remove_test_settings()
	UserSettingsScript.configure_storage_path(TEST_SETTINGS_PATH)
	UserSettingsScript.initialize(window)
	var defaults_error: Error = UserSettingsScript.reset_input_defaults()
	_expect(defaults_error == OK, "default bindings should save to the isolated test config")
	_expect(_has_joypad_button(&"ui_accept", JOY_BUTTON_A), "Confirm defaults should include controller A")
	_expect(_has_joypad_button(&"ui_cancel", JOY_BUTTON_B), "Menu / Back defaults should include controller B")

	_main = MAIN_SCENE.instantiate() as Control
	get_tree().root.add_child(_main)
	await _settle_frames(6)
	var enter_button: Button = _main.get_node_or_null("TitlePage/Center/Stack/EnterButton") as Button
	_expect(enter_button != null, "title page enter button missing")
	if enter_button != null:
		enter_button.pressed.emit()
	await _settle_frames(4)
	var title_menu: Control = _main.get_node_or_null("TitleMenu") as Control
	var settings_button: Button = _main.get_node_or_null("TitleMenu/Center/VBox/SettingsButton") as Button
	_expect(title_menu != null and title_menu.visible, "title menu missing after entering")
	_expect(settings_button != null, "settings navigation button missing")
	if settings_button != null:
		settings_button.pressed.emit()
	await _settle_frames(3)

	var scale_option: OptionButton = title_menu.find_child("UIScaleOption", true, false) as OptionButton if title_menu != null else null
	var motion_check: CheckBox = title_menu.find_child("ReducedMotionCheck", true, false) as CheckBox if title_menu != null else null
	var accept_button: Button = title_menu.find_child("Binding_ui_accept", true, false) as Button if title_menu != null else null
	var cancel_button: Button = title_menu.find_child("Binding_ui_cancel", true, false) as Button if title_menu != null else null
	var reset_button: Button = title_menu.find_child("ResetBindingsButton", true, false) as Button if title_menu != null else null
	var readability_status: Label = title_menu.find_child("ReadabilityStatus", true, false) as Label if title_menu != null else null
	var readability_guidance: Label = title_menu.find_child("ReadabilityGuidance", true, false) as Label if title_menu != null else null
	_expect(scale_option != null, "UI scale option missing")
	_expect(motion_check != null, "Reduced Motion option missing")
	_expect(accept_button != null, "Confirm binding button missing")
	_expect(cancel_button != null, "Menu / Back binding button missing")
	_expect(reset_button != null, "Reset Defaults button missing")
	_expect(readability_status != null and readability_status.text.contains("HIGH CONTRAST"), "Settings should expose the enforced high-contrast readability default")
	_expect(readability_status != null and int(readability_status.get_meta("utility_type_floor_px", 0)) >= 15, "Settings should publish a 15px utility typography floor")
	_expect(readability_status != null and int(readability_status.get_meta("functional_type_floor_px", 0)) >= 16, "Settings should publish a 16px functional typography floor")
	_expect(readability_guidance != null and readability_guidance.get_theme_font_size("font_size") >= 18, "Readability guidance should use legible utility typography")

	if scale_option != null:
		scale_option.select(1)
		scale_option.item_selected.emit(1)
	await _settle_frames(2)
	_expect(is_equal_approx(UserSettingsScript.get_ui_scale(), 1.25), "UI scale should update to 125 percent")
	if window != null:
		_expect(is_equal_approx(window.content_scale_factor, 1.25), "window content scale should update immediately")
	scale_option = title_menu.find_child("UIScaleOption", true, false) as OptionButton if title_menu != null else null
	if scale_option != null:
		scale_option.select(2)
		scale_option.item_selected.emit(2)
	await _settle_frames(4)
	_expect(is_equal_approx(UserSettingsScript.get_ui_scale(), 1.5), "UI scale should update to the supported 150 percent maximum")
	if window != null:
		_expect(is_equal_approx(window.content_scale_factor, 1.5), "window content scale should apply the 150 percent maximum immediately")
	scale_option = title_menu.find_child("UIScaleOption", true, false) as OptionButton if title_menu != null else null
	motion_check = title_menu.find_child("ReducedMotionCheck", true, false) as CheckBox if title_menu != null else null
	var content_panel: Control = title_menu.find_child("ContentPanel", true, false) as Control if title_menu != null else null
	var content_scroll: ScrollContainer = title_menu.find_child("ContentScroll", true, false) as ScrollContainer if title_menu != null else null
	var accessibility_priority: PanelContainer = title_menu.find_child("AccessibilityPriority", true, false) as PanelContainer if title_menu != null else null
	var volume_setting: PanelContainer = title_menu.find_child("VolumeSetting", true, false) as PanelContainer if title_menu != null else null
	var viewport_rect: Rect2 = title_menu.get_viewport().get_visible_rect() if title_menu != null else Rect2()
	_expect(
		content_panel != null and _rect_inside(content_panel.get_global_rect(), viewport_rect.grow(2.0)),
		"150 percent settings panel should remain inside the %dx%d viewport panel=%s viewport=%s"
		% [viewport_size.x, viewport_size.y, str(content_panel.get_global_rect() if content_panel != null else Rect2()), str(viewport_rect)]
	)
	var settings_visible_rect: Rect2 = content_scroll.get_global_rect() if content_scroll != null else Rect2()
	_expect(accessibility_priority != null and bool(accessibility_priority.get_meta("pinned_settings_block", false)), "Settings should expose an intentional first-response accessibility block")
	_expect(accessibility_priority != null and _rect_inside(accessibility_priority.get_global_rect(), settings_visible_rect.grow(2.0)), "150 percent accessibility priority banner should be visible without scrolling")
	_expect(scale_option != null and _rect_inside(scale_option.get_global_rect(), settings_visible_rect.grow(2.0)), "150 percent UI Scale should be immediately discoverable without scrolling")
	_expect(motion_check != null and _rect_inside(motion_check.get_global_rect(), settings_visible_rect.grow(2.0)), "150 percent Reduced Motion should be immediately discoverable without scrolling")
	_expect(volume_setting != null and scale_option != null and scale_option.get_global_rect().position.y < volume_setting.get_global_rect().position.y, "Accessibility controls should precede secondary volume settings")
	_save_capture("00_accessibility_first_1280x720_150.png")
	for control_name: String in [
		"GameTitle",
		"StartButton",
		"BlackLedgerButton",
		"HomeButton",
		"HowToPlayButton",
		"UnitsButton",
		"RGAGlossaryButton",
		"SettingsButton",
		"QuitButton",
	]:
		var navigation_control: Control = title_menu.find_child(control_name, true, false) as Control if title_menu != null else null
		_expect(
			navigation_control != null and _rect_inside(navigation_control.get_global_rect(), viewport_rect.grow(2.0)),
			"150 percent title control %s should remain inside the %dx%d viewport rect=%s viewport=%s"
			% [control_name, viewport_size.x, viewport_size.y, str(navigation_control.get_global_rect() if navigation_control != null else Rect2()), str(viewport_rect)]
		)
	if title_menu != null:
		title_menu.call("_select_section", "home", true)
	await _settle_frames(4)
	_expect(
		title_menu != null and is_equal_approx(float(title_menu.call("_actual_ui_scale")), 1.5),
		"command menu should detect the persisted/window 150 percent scale"
	)
	var route_manifest: VBoxContainer = title_menu.find_child("HomeRouteManifest", true, false) as VBoxContainer if title_menu != null else null
	_expect(route_manifest != null, "150 percent command menu should expose the Available Records manifest")
	if route_manifest != null:
		_expect_manifest_rows_readable(route_manifest, "150 percent command menu")
	if _main != null:
		_main.call("open_black_ledger", TEST_ACCOUNT_PROFILE_PATH)
	await _settle_frames(3)
	var ledger: Control = _main.find_child("BlackLedger", true, false) as Control if _main != null else null
	var ledger_panel: PanelContainer = ledger.find_child("LedgerPanel", true, false) as PanelContainer if ledger != null else null
	var ledger_progress: Label = ledger.find_child("ProgressMetadata", true, false) as Label if ledger != null else null
	var ledger_viewport: Rect2 = ledger.get_viewport().get_visible_rect() if ledger != null else Rect2()
	_expect(
		ledger_panel != null and _rect_inside(ledger_panel.get_global_rect(), ledger_viewport.grow(2.0)),
		"150 percent Black Ledger should remain inside the %dx%d viewport panel=%s viewport=%s"
		% [viewport_size.x, viewport_size.y, str(ledger_panel.get_global_rect() if ledger_panel != null else Rect2()), str(ledger_viewport)]
	)
	_expect(ledger_progress != null and String(ledger_progress.get_meta("responsive_layout", "")) == "two_row", "150 percent Black Ledger should deliberately recompose progress metadata into two rows")
	var ledger_progress_rows: PackedStringArray = ledger_progress.text.split("\n") if ledger_progress != null else PackedStringArray()
	_expect(
		ledger_progress_rows.size() == 2
		and ledger_progress_rows[0].begins_with("LIFETIME OMENS ")
		and (ledger_progress_rows[1].begins_with("NEXT SEAL ") or ledger_progress_rows[1] == "ALL SEALS WITNESSED"),
		"150 percent Black Ledger should keep Lifetime Omens and Next Seal as complete nonbreaking rows"
	)
	var ledger_close: Button = ledger.find_child("*", true, false) as Button if ledger != null else null
	if ledger != null:
		for candidate: Node in ledger.find_children("*", "Button", true, false):
			var button_candidate: Button = candidate as Button
			if button_candidate != null and button_candidate.text.to_upper().begins_with("CLOSE"):
				ledger_close = button_candidate
				break
	_expect(
		ledger_close != null and _rect_inside(ledger_close.get_global_rect(), ledger_viewport.grow(2.0)),
		"150 percent Black Ledger Close button should remain visible"
	)
	if _main != null:
		_main.call("_close_black_ledger")
	await _settle_frames(2)
	await _verify_stress_menu(title_menu, window)
	motion_check = title_menu.find_child("ReducedMotionCheck", true, false) as CheckBox if title_menu != null else null
	reset_button = title_menu.find_child("ResetBindingsButton", true, false) as Button if title_menu != null else null
	if motion_check != null:
		motion_check.button_pressed = true
	await _settle_frames(2)
	_expect(UserSettingsScript.get_reduced_motion(), "Reduced Motion should update immediately")
	_expect(not bool(title_menu.get("_motion_enabled")), "Reduced Motion should stop title-menu animation")

	var remap_key: InputEventKey = _make_key(KEY_F6)
	var binding_status: Label = title_menu.find_child("BindingStatus", true, false) as Label if title_menu != null else null
	if title_menu != null:
		title_menu.call("_begin_binding_capture", &"ui_accept")
	await _settle_frames(2)
	_expect(binding_status != null and String(binding_status.text).contains("Press a key"), "binding listening state should explain the next action")
	_save_capture("01_binding_listening.png")
	if title_menu != null:
		title_menu.call("_input", remap_key)
	await _settle_frames(2)
	_expect(UserSettingsScript.binding_text(&"ui_accept").contains("F6"), "Confirm should accept an unused keyboard binding")
	_expect(binding_status != null and String(binding_status.text).contains("now bound"), "binding success state should confirm the new key")
	_save_capture("02_binding_success.png")
	if title_menu != null:
		title_menu.call("_begin_binding_capture", &"ui_cancel")
		title_menu.call("_input", remap_key)
	await _settle_frames(2)
	_expect(binding_status != null and String(binding_status.text).contains("already assigned"), "duplicate binding should show a visible conflict state")
	_save_capture("03_binding_conflict.png")
	_expect(_non_key_event_count(&"ui_accept") >= _non_key_count(_original_accept_events), "remapping Confirm should preserve its existing non-key events")
	_expect(_has_joypad_button(&"ui_accept", JOY_BUTTON_A), "remapping Confirm should preserve controller A")

	UserSettingsScript.configure_storage_path(TEST_SETTINGS_PATH)
	UserSettingsScript.initialize(window)
	_expect(UserSettingsScript.binding_text(&"ui_accept").contains("F6"), "Confirm remap should survive reload")
	_expect(is_equal_approx(UserSettingsScript.get_ui_scale(), 1.5), "maximum UI scale should survive reload")
	_expect(UserSettingsScript.get_reduced_motion(), "Reduced Motion should survive reload")

	if title_menu != null:
		title_menu.call("_begin_binding_capture", &"ui_cancel")
		title_menu.call("_input", _make_key(KEY_ESCAPE))
	_expect(UserSettingsScript.binding_text(&"ui_cancel").contains("Escape"), "Escape should cancel capture without replacing Menu / Back")

	if reset_button != null:
		reset_button.pressed.emit()
	await _settle_frames(1)
	_expect(UserSettingsScript.binding_text(&"ui_accept").contains("Enter"), "reset should restore Confirm to Enter")
	_expect(UserSettingsScript.binding_text(&"ui_cancel").contains("Escape"), "reset should restore Menu / Back to Escape")
	_expect(_has_joypad_button(&"ui_accept", JOY_BUTTON_A), "reset should preserve controller A")
	_expect(_has_joypad_button(&"ui_cancel", JOY_BUTTON_B), "reset should preserve controller B")
	var how_to_button: Button = title_menu.find_child("HowToPlayButton", true, false) as Button if title_menu != null else null
	_expect(how_to_button != null, "How To Play controller target missing")
	if how_to_button != null:
		how_to_button.grab_focus()
		await _settle_frames(1)
		_send_joypad_button(JOY_BUTTON_A, true)
		_send_joypad_button(JOY_BUTTON_A, false)
		await _settle_frames(4)
		_expect(String(title_menu.get("_active_section")) == "how_to_play", "controller A should activate the focused title-menu action")
	_finish()

func _verify_stress_menu(title_menu: Control, window: Window) -> void:
	DisplayServer.window_set_size(STRESS_VIEWPORT_SIZE)
	if window != null:
		window.size = STRESS_VIEWPORT_SIZE
		window.content_scale_size = STRESS_VIEWPORT_SIZE
	if title_menu != null:
		title_menu.call("_select_section", "settings", false)
		title_menu.call_deferred("_refresh_scaled_layout")
	await _settle_frames(5)
	var title_panel: Panel = title_menu.find_child("TitlePanel", true, false) as Panel if title_menu != null else null
	var quit_button: Button = title_menu.find_child("QuitButton", true, false) as Button if title_menu != null else null
	var stress_viewport: Rect2 = title_menu.get_viewport().get_visible_rect() if title_menu != null else Rect2()
	var stress_title: Label = title_menu.find_child("GameTitle", true, false) as Label if title_menu != null else null
	_expect(title_panel != null, "1024x576 stress menu TitlePanel missing")
	_expect(
		title_panel != null and _rect_inside(title_panel.get_global_rect(), stress_viewport.grow(1.0)),
		"1024x576 title rail should remain fully inside the physical viewport"
	)
	_expect(stress_title != null and not stress_title.text.contains("\n"), "1024x576 at 150 percent should use the single-line compact wordmark")
	_expect(
		title_panel != null and quit_button != null and _rect_inside(quit_button.get_global_rect(), title_panel.get_global_rect().grow(1.0)),
		"1024x576 Quit button should remain fully contained by the title rail"
	)
	for action_name: String in [
		"StartButton",
		"BlackLedgerButton",
		"HomeButton",
		"HowToPlayButton",
		"UnitsButton",
		"RGAGlossaryButton",
		"SettingsButton",
		"QuitButton",
	]:
		var action_button: Button = title_menu.find_child(action_name, true, false) as Button if title_menu != null else null
		_expect(action_button != null, "1024x576 action %s missing" % action_name)
		_expect(
			action_button != null and action_button.get_theme_font_size("font_size") >= 16,
			"1024x576 action %s should use at least 16px functional type" % action_name
		)
		_expect(
			action_button != null and _rect_inside(action_button.get_global_rect(), stress_viewport.grow(1.0)),
			"1024x576 action %s should remain fully visible in the physical viewport" % action_name
		)
	var section_hint: Label = title_menu.find_child("SectionHint", true, false) as Label if title_menu != null else null
	var binding_status: Label = title_menu.find_child("BindingStatus", true, false) as Label if title_menu != null else null
	_expect(section_hint != null and section_hint.get_theme_font_size("font_size") >= 15, "1024x576 section guidance should remain at least 15px")
	_expect(binding_status != null and binding_status.get_theme_font_size("font_size") >= 15, "1024x576 binding guidance should remain at least 15px")
	var settings_button: Button = title_menu.find_child("SettingsButton", true, false) as Button if title_menu != null else null
	var ledger_button: Button = title_menu.find_child("BlackLedgerButton", true, false) as Button if title_menu != null else null
	_expect(settings_button != null and String(settings_button.get_meta("visual_role", "")) == "selected_navigation", "selected navigation should expose a distinct selected hierarchy role")
	_expect(ledger_button != null and String(ledger_button.get_meta("visual_role", "")) == "ledger", "Black Ledger should expose a distinct ledger hierarchy role")
	_expect(quit_button != null and String(quit_button.get_meta("visual_role", "")) == "quit", "Quit should expose a distinct destructive hierarchy role")
	_save_capture("00_settings_stress_1024x576.png")

func _copy_events(action: StringName) -> Array[InputEvent]:
	var copied: Array[InputEvent] = []
	for event: InputEvent in InputMap.action_get_events(action):
		copied.append(event.duplicate() as InputEvent)
	return copied

func _restore_events(action: StringName, events: Array[InputEvent]) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	InputMap.action_erase_events(action)
	for event: InputEvent in events:
		InputMap.action_add_event(action, event.duplicate() as InputEvent)

func _non_key_event_count(action: StringName) -> int:
	var count: int = 0
	for event: InputEvent in InputMap.action_get_events(action):
		if not (event is InputEventKey):
			count += 1
	return count

func _non_key_count(events: Array[InputEvent]) -> int:
	var count: int = 0
	for event: InputEvent in events:
		if not (event is InputEventKey):
			count += 1
	return count

func _has_joypad_button(action: StringName, button_index: JoyButton) -> bool:
	for event: InputEvent in InputMap.action_get_events(action):
		var joypad_event: InputEventJoypadButton = event as InputEventJoypadButton
		if joypad_event != null and joypad_event.button_index == button_index:
			return true
	return false

func _send_joypad_button(button_index: JoyButton, pressed: bool) -> void:
	var event: InputEventJoypadButton = InputEventJoypadButton.new()
	event.device = 0
	event.button_index = button_index
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _make_key(keycode: Key) -> InputEventKey:
	var key_event: InputEventKey = InputEventKey.new()
	key_event.keycode = keycode
	key_event.pressed = true
	return key_event

func _rect_inside(inner: Rect2, outer: Rect2) -> bool:
	return outer.has_point(inner.position) and outer.has_point(inner.end)

func _expect_manifest_rows_readable(route_manifest: VBoxContainer, context: String) -> void:
	var previous_route_bottom: float = -1.0
	for record_number: String in ["01", "02", "03", "04"]:
		var route: Button = route_manifest.get_node_or_null("ManifestRoute%s" % record_number) as Button
		var record_title: Label = route.get_node_or_null("BoundCopy/RecordCopy/RecordTitle") as Label if route != null else null
		var record_description: Label = route.get_node_or_null("BoundCopy/RecordCopy/RecordDescription") as Label if route != null else null
		_expect(route != null, "%s Record %s missing" % [context, record_number])
		_expect(record_title != null and record_description != null, "%s Record %s copy missing" % [context, record_number])
		if route == null or record_title == null or record_description == null:
			continue
		var route_rect: Rect2 = route.get_global_rect()
		var title_rect: Rect2 = record_title.get_global_rect()
		var description_rect: Rect2 = record_description.get_global_rect()
		_expect(title_rect.end.y <= description_rect.position.y + 1.0, "%s Record %s title overlaps its description" % [context, record_number])
		_expect(description_rect.end.y <= route_rect.end.y - 4.0, "%s Record %s description escapes its command row" % [context, record_number])
		_expect(previous_route_bottom < 0.0 or route_rect.position.y >= previous_route_bottom - 1.0, "%s Record %s overlaps the preceding command row" % [context, record_number])
		previous_route_bottom = route_rect.end.y

func _remove_test_settings() -> void:
	var absolute_path: String = ProjectSettings.globalize_path(TEST_SETTINGS_PATH)
	if FileAccess.file_exists(TEST_SETTINGS_PATH):
		DirAccess.remove_absolute(absolute_path)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

func _settle_frames(count: int) -> void:
	for _frame_index: int in range(count):
		await get_tree().process_frame

func _save_capture(filename: String) -> void:
	var display_name: String = DisplayServer.get_name().to_lower()
	var driver_name: String = RenderingServer.get_current_rendering_driver_name().to_lower()
	if display_name == "headless" or display_name == "server" or display_name == "dummy" or driver_name.contains("dummy"):
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var texture: ViewportTexture = get_viewport().get_texture()
	if texture == null or not texture.get_rid().is_valid():
		_failures.append("viewport unavailable for %s" % filename)
		return
	var image: Image = texture.get_image()
	var path: String = "%s/%s" % [OUTPUT_DIR, filename]
	var save_error: Error = image.save_png(path)
	if save_error != OK:
		_failures.append("capture failed for %s error=%d" % [filename, int(save_error)])
		return
	print("%s: saved %s" % [SMOKE_NAME, ProjectSettings.globalize_path(path)])

func _finish() -> void:
	if _main != null and is_instance_valid(_main):
		var combat_view: Node = _main.get_node_or_null("CombatView")
		if combat_view != null and combat_view.has_method("_teardown"):
			combat_view.call("_teardown")
		var parent: Node = _main.get_parent()
		if parent != null:
			parent.remove_child(_main)
		_main.free()
		_main = null
	_restore_events(&"ui_accept", _original_accept_events)
	_restore_events(&"ui_cancel", _original_cancel_events)
	var window: Window = get_window()
	if window != null:
		window.content_scale_factor = _original_scale
		if _original_window_size != Vector2i.ZERO:
			window.size = _original_window_size
			window.content_scale_size = _original_window_size
	UserSettingsScript.configure_storage_path(UserSettingsScript.DEFAULT_SETTINGS_PATH)
	var account_paths: Array[String] = [TEST_ACCOUNT_PROFILE_PATH, "%s.tmp" % TEST_ACCOUNT_PROFILE_PATH, "%s.bak" % TEST_ACCOUNT_PROFILE_PATH]
	for account_path: String in account_paths:
		if FileAccess.file_exists(account_path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(account_path))
	_remove_test_settings()
	if _failures.is_empty():
		print(SMOKE_NAME + ": OK")
		get_tree().quit(0)
		return
	for failure: String in _failures:
		push_error(SMOKE_NAME + ": " + failure)
	get_tree().quit(1)
