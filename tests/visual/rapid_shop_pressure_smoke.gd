extends Node

const MAIN_SCENE: PackedScene = preload("res://scenes/Main.tscn")
const AbilityCatalog: Script = preload("res://scripts/game/abilities/ability_catalog.gd")
const IdentityRegistry: Script = preload("res://scripts/game/identity/identity_registry.gd")
const ItemCatalog: Script = preload("res://scripts/game/items/item_catalog.gd")
const RoleLibrary: Script = preload("res://scripts/game/units/role_library.gd")
const ShopConfig: Script = preload("res://scripts/game/shop/shop_config.gd")
const StageRuleRunner: Script = preload("res://scripts/game/progression/stage_rule_runner.gd")
const TraitCompiler: Script = preload("res://scripts/game/traits/trait_compiler.gd")
const UnitFactory: Script = preload("res://scripts/unit_factory.gd")

const DEFAULT_SMOKE_NAME: String = "RapidShopPressureSmoke"
const TARGET_AUDIT_GOLD: int = 20

var _main: Control = null
var _failures: Array[String] = []
var _shop_errors: Array[Dictionary] = []
var _previous_time_scale: float = 1.0
var _previous_suppress_validation_warnings: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_run")

func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	var window: Window = get_window()
	if window != null:
		window.size = Vector2i(1920, 1080)
		window.content_scale_size = Vector2i(1920, 1080)
	_previous_time_scale = Engine.time_scale
	_previous_suppress_validation_warnings = bool(UnitFactory.get("suppress_validation_warnings"))
	UnitFactory.set("suppress_validation_warnings", true)
	Engine.time_scale = _flow_time_scale()
	if _has_autoload("Shop") and not Shop.is_connected("error", Callable(self, "_on_shop_error")):
		Shop.error.connect(_on_shop_error)
	await _run_flow()
	_finish()

