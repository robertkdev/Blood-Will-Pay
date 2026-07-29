extends RefCounted
class_name BuffSystem

# Lightweight timed buff manager.
# - Applies additive stat deltas and reverts them on expiry
# - Supports simple shields and stuns (data tracked here; integration is separate)

const BuffTags := preload("res://scripts/game/abilities/buff_tags.gd")

const SUPPORTED_FIELDS := [
	"armor", "magic_resist", "damage_reduction",
	"attack_damage", "spell_power", "attack_speed",
	"crit_chance", "crit_damage",
	"mana_regen",
	"max_hp", "move_speed", "lifesteal", "lifesteel", # support both spellings
	"true_damage", "armor_pen_flat", "armor_pen_pct",
	"mr_pen_flat", "mr_pen_pct",
	"damage_reduction_flat",
	"tenacity"
]

const MAX_ATTACK_SPEED := 4.0

# Map[Unit -> Array[Dictionary]]
var _buffs: Dictionary = {}
var _stacks: Dictionary = {} # Map[Unit -> Dictionary[String, int]]
var _cc_first: Dictionary = {} # Map[Unit -> bool]
var _source_stack: Array[Dictionary] = []
var _movement_blocker_count: int = 0

signal cc_applied_first(team: String, index: int, kind: String)
signal buff_applied(source_team: String, source_index: int, target_team: String, target_index: int, kind: String, fields: Dictionary, magnitude: float, duration: float)
signal debuff_applied(source_team: String, source_index: int, target_team: String, target_index: int, kind: String, fields: Dictionary, magnitude: float, duration: float)
signal on_hit_proc(source_team: String, source_index: int, target_team: String, target_index: int, kind: String, fields: Dictionary, magnitude: float)
signal cc_prevented(source_team: String, source_index: int, target_team: String, target_index: int, kind: String)
signal cc_taxed(source_team: String, source_index: int, target_team: String, target_index: int, kind: String, raw_duration: float, effective_duration: float, tenacity: float, prevented: bool)
signal cleanse_applied(source_team: String, source_index: int, target_team: String, target_index: int, removed: int)

func clear() -> void:
	_buffs.clear()
	_stacks.clear()
	_cc_first.clear()
	_source_stack.clear()
	_movement_blocker_count = 0

func clear_reverting_stats() -> void:
	# Revert any active 'stats' buffs before clearing so unit base stats
	# do not persist across rounds/intermissions when the buff system resets.
	for u in _buffs.keys():
		var arr: Array = _buffs[u]
		for b in arr:
			if String(b.get("kind", "")) == "stats":
				var f: Dictionary = b.get("fields", {})
				if f and not f.is_empty():
					_apply_fields(u, f, -1)
		# Reset shield UI cache
		if u != null and u.has_method("set"):
			u.set("ui_shield", 0)
	_buffs.clear()
	_stacks.clear()
	_cc_first.clear()
	_source_stack.clear()
	_movement_blocker_count = 0

func push_source(team: String, index: int, kind: String = "ability") -> void:
	var source_team: String = String(team).strip_edges()
	if source_team == "":
		return
	_source_stack.append({
		"team": source_team,
		"index": int(index),
		"kind": String(kind).strip_edges()
	})

func pop_source() -> void:
	if _source_stack.is_empty():
		return
	_source_stack.pop_back()

func current_source(default_team: String = "", default_index: int = -1) -> Dictionary:
	return _source_for_target(default_team, default_index)

func record_buff(state: BattleState, team: String, index: int, kind: String, fields: Dictionary = {}, magnitude: float = 0.0, duration_s: float = 0.0) -> Dictionary:
	var u: Unit = _unit_at(state, team, index)
	if u == null:
		return {"processed": false}
	_emit_buff_presence(team, index, kind, fields if fields != null else {}, float(magnitude), float(duration_s))
	return {"processed": true}

func record_debuff(state: BattleState, team: String, index: int, kind: String, fields: Dictionary = {}, magnitude: float = 0.0, duration_s: float = 0.0) -> Dictionary:
	var u: Unit = _unit_at(state, team, index)
	if u == null:
		return {"processed": false}
	_emit_debuff_presence(team, index, kind, fields if fields != null else {}, float(magnitude), float(duration_s))
	return {"processed": true}

