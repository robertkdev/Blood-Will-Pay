extends RefCounted
class_name OutcomeLadder

## Forced-result ladder for a fight that runs the clock out.
##
## This ladder is Blood Will Pay's own terminal rule, not a port of another game's.
## Teamfight Tactics handles a stalemate by escalating the fight with overtime combat
## modifiers - stronger offense, reduced sustain and crowd control - rather than
## comparing the two boards. This game instead awards the round from the board state
## so a clocked-out fight still resolves.
##
## Absolute remaining health is the rule, not a fraction of the roster - a fraction
## divides by the team's full maximum including dead units, so it can rank two sides
## the other way round from the health they actually have left.
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
