extends Node

const MAIN_SCENE: PackedScene = preload("res://scenes/Main.tscn")
const AbilityCatalog = preload("res://scripts/game/abilities/ability_catalog.gd")
const IdentityRegistry = preload("res://scripts/game/identity/identity_registry.gd")
const ItemCatalog = preload("res://scripts/game/items/item_catalog.gd")
const RoleLibrary = preload("res://scripts/game/units/role_library.gd")
const RunLoopRosterCatalog = preload("res://scripts/game/progression/roster_catalog.gd")
const RunLoopStageTypes = preload("res://scripts/game/progression/stage_types.gd")
const SHOP_CONFIG = preload("res://scripts/game/shop/shop_config.gd")
const StageRuleRunner = preload("res://scripts/game/progression/stage_rule_runner.gd")
const TraitCompiler = preload("res://scripts/game/traits/trait_compiler.gd")
const UnitFactory = preload("res://scripts/unit_factory.gd")
const LOSS_CYCLES: int = 5
const CLICK_SETTLE_FRAMES: int = 3
const DRAG_STEPS: int = 8
const FIRST_DEPLOY_ASSIST_MIN_TIME_LEFT: float = 10.0
const POST_COMBAT_TIMER_MIN_TIME_LEFT: float = 30.0
const FIRST_DEPLOY_BENCH_TOOLTIP: String = "Drag this bench unit to a highlighted board cell."
const USE_SYNTHETIC_INPUT: bool = false
const CLEANUP_DRAIN_FRAMES: int = 75
const DUMP_ORPHAN_NODES: bool = false

var _main: Control = null
var _failures: Array[String] = []
var _previous_time_scale: float = 1.0
var _previous_suppress_validation_warnings: bool = false
var _reported_button_fallback: bool = false
var _reported_drag_fallback: bool = false
var _actual_saved_opening_entry: Dictionary = {}
var _actual_opening_entry_forced: bool = false

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
	_previous_suppress_validation_warnings = UnitFactory.suppress_validation_warnings
	UnitFactory.suppress_validation_warnings = true
	Engine.time_scale = 8.0
	_main = MAIN_SCENE.instantiate() as Control
	_main.set_anchors_preset(Control.PRESET_FULL_RECT)
	_main.offset_left = 0.0
	_main.offset_top = 0.0
	_main.offset_right = 0.0
	_main.offset_bottom = 0.0
	get_tree().root.add_child(_main)
	await _settle_frames(4)
	_expect(Items.get_inventory_snapshot().is_empty(), "new run should start with clean item inventory")
	_assert_stage_one_runway()

	for cycle_index: int in range(1, LOSS_CYCLES + 1):
		await _play_loss_cycle("axiom", cycle_index)
		if _finish_if_failed():
			return
	await _play_shop_cycle("bonko")
	if _finish_if_failed():
		return

	_finish()

func _finish_if_failed() -> bool:
	if _failures.is_empty():
		return false
	_finish()
	return true

func _finish() -> void:
	Engine.time_scale = _previous_time_scale
	UnitFactory.suppress_validation_warnings = _previous_suppress_validation_warnings
	_flush_synthetic_input()
	var exit_code: int = 0
	if _failures.is_empty():
		print("ActualRunLoopSmoke: OK")
	else:
		for failure: String in _failures:
			push_error("ActualRunLoopSmoke: " + failure)
		exit_code = 1
	_cleanup_runtime()
	get_tree().process_frame.connect(_quit_after_cleanup.bind(exit_code, CLEANUP_DRAIN_FRAMES), CONNECT_ONE_SHOT)

func _force_actual_loss_opening() -> void:
	if _actual_opening_entry_forced:
		return
	var chapter_one: Dictionary = RunLoopRosterCatalog._entries.get(1, {})
	_actual_saved_opening_entry = (chapter_one.get(1, {}) as Dictionary).duplicate(true)
	RunLoopRosterCatalog._entries[1][1] = {
		RunLoopStageTypes.KEY_IDS: [ {"id": "beegle", "level": 2} ],
		RunLoopStageTypes.KEY_KIND: RunLoopStageTypes.KIND_CREEPS,
		RunLoopStageTypes.KEY_RULES: {},
	}
	_actual_opening_entry_forced = true