func tick(_state: BattleState, delta: float) -> void:
	if delta <= 0.0:
		return
	var to_remove: Array = []
	for u in _buffs.keys():
		var arr: Array = _buffs[u]
		for b in arr:
			var rem: float = float(b.get("remaining", 0.0)) - delta
			b["remaining"] = rem
			if rem <= 0.0:
				_expire_buff(u, b)
				to_remove.append([u, b])
	for pair in to_remove:
		var uu: Variant = pair[0]
		var bb: Variant = pair[1]
		if _buffs.has(uu):
			_buffs[uu].erase(bb)
			if _buffs[uu].is_empty():
				_buffs.erase(uu)
	# Recompute shield UI values after changes
	for u2 in _buffs.keys():
		_recompute_ui_shield(u2)

# === Public API ===

func apply_stats_buff(state: BattleState, team: String, index: int, fields: Dictionary, duration_s: float) -> Dictionary:
	var u: Unit = _unit_at(state, team, index)
	if u == null or duration_s <= 0.0:
		return {"processed": false}
	var f: Dictionary = _filter_fields(fields)
	if f.is_empty():
		return {"processed": false}
	_apply_fields(u, f, +1)
	var buff: Dictionary = {"kind": "stats", "fields": f, "remaining": duration_s}
	_add_buff(u, buff)
	_emit_stats_presence(team, index, f, duration_s)
	return {"processed": true, "applied": f, "duration": duration_s}

# Applies or refreshes a labeled stats buff so it does not stack.
# If a stats buff with the same label exists on the unit, refreshes its remaining duration to max(current, duration_s)
# and returns without reapplying fields. Otherwise applies fields and adds a new labeled stats buff.
func apply_stats_labeled(state: BattleState, team: String, index: int, label: String, fields: Dictionary, duration_s: float) -> Dictionary:
	var u: Unit = _unit_at(state, team, index)
	if u == null or String(label).strip_edges() == "" or duration_s <= 0.0:
		return {"processed": false}
	# If labeled stats buff exists, just refresh remaining
	if _buffs.has(u):
		for b in _buffs[u]:
			if String(b.get("kind", "")) == "stats" and String(b.get("label", "")) == String(label):
				var cur: float = float(b.get("remaining", 0.0))
				b["remaining"] = max(cur, float(duration_s))
				var existing_fields: Dictionary = b.get("fields", {})
				_emit_stats_presence(team, index, existing_fields, float(b["remaining"]))
				return {"processed": true, "refreshed": true, "duration": float(b["remaining"]) }
	var f: Dictionary = _filter_fields(fields)
	if f.is_empty():
		return {"processed": false}
	_apply_fields(u, f, +1)
	var buff: Dictionary = {"kind": "stats", "fields": f, "remaining": duration_s, "label": String(label)}
	_add_buff(u, buff)
	_emit_stats_presence(team, index, f, duration_s)
	return {"processed": true, "applied": f, "duration": duration_s}

func apply_shield(state: BattleState, team: String, index: int, amount: int, duration_s: float) -> Dictionary:
	var u: Unit = _unit_at(state, team, index)
	if u == null or amount <= 0 or duration_s <= 0.0:
		return {"processed": false}
	var amt: int = int(max(0, amount))
	# Apply shield strength multiplier from active healing mods tag if present
	const BuffTags := preload("res://scripts/game/abilities/buff_tags.gd")
	if has_tag(state, team, index, BuffTags.TAG_HEALING_MODS):
		var data: Dictionary = get_tag_data(state, team, index, BuffTags.TAG_HEALING_MODS)
		if data != null:
			var mult: float = 1.0 + float(data.get("shield_strength_pct", 0.0))
			if mult != 1.0:
				amt = int(max(0.0, round(float(amt) * max(0.0, mult))))
	var buff: Dictionary = {"kind": "shield", "shield": int(amt), "remaining": duration_s}
	_add_buff(u, buff)
	_recompute_ui_shield(u)
	_emit_buff_presence(team, index, "shield", {"shield": int(amt)}, float(amt), duration_s)
	return {"processed": true, "shield": int(amt), "duration": duration_s}

