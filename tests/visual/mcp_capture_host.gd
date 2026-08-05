extends Node

const MAIN_SCENE: PackedScene = preload("res://scenes/Main.tscn")
const UserSettingsScript: GDScript = preload("res://scripts/game/settings/user_settings.gd")
const CAPTURE_SETTINGS_PATH: String = "user://mcp_capture_host_settings.cfg"

@export var viewport_size: Vector2i = Vector2i(1920, 1080)
@export_enum("title", "tutorial", "settings") var capture_state: String = "title"
@export var ui_scale: float = 1.0
@export var reduced_motion: bool = false

var _main: Control = null


func _ready() -> void:
	call_deferred("_build_player_runtime")


func _build_player_runtime() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(viewport_size)
	var window: Window = get_window()
	if window != null:
		window.size = viewport_size
		window.content_scale_size = viewport_size
	UserSettingsScript.configure_storage_path(CAPTURE_SETTINGS_PATH)
	UserSettingsScript.initialize(window)
	UserSettingsScript.set_ui_scale(ui_scale, window)
	UserSettingsScript.set_reduced_motion(reduced_motion)

	_main = MAIN_SCENE.instantiate() as Control
	_main.set_anchors_preset(Control.PRESET_FULL_RECT)
	get_tree().root.add_child(_main)
	for _frame: int in range(8):
		await get_tree().process_frame
	if capture_state != "title":
		var enter_button: Button = _main.get_node_or_null("TitlePage/Center/Stack/EnterButton") as Button
		if enter_button != null:
			enter_button.pressed.emit()
		for _frame: int in range(8):
			await get_tree().process_frame
		var title_menu: Control = _main.get_node_or_null("TitleMenu") as Control
		if title_menu != null:
			var section: String = "how_to_play" if capture_state == "tutorial" else "settings"
			title_menu.call("_select_section", section, true)
		for _frame: int in range(8):
			await get_tree().process_frame

	var actual_size: Vector2i = window.size if window != null else Vector2i.ZERO
	print(
		"McpCaptureHost: READY state=%s requested=%dx%d actual=%dx%d"
		% [capture_state, viewport_size.x, viewport_size.y, actual_size.x, actual_size.y]
	)