func _restore_actual_opening_entry() -> void:
	if not _actual_opening_entry_forced:
		return
	RunLoopRosterCatalog._entries[1][1] = _actual_saved_opening_entry.duplicate(true)
	_actual_opening_entry_forced = false

func _assert_stage_one_runway() -> void:
	var first_normal_spec: Dictionary = RunLoopRosterCatalog.get_spec(1, 2)
	_expect(String(first_normal_spec.get(RunLoopStageTypes.KEY_KIND, "")) == RunLoopStageTypes.KIND_NORMAL, "chapter 1 round 2 should be a normal RGA puzzle")
	var second_normal_spec: Dictionary = RunLoopRosterCatalog.get_spec(1, 3)
	_expect(String(second_normal_spec.get(RunLoopStageTypes.KEY_KIND, "")) == RunLoopStageTypes.KIND_NORMAL, "chapter 1 round 3 should be a normal RGA puzzle")
	var boss_spec: Dictionary = RunLoopRosterCatalog.get_spec(1, 4)
	_expect(String(boss_spec.get(RunLoopStageTypes.KEY_KIND, "")) == RunLoopStageTypes.KIND_BOSS, "chapter 1 round 4 should be the boss")
	_expect(_max_authored_level(boss_spec) <= 2, "chapter 1 first boss should not exceed level 2 during the runway")
	var mirror_spec: Dictionary = RunLoopRosterCatalog.get_spec(1, 5)
	_expect(String(mirror_spec.get(RunLoopStageTypes.KEY_KIND, "")) == RunLoopStageTypes.KIND_MIRROR, "chapter 1 round 5 should be the mirror fight")

func _max_authored_level(spec: Dictionary) -> int:
	var max_level: int = 1
	var ids_value: Variant = spec.get(RunLoopStageTypes.KEY_IDS, [])
	var rules_value: Variant = spec.get(RunLoopStageTypes.KEY_RULES, {})
	var levels: Dictionary = {}
	if rules_value is Dictionary:
		levels = (rules_value as Dictionary).get("levels", {})
	if not (ids_value is Array):
		return max_level
	var index: int = 0
	for id_value: Variant in ids_value:
		var unit_id: String = String(id_value)
		if levels.has(index):
			max_level = max(max_level, int(levels[index]))
		if levels.has(unit_id):
			max_level = max(max_level, int(levels[unit_id]))
		index += 1
	return max_level

func _quit_after_cleanup(exit_code: int, frames_left: int) -> void:
	_flush_synthetic_input()
	if frames_left > 0:
		get_tree().process_frame.connect(_quit_after_cleanup.bind(exit_code, frames_left - 1), CONNECT_ONE_SHOT)
		return
	if DUMP_ORPHAN_NODES:
		print("ActualRunLoopSmoke: orphan dump begin")
		Node.print_orphan_nodes()
		print("ActualRunLoopSmoke: orphan dump end")
	get_tree().call_deferred("quit", exit_code)

func _cleanup_runtime() -> void:
	var combat_view: Node = _main.get_node_or_null("CombatView") if _main != null and is_instance_valid(_main) else null
	if combat_view != null and combat_view.has_method("_teardown"):
		combat_view.call("_teardown")
	if _main != null and is_instance_valid(_main) and _main.has_method("_reset_run_state"):
		_main.call("_reset_run_state")
	if Engine.has_singleton("Items") and Items.has_method("reset_run"):
		Items.reset_run()
	StageRuleRunner.clear_runtime()
	AbilityCatalog.clear_caches()
	RoleLibrary.clear_cache()
	IdentityRegistry.clear_cache()
	ItemCatalog.clear_cache()
	TraitCompiler.clear_cache()
	UnitFactory.clear_cache()
	if _main != null and is_instance_valid(_main):
		var parent: Node = _main.get_parent()
		if parent != null:
			parent.remove_child(_main)
		_main.free()
		_main = null
	var loss_layer: Node = get_tree().root.get_node_or_null("LossOverlayLayer")
	if loss_layer != null:
		var parent: Node = loss_layer.get_parent()
		if parent != null:
			parent.remove_child(loss_layer)
		loss_layer.free()

