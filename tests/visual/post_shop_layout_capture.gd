extends Node

const MAIN_SCENE: PackedScene = preload("res://scenes/Main.tscn")
const OUTPUT_DIR: String = "res://outputs/visual_iter/post_shop_layout_pass"

var _main: Control = null
var _failures: Array[String] = []

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	var window: Window = get_window()
	if window != null:
		window.size = Vector2i(1920, 1080)
		window.content_scale_size = Vector2i(1920, 1080)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_main = MAIN_SCENE.instantiate() as Control
	_main.set_anchors_preset(Control.PRESET_FULL_RECT)
	get_tree().root.add_child(_main)
	await _settle_frames(5)
	_build_post_shop_state()
	await _settle_frames(12)
	_capture("01_post_shop_layout.png")
	_finish()

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
	_expect(bool(reroll_result.get("ok", false)), "post-shop layout reroll failed")
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

func _capture(filename: String) -> void:
	if _is_framebuffer_unavailable():
		_expect(false, "framebuffer unavailable for %s" % filename)
		return
	var texture: ViewportTexture = get_viewport().get_texture()
	if texture == null or not texture.get_rid().is_valid():
		_expect(false, "viewport texture unavailable for %s" % filename)
		return
	var image: Image = texture.get_image()
	if image == null or image.is_empty():
		_expect(false, "viewport image unavailable for %s" % filename)
		return
	var path: String = "%s/%s" % [OUTPUT_DIR, filename]
	var error: Error = image.save_png(path)
	_expect(error == OK, "failed to save %s error=%d" % [ProjectSettings.globalize_path(path), int(error)])
	if error == OK:
		print("PostShopLayoutCapture: saved %s" % ProjectSettings.globalize_path(path))

func _is_framebuffer_unavailable() -> bool:
	var display_name: String = DisplayServer.get_name().to_lower()
	var driver_name: String = RenderingServer.get_current_rendering_driver_name().to_lower()
	return display_name == "headless" or display_name == "server" or display_name == "dummy" or driver_name.contains("dummy")

func _settle_frames(count: int) -> void:
	for frame_index: int in range(count):
		await get_tree().process_frame

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

func _finish() -> void:
	var exit_code: int = 0
	if _failures.is_empty():
		print("PostShopLayoutCapture: OK output=%s" % ProjectSettings.globalize_path(OUTPUT_DIR))
	else:
		for failure: String in _failures:
			push_error("PostShopLayoutCapture: " + failure)
		exit_code = 1
	get_tree().quit(exit_code)
