extends Node

const MAIN_SCENE: PackedScene = preload("res://scenes/Main.tscn")
const MainTransitionWait: GDScript = preload("res://tests/visual/main_transition_wait.gd")

var _main: Control = null
var _failures: Array[String] = []
var _previous_time_scale: float = 1.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_run")

func _run() -> void:
	_previous_time_scale = Engine.time_scale
	Engine.time_scale = 1.0
	DisplayServer.window_set_size(Vector2i(1280, 720))
	_main = MAIN_SCENE.instantiate() as Control
	get_tree().root.add_child(_main)
	await _settle_frames(4)

	var hidden_panel: CanvasItem = _main.get_node_or_null("AuditPanel") as CanvasItem
	_expect(hidden_panel == null or not hidden_panel.visible, "audit panel should be hidden before debug activation")

	var panel: Node = _main.call("enable_audit_panel_for_test") as Node
	await _settle_frames(2)
	_expect(panel != null, "audit panel did not instantiate")
	_expect(panel != null and panel.visible, "audit panel did not become visible")
	if panel == null:
		_finish()
		return

	var state_path: String = str(panel.call("export_state_for_test"))
	_expect(state_path != "", "state export path was empty")
	_expect(FileAccess.file_exists(state_path), "state export file missing at " + state_path)
	_validate_state_json(state_path)

	var screenshot_status: Dictionary = panel.call("capture_screenshot_for_test")
	_expect(bool(screenshot_status.get("ok", false)), "screenshot capture should save viewport or software fallback")
	var screenshot_path: String = str(screenshot_status.get("path", ""))
	_expect(screenshot_path != "" and FileAccess.file_exists(screenshot_path), "screenshot reported ok but file was missing")
	_expect(str(screenshot_status.get("kind", "")) != "", "screenshot status should include capture kind")

	panel.call("set_speed_for_test", 4.0)
	_expect(abs(Engine.time_scale - 4.0) < 0.001, "audit panel speed control did not set 4x")
	panel.call("set_speed_for_test", 1.0)
	_expect(abs(Engine.time_scale - 1.0) < 0.001, "audit panel speed control did not restore 1x")

	_main.call("_on_start")
	await _settle_frames(4)
	_main.call("_on_unit_selected", "bonko")
	var combat: Control = await MainTransitionWait.for_combat_view(self, _main)
	panel.call("hold_timer_for_test")
	_expect(combat != null, "combat view missing after Bonko start")
	if combat != null:
		_expect(float(combat.get("planning_time_left")) >= 9990.0, "timer hold did not extend planning time")

	panel.call("restart_run_for_test")
	await _settle_frames(8)
	var unit_select: CanvasItem = _main.get_node_or_null("UnitSelect") as CanvasItem
	_expect(unit_select != null and unit_select.visible, "audit panel new run did not return to Unit Select")

	_finish()

func _validate_state_json(path: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		_expect(false, "could not read state export")
		return
	var text: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	_expect(parsed is Dictionary, "state export was not JSON object")
	if parsed is Dictionary:
		var state: Dictionary = parsed as Dictionary
		_expect(state.has("phase_name"), "state export missing phase_name")
		_expect(state.has("shop"), "state export missing shop block")
		_expect(state.has("roster"), "state export missing roster block")
		_expect(state.has("combat_view"), "state export missing combat_view block")

func _settle_frames(frame_count: int) -> void:
	for _frame_index: int in range(frame_count):
		await get_tree().process_frame

func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)

func _finish() -> void:
	Engine.time_scale = _previous_time_scale
	if _main != null and is_instance_valid(_main):
		if _main.has_method("_reset_run_state"):
			_main.call("_reset_run_state")
		var parent: Node = _main.get_parent()
		if parent != null:
			parent.remove_child(_main)
		_main.free()
		_main = null
	var exit_code: int = 0
	if _failures.is_empty():
		print("AuditPanelSmoke: OK")
	else:
		for failure: String in _failures:
			push_error("AuditPanelSmoke: " + failure)
		exit_code = 1
	get_tree().quit(exit_code)
