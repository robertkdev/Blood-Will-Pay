extends RefCounted

# Buff Presence Kernel
# Counts source-attributed buff/debuff utility and target-side received effects.

const SIDE_A: String = "a"
const SIDE_B: String = "b"
const TEAM_PLAYER: String = "player"
const TEAM_ENEMY: String = "enemy"

var _engine: Object = null
var _connected: bool = false
var _player_is_team_a: bool = true
var _counts: Dictionary = {}
var _per_unit: Dictionary = {}
var _target_unit: Dictionary = {}
var _index_to_uid: Dictionary = {}
var _dot_target_keys_by_unit: Dictionary = {}
var _amp_beneficiary_keys_by_unit: Dictionary = {}
var _dot_active_by_key: Dictionary = {}
var _supported: bool = false
var _dot_tick_supported: bool = false

func attach(engine: Object, team_sizes: Dictionary, context_tags: Dictionary = {}, player_is_team_a: bool = true) -> void:
	detach()
	_engine = engine
	_player_is_team_a = player_is_team_a
	_counts = {
		SIDE_A: _empty_side_counts(int(team_sizes.get(SIDE_A, 0))),
		SIDE_B: _empty_side_counts(int(team_sizes.get(SIDE_B, 0)))
	}
	_per_unit = {SIDE_A: {}, SIDE_B: {}}
	_target_unit = {SIDE_A: {}, SIDE_B: {}}
	_dot_target_keys_by_unit = {SIDE_A: {}, SIDE_B: {}}
	_amp_beneficiary_keys_by_unit = {SIDE_A: {}, SIDE_B: {}}
	_dot_active_by_key = {}
	_index_to_uid = _extract_index_map(context_tags)
	_supported = false
	_dot_tick_supported = false
	_connected = _connect()

func detach() -> void:
	if _engine != null:
		_disconnect("buff_applied", Callable(self, "_on_buff_applied"))
		_disconnect("debuff_applied", Callable(self, "_on_debuff_applied"))
		_disconnect("on_hit_proc", Callable(self, "_on_on_hit_proc"))
		_disconnect("dot_tick_applied", Callable(self, "_on_dot_tick_applied"))
		_disconnect("amp_output_applied", Callable(self, "_on_amp_output_applied"))
		_disconnect("cc_prevented", Callable(self, "_on_cc_prevented"))
		_disconnect("cleanse_applied", Callable(self, "_on_cleanse_applied"))
	_engine = null
	_connected = false
	_dot_tick_supported = false
	_dot_active_by_key = {}

func tick(delta_s: float) -> void:
	var dt: float = max(0.0, float(delta_s))
	if dt <= 0.0 or _dot_active_by_key.is_empty():
		return
	var next_active: Dictionary = {}
	for key_value in _dot_active_by_key.keys():
		var key: String = String(key_value)
		var record: Dictionary = _dot_active_by_key.get(key, {})
		if not (record is Dictionary):
			continue
		var remaining: float = max(0.0, float(record.get("remaining", 0.0)))
		if remaining <= 0.0:
			continue
		var active_dt: float = min(dt, remaining)
		var source_side: String = String(record.get("source_side", ""))
		var source_index: int = int(record.get("source_index", -1))
		var target_side: String = String(record.get("target_side", ""))
		var target_index: int = int(record.get("target_index", -1))
		_bump_source(source_side, source_index, {"dot_uptime_s": active_dt})
		_bump_target(target_side, target_index, {"dot_uptime_received_s": active_dt})
		remaining -= active_dt
		if remaining > 0.0:
			record["remaining"] = remaining
			next_active[key] = record
	_dot_active_by_key = next_active

func finalize(_total_time_s: float) -> void:
	pass

func result() -> Dictionary:
	var a: Dictionary = _counts.get(SIDE_A, _empty_side_counts(0))
	var b: Dictionary = _counts.get(SIDE_B, _empty_side_counts(0))
	return {
		"buff_presence": {
			"supported": _supported,
			"dot_tick_supported": _dot_tick_supported,
			SIDE_A: _side_result(a),
			SIDE_B: _side_result(b),
			"per_unit": {
				SIDE_A: _per_unit.get(SIDE_A, {}),
				SIDE_B: _per_unit.get(SIDE_B, {})
			},
			"target_unit": {
				SIDE_A: _target_unit.get(SIDE_A, {}),
				SIDE_B: _target_unit.get(SIDE_B, {})
			}
		}
	}

func register(_aggregator: Variant) -> RefCounted:
	return self