func _run_flow() -> void:
	_main = MAIN_SCENE.instantiate() as Control
	if _main == null:
		_expect(false, "Main scene did not instantiate as Control")
		return
	_main.set_anchors_preset(Control.PRESET_FULL_RECT)
	_main.offset_left = 0.0
	_main.offset_top = 0.0
	_main.offset_right = 0.0
	_main.offset_bottom = 0.0
	get_tree().root.add_child(_main)
	await _settle_frames(4)

	await _ensure_unit_select()
	await _select_starter("bonko")
	await _settle_frames(4)
	_prepare_opener_planning()
	_set_bet_to_max()
	await _press_continue(true, "Bonko forced first fight")
	var shop_ready: bool = await _wait_for_shop_after_win(_first_shop_timeout_seconds())
	_expect(shop_ready, "post-first-fight shop did not open")
	if not shop_ready:
		return

	_prepare_rapid_shop_planning()
	_grant_audit_gold()
	var rerolls_used: int = await _reroll_until_unique_cost1_shop(30)
	_expect(rerolls_used <= 30, "could not prepare a unique cost-1 shop")
	await _settle_frames(8)

	var cards: Array[ShopCard] = _visible_buyable_cards()
	_expect(cards.size() == int(ShopConfig.SLOT_COUNT), "expected %d buyable shop cards, got %d" % [int(ShopConfig.SLOT_COUNT), cards.size()])
	if cards.is_empty():
		return
	var expected_ids: Array[String] = []
	var expected_cost: int = 0
	for card: ShopCard in cards:
		var offer: ShopOffer = _offer_for_slot(int(card.slot_index))
		_expect(offer != null, "shop card slot %d had no backing offer" % int(card.slot_index))
		if offer != null:
			expected_ids.append(String(offer.id))
			expected_cost += int(offer.cost)

	var gold_before: int = int(Economy.gold)
	var bench_before_count: int = _bench_ids().size()
	var board_before_count: int = _board_ids().size()
	var error_start: int = _shop_errors.size()
	await _purchase_cards(cards)
	await _settle_frames(10)

	var bench_after: Array[String] = _bench_ids()
	_expect(int(Economy.gold) == gold_before - expected_cost, "rapid purchases spent %d gold, expected %d" % [gold_before - int(Economy.gold), expected_cost])
	_expect(bench_after.size() == bench_before_count + expected_ids.size(), "rapid purchases should add %d bench units; bench=%s" % [expected_ids.size(), JSON.stringify(bench_after)])
	for expected_id: String in expected_ids:
		_expect(bench_after.has(expected_id), "bench missing purchased unit %s after rapid purchases" % expected_id)
	_expect(_blank_offer_count() == expected_ids.size(), "rapid purchases should leave %d blank offers, got %d" % [expected_ids.size(), _blank_offer_count()])
	_expect(_sold_placeholder_count() == expected_ids.size(), "rapid purchases should render %d sold placeholders, got %d" % [expected_ids.size(), _sold_placeholder_count()])
	_expect(_label_count_in_shop_grid("SOLD") == expected_ids.size(), "rapid purchases should render SOLD copy on every purchased slot")
	_expect(_label_count_in_shop_grid("On bench") == expected_ids.size(), "rapid purchases should render On bench copy on every purchased slot")
	_expect(_shop_errors_since(error_start).is_empty(), "rapid purchases emitted shop errors: %s" % JSON.stringify(_shop_errors_since(error_start)))
	_expect(_phase_name() == "PREVIEW" and not bool(Economy.combat_active), "rapid purchases moved game out of preview phase")
	_expect(_continue_button_text() == "Start Battle", "rapid purchases should leave Start Battle available, got %s" % _continue_button_text())
	_expect(_deploy_prompt_visible(), "rapid purchases should leave deployment guidance visible")
	await _after_rapid_purchase_checkpoint(expected_ids)

	var available_board_slots: int = max(0, int(Roster.max_team_size) - board_before_count) if _has_autoload("Roster") else expected_ids.size()
	var expected_deployed_count: int = min(expected_ids.size(), available_board_slots)
	var expected_bench_count: int = expected_ids.size() - expected_deployed_count
	var deployed_count: int = await _deploy_all_bench_units()
	var board_after_count: int = _board_ids().size()
	_expect(_bench_ids().size() == expected_bench_count, "rapid deploy should leave %d capacity-blocked bench units, got %s" % [expected_bench_count, JSON.stringify(_bench_ids())])
	_expect(deployed_count == expected_deployed_count, "rapid deploy moved %d units, expected %d under board cap=%d" % [deployed_count, expected_deployed_count, int(Roster.max_team_size)])
	_expect(board_after_count == board_before_count + expected_deployed_count, "rapid deploy board size should grow by %d, before=%d after=%d" % [expected_deployed_count, board_before_count, board_after_count])
	await _after_rapid_deploy_checkpoint(expected_ids)

	await _press_continue(false, "post-rapid-burst fight")
	var resolved: bool = await _wait_for_preview_or_loss(_post_burst_timeout_seconds())
	_expect(resolved, "post-rapid-burst fight did not resolve")

func _smoke_name() -> String:
	return DEFAULT_SMOKE_NAME

func _flow_time_scale() -> float:
	return 8.0

func _prepare_opener_planning() -> void:
	_set_planning_timer_safe(9999.0)

func _prepare_rapid_shop_planning() -> void:
	_set_planning_timer_safe(9999.0)

func _first_shop_timeout_seconds() -> float:
	return 30.0

func _post_burst_timeout_seconds() -> float:
	return 35.0

func _use_viewport_shop_clicks() -> bool:
	return false

func _shop_click_settle_frames() -> int:
	return 1

func _after_rapid_purchase_checkpoint(_expected_ids: Array[String]) -> void:
	await get_tree().process_frame

func _after_rapid_deploy_checkpoint(_expected_ids: Array[String]) -> void:
	await get_tree().process_frame

func _purchase_cards(cards: Array[ShopCard]) -> void:
	if _use_viewport_shop_clicks():
		var click_points: Array[Vector2] = []
		for card: ShopCard in cards:
			if is_instance_valid(card) and not card.disabled:
				click_points.append(_visible_click_point(card))
		for click_point: Vector2 in click_points:
			await _mouse_click(click_point)
			await _settle_frames(_shop_click_settle_frames())
		return
	for card: ShopCard in cards:
		if is_instance_valid(card) and not card.disabled:
			card.emit_signal("pressed")

