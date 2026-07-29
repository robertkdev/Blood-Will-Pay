extends RefCounted
class_name MoveRouter

const Debug := preload("res://scripts/util/debug.gd")

# Loose-typed external refs to avoid circular deps
var manager
var roster # Roster autoload
var board_grid
var bench_grid
var grid_placement
var bench_placement

var refresh_cb: Callable = Callable()
var last_route_status: Dictionary = {}

func configure(_manager, _roster, _board_grid, _bench_grid, _grid_placement, _bench_placement) -> void:
	manager = _manager
	roster = _roster
	board_grid = _board_grid
	bench_grid = _bench_grid
	grid_placement = _grid_placement
	bench_placement = _bench_placement

func set_refresh_callback(cb: Callable) -> void:
	refresh_cb = cb

func route_bench_to_board(uv: UnitView, tile_idx: int) -> bool:
	return _bench_to_board(uv, tile_idx)

func route_board_to_bench(uv: UnitView, tile_idx: int) -> bool:
	return _board_to_bench(uv, tile_idx)

func teardown() -> void:
	manager = null
	roster = null
	board_grid = null
	bench_grid = null
	grid_placement = null
	bench_placement = null
	refresh_cb = Callable()
	last_route_status.clear()

func _set_route_status(ok: bool, code: String, details: Dictionary = {}) -> bool:
	last_route_status = details.duplicate(true)
	last_route_status["ok"] = ok
	last_route_status["code"] = code
	return ok

func connect_unit_view(uv: UnitView) -> void:
	if uv and not uv.is_connected("dropped_on_target", Callable(self, "_on_unit_dropped")):
		uv.dropped_on_target.connect(_on_unit_dropped.bind(uv))

func _on_unit_dropped(target_grid, tile_idx: int, uv: UnitView) -> void:
	if uv == null or target_grid == null or tile_idx < 0:
		return
	# Phase guard
	if Engine.has_singleton("GameState") or uv.has_node("/root/GameState"):
		if GameState.phase == GameState.GamePhase.COMBAT:
			if Debug.enabled:
				print("[MoveRouter] Drop ignored: in COMBAT phase")
			return
	var from_board: bool = (board_grid != null and board_grid.index_of(uv) != -1)
	var from_bench: bool = (bench_grid != null and bench_grid.index_of(uv) != -1)
	if target_grid == board_grid and from_bench:
		_bench_to_board(uv, tile_idx)
		return
	if target_grid == bench_grid and from_board:
		_board_to_bench(uv, tile_idx)
		return
	if target_grid == bench_grid and from_bench:
		_bench_to_bench(uv, tile_idx)
		return
	# Board↔Board is handled by GridPlacement via dropped_on_tile
	if target_grid == board_grid and from_board:
		return
	# If target is neither board nor bench (e.g., shop sell grid), leave handling to controller
	if target_grid != board_grid and target_grid != bench_grid:
		return
	# Unknown route: snap back via helper
	_snap_back(uv)

