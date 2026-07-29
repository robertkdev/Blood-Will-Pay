extends Node


signal inventory_changed()
signal equipped_changed(unit)
signal action_log(text: String)

const MAX_SLOTS := 3

const ItemCatalog := preload("res://scripts/game/items/item_catalog.gd")
const CombineRules := preload("res://scripts/game/items/combine_rules.gd")
const Combiner := preload("res://scripts/game/items/combiner.gd")
const EquipService := preload("res://scripts/game/items/equip_service.gd")
const PhaseRules := preload("res://scripts/game/items/phase_rules.gd")

var _inventory: Dictionary = {}            # id -> count
var _equipped: Dictionary = {}             # Unit -> Array[String]
var _unit_refs: Dictionary = {}            # Unit -> WeakRef (for liveness checks)
var _equip_service: EquipService = null

const INVENTORY_COLUMNS := 6
const INVENTORY_MIN_ROWS := 3

var _inventory_slots: Array[String] = []

# DEV: starter inventory seeding (disabled by default)
# Toggle this on during development to auto‑populate inventory at startup.
@export var DEV_STARTER_INVENTORY_ENABLED: bool = false
# Array of [item_id: String, count: int]
@export var DEV_STARTER_INVENTORY: Array = [
	["hammer", 2],
	["crystal", 2],
	["wand", 2],
	["core", 2],
	["plate", 1],
	["veil", 1],
	["orb", 1],
	["spike", 1],
	["remover", 1],
]

func _ready() -> void:
	# Wire combiner providers to this autoload
	Combiner.configure(Callable(self, "get_equipped_ids"), Callable(self, "consume_components"))
	_equip_service = EquipService.new()
	_maybe_seed_dev_inventory()
	_ensure_inventory_slots()

func _exit_tree() -> void:
	_clear_runtime_state()
	Combiner.configure(Callable(), Callable())
	ItemCatalog.clear_cache()

func reset_run() -> void:
	_clear_runtime_state()
	_maybe_seed_dev_inventory()
	_ensure_inventory_slots()
	inventory_changed.emit()

func _clear_runtime_state() -> void:
	_inventory.clear()
	_equipped.clear()
	_unit_refs.clear()
	_inventory_slots.clear()
	if _equip_service != null and _equip_service.has_method("clear_all"):
		_equip_service.clear_all()

func add_to_inventory(id: String, n: int = 1) -> Dictionary:
	_cleanup_invalid_units()
	var res := {"ok": false, "reason": ""}
	var key := String(id).strip_edges()
	var cnt := int(n)
	if key == "" or cnt == 0:
		res.reason = "invalid_args"
		return res
	if ItemCatalog.get_def(key) == null:
		res.reason = "unknown_item"
		return res
	_inc_inventory(key, cnt)
	inventory_changed.emit()
	action_log.emit("+%d %s" % [cnt, key])
	res.ok = true
	res["count"] = int(_inventory.get(key, 0))
	return res

