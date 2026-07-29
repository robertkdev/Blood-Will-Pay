extends Node

const SMOKE_NAME: String = "ShopCardHoverSmoke"
const ShopPresenterLib: Script = preload("res://scripts/ui/shop/shop_presenter.gd")

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
	_hover_card(card)
	await _settle_frames(3)
	_expect(card.scale == Vector2.ONE, "shop hover should not scale cards inside the grid")
	_expect(String(card.tooltip_text) == "", "shop card should not use native tooltip_text")
	_expect(card.get_theme_stylebox("normal") is StyleBoxTexture, "shop card should use the generated card asset")
	_expect(_tooltip_count() == 1, "shop hover should show one custom tooltip")
	var tooltip: Control = _first_tooltip()
	_expect(tooltip != null and _control_inside_viewport(tooltip), "shop tooltip should stay inside the viewport")
	if tooltip != null:
		_expect(tooltip.get_theme_stylebox("panel") is StyleBoxTexture, "shop tooltip should use the generated panel asset")
		_expect(_tooltip_contains(tooltip, "Attack Targeting:"), "shop tooltip should show attack targeting")
		_expect(_tooltip_contains(tooltip, "Ability Targeting:"), "shop tooltip should show ability targeting")
		_expect(not _tooltip_contains(tooltip, "Positioning:"), "shop tooltip should not prescribe positioning")
	_move_hover(card)
	await _settle_frames(2)
	_expect(_tooltip_count() == 1, "shop hover motion should keep a single tooltip")

	var reroll_result: Dictionary = Shop.reroll()
	_expect(bool(reroll_result.get("ok", false)), "shop reroll should succeed during hover cleanup test")
	await _settle_frames(8)
	_expect(_tooltip_count() == 0, "shop rebuild should clear tooltip from old hovered card")

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
	if _host == null:
		return null
	var cards: Array[Node] = _host.find_children("*", "ShopCard", true, false)
	for node: Node in cards:
		var card: ShopCard = node as ShopCard
		if card != null and String(card.offer_id).strip_edges() != "":
			return card
	return null

func _hover_card(card: ShopCard) -> void:
	var center: Vector2 = card.get_global_rect().get_center()
	Input.warp_mouse(center)
	card.emit_signal("mouse_entered")
	var event: InputEventMouseMotion = InputEventMouseMotion.new()
	event.position = center
	event.global_position = center
	card.emit_signal("gui_input", event)

func _move_hover(card: ShopCard) -> void:
	var position: Vector2 = card.get_global_rect().get_center() + Vector2(20.0, 12.0)
	Input.warp_mouse(position)
	var event: InputEventMouseMotion = InputEventMouseMotion.new()
	event.position = position
	event.global_position = position
	card.emit_signal("gui_input", event)

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
