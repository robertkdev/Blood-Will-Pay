extends RefCounted
class_name CombatStatsCollector

const BattleState = preload("res://scripts/game/combat/battle_state.gd")

# Base combat aggregates collector. Subscribe to engine signals and call tick() per simulation frame.

var _engine
var _state: BattleState
var _player_is_team_a: bool = true

var _time_s: float = 0.0

var _team: Dictionary = {}
var _units: Dictionary = {}

var _mana_last_a: Array = []
var _mana_last_b: Array = []
var _death_time_a: Array = []
var _death_time_b: Array = []
var _has_committed_cast_signal: bool = false

func attach(engine, state: BattleState, player_is_team_a: bool) -> void:
    _engine = engine
    _state = state
    _player_is_team_a = player_is_team_a
    _time_s = 0.0
    _team = {
        "a": _new_team_totals(),
        "b": _new_team_totals(),
    }
    _units = {
        "a": [],
        "b": [],
    }
    _mana_last_a = []
    _mana_last_b = []
    _death_time_a = []
    _death_time_b = []
    _has_committed_cast_signal = false
    _init_unit_arrays()
    _connect_engine_signals()

func detach() -> void:
    _disconnect_engine_signals()
    _engine = null
    _state = null
    _player_is_team_a = true

func _disconnect_engine_signals() -> void:
    if _engine == null:
        return
    if _engine.has_signal("hit_applied") and _engine.is_connected("hit_applied", Callable(self, "_on_hit_applied")):
        _engine.hit_applied.disconnect(_on_hit_applied)
    if _engine.has_signal("redirected_damage_applied") and _engine.is_connected("redirected_damage_applied", Callable(self, "_on_redirected_damage_applied")):
        _engine.redirected_damage_applied.disconnect(_on_redirected_damage_applied)
    if _engine.has_signal("heal_applied") and _engine.is_connected("heal_applied", Callable(self, "_on_heal_applied")):
        _engine.heal_applied.disconnect(_on_heal_applied)
    if _engine.has_signal("shield_absorbed") and _engine.is_connected("shield_absorbed", Callable(self, "_on_shield_absorbed")):
        _engine.shield_absorbed.disconnect(_on_shield_absorbed)
    if _engine.has_signal("hit_mitigated") and _engine.is_connected("hit_mitigated", Callable(self, "_on_hit_mitigated")):
        _engine.hit_mitigated.disconnect(_on_hit_mitigated)
    if _engine.has_signal("hit_overkill") and _engine.is_connected("hit_overkill", Callable(self, "_on_hit_overkill")):
        _engine.hit_overkill.disconnect(_on_hit_overkill)
    if _engine.has_signal("hit_components") and _engine.is_connected("hit_components", Callable(self, "_on_hit_components")):
        _engine.hit_components.disconnect(_on_hit_components)
    if _engine.has_signal("ability_committed") and _engine.is_connected("ability_committed", Callable(self, "_on_ability_committed")):
        _engine.ability_committed.disconnect(_on_ability_committed)
    _has_committed_cast_signal = false

func _connect_engine_signals() -> void:
    if _engine == null:
        return
    if _engine.has_signal("hit_applied") and not _engine.is_connected("hit_applied", Callable(self, "_on_hit_applied")):
        _engine.hit_applied.connect(_on_hit_applied)
    if _engine.has_signal("redirected_damage_applied") and not _engine.is_connected("redirected_damage_applied", Callable(self, "_on_redirected_damage_applied")):
        _engine.redirected_damage_applied.connect(_on_redirected_damage_applied)
    if _engine.has_signal("heal_applied") and not _engine.is_connected("heal_applied", Callable(self, "_on_heal_applied")):
        _engine.heal_applied.connect(_on_heal_applied)
    if _engine.has_signal("shield_absorbed") and not _engine.is_connected("shield_absorbed", Callable(self, "_on_shield_absorbed")):
        _engine.shield_absorbed.connect(_on_shield_absorbed)
    if _engine.has_signal("hit_mitigated") and not _engine.is_connected("hit_mitigated", Callable(self, "_on_hit_mitigated")):
        _engine.hit_mitigated.connect(_on_hit_mitigated)
    if _engine.has_signal("hit_overkill") and not _engine.is_connected("hit_overkill", Callable(self, "_on_hit_overkill")):
        _engine.hit_overkill.connect(_on_hit_overkill)
    if _engine.has_signal("hit_components") and not _engine.is_connected("hit_components", Callable(self, "_on_hit_components")):
        _engine.hit_components.connect(_on_hit_components)
    if _engine.has_signal("ability_committed"):
        _has_committed_cast_signal = true
        if not _engine.is_connected("ability_committed", Callable(self, "_on_ability_committed")):
            _engine.ability_committed.connect(_on_ability_committed)

