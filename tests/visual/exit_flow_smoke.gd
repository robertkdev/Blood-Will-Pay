extends Node

const MainScene: PackedScene = preload("res://scenes/Main.tscn")
const MainTransitionWait: GDScript = preload("res://tests/visual/main_transition_wait.gd")
const UnitFactory := preload("res://scripts/unit_factory.gd")
const OUTPUT_DIR: String = "res://outputs/visual_iter/exit_menu_pass"
const SYSTEM_BACKDROP_MAX_ALPHA: float = 0.62
const SYSTEM_BACKDROP_MIN_ALPHA: float = 0.45

var _main: Control
var _failures: Array[String] = []
var _previous_suppress_validation_warnings: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_run")

func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_previous_suppress_validation_warnings = UnitFactory.suppress_validation_warnings
	UnitFactory.suppress_validation_warnings = true

	_main = MainScene.instantiate() as Control
	add_child(_main)
	await _settle_frames(2)

	_expect(_node_visible("TitlePage"), "title page should be visible on boot")
	_expect(not _node_visible("TitleMenu"), "title menu should wait behind the title page on boot")
	_expect(not _button_visible("SystemMenuButton"), "system menu button should be hidden on title")

	_press_title_enter()
	await _settle_frames(2)
	_expect(_node_visible("TitleMenu"), "title menu should be visible after entering title page")
	_press_title_start()
	await _settle_frames(2)
	_expect(_node_visible("UnitSelect"), "unit select should be visible after start")
	_expect(_button_visible("SystemMenuButton"), "system menu button should be visible during unit select")

	_press_button("SystemMenuButton")
	await _settle_frames(1)
	_expect(get_tree().paused, "opening system menu should pause the game")
	_expect(_overlay_visible(), "system menu overlay should be visible during unit select")
	_expect(_system_backdrop_alpha_in_range(), "system menu backdrop should keep underlying context readable")
	_expect(_control_uses_texture_style("SystemMenuButton", "normal"), "system menu button should use the generated small button asset")
	_expect(_control_uses_texture_style("SystemMenuOverlay/Center/Panel", "panel"), "system menu overlay should use the generated wide panel asset")
	_expect(_control_uses_texture_style("SystemMenuOverlay/Center/Panel/Margin/Stack/ResumeButton", "normal"), "resume button should use the generated primary button asset")
	_expect(_button_exists("ResumeButton"), "resume button missing")
	_expect(_button_exists("NewRunButton"), "new run button missing")
	_expect(_button_exists("ReturnTitleButton"), "return to title button missing")
	_expect(_button_exists("QuitGameButton"), "quit game button missing")
	_save_capture("01_unit_select_system_menu.png")
	_press_button("ResumeButton")
	await _settle_frames(2)
	_expect(not get_tree().paused, "resume should unpause the game")
	_expect(not _overlay_visible(), "resume should hide the system menu")

	_press_button("SystemMenuButton")
	_press_button("NewRunButton")
	await _settle_frames(3)
	_expect(not get_tree().paused, "new run should unpause the game")
	_expect(_node_visible("UnitSelect"), "new run should land on unit select")
	_expect(int(GameState.stage) == 1, "new run should reset stage to 1")
	_expect(int(Economy.gold) == int(Economy.STARTING_GOLD), "new run should reset gold to starting value")
	_expect(_unit_select_reset(), "new run should clear unit select choice")

	if _main.has_method("_on_unit_selected"):
		_main.call("_on_unit_selected", "mortem")
	var combat: Control = await MainTransitionWait.for_combat_view(self, _main)
	_expect(combat != null and _node_visible("CombatView"), "combat view should be visible after selecting a unit")
	_expect(_button_visible("SystemMenuButton"), "system menu button should be visible during combat")
	_expect(not _embedded_combat_menu_visible(), "embedded combat menu button should be hidden")

	_press_button("SystemMenuButton")
	await _settle_frames(1)
	_expect(get_tree().paused, "opening system menu in combat should pause")
	_expect(_overlay_visible(), "system menu overlay should be visible during combat")
	_expect(_system_backdrop_alpha_in_range(), "combat system menu backdrop should keep underlying context readable")
	_save_capture("02_combat_system_menu.png")
	_press_button("ReturnTitleButton")
	await _settle_frames(3)
	_expect(not get_tree().paused, "return to title should unpause")
	_expect(_node_visible("TitlePage"), "return to title should show title page")
	_expect(not _node_visible("TitleMenu"), "return to title should hide title menu until entered")
	_expect(not _node_visible("CombatView"), "return to title should hide combat")
	_expect(not _button_visible("SystemMenuButton"), "system menu button should hide on title")
	_expect(GameState.phase == GameState.GamePhase.MENU, "return to title should set menu phase")

	var fake_loss_layer: CanvasLayer = CanvasLayer.new()
	fake_loss_layer.name = "LossOverlayLayer"
	fake_loss_layer.layer = 100
	get_tree().root.add_child(fake_loss_layer)
	_press_title_enter()
	await _settle_frames(2)
	_press_title_start()
	await _settle_frames(2)
	_refresh_system_menu_state()
	await _settle_frames(1)
	_expect(not _button_visible("SystemMenuButton"), "system menu button should hide behind defeat overlay")
	_try_open_system_menu()
	await _settle_frames(1)
	_expect(not get_tree().paused, "defeat overlay should prevent system menu pause")
	_expect(not _overlay_visible(), "defeat overlay should prevent system menu overlay")
	_request_new_run()
	await _settle_frames(4)
	_expect(get_tree().root.get_node_or_null("LossOverlayLayer") == null, "new run should clear defeat overlay layer")
	_expect(_node_visible("UnitSelect"), "new run from overlay state should land on unit select")
	_expect(not get_tree().paused, "new run from overlay state should unpause")
	_expect(_unit_select_reset(), "new run from overlay state should clear unit select choice")

	UnitFactory.suppress_validation_warnings = _previous_suppress_validation_warnings
	if _failures.is_empty():
		print("ExitFlowSmoke: OK")
	else:
		for failure: String in _failures:
			push_error("ExitFlowSmoke: " + failure)
	get_tree().quit()