func _grant_audit_gold() -> void:
	var delta: int = TARGET_AUDIT_GOLD - int(Economy.gold)
	if delta > 0:
		Economy.add_gold(delta)

func _deploy_all_bench_units() -> int:
	var moved_count: int = 0
	var guard: int = 0
	while not _bench_ids().is_empty() and guard < 12:
		var moved: bool = await _drag_first_bench_unit_to_board()
		await _settle_frames(4)
		if not moved:
			return moved_count
		moved_count += 1
		guard += 1
	return moved_count

func _on_shop_error(code: String, context: Dictionary) -> void:
	_shop_errors.append({
		"code": code,
		"context": context.duplicate(true),
		"phase": _phase_name(),
		"stage": int(GameState.stage) if _has_autoload("GameState") else -1,
		"stage_in_chapter": int(GameState.stage_in_chapter) if _has_autoload("GameState") else -1,
		"gold": int(Economy.gold) if _has_autoload("Economy") else -1,
		"level": int(Shop.get_level()) if _has_autoload("Shop") else -1,
	})

func _ensure_unit_select() -> void:
	if _node_visible("TitleMenu"):
		var start: Button = _main.get_node_or_null("TitleMenu/Center/VBox/StartButton") as Button
		if start == null:
			_expect(false, "title start button missing")
			return
		start.emit_signal("pressed")
		await _settle_frames(4)
	_expect(_node_visible("UnitSelect"), "unit select was not visible")

func _select_starter(unit_id: String) -> void:
	var select: UnitSelect = _main.get_node_or_null("UnitSelect") as UnitSelect
	if select == null:
		_expect(false, "unit select node missing")
		return
	var button: Button = select.buttons_by_id.get(unit_id, null) as Button
	if button == null:
		_expect(false, "starter button missing for %s" % unit_id)
		return
	button.emit_signal("pressed")
	await _settle_frames(2)
	var start: Button = select.get_node_or_null("Center/HBox/Right/StartButton") as Button
	if start == null:
		_expect(false, "unit select start button missing")
		return
	_expect(not start.disabled, "unit select start button did not enable for %s" % unit_id)
	if not start.disabled:
		start.emit_signal("pressed")

func _press_continue(expect_forced: bool, label: String) -> void:
	var button: Button = _main.find_child("ContinueButton", true, false) as Button
	if button == null:
		_expect(false, "%s continue button missing" % label)
		return
	var expected: String = "Start Opening Fight" if expect_forced else "Start Battle"
	_expect(button.text == expected, "%s should show %s, got %s" % [label, expected, button.text])
	_expect(not button.disabled, "%s continue button disabled" % label)
	if not button.disabled:
		button.emit_signal("pressed")

