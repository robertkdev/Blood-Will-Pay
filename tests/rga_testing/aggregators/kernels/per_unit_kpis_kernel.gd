extends RefCounted

# Per-Unit KPIs Kernel
# Emits per-unit attribution keyed by unit_id with:
#  - time_on_target_pct
#  - attack_distance_median_tiles
#  - attacks_over_2_tiles_pct
#  - damage_over_2_tiles_pct
#  - damage_to_frontline_pct
#  - kiting_tax (proxy)

const SIDE_A := "a"
const SIDE_B := "b"
const TEAM_PLAYER := "player"
const TEAM_ENEMY := "enemy"

var _engine = null
var _connected: bool = false
var _player_is_team_a: bool = true
var _time_s: float = 0.0
var _tile_size: float = 1.0

var _team_sizes: Dictionary = { SIDE_A: 0, SIDE_B: 0 }
var _id_map: Dictionary = { SIDE_A: {}, SIDE_B: {} }           # side -> idx -> unit_id
var _frontline_targets: Dictionary = { SIDE_A: {}, SIDE_B: {} } # side -> idx(frontline true)

var _on_target: Dictionary = { SIDE_A: {}, SIDE_B: {} }         # side -> idx -> bool
var _obs_time: Dictionary = { SIDE_A: {}, SIDE_B: {} }          # side -> idx -> seconds
var _on_target_time: Dictionary = { SIDE_A: {}, SIDE_B: {} }    # side -> idx -> seconds
var _hit_dists: Dictionary = { SIDE_A: {}, SIDE_B: {} }         # side -> idx -> Array[float]
var _hits_total: Dictionary = { SIDE_A: {}, SIDE_B: {} }        # side -> idx -> int
var _hits_over_2: Dictionary = { SIDE_A: {}, SIDE_B: {} }       # side -> idx -> int
var _dmg_total: Dictionary = { SIDE_A: {}, SIDE_B: {} }         # side -> idx -> float
var _dmg_front: Dictionary = { SIDE_A: {}, SIDE_B: {} }         # side -> idx -> float
var _dmg_over_2: Dictionary = { SIDE_A: {}, SIDE_B: {} }        # side -> idx -> float

func attach(engine, team_sizes: Dictionary, context_tags: Dictionary = {}, player_is_team_a: bool = true) -> void:
    detach()
    _engine = engine
    _player_is_team_a = player_is_team_a
    _time_s = 0.0
    _team_sizes = { SIDE_A: int(team_sizes.get(SIDE_A, 0)), SIDE_B: int(team_sizes.get(SIDE_B, 0)) }
    _tile_size = _resolve_tile_size(engine, context_tags)
    _build_id_map(context_tags)
    _build_frontline_map(context_tags)
    _reset_accumulators()
    _connected = _connect()

func detach() -> void:
    if _engine != null:
        if _engine.has_signal("target_start") and _engine.is_connected("target_start", Callable(self, "_on_target_start")):
            _engine.target_start.disconnect(_on_target_start)
        if _engine.has_signal("target_end") and _engine.is_connected("target_end", Callable(self, "_on_target_end")):
            _engine.target_end.disconnect(_on_target_end)
        if _engine.has_signal("hit_applied") and _engine.is_connected("hit_applied", Callable(self, "_on_hit_applied")):
            _engine.hit_applied.disconnect(_on_hit_applied)
    _engine = null
    _connected = false

func tick(delta_s: float) -> void:
    var dt: float = max(0.0, float(delta_s))
    _time_s += dt
    # Accumulate observed and on-target times per unit
    for side in [SIDE_A, SIDE_B]:
        var n := int(_team_sizes.get(side, 0))
        for i in range(n):
            _obs_time[side][i] = float(_obs_time[side].get(i, 0.0)) + dt
            if bool(_on_target[side].get(i, false)):
                _on_target_time[side][i] = float(_on_target_time[side].get(i, 0.0)) + dt

func finalize(_total_time_s: float) -> void:
    pass

func result() -> Dictionary:
    var out_a: Dictionary = _summarize_side(SIDE_A)
    var out_b: Dictionary = _summarize_side(SIDE_B)
    return { "per_unit_kpis": { "supported": true, SIDE_A: out_a, SIDE_B: out_b } }

func register(_aggregator) -> RefCounted:
    return self

