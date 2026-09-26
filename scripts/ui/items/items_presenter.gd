extends RefCounted
class_name ItemsPresenter

const ItemCatalog := preload("res://scripts/game/items/item_catalog.gd")
const ItemDef := preload("res://scripts/game/items/item_def.gd")

const ITEM_CARD_SCENE_PATH: String = "res://scenes/ui/items/ItemCard.tscn"
const DEFAULT_MIN_ROWS: int = 3
const EMPTY_READY_SLOTS: int = 3
const CACHE_SHELL_NAME: String = "GothicItemsPlate"
## The cache is always three pockets across; how wide they can be follows from the
## rail's own width, never the other way round.
const MATERIAL_COLUMNS: int = 3
## Share of the rail's inner width the composition pass reserves for the grid's own
## breathing room when it caps a pocket, and that cap's floor. The composed tier
## derives its pocket extent with the same numbers, so the two passes agree on the
## slot size instead of undoing each other every pass.
const COMPOSED_SLOT_BUDGET: float = 12.0
const MIN_COMPOSED_SLOT: float = 24.0
const MIN_HEADER_WRAP_WIDTH: float = 48.0
## Left/top/right/bottom content margins of the header plate. Shared by the style
## and by the height the wrapped counts are budgeted with, so the measurement
## matches the box the text is drawn in.
const HEADER_CONTENT_MARGINS: Vector4 = Vector4(8.0, 4.0, 6.0, 4.0)

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
## Last wrapped-header measurement, so the per-frame overwritten check never
## re-lays-out the counts.
var _header_height_key: String = ""
var _header_height_value: float = 0.0

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

