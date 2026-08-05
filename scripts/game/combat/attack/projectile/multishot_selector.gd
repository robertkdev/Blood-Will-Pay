extends RefCounted
class_name MultishotSelector

const BuffTags := preload("res://scripts/game/abilities/buff_tags.gd")

var rng: RandomNumberGenerator = null
var hooks: Variant = null

func configure(_rng: RandomNumberGenerator, _hooks: Variant) -> void:
    rng = _rng
    hooks = _hooks

func _enemy_team_name(team: String) -> String:
    return "enemy" if team == "player" else "player"

func _enemy_arr(state: BattleState, team: String) -> Array[Unit]:
    return state.enemy_team if team == "player" else state.player_team

func _alive_indices(state: BattleState, team: String) -> Array[int]:
    var arr: Array[int] = []
    var enemies: Array[Unit] = _enemy_arr(state, team)
    for i in range(enemies.size()):
        var u: Unit = enemies[i]
        if u != null and u.is_alive():
            arr.append(i)
    return arr

func pick_base_target(state: BattleState, team: String, shooter_index: int, default_idx: int) -> int:
    if state == null:
        return default_idx
    var extra: int = 0
    if hooks != null and hooks.has_method("nyxa_extra_shots"):
        extra = int(hooks.nyxa_extra_shots(state, team, shooter_index))
    if extra <= 0:
        return default_idx
    var alive: Array[int] = _alive_indices(state, team)
    if alive.is_empty():
        return default_idx
    var pick_index: int = rng.randi_range(0, alive.size() - 1) if rng != null else 0
    return int(alive[pick_index])

func extra_targets(state: BattleState, team: String, shooter_index: int) -> Array[int]:
    var out: Array[int] = []
    if state == null:
        return out
    var extra: int = 0
    if hooks != null and hooks.has_method("nyxa_extra_shots"):
        extra = int(hooks.nyxa_extra_shots(state, team, shooter_index))
    if extra <= 0:
        return out
    var alive: Array[int] = _alive_indices(state, team)
    if alive.is_empty():
        return out
    for _i in range(extra):
        var pick_idx: int = (rng.randi_range(0, alive.size() - 1) if rng != null else 0)
        out.append(alive[pick_idx])
    _consume_nyxa_attack(state, team, shooter_index)
    return out

func _consume_nyxa_attack(state: BattleState, team: String, shooter_index: int) -> void:
    if hooks == null or state == null:
        return
    var active_buff_system: BuffSystem = hooks.get("buff_system") as BuffSystem
    if active_buff_system == null:
        return
    var tag: Dictionary = active_buff_system.get_tag(state, team, shooter_index, BuffTags.TAG_NYXA)
    if tag.is_empty():
        return
    var meta: Dictionary = tag.get("data", {})
    var attacks_left: int = int(meta.get("attacks_left", 0))
    var updated: Dictionary = meta.duplicate(true)
    updated["attacks_left"] = max(0, attacks_left - 1)
    tag["data"] = updated
    if int(updated["attacks_left"]) <= 0:
        tag["remaining"] = 0.0