func apply_stun(state: BattleState, team: String, index: int, duration_s: float) -> Dictionary:
	var u: Unit = _unit_at(state, team, index)
	if u == null or duration_s <= 0.0:
		return {"processed": false}
	var source: Dictionary = _source_for_target(team, index)
	var source_team: String = String(source.get("team", team))
	var source_index: int = int(source.get("index", index))
	var raw_duration: float = max(0.0, duration_s)
	var ten: float = _unit_tenacity(u)
	# Gate stuns when unit is CC-immune via active tag
	if _has_cc_immunity(state, team, index):
		emit_signal("cc_taxed", source_team, source_index, String(team), int(index), "stun", raw_duration, 0.0, ten, true)
		emit_signal("cc_prevented", source_team, source_index, String(team), int(index), "stun")
		return {"processed": false}
	var dur: float = raw_duration
	# Tenacity reduces CC duration: effective = duration * (1 - tenacity)
	if ten > 0.0:
		dur = max(0.0, dur * (1.0 - ten))
		emit_signal("cc_taxed", source_team, source_index, String(team), int(index), "stun", raw_duration, dur, ten, false)
	if dur <= 0.0:
		return {"processed": false}
	var buff: Dictionary = {"kind": "stun", "remaining": dur}
	_add_buff(u, buff)
	_maybe_mark_first_cc(state, team, index, "stun")
	_emit_debuff_presence(team, index, "stun", {"duration": dur}, dur, dur)
	return {"processed": true, "duration": duration_s, "effective": dur}

# Generic tagged timed buff helper (no stat deltas by default)
# Stores a buff as { kind: "tag", tag: String, remaining: float, data: Dictionary }
func apply_tag(state: BattleState, team: String, index: int, tag: String, duration_s: float, data: Dictionary = {}) -> Dictionary:
	var u: Unit = _unit_at(state, team, index)
	if u == null or tag.strip_edges() == "" or duration_s <= 0.0:
		return {"processed": false}
	var dur: float = max(0.0, duration_s)
	# Scale root/rooted tags by tenacity
	var lname: String = String(tag).to_lower()
	if lname == "root" or lname == "rooted":
		var raw_duration: float = dur
		var ten: float = _unit_tenacity(u)
		if ten > 0.0:
			dur = max(0.0, dur * (1.0 - ten))
			var source: Dictionary = _source_for_target(team, index)
			emit_signal("cc_taxed", String(source.get("team", team)), int(source.get("index", index)), String(team), int(index), lname, raw_duration, dur, ten, false)
		if dur <= 0.0:
			return {"processed": false}
	var source_meta: Dictionary = _source_for_target(team, index)
	var tag_data: Dictionary = data.duplicate(true) if data != null else {}
	if not tag_data.has("source_team"):
		tag_data["source_team"] = String(source_meta.get("team", team))
	if not tag_data.has("source_index"):
		tag_data["source_index"] = int(source_meta.get("index", index))
	if not tag_data.has("source_kind"):
		tag_data["source_kind"] = String(source_meta.get("kind", ""))
	# If tag already present, refresh remaining and merge data
	if _buffs.has(u):
		for b in _buffs[u]:
			if String(b.get("kind", "")) == "tag" and String(b.get("tag", "")) == tag:
				b["remaining"] = max(float(b.get("remaining", 0.0)), dur)
				var cur: Dictionary = b.get("data", {})
				var merged: Dictionary = cur.duplicate()
				for k in tag_data.keys():
					merged[k] = tag_data[k]
				b["data"] = merged
				_emit_tag_presence(team, index, tag, merged, dur)
				return {"processed": true, "updated": true, "remaining": float(b["remaining"]), "data": merged}
	var buff: Dictionary = {"kind": "tag", "tag": tag, "remaining": dur, "data": tag_data}
	_add_buff(u, buff)
	if lname == "root" or lname == "rooted":
		_maybe_mark_first_cc(state, team, index, "root")
	_emit_tag_presence(team, index, tag, buff["data"], dur)
	return {"processed": true, "created": true, "remaining": duration_s, "data": buff["data"]}

func has_tag(state: BattleState, team: String, index: int, tag: String) -> bool:
	var u: Unit = _unit_at(state, team, index)
	if u == null or not _buffs.has(u):
		return false
	for b in _buffs[u]:
		if String(b.get("kind", "")) == "tag" and String(b.get("tag", "")) == tag and float(b.get("remaining", 0.0)) > 0.0:
			return true
	return false