func _connect() -> bool:
	if _engine == null:
		return false
	var any_signal: bool = false
	any_signal = _connect_signal("buff_applied", Callable(self, "_on_buff_applied")) or any_signal
	any_signal = _connect_signal("debuff_applied", Callable(self, "_on_debuff_applied")) or any_signal
	any_signal = _connect_signal("on_hit_proc", Callable(self, "_on_on_hit_proc")) or any_signal
	_dot_tick_supported = _connect_signal("dot_tick_applied", Callable(self, "_on_dot_tick_applied"))
	any_signal = _dot_tick_supported or any_signal
	any_signal = _connect_signal("amp_output_applied", Callable(self, "_on_amp_output_applied")) or any_signal
	any_signal = _connect_signal("cc_prevented", Callable(self, "_on_cc_prevented")) or any_signal
	any_signal = _connect_signal("cleanse_applied", Callable(self, "_on_cleanse_applied")) or any_signal
	_supported = any_signal
	return any_signal

func _connect_signal(signal_name: String, callable: Callable) -> bool:
	if _engine == null or not _engine.has_signal(signal_name):
		return false
	if not _engine.is_connected(signal_name, callable):
		_engine.connect(signal_name, callable)
	return true

func _disconnect(signal_name: String, callable: Callable) -> void:
	if _engine == null or not _engine.has_signal(signal_name):
		return
	if _engine.is_connected(signal_name, callable):
		_engine.disconnect(signal_name, callable)

func _on_buff_applied(source_team: String, source_index: int, target_team: String, target_index: int, kind: String, _fields: Dictionary, magnitude: float, duration: float) -> void:
	var source_side: String = _team_to_side(source_team)
	var target_side: String = _team_to_side(target_team)
	if source_side == "":
		return
	_bump_side(source_side, "buff_applied", 1)
	if source_side == target_side:
		_bump_side(source_side, "ally_buff_targets", 1)
		if int(source_index) != int(target_index):
			_bump_side(source_side, "ally_buffs_to_others", 1)
			_bump_side(source_side, "ally_buff_magnitude_to_others", int(round(max(0.0, float(magnitude)))))
	if String(kind) == "cc_immunity":
		_bump_side(source_side, "cc_immunity_applied", 1)
	_bump_source(source_side, int(source_index), {
		"buff_applied": 1,
		"ally_buffs": (1 if source_side == target_side else 0),
		"ally_buffs_to_others": (1 if source_side == target_side and int(source_index) != int(target_index) else 0),
		"ally_buff_magnitude_to_others": (float(magnitude) if source_side == target_side and int(source_index) != int(target_index) else 0.0),
		"cc_immunity": (1 if String(kind) == "cc_immunity" else 0),
		"buff_magnitude": float(magnitude)
	})
	_bump_target(target_side, int(target_index), {
		"buff_received": 1,
		"cc_immunity_received": (1 if String(kind) == "cc_immunity" else 0),
		"buff_duration": float(duration)
	})

func _on_debuff_applied(source_team: String, source_index: int, target_team: String, target_index: int, kind: String, fields: Dictionary, magnitude: float, duration: float) -> void:
	var source_side: String = _team_to_side(source_team)
	var target_side: String = _team_to_side(target_team)
	if source_side == "":
		return
	var is_dot: bool = _is_dot_kind(kind, fields)
	var attack_speed_slow: float = 0.0
	if fields.has("attack_speed"):
		attack_speed_slow = max(0.0, -float(fields.get("attack_speed", 0.0)))
	var is_enemy_attack_speed_slow: bool = source_side != target_side and attack_speed_slow > 0.0
	_bump_side(source_side, "debuff_applied", 1)
	if source_side != "" and target_side != "" and source_side != target_side:
		_bump_side(source_side, "enemy_debuff_targets", 1)
	_bump_source(source_side, int(source_index), {
		"debuff_applied": 1,
		"enemy_debuffs": (1 if source_side != target_side else 0),
		"debuff_magnitude": float(magnitude),
		"enemy_attack_speed_slow_events": (1 if is_enemy_attack_speed_slow else 0),
		"enemy_attack_speed_slow_magnitude": (attack_speed_slow if is_enemy_attack_speed_slow else 0.0),
		"enemy_attack_speed_slow_duration_s": (max(0.0, float(duration)) if is_enemy_attack_speed_slow else 0.0),
		"dot_application_events": (1 if is_dot and source_side != target_side else 0),
		"dot_duration_applied_s": (max(0.0, float(duration)) if is_dot and source_side != target_side else 0.0)
	})
	_bump_target(target_side, int(target_index), {
		"debuff_received": 1,
		"debuff_duration": float(duration),
		"stuns_received": (1 if String(kind) == "stun" else 0),
		"dot_debuffs_received": (1 if is_dot and source_side != target_side else 0),
		"dot_duration_received_s": (max(0.0, float(duration)) if is_dot and source_side != target_side else 0.0)
	})
	if is_dot and source_side != "" and target_side != "" and source_side != target_side and float(duration) > 0.0:
		_record_dot_target(source_side, int(source_index), target_side, int(target_index))
		_track_dot_uptime(source_side, int(source_index), target_side, int(target_index), String(kind), float(duration))