func _bench_to_board(uv: UnitView, tile_idx: int) -> bool:
	if manager == null or board_grid == null or bench_grid == null or grid_placement == null or bench_placement == null:
		return _set_route_status(false, "missing_refs")

	# Explicitly type and cast the unit
	var u: Unit = (uv.unit as Unit)
	if u == null:
		_snap_back(uv)
		return _set_route_status(false, "missing_unit")
	var source_slot: int = bench_grid.index_of(uv)
	if source_slot == -1:
		source_slot = _roster_slot_of(u)
	if board_grid.is_occupied(tile_idx):
		return _bench_to_board_swap(uv, tile_idx, u, source_slot)
	if uv.has_method("set_bench_mode"):
		uv.set_bench_mode(false)

	# Team size cap (only when enabled)
	var cap: int = (int(roster.max_team_size) if roster else -1)
	if cap >= 0 and manager.player_team.size() >= cap:
		if Debug.enabled:
			print("[MoveRouter] Bench→Board failed: max team size reached", cap)
		_snap_back(uv)
		return _set_route_status(false, "team_cap_reached", {"cap": cap, "team_size": manager.player_team.size()})

	# Remove from bench
	if roster and roster.has_method("remove"):
		roster.remove(u)

	# Add to team
	manager.player_team.append(u)

	# Refresh views via controller callback when available (DRY)
	if refresh_cb.is_valid():
		refresh_cb.call()
	else:
		bench_placement.rebuild_bench_views(roster.bench_slots if roster else [], true)
		grid_placement.rebuild_player_views(manager.player_team, true)

	# Place new unit at desired tile (swap if needed)
	var idx_in_team: int = -1
	for i in range(manager.player_team.size()):
		if manager.player_team[i] == u:
			idx_in_team = i
			break
	if idx_in_team != -1 and grid_placement.has_method("_on_player_unit_dropped"):
		grid_placement._on_player_unit_dropped(idx_in_team, tile_idx)

	# Dispose original dragged view to avoid stale duplicates capturing input
	if uv:
		# Ensure any drag ghost is cleaned up before freeing the original view
		if uv.has_method("cleanup_drag_artifacts"):
			uv.cleanup_drag_artifacts()
		if uv.is_inside_tree():
			uv.queue_free()
	return _set_route_status(true, "bench_to_board", {"tile": tile_idx, "team_size": manager.player_team.size()})

func _bench_to_board_swap(uv: UnitView, tile_idx: int, bench_unit: Unit, source_slot: int) -> bool:
	if roster == null:
		_snap_back(uv)
		return _set_route_status(false, "missing_roster")
	if source_slot < 0 or source_slot >= bench_grid.size():
		_snap_back(uv)
		return _set_route_status(false, "bench_source_missing", {"tile": tile_idx, "bench_slot": source_slot})
	var board_unit: Unit = _board_unit_at_tile(tile_idx)
	if board_unit == null:
		_snap_back(uv)
		return _set_route_status(false, "board_unit_missing", {"tile": tile_idx, "bench_slot": source_slot})
	var board_team_index: int = _team_index_of(board_unit)
	if board_team_index == -1:
		_snap_back(uv)
		return _set_route_status(false, "board_unit_not_in_team", {"tile": tile_idx, "bench_slot": source_slot})
	if uv.has_method("set_bench_mode"):
		uv.set_bench_mode(false)
	manager.player_team[board_team_index] = bench_unit
	roster.set_slot(source_slot, board_unit)
	if refresh_cb.is_valid():
		refresh_cb.call()
	else:
		bench_placement.rebuild_bench_views(roster.bench_slots if roster else [], true)
		grid_placement.rebuild_player_views(manager.player_team, true)
	if grid_placement.has_method("_on_player_unit_dropped"):
		grid_placement._on_player_unit_dropped(board_team_index, tile_idx)
	if uv:
		if uv.has_method("cleanup_drag_artifacts"):
			uv.cleanup_drag_artifacts()
		if uv.is_inside_tree():
			uv.queue_free()
	return _set_route_status(true, "bench_to_board_swap", {"tile": tile_idx, "bench_slot": source_slot, "team_size": manager.player_team.size()})

