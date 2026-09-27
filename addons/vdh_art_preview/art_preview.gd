extends Control
## Fullscreen composition bench. Only instantiated by ArtPreview.tscn.
## The adapter mounts the production scene; this script never redraws its UI.

const SESSION_FILE: String = "res://.godot/art_preview/session.json"
var view_size: Vector2i = Vector2i(1920, 1080)

var settings: Dictionary = {}
var revision: int = 0
var _session: Dictionary = {}
var _adapter: RefCounted
var _game: Node
var _style: RefCounted = preload("res://addons/vdh_art_preview/composition_style.gd").new()
var _definitions: Array[Dictionary] = []
var _capture_timer: Timer
var _capturing: bool = false
var _capture_thread: Thread
var _ready_for_commands: bool = false
var _last_command: String = ""
var _run_dir: String = ""
var _reference: String = ""
var _reference_hash: String = ""
var _last_capture: Dictionary = {}
var _error: String = ""
var _owns_lock: bool = false
var _scene_tools: RefCounted
var _runtime_tools: RefCounted
var _input_tools: RefCounted
var _last_poll_ms: int = 0
var _asset_reload: Dictionary = {}
var _last_asset_reload: Dictionary = {}
var _arrangement: Dictionary = {}
var _typography: Dictionary = {}
var _vector: Dictionary = {}
var _surface: Dictionary = {}
var _exploration: Dictionary = {}
var _publications: RefCounted = preload("res://addons/vdh_art_preview/json_publications.gd").new()
var _publication_failed: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# A fresh editor with a private APPDATA tree is prepared by preview.py.
	# Do not let a preview fixture or an autoload share a player's save directory.
	_session = _read_json(SESSION_FILE)
	var dimensions: Array = _session.get("viewport_size", [1920, 1080])
	view_size = Vector2i(int(dimensions[0]), int(dimensions[1]))
	_run_dir = str(_session.get("output_dir", ""))
	if _run_dir.is_empty() or not OS.get_user_data_dir().replace("\\", "/").contains("art-preview"):
		_show_boot_error("Start with preview.py prepare and its isolated editor. This scene requires an art-preview user-data directory.")
		return
	if FileAccess.file_exists(_run_dir.path_join("runtime.lock")):
		push_error("This capture directory already has a runtime owner. Prepare a new session.")
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(_run_dir)
	if _write_json(_run_dir.path_join("runtime.lock"), {"pid": OS.get_process_id(), "session_id": _session.get("session_id", "")}) != OK:
		_show_boot_error("Could not acquire the runtime output lock.")
		return
	_owns_lock = true
	get_window().content_scale_size = view_size
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	get_window().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	get_window().mode = Window.MODE_FULLSCREEN
	get_window().title = "Godot Art Preview"
	var adapter_script: Script = load(str(_session.get("adapter", "res://addons/vdh_art_preview/generic_adapter.gd"))) as Script
	if adapter_script == null:
		_show_boot_error("Could not load the configured adapter")
		return
	_adapter = adapter_script.new()
	if _adapter.has_method("configure"):
		_adapter.call("configure", _session)
	_game = (await _adapter.call("mount", self)) as Node
	if _game == null:
		_show_boot_error("The preview adapter did not mount its production scene.")
		return
	await get_tree().process_frame
	await get_tree().process_frame
	_scene_tools = preload("res://addons/vdh_art_preview/scene_tools.gd").new()
	_scene_tools.configure(_game)
	_definitions.assign(_adapter.call("controls", _game))
	var common: Array[Dictionary] = [
		{"key": "spacing", "label": "Spacing multiplier", "min": 0.5, "max": 2.0, "step": 0.05, "value": 1.0},
		{"key": "typography", "label": "Typography scale", "min": 0.75, "max": 1.5, "step": 0.05, "value": 1.0},
		{"key": "background", "label": "Background visibility", "min": 0.0, "max": 1.0, "step": 0.05, "value": 1.0},
		{"key": "surface_opacity", "label": "Surface opacity", "min": 0.25, "max": 1.0, "step": 0.05, "value": 1.0},
		{"key": "border", "label": "Frame emphasis", "min": 0.0, "max": 3.0, "step": 0.25, "value": 1.0},
		{"key": "roundness", "label": "Corner radius multiplier", "min": 0.0, "max": 2.0, "step": 0.1, "value": 1.0}
	]
	var existing: Array[String] = []
	for definition: Dictionary in _definitions:
		existing.append(str(definition.key))
	for definition: Dictionary in common:
		if str(definition.key) not in existing:
			_definitions.append(definition)
	for definition: Dictionary in _definitions:
		settings[str(definition.key)] = float(definition.value)
	_reference = str(_session.get("reference", _adapter.call("default_reference")))
	_reference_hash = str(_session.get("reference_sha256", ""))
	_capture_timer = Timer.new()
	_capture_timer.one_shot = true
	_capture_timer.ignore_time_scale = true
	_capture_timer.process_mode = Node.PROCESS_MODE_ALWAYS
	_capture_timer.wait_time = 0.65
	_capture_timer.timeout.connect(_capture)
	add_child(_capture_timer)
	_runtime_tools = preload("res://addons/vdh_art_preview/runtime_tools.gd").new()
	_runtime_tools.configure(_game, [self, _capture_timer])
	_input_tools = preload("res://addons/vdh_art_preview/input_tools.gd").new()
	_input_tools.configure(_game)
	_scene_tools.transaction_validator = _validate_runtime_context
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


