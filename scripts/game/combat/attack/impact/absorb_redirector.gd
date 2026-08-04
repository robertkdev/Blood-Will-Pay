extends RefCounted
class_name AbsorbRedirector

const Health := preload("res://scripts/game/stats/health.gd")

var hooks

func configure(_hooks) -> void:
    hooks = _hooks

func divert(state: BattleState, target_team: String, target_index: int, incoming: int) -> Dictionary:
    var result: Dictionary = {"diverted": 0, "leftover": max(0, incoming), "redirect_index": -1}
    if hooks == null or state == null or incoming <= 0:
        return result
    var redirect_index: int = int(hooks.korath_redirect_index(state, target_team, target_index)) if hooks.has_method("korath_redirect_index") else -1
    if redirect_index < 0 or redirect_index == target_index:
        return result
    var pct: float = float(hooks.korath_absorb_pct(state, target_team, redirect_index)) if hooks.has_method("korath_absorb_pct") else 0.0
    if pct <= 0.0:
        return result
    var divert_amt: int = int(floor(float(incoming) * pct))
    if divert_amt <= 0:
        return result
    var allies: Array[Unit] = state.player_team if target_team == "player" else state.enemy_team
    var redirect_unit: Unit = allies[redirect_index] if redirect_index < allies.size() else null
    if redirect_unit == null or not redirect_unit.is_alive():
        return result
    var transfer: Dictionary = Health.apply_damage(redirect_unit, divert_amt)
    var transferred: int = int(transfer.get("dealt", 0))
    if transferred <= 0:
        return result
    if hooks.has_method("korath_accumulate_pool"):
        hooks.korath_accumulate_pool(state, target_team, redirect_index, transferred)
    result.diverted = transferred
    result.redirect_index = redirect_index
    result.leftover = max(0, incoming - transferred)
    return result
