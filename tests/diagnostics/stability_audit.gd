extends Node

const MAIN_SCENE: PackedScene = preload("res://scenes/Main.tscn")
const BattleStateLib: Script = preload("res://scripts/game/combat/battle_state.gd")
const CombatEngineLib: Script = preload("res://scripts/game/combat/combat_engine.gd")
const SHOP_CONFIG: Script = preload("res://scripts/game/shop/shop_config.gd")

const RESULT_PATH: String = "user://stability_audit_result.json"
const TILE_SIZE: float = 64.0
const SMALL_BOUNDS: Rect2 = Rect2(0.0, 0.0, 640.0, 360.0)
const LARGE_BOUNDS: Rect2 = Rect2(0.0, 0.0, 1600.0, 900.0)
const RESET_CYCLES: int = 6

var _main: Control = null
var _failures: Array[String] = []
var _evidence: Dictionary[String, Variant] = {}
var _engine_victory_count: int = 0
var _engine_tie_count: int = 0
var _shop_error_count: int = 0
var _previous_time_scale: float = 1.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_run")

func _run() -> void:
	_previous_time_scale = Engine.time_scale
	Engine.time_scale = 1.0
	_run_engine_lifecycle_probe()
	await _run_main_lifecycle_probe()
	_run_large_board_probe()
	_evidence["save_load_continue"] = {
		"status": "N/A",
		"reason": "The authoritative revision exposes high-score persistence only; no run save/load/continue API or player-facing surface exists to exercise.",
	}
	await _finish()

func _run_engine_lifecycle_probe() -> void:
	var state: BattleState = BattleStateLib.new()
	state.reset()
	var player: Unit = _make_probe_unit("lifecycle_player", 100.0)
	var enemy: Unit = _make_probe_unit("lifecycle_enemy", 0.0)
	state.player_team.append(player)
	state.enemy_team.append(enemy)

	var engine: CombatEngine = CombatEngineLib.new()
	engine.deterministic_rolls = true
	var ability_system: Variant = engine.ability_system
	_engine_victory_count = 0
	_engine_tie_count = 0
	if not engine.is_connected("victory", Callable(self, "_on_engine_victory")):
		engine.victory.connect(_on_engine_victory)
	if not engine.is_connected("tie", Callable(self, "_on_engine_tie")):
		engine.tie.connect(_on_engine_tie)
	engine.configure(state, player, 1, Callable())
	engine.set_arena(TILE_SIZE, [Vector2(64.0, 180.0)], [Vector2(512.0, 180.0)], SMALL_BOUNDS)
	engine.start()
	engine.process(0.05)
	for _frame: int in range(4):
		engine.process(0.05)
	_expect(_engine_victory_count == 1, "engine emitted duplicate outcome before teardown: %d" % _engine_victory_count)
	_expect(engine.state != null, "configured engine lost state before teardown")
	var victory_connections_before: int = engine.get_signal_connection_list("victory").size()
	_expect(victory_connections_before == 1, "engine victory signal should have one audit listener, got %d" % victory_connections_before)
	if ability_system != null and ability_system.has_signal("ability_cast"):
		var ability_connections_before: int = ability_system.get_signal_connection_list("ability_cast").size()
		_expect(ability_connections_before == 1, "ability signal should have one engine listener, got %d" % ability_connections_before)

	engine.teardown()
	_expect(engine.state == null, "engine teardown did not clear state")
	for _frame_after_teardown: int in range(6):
		engine.process(0.05)
	engine.on_projectile_hit("player", 0, 0, 1, false)
	_expect(_engine_victory_count == 1, "freed-state calls emitted a late outcome")
	if ability_system != null and ability_system.has_signal("ability_cast"):
		var ability_connections_after: int = ability_system.get_signal_connection_list("ability_cast").size()
		_expect(ability_connections_after == 0, "engine teardown left an ability signal listener: %d" % ability_connections_after)
	engine.teardown()

	var second_state: BattleState = BattleStateLib.new()
	second_state.reset()
	var second_player: Unit = _make_probe_unit("lifecycle_player_again", 100.0)
	var second_enemy: Unit = _make_probe_unit("lifecycle_enemy_again", 0.0)
	second_state.player_team.append(second_player)
	second_state.enemy_team.append(second_enemy)
	engine.configure(second_state, second_player, 1, Callable())
	engine.set_arena(TILE_SIZE, [Vector2(64.0, 180.0)], [Vector2(512.0, 180.0)], SMALL_BOUNDS)
	engine.start()
	engine.process(0.05)
	_expect(_engine_victory_count == 2, "engine reconfigure did not produce exactly one new outcome: %d" % _engine_victory_count)
	_expect(engine.get_signal_connection_list("victory").size() == 1, "engine reconfigure duplicated external victory listeners")
	engine.teardown()
	second_state.reset()
	_evidence["engine_lifecycle"] = {
		"teardown_process_calls": 6,
		"outcomes_after_reconfigure": _engine_victory_count,
		"victory_connections_after_reconfigure": 1,
	}

