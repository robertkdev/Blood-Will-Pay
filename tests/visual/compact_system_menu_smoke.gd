extends Node

const MAIN_SCENE: PackedScene = preload("res://scenes/Main.tscn")
const SHOP_CARD_SCENE: PackedScene = preload("res://scenes/ui/shop/ShopCard.tscn")

var _failures: Array[String] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_run")

func _run() -> void:
	var window: Window = get_window()
	if window != null:
		window.size = Vector2i(1280, 760)
		window.content_scale_size = Vector2i(1280, 720)
	var main: Node = MAIN_SCENE.instantiate()
	add_child(main)
	await _settle_frames(6)
	var title_menu: Control = main.get_node_or_null("TitleMenu") as Control
	var title_page: Control = main.get("_title_page") as Control
	if title_menu != null:
		title_menu.visible = false
	if title_page != null:
		title_page.visible = false
	main.call("_open_system_menu")
	await _settle_frames(6)
	var overlay: Control = main.get("_system_overlay") as Control
	var panel: PanelContainer = overlay.find_child("Panel", true, false) as PanelContainer if overlay != null else null
	var assembly: Control = panel.find_child("SystemAssemblyLayer", true, false) as Control if panel != null else null
	var scars: Label = panel.find_child("PanelScars", true, false) as Label if panel != null else null
	_expect(overlay != null and overlay.visible, "compact System menu did not open")
	_expect(panel != null and panel.clip_contents, "compact System panel must clip decoration to its calm interior")
	_expect(panel != null and String(panel.get_meta("decoration_containment", "")) == "calm_panel_interior", "compact System panel missing containment contract")
	_expect(assembly != null and assembly.clip_contents, "compact System assembly marks must be clipped")
	_expect(assembly != null and String(assembly.get_meta("decoration_containment", "")) == "panel_rect", "compact System assembly layer missing panel-bound contract")
	_expect(scars != null and bool(scars.get_meta("contained_by_panel", false)), "compact System X marks must declare panel containment")
	if panel != null:
		_expect(get_viewport().get_visible_rect().grow(1.0).encloses(panel.get_global_rect()), "compact System panel escaped the viewport")
	await _verify_compact_shop_detail_contract()
	get_tree().paused = false
	remove_child(main)
	main.free()
	await get_tree().process_frame
	if _failures.is_empty():
		print("CompactSystemMenuSmoke: OK")
		get_tree().quit(0)
		return
	for failure: String in _failures:
		push_error("CompactSystemMenuSmoke: " + failure)
	get_tree().quit(1)

func _verify_compact_shop_detail_contract() -> void:
	var shop_grid: GridContainer = GridContainer.new()
	shop_grid.name = "ShopGrid"
	shop_grid.columns = 5
	shop_grid.position = Vector2(80.0, 620.0)
	shop_grid.size = Vector2(1120.0, 62.0)
	shop_grid.custom_minimum_size = shop_grid.size
	add_child(shop_grid)
	var source_card: Button = null
	for card_index: int in range(5):
		var card: Button = SHOP_CARD_SCENE.instantiate() as Button
		card.custom_minimum_size = Vector2(216.0, 62.0)
		shop_grid.add_child(card)
		card.call("set_compact_presentation", true, true)
		card.call("set_data", {"id": "bonko", "name": "Offer %d" % card_index, "price": 1})
		if card_index == 4:
			source_card = card
	await _settle_frames(3)
	if source_card != null:
		source_card.call("_show_tooltip")
	await _settle_frames(2)
	var tooltip: PanelContainer = get_tree().root.find_child("ShopCardTooltip", true, false) as PanelContainer
	_expect(tooltip != null, "compact shop hover should expose a pinned detail treatment")
	if tooltip != null and source_card != null:
		_expect(bool(tooltip.get_meta("source_card_remains_visible", false)), "compact shop detail should keep its source card visible")
		_expect(String(tooltip.get_meta("opposite_side_anchor", "")) == "left_of_source", "rightmost compact shop source should anchor detail on the opposite side")
		_expect(String(tooltip.get_meta("information_access", "")) == "vertical_scroll_complete", "compact shop detail should keep the full record scroll-accessible")
		var width_ratio: float = float(tooltip.get_meta("shop_band_width_ratio", 0.0))
		_expect(width_ratio >= 0.40 and width_ratio <= 0.60, "compact shop detail should occupy roughly half of ShopGrid, got %.2f" % width_ratio)
		_expect(shop_grid.get_global_rect().grow(1.0).encloses(tooltip.get_global_rect()), "compact shop detail should remain inside ShopGrid")
	if source_card != null:
		source_card.call("_clear_tooltip")
	remove_child(shop_grid)
	shop_grid.free()

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

func _settle_frames(count: int) -> void:
	for _frame_index: int in range(count):
		await get_tree().process_frame
