extends Object
class_name MirrorBoardStore

static var _snapshots_by_chapter: Dictionary = {}

static func clear_runtime() -> void:
	_snapshots_by_chapter.clear()

static func snapshot_runtime() -> Dictionary:
	return _snapshots_by_chapter.duplicate(true)

static func restore_runtime(snapshot: Dictionary) -> void:
	_snapshots_by_chapter.clear()
	for raw_key: Variant in snapshot.keys():
		var chapter: int = int(raw_key)
		var value: Variant = snapshot[raw_key]
		if chapter > 0 and value is Array:
			_snapshots_by_chapter[chapter] = (value as Array).duplicate(true)

static func capture_boss_board(ch: int, units: Array[Unit]) -> void:
	var c: int = max(1, int(ch))
	var captured: Array[Dictionary] = []
	for unit: Unit in units:
		if unit == null:
			continue
		captured.append(_snapshot_unit(unit))
	if not captured.is_empty():
		_snapshots_by_chapter[c] = captured

static func has_snapshot(ch: int) -> bool:
	var c: int = max(1, int(ch))
	var snapshots: Array = _snapshots_by_chapter.get(c, [])
	return not snapshots.is_empty()

static func snapshot_ids(ch: int) -> Array[String]:
	var out: Array[String] = []
	var c: int = max(1, int(ch))
	var snapshots: Array = _snapshots_by_chapter.get(c, [])
	for snapshot_value: Variant in snapshots:
		if not (snapshot_value is Dictionary):
			continue
		var snapshot: Dictionary = snapshot_value
		var unit_id: String = String(snapshot.get("id", "")).strip_edges()
		if unit_id != "":
			out.append(unit_id)
	return out

static func apply_snapshot_to_units(ch: int, units: Array) -> void:
	var c: int = max(1, int(ch))
	var snapshots: Array = _snapshots_by_chapter.get(c, [])
	var count: int = min(units.size(), snapshots.size())
	for i: int in range(count):
		var unit: Unit = units[i] as Unit
		var snapshot_value: Variant = snapshots[i]
		if unit == null or not (snapshot_value is Dictionary):
			continue
		_apply_snapshot(unit, snapshot_value as Dictionary)

static func _snapshot_unit(unit: Unit) -> Dictionary:
	return {
		"id": String(unit.id),
		"level": int(unit.level),
		"max_hp": int(unit.max_hp),
		"hp_regen": float(unit.hp_regen),
		"attack_damage": float(unit.attack_damage),
		"spell_power": float(unit.spell_power),
		"attack_speed": float(unit.attack_speed),
		"crit_chance": float(unit.crit_chance),
		"crit_damage": float(unit.crit_damage),
		"true_damage": float(unit.true_damage),
		"lifesteal": float(unit.lifesteal),
		"attack_range": int(unit.attack_range),
		"move_speed": float(unit.move_speed),
		"armor": float(unit.armor),
		"magic_resist": float(unit.magic_resist),
		"block_chance": float(unit.block_chance),
		"damage_reduction": float(unit.damage_reduction),
		"damage_reduction_flat": float(unit.damage_reduction_flat),
		"armor_pen_flat": float(unit.armor_pen_flat),
		"armor_pen_pct": float(unit.armor_pen_pct),
		"mr_pen_flat": float(unit.mr_pen_flat),
		"mr_pen_pct": float(unit.mr_pen_pct),
		"tenacity": float(unit.tenacity),
		"mana_max": int(unit.mana_max),
		"mana_start": int(unit.mana_start),
		"mana_regen": float(unit.mana_regen),
		"cast_speed": float(unit.cast_speed),
		"mana_gain_per_attack": int(unit.mana_gain_per_attack),
		"items": _equipped_items_for(unit),
	}

