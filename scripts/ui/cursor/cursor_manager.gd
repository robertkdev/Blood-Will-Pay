extends Node

enum CursorState { DEFAULT, INTERACTIVE, DISABLED, DRAG, INVALID, TARGET }

const CURSOR_DISPLAY_SIZE: Vector2i = Vector2i(48, 48)
const HOTSPOT: Vector2 = Vector2(6.0, 3.0)
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
			_textures[key] = _scaled_texture(texture)
	_apply_state(CursorState.DEFAULT)

func _scaled_texture(texture: Texture2D) -> Texture2D:
	var image: Image = texture.get_image()
	if image == null or image.is_empty():
		return texture
	image.resize(CURSOR_DISPLAY_SIZE.x, CURSOR_DISPLAY_SIZE.y, Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(image)

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
		_clear_custom_cursors()

func set_state(state: CursorState) -> void:
	_apply_state(state)

func _state_for_control(control: Control) -> CursorState:
	if control == null:
		return CursorState.DEFAULT
	if control is BaseButton and (control as BaseButton).disabled:
		return CursorState.DISABLED
	if control.mouse_default_cursor_shape == Control.CURSOR_FORBIDDEN:
		return CursorState.INVALID
	if control.mouse_default_cursor_shape == Control.CURSOR_DRAG:
		return CursorState.DRAG
	if control.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND:
		return CursorState.INTERACTIVE
	return CursorState.DEFAULT

func _apply_state(state: CursorState) -> void:
	_state = state
	var key: String = _key_for_state(state)
	var texture: Texture2D = _textures.get(key, null)
	if texture != null and enabled:
		_set_custom_cursors(texture)
	elif enabled:
		_clear_custom_cursors()

func _set_custom_cursors(texture: Texture2D) -> void:
	Input.set_custom_mouse_cursor(texture, Input.CURSOR_ARROW, HOTSPOT)
	Input.set_custom_mouse_cursor(texture, Input.CURSOR_POINTING_HAND, HOTSPOT)
	Input.set_custom_mouse_cursor(texture, Input.CURSOR_DRAG, HOTSPOT)
	Input.set_custom_mouse_cursor(texture, Input.CURSOR_FORBIDDEN, HOTSPOT)

func _clear_custom_cursors() -> void:
	Input.set_custom_mouse_cursor(null, Input.CURSOR_ARROW)
	Input.set_custom_mouse_cursor(null, Input.CURSOR_POINTING_HAND)
	Input.set_custom_mouse_cursor(null, Input.CURSOR_DRAG)
	Input.set_custom_mouse_cursor(null, Input.CURSOR_FORBIDDEN)

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
