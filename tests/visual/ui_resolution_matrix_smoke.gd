extends Node

const SMOKE_NAME: String = "UIResolutionMatrixSmoke"
const MAIN_SCENE: PackedScene = preload("res://scenes/Main.tscn")
const UserSettingsScript: GDScript = preload("res://scripts/game/settings/user_settings.gd")
const TEST_SETTINGS_PATH: String = "user://ui_resolution_matrix_smoke.cfg"
const TEST_ACCOUNT_PROFILE_PATH: String = "user://ui_resolution_matrix_account.json"
const OUTPUT_DIR: String = "res://outputs/visual_iter/ui_resolution_matrix_pass"
const VIEWPORTS: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1920, 1080),
	Vector2i(2560, 1080),
	Vector2i(3840, 2160),
]
const SCALES: Array[float] = [1.0, 1.25, 1.5]

var _failures: Array[String] = []
var _main: Control = null
var _original_window_size: Vector2i = Vector2i.ZERO
var _original_scale: float = 1.0

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var window: Window = get_window()
	_original_window_size = window.size if window != null else Vector2i.ZERO
	_original_scale = window.content_scale_factor if window != null else 1.0
	UserSettingsScript.configure_storage_path(TEST_SETTINGS_PATH)
	for viewport_size: Vector2i in VIEWPORTS:
		for ui_scale: float in SCALES:
			await _verify_configuration(viewport_size, ui_scale)
	_finish()

func _verify_configuration(viewport_size: Vector2i, ui_scale: float) -> void:
	var window: Window = get_window()
	DisplayServer.window_set_size(viewport_size)
	if window != null:
		window.size = viewport_size
		window.content_scale_size = viewport_size
	UserSettingsScript.set_ui_scale(ui_scale, window)
	UserSettingsScript.set_reduced_motion(true)
	_main = MAIN_SCENE.instantiate() as Control
	get_tree().root.add_child(_main)
	await _settle_frames(5)
	var enter_button: Button = _main.get_node_or_null("TitlePage/Center/Stack/EnterButton") as Button
	if enter_button != null:
		enter_button.pressed.emit()
	await _settle_frames(3)
	var title_menu: Control = _main.get_node_or_null("TitleMenu") as Control
	if title_menu != null:
		title_menu.call("_select_section", "settings", false)
		title_menu.call_deferred("_refresh_scaled_layout")
	await _settle_frames(4)
	var viewport_rect: Rect2 = title_menu.get_viewport().get_visible_rect() if title_menu != null else Rect2()
	var label: String = "%dx%d @ %d%%" % [viewport_size.x, viewport_size.y, roundi(ui_scale * 100.0)]
	_expect(title_menu != null and title_menu.visible, "%s title menu missing" % label)
	for control_name: String in [
		"GameTitle",
		"StartButton",
		"BlackLedgerButton",
		"HomeButton",
		"HowToPlayButton",
		"UnitsButton",
		"RGAGlossaryButton",
		"SettingsButton",
		"QuitButton",
		"ContentPanel",
	]:
		var control: Control = title_menu.find_child(control_name, true, false) as Control if title_menu != null else null
		_expect(control != null and _rect_inside(control.get_global_rect(), viewport_rect.grow(2.0)), "%s %s escaped viewport rect=%s viewport=%s" % [label, control_name, str(control.get_global_rect() if control != null else Rect2()), str(viewport_rect)])
		_expect(control != null and control.is_visible_in_tree() and control.modulate.a >= 0.90, "%s %s was contained but not visibly reviewable" % [label, control_name])
	if _should_capture(viewport_size, ui_scale):
		_save_capture("%dx%d_%d_percent_title_menu.png" % [viewport_size.x, viewport_size.y, roundi(ui_scale * 100.0)])
	if _main != null:
		_main.call("open_black_ledger", TEST_ACCOUNT_PROFILE_PATH)
	await _settle_frames(3)
	var ledger: Control = _main.find_child("BlackLedger", true, false) as Control if _main != null else null
	var ledger_panel: PanelContainer = ledger.find_child("LedgerPanel", true, false) as PanelContainer if ledger != null else null
	_expect(ledger_panel != null and _rect_inside(ledger_panel.get_global_rect(), viewport_rect.grow(2.0)), "%s Black Ledger escaped viewport panel=%s viewport=%s" % [label, str(ledger_panel.get_global_rect() if ledger_panel != null else Rect2()), str(viewport_rect)])
	if _should_capture(viewport_size, ui_scale):
		_save_capture("%dx%d_%d_percent_ledger.png" % [viewport_size.x, viewport_size.y, roundi(ui_scale * 100.0)])
	if _main != null:
		_main.call("_close_black_ledger")
	await _settle_frames(1)
	_cleanup_main()

func _should_capture(viewport_size: Vector2i, ui_scale: float) -> bool:
	return (
		(viewport_size == Vector2i(1280, 720) and (is_equal_approx(ui_scale, 1.0) or is_equal_approx(ui_scale, 1.5)))
		or (viewport_size == Vector2i(1920, 1080) and is_equal_approx(ui_scale, 1.0))
		or (viewport_size == Vector2i(2560, 1080) and is_equal_approx(ui_scale, 1.25))
		or (viewport_size == Vector2i(3840, 2160) and is_equal_approx(ui_scale, 1.0))
	)

func _rect_inside(inner: Rect2, outer: Rect2) -> bool:
	return outer.has_point(inner.position) and outer.has_point(inner.end)

func _save_capture(filename: String) -> void:
	var display_name: String = DisplayServer.get_name().to_lower()
	var driver_name: String = RenderingServer.get_current_rendering_driver_name().to_lower()
	if display_name == "headless" or display_name == "server" or display_name == "dummy" or driver_name.contains("dummy"):
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var image: Image = get_viewport().get_texture().get_image()
	var path: String = "%s/%s" % [OUTPUT_DIR, filename]
	var save_error: Error = image.save_png(path)
	if save_error != OK:
		_failures.append("capture failed for %s error=%d" % [filename, int(save_error)])
		return
	print("%s: saved %s" % [SMOKE_NAME, ProjectSettings.globalize_path(path)])

func _cleanup_main() -> void:
	if _main == null or not is_instance_valid(_main):
		_main = null
		return
	var combat_view: Node = _main.get_node_or_null("CombatView")
	if combat_view != null and combat_view.has_method("_teardown"):
		combat_view.call("_teardown")
	var main_parent: Node = _main.get_parent()
	if main_parent != null:
		main_parent.remove_child(_main)
	_main.free()
	_main = null

func _expect(condition: bool, message: String) -> void:
	if not condition and not _failures.has(message):
		_failures.append(message)

func _settle_frames(count: int) -> void:
	for _frame_index: int in range(count):
		await get_tree().process_frame

func _finish() -> void:
	_cleanup_main()
	var window: Window = get_window()
	if window != null:
		window.content_scale_factor = _original_scale
		if _original_window_size != Vector2i.ZERO:
			window.size = _original_window_size
			window.content_scale_size = _original_window_size
	UserSettingsScript.configure_storage_path(UserSettingsScript.DEFAULT_SETTINGS_PATH)
	for path: String in [TEST_SETTINGS_PATH, TEST_ACCOUNT_PROFILE_PATH, "%s.tmp" % TEST_ACCOUNT_PROFILE_PATH, "%s.bak" % TEST_ACCOUNT_PROFILE_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if _failures.is_empty():
		print(SMOKE_NAME + ": OK matrix=4x3")
		get_tree().quit(0)
		return
	for failure: String in _failures:
		push_error(SMOKE_NAME + ": " + failure)
	get_tree().quit(1)
