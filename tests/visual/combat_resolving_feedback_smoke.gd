extends Node

const COMBAT_VIEW_SCENE: PackedScene = preload("res://scenes/CombatView.tscn")

var _failures: Array[String] = []
var _view: Control = null

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	_view = COMBAT_VIEW_SCENE.instantiate() as Control
	if _view == null:
		_fail("CombatView scene did not instantiate")
		_finish()
		return
	get_tree().root.add_child(_view)
	await get_tree().process_frame
	await get_tree().process_frame

	var controller: Variant = _view.get("controller")
	var button: Button = _view.find_child("ContinueButton", true, false) as Button
	if controller == null:
		_fail("CombatView controller missing")
	if button == null:
		_fail("ContinueButton missing")
	if controller == null or button == null:
		_finish()
		return

	controller.call("_begin_combat_resolving_feedback")
	controller.set("_battle_start_pending", true)
	_expect(String(button.text) == "Preparing battle...", "initial startup text should be immediate")

	controller.call("_update_combat_resolving_feedback", 2.0)
	_expect(String(button.text) == "Preparing battle...", "startup text should not count before delay")

	controller.call("_update_combat_resolving_feedback", 1.2)
	_expect(String(button.text) == "Preparing battle 3s...", "startup text should show elapsed seconds after delay")

	controller.call("_update_combat_resolving_feedback", 7.0)
	_expect(String(button.text) == "Startup delayed 10s...", "long startup text should warn after 10 seconds")

	controller.call("_on_log_line", "Combat no-progress timeout: forcing result from current board state.")
	_expect(String(button.text) == "Battle resolved by failsafe", "watchdog log should switch button to fallback text")

	controller.call("_update_combat_resolving_feedback", 3.0)
	_expect(String(button.text) == "Battle resolved by failsafe", "fallback text should not be overwritten by timer updates")

	_finish()

func _finish() -> void:
	if _view != null and is_instance_valid(_view):
		if _view.has_method("_teardown"):
			_view.call("_teardown")
		var view_parent: Node = _view.get_parent()
		if view_parent != null:
			view_parent.remove_child(_view)
		_view.free()
		_view = null
	if _failures.size() > 0:
		for failure: String in _failures:
			push_error("CombatResolvingFeedbackSmoke: " + failure)
		get_tree().quit(1)
		return
	print("CombatResolvingFeedbackSmoke: OK")
	get_tree().quit(0)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)

func _fail(message: String) -> void:
	_failures.append(message)