func equip(unit, id: String) -> Dictionary:
	_cleanup_invalid_units()
	var result := {"ok": false, "reason": ""}
	print("[Items] equip start unit=", (unit.name if unit and unit.has_method("get") else unit), " id=", id)
	if unit == null:
		result.reason = "no_unit"
		return result
	var key := String(id).strip_edges()
	if key == "":
		result.reason = "invalid_id"
		return result
	if not PhaseRules.can_equip():
		result.reason = "cannot_equip_in_phase"
		action_log.emit("Cannot equip items right now")
		return result
	var def = ItemCatalog.get_def(key)
	if def == null:
		result.reason = "unknown_item"
		return result
	if int(_inventory.get(key, 0)) <= 0:
		result.reason = "not_in_inventory"
		return result

	# Special: remover clears all items outside combat
	if key == "remover":
		if not PhaseRules.can_remove():
			result.reason = "cannot_remove_in_combat"
			action_log.emit("Cannot remove items during combat")
			return result
		if not _dec_inventory(key, 1):
			result.reason = "inventory_underflow"
			return result
		var rr := remove_all(unit)
		var uname: String = (unit.name if unit != null and unit.has_method("get") else "unit")
		action_log.emit("Removed %d item(s) from %s" % [int(rr.get("returned", 0)), str(uname)])
		print("[Items] remover used on ", uname, " -> ", rr)
		result.ok = true
		result["removed"] = int(rr.get("returned", 0))
		return result

	var eq: Array = _ensure_unit_array(unit)

	# Attempt auto-combine first when equipping a component (orderless, does not require temp slot)
	if String(def.type) == "component" and PhaseRules.can_combine():
		var combined_id: String = Combiner.try_combine_on_equip(unit, key)
		if combined_id != "":
			# Place the completed item; consumes components via consumer
			# Capacity is safe (2 -> 1 swap)
			eq.append(combined_id)
			_watch_unit(unit)
			if _equip_service:
				_equip_service.recompute_for(unit)
			equipped_changed.emit(unit)
			inventory_changed.emit() # consumed new component from inventory
			action_log.emit("Auto-combined to %s" % combined_id)
			print("[Items] auto-combined ", key, " -> ", combined_id, " on unit=", (unit.name if unit else "unit"))
			result.ok = true
			result["combined_id"] = combined_id
			return result

	# No combine: require capacity
	if eq.size() >= MAX_SLOTS:
		result.reason = "no_slot"
		action_log.emit("No empty item slots")
		print("[Items] equip blocked: no_slot for ", (unit.name if unit else "unit"))
		return result

	# Consume from inventory and equip
	if not _dec_inventory(key, 1):
		result.reason = "inventory_underflow"
		print("[Items] inventory_underflow id=", key)
		return result
	eq.append(key)
	_watch_unit(unit)
	if _equip_service:
		_equip_service.recompute_for(unit)
	equipped_changed.emit(unit)
	inventory_changed.emit()
	var uname2: String = (unit.name if unit != null and unit.has_method("get") else "unit")
	action_log.emit("Equipped %s on %s" % [key, str(uname2)])
	print("[Items] equipped id=", key, " on=", uname2)
	result.ok = true
	return result

func remove_all(unit) -> Dictionary:
	_cleanup_invalid_units()
	var result := {"ok": false, "returned": 0}
	if unit == null:
		result.ok = true
		return result
	var eq: Array = _equipped.get(unit, [])
	if eq is Array and eq.size() > 0:
		for id in eq:
			_inc_inventory(String(id), 1)
		_equipped.erase(unit)
		_unit_refs.erase(unit)
		if _equip_service:
			_equip_service.recompute_for(unit)
		equipped_changed.emit(unit)
		inventory_changed.emit()
		result["returned"] = int(eq.size())
	result.ok = true
	var uname3: String = (unit.name if unit != null and unit.has_method("get") else "unit")
	print("[Items] remove_all on=", uname3, " -> returned=", int(result.get("returned", 0)))
	return result

func force_set_equipped(unit, ids) -> Dictionary:
	_cleanup_invalid_units()
	var result := {"ok": false, "reason": ""}
	if unit == null:
		result.reason = "no_unit"
		return result
	var requested: Array = []
	if ids is Array:
		requested = ids
	elif typeof(ids) == TYPE_STRING:
		requested = [ids]
	elif ids != null:
		requested = [String(ids)]
	var deduped: Array[String] = []
	var seen: Dictionary = {}
	for raw in requested:
		if raw == null:
			continue
		var key := String(raw).strip_edges()
		if key == "":
			continue
		if not ItemCatalog.get_def(key):
			push_warning("Items.force_set_equipped: unknown item %s" % key)
			continue
		if seen.has(key):
			continue
		seen[key] = true
		deduped.append(key)
	if deduped.size() > MAX_SLOTS:
		deduped = deduped.slice(0, MAX_SLOTS)
	_equipped[unit] = deduped.duplicate()
	_watch_unit(unit)
	if _equip_service:
		_equip_service.recompute_for(unit)
	equipped_changed.emit(unit)
	result.ok = true
	result["count"] = deduped.size()
	result["items"] = deduped.duplicate()
	return result

