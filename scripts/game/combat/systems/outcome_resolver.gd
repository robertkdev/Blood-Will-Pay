extends RefCounted
class_name OutcomeResolver

var state: BattleState
var rng: RandomNumberGenerator
var outcome_sent: bool = false

func configure(_state: BattleState, _rng: RandomNumberGenerator) -> void:
    state = _state
    rng = _rng
    outcome_sent = false

func reset() -> void:
    outcome_sent = false

func evaluate_idle(totals: Dictionary) -> String:
    if outcome_sent:
        return ""
    var outcome: String = _outcome_from_board(
        BattleState.all_dead(state.player_team),
        BattleState.all_dead(state.enemy_team),
        totals
    )
    if outcome != "":
        outcome_sent = true
    return outcome

func evaluate_board(totals: Dictionary) -> String:
    if outcome_sent:
        return ""
    var outcome: String = _outcome_from_board(
        BattleState.all_dead(state.player_team),
        BattleState.all_dead(state.enemy_team),
        totals
    )
    if outcome != "":
        outcome_sent = true
    return outcome

func evaluate_frame(frame_flags: Dictionary) -> String:
    if outcome_sent:
        return ""
    # Resolve immediately only if exactly one team is defeated.
    var player_team_defeated: bool = bool(frame_flags.get("player_team_defeated", false))
    var enemy_team_defeated: bool = bool(frame_flags.get("enemy_team_defeated", false))
    if enemy_team_defeated and not player_team_defeated:
        outcome_sent = true
        return "victory"
    if player_team_defeated and not enemy_team_defeated:
        outcome_sent = true
        return "defeat"
    # Double KO or both dead at frame-level: defer to board evaluation.
    return ""

func mark_emitted() -> void:
    outcome_sent = true

func _outcome_from_board(player_team_defeated: bool, enemy_team_defeated: bool, _totals: Dictionary) -> String:
    if player_team_defeated and enemy_team_defeated:
        return "tie"
    elif player_team_defeated:
        return "defeat"
    elif enemy_team_defeated:
        return "victory"
    return ""

