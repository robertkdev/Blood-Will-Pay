extends RefCounted
class_name OutcomeLadder

## Forced-result ladder for a fight that runs the clock out.
##
## TFT resolves a round at its time limit and never draws: the side with more units
## alive wins, and equal survivors are decided by total remaining health. Absolute
## remaining health is the rule, not a fraction of the roster - a fraction divides by
## the team's full maximum including dead units, so it can rank two sides the other
## way round from the health they actually have left.
##
## Returns "" when the ladder cannot separate the sides (a mutual wipe, or an exact
## tie on survivors and health) so the caller can fall back to the seeded roll and
## keep the round decisive.

static func decide(player_alive: int, enemy_alive: int, player_health: int, enemy_health: int) -> String:
	if player_alive <= 0 and enemy_alive <= 0:
		return ""
	if player_alive != enemy_alive:
		return "victory" if player_alive > enemy_alive else "defeat"
	if player_health != enemy_health:
		return "victory" if player_health > enemy_health else "defeat"
	return ""
