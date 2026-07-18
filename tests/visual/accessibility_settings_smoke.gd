extends Node

const SMOKE_NAME: String = "AccessibilitySettingsSmoke"
const MAIN_SCENE: PackedScene = preload("res://scenes/Main.tscn")
const UserSettingsScript: GDScript = preload("res://scripts/game/settings/user_settings.gd")
const TEST_SETTINGS_PATH: String = "user://accessibility_settings_smoke.cfg"

var _main: Control = null
var _failures: Array[String] = []
var _original_scale: float = 1.0
var _original_accept_events: Array[InputEvent] = []
var _original_cancel_events: Array[InputEvent] = []

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var window: Window = get_window()
	_original_scale = window.content_scale_factor if window != null else 1.0
	_original_accept_events = _copy_events(&"ui_accept")
	_original_cancel_events = _copy_events(&"ui_cancel")
	_remove_test_settings()
	UserSettingsScript.configure_storage_path(TEST_SETTINGS_PATH)
	UserSettingsScript.initialize(window)
	var defaults_error: Error = UserSettingsScript.reset_input_defaults()
	_expect(defaults_error == OK, "default bindings should save to the isolated test config")

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
	var accept_button: Button = title_menu.find_child("Binding_ui_accept", true, false) as Button if title_menu != null else null
	var cancel_button: Button = title_menu.find_child("Binding_ui_cancel", true, false) as Button if title_menu != null else null
	var reset_button: Button = title_menu.find_child("ResetBindingsButton", true, false) as Button if title_menu != null else null
	_expect(scale_option != null, "UI scale option missing")
	_expect(accept_button != null, "Confirm binding button missing")
	_expect(cancel_button != null, "Menu / Back binding button missing")
	_expect(reset_button != null, "Reset Defaults button missing")

	if scale_option != null:
		scale_option.select(1)
		scale_option.item_selected.emit(1)
	await _settle_frames(2)
	_expect(is_equal_approx(UserSettingsScript.get_ui_scale(), 1.25), "UI scale should update to 125 percent")
	if window != null:
		_expect(is_equal_approx(window.content_scale_factor, 1.25), "window content scale should update immediately")

	var remap_key: InputEventKey = _make_key(KEY_F6)
	var remap_result: Dictionary[String, Variant] = UserSettingsScript.set_keyboard_binding(&"ui_accept", remap_key)
	_expect(bool(remap_result.get("ok", false)), "Confirm should accept an unused keyboard binding")
	var conflict_result: Dictionary[String, Variant] = UserSettingsScript.set_keyboard_binding(&"ui_cancel", remap_key)
	_expect(not bool(conflict_result.get("ok", true)) and String(conflict_result.get("error", "")) == "conflict", "duplicate binding should report a conflict")
	_expect(_non_key_event_count(&"ui_accept") == _non_key_count(_original_accept_events), "remapping Confirm should preserve its non-key events")

	UserSettingsScript.configure_storage_path(TEST_SETTINGS_PATH)
	UserSettingsScript.initialize(window)
	_expect(UserSettingsScript.binding_text(&"ui_accept").contains("F6"), "Confirm remap should survive reload")
	_expect(is_equal_approx(UserSettingsScript.get_ui_scale(), 1.25), "UI scale should survive reload")

	if title_menu != null:
		title_menu.call("_begin_binding_capture", &"ui_cancel")
		title_menu.call("_input", _make_key(KEY_ESCAPE))
	_expect(UserSettingsScript.binding_text(&"ui_cancel").contains("Escape"), "Escape should cancel capture without replacing Menu / Back")

	if reset_button != null:
		reset_button.pressed.emit()
	await _settle_frames(1)
	_expect(UserSettingsScript.binding_text(&"ui_accept").contains("Enter"), "reset should restore Confirm to Enter")
	_expect(UserSettingsScript.binding_text(&"ui_cancel").contains("Escape"), "reset should restore Menu / Back to Escape")
	_finish()

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

func _make_key(keycode: Key) -> InputEventKey:
	var key_event: InputEventKey = InputEventKey.new()
	key_event.keycode = keycode
	key_event.pressed = true
	return key_event

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
	UserSettingsScript.configure_storage_path(UserSettingsScript.DEFAULT_SETTINGS_PATH)
	_remove_test_settings()
	if _failures.is_empty():
		print(SMOKE_NAME + ": OK")
		get_tree().quit(0)
		return
	for failure: String in _failures:
		push_error(SMOKE_NAME + ": " + failure)
	get_tree().quit(1)
