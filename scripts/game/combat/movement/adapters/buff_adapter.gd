extends RefCounted
class_name MovementBuffAdapter

# MovementBuffAdapter
# Lightweight shim so Movement can query status from BuffSystem without taking
# a hard dependency on engine internals. Treats the presence of a stun or a
# generic root tag as blocking movement for that unit.

var buff_system: BuffSystem = null

func configure(_buff_system: BuffSystem) -> void:
    buff_system = _buff_system

func has_movement_blockers() -> bool:
    return buff_system != null and buff_system.has_movement_blockers()

func is_blocked(state: BattleState, team: String, idx: int) -> bool:
    if buff_system == null or state == null:
        return false
    return buff_system.is_movement_blocked(state, team, idx)

func is_unit_blocked(unit: Unit) -> bool:
    if buff_system == null:
        return false
    return buff_system.is_unit_movement_blocked(unit)
