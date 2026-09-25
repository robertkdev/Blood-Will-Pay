extends Control
## Fullscreen composition bench. Only instantiated by ArtPreview.tscn.
## The adapter mounts the production scene; this script never redraws its UI.

const SESSION_FILE: String = "res://.godot/art_preview/session.json"
const ADAPTER: Script = preload("res://addons/art_preview/preview_adapter.gd")
const VIEW_SIZE: Vector2i = Vector2i(1920, 1080)

var settings: Dictionary = {}
var debug: bool = false # Compatibility flag read by the production crew nodes.
var revision: int = 0
var _session: Dictionary = {}
var _adapter: RefCounted
var _game: Control
var _baseline: Dictionary = {}
var _definitions: Array[Dictionary] = []
var _capture_timer: Timer
var _capturing: bool = false
var _ready_for_commands: bool = false
var _last_command: String = ""
var _poll_elapsed: float = 0.0
var _run_dir: String = ""
var _reference: String = ""
var _reference_hash: String = ""
var _last_capture: Dictionary = {}
var _error: String = ""
var _owns_lock: bool = false


func _ready() -> void:
	# A fresh editor with a private APPDATA tree is prepared by preview.py.
	# Do not let a preview fixture or an autoload share a player's save directory.
	_session = _read_json(SESSION_FILE)
	_run_dir = str(_session.get("output_dir", ""))
	if _run_dir.is_empty() or not OS.get_user_data_dir().replace("\\", "/").contains("art-preview"):
		_show_boot_error("Start with preview.py prepare and its isolated editor. This scene requires an art-preview user-data directory.")
		return
	if FileAccess.file_exists(_run_dir.path_join("runtime.lock")):
		_show_boot_error("This capture directory already has a runtime owner. Prepare a new session.")
		return
	DirAccess.make_dir_recursive_absolute(_run_dir)
	if _write_json(_run_dir.path_join("runtime.lock"), {"pid": OS.get_process_id(), "session_id": _session.get("session_id", "")}) != OK:
		_show_boot_error("Could not acquire the runtime output lock.")
		return
	_owns_lock = true
	get_window().content_scale_size = VIEW_SIZE
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	get_window().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	get_window().mode = Window.MODE_FULLSCREEN
	get_window().title = "Godot Art Preview"
	_adapter = ADAPTER.new()
	_game = (await _adapter.call("mount", self)) as Control
	if _game == null:
		_show_boot_error("The preview adapter did not mount its production scene.")
		return
	await get_tree().process_frame
	await get_tree().process_frame
	_definitions.assign(_adapter.call("controls", _game))
	_definitions.append_array([
		{"key": "spacing", "label": "Spacing multiplier", "min": 0.5, "max": 2.0, "step": 0.05, "value": 1.0},
		{"key": "typography", "label": "Typography scale", "min": 0.75, "max": 1.5, "step": 0.05, "value": 1.0},
		{"key": "background", "label": "Background visibility", "min": 0.0, "max": 1.0, "step": 0.05, "value": 1.0},
		{"key": "surface_opacity", "label": "Surface opacity", "min": 0.25, "max": 1.0, "step": 0.05, "value": 1.0},
		{"key": "border", "label": "Frame emphasis", "min": 0.0, "max": 3.0, "step": 0.25, "value": 1.0},
		{"key": "roundness", "label": "Corner radius multiplier", "min": 0.0, "max": 2.0, "step": 0.1, "value": 1.0}
	])
	for definition: Dictionary in _definitions:
		settings[str(definition.key)] = float(definition.value)
	_reference = str(_session.get("reference", _adapter.call("default_reference")))
	_reference_hash = str(_session.get("reference_sha256", ""))
	_capture_timer = Timer.new()
	_capture_timer.one_shot = true
	_capture_timer.wait_time = 0.65
	_capture_timer.timeout.connect(_capture)
	add_child(_capture_timer)
	_remember(_game)
	_ready_for_commands = true
	var initial: Dictionary = apply_settings(_session.get("settings", {}))
	if not bool(initial.get("ok", false)):
		_show_boot_error(str(initial.get("error", "Invalid initial preset")))
		return
	_capture_timer.start()
	_write_status()


func _show_boot_error(message: String) -> void:
	_error = message
	_ready_for_commands = false
	var label: Label = Label.new()
	label.text = message
	label.position = Vector2(48, 48)
	label.add_theme_font_size_override("font_size", 24)
	add_child(label)
	push_error(message)
	_write_status()


