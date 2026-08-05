extends Node

const MainScene: PackedScene = preload("res://scenes/Main.tscn")

var _cursor_manager: Node = null

func _ready() -> void:
	var main: Node = MainScene.instantiate()
	add_child(main)
	_cursor_manager = get_node_or_null("/root/CursorManager")
	if _cursor_manager == null:
		push_error("CursorStateRuntimeDriver: CursorManager autoload is unavailable")
		return
	_cursor_manager.set_process(false)
	_set_cursor_state(0)

func _input(event: InputEvent) -> void:
	var key_event: InputEventKey = event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return
	var handled: bool = true
	match key_event.keycode:
		KEY_1:
			_set_cursor_state(0)
		KEY_2:
			_set_cursor_state(1)
		KEY_3:
			_set_cursor_state(2)
		KEY_4:
			_set_cursor_state(3)
		KEY_5:
			_set_cursor_state(4)
		KEY_6:
			_set_cursor_state(5)
		_:
			handled = false
	if handled:
		get_viewport().set_input_as_handled()

func _set_cursor_state(state: int) -> void:
	if _cursor_manager != null:
		_cursor_manager.call("set_state", state)
