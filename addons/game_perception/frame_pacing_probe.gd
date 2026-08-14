extends Node

@export var enabled: bool = true
@export var output_dir: String = "user://game_perception"
@export var flush_every_frames: int = 120
@export var ring_size: int = 600
@export var tracked_nodes: Array[NodePath] = []
@export var state_label: String = ""

const VISUAL_SYNC_GRID: int = 6
const VISUAL_SYNC_CELL_SIZE: int = 12
const VISUAL_SYNC_MIN_FRAMES: int = 3
const VISUAL_SYNC_MAX_FRAMES: int = 8

var _file: FileAccess = null
var _started_ms: int = 0
var _frame: int = 0
var _process_intervals: Array[float] = []
var _physics_tick_intervals: Array[float] = []
var _event_queue: Array[Dictionary] = []
var _input_queue: Array[Dictionary] = []
var _input_sequence: int = 0
var _source_sha: String = ""
var _csv_path: String = ""
var _camera: Node = null
var _physics_tick_delta_ms: float = 0.0
var _visual_sync_token: String = ""
var _visual_sync_requested_frames: int = 0
var _visual_sync_frames_remaining: int = 0
var _visual_sync_started_frame: int = -1
var _visual_sync_layer: CanvasLayer = null

class VisualSyncCue extends Control:
	var pattern_bits: PackedByteArray = PackedByteArray()

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(VISUAL_SYNC_CELL_SIZE * VISUAL_SYNC_GRID, VISUAL_SYNC_CELL_SIZE * VISUAL_SYNC_GRID)
		size = custom_minimum_size

	func _draw() -> void:
		for row: int in range(VISUAL_SYNC_GRID):
			for column: int in range(VISUAL_SYNC_GRID):
				var bit_index: int = row * VISUAL_SYNC_GRID + column
				var color: Color = Color(1.0, 0.0, 1.0) if pattern_bits[bit_index] == 1 else Color(1.0, 1.0, 0.0)
				draw_rect(Rect2(column * VISUAL_SYNC_CELL_SIZE, row * VISUAL_SYNC_CELL_SIZE, VISUAL_SYNC_CELL_SIZE, VISUAL_SYNC_CELL_SIZE), color)

func _ready() -> void:
	if not enabled:
		return
	flush_every_frames = maxi(1, flush_every_frames)
	ring_size = maxi(1, ring_size)
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir)) != OK:
		enabled = false
		push_error("FramePacingProbe cannot create output directory")
		return
	_started_ms = Time.get_ticks_msec()
	_source_sha = OS.get_environment("GAME_PERCEPTION_SOURCE_SHA")
	_csv_path = output_dir.path_join("frame_pacing_%d.csv" % _started_ms)
	_file = FileAccess.open(_csv_path, FileAccess.WRITE)
	if _file == null:
		enabled = false
		push_error("FramePacingProbe cannot open CSV: %s" % _csv_path)
		return
	_file.store_line("frame,timestamp_ms,process_delta_ms,physics_tick_delta_ms,event_id,event_frame,event_timestamp_ms,input_event,state_label,camera,tracked_json,events_json,inputs_json")

func mark_event(event_id: String, label: String = "") -> void:
	_event_queue.append({"marker_id": event_id, "timestamp_ms": Time.get_ticks_usec() / 1000.0 - _started_ms, "frame": _frame, "label": label})
	if not label.is_empty():
		state_label = label

func mark_capture_sync(sync_id: String = "capture_start") -> void:
	mark_event(sync_id)

func mark_visual_sync(token: String, presented_frames: int = VISUAL_SYNC_MIN_FRAMES) -> bool:
	var expression: RegEx = RegEx.new()
	expression.compile("^[0-9a-f]{32,128}$")
	if expression.search(token) == null:
		push_error("FramePacingProbe visual sync token must be 128+ bits of lowercase hexadecimal")
		return false
	if presented_frames < VISUAL_SYNC_MIN_FRAMES or presented_frames > VISUAL_SYNC_MAX_FRAMES:
		push_error("FramePacingProbe visual sync duration must be 3-8 presented frames")
		return false
	if not _visual_sync_token.is_empty() or is_instance_valid(_visual_sync_layer):
		push_error("FramePacingProbe rejects concurrent visual sync cues")
		return false
	_visual_sync_token = token
	_visual_sync_requested_frames = presented_frames
	return true

func set_state_label(label: String) -> void:
	state_label = label

func set_camera(camera: Node) -> void:
	if not (camera is Camera2D or camera is Camera3D):
		push_error("FramePacingProbe camera must be Camera2D or Camera3D")
		return
	_camera = camera

func set_source_sha(source_sha: String) -> void:
	_source_sha = source_sha

func _process(delta: float) -> void:
	if not enabled or _file == null:
		return
	_frame += 1
	_advance_visual_sync()
	if not _visual_sync_token.is_empty():
		_activate_visual_sync()
	var process_delta_ms: float = delta * 1000.0
	_push(_process_intervals, process_delta_ms)
	_push(_physics_tick_intervals, _physics_tick_delta_ms)
	var tracked: Array[Dictionary] = _tracked_node_snapshot()
	var first_event: Dictionary = _event_queue[0] if not _event_queue.is_empty() else {}
	var first_input: Dictionary = _input_queue[0] if not _input_queue.is_empty() else {}
	var camera_name: String = str(_camera.get_path()) if is_instance_valid(_camera) else ""
	_file.store_csv_line([str(_frame), str(Time.get_ticks_usec() / 1000.0 - _started_ms), "%.4f" % process_delta_ms, "%.4f" % _physics_tick_delta_ms, str(first_event.get("marker_id", "")), str(first_event.get("frame", -1)), str(first_event.get("timestamp_ms", "")), str(first_input.get("text", "")), state_label, camera_name, JSON.stringify(tracked), JSON.stringify(_event_queue), JSON.stringify(_input_queue)])
	_event_queue.clear()
	_input_queue.clear()
	if _frame % flush_every_frames == 0:
		_file.flush()
		_write_summary()

