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
	var log_label: RichTextLabel = _view.find_child("LogLabel", true, false) as RichTextLabel
	if controller == null:
		_fail("CombatView controller missing")
	if button == null:
		_fail("ContinueButton missing")
	if controller == null or button == null:
		_finish()
		return

	button.disabled = true
	controller.call("_begin_combat_resolving_feedback")
	controller.set("_battle_start_pending", true)
	controller.set("_battle_start_elapsed", 0.0)
	controller.call("_update_pending_battle_start", 10.1)

	_expect(not bool(controller.get("_battle_start_pending")), "timed-out startup should clear pending state")
	_expect(not button.disabled, "timed-out startup should re-enable the start button")
	_expect(String(button.text) == "Start Opening Fight" or String(button.text) == "Start Battle", "timed-out startup should restore start text")
	_expect(GameState.phase == GameState.GamePhase.PREVIEW, "timed-out startup should return to planning")
	var manager: Variant = controller.get("manager")
	_expect(manager != null and manager.get_engine() == null, "timed-out startup should clear partial combat runtime")
	if log_label != null:
		_expect(log_label.get_parsed_text().contains("Battle start recovery:"), "recovery should be visible in the combat log")

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
	if not _failures.is_empty():
		for failure: String in _failures:
			push_error("CombatStartRecoverySmoke: " + failure)
		get_tree().quit(1)
		return
	print("CombatStartRecoverySmoke: OK")
	get_tree().quit(0)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)

func _fail(message: String) -> void:
	_failures.append(message)
