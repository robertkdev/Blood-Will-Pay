extends Node

const MAIN_SCENE: PackedScene = preload("res://scenes/Main.tscn")
const VisionSnapshot: GDScript = preload("res://scripts/util/vision_snapshot.gd")
const OUTPUT_DIR: String = "res://outputs/vision_snapshots/title_menu_states"

var _main: Control = null
var _title_menu: Control = null
var _captures: Array[Dictionary] = []
var _failures: Array[String] = []

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	var window: Window = get_window()
	if window != null:
		window.size = Vector2i(1920, 1080)
		window.content_scale_size = Vector2i(1920, 1080)
	_main = MAIN_SCENE.instantiate() as Control
	_main.set_anchors_preset(Control.PRESET_FULL_RECT)
	_main.offset_left = 0.0
	_main.offset_top = 0.0
	_main.offset_right = 0.0
	_main.offset_bottom = 0.0
	get_tree().root.add_child(_main)
	await _settle_frames(8)
	_title_menu = _main.get_node_or_null("TitleMenu") as Control
	_expect(_title_menu != null, "TitleMenu missing")
	if _title_menu == null:
		_finish()
		return
	if not _title_menu.visible:
		var title_page: Control = _main.get_node_or_null("TitlePage") as Control
		_expect(title_page != null, "TitlePage missing")
		if title_page != null:
			_capture_title_page(title_page)
		var enter_button: Button = _main.get_node_or_null("TitlePage/Center/Stack/EnterButton") as Button
		_expect(enter_button != null, "TitlePage EnterButton missing")
		if enter_button != null:
			enter_button.emit_signal("pressed")
		await _settle_seconds(0.85)

	await _open_section("HomeButton")
	await _capture("01_overview", ["GAMBLE BATTLE", "COMMAND MENU", "OPENING LOOP"])
	await _open_section("HowToPlayButton")
	await _set_search("combine")
	await _capture("02_how_to_play_search_combine", ["HOW TO PLAY", "STRONGER COPY"])
	await _open_section("UnitsButton")
	await _set_search("hexeon")
	await _capture("03_units_search_hexeon", ["UNITS", "HEXEON", "PRISMATIC GUILLOTINE"])
	await _open_section("RGAGlossaryButton")
	await _set_search("threshold")
	await _capture("04_combat_terms_search_threshold", ["COMBAT TERMS", "ACTIVE TRAIT", "THRESHOLD"])
	await _set_search("definitely-no-such-combat-term")
	await _capture("05_combat_terms_no_results", ["COMBAT TERMS", "NOTHING FOUND", "CLEAR SEARCH"])
	await _open_section("SettingsButton")
	await _set_search("")
	await _capture("06_settings", ["SETTINGS", "MASTER VOLUME", "FULLSCREEN", "UI SCALE", "KEYBOARD BINDINGS"])
	_finish()

func _open_section(button_name: String) -> void:
	var button: Button = _title_menu.get_node_or_null("Center/VBox/%s" % button_name) as Button
	_expect(button != null, "%s missing" % button_name)
	if button != null:
		button.emit_signal("pressed")
	await _settle_frames(3)

func _set_search(text: String) -> void:
	var search_field: LineEdit = _title_menu.get_node_or_null("ContentPanel/Margin/Stack/Header/SearchField") as LineEdit
	_expect(search_field != null, "SearchField missing")
	if search_field != null:
		search_field.text = text
		search_field.emit_signal("text_changed", text)
	await _settle_frames(3)

func _capture(label: String, required_needles: Array[String]) -> void:
	_expect_generated_title_styles(label)
	var result: Dictionary[String, Variant] = VisionSnapshot.capture(_title_menu, label, OUTPUT_DIR)
	_captures.append(result)
	_expect(bool(result.get("ok", false)), "%s capture should succeed" % label)
	_expect(bool(result.get("software_ok", false)), "%s software PNG should be saved" % label)
	var path: String = str(result.get("path", ""))
	var software_path: String = str(result.get("software_path", ""))
	var json_path: String = str(result.get("json_path", ""))
	_expect(path != "" and FileAccess.file_exists(path), "%s final capture missing: %s" % [label, path])
	_expect(software_path != "" and FileAccess.file_exists(software_path), "%s software capture missing: %s" % [label, software_path])
	_expect(json_path != "" and FileAccess.file_exists(json_path), "%s JSON capture missing: %s" % [label, json_path])
	_expect(_json_contains_needles(json_path, required_needles), "%s JSON missing expected text: %s" % [label, JSON.stringify(required_needles)])