func _init_unit_arrays() -> void:
    _units["a"] = []
    _units["b"] = []
    _mana_last_a.clear()
    _mana_last_b.clear()
    _death_time_a.clear()
    _death_time_b.clear()
    var arr_a: Array = _state_array_for("a")
    var arr_b: Array = _state_array_for("b")
    for i in range(arr_a.size()):
        var entry_a := _new_unit_entry()
        var unit_a = arr_a[i]
        if unit_a != null:
            entry_a["unit_id"] = String(unit_a.id)
        _units["a"].append(entry_a)
        _mana_last_a.append(int(unit_a.mana) if unit_a else 0)
        _death_time_a.append(-1.0)
    for j in range(arr_b.size()):
        var entry_b := _new_unit_entry()
        var unit_b = arr_b[j]
        if unit_b != null:
            entry_b["unit_id"] = String(unit_b.id)
        _units["b"].append(entry_b)
        _mana_last_b.append(int(unit_b.mana) if unit_b else 0)
        _death_time_b.append(-1.0)

func _new_team_totals() -> Dictionary:
    return {
        "damage": 0,
        "healing": 0,
        "shield": 0,
        "mitigated": 0,
        "overkill": 0,
        "kills": 0,
        "deaths": 0,
        "casts": 0,
        "first_hit_s": -1.0,
        "first_cast_s": -1.0,
    }

func _new_unit_entry() -> Dictionary:
    return {
        "damage": 0,
        "healing": 0,
        "shield": 0,
        "mitigated": 0,
        "incoming": 0,
        "pre_mit_incoming": 0,
        "post_mit_incoming": 0,
        "overkill": 0,
        "kills": 0,
        "deaths": 0,
        "casts": 0,
        "time_alive_s": 0.0,
        "first_hit_s": -1.0,
        "first_cast_s": -1.0,
    }

func _state_array_for(side: String) -> Array:
    if _state == null:
        return []
    if side == "a":
        return (_state.player_team if _player_is_team_a else _state.enemy_team)
    return (_state.enemy_team if _player_is_team_a else _state.player_team)

func tick(delta_s: float) -> void:
    _time_s += max(0.0, delta_s)
    if _state == null:
        return
    var arr_a: Array = _state_array_for("a")
    var arr_b: Array = _state_array_for("b")
    for i in range(min(arr_a.size(), _mana_last_a.size())):
        var unit_a = arr_a[i]
        var mana_now := int(unit_a.mana) if unit_a else 0
        if not _has_committed_cast_signal and _mana_last_a[i] > 0 and mana_now == 0:
            _inc_cast("a", i)
        _mana_last_a[i] = mana_now
    for j in range(min(arr_b.size(), _mana_last_b.size())):
        var unit_b = arr_b[j]
        var mana_now_b := int(unit_b.mana) if unit_b else 0
        if not _has_committed_cast_signal and _mana_last_b[j] > 0 and mana_now_b == 0:
            _inc_cast("b", j)
        _mana_last_b[j] = mana_now_b

func finalize(total_time_s: float) -> void:
    var units_a_data = _units.get("a", [])
    var units_a: Array = []
    if units_a_data is Array:
        units_a = units_a_data
    for i in range(units_a.size()):
        var entry: Dictionary = units_a[i] as Dictionary
        var dt: float = (_death_time_a[i] if i < _death_time_a.size() else -1.0)
        entry["time_alive_s"] = (dt if dt >= 0.0 else total_time_s)
        units_a[i] = entry
    _units["a"] = units_a

    var units_b_data = _units.get("b", [])
    var units_b: Array = []
    if units_b_data is Array:
        units_b = units_b_data
    for j in range(units_b.size()):
        var entry_b: Dictionary = units_b[j] as Dictionary
        var dtb: float = (_death_time_b[j] if j < _death_time_b.size() else -1.0)
        entry_b["time_alive_s"] = (dtb if dtb >= 0.0 else total_time_s)
        units_b[j] = entry_b
    _units["b"] = units_b