static func _apply_snapshot(unit: Unit, snapshot: Dictionary) -> void:
	_force_items(unit, _to_string_array(snapshot.get("items", [])))
	unit.level = int(snapshot.get("level", unit.level))
	unit.max_hp = max(1, int(snapshot.get("max_hp", unit.max_hp)))
	unit.hp = unit.max_hp
	unit.hp_regen = max(0.0, float(snapshot.get("hp_regen", unit.hp_regen)))
	unit.attack_damage = max(0.0, float(snapshot.get("attack_damage", unit.attack_damage)))
	unit.spell_power = max(0.0, float(snapshot.get("spell_power", unit.spell_power)))
	unit.attack_speed = clampf(float(snapshot.get("attack_speed", unit.attack_speed)), 0.01, 4.0)
	unit.crit_chance = clampf(float(snapshot.get("crit_chance", unit.crit_chance)), 0.0, 0.95)
	unit.crit_damage = max(1.0, float(snapshot.get("crit_damage", unit.crit_damage)))
	unit.true_damage = max(0.0, float(snapshot.get("true_damage", unit.true_damage)))
	unit.lifesteal = clampf(float(snapshot.get("lifesteal", unit.lifesteal)), 0.0, 0.9)
	unit.attack_range = max(1, int(snapshot.get("attack_range", unit.attack_range)))
	unit.move_speed = max(0.0, float(snapshot.get("move_speed", unit.move_speed)))
	unit.armor = max(0.0, float(snapshot.get("armor", unit.armor)))
	unit.magic_resist = max(0.0, float(snapshot.get("magic_resist", unit.magic_resist)))
	unit.block_chance = clampf(float(snapshot.get("block_chance", unit.block_chance)), 0.0, 1.0)
	unit.damage_reduction = clampf(float(snapshot.get("damage_reduction", unit.damage_reduction)), 0.0, 0.95)
	unit.damage_reduction_flat = max(0.0, float(snapshot.get("damage_reduction_flat", unit.damage_reduction_flat)))
	unit.armor_pen_flat = max(0.0, float(snapshot.get("armor_pen_flat", unit.armor_pen_flat)))
	unit.armor_pen_pct = clampf(float(snapshot.get("armor_pen_pct", unit.armor_pen_pct)), 0.0, 1.0)
	unit.mr_pen_flat = max(0.0, float(snapshot.get("mr_pen_flat", unit.mr_pen_flat)))
	unit.mr_pen_pct = clampf(float(snapshot.get("mr_pen_pct", unit.mr_pen_pct)), 0.0, 1.0)
	unit.tenacity = clampf(float(snapshot.get("tenacity", unit.tenacity)), 0.0, 0.95)
	unit.mana_max = max(0, int(snapshot.get("mana_max", unit.mana_max)))
	unit.mana_start = clampi(int(snapshot.get("mana_start", unit.mana_start)), 0, int(unit.mana_max))
	unit.mana = int(unit.mana_start)
	unit.mana_regen = max(0.0, float(snapshot.get("mana_regen", unit.mana_regen)))
	unit.cast_speed = max(0.1, float(snapshot.get("cast_speed", unit.cast_speed)))
	unit.mana_gain_per_attack = max(0, int(snapshot.get("mana_gain_per_attack", unit.mana_gain_per_attack)))

static func _equipped_items_for(unit: Unit) -> Array[String]:
	var out: Array[String] = []
	var items_node: Variant = _items_singleton()
	if items_node == null or not items_node.has_method("get_equipped"):
		return out
	var raw_items: Variant = items_node.call("get_equipped", unit)
	return _to_string_array(raw_items)

static func _force_items(unit: Unit, items: Array[String]) -> void:
	if unit == null or items.is_empty():
		return
	var items_node: Variant = _items_singleton()
	if items_node == null or not items_node.has_method("force_set_equipped"):
		return
	items_node.call("force_set_equipped", unit, items)

static func _items_singleton() -> Variant:
	var loop: MainLoop = Engine.get_main_loop()
	if loop == null or not loop.has_method("get_root"):
		return null
	var root: Window = loop.get_root()
	if root == null:
		return null
	return root.get_node_or_null("/root/Items")

static func _to_string_array(value: Variant) -> Array[String]:
	var out: Array[String] = []
	if value is Array:
		for entry in value:
			var item_id: String = String(entry).strip_edges()
			if item_id != "":
				out.append(item_id)
	elif value is PackedStringArray:
		for entry in value:
			var item_id2: String = String(entry).strip_edges()
			if item_id2 != "":
				out.append(item_id2)
	elif typeof(value) == TYPE_STRING:
		var single: String = String(value).strip_edges()
		if single != "":
			out.append(single)
	return out
