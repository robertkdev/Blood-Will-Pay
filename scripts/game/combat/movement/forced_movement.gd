extends RefCounted
class_name ForcedMovement

# ForcedMovement
# Tracks per-unit forced movement impulses (e.g., knockbacks) that temporarily
# override normal movement. Each impulse is modeled as a total displacement
# to be applied evenly over its lifetime. When active, only forced movement is
# applied for that unit; normal approach steps are skipped.

class Impulse:
    var total: Vector2
    var remaining: float
    var duration: float
    func _init(_vec: Vector2, _dur: float) -> void:
        total = _vec
        duration = max(0.0001, _dur)
        remaining = duration
    func step(dt: float) -> Vector2:
        var d: float = clampf(dt, 0.0, remaining)
        var frac: float = d / duration
        var out: Vector2 = total * frac
        remaining -= d
        return out
    func is_done() -> bool:
        return remaining <= 0.0

var _team_maps: Dictionary[String, Dictionary] = {} # team -> Dictionary[int, Impulse]
var _team_counts: Dictionary[String, int] = {}

func add(team: String, idx: int, vec: Vector2, duration: float) -> void:
    if duration <= 0.0 or vec == Vector2.ZERO:
        return
    var team_map_value: Variant = _team_maps.get(team, null)
    var team_map: Dictionary = {}
    if team_map_value is Dictionary:
        team_map = team_map_value
    else:
        _team_maps[team] = team_map
    if not team_map.has(idx):
        _team_counts[team] = int(_team_counts.get(team, 0)) + 1
    team_map[idx] = Impulse.new(vec, duration)

func has_any() -> bool:
    return not _team_counts.is_empty()

func has_any_for_team(team: String) -> bool:
    return int(_team_counts.get(team, 0)) > 0

func has_active(team: String, idx: int) -> bool:
    var team_map_value: Variant = _team_maps.get(team, null)
    if not (team_map_value is Dictionary):
        return false
    var team_map: Dictionary = team_map_value
    var impulse_value: Variant = team_map.get(idx, null)
    return impulse_value is Impulse and not (impulse_value as Impulse).is_done()

func consume_step(team: String, idx: int, dt: float) -> Vector2:
    var team_map_value: Variant = _team_maps.get(team, null)
    if not (team_map_value is Dictionary):
        return Vector2.ZERO
    var team_map: Dictionary = team_map_value
    var impulse_value: Variant = team_map.get(idx, null)
    if not (impulse_value is Impulse):
        return Vector2.ZERO
    var imp: Impulse = impulse_value
    if imp.is_done():
        _erase_impulse(team, idx)
        return Vector2.ZERO
    var step_vec: Vector2 = imp.step(dt)
    if imp.is_done():
        _erase_impulse(team, idx)
    return step_vec

func _erase_impulse(team: String, idx: int) -> void:
    var team_map_value: Variant = _team_maps.get(team, null)
    if not (team_map_value is Dictionary):
        return
    var team_map: Dictionary = team_map_value
    if not team_map.has(idx):
        return
    team_map.erase(idx)
    if team_map.is_empty():
        _team_maps.erase(team)
    var current: int = int(_team_counts.get(team, 0))
    if current <= 1:
        _team_counts.erase(team)
    else:
        _team_counts[team] = current - 1

func clear() -> void:
    _team_maps.clear()
    _team_counts.clear()
