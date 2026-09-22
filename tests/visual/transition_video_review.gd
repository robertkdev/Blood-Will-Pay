extends Node
## Observer-only video entrypoint: runs the real Main UI at normal speed.
## Configure user://transition_video_review.json with output_dir, probe_path,
## and source_sha. The probe is supplied by the local Game Perception tool.
## Inputs come from the actual game window; this observer never starts a fight.

const MAIN_SCENE: PackedScene = preload("res://scenes/Main.tscn")
const CONFIG_PATH: String = "user://transition_video_review.json"
var _main: Control = null
var _probe: Node = null
var _output_dir: String = ""
var _frames: FileAccess = null
var _previous_state: String = ""
var _sync_token_seen: String = ""
var _poll_elapsed: float = 0.0
var _frame_index: int = 0

func _ready() -> void:
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH)) as Dictionary
	if config.is_empty():
		push_error("Transition video review requires its local observer configuration")
		get_tree().quit(1)
		return
	_output_dir = String(config.get("output_dir", ""))
	DirAccess.make_dir_recursive_absolute(_output_dir)
	var probe_script: GDScript = GDScript.new()
	# The external probe supports less strict projects; suppress only its
	# Variant inference warning when loading it under this project's policy.
	probe_script.source_code = "@warning_ignore_start(\"inference_on_variant\")\n" + FileAccess.get_file_as_string(String(config.get("probe_path", "")))
	probe_script.source_code = probe_script.source_code.replace('var camera_name := _camera.get_path() if is_instance_valid(_camera) else ""', 'var camera_name: String = str(_camera.get_path()) if is_instance_valid(_camera) else ""')
	if probe_script.reload() != OK:
		get_tree().quit(1)
		return
	_probe = Node.new()
	_probe.name = "GamePerceptionProbe"
	_probe.set_script(probe_script)
	_probe.set("output_dir", _output_dir)
	_probe.set("flush_every_frames", 30)
	get_tree().root.add_child.call_deferred(_probe)
	_main = MAIN_SCENE.instantiate() as Control
	get_tree().root.add_child.call_deferred(_main)
	_frames = FileAccess.open(_output_dir.path_join("transition-frames.jsonl"), FileAccess.WRITE)
	await get_tree().process_frame
	_probe.call("set_source_sha", String(config.get("source_sha", "")))
	var identity: Dictionary = {"pid": OS.get_process_id(), "project": ProjectSettings.globalize_path("res://"), "time_scale": Engine.time_scale, "viewport": str(get_viewport().get_visible_rect()), "source_sha": config.get("source_sha", "")}
	var file: FileAccess = FileAccess.open(_output_dir.path_join("runtime-ready.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(identity))
	file.close()

func _process(delta: float) -> void:
	if _probe == null or not _probe.is_inside_tree() or _frames == null:
		return
	_poll_elapsed += delta
	if _poll_elapsed >= 0.10:
		_poll_elapsed = 0.0
		var cue_path: String = _output_dir.path_join("sync-request.json")
		if FileAccess.file_exists(cue_path):
			var request: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(cue_path)) as Dictionary
			var token: String = String(request.get("token", ""))
			if not token.is_empty() and token != _sync_token_seen:
				_sync_token_seen = token
				_probe.call("mark_visual_sync", token, 8)
				var ack: FileAccess = FileAccess.open(_output_dir.path_join("sync-ack.json"), FileAccess.WRITE)
				ack.store_string(JSON.stringify({"queued": true, "ticks_usec": Time.get_ticks_usec()}))
				ack.close()
	var combat: Control = _main.get_node_or_null("CombatView") as Control
	var state: String = "menu"
	var record: Dictionary = {"frame": _frame_index, "ticks_usec": Time.get_ticks_usec(), "delta_ms": delta * 1000.0}
	if combat != null and combat.visible:
		var controller: Variant = combat.get("controller")
		var transition: Variant = controller.get("phase_transition") if controller != null else null
		state = String(transition.call("get_state_name")) if transition != null else "planning"
		var result: Control = combat.get_node_or_null("BattleResultBanner") as Control
		if result != null and result.visible:
			state = "result"
			var card: Control = result.get_node_or_null("Center/BattleResultCard") as Control
			if card != null:
				record["result_rect"] = _rect_array(card.get_global_rect())
		var planning: Control = combat.get("planning_area") as Control
		if planning != null:
			record["planning_rect"] = _rect_array(planning.get_global_rect())
		var bridge: Variant = controller.get("arena_bridge") if controller != null else null
		if bridge != null:
			var snapshot: Dictionary = bridge.call("get_transition_debug_snapshot") as Dictionary
			record["field_rect"] = _rect_array(snapshot.get("field_rect", Rect2()) as Rect2)
			var actors: Array[Dictionary] = []
			for value: Dictionary in snapshot.get("unit_presentations", []):
				var point: Vector2 = value.get("global_center", Vector2.ZERO) as Vector2
				actors.append({"id": value.get("presentation_instance_id"), "center": [point.x, point.y], "visible": value.get("visible", false)})
			record["actors"] = actors
	if state != _previous_state:
		_probe.call("mark_event", "phase_" + state, state)
		_previous_state = state
		record["marker"] = "phase_" + state
	record["state"] = state
	_frames.store_line(JSON.stringify(record))
	_frame_index += 1
	if _frame_index % 60 == 0:
		_frames.flush()

func _rect_array(rect: Rect2) -> Array[float]:
	return [rect.position.x, rect.position.y, rect.size.x, rect.size.y]

func _exit_tree() -> void:
	if _frames != null:
		_frames.close()
