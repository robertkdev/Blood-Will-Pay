extends RefCounted
class_name GridPlacement

signal player_placements_changed()

const UnitViewClass := preload("res://scripts/ui/combat/unit_view.gd")
const UnitSlotView := preload("res://scripts/ui/combat/unit_slot_view.gd")
const UnitItemsView := preload("res://scripts/ui/items/unit_items_view.gd")
const Debug := preload("res://scripts/util/debug.gd")
const Strings := preload("res://scripts/util/strings.gd")

var grid_w: int = 8
var grid_h: int = 3
var tile_size: int = 72

var player_grid: GridContainer
var enemy_grid: GridContainer

var player_tiles: Array[Button] = []
var enemy_tiles: Array[Button] = []

var player_grid_helper: BoardGrid
var enemy_grid_helper: BoardGrid

var player_views: Array[UnitSlotView] = []
var enemy_views: Array[UnitSlotView] = []

# Preserve player placements by Unit identity rather than array position.
# This avoids unintended reordering when the team array changes.
var _player_index_by_unit: Dictionary = {}
var _player_base_tile_idx: int = -1

func configure(_player_grid: GridContainer, _enemy_grid: GridContainer, _tile_size: int, _grid_w: int, _grid_h: int) -> void:
	player_grid = _player_grid
	enemy_grid = _enemy_grid
	tile_size = _tile_size
	grid_w = _grid_w
	grid_h = _grid_h
	_build_grids()

func set_player_base_tile(idx: int) -> void:
	_player_base_tile_idx = idx

func get_player_tiles() -> Array:
	return player_tiles

func get_enemy_tiles() -> Array:
	return enemy_tiles

func get_player_grid() -> BoardGrid:
	return player_grid_helper

func get_enemy_grid() -> BoardGrid:
	return enemy_grid_helper

func get_player_views() -> Array:
	return player_views

func get_enemy_views() -> Array:
	return enemy_views

func get_player_placements() -> Array[int]:
	var placements: Array[int] = []
	for slot: UnitSlotView in player_views:
		placements.append(int(slot.tile_idx) if slot != null else -1)
	return placements

func set_player_placements(player_team: Array[Unit], placements: Array[int]) -> void:
	_player_index_by_unit.clear()
	var count: int = min(player_team.size(), placements.size())
	for index: int in range(count):
		var unit: Unit = player_team[index]
		var tile_index: int = int(placements[index])
		if unit != null and tile_index >= 0 and tile_index < player_tiles.size():
			_player_index_by_unit[unit] = tile_index

func teardown() -> void:
	if player_grid_helper != null:
		player_grid_helper.clear()
	if enemy_grid_helper != null:
		enemy_grid_helper.clear()
	player_tiles.clear()
	enemy_tiles.clear()
	player_views.clear()
	enemy_views.clear()
	_player_index_by_unit.clear()
	player_grid_helper = null
	enemy_grid_helper = null
	player_grid = null
	enemy_grid = null

func _build_grids() -> void:
	player_tiles.clear()
	enemy_tiles.clear()
	if player_grid:
		for c in player_grid.get_children():
			if c is Button:
				var pb: Button = c as Button
				pb.text = ""
				pb.toggle_mode = false
				pb.focus_mode = Control.FOCUS_NONE
				pb.disabled = false
				pb.mouse_filter = Control.MOUSE_FILTER_PASS
				pb.mouse_default_cursor_shape = Control.CURSOR_ARROW
				# Always enforce tile size from constants to allow runtime scaling
				pb.custom_minimum_size = Vector2(tile_size, tile_size)
				player_tiles.append(pb)
	if enemy_grid:
		for c in enemy_grid.get_children():
			if c is Button:
				var eb: Button = c as Button
				eb.text = ""
				eb.toggle_mode = false
				eb.focus_mode = Control.FOCUS_NONE
				eb.disabled = false
				eb.mouse_filter = Control.MOUSE_FILTER_PASS
				eb.mouse_default_cursor_shape = Control.CURSOR_ARROW
				# Always enforce tile size from constants to allow runtime scaling
				eb.custom_minimum_size = Vector2(tile_size, tile_size)
				enemy_tiles.append(eb)
	player_grid_helper = load("res://scripts/board_grid.gd").new()
	player_grid_helper.configure(player_tiles, grid_w, grid_h)
	enemy_grid_helper = load("res://scripts/board_grid.gd").new()
	enemy_grid_helper.configure(enemy_tiles, grid_w, grid_h)

func rebuild_enemy_views(enemy_team: Array) -> void:
	enemy_views.clear()
	if enemy_grid_helper:
		enemy_grid_helper.clear()
	var summary: Array[String] = []
	var n: int = min(enemy_team.size(), enemy_tiles.size())
	for i in range(n):
		var u: Unit = enemy_team[i]
		var uv: UnitView = UnitViewClass.new()
		uv.set_unit(u)
		uv.drag_size = Vector2(float(tile_size), float(tile_size))
		# Items overlay
		var _items_view_e: UnitItemsView = UnitItemsView.new()
		_items_view_e.set_unit(u)
		uv.add_child(_items_view_e)
		var tile_idx: int = i
		if enemy_grid_helper:
			enemy_grid_helper.attach(uv, tile_idx)
		var slot: UnitSlotView = UnitSlotView.new()
		slot.unit = u
		slot.view = uv
		slot.tile_idx = tile_idx
		enemy_views.append(slot)
		var placement: String = "%d:%s" % [i, enemy_grid_helper.get_center(tile_idx)]
		summary.append(placement)
	if not summary.is_empty():
		Debug.log("Plan", "Enemy positions %s" % [Strings.join(summary, ", ")])

