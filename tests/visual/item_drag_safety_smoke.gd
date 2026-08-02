extends Node

const SMOKE_NAME: String = "ItemDragSafetySmoke"
const MAIN_SCENE: PackedScene = preload("res://scenes/Main.tscn")
const PLAYER_TEAM: Array[String] = ["mortem"]

var _main: Control = null
var _view: Control = null
var _manager: CombatManager = null
var _controller: RefCounted = null
var _failures: Array[String] = []
var _item_action_lines: Array[String] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_run")

func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	_main = MAIN_SCENE.instantiate() as Control
	add_child(_main)
	await _settle_frames(8)
	if _main.has_method("_on_start"):
		_main.call("_on_start")
	await _settle_frames(8)
	if _main.has_method("_on_unit_selected"):
		_main.call("_on_unit_selected", "mortem")
	_view = await _wait_for_combat_view(20.0)
	if _view == null:
		_fail("CombatView missing")
		_finish()
		return
	if _view.has_method("set_player_team_ids"):
		_view.call("set_player_team_ids", PLAYER_TEAM)
	if _view.has_method("_init_game"):
		_view.call("_init_game")
	await _settle_frames(18)

	_manager = _view.get("manager") as CombatManager
	_controller = _view.get("controller") as RefCounted
	if _manager == null or _controller == null:
		_fail("manager/controller missing")
		_finish()
		return
	if _manager.player_team.is_empty():
		_fail("player team missing")
		_finish()
		return
	var action_log_callable: Callable = Callable(self, "_on_item_action_log")
	if not Items.is_connected("action_log", action_log_callable):
		Items.connect("action_log", action_log_callable)
	var combat_started: bool = await _start_combat()
	_expect(combat_started, "opening fight should enter active combat before item checks")
	if not combat_started:
		_finish()
		return

	Items.add_to_inventory("hammer", 1)
	await _settle_frames(6)
	var hammer_card: ItemCard = _find_item_card("hammer")
	if hammer_card == null:
		_fail("hammer card missing")
		_finish()
		return
	var unit: Unit = _manager.player_team[0] as Unit
	var target_position: Vector2 = _first_combat_actor_center()
	if target_position.x < 0.0:
		_fail("combat hammer check needs a live player arena actor")
		_finish()
		return
	_drag_card_to_position(hammer_card, target_position)
	await _settle_frames(6)
	var equipped: Array = Items.get_equipped(unit)
	_expect(equipped.has("hammer"), "hammer should equip when released on a player actor during combat")

	Items.add_to_inventory("crystal", 1)
	await _settle_frames(6)
	var crystal_card: ItemCard = _find_item_card("crystal")
	if crystal_card == null:
		_fail("crystal card missing")
		_finish()
		return
	_drag_card_to_position(crystal_card, Vector2(-80.0, -80.0))
	await _settle_frames(6)
	_expect(_inventory_contains("crystal"), "invalid release should leave crystal in inventory")
	_expect(not bool(crystal_card.get("_dragging")), "invalid release should end the item drag")

	await _settle_frames(2)
	if not _combat_is_active():
		_fail("combat ended before the combat unit-drop check")
		_finish()
		return
	var combat_crystal_card: ItemCard = _find_item_card("crystal")
	var combat_actor_center: Vector2 = _first_combat_actor_center()
	if combat_crystal_card == null or combat_actor_center.x < 0.0:
		_fail("combat item check needs a crystal card and live player arena actor")
		_finish()
		return
	_expect(combat_crystal_card.can_drag_now(), "filled item cards should remain draggable during combat")
	_drag_card_to_position(combat_crystal_card, combat_actor_center)
	await _settle_frames(3)
	equipped = Items.get_equipped(unit)
	_expect(equipped == ["dagger"], "combat drop should combine hammer + crystal into equipped dagger")
	_expect(not _inventory_contains("crystal"), "combat unit-side combine should consume crystal inventory")

	Items.add_to_inventory("spike", 1)
	await _settle_frames(2)
	var spike_card: ItemCard = _find_item_card("spike")
	var enemy_actor_center: Vector2 = _first_enemy_actor_center()
	if spike_card == null or enemy_actor_center.x < 0.0:
		_fail("enemy rejection check needs a spike card and live enemy arena actor")
		_finish()
		return
	_expect(spike_card.can_drag_now(), "combat enemy-rejection card should be draggable")
	_drag_card_to_position(spike_card, enemy_actor_center)
	await _settle_frames(2)
	equipped = Items.get_equipped(unit)
	_expect(equipped == ["dagger"], "dropping on an enemy actor should not equip the nearby player unit")
	_expect(_inventory_contains("spike"), "enemy-targeted item drop should leave the item in inventory")

	Items.add_to_inventory("wand", 1)
	Items.add_to_inventory("orb", 1)
	await _settle_frames(3)
	if not _combat_is_active():
		_fail("combat ended before the inventory-combine check")
		_finish()
		return
	var wand_card: ItemCard = _find_item_card("wand")
	var orb_card: ItemCard = _find_item_card("orb")
	if wand_card == null or orb_card == null:
		_fail("combat inventory combine needs wand and orb cards")
		_finish()
		return
	_expect(wand_card.can_drag_now(), "inventory components should remain draggable during combat")
	_drag_card_to_position(wand_card, orb_card.get_global_rect().get_center())
	await _settle_frames(3)
	_expect(_inventory_contains("orb_on_a_stick"), "wand + orb should combine in inventory during combat")
	_expect(not _inventory_contains("wand") and not _inventory_contains("orb"), "combat inventory combine should consume both components")

	Items.add_to_inventory("remover", 1)
	await _settle_frames(3)
	if not _combat_is_active():
		_fail("combat ended before the remover-gating check")
		_finish()
		return
	var remover_card: ItemCard = _find_item_card("remover")
	combat_actor_center = _first_combat_actor_center()
	if remover_card == null or combat_actor_center.x < 0.0:
		_fail("combat remover check needs a remover card and live player arena actor")
		_finish()
		return
	_expect(remover_card.can_drag_now(), "remover card should be draggable so combat denial can provide feedback")
	_drag_card_to_position(remover_card, combat_actor_center)
	await _settle_frames(2)
	equipped = Items.get_equipped(unit)
	_expect(equipped == ["dagger"], "remover should not remove an equipped item during combat")
	_expect(_inventory_contains("remover"), "blocked combat remover should remain in inventory")
	_expect(_item_action_lines.has("Cannot remove items during combat"), "combat remover drop should reach the phase gate and emit denial feedback")
	_finish()