func get_tag(state: BattleState, team: String, index: int, tag: String) -> Dictionary:
	var u: Unit = _unit_at(state, team, index)
	if u == null or not _buffs.has(u):
		return {}
	for b in _buffs[u]:
		if String(b.get("kind", "")) == "tag" and String(b.get("tag", "")) == tag and float(b.get("remaining", 0.0)) > 0.0:
			return b
	return {}

func get_tag_data(state: BattleState, team: String, index: int, tag: String) -> Dictionary:
	var b: Dictionary = get_tag(state, team, index, tag)
	if b.is_empty():
		return {}
	var d: Dictionary = b.get("data", {})
	return d if d != null else {}

# Returns true if any active tag on the unit sets data.block_mana_gain == true
func is_mana_gain_blocked(state: BattleState, team: String, index: int) -> bool:
	var u: Unit = _unit_at(state, team, index)
	if u == null or not _buffs.has(u):
		return false
	for b in _buffs[u]:
		if String(b.get("kind", "")) != "tag":
			continue
		if float(b.get("remaining", 0.0)) <= 0.0:
			continue
		var d: Dictionary = b.get("data", {})
		if d != null and bool(d.get("block_mana_gain", false)):
			return true
	return false

# Returns true if unit has any debuff: active stun, root/rooted tag, or a tag with a debuff hint
func is_debuffed(state: BattleState, team: String, index: int) -> bool:
	var u: Unit = _unit_at(state, team, index)
	if u == null or not _buffs.has(u):
		return false
	# Stun counts as a debuff
	if is_stunned(u):
		return true
	for b in _buffs[u]:
		if float(b.get("remaining", 0.0)) <= 0.0:
			continue
		var kind: String = String(b.get("kind", ""))
		if kind == "tag":
			var tname: String = String(b.get("tag", ""))
			if tname == "root" or tname == "rooted":
				return true
			if tname.to_lower().find("mark") >= 0:
				return true
			var d: Dictionary = b.get("data", {})
			if d != null and (bool(d.get("is_debuff", false)) or bool(d.get("debuff", false))):
				return true
		elif kind == "stats":
			var f: Dictionary = b.get("fields", {})
			if f and not f.is_empty():
				# If any stat buff has negative value, treat as debuff
				for k in f.keys():
					if float(f[k]) < 0.0:
						return true
	return false

# Cleanses debuffs from a unit: removes stuns, root/rooted tags, marked tags, and negative stat buffs
func cleanse(state: BattleState, team: String, index: int) -> Dictionary:
	var result: Dictionary = {"removed": 0}
	var u: Unit = _unit_at(state, team, index)
	if u == null or not _buffs.has(u):
		return result
	var arr: Array = _buffs[u]
	var to_remove: Array = []
	for b in arr:
		var keep: bool = true
		var kind: String = String(b.get("kind", ""))
		if kind == "stun":
			keep = false
		elif kind == "tag":
			var tname: String = String(b.get("tag", ""))
			if tname == "root" or tname == "rooted" or tname.to_lower().find("mark") >= 0:
				keep = false
			else:
				var d: Dictionary = b.get("data", {})
				if d != null and (bool(d.get("is_debuff", false)) or bool(d.get("debuff", false)) or bool(d.get("cleanseable", false))):
					keep = false
		elif kind == "stats":
			var f: Dictionary = b.get("fields", {})
			if f and not f.is_empty():
				for k in f.keys():
					if float(f[k]) < 0.0:
						keep = false
						break
		# Shields and positive buffs are kept
		if not keep:
			to_remove.append(b)
	# Apply removals and revert stat buffs
	var removed: int = 0
	for b2 in to_remove:
		var kind2: String = String(b2.get("kind", ""))
		if kind2 == "stats":
			var f2: Dictionary = b2.get("fields", {})
			if f2 and not f2.is_empty():
				_apply_fields(u, f2, -1)
		_track_removed_buff(b2)
		arr.erase(b2)
		removed += 1
	if arr.is_empty():
		_buffs.erase(u)
	_recompute_ui_shield(u)
	result["removed"] = removed
	if removed > 0:
		var source: Dictionary = _source_for_target(team, index)
		emit_signal("cleanse_applied", String(source.get("team", team)), int(source.get("index", index)), String(team), int(index), removed)
	return result