func result() -> Dictionary:
    return {
        "teams": {
            "a": _team_entry("a").duplicate(),
            "b": _team_entry("b").duplicate(),
        },
        "units": {
            "a": _duplicate_units("a"),
            "b": _duplicate_units("b"),
        },
    }

func _duplicate_units(side: String) -> Array:
    var arr_data = _units.get(side, [])
    var arr: Array = []
    if arr_data is Array:
        arr = arr_data
    var out: Array = []
    for entry in arr:
        if entry is Dictionary:
            out.append((entry as Dictionary).duplicate())
    return out

func _on_hit_applied(team: String, sidx: int, tidx: int, _rolled: int, dealt: int, _crit: bool, _before_hp: int, after_hp: int, _pcd: float, _ecd: float) -> void:
    var src_key := _source_team_key(team)
    var dst_key := _opponent_of(src_key)
    var dealt_amt: int = max(0, int(dealt))
    if dealt_amt > 0:
        _add_team_and_unit(src_key, sidx, "damage", dealt_amt)
        # Per-unit defensive intake (post-mit): attribute to defender unit
        _increase_unit(dst_key, tidx, "incoming", dealt_amt)
        _maybe_set_first_hit(src_key, sidx)
    if int(after_hp) <= 0:
        _mark_death(dst_key, tidx)
        _increment_team_and_unit(src_key, sidx, "kills")

func _on_redirected_damage_applied(source_team: String, source_index: int, _original_target_team: String, _original_target_index: int, redirect_team: String, redirect_index: int, dealt_damage: int, _before_hp: int, after_hp: int, _kind: String) -> void:
    var source_side: String = _team_key(source_team)
    var redirect_side: String = _team_key(redirect_team)
    var amount: int = max(0, dealt_damage)
    if source_side == "" or redirect_side == "" or amount <= 0:
        return
    _add_team_and_unit(source_side, source_index, "damage", amount)
    _increase_unit(redirect_side, redirect_index, "incoming", amount)
    _increase_unit(redirect_side, redirect_index, "post_mit_incoming", amount)
    _maybe_set_first_hit(source_side, source_index)
    if after_hp <= 0:
        _mark_death(redirect_side, redirect_index)
        _increment_team_and_unit(source_side, source_index, "kills")

func _on_heal_applied(_st: String, _si: int, tt: String, ti: int, healed: int, _overheal: int, _bhp: int, _ahp: int) -> void:
    var dst_key := _team_key(tt)
    if dst_key == "":
        return
    _add_team_and_unit(dst_key, ti, "healing", int(healed))

func _on_shield_absorbed(tt: String, ti: int, absorbed: int) -> void:
    var dst_key := _team_key(tt)
    if dst_key == "":
        return
    _add_team_and_unit(dst_key, ti, "shield", int(absorbed))

func _on_hit_mitigated(_st: String, _si: int, tt: String, ti: int, pre_mit: int, post_pre_shield: int) -> void:
    var dst_key := _team_key(tt)
    if dst_key == "":
        return
    _add_team_and_unit(dst_key, ti, "mitigated", int(pre_mit))
    # Also track pre-mit incoming per defender unit for soak calculations
    _increase_unit(dst_key, ti, "pre_mit_incoming", int(pre_mit))
    _increase_unit(dst_key, ti, "post_mit_incoming", int(max(0, post_pre_shield)))

func _on_hit_overkill(st: String, si: int, _tt: String, _ti: int, overkill: int) -> void:
    var src_key := _team_key(st)
    if src_key == "":
        return
    _add_team_and_unit(src_key, si, "overkill", int(overkill))

func _on_hit_components(_st: String, _si: int, _tt: String, _ti: int, _phys: int, _mag: int, _tru: int) -> void:
    pass

func _on_ability_committed(source_team: String, source_index: int, _ability_id: String, _target_team: String, _target_index: int, _position: Vector2, _cooldown_s: float, _commitment_kind: String) -> void:
    var side: String = _team_key(source_team)
    if side == "":
        return
    _inc_cast(side, source_index)