func _run_main_lifecycle_probe() -> void:
	_main = MAIN_SCENE.instantiate() as Control
	if _main == null:
		_expect(false, "Main scene failed to instantiate for lifecycle probe")
		return
	get_tree().root.add_child(_main)
	await _settle_frames(3)
	var shop: Node = get_tree().root.get_node_or_null("Shop")
	if shop != null and shop.has_signal("error") and not shop.is_connected("error", Callable(self, "_on_shop_error")):
		shop.connect("error", _on_shop_error)
	_expect(_node_visible("TitlePage"), "Main lifecycle probe did not start on the title page")

	_main.call("_on_start")
	await _settle_frames(1)
	_start_with_starter()
	_main.call("request_new_run")
	await _settle_frames(3)
	_assert_run_reset("new run before deferred auto-start")

	_main.call("_on_start")
	await _settle_frames(1)
	_start_with_starter()
	_main.call("request_return_to_title")
	await _settle_frames(3)
	_assert_title_reset("return to title before deferred auto-start")

	for cycle_index: int in range(RESET_CYCLES):
		_main.call("_on_start")
		await _settle_frames(1)
		_start_with_starter()
		await _settle_frames(2)
		_main.call("request_new_run")
		await _settle_frames(2)
		_assert_run_reset("repeated reset cycle %d" % (cycle_index + 1))

	_main.call("_on_start")
	await _settle_frames(1)
	for menu_cycle: int in range(8):
		_main.call("_open_system_menu")
		_expect(_system_overlay_visible(), "system menu did not open on rapid cycle %d" % (menu_cycle + 1))
		_expect(get_tree().paused, "system menu did not pause on rapid cycle %d" % (menu_cycle + 1))
		_main.call("_close_system_menu")
		_expect(not _system_overlay_visible(), "system menu did not close on rapid cycle %d" % (menu_cycle + 1))
		_expect(not get_tree().paused, "system menu left the tree paused on rapid cycle %d" % (menu_cycle + 1))

	await _run_shop_pressure_probe()
	await _run_loss_recovery_probe()
	_start_with_starter()
	var combat_view: Node = _main.get_node_or_null("CombatView")
	if combat_view == null:
		_expect(false, "CombatView missing for deferred teardown probe")
	else:
		combat_view.call("_teardown")
		await _settle_frames(2)
		_expect(combat_view.get("controller") == null, "CombatView teardown did not clear controller")
		_expect(combat_view.get("manager") == null, "CombatView teardown did not clear manager")
		_main.call("request_return_to_title")
		await _settle_frames(2)
		_assert_title_reset("post-teardown return to title")
	_evidence["main_lifecycle"] = {
		"rapid_reset_cycles": RESET_CYCLES,
		"system_menu_cycles": 8,
		"rapid_shop_rerolls": 12,
		"loss_recovery_cycles": 2,
		"deferred_reset_probes": 2,
		"teardown_probe": true,
	}

