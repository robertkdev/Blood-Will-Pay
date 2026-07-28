extends RefCounted
class_name ItemDragRouter

const Debug := preload("res://scripts/util/debug.gd")
const COMBAT_ACTOR_DROP_PADDING: float = 16.0

var view: Control
var grid_placement
var player_grid_helper: BoardGrid
var bench_grid_helper: BoardGrid
var item_grid_helper: BoardGrid = null
var combat_arena_helper: BoardGrid = null

func configure(_view: Control, _grid_placement, _player_grid_helper: BoardGrid, _bench_grid_helper: BoardGrid) -> void:
	view = _view
	grid_placement = _grid_placement
	player_grid_helper = _player_grid_helper
	bench_grid_helper = _bench_grid_helper
	var arena_control: Control = null
	if view != null:
		arena_control = view.get("arena_container") as Control
	if arena_control == null and view != null:
		arena_control = view.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ArenaContainer") as Control
	if arena_control != null:
		combat_arena_helper = BoardGrid.new()
		var arena_tiles: Array[Control] = [arena_control]
		combat_arena_helper.configure(arena_tiles, 1, 1)

func teardown() -> void:
	view = null
	grid_placement = null
	player_grid_helper = null
	bench_grid_helper = null
	item_grid_helper = null
	combat_arena_helper = null

func attach_card(card: Node) -> void:
	if card == null:
		return
	# Expect DragAndDroppable API
	if card.has_method("set_drop_targets"):
		var targets: Array[BoardGrid] = []
		if player_grid_helper != null:
			targets.append(player_grid_helper)
		if bench_grid_helper != null:
			targets.append(bench_grid_helper)
		if item_grid_helper != null:
			targets.append(item_grid_helper)
		if combat_arena_helper != null:
			targets.append(combat_arena_helper)
		card.set_drop_targets(targets)
	# Connect to drop signal once
	var sig: StringName = &"dropped_on_target"
	# In Godot 4, connect expects a Callable; bind the card as extra arg
	var drop_callable: Callable = Callable(self, "_on_card_dropped").bind(card)
	if not card.is_connected(sig, drop_callable):
		card.connect(sig, drop_callable)


func _on_card_dropped(grid: Variant, tile_idx: int, card: Variant) -> void:
	if grid == null or tile_idx < 0 or card == null:
		return
	var iid: String = _item_id_for_card(card)
	if iid == "":
		return
	# Handle inventory-to-inventory combination BEFORE resolving a unit.
	if grid == item_grid_helper:
		var inventory_items: Node = _items_singleton()
		if inventory_items == null:
			return
		var src_idx: int = -1
		if card.has_method("get_slot_index"):
			src_idx = int(card.get_slot_index())
		if src_idx == -1:
			return
		if src_idx == tile_idx:
			return
		var target_ctrl: Control = item_grid_helper.tile_at(tile_idx)
		var target_id: String = _item_id_for_card(target_ctrl)
		var did_combine: bool = false
		if target_id != "" and inventory_items.has_method("combine_inventory_slots"):
			var cres: Variant = inventory_items.combine_inventory_slots(src_idx, tile_idx)
			if cres is Dictionary and bool(cres.get("ok", false)):
				did_combine = true
		if did_combine:
			return
		if inventory_items.has_method("swap_inventory_slots"):
			inventory_items.swap_inventory_slots(src_idx, tile_idx)
		return
	# Otherwise, resolve the unit at the drop location on a board grid.
	var unit: Unit = _resolve_unit(grid, tile_idx, card)
	if unit == null:
		return
	# Route to Items service (robustly resolve the autoload/node)
	var items_node: Node = _items_singleton()
	if items_node == null:
		return
	var res: Variant = null
	if items_node.has_method("equip"):
		res = items_node.equip(unit, iid)
	else:
		res = items_node.call_deferred("equip", unit, iid)
	if res is Dictionary and not bool(res.get("ok", false)):
		var failure_reason: String = String(res.get("reason", ""))
		if failure_reason not in ["cannot_remove_in_combat", "no_slot", "not_in_inventory"]:
			push_warning("Item equip failed: %s" % str(res))