func _wait_for_shop_after_win(timeout_seconds: float) -> bool:
	var deadline: int = Time.get_ticks_msec() + int(timeout_seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		if get_tree().root.get_node_or_null("LossOverlayLayer") != null:
			return false
		if GameState.phase == GameState.GamePhase.PREVIEW and int(GameState.stage_in_chapter) >= 2:
			if Shop.state != null and Shop.state.offers.size() == int(ShopConfig.SLOT_COUNT):
				return true
	return false

func _wait_for_preview_or_loss(timeout_seconds: float) -> bool:
	var deadline: int = Time.get_ticks_msec() + int(timeout_seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		if get_tree().root.get_node_or_null("LossOverlayLayer") != null:
			return true
		if GameState.phase == GameState.GamePhase.PREVIEW and not Economy.combat_active:
			return true
	return false

func _reroll_until_unique_cost1_shop(max_rerolls: int) -> int:
	for attempt: int in range(max(1, max_rerolls + 1)):
		if _offers_are_nonempty_unique_cost1():
			return attempt
		var result: Dictionary = Shop.reroll()
		if not bool(result.get("ok", false)):
			_expect(false, "audit prep reroll failed: %s" % JSON.stringify(result))
			return attempt
		await _settle_frames(5)
	return max_rerolls + 1

func _offers_are_nonempty_unique_cost1() -> bool:
	if Shop.state == null or Shop.state.offers.size() != int(ShopConfig.SLOT_COUNT):
		return false
	var seen: Dictionary[String, bool] = {}
	for raw_offer: Variant in Shop.state.offers:
		var offer: ShopOffer = raw_offer as ShopOffer
		if offer == null or String(offer.id) == "" or int(offer.cost) != 1:
			return false
		if seen.has(String(offer.id)):
			return false
		seen[String(offer.id)] = true
	return true

func _visible_buyable_cards() -> Array[ShopCard]:
	var out: Array[ShopCard] = []
	var grid: GridContainer = _main.find_child("ShopGrid", true, false) as GridContainer
	if grid == null:
		return out
	for child: Node in grid.get_children():
		var card: ShopCard = child as ShopCard
		if card == null or card.disabled:
			continue
		var offer: ShopOffer = _offer_for_slot(int(card.slot_index))
		if offer != null and String(offer.id) != "":
			out.append(card)
	return out

func _offer_for_slot(slot_index: int) -> ShopOffer:
	if not _has_autoload("Shop") or Shop.state == null:
		return null
	if slot_index < 0 or slot_index >= Shop.state.offers.size():
		return null
	return Shop.state.offers[slot_index] as ShopOffer

func _blank_offer_count() -> int:
	var count: int = 0
	if not _has_autoload("Shop") or Shop.state == null:
		return 0
	for raw_offer: Variant in Shop.state.offers:
		var offer: ShopOffer = raw_offer as ShopOffer
		if offer != null and String(offer.id) == "":
			count += 1
	return count

func _sold_placeholder_count() -> int:
	var count: int = 0
	var grid: GridContainer = _main.find_child("ShopGrid", true, false) as GridContainer
	if grid == null:
		return 0
	for child: Node in grid.get_children():
		var panel: PanelContainer = child as PanelContainer
		if panel != null and String(panel.tooltip_text).contains("Unit is on your bench"):
			count += 1
	return count

func _label_count_in_shop_grid(text: String) -> int:
	var grid: GridContainer = _main.find_child("ShopGrid", true, false) as GridContainer
	if grid == null:
		return 0
	return _label_count_with_text(grid, text)

func _label_count_with_text(root: Node, text: String) -> int:
	var count: int = 0
	if root is Label and String((root as Label).text) == text:
		count += 1
	for child: Node in root.get_children():
		count += _label_count_with_text(child, text)
	return count

func _bench_ids() -> Array[String]:
	var out: Array[String] = []
	if not _has_autoload("Roster"):
		return out
	var units: Array[Unit] = Roster.compact()
	for unit: Unit in units:
		out.append(_unit_id(unit))
	return out

func _board_ids() -> Array[String]:
	var out: Array[String] = []
	var controller: Variant = _combat_controller()
	if controller == null:
		return out
	var manager: Variant = controller.get("manager")
	if manager == null:
		return out
	for unit_value: Variant in manager.player_team:
		out.append(_unit_id(unit_value as Unit))
	return out

func _unit_id(unit: Unit) -> String:
	if unit == null:
		return ""
	if "id" in unit:
		return String(unit.id)
	return String(unit.name)

func _drag_first_bench_unit_to_board() -> bool:
	var combat: Control = _main.get_node_or_null("CombatView") as Control
	if combat == null:
		return false
	var controller: Variant = combat.get("controller")
	if controller == null or controller.manager == null:
		return false
	var bench_grid: GridContainer = combat.get_node_or_null("MarginContainer/VBoxContainer/BenchArea/BenchGrid") as GridContainer
	if bench_grid == null:
		return false
	var unit_view: UnitView = _find_first_unit_view(bench_grid)
	if unit_view == null:
		return false
	var target_tile: int = _first_empty_board_tile(controller)
	if target_tile < 0:
		return false
	var moved_unit: Unit = unit_view.unit as Unit
	var before_size: int = int(controller.manager.player_team.size())
	var target_center: Vector2 = controller.player_grid_helper.get_center(target_tile)
	var dragged: bool = await _drag_control_to(unit_view, target_center, "rapid bench unit to board")
	await _settle_frames(6)
	return dragged and moved_unit != null and controller.manager.player_team.has(moved_unit) and controller.manager.player_team.size() >= before_size + 1

func _find_first_unit_view(root: Node) -> UnitView:
	for child: Node in root.get_children():
		if child is UnitView:
			return child as UnitView
		var nested: UnitView = _find_first_unit_view(child)
		if nested != null:
			return nested
	return null

func _first_empty_board_tile(controller: Variant) -> int:
	if controller == null or controller.player_grid_helper == null:
		return -1
	for index: int in range(24):
		if not controller.player_grid_helper.is_occupied(index):
			return index
	return -1

func _drag_control_to(control: Control, target_pos: Vector2, label: String) -> bool:
	if control == null or not is_instance_valid(control) or not control.is_inside_tree():
		_expect(false, "%s source is not available" % label)
		return false
	if not control.visible:
		_expect(false, "%s source is hidden" % label)
		return false
	var drag_started: Array[bool] = [false]
	var drag_ended: Array[bool] = [false]
	var began_callback: Callable = func() -> void:
		drag_started[0] = true
	var ended_callback: Callable = func() -> void:
		drag_ended[0] = true
	if control.has_signal("began_drag"):
		control.connect("began_drag", began_callback, CONNECT_ONE_SHOT)
	if control.has_signal("ended_drag"):
		control.connect("ended_drag", ended_callback, CONNECT_ONE_SHOT)
	if control.has_method("_begin_drag_internal"):
		control.call("_begin_drag_internal")
		_send_drag_motion(target_pos)
		await _settle_frames(2)
		_send_drag_release(target_pos)
		await _settle_frames(4)
	if is_instance_valid(control):
		if control.has_signal("began_drag") and control.is_connected("began_drag", began_callback):
			control.disconnect("began_drag", began_callback)
		if control.has_signal("ended_drag") and control.is_connected("ended_drag", ended_callback):
			control.disconnect("ended_drag", ended_callback)
	_expect(bool(drag_started[0]), "%s did not begin drag" % label)
	_expect(bool(drag_ended[0]), "%s did not end drag" % label)
	return bool(drag_started[0]) and bool(drag_ended[0])

func _send_drag_motion(position: Vector2) -> void:
	Input.warp_mouse(position)
	var event: InputEventMouseMotion = InputEventMouseMotion.new()
	event.position = position
	event.global_position = position
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(event)

func _send_drag_release(position: Vector2) -> void:
	Input.warp_mouse(position)
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = 0
	event.position = position
	event.global_position = position
	event.pressed = false
	Input.parse_input_event(event)

func _visible_click_point(control: Control) -> Vector2:
	var rect: Rect2 = control.get_global_rect()
	var viewport_rect: Rect2 = _viewport_rect()
	var visible_rect: Rect2 = rect.intersection(viewport_rect)
	if visible_rect.size.x > 4.0 and visible_rect.size.y > 4.0:
		return visible_rect.get_center()
	return rect.get_center()

func _viewport_rect() -> Rect2:
	var viewport_rect: Rect2 = get_viewport().get_visible_rect()
	if viewport_rect.size.x > 4.0 and viewport_rect.size.y > 4.0:
		return viewport_rect
	var window_size: Vector2i = DisplayServer.window_get_size()
	if window_size.x > 4 and window_size.y > 4:
		return Rect2(Vector2.ZERO, Vector2(float(window_size.x), float(window_size.y)))
	return Rect2(Vector2.ZERO, Vector2(640.0, 360.0))

func _mouse_click(position: Vector2) -> void:
	await _mouse_button(position, true)
	await _mouse_button(position, false)

func _mouse_button(position: Vector2, pressed: bool) -> void:
	get_viewport().warp_mouse(position)
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	event.position = position
	event.global_position = position
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await get_tree().process_frame

func _set_planning_timer_safe(seconds: float) -> void:
	var combat: Control = _main.get_node_or_null("CombatView") as Control
	if combat == null:
		return
	combat.set("planning_timer_total", seconds)
	combat.set("planning_time_left", seconds)

func _set_bet_to_max() -> void:
	var slider: HSlider = _main.find_child("BetSlider", true, false) as HSlider
	if slider != null:
		slider.value = slider.max_value

func _deploy_prompt_visible() -> bool:
	var root: Node = _main.get_node_or_null("CombatView")
	if root == null:
		return false
	return _find_label_containing_text(root, "Drag it from bench to board") != null

func _continue_button_text() -> String:
	var button: Button = _main.find_child("ContinueButton", true, false) as Button
	return "" if button == null else String(button.text)

func _phase_name() -> String:
	if not _has_autoload("GameState"):
		return "NO_GAME_STATE"
	if int(GameState.phase) == int(GameState.GamePhase.PREVIEW):
		return "PREVIEW"
	if int(GameState.phase) == int(GameState.GamePhase.COMBAT):
		return "COMBAT"
	return str(int(GameState.phase))

func _combat_controller() -> Variant:
	var combat: Control = _main.get_node_or_null("CombatView") as Control
	if combat == null:
		return null
	return combat.get("controller")

func _find_label_containing_text(root: Node, text: String) -> Label:
	if root is Label and String((root as Label).text).find(text) >= 0:
		return root as Label
	for child: Node in root.get_children():
		var found: Label = _find_label_containing_text(child, text)
		if found != null:
			return found
	return null

func _shop_errors_since(start_index: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for index: int in range(max(0, start_index), _shop_errors.size()):
		out.append(_shop_errors[index].duplicate(true))
	return out

func _has_autoload(autoload_name: String) -> bool:
	var path: String = "/root/%s" % String(autoload_name)
	return get_tree().root.get_node_or_null(path) != null

func _node_visible(path: String) -> bool:
	if _main == null:
		return false
	var node: CanvasItem = _main.get_node_or_null(path) as CanvasItem
	return node != null and node.visible

func _settle_frames(count: int) -> void:
	for index: int in range(count):
		await get_tree().process_frame

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

func _finish() -> void:
	Engine.time_scale = _previous_time_scale
	UnitFactory.set("suppress_validation_warnings", _previous_suppress_validation_warnings)
	Input.flush_buffered_events()
	if _has_autoload("Shop") and Shop.is_connected("error", Callable(self, "_on_shop_error")):
		Shop.error.disconnect(_on_shop_error)
	var exit_code: int = 0
	if _failures.is_empty():
		print("%s: OK purchases=%d deployed_board=%d" % [_smoke_name(), int(ShopConfig.SLOT_COUNT), _board_ids().size()])
	else:
		for failure: String in _failures:
			push_error("%s: %s" % [_smoke_name(), failure])
		exit_code = 1
	_cleanup_runtime()
	get_tree().process_frame.connect(_quit_after_cleanup.bind(exit_code, 10), CONNECT_ONE_SHOT)

func _quit_after_cleanup(exit_code: int, frames_left: int) -> void:
	if frames_left > 0:
		get_tree().process_frame.connect(_quit_after_cleanup.bind(exit_code, frames_left - 1), CONNECT_ONE_SHOT)
		return
	get_tree().quit(exit_code)

func _cleanup_runtime() -> void:
	if _main != null and is_instance_valid(_main):
		var combat_view: Node = _main.get_node_or_null("CombatView")
		if combat_view != null and combat_view.has_method("_teardown"):
			combat_view.call("_teardown")
		if _main.has_method("_reset_run_state"):
			_main.call("_reset_run_state")
		var parent: Node = _main.get_parent()
		if parent != null:
			parent.remove_child(_main)
		_main.free()
		_main = null
	var loss_layer: Node = get_tree().root.get_node_or_null("LossOverlayLayer")
	if loss_layer != null:
		var loss_parent: Node = loss_layer.get_parent()
		if loss_parent != null:
			loss_parent.remove_child(loss_layer)
		loss_layer.free()
	if _has_autoload("Economy"):
		Economy.reset_run()
	if _has_autoload("Shop"):
		Shop.reset_run()
	if _has_autoload("Roster") and Roster.has_method("reset"):
		Roster.reset()
	if _has_autoload("Items") and Items.has_method("reset_run"):
		Items.reset_run()
	StageRuleRunner.clear_runtime()
	AbilityCatalog.clear_caches()
	RoleLibrary.clear_cache()
	IdentityRegistry.clear_cache()
	ItemCatalog.clear_cache()
	TraitCompiler.clear_cache()
	UnitFactory.clear_cache()