## Every metric this presenter applies, derived once from the same inputs the
## application uses. Detection compares the live nodes against these values, so a
## settled layout is not re-applied on every frame and the comparison can never
## disagree with what was written.
##
## On the composed dock tier the composition pass owns the rail's outer width and
## has already cleared the legacy interior pins, so the interiors fit the inner
## width it publishes (`composed_rail_logical`) instead of pinning a desktop one,
## and the header wraps its counts inside that width rather than forcing the rail
## wider than the authored physical mass. Lowering a pin is what the legacy
## `maxf` never allowed, which is why the rail used to grow at enlarged UI scales.
func _material_storage_metrics() -> Dictionary:
	var tight_compact: bool = bool(view.get_meta("tight_scale_layout", false))
	var compact: bool = bool(view.get_meta("compact_layout", false))
	var viewport_size: Vector2 = view.get_viewport_rect().size
	var composed_inner: float = float(view.get_meta("composed_rail_logical", 0.0))
	var composed: bool = bool(view.get_meta("full_hd_dock", false)) and composed_inner > 1.0
	var wide_support_rail: bool = compact and not tight_compact and viewport_size.x >= 1600.0
	# A wide desktop frame is the cache's support tier, whether the legacy compact
	# pass or the composed dock owns it: the dock draws the rail at its authored
	# 308 physical width with the desktop pocket extent, which is at or above the
	# support tier's own floor. The header therefore declares the tier the player
	# is actually shown, without re-sizing the pockets the dock already owns.
	var wide_support_tier: bool = wide_support_rail or (composed and viewport_size.x >= 1600.0)
	var columns: int = MATERIAL_COLUMNS
	var slot_size: Vector2 = Vector2(40.0, 56.0) if tight_compact else Vector2(70.0, 84.0) if wide_support_rail else Vector2(56.0, 74.0) if compact else Vector2(84.0, 96.0)
	var horizontal_separation: int = 4 if tight_compact else 6 if compact else 10
	var vertical_separation: int = 5 if tight_compact else 7 if compact else 10
	var rail_width: float = 136.0 if tight_compact else 240.0 if wide_support_rail else 180.0 if compact else 286.0
	var storage_width: float = rail_width
	var header_height: float = 34.0 if tight_compact else 48.0 if wide_support_rail else 42.0 if compact else 52.0
	var header_font_size: int = 11 if tight_compact else 13 if wide_support_rail else 12 if compact else 15
	var header_wrap: int = TextServer.AUTOWRAP_OFF
	var ui_scale: float = maxf(1.0, float(view.get_meta("persisted_ui_scale", 1.0)))
	var composed_rail: float = float(view.get_meta("composed_rail_physical", 0.0)) / ui_scale
	if composed:
		var slot_cap: float = maxf(
			MIN_COMPOSED_SLOT,
			(composed_inner - float(horizontal_separation) * 2.0 - COMPOSED_SLOT_BUDGET) / float(columns)
		)
		# Three pockets have to fit the rail's inner width, and the rail's width is
		# the axis that cannot grow. While the authored pocket already fits, it is
		# kept as authored - its height is not what the width constrains, and the
		# 100 percent composed rail holds it exactly as before. Once the width has to
		# give, the pocket takes the capped extent the composition pass applies.
		if slot_size.x > slot_cap:
			slot_size = Vector2(slot_cap, minf(slot_size.y, slot_cap))
		# The rail's own outer width belongs to the composition pass, so it is
		# re-stated at that width (releasing any legacy pin) and the interiors stay
		# inside the published inner width.
		rail_width = composed_rail if composed_rail > 1.0 else composed_inner
		storage_width = composed_inner
		header_wrap = TextServer.AUTOWRAP_WORD_SMART
	else:
		composed = false
	var occupied_slots: int = int(header.get_meta("occupied_slots", 0))
	var total_slots: int = maxi(1, int(header.get_meta("total_slots", grid.get_child_count())))
	var desired_ready_slots: int = mini(EMPTY_READY_SLOTS, maxi(0, total_slots - occupied_slots))
	var ready_slots: int = int(header.get_meta("ready_slots", desired_ready_slots))
	var sealed_slots: int = int(header.get_meta("sealed_slots", maxi(0, total_slots - occupied_slots - desired_ready_slots)))
	var header_text: String = _header_counts_text(occupied_slots, ready_slots, sealed_slots, tight_compact)
	var header_min_height: float = header_height
	if composed:
		header_min_height = _measured_header_height(header_text, header_font_size, storage_width, header_height)
	return {
		"composed": composed,
		"tight_compact": tight_compact,
		"compact": compact,
		"wide_support_rail": wide_support_rail,
		"wide_support_tier": wide_support_tier,
		"columns": columns,
		"slot": slot_size,
		"h_separation": horizontal_separation,
		"v_separation": vertical_separation,
		"rail_width": rail_width,
		"storage_width": storage_width,
		"header_text": header_text,
		"header_font_size": header_font_size,
		"header_min_height": header_min_height,
		"header_wrap": header_wrap,
	}

## The counts the header keeps: held, ready pockets and sealed reserve. One word
## plus the three numbers, on its own line so a narrow rail can wrap the counts
## without losing any of them.
func _header_counts_text(occupied_slots: int, ready_slots: int, sealed_slots: int, tight_compact: bool) -> String:
	return (
		"RELIQUARY\n%02d READY / %02d SEALED" % [ready_slots, sealed_slots]
		if tight_compact
		else "RELIQUARY\n%02d HELD  •  %02d READY  •  %02d SEALED" % [occupied_slots, ready_slots, sealed_slots]
	)

## Height the counts need once wrapped inside `width`, measured from the label's own
## font and the header plate's content margins. Measuring is what lets the counts
## wrap instead of being clipped or pushing the rail wider. Cached by input, so the
## per-frame check is a string compare rather than a text layout.
func _measured_header_height(text: String, font_size: int, width: float, minimum_height: float) -> float:
	var font: Font = header.get_theme_font("font")
	var key: String = "%s|%d|%.2f|%.2f|%d" % [
		text,
		font_size,
		width,
		minimum_height,
		font.get_instance_id() if font != null else 0,
	]
	if key == _header_height_key:
		return _header_height_value
	var height: float = minimum_height
	if font != null:
		var wrap_width: float = maxf(
			MIN_HEADER_WRAP_WIDTH,
			width - HEADER_CONTENT_MARGINS.x - HEADER_CONTENT_MARGINS.z
		)
		var wrapped: Vector2 = font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, wrap_width, font_size)
		height = maxf(minimum_height, ceilf(wrapped.y) + HEADER_CONTENT_MARGINS.y + HEADER_CONTENT_MARGINS.w)
	_header_height_key = key
	_header_height_value = height
	return height

