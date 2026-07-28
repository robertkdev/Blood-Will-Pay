extends RefCounted
class_name ItemsPresenter

const ItemCatalog := preload("res://scripts/game/items/item_catalog.gd")
const ItemDef := preload("res://scripts/game/items/item_def.gd")

const ITEM_CARD_SCENE := preload("res://scenes/ui/items/ItemCard.tscn")
const DEFAULT_MIN_ROWS := 3

var view: Control
var left_area: Control
var grid: GridContainer
var router
var _item_grid_helper
var _rebuild_queued: bool = false
var _rebuilding: bool = false
var _tearing_down: bool = false

func configure(_view: Control) -> void:
	_tearing_down = false
	_rebuild_queued = false
	_rebuilding = false
	view = _view
	if view:
		left_area = view.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ContentRow/LeftItemArea")
		grid = view.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ContentRow/LeftItemArea/ItemStorageGrid")

func initialize() -> void:
	_bind_items_signal()
	rebuild()

func teardown() -> void:
	_tearing_down = true
	_rebuild_queued = false
	_rebuilding = false
	var items = _items_singleton()
	if items != null and items.is_connected("inventory_changed", Callable(self, "_on_inventory_changed")):
		items.inventory_changed.disconnect(_on_inventory_changed)
	_clear_grid()
	_item_grid_helper = null
	router = null
	grid = null
	left_area = null
	view = null

func _bind_items_signal() -> void:
	var items = _items_singleton()
	if items != null and not items.is_connected("inventory_changed", Callable(self, "_on_inventory_changed")):
		items.inventory_changed.connect(_on_inventory_changed)

func _on_inventory_changed() -> void:
	_queue_rebuild()

func _queue_rebuild() -> void:
	if _tearing_down or _rebuild_queued:
		return
	_rebuild_queued = true
	call_deferred("_flush_queued_rebuild")

func _flush_queued_rebuild() -> void:
	_rebuild_queued = false
	if _tearing_down:
		return
	rebuild()

func rebuild() -> void:
	if _tearing_down or grid == null or left_area == null:
		return
	if _rebuilding:
		_queue_rebuild()
		return
	_rebuilding = true
	_clear_grid()
	var layout: Array[String] = _inventory_layout()
	var cols: int = int(grid.columns) if grid and grid.has_method("get") else 1
	cols = max(1, cols)
	var min_slots: int = cols * DEFAULT_MIN_ROWS
	while layout.size() < min_slots:
		layout.append("")
	for idx in range(layout.size()):
		var id := String(layout[idx])
		var card := ITEM_CARD_SCENE.instantiate()
		if card == null:
			continue
		if card.has_method("set_item_id"):
			card.set_item_id(id)
		if card.has_method("set_count"):
			card.set_count(1 if id != "" else 0)
		if card.has_method("set_slot_index"):
			card.set_slot_index(idx)
		else:
			card.set("slot_index", idx)
		grid.add_child(card)
		if router != null and router.has_method("attach_card"):
			router.attach_card(card)

	# Rebuild an item-grid helper so item-to-item drags can target specific cards.
	_item_grid_helper = _build_item_grid_helper()
	if router != null and router.has_method("set_item_grid"):
		router.set_item_grid(_item_grid_helper)
		# Re-attach to ensure drop targets include the item grid
		for c in grid.get_children():
			if router.has_method("attach_card"):
				router.attach_card(c)
	_rebuilding = false

func _clear_grid() -> void:
	if grid == null:
		return
	for c in grid.get_children():
		grid.remove_child(c)
		c.queue_free()

func _items_singleton():
	if Engine.has_singleton("Items"):
		return Items
	var node := (view.get_tree().root.get_node_or_null("/root/Items") if view else null)
	return node

func _inventory_snapshot() -> Dictionary:
	var result: Dictionary = {}
	var items = _items_singleton()
	if items == null:
		return result
	# Prefer explicit getter if it exists
	if items.has_method("get_inventory"):
		var inv = items.get_inventory()
		if inv is Dictionary:
			return inv.duplicate()
	if items.has_method("get_inventory_snapshot"):
		var inv2 = items.get_inventory_snapshot()
		if inv2 is Dictionary:
			return inv2.duplicate()
	# Fallback: attempt to read internal map (read-only) if exposed
	if items.has_method("get"):
		var raw = items.get("_inventory")
		if raw is Dictionary:
			return raw.duplicate()
	return result

func _inventory_layout() -> Array[String]:
	var items = _items_singleton()
	if items != null and items.has_method("get_inventory_slots"):
		var slots = items.get_inventory_slots()
		if slots is Array:
			var out: Array[String] = []
			for v in slots:
				out.append(String(v))
			return out
	var inv := _inventory_snapshot()
	var order: Array[String] = ["component", "completed", "special"]
	var ids: Array[String] = []
	for k in inv.keys():
		ids.append(String(k))
	ids.sort_custom(func(a, b):
		var da: ItemDef = ItemCatalog.get_def(a)
		var db: ItemDef = ItemCatalog.get_def(b)
		var ia: int = order.find(String(da.type)) if da != null else 3
		var ib: int = order.find(String(db.type)) if db != null else 3
		if ia == ib:
			var na: String = (da.name if da != null and String(da.name) != "" else a)
			var nb: String = (db.name if db != null and String(db.name) != "" else b)
			return String(na) < String(nb)
		return ia < ib)
	var fallback: Array[String] = []
	for id in ids:
		var cnt: int = int(inv.get(id, 0))
		for _i in range(cnt):
			fallback.append(String(id))
	return fallback

func set_router(r) -> void:
	router = r
	# Attach to existing cards
	if router != null and grid != null:
		# Ensure the router knows about the inventory grid immediately
		if _item_grid_helper != null and router.has_method("set_item_grid"):
			router.set_item_grid(_item_grid_helper)
		for c in grid.get_children():
			if router.has_method("attach_card"):
				router.attach_card(c)
		if Engine.has_singleton("Debug"):
			print("[ItemsPresenter] Router attached to ", grid.get_children().size(), " item cards")

func _build_item_grid_helper():
	if grid == null:
		return null
	var tiles: Array[Control] = []
	for c in grid.get_children():
		if c is Control:
			tiles.append(c as Control)
	var cols: int = int(grid.columns) if grid and grid.has_method("get") else 1
	cols = max(1, cols)
	var rows: int = int(ceil(float(tiles.size()) / float(cols)))
	var helper = load("res://scripts/board_grid.gd").new()
	helper.configure(tiles, cols, rows)
	return helper