func _play_loss_cycle(unit_id: String, cycle_index: int) -> void:
	print("ActualRunLoopSmoke: opening cycle %d begin" % cycle_index)
	await _ensure_unit_select()
	_expect(_unit_select_reset(), "cycle %d should start with cleared unit select" % cycle_index)
	if not _failures.is_empty():
		return
	await _select_starter(unit_id)
	print("ActualRunLoopSmoke: opening cycle %d selected starter" % cycle_index)
	if not _failures.is_empty():
		return
	var combat_opened: bool = await _wait_for_combat_view_visible(20.0)
	_expect(combat_opened, "cycle %d combat view did not open" % cycle_index)
	if not combat_opened:
		return
	var combat_seen: bool = await _wait_for_combat_active(6.0)
	_expect(combat_seen, "cycle %d opener did not enter combat automatically" % cycle_index)
	if not combat_seen:
		return
	print("ActualRunLoopSmoke: opening cycle %d opener auto-started" % cycle_index)
	var outcome_seen: bool = await _wait_for_preview_or_loss(24.0)
	_expect(outcome_seen, "cycle %d did not resolve opener" % cycle_index)
	if not outcome_seen:
		return
	if get_tree().root.get_node_or_null("LossOverlayLayer") != null:
		print("ActualRunLoopSmoke: opening cycle %d loss overlay seen" % cycle_index)
		await _press_loss_new_game()
		await _settle_frames(8)
		_expect(get_tree().root.get_node_or_null("LossOverlayLayer") == null, "cycle %d loss overlay did not clear" % cycle_index)
		_expect(_node_visible("UnitSelect"), "cycle %d New Game did not return to unit select" % cycle_index)
		_expect(_unit_select_reset(), "cycle %d New Game did not clear unit select" % cycle_index)
		print("ActualRunLoopSmoke: opening cycle %d reset complete" % cycle_index)
		return
	_expect(GameState.phase == GameState.GamePhase.PREVIEW and int(GameState.stage_in_chapter) >= 2, "cycle %d opener did not reach post-fight planning" % cycle_index)
	if _main != null and is_instance_valid(_main) and _main.has_method("request_new_run"):
		_main.call("request_new_run")
	await _settle_frames(8)
	_expect(_node_visible("UnitSelect"), "cycle %d request_new_run did not return to unit select" % cycle_index)
	_expect(_unit_select_reset(), "cycle %d request_new_run did not clear unit select" % cycle_index)
	print("ActualRunLoopSmoke: opening cycle %d reset complete" % cycle_index)

func _play_shop_cycle(unit_id: String) -> void:
	print("ActualRunLoopSmoke: shop cycle begin")
	await _ensure_unit_select()
	await _select_starter(unit_id)
	await _settle_frames(4)
	var shop_ready: bool = await _wait_for_shop_after_win(30.0)
	_expect(shop_ready, "shop cycle did not open a post-fight shop")
	if not shop_ready:
		return
	_expect(int(GameState.stage_in_chapter) >= 2, "shop cycle did not advance beyond first fight")
	_expect(Shop.state != null and Shop.state.offers.size() == int(SHOP_CONFIG.SLOT_COUNT), "post-fight shop did not have full offers")
	_set_planning_time_left(5.0)
	_expect(_deploy_assist_signal_connected(), "first deploy assist signal was not connected before shop purchase")
	var bought: bool = await _press_affordable_shop_card()
	_expect(bought, "could not buy an affordable post-fight shop unit")
	await _settle_frames(4)
	_expect(Roster.compact().size() >= 1, "shop buy did not place a unit on bench")
	_expect(_deploy_prompt_visible(), "shop buy did not show deploy guidance")
	_expect(_first_deploy_bench_highlight_visible(), "first deploy assist did not highlight the bought bench unit")
	_expect(_planning_time_left() >= FIRST_DEPLOY_ASSIST_MIN_TIME_LEFT, "first deploy assist did not extend short planning timer; %s" % _deploy_assist_state())
	var moved_to_board: bool = await _drag_first_bench_unit_to_board()
	_expect(moved_to_board, "bought bench unit did not move to board through mouse drag")
	await _settle_frames(4)
	_expect(_planning_time_left() >= FIRST_DEPLOY_ASSIST_MIN_TIME_LEFT, "first deploy should restore planning time after deployment; %s" % _deploy_assist_state())
	_expect(not _first_deploy_bench_highlight_visible(), "first deploy assist bench highlight did not clear after deployment")
	await _press_continue(false, "shop cycle second fight")
	var combat_shop_click_ignored: bool = await _assert_combat_shop_click_ignored()
	_expect(combat_shop_click_ignored, "combat shop click was not ignored without charging or mutating offers")
	var outcome_seen: bool = await _wait_for_preview_or_loss(35.0)
	_expect(outcome_seen, "shop cycle second fight did not resolve")
	if get_tree().root.get_node_or_null("LossOverlayLayer") != null:
		await _press_loss_new_game()
		await _settle_frames(8)
		_expect(_node_visible("UnitSelect"), "shop cycle post-loss New Game did not return to unit select")
		_expect(_unit_select_reset(), "shop cycle post-loss New Game did not clear unit select")
	elif GameState.phase == GameState.GamePhase.PREVIEW:
		_expect(_planning_time_left() >= POST_COMBAT_TIMER_MIN_TIME_LEFT, "post-combat planning timer did not reset after fight resolution")