func validate_settings(patch: Dictionary) -> Dictionary:
	# Validate the complete transaction before applying any part of it.
	for key: String in patch:
		if not settings.has(key) or not (patch[key] is float or patch[key] is int):
			return {"ok": false, "error": "Unknown or nonnumeric control: " + key}
		for definition: Dictionary in _definitions:
			if key == str(definition.key) and (not is_finite(float(patch[key])) or float(patch[key]) < float(definition.min) or float(patch[key]) > float(definition.max)):
				return {"ok": false, "error": "Control outside supported range: " + key}
	if _adapter.has_method("validate"):
		var validation: Dictionary = _adapter.call("validate", _game)
		if not bool(validation.get("ok", false)):
			return validation
	return {"ok": true}


func apply_settings(patch: Dictionary) -> Dictionary:
	var validation: Dictionary = validate_settings(patch)
	if not validation.ok:
		return validation
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


func change_settings(patch: Dictionary) -> Dictionary:
	var validation: Dictionary = validate_settings(patch)
	if not validation.ok:
		return validation
	var next_settings: Dictionary = settings.duplicate(true)
	for key: String in patch:
		next_settings[key] = float(patch[key])
	if next_settings != settings:
		var recorded: Dictionary = _scene_tools.edit([], "Adjust composition controls", false,
			{"before": settings, "after": next_settings})
		if not recorded.ok:
			return recorded
	return apply_settings(patch)


func _remember(node: Node) -> void:
	_style.remember(node)


func _apply_common(node: Node) -> void:
	_style.apply(node, settings)


func _validate_runtime_context(context: Dictionary) -> Dictionary:
	return _runtime_tools.validate(context.get("runtime", _runtime_tools.snapshot()))

