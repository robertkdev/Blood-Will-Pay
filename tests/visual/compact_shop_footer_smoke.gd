extends Node

const SMOKE_NAME: String = "CompactShopFooterSmoke"
const COMBAT_VIEW_SCENE: PackedScene = preload("res://scenes/CombatView.tscn")
const SHOP_CARD_SCENE: PackedScene = preload("res://scenes/ui/shop/ShopCard.tscn")
const VIEWPORT_SIZE: Vector2i = Vector2i(1280, 720)

var _view: Control = null
var _viewport: SubViewport = null
var _fixture_panel: ShopPanel = null
var _failures: Array[String] = []

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	DisplayServer.window_set_size(VIEWPORT_SIZE)
	var window: Window = get_window()
	if window != null:
		window.size = VIEWPORT_SIZE
		window.content_scale_size = VIEWPORT_SIZE
	if GameState.has_method("reset_run"):
		GameState.reset_run()
	GameState.set_phase(GameState.GamePhase.PREVIEW)
	if Economy.has_method("reset_run"):
		Economy.reset_run()
	if Shop.has_method("reset_run"):
		Shop.reset_run()
	_viewport = SubViewport.new()
	_viewport.size = VIEWPORT_SIZE
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)
	_view = COMBAT_VIEW_SCENE.instantiate() as Control
	if _view == null:
		_fail("CombatView instantiate failed")
		_finish()
		return
	_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_viewport.add_child(_view)
	await _settle_frames(8)
	_build_compact_footer_fixture()
	await _settle_frames(16)
	var live_slider: HSlider = _view.get("bet_slider") as HSlider
	var live_bet_row: HBoxContainer = live_slider.get_parent() as HBoxContainer if live_slider != null else null
	var live_command_bar: HBoxContainer = live_bet_row.get_parent() as HBoxContainer if live_bet_row != null else null
	if live_command_bar != null:
		live_command_bar.visible = true
		_view.call("_apply_action_bar_layout", live_command_bar, true)
	if live_bet_row != null:
		live_bet_row.visible = true
		_view.call("_apply_bet_row_layout", live_bet_row, true)
	await _settle_frames(2)
	_assert_footer_layout()
	_finish()

func _build_compact_footer_fixture() -> void:
	var shop_grid: GridContainer = _view.get("shop_grid") as GridContainer
	if shop_grid == null:
		_fail("shop grid missing")
		return
	for child: Node in shop_grid.get_children():
		shop_grid.remove_child(child)
		child.free()
	_fixture_panel = ShopPanel.new()
	_fixture_panel.configure(shop_grid, 5)
	_fixture_panel.set_empty_state("LEDGER", "Reroll to reveal", false)
	_fixture_panel.set_offers([])
	var first_placeholder: Node = shop_grid.get_child(0) if shop_grid.get_child_count() > 0 else null
	if first_placeholder != null:
		shop_grid.remove_child(first_placeholder)
		first_placeholder.free()
	var card: Control = SHOP_CARD_SCENE.instantiate() as Control
	if card != null:
		shop_grid.add_child(card)
	var controller: Variant = _view.get("controller")
	if controller != null:
		controller.call("_sync_bottom_combat_visibility", true)
	_view.call("_apply_responsive_layout")

func _assert_footer_layout() -> void:
	var viewport_rect: Rect2 = _view.get_viewport().get_visible_rect()
	var shop_grid: GridContainer = _view.get("shop_grid") as GridContainer
	_expect_inside(shop_grid, viewport_rect, "shop grid")
	var first_card_top: float = INF
	if shop_grid != null:
		for child: Node in shop_grid.get_children():
			var card: Control = child as Control
			if card == null or not card.visible:
				continue
			_expect_inside(card, viewport_rect, "shop card %s" % String(card.name))
			_expect(card.size.y <= 96.0, "compact shop card exceeded height budget: %s" % str(card.get_global_rect()))
			first_card_top = min(first_card_top, card.get_global_rect().position.y)
	var bet_slider: HSlider = _view.get("bet_slider") as HSlider
	var bet_value: Label = _view.get("bet_value") as Label
	var bet_row: HBoxContainer = bet_slider.get_parent() as HBoxContainer if bet_slider != null else null
	var command_bar: HBoxContainer = bet_row.get_parent() as HBoxContainer if bet_row != null else null
	_expect(command_bar != null and command_bar.visible, "shop command bar should be visible")
	_expect_inside(command_bar, viewport_rect, "shop command bar")
	_expect_inside(bet_value, viewport_rect, "bet value")
	if command_bar != null and first_card_top < INF:
		_expect(command_bar.get_global_rect().end.y <= first_card_top + 1.0, "shop command bar overlaps compact cards")
	if bet_slider != null and bet_value != null:
		_expect(bet_slider.custom_minimum_size.x <= 124.0, "compact bet slider width budget was not applied")
		_expect(bet_value.custom_minimum_size.x <= 28.0, "compact bet value width budget was not applied")
		_expect(bet_value.get_theme_stylebox("normal") is StyleBoxFlat, "compact bet value should use a framed badge")

func _expect_inside(control: Control, bounds: Rect2, label: String) -> void:
	_expect(control != null, label + " missing")
	if control == null:
		return
	var rect: Rect2 = control.get_global_rect()
	_expect(rect.position.x >= bounds.position.x - 1.0, "%s left edge escaped viewport: %s" % [label, str(rect)])
	_expect(rect.position.y >= bounds.position.y - 1.0, "%s top edge escaped viewport: %s" % [label, str(rect)])
	_expect(rect.end.x <= bounds.end.x + 1.0, "%s right edge escaped viewport: %s" % [label, str(rect)])
	_expect(rect.end.y <= bounds.end.y + 1.0, "%s bottom edge escaped viewport: %s" % [label, str(rect)])

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)

func _fail(message: String) -> void:
	if not _failures.has(message):
		_failures.append(message)

func _settle_frames(count: int) -> void:
	for _index: int in range(count):
		await get_tree().process_frame

func _finish() -> void:
	if _view != null and is_instance_valid(_view) and _view.has_method("_teardown"):
		_view.call("_teardown")
	if _view != null and is_instance_valid(_view):
		var parent: Node = _view.get_parent()
		if parent != null:
			parent.remove_child(_view)
		_view.free()
	_view = null
	if _viewport != null and is_instance_valid(_viewport):
		remove_child(_viewport)
		_viewport.free()
	_viewport = null
	_fixture_panel = null
	if _failures.is_empty():
		print(SMOKE_NAME + ": OK")
		get_tree().quit(0)
		return
	for failure: String in _failures:
		push_error(SMOKE_NAME + ": " + failure)
	get_tree().quit(1)
