extends Node

const MAIN_SCENE: PackedScene = preload("res://scenes/Main.tscn")
const UNIT_SELECT_SCENE: PackedScene = preload("res://scenes/UnitSelect.tscn")
const VisionSnapshot := preload("res://scripts/util/vision_snapshot.gd")
const SMOKE_NAME: String = "CompactViewportVisualAuditSmoke"
const OUTPUT_DIR: String = "res://outputs/visual_iter/compact_viewport_audit"
const VIEWPORT_SIZE: Vector2i = Vector2i(1280, 720)

var _main: Control = null
var _unit_select: UnitSelect = null
var _failures: Array[String] = []
var _saved_captures: int = 0

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	DisplayServer.window_set_size(VIEWPORT_SIZE)
	var window: Window = get_window()
	if window != null:
		window.size = VIEWPORT_SIZE
		window.content_scale_size = VIEWPORT_SIZE
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))

	_main = MAIN_SCENE.instantiate() as Control
	_main.set_anchors_preset(Control.PRESET_FULL_RECT)
	get_tree().root.add_child(_main)
	await _settle_frames(8)
	_expect_control_inside(_main.get_node_or_null("TitlePage/Center/Stack") as Control, "title page stack")
	_save_capture("01_title_page_1280x720.png", _main)

	var enter_button: Button = _main.get_node_or_null("TitlePage/Center/Stack/EnterButton") as Button
	if enter_button != null:
		enter_button.emit_signal("pressed")
	await get_tree().create_timer(1.15).timeout
	await _settle_frames(4)
	var title_menu: Control = _main.get_node_or_null("TitleMenu") as Control
	_expect(title_menu != null and title_menu.visible, "title menu did not become visible")
	_expect_control_inside(title_menu, "title menu")
	_save_capture("02_main_menu_1280x720.png", _main)

	if _main != null and is_instance_valid(_main):
		_main.queue_free()
		await _settle_frames(4)

	_unit_select = UNIT_SELECT_SCENE.instantiate() as UnitSelect
	_unit_select.set_anchors_preset(Control.PRESET_FULL_RECT)
	get_tree().root.add_child(_unit_select)
	await _settle_frames(8)
	var first_button: Button = _first_unit_button()
	_expect(first_button != null, "unit select first button missing")
	if first_button != null:
		first_button.emit_signal("mouse_entered")
	await _settle_frames(8)
	_expect_control_inside(_unit_select.get_node_or_null("Center/HBox") as Control, "unit select content")
	_expect_no_button_text_overflow(_unit_select, "unit select")
	_save_capture("03_starter_hover_1280x720.png", _unit_select)

	if first_button != null:
		first_button.button_pressed = true
		first_button.emit_signal("pressed")
	await _settle_frames(8)
	_expect_control_inside(_unit_select.get_node_or_null("Center/HBox") as Control, "unit select selected content")
	_save_capture("04_starter_selected_1280x720.png", _unit_select)

	if _unit_select != null and is_instance_valid(_unit_select):
		_unit_select.queue_free()
		await _settle_frames(4)

	_main = MAIN_SCENE.instantiate() as Control
	_main.set_anchors_preset(Control.PRESET_FULL_RECT)
	get_tree().root.add_child(_main)
	await _settle_frames(8)
	_build_post_shop_state()
	await _settle_frames(16)
	var combat: Control = _main.get_node_or_null("CombatView") as Control
	_expect_control_inside(combat, "combat view")
	_expect_control_inside(_combat_node("MarginContainer/VBoxContainer/BenchArea"), "bench area")
	_expect_control_inside(_combat_node("MarginContainer/VBoxContainer/BottomStorageArea"), "bottom shop area")
	_expect_no_button_text_overflow(combat, "post-shop combat")
	_save_capture("05_post_shop_planning_1280x720.png", _main)
	await _finish()