func _set_reference(path: String, expected_hash: String) -> Dictionary:
	if not FileAccess.file_exists(path) or expected_hash.is_empty() or FileAccess.get_sha256(path) != expected_hash:
		return {"ok": false, "error": "Reference source changed or is missing"}
	_reference = path
	_reference_hash = expected_hash
	revision += 1
	_error = ""
	_capture_timer.start()
	return {"ok": true}


func apply_settings(patch: Dictionary) -> Dictionary:
	# Validate the complete transaction before applying any part of it.
	for key: String in patch:
		if not settings.has(key) or not (patch[key] is float or patch[key] is int):
			return {"ok": false, "error": "Unknown or nonnumeric control: " + key}
		for definition: Dictionary in _definitions:
			if key == str(definition.key) and (not is_finite(float(patch[key])) or float(patch[key]) < float(definition.min) or float(patch[key]) > float(definition.max)):
				return {"ok": false, "error": "Control outside supported range: " + key}
	var changed: bool = false
	for key: String in patch:
		if not is_equal_approx(float(settings[key]), float(patch[key])):
			settings[key] = float(patch[key])
			changed = true
	if changed or revision == 0:
		_remember(_game)
		_apply_common(_game)
		_adapter.call("apply", _game, settings)
		revision += 1
		_error = ""
		_capture_timer.start()
	_write_status()
	return {"ok": true, "changed": changed, "revision": revision}


func _remember(node: Node) -> void:
	if node is Control and not _baseline.has(node.get_instance_id()):
		var control: Control = node as Control
		var record: Dictionary = {"font": {}, "constants": {}, "styles": {}}
		for key: String in ["font_size", "normal_font_size", "bold_font_size", "italics_font_size"]:
			record.font[key] = control.get_theme_font_size(key)
		for key: String in ["separation", "h_separation", "v_separation"]:
			record.constants[key] = control.get_theme_constant(key)
		for key: String in ["panel", "normal", "hover", "pressed", "disabled", "focus"]:
			if control.has_theme_stylebox(key):
				var style: StyleBox = control.get_theme_stylebox(key)
				if style is StyleBoxFlat:
					record.styles[key] = style.duplicate()
		_baseline[node.get_instance_id()] = record
	for child: Node in node.get_children():
		_remember(child)


func _apply_common(node: Node) -> void:
	if node is Control and _baseline.has(node.get_instance_id()):
		var control: Control = node as Control
		var record: Dictionary = _baseline[node.get_instance_id()]
		if control is Label or control is BaseButton or control is LineEdit or control is RichTextLabel:
			for key: String in record.font:
				control.add_theme_font_size_override(key, maxi(9, roundi(float(record.font[key]) * float(settings.typography))))
		if control is Container:
			for key: String in record.constants:
				control.add_theme_constant_override(key, roundi(float(record.constants[key]) * float(settings.spacing)))
		for key: String in record.styles:
			var style: StyleBoxFlat = (record.styles[key] as StyleBoxFlat).duplicate() as StyleBoxFlat
			style.bg_color.a *= float(settings.surface_opacity)
			style.border_width_left = roundi(style.border_width_left * float(settings.border))
			style.border_width_right = roundi(style.border_width_right * float(settings.border))
			style.border_width_top = roundi(style.border_width_top * float(settings.border))
			style.border_width_bottom = roundi(style.border_width_bottom * float(settings.border))
			style.corner_radius_top_left = roundi(style.corner_radius_top_left * float(settings.roundness))
			style.corner_radius_top_right = roundi(style.corner_radius_top_right * float(settings.roundness))
			style.corner_radius_bottom_left = roundi(style.corner_radius_bottom_left * float(settings.roundness))
			style.corner_radius_bottom_right = roundi(style.corner_radius_bottom_right * float(settings.roundness))
			control.add_theme_stylebox_override(key, style)
	for child: Node in node.get_children():
		_apply_common(child)


