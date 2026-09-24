extends Resource
class_name TraitDef

@export var id: String = ""
@export var name: String = ""
# Ordered thresholds for activation (e.g., [2,4,6,8])
@export var thresholds: Array[int] = []
@export var description: String = ""

## Ladder-shaped activation. When true, a count that falls BETWEEN two rungs
## activates nothing, and a count past the top rung keeps the top tier.
##
## Exile and Liaison are authored "exactly 1, 3, or 5", so 2 and 4 are dead
## zones that pay nothing. Every other trait is authored as a plain ramp, where
## the highest reached threshold wins and a count of 3 on a [2,4,6,8] ladder sits
## at tier 0.
@export var exact_thresholds: bool = false

## The one place the ladder rule lives, so a dead zone cannot exist in the
## compiler and not in the generator.
##
## `thresholds` is passed in rather than read off the instance because callers
## coerce an empty ladder to the default [2,4,6,8] first. Returns -1 when the
## count activates nothing.
static func tier_for(count: int, thresholds: Array[int], exact: bool) -> int:
	var tier: int = -1
	for i: int in range(thresholds.size()):
		if count >= int(thresholds[i]):
			tier = i
	if tier < 0:
		return -1
	if exact and tier < thresholds.size() - 1:
		return tier if count == int(thresholds[tier]) else -1
	return tier