func _board_to_bench(uv: UnitView, tile_idx: int) -> bool:
	if manager == null or board_grid == null or bench_grid == null or grid_placement == null or bench_placement == null or roster == null:
		return _set_route_status(false, "missing_refs")

	var u: Unit = (uv.unit as Unit)
	if u == null:
		_snap_back(uv)
		return _set_route_status(false, "missing_unit")
	if uv.has_method("set_bench_mode"):
		uv.set_bench_mode(true)

	# Prefer the exact target bench tile when available
	var slot: int = int(tile_idx)
	# If the chosen slot is invalid or occupied, fall back to first empty
	if slot < 0 or slot >= bench_grid.size() or (roster.get_slot(slot) != null):
		slot = roster.first_empty_slot() if roster.has_method("first_empty_slot") else -1
	if slot == -1:
		if Debug.enabled:
			print("[MoveRouter] Board→Bench failed: bench full or no valid slot")
		_snap_back(uv)
		return _set_route_status(false, "bench_full", {"tile": tile_idx})

	# Remove from board team by identity
	var rem_idx: int = -1
	for i in range(manager.player_team.size()):
		if manager.player_team[i] == u:
			rem_idx = i
			break
	if rem_idx == -1:
		_snap_back(uv)
		return _set_route_status(false, "unit_not_on_board", {"tile": tile_idx, "bench_slot": slot})

	manager.player_team.remove_at(rem_idx)
	roster.set_slot(slot, u)

	# Refresh views via controller callback when available (DRY)
	if refresh_cb.is_valid():
		refresh_cb.call()
	else:
		grid_placement.rebuild_player_views(manager.player_team, true)
		bench_placement.rebuild_bench_views(roster.bench_slots, true)

	# Dispose original dragged view to avoid stale duplicates capturing input
	if uv:
		if uv.has_method("cleanup_drag_artifacts"):
			uv.cleanup_drag_artifacts()
		if uv.is_inside_tree():
			uv.queue_free()
	return _set_route_status(true, "board_to_bench", {"tile": tile_idx, "bench_slot": slot, "team_size": manager.player_team.size()})

func _bench_to_bench(uv: UnitView, tile_idx: int) -> void:
	if bench_grid == null or roster == null:
		_snap_back(uv)
		return
	if tile_idx < 0 or tile_idx >= bench_grid.size():
		_snap_back(uv)
		return

	var from_idx: int = bench_grid.index_of(uv)
	if from_idx == -1:
		_snap_back(uv)
		return
	if from_idx == tile_idx:
		# No-op drop on same tile
		bench_grid.attach(uv, from_idx)
		return

	# Explicit types fix the inference errors flagged on lines 151 and 155
	var u: Unit = (uv.unit as Unit)
	if u == null:
		_snap_back(uv)
		return
	if uv.has_method("set_bench_mode"):
		uv.set_bench_mode(true)

	var dest_u: Unit = (roster.get_slot(tile_idx) as Unit)

	# Place or swap
	roster.set_slot(tile_idx, u)
	roster.set_slot(from_idx, dest_u)

	# Views will be rebuilt via bench_changed signal; dispose dragged view
	if uv:
		if uv.has_method("cleanup_drag_artifacts"):
			uv.cleanup_drag_artifacts()
		if uv.is_inside_tree():
			uv.queue_free()

func _snap_back(uv: UnitView) -> void:
	if uv == null:
		return
	# Return to original grid tile if possible
	if board_grid != null:
		var bi: int = board_grid.index_of(uv)
		if bi != -1:
			board_grid.attach(uv, bi)
			return
	if bench_grid != null:
		var si: int = bench_grid.index_of(uv)
		if si != -1:
			bench_grid.attach(uv, si)
			return

func _board_unit_at_tile(tile_idx: int) -> Unit:
	if board_grid == null:
		return null
	var occupant: Control = null
	if board_grid.has_method("occupant_at"):
		occupant = board_grid.occupant_at(tile_idx)
	var board_view: UnitView = occupant as UnitView
	if board_view != null:
		return board_view.unit as Unit
	if grid_placement != null and grid_placement.has_method("get_player_views"):
		for slot_value: Variant in grid_placement.get_player_views():
			if slot_value == null:
				continue
			if int(slot_value.tile_idx) == tile_idx:
				return slot_value.unit as Unit
	return null

func _team_index_of(unit: Unit) -> int:
	if unit == null or manager == null:
		return -1
	for index: int in range(manager.player_team.size()):
		if manager.player_team[index] == unit:
			return index
	return -1

func _roster_slot_of(unit: Unit) -> int:
	if unit == null or roster == null:
		return -1
	for index: int in range(roster.bench_slots.size()):
		if roster.bench_slots[index] == unit:
			return index
	return -1