# --- internals ---

func _resolve_tile_size(engine, context_tags: Dictionary) -> float:
    var metadata: Dictionary = context_tags.get("metadata", {}) if (context_tags is Dictionary) else {}
    if metadata is Dictionary and metadata.has("tile_size"):
        return max(0.0001, float(metadata.get("tile_size", 1.0)))
    if engine != null and engine.has_method("get"):
        var arena: Variant = engine.get("arena_state")
        if arena != null and arena.has_method("tile_size"):
            return max(0.0001, float(arena.tile_size()))
    return 1.0

func _connect() -> bool:
    if _engine == null:
        return false
    if _engine.has_signal("target_start"):
        _engine.connect("target_start", Callable(self, "_on_target_start"))
    if _engine.has_signal("target_end"):
        _engine.connect("target_end", Callable(self, "_on_target_end"))
    if _engine.has_signal("hit_applied"):
        _engine.connect("hit_applied", Callable(self, "_on_hit_applied"))
    return true

func _source_side(team_str: String) -> String:
    var t := String(team_str)
    if _player_is_team_a:
        return (SIDE_A if t == TEAM_PLAYER else SIDE_B)
    return (SIDE_A if t == TEAM_ENEMY else SIDE_B)

func _opponent_side(side: String) -> String:
    return (SIDE_B if side == SIDE_A else SIDE_A)

func _build_id_map(context_tags: Dictionary) -> void:
    _id_map = { SIDE_A: {}, SIDE_B: {} }
    var timelines = context_tags.get("unit_timelines", {})
    if not (timelines is Dictionary):
        return
    for side in [SIDE_A, SIDE_B]:
        var arr = timelines.get(side, [])
        if not (arr is Array):
            continue
        for entry in arr:
            if not (entry is Dictionary):
                continue
            var idx := int(entry.get("unit_index", -1))
            if idx < 0:
                continue
            var uid := String(entry.get("unit_id", ""))
            if uid == "":
                uid = "%s_%d" % [side, idx]
            _id_map[side][idx] = uid

func _build_frontline_map(context_tags: Dictionary) -> void:
    _frontline_targets = { SIDE_A: {}, SIDE_B: {} }
    var timelines = context_tags.get("unit_timelines", {})
    if not (timelines is Dictionary):
        return
    for side in [SIDE_A, SIDE_B]:
        var arr = timelines.get(side, [])
        if not (arr is Array):
            continue
        for entry in arr:
            if not (entry is Dictionary):
                continue
            var idx := int(entry.get("unit_index", -1))
            if idx < 0:
                continue
            var entries: Array = entry.get("entries", [])
            var is_front := false
            for e in entries:
                if e is Dictionary and String(e.get("tag", "")).to_lower() == "frontline":
                    is_front = true
                    break
            if is_front:
                _frontline_targets[side][idx] = true

func _reset_accumulators() -> void:
    for side in [SIDE_A, SIDE_B]:
        var n := int(_team_sizes.get(side, 0))
        var obs: Dictionary = {}
        var tgt: Dictionary = {}
        var hits: Dictionary = {}
        var ht: Dictionary = {}
        var ho2: Dictionary = {}
        var dtt: Dictionary = {}
        var dtf: Dictionary = {}
        var dto2: Dictionary = {}
        var ont: Dictionary = {}
        for i in range(n):
            obs[i] = 0.0
            tgt[i] = 0.0
            hits[i] = []
            ht[i] = 0
            ho2[i] = 0
            dtt[i] = 0.0
            dtf[i] = 0.0
            dto2[i] = 0.0
            ont[i] = false
        _obs_time[side] = obs
        _on_target_time[side] = tgt
        _hit_dists[side] = hits
        _hits_total[side] = ht
        _hits_over_2[side] = ho2
        _dmg_total[side] = dtt
        _dmg_front[side] = dtf
        _dmg_over_2[side] = dto2
        _on_target[side] = ont

func _on_target_start(source_team: String, source_index: int, _target_team: String, _target_index: int) -> void:
    var side := _source_side(source_team)
    if side == "":
        return
    _on_target[side][int(source_index)] = true

func _on_target_end(source_team: String, source_index: int, _target_team: String, _target_index: int) -> void:
    var side := _source_side(source_team)
    if side == "":
        return
    _on_target[side][int(source_index)] = false

