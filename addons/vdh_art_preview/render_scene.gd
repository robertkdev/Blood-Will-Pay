extends SceneTree
## Bounded normal-scene launch and capture. No preview root, styling or control UI.

var options: Dictionary = {}

func _initialize() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	for i: int in range(0,arguments.size()-1,2):
		options[arguments[i].trim_prefix("--")] = arguments[i+1]
	call_deferred("run")

func fail(message: String) -> void:
	push_error(message)
	quit(2)

func _reapply_compositions() -> void:
	for component: Node in get_nodes_in_group("vdh_composition_components"):
		component.reapply_authored()

func run() -> void:
	var output: String = str(options.get("output",""))
	var reference: String = str(options.get("reference",""))
	var requested_scene: String = str(options.get("scene",ProjectSettings.get_setting("application/run/main_scene","")))
	if output.is_empty() or reference.is_empty() or requested_scene.is_empty():
		fail("Output, reference and a scene or configured main scene are required")
		return
	var size := Vector2i(int(options.get("width",1920)),int(options.get("height",1080)))
	root.content_scale_size=size
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_VIEWPORT
	root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_KEEP
	root.mode=Window.MODE_FULLSCREEN
	var changed: Error = change_scene_to_file(requested_scene)
	if changed != OK:
		fail("Cannot launch normal scene: " + requested_scene)
		return
	for _frame: int in range(int(options.get("settle-frames",12))):
		await process_frame
	if current_scene == null:
		fail("Normal scene did not become current")
		return
	var temporal_tools: RefCounted
	var temporal: Dictionary = {"ok":true,"mode":"live"}
	if options.has("runtime-state"):
		var state_file: FileAccess = FileAccess.open(str(options["runtime-state"]),FileAccess.READ)
		var runtime_state: Variant = JSON.parse_string(state_file.get_as_text()) if state_file != null else null
		if not runtime_state is Dictionary:
			fail("Runtime-state file must contain an object")
			return
		temporal_tools = preload("res://addons/vdh_art_preview/runtime_tools.gd").new()
		temporal_tools.configure(current_scene)
		temporal = temporal_tools.set_state(runtime_state)
		if temporal.ok:
			temporal = await temporal_tools.prepare_capture(_reapply_compositions)
		if not temporal.ok:
			fail("Cannot apply visual runtime fixture: " + JSON.stringify(temporal))
			return
	else:
		var textures: Dictionary = await preload("res://addons/vdh_art_preview/texture_readiness.gd").new().wait_ready(current_scene)
		if not textures.ok:
			fail(str(textures.error))
			return
	var frame_before: int = Engine.get_frames_drawn()
	await process_frame
	await RenderingServer.frame_post_draw
	await process_frame
	await RenderingServer.frame_post_draw
	var actual: Image = root.get_texture().get_image()
	var frame_after: int = Engine.get_frames_drawn()
	if temporal_tools != null:
		temporal_tools.finish_capture()
	var compositions: Array[Dictionary] = []
	for component: Node in get_nodes_in_group("vdh_composition_components"):
		var result: Dictionary = component.verify_current()
		if not bool(component.result.get("ok",false)) or not bool(result.get("ok",false)):
			fail("Authored composition was not applied at capture: " + JSON.stringify(result))
			return
		compositions.append(result)
	if actual.is_empty() or actual.get_size()!=size or frame_after<=frame_before:
		fail("Normal-scene capture did not produce a fresh native frame")
		return
	var actual_path: String = output.path_join("actual.png")
	if actual.save_png(actual_path)!=OK:
		fail("Cannot save normal-scene capture")
		return
	var reference_image: Image = Image.load_from_file(reference)
	if reference_image == null or reference_image.is_empty():
		fail("Reference unreadable")
		return
	var reference_path: String = output.path_join("reference."+reference.get_extension())
	if DirAccess.copy_absolute(reference,reference_path)!=OK:
		fail("Cannot preserve reference")
		return
	var board: Image = Image.create(size.x*2,size.y,false,Image.FORMAT_RGB8)
	board.fill(Color("080e18"))
	var ratio: float = minf(float(size.x)/reference_image.get_width(),float(size.y)/reference_image.get_height())
	reference_image.resize(roundi(reference_image.get_width()*ratio),roundi(reference_image.get_height()*ratio),Image.INTERPOLATE_LANCZOS)
	reference_image.convert(Image.FORMAT_RGB8)
	actual.convert(Image.FORMAT_RGB8)
	board.blit_rect(reference_image,Rect2i(Vector2i.ZERO,reference_image.get_size()),(size-reference_image.get_size())/2)
	board.blit_rect(actual,Rect2i(Vector2i.ZERO,size),Vector2i(size.x,0))
	if board.save_png(output.path_join("comparison.png"))!=OK:
		fail("Cannot save reference comparison")
		return
	var source_file: FileAccess = FileAccess.open(output.path_join("source-files.json"),FileAccess.READ)
	var source_files: Dictionary = JSON.parse_string(source_file.get_as_text())
	source_file.close()
	var loaded: Array[String] = []
	for path: String in source_files:
		if ResourceLoader.has_cached("res://"+path):
			loaded.append(path)
	var autoloads: Array[String] = []
	for child: Node in root.get_children():
		if child != current_scene:
			autoloads.append(str(child.name))
	var capture: Dictionary = {"actual":actual_path,"reference":reference_path,"comparison":output.path_join("comparison.png"),
		"actual_sha256":FileAccess.get_sha256(actual_path),"reference_sha256":FileAccess.get_sha256(reference_path),
		"captured_at_unix":Time.get_unix_time_from_system(),"visual_verdict":"unreviewed","compositions":compositions,
		"runtime_provenance":{"project_path":ProjectSettings.globalize_path("res://"),"requested_scene":requested_scene,
			"scene":current_scene.scene_file_path,"mode":"normal_scene" if options.has("scene") else "normal_main_scene",
			"game_pid":OS.get_process_id(),"engine":Engine.get_version_info().string,"viewport":"%dx%d"%[size.x,size.y],
			"window_mode":root.mode,"frames_before":frame_before,"frames_drawn":frame_after,"stale_frame":false,
			"loaded_sources":loaded,"autoloads":autoloads,"user_data_dir":OS.get_user_data_dir(),"visual_runtime":temporal}}
	var file: FileAccess = FileAccess.open(output.path_join("capture.json"),FileAccess.WRITE)
	if file == null:
		fail("Cannot save capture metadata")
		return
	file.store_string(JSON.stringify(capture,"\t"))
	file.close()
	if temporal_tools != null:
		temporal_tools.release()
	quit()
