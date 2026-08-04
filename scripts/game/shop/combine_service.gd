extends RefCounted
class_name CombineService

const UnitScaler := preload("res://scripts/game/units/unit_scaler.gd")

var _roster
var _get_team: Callable = Callable()
var _remove_from_board_cb: Callable = Callable()

func configure(roster) -> void:
	_roster = roster

func clear_runtime() -> void:
	_roster = null
	_get_team = Callable()
	_remove_from_board_cb = Callable()

func set_team_provider(cb: Callable) -> void:
	# Supplies the current on-board team (Array[Unit]) when available
	_get_team = cb if cb != null else Callable()

func set_remove_from_board(cb: Callable) -> void:
	# Callback to remove a specific Unit from the on-board team.
	# Signature: func(unit: Unit) -> bool
	_remove_from_board_cb = cb if cb != null else Callable()

func combine() -> Array:
	# Scan bench (and optionally board) for three-of-a-kind (same id and level).
	# Promote one copy by +1 level (max 4), remove two others. Repeat while possible.
	var results: Array = []
	var bench_count: int = _bench_size()
	if bench_count <= 0 and not _has_team():
		return results
	# Build initial groups including board when available
	var groups: Dictionary = _build_groups()
	var changed: bool = true
	while changed:
		changed = false
		var match_key := _find_group_with_at_least(groups, 3)
		if match_key == "":
			break
		var entries: Array = groups[match_key]
		# Choose kept entry (prefer on-board unit so it upgrades in place)
		var kept = _pick_kept(entries)
		var id_level: Array = match_key.split("#")
		var id: String = String(id_level[0])
		var level: int = int(id_level[1])
		if level >= 4:
			# No promotion beyond level 4; drop this group to avoid infinite loop
			groups.erase(match_key)
			continue
		var u: Unit = kept.get("unit")
		if u == null or String(u.id) != id or int(u.level) != level:
			groups = _build_groups()
			continue
		_promote_one_level(u)
		# Persist promotion (bench unit updated via set_slot; board unit left in-place)
		if kept.get("kind") == "bench":
			var ks: int = int(kept.get("index", -1))
			if ks >= 0:
				_roster.set_slot(ks, u)
		# Prepare to consume two others, preferring bench units first
		var consumed: Array = _pick_consumed(entries, kept, 2)
		var consumed_slots: Array = []
		# Capture items from consumed units first so none are lost
		var items_to_transfer: Array[String] = []
		if _has_items():
			for c_pre in consumed:
				var cu_pre: Unit = c_pre.get("unit")
				if cu_pre != null:
					var eq_list: Array = _get_equipped_list(cu_pre)
					for iid in eq_list:
						items_to_transfer.append(String(iid))
		# Now remove consumed units from bench/board
		for c in consumed:
			var kind: String = String(c.get("kind", ""))
			if kind == "bench":
				var idx: int = int(c.get("index", -1))
				if idx >= 0:
					_roster.set_slot(idx, null)
					consumed_slots.append(idx)
			elif kind == "board":
				var cu: Unit = c.get("unit")
				if cu != null and _remove_from_board_cb.is_valid():
					var ok: bool = bool(_remove_from_board_cb.call(cu))
					if ok:
						consumed_slots.append(-1) # -1 to represent non-bench removal
		# Return consumed items to inventory explicitly (safety) and then equip onto kept up to capacity
		if _has_items():
			for c2 in consumed:
				var cu2: Unit = c2.get("unit")
				if cu2 != null:
					_items_remove_all(cu2)
			# Equip onto kept up to max slots
			_equip_onto(u, items_to_transfer)
		results.append({
			"id": id,
			"from_level": level,
			"to_level": int(u.level),
			"kept_kind": kept.get("kind"),
			"kept_index": kept.get("index", -1),
			"consumed": consumed_slots,
		})
		# Rebuild groups after mutation and loop again (chained promotions allowed)
		groups = _build_groups()
		changed = true
	return results

func _bench_size() -> int:
	if _roster != null and _roster.has_method("slot_count"):
		return int(_roster.slot_count())
	elif Engine.has_singleton("Roster"):
		return int(Roster.slot_count())
	return 0

func _build_groups() -> Dictionary:
	# Returns: { key -> Array[ { kind: "bench"|"board", index: int, unit: Unit } ] }
	var groups: Dictionary = {}
	var n: int = _bench_size()
	for i in range(n):
		var u: Unit = _roster.get_slot(i) if _roster != null else (Roster.get_slot(i) if Engine.has_singleton("Roster") else null)
		if u == null:
			continue
		var id := String(u.id)
		var lv := int(u.level)
		if id == "":
			continue
		var key := id + "#" + str(lv)
		if not groups.has(key):
			groups[key] = []
		groups[key].append({ "kind": "bench", "index": i, "unit": u })
	# Add board team if available
	if _has_team():
		var team: Array = _safe_team()
		for j in range(team.size()):
			var bu: Unit = (team[j] as Unit)
			if bu == null:
				continue
			var bid: String = String(bu.id)
			var blv: int = int(bu.level)
			if bid == "":
				continue
			var bkey: String = bid + "#" + str(blv)
			if not groups.has(bkey):
				groups[bkey] = []
			groups[bkey].append({ "kind": "board", "index": j, "unit": bu })
	return groups