func _physics_process(delta: float) -> void:
	_physics_tick_delta_ms = delta * 1000.0

func _input(event: InputEvent) -> void:
	_input_sequence += 1
	_input_queue.append({"marker_id": event.as_text(), "sequence": _input_sequence, "timestamp_ms": Time.get_ticks_usec() / 1000.0 - _started_ms, "frame": _frame, "text": event.as_text()})

func _tracked_node_snapshot() -> Array[Dictionary]:
	var tracked: Array[Dictionary] = []
	for path: NodePath in tracked_nodes:
		var node: Node = get_node_or_null(path)
		if node is Node2D:
			var node_2d: Node2D = node as Node2D
			tracked.append({"path": str(path), "world": [node_2d.global_position.x, node_2d.global_position.y], "screen": [node_2d.get_global_transform_with_canvas().origin.x, node_2d.get_global_transform_with_canvas().origin.y]})
		elif node is Node3D:
			var node_3d: Node3D = node as Node3D
			var item: Dictionary = {"path": str(path), "world": [node_3d.global_position.x, node_3d.global_position.y, node_3d.global_position.z]}
			if _camera is Camera3D and not (_camera as Camera3D).is_position_behind(node_3d.global_position):
				var screen: Vector2 = (_camera as Camera3D).unproject_position(node_3d.global_position)
				item["screen"] = [screen.x, screen.y]
			tracked.append(item)
	return tracked

func _activate_visual_sync() -> void:
	var context: HashingContext = HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(_visual_sync_token.to_utf8_buffer())
	var digest: PackedByteArray = context.finish()
	var cue: VisualSyncCue = VisualSyncCue.new()
	for index: int in range(VISUAL_SYNC_GRID * VISUAL_SYNC_GRID):
		cue.pattern_bits.append((digest[index >> 3] >> (index % 8)) & 1)
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 127
	cue.position = Vector2(8.0, 8.0)
	layer.add_child(cue)
	get_tree().root.add_child(layer)
	_visual_sync_layer = layer
	_visual_sync_frames_remaining = _visual_sync_requested_frames
	_visual_sync_started_frame = _frame
	_event_queue.append({"marker_id": "gp_visual_sync:%s" % _visual_sync_token, "timestamp_ms": Time.get_ticks_usec() / 1000.0 - _started_ms, "frame": _frame})
	_visual_sync_token = ""
	_visual_sync_requested_frames = 0

func _advance_visual_sync() -> void:
	if not is_instance_valid(_visual_sync_layer):
		return
	if _frame > _visual_sync_started_frame:
		_visual_sync_frames_remaining -= 1
	if _visual_sync_frames_remaining <= 0:
		_visual_sync_layer.queue_free()
		_visual_sync_layer = null
		_visual_sync_started_frame = -1

func _exit_tree() -> void:
	if is_instance_valid(_visual_sync_layer):
		_visual_sync_layer.queue_free()
	if _file != null:
		_file.flush()
		_file.close()
		_write_summary()

func _push(values: Array[float], value: float) -> void:
	values.append(value)
	if values.size() > ring_size:
		values.pop_front()

func _write_summary() -> void:
	var data: Dictionary[String, Variant] = {
		"schema_version": 3,
		"run_id": str(_started_ms),
		"started_ticks_ms": _started_ms,
		"frames": _frame,
		"source_sha": _source_sha,
		"process_delta_ms": _stats(_process_intervals),
		"physics_tick_delta_ms": _stats(_physics_tick_intervals),
		"played_av_sync_cues": [],
		"engine": Engine.get_version_info(),
		"project": ProjectSettings.get_setting("application/config/name", ""),
		"output_csv": _csv_path,
	}
	var summary_path: String = output_dir.path_join("frame_pacing_summary_%d.json" % _started_ms)
	var summary_file: FileAccess = FileAccess.open(summary_path, FileAccess.WRITE)
	if summary_file != null:
		summary_file.store_string(JSON.stringify(data, "\t"))
		summary_file.close()

func _stats(values: Array[float]) -> Dictionary[String, Variant]:
	if values.is_empty():
		return {}
	var sorted: Array[float] = values.duplicate()
	sorted.sort()
	var median: float = _percentile(sorted, 0.5)
	var over_33_3ms: int = 0
	var over_2x_median: int = 0
	var hitches_50ms: int = 0
	for value: float in sorted:
		if value > 33.3:
			over_33_3ms += 1
		if value > median * 2.0:
			over_2x_median += 1
		if value >= 50.0:
			hitches_50ms += 1
	return {
		"count": sorted.size(),
		"p50": median,
		"p95": _percentile(sorted, 0.95),
		"p99": _percentile(sorted, 0.99),
		"max": sorted[-1],
		"over_33_3ms": over_33_3ms,
		"over_2x_median": over_2x_median,
		"hitches_50ms": hitches_50ms,
	}

func _percentile(sorted: Array[float], percentile: float) -> float:
	var position: float = float(sorted.size() - 1) * percentile
	var low: int = floori(position)
	var high: int = ceili(position)
	return sorted[low] if low == high else lerpf(sorted[low], sorted[high], position - float(low))