func _process(_delta: float) -> void:
	_publications.poll()
	var failures: Array[Dictionary] = _publications.take_failures()
	if not failures.is_empty():
		_publication_failed = true
		_error = "Preview JSON publication failed after bounded retries: " + JSON.stringify(failures)
		push_error(_error)
		# Preserve failed staging files for diagnosis. A permanent publication
		# failure requires restart; never accept another command from stale state.
		_ready_for_commands = false
		if not failures.any(func(item: Dictionary) -> bool: return str(item.path).ends_with("/status.json")):
			_write_status()
	if _publication_failed or _publications.pending():
		return
	if not _ready_for_commands:
		return
	var now: int = Time.get_ticks_msec()
	if now - _last_poll_ms < 150 or _capturing:
		return
	_last_poll_ms = now
	var command: Dictionary = _read_json(_run_dir.path_join("command.json"))
	var id: String = str(command.get("id", ""))
	if id.is_empty() or id == _last_command:
		return
	_last_command = id
	_runtime_tools.finish_capture()
	var result: Dictionary = {"ok": true}
	if command.get("session_id", "") != _session.get("session_id", ""):
		result = {"ok": false, "error": "Wrong preview session"}
	elif command.has("expected_revision") and int(command.expected_revision) != revision:
		result = {"ok": false, "error": "Revision changed; read status before retrying"}
	elif not _asset_reload.is_empty() and command.get("op","") not in ["reload_commit","reload_cancel","quit"]:
		result = {"ok":false,"error":"Asset reload is in progress; finish or cancel its transaction"}
	elif not _exploration.is_empty() and command.get("op","")!="quit" and (command.get("exploration_token","")!=_exploration.token or command.get("op","") not in ["exploration","edit","layers","set","typography","vector","surface","arrange","capture","inspect"]):
		result = {"ok":false,"error":"Concept exploration owns this authoring branch; finish or recover it first"}
	else:
		match str(command.get("op", "")):
			"input":
				if _runtime_tools.state.paused:
					result = {"ok":false,"error":"Reset the frozen visual fixture before native input"}
				else:
					_capturing = true
					_capture_timer.stop()
					result = await _input_tools.perform(command.get("options", {}))
					_capturing = false
					if result.ok:
						revision += 1
						_error = ""
						_capture_timer.start(0.05)
			"exploration": result = _explore(command.get("options",{}))
			"surface":
				if command.get("pick_capture_id","") != _last_capture.get("id",""):
					result = {"ok":false,"error":"Surface requires the current capture"}
				elif not _runtime_tools.state.paused and command.get("options",{}).get("action","describe")!="describe":
					result = {"ok":false,"error":"Freeze the visual fixture before composing surfaces"}
				else:
					var surface: RefCounted = preload("res://addons/vdh_art_preview/surface_tools.gd").new()
					surface.configure(_game,_scene_tools)
					result = surface.surface(command.get("options",{}),str(command.get("label","Compose native surface")))
					if result.ok and result.changed:
						revision += 1
						_surface = {"revision":revision,"records":result.records}
						_error = ""
						_capture_timer.start(0.05)
			"vector":
				var vector: RefCounted = preload("res://addons/vdh_art_preview/vector_tools.gd").new()
				vector.configure(_game,_scene_tools)
				var operations: Variant = command.get("options",{}).get("operations")
				var readonly: bool = operations is Array and not operations.is_empty() and operations.all(func(o: Variant): return o is Dictionary and o.get("op")=="describe")
				if command.get("pick_capture_id","") != _last_capture.get("id",""):
					result = {"ok":false,"error":"Vector requires the current capture"}
				elif not _runtime_tools.state.paused and not readonly:
					result = {"ok":false,"error":"Freeze the visual fixture before composing vector artwork"}
				else:
					result = vector.vector(command.get("options",{}),str(command.get("label","Compose native vector artwork")))
					if result.ok and result.changed:
						revision += 1
						_vector = {"revision":revision,"records":result.records}
						_error = ""
						_capture_timer.start(0.05)
			"typography":
				if command.get("pick_capture_id","") != _last_capture.get("id",""):
					result = {"ok":false,"error":"Typography requires the current capture"}
				elif not _runtime_tools.state.paused and command.get("options",{}).get("action","describe")!="describe":
					result = {"ok":false,"error":"Freeze the visual fixture before composing typography"}
				else:
					var typography: RefCounted = preload("res://addons/vdh_art_preview/typography_tools.gd").new()
					typography.configure(_game,_scene_tools)
					result = typography.typography(command.get("options",{}),str(command.get("label","Set native typography")))
					if result.ok and result.changed:
						revision += 1
						_typography = {"revision":revision,"records":result.records}
						_error = ""
						_capture_timer.start(0.05)
			"arrange":
				if command.get("pick_capture_id","") != _last_capture.get("id",""):
					result = {"ok":false,"error":"Arrangement requires the current capture"}
				elif not _runtime_tools.state.paused and (command.get("options",{}).get("action","measure") != "measure" or command.get("options",{}).get("bounds_mode","geometry") == "render"):
					result = {"ok":false,"error":"Freeze the visual fixture before arranging artwork"}
				else:
					_capturing = true
					result = await _arrange(command.get("options",{}),str(command.get("label","Arrange composition")))
					_capturing = false
					if result.ok and result.changed:
						revision += 1
						_arrangement = {"revision":revision,"checks":result.screen_checks}
						_error = ""
						_capture_timer.start(0.05)
			"reload_begin": result = _begin_asset_reload(command.get("asset_reload",{}))
			"reload_commit": result = _commit_asset_reload(command.get("asset_reload",{}))
			"reload_cancel":
				if command.get("asset_reload",{}).get("token","") != _asset_reload.get("token",""):
					result = {"ok":false,"error":"Wrong asset reload token"}
				else:
					_asset_reload.clear()
			"set": result = change_settings(command.get("settings", {}))
			"inspect": result = _scene_tools.inspect_scene(command.get("options", {}))
			"pick":
				_capturing = true
				result = await _pick(command.get("options", {}),str(command.get("pick_capture_id","")))
				_capturing = false
			"edit":
				result = _scene_tools.edit(command.get("edits", []), str(command.get("label", "")))
				if bool(result.get("ok", false)):
					revision += 1
					_error = ""
					_capture_timer.start(0.05)
			"layers":
				result = _scene_tools.layers(command.get("operations", []), str(command.get("label", "Arrange art layers")))
				if bool(result.get("ok", false)):
					revision += 1
					_error = ""
					_capture_timer.start(0.05)
			"runtime":
				var action: String = str(command.get("runtime_action", "describe"))
				if action == "describe":
					result = _runtime_tools.describe()
				elif action in ["set", "reset"]:
					var desired: Dictionary = _runtime_tools.snapshot() if action == "set" else {}
					desired.merge(command.get("runtime_state", {}), true)
					result = _runtime_tools.validate(desired)
					if result.ok:
						var next: Dictionary = result.state
						result = _scene_tools.edit([], "Set visual runtime state", false,
							{"before":{"runtime":_runtime_tools.snapshot()}, "after":{"runtime":next}})
						if result.ok:
							_runtime_tools.set_state(next)
							revision += 1
							result["changed"] = true
							_error = ""
							_capture_timer.start(0.05)
				else:
					result = {"ok":false,"error":"Unknown runtime action"}
			"restore":
				var old_settings: Dictionary = settings.duplicate(true)
				var old_revision: int = revision
				var old_runtime: Dictionary = _runtime_tools.snapshot()
				var next_settings: Dictionary = settings.duplicate(true)
				next_settings.merge(command.get("settings", {}), true)
				result = validate_settings(next_settings)
				if bool(result.get("ok", false)):
					result = _scene_tools.edit(command.get("edits", []), str(command.get("label", "Restore variant")), true,
						{"before": {"settings":old_settings,"runtime":old_runtime},
						"after":{"settings":next_settings,"runtime":command.get("runtime_state",{})}}, command.get("layers", []))
					if bool(result.get("ok", false)):
						var temporal: Dictionary = _runtime_tools.set_state(command.get("runtime_state", {}))
						if not temporal.ok:
							_scene_tools.history("undo")
							_runtime_tools.set_state(old_runtime)
							result = temporal
						else:
							apply_settings(next_settings)
							revision = old_revision + 1
							_error = ""
							_capture_timer.start(0.05)
			"history":
				var old_revision: int = revision
				result = _scene_tools.history(str(command.get("history_action", "status")))
				if bool(result.get("ok", false)) and bool(result.get("changed", false)):
					var context: Dictionary = result.get("context", {})
					var temporal: Dictionary = _runtime_tools.validate(context.get("runtime", _runtime_tools.snapshot()))
					if not temporal.ok:
						_scene_tools.history("redo" if command.history_action == "undo" else "undo")
						result = temporal
					else:
						if context.has("runtime"):
							_runtime_tools.set_state(temporal.state)
						apply_settings(context.get("settings", {}) if context.has("runtime") or context.has("settings") else context)
						revision = old_revision + 1
						_error = ""
						_capture_timer.start(0.05)
			"reference": result = _set_reference(str(command.get("path", "")), str(command.get("reference_sha256", "")))
			"capture": _capture_timer.start(0.05)
			"quit": get_tree().quit()
			_: result = {"ok": false, "error": "Unknown preview command"}
	result["id"] = id
	result["revision"] = revision
	_publications.publish(_run_dir.path_join("command-result.json"), result)
	_runtime_tools.hold()
	_write_status()


