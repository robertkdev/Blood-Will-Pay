extends Node

const COMBAT_VIEW_SCENE: PackedScene = preload("res://scenes/CombatView.tscn")
const OUTPUT_PATH := "res://outputs/blood-will-pay-gothic-ui-battle-pass6.png"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1600, 900))
	var view: Control = COMBAT_VIEW_SCENE.instantiate()
	add_child(view)
	await get_tree().process_frame
	await get_tree().process_frame
	if view.has_method("set_player_team_ids"):
		view.call("set_player_team_ids", ["bonko", "paisley"])
	await get_tree().process_frame
	await get_tree().process_frame
	_save_capture()
	print("CombatViewThemeCapture: ready")

func _save_capture() -> void:
	if _is_framebuffer_unavailable():
		print("CombatViewThemeCapture: skipped capture because framebuffer capture is unavailable")
		return
	var output_dir: String = ProjectSettings.globalize_path("res://outputs")
	DirAccess.make_dir_recursive_absolute(output_dir)
	var texture: ViewportTexture = get_viewport().get_texture()
	if texture == null or not texture.get_rid().is_valid():
		print("CombatViewThemeCapture: skipped capture; viewport texture unavailable")
		return
	var image: Image = texture.get_image()
	if image == null or image.is_empty():
		print("CombatViewThemeCapture: skipped capture; viewport image unavailable")
		return
	var result: Error = image.save_png(OUTPUT_PATH)
	if result != OK:
		push_error("CombatViewThemeCapture: save failed %s" % str(result))
		return
	print("CombatViewThemeCapture: saved %s" % ProjectSettings.globalize_path(OUTPUT_PATH))

func _is_framebuffer_unavailable() -> bool:
	var display_name: String = DisplayServer.get_name().to_lower()
	var driver_name: String = RenderingServer.get_current_rendering_driver_name().to_lower()
	return display_name == "headless" or display_name == "server" or display_name == "dummy" or driver_name.contains("dummy")
