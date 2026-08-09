extends Node

const MAIN_SCENE: PackedScene = preload("res://scenes/Main.tscn")

class SaveFailureCombatView extends Control:
	var save_calls: int = 0

	func save_active_run_now() -> Dictionary:
		save_calls += 1
		return {"ok": false, "error": "UNSTABLE_PHASE"}

var _failures: Array[String] = []
var _main: Control = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_run")

func _run() -> void:
	_main = MAIN_SCENE.instantiate() as Control
	add_child(_main)
	await _settle_frames(3)
	_expect(not get_tree().auto_accept_quit, "window close must route through the preserve gate")
	var title_page: Control = _main.get("_title_page") as Control
	var title_menu: Control = _main.get_node_or_null("TitleMenu") as Control
	if title_page != null:
		title_page.visible = false
	if title_menu != null:
		title_menu.visible = false
	var failed_combat: SaveFailureCombatView = SaveFailureCombatView.new()
	failed_combat.visible = true
	_main.add_child(failed_combat)
	_main.set("combat_view", failed_combat)

	_main.call("request_return_to_title")
	await _settle_frames(2)
	_expect(failed_combat.save_calls == 1, "Return to Title must attempt a preserve save")
	_expect(get_tree().paused, "failed preserve must keep the run paused behind recovery")
	_expect(title_page != null and not title_page.visible, "failed preserve must not leave for the title page")
	_expect(_overlay_visible(), "failed preserve must expose the system recovery path")
	var recovery_notice: Label = _main.find_child("PreserveRecoveryNotice", true, false) as Label
	_expect(recovery_notice != null and recovery_notice.visible and recovery_notice.text.contains("combat is still resolving"), "recovery must explain how to keep the run and retry safely")

	_main.call("_close_system_menu")
	_main.call("_open_runtime_settings")
	await _settle_frames(2)
	_expect(not failed_combat.visible and title_menu != null and title_menu.visible, "runtime Settings setup must hide the live combat view")
	_main.call("_on_quit")
	await _settle_frames(2)
	_expect(failed_combat.save_calls == 2, "Quit to Desktop must attempt a preserve save")
	_expect(_overlay_visible() and get_tree().paused, "failed Quit must leave the recovery path open instead of exiting")
	_expect(failed_combat.visible and title_menu != null and not title_menu.visible, "failed Quit from Settings must restore the run before showing recovery")
	_finish()

func _overlay_visible() -> bool:
	var overlay: Control = _main.get_node_or_null("SystemMenuLayer/SystemMenuOverlay") as Control if _main != null else null
	return overlay != null and overlay.visible

func _finish() -> void:
	get_tree().paused = false
	if _main != null and is_instance_valid(_main):
		var parent: Node = _main.get_parent()
		if parent != null:
			parent.remove_child(_main)
		_main.free()
		_main = null
	if _failures.is_empty():
		print("PreserveExitRecoverySmoke: OK")
		get_tree().quit(0)
		return
	for failure: String in _failures:
		push_error("PreserveExitRecoverySmoke: " + failure)
	get_tree().quit(1)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

func _settle_frames(count: int) -> void:
	for _frame_index: int in range(count):
		await get_tree().process_frame