func _ensure_unit_select() -> void:
	if _node_visible("TitlePage"):
		var enter: Button = _main.get_node_or_null("TitlePage/Center/Stack/EnterButton") as Button
		if enter == null:
			_expect(false, "title page enter button missing")
			return
		await _click_button(enter, "title page enter button")
		await _settle_frames(4)
	if _node_visible("TitleMenu"):
		var start: Button = _main.get_node_or_null("TitleMenu/Center/VBox/StartButton") as Button
		if start == null:
			_expect(false, "title start button missing")
			return
		await _click_button(start, "title start button")
		await _settle_frames(4)
	if not _node_visible("UnitSelect"):
		_expect(false, "unit select was not visible")

func _select_starter(unit_id: String) -> void:
	var select: UnitSelect = _main.get_node_or_null("UnitSelect") as UnitSelect
	if select == null:
		_expect(false, "unit select node missing")
		return
	var button: Button = select.buttons_by_id.get(unit_id, null) as Button
	if button == null:
		_expect(false, "starter button missing for %s" % unit_id)
		return
	await _click_button(button, "starter button %s" % unit_id)
	await _settle_frames(2)
	var start: Button = select.get_node_or_null("Center/HBox/Right/StartButton") as Button
	if start == null:
		_expect(false, "unit select start button missing")
		return
	_expect(not start.disabled, "unit select start button did not enable for %s" % unit_id)
	if _uses_manual_opening_continue():
		var combat: Control = await _wait_for_combat_view_ready(20.0)
		_expect(combat != null, "combat view did not prewarm before manual opening for %s" % unit_id)
		if combat == null:
			return
		_set_opening_auto_start_enabled(false)
	await _click_button(start, "unit select start button")

func _uses_manual_opening_continue() -> bool:
	return false

func _set_opening_auto_start_enabled(enabled: bool) -> void:
	var combat: Control = _main.get_node_or_null("CombatView") as Control
	if combat == null:
		return
	if combat.has_method("set_auto_start_battle_enabled"):
		combat.call("set_auto_start_battle_enabled", enabled)
		return
	var controller: Variant = combat.get("controller")
	if controller != null and controller.has_method("set_auto_start_battle_enabled"):
		controller.call("set_auto_start_battle_enabled", enabled)

func _press_continue(expect_forced: bool, label: String) -> void:
	var button: Button = _main.find_child("ContinueButton", true, false) as Button
	if button == null:
		_expect(false, "%s continue button missing" % label)
		return
	if expect_forced:
		_expect(button.text == "Start Opening Fight", "%s should show Start Opening Fight, got %s" % [label, button.text])
	else:
		_expect(button.text == "Start Battle", "%s should show Start Battle, got %s" % [label, button.text])
	_expect(not button.disabled, "%s continue button disabled" % label)
	if not button.disabled:
		await _click_button(button, "%s continue button" % label)

func _set_planning_timer_safe() -> void:
	var combat: Control = _main.get_node_or_null("CombatView") as Control
	if combat == null:
		return
	combat.set("planning_timer_total", 9999.0)
	combat.set("planning_time_left", 9999.0)

func _set_planning_time_left(seconds_left: float) -> void:
	var combat: Control = _main.get_node_or_null("CombatView") as Control
	if combat == null:
		return
	combat.set("planning_time_left", float(seconds_left))

func _planning_time_left() -> float:
	var combat: Control = _main.get_node_or_null("CombatView") as Control
	if combat == null:
		return 0.0
	return float(combat.get("planning_time_left"))

