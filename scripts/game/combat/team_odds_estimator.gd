extends Object
class_name TeamOddsEstimator

const CombatPowerModel := preload("res://scripts/game/combat/combat_power_model.gd")

const MIN_PERCENT: int = 1
const MAX_PERCENT: int = 99
const EMPTY_TEAM_RATING: float = 1.0
const ODDS_EXPONENT: float = CombatPowerModel.ODDS_EXPONENT
# The broad live-combat calibration's worst populated-bucket miss was 12.4
# percentage points. Round outward as a rough decision aid, not a calibrated
# guarantee for boards with abilities, items, placement, hazards, or targeting.
const DISPLAY_RANGE_POINTS: int = 15
# Boss previews are shown before the live encounter escalation can trigger.
# This factor is a preview heuristic for the default heal/revive/attack phases.
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
		clampi(midpoint - DISPLAY_RANGE_POINTS, MIN_PERCENT, MAX_PERCENT),
		clampi(midpoint + DISPLAY_RANGE_POINTS, MIN_PERCENT, MAX_PERCENT)
	)

## Per-encounter correction to the quoted win odds, in log-odds.
##
## The rating ratio is a fair predictor of a mirror - both sides are the same board - and of a
## creep wave. It is badly optimistic about normal waves and mildly optimistic about bosses,
## because a generated board's rating does not convert into the field strength its rating
## claims. The rig watched this for two days: it won far more often than the panel said,
## which also made it wager smaller than the truth justified.
##
## Fitted on 4,494 recorded fights from 123 Jev runs, as the actual-minus-quoted log-odds
## residual per encounter kind:
##
##   kind      n      quoted   actual   residual
##   NORMAL    1775   0.589    0.856    +1.427
##   BOSS      1128   0.409    0.563    +0.620
##   MIRROR    1035   0.544    0.538    -0.024
##   CREEPS     556   0.985    1.000     ~0
##
## Mirror and creep waves are already honest, so they are left alone. The correction is
## measured against the Jev rig's play, which is stronger than a first-time player's, so these
## numbers describe the boards the rig actually fields rather than a floor for everyone.
##
## Only the quoted odds move with this. Payouts are priced by the encounter tier and the enemy
## generator never reads the estimate, so difficulty is untouched.
const ENCOUNTER_ODDS_BIAS: Dictionary = {
	"CREEPS": 0.0,
	"NORMAL": 1.427,
	"BOSS": 0.620,
	"MIRROR": -0.024,
}

## The quoted win percent for an encounter of this kind, corrected to what actually happens.
static func quote_win_percent(percent: int, encounter_kind: String) -> int:
	var bias: float = float(ENCOUNTER_ODDS_BIAS.get(String(encounter_kind).strip_edges().to_upper(), 0.0))
	var bounded: int = clampi(percent, MIN_PERCENT, MAX_PERCENT)
	if is_zero_approx(bias):
		return bounded
	# Adding to the log-odds multiplies the odds.
	var probability: float = clampf(float(bounded) / 100.0, 0.001, 0.999)
	var quoted_odds: float = probability / (1.0 - probability)
	var corrected_odds: float = quoted_odds * exp(bias)
	var corrected: float = corrected_odds / (1.0 + corrected_odds)
	return clampi(int(round(corrected * 100.0)), MIN_PERCENT, MAX_PERCENT)

static func preview_enemy_power(enemy_rating: float, enemy_power_multiplier: float = 1.0) -> float:
	return max(CombatPowerModel.MIN_POWER, float(enemy_rating) * max(1.0, float(enemy_power_multiplier)))

static func team_rating(team: Array[Unit]) -> float:
	return CombatPowerModel.team_power(team)

static func unit_rating(unit: Unit) -> float:
	return CombatPowerModel.unit_power(unit)