func get_equipped_base_snapshot(unit) -> Dictionary:
	if _equip_service == null or not _equip_service.has_method("get_base_snapshot"):
		return {}
	return _equip_service.get_base_snapshot(unit)

func restore_equipped_snapshot(unit, ids: Array[String], base_snapshot: Dictionary) -> Dictionary:
	_cleanup_invalid_units()
	var result: Dictionary = {"ok": false, "reason": ""}
	if unit == null:
		result["reason"] = "no_unit"
		return result
	var restored_ids: Array[String] = []
	for raw_id: String in ids:
		var item_id: String = String(raw_id).strip_edges()
		if item_id == "" or ItemCatalog.get_def(item_id) == null:
			result["reason"] = "unknown_item"
			return result
		restored_ids.append(item_id)
	if restored_ids.size() > MAX_SLOTS:
		result["reason"] = "too_many_items"
		return result
	_equipped[unit] = restored_ids.duplicate()
	_watch_unit(unit)
	if _equip_service != null:
		_equip_service.restore_base_snapshot(unit, base_snapshot)
		_equip_service.recompute_for(unit)
	equipped_changed.emit(unit)
	result["ok"] = true
	return result

func get_equipped(unit) -> Array:
	_cleanup_invalid_units()
	var eq: Array = _equipped.get(unit, [])
	return (eq.duplicate() if eq is Array else [])

func get_equipped_ids(unit) -> Array:
	return get_equipped(unit)

func slot_count(_unit = null) -> int:
	return int(MAX_SLOTS)

func get_inventory_snapshot() -> Dictionary:
	# Return a shallow copy for UI display
	return _inventory.duplicate()

func restore_run_snapshot(inventory: Dictionary, inventory_slots: Array[String]) -> void:
	_clear_runtime_state()
	for raw_id: Variant in inventory.keys():
		var item_id: String = String(raw_id).strip_edges()
		var count: int = max(0, int(inventory[raw_id]))
		if item_id == "" or count <= 0 or ItemCatalog.get_def(item_id) == null:
			continue
		_inventory[item_id] = count
	_inventory_slots = inventory_slots.duplicate()
	_ensure_inventory_slots()
	inventory_changed.emit()

# Combine two components directly in inventory (no unit involved)
func try_combine_in_inventory(a: String, b: String, a_slot: int = -1, b_slot: int = -1, result_slot: int = -1) -> Dictionary:
	var res := {"ok": false, "reason": ""}
	if not PhaseRules.can_combine():
		res.reason = "cannot_combine_in_phase"
		return res
	var ia := String(a).strip_edges()
	var ib := String(b).strip_edges()
	if ia == "" or ib == "":
		res.reason = "invalid_args"
		return res
	if not ItemCatalog.is_component(ia) or not ItemCatalog.is_component(ib):
		res.reason = "not_components"
		return res
	var cid := CombineRules.completed_for(ia, ib)
	if cid == "":
		res.reason = "no_recipe"
		return res
	var need_a := 1
	var need_b := 1
	if ia == ib:
		need_a = 2
		need_b = 0
	var have_a := int(_inventory.get(ia, 0))
	var have_b := int(_inventory.get(ib, 0))
	if have_a < need_a or have_b < need_b:
		res.reason = "insufficient_components"
		return res
	_ensure_inventory_slots()
	var taken: Dictionary = {}
	var slots_a: Array[int] = []
	var slots_b: Array[int] = []
	var slot_a1 := _take_inventory_slot(ia, a_slot, taken)
	if slot_a1 == -1:
		res.reason = "insufficient_components"
		return res
	slots_a.append(slot_a1)
	if need_a > 1:
		var slot_a2 := _take_inventory_slot(ia, b_slot, taken)
		if slot_a2 == -1:
			slot_a2 = _take_inventory_slot(ia, -1, taken)
		if slot_a2 == -1:
			res.reason = "insufficient_components"
			return res
		slots_a.append(slot_a2)
	if need_b > 0:
		var slot_b1 := _take_inventory_slot(ib, b_slot, taken)
		if slot_b1 == -1:
			slot_b1 = _take_inventory_slot(ib, -1, taken)
		if slot_b1 == -1:
			res.reason = "insufficient_components"
			return res
		slots_b.append(slot_b1)
	if need_a > 0 and not _dec_inventory(ia, need_a, slots_a):
		res.reason = "inventory_underflow_a"
		return res
	if need_b > 0 and not _dec_inventory(ib, need_b, slots_b):
		res.reason = "inventory_underflow_b"
		return res
	var preferred: Array[int] = []
	if result_slot >= 0:
		preferred.append(result_slot)
	_inc_inventory(cid, 1, preferred)
	inventory_changed.emit()
	action_log.emit("Combined %s + %s -> %s" % [ia, ib, cid])
	print("[Items] combined in inventory: ", ia, " + ", ib, " -> ", cid)
	res.ok = true
	res["completed_id"] = cid
	return res