func _find_item_card(item_id: String) -> ItemCard:
	if _view == null:
		return null
	var grid: Node = _view.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ContentRow/LeftItemArea/ItemStorageGrid")
	if grid == null:
		return null
	for child: Node in grid.get_children():
		var card: ItemCard = child as ItemCard
		if card != null and String(card.item_id) == item_id:
			return card
	return null

func _first_board_unit_center() -> Vector2:
	if _controller == null:
		return Vector2.ZERO
	var placement: Variant = _controller.get("grid_placement")
	var helper: BoardGrid = _controller.get("player_grid_helper") as BoardGrid
	if placement == null or helper == null or not placement.has_method("get_player_views"):
		return Vector2.ZERO
	var player_views: Variant = placement.call("get_player_views")
	if not (player_views is Array) or (player_views as Array).is_empty():
		return Vector2.ZERO
	var view_entry: Variant = (player_views as Array)[0]
	var tile_idx: int = int(view_entry.tile_idx)
	return helper.get_center(tile_idx)

func _first_combat_actor_center() -> Vector2:
	if _controller == null or not _controller.has_method("get"):
		return Vector2(-1.0, -1.0)
	var arena_bridge: Variant = _controller.get("arena_bridge")
	if arena_bridge == null or not arena_bridge.has_method("get_player_actor"):
		return Vector2(-1.0, -1.0)
	var actor: Control = arena_bridge.call("get_player_actor", 0) as Control
	if actor == null or not is_instance_valid(actor) or not actor.visible:
		return Vector2(-1.0, -1.0)
	return actor.get_global_rect().get_center()