# Attempts to absorb incoming damage using active shields on this unit.
# Returns leftover damage after shields (non-negative) and the amount absorbed.
func absorb_with_shields(u: Unit, incoming_damage: int) -> Dictionary:
	var result: Dictionary = {"leftover": max(0, incoming_damage), "absorbed": 0}
	if u == null or incoming_damage <= 0 or not _buffs.has(u):
		return result
	var arr: Array = _buffs[u]
	var dmg: int = max(0, incoming_damage)
	for b in arr:
		if dmg <= 0:
			break
		if String(b.get("kind", "")) != "shield":
			continue
		var s: int = int(b.get("shield", 0))
		if s <= 0:
			continue
		var used: int = min(s, dmg)
		b["shield"] = s - used
		dmg -= used
		result["absorbed"] = int(result["absorbed"]) + used
	result["leftover"] = dmg
	_recompute_ui_shield(u)
	return result

# Instantly removes all active shield values on the unit.
# Returns the total shield amount removed.
func break_shields(u: Unit) -> int:
	var removed: int = 0
	if u == null or not _buffs.has(u):
		return removed
	var arr: Array = _buffs[u]
	for b in arr:
		if String(b.get("kind", "")) != "shield":
			continue
		var s: int = int(b.get("shield", 0))
		if s > 0:
			removed += s
			b["shield"] = 0
	_recompute_ui_shield(u)
	return removed

func break_shields_on(state: BattleState, team: String, index: int) -> int:
	var u: Unit = _unit_at(state, team, index)
	return break_shields(u)

func is_stunned(u: Unit) -> bool:
	if u == null or not _buffs.has(u):
		return false
	for b in _buffs[u]:
		if String(b.get("kind", "")) == "stun" and float(b.get("remaining", 0.0)) > 0.0:
			return true
	return false

func is_movement_blocked(state: BattleState, team: String, index: int) -> bool:
	var u: Unit = _unit_at(state, team, index)
	return is_unit_movement_blocked(u)

func is_unit_movement_blocked(u: Unit) -> bool:
	if u == null or not _buffs.has(u):
		return false
	for b in _buffs[u]:
		if float(b.get("remaining", 0.0)) <= 0.0:
			continue
		var kind: String = String(b.get("kind", ""))
		if kind == "stun":
			return true
		if kind == "tag":
			var tag_name: String = String(b.get("tag", ""))
			if tag_name == "root" or tag_name == "rooted":
				return true
	return false

func has_movement_blockers() -> bool:
	return _movement_blocker_count > 0

# === Stacks API ===

func add_stack(state: BattleState, team: String, index: int, key: String, delta: int, per_stack_fields: Dictionary = {}) -> Dictionary:
	var u: Unit = _unit_at(state, team, index)
	if u == null or key.strip_edges() == "" or delta == 0:
		return {"processed": false}
	if not _stacks.has(u):
		_stacks[u] = {}
	var smap: Dictionary = _stacks[u]
	var current: int = int(smap.get(key, 0))
	var new_count: int = max(0, current + delta)
	var applied_delta: int = new_count - current
	smap[key] = new_count
	# Apply permanent per-stack field deltas (scaled by applied_delta)
	if applied_delta != 0 and per_stack_fields != null and not per_stack_fields.is_empty():
		var scaled: Dictionary = {}
		for k in per_stack_fields.keys():
			scaled[k] = float(per_stack_fields[k]) * float(applied_delta)
		_apply_fields(u, scaled, +1)
		_emit_stats_presence(team, index, scaled, 9999.0)
	return {"processed": true, "key": key, "count": new_count, "delta": applied_delta}

func get_stack(state: BattleState, team: String, index: int, key: String) -> int:
	var u: Unit = _unit_at(state, team, index)
	if u == null or not _stacks.has(u):
		return 0
	var smap: Dictionary = _stacks[u]
	return int(smap.get(key, 0))

# === Internals ===

func _add_buff(u: Unit, buff: Dictionary) -> void:
	if u == null:
		return
	if not _buffs.has(u):
		_buffs[u] = []
	_buffs[u].append(buff)
	_track_added_buff(buff)

