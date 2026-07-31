extends Node

const SMOKE_NAME: String = "UIResolutionMatrixSmoke"
const MAIN_SCENE: PackedScene = preload("res://scenes/Main.tscn")
const UserSettingsScript: GDScript = preload("res://scripts/game/settings/user_settings.gd")
const AccountProfileStoreScript: GDScript = preload("res://scripts/game/account/account_profile_store.gd")
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
var _capture_count: int = 0

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var window: Window = get_window()
	_original_window_size = window.size if window != null else Vector2i.ZERO
	_original_scale = window.content_scale_factor if window != null else 1.0
	UserSettingsScript.configure_storage_path(TEST_SETTINGS_PATH)
	AccountProfileStoreScript.clear(TEST_ACCOUNT_PROFILE_PATH)
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
	UserSettingsScript.configure_storage_path(TEST_SETTINGS_PATH)
	var scale_save_error: Error = UserSettingsScript.set_ui_scale(ui_scale, window)
	var motion_save_error: Error = UserSettingsScript.set_reduced_motion(true)
	_expect(scale_save_error == OK, "%dx%d @ %d%% scale fixture should persist" % [viewport_size.x, viewport_size.y, roundi(ui_scale * 100.0)])
	_expect(motion_save_error == OK, "%dx%d @ %d%% motion fixture should persist" % [viewport_size.x, viewport_size.y, roundi(ui_scale * 100.0)])
	UserSettingsScript.configure_storage_path(TEST_SETTINGS_PATH)
	_main = MAIN_SCENE.instantiate() as Control
	get_tree().root.add_child(_main)
	await _settle_frames(5)
	_expect(is_equal_approx(UserSettingsScript.get_ui_scale(), ui_scale), "%dx%d @ %d%% Main should load the persisted UI scale" % [viewport_size.x, viewport_size.y, roundi(ui_scale * 100.0)])
	if window != null:
		_expect(is_equal_approx(window.content_scale_factor, ui_scale), "%dx%d @ %d%% Main should apply the persisted UI scale to its window" % [viewport_size.x, viewport_size.y, roundi(ui_scale * 100.0)])
	var enter_button: Button = _main.get_node_or_null("TitlePage/Center/Stack/EnterButton") as Button
	if enter_button != null:
		enter_button.pressed.emit()
	await _settle_frames(3)
	var title_menu: Control = _main.get_node_or_null("TitleMenu") as Control
	var label: String = "%dx%d @ %d%%" % [viewport_size.x, viewport_size.y, roundi(ui_scale * 100.0)]
	if viewport_size == Vector2i(1920, 1080) and is_equal_approx(ui_scale, 1.5):
		var natural_manifest: VBoxContainer = title_menu.find_child("HomeRouteManifest", true, false) as VBoxContainer if title_menu != null else null
		_expect(title_menu != null and is_equal_approx(float(title_menu.get_meta("effective_ui_scale", 0.0)), 1.5), "%s Natural Main should publish the persisted 150 percent layout scale" % label)
		_expect(natural_manifest != null, "%s Natural Main should open with its Available Records manifest" % label)
		if natural_manifest != null:
			_expect_manifest_rows_readable(natural_manifest, "%s Natural Main" % label)
		_expect(_save_capture("1920x1080_150_percent_natural_home_manifest.png"), "%s Natural Main persisted-scale manifest capture was not produced" % label)
	if title_menu != null:
		title_menu.call("_select_section", "settings", false)
		title_menu.call_deferred("_refresh_scaled_layout")
	await _settle_frames(4)
	var viewport_rect: Rect2 = title_menu.get_viewport().get_visible_rect() if title_menu != null else Rect2()
	_expect(title_menu != null and title_menu.visible, "%s title menu missing" % label)
	var title_panel: Panel = title_menu.get_node_or_null("TitlePanel") as Panel if title_menu != null else null
	_expect(title_panel != null, "%s TitlePanel missing" % label)
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
	for rail_control_name: String in [
		"GameTitle",
		"StartButton",
		"BlackLedgerButton",
		"HomeButton",
		"HowToPlayButton",
		"UnitsButton",
		"RGAGlossaryButton",
		"SettingsButton",
		"QuitButton",
	]:
		var rail_control: Control = title_menu.find_child(rail_control_name, true, false) as Control if title_menu != null else null
		_expect(
			title_panel != null and rail_control != null and _rect_inside(rail_control.get_global_rect(), title_panel.get_global_rect().grow(2.0)),
			"%s %s escaped TitlePanel rail control=%s panel=%s" % [label, rail_control_name, str(rail_control.get_global_rect() if rail_control != null else Rect2()), str(title_panel.get_global_rect() if title_panel != null else Rect2())]
		)
	var start_button: Button = title_menu.find_child("StartButton", true, false) as Button if title_menu != null else null
	var continue_button: Button = title_menu.find_child("ContinueRunButton", true, false) as Button if title_menu != null else null
	var settings_button: Button = title_menu.find_child("SettingsButton", true, false) as Button if title_menu != null else null
	var ledger_button: Button = title_menu.find_child("BlackLedgerButton", true, false) as Button if title_menu != null else null
	var quit_button: Button = title_menu.find_child("QuitButton", true, false) as Button if title_menu != null else null
	var continue_is_primary: bool = continue_button != null and continue_button.visible
	var primary_action: Button = continue_button if continue_is_primary else start_button
	_expect(primary_action != null and String(primary_action.get_meta("visual_role", "")) == "primary", "%s resumable or fresh-run entry should own the primary hierarchy role" % label)
	_expect(start_button != null and String(start_button.get_meta("visual_role", "")) == ("secondary" if continue_is_primary else "primary"), "%s New Run should become secondary only while Continue Run is available" % label)
	if continue_is_primary:
		_expect(title_panel != null and _rect_inside(continue_button.get_global_rect(), title_panel.get_global_rect().grow(2.0)), "%s Continue Run escaped TitlePanel" % label)
	_expect(settings_button != null and String(settings_button.get_meta("visual_role", "")) == "selected_navigation", "%s Settings should expose the selected navigation hierarchy role" % label)
	_expect(settings_button != null and bool(settings_button.get_meta("active_page", false)), "%s Settings should retain a persistent active-page marker" % label)
	_expect(settings_button != null and settings_button.text.begins_with("ACTIVE //"), "%s Settings active-page label should survive responsive layout" % label)
	var settings_pressed_style: StyleBoxFlat = settings_button.get_theme_stylebox("pressed") as StyleBoxFlat if settings_button != null else null
	var settings_focus_style: StyleBoxFlat = settings_button.get_theme_stylebox("focus") as StyleBoxFlat if settings_button != null else null
	_expect(
		settings_pressed_style != null and settings_focus_style != null and settings_pressed_style.border_color != settings_focus_style.border_color,
		"%s Settings active-page and keyboard-focus surfaces should remain distinct" % label
	)
	_expect(
		settings_focus_style != null and settings_focus_style.border_color.b > settings_focus_style.border_color.r,
		"%s Settings focus should use the non-red signal-blue channel" % label
	)
	var settings_docket: PanelContainer = title_menu.find_child("SettingsDocket", true, false) as PanelContainer if title_menu != null else null
	_expect(settings_docket != null and _rect_inside(settings_docket.get_global_rect(), viewport_rect.grow(2.0)), "%s Settings field-record docket escaped the viewport" % label)
	_expect(ledger_button != null and String(ledger_button.get_meta("visual_role", "")) == "ledger", "%s Black Ledger should expose a distinct ledger hierarchy role" % label)
	_expect(quit_button != null and String(quit_button.get_meta("visual_role", "")) == "quit", "%s Quit should expose a distinct destructive hierarchy role" % label)
	_expect(
		primary_action != null and settings_button != null and ledger_button != null and quit_button != null
		and _style_texture_path(primary_action) != _style_texture_path(settings_button)
		and _style_texture_path(settings_button) != _style_texture_path(ledger_button)
		and _style_texture_path(ledger_button) != _style_texture_path(quit_button),
		"%s primary, selected, ledger, and Quit actions should use visibly distinct plate families" % label
	)
	var effective_height: float = float(viewport_size.y) / ui_scale
	if effective_height < 640.0:
		var compact_actions: Array[Button] = [start_button, settings_button, ledger_button, quit_button]
		for compact_action: Button in compact_actions:
			_expect(
				compact_action != null and compact_action.get_theme_font_size("font_size") >= 16,
				"%s compact action text should remain at least 16px" % label
			)
	if _should_capture(viewport_size, ui_scale):
		var settings_filename: String = "%dx%d_%d_percent_title_menu.png" % [viewport_size.x, viewport_size.y, roundi(ui_scale * 100.0)]
		_expect(_save_capture(settings_filename), "%s settings capture was not produced" % label)
	if title_menu != null:
		title_menu.call("_select_section", "home", true)
	await _settle_frames(3)
	var route_manifest: VBoxContainer = title_menu.find_child("HomeRouteManifest", true, false) as VBoxContainer if title_menu != null else null
	var content_scroll: ScrollContainer = title_menu.find_child("ContentScroll", true, false) as ScrollContainer if title_menu != null else null
	_expect(route_manifest != null and content_scroll != null, "%s Available Records manifest or scroll surface missing" % label)
	_expect(
		route_manifest != null and content_scroll != null
		and route_manifest.get_global_rect().position.x >= content_scroll.get_global_rect().position.x - 2.0
		and route_manifest.get_global_rect().end.x <= content_scroll.get_global_rect().end.x + 2.0,
		"%s Available Records manifest escaped the horizontal scroll bounds" % label
	)
	_expect(content_scroll != null and content_scroll.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED, "%s Available Records must remain vertically scrollable when scaled" % label)
	if route_manifest != null:
		_expect_manifest_rows_readable(route_manifest, label)
	if _main != null:
		_main.call("open_black_ledger", TEST_ACCOUNT_PROFILE_PATH)
	await _settle_frames(3)
	var ledger: Control = _main.find_child("BlackLedger", true, false) as Control if _main != null else null
	var ledger_panel: PanelContainer = ledger.find_child("LedgerPanel", true, false) as PanelContainer if ledger != null else null
	_expect(ledger_panel != null and _rect_inside(ledger_panel.get_global_rect(), viewport_rect.grow(2.0)), "%s Black Ledger escaped viewport panel=%s viewport=%s" % [label, str(ledger_panel.get_global_rect() if ledger_panel != null else Rect2()), str(viewport_rect)])
	var effective_width: float = float(viewport_size.x) / ui_scale
	if effective_width >= 1440.0:
		_expect(
			ledger_panel != null and ledger_panel.size.y >= 630.0 and ledger_panel.size.y <= 670.0,
			"%s sparse Black Ledger should remain content-height at wide scale, got %.1f" % [label, ledger_panel.size.y if ledger_panel != null else -1.0]
		)
	if viewport_size == Vector2i(1920, 1080) and is_equal_approx(ui_scale, 1.0):
		_expect(
			ledger != null and bool(ledger.get("_sparse_content_record")),
			"%s fresh Black Ledger should identify its actually rendered content as sparse" % label
		)
		_expect(
			ledger_panel != null and ledger_panel.size.y >= 630.0 and ledger_panel.size.y <= 670.0,
			"%s fresh Black Ledger should preserve its dedicated record and footer gutters, got %.1f" % [label, ledger_panel.size.y if ledger_panel != null else -1.0]
		)
	if _should_capture(viewport_size, ui_scale):
		var ledger_filename: String = "%dx%d_%d_percent_ledger.png" % [viewport_size.x, viewport_size.y, roundi(ui_scale * 100.0)]
		_expect(_save_capture(ledger_filename), "%s Black Ledger capture was not produced" % label)
	if _main != null:
		_main.call("_close_black_ledger")
	await _settle_frames(1)
	_cleanup_main()