func _run_large_board_probe() -> void:
	var state: BattleState = BattleStateLib.new()
	state.reset()
	var player_positions: Array[Vector2] = []
	var enemy_positions: Array[Vector2] = []
	for index: int in range(12):
		var player: Unit = _make_probe_unit("large_player_%d" % index, 100.0)
		var enemy: Unit = _make_probe_unit("large_enemy_%d" % index, 100.0)
		state.player_team.append(player)
		state.enemy_team.append(enemy)
		player_positions.append(Vector2(128.0 + float(index % 6) * 96.0, 180.0 + float(index / 6.0) * 128.0))
		enemy_positions.append(Vector2(900.0 + float(index % 6) * 96.0, 180.0 + float(index / 6.0) * 128.0))

	var engine: CombatEngine = CombatEngineLib.new()
	engine.abilities_enabled = false
	engine.deterministic_rolls = true
	engine.combat_timeout_s = 0.5
	engine.no_progress_timeout_s = 0.2
	_engine_tie_count = 0
	if not engine.is_connected("tie", Callable(self, "_on_engine_tie")):
		engine.tie.connect(_on_engine_tie)
	engine.configure(state, state.player_team[0], 1, Callable())
	engine.set_arena(TILE_SIZE, player_positions, enemy_positions, LARGE_BOUNDS)
	engine.start()
	var process_calls: int = 0
	for _frame: int in range(20):
		process_calls += 1
		engine.process(0.05)
		if _engine_tie_count > 0:
			break
	_expect(_engine_tie_count == 1, "large-board no-progress watchdog did not resolve exactly once")
	_expect(not state.battle_active, "large-board watchdog left combat active")
	engine.teardown()
	_evidence["large_board"] = {
		"player_units": 12,
		"enemy_units": 12,
		"process_calls": process_calls,
		"watchdog_outcomes": _engine_tie_count,
	}

func _start_with_starter() -> void:
	_start_with_starter_id("axiom")

func _start_with_starter_id(unit_id: String) -> void:
	if _main == null or not is_instance_valid(_main):
		_expect(false, "Main was invalid while starting a lifecycle run")
		return
	var select: Node = _main.get_node_or_null("UnitSelect")
	if select == null:
		_expect(false, "UnitSelect missing while starting a lifecycle run")
		return
	select.call("show_screen")
	select.call("_on_unit_button_pressed", null, unit_id, unit_id.capitalize())
	select.call("_on_StartButton_pressed")

func _run_shop_pressure_probe() -> void:
	var shop: Node = get_tree().root.get_node_or_null("Shop")
	if shop == null or not shop.has_method("reroll"):
		_evidence["shop_pressure"] = {"status": "N/A", "reason": "Shop autoload/reroll surface unavailable"}
		return
	var previous_scale: float = Engine.time_scale
	Engine.time_scale = 8.0
	_main.call("_on_start")
	await _settle_frames(1)
	_start_with_starter_id("bonko")
	var shop_ready: bool = await _wait_for_shop_after_win(30.0)
	_expect(shop_ready, "rapid shop pressure could not reach a post-fight shop")
	if shop_ready:
		var errors_before: int = _shop_error_count
		Economy.add_gold(100)
		for reroll_index: int in range(12):
			shop.call("reroll")
			await _settle_frames(1)
		var grid: GridContainer = _main.find_child("ShopGrid", true, false) as GridContainer
		if grid == null:
			_expect(false, "rapid shop pressure could not find ShopGrid")
		else:
			for card: Node in grid.get_children():
				if card.has_signal("pressed"):
					card.emit_signal("pressed")
			await _settle_frames(4)
		_expect(_shop_error_count == errors_before, "rapid shop pressure emitted %d shop errors" % (_shop_error_count - errors_before))
		_expect(int(GameState.phase) == int(GameState.GamePhase.PREVIEW), "rapid shop pressure left preview phase")
		_expect(not bool(Economy.combat_active), "rapid shop pressure started combat")
		_evidence["shop_pressure"] = {
			"status": "PASS",
			"rerolls": 12,
			"same_frame_card_presses": int(SHOP_CONFIG.SLOT_COUNT),
			"shop_errors": _shop_error_count - errors_before,
		}
		_main.call("request_new_run")
		await _settle_frames(2)
		_assert_run_reset("shop pressure cleanup")
	else:
		_evidence["shop_pressure"] = {"status": "FAIL", "rerolls": 0}
	Engine.time_scale = previous_scale

