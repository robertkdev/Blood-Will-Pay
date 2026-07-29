extends Node

const SMOKE_NAME: String = "SystemMenuHoverStabilitySmoke"
const MAIN_SCRIPT: GDScript = preload("res://scripts/main.gd")
const MAIN_SCENE: PackedScene = preload("res://scenes/Main.tscn")

var _style_host: Control = null
var _button: Button = null
var _failures: Array[String] = []

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	_style_host = Control.new()
	_style_host.set_script(MAIN_SCRIPT)
	_button = Button.new()
	_button.name = "SystemMenuButton"
	_button.text = "Menu"
	_button.position = Vector2(1120.0, 16.0)
	_button.custom_minimum_size = Vector2(96.0, 34.0)
	add_child(_button)
	_style_host.call("_apply_button_style", _button, true)
	await _settle_frames(3)

	var rect_before: Rect2 = _button.get_global_rect()
	_button.mouse_entered.emit()
	await _settle_frames(10)
	var rect_after: Rect2 = _button.get_global_rect()
	_expect(_button.scale.is_equal_approx(Vector2.ONE), "fixed SystemMenuButton should not scale on hover")
	_expect(rect_before.position.is_equal_approx(rect_after.position), "fixed SystemMenuButton position drifted on hover: before=%s after=%s" % [str(rect_before), str(rect_after)])
	_expect(rect_before.size.is_equal_approx(rect_after.size), "fixed SystemMenuButton size drifted on hover: before=%s after=%s" % [str(rect_before), str(rect_after)])
	_expect(not _button.has_meta("hover_tween"), "fixed SystemMenuButton should not create a hover tween")
	var main: Control = MAIN_SCENE.instantiate() as Control
	get_tree().root.add_child(main)
	await _settle_frames(5)
	var overlay: Control = main.get_node_or_null("SystemMenuLayer/SystemMenuOverlay") as Control
	if overlay != null:
		overlay.visible = true
	await _settle_frames(3)
	var panel: PanelContainer = main.get_node_or_null("SystemMenuLayer/SystemMenuOverlay/Center/Panel") as PanelContainer
	_expect(panel != null, "System Menu panel missing")
	if panel != null:
		_expect(panel.size.is_equal_approx(Vector2(430.0, 430.0)), "System Menu must match the frozen 430x430 contract, got %s" % str(panel.size))
	for button_name: String in ["ResumeButton", "NewRunButton", "BlackLedgerButton", "ReturnTitleButton", "QuitGameButton"]:
		var action: Button = main.get_node_or_null("SystemMenuLayer/SystemMenuOverlay/Center/Panel/Margin/Stack/%s" % button_name) as Button
		_expect(action != null, "System Menu action missing: %s" % button_name)
		if action != null:
			_expect(action.size.is_equal_approx(Vector2(320.0, 52.0)), "System Menu action %s must match 320x52, got %s" % [button_name, str(action.size)])
	if main != null and is_instance_valid(main):
		get_tree().root.remove_child(main)
		main.free()
	await _finish()

func _expect(condition: bool, message: String) -> void:
	if not condition and not _failures.has(message):
		_failures.append(message)

func _settle_frames(count: int) -> void:
	for _index: int in range(count):
		await get_tree().process_frame

func _finish() -> void:
	if _button != null and is_instance_valid(_button):
		remove_child(_button)
		_button.free()
	_button = null
	if _style_host != null and is_instance_valid(_style_host):
		_style_host.free()
	_style_host = null
	await _settle_frames(2)
	if _failures.is_empty():
		print(SMOKE_NAME + ": OK")
		get_tree().quit(0)
		return
	for failure: String in _failures:
		push_error(SMOKE_NAME + ": " + failure)
	get_tree().quit(1)
