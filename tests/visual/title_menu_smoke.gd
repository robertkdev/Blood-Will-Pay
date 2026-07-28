extends Node

const MAIN_SCENE: PackedScene = preload("res://scenes/Main.tscn")

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
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
		var enter_button: Button = main.get_node_or_null("TitlePage/Center/Stack/EnterButton") as Button
		_expect(enter_button != null, "TitlePage EnterButton missing", failures)
		if enter_button != null:
			enter_button.emit_signal("pressed")
			await get_tree().process_frame
			await get_tree().process_frame
		_expect(title_menu.visible, "TitleMenu is not visible after entering from title page", failures)
		var title_label: Label = title_menu.get_node_or_null("Center/VBox/GameTitle") as Label
		_expect(title_label != null, "GameTitle missing", failures)
		if title_label != null:
			_expect(title_label.get_theme_font_size("font_size") >= 54, "GameTitle is not visually prioritized", failures)
		var hero: TextureRect = title_menu.get_node_or_null("TitleHero") as TextureRect
		_expect(hero == null, "TitleHero should not render a background unit over the menu", failures)
		var content_panel: PanelContainer = title_menu.get_node_or_null("ContentPanel") as PanelContainer
		_expect(content_panel != null, "ContentPanel missing", failures)
		if content_panel != null:
			var content_style: StyleBox = content_panel.get_theme_stylebox("panel")
			_expect(content_style is StyleBoxTexture, "ContentPanel should use the generated wide panel asset", failures)
		var search_field: LineEdit = title_menu.get_node_or_null("ContentPanel/Margin/Stack/Header/SearchField") as LineEdit
		_expect(search_field != null, "SearchField missing", failures)
		if search_field != null:
			_expect_stylebox_texture(search_field, "normal", "SearchField normal should use generated texture styling", failures)
			_expect_stylebox_texture(search_field, "focus", "SearchField focus should use generated texture styling", failures)
		var how_to_play_button: Button = title_menu.get_node_or_null("Center/VBox/HowToPlayButton") as Button
		var units_button: Button = title_menu.get_node_or_null("Center/VBox/UnitsButton") as Button
		var rga_button: Button = title_menu.get_node_or_null("Center/VBox/RGAGlossaryButton") as Button
		var settings_button: Button = title_menu.get_node_or_null("Center/VBox/SettingsButton") as Button
		_expect(how_to_play_button != null, "HowToPlayButton missing", failures)
		_expect(units_button != null, "UnitsButton missing", failures)
		_expect(rga_button != null, "RGAGlossaryButton missing", failures)
		_expect(settings_button != null, "SettingsButton missing", failures)
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
			_expect_content_panels_generated(title_menu, "How To Play cards should use generated texture styling", failures)
		if settings_button != null:
			settings_button.emit_signal("pressed")
			await get_tree().process_frame
			var volume_slider: HSlider = title_menu.find_child("MasterVolumeSlider", true, false) as HSlider
			_expect(volume_slider != null, "Settings did not expose master volume slider", failures)
			if volume_slider != null:
				_expect_stylebox_texture(volume_slider, "slider", "MasterVolumeSlider track should use generated texture styling", failures)
				_expect_stylebox_texture(volume_slider, "grabber_area", "MasterVolumeSlider filled area should use generated texture styling", failures)
			var fullscreen_check: CheckBox = title_menu.find_child("FullscreenCheck", true, false) as CheckBox
			var motion_check: CheckBox = title_menu.find_child("ReducedMotionCheck", true, false) as CheckBox
			_expect(fullscreen_check != null, "FullscreenCheck missing", failures)
			_expect(motion_check == null, "ReducedMotionCheck should be removed from settings", failures)
			_expect_button_states(fullscreen_check, "FullscreenCheck", failures)
		var start_button: Button = title_menu.get_node_or_null("Center/VBox/StartButton") as Button
		_expect(start_button != null, "StartButton missing", failures)
		if start_button != null:
			_expect(start_button.custom_minimum_size.x >= 300.0, "StartButton is not visually prioritized", failures)
			var start_style: StyleBox = start_button.get_theme_stylebox("normal")
			_expect(start_style is StyleBoxTexture, "Title StartButton should use the generated primary button asset", failures)
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
		_expect_stylebox_texture(panel, "panel", "%s: %s" % [message, str(panel.name)], failures)
	_expect(panel_count > 0, message, failures)

func _expect_button_states(button: Button, label: String, failures: Array[String]) -> void:
	_expect(button != null, "%s missing" % label, failures)
	if button == null:
		return
	var states: Array[String] = ["normal", "hover", "pressed", "focus"]
	for state: String in states:
		_expect_stylebox_texture(button, state, "%s %s should use generated texture styling" % [label, state], failures)

func _expect_stylebox_texture(control: Control, style_name: String, message: String, failures: Array[String]) -> void:
	_expect(control != null, message, failures)
	if control == null:
		return
	var style: StyleBox = control.get_theme_stylebox(style_name)
	_expect(style is StyleBoxTexture, message, failures)

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