func _on_hit_applied(team: String, source_index: int, target_index: int, _rolled: int, dealt: int, _crit: bool, _bhp: int, _ahp: int, _pcd: float, _ecd: float) -> void:
    var src_side := _source_side(team)
    var dst_side := _opponent_side(src_side)
    if src_side == "" or dst_side == "":
        return
    var sidx: int = int(source_index)
    var tidx: int = int(target_index)
    # Damage attribution
    _dmg_total[src_side][sidx] = float(_dmg_total[src_side].get(sidx, 0.0)) + max(0, int(dealt))
    if bool(_frontline_targets.get(dst_side, {}).get(tidx, false)):
        _dmg_front[src_side][sidx] = float(_dmg_front[src_side].get(sidx, 0.0)) + max(0, int(dealt))
    # Distance measurement
    var spos := _get_position(src_side, sidx)
    var tpos := _get_position(dst_side, tidx)
    if spos is Vector2 and tpos is Vector2:
        var dist_tiles: float = ((spos as Vector2).distance_to(tpos as Vector2)) / max(0.0001, _tile_size)
        (_hit_dists[src_side][sidx] as Array).append(dist_tiles)
        _hits_total[src_side][sidx] = int(_hits_total[src_side].get(sidx, 0)) + 1
        if dist_tiles >= 2.0:
            _hits_over_2[src_side][sidx] = int(_hits_over_2[src_side].get(sidx, 0)) + 1
            _dmg_over_2[src_side][sidx] = float(_dmg_over_2[src_side].get(sidx, 0.0)) + max(0, int(dealt))

func _get_position(side: String, idx: int) -> Vector2:
    if _engine == null:
        return Vector2.ZERO
    if side == SIDE_A:
        if _player_is_team_a:
            return _engine.get_player_position(idx)
        return _engine.get_enemy_position(idx)
    else:
        if _player_is_team_a:
            return _engine.get_enemy_position(idx)
        return _engine.get_player_position(idx)

func _summarize_side(side: String) -> Dictionary:
    var out: Dictionary = {}
    var n := int(_team_sizes.get(side, 0))
    for i in range(n):
        var uid: String = String(_id_map.get(side, {}).get(i, ""))
        if uid == "":
            uid = "%s_%d" % [side, i]
        var obs: float = float(_obs_time[side].get(i, 0.0))
        var on_t: float = float(_on_target_time[side].get(i, 0.0))
        var hits: int = int(_hits_total[side].get(i, 0))
        var over2: int = int(_hits_over_2[side].get(i, 0))
        var d_all: float = float(_dmg_total[side].get(i, 0.0))
        var d_front: float = float(_dmg_front[side].get(i, 0.0))
        var time_on_target_pct: float = (on_t / max(0.001, obs))
        var attacks_over_2_tiles_pct: float = (float(over2) / max(1.0, float(hits)))
        var damage_over_2_tiles_pct: float = (float(_dmg_over_2[side].get(i, 0.0)) / max(0.001, d_all)) if d_all > 0.0 else 0.0
        var damage_to_frontline_pct: float = (d_front / max(0.001, d_all)) if d_all > 0.0 else 0.0
        var med_dist: float = _median(_hit_dists[side].get(i, []))
        # Kiting tax (proxy): lower when high hits per second while on target
        var kiting_tax: float = 1.0
        if on_t > 0.0:
            var hps := float(hits) / on_t
            kiting_tax = clamp(1.0 - hps, 0.0, 1.0)
        out[uid] = {
            "time_on_target_pct": time_on_target_pct,
            "attack_distance_median_tiles": med_dist,
            "attacks_over_2_tiles_pct": attacks_over_2_tiles_pct,
            "damage_over_2_tiles_pct": damage_over_2_tiles_pct,
            "damage_to_frontline_pct": damage_to_frontline_pct,
            "kiting_tax": kiting_tax
        }
    return out

func _median(vs) -> float:
    var arr: Array = []
    if vs is Array:
        for v in vs:
            arr.append(float(v))
    if arr.is_empty():
        return 0.0
    arr.sort()
    var n := arr.size()
    var mid := int(float(n) * 0.5)
    if (n % 2) == 1:
        return float(arr[mid])
    return 0.5 * (float(arr[mid-1]) + float(arr[mid]))