func _resolve_unit(grid: Variant, tile_idx: int, card: Variant = null) -> Unit:
	if grid == combat_arena_helper:
		if not _is_combat_phase():
			return null
		return _resolve_combat_player_unit(_drop_position_for_card(card))
	if grid == player_grid_helper:
		if _is_combat_phase():
			return _resolve_combat_player_unit(_drop_position_for_card(card))
		# Find unit by tile index in player views
		if grid_placement != null and grid_placement.has_method("get_player_views"):
			var pviews: Variant = grid_placement.get_player_views()
			if pviews is Array:
				for v: Variant in pviews:
					if v != null and int(v.tile_idx) == int(tile_idx):
						return v.unit
	if grid == bench_grid_helper:
		# Bench slots map 1:1 with grid indices
		if Engine.has_singleton("Roster"):
			return Roster.get_slot(int(tile_idx))
		# Fallback: attempt to read bench array directly
		if view and view.has_node("/root/Roster"):
			var roster_node: Node = view.get_node("/root/Roster")
			if roster_node and roster_node.has_method("get_slot"):
				return roster_node.get_slot(int(tile_idx))
		return null
	return null

func _drop_position_for_card(card: Variant) -> Vector2:
	if card != null and card.has_method("get"):
		var release_position: Variant = card.get("_last_mouse_pos")
		if release_position is Vector2:
			return Vector2(release_position)
	if card is Control:
		return (card as Control).get_global_rect().get_center()
	return Vector2(-1000000.0, -1000000.0)

func _resolve_combat_player_unit(drop_position: Vector2) -> Unit:
	if view == null:
		return null
	var controller_value: Variant = view.get("controller")
	if controller_value == null or not controller_value.has_method("get"):
		return null
	var arena_bridge_value: Variant = controller_value.get("arena_bridge")
	if arena_bridge_value == null or not arena_bridge_value.has_method("get_player_actor") or not arena_bridge_value.has_method("get_enemy_actor"):
		return null
	var manager: CombatManager = view.get("manager") as CombatManager
	if manager == null:
		return null
	var closest_unit: Unit = null
	var closest_distance_squared: float = INF
	for index: int in range(manager.player_team.size()):
		var actor: Control = arena_bridge_value.call("get_player_actor", index) as Control
		if actor == null or not is_instance_valid(actor) or not actor.visible:
			continue
		var actor_unit: Unit = actor.get("unit") as Unit
		if actor_unit == null:
			continue
		var actor_rect: Rect2 = actor.get_global_rect()
		if not actor_rect.grow(COMBAT_ACTOR_DROP_PADDING).has_point(drop_position):
			continue
		var distance_squared: float = drop_position.distance_squared_to(actor_rect.get_center())
		if distance_squared < closest_distance_squared:
			closest_distance_squared = distance_squared
			closest_unit = actor_unit
	# Enemy actors compete for the same pointer hit. If an enemy is the closest
	# visible actor, reject the drop instead of equipping an overlapping ally.
	for index: int in range(manager.enemy_team.size()):
		var enemy_actor: Control = arena_bridge_value.call("get_enemy_actor", index) as Control
		if enemy_actor == null or not is_instance_valid(enemy_actor) or not enemy_actor.visible:
			continue
		var enemy_rect: Rect2 = enemy_actor.get_global_rect()
		if not enemy_rect.grow(COMBAT_ACTOR_DROP_PADDING).has_point(drop_position):
			continue
		var enemy_distance_squared: float = drop_position.distance_squared_to(enemy_rect.get_center())
		if enemy_distance_squared <= closest_distance_squared:
			closest_distance_squared = enemy_distance_squared
			closest_unit = null
	return closest_unit

func _is_combat_phase() -> bool:
	var game_state: Node = null
	if view != null and view.get_tree() != null:
		game_state = view.get_tree().root.get_node_or_null("/root/GameState")
	if game_state == null:
		var tree: SceneTree = Engine.get_main_loop() as SceneTree
		if tree != null:
			game_state = tree.root.get_node_or_null("/root/GameState")
	return game_state != null and int(game_state.get("phase")) == int(GameState.GamePhase.COMBAT)

func _items_singleton() -> Node:
	if Engine.has_singleton("Items"):
		return Items
	var root_node: Node = null
	if view and view.has_method("get_tree"):
		var tree: SceneTree = view.get_tree()
		if tree != null:
			root_node = tree.root
	if root_node == null:
		var ml: SceneTree = Engine.get_main_loop() as SceneTree
		if ml != null:
			root_node = ml.root
	if root_node and root_node.has_node("/root/Items"):
		return root_node.get_node("/root/Items")
	return null

func set_item_grid(helper: BoardGrid) -> void:
	item_grid_helper = helper

func _item_id_for_card(card: Variant) -> String:
	if card == null:
		return ""
	if card.has_method("get_item_id"):
		return String(card.get_item_id())
	if card.has_method("get"):
		return String(card.get("item_id"))
	return ""
