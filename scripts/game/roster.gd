extends Node

const Unit := preload("res://scripts/unit.gd")
const BenchConstants := preload("res://scripts/constants/bench_constants.gd")
const ShopConfig := preload("res://scripts/game/shop/shop_config.gd")
const STARTING_TEAM_SIZE: int = ShopConfig.DEFAULT_BOARD_CAPACITY

signal bench_changed()
signal max_team_size_changed(old_value: int, new_value: int)

# Bench slots store owned-but-benched units. Fixed capacity per BenchConstants.
var bench_slots: Array[Unit] = []

# When >= 0, represents a hard cap for on-board units.
var max_team_size: int = STARTING_TEAM_SIZE

func _ready() -> void:
	_ensure_capacity()

func _ensure_capacity() -> void:
	var cap: int = int(BenchConstants.BENCH_CAPACITY)
	if bench_slots.size() < cap:
		while bench_slots.size() < cap:
			bench_slots.append(null)
	elif bench_slots.size() > cap:
		bench_slots.resize(cap)

func slot_count() -> int:
	return int(BenchConstants.BENCH_CAPACITY)

func get_slot(slot: int) -> Unit:
	if slot < 0 or slot >= bench_slots.size():
		return null
	return bench_slots[slot]

func set_slot(slot: int, unit: Unit) -> bool:
	if slot < 0 or slot >= bench_slots.size():
		return false
	bench_slots[slot] = unit
	bench_changed.emit()
	return true

func first_empty_slot() -> int:
	for i in range(bench_slots.size()):
		if bench_slots[i] == null:
			return i
	return -1

func remove(unit: Unit) -> bool:
	if unit == null:
		return false
	for i in range(bench_slots.size()):
		if bench_slots[i] == unit:
			bench_slots[i] = null
			bench_changed.emit()
			return true
	return false

func compact() -> Array[Unit]:
	var out: Array[Unit] = []
	for u in bench_slots:
		if u != null:
			out.append(u)
	return out


func reset(clear_max_team: bool = true) -> void:
	for i in range(bench_slots.size()):
		var u: Unit = bench_slots[i]
		if u != null:
			var items: Node = _items_singleton()
			if items != null and items.has_method("remove_all"):
				items.call("remove_all", u)
		bench_slots[i] = null
	if clear_max_team:
		var prev: int = max_team_size
		max_team_size = STARTING_TEAM_SIZE
		if prev != max_team_size:
			max_team_size_changed.emit(prev, max_team_size)
	bench_changed.emit()

func set_max_team_size(value: int) -> int:
	var target: int = max(0, int(value))
	if target == max_team_size:
		return max_team_size
	var old: int = max_team_size
	max_team_size = target
	max_team_size_changed.emit(old, max_team_size)
	return max_team_size

func _items_singleton() -> Node:
	if Engine.has_singleton("Items"):
		return Items
	var loop: MainLoop = Engine.get_main_loop()
	if loop is SceneTree:
		var tree: SceneTree = loop as SceneTree
		if tree.root != null:
			return tree.root.get_node_or_null("/root/Items")
	return null

# Returns a union of current on-board team and bench (no duplicates, preserve order: team first).
func owned_units(current_team: Array = []) -> Array[Unit]:
	var seen: Dictionary = {}
	var out: Array[Unit] = []
	# Team units first
	for u in current_team:
		if u != null and not seen.has(u):
			out.append(u)
			seen[u] = true
	# Then bench slots
	for b in bench_slots:
		if b != null and not seen.has(b):
			out.append(b)
			seen[b] = true
	return out

# Increase cap by n; when unlimited (<0), remains unlimited.
func increase_max_team_size(n: int) -> int:
	var inc: int = int(n)
	if inc == 0:
		return max_team_size
	if max_team_size < 0:
		return max_team_size
	var old: int = max_team_size
	max_team_size = max(0, max_team_size + inc)
	if max_team_size != old:
		max_team_size_changed.emit(old, max_team_size)
	return max_team_size

# Decrease cap by n; never below the provided floor (e.g., current board size).
# If unlimited (<0), remains unlimited.
func decrease_max_team_size(n: int, floor_current_board_size: int = -1) -> int:
	var dec: int = int(n)
	if dec <= 0:
		return max_team_size
	if max_team_size < 0:
		return max_team_size
	var old: int = max_team_size
	var floor_val: int = 0
	if floor_current_board_size >= 0:
		floor_val = int(floor_current_board_size)
	var target: int = max(floor_val, max(0, max_team_size - dec))
	if target != max_team_size:
		max_team_size = target
		max_team_size_changed.emit(old, max_team_size)
	return max_team_size
