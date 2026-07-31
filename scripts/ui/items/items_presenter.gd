extends RefCounted
class_name ItemsPresenter

const ItemCatalog := preload("res://scripts/game/items/item_catalog.gd")
const ItemDef := preload("res://scripts/game/items/item_def.gd")

const ITEM_CARD_SCENE_PATH: String = "res://scenes/ui/items/ItemCard.tscn"
const DEFAULT_MIN_ROWS: int = 3
const EMPTY_READY_SLOTS: int = 3
const CACHE_SHELL_NAME: String = "GothicItemsPlate"

var view: Control
var left_area: Control
var grid: GridContainer
var header: Label
var router: ItemDragRouter = null
var _item_grid_helper: BoardGrid = null
var _rebuild_queued: bool = false
var _rebuilding: bool = false
var _tearing_down: bool = false
var _item_card_scene: PackedScene = null

func configure(_view: Control) -> void:
	_tearing_down = false
	_rebuild_queued = false
	_rebuilding = false
	view = _view
	if view:
		left_area = view.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ContentRow/LeftItemArea")
		grid = view.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ContentRow/LeftItemArea/ItemStorageGrid")
		header = view.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ContentRow/LeftItemArea/ItemStorageHeader") as Label
		var layout_callable: Callable = Callable(self, "_queue_material_storage_layout")
		if not view.resized.is_connected(layout_callable):
			view.resized.connect(layout_callable)
		var frame_callable: Callable = Callable(self, "_on_process_frame")
		if not view.get_tree().process_frame.is_connected(frame_callable):
			view.get_tree().process_frame.connect(frame_callable)

func initialize() -> void:
	_bind_items_signal()
	rebuild()

func teardown() -> void:
	_tearing_down = true
	_rebuild_queued = false
	_rebuilding = false
	var items: Node = _items_singleton()
	if items != null and items.is_connected("inventory_changed", Callable(self, "_on_inventory_changed")):
		items.inventory_changed.disconnect(_on_inventory_changed)
	if view != null:
		var layout_callable: Callable = Callable(self, "_queue_material_storage_layout")
		if view.resized.is_connected(layout_callable):
			view.resized.disconnect(layout_callable)
		var frame_callable: Callable = Callable(self, "_on_process_frame")
		if view.get_tree() != null and view.get_tree().process_frame.is_connected(frame_callable):
			view.get_tree().process_frame.disconnect(frame_callable)
	_clear_grid()
	_item_grid_helper = null
	router = null
	grid = null
	header = null
	left_area = null
	view = null

func _bind_items_signal() -> void:
	var items: Node = _items_singleton()
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
	_sync_storage_header(layout)
	var item_card_scene: PackedScene = _get_item_card_scene()
	if item_card_scene == null:
		_rebuilding = false
		push_error("ItemsPresenter: failed to load %s" % ITEM_CARD_SCENE_PATH)
		return
	for idx: int in range(layout.size()):
		var id: String = String(layout[idx])
		var card: Control = item_card_scene.instantiate() as Control
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
		for child: Node in grid.get_children():
			if router.has_method("attach_card"):
				router.attach_card(child)
	_rebuilding = false
	if view != null and view.has_method("_apply_responsive_layout"):
		view.call_deferred("_apply_responsive_layout")
	_queue_material_storage_layout()

func _sync_storage_header(layout: Array[String]) -> void:
	if header == null:
		return
	var occupied_slots: int = 0
	for item_id: String in layout:
		if item_id.strip_edges() != "":
			occupied_slots += 1
	header.set_meta("occupied_slots", occupied_slots)
	header.set_meta("total_slots", layout.size())
	header.text = "ITEM CACHE // EMPTY" if occupied_slots == 0 else "ITEM CACHE // %02d / %02d" % [occupied_slots, layout.size()]
	if view != null and view.has_method("_sync_item_storage_header"):
		view.call_deferred("_sync_item_storage_header")

func _queue_material_storage_layout() -> void:
	if _tearing_down:
		return
	call_deferred("_defer_material_storage_layout")

func _defer_material_storage_layout() -> void:
	if _tearing_down:
		return
	call_deferred("_apply_material_storage_layout")