func _find_group_with_at_least(groups: Dictionary, n: int) -> String:
	for k in groups.keys():
		var arr: Array = groups[k]
		if arr.size() >= int(n):
			return String(k)
	return ""

func _has_team() -> bool:
	return _get_team.is_valid()

func _safe_team() -> Array:
	if _get_team.is_valid():
		var t = _get_team.call()
		if typeof(t) == TYPE_ARRAY:
			return t
	return []

func _pick_kept(entries: Array) -> Dictionary:
	# Prefer: on-board > higher level > most items; fallback to first
	var kept: Dictionary = {}
	if entries.is_empty():
		return kept
	var sorted: Array = entries.duplicate()
	sorted.sort_custom(func(a, b):
		var ua: Unit = a.get("unit")
		var ub: Unit = b.get("unit")
		var ka: String = String(a.get("kind", "bench"))
		var kb: String = String(b.get("kind", "bench"))
		# Board first
		if (ka == "board") != (kb == "board"):
			return (ka == "board")
		# Higher level next
		var la: int = (int(ua.level) if ua != null else 1)
		var lb: int = (int(ub.level) if ub != null else 1)
		if la != lb:
			return la > lb
		# More items next (requires Items)
		var ia: int = _equipped_count(ua)
		var ib: int = _equipped_count(ub)
		if ia != ib:
			return ia > ib
		# Finally prefer lower bench index for determinism
		return int(a.get("index", 0)) < int(b.get("index", 0))
	)
	kept = sorted[0]
	return kept

func _equipped_count(u: Unit) -> int:
	if not _has_items() or u == null:
		return 0
	var arr = _get_equipped_list(u)
	return (arr.size() if arr is Array else 0)

func _get_equipped_list(u: Unit) -> Array:
	if not _has_items() or u == null:
		return []
	var items: Node = _items_singleton()
	if items == null:
		return []
	# Prefer explicit get_equipped; fallback to get_equipped_ids
	if items.has_method("get_equipped"):
		var eq = items.call("get_equipped", u)
		return (eq.duplicate() if eq is Array else [])
	if items.has_method("get_equipped_ids"):
		var eq2 = items.call("get_equipped_ids", u)
		return (eq2.duplicate() if eq2 is Array else [])
	return []

func _items_remove_all(u: Unit) -> void:
	if not _has_items() or u == null:
		return
	var items: Node = _items_singleton()
	if items != null and items.has_method("remove_all"):
		items.call("remove_all", u)

func _equip_onto(target: Unit, ids: Array[String]) -> void:
	if not _has_items() or target == null or ids == null:
		return
	var cap: int = 3
	var items: Node = _items_singleton()
	if items == null:
		return
	if items.has_method("slot_count"):
		cap = int(items.call("slot_count", target))
	var existing: int = _equipped_count(target)
	var space: int = int(max(0, cap - existing))
	if space <= 0:
		return
	var equipped_now: int = 0
	for iid in ids:
		if equipped_now >= space:
			break
		var id: String = String(iid)
		if id == "":
			continue
		if items.has_method("equip"):
			var res: Variant = items.call("equip", target, id)
			if res is Dictionary and bool((res as Dictionary).get("ok", false)):
				equipped_now += 1

func _has_items() -> bool:
	return _items_singleton() != null

func _items_singleton() -> Node:
	if Engine.has_singleton("Items"):
		return Items
	var loop: MainLoop = Engine.get_main_loop()
	if loop is SceneTree:
		var tree: SceneTree = loop as SceneTree
		if tree.root != null:
			return tree.root.get_node_or_null("/root/Items")
	return null

func _pick_consumed(entries: Array, kept: Dictionary, count: int) -> Array:
	# Prefer consuming bench entries; exclude 'kept'
	var pool: Array = []
	for e in entries:
		if e == kept:
			continue
		pool.append(e)
	# Stable order: bench first, then board
	pool.sort_custom(func(a, b):
		var ka: String = String(a.get("kind", "bench"))
		var kb: String = String(b.get("kind", "bench"))
		if ka == kb:
			return int(a.get("index", 0)) < int(b.get("index", 0))
		return (ka == "bench") and (kb != "bench")
	)
	var out: Array = []
	var needed: int = max(0, int(count))
	var i: int = 0
	while i < pool.size() and out.size() < needed:
		out.append(pool[i])
		i += 1
	return out

func _promote_one_level(u: Unit) -> void:
	# Increase unit.level by 1 (max 4) and apply multiplicative step to scaled stats.
	if u == null:
		return
	var steps := 1
	for _i in range(steps):
		for k in UnitScaler.SCALE_KEYS:
			var curv: float = float(u.get(k))
			curv *= 1.5
			match k:
				"max_hp":
					u.max_hp = max(1, int(curv))
				"hp_regen":
					u.hp_regen = max(0.0, curv)
				"attack_damage":
					u.attack_damage = max(0.0, curv)
				"spell_power":
					u.spell_power = max(0.0, curv)
				"lifesteal":
					u.lifesteal = clampf(curv, 0.0, 0.9)
				"armor":
					u.armor = max(0.0, curv)
				"magic_resist":
					u.magic_resist = max(0.0, curv)
				"true_damage":
					u.true_damage = max(0.0, curv)
	u.level = min(4, int(u.level) + 1)
	# Heal to full after promotion
	u.hp = u.max_hp
