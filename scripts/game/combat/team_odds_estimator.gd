extends Object
class_name TeamOddsEstimator

const CombatPowerModel := preload("res://scripts/game/combat/combat_power_model.gd")

const MIN_PERCENT: int = 1
const MAX_PERCENT: int = 99
const EMPTY_TEAM_RATING: float = 1.0
const ODDS_EXPONENT: float = CombatPowerModel.ODDS_EXPONENT

static func estimate_win_percent(player_team: Array[Unit], enemy_team: Array[Unit]) -> int:
	var player_rating: float = team_rating(player_team)
	var enemy_rating: float = team_rating(enemy_team)
	return estimate_from_ratings(player_rating, enemy_rating)

static func estimate_from_ratings(player_rating: float, enemy_rating: float) -> int:
	return CombatPowerModel.estimate_from_powers(player_rating, enemy_rating)

static func team_rating(team: Array[Unit]) -> float:
	return CombatPowerModel.team_power(team)

static func unit_rating(unit: Unit) -> float:
	return CombatPowerModel.unit_power(unit)
