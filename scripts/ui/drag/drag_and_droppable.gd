extends Control
class_name DragAndDroppable

signal dropped_on_tile(tile_idx: int)
signal dropped_on_target(grid, tile_idx: int)
signal began_drag()
signal ended_drag()

@export var content_root_path: NodePath
@export var drag_size: Vector2 = Vector2(72, 72)
@export var allowed_phases: Array = []
@export var drag_channel: String = ""

var _grid: BoardGrid = null
var _grids: Array[BoardGrid] = [] # Optional multiple targets; first is preferred
var _dragging: bool = false
var _mouse_down: bool = false
var _press_pos: Vector2 = Vector2.ZERO
var _last_mouse_pos: Vector2 = Vector2.ZERO
var _orig_tile_idx: int = -1

var _ghost: Control = null
var _drag_mgr: DragManager = null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process_input(false)
	if not is_connected("gui_input", Callable(self, "_on_gui_input_base")):
		gui_input.connect(_on_gui_input_base)

func set_drop_grid(grid: BoardGrid) -> void:
	# Backward-compatible single-target API
	_grid = grid
	_grids.clear()
	if grid:
		_grids.append(grid)
		_orig_tile_idx = grid.index_of(self)

func enable_drag(grid: BoardGrid) -> void:
	set_drop_grid(grid)

func set_drop_targets(grids: Array) -> void:
	# Preferred multi-target API (KISS): store ordered list; first has precedence
	_grids.clear()
	for raw_grid: Variant in grids:
		var grid: BoardGrid = raw_grid as BoardGrid
		if grid != null:
			_grids.append(grid)
	_grid = null
	_orig_tile_idx = -1
	for grid: BoardGrid in _grids:
		var origin_index: int = grid.index_of(self)
		if origin_index != -1:
			_grid = grid
			_orig_tile_idx = origin_index
			break
	if _grid == null and _grids.size() > 0:
		_grid = _grids[0]

func can_drag_now() -> bool:
	# Prefer global GameState if available for phase checks
	var current_phase: int = -1
	if Engine.has_singleton("GameState") or has_node("/root/GameState"):
		current_phase = GameState.phase
	else:
		var main: Node = get_tree().root.get_node_or_null("/root/Main")
		current_phase = main.game_phase if main != null else -1
	var phase_ok: bool = allowed_phases.is_empty() or allowed_phases.has(current_phase)
	return phase_ok and _can_drag_extra()

func _can_drag_extra() -> bool:
	return true

func on_drop(_success: bool, _index: int) -> void:
	# Overridable hook for subclasses (e.g., items)
	pass

func finish_drag_at_global(global_pos: Vector2) -> void:
	_last_mouse_pos = global_pos
	if _dragging:
		_end_drag_internal()

func _on_gui_input_base(event: InputEvent) -> void:
	if not can_drag_now():
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_last_mouse_pos = _event_mouse_position(event)
		if event.pressed:
			_mouse_down = true
			_press_pos = _last_mouse_pos
		else:
			_mouse_down = false
			if _dragging:
				_end_drag_internal()
	elif event is InputEventMouseMotion:
		_last_mouse_pos = _event_mouse_position(event)
		var mp: Vector2 = _last_mouse_pos
		if _mouse_down and not _dragging:
			if mp.distance_to(_press_pos) > 6.0:
				_begin_drag_internal()
		if _dragging and _drag_mgr:
			_drag_mgr.update()

func _input(event: InputEvent) -> void:
	if not _dragging:
		return
	if event is InputEventMouseMotion:
		_last_mouse_pos = _event_mouse_position(event)
		if _drag_mgr:
			_drag_mgr.update()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_last_mouse_pos = _event_mouse_position(event)
		if not event.pressed:
			_mouse_down = false
			_end_drag_internal()
			var viewport: Viewport = get_viewport()
			if viewport != null:
				viewport.set_input_as_handled()

func _event_mouse_position(event: InputEvent) -> Vector2:
	var mouse_event: InputEventMouse = event as InputEventMouse
	if mouse_event != null:
		return mouse_event.global_position
	var vp: Viewport = get_viewport()
	return vp.get_mouse_position() if vp != null else Vector2.ZERO

