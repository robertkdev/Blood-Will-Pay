extends RefCounted
class_name ItemEffectBase

var manager: CombatManager = null
var engine: CombatEngine = null
var buff_system: BuffSystem = null

func configure(_manager: CombatManager, _engine: CombatEngine, _buff_system: BuffSystem) -> void:
    manager = _manager
    engine = _engine
    buff_system = _buff_system

# Unified event entrypoint: override in concrete effects.
func on_event(_unit: Unit, _event: String, _data: Dictionary) -> void:
    pass

func _team_index_of(u: Unit) -> Dictionary:
    var res: Dictionary = {"team": "", "index": -1}
    if u == null:
        return res
    var player_team: Array = _team_array("player")
    for i: int in range(player_team.size()):
        if player_team[i] == u:
            res.team = "player"
            res.index = i
            return res
    var enemy_team: Array = _team_array("enemy")
    for j: int in range(enemy_team.size()):
        if enemy_team[j] == u:
            res.team = "enemy"
            res.index = j
            return res
    return res

func _unit_at(team: String, index: int) -> Unit:
    if index < 0:
        return null
    var units: Array = _team_array(team)
    if index >= units.size():
        return null
    return units[index] as Unit

func _team_array(team: String) -> Array:
    if manager != null:
        return manager.player_team if team == "player" else manager.enemy_team
    if engine != null and engine.state != null:
        return engine.state.player_team if team == "player" else engine.state.enemy_team
    return []

func _state() -> BattleState:
    return (engine.state if engine != null else null)

func _other_team(team: String) -> String:
    return "enemy" if team == "player" else "player"