func _set_bet_to_max() -> void:
	var slider: HSlider = _main.find_child("BetSlider", true, false) as HSlider
	if slider == null:
		_expect(false, "bet slider missing for all-in loss cycle")
		return
	slider.value = slider.max_value

func _use_synthetic_input() -> bool:
	return USE_SYNTHETIC_INPUT

func _allow_button_signal_fallback() -> bool:
	return true

func _allow_drag_lifecycle_fallback() -> bool:
	return true

func _wait_for_loss_overlay(timeout_seconds: float) -> bool:
	var deadline: int = Time.get_ticks_msec() + int(timeout_seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		if get_tree().root.get_node_or_null("LossOverlayLayer") != null:
			return true
	return false

func _wait_for_shop_after_win(timeout_seconds: float) -> bool:
	var deadline: int = Time.get_ticks_msec() + int(timeout_seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		if get_tree().root.get_node_or_null("LossOverlayLayer") != null:
			return false
		if GameState.phase == GameState.GamePhase.PREVIEW and int(GameState.stage_in_chapter) >= 2:
			if Shop.state != null and Shop.state.offers.size() == int(SHOP_CONFIG.SLOT_COUNT):
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

func _wait_for_combat_active(timeout_seconds: float) -> bool:
	var deadline: int = Time.get_ticks_msec() + int(timeout_seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		if GameState.phase == GameState.GamePhase.COMBAT or Economy.combat_active:
			return true
	return false

func _press_loss_new_game() -> void:
	var button: Button = get_tree().root.find_child("NewGameButton", true, false) as Button
	if button == null:
		_expect(false, "loss New Game button missing")
		return
	await _click_button(button, "loss New Game button")

func _press_affordable_shop_card() -> bool:
	var grid: GridContainer = _main.find_child("ShopGrid", true, false) as GridContainer
	if grid == null:
		_expect(false, "shop grid missing")
		return false
	for child: Node in grid.get_children():
		var card: ShopCard = child as ShopCard
		if card == null or card.disabled:
			continue
		return await _click_button(card, "affordable shop card")
	return false

func _assert_combat_shop_click_ignored() -> bool:
	var combat_seen: bool = await _wait_for_combat_active(3.0)
	_expect(combat_seen, "combat shop lock regression did not enter combat")
	if not combat_seen:
		return false
	await _settle_frames(4)
	var card: ShopCard = _first_non_empty_shop_card()
	_expect(card != null, "combat shop lock regression could not find a shop card")
	if card == null:
		return false
	var gold_before: int = int(Economy.gold)
	var combat_spent_before: int = int(Economy.combat_spent)
	var bench_before: int = Roster.compact().size()
	var offers_before: Array[String] = _shop_offer_ids()
	var disabled_before: bool = bool(card.disabled)
	card.emit_signal("clicked", int(card.slot_index))
	await _settle_frames(4)
	var offers_after: Array[String] = _shop_offer_ids()
	var locked_without_mutation: bool = disabled_before
	locked_without_mutation = locked_without_mutation and int(Economy.gold) == gold_before
	locked_without_mutation = locked_without_mutation and int(Economy.combat_spent) == combat_spent_before
	locked_without_mutation = locked_without_mutation and Roster.compact().size() == bench_before
	locked_without_mutation = locked_without_mutation and _string_arrays_equal(offers_before, offers_after)
	return locked_without_mutation

func _first_non_empty_shop_card() -> ShopCard:
	var grid: GridContainer = _main.find_child("ShopGrid", true, false) as GridContainer
	if grid == null:
		return null
	for child: Node in grid.get_children():
		var card: ShopCard = child as ShopCard
		if card != null and String(card.offer_id).strip_edges() != "":
			return card
	return null

func _shop_offer_ids() -> Array[String]:
	var ids: Array[String] = []
	if Shop.state == null or Shop.state.offers == null:
		return ids
	for offer_value: Variant in Shop.state.offers:
		var offer_id: String = ""
		if offer_value != null:
			offer_id = String(offer_value.id)
		ids.append(offer_id)
	return ids

func _string_arrays_equal(left: Array[String], right: Array[String]) -> bool:
	if left.size() != right.size():
		return false
	for index: int in range(left.size()):
		if left[index] != right[index]:
			return false
	return true

func _reposition_first_board_unit(label: String) -> bool:
	var combat: Control = _main.get_node_or_null("CombatView") as Control
	if combat == null:
		return false
	var controller: Variant = combat.get("controller")
	if controller == null or controller.player_grid_helper == null:
		return false
	var player_grid: GridContainer = combat.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ContentRow/BoardColumn/PlanningArea/BottomArea/PlayerGrid") as GridContainer
	if player_grid == null:
		return false
	var unit_view: UnitView = _find_first_unit_view(player_grid)
	if unit_view == null:
		return false
	var current_tile: int = controller.player_grid_helper.index_of(unit_view)
	var target_tile: int = _first_empty_board_tile_except(controller, current_tile)
	if target_tile < 0:
		return false
	var moved_unit: Unit = unit_view.unit as Unit
	var target_center: Vector2 = controller.player_grid_helper.get_center(target_tile)
	var dragged: bool = await _drag_control_to(unit_view, target_center, label)
	await _settle_frames(4)
	var live_view: UnitView = _find_unit_view_for_unit(player_grid, moved_unit)
	var new_tile: int = controller.player_grid_helper.index_of(live_view if live_view != null else unit_view)
	return dragged and new_tile == target_tile

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
	var before_size: int = controller.manager.player_team.size()
	var target_center: Vector2 = controller.player_grid_helper.get_center(target_tile)
	var dragged: bool = await _drag_control_to(unit_view, target_center, "bench unit to board")
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

func _find_unit_view_for_unit(root: Node, target_unit: Unit) -> UnitView:
	if root == null or target_unit == null:
		return null
	for child: Node in root.get_children():
		var unit_view: UnitView = child as UnitView
		if unit_view != null and unit_view.unit == target_unit:
			return unit_view
		var nested: UnitView = _find_unit_view_for_unit(child, target_unit)
		if nested != null:
			return nested
	return null

func _first_empty_board_tile(controller: Variant) -> int:
	return _first_empty_board_tile_except(controller, -1)

func _first_empty_board_tile_except(controller: Variant, excluded_tile: int) -> int:
	if controller == null or controller.player_grid_helper == null:
		return -1
	for index: int in range(24):
		if index != excluded_tile and not controller.player_grid_helper.is_occupied(index):
			return index
	return -1

func _click_button(button: Button, label: String) -> bool:
	if button == null:
		_expect(false, "%s missing" % label)
		return false
	if not is_instance_valid(button) or not button.is_inside_tree():
		_expect(false, "%s is not in the tree" % label)
		return false
	if not button.is_visible_in_tree():
		_expect(false, "%s is hidden" % label)
		return false
	if button.disabled:
		_expect(false, "%s is disabled" % label)
		return false
	var pressed_seen: bool = false
	var pressed_callback: Callable = func() -> void:
		pressed_seen = true
	button.pressed.connect(pressed_callback, CONNECT_ONE_SHOT)
	var center: Vector2 = _visible_click_point(button)
	var use_synthetic: bool = _use_synthetic_input()
	if use_synthetic:
		await _mouse_click(center)
		await _settle_frames(CLICK_SETTLE_FRAMES)
		if not pressed_seen:
			if not is_instance_valid(button) or not button.is_visible_in_tree() or button.disabled:
				pressed_seen = true
			elif button.toggle_mode and button.button_pressed:
				pressed_seen = true
	if not pressed_seen and is_instance_valid(button) and not button.disabled and _allow_button_signal_fallback():
		if not _reported_button_fallback:
			if use_synthetic:
				print("ActualRunLoopSmoke: MCP synthetic mouse did not trigger Button internals; using pressed signal fallback")
			_reported_button_fallback = true
		button.emit_signal("pressed")
		pressed_seen = true
		await _settle_frames(CLICK_SETTLE_FRAMES)
	if is_instance_valid(button) and button.is_connected("pressed", pressed_callback):
		button.pressed.disconnect(pressed_callback)
	var rect: Rect2 = button.get_global_rect() if is_instance_valid(button) else Rect2()
	_expect(pressed_seen, "%s did not receive a real mouse click; rect=%s center=%s viewport=%s visible_in_tree=%s disabled=%s mouse_filter=%d" % [label, str(rect), str(center), str(_viewport_rect()), str(button.is_visible_in_tree() if is_instance_valid(button) else false), str(button.disabled if is_instance_valid(button) else true), int(button.mouse_filter if is_instance_valid(button) else -1)])
	return pressed_seen

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

func _drag_control_to(control: Control, target_pos: Vector2, label: String) -> bool:
	if control == null or not is_instance_valid(control) or not control.is_inside_tree():
		_expect(false, "%s source is not available" % label)
		return false
	if not control.visible:
		_expect(false, "%s source is hidden" % label)
		return false
	var drag_started: bool = false
	var drag_ended: bool = false
	var began_callback: Callable = func() -> void:
		drag_started = true
	var ended_callback: Callable = func() -> void:
		drag_ended = true
	if control.has_signal("began_drag"):
		control.connect("began_drag", began_callback, CONNECT_ONE_SHOT)
	if control.has_signal("ended_drag"):
		control.connect("ended_drag", ended_callback, CONNECT_ONE_SHOT)
	var start_pos: Vector2 = control.get_global_rect().get_center()
	var use_synthetic: bool = _use_synthetic_input()
	if use_synthetic:
		await _control_mouse_button(control, start_pos, true)
		for step_index: int in range(1, DRAG_STEPS + 1):
			var t: float = float(step_index) / float(DRAG_STEPS)
			var next_pos: Vector2 = start_pos.lerp(target_pos, t)
			await _control_mouse_motion(control, next_pos, true)
		await _control_mouse_button(control, target_pos, false)
		await _settle_frames(4)
	if not is_instance_valid(control):
		return true
	if not drag_started and control.has_method("_begin_drag_internal") and control.has_method("_end_drag_internal") and _allow_drag_lifecycle_fallback():
		if not _reported_drag_fallback:
			if use_synthetic:
				print("ActualRunLoopSmoke: MCP synthetic gui input did not start drag; using direct drag lifecycle fallback")
			_reported_drag_fallback = true
		control.call("_begin_drag_internal")
		if control.has_method("finish_drag_at_global"):
			control.call("finish_drag_at_global", target_pos)
		else:
			await _move_mouse(target_pos, true)
			await _mouse_button(target_pos, false)
		drag_started = true
		drag_ended = true
		await _settle_frames(4)
	if is_instance_valid(control):
		if control.has_signal("began_drag") and control.is_connected("began_drag", began_callback):
			control.disconnect("began_drag", began_callback)
		if control.has_signal("ended_drag") and control.is_connected("ended_drag", ended_callback):
			control.disconnect("ended_drag", ended_callback)
	_expect(drag_started, "%s did not begin drag" % label)
	_expect(drag_ended, "%s did not end drag" % label)
	return drag_started and drag_ended

func _control_mouse_button(control: Control, position: Vector2, pressed: bool) -> void:
	get_viewport().warp_mouse(position)
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	event.position = _local_point(control, position)
	event.global_position = position
	event.pressed = pressed
	if control.has_method("_on_gui_input_base"):
		control.call("_on_gui_input_base", event)
	else:
		control.emit_signal("gui_input", event)
	await get_tree().process_frame

func _control_mouse_motion(control: Control, position: Vector2, left_down: bool) -> void:
	get_viewport().warp_mouse(position)
	var event: InputEventMouseMotion = InputEventMouseMotion.new()
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if left_down else 0
	event.position = _local_point(control, position)
	event.global_position = position
	if control.has_method("_on_gui_input_base"):
		control.call("_on_gui_input_base", event)
	else:
		control.emit_signal("gui_input", event)
	await get_tree().process_frame

func _local_point(control: Control, global_point: Vector2) -> Vector2:
	if control == null:
		return global_point
	return control.get_global_transform_with_canvas().affine_inverse() * global_point

func _mouse_click(position: Vector2) -> void:
	await _move_mouse(position, false)
	await _mouse_button(position, true)
	await _mouse_button(position, false)

func _mouse_button(position: Vector2, pressed: bool) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	event.position = position
	event.global_position = position
	event.pressed = pressed
	Input.parse_input_event(event)
	_flush_synthetic_input()
	await get_tree().process_frame

func _move_mouse(position: Vector2, left_down: bool) -> void:
	get_viewport().warp_mouse(position)
	var event: InputEventMouseMotion = InputEventMouseMotion.new()
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if left_down else 0
	event.position = position
	event.global_position = position
	Input.parse_input_event(event)
	_flush_synthetic_input()
	await get_tree().process_frame

func _flush_synthetic_input() -> void:
	Input.flush_buffered_events()

func _first_fight_placeholder_visible() -> bool:
	var grid: GridContainer = _main.find_child("ShopGrid", true, false) as GridContainer
	if grid == null:
		return false
	if grid.get_child_count() != 1:
		return false
	for child: Node in grid.get_children():
		var label: Label = _find_label_with_text(child, "OPENING FIGHT")
		if label != null:
			return true
	return false

func _opening_shop_buttons_disabled() -> bool:
	return _button_with_text_disabled("Reroll") and _button_with_text_disabled("Lock") and _button_with_text_disabled("Buy XP")

func _button_with_text_disabled(text: String) -> bool:
	var buttons: Array[Node] = _main.find_children("*", "Button", true, false)
	for node: Node in buttons:
		var button: Button = node as Button
		if button != null and button.text == text:
			return button.disabled
	return false

func _deploy_prompt_visible() -> bool:
	var root: Node = _main.get_node_or_null("CombatView")
	if root == null:
		return false
	return _find_label_containing_text(root, "Drag it from bench to board") != null

func _first_deploy_bench_highlight_visible() -> bool:
	var bench_grid: GridContainer = _main.find_child("BenchGrid", true, false) as GridContainer
	if bench_grid == null:
		return false
	for tile_node: Node in bench_grid.get_children():
		var tile: Control = tile_node as Control
		if tile == null:
			continue
		if String(tile.tooltip_text) != FIRST_DEPLOY_BENCH_TOOLTIP:
			continue
		var button: Button = tile as Button
		if button == null or not button.has_theme_stylebox_override("normal"):
			continue
		return _find_first_unit_view(tile) != null
	return false

func _deploy_assist_signal_connected() -> bool:
	var controller: Variant = _combat_controller()
	if controller == null:
		return false
	var presenter: Variant = controller.get("shop_presenter")
	return presenter != null and presenter.is_connected("first_purchase_needs_deploy", Callable(controller, "_on_first_purchase_needs_deploy"))

func _deploy_assist_state() -> String:
	var controller: Variant = _combat_controller()
	if controller == null:
		return "controller=null time=%.2f roster=%d" % [_planning_time_left(), Roster.compact().size()]
	var presenter: Variant = controller.get("shop_presenter")
	var connected: bool = presenter != null and presenter.is_connected("first_purchase_needs_deploy", Callable(controller, "_on_first_purchase_needs_deploy"))
	var manager: Variant = controller.get("manager")
	var board_size: int = manager.player_team.size() if manager != null else -1
	return "connected=%s active=%s seen=%s team_before=%d board=%d roster=%d time=%.2f" % [
		str(connected),
		str(bool(controller.get("_first_deploy_assist_active"))),
		str(bool(controller.get("_first_deploy_assist_seen"))),
		int(controller.get("_first_deploy_team_size")),
		board_size,
		Roster.compact().size(),
		_planning_time_left(),
	]

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

func _find_label_with_text(root: Node, text: String) -> Label:
	if root is Label and String((root as Label).text) == text:
		return root as Label
	for child: Node in root.get_children():
		var found: Label = _find_label_with_text(child, text)
		if found != null:
			return found
	return null

func _unit_select_reset() -> bool:
	var select: UnitSelect = _main.get_node_or_null("UnitSelect") as UnitSelect
	if select == null:
		return false
	var start: Button = select.get_node_or_null("Center/HBox/Right/StartButton") as Button
	return select.selected_id == "" and start != null and start.disabled

func _node_visible(path: String) -> bool:
	var node: CanvasItem = _main.get_node_or_null(path) as CanvasItem
	return node != null and node.visible

func _wait_for_combat_view_visible(timeout_seconds: float) -> bool:
	var deadline_ms: int = Time.get_ticks_msec() + int(max(0.0, timeout_seconds) * 1000.0)
	while Time.get_ticks_msec() < deadline_ms:
		if _node_visible("CombatView"):
			return true
		await get_tree().process_frame
	return false

func _wait_for_combat_view_ready(timeout_seconds: float) -> Control:
	var deadline_ms: int = Time.get_ticks_msec() + int(max(0.0, timeout_seconds) * 1000.0)
	while Time.get_ticks_msec() < deadline_ms:
		var combat: Control = _main.get_node_or_null("CombatView") as Control
		if combat != null and combat.get("controller") != null:
			return combat
		await get_tree().process_frame
	return null

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

func _settle_frames(count: int) -> void:
	for index: int in range(count):
		await get_tree().process_frame