func _should_capture(viewport_size: Vector2i, ui_scale: float) -> bool:
	return (
		(viewport_size == Vector2i(1280, 720) and (is_equal_approx(ui_scale, 1.0) or is_equal_approx(ui_scale, 1.5)))
		or (viewport_size == Vector2i(1920, 1080) and is_equal_approx(ui_scale, 1.0))
		or (viewport_size == Vector2i(1920, 1080) and is_equal_approx(ui_scale, 1.5))
		or (viewport_size == Vector2i(2560, 1080) and is_equal_approx(ui_scale, 1.25))
		or (viewport_size == Vector2i(3840, 2160) and is_equal_approx(ui_scale, 1.0))
	)

func _expect_manifest_rows_readable(route_manifest: VBoxContainer, label: String) -> void:
	var previous_route_bottom: float = -1.0
	for record_number: String in ["01", "02", "03", "04"]:
		var route: Button = route_manifest.get_node_or_null("ManifestRoute%s" % record_number) as Button
		var serial: Label = route.get_node_or_null("BoundCopy/Serial") as Label if route != null else null
		var record_title: Label = route.get_node_or_null("BoundCopy/RecordCopy/RecordTitle") as Label if route != null else null
		var record_description: Label = route.get_node_or_null("BoundCopy/RecordCopy/RecordDescription") as Label if route != null else null
		_expect(route != null and route.size.x >= route_manifest.size.x - 2.0, "%s Record %s should fill the joined manifest width" % [label, record_number])
		_expect(serial != null and record_title != null and record_description != null, "%s Record %s should bind serial, title, and description" % [label, record_number])
		_expect(record_description != null and record_description.get_theme_font_size("font_size") >= 18, "%s Record %s description should remain functional-size copy" % [label, record_number])
		if route != null and record_title != null and record_description != null:
			var route_rect: Rect2 = route.get_global_rect()
			var title_rect: Rect2 = record_title.get_global_rect()
			var description_rect: Rect2 = record_description.get_global_rect()
			_expect(title_rect.end.y <= description_rect.position.y + 1.0, "%s Record %s title and description overlap title=%s description=%s" % [label, record_number, str(title_rect), str(description_rect)])
			_expect(description_rect.end.y <= route_rect.end.y - 4.0, "%s Record %s description escaped its row description=%s row=%s" % [label, record_number, str(description_rect), str(route_rect)])
			_expect(previous_route_bottom < 0.0 or route_rect.position.y >= previous_route_bottom - 1.0, "%s Record %s overlaps the preceding record row" % [label, record_number])
			previous_route_bottom = route_rect.end.y
		var route_focus: StyleBoxFlat = route.get_theme_stylebox("focus") as StyleBoxFlat if route != null else null
		var route_pressed: StyleBoxFlat = route.get_theme_stylebox("pressed") as StyleBoxFlat if route != null else null
		_expect(route_focus != null and route_pressed != null and route_focus.border_color != route_pressed.border_color, "%s Record %s focus should remain distinct from pressed blood" % [label, record_number])