func _on_on_hit_proc(source_team: String, source_index: int, target_team: String, target_index: int, _kind: String, _fields: Dictionary, magnitude: float) -> void:
	var source_side: String = _team_to_side(source_team)
	var target_side: String = _team_to_side(target_team)
	if source_side == "":
		return
	_bump_side(source_side, "on_hit_effects", 1)
	_bump_source(source_side, int(source_index), {
		"on_hit_effects": 1,
		"on_hit_magnitude": float(magnitude)
	})
	_bump_target(target_side, int(target_index), {
		"on_hit_received": 1
	})

func _on_dot_tick_applied(source_team: String, source_index: int, target_team: String, target_index: int, amount: int, _kind: String) -> void:
	var source_side: String = _team_to_side(source_team)
	var target_side: String = _team_to_side(target_team)
	if source_side == "":
		return
	var safe_amount: int = max(0, int(amount))
	_bump_side(source_side, "dot_tick_events", 1)
	_bump_side(source_side, "dot_tick_damage", safe_amount)
	_bump_source(source_side, int(source_index), {
		"dot_tick_events": 1,
		"dot_tick_damage": safe_amount
	})
	_record_dot_target(source_side, int(source_index), target_side, int(target_index))
	_bump_target(target_side, int(target_index), {
		"dot_ticks_received": 1,
		"dot_damage_received": safe_amount
	})

func _on_amp_output_applied(source_team: String, source_index: int, beneficiary_team: String, beneficiary_index: int, target_team: String, target_index: int, amount: float, amp_pct: float, _kind: String) -> void:
	var source_side: String = _team_to_side(source_team)
	var beneficiary_side: String = _team_to_side(beneficiary_team)
	var target_side: String = _team_to_side(target_team)
	if source_side == "":
		return
	var safe_amount: float = max(0.0, float(amount))
	_bump_side(source_side, "amp_output_events", 1)
	_bump_side(source_side, "amp_output_delta", int(round(safe_amount)))
	_bump_source(source_side, int(source_index), {
		"amp_output_events": 1,
		"amp_output_delta": safe_amount,
		"amp_output_pct_total": max(0.0, float(amp_pct))
	})
	_record_amp_beneficiary(source_side, int(source_index), beneficiary_side, int(beneficiary_index))
	_bump_target(target_side, int(target_index), {
		"amp_output_hits_received": 1,
		"amp_output_received": safe_amount
	})

func _on_cc_prevented(source_team: String, source_index: int, target_team: String, target_index: int, _kind: String) -> void:
	var source_side: String = _team_to_side(source_team)
	var target_side: String = _team_to_side(target_team)
	if source_side != "":
		_bump_side(source_side, "cc_prevented_by_enemy", 1)
		_bump_source(source_side, int(source_index), {"cc_prevented_by_enemy": 1})
	if target_side != "":
		_bump_side(target_side, "cc_prevented", 1)
		_bump_target(target_side, int(target_index), {"cc_prevented": 1})

func _on_cleanse_applied(source_team: String, source_index: int, target_team: String, target_index: int, removed: int) -> void:
	var source_side: String = _team_to_side(source_team)
	var target_side: String = _team_to_side(target_team)
	if source_side == "":
		return
	_bump_side(source_side, "cleanse_applied", int(removed))
	_bump_source(source_side, int(source_index), {"cleanse_applied": int(removed)})
	_bump_target(target_side, int(target_index), {"cleanse_received": int(removed)})

