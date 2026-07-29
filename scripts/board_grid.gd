extends RefCounted
class_name BoardGrid

# Lightweight helper around an existing array of tile Controls.
# Not a Node; consumers pass tiles and configuration.

var _tiles: Array[Control] = []
var _columns: int = 0
var _rows: int = 0
var _occupants: Array[Control] = []
var _index_by_control: Dictionary = {}

func configure(tiles: Array, columns: int, rows: int) -> void:
	_tiles = []
	for t in tiles:
		if t is Control:
			_tiles.append(t)
	_columns = max(1, columns)
	_rows = max(1, rows)
	_occupants.clear()
	_index_by_control.clear()
	for i in range(_tiles.size()):
		_occupants.append(null)

func size() -> int:
	return _tiles.size()

func tile_at(idx: int) -> Control:
	if idx < 0 or idx >= _tiles.size():
		return null
	return _tiles[idx]

func index_at_global(pos: Vector2) -> int:
	for i in range(_tiles.size()):
		var t: Control = _tiles[i]
		if not is_instance_valid(t):
			continue
		if t.get_global_rect().has_point(pos):
			return i
	return -1

func attach(control: Control, idx: int) -> void:
	var tile := tile_at(idx)
	if not tile or not control:
		return
	# Clear previous mapping
	var prev_idx := index_of(control)
	if prev_idx != -1:
		_occupants[prev_idx] = null
		_index_by_control.erase(control)
	var parent := control.get_parent()
	if parent:
		parent.remove_child(control)
	tile.add_child(control)
	if control is Control:
		control.anchor_left = 0.0
		control.anchor_top = 0.0
		control.anchor_right = 1.0
		control.anchor_bottom = 1.0
		control.offset_left = 0.0
		control.offset_top = 0.0
		control.offset_right = 0.0
		control.offset_bottom = 0.0
	_occupants[idx] = control
	_index_by_control[control] = idx

func clear() -> void:
	# Remove all children from each tile and reset occupancy maps
	for i in range(_tiles.size()):
		var tile: Control = _tiles[i]
		if not is_instance_valid(tile):
			continue
		for child in tile.get_children():
			if child is Node:
				child.queue_free()
	_occupants.clear()
	for i in range(_tiles.size()):
		_occupants.append(null)
	_index_by_control.clear()

func get_center(idx: int) -> Vector2:
	var tile := tile_at(idx)
	if not tile:
		return Vector2.ZERO
	return tile.get_global_rect().get_center()

func is_occupied(idx: int) -> bool:
	if idx < 0 or idx >= _occupants.size():
		return false
	return _occupants[idx] != null

func occupant_at(idx: int) -> Control:
	if idx < 0 or idx >= _occupants.size():
		return null
	return _occupants[idx]

func index_of(control: Control) -> int:
	if _index_by_control.has(control):
		return int(_index_by_control[control])
	return -1

func swap(a: int, b: int) -> void:
	if a == b:
		return
	var ta := tile_at(a)
	var tb := tile_at(b)
	if not ta or not tb:
		return
	var ca := _occupants[a]
	var cb := _occupants[b]
	if ca:
		attach(ca, b)
	if cb:
		attach(cb, a)

func neighbors(idx: int) -> Array[int]:
	var out: Array[int] = []
	if idx < 0 or idx >= _tiles.size():
		return out
	var x := idx % _columns
	var y := int(float(idx) / float(_columns))
	var dirs = [[1,0],[-1,0],[0,1],[0,-1]]
	for d in dirs:
		var nx: int = x + d[0]
		var ny: int = y + d[1]
		if nx >= 0 and nx < _columns and ny >= 0 and ny < _rows:
			out.append(ny * _columns + nx)
	return out

func distance(a: int, b: int) -> int:
	if a < 0 or b < 0:
		return 0
	var ax := a % _columns
	var ay := int(float(a) / float(_columns))
	var bx := b % _columns
	var by := int(float(b) / float(_columns))
	return abs(ax - bx) + abs(ay - by)