func _explore(options: Dictionary) -> Dictionary:
	var action: String = str(options.get("action",""))
	if action=="begin":
		if not _exploration.is_empty() or not _runtime_tools.state.paused or _last_capture.get("revision",-1)!=revision or str(options.get("token","")).is_empty():
			return {"ok":false,"error":"Exploration needs an unreserved frozen fixture and its current capture"}
		var branch: RefCounted = preload("res://addons/vdh_art_preview/exploration_branch.gd").new()
		var result: Dictionary = branch.begin(_scene_tools)
		if result.ok:
			_exploration = {"token":str(options.token),"branch":branch,"settings":settings.duplicate(true),
				"runtime":_runtime_tools.snapshot(),"style_baseline":_style._baseline.duplicate(true),
				"baseline_capture":_run_dir.path_join(str(_last_capture.id)).path_join("capture.json")}
		return result
	if action not in ["reset","finish"] or _exploration.is_empty():
		return {"ok":false,"error":"No matching exploration to reset or finish"}
	var restored: Dictionary = _exploration.branch.reset()
	if not restored.ok:
		return restored
	_style._baseline = _exploration.style_baseline.duplicate(true)
	var old_revision: int = revision
	var temporal: Dictionary = _runtime_tools.set_state(_exploration.runtime)
	if not temporal.ok:
		return temporal
	var styling: Dictionary = apply_settings(_exploration.settings)
	if not styling.ok:
		return styling
	_scene_tools.reapply()
	if action=="finish":
		var finished: Dictionary = _exploration.branch.finish()
		if not finished.ok:
			return finished
		_exploration.clear()
	_arrangement.clear()
	_typography.clear()
	_vector.clear()
	_surface.clear()
	revision = old_revision+1
	_error = ""
	_capture_timer.start(0.05)
	return {"ok":true,"changed":true,"history":_scene_tools.history_status()}