func _empty_side_counts(allies: int) -> Dictionary:
	return {
		"buff_applied": 0,
		"debuff_applied": 0,
		"ally_buff_targets": 0,
		"ally_buffs_to_others": 0,
		"ally_buff_magnitude_to_others": 0,
		"enemy_debuff_targets": 0,
		"cc_immunity_applied": 0,
		"on_hit_effects": 0,
		"dot_tick_events": 0,
		"dot_tick_damage": 0,
		"amp_output_events": 0,
		"amp_output_delta": 0,
		"cc_prevented": 0,
		"cc_prevented_by_enemy": 0,
		"cleanse_applied": 0,
		"allies": max(0, int(allies))
	}

func _side_result(data: Dictionary) -> Dictionary:
	var total_events: int = int(data.get("buff_applied", 0)) + int(data.get("debuff_applied", 0)) + int(data.get("cc_prevented", 0)) + int(data.get("cleanse_applied", 0))
	var allies: int = max(1, int(data.get("allies", 1)))
	var out: Dictionary = data.duplicate(true)
	out["events_per_ally"] = float(total_events) / float(allies)
	return out

func _team_to_side(team_str: String) -> String:
	var team: String = String(team_str)
	if team == "":
		return ""
	if _player_is_team_a:
		return SIDE_A if team == TEAM_PLAYER else SIDE_B
	return SIDE_A if team == TEAM_ENEMY else SIDE_B

func _bump_side(side: String, key: String, amount: int) -> void:
	if side == "":
		return
	var data: Dictionary = _counts.get(side, _empty_side_counts(0))
	data[key] = int(data.get(key, 0)) + int(amount)
	_counts[side] = data

func _bump_source(side: String, source_index: int, deltas: Dictionary) -> void:
	var uid: String = _uid_for(side, source_index)
	if uid == "":
		return
	var by_side: Dictionary = _per_unit.get(side, {})
	var rec: Dictionary = by_side.get(uid, _empty_unit_counts())
	_apply_deltas(rec, deltas)
	by_side[uid] = rec
	_per_unit[side] = by_side

func _bump_target(side: String, target_index: int, deltas: Dictionary) -> void:
	var uid: String = _uid_for(side, target_index)
	if uid == "":
		return
	var by_side: Dictionary = _target_unit.get(side, {})
	var rec: Dictionary = by_side.get(uid, _empty_target_counts())
	_apply_deltas(rec, deltas)
	by_side[uid] = rec
	_target_unit[side] = by_side

func _empty_unit_counts() -> Dictionary:
	return {
		"buff_applied": 0,
		"debuff_applied": 0,
		"ally_buffs": 0,
		"ally_buffs_to_others": 0,
		"ally_buff_magnitude_to_others": 0.0,
		"enemy_debuffs": 0,
		"enemy_attack_speed_slow_events": 0,
		"enemy_attack_speed_slow_magnitude": 0.0,
		"enemy_attack_speed_slow_duration_s": 0.0,
		"cc_immunity": 0,
		"on_hit_effects": 0,
		"on_hit_magnitude": 0.0,
		"dot_tick_events": 0,
		"dot_tick_damage": 0,
		"dot_tick_targets": 0,
		"amp_output_events": 0,
		"amp_output_delta": 0.0,
		"amp_output_pct_total": 0.0,
		"amp_output_beneficiaries": 0,
		"dot_application_events": 0,
		"dot_duration_applied_s": 0.0,
		"dot_uptime_s": 0.0,
		"cc_prevented_by_enemy": 0,
		"cleanse_applied": 0,
		"buff_magnitude": 0.0,
		"debuff_magnitude": 0.0
	}

func _empty_target_counts() -> Dictionary:
	return {
		"buff_received": 0,
		"debuff_received": 0,
		"cc_immunity_received": 0,
		"cc_prevented": 0,
		"cleanse_received": 0,
		"on_hit_received": 0,
		"dot_ticks_received": 0,
		"dot_damage_received": 0,
		"amp_output_hits_received": 0,
		"amp_output_received": 0.0,
		"dot_debuffs_received": 0,
		"dot_duration_received_s": 0.0,
		"dot_uptime_received_s": 0.0,
		"stuns_received": 0,
		"buff_duration": 0.0,
		"debuff_duration": 0.0
	}

func _apply_deltas(record: Dictionary, deltas: Dictionary) -> void:
	for key in deltas.keys():
		var old_value: Variant = record.get(key, 0)
		var delta_value: Variant = deltas.get(key, 0)
		if typeof(old_value) == TYPE_FLOAT or typeof(delta_value) == TYPE_FLOAT:
			record[key] = float(old_value) + float(delta_value)
		else:
			record[key] = int(old_value) + int(delta_value)