# Lifecycle helpers

func release_for(unit) -> void:
	if unit == null:
		return
	_equipped.erase(unit)
	_unit_refs.erase(unit)

func replace_unit(old_unit, new_unit) -> void:
	if old_unit == null or new_unit == null:
		return
	if not _equipped.has(old_unit):
		return
	var arr: Array = (_equipped[old_unit] as Array).duplicate()
	_equipped.erase(old_unit)
	_unit_refs.erase(old_unit)
	_equipped[new_unit] = arr
	_watch_unit(new_unit)
	equipped_changed.emit(new_unit)

# -- Combiner consumer/provider helpers --

func consume_components(unit, ids: Array) -> void:
	if unit == null or ids == null:
		return
	var eq: Array = _ensure_unit_array(unit)
	for raw in ids:
		var id := String(raw)
		if id == "":
			continue
		# Prefer removing from equipped (existing component)
		var idx := eq.find(id)
		if idx != -1:
			eq.remove_at(idx)
		else:
			# Otherwise consume from inventory (the new component being combined)
			_dec_inventory(id, 1)

	# Ensure unit is tracked and notify
	_watch_unit(unit)
	if _equip_service:
		_equip_service.recompute_for(unit)
	equipped_changed.emit(unit)

# -- Internals --

func _ensure_unit_array(unit) -> Array:
	if not _equipped.has(unit):
		_equipped[unit] = []
		_watch_unit(unit)
	return (_equipped[unit] as Array)

func _dec_inventory(id: String, n: int, slots: Array[int] = []) -> bool:
	var key := String(id)
	var need := int(n)
	if need <= 0:
		return true
	var have := int(_inventory.get(key, 0))
	if have < need:
		return false
	_inventory[key] = have - need
	if int(_inventory.get(key, 0)) <= 0:
		_inventory.erase(key)
	var remaining := need
	var used: Dictionary = {}
	if slots != null:
		for s in slots:
			if remaining <= 0:
				break
			if s >= 0 and s < _inventory_slots.size() and _inventory_slots[s] == key and not used.has(s):
				_inventory_slots[s] = ""
				used[s] = true
				remaining -= 1
	if remaining > 0:
		for idx in range(_inventory_slots.size()):
			if remaining <= 0:
				break
			if _inventory_slots[idx] == key and not used.has(idx):
				_inventory_slots[idx] = ""
				used[idx] = true
				remaining -= 1
	return remaining == 0

