extends "res://tests/visual/actual_run_loop_smoke.gd"

const VisionSnapshot := preload("res://scripts/util/vision_snapshot.gd")
const SMOKE_NAME: String = "OpeningFightVisualSmoke"
const OUTPUT_DIR: String = "res://outputs/visual_iter/opening_fight_copy_pass"
const STARTER_ID: String = "bonko"
const START_OPENING_FIGHT_TEXT: String = "Start Opening Fight"
const OPENING_FIGHT_LABEL: String = "OPENING FIGHT"
const OPENING_FIGHT_HINT: String = "Win this opener to unlock the shop"
const OPENING_FIGHT_MESSAGE: String = "Opening fight is fixed. Win it to unlock the shop."

var _saved_captures: int = 0
var _finished_opening_smoke: bool = false

func _uses_manual_opening_continue() -> bool:
	return true

func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	var window: Window = get_window()
	if window != null:
		window.size = Vector2i(1920, 1080)
		window.content_scale_size = Vector2i(1920, 1080)
	_previous_time_scale = Engine.time_scale
	_previous_suppress_validation_warnings = UnitFactory.suppress_validation_warnings
	UnitFactory.suppress_validation_warnings = true
	Engine.time_scale = 1.0
	_main = MAIN_SCENE.instantiate() as Control
	_main.set_anchors_preset(Control.PRESET_FULL_RECT)
	_main.offset_left = 0.0
	_main.offset_top = 0.0
	_main.offset_right = 0.0
	_main.offset_bottom = 0.0
	get_tree().root.add_child(_main)
	await _settle_frames(4)

	await _ensure_unit_select()
	await _select_starter(STARTER_ID)
	await _settle_frames(6)
	_expect(_node_visible("CombatView"), "CombatView did not open for opening-fight smoke")
	_verify_opening_fight_state()
	_set_planning_timer_safe()
	_normalize_capture_timer()
	await get_tree().process_frame
	_save_capture("01_opening_fight_locked_shop.png")
	await _click_opening_placeholder()
	await _settle_frames(3)
	_expect(_find_label_with_text(_main, OPENING_FIGHT_MESSAGE) != null, "opening placeholder feedback label missing")
	_save_capture("02_opening_fight_feedback.png")
	_finish_opening_smoke()

func _verify_opening_fight_state() -> void:
	var continue_button: Button = _main.find_child("ContinueButton", true, false) as Button
	_expect(continue_button != null and String(continue_button.text) == START_OPENING_FIGHT_TEXT, "continue button should read %s" % START_OPENING_FIGHT_TEXT)
	_expect(_find_label_with_text(_main, OPENING_FIGHT_LABEL) != null, "opening fight label missing")
	_expect(_find_label_with_text(_main, OPENING_FIGHT_HINT) != null, "opening fight hint missing")
	_expect(_opening_shop_buttons_disabled(), "opening shop controls should be disabled")
	var bet_slider: HSlider = _main.find_child("BetSlider", true, false) as HSlider
	_expect(bet_slider != null, "BetSlider missing")
	if bet_slider != null:
		_expect(not bet_slider.visible, "opening bet slider should be hidden")
		_expect(not bet_slider.editable, "opening bet slider should be locked")
	var bet_value: Label = _main.find_child("BetValue", true, false) as Label
	_expect(bet_value != null and String(bet_value.text) == "Opening bet: 1", "opening bet copy missing")
	var placeholder: PanelContainer = _opening_placeholder_panel()
	_expect(placeholder != null, "opening placeholder panel missing")
	if placeholder != null:
		_expect(String(placeholder.tooltip_text) == OPENING_FIGHT_MESSAGE, "opening placeholder tooltip mismatch")

func _click_opening_placeholder() -> void:
	var placeholder: PanelContainer = _opening_placeholder_panel()
	_expect(placeholder != null, "opening placeholder panel missing before feedback click")
	if placeholder == null:
		return
	var mouse_event: InputEventMouseButton = InputEventMouseButton.new()
	mouse_event.button_index = MOUSE_BUTTON_LEFT
	mouse_event.pressed = true
	placeholder.emit_signal("gui_input", mouse_event)
	await get_tree().process_frame

func _opening_placeholder_panel() -> PanelContainer:
	var label: Label = _find_label_with_text(_main, OPENING_FIGHT_LABEL)
	if label == null:
		return null
	var current: Node = label
	while current != null:
		if current is PanelContainer:
			return current as PanelContainer
		current = current.get_parent()
	return null

