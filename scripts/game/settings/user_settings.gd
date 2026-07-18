extends RefCounted
class_name UserSettings

const DEFAULT_SETTINGS_PATH: String = "user://settings.cfg"
const SECTION_ACCESSIBILITY: String = "accessibility"
const SECTION_INPUT: String = "input"
const KEY_UI_SCALE: String = "ui_scale"
const DEFAULT_UI_SCALE: float = 1.0
const MIN_UI_SCALE: float = 1.0
const MAX_UI_SCALE: float = 1.5
const REMAPPABLE_ACTIONS: Array[StringName] = [&"ui_accept", &"ui_cancel"]

static var _settings_path: String = DEFAULT_SETTINGS_PATH
static var _loaded: bool = false
static var _ui_scale: float = DEFAULT_UI_SCALE

static func initialize(window: Window, settings_path: String = "") -> void:
	if not settings_path.is_empty() and settings_path != _settings_path:
		_settings_path = settings_path
		_loaded = false
	if not _loaded:
		_load()
	_apply_ui_scale(window)

static func configure_storage_path(settings_path: String) -> void:
	_settings_path = settings_path if not settings_path.is_empty() else DEFAULT_SETTINGS_PATH
	_loaded = false
	_ui_scale = DEFAULT_UI_SCALE

static func get_ui_scale() -> float:
	_ensure_loaded()
	return _ui_scale

static func set_ui_scale(value: float, window: Window) -> Error:
	_ensure_loaded()
	_ui_scale = clampf(value, MIN_UI_SCALE, MAX_UI_SCALE)
	_apply_ui_scale(window)
	return _save()

static func get_keyboard_binding(action: StringName) -> InputEventKey:
	_ensure_loaded()
	for event: InputEvent in InputMap.action_get_events(action):
		var key_event: InputEventKey = event as InputEventKey
		if key_event != null:
			return key_event.duplicate() as InputEventKey
	return null

static func binding_text(action: StringName) -> String:
	var key_event: InputEventKey = get_keyboard_binding(action)
	if key_event == null:
		return "Unbound"
	return key_event.as_text_keycode()

static func set_keyboard_binding(action: StringName, key_event: InputEventKey) -> Dictionary[String, Variant]:
	_ensure_loaded()
	if not REMAPPABLE_ACTIONS.has(action):
		return {"ok": false, "error": "unsupported_action"}
	if key_event == null or _event_code(key_event) == 0:
		return {"ok": false, "error": "invalid_key"}
	var conflict_action: StringName = _find_conflict(action, key_event)
	if conflict_action != StringName():
		return {"ok": false, "error": "conflict", "conflict_action": String(conflict_action)}
	_replace_keyboard_events(action, [key_event])
	var save_error: Error = _save()
	return {"ok": save_error == OK, "error": "" if save_error == OK else "save_failed", "save_error": int(save_error)}

static func reset_input_defaults() -> Error:
	_ensure_loaded()
	_replace_keyboard_events(&"ui_accept", [_make_key_event(KEY_ENTER)])
	_replace_keyboard_events(&"ui_cancel", [_make_key_event(KEY_ESCAPE)])
	return _save()

static func reload(window: Window) -> void:
	_loaded = false
	_load()
	_apply_ui_scale(window)

static func _ensure_loaded() -> void:
	if not _loaded:
		_load()

static func _load() -> void:
	_loaded = true
	_ui_scale = DEFAULT_UI_SCALE
	var config: ConfigFile = ConfigFile.new()
	var load_error: Error = config.load(_settings_path)
	if load_error != OK and load_error != ERR_FILE_NOT_FOUND:
		push_warning("UserSettings: failed to load %s error=%d" % [_settings_path, int(load_error)])
	_ui_scale = clampf(float(config.get_value(SECTION_ACCESSIBILITY, KEY_UI_SCALE, DEFAULT_UI_SCALE)), MIN_UI_SCALE, MAX_UI_SCALE)
	for action: StringName in REMAPPABLE_ACTIONS:
		if not config.has_section_key(SECTION_INPUT, String(action)):
			continue
		var value: Variant = config.get_value(SECTION_INPUT, String(action), null)
		if value is Dictionary:
			var key_event: InputEventKey = _event_from_dictionary(value as Dictionary)
			if key_event != null:
				_replace_keyboard_events(action, [key_event])

static func _save() -> Error:
	var config: ConfigFile = ConfigFile.new()
	config.set_value(SECTION_ACCESSIBILITY, KEY_UI_SCALE, _ui_scale)
	for action: StringName in REMAPPABLE_ACTIONS:
		var key_event: InputEventKey = get_keyboard_binding(action)
		if key_event != null:
			config.set_value(SECTION_INPUT, String(action), _event_to_dictionary(key_event))
	return config.save(_settings_path)

static func _apply_ui_scale(window: Window) -> void:
	if window != null:
		window.content_scale_factor = _ui_scale

static func _replace_keyboard_events(action: StringName, keyboard_events: Array[InputEventKey]) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var preserved_events: Array[InputEvent] = []
	for event: InputEvent in InputMap.action_get_events(action):
		if not (event is InputEventKey):
			preserved_events.append(event.duplicate() as InputEvent)
	InputMap.action_erase_events(action)
	for preserved_event: InputEvent in preserved_events:
		InputMap.action_add_event(action, preserved_event)
	for keyboard_event: InputEventKey in keyboard_events:
		InputMap.action_add_event(action, keyboard_event.duplicate() as InputEventKey)

static func _find_conflict(action: StringName, key_event: InputEventKey) -> StringName:
	for candidate: StringName in REMAPPABLE_ACTIONS:
		if candidate == action:
			continue
		for event: InputEvent in InputMap.action_get_events(candidate):
			var candidate_key: InputEventKey = event as InputEventKey
			if candidate_key != null and _same_key(candidate_key, key_event):
				return candidate
	return StringName()

static func _same_key(left: InputEventKey, right: InputEventKey) -> bool:
	return _event_code(left) == _event_code(right) and left.shift_pressed == right.shift_pressed and left.ctrl_pressed == right.ctrl_pressed and left.alt_pressed == right.alt_pressed and left.meta_pressed == right.meta_pressed

static func _event_code(key_event: InputEventKey) -> int:
	if int(key_event.physical_keycode) != 0:
		return int(key_event.physical_keycode)
	return int(key_event.keycode)

static func _event_to_dictionary(key_event: InputEventKey) -> Dictionary[String, Variant]:
	return {
		"keycode": int(key_event.keycode),
		"physical_keycode": int(key_event.physical_keycode),
		"shift": key_event.shift_pressed,
		"ctrl": key_event.ctrl_pressed,
		"alt": key_event.alt_pressed,
		"meta": key_event.meta_pressed,
	}

static func _event_from_dictionary(value: Dictionary) -> InputEventKey:
	var key_event: InputEventKey = InputEventKey.new()
	key_event.keycode = int(value.get("keycode", 0))
	key_event.physical_keycode = int(value.get("physical_keycode", 0))
	key_event.shift_pressed = bool(value.get("shift", false))
	key_event.ctrl_pressed = bool(value.get("ctrl", false))
	key_event.alt_pressed = bool(value.get("alt", false))
	key_event.meta_pressed = bool(value.get("meta", false))
	return key_event if _event_code(key_event) != 0 else null

static func _make_key_event(keycode: Key) -> InputEventKey:
	var key_event: InputEventKey = InputEventKey.new()
	key_event.keycode = keycode
	return key_event