func _press_title_enter() -> void:
	var button: Button = _main.get_node_or_null("TitlePage/Center/Stack/EnterButton") as Button
	if button == null:
		_expect(false, "title page enter button missing")
		return
	button.pressed.emit()

func _press_title_start() -> void:
	var button: Button = _main.get_node_or_null("TitleMenu/Center/VBox/StartButton") as Button
	if button == null:
		_expect(false, "title start button missing")
		return
	button.pressed.emit()

func _press_button(button_name: String) -> void:
	var button: Button = _main.find_child(button_name, true, false) as Button
	if button == null:
		_expect(false, "%s missing" % button_name)
		return
	button.pressed.emit()

func _try_open_system_menu() -> void:
	if _main != null and _main.has_method("_open_system_menu"):
		_main.call("_open_system_menu")

func _refresh_system_menu_state() -> void:
	if _main != null and _main.has_method("refresh_system_menu_state"):
		_main.call("refresh_system_menu_state")

func _request_new_run() -> void:
	if _main != null and _main.has_method("request_new_run"):
		_main.call("request_new_run")
		return
	_expect(false, "main request_new_run missing")

func _button_exists(button_name: String) -> bool:
	return _main.find_child(button_name, true, false) is Button

func _button_visible(button_name: String) -> bool:
	var button: Button = _main.find_child(button_name, true, false) as Button
	return button != null and button.visible

func _control_uses_texture_style(path_or_name: String, style_name: String) -> bool:
	if _main == null:
		return false
	var control: Control = _main.get_node_or_null("SystemMenuLayer/" + path_or_name) as Control
	if control == null:
		control = _main.find_child(path_or_name, true, false) as Control
	if control == null:
		return false
	return control.get_theme_stylebox(style_name) is StyleBoxTexture

func _overlay_visible() -> bool:
	var overlay: Control = _main.get_node_or_null("SystemMenuLayer/SystemMenuOverlay") as Control
	return overlay != null and overlay.visible

func _system_backdrop_alpha_in_range() -> bool:
	var backdrop: ColorRect = _main.get_node_or_null("SystemMenuLayer/SystemMenuOverlay/Backdrop") as ColorRect
	if backdrop == null:
		return false
	var alpha: float = backdrop.color.a
	return alpha >= SYSTEM_BACKDROP_MIN_ALPHA and alpha <= SYSTEM_BACKDROP_MAX_ALPHA

func _node_visible(path: String) -> bool:
	var node: CanvasItem = _main.get_node_or_null(path) as CanvasItem
	return node != null and node.visible

func _embedded_combat_menu_visible() -> bool:
	var button: Button = _main.get_node_or_null("CombatView/TopBar/MenuButton") as Button
	return button != null and button.visible

func _unit_select_reset() -> bool:
	var select: UnitSelect = _main.get_node_or_null("UnitSelect") as UnitSelect
	if select == null:
		return false
	var start: Button = select.get_node_or_null("Center/HBox/Right/StartButton") as Button
	return select.selected_id == "" and start != null and start.disabled

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

func _settle_frames(count: int) -> void:
	for index: int in range(count):
		await get_tree().process_frame

func _save_capture(filename: String) -> void:
	var display_name: String = DisplayServer.get_name().to_lower()
	if display_name == "headless" or display_name == "server" or display_name == "dummy":
		print("ExitFlowSmoke: skipped %s because framebuffer capture is unavailable" % filename)
		return
	var texture: ViewportTexture = get_viewport().get_texture()
	if texture == null or not texture.get_rid().is_valid():
		print("ExitFlowSmoke: skipped %s because viewport texture is unavailable" % filename)
		return
	var image: Image = texture.get_image()
	if image == null or image.is_empty():
		print("ExitFlowSmoke: skipped %s because viewport image is unavailable" % filename)
		return
	var path: String = "%s/%s" % [OUTPUT_DIR, filename]
	var err: Error = image.save_png(path)
	if err != OK:
		print("ExitFlowSmoke: failed to save %s error=%d" % [ProjectSettings.globalize_path(path), int(err)])
		return
	print("ExitFlowSmoke: saved %s" % ProjectSettings.globalize_path(path))