func _record_dot_target(source_side: String, source_index: int, target_side: String, target_index: int) -> void:
	if source_side == "":
		return
	var uid: String = _uid_for(source_side, source_index)
	if uid == "":
		return
	var source_targets: Dictionary = _dot_target_keys_by_unit.get(source_side, {})
	var target_set: Dictionary = source_targets.get(uid, {})
	var key: String = "%s:%d" % [String(target_side), int(target_index)]
	target_set[key] = true
	source_targets[uid] = target_set
	_dot_target_keys_by_unit[source_side] = source_targets
	_set_source_value(source_side, source_index, "dot_tick_targets", target_set.size())

func _record_amp_beneficiary(source_side: String, source_index: int, beneficiary_side: String, beneficiary_index: int) -> void:
	if source_side == "":
		return
	var uid: String = _uid_for(source_side, source_index)
	if uid == "":
		return
	var source_targets: Dictionary = _amp_beneficiary_keys_by_unit.get(source_side, {})
	var target_set: Dictionary = source_targets.get(uid, {})
	var key: String = "%s:%d" % [String(beneficiary_side), int(beneficiary_index)]
	target_set[key] = true
	source_targets[uid] = target_set
	_amp_beneficiary_keys_by_unit[source_side] = source_targets
	_set_source_value(source_side, source_index, "amp_output_beneficiaries", target_set.size())

func _track_dot_uptime(source_side: String, source_index: int, target_side: String, target_index: int, kind: String, duration_s: float) -> void:
	var source_uid: String = _uid_for(source_side, source_index)
	var target_uid: String = _uid_for(target_side, target_index)
	if source_uid == "" or target_uid == "":
		return
	var safe_kind: String = _safe_kind(kind)
	var key: String = "%s:%d>%s:%d:%s" % [source_side, int(source_index), target_side, int(target_index), safe_kind]
	var existing: Dictionary = _dot_active_by_key.get(key, {})
	var remaining: float = max(max(0.0, float(duration_s)), float(existing.get("remaining", 0.0)))
	_dot_active_by_key[key] = {
		"source_side": source_side,
		"source_index": int(source_index),
		"target_side": target_side,
		"target_index": int(target_index),
		"kind": safe_kind,
		"remaining": remaining
	}

func _set_source_value(side: String, source_index: int, key: String, value: Variant) -> void:
	var uid: String = _uid_for(side, source_index)
	if uid == "":
		return
	var by_side: Dictionary = _per_unit.get(side, {})
	var rec: Dictionary = by_side.get(uid, _empty_unit_counts())
	rec[String(key)] = value
	by_side[uid] = rec
	_per_unit[side] = by_side

func _uid_for(side: String, index: int) -> String:
	var uid_map: Dictionary = _index_to_uid.get(side, {})
	return String(uid_map.get(int(index), ""))

func _is_dot_kind(kind: String, fields: Dictionary) -> bool:
	var lname: String = String(kind).strip_edges().to_lower()
	if lname.find("dot") >= 0 or lname.find("bleed") >= 0 or lname.find("poison") >= 0 or lname.find("burn") >= 0 or lname.find("fractured") >= 0:
		return true
	if fields is Dictionary:
		var tag: String = String(fields.get("tag", "")).strip_edges().to_lower()
		if tag.find("dot") >= 0 or tag.find("bleed") >= 0 or tag.find("poison") >= 0 or tag.find("burn") >= 0 or tag.find("fractured") >= 0:
			return true
	return false

func _safe_kind(kind: String) -> String:
	var out: String = String(kind).strip_edges().to_lower()
	if out == "":
		return "unknown"
	return out

func _extract_index_map(context_tags: Dictionary) -> Dictionary:
	var out: Dictionary = {SIDE_A: {}, SIDE_B: {}}
	if not (context_tags is Dictionary):
		return out
	var timelines_root: Dictionary = context_tags.get("unit_timelines", {})
	if not (timelines_root is Dictionary):
		return out
	for side in [SIDE_A, SIDE_B]:
		var arr: Array = timelines_root.get(side, [])
		if not (arr is Array):
			continue
		var index_map: Dictionary = {}
		for entry in arr:
			if not (entry is Dictionary):
				continue
			var idx_value: Variant = (entry as Dictionary).get("unit_index", null)
			if typeof(idx_value) != TYPE_INT:
				continue
			var uid: String = String((entry as Dictionary).get("unit_id", ""))
			if uid == "":
				continue
			index_map[int(idx_value)] = uid
		out[side] = index_map
	return out