func _build_post_shop_state() -> void:
	var title_page: Control = _main.get_node_or_null("TitlePage") as Control
	if title_page != null:
		title_page.visible = false
	var title_menu: Control = _main.get_node_or_null("TitleMenu") as Control
	if title_menu != null:
		title_menu.visible = false
	var unit_select: Control = _main.get_node_or_null("UnitSelect") as Control
	if unit_select != null:
		unit_select.visible = false
	var combat: Control = _main.get_node_or_null("CombatView") as Control
	_expect(combat != null, "CombatView missing")
	if combat == null:
		return
	combat.visible = true
	combat.set_process(true)
	if combat.has_method("set_player_team_ids"):
		combat.call("set_player_team_ids", ["bonko", "berebell"])
	if combat.has_method("_init_game"):
		combat.call("_init_game")
	if GameState.has_method("set_chapter_and_stage"):
		GameState.set_chapter_and_stage(1, 2)
	GameState.set_phase(GameState.GamePhase.PREVIEW)
	Economy.reset_run()
	Economy.add_gold(6)
	Economy.set_bet(1)
	Shop.reset_run()
	Shop.set_opening_starter_id("bonko")
	Shop.add_free_rerolls(1)
	var reroll_result: Dictionary = Shop.reroll()
	_expect(bool(reroll_result.get("ok", false)), "compact post-shop reroll failed")
	var manager: Variant = combat.get("manager")
	if manager != null:
		manager.set("stage", 2)
		if manager.has_method("setup_stage_preview"):
			manager.setup_stage_preview()
	var controller: Variant = combat.get("controller")
	if controller != null:
		if controller.has_method("refresh_all_views"):
			controller.call("refresh_all_views")
		if controller.has_method("_set_continue_to_start_text"):
			controller.call("_set_continue_to_start_text")
		if controller.has_method("_sync_bottom_combat_visibility"):
			controller.call("_sync_bottom_combat_visibility", true)
		var economy_ui: Variant = controller.get("economy_ui")
		if economy_ui != null and economy_ui.has_method("refresh"):
			economy_ui.refresh()
	combat.set("planning_timer_total", 120.0)
	combat.set("planning_time_left", 120.0)
	var timer_label: Label = combat.get_node_or_null("MarginContainer/VBoxContainer/PlanningTimerLabel") as Label
	if timer_label != null:
		timer_label.visible = true
		timer_label.text = "Planning: 2:00"

func _combat_node(path: String) -> Control:
	var combat: Control = _main.get_node_or_null("CombatView") as Control
	if combat == null:
		return null
	return combat.get_node_or_null(path) as Control

func _first_unit_button() -> Button:
	if _unit_select == null:
		return null
	return _unit_select.find_child("UnitButton_*", true, false) as Button

func _expect_control_inside(control: Control, label: String) -> void:
	_expect(control != null, "%s missing" % label)
	if control == null:
		return
	var rect: Rect2 = control.get_global_rect()
	var viewport_rect: Rect2 = _viewport_rect()
	_expect(rect.position.x >= viewport_rect.position.x - 1.0, "%s left edge is outside viewport: %s" % [label, str(rect)])
	_expect(rect.position.y >= viewport_rect.position.y - 1.0, "%s top edge is outside viewport: %s" % [label, str(rect)])
	_expect(rect.end.x <= viewport_rect.end.x + 1.0, "%s right edge is outside viewport: %s viewport=%s" % [label, str(rect), str(viewport_rect)])
	_expect(rect.end.y <= viewport_rect.end.y + 1.0, "%s bottom edge is outside viewport: %s viewport=%s" % [label, str(rect), str(viewport_rect)])

func _expect_no_button_text_overflow(root: Node, context: String) -> void:
	if root == null:
		return
	for node: Node in root.find_children("*", "Button", true, false):
		var button: Button = node as Button
		if button == null or not button.visible:
			continue
		var text_size: Vector2 = button.get_theme_font("font").get_string_size(button.text, HORIZONTAL_ALIGNMENT_CENTER, -1, button.get_theme_font_size("font_size"))
		var available_width: float = maxf(1.0, button.size.x - 12.0)
		_expect(text_size.x <= available_width + 1.0, "%s button text overflows %s: text_width=%.1f available=%.1f" % [context, str(button.name), text_size.x, available_width])

func _viewport_rect() -> Rect2:
	var viewport_rect: Rect2 = get_viewport().get_visible_rect()
	if viewport_rect.size.x > 4.0 and viewport_rect.size.y > 4.0:
		return viewport_rect
	return Rect2(Vector2.ZERO, Vector2(VIEWPORT_SIZE))

func _save_capture(filename: String, root_node: Node) -> void:
	if _is_framebuffer_unavailable():
		_save_vision_capture(filename, root_node)
		return
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

func _save_vision_capture(filename: String, root_node: Node) -> void:
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

func _settle_frames(count: int) -> void:
	for _frame_index: int in range(count):
		await get_tree().process_frame

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

func _finish() -> void:
	var exit_code: int = 0
	if _failures.is_empty():
		print("%s: OK captures=%d output=%s" % [SMOKE_NAME, _saved_captures, ProjectSettings.globalize_path(OUTPUT_DIR)])
	else:
		for failure: String in _failures:
			push_error("%s: %s" % [SMOKE_NAME, failure])
		exit_code = 1
	if _main != null and is_instance_valid(_main):
		var combat_view: Node = _main.get_node_or_null("CombatView")
		if combat_view != null and combat_view.has_method("_teardown"):
			combat_view.call("_teardown")
		var main_parent: Node = _main.get_parent()
		if main_parent != null:
			main_parent.remove_child(_main)
		_main.free()
		_main = null
	_unit_select = null
	await _settle_frames(4)
	get_tree().quit(exit_code)