## True while any pocket still carries an extent other than the one this tier
## applies. The composition pass caps the same pockets to the same derived
## extent, so a settled composed rail reports false in both pass orders.
func _slot_size_overwritten(slot_size: Vector2) -> bool:
	for child: Node in grid.get_children():
		var card: Control = child as Control
		if card == null:
			continue
		if not card.custom_minimum_size.is_equal_approx(slot_size):
			return true
	return false

func _on_process_frame() -> void:
	if _tearing_down or view == null or grid == null or header == null:
		return
	var metrics: Dictionary = _material_storage_metrics()
	var composed: bool = bool(metrics.composed)
	var rail_width: float = float(metrics.rail_width)
	var storage_width: float = float(metrics.storage_width)
	var header_overwritten: bool = (
		not bool(header.get_meta("reliquary_cache_hierarchy", false))
		or header.text != String(metrics.header_text)
		or header.autowrap_mode != int(metrics.header_wrap)
		or not is_equal_approx(header.custom_minimum_size.y, float(metrics.header_min_height))
	)
	var layout_overwritten: bool = (
		grid.columns != int(metrics.columns)
		or grid.get_theme_constant("h_separation") != int(metrics.h_separation)
		or _slot_size_overwritten(Vector2(metrics.slot))
	)
	var width_overwritten: bool
	if composed:
		# The composed application assigns these widths, so a different value is
		# stale; the legacy tiers only floor theirs, so only a smaller value is.
		width_overwritten = (
			not is_equal_approx(left_area.custom_minimum_size.x, rail_width)
			or not is_equal_approx(header.custom_minimum_size.x, storage_width)
			or not is_equal_approx(grid.custom_minimum_size.x, storage_width)
		)
	else:
		width_overwritten = (
			left_area.custom_minimum_size.x < rail_width - 0.01
			or header.custom_minimum_size.x < storage_width - 0.01
			or grid.custom_minimum_size.x < storage_width - 0.01
		)
	var shell: Panel = view.get_node_or_null(CACHE_SHELL_NAME) as Panel
	var shell_unstyled: bool = shell != null and not bool(shell.get_meta("physical_reliquary_shell", false))
	if header_overwritten or width_overwritten or layout_overwritten or shell_unstyled:
		_apply_material_storage_layout()

func _apply_material_storage_layout() -> void:
	if _tearing_down or view == null or grid == null or header == null:
		return
	var metrics: Dictionary = _material_storage_metrics()
	var composed: bool = bool(metrics.composed)
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
	var material_columns: int = int(metrics.columns)
	var slot_size: Vector2 = Vector2(metrics.slot)
	var horizontal_separation: int = int(metrics.h_separation)
	var vertical_separation: int = int(metrics.v_separation)
	var visible_rows: int = maxi(1, ceili(float(visible_cards) / float(material_columns)))
	grid.columns = material_columns
	var rail_width: float = float(metrics.rail_width)
	var storage_width: float = float(metrics.storage_width)
	if composed:
		# Assignment, not maxf: the composed rail's width belongs to the composition
		# pass, so an interior pin left over from a legacy tier has to be released
		# downwards as well as raised. Nothing here can widen the outer rail, since
		# these are the widths that pass published.
		left_area.custom_minimum_size.x = rail_width
		header.custom_minimum_size.x = storage_width
		grid.custom_minimum_size.x = storage_width
	else:
		left_area.custom_minimum_size.x = maxf(left_area.custom_minimum_size.x, rail_width)
		header.custom_minimum_size.x = maxf(header.custom_minimum_size.x, rail_width)
		grid.custom_minimum_size.x = maxf(grid.custom_minimum_size.x, rail_width)
	grid.add_theme_constant_override("h_separation", horizontal_separation)
	grid.add_theme_constant_override("v_separation", vertical_separation)
	var rows_height: float = float(visible_rows) * slot_size.y + float(maxi(0, visible_rows - 1) * vertical_separation)
	grid.custom_minimum_size.y = rows_height if composed else maxf(grid.custom_minimum_size.y, rows_height)
	grid.set_meta("material_cache_layout", true)
	grid.set_meta("visible_ready_slots", ready_slots_shown)
	grid.set_meta("visible_cache_slots", visible_cards)
	grid.set_meta("sealed_reserve_slots", maxi(0, total_slots - visible_cards))
	grid.set_meta("material_slot_size", slot_size)
	grid.set_meta("physical_compartment_shell", true)
	grid.set_meta("ready_slot_contract", EMPTY_READY_SLOTS)
	grid.set_meta("cache_scale_tier", "composed" if composed else "tight" if bool(metrics.tight_compact) else "wide_support" if bool(metrics.wide_support_rail) else "compact" if bool(metrics.compact) else "desktop")
	for card_node: Node in grid.get_children():
		var item_card: Control = card_node as Control
		if item_card != null and item_card.has_method("set_material_slot_presentation"):
			item_card.call("set_material_slot_presentation", slot_size)
	_item_grid_helper = _build_item_grid_helper()
	if router != null:
		router.set_item_grid(_item_grid_helper)
		for card_node: Node in grid.get_children():
			router.attach_card(card_node)
	_apply_material_header_style(occupied_slots, total_slots, ready_slots_shown, metrics)
	_apply_cache_shell_style(bool(metrics.tight_compact), bool(metrics.compact))
	grid.queue_sort()
	left_area.queue_sort()