func _capture_title_page(title_page: Control) -> void:
	var result: Dictionary[String, Variant] = VisionSnapshot.capture(title_page, "00_title_page", OUTPUT_DIR)
	_captures.append(result)
	_expect(bool(result.get("ok", false)), "00_title_page capture should succeed")
	_expect(bool(result.get("software_ok", false)), "00_title_page software PNG should be saved")
	var path: String = str(result.get("path", ""))
	var software_path: String = str(result.get("software_path", ""))
	var json_path: String = str(result.get("json_path", ""))
	_expect(path != "" and FileAccess.file_exists(path), "00_title_page final capture missing: %s" % path)
	_expect(software_path != "" and FileAccess.file_exists(software_path), "00_title_page software capture missing: %s" % software_path)
	_expect(json_path != "" and FileAccess.file_exists(json_path), "00_title_page JSON capture missing: %s" % json_path)
	_expect(_json_contains_needles(json_path, ["GAMBLE BATTLE", "ENTER"]), "00_title_page JSON missing expected title-page text")

func _expect_generated_title_styles(context: String) -> void:
	var content_panel: PanelContainer = _title_menu.get_node_or_null("ContentPanel") as PanelContainer
	_expect(content_panel != null and content_panel.get_theme_stylebox("panel") is StyleBoxTexture, "%s content panel should use generated texture style" % context)
	var search_field: LineEdit = _title_menu.get_node_or_null("ContentPanel/Margin/Stack/Header/SearchField") as LineEdit
	_expect(search_field != null and search_field.get_theme_stylebox("normal") is StyleBoxTexture, "%s search field should use generated normal style" % context)
	_expect(search_field != null and search_field.get_theme_stylebox("focus") is StyleBoxTexture, "%s search field should use generated focus style" % context)
	var body: Control = _title_menu.get_node_or_null("ContentPanel/Margin/Stack/ContentScroll/ContentBody") as Control
	_expect(body != null, "%s content body missing" % context)
	if body != null:
		var panel_count: int = 0
		for node: Node in body.find_children("*", "PanelContainer", true, false):
			var panel: PanelContainer = node as PanelContainer
			# OptionButton creates private popup/focus PanelContainers that inherit
			# engine styles; app-authored cards all own a named Margin child.
			if panel != null and panel.get_node_or_null("Margin") != null:
				panel_count += 1
				_expect(panel.get_theme_stylebox("panel") is StyleBoxTexture, "%s %s should use generated texture style" % [context, str(panel.name)])
		_expect(panel_count > 0, "%s should expose at least one generated card or chip" % context)
	var nav_names: Array[String] = ["HomeButton", "HowToPlayButton", "UnitsButton", "RGAGlossaryButton", "SettingsButton"]
	for nav_name: String in nav_names:
		var button: Button = _title_menu.get_node_or_null("Center/VBox/%s" % nav_name) as Button
		_expect(button != null and button.get_theme_stylebox("normal") is StyleBoxTexture, "%s %s normal style should be generated" % [context, nav_name])
		_expect(button != null and button.get_theme_stylebox("pressed") is StyleBoxTexture, "%s %s pressed style should be generated" % [context, nav_name])
	var motion_check: CheckBox = _title_menu.find_child("ReducedMotionCheck", true, false) as CheckBox
	_expect(motion_check == null, "%s ReducedMotionCheck should not be present" % context)

func _json_contains_needles(path: String, needles: Array[String]) -> bool:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var text: String = file.get_as_text().to_upper()
	file.close()
	for needle: String in needles:
		if not text.contains(needle.to_upper()):
			return false
	return true

func _settle_frames(count: int) -> void:
	for _frame_index: int in range(count):
		await get_tree().process_frame

func _settle_seconds(seconds: float) -> void:
	await _settle_frames(4)
	await get_tree().create_timer(seconds).timeout
	await _settle_frames(4)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

func _finish() -> void:
	if _main != null and is_instance_valid(_main):
		var parent: Node = _main.get_parent()
		if parent != null:
			parent.remove_child(_main)
		_main.free()
		_main = null
	var exit_code: int = 0
	if _failures.is_empty():
		print("TitleMenuStateCapture: OK captures=%d output=%s" % [_captures.size(), ProjectSettings.globalize_path(OUTPUT_DIR)])
	else:
		for failure: String in _failures:
			push_error("TitleMenuStateCapture: " + failure)
		exit_code = 1
	get_tree().quit(exit_code)
