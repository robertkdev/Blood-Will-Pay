extends RefCounted
class_name RunSnapshotCoordinator

const UnitFactory := preload("res://scripts/unit_factory.gd")
const ItemCatalog := preload("res://scripts/game/items/item_catalog.gd")
const RosterCatalog := preload("res://scripts/game/progression/roster_catalog.gd")
const MirrorBoardStore := preload("res://scripts/game/progression/mirror_board_store.gd")

static func capture(controller: Variant) -> Dictionary:
	if controller == null or controller.manager == null:
		return {}
	var board_records: Array[Dictionary] = []
	for unit: Unit in controller.manager.player_team:
		board_records.append(_serialize_unit(unit))
	var bench_records: Array = []
	var roster_node: Node = _autoload("Roster")
	if roster_node != null:
		var live_bench_slots: Array = roster_node.get("bench_slots") as Array
		for unit: Unit in live_bench_slots:
			bench_records.append(_serialize_unit(unit) if unit != null else null)
	var placements: Array[int] = []
	if controller.grid_placement != null and controller.grid_placement.has_method("get_player_placements"):
		placements = _int_array(controller.grid_placement.call("get_player_placements"))
	var economy_node: Node = _autoload("Economy")
	var shop_node: Node = _autoload("Shop")
	var items_node: Node = _autoload("Items")
	var game_state_node: Node = _autoload("GameState")
	var inventory: Dictionary = {}
	var inventory_slots: Array[String] = []
	if items_node != null:
		if items_node.has_method("get_inventory_snapshot"):
			inventory = items_node.call("get_inventory_snapshot") as Dictionary
		if items_node.has_method("get_inventory_slots"):
			inventory_slots = _string_array(items_node.call("get_inventory_slots"))
	return {
		"snapshot_kind": "active_run",
		"phase": "preview",
		"game_state": {
			"chapter": int(game_state_node.get("chapter")) if game_state_node != null else 1,
			"stage_in_chapter": int(game_state_node.get("stage_in_chapter")) if game_state_node != null else 1,
		},
		"economy": economy_node.call("snapshot_run_record") if economy_node != null and economy_node.has_method("snapshot_run_record") else {},
		"shop": shop_node.call("snapshot_run_state") if shop_node != null and shop_node.has_method("snapshot_run_state") else {},
		"board": board_records,
		"board_placements": placements,
		"bench": bench_records,
		"roster_max_team_size": int(roster_node.get("max_team_size")) if roster_node != null else 1,
		"inventory": inventory,
		"inventory_slots": inventory_slots,
		"roster_catalog": RosterCatalog.snapshot_runtime(),
		"mirror_boards": MirrorBoardStore.snapshot_runtime(),
		"planning_time_left": float(controller.parent.get("planning_time_left")) if controller.parent != null else 0.0,
	}