func _expire_buff(u: Unit, buff: Dictionary) -> void:
	if u == null:
		return
	var kind: String = String(buff.get("kind", ""))
	if kind == "stats":
		var f: Dictionary = buff.get("fields", {})
		if f and not f.is_empty():
			_apply_fields(u, f, -1)
	# shield and stun expire passively
	# tag kind also expires passively
	if kind == "shield":
		_recompute_ui_shield(u)
	_track_removed_buff(buff)

func _track_added_buff(buff: Dictionary) -> void:
	if _is_movement_blocker_buff(buff):
		_movement_blocker_count += 1

func _track_removed_buff(buff: Dictionary) -> void:
	if _is_movement_blocker_buff(buff):
		_movement_blocker_count = max(0, _movement_blocker_count - 1)

func _is_movement_blocker_buff(buff: Dictionary) -> bool:
	var kind: String = String(buff.get("kind", ""))
	if kind == "stun":
		return true
	if kind != "tag":
		return false
	var tag_name: String = String(buff.get("tag", ""))
	return tag_name == "root" or tag_name == "rooted"

func _apply_fields(u: Unit, fields: Dictionary, sign: int) -> void:
	for k in fields.keys():
		var v: Variant = fields[k]
		var delta: float = float(v) * float(sign)
		match String(k):
			"damage_reduction":
				u.damage_reduction = clamp(u.damage_reduction + delta, 0.0, 0.9)
			"attack_speed":
				u.attack_speed = clamp(u.attack_speed + delta, 0.01, MAX_ATTACK_SPEED)
			"lifesteal":
				u.lifesteal = clamp(u.lifesteal + delta, 0.0, 0.9)
			"lifesteel": # alias
				u.lifesteal = clamp(u.lifesteal + delta, 0.0, 0.9)
			"tenacity":
				var base_t: float = 0.0
				if u.has_method("get"):
					base_t = float(u.get("tenacity"))
				else:
					base_t = float(u.tenacity)
				var nv_t: float = clamp(base_t + delta, 0.0, 0.95)
				if u.has_method("set"):
					u.set("tenacity", nv_t)
				else:
					u.tenacity = nv_t
			"max_hp":
				var new_max: int = max(1, int(round(float(u.max_hp) + delta)))
				u.max_hp = new_max
				if u.hp > new_max:
					u.hp = new_max
			_:
				# Fallback for numeric fields; clamp to >= 0 for defenses
				var cur: Variant = u.get(k)
				if typeof(cur) == TYPE_FLOAT or typeof(cur) == TYPE_INT:
					var nv: float = float(cur) + delta
					if k in ["armor", "magic_resist", "armor_pen_flat", "mr_pen_flat"]:
						nv = max(0.0, nv)
					u.set(k, nv)

func _maybe_mark_first_cc(state: BattleState, team: String, index: int, kind: String) -> void:
	var u: Unit = _unit_at(state, team, index)
	if u == null:
		return
	if not _cc_first.has(u) or not bool(_cc_first[u]):
		_cc_first[u] = true
		emit_signal("cc_applied_first", team, index, String(kind))

func _has_cc_immunity(state: BattleState, team: String, index: int) -> bool:
	return has_tag(state, team, index, BuffTags.TAG_CC_IMMUNE)

func _unit_tenacity(u: Unit) -> float:
	if u == null:
		return 0.0
	if u.has_method("get"):
		return max(0.0, min(0.95, float(u.get("tenacity"))))
	return max(0.0, min(0.95, float(u.tenacity)))

