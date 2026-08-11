extends Node

const SMOKE_NAME: String = "ShopCardHoverSmoke"
const ShopPresenterLib: Script = preload("res://scripts/ui/shop/shop_presenter.gd")
const OUTPUT_DIR: String = "res://outputs/visual_iter/shop_card_hover_pass"

var _failures: Array[String] = []
var _presenter: ShopPresenter = null
var _host: VBoxContainer = null

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var window: Window = get_window()
	if window != null:
		window.size = Vector2i(1280, 720)
		window.content_scale_size = Vector2i(1280, 720)
	if not _autoloads_ready():
		_finish()
		return
	_prepare_populated_shop()
	_host = VBoxContainer.new()
	_host.custom_minimum_size = Vector2(860.0, 180.0)
	add_child(_host)
	var grid: GridContainer = GridContainer.new()
	_host.add_child(grid)
	_presenter = ShopPresenterLib.new()
	_presenter.configure(self, grid)
	await _settle_frames(4)

	var card: ShopCard = _first_shop_card()
	_expect(card != null, "first shop card missing")
	if card == null:
		_finish()
		return
	_expect(String(card.get_meta("tooltip_detail_state", "")) == "deferred", "shop card binding must defer tooltip-only unit previews")
	_expect(not bool(card.get("_tooltip_details_built")), "shop card binding must not build tooltip-only unit previews")
	_hover_card(card)
	card.emit_signal("mouse_entered")
	await _settle_frames(3)
	_expect(bool(card.get_meta("tooltip_suppressed_for_compact", false)), "compact shop card hover should suppress the detail panel")
	_expect(String(card.get_meta("tooltip_detail_state", "")) == "deferred", "compact hover must leave tooltip-only unit previews deferred")
	_expect(_tooltip_count() == 0, "compact shop card hover should not create a custom tooltip")
	card.set_compact_presentation(false)
	card.emit_signal("mouse_exited")
	card.emit_signal("mouse_entered")
	await _settle_frames(3)
	_expect(String(card.get_meta("tooltip_detail_state", "")) == "resolved", "shop card hover must resolve deferred tooltip detail")
	_expect(card.scale == Vector2.ONE, "shop hover should not scale cards inside the grid")
	_expect(String(card.tooltip_text) == "", "shop card should not use native tooltip_text")
	_expect(card.get_theme_stylebox("normal") is StyleBoxFlat, "shop card should retain its authored flat frame style")
	_expect(_tooltip_count() == 1, "shop hover should show one custom tooltip")
	var tooltip: Control = _first_tooltip()
	_expect(tooltip != null and _control_inside_viewport(tooltip), "shop tooltip should stay inside the viewport")
	if tooltip != null:
		var tooltip_layer: CanvasLayer = tooltip.get_parent() as CanvasLayer
		_expect(tooltip_layer != null and tooltip_layer.layer >= 400, "shop tooltip should live above shop/footer CanvasLayers")
		_expect(tooltip.get_theme_stylebox("panel") is StyleBoxTexture, "shop tooltip should use the generated panel asset")
		_expect(not tooltip.get_global_rect().intersects(card.get_global_rect()), "shop tooltip should not cover its source card")
		var card_grid: Control = card.get_parent() as Control
		_expect(card_grid == null or not tooltip.get_global_rect().intersects(card_grid.get_global_rect()), "shop tooltip should not cover the shop-card strip")
		_expect(_tooltip_contains(tooltip, "Attack Targeting:"), "shop tooltip should show attack targeting")
		_expect(_tooltip_contains(tooltip, "Ability Targeting:"), "shop tooltip should show ability targeting")
		_expect(not _tooltip_contains(tooltip, "Positioning:"), "shop tooltip should not prescribe positioning")
	_save_capture("01_shop_card_hover_tooltip.png")
	_move_hover(card)
	await _settle_frames(2)
	_expect(_tooltip_count() == 1, "shop hover motion should keep a single tooltip")

	var old_card_instance_id: int = card.get_instance_id()
	var reroll_result: Dictionary = Shop.reroll()
	_expect(bool(reroll_result.get("ok", false)), "shop reroll should succeed during hover cleanup test")
	_expect(_tooltip_count() == 0, "shop rebuild should synchronously clear tooltip from old hovered card")
	var rebound_card: ShopCard = _first_shop_card_excluding(old_card_instance_id)
	_expect(rebound_card != null, "shop card missing immediately after reroll binding")
	if rebound_card != null:
		_expect(String(rebound_card.get_meta("tooltip_detail_state", "")) == "deferred", "reroll binding must keep replacement-card tooltip detail deferred")
		_expect(not bool(rebound_card.get("_tooltip_details_built")), "reroll binding must not build replacement-card tooltip detail")
	await _settle_frames(8)
	_expect(_tooltip_count() <= 1, "shop rebuild should never leave stacked old and new tooltips")
	var rebuilt_tooltip: Control = _first_tooltip()
	if rebuilt_tooltip != null:
		_expect(int(rebuilt_tooltip.get_meta("source_card_instance_id", 0)) != old_card_instance_id, "shop rebuild should clear tooltip owned by the old hovered card")

	var next_card: ShopCard = _first_shop_card()
	_expect(next_card != null, "shop card missing after reroll")
	if next_card != null:
		_hover_card(next_card)
		await _settle_frames(2)
		_unhover_card(next_card)
		await _settle_frames(4)
		_expect(_tooltip_count() == 0, "shop hover exit should clear tooltip")
		_expect(next_card.scale == Vector2.ONE, "shop hover exit should keep card scale stable")
	_finish()