func _arrange(options: Dictionary, label: String) -> Dictionary:
	var arranger: RefCounted = preload("res://addons/vdh_art_preview/arrange_tools.gd").new()
	arranger.configure(_game,_scene_tools)
	if options.get("bounds_mode","geometry") != "render":
		return arranger.arrange(options,label)
	_apply_common(_game)
	_adapter.call("apply",_game,settings)
	_scene_tools.reapply()
	var temporal: Dictionary = await _runtime_tools.prepare_capture(_scene_tools.reapply)
	if not temporal.ok:
		_runtime_tools.finish_capture()
		return temporal
	var plan: Dictionary = await arranger.rendered_plan(options,Image.load_from_file(_last_capture.actual))
	_runtime_tools.finish_capture()
	if not _scene_tools.verify_applied().ok:
		return {"ok":false,"error":"Authored properties changed while measuring rendered bounds"}
	return arranger.apply_plan(plan,label)

func _pick(options: Dictionary, capture_id: String) -> Dictionary:
	if capture_id != str(_last_capture.get("id","")) or _last_capture.get("revision",-1) != revision:
		return {"ok":false,"error":"Pick requires the current capture ID and revision"}
	var picker: RefCounted = preload("res://addons/vdh_art_preview/picking.gd").new()
	picker.configure(_game)
	var valid: Dictionary = picker.validate(options)
	if not valid.ok:
		return valid
	if valid.mode == "geometry":
		var result: Dictionary = await picker.pick(options)
		result["capture_id"] = capture_id
		result["observation"] = "Current live geometry; not a pixel attribution"
		return result
	if not _runtime_tools.state.paused:
		return {"ok":false,"error":"Render picking requires a frozen fixture. Set runtime paused=true, inspect its fresh image, then pick using that capture ID; geometry mode is available for live scenes."}
	_apply_common(_game)
	_adapter.call("apply",_game,settings)
	_scene_tools.reapply()
	var temporal: Dictionary = await _runtime_tools.prepare_capture(_scene_tools.reapply)
	if not temporal.ok:
		_runtime_tools.finish_capture()
		return temporal
	var result: Dictionary = await picker.pick(options,Image.load_from_file(_last_capture.actual))
	_runtime_tools.finish_capture()
	if result.ok and not _scene_tools.verify_applied().ok:
		return {"ok":false,"error":"Authored properties changed during picking"}
	result["capture_id"] = capture_id
	return result