func _apply_material_header_style(occupied_slots: int, total_slots: int, ready_slots: int, metrics: Dictionary) -> void:
	if header == null:
		return
	var tight_compact: bool = bool(metrics.tight_compact)
	var wide_support_tier: bool = bool(metrics.wide_support_tier)
	var sealed_slots: int = maxi(0, total_slots - occupied_slots - ready_slots)
	# One word and three counts: held, ready pockets and sealed reserve. The wide
	# variant used to read "EVIDENCE RELIQUARY CACHE / 00 HELD • 03 READY POCKETS •
	# 15 SEALED IN RESERVE" - eleven words to convey three numbers on a panel whose
	# shell art and slot colouring already say what it is.
	header.text = _header_counts_text(occupied_slots, ready_slots, sealed_slots, tight_compact)
	header.custom_minimum_size.y = float(metrics.header_min_height)
	header.add_theme_font_size_override("font_size", int(metrics.header_font_size))
	header.add_theme_color_override("font_color", Color(0.94, 0.83, 0.68, 1.0))
	header.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.92))
	header.add_theme_constant_override("outline_size", 2)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	header.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.clip_text = false
	# The counts wrap rather than being clipped or widening the rail; the composed
	# height above is the budget for what the wrap needs.
	header.autowrap_mode = int(metrics.header_wrap)
	var header_style: StyleBoxFlat = StyleBoxFlat.new()
	header_style.bg_color = Color(0.018, 0.013, 0.016, 0.98)
	header_style.border_color = Color(0.58, 0.43, 0.29, 0.94)
	header_style.border_width_left = 5
	header_style.border_width_top = 2
	header_style.border_width_right = 2
	header_style.border_width_bottom = 4
	header_style.content_margin_left = HEADER_CONTENT_MARGINS.x
	header_style.content_margin_top = HEADER_CONTENT_MARGINS.y
	header_style.content_margin_right = HEADER_CONTENT_MARGINS.z
	header_style.content_margin_bottom = HEADER_CONTENT_MARGINS.w
	header_style.shadow_color = Color(0.0, 0.0, 0.0, 0.82)
	header_style.shadow_size = 4
	header.add_theme_stylebox_override("normal", header_style)
	header.set_meta("material_cache_hierarchy", true)
	header.set_meta("reliquary_cache_hierarchy", true)
	header.set_meta("cache_visual_language", "evidence_reliquary")
	header.set_meta("ready_slots", ready_slots)
	header.set_meta("sealed_slots", sealed_slots)
	header.set_meta("header_hierarchy_lines", 2)
	header.set_meta("wide_support_rail", wide_support_tier)
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