static func restore(controller: Variant, snapshot: Dictionary) -> Dictionary:
	if controller == null or controller.manager == null:
		return {"ok": false, "error": "CONTROLLER_NOT_READY"}
	var validation: Dictionary = _validate_restore_payload(controller, snapshot)
	if not bool(validation.get("ok", false)):
		return validation
	var board_records: Array = snapshot.get("board", []) as Array
	var bench_records: Array = snapshot.get("bench", []) as Array
	var board_build: Dictionary = _prebuild_units(board_records, false)
	if not bool(board_build.get("ok", false)):
		return board_build
	var bench_build: Dictionary = _prebuild_units(bench_records, true)
	if not bool(bench_build.get("ok", false)):
		return bench_build
	var board_units: Array[Unit] = []
	for raw_board_unit: Variant in (board_build.get("units", []) as Array):
		board_units.append(raw_board_unit as Unit)
	var bench_units: Array = bench_build.get("units", []) as Array
	var game_state_node: Node = _autoload("GameState")
	var economy_node: Node = _autoload("Economy")
	var shop_node: Node = _autoload("Shop")
	var items_node: Node = _autoload("Items")
	var roster_node: Node = _autoload("Roster")
	var roster_catalog_value: Variant = snapshot.get("roster_catalog", {})
	if roster_catalog_value is Dictionary:
		RosterCatalog.restore_runtime(roster_catalog_value as Dictionary)
	var mirror_value: Variant = snapshot.get("mirror_boards", {})
	if mirror_value is Dictionary:
		MirrorBoardStore.restore_runtime(mirror_value as Dictionary)
	var game_state_data: Dictionary = snapshot.get("game_state", {}) as Dictionary
	game_state_node.call(
		"set_chapter_and_stage",
		max(1, int(game_state_data.get("chapter", 1))),
		max(1, int(game_state_data.get("stage_in_chapter", 1)))
	)
	economy_node.call("restore_run_record", snapshot.get("economy", {}) as Dictionary)
	shop_node.call("restore_run_state", snapshot.get("shop", {}) as Dictionary)
	items_node.call(
		"restore_run_snapshot",
		snapshot.get("inventory", {}) as Dictionary,
		_string_array(snapshot.get("inventory_slots", []))
	)
	roster_node.call("reset", false)
	controller.manager.player_team.clear()
	controller.manager.player_team.append_array(board_units)
	var restored_bench_slots: Array = roster_node.get("bench_slots") as Array
	for index: int in range(bench_units.size()):
		restored_bench_slots[index] = bench_units[index]
	roster_node.set(
		"max_team_size",
		max(0, int(snapshot.get("roster_max_team_size", int(roster_node.get("max_team_size")))))
	)
	for board_index: int in range(board_units.size()):
		_restore_unit_items(board_units[board_index], board_records[board_index] as Dictionary, items_node)
	for bench_index: int in range(bench_units.size()):
		var restored_bench_unit: Unit = bench_units[bench_index] as Unit
		if restored_bench_unit != null:
			_restore_unit_items(restored_bench_unit, bench_records[bench_index] as Dictionary, items_node)
	roster_node.emit_signal("bench_changed")
	if controller.grid_placement != null and controller.grid_placement.has_method("set_player_placements"):
		controller.grid_placement.call(
			"set_player_placements",
			controller.manager.player_team,
			_int_array(snapshot.get("board_placements", []))
		)
	if game_state_node != null:
		controller.manager.stage = int(game_state_node.get("stage"))
	controller.manager.setup_stage_preview()
	controller.refresh_all_views()
	game_state_node.call("set_phase", 1)
	if controller.parent != null:
		var current_planning_time: float = float(controller.parent.get("planning_time_left"))
		controller.parent.set("planning_time_left", max(0.0, float(snapshot.get("planning_time_left", current_planning_time))))
	if controller.economy_ui != null:
		controller.economy_ui.refresh()
	controller._update_stage_label()
	controller._update_board_status()
	return {"ok": true}

static func _serialize_unit(unit: Unit) -> Dictionary:
	if unit == null:
		return {}
	var items_node: Node = _autoload("Items")
	var equipped: Array[String] = []
	if items_node != null and items_node.has_method("get_equipped"):
		equipped = _string_array(items_node.call("get_equipped", unit))
	var item_base: Dictionary = {}
	if items_node != null and items_node.has_method("get_equipped_base_snapshot"):
		item_base = items_node.call("get_equipped_base_snapshot", unit) as Dictionary
	return {
		"id": unit.id,
		"level": unit.level,
		"purchase_value": unit.purchase_value,
		"market_package_kind": unit.market_package_kind,
		"capital_charter_id": unit.capital_charter_id,
		"ascension_path_id": unit.ascension_path_id,
		"targeting_mode_override": unit.targeting_mode_override,
		"items": equipped,
		"item_base": item_base,
	}

static func _deserialize_unit(record: Dictionary) -> Unit:
	var unit_id: String = String(record.get("id", "")).strip_edges()
	if unit_id == "":
		return null
	var unit: Unit = UnitFactory.spawn_at_level(unit_id, max(1, int(record.get("level", 1))))
	if unit == null:
		return null
	unit.purchase_value = max(0, int(record.get("purchase_value", unit.cost)))
	unit.market_package_kind = String(record.get("market_package_kind", "standard"))
	unit.capital_charter_id = String(record.get("capital_charter_id", ""))
	unit.ascension_path_id = String(record.get("ascension_path_id", ""))
	unit.targeting_mode_override = String(record.get("targeting_mode_override", ""))
	return unit

static func _restore_unit_items(unit: Unit, record: Dictionary, items_node: Node) -> void:
	var item_base_value: Variant = record.get("item_base", {})
	var item_base: Dictionary = {}
	if item_base_value is Dictionary:
		item_base = item_base_value as Dictionary
	items_node.call(
		"restore_equipped_snapshot",
		unit,
		_string_array(record.get("items", [])),
		item_base
	)

