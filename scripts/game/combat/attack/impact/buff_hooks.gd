extends RefCounted
class_name BuffHooks

func nyxa_extra_shots(_state: BattleState, _team: String, _index: int) -> int:
	return 0

func nyxa_per_shot_bonus(_state: BattleState, _team: String, _index: int) -> int:
	return 0

func korath_absorb_pct(_state: BattleState, _team: String, _index: int) -> float:
	return 0.0

func korath_redirect_for_ally(_state: BattleState, _team: String, _index: int) -> Dictionary:
	return {}

func korath_on_redirected_damage(_state: BattleState, _team: String, _index: int, _amount: int, _kind: String) -> void:
	pass

func korath_accumulate_pool(_state: BattleState, _team: String, _index: int, _amount: int) -> void:
	pass

func unstable_pre_phys_bonus(_state: BattleState, _team: String, _index: int, _tgt_team: String, _target_index: int) -> float:
	return 0.0

# Executioner specials
func exec_ignore_shields_on_crit(_state: BattleState, _team: String, _index: int) -> bool:
	return false

func exec_true_bonus_pct(_state: BattleState, _team: String, _index: int) -> float:
	return 0.0