func _rect_inside(inner: Rect2, outer: Rect2) -> bool:
	return outer.has_point(inner.position) and outer.has_point(inner.end)

func _style_texture_path(control: Control) -> String:
	if control == null:
		return ""
	var style: StyleBoxTexture = control.get_theme_stylebox("normal") as StyleBoxTexture
	if style == null or style.texture == null:
		return ""
	return style.texture.resource_path

func _save_capture(filename: String) -> bool:
	if not _framebuffer_capture_available():
		print("%s: explicit headless capture skipped for %s" % [SMOKE_NAME, filename])
		return true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	RenderingServer.force_draw(false)
	var texture: ViewportTexture = get_viewport().get_texture()
	if texture == null or not texture.get_rid().is_valid():
		_failures.append("capture failed for %s: viewport texture unavailable" % filename)
		return false
	var image: Image = texture.get_image()
	if image == null or image.is_empty() or image.get_width() <= 0 or image.get_height() <= 0:
		_failures.append("capture failed for %s: viewport image unavailable" % filename)
		return false
	var path: String = "%s/%s" % [OUTPUT_DIR, filename]
	var save_error: Error = image.save_png(path)
	if save_error != OK:
		_failures.append("capture failed for %s error=%d" % [filename, int(save_error)])
		return false
	if not FileAccess.file_exists(path) or FileAccess.get_file_as_bytes(path).is_empty():
		_failures.append("capture failed for %s: saved file was missing or empty" % filename)
		return false
	_capture_count += 1
	print("%s: saved %s" % [SMOKE_NAME, ProjectSettings.globalize_path(path)])
	return true

func _framebuffer_capture_available() -> bool:
	var display_name: String = DisplayServer.get_name().to_lower()
	var driver_name: String = RenderingServer.get_current_rendering_driver_name().to_lower()
	return display_name != "headless" and display_name != "server" and display_name != "dummy" and not driver_name.contains("dummy")

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
	if _framebuffer_capture_available():
		_expect(_capture_count == 13, "expected 13 non-empty settings/Ledger/home-manifest proof images, produced %d" % _capture_count)
	if _failures.is_empty():
		print(SMOKE_NAME + ": OK matrix=4x3")
		get_tree().quit(0)
		return
	for failure: String in _failures:
		push_error(SMOKE_NAME + ": " + failure)
	get_tree().quit(1)