func _begin_drag_internal() -> void:
	_dragging = true
	set_process_input(true)
	emit_signal("began_drag")
	# print debug removed
	mouse_filter = Control.MOUSE_FILTER_STOP
	if _drag_mgr == null:
		_drag_mgr = load("res://scripts/ui/drag/drag_manager.gd").new()
	if _orig_tile_idx == -1:
		# Resolve origin grid from available targets to allow bench↔board drags
		var resolved: bool = false
		if _grid != null:
			var oi: int = _grid.index_of(self)
			if oi != -1:
				_orig_tile_idx = oi
				resolved = true
		if not resolved and _grids.size() > 0:
			for g in _grids:
				var idx: int = g.index_of(self)
				if idx != -1:
					_grid = g
					_orig_tile_idx = idx
					resolved = true
					break
	# Build ghost from content root (clone subtree so bars/sprite follow)
	var src: Control = (get_node_or_null(content_root_path) as Control) if content_root_path != NodePath("") else self
	_ghost = Control.new()
	_ghost.name = "DragGhost"
	_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ghost.anchor_left = 0.0
	_ghost.anchor_top = 0.0
	_ghost.anchor_right = 0.0
	_ghost.anchor_bottom = 0.0
	_ghost.size = drag_size
	_ghost.z_index = 2000
	if src:
		var clone: Node = src.duplicate(true)
		if clone is Control:
			_ghost.add_child(clone)
			# Fill ghost
			(clone as Control).anchor_left = 0.0
			(clone as Control).anchor_top = 0.0
			(clone as Control).anchor_right = 1.0
			(clone as Control).anchor_bottom = 1.0
			(clone as Control).offset_left = 0.0
			(clone as Control).offset_top = 0.0
			(clone as Control).offset_right = 0.0
			(clone as Control).offset_bottom = 0.0
			_set_mouse_ignore_recursive(clone)
	# Place ghost at this control's position
	var rect: Rect2 = get_global_rect()
	_ghost.global_position = rect.position
	get_tree().root.add_child(_ghost)
	# Dim original during drag
	self.modulate.a = 0.35
	_drag_mgr.begin(_ghost, _grid)
	# print debug removed

func _set_mouse_ignore_recursive(n: Node) -> void:
	if n is Control:
		(n as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in n.get_children():
		_set_mouse_ignore_recursive(c)

func _end_drag_internal() -> void:
	_dragging = false
	set_process_input(false)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var did_drop: bool = false
	var idx: int = -1
	var target_grid: BoardGrid = null
	var mp: Vector2 = _last_mouse_pos
	# print debug removed
	if _grids.size() > 0:
		for g in _grids:
			var ti: int = g.index_at_global(mp)
			# print debug removed
			if ti != -1:
				idx = ti
				target_grid = g
				break
	elif _grid:
		idx = _grid.index_at_global(mp)
		if idx != -1:
			target_grid = _grid
	if target_grid != null and idx != -1:
		# print debug removed
		emit_signal("dropped_on_tile", idx)
		emit_signal("dropped_on_target", target_grid, idx)
		did_drop = true
	elif _orig_tile_idx >= 0 and _grid:
		# print debug removed
		_grid.attach(self, _orig_tile_idx)
	on_drop(did_drop, idx)
	if _drag_mgr:
		_drag_mgr.end()
		_drag_mgr = null
	if _ghost:
		var p: Node = _ghost.get_parent()
		if p:
			p.remove_child(_ghost)
		_ghost.queue_free()
		_ghost = null
	self.modulate.a = 1.0
	emit_signal("ended_drag")
	# print debug removed

# Public helper to clean up any in-progress drag artifacts (ghost, manager)
# Useful for external callers that dispose the control during a drop.
func cleanup_drag_artifacts() -> void:
	_dragging = false
	set_process_input(false)
	mouse_filter = Control.MOUSE_FILTER_STOP
	if _drag_mgr:
		_drag_mgr.end()
		_drag_mgr = null
	if _ghost:
		var p: Node = _ghost.get_parent()
		if p:
			p.remove_child(_ghost)
		_ghost.queue_free()
		_ghost = null
	self.modulate.a = 1.0