func _filter_fields(fields: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	if fields == null:
		return out
	for k in SUPPORTED_FIELDS:
		if fields.has(k):
			out[k] = fields[k]
	return out

func _unit_at(state: BattleState, team: String, idx: int) -> Unit:
	var arr: Array[Unit] = state.player_team if team == "player" else state.enemy_team
	if idx < 0 or idx >= arr.size():
		return null
	return arr[idx]

func _source_for_target(default_team: String, default_index: int) -> Dictionary:
	if not _source_stack.is_empty():
		var source: Dictionary = _source_stack[_source_stack.size() - 1]
		return {
			"team": String(source.get("team", default_team)),
			"index": int(source.get("index", default_index)),
			"kind": String(source.get("kind", ""))
		}
	return {
		"team": String(default_team),
		"index": int(default_index),
		"kind": "self"
	}

func _emit_stats_presence(team: String, index: int, fields: Dictionary, duration_s: float) -> void:
	var positive_fields: Dictionary = _fields_matching_sign(fields, true)
	var negative_fields: Dictionary = _fields_matching_sign(fields, false)
	if not positive_fields.is_empty():
		_emit_buff_presence(team, index, "stats", positive_fields, _fields_magnitude(positive_fields), duration_s)
	if not negative_fields.is_empty():
		_emit_debuff_presence(team, index, "stats", negative_fields, _fields_magnitude(negative_fields), duration_s)

func _emit_tag_presence(team: String, index: int, tag: String, data: Dictionary, duration_s: float) -> void:
	var fields: Dictionary = {"tag": String(tag)}
	for key in data.keys():
		var key_string: String = String(key)
		var value: Variant = data.get(key)
		if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT or typeof(value) == TYPE_BOOL or typeof(value) == TYPE_STRING:
			fields[key_string] = value
	if _tag_is_debuff(tag, data):
		_emit_debuff_presence(team, index, String(tag), fields, max(0.0, duration_s), duration_s)
	else:
		var kind: String = "cc_immunity" if String(tag) == BuffTags.TAG_CC_IMMUNE else String(tag)
		_emit_buff_presence(team, index, kind, fields, max(0.0, duration_s), duration_s)

func _emit_buff_presence(team: String, index: int, kind: String, fields: Dictionary, magnitude: float, duration_s: float) -> void:
	var source: Dictionary = _source_for_target(team, index)
	var source_team: String = String(source.get("team", team))
	var source_index: int = int(source.get("index", index))
	var copied_fields: Dictionary = fields.duplicate(true)
	emit_signal("buff_applied", source_team, source_index, String(team), int(index), String(kind), copied_fields, float(magnitude), float(duration_s))
	if String(source.get("kind", "")) == "on_hit":
		emit_signal("on_hit_proc", source_team, source_index, String(team), int(index), String(kind), copied_fields, float(magnitude))

func _emit_debuff_presence(team: String, index: int, kind: String, fields: Dictionary, magnitude: float, duration_s: float) -> void:
	var source: Dictionary = _source_for_target(team, index)
	var source_team: String = String(source.get("team", team))
	var source_index: int = int(source.get("index", index))
	var copied_fields: Dictionary = fields.duplicate(true)
	emit_signal("debuff_applied", source_team, source_index, String(team), int(index), String(kind), copied_fields, float(magnitude), float(duration_s))
	if String(source.get("kind", "")) == "on_hit":
		emit_signal("on_hit_proc", source_team, source_index, String(team), int(index), String(kind), copied_fields, float(magnitude))

func _fields_matching_sign(fields: Dictionary, positive: bool) -> Dictionary:
	var out: Dictionary = {}
	if fields == null:
		return out
	for key in fields.keys():
		var value: Variant = fields.get(key)
		if not (typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT):
			continue
		var numeric: float = float(value)
		if positive and numeric > 0.0:
			out[key] = value
		elif (not positive) and numeric < 0.0:
			out[key] = value
	return out

func _fields_magnitude(fields: Dictionary) -> float:
	var total: float = 0.0
	if fields == null:
		return total
	for key in fields.keys():
		var value: Variant = fields.get(key)
		if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
			total += abs(float(value))
	return total

func _tag_is_debuff(tag: String, data: Dictionary) -> bool:
	var lname: String = String(tag).strip_edges().to_lower()
	if lname in ["root", "rooted", "stun", "stunned"]:
		return true
	if lname.find("mark") >= 0 or lname.find("bleed") >= 0 or lname.find("shred") >= 0:
		return true
	if data != null and (bool(data.get("is_debuff", false)) or bool(data.get("debuff", false)) or bool(data.get("cleanseable", false))):
		return true
	return false

func _recompute_ui_shield(u: Unit) -> void:
	if u == null:
		return
	var total: int = 0
	if _buffs.has(u):
		var arr: Array = _buffs[u]
		for b in arr:
			if String(b.get("kind", "")) == "shield":
				total += max(0, int(b.get("shield", 0)))
	if u.has_method("set"):
		u.ui_shield = int(total)
