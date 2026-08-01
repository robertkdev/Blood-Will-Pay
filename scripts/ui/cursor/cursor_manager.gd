extends Node

enum CursorState { DEFAULT, INTERACTIVE, DISABLED, DRAG, INVALID, TARGET }

const CURSOR_SIZE: Vector2 = Vector2(32.0, 32.0)
const CURSOR_PATHS: Dictionary[String, String] = {
	"default": "res://assets/ui/cursor/default.png",
	"interactive": "res://assets/ui/cursor/interactive.png",
	"disabled": "res://assets/ui/cursor/disabled.png",
	"drag": "res://assets/ui/cursor/drag.png",
	"invalid": "res://assets/ui/cursor/invalid.png",
	"target": "res://assets/ui/cursor/target.png",
}

var enabled: bool = true
var _textures: Dictionary[String, Texture2D] = {}
var _state: CursorState = CursorState.DEFAULT

func _ready() -> void:
	for key: String in CURSOR_PATHS:
		var texture: Texture2D = load(CURSOR_PATHS[key]) as Texture2D
		if texture != null:
			_textures[key] = texture
	_apply_state(CursorState.DEFAULT)

func _process(_delta: float) -> void:
	if not enabled:
		return
	var hovered: Control = get_viewport().gui_get_hovered_control() as Control
	var next_state: CursorState = _state_for_control(hovered)
	if next_state != _state:
		_apply_state(next_state)

func set_enabled(value: bool) -> void:
	enabled = value
	if enabled:
		_apply_state(CursorState.DEFAULT)
	else:
		Input.set_custom_mouse_cursor(null)

func set_state(state: CursorState) -> void:
	_apply_state(state)

func _state_for_control(control: Control) -> CursorState:
	if control == null:
		return CursorState.DEFAULT
	if control.mouse_default_cursor_shape == Control.CURSOR_FORBIDDEN:
		return CursorState.INVALID
	if control.mouse_default_cursor_shape == Control.CURSOR_DRAG:
		return CursorState.DRAG
	if control.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND:
		if control is BaseButton and (control as BaseButton).disabled:
			return CursorState.DISABLED
		return CursorState.INTERACTIVE
	return CursorState.DEFAULT

func _apply_state(state: CursorState) -> void:
	_state = state
	var key: String = _key_for_state(state)
	var texture: Texture2D = _textures.get(key, null)
	if texture != null and enabled:
		Input.set_custom_mouse_cursor(texture, Input.CURSOR_ARROW, Vector2(4.0, 2.0))

func _key_for_state(state: CursorState) -> String:
	match state:
		CursorState.INTERACTIVE:
			return "interactive"
		CursorState.DISABLED:
			return "disabled"
		CursorState.DRAG:
			return "drag"
		CursorState.INVALID:
			return "invalid"
		CursorState.TARGET:
			return "target"
		_:
			return "default"