func rebuild_player_views(player_team: Array, allow_drag: bool) -> void:
	# Capture previous placements by Unit from existing views to preserve layout robustly
	var prev_map: Dictionary = {}
	if player_views and player_views.size() > 0:
		for pv in player_views:
			if pv and pv.unit != null:
				prev_map[pv.unit] = int(pv.tile_idx)
	player_views.clear()
	if player_team.size() == 0:
		# No team: clear grid visuals and placement map
		if player_grid_helper:
			player_grid_helper.clear()
		_player_index_by_unit.clear()
		return
	if player_grid_helper:
		player_grid_helper.clear()
	# Assign a tile to each unit, preferring prior placement by Unit identity.
	var tiles_count: int = player_tiles.size()
	var used_tiles: Dictionary = {}
	# Update internal map from previous snapshot but do not pre-mark used tiles.
	# We will claim tiles progressively so preserved placements are kept where possible.
	for u in player_team:
		if u != null and prev_map.has(u):
			var keep: int = int(prev_map[u])
			if keep >= 0 and keep < tiles_count:
				_player_index_by_unit[u] = keep
	var summary: Array[String] = []
	var n: int = min(player_team.size(), player_tiles.size())
	for i in range(n):
		var pu: Unit = player_team[i]
		if pu == null:
			continue
		# Prefer existing placement for this Unit
		var tile_idx: int = int(_player_index_by_unit.get(pu, -1))
		# If missing/invalid or already used by another unit, pick the next free near base
		if tile_idx < 0 or tile_idx >= tiles_count or used_tiles.has(tile_idx):
			var base: int = _player_base_tile_idx if _player_base_tile_idx >= 0 else 0
			var picked: int = -1
			if tiles_count > 0:
				for off in range(tiles_count):
					var cand: int = (base + off) % tiles_count
					if not used_tiles.has(cand):
						picked = cand
						break
			if picked < 0:
				picked = max(0, min(tiles_count - 1, 0))
			tile_idx = picked
		# Record and mark used
		_player_index_by_unit[pu] = tile_idx
		used_tiles[tile_idx] = true
		var uv: UnitView = UnitViewClass.new()
		uv.set_unit(pu)
		uv.drag_size = Vector2(float(tile_size), float(tile_size))
		# Items overlay
		var _items_view_p: UnitItemsView = UnitItemsView.new()
		_items_view_p.set_unit(pu)
		uv.add_child(_items_view_p)
		if player_grid_helper:
			player_grid_helper.attach(uv, tile_idx)
		if allow_drag:
			uv.enable_drag(player_grid_helper)
			uv.dropped_on_tile.connect(_on_player_unit_view_dropped.bind(uv))
		var slot: UnitSlotView = UnitSlotView.new()
		slot.unit = pu
		slot.view = uv
		slot.tile_idx = tile_idx
		player_views.append(slot)
		var placement: String = "%d:%s" % [i, player_grid_helper.get_center(tile_idx)]
		summary.append(placement)
	if not summary.is_empty():
		Debug.log("Plan", "Player positions %s" % [Strings.join(summary, ", ")])

func _on_player_unit_view_dropped(idx: int, view: UnitView) -> void:
	if view == null:
		return
	for i: int in range(player_views.size()):
		var slot: UnitSlotView = player_views[i]
		if slot != null and slot.view == view:
			_on_player_unit_dropped(i, idx)
			return

func _on_player_unit_dropped(i: int, idx: int) -> void:
	if idx < 0 or idx >= player_tiles.size():
		return
	if i < 0 or i >= player_views.size():
		return
	# Resolve Units for source index and any target occupant
	var u_i: Unit = player_views[i].unit
	# Find if some other view currently uses the target tile
	var j: int = -1
	for k in range(player_views.size()):
		if k == i:
			continue
		var u_k: Unit = player_views[k].unit
		var t_k: int = int(_player_index_by_unit.get(u_k, -1))
		if t_k == idx:
			j = k
			break
	var old_idx: int = int(_player_index_by_unit.get(u_i, -1))
	_player_index_by_unit[u_i] = idx
	if j != -1:
		if j < 0 or j >= player_views.size():
			return
		var u_j: Unit = player_views[j].unit
		_player_index_by_unit[u_j] = old_idx
		var ctrl_i: Control = player_views[i].view
		var ctrl_j: Control = player_views[j].view
		if player_grid_helper:
			player_grid_helper.attach(ctrl_i, idx)
			player_grid_helper.attach(ctrl_j, old_idx)
		player_views[i].tile_idx = idx
		player_views[j].tile_idx = old_idx
	else:
		var ctrl: Control = player_views[i].view
		if player_grid_helper and ctrl:
			player_grid_helper.attach(ctrl, idx)
		player_views[i].tile_idx = idx
	player_placements_changed.emit()