func _scene_identity() -> Dictionary:
	var result: Dictionary = {}
	var pending: Array[Node] = [get_tree().root]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		result[str(node.get_path())] = str(node.get_instance_id())
		pending.append_array(node.get_children())
	return result

func _begin_asset_reload(options: Dictionary) -> Dictionary:
	if not _runtime_tools.state.paused:
		return {"ok":false,"error":"Freeze the visual fixture before reloading assets"}
	if str(options.get("token","")).is_empty():
		return {"ok":false,"error":"Missing asset reload token"}
	_capture_timer.stop()
	_asset_reload = {"token":options.token,"nodes":_scene_identity(),"history":_scene_tools.history_status()}
	return {"ok":true,"node_count":_asset_reload.nodes.size(),"history":_asset_reload.history}

func _commit_asset_reload(options: Dictionary) -> Dictionary:
	if _asset_reload.is_empty() or options.get("token","") != _asset_reload.token:
		return {"ok":false,"error":"Wrong asset reload transaction"}
	var paths: Array = options.get("paths",[])
	var sources: Dictionary = options.get("source_files",{})
	for path: String in paths:
		var relative: String = path.trim_prefix("res://")
		if not sources.has(relative) or FileAccess.get_sha256(path) != sources[relative]:
			return {"ok":false,"error":"Asset source changed during reload: " + path}
	var helper: RefCounted = preload("res://addons/vdh_art_preview/asset_tools.gd").new()
	var result: Dictionary = helper.refresh(paths)
	if not result.ok:
		_error = "Asset reload failed: " + JSON.stringify(result)
		return result
	_style.refresh_sources(_game)
	_runtime_tools.invalidate_shader_cache()
	_apply_common(_game)
	_adapter.call("apply",_game,settings)
	_scene_tools.reapply()
	if _scene_identity() != _asset_reload.nodes or _scene_tools.history_status() != _asset_reload.history or not _scene_tools.verify_applied().ok:
		_error = "Resource callbacks changed nodes or authored values during reload; inspect the scene before continuing"
		return {"ok":false,"error":_error,"partial":true}
	_session["source_files"] = sources
	_session["asset_revision"] = int(options.get("asset_revision",0))
	_last_asset_reload = result.duplicate(true)
	_last_asset_reload["asset_revision"] = _session.asset_revision
	_last_asset_reload["node_identity_preserved"] = true
	_last_asset_reload["history_preserved"] = true
	_asset_reload.clear()
	revision += 1
	_error = ""
	_capture_timer.start(0.05)
	return _last_asset_reload.duplicate(true)

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
	_scene_tools.reapply()
	var temporal: Dictionary = await _runtime_tools.prepare_capture(_scene_tools.reapply)
	if not temporal.ok:
		_runtime_tools.finish_capture()
		_error = "Runtime fixture could not be applied: " + JSON.stringify(temporal)
		_capturing = false
		_write_status()
		return
	var captured_revision: int = revision
	var frame_before: int = Engine.get_frames_drawn()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var actual: Image = get_viewport().get_texture().get_image()
	var frame_after: int = Engine.get_frames_drawn()
	_runtime_tools.finish_capture()
	var application: Dictionary = {"status": "adapter_readback_unavailable", "targets": []}
	if _adapter.has_method("verify_applied"):
		application = _adapter.call("verify_applied", _game, settings)
		if not bool(application.get("ok", false)):
			_error = "Declared property edits did not survive layout: " + JSON.stringify(application)
			_capturing = false
			_write_status()
			return
	var edit_application: Dictionary = _scene_tools.verify_applied()
	if not bool(edit_application.get("ok", false)):
		_error = "Typed edits did not survive the rendered frames: " + JSON.stringify(edit_application)
		_capturing = false
		_write_status()
		return
	var arrangement_verification: Dictionary = {}
	if _arrangement.get("revision",-1) == captured_revision:
		var arranger: RefCounted = preload("res://addons/vdh_art_preview/arrange_tools.gd").new()
		arranger.configure(_game,_scene_tools)
		arrangement_verification = arranger.verify(_arrangement.checks)
		if not arrangement_verification.ok:
			_error = "Screen arrangement did not survive layout/animation: " + JSON.stringify(arrangement_verification)
			_capturing = false
			_write_status()
			return
	var surface_verification: Dictionary = {}
	if _surface.get("revision",-1) == captured_revision:
		var surface: RefCounted = preload("res://addons/vdh_art_preview/surface_tools.gd").new()
		surface.configure(_game,_scene_tools)
		surface_verification = surface.verify(_surface.records)
		if not surface_verification.ok:
			_error = "Surface controls did not survive rendering: " + JSON.stringify(surface_verification)
			_capturing = false
			_write_status()
			return
	var vector_verification: Dictionary = {}
	if _vector.get("revision",-1) == captured_revision:
		var vector: RefCounted = preload("res://addons/vdh_art_preview/vector_tools.gd").new()
		vector.configure(_game,_scene_tools)
		vector_verification = vector.verify(_vector.records)
		if not vector_verification.ok:
			_error = "Vector controls or baked geometry changed before rendering: " + JSON.stringify(vector_verification)
			_capturing = false
			_write_status()
			return
	var typography_verification: Dictionary = {}
	if _typography.get("revision",-1) == captured_revision:
		var typography: RefCounted = preload("res://addons/vdh_art_preview/typography_tools.gd").new()
		typography.configure(_game,_scene_tools)
		typography_verification = typography.verify(_typography.records)
		if not typography_verification.ok:
			_error = "Effective typography did not survive rendered layout: " + JSON.stringify(typography_verification)
			_capturing = false
			_write_status()
			return
	if captured_revision != revision or frame_after <= frame_before or actual.is_empty() or actual.get_size() != view_size or get_window().mode not in [Window.MODE_FULLSCREEN, Window.MODE_EXCLUSIVE_FULLSCREEN]:
		_error = "Capture rejected: changed revision, no fresh frame, or incorrect design viewport."
		_capturing = false
		_write_status()
		return
	var capture_id: String = "p%d-r%04d-f%d" % [OS.get_process_id(), revision, frame_after]
	var directory: String = _run_dir.path_join(capture_id)
	DirAccess.make_dir_recursive_absolute(directory)
	var actual_path: String = directory.path_join("actual.png")
	var comparison_path: String = directory.path_join("comparison.png")
	var reference_path: String = directory.path_join("reference." + _reference.get_extension())
	var runtime: Dictionary = _session.get("runtime_provenance", {}).duplicate(true)
	var geometry_records: Array[Dictionary] = _geometry(_game)
	geometry_records.append_array(_scene_tools.geometry())
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
	runtime["asset_revision"] = int(_session.get("asset_revision",0))
	runtime["asset_reload"] = _last_asset_reload
	runtime["application_verification"] = application
	runtime["edit_verification"] = edit_application
	runtime["arrangement_verification"] = arrangement_verification
	runtime["typography_verification"] = typography_verification
	runtime["vector_verification"] = vector_verification
	runtime["surface_verification"] = surface_verification
	runtime["edit_history"] = _scene_tools.history_status()
	runtime["visual_runtime"] = temporal
	runtime["root_name"] = str(_game.name)
	runtime["reference_source"] = ProjectSettings.globalize_path(_reference)
	runtime["reference_source_sha256"] = _reference_hash
	runtime.merge({"project_path": ProjectSettings.globalize_path("res://"), "scene": _adapter.call("scene_path"), "preview_scene": scene_file_path, "session_id": _session.get("session_id", ""), "game_pid": OS.get_process_id(), "engine": Engine.get_version_info().string, "viewport": "%dx%d" % [view_size.x, view_size.y], "window_mode": get_window().mode, "frames_before": frame_before, "frames_drawn": frame_after, "stale_frame": false, "revision": revision}, true)
	var capture: Dictionary = {"id": capture_id, "revision": revision, "actual": actual_path, "reference": reference_path, "comparison": comparison_path, "settings": settings.duplicate(true), "runtime_provenance": runtime, "captured_at_unix": Time.get_unix_time_from_system(), "visual_verdict": "unreviewed"}
	capture["edits"] = _scene_tools.export_edits()
	capture["layers"] = _scene_tools.export_layers()
	capture["runtime_state"] = _runtime_tools.snapshot()
	# Readback temporarily restores authored values for verification. Freeze the
	# scene again before the image worker yields frames: ALWAYS callbacks and
	# GPU simulation must not advance while a frozen evidence bundle is encoded.
	_runtime_tools.hold()
	# Snapshot scene state above, on the main thread and at the captured frame.
	# Encoding two large PNGs must not stall live animation or player input.
	# The worker exclusively owns the detached CPU images until it completes.
	var writer: RefCounted = preload("res://addons/vdh_art_preview/capture_writer.gd").new()
	_capture_thread = Thread.new()
	var write_frame: int = Engine.get_frames_drawn()
	var thread_error: Error = _capture_thread.start(writer.write.bind(actual,reference_image,view_size,directory,ProjectSettings.globalize_path(_reference),_reference_hash))
	if thread_error != OK:
		_capture_thread = null
		_error = "Capture image writer could not start: " + str(thread_error)
		_capturing = false
		_write_status()
		return
	while _capture_thread.is_alive():
		await get_tree().process_frame
	var written: Dictionary = _capture_thread.wait_to_finish()
	_capture_thread = null
	if not written.ok:
		_error = written.error
		_capturing = false
		_write_status()
		return
	capture["reference_sha256"] = written.reference_sha256
	capture["actual_sha256"] = written.actual_sha256
	runtime["capture_io"] = {"mode":"worker_cpu_images","seconds":written.seconds,"frames_advanced":Engine.get_frames_drawn()-write_frame}
	if _write_json(directory.path_join("geometry.json"), {"controls": geometry_records}) != OK or _write_json(directory.path_join("capture.json"), capture) != OK or _write_json(_run_dir.path_join("latest.json"), capture) != OK:
		_error = "Capture metadata could not be saved completely."
		_capturing = false
		_write_status()
		return
	_last_capture = capture
	var adapter_path: String = str(_session.get("adapter", ""))
	_write_json(_run_dir.path_join("preset.json"), {"settings": settings, "reference": _reference, "scene": _adapter.call("scene_path"), "target_scene": _session.get("target_scene", ""), "adapter": adapter_path, "adapter_sha256": FileAccess.get_sha256(adapter_path), "source_sha": runtime.get("source_sha", ""), "bindings": _session.get("bindings", {})})
	_error = ""
	_capturing = false
	_write_status()


