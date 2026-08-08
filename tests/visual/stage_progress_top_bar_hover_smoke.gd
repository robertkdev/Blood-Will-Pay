extends Node

const StageProgressTopBar := preload("res://scripts/ui/combat/stage_progress_top_bar.gd")
const ProgressionConfig := preload("res://scripts/game/progression/progression_config.gd")

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var window: Window = get_window()
	if window != null:
		window.size = Vector2i(1280, 720)
		window.content_scale_size = Vector2i(1280, 720)
	var failures: Array[String] = []
	var top_bar: Control = StageProgressTopBar.new() as Control
	top_bar.position = Vector2(120.0, 40.0)
	add_child(top_bar)
	await get_tree().process_frame
	top_bar.call("update_progress", 1, ProgressionConfig.BOSS_STAGE, ProgressionConfig.STAGES_PER_CHAPTER)
	await get_tree().process_frame
	var icon: TextureRect = top_bar.find_child("StageIcon4", true, false) as TextureRect
	_expect(icon != null, "missing boss stage icon", failures)
	if icon != null:
		_expect(String(icon.tooltip_text) == "", "stage icon should suppress native tooltip text", failures)
		_expect(String(icon.get_meta("stage_hover_text", "")).contains("Stage 4: Boss"), "stage icon should retain hover text metadata", failures)
		icon.emit_signal("mouse_entered")
		await get_tree().process_frame
		var tooltip: PanelContainer = get_tree().root.find_child("StageProgressTooltip", true, false) as PanelContainer
		_expect(tooltip != null, "hover should create StageProgressTooltip", failures)
		if tooltip != null:
			_expect(tooltip.get_theme_stylebox("panel") is StyleBoxTexture, "stage hover should use gothic generated panel style", failures)
			_expect(_tooltip_contains(tooltip, "Stage 4: Boss"), "stage hover should show boss title", failures)
			_expect(_control_inside_viewport(tooltip), "stage hover should stay inside viewport", failures)
		icon.emit_signal("mouse_exited")
		await get_tree().process_frame
		_expect(get_tree().root.find_child("StageProgressTooltip", true, false) == null, "hover exit should clear StageProgressTooltip", failures)
	if failures.is_empty():
		print("StageProgressTopBarHoverSmoke: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("StageProgressTopBarHoverSmoke: %s" % failure)
	get_tree().quit(1)

func _tooltip_contains(root: Control, needle: String) -> bool:
	if root == null:
		return false
	for node: Node in root.find_children("*", "Label", true, false):
		var label: Label = node as Label
		if label != null and String(label.text).contains(needle):
			return true
	return false

func _control_inside_viewport(control: Control) -> bool:
	if control == null:
		return false
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var rect: Rect2 = control.get_global_rect()
	return rect.position.x >= -0.5 and rect.position.y >= -0.5 and rect.end.x <= viewport_size.x + 0.5 and rect.end.y <= viewport_size.y + 0.5

func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
