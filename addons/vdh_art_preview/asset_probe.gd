extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	if arguments.size() != 2:
		quit(2)
		return
	var paths: Variant = JSON.parse_string(FileAccess.get_file_as_string(arguments[0]))
	var helper: RefCounted = load("res://addons/vdh_art_preview/asset_tools.gd").new()
	var result: Dictionary = helper.stage(paths if paths is Array else [])
	var file := FileAccess.open(arguments[1],FileAccess.WRITE)
	if file == null:
		quit(2)
		return
	file.store_string(JSON.stringify(result))
	file.close()
	quit(0 if result.ok else 1)
