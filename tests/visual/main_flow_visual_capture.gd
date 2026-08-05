extends Node

const MAIN_SCENE: PackedScene = preload("res://scenes/Main.tscn")
const MainTransitionWait: GDScript = preload("res://tests/visual/main_transition_wait.gd")
const OUTPUT_DIR: String = "res://outputs/visual_iter"

var _main: Control = null

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))

	_main = MAIN_SCENE.instantiate() as Control
	add_child(_main)
	await _settle(0.35)
	_save("after_title_pass2.png")

	if _main.has_method("_on_start"):
		_main.call("_on_start")
	await _settle(0.35)
	_save("after_unit_select_pass2.png")

	if _main.has_method("_on_unit_selected"):
		_main.call("_on_unit_selected", "mortem")
	await MainTransitionWait.for_combat_view(self, _main)
	_save("after_combat_initial_pass2.png")

	if Engine.has_singleton("Shop"):
		Shop.add_free_rerolls(1)
		Shop.reroll()
	await _settle(0.65)
	_save("after_combat_shop_offers_pass2.png")

	get_tree().quit(0)

func _settle(seconds: float) -> void:
	for _frame_index: int in range(3):
		await get_tree().process_frame
	await get_tree().create_timer(seconds).timeout
	for _frame_index: int in range(2):
		await get_tree().process_frame

func _save(filename: String) -> void:
	if _is_framebuffer_unavailable():
		print("MainFlowVisualCapture: skipped %s because framebuffer capture is unavailable" % filename)
		return
	var texture: ViewportTexture = get_viewport().get_texture()
	if texture == null or not texture.get_rid().is_valid():
		print("MainFlowVisualCapture: skipped %s; viewport texture unavailable under this renderer." % filename)
		return
	var image: Image = texture.get_image()
	if image == null or image.is_empty():
		print("MainFlowVisualCapture: skipped %s; viewport image unavailable under this renderer." % filename)
		return
	var output_path: String = "%s/%s" % [OUTPUT_DIR, filename]
	var err: Error = image.save_png(output_path)
	if err != OK:
		push_error("MainFlowVisualCapture: failed to save %s error=%s" % [ProjectSettings.globalize_path(output_path), str(int(err))])
		return
	print("MainFlowVisualCapture: saved %s" % ProjectSettings.globalize_path(output_path))

func _is_framebuffer_unavailable() -> bool:
	var display_name: String = DisplayServer.get_name().to_lower()
	var driver_name: String = RenderingServer.get_current_rendering_driver_name().to_lower()
	return display_name == "headless" or display_name == "server" or display_name == "dummy" or driver_name.contains("dummy")
