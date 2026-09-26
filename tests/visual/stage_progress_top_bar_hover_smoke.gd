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
	var token: PanelContainer = top_bar.find_child("StageToken4", true, false) as PanelContainer
	_expect(token != null, "missing visible boss stage token", failures)
	if token != null:
		_expect(token.tooltip_text.contains("Round 4: Boss"), "boss token should retain the native hover description", failures)
		_expect(token.mouse_filter == Control.MOUSE_FILTER_PASS, "visible token must receive hover", failures)
		_expect(top_bar.get_theme_stylebox("panel") is StyleBoxTexture, "chapter bar should retain its material frame", failures)
		var token_rect: Rect2 = token.get_global_rect()
		token.emit_signal("mouse_entered")
		await get_tree().process_frame
		_expect(token.get_global_rect().is_equal_approx(token_rect), "hover must not resize a stage token", failures)
		_expect(_control_inside_viewport(top_bar), "chapter bar should stay within the viewport", failures)
		token.emit_signal("mouse_exited")
		await get_tree().process_frame
	if icon != null:
		_expect(icon.mouse_filter == Control.MOUSE_FILTER_IGNORE, "transparent compatibility icon must not intercept hover", failures)
	if failures.is_empty():
		print("StageProgressTopBarHoverSmoke: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("StageProgressTopBarHoverSmoke: %s" % failure)
	get_tree().quit(1)

func _control_inside_viewport(control: Control) -> bool:
	if control == null:
		return false
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var rect: Rect2 = control.get_global_rect()
	return rect.position.x >= -0.5 and rect.position.y >= -0.5 and rect.end.x <= viewport_size.x + 0.5 and rect.end.y <= viewport_size.y + 0.5

func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