func _on_process_frame() -> void:
	if _tearing_down or view == null or grid == null or header == null:
		return
	var desired_columns: int = 3
	var tight_compact: bool = bool(view.get_meta("tight_scale_layout", false))
	var compact: bool = bool(view.get_meta("compact_layout", false))
	var viewport_size: Vector2 = view.get_viewport_rect().size
	var wide_support_rail: bool = compact and not tight_compact and viewport_size.x >= 1600.0
	var desired_header_height: float = 34.0 if tight_compact else 48.0 if wide_support_rail else 42.0 if compact else 52.0
	var desired_rail_width: float = 136.0 if tight_compact else 240.0 if wide_support_rail else 180.0 if compact else 286.0
	var header_overwritten: bool = (
		not bool(header.get_meta("reliquary_cache_hierarchy", false))
		or not header.text.contains("RELIQUARY")
		or not header.text.contains("READY")
		or not header.text.contains("SEALED")
		or header.custom_minimum_size.y < desired_header_height
	)
	var layout_overwritten: bool = left_area.custom_minimum_size.x < desired_rail_width
	var shell: Panel = view.get_node_or_null(CACHE_SHELL_NAME) as Panel
	var shell_unstyled: bool = shell != null and not bool(shell.get_meta("physical_reliquary_shell", false))
	if grid.columns != desired_columns or header_overwritten or layout_overwritten or shell_unstyled:
		_apply_material_storage_layout()

func _apply_material_storage_layout() -> void:
	if _tearing_down or view == null or grid == null or header == null:
		return
	var tight_compact: bool = bool(view.get_meta("tight_scale_layout", false))
	var compact: bool = bool(view.get_meta("compact_layout", false))
	var viewport_size: Vector2 = view.get_viewport_rect().size
	var wide_support_rail: bool = compact and not tight_compact and viewport_size.x >= 1600.0
	var occupied_slots: int = int(header.get_meta("occupied_slots", 0))
	var total_slots: int = maxi(1, int(header.get_meta("total_slots", grid.get_child_count())))
	var desired_ready_slots: int = mini(EMPTY_READY_SLOTS, maxi(0, total_slots - occupied_slots))
	var visible_cards: int = 0
	var ready_slots_shown: int = 0
	for card_node: Node in grid.get_children():
		var card: Control = card_node as Control
		if card == null:
			continue
		var filled: bool = String(card.get("item_id")).strip_edges() != ""
		var ready_pocket: bool = not filled and ready_slots_shown < desired_ready_slots
		card.visible = filled or ready_pocket
		if ready_pocket:
			ready_slots_shown += 1
		if card.visible:
			visible_cards += 1
	var material_columns: int = 3
	var slot_size: Vector2 = Vector2(40.0, 56.0) if tight_compact else Vector2(70.0, 84.0) if wide_support_rail else Vector2(56.0, 74.0) if compact else Vector2(84.0, 96.0)
	var horizontal_separation: int = 4 if tight_compact else 6 if compact else 10
	var vertical_separation: int = 5 if tight_compact else 7 if compact else 10
	var visible_rows: int = maxi(1, ceili(float(visible_cards) / float(material_columns)))
	grid.columns = material_columns
	var rail_width: float = 136.0 if tight_compact else 240.0 if wide_support_rail else 180.0 if compact else 286.0
	left_area.custom_minimum_size.x = maxf(left_area.custom_minimum_size.x, rail_width)
	header.custom_minimum_size.x = maxf(header.custom_minimum_size.x, rail_width)
	grid.custom_minimum_size.x = maxf(grid.custom_minimum_size.x, rail_width)
	grid.add_theme_constant_override("h_separation", horizontal_separation)
	grid.add_theme_constant_override("v_separation", vertical_separation)
	grid.custom_minimum_size.y = maxf(
		grid.custom_minimum_size.y,
		float(visible_rows) * slot_size.y + float(maxi(0, visible_rows - 1) * vertical_separation)
	)
	grid.set_meta("material_cache_layout", true)
	grid.set_meta("visible_ready_slots", ready_slots_shown)
	grid.set_meta("visible_cache_slots", visible_cards)
	grid.set_meta("sealed_reserve_slots", maxi(0, total_slots - visible_cards))
	grid.set_meta("material_slot_size", slot_size)
	grid.set_meta("physical_compartment_shell", true)
	grid.set_meta("ready_slot_contract", EMPTY_READY_SLOTS)
	grid.set_meta("cache_scale_tier", "tight" if tight_compact else "wide_support" if wide_support_rail else "compact" if compact else "desktop")
	for card_node: Node in grid.get_children():
		var item_card: Control = card_node as Control
		if item_card != null and item_card.has_method("set_material_slot_presentation"):
			item_card.call("set_material_slot_presentation", slot_size)
	_item_grid_helper = _build_item_grid_helper()
	if router != null:
		router.set_item_grid(_item_grid_helper)
		for card_node: Node in grid.get_children():
			router.attach_card(card_node)
	_apply_material_header_style(occupied_slots, total_slots, ready_slots_shown, tight_compact, compact, wide_support_rail)
	_apply_cache_shell_style(tight_compact, compact)
	grid.queue_sort()
	left_area.queue_sort()