func _run_loss_recovery_probe() -> void:
	var previous_scale: float = Engine.time_scale
	Engine.time_scale = 8.0
	var recovered_cycles: int = 0
	for cycle_index: int in range(2):
		_main.call("_on_start")
		await _settle_frames(1)
		_start_with_starter_id("axiom")
		await _settle_frames(3)
		var combat_view: Node = _main.get_node_or_null("CombatView")
		var manager: CombatManager = combat_view.get("manager") as CombatManager if combat_view != null else null
		var engine: CombatEngine = manager.get_engine() as CombatEngine if manager != null else null
		_expect(engine != null, "loss recovery cycle %d did not create a combat engine" % (cycle_index + 1))
		if engine == null or manager == null:
			continue
		var player_team: Array[Unit] = manager.player_team
		_expect(not player_team.is_empty(), "loss recovery cycle %d had no player unit" % (cycle_index + 1))
		if player_team.is_empty():
			continue
		Economy.add_gold(-100)
		player_team[0].hp = 0
		manager.set_process(false)
		engine.process(0.05)
		var loss_ready: bool = await _wait_for_loss_overlay(5.0)
		_expect(loss_ready, "loss recovery cycle %d did not reach the loss overlay" % (cycle_index + 1))
		if not loss_ready:
			continue
		var loss_layer: Node = get_tree().root.get_node_or_null("LossOverlayLayer")
		var loss_screen: Node = loss_layer.get_child(0) if loss_layer != null and loss_layer.get_child_count() > 0 else null
		_expect(loss_screen != null and loss_screen.has_method("_on_new_game"), "loss recovery cycle %d missing dismissable loss screen" % (cycle_index + 1))
		if loss_screen == null or not loss_screen.has_method("_on_new_game"):
			continue
		loss_screen.call("_on_new_game")
		await _settle_frames(6)
		_assert_run_reset("loss recovery cycle %d" % (cycle_index + 1))
		recovered_cycles += 1
	Engine.time_scale = previous_scale
	_evidence["loss_recovery"] = {
		"cycles": recovered_cycles,
		"expected_cycles": 2,
		"production_defeat_path": true,
		"overlay_dismissal": "New Game",
	}

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
		if int(GameState.phase) == int(GameState.GamePhase.PREVIEW) and int(GameState.stage_in_chapter) >= 2:
			if Shop.state != null and Shop.state.offers.size() > 0:
				return true
	return false

func _on_shop_error(_code: String, _context: Dictionary) -> void:
	_shop_error_count += 1

func _assert_run_reset(label: String) -> void:
	var select: Node = _main.get_node_or_null("UnitSelect") if _main != null and is_instance_valid(_main) else null
	var combat: CanvasItem = _main.get_node_or_null("CombatView") as CanvasItem if _main != null and is_instance_valid(_main) else null
	var title: CanvasItem = _main.get_node_or_null("TitlePage") as CanvasItem if _main != null and is_instance_valid(_main) else null
	_expect(select != null and bool(select.visible), "%s did not show UnitSelect" % label)
	_expect(select == null or String(select.get("selected_id")) == "", "%s left a selected starter" % label)
	if select != null:
		var start: Button = select.get_node_or_null("Center/HBox/Right/StartButton") as Button
		_expect(start != null and start.disabled, "%s left Start Game enabled" % label)
	_expect(combat == null or not combat.visible, "%s left CombatView visible" % label)
	_expect(title == null or not title.visible, "%s left TitlePage visible" % label)
	_expect(int(GameState.phase) == int(GameState.GamePhase.MENU), "%s left GameState phase at %s" % [label, str(GameState.phase)])
	_expect(int(GameState.stage) == 1 and int(GameState.stage_in_chapter) == 1, "%s changed stage to %d:%d" % [label, int(GameState.chapter), int(GameState.stage_in_chapter)])
	_expect(not bool(Economy.combat_active), "%s left Economy combat_active" % label)
	_expect(Roster.compact().is_empty(), "%s left roster units after reset" % label)
	_expect(Items.get_inventory_snapshot().is_empty(), "%s left item inventory after reset" % label)
	_expect(get_tree().root.get_node_or_null("LossOverlayLayer") == null, "%s left a loss overlay" % label)