func _inc_inventory(id: String, n: int, preferred_slots: Array[int] = []) -> void:
	var key := String(id)
	var inc := int(n)
	if inc <= 0:
		return
	_inventory[key] = int(_inventory.get(key, 0)) + inc
	var remaining := inc
	if preferred_slots != null:
		for s in preferred_slots:
			if remaining <= 0:
				break
			if s < 0:
				continue
			_ensure_inventory_slots(s + 1)
			if _inventory_slots[s] == "":
				_inventory_slots[s] = key
				remaining -= 1
	while remaining > 0:
		var idx := _inventory_slots.find("")
		if idx == -1:
			_inventory_slots.append("")
			idx = _inventory_slots.size() - 1
		_inventory_slots[idx] = key
		remaining -= 1

func get_inventory_slots() -> Array[String]:
	_ensure_inventory_slots()
	return _inventory_slots.duplicate()

func swap_inventory_slots(a: int, b: int) -> void:
	var max_idx: int = max(a, b)
	_ensure_inventory_slots(max_idx + 1)
	if a < 0 or b < 0:
		return
	if a >= _inventory_slots.size() or b >= _inventory_slots.size():
		return
	if a == b:
		return
	var val_a := _inventory_slots[a]
	var val_b := _inventory_slots[b]
	if val_a == val_b:
		return
	_inventory_slots[a] = val_b
	_inventory_slots[b] = val_a
	inventory_changed.emit()

func combine_inventory_slots(src: int, dst: int) -> Dictionary:
	var res := {"ok": false}
	var max_idx: int = max(src, dst)
	_ensure_inventory_slots(max_idx + 1)
	if src < 0 or dst < 0:
		res.reason = "invalid_slot"
		return res
	if src >= _inventory_slots.size() or dst >= _inventory_slots.size():
		res.reason = "invalid_slot"
		return res
	var a_id := String(_inventory_slots[src])
	var b_id := String(_inventory_slots[dst])
	if a_id == "" or b_id == "":
		res.reason = "empty_slot"
		return res
	res = try_combine_in_inventory(a_id, b_id, src, dst, dst)
	return res

func _take_inventory_slot(id: String, preferred: int, taken: Dictionary) -> int:
	if preferred >= 0:
		_ensure_inventory_slots(preferred + 1)
		if preferred < _inventory_slots.size() and _inventory_slots[preferred] == id and not taken.has(preferred):
			taken[preferred] = true
			return preferred
	for idx in range(_inventory_slots.size()):
		if _inventory_slots[idx] == id and not taken.has(idx):
			taken[idx] = true
			return idx
	return -1

func _ensure_inventory_slots(min_slots: int = INVENTORY_COLUMNS * INVENTORY_MIN_ROWS) -> void:
	if min_slots < 0:
		min_slots = 0
	while _inventory_slots.size() < min_slots:
		_inventory_slots.append("")

func _watch_unit(unit) -> void:
	if unit == null:
		return
	# Keep a weakref to detect GC/freed refs (RefCounted)
	_unit_refs[unit] = weakref(unit)

func _cleanup_invalid_units() -> void:
	# Remove entries for units that are no longer valid (freed/replaced)
	var to_erase: Array = []
	for u in _equipped.keys():
		var wr: WeakRef = _unit_refs.get(u, null)
		if wr == null:
			continue
		if wr.get_ref() == null:
			to_erase.append(u)
	for dead in to_erase:
		_equipped.erase(dead)
		_unit_refs.erase(dead)

func _maybe_seed_dev_inventory() -> void:
	if not DEV_STARTER_INVENTORY_ENABLED:
		return
	if DEV_STARTER_INVENTORY == null:
		return
	for entry in DEV_STARTER_INVENTORY:
		var id := ""
		var cnt: int = 1
		if entry is Array and entry.size() >= 1:
			id = String(entry[0])
			if entry.size() >= 2:
				cnt = int(entry[1])
		elif entry is Dictionary:
			id = String(entry.get("id", ""))
			cnt = int(entry.get("count", 1))
		if id != "" and cnt != 0:
			add_to_inventory(id, cnt)