func _apply_material_header_style(occupied_slots: int, total_slots: int, ready_slots: int, tight_compact: bool, compact: bool, wide_support_rail: bool) -> void:
	if header == null:
		return
	var sealed_slots: int = maxi(0, total_slots - occupied_slots - ready_slots)
	header.text = (
		"CACHE RELIQUARY\n%02d READY / %02d SEALED" % [ready_slots, sealed_slots]
		if tight_compact
		else "RELIQUARY CACHE\n%02d HELD  •  %02d READY  •  %02d SEALED" % [occupied_slots, ready_slots, sealed_slots]
		if compact
		else "EVIDENCE RELIQUARY CACHE\n%02d HELD  •  %02d READY POCKETS  •  %02d SEALED IN RESERVE" % [occupied_slots, ready_slots, sealed_slots]
	)
	header.custom_minimum_size.y = 34.0 if tight_compact else 48.0 if wide_support_rail else 42.0 if compact else 52.0
	header.add_theme_font_size_override("font_size", 11 if tight_compact else 13 if wide_support_rail else 12 if compact else 15)
	header.add_theme_color_override("font_color", Color(0.94, 0.83, 0.68, 1.0))
	header.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.92))
	header.add_theme_constant_override("outline_size", 2)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	header.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.clip_text = false
	header.autowrap_mode = TextServer.AUTOWRAP_OFF
	var header_style: StyleBoxFlat = StyleBoxFlat.new()
	header_style.bg_color = Color(0.018, 0.013, 0.016, 0.98)
	header_style.border_color = Color(0.58, 0.43, 0.29, 0.94)
	header_style.border_width_left = 5
	header_style.border_width_top = 2
	header_style.border_width_right = 2
	header_style.border_width_bottom = 4
	header_style.content_margin_left = 8.0
	header_style.content_margin_top = 4.0
	header_style.content_margin_right = 6.0
	header_style.content_margin_bottom = 4.0
	header_style.shadow_color = Color(0.0, 0.0, 0.0, 0.82)
	header_style.shadow_size = 4
	header.add_theme_stylebox_override("normal", header_style)
	header.set_meta("material_cache_hierarchy", true)
	header.set_meta("reliquary_cache_hierarchy", true)
	header.set_meta("cache_visual_language", "evidence_reliquary")
	header.set_meta("ready_slots", ready_slots)
	header.set_meta("sealed_slots", sealed_slots)
	header.set_meta("header_hierarchy_lines", 2)
	header.set_meta("wide_support_rail", wide_support_rail)
	header.set_meta("purposeful_empty_focus", occupied_slots == 0 and ready_slots == EMPTY_READY_SLOTS)
	if grid != null:
		grid.set_meta("material_header_text", header.text)