func _autoloads_ready() -> bool:
	var ok: bool = true
	if get_tree().root.get_node_or_null("/root/GameState") == null:
		_fail("GameState autoload missing")
		ok = false
	if get_tree().root.get_node_or_null("/root/Economy") == null:
		_fail("Economy autoload missing")
		ok = false
	if get_tree().root.get_node_or_null("/root/Shop") == null:
		_fail("Shop autoload missing")
		ok = false
	if get_tree().root.get_node_or_null("/root/Roster") == null:
		_fail("Roster autoload missing")
		ok = false
	return ok

func _prepare_populated_shop() -> void:
	Economy.reset_run()
	Shop.reset_run()
	if Roster.has_method("reset"):
		Roster.reset()
	GameState.set_chapter_and_stage(1, 2)
	GameState.set_phase(GameState.GamePhase.PREVIEW)
	_set_gold(20)
	Shop.reroll()

func _set_gold(value: int) -> void:
	var delta: int = int(value) - int(Economy.gold)
	if delta != 0:
		Economy.add_gold(delta)

func _first_shop_card() -> ShopCard:
	return _first_shop_card_excluding(0)

func _first_shop_card_excluding(excluded_instance_id: int) -> ShopCard:
	if _host == null:
		return null
	var cards: Array[Node] = _host.find_children("*", "ShopCard", true, false)
	for node: Node in cards:
		var card: ShopCard = node as ShopCard
		if card != null and card.get_instance_id() != excluded_instance_id and String(card.offer_id).strip_edges() != "":
			return card
	return null

func _hover_card(card: ShopCard) -> void:
	var center: Vector2 = card.get_global_rect().get_center()
	Input.warp_mouse(center)
	var event: InputEventMouseMotion = InputEventMouseMotion.new()
	event.position = center
	event.global_position = center
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _move_hover(card: ShopCard) -> void:
	var position: Vector2 = card.get_global_rect().get_center() + Vector2(20.0, 12.0)
	Input.warp_mouse(position)
	var event: InputEventMouseMotion = InputEventMouseMotion.new()
	event.position = position
	event.global_position = position
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _unhover_card(card: ShopCard) -> void:
	card.emit_signal("mouse_exited")

func _tooltip_count() -> int:
	var count: int = 0
	for node: Node in get_tree().root.find_children("ShopCardTooltip", "PanelContainer", true, false):
		if node is Control and is_instance_valid(node):
			count += 1
	return count

func _first_tooltip() -> Control:
	for node: Node in get_tree().root.find_children("ShopCardTooltip", "PanelContainer", true, false):
		var control: Control = node as Control
		if control != null and is_instance_valid(control):
			return control
	return null

func _control_inside_viewport(control: Control) -> bool:
	if control == null:
		return false
	var rect: Rect2 = control.get_global_rect()
	var viewport_rect: Rect2 = get_viewport().get_visible_rect()
	if viewport_rect.size.x <= 4.0 or viewport_rect.size.y <= 4.0:
		viewport_rect = Rect2(Vector2.ZERO, Vector2(1280.0, 720.0))
	return rect.position.x >= viewport_rect.position.x and rect.position.y >= viewport_rect.position.y and rect.end.x <= viewport_rect.end.x and rect.end.y <= viewport_rect.end.y

func _tooltip_contains(control: Control, needle: String) -> bool:
	if control == null:
		return false
	for node: Node in control.find_children("*", "Label", true, false):
		var label: Label = node as Label
		if label != null and String(label.text).contains(needle):
			return true
	return false

func _settle_frames(count: int) -> void:
	for _frame_index: int in range(count):
		await get_tree().process_frame

func _save_capture(filename: String) -> void:
	var display_name: String = DisplayServer.get_name().to_lower()
	var driver_name: String = RenderingServer.get_current_rendering_driver_name().to_lower()
	if display_name == "headless" or display_name == "server" or display_name == "dummy" or driver_name.contains("dummy"):
		print("%s: skipped %s because framebuffer capture is unavailable" % [SMOKE_NAME, filename])
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var texture: ViewportTexture = get_viewport().get_texture()
	if texture == null or not texture.get_rid().is_valid():
		push_error("%s: viewport unavailable for %s" % [SMOKE_NAME, filename])
		return
	var image: Image = texture.get_image()
	if image == null or image.is_empty():
		push_error("%s: image unavailable for %s" % [SMOKE_NAME, filename])
		return
	var path: String = "%s/%s" % [OUTPUT_DIR, filename]
	var error: Error = image.save_png(path)
	if error != OK:
		push_error("%s: save failed %s error=%d" % [SMOKE_NAME, path, int(error)])
		return
	print("%s: saved %s" % [SMOKE_NAME, ProjectSettings.globalize_path(path)])

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)

func _fail(message: String) -> void:
	_failures.append(message)

func _finish() -> void:
	if _presenter != null:
		_presenter.teardown()
		_presenter = null
	if _host != null and is_instance_valid(_host):
		remove_child(_host)
		_host.free()
		_host = null
	for node: Node in get_tree().root.find_children("ShopCardTooltip", "PanelContainer", true, false):
		if node != null and is_instance_valid(node):
			node.queue_free()
	if get_tree().root.get_node_or_null("/root/Economy") != null:
		Economy.reset_run()
	if get_tree().root.get_node_or_null("/root/Shop") != null:
		Shop.reset_run()
	if get_tree().root.get_node_or_null("/root/Roster") != null and Roster.has_method("reset"):
		Roster.reset()
	if not _failures.is_empty():
		for failure: String in _failures:
			push_error(SMOKE_NAME + ": " + failure)
		get_tree().quit(1)
		return
	print(SMOKE_NAME + ": OK")
	get_tree().quit(0)
