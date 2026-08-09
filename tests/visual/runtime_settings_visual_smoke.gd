extends Node

const MAIN_SCENE: PackedScene = preload("res://scenes/Main.tscn")
const OUTPUT_DIR: String = "res://outputs/visual_iter/runtime_settings_pass"
const CAPTURE_NAME: String = "01_runtime_settings_modal_1920x1080.png"

var _failures: Array[String] = []
var _main: Control = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_run")

func _run() -> void:
	var window: Window = get_window()
	if window != null:
		window.size = Vector2i(1920, 1080)
		window.content_scale_size = Vector2i(1920, 1080)
	_main = MAIN_SCENE.instantiate() as Control
	add_child(_main)
	await _settle_frames(6)
	var title_page: Control = _main.get("_title_page") as Control
	var title_menu: Control = _main.get_node_or_null("TitleMenu") as Control
	var combat_view: Control = _main.get_node_or_null("CombatView") as Control
	if title_page != null:
		title_page.visible = false
	if title_menu != null:
		title_menu.visible = false
	if combat_view != null:
		combat_view.visible = true
	_main.call("_open_system_menu")
	await _settle_frames(4)
	var overlay: Control = _main.get("_system_overlay") as Control
	var settings_button: Button = overlay.find_child("SettingsButton", true, false) as Button if overlay != null else null
	_expect(settings_button != null and settings_button.visible, "active System menu did not expose Settings")
	if settings_button != null:
		settings_button.emit_signal("pressed")
	await _settle_frames(8)
	var return_to_run: Button = title_menu.find_child("ReturnToRunButton", true, false) as Button if title_menu != null else null
	var settings_panel: Control = title_menu.find_child("ContentPanel", true, false) as Control if title_menu != null else null
	_expect(get_tree().paused, "runtime Settings did not preserve the paused run")
	_expect(overlay != null and not overlay.visible, "System overlay remained stacked above runtime Settings")
	_expect(title_menu != null and title_menu.visible, "runtime Settings did not become visible")
	_expect(title_menu != null and title_menu.process_mode == Node.PROCESS_MODE_ALWAYS, "runtime Settings stopped processing while paused")
	_expect(combat_view != null and not combat_view.visible, "CombatView remained visible behind runtime Settings")
	_expect(return_to_run != null and return_to_run.visible and return_to_run.has_focus(), "runtime Settings did not focus its Return to Run recovery action")
	_expect(settings_panel != null and get_viewport().get_visible_rect().grow(1.0).encloses(settings_panel.get_global_rect()), "runtime Settings panel escaped the 1920x1080 viewport")
	_save_capture(CAPTURE_NAME)
	if return_to_run != null:
		return_to_run.emit_signal("pressed")
	await _settle_frames(4)
	_expect(not get_tree().paused, "Return to Run left the tree paused")
	_expect(title_menu != null and not title_menu.visible, "Return to Run left runtime Settings visible")
	_expect(combat_view != null and combat_view.visible, "Return to Run did not restore the unchanged CombatView")
	_finish()

func _save_capture(filename: String) -> void:
	var display_name: String = DisplayServer.get_name().to_lower()
	var driver_name: String = RenderingServer.get_current_rendering_driver_name().to_lower()
	if display_name == "headless" or display_name == "server" or display_name == "dummy" or driver_name.contains("dummy"):
		_failures.append("framebuffer capture unavailable for %s" % filename)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var texture: ViewportTexture = get_viewport().get_texture()
	if texture == null or not texture.get_rid().is_valid():
		_failures.append("viewport unavailable for %s" % filename)
		return
	var image: Image = texture.get_image()
	var path: String = "%s/%s" % [OUTPUT_DIR, filename]
	var save_error: Error = image.save_png(path)
	if save_error != OK:
		_failures.append("capture failed for %s error=%d" % [filename, int(save_error)])
		return
	print("RuntimeSettingsVisualSmoke: saved %s" % ProjectSettings.globalize_path(path))

func _finish() -> void:
	get_tree().paused = false
	if _main != null and is_instance_valid(_main):
		var parent: Node = _main.get_parent()
		if parent != null:
			parent.remove_child(_main)
		_main.free()
		_main = null
	if _failures.is_empty():
		print("RuntimeSettingsVisualSmoke: OK")
		get_tree().quit(0)
		return
	for failure: String in _failures:
		push_error("RuntimeSettingsVisualSmoke: " + failure)
	get_tree().quit(1)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

func _settle_frames(count: int) -> void:
	for _frame_index: int in range(count):
		await get_tree().process_frame