func _source_team_key(team_str: String) -> String:
    var t := String(team_str)
    if _player_is_team_a:
        return ("a" if t == "player" else "b")
    return ("a" if t == "enemy" else "b")

func _team_key(team_str: String) -> String:
    var t := String(team_str)
    if _player_is_team_a:
        return ("a" if t == "player" else "b")
    return ("a" if t == "enemy" else "b")

func _opponent_of(side: String) -> String:
    return ("b" if side == "a" else "a")

func _inc_cast(side: String, idx: int) -> void:
    _increment_team_and_unit(side, idx, "casts")
    _maybe_set_first_cast(side, idx)

func _maybe_set_first_hit(side: String, idx: int) -> void:
    var team_entry: Dictionary = _team_entry(side)
    if float(team_entry.get("first_hit_s", -1.0)) < 0.0:
        team_entry["first_hit_s"] = _time_s
        _team[side] = team_entry
    var unit_entry: Dictionary = _unit_entry(side, idx)
    if unit_entry.is_empty():
        return
    if float(unit_entry.get("first_hit_s", -1.0)) < 0.0:
        unit_entry["first_hit_s"] = _time_s
        _set_unit_entry(side, idx, unit_entry)

func _maybe_set_first_cast(side: String, idx: int) -> void:
    var team_entry: Dictionary = _team_entry(side)
    if float(team_entry.get("first_cast_s", -1.0)) < 0.0:
        team_entry["first_cast_s"] = _time_s
        _team[side] = team_entry
    var unit_entry: Dictionary = _unit_entry(side, idx)
    if unit_entry.is_empty():
        return
    if float(unit_entry.get("first_cast_s", -1.0)) < 0.0:
        unit_entry["first_cast_s"] = _time_s
        _set_unit_entry(side, idx, unit_entry)

func _mark_death(side: String, idx: int) -> void:
    var now := _time_s
    if side == "a":
        if idx >= 0 and idx < _death_time_a.size() and _death_time_a[idx] < 0.0:
            _death_time_a[idx] = now
            _increase_team(side, "deaths", 1)
            _increase_unit(side, idx, "deaths", 1)
    else:
        if idx >= 0 and idx < _death_time_b.size() and _death_time_b[idx] < 0.0:
            _death_time_b[idx] = now
            _increase_team(side, "deaths", 1)
            _increase_unit(side, idx, "deaths", 1)

func _add_team_and_unit(side: String, idx: int, key: String, amount: int) -> void:
    if amount == 0:
        return
    _increase_team(side, key, amount)
    _increase_unit(side, idx, key, amount)

func _increment_team_and_unit(side: String, idx: int, key: String) -> void:
    _increase_team(side, key, 1)
    _increase_unit(side, idx, key, 1)

func _team_entry(side: String) -> Dictionary:
    if not _team.has(side):
        _team[side] = _new_team_totals()
    return _team[side]

func _unit_entry(side: String, idx: int) -> Dictionary:
    var arr_data = _units.get(side, [])
    if not (arr_data is Array):
        return {}
    var arr: Array = arr_data as Array
    if arr.is_empty():
        return {}
    var clamped: int = clamp(int(idx), 0, arr.size() - 1)
    var value = arr[clamped]
    return value if value is Dictionary else {}

func _set_unit_entry(side: String, idx: int, entry: Dictionary) -> void:
    var arr_data = _units.get(side, [])
    if not (arr_data is Array):
        return
    var arr: Array = arr_data as Array
    if arr.is_empty():
        return
    var clamped: int = clamp(int(idx), 0, arr.size() - 1)
    arr[clamped] = entry
    _units[side] = arr

func _increase_team(side: String, key: String, amount: int) -> void:
    var entry := _team_entry(side)
    entry[key] = int(entry.get(key, 0)) + amount
    _team[side] = entry

func _increase_unit(side: String, idx: int, key: String, amount: int) -> void:
    var arr_data = _units.get(side, [])
    if not (arr_data is Array):
        return
    var arr: Array = arr_data as Array
    if arr.is_empty():
        return
    var clamped: int = clamp(int(idx), 0, arr.size() - 1)
    var value = arr[clamped]
    if not (value is Dictionary):
        return
    var entry: Dictionary = value
    entry[key] = int(entry.get(key, 0)) + amount
    arr[clamped] = entry
    _units[side] = arr