static func _validate_restore_payload(controller: Variant, snapshot: Dictionary) -> Dictionary:
	var phase: String = String(snapshot.get("phase", "")).to_lower()
	if phase != "preview" and phase != "post_combat":
		return {"ok": false, "error": "INVALID_RESUME_PHASE"}
	var required: Array[String] = ["game_state", "economy", "shop", "board", "bench", "inventory"]
	for key: String in required:
		if not snapshot.has(key):
			return {"ok": false, "error": "MISSING_SECTION", "section": key}
	if not (snapshot["game_state"] is Dictionary) or not (snapshot["economy"] is Dictionary) or not (snapshot["shop"] is Dictionary):
		return {"ok": false, "error": "INVALID_SECTION_TYPE"}
	if not (snapshot["board"] is Array) or not (snapshot["bench"] is Array) or not (snapshot["inventory"] is Dictionary):
		return {"ok": false, "error": "INVALID_SECTION_TYPE"}
	if (snapshot["board"] as Array).is_empty():
		return {"ok": false, "error": "EMPTY_BOARD"}
	var roster_node: Node = _autoload("Roster")
	var items_node: Node = _autoload("Items")
	var economy_node: Node = _autoload("Economy")
	var shop_node: Node = _autoload("Shop")
	var game_state_node: Node = _autoload("GameState")
	if roster_node == null or items_node == null or economy_node == null or shop_node == null or game_state_node == null:
		return {"ok": false, "error": "MISSING_AUTOLOAD"}
	if not items_node.has_method("restore_run_snapshot") or not items_node.has_method("restore_equipped_snapshot"):
		return {"ok": false, "error": "ITEM_RESTORE_UNAVAILABLE"}
	var live_bench_slots: Array = roster_node.get("bench_slots") as Array
	if (snapshot["bench"] as Array).size() > live_bench_slots.size():
		return {"ok": false, "error": "BENCH_TOO_LARGE"}
	var placements: Array[int] = _int_array(snapshot.get("board_placements", []))
	if placements.size() != (snapshot["board"] as Array).size():
		return {"ok": false, "error": "PLACEMENT_COUNT_MISMATCH"}
	var occupied: Dictionary = {}
	var tile_count: int = controller.grid_placement.player_tiles.size() if controller.grid_placement != null else 0
	for tile_index: int in placements:
		if tile_index < 0 or tile_index >= tile_count or occupied.has(tile_index):
			return {"ok": false, "error": "INVALID_BOARD_PLACEMENT"}
		occupied[tile_index] = true
	return {"ok": true}

static func _prebuild_units(records: Array, allow_null: bool) -> Dictionary:
	var units: Array = []
	for raw_record: Variant in records:
		if raw_record == null and allow_null:
			units.append(null)
			continue
		if not raw_record is Dictionary:
			return {"ok": false, "error": "INVALID_UNIT_RECORD"}
		var record: Dictionary = raw_record as Dictionary
		var items: Array[String] = _string_array(record.get("items", []))
		if items.size() > 3:
			return {"ok": false, "error": "TOO_MANY_UNIT_ITEMS"}
		for item_id: String in items:
			if ItemCatalog.get_def(item_id) == null:
				return {"ok": false, "error": "UNKNOWN_ITEM", "item_id": item_id}
		var unit: Unit = _deserialize_unit(record)
		if unit == null:
			return {"ok": false, "error": "UNKNOWN_UNIT", "unit_id": String(record.get("id", ""))}
		units.append(unit)
	return {"ok": true, "units": units}

static func _autoload(autoload_name: String) -> Node:
	var loop: MainLoop = Engine.get_main_loop()
	if loop == null or not loop.has_method("get_root"):
		return null
	var root: Window = loop.get_root()
	return root.get_node_or_null("/root/%s" % autoload_name) if root != null else null

static func _string_array(value: Variant) -> Array[String]:
	var output: Array[String] = []
	if value is Array or value is PackedStringArray:
		for entry: Variant in value:
			output.append(String(entry))
	return output

static func _int_array(value: Variant) -> Array[int]:
	var output: Array[int] = []
	if value is Array or value is PackedInt32Array or value is PackedInt64Array:
		for entry: Variant in value:
			output.append(int(entry))
	return output