func _apply_cache_shell_style(tight_compact: bool, compact: bool) -> void:
	if view == null:
		return
	var shell: Panel = view.get_node_or_null(CACHE_SHELL_NAME) as Panel
	if shell == null:
		return
	var shell_style: StyleBoxFlat = StyleBoxFlat.new()
	shell_style.bg_color = Color(0.012, 0.009, 0.012, 0.98)
	shell_style.border_color = Color(0.48, 0.38, 0.30, 0.94)
	shell_style.border_width_left = 4 if tight_compact else 5
	shell_style.border_width_top = 2
	shell_style.border_width_right = 2
	shell_style.border_width_bottom = 5 if compact or tight_compact else 7
	shell_style.content_margin_left = 7.0 if tight_compact else 9.0
	shell_style.content_margin_top = 7.0 if tight_compact else 9.0
	shell_style.content_margin_right = 7.0 if tight_compact else 9.0
	shell_style.content_margin_bottom = 8.0 if tight_compact else 10.0
	shell_style.shadow_color = Color(0.18, 0.0, 0.015, 0.68)
	shell_style.shadow_size = 8 if compact or tight_compact else 12
	shell.add_theme_stylebox_override("panel", shell_style)
	shell.set_meta("physical_reliquary_shell", true)
	shell.set_meta("cache_material_palette", "black_bone_oxblood")

func _get_item_card_scene() -> PackedScene:
	if _item_card_scene == null:
		_item_card_scene = ResourceLoader.load(ITEM_CARD_SCENE_PATH, "PackedScene") as PackedScene
	return _item_card_scene

func _clear_grid() -> void:
	if grid == null:
		return
	for child: Node in grid.get_children():
		grid.remove_child(child)
		child.queue_free()

func _items_singleton() -> Node:
	if Engine.has_singleton("Items"):
		return Items
	var node: Node = view.get_tree().root.get_node_or_null("/root/Items") if view != null else null
	return node

func _inventory_snapshot() -> Dictionary:
	var result: Dictionary = {}
	var items: Node = _items_singleton()
	if items == null:
		return result
	# Prefer explicit getter if it exists
	if items.has_method("get_inventory"):
		var inventory: Variant = items.call("get_inventory")
		if inventory is Dictionary:
			return inventory.duplicate()
	if items.has_method("get_inventory_snapshot"):
		var inventory_snapshot: Variant = items.call("get_inventory_snapshot")
		if inventory_snapshot is Dictionary:
			return inventory_snapshot.duplicate()
	# Fallback: attempt to read internal map (read-only) if exposed
	if items.has_method("get"):
		var raw: Variant = items.get("_inventory")
		if raw is Dictionary:
			return raw.duplicate()
	return result

func _inventory_layout() -> Array[String]:
	var items: Node = _items_singleton()
	if items != null and items.has_method("get_inventory_slots"):
		var slots: Variant = items.call("get_inventory_slots")
		if slots is Array:
			var out: Array[String] = []
			for value: Variant in slots:
				out.append(String(value))
			return out
	var inv: Dictionary = _inventory_snapshot()
	var order: Array[String] = ["component", "completed", "special"]
	var ids: Array[String] = []
	for key: Variant in inv.keys():
		ids.append(String(key))
	ids.sort_custom(func(a: String, b: String) -> bool:
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
	for id: String in ids:
		var cnt: int = int(inv.get(id, 0))
		for _i: int in range(cnt):
			fallback.append(String(id))
	return fallback

func set_router(r: ItemDragRouter) -> void:
	router = r
	# Attach to existing cards
	if router != null and grid != null:
		# Ensure the router knows about the inventory grid immediately
		if _item_grid_helper != null and router.has_method("set_item_grid"):
			router.set_item_grid(_item_grid_helper)
		for child: Node in grid.get_children():
			if router.has_method("attach_card"):
				router.attach_card(child)
		if Engine.has_singleton("Debug"):
			print("[ItemsPresenter] Router attached to ", grid.get_children().size(), " item cards")

func _build_item_grid_helper() -> BoardGrid:
	if grid == null:
		return null
	var tiles: Array[Control] = []
	for child: Node in grid.get_children():
		if child is Control:
			tiles.append(child as Control)
	var cols: int = int(grid.columns) if grid and grid.has_method("get") else 1
	cols = max(1, cols)
	var rows: int = int(ceil(float(tiles.size()) / float(cols)))
	var helper: BoardGrid = BoardGrid.new()
	helper.configure(tiles, cols, rows)
	return helper