func _first_enemy_actor_center() -> Vector2:
	if _controller == null or not _controller.has_method("get"):
		return Vector2(-1.0, -1.0)
	var arena_bridge: Variant = _controller.get("arena_bridge")
	if arena_bridge == null or not arena_bridge.has_method("get_enemy_actor"):
		return Vector2(-1.0, -1.0)
	var actor: Control = arena_bridge.call("get_enemy_actor", 0) as Control
	if actor == null or not is_instance_valid(actor) or not actor.visible:
		return Vector2(-1.0, -1.0)
	return actor.get_global_rect().get_center()

func _combat_is_active() -> bool:
	return int(GameState.phase) == int(GameState.GamePhase.COMBAT) and bool(Economy.combat_active)

func _start_combat() -> bool:
	if _combat_is_active():
		return true
	if _view == null or not _view.has_method("_on_continue_pressed"):
		return false
	_view.call("_on_continue_pressed")
	for _frame_index: int in range(20):
		if int(GameState.phase) == int(GameState.GamePhase.COMBAT) and bool(Economy.combat_active):
			return true
		await get_tree().process_frame
	return false

func _drag_card_to_position(card: ItemCard, position: Vector2) -> void:
	card.call("_begin_drag_internal")
	card.set("_last_mouse_pos", position)
	card.call("_end_drag_internal")

func _inventory_contains(item_id: String) -> bool:
	var snapshot: Dictionary = Items.get_inventory_snapshot()
	return int(snapshot.get(item_id, 0)) > 0

func _on_item_action_log(text: String) -> void:
	_item_action_lines.append(text)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)

func _fail(message: String) -> void:
	if not _failures.has(message):
		_failures.append(message)

func _settle_frames(count: int) -> void:
	for _index: int in range(count):
		await get_tree().process_frame

func _wait_for_combat_view(timeout_seconds: float) -> Control:
	var deadline_ms: int = Time.get_ticks_msec() + int(max(0.0, timeout_seconds) * 1000.0)
	while Time.get_ticks_msec() < deadline_ms:
		var combat: Control = _main.get_node_or_null("CombatView") as Control
		if combat != null and combat.visible:
			return combat
		await get_tree().process_frame
	return null

func _finish() -> void:
	var action_log_callable: Callable = Callable(self, "_on_item_action_log")
	if get_tree().root.get_node_or_null("/root/Items") != null and Items.is_connected("action_log", action_log_callable):
		Items.disconnect("action_log", action_log_callable)
	if get_tree().root.get_node_or_null("/root/Items") != null:
		Items.reset_run()
	if get_tree().root.get_node_or_null("/root/Roster") != null and Roster.has_method("reset"):
		Roster.reset()
	if _view != null and is_instance_valid(_view) and _view.has_method("_teardown"):
		_view.call("_teardown")
	if get_tree().root.get_node_or_null("/root/Economy") != null and Economy.has_method("reset_run"):
		Economy.reset_run()
	if get_tree().root.get_node_or_null("/root/GameState") != null:
		GameState.set_phase(int(GameState.GamePhase.MENU))
	if _main != null and is_instance_valid(_main):
		remove_child(_main)
		_main.queue_free()
		_main = null
	if _failures.is_empty():
		print(SMOKE_NAME + ": OK")
		get_tree().quit(0)
		return
	for failure: String in _failures:
		push_error(SMOKE_NAME + ": " + failure)
	get_tree().quit(1)