func _assert_title_reset(label: String) -> void:
	var title: CanvasItem = _main.get_node_or_null("TitlePage") as CanvasItem if _main != null and is_instance_valid(_main) else null
	var menu: CanvasItem = _main.get_node_or_null("TitleMenu") as CanvasItem if _main != null and is_instance_valid(_main) else null
	var select: CanvasItem = _main.get_node_or_null("UnitSelect") as CanvasItem if _main != null and is_instance_valid(_main) else null
	_expect(title != null and title.visible, "%s did not show TitlePage" % label)
	_expect(menu == null or not menu.visible, "%s left TitleMenu visible" % label)
	_expect(select == null or not select.visible, "%s left UnitSelect visible" % label)
	_expect(int(GameState.phase) == int(GameState.GamePhase.MENU), "%s left GameState out of MENU" % label)
	_expect(not bool(Economy.combat_active), "%s left Economy combat_active" % label)
	_expect(get_tree().root.get_node_or_null("LossOverlayLayer") == null, "%s left a loss overlay" % label)

func _system_overlay_visible() -> bool:
	if _main == null or not is_instance_valid(_main):
		return false
	var overlay: CanvasItem = _main.get_node_or_null("SystemMenuLayer/SystemMenuOverlay") as CanvasItem
	return overlay != null and overlay.visible

func _node_visible(path: String) -> bool:
	if _main == null or not is_instance_valid(_main):
		return false
	var node: CanvasItem = _main.get_node_or_null(path) as CanvasItem
	return node != null and node.visible

func _make_probe_unit(id: String, hp_value: float) -> Unit:
	var unit: Unit = Unit.new()
	unit.id = id
	unit.name = id
	unit.max_hp = int(max(1.0, hp_value))
	unit.hp = int(hp_value)
	unit.attack_damage = 0.0
	unit.attack_speed = 0.01
	unit.attack_range = 1
	unit.move_speed = 0.0
	unit.mana_max = 0
	unit.mana = 0
	unit.mana_start = 0
	unit.mana_regen = 0.0
	unit.ability_id = ""
	return unit

func _on_engine_victory(_stage: int) -> void:
	_engine_victory_count += 1

func _on_engine_tie(_stage: int) -> void:
	_engine_tie_count += 1

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

func _finish() -> void:
	Engine.time_scale = _previous_time_scale
	if _failures.is_empty():
		print("StabilityAudit: OK result=%s" % ProjectSettings.globalize_path(RESULT_PATH))
	else:
		for failure: String in _failures:
			push_error("StabilityAudit: " + failure)
	_write_result()
	_cleanup_main()
	await _settle_frames(6)
	await get_tree().create_timer(1.0).timeout
	get_tree().quit(1 if not _failures.is_empty() else 0)

func _write_result() -> void:
	var result: Dictionary[String, Variant] = {
		"status": "PASS" if _failures.is_empty() else "FAIL",
		"failures": _failures,
		"evidence": _evidence,
	}
	var file: FileAccess = FileAccess.open(RESULT_PATH, FileAccess.WRITE)
	if file == null:
		push_error("StabilityAudit: could not write %s" % ProjectSettings.globalize_path(RESULT_PATH))
		return
	file.store_string(JSON.stringify(result))
	file.close()

func _cleanup_main() -> void:
	get_tree().paused = false
	if _main != null and is_instance_valid(_main):
		if _main.has_method("_reset_run_state"):
			_main.call("_reset_run_state")
		var parent: Node = _main.get_parent()
		if parent != null:
			parent.remove_child(_main)
		_main.free()
		_main = null
	var loss_layer: Node = get_tree().root.get_node_or_null("LossOverlayLayer")
	if loss_layer != null:
		var overlay_parent: Node = loss_layer.get_parent()
		if overlay_parent != null:
			overlay_parent.remove_child(loss_layer)
		loss_layer.free()

func _settle_frames(count: int) -> void:
	for _frame: int in range(count):
		await get_tree().process_frame
