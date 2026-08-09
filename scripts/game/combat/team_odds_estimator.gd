extends Object
class_name TeamOddsEstimator

const CombatPowerModel := preload("res://scripts/game/combat/combat_power_model.gd")

const MIN_PERCENT: int = 1
const MAX_PERCENT: int = 99
const EMPTY_TEAM_RATING: float = 1.0
const ODDS_EXPONENT: float = CombatPowerModel.ODDS_EXPONENT
# The broad live-combat calibration's worst populated-bucket miss was 12.4
# percentage points. Round outward so the player sees a decision aid with an
# honest empirical guard band instead of a false point estimate.
const CALIBRATION_ERROR_POINTS: int = 15
# Boss previews are shown before the live encounter escalation can trigger.
# This factor is the calibrated equivalent for the default heal/revive/attack
# phases; it keeps the player-facing quote aligned with the fight it will run.
const BOSS_ESCALATION_PREVIEW_FACTOR: float = 1.25

static func estimate_win_percent(player_team: Array[Unit], enemy_team: Array[Unit], enemy_power_multiplier: float = 1.0) -> int:
	var player_rating: float = team_rating(player_team)
	var enemy_rating: float = team_rating(enemy_team)
	return estimate_from_ratings(player_rating, enemy_rating, enemy_power_multiplier)

static func estimate_from_ratings(player_rating: float, enemy_rating: float, enemy_power_multiplier: float = 1.0) -> int:
	return CombatPowerModel.estimate_from_powers(player_rating, preview_enemy_power(enemy_rating, enemy_power_multiplier))

static func estimate_range(midpoint_percent: int) -> Vector2i:
	var midpoint: int = clampi(midpoint_percent, MIN_PERCENT, MAX_PERCENT)
	return Vector2i(
		clampi(midpoint - CALIBRATION_ERROR_POINTS, MIN_PERCENT, MAX_PERCENT),
		clampi(midpoint + CALIBRATION_ERROR_POINTS, MIN_PERCENT, MAX_PERCENT)
	)

static func preview_enemy_power(enemy_rating: float, enemy_power_multiplier: float = 1.0) -> float:
	return max(CombatPowerModel.MIN_POWER, float(enemy_rating) * max(1.0, float(enemy_power_multiplier)))

static func team_rating(team: Array[Unit]) -> float:
	return CombatPowerModel.team_power(team)

static func unit_rating(unit: Unit) -> float:
	return CombatPowerModel.unit_power(unit)
