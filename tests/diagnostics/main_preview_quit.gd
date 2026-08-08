extends Node

const MAIN_SCENE: PackedScene = preload("res://scenes/Main.tscn")

var _main: Control = null
var _failures: Array[String] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_run")

func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	_main = MAIN_SCENE.instantiate() as Control
	add_child(_main)
	_expect(_main.get_node_or_null("CombatView") != null, "Main scene is missing the CombatView runtime contract")
	await _settle_frames(4)

	await _ensure_unit_select()
	await _select_starter("axiom")
	await _settle_frames(4)
	_expect(_node_visible("CombatView"), "combat view did not open")
	_finish()

func _finish() -> void:
	var exit_code: int = 0
	if _failures.is_empty():
		print("MainPreviewQuit: PASS")
	else:
		for failure: String in _failures:
			push_error("MainPreviewQuit: " + failure)
		exit_code = 1
	_cleanup_runtime()
	get_tree().process_frame.connect(_quit_after_cleanup.bind(exit_code, 2), CONNECT_ONE_SHOT)

func _quit_after_cleanup(exit_code: int, frames_left: int) -> void:
	if frames_left > 0:
		get_tree().process_frame.connect(_quit_after_cleanup.bind(exit_code, frames_left - 1), CONNECT_ONE_SHOT)
		return
	get_tree().quit(exit_code)

func _cleanup_runtime() -> void:
	if _main != null and is_instance_valid(_main):
		var parent: Node = _main.get_parent()
		if parent != null:
			parent.remove_child(_main)
		_main.free()
		_main = null

func _ensure_unit_select() -> void:
	if _node_visible("TitleMenu"):
		var start: Button = _main.get_node_or_null("TitleMenu/Center/VBox/StartButton") as Button
		if start == null:
			_expect(false, "title start button missing")
			return
		start.pressed.emit()
		await _settle_frames(4)
	if not _node_visible("UnitSelect"):
		_expect(false, "unit select was not visible")

func _select_starter(unit_id: String) -> void:
	var select: UnitSelect = _main.get_node_or_null("UnitSelect") as UnitSelect
	if select == null:
		_expect(false, "unit select node missing")
		return
	var button: Button = select.buttons_by_id.get(unit_id, null) as Button
	if button == null:
		_expect(false, "starter button missing for %s" % unit_id)
		return
	button.pressed.emit()
	await _settle_frames(2)
	var start: Button = select.get_node_or_null("Center/HBox/Right/StartButton") as Button
	if start == null:
		_expect(false, "unit select start button missing")
		return
	_expect(not start.disabled, "unit select start button did not enable for %s" % unit_id)
	start.pressed.emit()

func _node_visible(path: String) -> bool:
	if _main == null:
		return false
	var node: CanvasItem = _main.get_node_or_null(path) as CanvasItem
	return node != null and node.visible

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

func _settle_frames(count: int) -> void:
	for index: int in range(count):
		await get_tree().process_frame