func _find_label_with_text(root: Node, text: String) -> Label:
	if root == null:
		return null
	if root is Label and String((root as Label).text) == text:
		return root as Label
	for child: Node in root.get_children():
		var found: Label = _find_label_with_text(child, text)
		if found != null:
			return found
	return null

func _normalize_capture_timer() -> void:
	var combat: Control = _main.get_node_or_null("CombatView") as Control
	if combat == null:
		return
	combat.set("planning_timer_total", 60.0)
	combat.set("planning_time_left", 60.0)
	var timer_label: Label = combat.get_node_or_null("MarginContainer/VBoxContainer/PlanningTimerLabel") as Label
	if timer_label != null:
		timer_label.text = "Planning: 1:00"

func _save_capture(filename: String) -> void:
	if _is_framebuffer_unavailable():
		_save_vision_capture(filename)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var texture: ViewportTexture = get_viewport().get_texture()
	if texture == null or not texture.get_rid().is_valid():
		push_error("%s: skipped %s; viewport texture unavailable" % [SMOKE_NAME, filename])
		return
	var image: Image = texture.get_image()
	if image == null or image.is_empty():
		push_error("%s: skipped %s; viewport image unavailable" % [SMOKE_NAME, filename])
		return
	var path: String = "%s/%s" % [OUTPUT_DIR, filename]
	var error: Error = image.save_png(path)
	if error != OK:
		push_error("%s: failed to save %s error=%s" % [SMOKE_NAME, ProjectSettings.globalize_path(path), str(int(error))])
		return
	_saved_captures += 1
	print("%s: saved %s" % [SMOKE_NAME, ProjectSettings.globalize_path(path)])

func _save_vision_capture(filename: String) -> void:
	var root_node: Node = _main if _main != null else self
	var result: Dictionary[String, Variant] = VisionSnapshot.capture(root_node, filename.get_basename(), OUTPUT_DIR)
	if not bool(result.get("ok", false)):
		push_error("%s: vision fallback failed for %s reason=%s" % [SMOKE_NAME, filename, str(result.get("reason", ""))])
		return
	_saved_captures += 1
	print("%s: saved %s via %s" % [SMOKE_NAME, ProjectSettings.globalize_path(str(result.get("path", ""))), str(result.get("kind", ""))])

func _is_framebuffer_unavailable() -> bool:
	var display_name: String = DisplayServer.get_name().to_lower()
	var driver_name: String = RenderingServer.get_current_rendering_driver_name().to_lower()
	return display_name == "headless" or display_name == "server" or display_name == "dummy" or driver_name.contains("dummy")

func _finish_opening_smoke() -> void:
	if _finished_opening_smoke:
		return
	_finished_opening_smoke = true
	Engine.time_scale = _previous_time_scale
	UnitFactory.suppress_validation_warnings = _previous_suppress_validation_warnings
	_flush_synthetic_input()
	var exit_code: int = 0
	if _failures.is_empty():
		print("%s: OK captures=%d output=%s" % [SMOKE_NAME, _saved_captures, ProjectSettings.globalize_path(OUTPUT_DIR)])
	else:
		for failure: String in _failures:
			push_error(SMOKE_NAME + ": " + failure)
		exit_code = 1
	_write_terminal_evidence(exit_code)
	_cleanup_runtime()
	await get_tree().create_timer(2.0, true, false, true).timeout
	get_tree().quit(exit_code)

func _finish() -> void:
	_finish_opening_smoke()

func _write_terminal_evidence(exit_code: int) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var path: String = "%s/result.json" % OUTPUT_DIR
	var output_file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if output_file == null:
		push_warning("%s: could not write terminal evidence" % SMOKE_NAME)
		return
	output_file.store_string(JSON.stringify({
		"smoke": SMOKE_NAME,
		"passed": exit_code == 0,
		"failures": _failures,
		"captures": _saved_captures,
		"shop_buttons": _shop_button_evidence(),
	}, "\t"))
	output_file.close()

func _shop_button_evidence() -> Array[Dictionary]:
	var evidence: Array[Dictionary] = []
	if _main == null:
		return evidence
	for node: Node in _main.find_children("*", "Button", true, false):
		var button: Button = node as Button
		if button != null and (button.text.begins_with("Reroll") or button.text.begins_with("Lock") or button.text.begins_with("Buy XP")):
			evidence.append({"text": button.text, "disabled": button.disabled, "visible": button.is_visible_in_tree()})
	return evidence