func _geometry(node: Node) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if node is Control and (node as Control).is_visible_in_tree():
		var control: Control = node as Control
		var rect: Rect2 = control.get_global_rect()
		var visible_rect: Rect2 = rect.intersection(Rect2(Vector2.ZERO, Vector2(view_size)))
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
	if _runtime_tools != null:
		_runtime_tools.hold()
	var status: Dictionary = {"ready": _ready_for_commands, "revision": revision, "session_id": _session.get("session_id", ""), "pid": OS.get_process_id(), "settings": settings, "controls": _definitions, "reference": _reference, "last_capture": _last_capture, "error": _error, "user_data_dir": OS.get_user_data_dir()}
	status["asset_revision"] = int(_session.get("asset_revision",0))
	status["asset_reload_pending"] = _asset_reload.get("token","")
	status["exploration"] = {} if _exploration.is_empty() else {"token":_exploration.token,"baseline_capture":_exploration.baseline_capture}
	if _runtime_tools != null:
		status["runtime_state"] = _runtime_tools.snapshot()
	if not _run_dir.is_empty():
		_publications.publish(_run_dir.path_join("status.json"), status)


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	# Windows replacement can briefly make a valid command unreadable. The
	# instance parser reports an Error without logging a debugger-breaking error;
	# the next bounded poll retries the same immutable command ID.
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var text: String = file.get_as_text()
	file.close()
	var parser: JSON = JSON.new()
	if text.is_empty() or parser.parse(text) != OK:
		return {}
	return parser.data if parser.data is Dictionary else {}


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
	if _capture_thread != null and _capture_thread.is_started():
		_capture_thread.wait_to_finish()
		_capture_thread = null
	if _runtime_tools != null:
		_runtime_tools.release()
	if _owns_lock:
		DirAccess.remove_absolute(_run_dir.path_join("runtime.lock"))