func _process(delta: float) -> void:
	if not _ready_for_commands:
		return
	_poll_elapsed += delta
	if _poll_elapsed < 0.15 or _capturing:
		return
	_poll_elapsed = 0.0
	var command: Dictionary = _read_json(_run_dir.path_join("command.json"))
	var id: String = str(command.get("id", ""))
	if id.is_empty() or id == _last_command:
		return
	_last_command = id
	var result: Dictionary = {"ok": true}
	if command.get("session_id", "") != _session.get("session_id", ""):
		result = {"ok": false, "error": "Wrong preview session"}
	elif command.has("expected_revision") and int(command.expected_revision) != revision:
		result = {"ok": false, "error": "Revision changed; read status before retrying"}
	else:
		match str(command.get("op", "")):
			"set": result = apply_settings(command.get("settings", {}))
			"reference": result = _set_reference(str(command.get("path", "")), str(command.get("reference_sha256", "")))
			"capture": _capture_timer.start(0.05)
			"quit": get_tree().quit()
			_: result = {"ok": false, "error": "Unknown preview command"}
	result["id"] = id
	result["revision"] = revision
	_write_json(_run_dir.path_join("command-result.json"), result)
	_write_status()


func _input(event: InputEvent) -> void:
	if _ready_for_commands and not _capturing and event is InputEventMouseButton and not event.is_pressed():
		_capture_timer.start()


func _capture() -> void:
	if _capturing:
		_capture_timer.start()
		return
	if not FileAccess.file_exists(_reference) or FileAccess.get_sha256(_reference) != _reference_hash:
		_error = "Reference missing; visual acceptance is blocked. Set a valid reference through the agent command."
		_write_status()
		return
	var reference_image: Image = Image.load_from_file(_reference)
	if reference_image == null or reference_image.is_empty():
		_error = "Reference missing or unreadable; visual acceptance is blocked. Set a valid reference through the agent command."
		_write_status()
		return
	_capturing = true
	_remember(_game)
	_apply_common(_game)
	_adapter.call("apply", _game, settings)
	var captured_revision: int = revision
	var frame_before: int = Engine.get_frames_drawn()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var actual: Image = get_viewport().get_texture().get_image()
	var frame_after: int = Engine.get_frames_drawn()
	if captured_revision != revision or frame_after <= frame_before or actual.is_empty() or actual.get_size() != VIEW_SIZE or get_window().mode not in [Window.MODE_FULLSCREEN, Window.MODE_EXCLUSIVE_FULLSCREEN]:
		_error = "Capture rejected: changed revision, no fresh frame, or viewport is not 1920x1080."
		_capturing = false
		_write_status()
		return
	var capture_id: String = "p%d-r%04d-f%d" % [OS.get_process_id(), revision, frame_after]
	var directory: String = _run_dir.path_join(capture_id)
	DirAccess.make_dir_recursive_absolute(directory)
	var actual_path: String = directory.path_join("actual.png")
	var comparison_path: String = directory.path_join("comparison.png")
	var reference_path: String = directory.path_join("reference." + _reference.get_extension())
	var copied: Error = DirAccess.copy_absolute(ProjectSettings.globalize_path(_reference), reference_path)
	var saved: Error = actual.save_png(actual_path)
	var board: Image = Image.create(VIEW_SIZE.x * 2, VIEW_SIZE.y, false, Image.FORMAT_RGB8)
	board.fill(Color("080e18"))
	var ratio: float = minf(float(VIEW_SIZE.x) / reference_image.get_width(), float(VIEW_SIZE.y) / reference_image.get_height())
	reference_image.resize(roundi(reference_image.get_width() * ratio), roundi(reference_image.get_height() * ratio), Image.INTERPOLATE_LANCZOS)
	reference_image.convert(Image.FORMAT_RGB8)
	actual.convert(Image.FORMAT_RGB8)
	board.blit_rect(reference_image, Rect2i(Vector2i.ZERO, reference_image.get_size()), (VIEW_SIZE - reference_image.get_size()) / 2)
	board.blit_rect(actual, Rect2i(Vector2i.ZERO, VIEW_SIZE), Vector2i(VIEW_SIZE.x, 0))
	var board_saved: Error = board.save_png(comparison_path)
	if saved != OK or copied != OK or board_saved != OK or FileAccess.get_sha256(reference_path) != _reference_hash:
		_error = "Capture could not be saved completely. Check output directory permissions and free space."
		_capturing = false
		_write_status()
		return
	var runtime: Dictionary = _session.get("runtime_provenance", {}).duplicate(true)
	var geometry_records: Array[Dictionary] = _geometry(_game)
	var loaded_sources: Array[String] = []
	for relative: String in _session.get("source_files", {}):
		if ResourceLoader.has_cached("res://" + relative):
			loaded_sources.append(relative)
	for record: Dictionary in geometry_records:
		for key: String in ["script", "texture"]:
			var resource_path: String = str(record.get(key, ""))
			if resource_path.begins_with("res://"):
				var relative: String = resource_path.trim_prefix("res://").split("::")[0]
				if relative not in loaded_sources:
					loaded_sources.append(relative)
	runtime["loaded_sources"] = loaded_sources
	runtime["reference_source"] = ProjectSettings.globalize_path(_reference)
	runtime["reference_source_sha256"] = _reference_hash
	runtime.merge({"project_path": ProjectSettings.globalize_path("res://"), "scene": _adapter.call("scene_path"), "preview_scene": scene_file_path, "session_id": _session.get("session_id", ""), "game_pid": OS.get_process_id(), "engine": Engine.get_version_info().string, "viewport": "1920x1080", "window_mode": get_window().mode, "frames_before": frame_before, "frames_drawn": frame_after, "stale_frame": false, "revision": revision}, true)
	var capture: Dictionary = {"id": capture_id, "revision": revision, "actual": actual_path, "reference": reference_path, "comparison": comparison_path, "reference_sha256": FileAccess.get_sha256(reference_path), "actual_sha256": FileAccess.get_sha256(actual_path), "settings": settings.duplicate(true), "runtime_provenance": runtime, "captured_at_unix": Time.get_unix_time_from_system(), "visual_verdict": "unreviewed"}
	if _write_json(directory.path_join("geometry.json"), {"controls": geometry_records}) != OK or _write_json(directory.path_join("capture.json"), capture) != OK or _write_json(_run_dir.path_join("latest.json"), capture) != OK:
		_error = "Capture metadata could not be saved completely."
		_capturing = false
		_write_status()
		return
	_last_capture = capture
	_write_json(_run_dir.path_join("preset.json"), {"settings": settings, "reference": _reference, "scene": _adapter.call("scene_path")})
	_error = ""
	_capturing = false
	_write_status()


func _geometry(node: Node) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if node is Control and (node as Control).is_visible_in_tree():
		var control: Control = node as Control
		var rect: Rect2 = control.get_global_rect()
		var visible_rect: Rect2 = rect.intersection(Rect2(Vector2.ZERO, Vector2(VIEW_SIZE)))
		var ancestor: Node = control.get_parent()
		while ancestor != null:
			if ancestor is Control and (ancestor as Control).clip_contents:
				visible_rect = visible_rect.intersection((ancestor as Control).get_global_rect())
			ancestor = ancestor.get_parent()
		var minimum: Vector2 = control.get_combined_minimum_size()
		var record: Dictionary = {"path": str(_game.get_path_to(control)), "type": control.get_class(), "rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y], "minimum": [minimum.x, minimum.y], "clip_contents": control.clip_contents, "font_size": control.get_theme_font_size("font_size"), "modulate_alpha": control.modulate.a}
		record["visible_rect"] = [visible_rect.position.x, visible_rect.position.y, visible_rect.size.x, visible_rect.size.y]
		record["on_screen"] = visible_rect.has_area()
		record["scale"] = [control.scale.x, control.scale.y]
		if control.get_script() != null:
			record["script"] = (control.get_script() as Script).resource_path
		if control is Label or control is BaseButton or control is RichTextLabel:
			record["text"] = str(control.get("text"))
		if control is TextureRect and (control as TextureRect).texture != null:
			record["texture"] = (control as TextureRect).texture.resource_path
		if control.has_theme_stylebox("panel") and control.get_theme_stylebox("panel") is StyleBoxFlat:
			var style: StyleBoxFlat = control.get_theme_stylebox("panel") as StyleBoxFlat
			record["surface_alpha"] = style.bg_color.a
			record["border_width"] = style.border_width_left
		result.append(record)
	for child: Node in node.get_children():
		result.append_array(_geometry(child))
	return result


func _write_status() -> void:
	var status: Dictionary = {"ready": _ready_for_commands, "revision": revision, "session_id": _session.get("session_id", ""), "pid": OS.get_process_id(), "settings": settings, "controls": _definitions, "reference": _reference, "last_capture": _last_capture, "error": _error, "user_data_dir": OS.get_user_data_dir()}
	if not _run_dir.is_empty():
		_write_json(_run_dir.path_join("status.json"), status)


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


func _write_json(path: String, value: Dictionary) -> Error:
	var file: FileAccess = FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(value, "\t"))
	var error: Error = file.get_error()
	file.close()
	if error != OK:
		return error
	return DirAccess.rename_absolute(path + ".tmp", path)


func _exit_tree() -> void:
	if _owns_lock:
		DirAccess.remove_absolute(_run_dir.path_join("runtime.lock"))
